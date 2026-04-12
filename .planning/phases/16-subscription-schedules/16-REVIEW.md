---
phase: 16-subscription-schedules
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - guides/subscriptions.md
  - lib/lattice_stripe/billing/guards.ex
  - lib/lattice_stripe/subscription_schedule.ex
  - lib/lattice_stripe/subscription_schedule/add_invoice_item.ex
  - lib/lattice_stripe/subscription_schedule/current_phase.ex
  - lib/lattice_stripe/subscription_schedule/phase.ex
  - lib/lattice_stripe/subscription_schedule/phase_item.ex
  - mix.exs
  - test/integration/subscription_schedule_integration_test.exs
  - test/lattice_stripe/billing/guards_test.exs
  - test/lattice_stripe/form_encoder_test.exs
  - test/lattice_stripe/subscription_schedule/add_invoice_item_test.exs
  - test/lattice_stripe/subscription_schedule/current_phase_test.exs
  - test/lattice_stripe/subscription_schedule/phase_item_test.exs
  - test/lattice_stripe/subscription_schedule/phase_test.exs
  - test/lattice_stripe/subscription_schedule_test.exs
  - test/support/fixtures/subscription_schedule.ex
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found (info-level only)

## Summary

Phase 16 adds `LatticeStripe.SubscriptionSchedule` and its four nested typed
structs (`Phase`, `PhaseItem`, `CurrentPhase`, `AddInvoiceItem`), wires the
shared `Billing.Guards.check_proration_required/2` into `update/4` with
`phases[]` awareness, and ships an extensive test suite (unit + Mox +
stripe-mock integration). The code is clean, idiomatic, well-documented, and
aligned with existing Phase 14/15 conventions.

No bugs, security issues, or correctness problems found. The only items below
are minor code-quality observations and do not block merge.

**Highlights of what was verified:**

- **Proration guard wiring (D4):** `update/4` invokes the guard via `with`;
  `create/3`, `cancel/4`, `release/4` deliberately do not. Tests cover each
  path including the negative case (guard fires pre-network).
- **Wire-verb correctness (T-16-04):** `cancel/4` and `release/4` both use
  `POST` to sub-paths, matching Stripe's API shape (not `DELETE` like
  `Subscription.cancel/4`). Both unit tests and the stripe-mock integration
  test pin this.
- **PII safety (T-16-01):** The single custom `defimpl Inspect` on
  `SubscriptionSchedule` never surfaces `phases[]` or `default_settings`
  contents as full structs, preventing leaks of `default_payment_method`
  through default-derived inspect on nested `Phase`. Regression tests assert
  `pm_` never appears.
- **Form encoder (T-16-05):** The `phases[0][items][0][price_data][recurring][interval]`
  regression guard in `form_encoder_test.exs` pins nested encoding.
- **Guards extension:** `phases_has?/1` correctly stops at the phase level and
  does NOT walk into `phases[].items[]` — matching Stripe's actual wire
  acceptance surface (documented inline with a source link).
- **Struct shape divergence:** `PhaseItem` intentionally omits `id`,
  `object`, `subscription`, `created`, and period fields (template, not live
  item). A regression test asserts these keys are absent.

## Info

### IN-01: `decode_phases/1` and `decode_items/1` silently pass through non-list, non-nil values

**File:** `lib/lattice_stripe/subscription_schedule.ex:412`, `lib/lattice_stripe/subscription_schedule/phase.ex:155, 162`

**Issue:** The fallthrough clauses for `decode_phases/decode_items/decode_add_invoice_items` return the input unchanged when it is neither `nil` nor a list:

```elixir
defp decode_phases(other), do: other
```

This means a malformed Stripe payload where `phases` is, say, a map or
string would end up stored on the struct as-is, violating the `@type`
contract (`phases: [Phase.t()] | nil`). In practice Stripe only sends
`list | nil` for these fields, so this is purely defensive, but it silently
hides decoder bugs during development rather than surfacing them.

**Fix:** Either drop the fallthrough entirely (let `FunctionClauseError`
surface the bug in tests) or coerce to `nil`:

```elixir
defp decode_phases(_other), do: nil
```

Prefer the coerce-to-nil approach — it keeps the struct type-honest without
crashing production on an unexpected Stripe shape. Apply the same change to
`Phase.decode_items/1` and `Phase.decode_add_invoice_items/1`.

### IN-02: `stream!/3` uses inconsistent pipeline shape

**File:** `lib/lattice_stripe/subscription_schedule.ex:249-253`

**Issue:** Every other public function in the module uses the
`|> then(&Client.request(client, &1))` pattern, but `stream!/3` builds the
request into a local variable and then pipes outside the `%Request{}`
literal:

```elixir
def stream!(%Client{} = client, params \\ %{}, opts \\ [])
    when is_map(params) and is_list(opts) do
  req = %Request{method: :get, path: "/v1/subscription_schedules", params: params, opts: opts}
  LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

Not a bug — just a style discontinuity inside a single file. Readers
scanning the module for the next Stripe call have to parse a different
shape here. Minor.

**Fix:** Consider rewriting for consistency, if other resource modules
(`Subscription`, `Invoice`, etc.) follow a uniform shape:

```elixir
def stream!(%Client{} = client, params \\ %{}, opts \\ [])
    when is_map(params) and is_list(opts) do
  %Request{method: :get, path: "/v1/subscription_schedules", params: params, opts: opts}
  |> then(&LatticeStripe.List.stream!(client, &1))
  |> Stream.map(&from_map/1)
end
```

Only worth doing if the rest of the codebase already uses this shape for
`stream!` functions. If other modules also use the `req = ...` pattern,
leave it alone.

### IN-03: `list_response/1` fixture uses a convoluted range-with-filter idiom

**File:** `test/support/fixtures/subscription_schedule.ex:147-150`

**Issue:** The comprehension:

```elixir
for i <- 1..max(count, 1)//1, count > 0 do
  basic(%{"id" => "sub_sched_test#{i}"})
end
```

works (for `count == 0` the `count > 0` filter empties the result), but the
`max(count, 1)` + filter combination obscures intent. A reader has to
trace two guards to confirm the `count == 0` case yields `[]`.

**Fix:** Prefer an explicit empty-case short-circuit or a straight `Enum.map`:

```elixir
def list_response(0), do: %{
  "object" => "list",
  "data" => [],
  "has_more" => false,
  "url" => "/v1/subscription_schedules"
}

def list_response(count) when is_integer(count) and count > 0 do
  items = Enum.map(1..count, fn i -> basic(%{"id" => "sub_sched_test#{i}"}) end)
  %{"object" => "list", "data" => items, "has_more" => false, "url" => "/v1/subscription_schedules"}
end
```

Test-support code only; no runtime impact.

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
