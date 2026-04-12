# Phase 15 Research: Subscriptions + Subscription Items

**Researched:** 2026-04-12
**Source:** Consolidated from three parallel Explore agents (ecosystem research, codebase deep-dive, roadmap audit) run while producing the locked draft at `~/.claude/plans/lazy-shimmying-ladybug.md`. Two incorrect agent claims were corrected against git + working tree (see "Reality check" below).

## Objective

Answer: "What do I need to know to PLAN Subscriptions + SubscriptionItem well in LatticeStripe?"

---

## Reality check (claims verified against git + working tree)

Two research claims were wrong and matter for the plan:

1. **Phase 12 (Products/Prices/Coupons/PromotionCode) and Phase 13 (TestClocks) are NOT merely "archived."** They were built and committed to `main`, then **obliterated** in commit `39b98c9 feat(14-01): create typed nested structs` — which, despite its misleading message, deleted:
   - `lib/lattice_stripe/product.ex`
   - `lib/lattice_stripe/price.ex`
   - `lib/lattice_stripe/coupon.ex`
   - `lib/lattice_stripe/promotion_code.ex`
   - `lib/lattice_stripe/testing/test_clock/*`
   - The entire prior `.planning/v1.0-phases/` layout and a v1.0 milestone directory
   
   Recoverable via `git show 39b98c9^:<path>` but **not available to downstream code today**. This is the root driver of locked decision D1 (restore commit).

2. **WR-01 is already fixed on `main`** (commit `0628bbd fix(14): support nested subscription_details.proration_behavior in guards`). `Billing.Guards.has_proration_behavior?/1` now checks both top-level `"proration_behavior"` and nested `subscription_details.proration_behavior`. Phase 14's `14-VERIFICATION.md` is stale on this point. What's still missing is **`items[].proration_behavior`** coverage (the batch-update form that `Subscription.update` hits when changing items) — that's the extension this phase ships.

---

## Stripe API surface (Subscriptions)

### Endpoints in scope
| Verb | Endpoint | Maps to |
|------|----------|---------|
| POST | `/v1/subscriptions` | `Subscription.create/3` |
| GET | `/v1/subscriptions/:id` | `Subscription.retrieve/3` |
| POST | `/v1/subscriptions/:id` | `Subscription.update/4` |
| DELETE | `/v1/subscriptions/:id` | `Subscription.cancel/4` |
| POST | `/v1/subscriptions/:id/resume` | `Subscription.resume/3` (dedicated endpoint) |
| GET | `/v1/subscriptions` | `Subscription.list/3` + `stream!/2` |
| GET | `/v1/subscriptions/search` | `Subscription.search/3` + `search_stream!/3` |

**No dedicated pause endpoint.** Pausing is done via `update` with `pause_collection: {behavior: ...}`. This shapes D5.

### Endpoints in scope (SubscriptionItem)
| Verb | Endpoint | Maps to |
|------|----------|---------|
| POST | `/v1/subscription_items` | `SubscriptionItem.create/3` |
| GET | `/v1/subscription_items/:id` | `SubscriptionItem.retrieve/3` |
| POST | `/v1/subscription_items/:id` | `SubscriptionItem.update/4` |
| DELETE | `/v1/subscription_items/:id` | `SubscriptionItem.delete/3` |
| GET | `/v1/subscription_items?subscription=:sub_id` | `SubscriptionItem.list/3` + `stream!/2` |

**Deferred endpoints** (not Phase 15):
- `/v1/subscription_items/:id/usage_records` — deprecated in favor of Billing Meters, skip
- `/v1/billing/meters` and `/v1/billing/meter_events` — belongs to BILL-07 future phase

---

## Cross-SDK survey — lessons learned

### stripe-ruby
- Separate `cancel` method on Subscription resource (not just DELETE in update) — cleaner DX, matches the user's mental model. LatticeStripe should match.
- No explicit pause helper — users call `update(id, pause_collection: {...})` directly. Users complain in issues about having to remember the exact shape.
- Resource class has `items` as an array of `SubscriptionItem` instances — confirms D4.

### stripe-python
- Same separate `cancel` approach. Also has `modify` as an alias for update which we reject (confusing).
- Uses `delete_discount` as part of Discount resource, not Subscription — confirms Phase 15 exclusion.

### stripe-node
- TypeScript types on every nested object by default — heavier than our approach but validates that users want `items`, `automatic_tax`, `pause_collection`, `cancellation_details` typed for IDE completion. Guides typed-struct promotion decisions.

### stripe-go
- Uses individual params structs per endpoint — heavier than our map-based approach. Not copying this pattern, but the SubscriptionItem CRUD param shape is well-documented there.

### stripity_stripe (Elixir community SDK — LatticeStripe's predecessor space)
- **Known bug:** nested items in Subscription response missing `id` field, making programmatic updates impossible. LatticeStripe MUST preserve `id` on every SubscriptionItem even when returned as part of a Subscription. This drives the "full SubscriptionItem struct in `Subscription.items`" requirement, not a reduced inline version.
- **Known pain point:** struct hierarchy is cited in its issue tracker as a maintenance pain. They promoted too many nested fields. LatticeStripe's "only 5 typed nested fields" is a direct response.
- **Known pain point:** form encoding of nested params (issues #208, #210 on their tracker). `items[]` array encoding was the biggest source of bugs. LatticeStripe's `form_encoder.ex` handles this — Phase 15 must verify `items[0][price]`, `items[0][quantity]`, `items[0][proration_behavior]` encode correctly in tests.
- Subscription lifecycle verb fragmentation — users complained about inconsistent naming. D5 directly addresses this.

### Usage Records deprecation status
Stripe has been pushing the Billing Meters API (`/v1/billing/meters`, `/v1/billing/meter_events`) as the replacement for Usage Records since the 2024.x–2025.x API versions. Usage Records still works but is legacy. **Building UsageRecord support in Phase 15 is shipping tech debt.** BILL-07 explicitly frames this as a future phase. Confirmed via Stripe API changelog.

---

## Codebase deep-dive — patterns already locked (do not re-litigate)

Phases 4 / 5 / 6 / 14 established every pattern Subscription needs:

### Struct construction
- `@known_fields` list for top-level typed fields
- `extra` field (plain map) catches unknown/future fields for forward compatibility
- `from_map/1` does the split: known fields go to struct fields (recursively building nested typed structs), unknown fields go to `extra`
- PII-safe custom `Inspect` implementation — hides customer email, payment_settings internals, any raw auth
- No `Jason.Encoder` derivation — Stripe SDK output is not JSON-serialized by users typically
- **Flat module namespace** (Phase 1 D-17) — `LatticeStripe.SubscriptionItem`, not `LatticeStripe.Subscription.Item`

### Function signatures
- Every tuple-returning function has a bang variant (Phase 6 D-37)
- `Resource.require_param!/3` for validated required params
- `List.stream!/2` for cursor pagination, returns a lazy `Stream`
- `search_stream!/3` for the `search` endpoint (Phase 6 precedent in `Checkout.Session`)
- Standard `opts` keyword includes `:idempotency_key`, `:stripe_account`, `:api_version` pass-through

### Error handling
- `{:error, %LatticeStripe.Error{type: :proration_required}}` is the existing guard failure shape — Phase 15 reuses this exact type for guard rejections.

### Request pipeline
- Resource module builds `%LatticeStripe.Request{}` (method, path, params, opts) — pure data
- `Client.request/2` dispatches through the Transport behaviour
- Unit tests use `Mox` against the Transport behaviour; integration tests hit stripe-mock via a dedicated `test_integration_client/0`

### Telemetry
- General `[:lattice_stripe, :request, :start|:stop|:exception]` events emitted by `Client.request/2` — subscription CRUD piggybacks on these. **No new subscription-specific telemetry events** — subscription state transitions belong to user webhook handlers, not the SDK.

---

## Typed nested struct promotion heuristic

Phase 4 D-06 default: "nested = plain map." Phase 14 promoted 4 Invoice fields based on "do users pattern-match on this in real integration code?" Phase 15 applies the same heuristic and lands on these 5:

| Field | Promote? | Reason |
|-------|----------|--------|
| `items` | ✅ (list of SubscriptionItem) | Users pattern-match constantly — find price, change quantity |
| `automatic_tax` | ✅ (reuse Invoice.AutomaticTax) | Same shape as Invoice; don't duplicate |
| `pause_collection` | ✅ (new) | Users pattern-match on `behavior` when handling paused subs |
| `cancellation_details` | ✅ (new) | Users pattern-match on `reason` for churn analytics |
| `trial_settings` | ✅ (new) | Users pattern-match on `end_behavior.missing_payment_method` in trial-expiry flows |
| `billing_thresholds` | ❌ map | Simple key-value, read once, never matched |
| `pending_invoice_item_interval` | ❌ map | Rare, edge case |
| `pending_update` | ❌ map | Only populated during pending updates, niche |
| `transfer_data` | ❌ map | Connect-only, future phase territory |
| `metadata` | ❌ map | Always map by convention |
| `plan` | ❌ map | DEPRECATED by Stripe in favor of `items[].price`, don't encourage |

## Validation Architecture

The Phase 15 work is exercised at four levels; the validation strategy document (`15-VALIDATION.md`) should wire test coverage to each.

1. **Unit — struct construction & decode**
   - `Subscription.from_map/1` round-trips every documented field
   - Unknown fields end up in `extra` (forward compatibility)
   - Nested typed structs (`PauseCollection`, `CancellationDetails`, `TrialSettings`) decode correctly
   - `items` list decodes into full `[%SubscriptionItem{}]` with `id` preserved
   - `automatic_tax` reuses `Invoice.AutomaticTax`
   - Custom `Inspect` hides PII (no customer email, no payment_settings internals)

2. **Unit — request building & dispatch (Mox against Transport)**
   - Every function (`create`, `retrieve`, `update`, `cancel`, `resume`, `pause_collection`, `list`, `search`, `stream!`, `search_stream!`) builds the correct `%Request{}`
   - Bang variants raise on error
   - `Resource.require_param!/3` rejects missing required params
   - Guard rejects `{:error, %Error{type: :proration_required}}` when proration required and not specified

3. **Unit — guard extension**
   - `has_proration_behavior?/1` returns true for top-level, nested `subscription_details`, AND any item in `items[]` with `proration_behavior`
   - Returns false for empty lists, missing keys, non-map items (defensive, no crashes)
   - Existing top-level and `subscription_details` cases still pass

4. **Integration — stripe-mock**
   - Full Subscription CRUD + lifecycle round-trip against stripe-mock
   - Full SubscriptionItem CRUD round-trip
   - `form_encoder.ex` correctly encodes `items[0][price]`, `items[0][quantity]`, `items[0][proration_behavior]`
   - `Subscription.stream!/2` paginates correctly across multiple pages
   - `Subscription.search_stream!/3` paginates
   - Pause → resume round trip preserves subscription identity

5. **Docs — ExDoc rendering**
   - `guides/subscriptions.md` renders cleanly under Billing module group
   - Subscription + SubscriptionItem + 3 nested modules appear in Billing module group in mix.exs extras

---

## Security Threat Model Hooks (for planner)

This phase operates inside an authenticated HTTP SDK boundary. Threats the planner's `<threat_model>` block should enumerate:

- **T1 — PII leakage via Inspect / logs** — Subscription objects carry `customer`, `payment_settings`, `default_payment_method`, cancellation feedback comments. Mitigation: custom `Inspect` (matches Invoice pattern), no default logging of struct contents. (ASVS V8)
- **T2 — Idempotency replay** — `create`/`update`/`cancel` mutations without idempotency keys can double-charge on retry. Mitigation: `opts[:idempotency_key]` pass-through already exists; tests must confirm it's forwarded on every mutation path. (ASVS V1)
- **T3 — Proration guard bypass** — If `items[]` extension is missing, a user with `require_explicit_proration: true` could unintentionally prorate by changing items without specifying `proration_behavior`. Mitigation: guard extension + guard tests (this phase explicitly delivers this). (ASVS V11)
- **T4 — Webhook confusion** — Developers may try to drive subscription state transitions from SDK responses instead of webhooks. Mitigation: `guides/subscriptions.md` must include an explicit "subscription state transitions belong to webhook handlers" callout. (ASVS V1 documentation control)
- **T5 — Form encoder injection via nested params** — Malicious metadata keys with `[`, `]`, `&`, `=` could corrupt the encoded body. Mitigation: rely on existing `form_encoder.ex` escaping (verified in Phase 1); tests should include a metadata injection case. (ASVS V5)

---

## Canonical references

See `15-CONTEXT.md` `<canonical_refs>` — full list of files the planner and executor must read.

---

## Open questions for the planner

- **OQ-1** — Should `Subscription.cancel/4` accept a bare id (no params) as `cancel/3`? The 4-arity form with optional params is listed in D2; a 3-arity convenience would match some users' mental models. Recommend: **yes, add `cancel/3` that delegates to `cancel/4` with `%{}`** — matches Phase 6 `Checkout.Session.expire` pattern.
- **OQ-2** — Should `SubscriptionItem.list/3` require `subscription` param, or accept it as optional (Stripe's API allows it optional for admin-like listings)? Recommend: **require it via `Resource.require_param!/3`** — the un-filtered list is an antipattern for production SaaS and stripity_stripe users complain about accidental full-list queries.
- **OQ-3** — Telemetry — reconfirm: **no new events**, piggyback on request-level only. (Draft says yes; flag for planner to confirm in PLAN.md rather than silently.)

These are for the planner to resolve and record in PLAN.md's decisions section.

---

## RESEARCH COMPLETE
