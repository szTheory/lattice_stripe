# Testing

This guide helps you choose the smallest test that can truthfully prove each Stripe integration
behavior. LatticeStripe provides raw and typed fixtures, a mockable `Transport` behaviour, signed
webhook helpers, and integration points for Stripe's own test tools.

For Stripe's official testing documentation (test card numbers, bank accounts, etc.), see
[Stripe Testing docs](https://docs.stripe.com/testing).

## Testing pyramid: choose the smallest truthful test

Not every behavior needs a network test, and no single test double proves everything. Start at
the lowest useful layer and add a higher layer only for behavior the lower layer cannot model.

| Layer | Best for | What it does not prove |
|-------|----------|------------------------|
| Shipped fixtures and pure tests | Business rules, resource decoding, and application state transitions | Request encoding, signatures, or Stripe behavior |
| Mox at `LatticeStripe.Transport` | Request method/path/body, retry decisions, response decoding, and error handling | Real HTTP or Stripe's server-side state machine |
| `Plug.Test` with signed payload helpers | Webhook routing, signature verification, and handler responses | Stripe delivery timing or redelivery behavior |
| [stripe-mock](https://github.com/stripe/stripe-mock) | Real HTTP plumbing plus basic route, parameter, and response-shape compatibility | Persistence, lifecycle transitions, asynchronous events, or complete Stripe validation |
| Stripe test mode, Stripe CLI, and Test Clocks | Provider validation, object lifecycles, webhook delivery, and time-dependent billing behavior | Live-mode account configuration and production operations |

Most application tests should use fixtures or Mox. Keep a smaller integration suite for the
provider behaviors your application actually depends on. A green stripe-mock test is useful
evidence, but it is not proof that Stripe test mode will accept or behave like the scenario.

## Public fixture builders

LatticeStripe ships canonical raw-map fixtures under `LatticeStripe.Testing.Fixtures.*`. These
modules are the canonical fixture source of truth for the resource families LatticeStripe ships.

These modules are the recommended starting point when you want realistic Stripe-shaped
payloads in downstream application tests:

- `LatticeStripe.Testing.Fixtures.File`
- `LatticeStripe.Testing.Fixtures.FileLink`
- `LatticeStripe.Testing.Fixtures.Dispute`
- `LatticeStripe.Testing.Fixtures.CreditNote`
- `LatticeStripe.Testing.Fixtures.Mandate`
- `LatticeStripe.Testing.Fixtures.SetupAttempt`
- `LatticeStripe.Testing.Fixtures.Quote`
- `LatticeStripe.Testing.Fixtures.TaxCalculation`
- `LatticeStripe.Testing.Fixtures.TaxTransaction`
- `LatticeStripe.Testing.Fixtures.TaxId`
- `LatticeStripe.Testing.Fixtures.Entitlements`
- `LatticeStripe.Testing.Fixtures.MeterEvent`
- `LatticeStripe.Testing.Fixtures.MeterEventSummary`
- `LatticeStripe.Testing.Fixtures.MeterErrorReport`
- `LatticeStripe.Testing.Fixtures.Customer`
- `LatticeStripe.Testing.Fixtures.PaymentIntent`
- `LatticeStripe.Testing.Fixtures.Subscription`
- `LatticeStripe.Testing.Fixtures.Invoice`

The raw map is the canonical test shape. Build other forms explicitly on top:

- `LatticeStripe.Testing.generate_webhook_event/3` for `%LatticeStripe.Event{}`
- `LatticeStripe.Testing.generate_webhook_payload/3` for signed raw webhook payloads
- `LatticeStripe.Testing.quote/1`, `dispute/1`, `credit_note/1`, `tax_calculation/1`, `tax_transaction/1`, `tax_id/1`, `active_entitlement/1`, `active_entitlement_summary/1`, `feature/1`, `meter_event/1`, `meter_event_summary/1`, `meter_error_report/1`, `customer/1`, `payment_intent/1`, `subscription/1`, `invoice/1`, and friends for typed structs

## Tax

Stripe Tax fixtures follow the same two-layer pattern as Credit Notes and Quotes:

1. Build a wire map with `tax_calculation_json/1`, `tax_transaction_json/1`, or `tax_id_json/1`
2. Convert to a typed struct with `LatticeStripe.Testing.tax_calculation/1`, `tax_transaction/1`, or `tax_id/1`

```elixir
import LatticeStripe.Testing.Fixtures.TaxCalculation
import LatticeStripe.Testing.Fixtures.TaxTransaction

alias LatticeStripe.Testing
alias LatticeStripe.Tax

calc_map = tax_calculation_json(%{"currency" => "eur"})
calc = Testing.tax_calculation(calc_map)

txn_map =
  tax_transaction_json(%{
    "reference" => "order-#{System.unique_integer([:positive])}",
    "line_items" => %{
      "object" => "list",
      "data" => [tax_transaction_line_item_json()],
      "has_more" => false
    }
  })

txn = Testing.tax_transaction(txn_map)
```

### Other resource fixtures

```elixir
alias LatticeStripe.Testing
alias LatticeStripe.Testing.Fixtures

quote_map = Fixtures.Quote.accepted_quote_json()
quote = Testing.quote(quote_map)

assert quote.id == quote_map["id"]
assert quote.status == :accepted
```

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
  alias LatticeStripe.Testing.Fixtures

  test "handles payment_intent.succeeded" do
    payment_intent = %{
      "id" => "pi_test123",
      "amount" => 2000,
      "currency" => "usd",
      "status" => "succeeded",
      "metadata" => %{"order_id" => "order_456"}
    }

    event = Testing.generate_webhook_event("payment_intent.succeeded", payment_intent)

    assert {:ok, :processed} = MyApp.WebhookHandler.handle(event)
  end

  test "handles dispute evidence workflows from canonical fixtures" do
    event =
      Testing.generate_webhook_event(
        "charge.dispute.created",
        Fixtures.Dispute.dispute_json(%{"metadata" => %{"ticket" => "support_123"}})
      )

    assert {:ok, :queued} = MyApp.WebhookHandler.handle(event)
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
  alias LatticeStripe.Testing.Fixtures

  @webhook_secret "whsec_test_supersecret"

  test "accepts valid signed webhook" do
    {payload, sig_header} = LatticeStripe.Testing.generate_webhook_payload(
      "quote.accepted",
      Fixtures.Quote.accepted_quote_json(),
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

Use [stripe-mock](https://github.com/stripe/stripe-mock) for fast integration tests that need a
real HTTP boundary and basic compatibility with routes and shapes from Stripe's OpenAPI spec.

stripe-mock is stateless and returns generated or hard-coded examples. A created object is not
persisted for a later retrieve, and the server does not reproduce lifecycle transitions,
asynchronous webhook delivery, timing behavior, or every validation performed by Stripe. Use
Stripe test mode for those behaviors; add the Stripe CLI when the test depends on webhook
delivery, and use Test Clocks for time-dependent billing transitions.

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

### Canonical fixture flow

Prefer this layering order in application tests:

1. Start with a canonical raw fixture from `LatticeStripe.Testing.Fixtures.*`
2. Use `generate_webhook_event/3` or `generate_webhook_payload/3` when you need webhook shapes
3. Use `LatticeStripe.Testing.quote/1`, `dispute/1`, and similar wrappers when your code wants typed structs

That keeps the raw Stripe payload shape as the single source of truth while still
making event tests and typed-struct tests easy to read.

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

## Which TestClock do I want?

Two public modules carry the name, and they sit at different levels. Almost always you
want the first.

| | `LatticeStripe.Testing.TestClock` | `LatticeStripe.TestHelpers.TestClock` |
|---|---|---|
| What it is | ExUnit ergonomics layer (`use`-able) | Thin wrapper over Stripe's REST surface |
| Reach for it when | writing a test that needs to move time | you need direct clock CRUD, or you are building your own helper |
| Cleanup | automatic on test exit, including on crash or assertion failure | you call `delete/3` yourself |
| Mirrors | nothing — it is our ergonomics | Stripe's literal `/v1/test_helpers/test_clocks` path |

`Testing.TestClock` is built on `TestHelpers.TestClock`, so this is a layering, not two
competing ways to do the same thing — the same relationship as `Ecto.Repo` and
`Ecto.Adapters.*`. Both are public and both are covered by semver.

Start with `Testing.TestClock.test_clock/1`; it registers each clock with a per-test owner
process that deletes it on exit, which is what keeps test clocks from accumulating against
your account. Stripe caps how many you may have, so leaked clocks eventually fail your
suite. If you do create clocks directly through `TestHelpers.TestClock`, the
`mix lattice_stripe.test_clock.cleanup` task sweeps up what you left behind.

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

**Do not make long-lived cassettes your contract**

Stripe's API evolves frequently. Recorded responses become stale and can hide changed behavior.
Prefer shipped fixtures for application logic, Mox when a test owns the response, stripe-mock for
HTTP and basic schema compatibility, and Stripe test mode for provider behavior.

**Treat stripe-mock failures as signals, not final verdicts**

A stripe-mock rejection may expose a route or shape bug and is worth investigating. Its model is
not complete, however, so confirm disputed behavior in Stripe test mode. Likewise, acceptance by
stripe-mock does not prove server-side validation, persistence, or lifecycle behavior.

**Test keys must use `sk_test_` prefix**

The real Stripe API rejects test key formatting issues. With stripe-mock, any `sk_test_` value works.
Never use real API keys in tests.

For metering-specific integration test guidance and the nightly batch flush
anti-pattern, see [metering.md](metering.md#what-not-to-do-nightly-batch-flush).

## See also

- [API Stability](api_stability.md) — compatibility guarantees for public testing helpers
- [Client Configuration](client-configuration.md) — explicit clients and per-request overrides
- [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md)
- [Metering Runtime and Reconciliation](metering-runtime-and-reconciliation.md)
- [Webhooks](webhooks.md) — signed payload helpers and end-to-end handler verification
- [Error Handling](error-handling.md) — asserting `%LatticeStripe.Error{}` shapes and request IDs
- [Metering](metering.md) — usage-reporting hot path and reconciliation follow-through
- [Event Debugging](event-debugging.md) — production webhook symptom spine after tests pass locally
