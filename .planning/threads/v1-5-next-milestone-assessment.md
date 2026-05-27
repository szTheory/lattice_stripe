# v1.5 Next-Milestone Assessment

Updated: 2026-05-27

## Why this thread exists

After v1.4 Adoption Closure shipped (2026-05-27), a fresh assessment pass was run before defining v1.5 to (a) re-check how close LatticeStripe is to "done enough" for its intended SDK scope, (b) pick the single highest-leverage next milestone, and (c) retain the research so the next milestone starts informed.

This thread captures the durable findings, the recommendation, and the planned ordering for v1.5 → v1.7. After v1.7, the library is expected to be "done for v1.x scope" absent fresh adopter pull.

## Repo-truth findings to preserve

### Shipped surface (verified by `lib/` scan, not just planning docs)

- ~15.8k LOC across `lib/`, ~50 resource modules, 36 integration test files.
- Full Payments/Checkout/Refunds/SetupIntent/PaymentMethod surface.
- Full Billing surface (Invoice/Subscription/SubscriptionSchedule/SubscriptionItem/Coupon/PromotionCode) plus Billing.Meter/MeterEvent/MeterEventStream.
- Connect (Account family + AccountLink/LoginLink) + money movement (Transfer/TransferReversal/Payout).
- Webhook stack: HMAC verify, Phoenix Plug, Handler behaviour, secret rotation, raw-body reader, signature generation for tests.
- v1.3 breadth: File/FileLink, Dispute (+ typed evidence), CreditNote, Mandate, SetupAttempt, Quote.
- v1.2 hardening: per-op timeouts, warm-up, circuit breaker, OTel guides, request batching, drift detection, LiveBook.
- BillingPortal.Configuration CRUDL + Session.
- Search shipped on: Customer, Invoice, PaymentIntent, Price, Product, Subscription.
- Docs: 26 guides, layered ExDoc groups, 4 flagship recipes, docs-truth regression contract (7 tests).

### NOT shipped (verified by grep, fresh)

- No `Tax.*` module family. Only `automatic_tax` sub-struct on Invoice/Subscription/Checkout/Quote.
- No thin-event (`/v2/events`) webhook handling. `MeterEventStream` lives at `/v2/billing/meter_events` — different `/v2` surface, **not** thin-event webhooks. Snapshot-biased docs assume `event.data["object"]` is authoritative.
- No Identity / Treasury / Issuing / Terminal / Financial Connections / Climate / Sigma / Reporting families.

### Fresh surface gaps surfaced by this assessment

These are **not** captured anywhere else in planning. They are real repo-truth gaps found during the v1.5 assessment pass:

1. **`Charge` module is unusually thin.** Only `retrieve/3` and `from_map/1` (`lib/lattice_stripe/charge.ex`). No `list`, no `search`, no `capture`, no `update`. PaymentIntent-era apps rarely touch Charge directly, but support / reconciliation / audit / refund-lookup workflows do. **Action:** absorb into the v1.7 polish milestone (`Charge.list/3`, `Charge.search/3`, possibly `Charge.capture/4` and `Charge.update/4`). Not v1.5 scope.
2. **`Webhook.check_tolerance/2` `tolerance: 0` is buggy.** Already flagged in `thin-event-webhook-evaluation.md`, but stayed open through v1.3/v1.4. Docstring (`lib/lattice_stripe/webhook.ex:84`) says "Set 0 to disable staleness check" but `check_tolerance/2` always returns `{:error, :timestamp_expired}` for the `0` clause (`lib/lattice_stripe/webhook.ex:268-273`). **Action:** fix as part of v1.5 (any thin-event work touches webhook semantics anyway).

### Hex/version state

- `mix.exs` ships `@version "1.3.0"`.
- v1.4 was a docs/truth pass — no new Hex release.
- Git tags exist for `v1.2`, `v1.3`, `v1.4`. There is no `v1.1` tag (v1.1 was a deliberate internal mini-milestone).
- A v1.5 code milestone (thin events) would be the first new package release since 1.3.0 in April.

## Wedge analysis (compact)

Full research from parallel subagents lives in this session; the durable conclusions:

### Wedge A — Thin-Event Webhook Support `(SELECTED for v1.5)`

- Mainstream Stripe direction: `/v2/events` ("thin events") deliver `{id, type, related_object}` instead of a full snapshot. Adopter must fetch authoritative state after verification.
- Reference shape from other SDKs: stripe-node v49+ exposes `parseEventNotification` returning `Stripe.V2.EventNotification` with `relatedObject` and `fetchRelatedObject()` / `fetchEvent()` methods.
- Concrete LatticeStripe surface to ship:
  - `Webhook.parse_event_notification/3` (parallel to `construct_event/3` but for thin events)
  - `Webhook.fetch_event/2` (typed `Event.t()`)
  - `Webhook.fetch_related_object/2` (returns the underlying typed resource via `ObjectTypes` dispatch — leverages existing v1.2 expand machinery)
  - Extend `Event` struct to surface `context` and `related_object` cleanly
  - Extend `Testing` helpers to emit thin-event payload shapes
  - Reconcile `tolerance: 0` semantics in `Webhook.check_tolerance/2`
- Canonical docs: `guides/webhooks-thin-events.md` with Phoenix handler, fetch-after-verify idempotency, rate-limit guidance (keep delivery <90/s to stay under Stripe's 100 req/s ceiling), Connect/context-aware events.
- Footguns:
  - Snapshot-biased mental models — docs must be explicit about which payload shape carries authoritative state.
  - Fetch-after-verify race conditions — resource may change between webhook send and fetch; idempotency lives in the app.
  - Connect context — thin events carry `context` for connected-account scope; existing `Event.context` already exists, must surface it in guidance.
- Done-enough: implemented helpers + extended Testing + one guide + integration test coverage + `tolerance: 0` reconciled.
- Scope discipline check: pure SDK lane. No Accrue overlap risk.
- Estimated effort: medium (1 phase, 3-5 plans).

### Wedge B — Tax Resource Family `(v1.6 — needs explicit scope negotiation)`

- Missing surface: `Tax.Calculation`, `Tax.Transaction`, `Tax.Settings`, `Tax.Registration`, `TaxId` (nested under `Customer`), `TaxRate` (legacy, low-priority).
- Reference shapes:
  - stripe-node: `tax.calculations.create`, `tax.transactions.create/list/post/void`, `tax.settings.retrieve/update`.
  - Calculation is stateless (90-day validity); Transaction is state-bearing (immutable after `post`).
- Footguns: calculation expiry (90 days), reverse-charge / VAT-exempt edge cases, multi-jurisdiction filing (out of SDK scope — Accrue), nexus & registration thresholds, TaxRate-vs-Tax.Calculation legacy confusion.
- Done-enough: Calculation create/retrieve/list; Transaction create/retrieve/list/post/void; Settings retrieve/update; Registration CRUDL; TaxId nested under Customer; `guides/tax.md` explaining automatic_tax vs explicit Tax API; integration tests under `stripe-mock` covering happy path + expiry + exemption.
- Scope discipline check: **SDK scope for the resource surface only**. Tax *strategy* and *filing orchestration* must be left to Accrue. Negotiate this in the discuss-phase before plan-phase.
- Estimated effort: large (2-3 phases).

### Wedge C — Polish & Operator `(v1.7)`

- Charge surface fill: `list/3`, `search/3`, `capture/4`, `update/4`.
- Audit other thin resource modules for similar surface gaps.
- Phase 41.1 closure: re-run with valid sandbox creds OR retire as accepted external-proof boundary (decide in milestone discuss-phase).
- New guides: `guides/production-checklist.md`, `guides/event-debugging.md`.
- Optional LiveBook: live event tail (`notebooks/event_inspector.livemd`).
- Estimated effort: small (1 phase).

### Wedges D-F — Defer indefinitely

- Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, Reporting: defer until real adopter pull. JTBD doctrine. Treasury/FinConnect are the most plausible future asks; the rest are vertical-specialist territory.

## Recommended ordering

1. **v1.5 — Thin-Event Webhooks** (medium, 1 phase) ← SELECTED PICK
2. **v1.6 — Tax** (large, 2-3 phases)
3. **v1.7 — Polish & Operator** (small, 1 phase; includes Charge surface fill + Phase 41.1 closure + operator guides)
4. **Stop**, unless fresh adopter pull surfaces specifics.

After v1.7 the library is "done for v1.x scope" by any reasonable definition. Further code work risks Accrue scope creep; further docs work hits diminishing returns.

## Why thin events lead over Tax

- Webhook foundation is already strong → additive work, high success probability.
- Stays pure SDK lane → zero Accrue scope-overlap risk.
- Unlocks modern Stripe behavior for **all** existing adopters, not just tax-region adopters.
- Scope is bounded and reference-shaped (stripe-node v49+ pattern).
- Resolves the `tolerance: 0` footgun on the way through.
- Gives the project a code release (1.4.0 or 1.5.0 on Hex) — last release was 1.3.0 in April.

**Conditional override:** if Accrue or another real adopter is blocked on Tax compute *right now*, swap v1.5↔v1.6. Otherwise lead with thin events.

## Graduation candidates surfaced

Reusable cross-project rules confirmed by this assessment:

- **"Verify shipped surface against `lib/` source, not planning docs or milestone names, before defining the next milestone."** Found two real repo-truth gaps (Charge thinness, `tolerance: 0` bug) that no existing planning doc captured. The lesson generalizes: planning artifacts can be coherent and still miss code-truth gaps that only a grep finds.
- **"After a docs-only adoption milestone, prefer a code wedge for the next milestone."** Two reasons: (a) a Hex release with new code value re-anchors public truth; (b) sustaining-only docs work has diminishing returns past one milestone.
- **"Stop signals deserve explicit naming, not just implicit drift."** Identifying v1.7 as the planned "stop" milestone lets future milestones reject scope-creep candidates with a clear reference, instead of drifting into perpetual maintenance.

## Files consulted during this assessment

- `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/MILESTONES.md`, `.planning/RETROSPECTIVE.md`, `.planning/JTBD-MAP.md`
- `.planning/threads/thin-event-webhook-evaluation.md`, `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md`, `.planning/threads/v1-4-adoption-closure.md`
- `.planning/milestones/v1.4-REQUIREMENTS.md`, `.planning/milestones/v1.4-MILESTONE-AUDIT.md`
- `.planning/v1.1-accrue-context.md`, `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`
- `prompts/` deep-research files: the master Elixir gap doc, stripe-sdk-api-surface, stripe-lib-priority-user-flows, elixir-best-practices, phoenix-best-practices, elixir-opensource-libs-best-practices, lattice-stripe-oss-lib-name
- `lib/lattice_stripe.ex`, `lib/lattice_stripe/webhook.ex`, `lib/lattice_stripe/webhook/plug.ex`, `lib/lattice_stripe/webhook/handler.ex`, `lib/lattice_stripe/event.ex`, `lib/lattice_stripe/charge.ex`, `lib/lattice_stripe/quote.ex`, plus directory listings of all subdirectories under `lib/lattice_stripe/`
- `mix.exs`, `README.md`, `CHANGELOG.md`, `git log` and `git tag`
