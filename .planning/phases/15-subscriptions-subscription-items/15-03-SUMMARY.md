# Phase 15 Plan 03: Integration, Guide, and Docs Summary

**Status:** Complete
**Completed:** 2026-04-12

## One-liner

End-to-end stripe-mock verification, developer guide with mandatory webhook
callout (T-15-04), and ExDoc wiring for all 5 Phase 15 modules.

## Files Created

- `test/integration/subscription_integration_test.exs` (6 tests)
- `test/integration/subscription_item_integration_test.exs` (5 tests)
- `guides/subscriptions.md`

## Files Modified

- `mix.exs` — Billing module group + docs extras list

## Commits

- `3d172d0` — test(15-03): add Subscription + SubscriptionItem stripe-mock integration
- `e79feef` — docs(15-03-03): add guides/subscriptions.md with webhook callout
- `01f5bc2` — docs(15-03-04): wire Phase 15 modules into ExDoc Billing group

## Test Count

- Integration tests: **11 passing** (6 Subscription + 5 SubscriptionItem)
- Full unit suite: **961 passing, 0 failures**
- Combined with integration: **972 total tests, 0 failures**

## Key verification

- stripe-mock accepts nested `items[0][id]`, `items[0][quantity]`,
  `items[0][proration_behavior]` params against its OpenAPI spec —
  T-15-05 form encoder mitigation verified end-to-end.
- Strict client rejects items[] update without proration_behavior
  without hitting the network — T-15-03 verified end-to-end.
- `idempotency_key` forwarded through the Client pipeline into the
  Idempotency-Key HTTP header — T-15-02 verified end-to-end.
- `SubscriptionItem.list(client, %{})` raises `ArgumentError` — OQ-2 closed.
- `mix docs` renders cleanly; `doc/LatticeStripe.Subscription.html`,
  `doc/LatticeStripe.SubscriptionItem.html`,
  `doc/LatticeStripe.Subscription.PauseCollection.html`,
  `doc/LatticeStripe.Subscription.CancellationDetails.html`,
  `doc/LatticeStripe.Subscription.TrialSettings.html`, and
  `doc/subscriptions.html` all exist.

## Threat Mitigations Applied

- **T-15-02** — Integration tests exercise `idempotency_key` forwarding through
  the full Client → transport pipeline; stripe-mock accepts the header.
- **T-15-03** — Strict-client items[] test verifies guard rejection end-to-end
  without network traffic.
- **T-15-04** — `guides/subscriptions.md` contains mandatory `## Webhooks own
  state transitions` section with the exact phrase "Always drive your
  application state from webhook events, not from SDK responses."
- **T-15-05** — stripe-mock validates nested items[] encoding against the
  real Stripe OpenAPI spec; successful create is the verification.

## Deviations from Plan

1. **[Rule 1 — Bug] stripe-mock is stateless against repeated calls.**
   Plan's lifecycle round-trip test asserted `retrieved.id == sub.id` across
   sequential calls, but stripe-mock returns fresh randomized responses per
   OpenAPI spec. Changed assertions to focus on structural shape
   (`%Subscription{} = ...`, `is_binary(id)`) rather than id equality. This
   is a standard stripe-mock caveat that every existing integration test in
   this repo already handles the same way.

2. **[Rule 1 — Minor] `mix docs` verify command referenced
   `grep -q "Subscriptions" doc/api-reference.html`.** ExDoc writes the guide
   group name into sidebar JS files (`dist/sidebar_items-*.js`) rather than
   into `api-reference.html` directly. The guide rendered successfully
   (`doc/subscriptions.html` exists, modules are all in the sidebar) and
   `mix docs` exits 0 — so this does not block plan completion.

## Open items for Phase 16 (Schedules)

- `LatticeStripe.Subscription.Schedule` (BILL-03 extension)
- Phase transitions timeline + lifecycle hooks
- Schedule-driven proration semantics

## Self-Check: PASSED

- `test/integration/subscription_integration_test.exs` exists and contains
  `@moduletag :integration`, `"CRUD + lifecycle round-trip"`,
  `Subscription.pause_collection(... :keep_as_draft)`, `Subscription.resume`,
  `"proration_behavior" => "create_prorations"`, `"idempotency_key is forwarded"`,
  and the strict-client items[] rejection test.
- `test/integration/subscription_item_integration_test.exs` exists and contains
  `@moduletag :integration`, `create -> retrieve -> update -> delete round-trip`,
  `assert_raise ArgumentError`, and `SubscriptionItem.stream!(client`.
- `guides/subscriptions.md` passes the full grep verification command.
- `mix.exs` extras contains `"guides/subscriptions.md"`.
- `mix.exs` Billing module group contains all 5 new modules.
- `mix docs` exits 0 with all expected HTML files present.
- Integration suite: 11/11 green. Unit suite: 961/961 green.
- Commits `3d172d0`, `e79feef`, `01f5bc2` present in git log.
