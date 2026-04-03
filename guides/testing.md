# Testing

This guide covers how to test application code that uses LatticeStripe. LatticeStripe is designed
to be testable: the `Transport` behaviour is mockable with [Mox](https://github.com/dashbitco/mox),
webhook helpers are included in the library itself, and
[stripe-mock](https://github.com/stripe/stripe-mock) provides a real HTTP server for integration
tests validated against Stripe's OpenAPI spec.

For Stripe's official testing documentation (test card numbers, bank accounts, etc.), see
[Stripe Testing docs](https://docs.stripe.com/testing).

## Mocking with Mox

LatticeStripe uses a `Transport` behaviour for all HTTP calls. In your tests, you can replace
the real Finch transport with a Mox mock — no HTTP calls, no external dependencies, full control
over responses.

**Step 1: Define the mock in your test support**

```elixir
# In test/support/mocks.ex (or anywhere compiled by elixirc_paths(:test))
Mox.defmock(MyApp.MockTransport, for: LatticeStripe.Transport)
```

Make sure `test/support/` is compiled in your `mix.exs`:

```elixir
# mix.exs
def project do
  [
    # ...
    elixirc_paths: elixirc_paths(Mix.env())
  ]
end

defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]
```

**Step 2: Configure the mock as the default in test env**

```elixir
# config/test.exs
config :my_app, :stripe_transport, MyApp.MockTransport
```

Or build the client with the mock transport directly in each test (recommended for explicitness):

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_mock",
  finch: MyApp.Finch,
  transport: MyApp.MockTransport
)
```

**Step 3: Write tests with `expect/3`**

```elixir
defmodule MyApp.PaymentsTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "creates a payment intent successfully" do
    MyApp.MockTransport
    |> expect(:request, fn request ->
      # Assert the request shape
      assert request.method == :post
      assert request.url =~ "/v1/payment_intents"

      # Return a mock Stripe response
      {:ok, %{
        status: 200,
        headers: [{"request-id", "req_test123"}],
        body: Jason.encode!(%{
          "id" => "pi_test123",
          "object" => "payment_intent",
          "amount" => 2000,
          "currency" => "usd",
          "status" => "requires_payment_method",
          "livemode" => false
        })
      }}
    end)

    client = LatticeStripe.Client.new!(
      api_key: "sk_test_mock",
      finch: MyApp.Finch,
      transport: MyApp.MockTransport
    )

    assert {:ok, %LatticeStripe.PaymentIntent{amount: 2000, currency: "usd"}} =
      LatticeStripe.PaymentIntent.create(client, %{
        "amount" => 2000,
        "currency" => "usd"
      })
  end

  test "handles card declined error" do
    MyApp.MockTransport
    |> expect(:request, fn _request ->
      {:ok, %{
        status: 402,
        headers: [{"request-id", "req_declined"}],
        body: Jason.encode!(%{
          "error" => %{
            "type" => "card_error",
            "code" => "card_declined",
            "decline_code" => "insufficient_funds",
            "message" => "Your card has insufficient funds.",
            "doc_url" => "https://docs.stripe.com/error-codes/card-declined"
          }
        })
      }}
    end)

    client = LatticeStripe.Client.new!(
      api_key: "sk_test_mock",
      finch: MyApp.Finch,
      transport: MyApp.MockTransport
    )

    assert {:error, %LatticeStripe.Error{
      type: :card_error,
      decline_code: "insufficient_funds",
      request_id: "req_declined"
    }} = LatticeStripe.PaymentIntent.create(client, %{
      "amount" => 2000,
      "currency" => "usd"
    })
  end
end
```

### Mocking Multiple Calls in Sequence

Use `expect/3` multiple times — each call consumes the next expectation in order:

```elixir
test "retries on rate limit then succeeds" do
  rate_limit_body = Jason.encode!(%{
    "error" => %{
      "type" => "rate_limit_error",
      "message" => "Too many requests"
    }
  })

  success_body = Jason.encode!(%{
    "id" => "cus_test123",
    "object" => "customer",
    "email" => "user@example.com"
  })

  MyApp.MockTransport
  |> expect(:request, fn _req ->
    {:ok, %{status: 429, headers: [], body: rate_limit_body}}
  end)
  |> expect(:request, fn _req ->
    {:ok, %{status: 200, headers: [{"request-id", "req_ok"}], body: success_body}}
  end)

  # Configure client with max_retries: 1 to test exactly one retry
  client = LatticeStripe.Client.new!(
    api_key: "sk_test_mock",
    finch: MyApp.Finch,
    transport: MyApp.MockTransport,
    max_retries: 1
  )

  assert {:ok, %LatticeStripe.Customer{email: "user@example.com"}} =
    LatticeStripe.Customer.create(client, %{"email" => "user@example.com"})
end
```

### Mocking Connection Errors

```elixir
test "returns connection_error on network failure" do
  MyApp.MockTransport
  |> expect(:request, fn _req ->
    {:error, %Mint.TransportError{reason: :econnrefused}}
  end)

  client = LatticeStripe.Client.new!(
    api_key: "sk_test_mock",
    finch: MyApp.Finch,
    transport: MyApp.MockTransport,
    max_retries: 0  # don't retry in this test
  )

  assert {:error, %LatticeStripe.Error{type: :connection_error}} =
    LatticeStripe.Customer.create(client, %{"email" => "user@example.com"})
end
```

## Testing Webhook Handlers

LatticeStripe ships `LatticeStripe.Testing` — a module included in the library itself (not just in
test support) that generates realistic signed webhook payloads. You don't need to understand Stripe's
HMAC signing scheme to test webhook handling.

### Testing Event Handler Logic

For testing your webhook business logic without any HTTP layer:

```elixir
defmodule MyApp.WebhookHandlerTest do
  use ExUnit.Case, async: true
  alias LatticeStripe.Testing

  test "handles payment_intent.succeeded" do
    event = Testing.generate_webhook_event("payment_intent.succeeded", %{
      "id" => "pi_test123",
      "amount" => 2000,
      "currency" => "usd",
      "status" => "succeeded",
      "metadata" => %{"order_id" => "order_456"}
    })

    assert {:ok, :processed} = MyApp.WebhookHandler.handle(event)
  end

  test "ignores unknown event types gracefully" do
    event = Testing.generate_webhook_event("customer.subscription.created", %{
      "id" => "sub_test789"
    })

    assert {:ok, :ignored} = MyApp.WebhookHandler.handle(event)
  end
end
```

### Testing Webhook Plug Endpoint

For testing the full HTTP path — signature verification through to your handler:

```elixir
defmodule MyApp.WebhookPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias LatticeStripe.Testing

  @webhook_secret "whsec_test_supersecret"

  test "accepts valid signed webhook" do
    {payload, sig_header} = LatticeStripe.Testing.generate_webhook_payload(
      "payment_intent.succeeded",
      %{"id" => "pi_test123", "amount" => 2000},
      secret: @webhook_secret
    )

    conn =
      conn(:post, "/webhooks/stripe", payload)
      |> put_req_header("stripe-signature", sig_header)
      |> put_req_header("content-type", "application/json")

    conn = MyApp.Router.call(conn, [])
    assert conn.status == 200
  end

  test "rejects webhook with invalid signature" do
    {payload, _valid_sig} = LatticeStripe.Testing.generate_webhook_payload(
      "payment_intent.succeeded",
      %{"id" => "pi_test123"},
      secret: @webhook_secret
    )

    conn =
      conn(:post, "/webhooks/stripe", payload)
      |> put_req_header("stripe-signature", "t=12345,v1=invalidsignature")
      |> put_req_header("content-type", "application/json")

    conn = MyApp.Router.call(conn, [])
    assert conn.status == 400
  end
end
```

The `generate_webhook_payload/3` function returns a `{raw_json_string, stripe_signature_header}`
tuple. The signature is computed using the same HMAC algorithm Stripe uses, so `Webhook.construct_event/4`
will accept it.

## Using stripe-mock

For integration tests that verify real request/response shapes against Stripe's actual API spec,
use [stripe-mock](https://github.com/stripe/stripe-mock). It's an official Stripe server powered
by Stripe's OpenAPI spec — if stripe-mock accepts your request, the real Stripe API will too.

### Starting stripe-mock

```bash
# Run via Docker (recommended for CI)
docker run -d -p 12111:12111 -p 12112:12112 stripe/stripe-mock:latest

# Or via Homebrew on macOS
brew install stripe/stripe-mock/stripe-mock
stripe-mock &
```

### Integration Test Client

Point a client at stripe-mock:

```elixir
defmodule MyApp.IntegrationTest do
  use ExUnit.Case

  # Guard: skip if stripe-mock isn't running
  setup_all do
    case :gen_tcp.connect(~c"localhost", 12111, [], 1_000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok
      {:error, _} ->
        raise "stripe-mock is not running. Start it with:\n  " <>
              "docker run -p 12111:12111 -p 12112:12112 stripe/stripe-mock:latest"
    end
  end

  defp stripe_mock_client do
    LatticeStripe.Client.new!(
      api_key: "sk_test_123",
      finch: MyApp.Finch,
      base_url: "http://localhost:12111"
    )
  end

  test "creates a customer via stripe-mock" do
    client = stripe_mock_client()

    assert {:ok, %LatticeStripe.Customer{} = customer} =
      LatticeStripe.Customer.create(client, %{
        "email" => "integration@example.com",
        "name" => "Integration Test User"
      })

    assert customer.email == "integration@example.com"
    assert is_binary(customer.id)
    assert String.starts_with?(customer.id, "cus_")
  end

  test "lists customers via stripe-mock" do
    client = stripe_mock_client()

    assert {:ok, %LatticeStripe.List{}} =
      LatticeStripe.Customer.list(client)
  end
end
```

### stripe-mock in CI (GitHub Actions)

```yaml
# .github/workflows/ci.yml
services:
  stripe-mock:
    image: stripe/stripe-mock:latest
    ports:
      - 12111:12111
      - 12112:12112
```

Then your integration tests connect to `http://localhost:12111` in CI automatically.

## Test Helper Patterns

### Shared Client Factory

Avoid repeating client setup in every test by extracting a helper:

```elixir
# test/support/stripe_helpers.ex
defmodule MyApp.StripeHelpers do
  def mock_client do
    LatticeStripe.Client.new!(
      api_key: "sk_test_mock",
      finch: MyApp.Finch,
      transport: MyApp.MockTransport
    )
  end

  def stripe_mock_client do
    LatticeStripe.Client.new!(
      api_key: "sk_test_123",
      finch: MyApp.Finch,
      base_url: "http://localhost:12111"
    )
  end
end
```

### Async Test Compatibility

Mox is safe for `async: true` tests when using `verify_on_exit!` in setup:

```elixir
defmodule MyApp.PaymentsTest do
  use ExUnit.Case, async: true  # safe with Mox
  import Mox

  setup :verify_on_exit!

  # ...
end
```

Under the hood, Mox stores expectations in the test process dictionary, so concurrent tests don't
share expectations.

### Disabling Telemetry in Tests

By default, telemetry events are emitted even with a mock transport. To disable them:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_mock",
  finch: MyApp.Finch,
  transport: MyApp.MockTransport,
  telemetry_enabled: false
)
```

## Common Pitfalls

**Mock response bodies must be valid JSON strings**

The Transport callback receives and must return raw HTTP data. The response body must be a JSON
string, not an Elixir map:

```elixir
# Wrong: body is a map — LatticeStripe will try to JSON-decode a map and fail
{:ok, %{status: 200, headers: [], body: %{"id" => "cus_123"}}}

# Correct: body is a JSON string
{:ok, %{status: 200, headers: [{"request-id", "req_test"}], body: Jason.encode!(%{"id" => "cus_123", "object" => "customer"})}}
```

**Include the `object` field in mock response bodies**

LatticeStripe uses the `"object"` field in Stripe responses for certain validations. Always include
it:

```elixir
%{
  "id" => "pi_test123",
  "object" => "payment_intent",  # required
  "amount" => 2000,
  "currency" => "usd",
  "status" => "requires_payment_method"
}
```

**Use `verify_on_exit!` to catch unused expectations**

Without it, a test that expects 2 calls but only makes 1 will silently pass:

```elixir
setup :verify_on_exit!  # catches: "expected 2 calls, got 1"
```

**Don't use ExVCR or cassette recording**

Stripe's API evolves frequently. Cassettes become stale and hide real behavior. Use Mox for unit
tests (control the response) and stripe-mock for integration tests (validates against real spec).

**stripe-mock validates against Stripe's OpenAPI spec**

If stripe-mock rejects a request with a 400 or 422, it means your request shape doesn't match
Stripe's API contract — that's a real bug. stripe-mock is more strict than just passing tests.

**Test keys must use `sk_test_` prefix**

The real Stripe API rejects test key formatting issues. With stripe-mock, any `sk_test_` value works.
Never use real API keys in tests.
