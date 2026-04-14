---
phase: 21-customer-portal
plan: "03"
subsystem: billing_portal
tags: [session, guards, inspect-masking, portal, tdd, portal-resource]
dependency_graph:
  requires:
    - 21-01
    - 21-02
  provides:
    - lib/lattice_stripe/billing_portal/session.ex
    - lib/lattice_stripe/billing_portal/guards.ex
  affects:
    - test/lattice_stripe/billing_portal/session_test.exs
    - test/lattice_stripe/billing_portal/guards_test.exs
tech_stack:
  added: []
  patterns:
    - "VERBATIM D-01 pattern-match clause dispatch on flow_data.type (PORTAL-GUARD-01)"
    - "VERBATIM D-03 defimpl Inspect allowlist masking (T-21-05 mitigate)"
    - "Resource.require_param! + Guards pre-flight before network call"
    - "FlowData.from_map/1 used in Session.from_map/1 for nested decode"
    - "@known_fields + Map.drop extra-capture pattern (mirrors MeterEventAdjustment)"
key_files:
  created:
    - lib/lattice_stripe/billing_portal/session.ex
    - lib/lattice_stripe/billing_portal/guards.ex
  modified:
    - test/lattice_stripe/billing_portal/session_test.exs
    - test/lattice_stripe/billing_portal/guards_test.exs
decisions:
  - "Guards module implemented VERBATIM from CONTEXT.md D-01 — not a single line altered"
  - "Inspect impl placed after Session module end in the same file (session.ex) — consistent with Checkout.Session precedent"
  - "from_map/1 has nil-safe two-clause shape (nil → nil, is_map → struct) matching FlowData sub-module template"
  - "Non-map flow_data value (e.g. atom) passes via catchall → :ok — HTTP layer surfaces Stripe's 400"
metrics:
  duration: ~3 minutes
  completed: 2026-04-14T20:03:08Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 2
---

# Phase 21 Plan 03: Session Resource + Guards Summary

**One-liner:** BillingPortal.Session create-only resource with Guards pre-flight validator (PORTAL-GUARD-01) and Inspect allowlist masking `:url` and `:flow` (D-03/T-21-05), closing all PORTAL-01/02/04/05/06 requirements.

---

## What Was Built

### Task 1 — BillingPortal.Guards module (RED `daf573c`, GREEN `0aa4df1`)

`LatticeStripe.BillingPortal.Guards` at `lib/lattice_stripe/billing_portal/guards.ex` with `@moduledoc false`.

Implemented VERBATIM from CONTEXT.md D-01. Public surface: `check_flow_data!/1 :: map() :: :ok`.

**Dispatch shape (PORTAL-GUARD-01):**

- `payment_method_update` — no sub-fields required, passes immediately
- `subscription_cancel` — requires `subscription_cancel.subscription` non-empty binary
- `subscription_update` — requires `subscription_update.subscription` non-empty binary
- `subscription_update_confirm` — requires `subscription_update_confirm.subscription` (binary) AND `subscription_update_confirm.items` (non-empty list)
- Unknown binary type — raises with all 4 valid types enumerated
- Malformed flow_data (no type key) — raises `"must contain a \"type\" key"`
- Non-map flow_data value — passes via catchall (HTTP layer surfaces Stripe's 400)

All 13 guard tests green including function-name prefix assertion on every raise case.

### Task 2 — Session resource module + Inspect masking (RED `f459036`, GREEN `461f2e0`)

`LatticeStripe.BillingPortal.Session` at `lib/lattice_stripe/billing_portal/session.ex`.

**Module contents:**

1. `@moduledoc` — portal overview, flow type summary, usage examples, security note on `:url`, portal configuration deferred to v1.2+.
2. `@known_fields ~w(id object customer url return_url created livemode locale configuration on_behalf_of flow)` — all 11 PORTAL-05 fields.
3. `@type t` + `defstruct` with 11 fields + `extra: %{}`.
4. `create/3` — `Resource.require_param!(params, "customer", ...)` → `Guards.check_flow_data!(params)` → `%Request{method: :post, path: "/v1/billing_portal/sessions", ...}` → `Client.request/2` → `Resource.unwrap_singular(&from_map/1)`.
5. `create!/3` — bang variant via `Resource.unwrap_bang!()`.
6. `from_map/1` — nil-safe two-clause; `flow` decoded via `FlowData.from_map(map["flow"])`; extra via `Map.drop(map, @known_fields)`.
7. `defimpl Inspect` — VERBATIM from CONTEXT.md D-03 (full comment block preserved). Visible: `id, object, livemode, customer, configuration, on_behalf_of, created, return_url, locale`. Hidden: `:url` (T-21-05), `:flow` (T-21-10).

No retrieve/list/update/delete functions (PORTAL-02 — Stripe API does not expose them).

All 47 billing_portal tests green (29 session + guards + 18 flow_data).

---

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (guards) | `daf573c` | `test(21-03): add failing guard matrix tests for BillingPortal.Guards (RED)` |
| GREEN (guards) | `0aa4df1` | `feat(21-03): implement BillingPortal.Guards with check_flow_data!/1 (PORTAL-04)` |
| RED (session) | `f459036` | `test(21-03): add failing session resource tests (RED)` |
| GREEN (session) | `461f2e0` | `feat(21-03): implement BillingPortal.Session resource + Inspect masking (PORTAL-01/02/05/06)` |
| REFACTOR | — | No refactor needed; both modules are minimal and clean |

---

## Requirements Closed

| Requirement | Description | Closed By |
|-------------|-------------|-----------|
| PORTAL-01 | `Session.create/3` → `{:ok, %Session{}}` | Task 2 GREEN |
| PORTAL-02 | No retrieve/list/update/delete | Task 2 GREEN (by absence) |
| PORTAL-04 | Pre-flight guard for `flow_data` sub-fields | Task 1 GREEN |
| PORTAL-05 | `from_map/1` decodes all 11 fields + flow | Task 2 GREEN |
| PORTAL-06 | `stripe_account:` opt threads as `Stripe-Account` header | Task 2 GREEN |

---

## Deviations from Plan

None — plan executed exactly as written. Both modules implemented VERBATIM from CONTEXT.md D-01 and D-03 respectively.

---

## Known Stubs

None. All modules fully implemented with real assertions. No `@tag :skip` remaining in `guards_test.exs` or `session_test.exs`.

---

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: Information Disclosure (T-21-05 MITIGATED) | `lib/lattice_stripe/billing_portal/session.ex` | `defimpl Inspect` hides `:url` — single-use bearer credential masked from Logger/APM/crash dumps. Tested via `refute inspect(session) =~ session.url`. |
| threat_flag: Information Disclosure (T-21-10 MITIGATED) | `lib/lattice_stripe/billing_portal/session.ex` | `defimpl Inspect` hides `:flow` — prevents `after_completion.redirect` / `retention.coupon_offer` leakage in default Inspect output. |
| threat_flag: Elevation of Privilege (T-21-06 MITIGATED) | `lib/lattice_stripe/billing_portal/guards.ex` | Unknown `flow_data.type` strings structurally impossible to forward — binary catchall raises before network call. Tested via guard matrix case 10. |
| threat_flag: Spoofing (T-21-07 MITIGATED) | `lib/lattice_stripe/billing_portal/session.ex` | `stripe_account:` opt threading verified via Mox header assertion. `Client.request/2` primitive adds `Stripe-Account` header from opts. |

---

## Self-Check: PASSED

Files verified:
- `lib/lattice_stripe/billing_portal/guards.ex` — FOUND
- `lib/lattice_stripe/billing_portal/session.ex` — FOUND
- `test/lattice_stripe/billing_portal/guards_test.exs` — FOUND (13 tests, 0 failures)
- `test/lattice_stripe/billing_portal/session_test.exs` — FOUND (16 tests, 0 failures)

Commits verified:
- `daf573c` — RED: guards tests
- `0aa4df1` — GREEN: guards module
- `f459036` — RED: session tests
- `461f2e0` — GREEN: session module
