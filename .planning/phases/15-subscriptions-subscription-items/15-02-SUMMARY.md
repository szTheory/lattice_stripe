# Phase 15 Plan 02: SubscriptionItem Summary

**Status:** Complete
**Completed:** 2026-04-12

## One-liner

`LatticeStripe.SubscriptionItem` flat-namespace resource with full CRUD,
guarded mutations, id-preserving decode, and OQ-2 required-param listing.

## Files Created

- `lib/lattice_stripe/subscription_item.ex`
- `test/lattice_stripe/subscription_item_test.exs` (23 unit tests)
- `test/support/fixtures/subscription_item.ex`

## Files Modified

None.

## Commits

- `8f18637` — feat(15-02-01): add LatticeStripe.SubscriptionItem resource

## Test Count Delta

- SubscriptionItem: +23 tests
- **Net cross-plan fix:** Subscription's regression-guard test (added in
  Plan 15-01, pending) now passes — SubscriptionItem.from_map/1 is live.
- Full unit suite: **961 tests, 0 failures** (up from 887 baseline).

## Key verification

- `Subscription.from_map(Fixtures.with_items())` round-trips items into
  `[%SubscriptionItem{}]` with id preserved (stripity_stripe #208 regression
  guard).
- `SubscriptionItem.list(client, %{})` raises `ArgumentError` with message
  mentioning `"subscription"` and `"SubscriptionItem.list/3"`.
- `SubscriptionItem.stream!(client, %{})` raises `ArgumentError`.
- Strict-client guard wiring verified on `create/3`, `update/4`, and
  `delete/4` paths.
- Idempotency key forwarded on every mutation path.

## Decisions Applied

- **D4** — Flat top-level module `LatticeStripe.SubscriptionItem`
- **OQ-2 RESOLVED YES** — `list/3` and `stream!/2` require `subscription` param

## Threat Mitigations Applied

- **T-15-01** — Inspect masks `metadata` and `billing_thresholds` as `:present`.
- **T-15-02** — `opts[:idempotency_key]` forwarded on create/update/delete.
- **T-15-03** — Guard wired into create/update/delete with strict/permissive tests.

## Deviations from Plan

None. Plan executed as written.

## Open items for Plan 15-03

- Integration tests against stripe-mock (Subscription + SubscriptionItem)
- `guides/subscriptions.md` with T-15-04 webhook callout
- mix.exs ExDoc Billing module group extension

## Self-Check: PASSED

- `lib/lattice_stripe/subscription_item.ex` exists.
- Commit `8f18637` in git log.
- Full unit suite green (961/961).
- Plan 15-01's cross-plan regression test now passes.
