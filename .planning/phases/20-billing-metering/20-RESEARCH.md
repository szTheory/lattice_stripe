# Phase 20: Billing Metering - Research

**Researched:** 2026-04-14
**Domain:** Elixir SDK — Stripe Billing Meter + MeterEvent + MeterEventAdjustment
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — GUARD-01 scope, severity, and location**
Helper `LatticeStripe.Billing.Guards.check_meter_value_settings!/1` (new), called from `Meter.create/3` after `Resource.require_param!/3` checks. Behavior:
1. Hard `ArgumentError` when `default_aggregation.formula` is `"sum"` or `"last"` AND `value_settings` is a map with missing/nil/empty-string `event_payload_key`.
2. Silent pass when `value_settings` is omitted entirely (Stripe defaults to `"value"`).
3. `Logger.warning/1` when `formula == "count"` AND `value_settings` is passed (Stripe silently ignores it).
4. String keys only — atom-keyed params bypass the guard silently.

**D-02 — MeterEvent Inspect masking: allowlist pattern, hide `:payload`**
Extend existing LatticeStripe allowlist Inspect pattern to `%LatticeStripe.Billing.MeterEvent{}`. Render: `#LatticeStripe.Billing.MeterEvent<event_name:, identifier:, timestamp:, created:, livemode:>`. Hide `:payload` entirely. Pattern: `lib/lattice_stripe/customer.ex:467+` and `lib/lattice_stripe/checkout/session.ex`.

**D-03 — Nested typed struct budget for `%Meter{}` (4 modules)**
4 distinct nested struct modules:
- `LatticeStripe.Billing.Meter.DefaultAggregation` — single field `formula` (string), simple struct no `:extra`
- `LatticeStripe.Billing.Meter.CustomerMapping` — fields `event_payload_key`, `type`, `@known_fields + :extra`
- `LatticeStripe.Billing.Meter.ValueSettings` — single field `event_payload_key`, simple struct no `:extra`
- `LatticeStripe.Billing.Meter.StatusTransitions` — field `deactivated_at`, `@known_fields + :extra`
No `Jason.Encoder` on any struct. No PII masking on nested structs (only MeterEvent.payload).

**D-04 — `MeterEventAdjustment` gets a full typed struct (not raw map)**
`%LatticeStripe.Billing.MeterEventAdjustment{}` with `from_map/1`, `@known_fields`, `:extra`. Fields: `id`, `object`, `event_name`, `status`, `cancel`, `livemode` + `extra`. `cancel` decoded as `LatticeStripe.Billing.MeterEventAdjustment.Cancel` (single field: `identifier`). Unit test MUST assert `cancel: %{"identifier" => "req_abc"}` decodes to `%Cancel{identifier: "req_abc"}`.

**D-05 — `guides/metering.md` depth and structure**
Target: 580 lines ± 40. 12 H2 sections. Full `AccrueLike.UsageReporter` module (~40 lines). Two-layer idempotency explainer. Dunning correction worked example (~45 lines). 7-row error code table. GUARD-01 escape hatch. Cross-links to 5 sibling guides. Hard stops: >700 lines cut dunning to reference-only; <450 lines the error-code table or formula section is too shallow.

**D-06 — Formula input surface: strings only (no atom normalization on write)**
`Meter.create/3` accepts strings only on the wire. Atom-keyed params not normalized. Read-side `status_atom/1` helper on parent `%Meter{}` is unaffected.

**D-07 — `customer_mapping` presence guard: deferred**
Not implemented in Phase 20. Track as post-ship candidate.

### Claude's Discretion

- Exact field order in each nested struct (follow Stripe API doc order)
- Exact `@moduledoc` wording and examples (follow Phase 14/15/16/17 conventions)
- Exact message wording in `ArgumentError` / `Logger.warning` (D-01 sketch is a baseline)
- Test fixture shapes (follow `test/support/fixtures/` conventions)
- stripe-mock integration test coverage depth (mirror Phase 17/18 pattern)
- Whether `Meter.update/4` pre-validates `status` mutation attempts (recommend NO)
- ExDoc group ordering in `mix.exs` (place "Billing Metering" after "Billing", before "Connect")
- Whether `MeterEventAdjustment.Cancel` nested struct deserves its own test module
- `@typedoc` depth on `DefaultAggregation` formula enum (recommend enumerate 3 values with semantics)
- Whether integration tests split into 1 file or 3 files (recommend 3 files)
- Whether hot-path `UsageReporter` example appears as `moduledoc` doctest (recommend guide-only)

### Deferred Ideas (OUT OF SCOPE)

- `/v2/billing/meter_event_stream` high-throughput variant (v1.1 D3)
- `BillingPortal.Configuration` CRUDL (v1.1 D4)
- `Meter` delete / search (Stripe API does not expose)
- `MeterEvent` retrieve / list (write-only)
- `Billing.Meter.EventSummary` aggregate queries (separate API family — v1.2+)
- Release-cut phase (zero-touch via release-please)
- `customer_mapping` presence guard (D-07 deferred)
- Formula atom normalization on write (D-06 rejects)
- `MeterEventAdjustment` webhook reconcile example in guide
- `UsageReporter` as moduledoc doctest
- Property-based tests (StreamData) for idempotency
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| METER-01 | Create Meter with full params, receive `%Meter{}` struct | Stripe API confirmed: POST `/v1/billing/meters`, required fields: `display_name`, `event_name`, `default_aggregation.formula` |
| METER-02 | Retrieve Meter by ID | GET `/v1/billing/meters/{id}` — confirmed in OpenAPI spec |
| METER-03 | Update Meter mutable fields via `update/4` | POST `/v1/billing/meters/{id}` — `display_name` is the primary mutable field |
| METER-04 | List Meters with cursor pagination + lazy `stream!/3` | GET `/v1/billing/meters` — standard LatticeStripe `List.stream!/2` pattern |
| METER-05 | `deactivate/3` verb — POST `/v1/billing/meters/{id}/deactivate` | Confirmed distinct endpoint, not a status update; mirrors `Payout.cancel/4` precedent |
| METER-06 | `reactivate/3` verb — POST `/v1/billing/meters/{id}/reactivate` | Confirmed distinct endpoint |
| METER-07 | Bang variants for all functions | `Resource.unwrap_bang!/1` pattern — trivial once non-bang variants exist |
| METER-08 | 4 nested typed structs with `@known_fields + :extra` where needed | D-03 locked: DefaultAggregation (simple), CustomerMapping (extra), ValueSettings (simple), StatusTransitions (extra) |
| METER-09 | `Meter.status` decoded to atom via `status_atom/1` helper | `Account.Capability.status_atom/1` is the exact pattern to mirror; `@known_statuses ["active", "inactive"]` |
| EVENT-01 | `MeterEvent.create/3` with `event_name`, `payload`, optional `timestamp`/`identifier` | POST `/v1/billing/meter_events` — confirmed |
| EVENT-02 | Honor `idempotency_key:` opt (HTTP header) independently from body `identifier` | Already wired in v1.0 Client plumbing — zero new Client code needed |
| EVENT-03 | Honor `stripe_account:` opt for Connect | Already wired in v1.0 Client plumbing |
| EVENT-04 | `MeterEventAdjustment.create/3` with exact `cancel.identifier` field shape | POST `/v1/billing/meter_event_adjustments`, `cancel: %{"identifier" => "..."}` nested shape |
| EVENT-05 | `MeterEvent` struct with 6 fields: `event_name`, `identifier`, `payload`, `timestamp`, `created`, `livemode` | Minimal — no back-read operations |
| GUARD-01 | Pre-flight `value_settings` guard in `Meter.create/3` | D-01 decision locks the exact behavior and code; `Billing.Guards.check_meter_value_settings!/1` |
| GUARD-02 | Inline `@doc` for `MeterEvent.create/3` documenting 35-day window, 24h dedup window, async nature | Guide + moduledoc callout — PITFALLS.md has exact wording anchors |
| GUARD-03 | `{:ok, %MeterEvent{}}` documented as "accepted for processing" not "recorded" | Mirrors Phase 15 webhook-handoff callout precedent |
| TEST-01 | `test/support/fixtures/metering.ex` with `Meter`, `MeterEvent`, `MeterEventAdjustment` fixtures | Pattern: `basic(overrides \\ %{})` + named variants, mirrors `fixtures/subscription.ex` |
| TEST-03 | Wave 0 stripe-mock probe confirms 3 endpoint families + deactivate/reactivate shapes | All endpoints confirmed in OpenAPI spec without beta flags; stripe-mock stateless caveat documented |
| TEST-05 | Full integration tests: create→report→adjust→deactivate→list→reactivate | 3 separate integration test files, `@moduletag :integration`, shape-only assertions |
| DOCS-01 | `guides/metering.md` — 580 ± 40 lines, 12 H2 sections, full content per D-05 | D-05 section outline provides exact section list |
| DOCS-03 | `mix.exs` gains `"Billing Metering"` group (7 modules) + `guides/metering.md` in `extras` | ARCHITECTURE.md has exact `groups_for_modules` snippet |
| DOCS-04 | Cross-links from `subscriptions.md`, `webhooks.md`, `telemetry.md`, `error-handling.md`, `testing.md` | Reciprocal links — 5 target files confirmed to exist in `guides/` |
</phase_requirements>

---

## Summary

Phase 20 adds three new public modules under `LatticeStripe.Billing.*`: a full CRUDL resource (`Billing.Meter` with deactivate/reactivate lifecycle verbs), a create-only hot-path event reporter (`Billing.MeterEvent`), and a create-only correction mechanism (`Billing.MeterEventAdjustment`). All decisions are already locked in CONTEXT.md D-01..D-07; this research documents exactly what the planner needs to produce concrete, executable task plans without re-deriving any choices.

The primary implementation challenge is not complexity — the code follows established v1.0 patterns throughout — but documentation fidelity. Metering has more async silent-failure modes than any other Stripe resource (silent-zero trap, customer-mapping silent drop, async ack confusion), and the `guides/metering.md` at 580 ± 40 lines is the single differentiator over stripity_stripe, which ships no metering guide at all.

All 7 Stripe API endpoints are confirmed present in stripe-mock without beta flags (verified from Stripe OpenAPI `spec3.json` 2026-04-13). No new Hex dependencies are required. All infrastructure — Client, Transport, Resource helpers, Telemetry — is unchanged from v1.0.

**Primary recommendation:** Follow the 6-plan sequential wave structure locked in CONTEXT.md, with each plan self-contained and committed as a single feat: conventional commit. The planner can map each plan directly to the wave structure in `<plan_structure>` section of CONTEXT.md.

---

## Standard Stack

### Core (Unchanged from v1.0 — no new deps)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | ~> 0.21 | HTTP transport | Default transport behaviour adapter; v1.0 Finch pool serves metering endpoints identically to all other Stripe resources | [VERIFIED: mix.exs] |
| Jason | ~> 1.4 | JSON encoding/decoding | Handles POST body encoding and response decoding for all metering endpoints | [VERIFIED: mix.exs] |
| :telemetry | ~> 1.0 | Instrumentation events | Auto-emitted by Client layer for every `MeterEvent.create/3` call — zero per-resource telemetry code needed | [VERIFIED: mix.exs] |
| Mox | ~> 1.2 | Test mocking | Mock `LatticeStripe.MockTransport` behaviour in all unit tests | [VERIFIED: mix.exs] |
| ExUnit | stdlib | Test framework | All unit and integration tests | [VERIFIED: mix.exs] |
| ExDoc | ~> 0.34 | Documentation | `guides/metering.md` + module docs | [VERIFIED: mix.exs] |

**No additions to `mix.exs deps/0` required for Phase 20.** [VERIFIED: .planning/research/STACK.md]

### CI Infrastructure

| Tool | Version | Purpose | Status |
|------|---------|---------|--------|
| stripe-mock | latest (Docker) | Integration tests against OpenAPI spec | All 7 v1.1 endpoints confirmed present without beta flags [VERIFIED: .planning/research/STACK.md] |

---

## Architecture Patterns

### Recommended Project Structure (Phase 20 additions)

```
lib/lattice_stripe/billing/
  guards.ex                        # EXISTING — add check_meter_value_settings!/1 here
  meter.ex                         # NEW — Billing.Meter resource module
  meter/
    default_aggregation.ex         # NEW — simple struct, no :extra
    customer_mapping.ex            # NEW — @known_fields + :extra
    value_settings.ex              # NEW — simple struct, no :extra
    status_transitions.ex          # NEW — @known_fields + :extra
  meter_event.ex                   # NEW — Billing.MeterEvent resource module
  meter_event_adjustment.ex        # NEW — Billing.MeterEventAdjustment resource module
  meter_event_adjustment/
    cancel.ex                      # NEW — minimal nested struct for cancel.identifier

test/support/fixtures/
  metering.ex                      # NEW — Meter.basic, Meter.list_response, Meter.deactivated,
                                   #        MeterEvent.basic, MeterEventAdjustment.basic

test/integration/
  meter_integration_test.exs           # NEW
  meter_event_integration_test.exs     # NEW
  meter_event_adjustment_integration_test.exs  # NEW

guides/
  metering.md                      # NEW — 580 ± 40 lines
```

Modified files:
- `lib/lattice_stripe/billing/guards.ex` — add `check_meter_value_settings!/1`
- `mix.exs` — add `"Billing Metering"` group to `groups_for_modules`, add guide to `extras`
- `guides/subscriptions.md`, `guides/webhooks.md`, `guides/telemetry.md`, `guides/error-handling.md`, `guides/testing.md` — add reciprocal cross-links

### Pattern 1: Simple Typed Struct (no `:extra`) — DefaultAggregation, ValueSettings

Use for nested objects where Stripe's spec shows only 1 field and the field set is stable.

```elixir
# Source: lib/lattice_stripe/invoice/status_transitions.ex (exact precedent)
defmodule LatticeStripe.Billing.Meter.DefaultAggregation do
  @moduledoc """
  Aggregation formula configuration for a Stripe Billing Meter.
  ...
  """

  defstruct [:formula]

  @typedoc """
  - `formula` - `"sum"` | `"count"` | `"last"` ...
  """
  @type t :: %__MODULE__{formula: String.t() | nil}

  @doc false
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{formula: map["formula"]}
  end
end
```

### Pattern 2: `@known_fields + :extra` Typed Struct — CustomerMapping, StatusTransitions

Use for nested objects that Stripe may extend with new fields.

```elixir
# Source: lib/lattice_stripe/account/capability.ex (exact precedent)
defmodule LatticeStripe.Billing.Meter.CustomerMapping do
  @known_fields ~w(event_payload_key type)a

  defstruct @known_fields ++ [extra: %{}]

  @type t :: %__MODULE__{
          event_payload_key: String.t() | nil,
          type: String.t() | nil,
          extra: map()
        }

  @doc false
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, Enum.map(@known_fields, &Atom.to_string/1))

    struct(__MODULE__,
      event_payload_key: known["event_payload_key"],
      type: known["type"],
      extra: extra
    )
  end
end
```

### Pattern 3: `status_atom/1` helper — `%Meter{}` status field

Mirror `Account.Capability.status_atom/1` exactly.

```elixir
# Source: lib/lattice_stripe/account/capability.ex:50-69 [VERIFIED: read in this session]
@known_statuses ~w(active inactive)
@known_status_atoms [:active, :inactive]
@doc false
def known_status_atoms, do: @known_status_atoms

@spec status_atom(t() | String.t() | nil) :: atom()
def status_atom(%__MODULE__{status: s}), do: status_atom(s)
def status_atom(nil), do: nil
def status_atom(s) when s in @known_statuses, do: String.to_existing_atom(s)
def status_atom(_), do: :unknown
```

### Pattern 4: Lifecycle verb as distinct function — deactivate/reactivate

```elixir
# Source: lib/lattice_stripe/account.ex:285-299 (reject/4 pattern) [VERIFIED: read in this session]
# Also: lib/lattice_stripe/payout.ex cancel/4 precedent

def deactivate(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/billing/meters/#{id}/deactivate", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

def deactivate!(%Client{} = client, id, opts \\ []) when is_binary(id),
  do: client |> deactivate(id, opts) |> Resource.unwrap_bang!()
```

### Pattern 5: Allowlist Inspect — MeterEvent

```elixir
# Source: lib/lattice_stripe/customer.ex:467-489 [VERIFIED: read in this session]
defimpl Inspect, for: LatticeStripe.Billing.MeterEvent do
  import Inspect.Algebra

  def inspect(event, opts) do
    # :payload hidden — contains stripe_customer_id and metered value
    # Escape hatch: IO.inspect(event, structs: false)  or  event.payload
    fields = [
      event_name: event.event_name,
      identifier: event.identifier,
      timestamp: event.timestamp,
      created: event.created,
      livemode: event.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Billing.MeterEvent<" | pairs] ++ [">"])
  end
end
```

### Pattern 6: GUARD-01 guard helper

```elixir
# Source: CONTEXT.md D-01 code sketch (exact implementation target)
# Drop into lib/lattice_stripe/billing/guards.ex alongside check_proration_required/2

require Logger

@spec check_meter_value_settings!(map()) :: :ok
def check_meter_value_settings!(params) when is_map(params) do
  formula = get_in(params, ["default_aggregation", "formula"])
  value_settings = Map.get(params, "value_settings")

  cond do
    formula in ["sum", "last"] and is_map(value_settings) and
        not valid_event_payload_key?(value_settings) ->
      raise ArgumentError, "LatticeStripe.Billing.Meter.create/3: ..."

    formula == "count" and not is_nil(value_settings) ->
      Logger.warning("LatticeStripe.Billing.Meter.create/3: value_settings ignored for count ...")
      :ok

    true -> :ok
  end
end

def check_meter_value_settings!(_non_map), do: :ok

defp valid_event_payload_key?(%{"event_payload_key" => key})
     when is_binary(key) and byte_size(key) > 0, do: true
defp valid_event_payload_key?(_), do: false
```

### Pattern 7: MeterEventAdjustment with nested Cancel struct

```elixir
# Source: D-04 decision in CONTEXT.md [VERIFIED: read in this session]
# MeterEventAdjustment has a nested Cancel struct to enforce the cancel.identifier shape

defmodule LatticeStripe.Billing.MeterEventAdjustment.Cancel do
  defstruct [:identifier]
  @type t :: %__MODULE__{identifier: String.t() | nil}

  def from_map(nil), do: nil
  def from_map(%{"identifier" => identifier}), do: %__MODULE__{identifier: identifier}
  def from_map(_), do: %__MODULE__{}
end
```

### Pattern 8: Integration test structure

```elixir
# Source: test/integration/account_integration_test.exs [VERIFIED: read in this session]
defmodule LatticeStripe.MeterIntegrationTest do
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
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end
  # ...
end
```

### Anti-Patterns to Avoid

- **Using `update/4` with `%{"status" => "inactive"}`** for deactivation — Stripe exposes `/deactivate` and `/reactivate` as distinct endpoints. Status must NOT be changed via `update/4`.
- **Passing atom keys to guards**: `%{default_aggregation: %{formula: :sum}}` — D-01 and D-06 explicitly scope guards to string keys only. Atom-keyed params pass through silently; Stripe's HTTP layer will 400.
- **Aliasing `identifier` to `idempotency_key:`** — they are orthogonal mechanisms at different layers. Never map one to the other in code or docs.
- **Raw `map()` return for MeterEventAdjustment** — D-04 locks: use full typed struct for `{:ok, %MeterEventAdjustment{}}` symmetry.
- **`IO.warn/2` instead of `Logger.warning/1`** for count+value_settings — D-01 locks Logger.warning to avoid stacktrace noise in test output.
- **Nesting `MeterEventAdjustment` under `MeterEvent` namespace** — Stripe's API is a sibling resource at `/v1/billing/meter_event_adjustments`, mirrors `TransferReversal` pattern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unwrap `{:ok, response}` → `{:ok, struct}` | Custom result transformation | `Resource.unwrap_singular/2` | Already handles error passthrough; one-liner |
| Unwrap list responses | Custom list mapper | `Resource.unwrap_list/2` | Handles `%List{}` + typed item mapping |
| Bang variants | Custom raise-on-error wrapper | `Resource.unwrap_bang!/1` | Raises `LatticeStripe.Error` correctly |
| Required param validation | Custom `if Map.has_key?` | `Resource.require_param!/3` | Consistent error message pattern, pre-network |
| Connection pooling for integration tests | Custom Finch setup | `test_integration_client/0` from `TestHelpers` | Already configured for `localhost:12111` |
| Lazy streaming over paginated meters | Custom cursor loop | `List.stream!/2` wrapping a `%Request{}` | Handles `has_more`, cursor threading |
| JSON encode/decode | Custom serialization | Jason (stdlib of the project) | Already in deps, no new code |
| Telemetry events | Per-resource telemetry calls | Client layer emits automatically | Every `Client.request/2` call emits spans |
| PII-safe struct rendering | Custom `to_string` | `defimpl Inspect` allowlist pattern | Customer.ex + Session.ex are the exact templates |
| Pre-flight option validation | Custom schema checker | String key guard + `valid_event_payload_key?/1` | Pattern from D-01; no NimbleOptions needed for nested map params |

**Key insight:** All resource-level boilerplate (CRUDL pattern, bang variants, list/stream, unwrapping, error propagation) has been solved and standardized in v1.0. Phase 20 adds NO new infrastructure patterns — it follows all of them exactly.

---

## Stripe API Endpoints Reference

All endpoints confirmed present in Stripe OpenAPI spec without beta/restricted flags. [VERIFIED: .planning/research/STACK.md, 2026-04-13]

### Billing.Meter

| Operation | HTTP | Path |
|-----------|------|------|
| create | POST | `/v1/billing/meters` |
| retrieve | GET | `/v1/billing/meters/{id}` |
| update | POST | `/v1/billing/meters/{id}` |
| list | GET | `/v1/billing/meters` |
| deactivate | POST | `/v1/billing/meters/{id}/deactivate` |
| reactivate | POST | `/v1/billing/meters/{id}/reactivate` |

**Required create params:** `display_name`, `event_name`, `default_aggregation` (with `formula`).
**Optional create params:** `customer_mapping`, `value_settings`, `event_time_window`.
**Mutable via update:** `display_name`, `customer_mapping`, `default_aggregation`. Status is NOT a mutable param — use deactivate/reactivate verbs.
**ID prefix:** `mtr_...`
**Statuses:** `"active"` (default on create), `"inactive"` (after deactivate).

### Billing.MeterEvent

| Operation | HTTP | Path |
|-----------|------|------|
| create | POST | `/v1/billing/meter_events` |

**Required params:** `event_name`, `payload` (map with at least the `customer_mapping.event_payload_key` key).
**Optional params:** `timestamp` (Unix timestamp, defaults to now), `identifier` (string, max 100 chars, Stripe auto-generates if omitted).
**Response:** Thin ack struct — `event_name`, `identifier`, `payload`, `timestamp`, `created`, `livemode`.
**CRITICAL: Async semantics.** `{:ok, %MeterEvent{}}` means "accepted for async processing." Customer-mapping validation, value validation, and billing aggregation all happen asynchronously. The only detection mechanism for async failures is the `v1.billing.meter.error_report_triggered` webhook.

### Billing.MeterEventAdjustment

| Operation | HTTP | Path |
|-----------|------|------|
| create | POST | `/v1/billing/meter_event_adjustments` |

**Required params:** `event_name`, `type` (must be `"cancel"`), `cancel` (map with `identifier` key).
**Critical shape:** `cancel` is a nested sub-object, NOT a top-level field.
```elixir
%{
  "event_name" => "api_calls",
  "type" => "cancel",
  "cancel" => %{"identifier" => "evt_abc123"}
}
```
**24-hour window:** Adjustments only work for events from the last 24 hours. stripe-mock does NOT enforce this window — tests pass in CI but may fail in production for older events.
**Response fields:** `id`, `object`, `event_name`, `status`, `cancel` (echoed as sub-object), `livemode`.

---

## Common Pitfalls

### Pitfall 1: Silent-Zero Billing Trap (sum/last + malformed value_settings)

**What goes wrong:** `Meter.create/3` with `default_aggregation.formula: "sum"` and `value_settings: %{}` (present but empty) causes Stripe to silently bill $0 forever. GUARD-01 (D-01) addresses this by raising `ArgumentError` before the network call — but ONLY when value_settings is present-but-malformed, not when it's omitted (omission is legal — Stripe defaults to `"value"`). [VERIFIED: .planning/research/PITFALLS.md + CONTEXT.md D-01]

**How to avoid:** `check_meter_value_settings!/1` raises on `is_map(value_settings) and missing/empty event_payload_key`. Tests: 8-case matrix in D-01.

**Warning signs:** Usage summing to zero despite events being sent. `meter_event_value_not_found` in error webhook.

### Pitfall 2: Async Ack Confusion

**What goes wrong:** `MeterEvent.create/3` returning `{:ok, %MeterEvent{}}` does NOT mean the event was recorded. It means Stripe accepted it for async processing. Customer mapping validation, value validation, and dedup all happen asynchronously. Silent drops surface via `v1.billing.meter.error_report_triggered` webhook only. [VERIFIED: .planning/research/PITFALLS.md Pitfall 3]

**How to avoid:** GUARD-02 and GUARD-03 require explicit documentation in `@doc`. Guide monitoring section with 7-row error code table (D-05).

**Warning signs:** Billing usage shows zero despite `{:ok, _}` responses. `billing.meter.error_report_triggered` fires.

### Pitfall 3: Dual Idempotency Layer Confusion

**What goes wrong:** `identifier` (body field, domain-level dedup, 24h rolling window) and `idempotency_key:` opt (HTTP header, request-level dedup) are orthogonal. Using only `idempotency_key:` leaves a double-billing hole if the HTTP key changes between retries (e.g., process restart loses in-memory key). Using only `identifier` leaves a race condition if two concurrent requests race before Stripe's dedup window fires. [VERIFIED: .planning/research/PITFALLS.md Pitfall 1]

**How to avoid:** Always set both. Recommended pattern in guide: `identifier = "#{customer_id}:#{event_name}:#{unix_second}"` and pass it as BOTH the body field and `idempotency_key:` opt. Document both mechanisms separately in `MeterEvent.create/3` `@doc`.

**Warning signs:** Duplicate events in Stripe dashboard. Usage summed at 2× expected value.

### Pitfall 4: `cancel.identifier` Field Name in MeterEventAdjustment

**What goes wrong:** Three common mistakes: (1) using `"id"` instead of `"identifier"` inside cancel, (2) putting `"identifier"` at the top level instead of inside `"cancel"`, (3) confusing the adjustment's `cancel.identifier` with the MeterEvent's body-level `identifier` field (different purposes). Stripe returns a 400 for wrong shapes. [VERIFIED: .planning/research/PITFALLS.md Pitfall 6]

**How to avoid:** Unit test in Plan 20-04 MUST assert `from_map(%{"cancel" => %{"identifier" => "req_abc"}})` produces `%MeterEventAdjustment{cancel: %Cancel{identifier: "req_abc"}}`. Guide dunning example shows exact shape.

**Warning signs:** `{:error, %Error{param: "cancel[identifier]"}}` from Stripe.

### Pitfall 5: Events to Inactive Meter (archived_meter)

**What goes wrong:** After `deactivate/3`, any MeterEvent with the matching `event_name` returns synchronous `archived_meter` error code. Events during the inactive window are permanently lost — reactivation does not retroactively process them. [VERIFIED: .planning/research/PITFALLS.md Pitfall 5]

**How to avoid:** Document in `deactivate/3` `@doc`. Error code must be pattern-matchable via `%Error{code: "archived_meter"}` — already normalized by v1.0 error handling.

### Pitfall 6: Timestamp Backdating Window

**What goes wrong:** `timestamp` more than 35 calendar days in the past returns synchronous `timestamp_too_far_in_past` (400). `timestamp` more than 5 minutes in the future returns `timestamp_in_future` (400). Batch-flush anti-pattern (accumulate events, flush daily with original timestamps) breaks for events > 35 days old. [VERIFIED: .planning/research/PITFALLS.md Pitfall 2]

**How to avoid:** GUARD-02 requires documenting constraints in `MeterEvent.create/3` `@doc`. Guide "What NOT to do: nightly batch flush" section with wrong-way/right-way code blocks (D-05).

### Pitfall 7: stripe-mock Statelessness Gaps

**What goes wrong:** stripe-mock does NOT simulate: (a) `identifier`-based dedup (both sends succeed), (b) 24-hour MeterEventAdjustment cancellation window (all adjustments succeed), (c) `archived_meter` after deactivate (subsequent events still succeed), (d) async customer-mapping validation failures. Tests that rely on these behaviors will pass in CI and fail in production. [VERIFIED: .planning/research/STACK.md + PITFALLS.md Integration Gotchas]

**How to avoid:** Integration test files MUST contain comments explaining which behaviors cannot be verified against stripe-mock and require Stripe test mode. TEST-03 explicitly acknowledges this (stripe-mock is "shape-only, not state-transition").

---

## Webhook Error Codes — `v1.billing.meter.error_report_triggered`

These are the exact error codes that appear in the error webhook and must be in the guide's 7-row table (D-05). [VERIFIED: .planning/research/PITFALLS.md + .planning/research/FEATURES.md + Stripe Recording Usage API guide]

| `error_code` | When Triggered | Delivery Mode | Silent Drop? | Remediation |
|---|---|---|---|---|
| `meter_event_customer_not_found` | Customer referenced by mapping key doesn't exist in Stripe | Async webhook | YES | Sweep job to find + fix affected events within 35-day window |
| `meter_event_no_customer_defined` | Payload is missing the `customer_mapping.event_payload_key` key | Async webhook | YES | Fix reporter code; add payload key |
| `meter_event_invalid_value` | Value at `value_settings.event_payload_key` is not numeric | Async webhook | YES | Fix reporter to send numeric value |
| `meter_event_value_not_found` | `sum`/`last` formula but no value at the configured key | Async webhook | YES | Usually GUARD-01 bypass; fix payload or meter config |
| `archived_meter` | Meter is in `inactive` status | Synchronous 400 | NO (sync error) | Alert — events during inactive window are PERMANENTLY LOST; reactivate meter |
| `timestamp_too_far_in_past` | Event timestamp > 35 days ago | Synchronous 400 | NO (sync error) | Drop; data permanently unrecoverable outside window |
| `timestamp_in_future` | Event timestamp > 5 minutes future | Synchronous 400 | NO (sync error) | Fix clock skew in reporter |

Note: `archived_meter`, `timestamp_too_far_in_past`, and `timestamp_in_future` are synchronous (HTTP 400) — LatticeStripe surfaces them as `{:error, %Error{code: "..."}}`. The first four are async-only and arrive exclusively via webhook.

---

## Aggregation Formula Semantics

[VERIFIED: .planning/research/FEATURES.md + Stripe API docs]

| Formula | Stripe Definition | When to Use | `value_settings` Required? |
|---------|-------------------|-------------|---------------------------|
| `"sum"` | Sum each event's value within the window | API calls (value = 1 per call), tokens consumed, bytes transferred | YES — `event_payload_key` must point to a numeric field |
| `"count"` | Count the number of events (ignores value field) | Simple event counting where magnitude doesn't matter | NO — value field is silently ignored |
| `"last"` | Take the most recent event's value in the window | Seat counts, storage usage — want current state, not total | YES — same requirement as `"sum"` |

`event_time_window` (`"hour"` or `"day"`) controls when the aggregation resets. Important for `"last"` formula: within the window, only the final value is used. At window reset, the meter starts fresh.

**D-01 amends the REQUIREMENT text:** Raising when `value_settings` is ABSENT is over-strict — Stripe defaults `event_payload_key` to `"value"`, which is valid. GUARD-01 raises only on present-but-malformed `value_settings`.

---

## Fixture Shapes

### Meter fixture (for `test/support/fixtures/metering.ex`)

Reference: [VERIFIED: Stripe API object fields from .planning/research/FEATURES.md]

```elixir
# Meter.basic/1
%{
  "id" => "mtr_test1234567890",
  "object" => "billing.meter",
  "display_name" => "API Calls",
  "event_name" => "api_calls",
  "event_time_window" => "hour",
  "status" => "active",
  "status_transitions" => %{"deactivated_at" => nil},
  "default_aggregation" => %{"formula" => "sum"},
  "customer_mapping" => %{
    "event_payload_key" => "stripe_customer_id",
    "type" => "by_id"
  },
  "value_settings" => %{"event_payload_key" => "value"},
  "created" => 1_700_000_000,
  "livemode" => false,
  "zzz_future_field" => "extra_value"  # F-001 extra split coverage
}

# Meter.deactivated/1 — same as basic but status: "inactive" + status_transitions.deactivated_at set
# Meter.list_response/1 — wraps one meter in standard List shape

# MeterEvent.basic/1
%{
  "object" => "billing.meter_event",
  "event_name" => "api_calls",
  "identifier" => "evt_test_abc123",
  "payload" => %{"stripe_customer_id" => "cus_test123", "value" => "1"},
  "timestamp" => 1_700_000_000,
  "created" => 1_700_000_000,
  "livemode" => false
}

# MeterEventAdjustment.basic/1
%{
  "id" => "bmadjust_test1234567890",
  "object" => "billing.meter_event_adjustment",
  "event_name" => "api_calls",
  "type" => "cancel",
  "status" => "pending",
  "cancel" => %{"identifier" => "evt_test_abc123"},
  "created" => 1_700_000_000,
  "livemode" => false
}
```

---

## Codebase Reference — Exact Patterns to Mirror

All patterns below were verified by reading source files in this session.

| What to Implement | Mirror This File | Key Lines |
|---|---|---|
| Simple nested struct (no `:extra`) | `lib/lattice_stripe/invoice/status_transitions.ex` | Full file — defstruct, @typedoc, from_map/1 |
| `@known_fields + :extra` nested struct | `lib/lattice_stripe/account/capability.ex` | Lines 20-48 (cast/1 pattern) |
| `status_atom/1` helper | `lib/lattice_stripe/account/capability.ex` | Lines 50-69 |
| Resource CRUDL + lifecycle verbs | `lib/lattice_stripe/account.ex` | Lines 161-331 (create through stream) |
| Allowlist Inspect implementation | `lib/lattice_stripe/customer.ex` | Lines 467-489 |
| Additional Inspect example | `lib/lattice_stripe/checkout/session.ex` | Search `defimpl Inspect` |
| Guards helper | `lib/lattice_stripe/billing/guards.ex` | Full file — add new guard alongside `check_proration_required/2` |
| require_param! usage | `lib/lattice_stripe/resource.ex` | Lines 95-125 |
| Integration test structure | `test/integration/account_integration_test.exs` | Lines 1-39 (setup_all + shape assertions) |
| Fixture module structure | `test/support/fixtures/subscription.ex` | Lines 1-30 (basic/1 + Map.merge pattern) |
| TestHelpers | `test/support/test_helpers.ex` | Full file — use `test_client/1` and `test_integration_client/1` as-is |

---

## mix.exs Changes Required

[VERIFIED: mix.exs read in this session; ARCHITECTURE.md has exact snippet]

### `groups_for_modules` — add after existing `Billing` group, before `Connect`:

```elixir
"Billing Metering": [
  LatticeStripe.Billing.Meter,
  LatticeStripe.Billing.Meter.DefaultAggregation,
  LatticeStripe.Billing.Meter.CustomerMapping,
  LatticeStripe.Billing.Meter.ValueSettings,
  LatticeStripe.Billing.Meter.StatusTransitions,
  LatticeStripe.Billing.MeterEvent,
  LatticeStripe.Billing.MeterEventAdjustment
],
```

### `extras` — add after existing billing/subscription guides:

```elixir
"guides/metering.md",
```

Note: `LatticeStripe.Billing.MeterEventAdjustment.Cancel` is a nested struct but is unlikely to warrant its own ExDoc group entry — it will appear under the parent module. Planner can add it to the group if desired (Claude's discretion).

---

## guides/metering.md Section Outline

[Source: CONTEXT.md D-05, locked decision]

12 H2 sections, ~580 lines ± 40:

1. **Intro** — what metering is, what this guide covers (2 paragraphs)
2. **Mental model** — Meter = schema / MeterEvent = fire-and-forget fact / Subscription with metered price = billing glue. ASCII diagram. Cross-link OUT to `subscriptions.md#metered-prices`.
3. **Defining a meter** (H3s: Aggregation formulas, customer_mapping, value_settings, Lifecycle verbs)
   - 1 paragraph per formula (sum, count, last) with when-to-use + one example each
   - Explicit callout: `:sum`/`:last` REQUIRE a well-formed `value_settings.event_payload_key`
4. **Reporting usage (the hot path)** (H3s: fire-and-forget idiom, two-layer idempotency, timestamp semantics, batch-flush anti-pattern)
   - Full `AccrueLike.UsageReporter` module (~40 lines) using `Task.Supervisor.start_child` + telemetry + error classification
   - Two-layer idempotency: side-by-side `identifier` vs `idempotency_key:` code + table
   - `> **Warning:**` box for batch-flush wrong-way code, immediately followed by right way
5. **Corrections and adjustments** (H3s: `MeterEventAdjustment.create/3`, dunning-style over-report flow)
   - ~45-line end-to-end dunning example with exact `cancel.identifier` shape
6. **Reconciliation via webhooks** (H3s: error-report webhook, error codes table, remediation patterns)
   - 7-row error code table (verbatim from section above)
7. **Observability** (H3s: telemetry, debugging with Inspect)
   - D-02 masking documented + `IO.inspect(event, structs: false)` + `event.payload` escape hatches
   - NEVER log raw `MeterEvent.payload` guidance
8. **Guards and escape hatches** — D-01 framing + `LatticeStripe.Client.request/4` one-line bypass
9. **Common pitfalls** — 7 bullets (one per PITFALLS.md entry), each 2-3 lines
10. **See also** — 5 cross-links: subscriptions.md, webhooks.md, telemetry.md, error-handling.md, testing.md

Style: `> **Warning:**` for data-loss content, `> **Note:**` for easy-to-miss facts, `elixir` fencing on all code blocks.

Hard stops: if >700 lines cut dunning to reference-only; if <450 lines error-code table or formula section is too shallow.

---

## Runtime State Inventory

Step 2.5: SKIPPED — Phase 20 is not a rename/refactor/migration phase. It adds new modules and files only; no existing state is renamed.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker / stripe-mock | TEST-03, TEST-05 integration tests | Must be started manually | stripe/stripe-mock:latest | Unit tests (Mox) cover all behavior; integration tests tagged `:integration` and skipped when Docker not running |
| Elixir | All | ✓ | >= 1.15 per mix.exs | — |
| ExUnit | All tests | ✓ | stdlib | — |

**Missing dependencies with no fallback:** None — integration tests are optional and guarded by `@moduletag :integration` with `setup_all` connectivity check.

**Missing dependencies with fallback:** stripe-mock Docker — all unit test behaviors covered by Mox; integration tests skip gracefully when mock not running.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test --exclude integration` |
| Full suite command | `mix test` (requires stripe-mock Docker running) |
| Integration only | `mix test test/integration/ --include integration` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| METER-01 | `Meter.create/3` returns `%Meter{}` with typed nested structs | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-02 | `Meter.retrieve/3` returns `%Meter{}` by ID | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-03 | `Meter.update/4` returns updated `%Meter{}` | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-04 | `Meter.list/3` returns `%Response{data: %List{}}` + `stream!/3` lazy | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-05 | `Meter.deactivate/3` calls correct endpoint | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-06 | `Meter.reactivate/3` calls correct endpoint | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-07 | All bang variants raise on error | unit (Mox) | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| METER-08 | `from_map/1` round-trips for all 4 nested structs, captures `:extra` | unit | `mix test test/lattice_stripe/billing/meter/` | ❌ Wave 0 |
| METER-09 | `status_atom/1` returns `:active`, `:inactive`, `:unknown` | unit | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave 0 |
| EVENT-01 | `MeterEvent.create/3` returns `%MeterEvent{}` with thin struct | unit (Mox) | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ❌ Wave 0 |
| EVENT-02 | `idempotency_key:` opt threads to HTTP header | unit (Mox) — assert header in mock capture | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ❌ Wave 0 |
| EVENT-03 | `stripe_account:` opt threads to HTTP header | unit (Mox) | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ❌ Wave 0 |
| EVENT-04 | `MeterEventAdjustment.create/3` with `cancel.identifier` nested shape | unit (Mox) | `mix test test/lattice_stripe/billing/meter_event_adjustment_test.exs` | ❌ Wave 0 |
| EVENT-05 | `MeterEvent` struct fields, Inspect masks `:payload` | unit | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ❌ Wave 0 |
| GUARD-01 | 8-case guard matrix (D-01): sum/nil, sum/good, sum/empty, sum/blank, last/nil, count/settings, count/nil, atoms) | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | ❌ Wave 0 |
| GUARD-02 | `@doc` contains "35-day", "24-hour", and "async" — verified via `@moduledoc` text test or manual | documentation review | n/a — manual review at verify step | n/a |
| GUARD-03 | `@doc` for `MeterEvent.create/3` states "accepted for processing" framing | documentation review | n/a — manual review | n/a |
| TEST-01 | `test/support/fixtures/metering.ex` exists with 5 fixture functions | fixture structure | `mix test test/lattice_stripe/billing/meter_test.exs` (uses fixtures) | ❌ Wave 0 |
| TEST-03 | stripe-mock probe script confirms endpoint shapes + documents gaps | probe script | `mix run scripts/verify_metering_endpoints.exs` or inline Wave 0 probe | ❌ Wave 0 |
| TEST-05 | Integration lifecycle: create→event→adjust→deactivate→list→reactivate | integration | `mix test test/integration/ --include integration` | ❌ Wave 0 |
| DOCS-01 | `guides/metering.md` exists, line count 540-620, contains all 10 H2 section headers | documentation check | `wc -l guides/metering.md` | ❌ Wave 0 |
| DOCS-03 | `mix.exs` contains "Billing Metering" group with 7 modules + `guides/metering.md` in extras | config check | `mix docs --warnings-as-errors` | ❌ Wave 0 |
| DOCS-04 | Cross-links exist in 5 sibling guide files | documentation check | `grep -l "metering.md" guides/*.md` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test --exclude integration`
- **Per wave merge:** `mix test --exclude integration && mix compile --warnings-as-errors && mix credo --strict`
- **Phase gate (before `/gsd-verify-work`):** Full suite green (`mix test` with stripe-mock running) + `mix docs --warnings-as-errors`

### Wave 0 Gaps

All test files are new — none exist yet. Wave 0 (Plan 20-01) must create:

- [ ] `test/support/fixtures/metering.ex` — covers TEST-01
- [ ] `test/lattice_stripe/billing/guards_test.exs` — partial, GUARD-01 8-case matrix (expanded in Plan 20-03)
- [ ] `test/lattice_stripe/billing/meter/default_aggregation_test.exs` — covers METER-08 (sub-module)
- [ ] `test/lattice_stripe/billing/meter/customer_mapping_test.exs` — covers METER-08 (sub-module)
- [ ] `test/lattice_stripe/billing/meter/value_settings_test.exs` — covers METER-08 (sub-module)
- [ ] `test/lattice_stripe/billing/meter/status_transitions_test.exs` — covers METER-08 (sub-module)
- [ ] `test/lattice_stripe/billing/meter_test.exs` — covers METER-01..09 (created in Plan 20-03)
- [ ] `test/lattice_stripe/billing/meter_event_test.exs` — covers EVENT-01..03, EVENT-05 (Plan 20-04)
- [ ] `test/lattice_stripe/billing/meter_event_adjustment_test.exs` — covers EVENT-04 (Plan 20-04)
- [ ] `test/integration/meter_integration_test.exs` — covers TEST-05 (Plan 20-05)
- [ ] `test/integration/meter_event_integration_test.exs` — covers TEST-05 (Plan 20-05)
- [ ] `test/integration/meter_event_adjustment_integration_test.exs` — covers TEST-05 (Plan 20-05)
- [ ] `guides/metering.md` — covers DOCS-01 (Plan 20-06)

Framework install: ExUnit is stdlib, no install needed. Mox already in `mix.exs`. No new test infrastructure required.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | API key auth unchanged from v1.0 — no new auth flows |
| V3 Session Management | No | Stateless HTTP, no session management |
| V4 Access Control | No | Stripe API key controls access; LatticeStripe is client-side only |
| V5 Input Validation | Yes | GUARD-01 validates `value_settings` shape; `Resource.require_param!/3` validates required fields |
| V6 Cryptography | No | No new cryptographic operations; webhook HMAC unchanged from v1.0 |

### Known Threat Patterns for Metering Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| PII leakage via `MeterEvent.payload` in logs | Information Disclosure | Allowlist Inspect implementation (D-02) hides `:payload`; guide documents `IO.inspect(event, structs: false)` as opt-in debugging only |
| Customer ID exposure via `identifier` in logs | Information Disclosure | Guide note: if `identifier` encodes customer IDs, filter from production log aggregation |
| Double-billing via idempotency misuse | Tampering | Two-layer idempotency documented (EVENT-02, GUARD-02); guide "always set both" rule |
| Silent data loss via archived_meter without monitoring | Denial of Service (billing data) | `{:error, %Error{code: "archived_meter"}}` is synchronous and pattern-matchable; documented in guide + `deactivate/3` `@doc` |
| Invalid params bypassing GUARD-01 via atom keys | Tampering | D-01 documents atom-key bypass explicitly; guard only reads string keys matching Stripe's wire format |

---

## Open Questions (RESOLVED)

1. **`MeterEventAdjustment.Cancel` — separate file or inline?**
   - What we know: `Cancel` is a single-field struct. The CONTEXT.md D-04 says "nested typed struct" but doesn't specify file placement.
   - What's unclear: Whether `Cancel` should live in `meter_event_adjustment/cancel.ex` (separate file) or as a sub-module at the bottom of `meter_event_adjustment.ex`.
   - Recommendation: Separate file at `lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex` for consistency with the `Meter.*` sub-module pattern. Claude's discretion per CONTEXT.md.

2. **stripe-mock Wave 0 probe script format**
   - What we know: Phase 17 used `scripts/verify_stripe_mock_reject.exs` as a standalone probe script.
   - What's unclear: Whether Plan 20-01 probe should be a standalone `.exs` script or inline ExUnit tests.
   - Recommendation: Follow Phase 17 pattern — create `scripts/verify_metering_endpoints.exs` with 3 probe sections (meters, meter_events, meter_event_adjustments) + deactivate/reactivate; record results in `20-VALIDATION.md`.

3. **`guards_test.exs` — new file or add to existing?**
   - What we know: `lib/lattice_stripe/billing/guards.ex` is a module with 2 functions post-Phase 20; no test file currently exists for it.
   - What's unclear: Whether the proration guard tests live somewhere or were tested indirectly.
   - Recommendation: Create `test/lattice_stripe/billing/guards_test.exs` as a new dedicated test module covering both `check_proration_required/2` and `check_meter_value_settings!/1`. The 8-case D-01 matrix belongs here.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `MeterEvent.payload` values are strings in Stripe's response (e.g., `"value" => "1"` not `"value" => 1`) | Fixture Shapes | Fixture would need updating; from_map/1 is passthrough so no struct code impact |
| A2 | `MeterEventAdjustment.status` field values are `"pending"` and `"complete"` (inferred from Stripe object docs) | Fixture Shapes | Known status atoms in the struct may be wrong; safe because status is passthrough string |
| A3 | `Meter.update/4` does NOT accept `event_time_window` as a mutable field (inferred as create-only) | Stripe API Endpoints Reference | If Stripe allows updating `event_time_window`, the docs should mention it |

If this table is non-empty: claims A1-A3 are low-risk (`[ASSUMED]` from training knowledge + prior research, not newly verified in this session). They affect fixtures and typedocs only, not structural implementation decisions. All implementation decisions are covered by locked CONTEXT.md decisions.

---

## Sources

### Primary (HIGH confidence)

- `.planning/research/FEATURES.md` (2026-04-13) — Meter/MeterEvent/MeterEventAdjustment feature categorization, formula semantics, idempotency two-layer system
- `.planning/research/PITFALLS.md` (2026-04-13) — 7 metering pitfalls with exact error codes, webhook behavior, 24h/35-day windows
- `.planning/research/ARCHITECTURE.md` (2026-04-13) — module namespacing, file manifest, nested struct pattern selection, fixture structure
- `.planning/research/STACK.md` (2026-04-13) — zero-new-deps verdict, stripe-mock OpenAPI coverage, API version compatibility
- `.planning/phases/20-billing-metering/20-CONTEXT.md` (2026-04-14) — 7 locked decisions D-01..D-07 (authoritative for this phase)
- `lib/lattice_stripe/account/capability.ex` — `status_atom/1` pattern + `@known_fields + :extra` nested struct pattern [VERIFIED: read in session]
- `lib/lattice_stripe/invoice/status_transitions.ex` — simple typed struct pattern (no extra) [VERIFIED: read in session]
- `lib/lattice_stripe/billing/guards.ex` — existing `check_proration_required/2` — where new guard is added [VERIFIED: read in session]
- `lib/lattice_stripe/account.ex` — CRUDL + lifecycle verb pattern [VERIFIED: read in session]
- `lib/lattice_stripe/customer.ex:467-489` — Inspect allowlist pattern [VERIFIED: read in session]
- `lib/lattice_stripe/resource.ex` — `unwrap_singular`, `unwrap_list`, `unwrap_bang!`, `require_param!` [VERIFIED: read in session]
- `test/integration/account_integration_test.exs` — integration test structure [VERIFIED: read in session]
- `test/support/test_helpers.ex` — `test_client/1`, `test_integration_client/0` [VERIFIED: read in session]
- `test/support/fixtures/subscription.ex` — fixture module pattern [VERIFIED: read in session]
- `mix.exs` — current `groups_for_modules` layout, deps block [VERIFIED: read in session]

### Secondary (MEDIUM confidence)

- `.planning/phases/20-billing-metering/20-DISCUSSION-LOG.md` (2026-04-14) — 4 parallel advisor research agent outputs, gray area resolution rationale
- Stripe Billing Meter API Reference: https://docs.stripe.com/api/billing/meter — referenced by FEATURES.md and PITFALLS.md (not re-fetched in this session)
- Stripe Recording Usage API: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api — timestamp windows, error codes

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from mix.exs; no new deps required
- Architecture: HIGH — 6-plan wave structure locked in CONTEXT.md; all file paths from ARCHITECTURE.md
- Stripe API shapes: HIGH — FEATURES.md verified from Stripe docs 2026-04-13; OpenAPI spec confirmed in STACK.md
- Pitfalls: HIGH — PITFALLS.md verified from Stripe docs + codebase patterns
- Fixture shapes: MEDIUM — mostly derived from prior research; Assumptions A1-A3 are low-risk string/status fields
- ExDoc config: HIGH — exact `groups_for_modules` snippet in ARCHITECTURE.md + mix.exs verified

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (30 days; Stripe's metering API is stable, no breaking changes expected in this window)
