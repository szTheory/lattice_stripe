---
phase: 16-subscription-schedules
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/16-subscription-schedules/16-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 2
skipped: 1
status: partial
---

# Phase 16: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/16-subscription-schedules/16-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 2
- Skipped: 1

## Fixed Issues

### IN-01: `decode_phases/1` and `decode_items/1` silently pass through non-list, non-nil values

**Files modified:** `lib/lattice_stripe/subscription_schedule.ex`, `lib/lattice_stripe/subscription_schedule/phase.ex`
**Commit:** 9cba671
**Applied fix:** Replaced the pass-through fallthrough clause in `decode_phases/1`
(`SubscriptionSchedule`), `decode_items/1`, and `decode_add_invoice_items/1`
(`Phase`) with a coerce-to-nil clause (`defp decode_phases(_other), do: nil`).
Added inline comments explaining the defensive rationale — keeps the struct
type-honest against the documented `@type` contracts
(`phases: [Phase.t()] | nil`, `items: [PhaseItem.t()] | nil`) without crashing
production on an unexpected Stripe shape. Verified via `mix compile` (clean).

### IN-03: `list_response/1` fixture uses a convoluted range-with-filter idiom

**Files modified:** `test/support/fixtures/subscription_schedule.ex`
**Commit:** ce621e7
**Applied fix:** Split `list_response/1` into two explicit clauses: a
zero-case `list_response(0)` that short-circuits to an empty `data` list, and
`list_response(count) when is_integer(count) and count > 0` that uses a
straight `Enum.map(1..count, ...)` — dropping the `max(count, 1)//1` +
`count > 0` filter combination. Intent is now obvious without tracing two
guards. Verified via `MIX_ENV=test mix compile` (clean).

## Skipped Issues

### IN-02: `stream!/3` uses inconsistent pipeline shape

**File:** `lib/lattice_stripe/subscription_schedule.ex:249-253`
**Reason:** Skipped intentionally per reviewer guidance. The reviewer's fix
text explicitly said: _"Only worth doing if the rest of the codebase already
uses this shape for `stream!` functions. If other modules also use the
`req = ...` pattern, leave it alone."_ A grep of all resource modules shows
that every other `stream!/3` in the codebase (Refund, Event, Product, Coupon,
Checkout.Session, PromotionCode, Subscription, Customer, InvoiceItem, Price,
Invoice, SetupIntent, PaymentIntent, TestClock) uses the same
`req = %Request{...}; List.stream!(client, req) |> Stream.map(&from_map/1)`
shape as `SubscriptionSchedule`. The perceived discontinuity is actually the
established project-wide convention, so rewriting only this one call site
would introduce a new inconsistency rather than remove one. Leaving as-is.
**Original issue:** Style discontinuity inside the module — every other
public function uses the `|> then(&Client.request(client, &1))` pattern but
`stream!/3` builds into a local `req` variable. Not a bug.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
