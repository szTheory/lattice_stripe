# Phase 15: Subscriptions + Subscription Items - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Seeded from locked draft plan (~/.claude/plans/lazy-shimmying-ladybug.md) — 5 decisions D1–D5 already confirmed by user.

<domain>
## Phase Boundary

Developers can create, retrieve, update, cancel, pause, resume, list, and search Subscriptions and manage SubscriptionItem CRUD with a coherent, pattern-matchable API that reuses the Billing proration guard and Phase 14 nested-struct conventions.

Requirements: **BILL-03**

**In scope:**
- `LatticeStripe.Subscription` resource module: `create`, `retrieve`, `update`, `cancel`, `list`, `search`, `stream!`, `search_stream!` + bang variants
- Subscription lifecycle verbs: `cancel/4`, `resume/3`, `pause_collection/5`
- `LatticeStripe.SubscriptionItem` resource module: full CRUD + `stream!` + bang variants
- Extension of `Billing.Guards.has_proration_behavior?/1` to cover `items[]` array case
- 5 typed nested structs on Subscription (see D4 / §2.4 in draft)
- stripe-mock integration tests for both resources
- `guides/subscriptions.md` + ExDoc Billing module group wiring

**Out of scope:**
- Customer Portal (BILL-05)
- Coupons/PromoCodes (BILL-06) — will return via D1 restore commit, but resource wiring is a later phase
- Meters / Usage Records (BILL-07) — deprecated path, future phase
- Connect (phases 17/18)
- `delete_discount/3` on Subscription — belongs with Coupons phase
- `cancel_at` sugar — one-liner on `update`, defer to docs

</domain>

<decisions>
## Implementation Decisions (Locked — D1–D5)

### D1 — Phase 12/13 restoration (PRE-phase-15 prerequisite)
Before Phase 15 execution begins, run a dedicated restore session that cherry-picks the deleted Phase 12/13 artifacts from `git show 39b98c9^:<path>`:
- `lib/lattice_stripe/product.ex`
- `lib/lattice_stripe/price.ex`
- `lib/lattice_stripe/coupon.ex`
- `lib/lattice_stripe/promotion_code.ex`
- `lib/lattice_stripe/testing/test_clock*` and tests/fixtures

Land in a single atomic commit: `restore(12-13): recover billing catalog and test clocks deleted in 39b98c9`. Verify all tests green and docs still render. This unblocks real stripe-mock subscription integration tests (create real Price → create real Subscription) and restores `LatticeStripe.Testing.TestClock` for time-travel lifecycle testing.

**Note for planner:** This restore is prerequisite, not part of Phase 15's plan files. Plan 15-03 (integration tests) may assume `Price` and `TestClock` modules are available on `main`.

### D2 — Phase 15 scope: Subscription + SubscriptionItem only
Three plans total. No Customer Portal, no Coupons/PromoCodes wiring (even after D1 restore brings the code back), no Meters, no Connect. Tight domain boundary.

### D3 — Milestone framing: v2.0-billing
Phases 14 (done), 15 (current), 16 (schedules) land under a new `v2.0-billing` milestone in STATE.md. Connect (17/18) and cross-cutting polish (19) are deferred to separate future milestones. v1.0 stays closed at phases 1–11.

### D4 — Resource module naming: flat namespace
- `LatticeStripe.SubscriptionItem` at top level (matches Phase 1 D-17 flat namespace convention used for `Customer`, `PaymentIntent`, `Refund`, `Invoice`).
- Subscription-specific typed nested structs live under `LatticeStripe.Subscription.*`:
  - `LatticeStripe.Subscription.PauseCollection`
  - `LatticeStripe.Subscription.CancellationDetails`
  - `LatticeStripe.Subscription.TrialSettings`
- `LatticeStripe.Invoice.AutomaticTax` is **reused**, not duplicated, as `Subscription.automatic_tax`.

### D5 — Pause helper: `pause_collection/5`
```elixir
Subscription.pause_collection(client, id, behavior, params \\ %{}, opts \\ [])
  when behavior in [:keep_as_draft, :mark_uncollectible, :void]
```

Function name matches Stripe's field name exactly. Takes a `behavior` atom guarded at the function head for compile-time typo protection. No generic `pause/4` — Stripe has no dedicated pause endpoint; a generic name would mislead users. The helper dispatches to `update` with `pause_collection` set.

### Typed nested struct promotion (D4 expansion, from §2.4 of draft)

Promote exactly 5 nested fields on `%Subscription{}` to typed structs:
1. **`items`** → `[%LatticeStripe.SubscriptionItem{}]` (mandatory; users pattern-match constantly)
2. **`automatic_tax`** → reuse `%LatticeStripe.Invoice.AutomaticTax{}`
3. **`pause_collection`** → new `%Subscription.PauseCollection{}` with `behavior`, `resumes_at`
4. **`cancellation_details`** → new `%Subscription.CancellationDetails{}` with `reason`, `feedback`, `comment`
5. **`trial_settings`** → new `%Subscription.TrialSettings{}` with `end_behavior.missing_payment_method`

Leave as plain maps (on `extra` or plain map typed field):
- `billing_thresholds`, `pending_invoice_item_interval`, `pending_update`, `transfer_data`, `metadata`, `plan` (deprecated by Stripe)

### Guard extension (from §2.3 of draft)

Extend `Billing.Guards.has_proration_behavior?/1` to also return true when any map in `params["items"]` has a `"proration_behavior"` key. Wire `check_proration_required/2` into:
- `Subscription.create/3`
- `Subscription.update/4`
- `SubscriptionItem.create/3`
- `SubscriptionItem.update/4`
- `SubscriptionItem.delete/3`

Add guard tests for items-array-with-proration and items-array-without.

### Plan file structure (from §2.5 of draft)

Three plans:
- **15-01-PLAN.md** — Subscription struct + 3 new nested typed structs + CRUD + lifecycle verbs (`cancel`, `resume`, `pause_collection`) + guard wiring + guard extension + unit tests
- **15-02-PLAN.md** — SubscriptionItem struct + CRUD (incl. `delete`) + guard wiring + unit tests + fixtures
- **15-03-PLAN.md** — stripe-mock integration tests + `guides/subscriptions.md` + mix.exs ExDoc wiring (Billing module group extension)

### Claude's Discretion
- Exact field list on each typed nested struct (follow Phase 14 `@known_fields` + `extra` pattern)
- Test organization within each `*_test.exs` (follow Invoice test style)
- `guides/subscriptions.md` section ordering (follow existing guide patterns)
- Whether to split any plan further if task count exceeds ~8 tasks
- Fixture JSON shape (follow `test/support/fixtures/customer.ex` template)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 14 precedents (closest template)
- `lib/lattice_stripe/invoice.ex` — closest resource precedent; same size and complexity
- `lib/lattice_stripe/invoice/automatic_tax.ex` — literally reused as `Subscription.automatic_tax`
- `lib/lattice_stripe/invoice/status_transitions.ex` — typed nested struct template
- `lib/lattice_stripe/invoice/line_item.ex` — larger nested struct with `@known_fields` + `extra` and custom Inspect
- `lib/lattice_stripe/invoice_item/period.ex` — small nested struct template
- `.planning/phases/14-invoices-invoice-line-items/14-UAT.md` — UAT style template

### Other canonical resource patterns
- `lib/lattice_stripe/checkout/session.ex` — action verbs (`expire`), search endpoint, nested namespace example
- `lib/lattice_stripe/refund.ex` — smaller resource, simpler Inspect pattern
- `lib/lattice_stripe/customer.ex` — baseline resource pattern (Phase 4 D-06)

### Reusable helpers (call — do not duplicate)
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3`
- `lib/lattice_stripe/client.ex` — `request/2`, `request!/2`, `require_explicit_proration` field
- `lib/lattice_stripe/billing/guards.ex` — `check_proration_required/2` (already present, WR-01 fixed in commit `0628bbd`, needs `items[]` extension)
- `lib/lattice_stripe/list.ex` — `stream!/2` and `from_json/3`
- `lib/lattice_stripe/form_encoder.ex` — nested-param encoding (critical — verify `items[]` array encoding in tests; this was stripity_stripe's biggest pain point per issues #208/#210)
- `lib/lattice_stripe/telemetry.ex` — general request events only; no new subscription-specific events

### Test infrastructure
- `test/support/test_helpers.ex` — `test_client/1`, `ok_response/1`, `list_json/2`, `test_integration_client/0`
- `test/support/fixtures/customer.ex` — fixture module template
- `test/support/fixtures/checkout_session.ex` — fixture module template
- `test/integration/invoice_integration_test.exs` — stripe-mock integration skeleton
- `test/lattice_stripe/billing/guards_test.exs` — guard test template (extend with `items[]` cases)

### Project conventions
- `CLAUDE.md` — project instructions
- `.planning/STATE.md` — current position, milestone framing
- `.planning/ROADMAP.md` — Phase 15 entry (to be created per D3 as part of the Part 1 realignment, not Phase 15 itself)
- `.planning/REQUIREMENTS.md` — BILL-03 definition

</canonical_refs>

<specifics>
## Specific Ideas from Draft

- Subscription's `items` field MUST be a list of full `%SubscriptionItem{}` structs (not reduced inline) — stripity_stripe had a well-known bug where nested items in Subscription response were missing `id`, making programmatic updates impossible. The `id` field is non-negotiable on SubscriptionItem.
- Both `Subscription.search` and `Subscription.search_stream!` are in scope (Stripe provides `GET /v1/subscriptions/search` with its own pagination page token semantics — follow the Phase 6 `Checkout.Session.search_stream!` precedent).
- `Subscription.cancel` takes params including `prorate`, `invoice_now`, `cancellation_details` — all optional, all pass-through to Stripe.
- Telemetry: piggyback on the general `[:lattice_stripe, :request, *]` events from Phase 8; do NOT introduce subscription-specific events. Subscription state transitions belong to webhook handlers, not SDK layer.
- PII safety: the custom `Inspect` implementation must hide `customer` field details and `payment_settings` internals (mirror `Invoice` Inspect).
- No `Jason.Encoder` derivation on any new struct (per locked pattern).

</specifics>

<deferred>
## Deferred Ideas

- **Usage Records / Meters / Meter Events** (BILL-07) — deprecated path at Stripe; defer entirely. Add a one-paragraph note in `SubscriptionItem` `@moduledoc` pointing at Billing Meters API for usage-based billing.
- **Coupons, PromotionCodes, Discounts** (BILL-06) — restored to codebase via D1, but resource wiring and `delete_discount/3` etc. belong to a later phase.
- **Customer Portal** (BILL-05) — future phase.
- **Subscription Schedules** (Phase 16 / BILL-03 extension).
- **Connect subscriptions** (phases 17/18).
- **`cancel_at` sugar helper** — one-liner on `update(id, %{cancel_at: ts})`, document in guide instead of adding a function.
- **`delete_discount/3`** on Subscription — belongs to Discount resource in a future phase.
- **Retroactive BILL-04b/04c/10 requirement IDs** — leave as orphan IDs; do not resurrect. Note in REQUIREMENTS.md v2 traceability section.

</deferred>

---

*Phase: 15-subscriptions-subscription-items*
*Context gathered: 2026-04-12 — seeded from locked draft plan (5 decisions D1–D5 user-confirmed)*
