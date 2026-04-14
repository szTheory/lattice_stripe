# Phase 21: Customer Portal — Research

**Researched:** 2026-04-14
**Domain:** Stripe BillingPortal.Session, Elixir SDK nested-struct pattern, client-side flow validation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — Flow-type validation architecture**
New `LatticeStripe.BillingPortal.Guards` module at `lib/lattice_stripe/billing_portal/guards.ex` with `@moduledoc false`. Single public function `check_flow_data!/1`. Pattern-match function-head clauses on private `check_flow!/1` — one happy-path clause per flow type, one missing-field clause per type raising with a type-specific message, a `when is_binary(type)` catchall for unknown strings, and a final catchall for malformed `flow_data`. Full implementation provided verbatim in CONTEXT.md D-01. Call site: after `Resource.require_param!(params, "customer", ...)` and before `Resource.request/6`. Reads string keys only (Stripe wire format). Atom-keyed params bypass guard intentionally.

**D-02 — FlowData nested-struct shape: 5-module polymorphic-flat layout**
Module tree under `lib/lattice_stripe/billing_portal/session/flow_data/`:
1. `flow_data.ex` — parent `FlowData`, fields: `:type`, `:after_completion`, `:subscription_cancel`, `:subscription_update`, `:subscription_update_confirm`, `:extra`
2. `flow_data/after_completion.ex` — fields: `:type`, `:redirect` (raw map), `:hosted_confirmation` (raw map), `:extra`
3. `flow_data/subscription_cancel.ex` — fields: `:subscription`, `:retention` (raw map), `:extra`
4. `flow_data/subscription_update.ex` — fields: `:subscription`, `:extra`
5. `flow_data/subscription_update_confirm.ex` — fields: `:subscription`, `:items` (list of raw maps), `:discounts` (list of raw maps), `:extra`
No module for `payment_method_update` — zero extra fields. Shallow leaf sub-fields (retention, items, discounts, redirect, hosted_confirmation) stay as raw maps. Full FlowData sketch provided verbatim in CONTEXT.md D-02.

**D-03 — BillingPortal.Session Inspect allowlist**
Allowlist `defimpl Inspect` using `Inspect.Algebra`. Visible fields (exact order): `id`, `object`, `livemode`, `customer`, `configuration`, `on_behalf_of`, `created`, `return_url`, `locale`. Hidden fields: `url`, `flow`. Full implementation provided verbatim in CONTEXT.md D-03.

**D-04 — Guide envelope for `guides/customer-portal.md`**
MODERATE envelope: 240 lines ± 40, 7 H2 sections. Bundle guide into the resource-landing plan (21-03 in the v1.1 brief). ExDoc registration: add `guides/customer-portal.md` to `extras` (alphabetically near `connect-money-movement.md`), add `"Customer Portal"` group to `groups_for_modules` with 6 modules (Session, FlowData, AfterCompletion, SubscriptionCancel, SubscriptionUpdate, SubscriptionUpdateConfirm). Guards has `@moduledoc false`, not in any group. H2 outline binding: 7 sections — "What the Customer Portal is", "Quickstart", "Deep-link flows" (4 H3 subsections), "End-to-end Phoenix example", "Security and session lifetime", "Common pitfalls", "See also".

### Claude's Discretion

- **D. Plan breakdown (3 vs 4 plans)** — gsd-plan-phase decides based on resource-plan weight after research. Start from 4-plan sketch (Wave 0 bootstrap / FlowData nested structs / resource module + guard / integration tests + guide). D-04 commits to bundling guide with resource plan (21-03) as default; split only if 21-03 is already heavy.
- **F. `configuration` param type handling** — accept `binary()` (Stripe `bpc_*` configuration ID) as documented type; do NOT write a pre-flight guard for it (Stripe's 400 is clear enough). Document in moduledoc that portal configuration is managed via Stripe dashboard in v1.1 (locked v1.1 D4).

### Deferred Ideas (OUT OF SCOPE)

- `BillingPortal.Configuration` CRUDL — locked v1.1 D4; defer to v1.2+
- Session retrieve/list/update/delete — Stripe API does not expose
- Release-cut phase — zero-touch via release-please (last `feat:` commit of Phase 21 auto-ships v1.1.0)
- Atom normalization of `flow_data.type` on ingress — Phase 20 D-06 (string-keyed wire format only)
- Function-head atom guards on `flow_data.type` in `Session.create/3` — Phase 17 D-04c forbids for nested-in-map string-valued keys
- NimbleOptions schema validation of `flow_data` — Phase 19 D-16, Phase 20 D-01 rejected
- Typed sub-modules for shallow leaf objects (AfterCompletion.redirect, SubscriptionCancel.retention, SubscriptionUpdateConfirm.items/discounts)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PORTAL-01 | `BillingPortal.Session.create/3` with required `customer`, optional `return_url`, `configuration`, `locale`, `flow_data`, `on_behalf_of`; returns `%Session{url: url}` | Stripe API confirmed; stripe-mock returns 200 with `url` field |
| PORTAL-02 | `create!/3` bang variant; no retrieve/list/update/delete | Stripe API create-only confirmed |
| PORTAL-03 | `flow_data` decoded into `FlowData` typed struct with `@known_fields + :extra` | 5-module tree design confirmed in D-02; matches Phase 20 Meter pattern |
| PORTAL-04 | `Session.create/3` validates `flow_data.type` client-side raising `ArgumentError` before network call | `BillingPortal.Guards.check_flow_data!/1` pattern confirmed; stripe-mock does NOT enforce missing sub-fields (returns 200 even without `subscription_cancel.subscription`) |
| PORTAL-05 | Session struct: `id`, `object`, `customer`, `url`, `return_url`, `created`, `livemode`, `locale`, `configuration`, `flow` | All fields confirmed present in stripe-mock response |
| PORTAL-06 | Honors `stripe_account:` opt for Connect | Standard opts threading confirmed via `MeterEvent` precedent |
| TEST-02 | `test/support/fixtures/billing_portal.ex` with canonical Session fixture + one FlowData shape per flow type | Pattern confirmed from `metering.ex`; 4 flow-type shapes needed |
| TEST-04 | Wave 0 stripe-mock probe for `/v1/billing_portal/sessions` | Live probe confirmed: 200 with `customer` param; `unknown_type` → 422 with validation error; missing `customer` → 422; missing `subscription_cancel.subscription` → 200 (stripe-mock does NOT enforce sub-field validation) |
| TEST-05 (portal) | `:integration`-tagged full portal flow test against stripe-mock | Pattern confirmed from checkout_session_integration_test.exs |
| DOCS-02 | `guides/customer-portal.md` with Accrue-style example covering all four flow types | D-04 envelope locked at 240 lines / 7 H2 |
| DOCS-03 (portal) | `mix.exs` `groups_for_modules` gains `"Customer Portal"` group; guide added to `extras` | mix.exs already has `"Billing Metering"` group as template |
</phase_requirements>

---

## Summary

Phase 21 ships `LatticeStripe.BillingPortal.Session` — a create-only resource wrapping Stripe's `/v1/billing_portal/sessions` endpoint. The implementation is structurally simple: one resource module, five nested-struct modules under `FlowData.*`, one guard module, one guide. Every pattern needed — nested structs, Inspect masking, guard modules, integration test setup — has an exact template in the codebase from Phase 20.

The critical finding that shapes testing strategy: **stripe-mock does NOT enforce `flow_data` sub-field validation**. A request with `flow_data.type = "subscription_cancel"` but no `subscription_cancel.subscription` key returns HTTP 200. Only an unknown `flow_data.type` value triggers a stripe-mock 422. This means the D-01 guard is the only mechanism that catches missing sub-fields — unit tests against `BillingPortal.Guards` are the sole test surface for those 8 cases (guard matrix from D-01). Integration tests verify the happy path and struct decoding only.

The implementation has zero new dependencies, zero new patterns to invent. Everything is a port of Phase 20 idioms into the `BillingPortal.*` namespace.

**Primary recommendation:** Follow the 4-plan sketch from the v1.1 brief verbatim — Wave 0 bootstrap, FlowData nested structs, Session resource + Guards + guide (bundled), integration test. All code templates are in CONTEXT.md D-01 through D-04.

---

## Standard Stack

No new dependencies. Phase 21 uses the existing v1.0/v1.1 stack unchanged.

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| Finch | ~> 0.21 | HTTP transport (via `LatticeStripe.Transport.Finch`) | [VERIFIED: existing mix.exs] |
| Jason | ~> 1.4 | JSON decode of Stripe response | [VERIFIED: existing mix.exs] |
| :telemetry | ~> 1.0 | Request span events (via existing `LatticeStripe.Telemetry`) | [VERIFIED: existing mix.exs] |
| ExUnit | stdlib | Test framework | [VERIFIED: existing test suite] |
| Mox | ~> 1.2 | Transport mock for unit tests | [VERIFIED: existing mix.exs] |
| ExDoc | ~> 0.34 | Documentation | [VERIFIED: existing mix.exs] |

**Installation:** None required. No `mix deps.get` needed for Phase 21.

---

## Architecture Patterns

### File Layout

```
lib/lattice_stripe/
  billing_portal/              # NEW — directory does not exist yet
    guards.ex                  # LatticeStripe.BillingPortal.Guards (@moduledoc false)
    session/
      flow_data/
        after_completion.ex    # LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion
        subscription_cancel.ex # LatticeStripe.BillingPortal.Session.FlowData.SubscriptionCancel
        subscription_update.ex # LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdate
        subscription_update_confirm.ex
      flow_data.ex             # LatticeStripe.BillingPortal.Session.FlowData (parent)
    session.ex                 # LatticeStripe.BillingPortal.Session (resource + defimpl Inspect)

test/
  lattice_stripe/
    billing_portal/
      session_test.exs         # unit tests: guard matrix, Inspect masking, from_map decoding
  integration/
    billing_portal_session_integration_test.exs  # :integration tagged
  support/
    fixtures/
      billing_portal.ex        # LatticeStripe.Test.Fixtures.BillingPortal
```

**Note:** `lib/lattice_stripe/billing_portal/` does not exist yet — the entire directory tree is new. [VERIFIED: `ls lib/lattice_stripe/billing_portal/ 2>/dev/null || echo "DIRECTORY DOES NOT EXIST"` confirmed.]

### Pattern 1: Resource Module (Session.create/3)

Mirrors `LatticeStripe.Billing.MeterEventAdjustment` exactly — required param guard → domain guard → `Resource.request/6` → `Resource.unwrap_singular/2`.

```elixir
# Source: lib/lattice_stripe/billing/meter_event_adjustment.ex (lines 43-56)
def create(%Client{} = client, params, opts \\ []) when is_map(params) do
  Resource.require_param!(params, "customer",
    "LatticeStripe.BillingPortal.Session.create/3 requires a customer param")

  BillingPortal.Guards.check_flow_data!(params)

  %Request{method: :post, path: "/v1/billing_portal/sessions", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Pattern 2: Nested Struct Module (FlowData sub-modules)

Template from `lib/lattice_stripe/billing/meter/customer_mapping.ex` — applies to all 4 FlowData sub-modules.

```elixir
# Source: lib/lattice_stripe/billing/meter/customer_mapping.ex
@known_fields ~w(event_payload_key type)

@type t :: %__MODULE__{
        event_payload_key: String.t() | nil,
        type: String.t() | nil,
        extra: map()
      }
defstruct [:event_payload_key, :type, extra: %{}]

@spec from_map(map() | nil) :: t() | nil
def from_map(nil), do: nil

def from_map(map) when is_map(map) do
  %__MODULE__{
    event_payload_key: map["event_payload_key"],
    type: map["type"],
    extra: Map.drop(map, @known_fields)
  }
end
```

The `FlowData` parent struct is more complex (4 sub-module delegations in `from_map/1`). Full sketch is in CONTEXT.md D-02.

### Pattern 3: Guards Module

Template from `lib/lattice_stripe/billing/guards.ex` — specifically `check_adjustment_cancel_shape!/1` (GUARD-03 pattern-match style, lines 153-171). Full `BillingPortal.Guards` implementation is in CONTEXT.md D-01 verbatim. Key elements:
- `@moduledoc false`
- `@fn_name` module attribute for consistent error messages
- Pattern-match function heads on `check_flow!/1` (private)
- `when is_binary(type)` catchall ensures unknown strings never pass silently
- Binary catchall matches the `check_adjustment_cancel_shape!/1` idiom exactly

### Pattern 4: Inspect Protocol Masking

Template from `lib/lattice_stripe/billing/meter_event.ex` (lines 103-133). Full `defimpl Inspect` for Session is in CONTEXT.md D-03 verbatim. Key notes:
- `import Inspect.Algebra`
- Hardcoded visible-field list (keyword list, not struct fields)
- `Enum.map/2` + `concat/1` + `Enum.intersperse/2` for comma-separated output
- `#LatticeStripe.BillingPortal.Session<...>` angle-bracket delimiters
- **Checkout.Session already hides `:url`** in its own Inspect impl (lib/lattice_stripe/checkout/session.ex:658-684) — established SDK invariant

### Pattern 5: Fixture Module

Template from `test/support/fixtures/metering.ex` — `LatticeStripe.Test.Fixtures.Metering` with nested submodules. Phase 21 creates `LatticeStripe.Test.Fixtures.BillingPortal` following the same shape.

```elixir
# Source: test/support/fixtures/metering.ex (overall structure)
defmodule LatticeStripe.Test.Fixtures.BillingPortal do
  @moduledoc false

  defmodule Session do
    @moduledoc false

    def basic(overrides \\ %{}) do
      %{
        "id" => "bps_123",
        "object" => "billing_portal.session",
        "customer" => "cus_test123",
        "url" => "https://billing.stripe.com/session/test_token",
        "return_url" => "https://example.com/account",
        "configuration" => "bpc_123",
        "on_behalf_of" => nil,
        "locale" => nil,
        "created" => 1_712_345_678,
        "livemode" => false,
        "flow" => nil
      }
      |> Map.merge(overrides)
    end

    # One fixture per flow type (TEST-02 requirement)
    def with_subscription_cancel_flow(overrides \\ %{}) do
      basic(%{
        "flow" => %{
          "type" => "subscription_cancel",
          "subscription_cancel" => %{"subscription" => "sub_123", "retention" => nil},
          "subscription_update" => nil,
          "subscription_update_confirm" => nil,
          "after_completion" => %{"type" => "portal_homepage"}
        }
      })
      |> Map.merge(overrides)
    end
    # ... similar for subscription_update, subscription_update_confirm, payment_method_update
  end
end
```

### Pattern 6: Integration Test Setup

Template from `test/integration/checkout_session_integration_test.exs` (lines 1-84):
- `@moduletag :integration`
- `use ExUnit.Case, async: false`
- `import LatticeStripe.TestHelpers`
- `setup_all` probes `localhost:12111` with `:gen_tcp.connect/4` — raises if stripe-mock not running
- `setup` block yields `{:ok, client: test_integration_client()}`
- `test_integration_client()` already wired in `test/support/test_helpers.ex`

### Pattern 7: Wave 0 Probe Script

Template from `scripts/verify_meter_endpoints.exs` — uses `:httpc` (Erlang stdlib), not `LatticeStripe.Client` (which requires a named Finch pool). Phase 21 probe script covers one endpoint: `POST /v1/billing_portal/sessions`.

### Anti-Patterns to Avoid

- **Using `LatticeStripe.Client.new!/1` in probe scripts** — requires a started Finch pool; use `:httpc` instead (established by Plan 20-01 deviation record)
- **Using `LatticeStripe.Fixtures.BillingPortal` namespace** — existing convention is `LatticeStripe.Test.Fixtures.*` (Phase 20 deviation record)
- **`cond` dispatch in Guards** — use pattern-match function heads (D-01 rationale); `cond` gives weaker stack traces
- **Extending `Billing.Guards`** — `BillingPortal.*` is a separate Stripe namespace from `Billing.*`; create new `BillingPortal.Guards` module
- **Typing `flow_data` params as atoms** — Phase 20 D-06: string-keyed wire format only; atom-keyed params bypass guards
- **Promoting shallow leaf objects** — `retention`, `items`, `discounts`, `redirect`, `hosted_confirmation` stay as `map() | [map()]`

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Required param validation | Custom nil check in `create/3` body | `Resource.require_param!/3` | Already exists at `lib/lattice_stripe/resource.ex:118`; raises `ArgumentError` |
| Response unwrapping | Manual `{:ok, from_map(resp.data)}` | `Resource.unwrap_singular/2` | Handles `{:error, %Error{}}` passthrough cleanly |
| Bang variant | Manual `case` on `create/3` result | `Resource.unwrap_bang!/1` | One-liner: `client |> create(params, opts) |> Resource.unwrap_bang!()` |
| HTTP request building | Manual Finch call | `%Request{} |> Client.request/2` | Handles headers, retries, telemetry, stripe_account, idempotency_key |
| Inspect masking | `IO.inspect(..., except: [:url])` | `defimpl Inspect` allowlist | `except:` option doesn't exist; allowlist is the only safe pattern |
| JSON encode/decode | Manual Jason calls | Built into Transport layer | Codec is injected, not called by resource modules |

---

## Stripe API Surface (Verified)

### POST /v1/billing_portal/sessions

**Endpoint:** `/v1/billing_portal/sessions`
**Method:** POST
[VERIFIED: stripe-mock probe returning 200]

**Required params:**
- `customer` (string) — Stripe enforces this; stripe-mock returns 422 if absent [VERIFIED: live probe]

**Optional params:**
- `configuration` (string, `bpc_*`) — portal configuration ID
- `locale` (string) — IETF language tag or `"auto"`
- `on_behalf_of` (string, `acct_*`) — Connect platform account
- `return_url` (string) — where to redirect after portal
- `flow_data` (object) — deep-link to specific flow

**`flow_data` structure:**

| `flow_data.type` | Required sub-object | Required sub-fields |
|-----------------|--------------------|--------------------|
| `"payment_method_update"` | none | none |
| `"subscription_cancel"` | `subscription_cancel` | `.subscription` (string) |
| `"subscription_update"` | `subscription_update` | `.subscription` (string) |
| `"subscription_update_confirm"` | `subscription_update_confirm` | `.subscription` (string) AND `.items` (non-empty array) |

[CITED: docs.stripe.com/api/customer_portal/sessions/create]

**`flow_data.after_completion`** (optional, applicable to all flow types):
- `type` (enum): `"hosted_confirmation"`, `"portal_homepage"`, or `"redirect"`
- `redirect.return_url` (string, required if type is `"redirect"`)
- `hosted_confirmation.custom_message` (string, optional)

**Session response object fields** (from live stripe-mock probe):
- `id` — `"bps_*"` prefix
- `object` — `"billing_portal.session"`
- `customer` — echoed back
- `configuration` — `"bpc_*"` ID
- `url` — single-use portal URL (format: `https://*.stripe.me/session/{SESSION_SECRET}`)
- `return_url` — echoed back
- `created` — unix timestamp
- `livemode` — boolean
- `locale` — null or locale string
- `on_behalf_of` — null or `acct_*`
- `flow` — echoed `flow` object (same structure as input `flow_data`, with `type` + all four branch keys populated by stripe-mock regardless of type)

[VERIFIED: live stripe-mock probe with `customer=cus_test123`]

---

## Critical stripe-mock Behavior Findings

These findings directly shape the testing architecture:

### Finding 1: stripe-mock does NOT enforce flow_data sub-field validation
[VERIFIED: live probe]

`POST /v1/billing_portal/sessions` with `flow_data[type]=subscription_cancel` but NO `subscription_cancel.subscription` returns **HTTP 200** (not 422). stripe-mock returns a stub response with fabricated `subscription_cancel.subscription = "subscription"` regardless of input.

**Consequence for TEST-04:** The Wave 0 probe confirms the endpoint exists but documents that sub-field validation is NOT testable via stripe-mock. The PORTAL-04 guard matrix (10 cases from D-01) MUST be exercised via unit tests against `BillingPortal.Guards.check_flow_data!/1` in isolation — not via integration tests.

### Finding 2: stripe-mock DOES enforce unknown flow_data.type
[VERIFIED: live probe]

`flow_data[type]=unknown_type` → HTTP 422 with `"value is not in enumeration"` error. This means the "unknown type" guard (D-01 line 116-121) can be validated via either unit test OR integration test. Unit test is preferred (faster, no network).

### Finding 3: stripe-mock enforces customer as required
[VERIFIED: live probe]

No `customer` param → HTTP 422 with `"object property 'customer' is required"`. The `Resource.require_param!` guard for `customer` is redundant with stripe-mock behavior but is still the correct SDK posture (pre-network raise, not a Stripe 422 surfaced as `{:error, %Error{}}`).

### Finding 4: stripe-mock url field shape
[VERIFIED: live probe]

`url` value: `"https://sangeekp-15t6ai--customer_portal-mydev.dev.stripe.me/session/{SESSION_SECRET}"` — a non-empty string. Integration test success criterion "returned `url` is a non-empty string" is satisfied. The `{SESSION_SECRET}` placeholder is stripe-mock's pattern.

### Finding 5: stripe-mock flow response shape
[VERIFIED: live probe]

stripe-mock always returns all four flow branch keys populated regardless of `flow_data.type`. This means `from_map/1` on the `flow` field will always receive a fully-populated map in integration tests; the `nil` branch of each sub-struct `from_map/1` will only be exercised in unit tests with sparse fixtures.

---

## Validation Architecture

**Framework:** ExUnit (stdlib)
**Config file:** `test/test_helper.exs`
**Quick run command:** `mix test --stale`
**Full suite command:** `mix test`
**Integration run:** `mix test --include integration`

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File |
|--------|----------|-----------|-------------------|------|
| PORTAL-01 | `create/3` returns `{:ok, %Session{url: url}}` | integration | `mix test test/integration/billing_portal_session_integration_test.exs --include integration` | Wave 0 creates skeleton |
| PORTAL-02 | `create!/3` raises on error | unit | `mix test test/lattice_stripe/billing_portal/session_test.exs` | Wave 0 creates skeleton |
| PORTAL-03 | `FlowData.from_map/1` decodes all 4 flow types correctly | unit | `mix test test/lattice_stripe/billing_portal/session_test.exs` | Wave 0 creates skeleton |
| PORTAL-04 | Guard matrix: 10 cases, ArgumentError before network call | unit | `mix test test/lattice_stripe/billing_portal/session_test.exs` | Wave 0 creates skeleton |
| PORTAL-05 | Session struct field decoding | unit | `mix test test/lattice_stripe/billing_portal/session_test.exs` | Wave 0 creates skeleton |
| PORTAL-06 | `stripe_account:` opt threads through | unit (Mox) | `mix test test/lattice_stripe/billing_portal/session_test.exs` | Wave 0 creates skeleton |
| TEST-02 | Fixture module exists with 4 FlowData shapes | unit | `mix test test/lattice_stripe/billing_portal/session_test.exs` | Plan 21-01 creates |
| TEST-04 | stripe-mock probe documents sub-field validation gap | probe script | `elixir scripts/verify_portal_endpoint.exs` | Plan 21-01 creates |
| TEST-05 (portal) | Full portal flow integration test | integration | `mix test test/integration/billing_portal_session_integration_test.exs --include integration` | Plan 21-01 skeleton, Plan 21-03 fills |
| DOCS-02 | `guides/customer-portal.md` exists | `mix docs` | `mix docs --warnings-as-errors` | Plan 21-03 creates |
| DOCS-03 (portal) | `mix.exs` groups_for_modules has "Customer Portal" | `mix docs` | `mix docs --warnings-as-errors` | Plan 21-03 updates |

### Sampling Rate

- **Per task commit:** `mix test --stale`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green + `mix docs` + `mix credo --strict` + `mix deps.audit` before `/gsd-verify-work`

### Wave 0 Gaps

The following files do not exist and must be created in Plan 21-01:
- [ ] `test/support/fixtures/billing_portal.ex` — covers TEST-02
- [ ] `test/lattice_stripe/billing_portal/session_test.exs` — covers PORTAL-01..06 unit cases
- [ ] `test/integration/billing_portal_session_integration_test.exs` — covers TEST-05 portal
- [ ] `scripts/verify_portal_endpoint.exs` — covers TEST-04 probe

---

## Common Pitfalls

### Pitfall 1: stripe-mock sub-field validation gap
**What goes wrong:** Integration test passes with `flow_data.type = "subscription_cancel"` but no `subscription_cancel.subscription` — stripe-mock returns 200. Developer concludes the guard is working but has not actually exercised the guard path.
**Why it happens:** stripe-mock is OpenAPI-spec-based but does not enforce `flow_data` sub-field conditionals (confirmed via live probe).
**How to avoid:** Put all 10 guard matrix cases in unit tests against `BillingPortal.Guards` directly, not behind `Session.create/3` with the integration client.
**Warning signs:** Integration tests cover guard behavior; no dedicated unit test file for `BillingPortal.Guards`.

### Pitfall 2: Namespace collision with `Billing.Guards`
**What goes wrong:** Guard function added to `LatticeStripe.Billing.Guards` instead of a new `LatticeStripe.BillingPortal.Guards`.
**Why it happens:** "billing" prefix in module name looks like a match.
**How to avoid:** `Billing.*` and `BillingPortal.*` are unrelated Stripe surfaces. Phase 20 D-01 is explicit: guards live alongside their resource namespace.
**Warning signs:** `lib/lattice_stripe/billing/guards.ex` has a `check_flow_data!/1` function.

### Pitfall 3: `from_map/1` on `flow` field vs `flow_data` params
**What goes wrong:** Confusing the outgoing `flow_data` (raw string-keyed map that users pass IN to `create/3`) with the incoming `flow` (the Stripe-echoed response field that `from_map/1` decodes into `%FlowData{}`).
**Why it happens:** Stripe uses `flow_data` as the param name but `flow` in the response object.
**How to avoid:** `Session.from_map/1` reads `map["flow"]` (not `map["flow_data"]`). There is NO encode path for `%FlowData{}` → params. String keys only in both directions.
**Warning signs:** `flow_data.ex` has a `to_params/1` function.

### Pitfall 4: Inspect test asserting `"url:"` instead of actual URL value
**What goes wrong:** `refute inspect(session) =~ "url:"` passes even if the URL value leaks but the key label is absent.
**Why it happens:** Weak assertion tests for the label, not the credential.
**How to avoid:** Use `refute inspect(session) =~ session.url` — asserts the actual URL value is not present anywhere in the output. Sourced from D-03 test spec.
**Warning signs:** Inspect test uses `=~ "url:"` rather than `=~ session.url`.

### Pitfall 5: `BillingPortal.Guards` in `groups_for_modules`
**What goes wrong:** `LatticeStripe.BillingPortal.Guards` appears in the `"Customer Portal"` ExDoc group.
**Why it happens:** Guards module lives in `billing_portal/` directory, looks like it should be in the group.
**How to avoid:** `@moduledoc false` modules are excluded from ExDoc. Explicitly do NOT list `BillingPortal.Guards` in `groups_for_modules`. Matches `LatticeStripe.Billing.Guards` which sits in the `Internals` group.
**Warning signs:** `groups_for_modules` `"Customer Portal"` entry contains `LatticeStripe.BillingPortal.Guards`.

### Pitfall 6: Empty `items` list passing the guard
**What goes wrong:** `subscription_update_confirm` guard accepts `items: []` as valid.
**Why it happens:** `is_list([])` is true; naive check misses the non-empty constraint.
**How to avoid:** Guard clause uses `is_list(i) and i != []` (not `length(i) > 0`). This is explicitly specified in D-01 clause 8 and avoids unnecessary traversal.
**Warning signs:** Guard clause 8 uses `is_list(i)` without the `i != []` conjunction.

---

## Code Examples

### Resource.require_param!/3 (existing utility)

```elixir
# Source: lib/lattice_stripe/resource.ex:118-124
@spec require_param!(map(), String.t(), String.t()) :: :ok
def require_param!(params, key, message) do
  unless Map.has_key?(params, key) do
    raise ArgumentError, message
  end
  :ok
end
```

### Guards module GUARD-03 pattern (template for BillingPortal.Guards)

```elixir
# Source: lib/lattice_stripe/billing/guards.ex:153-171
@spec check_adjustment_cancel_shape!(map()) :: :ok
def check_adjustment_cancel_shape!(%{"cancel" => %{"identifier" => id}})
    when is_binary(id) and byte_size(id) > 0,
    do: :ok

def check_adjustment_cancel_shape!(%{"cancel" => cancel}) do
  raise ArgumentError,
        ~s[LatticeStripe.Billing.MeterEventAdjustment.create/3: `cancel` must be ] <>
          ~s[a map shaped %{"identifier" => "<meter_event_identifier>"}, got: ] <>
          "#{inspect(cancel)}. ..."
end

def check_adjustment_cancel_shape!(params) do
  raise ArgumentError,
        ~s[LatticeStripe.Billing.MeterEventAdjustment.create/3: missing `cancel` ] <>
          ~s[sub-object. Expected %{"cancel" => %{"identifier" => "..."}}, ] <>
          "got: #{inspect(params)}"
end
```

### Inspect Protocol masking (MeterEvent template)

```elixir
# Source: lib/lattice_stripe/billing/meter_event.ex:103-133
defimpl Inspect, for: LatticeStripe.Billing.MeterEvent do
  import Inspect.Algebra

  def inspect(event, opts) do
    fields = [
      event_name: event.event_name,
      identifier: event.identifier,
      timestamp: event.timestamp,
      created: event.created,
      livemode: event.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Billing.MeterEvent<" | pairs] ++ [">"])
  end
end
```

### Integration test setup (checkout_session template)

```elixir
# Source: test/integration/checkout_session_integration_test.exs:1-26
defmodule LatticeStripe.Checkout.SessionIntegrationTest do
  use ExUnit.Case, async: false
  import LatticeStripe.TestHelpers
  @moduletag :integration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok
      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 ..."
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end
end
```

### mix.exs groups_for_modules pattern (existing "Billing Metering" as template)

```elixir
# Source: mix.exs:86-95
"Billing Metering": [
  LatticeStripe.Billing.Meter,
  LatticeStripe.Billing.Meter.DefaultAggregation,
  LatticeStripe.Billing.Meter.CustomerMapping,
  LatticeStripe.Billing.Meter.ValueSettings,
  LatticeStripe.Billing.Meter.StatusTransitions,
  LatticeStripe.Billing.MeterEvent,
  LatticeStripe.Billing.MeterEventAdjustment,
  LatticeStripe.Billing.MeterEventAdjustment.Cancel
],
# Phase 21 adds after this:
"Customer Portal": [
  LatticeStripe.BillingPortal.Session,
  LatticeStripe.BillingPortal.Session.FlowData,
  LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion,
  LatticeStripe.BillingPortal.Session.FlowData.SubscriptionCancel,
  LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdate,
  LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdateConfirm
],
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stripe-mock on port 12111 | Integration tests, Wave 0 probe | Currently running | unknown | Run: `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` |
| Elixir | All | Yes | (existing project) | — |
| Docker (for stripe-mock) | CI integration tests | [ASSUMED] | — | Local `mix run` with stripe-mock binary |

[VERIFIED: stripe-mock confirmed running on localhost:12111 via live probe returning 200]

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| stripity_stripe: flat raw maps for all sub-objects | LatticeStripe: typed nested structs with `@known_fields + :extra` | Atom dot-access (`session.flow.subscription_cancel.subscription`) vs string bracket access |
| stripity_stripe: zero client-side flow validation | LatticeStripe: `BillingPortal.Guards.check_flow_data!/1` raises before network call | Missing sub-fields caught at SDK boundary with actionable message |
| Checkout.Session `url` not hidden (pre-Phase 17) | All session URLs hidden in Inspect by default | SDK invariant: "Stripe session URLs are uniformly masked" |

---

## Integration Points (mix.exs changes)

1. **`extras` list** — add `"guides/customer-portal.md"` after `"guides/connect-money-movement.md"` (alphabetical)
   [VERIFIED: mix.exs:23-41 inspected; current list is in alphabetical order]

2. **`groups_for_modules`** — add `"Customer Portal"` group with 6 modules after the `"Billing Metering"` group
   [VERIFIED: mix.exs:86-95 inspected; "Billing Metering" is the direct predecessor]

3. **`lib/lattice_stripe.ex` moduledoc** — add `BillingPortal.Session` to the `## Modules` bullet list
   [VERIFIED: lib/lattice_stripe.ex:31-40 inspected; existing list does NOT include billing metering modules yet — Phase 20 may have updated this, but DOCS-04 is a Phase 20 requirement; Phase 21 adds the portal entry]

4. **`guides/subscriptions.md`** — add "See also" cross-links in §Lifecycle and §Proration sections pointing to `guides/customer-portal.md`

5. **`guides/webhooks.md`** — add pointer to `guides/customer-portal.md` §Security section

---

## Open Questions

1. **Phase 20 DOCS-04 completion status**
   - What we know: DOCS-04 requires adding billing metering modules to `LatticeStripe` moduledoc resource index. Phase 20 is marked complete.
   - What's unclear: Whether `lib/lattice_stripe.ex` moduledoc was updated by Phase 20 to include `Billing.Meter` / `Billing.MeterEvent`. The read showed the old v1.0 module list.
   - Recommendation: Plan 21-03 task reads `lib/lattice_stripe.ex` before editing. If Billing Metering entries are present (Phase 20 landed them), add Portal entry after them. If absent (Phase 20 skipped it), add both sets.

2. **`guides/customer-portal.md` insertion position in `extras` list**
   - What we know: alphabetical ordering; current list has `connect-money-movement.md` followed by `webhooks.md`.
   - What's unclear: "customer-portal" sorts after "connect-money-movement" (c-o-n-n vs c-u-s) and before "error-handling" (c vs e).
   - Recommendation: Insert `"guides/customer-portal.md"` after `"guides/connect-money-movement.md"` and before `"guides/error-handling.md"`.

3. **Wave 0 probe script naming**
   - What we know: Phase 20 uses `scripts/verify_meter_endpoints.exs`. Phase 21 needs a similar script for `/v1/billing_portal/sessions`.
   - What's unclear: Whether to name it `verify_portal_endpoint.exs` or `verify_billing_portal_sessions.exs`.
   - Recommendation: `scripts/verify_billing_portal_endpoint.exs` — parallel to Phase 20's `verify_meter_endpoints.exs` naming convention.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Docker is available in the CI environment for stripe-mock | Environment Availability | Integration tests don't run in CI; flag for user if Docker absent |
| A2 | `lib/lattice_stripe.ex` moduledoc was updated by Phase 20 to include Billing Metering modules | Integration Points #3 | Plan 21-03 must read the file before editing — no structural risk |

---

## Sources

### Primary (HIGH confidence)

- `lib/lattice_stripe/billing/guards.ex` — GUARD-03 pattern-match template [VERIFIED: read in full]
- `lib/lattice_stripe/billing/meter_event.ex` — Inspect masking template [VERIFIED: read in full]
- `lib/lattice_stripe/billing/meter.ex` — resource module create/3 + require_param! + guard call pattern [VERIFIED: read lines 1-180]
- `lib/lattice_stripe/billing/meter/customer_mapping.ex` — nested sub-struct template [VERIFIED: read in full]
- `lib/lattice_stripe/billing/meter_event_adjustment.ex` — parent resource + sub-struct pattern [VERIFIED: read in full]
- `lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex` — minimal nested sub-struct [VERIFIED: read in full]
- `lib/lattice_stripe/checkout/session.ex` — Inspect impl hiding `:url` (lines 658-684) [VERIFIED: read]
- `lib/lattice_stripe/resource.ex` — `require_param!/3` and `unwrap_singular/2` [VERIFIED: read]
- `mix.exs` — `groups_for_modules` structure, `extras` list, deps [VERIFIED: read in full]
- `test/support/fixtures/metering.ex` — fixture module pattern [VERIFIED: read in full]
- `test/support/test_helpers.ex` — `test_integration_client/1` helper [VERIFIED: read]
- `test/integration/checkout_session_integration_test.exs` — integration test setup pattern [VERIFIED: read in full]
- stripe-mock live probe: `POST /v1/billing_portal/sessions` [VERIFIED: multiple live probes executed]
- `.planning/phases/21-customer-portal/21-CONTEXT.md` — all locked decisions D-01..D-04 [VERIFIED: read in full]

### Secondary (MEDIUM confidence)

- `https://docs.stripe.com/api/customer_portal/sessions/create` — full parameter list and flow_data schema [CITED: WebFetch confirmed]
- `.planning/phases/20-billing-metering/20-01-SUMMARY.md` — Wave 0 deviation records (`:httpc` vs `LatticeStripe.Client`; `LatticeStripe.Test.Fixtures.*` namespace convention) [VERIFIED: read]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps, existing stack verified in mix.exs
- Architecture patterns: HIGH — all templates read from actual codebase files
- Stripe API surface: HIGH — live stripe-mock probes + official docs
- stripe-mock behavior: HIGH — live probes confirmed sub-field enforcement gap
- Pitfalls: HIGH — sourced from CONTEXT.md decisions + live probe findings

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (30 days — stable Stripe API, stable Elixir ecosystem)
