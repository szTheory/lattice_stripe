# Architecture Patterns

**Domain:** Elixir API SDK / Stripe client library
**Researched:** 2026-04-13 (v1.1 update — metering + portal integration)
**Scope:** v1.1 addition of `Billing.Meter`, `Billing.MeterEvent`, `Billing.MeterEventAdjustment`, and `BillingPortal.Session` into the existing v1.0 architecture.

---

## v1.1 Integration Overview

Three new Stripe resource families slot into the existing architecture without any changes to the foundation layers (Client, Transport, Request, Response, Error, Telemetry, Webhook). Every new module follows the v1.0 resource module pattern exactly:

```
defstruct + @known_fields + from_map/1 (drops unknowns into :extra)
     |
     v
Resource.unwrap_singular/2 or unwrap_list/2
     |
     v
Client.request/2 (unchanged — all opts threading already in place)
```

The only architectural additions are new files in `lib/lattice_stripe/billing/` and a new `lib/lattice_stripe/billing_portal/` directory.

---

## Q1: Module Namespacing

### Billing.* — existing namespace, new siblings

`LatticeStripe.Billing.*` already exists in v1.0 but only contains `LatticeStripe.Billing.Guards` (internal, `@moduledoc false`). The three metering modules are the first **public** Billing-namespaced resources.

**Resolved namespace layout:**

```
lib/lattice_stripe/billing/
  guards.ex                          # EXISTING — internal proration guard
  meter.ex                           # NEW — Billing.Meter resource module
  meter/
    default_aggregation.ex           # NEW — nested typed struct
    customer_mapping.ex              # NEW — nested typed struct
    value_settings.ex                # NEW — nested typed struct
    status_transitions.ex            # NEW — nested typed struct
  meter_event.ex                     # NEW — Billing.MeterEvent resource module
  meter_event_adjustment.ex          # NEW — Billing.MeterEventAdjustment resource module
```

There are no sibling resource modules in `LatticeStripe.Billing.*` in v1.0. The existing billing resources (`Invoice`, `Subscription`, `SubscriptionItem`, `SubscriptionSchedule`) live at `LatticeStripe.Invoice`, `LatticeStripe.Subscription`, etc. — NOT under `LatticeStripe.Billing.*`. The `billing/` directory in v1.0 exists only for the internal `Guards` module.

This means the metering modules are the first public inhabitants of the `Billing` namespace. That is appropriate because Stripe's metering API lives under `/v1/billing/meters` and `/v1/billing/meter_events` — the URL prefix maps directly to the module namespace.

**Stripe URL → Module mapping:**

| Stripe URL | Module |
|------------|--------|
| `/v1/billing/meters` | `LatticeStripe.Billing.Meter` |
| `/v1/billing/meter_events` | `LatticeStripe.Billing.MeterEvent` |
| `/v1/billing/meter_event_adjustments` | `LatticeStripe.Billing.MeterEventAdjustment` |
| `/v1/billing_portal/sessions` | `LatticeStripe.BillingPortal.Session` |

### BillingPortal — new top-level namespace

**Decision: `LatticeStripe.BillingPortal` is a new top-level namespace, NOT nested under `Billing`.**

Rationale:
1. Stripe's API uses `/v1/billing_portal/` as a distinct URL prefix, separate from `/v1/billing/`. These are different Stripe product areas.
2. The v1.0 precedent is `LatticeStripe.Checkout.Session` — a namespace created solely for `Checkout.Session`, with `Checkout.LineItem` as a companion. `BillingPortal` follows the same pattern: a namespace that currently holds only `Session`, with `Configuration` as the future sibling (deferred to v1.2+).
3. `LatticeStripe.BillingPortal` matches the downstream Accrue usage (`Accrue.Billing.create_portal_session/2` calling `LatticeStripe.BillingPortal.Session.create/3`) — the module name reads naturally in user code.
4. Mixing billing_portal resources under `Billing.*` would confuse the namespace: `LatticeStripe.Billing.Portal.Session` looks like a sub-resource of a Billing family, not a standalone portal session.

**New directory:**

```
lib/lattice_stripe/billing_portal/
  session.ex                         # NEW — BillingPortal.Session resource module
  session/
    flow_data.ex                     # NEW — nested typed struct
```

### mix.exs groups_for_modules additions

Two new groups must be added to the nine-group ExDoc layout. Current groups: `Client & Configuration`, `Payments`, `Checkout`, `Billing`, `Connect`, `Webhooks`, `Telemetry`, `Testing`, `Internals`.

**Add two groups:**

```elixir
# After the existing Billing group:
"Billing Metering": [
  LatticeStripe.Billing.Meter,
  LatticeStripe.Billing.Meter.DefaultAggregation,
  LatticeStripe.Billing.Meter.CustomerMapping,
  LatticeStripe.Billing.Meter.ValueSettings,
  LatticeStripe.Billing.Meter.StatusTransitions,
  LatticeStripe.Billing.MeterEvent,
  LatticeStripe.Billing.MeterEventAdjustment
],
"Customer Portal": [
  LatticeStripe.BillingPortal.Session,
  LatticeStripe.BillingPortal.Session.FlowData
],
```

This keeps the existing `Billing` group (Invoice, Subscription, SubscriptionItem, SubscriptionSchedule) unchanged and groups the metering and portal resources in their own sections.

---

## Q2: Nested Typed Struct Structure

The rule established in v1.0 (Phase 14/17 pattern) is: promote a field to a typed nested struct only when callers need to pattern-match on its sub-fields. Raw maps are left as `map() | nil`. The `@known_fields` + `extra: %{}` pattern applies to nested structs that have room for unknown fields.

Two sub-patterns exist in v1.0:

- **Simple typed struct, no `extra`:** `Invoice.StatusTransitions` — all fields are known Unix timestamps, no unknown field risk. Defined as `defstruct` with no `extra` field. `from_map/1` returns `nil` for nil input.
- **Complex nested struct with `extra`:** `Subscription.CancellationDetails`, `Account.Capability` — fields can grow (Stripe adds sub-fields), so `@known_fields` + `extra: %{}` is used. `from_map/1` uses `Map.split/2`.

### Meter nested structs (Phase 20)

**`LatticeStripe.Billing.Meter.DefaultAggregation`**

Accrue reads `default_aggregation.formula` to display usage configuration. Promote to typed struct.

```
File: lib/lattice_stripe/billing/meter/default_aggregation.ex
Fields: formula (string — "sum" | "count" | "last")
Pattern: simple typed struct, no extra (only one known sub-field from Stripe spec)
from_map: returns nil for nil input
```

**`LatticeStripe.Billing.Meter.CustomerMapping`**

Accrue reads `customer_mapping.event_payload_key` and `customer_mapping.type`. Promote to typed struct.

```
File: lib/lattice_stripe/billing/meter/customer_mapping.ex
Fields: event_payload_key (string), type (string — "by_id")
Pattern: @known_fields + extra: %{} (Stripe may add mapping types)
from_map: returns nil for nil input
```

**`LatticeStripe.Billing.Meter.ValueSettings`**

Accrue reads `value_settings.event_payload_key`. Promote to typed struct.

```
File: lib/lattice_stripe/billing/meter/value_settings.ex
Fields: event_payload_key (string)
Pattern: simple typed struct, no extra (single known sub-field)
from_map: returns nil for nil input
```

**`LatticeStripe.Billing.Meter.StatusTransitions`**

Accrue does not directly read sub-fields, but the `StatusTransitions` name echoes `Invoice.StatusTransitions` — a strong v1.0 precedent. Promote to typed struct to match the existing naming convention and to give callers access to `deactivated_at`.

```
File: lib/lattice_stripe/billing/meter/status_transitions.ex
Fields: deactivated_at (integer | nil)
Pattern: simple typed struct, no extra (only one known field currently)
from_map: returns nil for nil input
Precedent: lib/lattice_stripe/invoice/status_transitions.ex (exact same shape)
```

### BillingPortal.Session nested struct (Phase 21)

**`LatticeStripe.BillingPortal.Session.FlowData`**

Accrue constructs `flow_data` on the way in (as a request param) and pattern-matches on `session.flow` on the way back (to confirm the deep-link flow type). Promote to typed struct.

```
File: lib/lattice_stripe/billing_portal/session/flow_data.ex
Fields: type (string — "subscription_cancel" | "payment_method_update" | etc.),
        subscription_cancel (map | nil), subscription_update (map | nil),
        payment_method_update (map | nil), after_completion (map | nil)
Pattern: @known_fields + extra: %{} (flow types can expand)
from_map: returns nil for nil input
```

The sub-flow maps (`subscription_cancel`, `payment_method_update`, etc.) are left as raw `map() | nil` — Accrue does not pattern-match their internal structure, and Stripe's spec shows they have varied shapes per flow type.

### Fields left as raw maps (not promoted)

These Meter fields are not promoted to typed structs because Accrue does not pattern-match their sub-fields and they are not named sub-objects in Stripe's stable schema:

- `metadata` — always left as `map() | nil` across all v1.0 resources
- `event_time_window` — string value, not a nested object

---

## Q3: Fixtures and Test Helpers

### What can be reused from v1.0

**`test/support/test_helpers.ex`** — fully reusable. `test_client/1` and `test_integration_client/0` are unchanged. New integration tests for metering and portal use `test_integration_client()` exactly as account and subscription integration tests do.

**Pattern from `test/support/fixtures/subscription.ex`** — the `basic(overrides \\ %{})` + named variants pattern is the direct model for new fixture modules.

**Pattern from `test/support/fixtures/checkout_session.ex`** — the `Checkout.Session` fixture demonstrates Session-specific patterns (create-only workflows, `url` field) applicable to `BillingPortal.Session`.

**`test/support/fixtures/customer.ex`** — used as-is in metering integration tests: a meter requires a customer to send events through. The existing `LatticeStripe.Test.Fixtures.Customer` can be used directly in integration test `setup` blocks.

### New fixtures to build

**`test/support/fixtures/metering.ex`** — single new file for all three metering resources:

```elixir
defmodule LatticeStripe.Test.Fixtures.Metering do
  @moduledoc false

  # Canonical Meter response fixture (active status, full nested struct coverage)
  def meter(overrides \\ %{}) ...

  # Meter with inactive status (post-deactivate shape)
  def meter_inactive(overrides \\ %{}) ...

  # MeterEvent create response fixture (thin ack shape)
  def meter_event(overrides \\ %{}) ...

  # MeterEventAdjustment create response fixture
  def meter_event_adjustment(overrides \\ %{}) ...
end
```

Rationale for a single file: Meter, MeterEvent, and MeterEventAdjustment are bundled in Phase 20 (decision D1/D2). Separating them into three fixture files adds overhead without benefit — they always appear together in integration tests.

**`test/support/fixtures/billing_portal.ex`** — new file for portal resources:

```elixir
defmodule LatticeStripe.Test.Fixtures.BillingPortal do
  @moduledoc false

  # Canonical BillingPortal.Session fixture (basic create response)
  def session(overrides \\ %{}) ...

  # Session with flow_data echoed back (deep-link flow variant)
  def session_with_flow(overrides \\ %{}) ...
end
```

### No existing portal fixtures

There is no existing `billing_portal_session.ex` or similar in `test/support/fixtures/`. The portal is entirely new in v1.1. The `checkout_session.ex` fixture is the closest structural analogue (Session, create-only, returns `url`).

---

## Q4: Build Order Within Each Phase

The Phase 17 (Connect) plan structure is the primary precedent. Its six-plan wave matches the v1.1 brief exactly. Confirmed build order:

**Phase 20 (Billing.Meter + MeterEvent + MeterEventAdjustment):**

```
Plan 20-01  Wave 0 bootstrap
            - Create test/support/fixtures/metering.ex with canonical Meter, MeterEvent,
              MeterEventAdjustment maps
            - stripe-mock probe: verify /v1/billing/meters, /v1/billing/meter_events,
              /v1/billing/meter_event_adjustments all respond (some stripe-mock versions
              may not have the metering endpoints — document if any endpoint is absent
              and use fixture-only unit tests for that endpoint)
            - Dependency: none

Plan 20-02  Nested structs (Meter sub-modules)
            - lib/lattice_stripe/billing/meter/default_aggregation.ex
            - lib/lattice_stripe/billing/meter/customer_mapping.ex
            - lib/lattice_stripe/billing/meter/value_settings.ex
            - lib/lattice_stripe/billing/meter/status_transitions.ex
            - Unit tests: from_map/1 round-trips, nil guard, extra field split
            - Dependency: fixtures from 20-01 (for from_map test inputs)

Plan 20-03  Billing.Meter resource module
            - lib/lattice_stripe/billing/meter.ex
            - create/3, retrieve/3, update/4, list/3, stream/3
            - deactivate/3, reactivate/3 (POST to /v1/billing/meters/:id/deactivate etc.)
            - Bang variants for all
            - Struct embeds nested structs from 20-02 via from_map/1
            - Unit tests using Mox + fixtures from 20-01
            - Dependency: nested structs from 20-02

Plan 20-04  Billing.MeterEvent + Billing.MeterEventAdjustment
            - lib/lattice_stripe/billing/meter_event.ex (create/3 only)
            - lib/lattice_stripe/billing/meter_event_adjustment.ex (create/3 only)
            - Both minimal structs (no nested sub-structs needed)
            - idempotency_key: and stripe_account: opts threaded through (standard Client opts)
            - Unit tests using Mox + fixtures from 20-01
            - Dependency: 20-01 fixtures only (no dependency on 20-02/03)
              Note: 20-04 CAN be built in parallel with 20-03 if desired

Plan 20-05  Integration tests
            - test/integration/meter_integration_test.exs
            - Lifecycle: create meter → report event → adjust → deactivate → list
            - Verifies: struct shapes, id prefixes (mtr_...), status transitions
            - Depends on: 20-03 and 20-04 both complete

Plan 20-06  Guide + ExDoc
            - guides/metering.md (new)
            - mix.exs groups_for_modules: add "Billing Metering" group
            - mix.exs extras: add guides/metering.md
            - Cross-link from guides/subscriptions.md or guides/getting-started.md
            - Dependency: 20-03 and 20-04 complete (need real module docs to link)
```

**Phase 21 (BillingPortal.Session):**

```
Plan 21-01  Wave 0 bootstrap
            - Create test/support/fixtures/billing_portal.ex
            - stripe-mock probe: verify /v1/billing_portal/sessions responds to POST
            - Dependency: none

Plan 21-02  Nested structs (Session.FlowData)
            - lib/lattice_stripe/billing_portal/session/flow_data.ex
            - Unit tests: from_map/1, nil guard, extra field split
            - Dependency: fixtures from 21-01

Plan 21-03  BillingPortal.Session resource module
            - lib/lattice_stripe/billing_portal/session.ex
            - create/3 and create!/3 only — no retrieve, list, update, delete
            - Resource.require_param!(params, "customer", ...) guard (matches Checkout.Session "mode" guard pattern)
            - Embeds FlowData via from_map/1 on the `flow` field in the response
            - Unit tests using Mox + fixtures from 21-01
            - Dependency: 21-02

Plan 21-04  Integration test + guide
            - test/integration/billing_portal_session_integration_test.exs
            - Test: create session returns {:ok, %Session{url: url}} with non-empty url
            - guides/customer-portal.md (new or extend existing)
            - mix.exs groups_for_modules: add "Customer Portal" group
            - mix.exs extras: add guides/customer-portal.md
            - Dependency: 21-03 complete
```

**Critical path dependency:**
- Within Phase 20: 20-02 must precede 20-03 (Meter resource embeds nested structs). 20-01 must precede 20-02 and 20-04. 20-03 and 20-04 can be parallelized. 20-05 requires both 20-03 and 20-04.
- Within Phase 21: strictly sequential (21-01 → 21-02 → 21-03 → 21-04).
- Cross-phase: Phase 21 has no code dependency on Phase 20. Planning can begin immediately after Phase 20 scope is locked.

---

## Q5: MeterEventAdjustment as Sibling vs Nested

**Decision: `LatticeStripe.Billing.MeterEventAdjustment` is a sibling module, NOT nested under `MeterEvent`.**

Rationale:

1. **Stripe API position.** The endpoint is `/v1/billing/meter_event_adjustments` — a separate top-level resource under `/v1/billing/`, not a sub-resource of `/v1/billing/meter_events/:id/adjustments`. Stripe's object is `"billing.meter_event_adjustment"`, distinct from `"billing.meter_event"`. The API shape mirrors other sibling corrections (e.g., `TransferReversal` is a sibling of `Transfer`, not `Transfer.Reversal`).

2. **v1.0 precedent.** `LatticeStripe.TransferReversal` lives at `lib/lattice_stripe/transfer_reversal.ex` as a sibling of `LatticeStripe.Transfer`, not `LatticeStripe.Transfer.Reversal`. MeterEventAdjustment follows the same pattern.

3. **Module usage clarity.** `LatticeStripe.Billing.MeterEventAdjustment.create/3` reads more clearly than `LatticeStripe.Billing.MeterEvent.Adjustment.create/3`. The latter implies it's a namespace for a sub-resource type; the former is an independent operation.

4. **File placement.** `lib/lattice_stripe/billing/meter_event_adjustment.ex` alongside `lib/lattice_stripe/billing/meter_event.ex`. No sub-directory needed.

5. **Bundle scope.** Both live in Plan 20-04 per the locked decision D2 — bundled together in one plan, one file per resource.

---

## New vs Modified Files Summary

### Phase 20 — new files

| File | Type |
|------|------|
| `lib/lattice_stripe/billing/meter.ex` | New resource module |
| `lib/lattice_stripe/billing/meter/default_aggregation.ex` | New nested struct |
| `lib/lattice_stripe/billing/meter/customer_mapping.ex` | New nested struct |
| `lib/lattice_stripe/billing/meter/value_settings.ex` | New nested struct |
| `lib/lattice_stripe/billing/meter/status_transitions.ex` | New nested struct |
| `lib/lattice_stripe/billing/meter_event.ex` | New resource module |
| `lib/lattice_stripe/billing/meter_event_adjustment.ex` | New resource module |
| `test/support/fixtures/metering.ex` | New fixture module |
| `test/integration/meter_integration_test.exs` | New integration test |
| `guides/metering.md` | New guide |

### Phase 20 — modified files

| File | Modification |
|------|--------------|
| `mix.exs` | Add `"Billing Metering"` group to `groups_for_modules`; add `guides/metering.md` to `extras` |

### Phase 21 — new files

| File | Type |
|------|------|
| `lib/lattice_stripe/billing_portal/session.ex` | New resource module |
| `lib/lattice_stripe/billing_portal/session/flow_data.ex` | New nested struct |
| `test/support/fixtures/billing_portal.ex` | New fixture module |
| `test/integration/billing_portal_session_integration_test.exs` | New integration test |
| `guides/customer-portal.md` | New guide (or extend existing) |

### Phase 21 — modified files

| File | Modification |
|------|--------------|
| `mix.exs` | Add `"Customer Portal"` group to `groups_for_modules`; add `guides/customer-portal.md` to `extras` |

---

## Key Architectural Decisions (v1.1)

| Decision | Rationale | Precedent |
|----------|-----------|-----------|
| `BillingPortal` as new top-level namespace, not nested under `Billing` | Stripe uses `/v1/billing_portal/` as distinct prefix; matches `Checkout` namespace pattern | `LatticeStripe.Checkout.Session` in v1.0 |
| `MeterEventAdjustment` as sibling of `MeterEvent`, not nested | Stripe API is a top-level resource, not a sub-resource; sibling pattern for corrections | `LatticeStripe.TransferReversal` in v1.0 |
| All four Meter nested structs promoted, even `StatusTransitions` | Matches `Invoice.StatusTransitions` naming convention; gives callers `deactivated_at` access | `lib/lattice_stripe/invoice/status_transitions.ex` |
| `FlowData` uses `@known_fields + extra` (not simple typed struct) | Flow types can expand; Stripe regularly adds portal flow types | `Subscription.CancellationDetails` pattern |
| Single `metering.ex` fixture file for all three metering resources | D1/D2 bundles them; they appear together in integration tests | `lib/lattice_stripe/billing/guards.ex` cohesion |
| `Resource.require_param!` guard on `BillingPortal.Session.create` for `"customer"` | `customer` is the only required param; fail fast pre-network | `Checkout.Session` requires `"mode"` guard |
| `deactivate/3` and `reactivate/3` as explicit verbs, not `update(params: %{"status" => "inactive"})` | Stripe exposes these as distinct POST endpoints; explicit verb philosophy | `Payout.cancel/4`, `Account.reject/4` in v1.0 |
| No new foundation layer changes | All infrastructure (Client, Transport, Request, Response, Error, Telemetry, Retry) unchanged | Entire v1.0 foundation |

---

## Foundation Architecture (Unchanged from v1.0)

The v1.0 layered architecture is unchanged. New resource modules slot into the Public API Layer without touching any lower layer:

```
+---------------------------------------------------------------+
|  PUBLIC API LAYER (new modules slot here)                     |
|  Billing.Meter, Billing.MeterEvent, Billing.MeterEventAdj,   |
|  BillingPortal.Session — each builds Request structs,         |
|  delegates to Client, unwraps with Resource helpers           |
+---------------------------------------------------------------+
        |
        v
+---------------------------------------------------------------+
|  CLIENT LAYER — LatticeStripe.Client (UNCHANGED)             |
|  idempotency_key:, stripe_account:, expand: opts already      |
|  threaded through; metering and portal get them for free      |
+---------------------------------------------------------------+
        |
        v
+---------------------------------------------------------------+
|  HTTP / TRANSPORT LAYER — UNCHANGED                          |
+---------------------------------------------------------------+
```

Telemetry spans emit automatically at the Client level for all new resources — no per-resource telemetry additions needed.

---

## Sources

- `lib/lattice_stripe/billing/guards.ex` — confirms existing `Billing` namespace is internal-only in v1.0
- `lib/lattice_stripe/checkout/session.ex` — direct precedent for `BillingPortal.Session` namespace and create-only pattern
- `lib/lattice_stripe/invoice/status_transitions.ex` — simple typed struct pattern (no `extra` field)
- `lib/lattice_stripe/subscription/cancellation_details.ex` — `@known_fields + extra` nested struct pattern
- `lib/lattice_stripe/account/capability.ex` — `@known_fields + extra` with atom list variant
- `lib/lattice_stripe/transfer_reversal.ex` — sibling-not-nested pattern for `MeterEventAdjustment` decision
- `lib/lattice_stripe/payout.ex` — lifecycle verb pattern (`cancel/4`, `reverse/4`) for `deactivate/3`/`reactivate/3`
- `mix.exs` — nine-group ExDoc layout to extend with two new groups
- `test/support/fixtures/checkout_session.ex` — fixture module structure for BillingPortal fixtures
- `test/support/fixtures/subscription.ex` — `basic/1 + named variants` fixture pattern
- `test/integration/account_integration_test.exs` — integration test structure (stripe-mock guard, setup_all, shape assertions)
- `.planning/v1.1-accrue-context.md` — locked decisions D1-D5, phase structure, Accrue field access requirements
