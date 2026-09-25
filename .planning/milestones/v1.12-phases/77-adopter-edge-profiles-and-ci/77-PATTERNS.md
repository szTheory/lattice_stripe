# Phase 77: Adopter Edge Profiles and CI - Pattern Map

**Mapped:** 2026-09-24  
**Files analyzed:** 5 candidate targets (3 focused profile tests, CI, README)  
**Analogs found:** 5 / 5

> The research recommends separate ExUnit files, but does not lock their exact names. The profile test paths below are proposed names; planner may choose equivalent names under `test_apps/phoenix_adopter/test/`. No package implementation or dependency changes are indicated.

## File Classification

| New/Modified File | Role | Data Flow | Closest Tracked Analog | Match Quality |
|---|---|---|---|---|
| `test_apps/phoenix_adopter/test/b2b_invoice_profile_test.exs` (proposed) | integration test | request-response | `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test/lattice_stripe/invoice_test.exs` | exact host harness + role match for SDK assertions |
| `test_apps/phoenix_adopter/test/usage_reconciliation_profile_test.exs` (proposed) | integration test | streaming + request-response | `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs`; `test/lattice_stripe/billing/meter_event_test.exs` | exact host harness + exact contract analogs |
| `test_apps/phoenix_adopter/test/connect_context_profile_test.exs` (proposed) | integration test | request-response | `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test/lattice_stripe/balance_test.exs` | exact host harness + exact request contract |
| `.github/workflows/ci.yml` | CI config | batch / verification | `.github/workflows/ci.yml` test job and `ci-gate` | exact |
| `test_apps/phoenix_adopter/README.md` (only if invocation/profile docs need updating) | adopter docs | documentation / discovery | `test_apps/phoenix_adopter/README.md` | exact |

All named code analogs were confirmed tracked with `git ls-files`. The app already owns its Phoenix endpoint, test transport mock, separate Mix project, and lockfile; no new app or package runtime module is called for.

## Pattern Assignments

### `test_apps/phoenix_adopter/test/b2b_invoice_profile_test.exs` (proposed; integration test, request-response)

**Analogs:** `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test/lattice_stripe/invoice_test.exs`

Use an ordinary async ExUnit test for direct public SDK calls through the adopter's mock transport. Build an explicit `LatticeStripe.Client` with the synthetic key, `PhoenixAdopter.MockTransport`, retries disabled, and telemetry disabled. In the Mox callback inspect the outgoing method/version header, return a synthetic Stripe-shaped JSON body, and assert the typed result. The required version can be passed per call (or explicitly on the client); keep the assertion that makes the version gate visible.

**Host test setup pattern** (`core_flow_test.exs` lines 1-15; `mix.exs` lines 18-24):

```elixir
defmodule PhoenixAdopter.CoreFlowTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest
  import Mox

  alias LatticeStripe.{Checkout.Session, Event, Webhook}

  @endpoint PhoenixAdopter.Endpoint
  setup :verify_on_exit!
end
```

Profile tests that only call the SDK need not import ConnTest or use the Phoenix endpoint; preserve `import Mox`, `setup :verify_on_exit!`, and the nested test helper's `PhoenixAdopter.MockTransport` module.

**Typed invoice request pattern** (`test/lattice_stripe/invoice_test.exs` lines 312-339):

```elixir
client = test_client(api_version: "2026-05-27.dahlia")

expect(LatticeStripe.MockTransport, :request, fn req ->
  stripe_version =
    Enum.find_value(req.headers, fn {key, value} ->
      if key == "stripe-version", do: value
    end)

  assert req.method == :get
  assert stripe_version == "2026-05-27.dahlia"
  ok_response(invoice_json(%{"amount_paid" => 300, "amount_paid_off_stripe" => 700}))
end)

assert {:ok, %Invoice{amount_paid: 300, amount_paid_off_stripe: 700}} =
         Invoice.retrieve(client, "in_test1234567890")
```

In the adopter, change only the transport module/client helper and fixture source as needed. Since the example uses the package test helper's `test_client/1`, the nested app must construct the equivalent client explicitly or add a small shared test helper if more than one profile needs it.

### `test_apps/phoenix_adopter/test/usage_reconciliation_profile_test.exs` (proposed; integration test, streaming + request-response)

**Analogs:** `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs`; `test/lattice_stripe/billing/meter_event_test.exs`

The host analog establishes the mock seam. The package pagination test is the closest behavior analog: define a deterministic two-page list response, assert page two's `starting_after`, enumerate `stream!/4`, and assert the complete typed sequence. Use the package's required customer and aligned time window shape. If adding the meter-event write contract, keep both `identifier` and HTTP `idempotency_key:` visible at the request boundary; these cover distinct duplicate boundaries.

**Cursor and typed-result pattern** (`meter_event_summary_pagination_test.exs` lines 92-111, 176-194):

```elixir
LatticeStripe.MockTransport
|> expect(:request, fn req ->
  refute Map.has_key?(query_params(req), "starting_after")
  summaries_response([summary("mtrusg_a"), summary("mtrusg_b")], true)
end)
|> expect(:request, fn req ->
  assert query_params(req)["starting_after"] == "mtrusg_b"
  summaries_response([summary("mtrusg_c")], false)
end)

summaries =
  test_client()
  |> MeterEventSummary.stream!(@meter_id, @bucketed_window)
  |> Enum.to_list()

assert [%MeterEventSummary{id: "mtrusg_a"},
        %MeterEventSummary{id: "mtrusg_b"},
        %MeterEventSummary{id: "mtrusg_c"}] = summaries
```

The pagination analog's response helper uses `list_json(items, url, has_more)` and `Jason.encode!/1` (lines 51-60); the nested app has no package `LatticeStripe.TestHelpers` import by default, so define a concise local response helper or use the host test's existing raw `%{status, headers, body}` response form. Do not hand-roll the cursor loop in adopter code.

**Dual idempotency sources** (`test/lattice_stripe/billing/meter_event_test.exs` lines 55-82; `test/lattice_stripe/client/request_building_test.exs` lines 172-182; research-supported `MeterEvent.create/3`):

```elixir
assert req.method == :post
assert String.ends_with?(req.url, "/v1/billing/meter_events")
assert req.body =~ "payload[value]=0.000001"

MeterEvent.create(client, %{
  "event_name" => "api_call",
  "payload" => %{"stripe_customer_id" => customer_id, "value" => "1"},
  "identifier" => event_identifier
}, idempotency_key: request_key)
```

The MeterEvent test demonstrates its POST/body seam; the request-building test demonstrates asserting an explicit HTTP idempotency header. Assert the MeterEvent body `identifier` and `idempotency-key` request header separately if this write is included. Keep the test about the SDK request contract; acceptance does not demonstrate a durable queue or settled usage.

### `test_apps/phoenix_adopter/test/connect_context_profile_test.exs` (proposed; integration test, request-response)

**Analogs:** `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test/lattice_stripe/balance_test.exs`; `test/lattice_stripe/client_stripe_account_header_test.exs`

Use one explicit platform client for sequential calls and vary the per-request `stripe_account:` option. The host test proves the selected transport seam; the Balance test covers the public typed API; the header regression test proves that per-request context wins and does not leak the client-level account value. Assert the exact header for each request and absence of the other account value.

**Typed Balance and account header pattern** (`balance_test.exs` lines 37-49):

```elixir
expect(LatticeStripe.MockTransport, :request, fn req_map ->
  assert req_map.method == :get
  assert String.ends_with?(req_map.url, "/v1/balance")
  assert {"stripe-account", "acct_123"} in req_map.headers
  ok_response(basic())
end)

assert {:ok, %Balance{}} = Balance.retrieve(client, stripe_account: "acct_123")
```

**No-bleed assertion pattern** (`client_stripe_account_header_test.exs` lines 47-58):

```elixir
client = test_client(stripe_account: "acct_client")

expect(LatticeStripe.MockTransport, :request, fn req_map ->
  assert {"stripe-account", "acct_request"} in req_map.headers
  refute {"stripe-account", "acct_client"} in req_map.headers
  ok_response()
end)

assert {:ok, _} = Client.request(client, get_req(stripe_account: "acct_request"))
```

For the adopter, prefer `Balance.retrieve/2` to prove routing on a real public resource call, and make two expectations with different connected-account IDs. A direct `Client.request/2` test is a useful package unit-test analog, but less complete as the adopter profile.

### `.github/workflows/ci.yml` (CI config, batch / verification)

**Analog:** `.github/workflows/ci.yml` lines 153-199 and 438-483

Add one job that checks out the repo and sets up Elixir 1.19 / OTP 28, then works from `test_apps/phoenix_adopter` to resolve its own lock and run the full suite. Keep the existing package matrix unchanged. The `ci-gate` job manually lists required jobs in both `needs` and its environment-variable/loop check; add the adopter job to each list or successful adopter checks will not be enforced by the aggregate gate.

**Focused single-toolchain gate pattern** (current `test` job lines 165-199):

```yaml
- elixir: '1.19'
  otp: '28'
...
- name: Tax adoption contract
  if: matrix.elixir == '1.19' && matrix.otp == '28'
  run: mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors
```

For the nested host, the research's intended command is `mix deps.get --check-locked` followed by `mix test --warnings-as-errors`, executed with `working-directory: test_apps/phoenix_adopter` (or an equivalent explicit `cd`). The checked-in nested `mix.lock` is the lock to resolve. No Stripe secret, live service, or production dataset belongs in job env.

### `test_apps/phoenix_adopter/README.md` (conditional doc update, documentation / discovery)

**Analog:** `test_apps/phoenix_adopter/README.md` lines 5-17

Preserve the existing short local command and synthetic-only explanation. If profiles receive focused filenames or tags, document those selectors and keep the full-suite command obvious. Align dependency resolution wording with CI's `--check-locked` command if appropriate.

```sh
cd test_apps/phoenix_adopter
mix deps.get
mix test
```

Existing documentation also calls out the checked-out `path: "../../"` dependency, isolated `mix.lock`, mock transport, raw-body webhook verification, and the fact that synthetic webhook receipt is not durable processing. Extend this README rather than creating a competing guide unless planning identifies a concrete discovery gap.

## Shared Patterns

### Explicit synthetic client and mock transport

**Sources:** `test_apps/phoenix_adopter/lib/phoenix_adopter.ex` lines 26-33; `test_apps/phoenix_adopter/test/test_helper.exs` lines 1-3; `test/support/test_helpers.ex` lines 6-16.

Every profile should call the public API with an explicit client configured with the synthetic `sk_test_...` key, `PhoenixAdopter.MockTransport`, `max_retries: 0`, and telemetry disabled. `PhoenixAdopter.MockTransport` implements `LatticeStripe.Transport`; use `expect/3` to inspect request method, URL, relevant headers/body, and return synthetic Stripe-shaped response bytes. The package helper's exact constructor is:

```elixir
defaults = [
  api_key: "sk_test_123",
  finch: :test_finch,
  transport: LatticeStripe.MockTransport,
  telemetry_enabled: false,
  max_retries: 0
]

Client.new!(Keyword.merge(defaults, overrides))
```

The adopter can mirror these defaults with its own mock. Do not fall back to global mutable client config or live HTTP.

### Structured SDK errors

**Sources:** `test/lattice_stripe/checkout/session_test.exs` lines 111-120; `test/support/test_helpers.ex` lines 40-53.

Return a controlled 400 from the Mox expectation and assert `{:error, %LatticeStripe.Error{type: :invalid_request_error, status: 400}}` from the selected non-bang public call. At host level, keep controller-level mapping separate from the SDK error contract; the existing `/checkout` controller translates an SDK error to 502 at `test_apps/phoenix_adopter/lib/phoenix_adopter.ex` lines 42-50.

### Existing webhook proof

**Source:** `test_apps/phoenix_adopter/test/core_flow_test.exs` lines 75-101.

The signed valid and tampered raw-body webhook cases already live in the host spine. Keep using `LatticeStripe.Webhook.generate_test_signature/2` and send the unchanged raw payload to the actual `/webhooks/stripe` endpoint. Avoid duplicating HMAC code or making the three SDK profile files re-prove webhook delivery.

## No Analog Found

| File / Area | Reason |
|---|---|
| New Phoenix host routes/controllers for invoice, usage, or Connect | No such host routes are implied or required. The profiles can call the SDK directly through the established transport seam; add host endpoints only if planning finds a concrete host-boundary requirement. |

## Metadata

**Analog search scope:** `test_apps/phoenix_adopter/`, `test/lattice_stripe/{invoice_test.exs,balance_test.exs,client_stripe_account_header_test.exs,client/request_building_test.exs,checkout/session_test.exs,billing/meter_event_test.exs,billing/meter_event_summary_pagination_test.exs}`, `test/support/test_helpers.ex`, and `.github/workflows/ci.yml`.  
**Tracked-source gate:** All named analog source paths are tracked.  
**Files scanned:** 10 strong analogs / guidance files.  
**Pattern extraction date:** 2026-09-24.
