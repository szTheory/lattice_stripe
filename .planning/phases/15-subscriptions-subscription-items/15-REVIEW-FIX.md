---
phase: 15
fixed_at: 2026-04-12
scope: critical_high_medium
review_path: .planning/phases/15-subscriptions-subscription-items/15-REVIEW.md
findings_in_scope: 4
findings_addressed: 4
fixed: 4
skipped: 0
status: all_fixed
iteration: 1
commits:
  - 41718d1 fix(review-15): F-001 capture unknown fields in Invoice.AutomaticTax
  - f48393e docs(review-15): F-002 explain search_stream! bang convention
  - e118130 fix(review-15): F-003 correct SubscriptionItem.stream! arity labels
  - b67f9a1 test(review-15): F-004 cover missing Subscription bang variants
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** `.planning/phases/15-subscriptions-subscription-items/15-REVIEW.md`
**Iteration:** 1
**Scope:** Critical + High + Medium (Low and Info deferred per request)

**Summary:**
- Findings in scope: 4 (1 HIGH, 3 MEDIUM)
- Fixed: 4
- Skipped: 0
- Deferred (out of scope): F-005, F-006 (LOW), F-007, F-008 (INFO)

Full unit test suite: **975 tests, 0 failures (79 integration excluded)**.

---

## Fixed Issues

### F-001 [HIGH] — `Invoice.AutomaticTax` silently drops unknown fields

**Files modified:**
- `lib/lattice_stripe/invoice/automatic_tax.ex`
- `test/lattice_stripe/invoice/automatic_tax_test.exs`

**Commit:** `41718d1`

**Applied fix:**
- Added `@known_fields ~w[enabled liability status]` and `extra: %{}` to the struct (mirrors `Invoice.LineItem` / `PauseCollection` pattern).
- `from_map/1` now uses `Map.split(map, @known_fields)` to capture unknown subfields into `:extra` rather than silently dropping them. Affects both `Invoice` and `Subscription` callers (D4 reuse).
- Updated `@type t` to include `extra: map()`.
- Added a custom `Inspect` implementation mirroring `Invoice.LineItem`: shows `enabled`/`status`/`liability` always, and appends `extra:` only when non-empty for compact output.
- Added four test cases: unknown-fields-land-in-extra, empty-extra-default, Inspect-hides-empty-extra, Inspect-shows-nonempty-extra.

**Verification:** `mix test test/lattice_stripe/invoice/automatic_tax_test.exs test/lattice_stripe/subscription_test.exs` → 42 tests, 0 failures. Full suite green.

---

### F-002 [MEDIUM] — `Subscription.search_stream!/3` doc doesn't explain bang convention

**Files modified:** `lib/lattice_stripe/subscription.ex`

**Commit:** `f48393e`

**Applied fix:**
Rewrote the `@doc` for `search_stream!/3` to:
1. State explicitly that pages are emitted via auto-pagination and that `LatticeStripe.Error` is raised on mid-stream failure.
2. Explain that the `!` suffix does **not** pair with a tuple-returning `search_stream/3` — there is none — because Elixir Streams cannot return `{:ok, _} | {:error, _}` for mid-stream failures.
3. Cross-reference the matching convention used by `Invoice.search_stream!/3` and `Checkout.Session.search_stream!/3`.
4. Added the eventual-consistency warning block to match `Invoice.search_stream!/3` wording.

**Verification:** `mix compile --warnings-as-errors` clean. `mix test test/lattice_stripe/subscription_test.exs` → 33 tests, 0 failures.

---

### F-003 [MEDIUM] — `SubscriptionItem.stream!/3` arity wrongly labeled as `stream!/2`

**Files modified:** `lib/lattice_stripe/subscription_item.ex`

**Commit:** `e118130`

**Applied fix:**
Function signature is `def stream!(%Client{} = client, params, opts \\ [])` → canonical arity is 3. Two corrections:

1. `@moduledoc` line 15: `list/3` and `stream!/2` → `list/3` and `stream!/3`
2. Runtime error message in `Resource.require_param!` call (line 215): `SubscriptionItem.stream!/2` → `SubscriptionItem.stream!/3`

No `@spec` change needed — spec already showed 3-arity. Aligns IEx help, error messages, and spec.

**Verification:** `mix compile --warnings-as-errors` clean. `mix test test/lattice_stripe/subscription_item_test.exs` → 23 tests, 0 failures.

---

### F-004 [MEDIUM] — Bang variant unit tests incomplete

**Files modified:** `test/lattice_stripe/subscription_test.exs`

**Commit:** `b67f9a1`

**Applied fix:**
Extended the `describe "bang variants"` block with 10 new tests (pattern lifted from the existing `create!` tests):

| Function | Success test | Raise test |
|---|---|---|
| `pause_collection!/3` | returns `%Subscription{pause_collection: %PauseCollection{behavior: "keep_as_draft"}}` | raises `LatticeStripe.Error` on transport error |
| `resume!/3` | returns `%Subscription{}` | raises `LatticeStripe.Error` on transport error |
| `list!/3` | returns `%Response{data: %List{data: [%Subscription{}]}}` | raises `LatticeStripe.Error` on transport error |
| `stream!/3` | yields `[%Subscription{id: "sub_test1234567890"}]` via `Enum.take(5)` | raises `LatticeStripe.Error` mid-stream (first-page error) |
| `cancel!/3` | returns `%Subscription{status: "canceled"}` | raises `LatticeStripe.Error` on transport error |

Total bang-variant test count grew from 2 (create! success + raise) to 12. File still runs `async: true`.

**Verification:** `mix test test/lattice_stripe/subscription_test.exs` → 43 tests, 0 failures (was 33). Full suite: `mix test --exclude integration` → 975 tests, 0 failures.

---

## Skipped Issues

None. All 4 in-scope findings were fixed cleanly in one pass.

## Out-of-Scope Findings (not addressed this pass)

Per the fix scope (Critical + High + Medium only), the following are intentionally deferred:

- **F-005 [LOW]** — `cancel/3`/`cancel/4` `@doc` redundancy. Not touched; no compiler warning surfaced in `mix compile --warnings-as-errors` during this pass, so behavior is Elixir-idiomatic as-is.
- **F-006 [LOW]** — duplicate of F-003 grouping; incidentally addressed by F-003's moduledoc fix.
- **F-007 [INFO]** — `Subscription.stream!/3` unit test. Incidentally addressed by F-004 (stream! bang tests added).
- **F-008 [INFO]** — `SubscriptionItem` Inspect exposes subscription ID in plain text. Deferred — per the review, this is a policy decision for the team, not a defect.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
