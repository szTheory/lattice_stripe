---
phase: 21-customer-portal
reviewed: 2026-04-14T20:13:18Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - lib/lattice_stripe/billing_portal/guards.ex
  - lib/lattice_stripe/billing_portal/session.ex
  - lib/lattice_stripe/billing_portal/session/flow_data.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex
  - test/integration/billing_portal_session_integration_test.exs
  - test/lattice_stripe/billing_portal/guards_test.exs
  - test/lattice_stripe/billing_portal/session/flow_data_test.exs
  - test/lattice_stripe/billing_portal/session_test.exs
  - test/support/fixtures/billing_portal.ex
  - mix.exs
  - guides/customer-portal.md
  - guides/subscriptions.md
  - guides/webhooks.md
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
issues:
  critical: 0
  warning: 0
  info: 2
status: clean
---

# Phase 21: Code Review Report

**Reviewed:** 2026-04-14T20:13:18Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** clean (2 minor info items, non-blocking)

## Summary

Phase 21 Customer Portal implementation is clean, idiomatic, and faithfully
implements all four locked decisions (D-01 Guards, D-02 FlowData nested tree,
D-03 Inspect masking, D-04 Guide envelope). No bugs, no security issues, no
code-quality problems of substance.

Verification highlights:

- **D-01 Guards** — `BillingPortal.Guards.check_flow_data!/1` uses the exact
  GUARD-03 pattern-match idiom specified in CONTEXT.md. Dispatch clauses are
  pattern-matched per flow type with a binary catchall for unknown types and
  a final catchall for malformed `flow_data`. Error messages include the
  fully-qualified function name via the `@fn_name` module attribute as
  specified. The `subscription_update_confirm` clause uses `i != []` rather
  than `length(i) > 0` per the D-01 "Specific Ideas" directive. `@moduledoc
  false` is applied. Call site in `Session.create/3` is a one-liner after
  `Resource.require_param!`, before `Resource.request`. Guard test matrix
  covers all 10 specified cases plus 2 extras.

- **D-02 FlowData tree** — Exactly 5 modules (parent + 4 sub-structs) matching
  Meter's 4+1 footprint. Each sub-struct uses the Phase 20 `@known_fields` +
  `defstruct` + `from_map(nil)` + `from_map(map)` + `Map.drop/:extra`
  template verbatim. `retention`, `redirect`, `hosted_confirmation`, `items`,
  `discounts` correctly remain raw maps per D-02. Parent `FlowData`
  forward-compat works correctly — unknown flow types (e.g. a future
  `subscription_pause`) land in `:extra` with the branch key, verified by
  `flow_data_test.exs` line 162.

- **D-03 Inspect masking** — Allowlist `defimpl Inspect` hides both `:url` and
  `:flow`. Per-field rationale comment block above the impl explains
  sensitivity. Test suite uses the stronger assertion `refute inspect(session)
  =~ session.url` (not `refute =~ "url:"`) per the D-03 Specific Idea, plus
  `refute =~ "secret_abc"` and `refute =~ "FlowData"` — both actual-value
  assertions catch partial leaks. Module field order in output matches D-03
  exactly: `id, object, livemode, customer, configuration, on_behalf_of,
  created, return_url, locale`. Angle-bracket delimiters match spec.

- **D-04 Guide envelope** — `guides/customer-portal.md` is 280 lines (within
  the 240 ± 40 envelope). `mix.exs` `extras:` registers the guide;
  `groups_for_modules:` "Customer Portal" group lists exactly the 6 public
  modules (parent `Session` + `FlowData` + 4 sub-modules); `BillingPortal.
  Guards` is correctly NOT in the group since it is `@moduledoc false`.
  Reciprocal cross-links landed in `guides/subscriptions.md` (2 deep-links to
  cancellation and proration sections) and `guides/webhooks.md` (1 link to
  Security section).

- **No debug artifacts** — Only `IO.inspect` references are inside moduledoc
  and comment blocks documenting the `structs: false` escape hatch. No
  `TODO`/`FIXME`/`HACK`/`dbg()` in any phase 21 source file.

- **Test completeness** — Tests assert actual behavior (values, raises with
  regex on message content, struct shape), not just structure. The guard test
  explicitly verifies that error messages contain the FQ function name across
  all raise paths (single parameterized test).

## Info

### IN-01: Unknown-type error message string assembly is hard to read

**File:** `lib/lattice_stripe/billing_portal/guards.ex:71-76`
**Issue:** The error message for the unknown-type clause is assembled from
three concatenated strings, two of which are `~s[]` sigils. The construction
is correct (I verified the output is
`... Valid types: "subscription_cancel", "subscription_update", "subscription_update_confirm", "payment_method_update".`)
but the line break placement inside a quoted list with an embedded sentence
period is visually confusing, especially the final fragment
`~s["subscription_update_confirm", "payment_method_update".]` where the
terminal `.]` looks like punctuation but is `.` (sentence period) + `]`
(sigil delimiter).
**Fix:** Build the valid-types list once as a module attribute and interpolate
it:
```elixir
@valid_types_message ~s["subscription_cancel", "subscription_update", ] <>
                       ~s["subscription_update_confirm", "payment_method_update"]

defp check_flow!(%{"type" => type}) when is_binary(type) do
  raise ArgumentError,
        "#{@fn_name}: unknown flow_data.type #{inspect(type)}. " <>
          "Valid types: #{@valid_types_message}."
end
```
This separates the sentence period from the sigil delimiter and keeps the
valid-type list declarative. Non-blocking — current code is correct and
covered by test case 10.

### IN-02: `test/support/fixtures/billing_portal.ex` double `Map.merge` in branch fixtures

**File:** `test/support/fixtures/billing_portal.ex:40-51` (and lines 60-74,
81-94, 102-117)
**Issue:** Each branch fixture calls `basic(%{"flow" => ...})` and then
`|> Map.merge(overrides)`. Because `basic/1` already merges its argument into
the baseline, the outer `Map.merge(overrides)` is the second merge pass. This
is functionally correct — overrides still win — but the code path is subtly
non-obvious: if a caller passes `overrides = %{"flow" => ...}`, the outer
merge overwrites the flow that was just set by `basic/1`, which is probably
the intended behavior but is undocumented. The simpler shape is to pass a
single merged map into `basic/1`:
```elixir
def with_subscription_cancel_flow(overrides \\ %{}) do
  basic(
    Map.merge(
      %{"flow" => %{"type" => "subscription_cancel", ...}},
      overrides
    )
  )
end
```
**Fix:** Optional — collapse the double merge per the snippet above, or add
a one-line comment that the outer `Map.merge` is there intentionally to let
callers override the flow. Non-blocking; tests pass and behavior is correct.

---

_Reviewed: 2026-04-14T20:13:18Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
