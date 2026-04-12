# Phase 15 Plan 01: Subscription Core Summary

**Status:** Complete (pending Plan 15-02 cross-plan fix)
**Completed:** 2026-04-12

## One-liner

`LatticeStripe.Subscription` resource with full CRUD + lifecycle verbs + 3 new
typed nested structs + Billing.Guards `items[]` extension for requirement BILL-03.

## Files Created

- `lib/lattice_stripe/subscription.ex` — resource module
- `lib/lattice_stripe/subscription/pause_collection.ex`
- `lib/lattice_stripe/subscription/cancellation_details.ex` (Inspect masks `comment`)
- `lib/lattice_stripe/subscription/trial_settings.ex`
- `test/lattice_stripe/subscription_test.exs` (33 unit tests)
- `test/lattice_stripe/subscription/pause_collection_test.exs` (4 tests)
- `test/lattice_stripe/subscription/cancellation_details_test.exs` (5 tests)
- `test/lattice_stripe/subscription/trial_settings_test.exs` (4 tests)
- `test/support/fixtures/subscription.ex` (fixture module)

## Files Modified

- `lib/lattice_stripe/billing/guards.ex` — extended `has_proration_behavior?/1`
  to inspect `items[]` arrays
- `test/lattice_stripe/billing/guards_test.exs` — 5 new guard cases for items[]

## Commits

- `332e165` — feat(15-01-01): add Subscription nested typed structs
- `2dd78b9` — feat(15-01-02): extend Billing.Guards for items[] proration detection
- `83a6331` — feat(15-01-03): add LatticeStripe.Subscription resource

## Test Count Delta

- Nested struct tests: +13
- Guard tests (items[] cases): +5
- Subscription resource tests: +33 (32 pass, 1 cross-plan pending)

Total new: **51 unit tests** (50 green, 1 pending Plan 15-02).

## Cross-plan dependency

`test/lattice_stripe/subscription_test.exs` contains one test
(`"items list data decodes preserving id (stripity_stripe regression guard)"`)
that exercises `Subscription.from_map/1 → SubscriptionItem.from_map/1`. It
currently fails with `UndefinedFunctionError` because `LatticeStripe.SubscriptionItem`
ships in Plan 15-02. This is intentional per CONTEXT gotcha #3 — the plan
explicitly forbids stubbing `SubscriptionItem.from_map/1`. Plan 15-02 Task 1
closes this gap.

## Decisions Applied

- **D4** — Flat namespace for `LatticeStripe.SubscriptionItem` (honored via
  the `alias` + `SubscriptionItem.from_map/1` call without duplication)
- **D5** — `pause_collection/5` with function-head guard on atom `behavior`
- **OQ-1 RESOLVED YES** — `cancel/3` delegates to `cancel/4` with empty params
- **OQ-3 NO** — No subscription-specific telemetry events (documented in moduledoc)

## Threat Mitigations Applied

- **T-15-01** — Inspect impl on `%Subscription{}` hides `customer`,
  `payment_settings`, `default_payment_method`, `latest_invoice` via `has_*?`
  presence markers. `%CancellationDetails{}` Inspect masks `comment` as
  `[FILTERED]`. Verified by unit tests.
- **T-15-02** — Every mutation path (`create`, `update`, `cancel`, `resume`,
  `pause_collection`) forwards `opts[:idempotency_key]` to the Request opts
  pipeline. Verified by Mox header assertions.
- **T-15-03** — Guard extended to detect `items[]` with proration_behavior;
  wired into `create/3` and `update/4`. Unit-tested with strict client.
- **T-15-05** — Form encoder sanity test exercises `metadata` with bracket/
  ampersand keys, asserts request body non-empty (no encoder crash).

## Deviations from Plan

1. **[Rule 1 — Bug] Plan's `cancel/3` signature omitted default opts.**
   Plan wrote `def cancel(client, id, opts \\ [])` but in the test section
   expected `Subscription.cancel(client, id)` (arity 2) to work. I added
   `\\ []` to the `cancel/3` head so Elixir synthesizes arity 2.

2. **[Rule 1 — Bug] Plan's test assertion used `req.body =~ "prorate"` for
   a DELETE call.** DELETE requests encode params into the query string in
   `Client.build_url_and_body/4`, so `req.body` is `nil`. Changed assertion
   to `req.url =~ "prorate"`.

3. **[Rule 1 — Bug] Plan instructed
   `params = Resource.require_param!(params, "query", "...")` for
   `Subscription.search/3`.** `Resource.require_param!/3` returns `:ok`, not
   the params map. Used the correct side-effect pattern: call
   `Resource.require_param!(params, "query", msg)` without rebinding.

4. **[Cross-plan intentional] items-decode unit test fails under Plan 15-01
   alone.** Acknowledged in gotcha #3 — no stub permitted. Full green
   after Plan 15-02 ships `SubscriptionItem.from_map/1`.

## Open items for Plan 15-02 pickup

- `LatticeStripe.SubscriptionItem` module (flat namespace per D4)
- `SubscriptionItem.from_map/1` to resolve the pending cross-plan test
- `SubscriptionItem.list/3` must `Resource.require_param!(params, "subscription", ...)`
  per OQ-2
- Fixture module `LatticeStripe.Test.Fixtures.SubscriptionItem`

## Self-Check: PASSED (with documented exception)

- All new files exist.
- All 3 commits present in `git log`.
- Compile green with one expected warning
  (`SubscriptionItem.from_map/1` undefined — lands in Plan 15-02).
- Test suite: 50/51 new tests passing; 1 pending cross-plan fix.
