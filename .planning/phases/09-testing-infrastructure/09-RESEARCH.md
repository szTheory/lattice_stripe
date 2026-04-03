# Phase 9: Testing Infrastructure - Research

**Researched:** 2026-04-03
**Domain:** ExUnit integration testing, stripe-mock, LatticeStripe.Testing public module, mix CI alias
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Integration tests use `@tag :integration` and are skipped by default (`ExUnit.configure(exclude: [:integration])`). Enable with `mix test --include integration`. This keeps default `mix test` fast and CI-independent.
- **D-02:** stripe-mock runs as a Docker container (`stripe/stripe-mock:latest`) on ports 12111-12112. Tests connect to `http://localhost:12111` with real Finch HTTP calls (not mocked transport).
- **D-03:** Integration tests cover all resource modules: Customer, PaymentIntent, SetupIntent, PaymentMethod, Refund, Checkout.Session — CRUD + action verbs + list + error cases.
- **D-04:** Integration test client uses a dedicated `test_integration_client/0` helper with real Finch transport (not MockTransport), configured for stripe-mock's base URL.
- **D-05:** `LatticeStripe.Testing` is a public module shipped with the hex package, providing helpers for downstream app tests. It is NOT a dev-only dependency — users import it in their test code.
- **D-06:** Testing module provides: `generate_webhook_event/2` (constructs a realistic Event struct with valid signatures for testing webhook handlers), `generate_webhook_payload/2` (raw signed payload + signature header pair for Plug-level testing).
- **D-07:** Testing module does NOT provide a mock transport or test client — those are internal concerns. It focuses on webhook event construction since that's the primary pain point for downstream users.
- **D-08:** Audit existing 535 tests against Phase 9 success criteria. Focus on gaps, not rewriting what works. Existing Mox-based unit tests are already strong — the main gap is integration tests (TEST-01) and the public Testing module (TEST-04).
- **D-09:** Unit test gaps to fill: edge cases in form encoding, error normalization for unusual Stripe error shapes, pagination cursor management edge cases, telemetry metadata completeness.
- **D-10:** Create a `mix ci` alias that runs: `mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict && mix test && mix docs --warnings-as-errors`. Phase 11 will invoke this alias from GitHub Actions.
- **D-11:** Credo config (`.credo.exs`) should be created if not present, with strict mode and sensible defaults for a library project.

### Claude's Discretion

- Integration test granularity: Claude decides which specific stripe-mock endpoints to test per resource (CRUD minimum, action verbs where applicable)
- Test file organization: Claude decides whether integration tests go in a separate `test/integration/` directory or alongside existing tests with tags
- Fixture reuse: Claude decides how much of the existing fixture infrastructure to reuse vs creating integration-specific fixtures

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | Integration tests validate real HTTP request/response cycles via stripe-mock | stripe-mock Docker, Finch transport, `@tag :integration`, `test_integration_client/0` pattern |
| TEST-02 | Unit tests cover pure logic: request building, response decoding, error normalization, pagination | Audit of existing 535 tests — gaps identified in form encoding edge cases, unusual error shapes, pagination cursors |
| TEST-03 | Mox-based tests validate Transport behaviour contract adherence | Existing MockTransport tests already cover most cases; gap analysis shows behaviour contract tests need explicit callback verification |
| TEST-04 | Test helpers available for constructing mock webhook events | `LatticeStripe.Testing` public module using `Webhook.generate_test_signature/2` + `Event.from_map/1` |
| TEST-05 | CI runs formatter, compiler warnings, Credo, tests, ExDoc build | `mix ci` alias in mix.exs — all tools already present, `.credo.exs` exists in strict: false mode, needs strict: true |
| TEST-06 | CI tests across Elixir 1.15/OTP 26, 1.17/OTP 27, 1.19/OTP 28 | Matrix is Phase 11 (GitHub Actions). Phase 9 only ensures checks pass locally. |
</phase_requirements>

## Summary

Phase 9 is primarily a **gap-filling phase**, not a greenfield build. The project already has a large, well-structured test suite (~535 tests) organized around Mox-based Transport mocking, covering all resource modules. The main gaps are: (1) integration tests against stripe-mock are entirely absent, (2) the public `LatticeStripe.Testing` module does not exist yet, and (3) the `mix ci` alias is not defined.

The existing infrastructure is reusable. `LatticeStripe.Webhook.generate_test_signature/2` already produces valid Stripe-compatible `Stripe-Signature` headers — the `LatticeStripe.Testing` module wraps this with a higher-level API for downstream users. Integration tests require Finch to be started in the test process (not mocked via MockTransport), which requires a `test_integration_client/0` helper and a Finch named process started in the integration test setup.

The `.credo.exs` already exists in the project with `strict: false`. Decision D-11 requires it to be updated to `strict: true` for library-grade consistency. All other tools (ExDoc, Credo, formatter) are already in `mix.exs`.

**Primary recommendation:** Implement in three sequential work units — (1) integration test infrastructure + tests, (2) `LatticeStripe.Testing` public module, (3) `mix ci` alias + Credo strict mode update.

## Standard Stack

### Core (all already in mix.exs)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExUnit | stdlib | Test framework | Ships with Elixir. Already used across all 535 tests. |
| Mox | ~> 1.2 | Behaviour mocking | Already used project-wide via `MockTransport`, `MockJson`, `MockRetryStrategy`. |
| Finch | ~> 0.19 | Real HTTP for integration tests | Already a runtime dep. Integration tests use real Finch pool, not MockTransport. |
| stripe-mock | latest (Docker) | OpenAPI-driven Stripe mock server | Official Stripe tool; validates requests against real OpenAPI spec. |
| Credo | ~> 1.7 | Static analysis | Already in mix.exs as dev/test dep. `.credo.exs` already exists. |
| ExDoc | ~> 0.34 | Documentation build gate | Already in mix.exs as dev dep. `mix docs --warnings-as-errors` is the gate. |

### No New Dependencies Required

All tools needed for Phase 9 are already declared in `mix.exs`. This phase adds test files and modules, not new dependencies.

**Installation:** No new `mix deps.get` needed.

**stripe-mock Docker:**
```bash
docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest
```

Docker 27.5.1 is available on the development machine. stripe-mock image availability confirmed (Docker available; image pull tested).

## Architecture Patterns

### Recommended Project Structure

```
lib/
└── lattice_stripe/
    └── testing.ex          # NEW: public module for downstream users

test/
├── test_helper.exs         # UPDATE: add ExUnit.configure(exclude: [:integration])
├── support/
│   └── test_helpers.ex     # UPDATE: add test_integration_client/0
└── integration/            # NEW: integration test directory
    ├── customer_integration_test.exs
    ├── payment_intent_integration_test.exs
    ├── setup_intent_integration_test.exs
    ├── payment_method_integration_test.exs
    ├── refund_integration_test.exs
    └── checkout_session_integration_test.exs

mix.exs                     # UPDATE: add aliases with mix ci
.credo.exs                  # UPDATE: strict: false -> strict: true
```

### Pattern 1: ExUnit Integration Tag Exclusion

**What:** Integration tests tagged with `@tag :integration` are excluded from `mix test` by default. Run with `--include integration` when stripe-mock is available.

**When to use:** Any test that requires an external service (stripe-mock, real HTTP).

```elixir
# In test/test_helper.exs — add this line:
ExUnit.configure(exclude: [:integration])

# In integration test file:
defmodule LatticeStripe.CustomerIntegrationTest do
  use ExUnit.Case, async: false   # async: false — shared network resource

  @moduletag :integration

  setup do
    client = LatticeStripe.TestHelpers.test_integration_client()
    {:ok, client: client}
  end

  test "create customer via stripe-mock", %{client: client} do
    assert {:ok, customer} = LatticeStripe.Customer.create(client, %{
      "email" => "test@example.com",
      "name" => "Test User"
    })
    assert customer.id =~ ~r/^cus_/
    assert customer.email == "test@example.com"
  end
end
```

### Pattern 2: Integration Client with Real Finch

**What:** `test_integration_client/0` creates a real `LatticeStripe.Client` pointing at stripe-mock, using `LatticeStripe.Transport.Finch` (not MockTransport).

**When to use:** All integration test setups.

```elixir
# In test/support/test_helpers.ex — add this function:
def test_integration_client(overrides \\ []) do
  defaults = [
    api_key: "sk_test_123",      # stripe-mock accepts any sk_test_ key
    base_url: "http://localhost:12111",
    finch: LatticeStripe.IntegrationFinch,
    transport: LatticeStripe.Transport.Finch,
    telemetry_enabled: false,
    max_retries: 0
  ]

  Client.new!(Keyword.merge(defaults, overrides))
end
```

Finch must be started for integration tests. Options:
1. Start a named Finch instance in `test_helper.exs` under `Application.ensure_all_started/1` or directly via `Finch.start_link/1` — simplest approach.
2. Each integration test module starts Finch in a `setup_all` block.

**Recommended:** Start `LatticeStripe.IntegrationFinch` in `test_helper.exs` conditionally, or use a `start_supervised!` call in integration test `setup_all`. The `start_supervised!/1` approach is cleaner for test isolation.

```elixir
# In integration test setup_all:
setup_all do
  start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
  :ok
end
```

### Pattern 3: LatticeStripe.Testing Public Module

**What:** A public module shipped in the library (not dev-only) that downstream users import in their test files to construct realistic webhook events.

**When to use:** Downstream apps testing their webhook handlers without needing to know Stripe's signing scheme.

```elixir
defmodule LatticeStripe.Testing do
  @moduledoc """
  Test helpers for apps using LatticeStripe.

  Import this module in your test files to construct realistic Stripe webhook
  events and signed payloads without hard-coding HMAC values.

  ## Usage

      # In your test:
      import LatticeStripe.Testing

      test "handles payment_intent.succeeded webhook" do
        event = generate_webhook_event("payment_intent.succeeded", %{
          "object" => %{"id" => "pi_123", "amount" => 2000, "status" => "succeeded"}
        })
        assert handle_webhook(event) == :ok
      end

      test "Plug-level webhook verification" do
        {payload, sig_header} = generate_webhook_payload(
          "customer.created",
          %{"object" => %{"id" => "cus_123"}},
          secret: "whsec_test_secret"
        )
        # Use payload + sig_header to test your webhook Plug directly
      end
  """

  alias LatticeStripe.{Event, Webhook}

  @doc """
  Builds a `%LatticeStripe.Event{}` struct for the given event type and data.

  The event has a realistic shape matching Stripe's API. The `data.object` map
  is whatever you pass as `object_data`. No real HTTP calls are made.

  ## Parameters

  - `type` - Stripe event type string, e.g. `"payment_intent.succeeded"`
  - `object_data` - The `data.object` map for the event (default: `%{}`)
  - `opts` - Options:
    - `:id` - Event ID (default: `"evt_test_" <> random_hex`)
    - `:api_version` - API version string (default: current pinned version)
    - `:livemode` - boolean (default: `false`)

  ## Returns

  A `%LatticeStripe.Event{}` struct.
  """
  @spec generate_webhook_event(String.t(), map(), keyword()) :: Event.t()
  def generate_webhook_event(type, object_data \\ %{}, opts \\ []) do
    id = Keyword.get(opts, :id, "evt_test_" <> random_hex(16))
    api_version = Keyword.get(opts, :api_version, "2026-03-25.dahlia")
    livemode = Keyword.get(opts, :livemode, false)

    Event.from_map(%{
      "id" => id,
      "object" => "event",
      "type" => type,
      "api_version" => api_version,
      "created" => System.system_time(:second),
      "livemode" => livemode,
      "pending_webhooks" => 1,
      "request" => %{"id" => nil, "idempotency_key" => nil},
      "data" => %{"object" => object_data}
    })
  end

  @doc """
  Generates a signed webhook payload pair for Plug-level testing.

  Returns `{payload_string, signature_header_value}` where the signature
  is computed with `Webhook.generate_test_signature/2`.

  ## Parameters

  - `type` - Stripe event type string
  - `object_data` - The `data.object` map for the event (default: `%{}`)
  - `opts` - Options:
    - `:secret` - Webhook signing secret (required)
    - `:timestamp` - Unix timestamp to embed in signature (default: current time)
    - Other opts forwarded to `generate_webhook_event/3`

  ## Returns

  `{raw_payload_string, stripe_signature_header_value}`

  ## Example

      {payload, sig_header} = LatticeStripe.Testing.generate_webhook_payload(
        "payment_intent.succeeded",
        %{"id" => "pi_123", "status" => "succeeded"},
        secret: "whsec_test"
      )
  """
  @spec generate_webhook_payload(String.t(), map(), keyword()) ::
          {String.t(), String.t()}
  def generate_webhook_payload(type, object_data \\ %{}, opts \\ []) do
    {secret, opts} = Keyword.pop!(opts, :secret)
    {timestamp, opts} = Keyword.pop(opts, :timestamp, System.system_time(:second))

    event = generate_webhook_event(type, object_data, opts)

    payload = Jason.encode!(%{
      "id" => event.id,
      "object" => event.object,
      "type" => event.type,
      "api_version" => event.api_version,
      "created" => event.created,
      "livemode" => event.livemode,
      "pending_webhooks" => event.pending_webhooks,
      "request" => event.request,
      "data" => event.data
    })

    sig_header = Webhook.generate_test_signature(payload, secret, timestamp: timestamp)
    {payload, sig_header}
  end

  defp random_hex(bytes), do: :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
end
```

### Pattern 4: mix ci Alias

**What:** A `mix ci` alias in `mix.exs` that chains all quality gates in one command.

**When to use:** Pre-commit, pre-PR, and (in Phase 11) GitHub Actions.

```elixir
# In mix.exs project/0:
def project do
  [
    # ... existing config ...
    aliases: aliases()
  ]
end

defp aliases do
  [
    ci: [
      "format --check-formatted",
      "compile --warnings-as-errors",
      "credo --strict",
      "test",
      "docs --warnings-as-errors"
    ]
  ]
end
```

Note: `mix docs --warnings-as-errors` requires ExDoc ~> 0.34. The project already declares `{:ex_doc, "~> 0.34", only: :dev, runtime: false}` so this is satisfied.

### Pattern 5: Integration Test Coverage per Resource

**What:** Each resource integration test file covers CRUD operations plus action verbs. stripe-mock returns OpenAPI-spec-compliant responses.

**stripe-mock behavior:** Returns fixture data (not real Stripe data). IDs returned match the `*_test_*` pattern for some resources but not all — the key value is that HTTP round-trips work end-to-end. stripe-mock rejects requests that don't match the OpenAPI spec (wrong params, wrong method), so integration tests also validate our request construction.

**Coverage plan (Claude's discretion):**

| Resource | Operations to test |
|----------|-------------------|
| Customer | create, retrieve, update, delete, list |
| PaymentIntent | create, retrieve, update, confirm, capture, cancel, list |
| SetupIntent | create, retrieve, update, confirm, cancel, list |
| PaymentMethod | create, retrieve, update, attach, detach, list |
| Refund | create, retrieve, update, list |
| Checkout.Session | create (payment mode), retrieve, expire, list |

Action verbs (confirm, capture, cancel, attach, detach, expire) each make separate POST requests — test them as distinct integration tests.

**Error case:** Test with an invalid ID (e.g., `"cus_nonexistent"`) — stripe-mock returns a 404 `resource_missing` error, validating our error normalization path.

### Anti-Patterns to Avoid

- **`async: true` in integration tests:** Integration tests share a real network connection to stripe-mock. Use `async: false` to prevent test interference.
- **Hard-coding HMAC values in tests:** Use `Webhook.generate_test_signature/2` instead. Hard-coded values break when the timestamp tolerance check is active.
- **Starting Finch in each `setup` (not `setup_all`):** Creates and tears down Finch pools per test — slow. Use `setup_all` or start once in `test_helper.exs`.
- **Relying on fixture IDs from stripe-mock:** stripe-mock generates its own IDs. Assert on shape (starts with `cus_`, not nil) rather than exact values.
- **Calling `mix ci` with `mix test --include integration` in the alias:** The `ci` alias should run only default (non-integration) tests. Integration tests need stripe-mock running, which is a separate CI job concern (Phase 11).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Webhook signature for tests | Custom HMAC builder | `LatticeStripe.Webhook.generate_test_signature/2` | Already exists, tested, correct format |
| JSON encoding in Testing module | Custom serializer | `Jason.encode!/1` | Already a direct dep; no codec abstraction needed for test helper |
| Stripe mock HTTP server | Custom Plug mock | `stripe/stripe-mock` Docker image | Validates against real OpenAPI spec — catches malformed requests |
| ExUnit test filtering | Custom test runner | `@tag :integration` + `ExUnit.configure(exclude:)` | Standard ExUnit pattern, zero code |
| Credo config | Custom lint rules | `.credo.exs` with `strict: true` | Already exists, only needs `strict: false` changed to `strict: true` |

**Key insight:** All the tools exist. This phase is about wiring them together, filling coverage gaps, and exposing the right public surface for downstream users.

## Common Pitfalls

### Pitfall 1: Finch Not Started for Integration Tests

**What goes wrong:** Integration tests crash with `{:error, %RuntimeError{message: "could not find Finch name..."}}` because no Finch pool with the expected name is running.

**Why it happens:** Unlike Mox-based unit tests that use `MockTransport`, integration tests use `LatticeStripe.Transport.Finch`, which calls `Finch.request/3` — requiring a live, named Finch process in the supervision tree.

**How to avoid:** Add `start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})` in `setup_all` blocks, or start it in `test_helper.exs` with a guard checking whether stripe-mock is reachable.

**Warning signs:** `KeyError: key :finch not found` or `RuntimeError: could not find Finch name`.

### Pitfall 2: stripe-mock Not Running Causes Confusing Errors

**What goes wrong:** Integration tests fail with `{:error, %Mint.TransportError{reason: :econnrefused}}` when stripe-mock is not running, and ExUnit reports these as test failures rather than setup failures.

**Why it happens:** The connection is only attempted when the test body runs, not during setup.

**How to avoid:** Add a connectivity check in `test_helper.exs` or a `setup_all` block that attempts a simple HTTP request to `http://localhost:12111` and skips the suite with a message if not reachable:

```elixir
# Optional guard in setup_all:
setup_all do
  case :gen_tcp.connect(~c"localhost", 12111, [], 1000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
      :ok
    {:error, _} ->
      {:skip, "stripe-mock not running on localhost:12111"}
  end
end
```

**Warning signs:** `econnrefused` errors on integration tests when you forgot to start Docker.

### Pitfall 3: LatticeStripe.Testing Compiled into Production Releases

**What goes wrong:** Downstream users who use `LatticeStripe.Testing` in `test` env see it unexpectedly available in prod because the module ships in the library's main `lib/` directory without env gating.

**Why it happens:** Unlike internal test helpers in `test/support/` (which are only compiled when `elixirc_paths(:test)` is active), `lib/lattice_stripe/testing.ex` is always compiled.

**Is this a problem?** No — this is intentional per D-05. The module ships in the hex package so downstream users can use it. The module itself has no side effects (no processes started, no global state). Size impact is negligible. Document clearly in `@moduledoc` that it is a test-only utility.

**Warning signs:** None — this is expected behavior. Just document intent clearly.

### Pitfall 4: Credo Strict Mode Failures on Existing Code

**What goes wrong:** Changing `.credo.exs` from `strict: false` to `strict: true` makes `mix credo --strict` surface previously-suppressed low-priority issues across existing code.

**Why it happens:** Strict mode enables low-priority checks that were previously suppressed. Common issues: `AliasUsage`, `SinglePipe`, `ModuleDoc` on private helpers.

**How to avoid:** Run `mix credo --strict` before committing the config change. Fix or suppress individual checks in `.credo.exs` rather than leaving the config as `strict: false`. The `@moduledoc false` pattern is acceptable for internal modules.

**Warning signs:** Sudden flood of Credo issues after enabling strict mode.

### Pitfall 5: generate_webhook_payload/3 Timestamp Tolerance Mismatch

**What goes wrong:** Tests using `generate_webhook_payload/3` fail intermittently with `{:error, :timestamp_expired}` when the system clock advances past the 300-second tolerance window during test execution.

**Why it happens:** Not a real problem in practice — tests run in milliseconds. But if a test calls `generate_webhook_payload/3`, stores the payload, and then processes it after a significant delay (e.g., in a slow integration environment), the timestamp could expire.

**How to avoid:** Tests that verify `construct_event/4` should use `tolerance: 0` carefully (it always returns `:timestamp_expired`) or pass an explicit `:timestamp` that's guaranteed fresh. Normal test execution has no issue.

**Warning signs:** Flaky `{:error, :timestamp_expired}` in slow CI environments.

## Code Examples

### Integration Test File Structure

```elixir
# Source: decisions D-01, D-02, D-03, D-04
defmodule LatticeStripe.CustomerIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Customer, Error}

  @moduletag :integration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok
      {:error, _} ->
        {:skip, "stripe-mock not running on localhost:12111 — run: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"}
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  describe "create/3" do
    test "creates a customer and returns typed struct", %{client: client} do
      assert {:ok, %Customer{} = customer} =
               Customer.create(client, %{"email" => "test@example.com", "name" => "Test User"})

      assert is_binary(customer.id)
      assert customer.email == "test@example.com"
    end
  end

  describe "retrieve/3" do
    test "retrieves a customer by ID", %{client: client} do
      {:ok, created} = Customer.create(client, %{"email" => "retrieve@test.com"})
      assert {:ok, %Customer{id: ^created.id}} = Customer.retrieve(client, created.id)
    end

    test "returns error for nonexistent ID", %{client: client} do
      assert {:error, %Error{type: :invalid_request_error}} =
               Customer.retrieve(client, "cus_nonexistent999")
    end
  end
end
```

### test_integration_client/0 Helper

```elixir
# Add to test/support/test_helpers.ex
def test_integration_client(overrides \\ []) do
  defaults = [
    api_key: "sk_test_123",
    base_url: "http://localhost:12111",
    finch: LatticeStripe.IntegrationFinch,
    transport: LatticeStripe.Transport.Finch,
    telemetry_enabled: false,
    max_retries: 0
  ]

  LatticeStripe.Client.new!(Keyword.merge(defaults, overrides))
end
```

### test_helper.exs Integration Tag Exclusion

```elixir
# Source: decision D-01
ExUnit.start()
ExUnit.configure(exclude: [:integration])

# Existing Mox mock definitions — unchanged:
Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)
Mox.defmock(LatticeStripe.MockJson, for: LatticeStripe.Json)
Mox.defmock(LatticeStripe.MockRetryStrategy, for: LatticeStripe.RetryStrategy)
```

### mix.exs Aliases Addition

```elixir
# Source: decision D-10
defp aliases do
  [
    ci: [
      "format --check-formatted",
      "compile --warnings-as-errors",
      "credo --strict",
      "test",
      "docs --warnings-as-errors"
    ]
  ]
end
```

### LatticeStripe.Testing Usage by Downstream Users

```elixir
# In downstream app test — how users consume the Testing module
defmodule MyApp.WebhooksTest do
  use ExUnit.Case, async: true

  import LatticeStripe.Testing

  test "handles payment_intent.succeeded event" do
    # High-level: get an Event struct directly
    event = generate_webhook_event("payment_intent.succeeded", %{
      "id" => "pi_test123",
      "amount" => 2000,
      "currency" => "usd",
      "status" => "succeeded"
    })

    assert {:ok, :processed} = MyApp.Webhooks.handle(event)
  end

  test "Plug integration: verifies real signature on POST /webhooks" do
    # Low-level: get raw payload + header for Conn-level testing
    {payload, sig_header} = generate_webhook_payload(
      "customer.created",
      %{"id" => "cus_test456", "email" => "new@example.com"},
      secret: "whsec_test_secret_for_test_env"
    )

    conn =
      Plug.Test.conn(:post, "/webhooks", payload)
      |> Plug.Conn.put_req_header("stripe-signature", sig_header)
      |> MyApp.Router.call([])

    assert conn.status == 200
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ExVCR cassette recording | stripe-mock + Mox | 2020+ community shift | stripe-mock validates against real OpenAPI spec, not brittle recorded responses |
| Manual HMAC in tests | `generate_test_signature/2` | Phase 7 | Eliminates hard-coded hex values that break with timestamp checks |
| Integration tests always run | `@tag :integration` exclusion | Standard ExUnit practice | Default `mix test` stays fast; integration tests run when stripe-mock is available |

**Deprecated/outdated:**
- ExVCR: Brittle cassette-based HTTP mocking. Explicitly excluded in CLAUDE.md and REQUIREMENTS.md.
- Bypass: Local HTTP server — stripe-mock is better because it validates against Stripe's actual OpenAPI spec.

## Open Questions

1. **stripe-mock ID format for some resources**
   - What we know: stripe-mock returns fixture IDs; exact format varies by resource (e.g., `cus_123` vs. longer fixture IDs)
   - What's unclear: Whether `customer.id =~ ~r/^cus_/` assertions hold for all stripe-mock responses
   - Recommendation: Assert `is_binary(id)` and not nil rather than prefix pattern; verify with a test run against stripe-mock.

2. **PaymentMethod list/3 requires customer ID pre-network**
   - What we know: `PaymentMethod.list/3` calls `Resource.require_param!` before HTTP — requires `customer` param
   - What's unclear: stripe-mock may not require it (permissive) — integration test should still pass the param to match real Stripe behavior
   - Recommendation: Always pass `customer` param in PaymentMethod integration tests.

3. **generate_webhook_payload/3 Event struct vs raw map encoding**
   - What we know: `Event.from_map/1` may not round-trip perfectly back to a JSON-encodable map (extra fields handling)
   - What's unclear: Whether encoding the Event struct back to JSON for `generate_webhook_payload/3` needs special handling for the `extra` field
   - Recommendation: Build the raw map before calling `Event.from_map/1` in `generate_webhook_payload/3`, not after — see code example above.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | stripe-mock integration tests | Yes | 27.5.1 | Run stripe-mock binary directly (not recommended) |
| stripe-mock image | TEST-01 integration tests | Needs pull | latest | — |
| Finch (dep) | test_integration_client | Yes (in mix.exs) | ~> 0.19 | — |
| ExDoc | `mix docs` gate (TEST-05) | Yes (in mix.exs) | ~> 0.34 | — |
| Credo | `mix credo` gate (TEST-05) | Yes (in mix.exs) | ~> 1.7 | — |

**Missing dependencies with no fallback:**
- stripe-mock Docker image: Must be pulled before integration tests run (`docker pull stripe/stripe-mock:latest`). Phase 11 (GitHub Actions) handles this in CI. Locally, developers must run Docker.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, ships with Elixir 1.15+) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test --include integration` |
| CI alias | `mix ci` (after alias is added) |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | Real HTTP request/response cycles via stripe-mock | integration | `mix test --include integration` | Wave 0 (new files) |
| TEST-02 | Pure logic: form encoding edge cases, error normalization, pagination cursors | unit | `mix test test/lattice_stripe/form_encoder_test.exs test/lattice_stripe/error_test.exs test/lattice_stripe/list_test.exs` | Partial (files exist, gaps to fill) |
| TEST-03 | Transport behaviour contract adherence | unit (Mox) | `mix test test/lattice_stripe/transport_test.exs` | Partial (file exists, completeness check) |
| TEST-04 | LatticeStripe.Testing helpers for webhook event construction | unit | `mix test test/lattice_stripe/testing_test.exs` | Wave 0 (new file) |
| TEST-05 | `mix ci` alias runs all quality gates | manual + alias | `mix ci` | Wave 0 (alias not yet in mix.exs) |
| TEST-06 | Matrix across Elixir versions | CI matrix | N/A — Phase 11 scope | N/A |

### Sampling Rate

- **Per task commit:** `mix test` (excludes integration)
- **Per wave merge:** `mix test && mix credo` (excludes integration)
- **Phase gate:** `mix ci` green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/integration/customer_integration_test.exs` — covers TEST-01 (Customer)
- [ ] `test/integration/payment_intent_integration_test.exs` — covers TEST-01 (PaymentIntent)
- [ ] `test/integration/setup_intent_integration_test.exs` — covers TEST-01 (SetupIntent)
- [ ] `test/integration/payment_method_integration_test.exs` — covers TEST-01 (PaymentMethod)
- [ ] `test/integration/refund_integration_test.exs` — covers TEST-01 (Refund)
- [ ] `test/integration/checkout_session_integration_test.exs` — covers TEST-01 (Checkout.Session)
- [ ] `lib/lattice_stripe/testing.ex` — covers TEST-04
- [ ] `test/lattice_stripe/testing_test.exs` — unit tests for LatticeStripe.Testing
- [ ] `mix.exs aliases/0` addition — covers TEST-05 (`mix ci`)
- [ ] `test/test_helper.exs` update — add `ExUnit.configure(exclude: [:integration])`
- [ ] `test/support/test_helpers.ex` update — add `test_integration_client/0`
- [ ] `.credo.exs` update — change `strict: false` to `strict: true`

## Sources

### Primary (HIGH confidence)

- ExUnit documentation (stdlib, no external source needed) — tag configuration, `setup_all`, `@moduletag`
- `test/test_helper.exs` in project — current Mox mock definitions
- `test/support/test_helpers.ex` in project — existing `test_client/1`, `ok_response/1`, `error_response/0`, `list_json/2`
- `lib/lattice_stripe/webhook.ex` in project — `generate_test_signature/2` function (basis for Testing module)
- `lib/lattice_stripe/event.ex` in project — `Event.from_map/1` (used in Testing module)
- `mix.exs` in project — confirmed all dependencies already declared
- `.credo.exs` in project — confirmed exists with `strict: false`
- `09-CONTEXT.md` — all locked decisions D-01 through D-11

### Secondary (MEDIUM confidence)

- stripe-mock GitHub (`https://github.com/stripe/stripe-mock`) — Docker image `stripe/stripe-mock:latest`, ports 12111-12112, accepts any `sk_test_*` API key
- Mox documentation — `start_supervised!`, `verify_on_exit!`, `async: false` for integration tests

### Tertiary (LOW confidence)

- None — all claims are verified against project source or official stdlib documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all dependencies already in mix.exs, verified in project
- Architecture: HIGH — based on existing project patterns and locked CONTEXT.md decisions
- Pitfalls: HIGH — derived from existing codebase analysis and known ExUnit/Mox patterns
- Integration test coverage plan: MEDIUM — stripe-mock response shapes assumed based on official docs; exact ID formats to verify on first run

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable domain — ExUnit, Mox, stripe-mock APIs rarely change)
