# Research: Pitfalls — Billing + Connect in lattice_stripe v2.0

**Mode:** Ecosystem (pitfall-focused)
**Confidence:** HIGH for Stripe API behaviors; MEDIUM for "what other SDKs get wrong" (based on public issue tracker patterns)
**Target phases:** 12–19 (v2.0 Billing & Connect)
**Researched:** 2026-04-12

## Severity Legend

- **CRITICAL** — Silent data corruption, charges to wrong accounts, or broken callers. Must fix in SDK.
- **HIGH** — Surprising behavior that causes on-call incidents. SDK should guard or validate.
- **MEDIUM** — Documentation-only footgun; caller problem, but docs must be loud.

---

## CRITICAL Pitfalls

### C1. `proration_behavior` default silently varies across endpoints and API versions

**What goes wrong:** `Subscription.update(client, sub_id, %{"items" => [...]})` expecting no proration, gets a prorated invoice. Stripe's defaults differ:
- `POST /v1/subscriptions` (create): no proration applies
- `POST /v1/subscriptions/:id` (update): defaults to `create_prorations`
- `POST /v1/subscription_items/:id`: defaults to `create_prorations`
- `POST /v1/subscription_schedules/:id`: phase-dependent, defaults to `create_prorations` on phase transition

Silent inheritance is a time-bomb when callers bump `api_version`.

**Why:** Stripe applies defaults server-side when a param is omitted. Pass-through SDKs inherit whatever Stripe does today.

**Prevention (SDK-level):**
1. In `Subscription.update/3`, `Subscription.cancel/3`, `SubscriptionSchedule.update/3`, `SubscriptionItem.update/3`, `Invoice.upcoming/2`: validate `proration_behavior` presence when mutation-class. If absent AND `client.require_explicit_proration == true`, return `{:error, %Error{type: :proration_required, ...}}`.
2. Ship `LatticeStripe.Billing.ProrationBehavior.validate!/1` accepting string values `"create_prorations" | "always_invoice" | "none"` (strings, matching v1's wire format). Reject atoms with a clear message pointing to the string form.
3. Default `require_explicit_proration: false` for back-compat. Heavily document in Subscriptions guide; recommend `true` for new apps.
4. Never set a proration default inside the SDK — let Stripe's server apply its default when caller opts out (forward-compat).

**Phase:** 15 (Subscriptions, primary). 14 (Invoice.upcoming). 16 (Schedules).

**How to test:**
- Unit: Mox-based — `Subscription.update/3` returns `{:error, :proration_required}` when flag on + param missing.
- Unit: `ProrationBehavior.validate!/1` accepts the three strings, rejects atoms + unknown strings.
- Integration (stripe-mock): omitting and passing `proration_behavior` both succeed HTTP-wise but SDK path only encodes when present.
- Integration (stripe-mock + TestClock): create sub, advance past period boundary, update with `proration_behavior=none`, assert no proration line items.

---

### C2. Subscription `incomplete` → `incomplete_expired` 23-hour hard cancel window

**What goes wrong:** Sub created, first PaymentIntent requires SCA or fails, Sub goes `incomplete`. If customer doesn't complete auth within **23 hours**, Stripe auto-transitions to `incomplete_expired` — permanently dead, no retry, no rescue. Callers treating `incomplete` as "will self-heal" end up with dead subs.

**Why:** Stripe's SCA compliance model needs a firm deadline. 23 hours is a hard Stripe-side timer, not configurable.

**Prevention:**
1. `Subscription` `@moduledoc` documents the state machine explicitly, with a Mermaid or ASCII diagram showing `incomplete —23h→ incomplete_expired` as a one-way edge.
2. `Subscription.status_is_terminal?/1` helper returns `true` for `"incomplete_expired" | "canceled" | "unpaid"`. Use in webhook handlers to short-circuit rescue logic.
3. `LatticeStripe.EventType` documents that `incomplete → incomplete_expired` fires as `customer.subscription.updated`, not `.deleted` — a common surprise.
4. Subscriptions guide: "Don't rely on `incomplete` self-healing. Use `payment_behavior: default_incomplete` + frontend confirmation, or `payment_behavior: error_if_incomplete` to fail fast server-side."

**Phase:** 15 (Subscriptions).

**How to test:**
- Integration (stripe-mock + TestClock): create sub with failing test card, advance 24h, assert `incomplete_expired`. Note: stripe-mock may not simulate this transition; backstop with real test-mode CI.
- Unit: `status_is_terminal?/1` truth table.

---

### C3. Connect `Stripe-Account` header scoping — platform vs connected account

**What goes wrong:** `Customer.create(client, %{"email" => "x@y.com"})` without `stripe_account` creates the Customer **on the platform**, not the connected account. Later `Subscription.create(client_with_account, %{"customer" => "cus_xxx"})` returns `resource_missing: No such customer` because the Customer is in the wrong namespace.

Inverse: accidentally including `Stripe-Account` on a `PaymentMethod.attach` for a platform-level customer attaches nothing, or — worse in direct-charge mode — moves the attach to the wrong context silently.

**Security implication:** Cross-tenant leak possible if a platform caches customers by email on the platform and reads them from connected-account context.

**Why:** `Stripe-Account` is a **context switch**. Every resource lookup/mutation is scoped to that account. No implicit "try both" — different namespaces entirely.

**Prevention:**
1. Keep v1's existing per-request `stripe_account` option.
2. Add telemetry metadata: `stripe_account: "acct_xxx" | nil` on the request span. Grep-able in logs.
3. Connect guide: ship a "Context matrix" table — which resources **must** be scoped (PaymentIntent direct charges, Customer for Express/Custom onboarding), **must not** be scoped (`Account.create` for new connected account, `AccountLink.create`).
4. `LatticeStripe.Connect` namespace doc module with top-level warning: *"The `stripe_account` option switches execution context. A client without it talks to the platform; with it, to the connected account. These are different data universes."*
5. Ship `LatticeStripe.Client.with_account(client, "acct_xxx")` returning a new Client struct with the header baked in. Makes per-context paths explicit and greppable.

**Phase:** 17 (Connect Accounts/Links).

**How to test:**
- Integration (stripe-mock): `Customer.create` without vs with `stripe_account`, assert headers differ, params identical.
- Unit: `with_account/2` returns new struct with `stripe_account` set; immutability check.
- Doc-test: Connect guide code samples compile and run against stripe-mock.

---

### C4. Invoice finalization race — ~1h auto-finalize after creation

**What goes wrong:** Caller does `Invoice.create(...)` intending to add line items via a follow-up call. After ~1 hour, Stripe **auto-finalizes the draft**. Now `Invoice.update` returns `invoice_not_editable` and CI fails mysteriously.

**Why:** Stripe auto-advances draft invoices via an async worker. `auto_advance` default differs by creation path — `true` for subscription-generated, `false` for manual.

**Prevention:**
1. In `Invoice.create/2`: if caller omits `auto_advance`, emit telemetry event `[:lattice_stripe, :invoice, :auto_advance_unset]` (silent in prod, catchable in dev logger). Do NOT change Stripe's default.
2. Invoice guide documents the canonical order:
   ```
   create(%{"customer" => id, "auto_advance" => false, ...})
     → add_invoice_items
     → finalize
     → pay
   ```
3. Ship `Invoice.finalize/2`, `pay/2+3` as first-class verbs.
4. Error catalog: `invoice_not_editable` → likely means auto-finalized.

**Phase:** 14 (Invoices).

**How to test:**
- Integration (stripe-mock + TestClock): create with `auto_advance=false`, advance 2h, assert still `draft`, update succeeds.
- Integration: create with `auto_advance=true`, advance clock, assert status transitions and subsequent `update/3` returns typed error.
- Unit: telemetry warning fires when `auto_advance` absent.

---

### C5. `SubscriptionSchedule` owns its Subscription — direct mutations conflict

**What goes wrong:** Caller creates a SubscriptionSchedule (quarterly upgrade path), 3 months later calls `Subscription.update(sub_id, %{"items" => [new_plan]})` directly. Schedule's next phase transition wipes those changes, or fails with `subscription_schedule_not_released` — customer stuck.

**Why:** SubscriptionSchedule is the source of truth for the sub's plan trajectory. Stripe treats the Subscription as a rendered view of the Schedule's current phase.

**Prevention:**
1. `Subscription.update/3` `@doc`: **loud warning** that if `sub.schedule` is not nil, you likely want `SubscriptionSchedule.update/3`.
2. `SubscriptionSchedule.release/2`: document as the "convert scheduled sub back to free-standing" mechanism.
3. `Subscription` struct surfaces `:schedule` as a typed field so callers can pattern-match `%Subscription{schedule: nil}`.
4. **Discussion item** for Phase 16: should `Subscription.update/3` return `{:error, :schedule_owned}` when `sub.schedule` is non-nil? Opinionated, prevents a valid use case (one-off override within phase). Default to docs-only for v0.3.0.

**Phase:** 16 (Subscription Schedules). Cross-file doc update in 15.

**How to test:**
- Integration (stripe-mock): create sub via schedule, attempt direct update, assert `:schedule` populated.
- Unit: struct decoder lifts `schedule` from raw JSON into typed field.

---

## HIGH Pitfalls

### H1. `cancel_at_period_end: true` keeps status `"active"` — not `"canceled"`

**What goes wrong:** Tests assert `sub.status == "canceled"` after `Subscription.update(sub, %{"cancel_at_period_end" => true})`. Status still `"active"`. Only transitions to `canceled` when period ends. CI passes locally, fails in production because clock time differs.

**Why:** `cancel_at_period_end` is a scheduling flag, not a state transition. Sets `sub.cancel_at = period_end` and `cancel_at_period_end = true`, but keeps serving until Stripe's billing worker runs at period boundary.

**Prevention:**
1. `Subscription.cancel/2+3` `@doc` distinguishes two modes prominently:
   - `cancel/2` (immediate): status → `canceled` synchronously.
   - `cancel/3` with `cancel_at_period_end: true`: flag set, status stays `active`, cancellation deferred.
2. `Subscription.cancellation_pending?/1` returns `true` when `cancel_at_period_end == true`. Useful in UI ("your plan ends on X").
3. Document webhook sequence: `customer.subscription.updated` fires when flag set; `customer.subscription.deleted` fires when period ends and cancel executes.

**Phase:** 15 (Subscriptions).

**How to test:**
- Integration (stripe-mock + TestClock): set flag, assert unchanged; advance past period_end, assert `canceled`.
- Unit: `cancellation_pending?/1` truth table.

---

### H2. Webhook event ordering — `invoice.paid` can arrive before `invoice.finalized`

**What goes wrong:** Handler assumes `finalized` precedes `paid`. Stripe's distributed queue has at-least-once semantics with best-effort ordering. Retries reorder. Handler that creates local record on `finalized` and marks paid on `paid` hits foreign-key race and 500s.

**Why:** Stripe webhook delivery is at-least-once with best-effort ordering. Cross-event-type ordering never guaranteed.

**Prevention:**
1. Fundamentally caller's problem — SDK can't fix ordering. Educate.
2. Webhooks guide: "Handling out-of-order events" section:
   - Order by event `created` timestamp, not arrival.
   - Make handlers idempotent: upsert by Stripe ID, not insert.
   - When dependent event arrives before prerequisite, fetch current state via `retrieve/2` instead of relying on event payload.
3. Ship `LatticeStripe.Event.created_at/1` returning `DateTime` from unix timestamp. Tiny ergonomic that makes "order by created" obvious.
4. Document which events can arrive out of order (invoice lifecycle, subscription updates) vs tightly ordered (payment_intent within a single intent).

**Phase:** 19 (cross-cutting, Webhooks guide update). Optional helper in Phase 15.

**How to test:**
- Unit: `Event.created_at/1` returns DateTime from integer.
- Doc-test: guide's idempotent handler example compiles.

---

### H3. Search eventual consistency — just-created resources don't show up

**What goes wrong:** `Customer.create` → immediate `Customer.search(query: "email:'x@y.com'")` returns empty. Stripe search is async-indexed; resources take ~1s (sometimes longer) to appear.

**Why:** Stripe search is backed by an Elasticsearch-style eventually-consistent store.

**Prevention:**
1. Every `search/2` `@doc` (Customer, Invoice, PaymentIntent, Charge, Price, Product, Subscription) includes: *"Search is eventually consistent. Resources created within the last ~1 second may not yet appear. For immediate reads, use `retrieve/2` with a known ID or `list/2` with filters."*
2. Do **not** bake retry-loops into `search/2` — hides semantics and wastes quota. stripe-ruby and stripe-node both document the delay without retrying.
3. `LatticeStripe.Search` module doc explains the search pagination shape (`page` / `next_page`, not `starting_after`).

**Phase:** 19 (cross-cutting — Search.stream! + docs). Per-resource doc updates in 12, 14, 15.

**How to test:**
- Integration: skip. stripe-mock doesn't simulate indexing delay reliably.
- Doc-test: callout text exists in every relevant `@moduledoc`.

---

### H4. `BillingTestClock` fixture isolation + async advancement + cleanup

**What goes wrong:**
- (a) Developer creates Customer + Sub **outside** any clock, then creates a clock and tries to test advancement — nothing happens because fixtures aren't attached. **All resources under test must be created with `test_clock: "clock_xxx"` at creation time.**
- (b) Tests leak clocks between runs. Stripe allows ~100 test clocks per account; CI eventually hits the limit.
- (c) `clock.advance/3` is **async** — returns with `status: "advancing"`. Tests asserting on sub state before advancement completes see stale status.
- (d) stripe-mock clock simulation is incomplete (see M3).

**Why:** Clocks are Stripe's deterministic-time sandbox. Strict isolation prevents cross-contamination. Advancement is async because Stripe has to re-run the billing worker pipeline.

**Prevention:**
1. `BillingTestClock.advance/3` returns the clock with `status: "advancing"`. Ship `advance_and_wait/3` (or `await_ready/2`) polling `retrieve/2` until `status == "ready"` with configurable timeout. Matches stripe-node's `clock.advance + clock.retrieve` pattern.
2. Billing guide: **always** pass `test_clock` param when creating fixtures under a clock.
3. Add Mix task `mix lattice_stripe.test_clock.cleanup` (or ExUnit helper in `test/support/`) listing + deleting clocks tagged with test marker metadata. Run in CI `after` hook.
4. Document the 100-clock limit; recommend tagging via `metadata: %{"lattice_stripe_test" => "true"}` for cleanup.

**Phase:** 13 (TestClocks — pulled forward for exactly this reason).

**How to test:**
- Integration (stripe-mock): create clock, create sub with `test_clock`, advance, poll, assert transitions.
- Unit: `advance_and_wait/3` timeout path returns `{:error, :timeout}`.
- ExUnit support helper compiles in a sample test.

---

### H5. Meter events eventual consistency (Tier 4, deferred — but design now)

**What goes wrong:** Usage-based system does `MeterEvent.create(...)`, queries `MeterEventSummary.list(...)`, expects the new event. Stripe's meter aggregation is async; events land in summaries after a delay of up to several minutes.

**Why:** Stripe's meter system is designed for high-volume telemetry (API gateways billing per-request). Synchronous aggregation wouldn't scale.

**Prevention (forward-looking for v0.5.x):**
1. Don't design `MeterEvent.create/2` to return an enriched struct implying aggregation. Return raw response — `%MeterEvent{status: "pending", ...}` ack shape.
2. `@moduledoc` opens with: *"Meter events are processed asynchronously. Expect a delay of up to several minutes before events appear in `MeterEventSummary.list/3`. Do not use meters for synchronous UI flows."*
3. Foundational choice now (v0.3.0): `LatticeStripe.Resource` helper's `create` return shape should remain flexible as "ack-only" vs "full resource" without breaking changes. Already flexible in v1 (returns raw `Response`) — just note Meters shouldn't sugar it.

**Phase:** Design note for Phase 19; actual implementation in future v0.5.x.

---

### H6. `BillingPortal.Session` URL expiry (Tier 3, deferred — but note)

**What goes wrong:** Caller creates portal session, stores URL in DB, uses it a day later — URL is dead. Portal session URLs expire quickly (~5 min to first click, then ~1h valid). **Not reusable across customers or long-lived.**

**Why:** Portal session URLs embed short-lived signed tokens for security.

**Prevention (for v0.4.x):**
1. `BillingPortal.Session.create/2` returns `%Session{url: url, expires_at: datetime | nil}` populated from Stripe's response or computed as `created + 1h`.
2. `@moduledoc`: *"Portal session URLs are single-use and short-lived. Generate a fresh session on every portal entry; do not cache URLs."*

**Phase:** Future (v0.4.x). Note only in v0.3.0 research.

---

### H7. Connect Account deletion and live-mode immutability

**What goes wrong:** `Account.delete(client, "acct_xxx")` on a live-mode Standard connected account returns 400/401. Only Custom/Express (and all test-mode) are deletable. Standard accounts are also largely immutable post-onboarding — `Account.update` with business fields returns `account_invalid`.

**Why:** Standard connected accounts are owned by the account holder (not the platform). Platform's relationship is oauth-authorized; deletion is via deauthorization, not resource delete. Live accounts have regulatory retention obligations.

**Prevention:**
1. `Account.delete/2` `@doc` prominent callout: *"Only test-mode accounts and Custom/Express live accounts can be deleted. Deleting a Standard live account is not supported — use oauth deauthorization via the platform dashboard. Returns `{:error, %Error{type: :invalid_request, code: \"account_cannot_be_deleted\"}}` on such accounts."*
2. `Account.update/3` `@doc`: Standard accounts accept only a narrow subset of fields post-onboarding; link to Stripe's "Updating accounts" doc.
3. Connect guide: "Which Account type?" decision matrix.

**Phase:** 17 (Connect Accounts).

**How to test:**
- Integration (stripe-mock): create test account, delete, assert 200. Note: stripe-mock likely permits deletion always; negative path is doc-test only.
- Unit: error normalization maps `account_cannot_be_deleted` to typed Error.

---

### H8. Params serialization — nested arrays and `expand` with indices

**What goes wrong:** v1's `FormEncoder` handles most cases. Billing introduces nasty shapes:
- `items[0][price]=price_xxx&items[0][quantity]=2` — array of maps (v1 handles)
- `discounts[0][coupon]=X&discounts[1][promotion_code]=Y` — Billing-specific multi-discount
- `expand[]=data.customer&expand[]=data.subscription.default_payment_method` — nested dot paths (v1 handles)
- `add_invoice_items[0][price_data][currency]=usd&add_invoice_items[0][price_data][product]=prod_xxx` — **triple-nested**: array of maps containing maps containing scalars. `Subscription.update` with `add_invoice_items` is notoriously ugly
- `automatic_tax[enabled]=true` — boolean-nested in top-level map. Booleans must serialize as `"true"`/`"false"` strings. v1 should handle; audit

**Why:** Stripe's form encoding is idiosyncratic. Array-of-maps uses `[index]`, nested maps use `[key]`, booleans are stringified.

**Prevention:**
1. Phase 12 (Products/Prices) and Phase 15 (Subscriptions) each include an integration test battery hitting stripe-mock with the complex shapes. stripe-mock validates form encoding against OpenAPI.
2. Explicit unit tests for `FormEncoder`:
   - `items[n][price_data][recurring][interval]` (4 levels deep)
   - `discounts` array with mixed coupon/promotion_code keys
   - `metadata` with keys containing dots
   - `expand` with 3-level dot paths
3. Price + Subscription guides document the exact map shapes with working examples for `price_data` inline creation.

**Phase:** 12 (Products/Prices), 15 (Subscriptions).

**How to test:**
- Unit: `FormEncoder.encode/1` round-trips the battery.
- Integration (stripe-mock): create Subscription with inline `price_data` in items, assert 200.

---

## MEDIUM Pitfalls (Docs-Only)

### M1. Event type drift across API versions

**What goes wrong:** Stripe adds new webhook event types with each API version bump. Hand-maintained `LatticeStripe.EventType` goes stale; caller pattern matches silently miss new events.

**Prevention:**
1. Phase 19 adds Mix task `mix lattice_stripe.gen.event_types` fetching Stripe's OpenAPI spec (cached, not build-time default), diffing against the module, emitting CI warning on drift. Do NOT regenerate automatically — humans should review additions.
2. CI job (separate workflow, weekly cron): run drift check, open an issue on drift. Low-maintenance tripwire.
3. Pin catalog to API version in `Client`'s default (`2026-03-25.dahlia`). Doc: *"Catalog accurate as of Stripe API version X. If you pin newer, run `mix lattice_stripe.events.drift`."*

**Phase:** 19 (Cross-cutting EventType catalog).

---

### M2. "Strict mode" opinionated flags — community reception

**What goes wrong:** `require_explicit_proration` is a strict-mode toggle. Research from Ruby/Node ecosystems:
- **stripe-ruby / stripe-node / stripe-python**: no strict modes. Pure pass-through; opinions belong at caller's level.
- **stripity_stripe** (stale Elixir lib): also pass-through.
- **Rails `pay` gem**: opinions at its own level, not SDK's. Community likes this split: "SDK = dumb wire, high-level lib = opinions."
- **Laravel Cashier**: opinionated, but Cashier IS the wrapper, not the SDK.

Adding `require_explicit_proration` is a departure from Ruby/Node/Python norms. **Aligned with Elixir community's bias for explicitness** (Ecto's `required_fields`, NimbleOptions). Risk: stripe-ruby migrators surprised.

**Mitigation:** Opt-in, defaults to `false`, heavily documented, framed as "strict mode" not "default mode."

**Recommendation:** Ship it. Default off. Document as first-class feature in Subscriptions guide. Mention in release notes as opt-in.

**Phase:** 15 (implement flag), 19 (document in guide).

---

### M3. stripe-mock coverage gaps

**What goes wrong:** stripe-mock is generated from OpenAPI. Validates **shape**, not **semantics**. Known gaps for v0.3.0:

- **TestClocks:** stripe-mock accepts create/advance but **does not simulate time-advance effects** on subscriptions, invoices, or meter events. Advancing doesn't cause renewal/invoice generation. Integration tests for lifecycle depending on clock effects **must** run against real Stripe test mode.
- **Webhook event firing:** stripe-mock doesn't fire webhooks. Webhook signature verification is v1 functionality (tested in isolation); integration flow testing needs a different approach.
- **Search:** deterministic stubs, not a real index. Eventual-consistency delay not simulated.
- **Connect:** accepts `Stripe-Account` header but doesn't enforce cross-account isolation. Tests can verify header is **sent**, not enforced.
- **Billing Portal:** stub URLs, not real.
- **SubscriptionSchedule phase transitions:** shape returned, transitions not executed on clock advance.

**Prevention — two-tier integration testing strategy**, documented in CONTRIBUTING:
- **Unit/stripe-mock tier** (always runs in CI): verifies request shape, response parsing, error normalization, header presence. Fast, hermetic.
- **Real test-mode tier** (gated behind `STRIPE_TEST_SECRET_KEY` env var, opt-in, tag `:real_stripe`): verifies end-to-end semantics — clock effects, webhook delivery, search indexing. Runs nightly or on release candidates.

Each test file with semantic assertions stripe-mock can't satisfy uses `@tag :real_stripe` and skips unless env var set.

Phases needing real-Stripe coverage: 13 (clocks), 14 (invoice auto-advance), 15 (subscription lifecycle), 16 (schedule phase transitions).

**Phase:** 13 (first impact). Phase 19 (strategy documentation).

**Open question:** stripe-mock clock simulation status may have improved since knowledge cutoff. Spike at start of Phase 13 to confirm.

---

### M4. Release Please with multi-phase milestone — conventional commit scopes

**What goes wrong:** Milestone spans 8 phases with multiple commits. Inconsistent scopes (`feat(billing)`, `feat(subscription)`, `feat:`) produce incoherent CHANGELOG.

**Prevention:**
1. CONTRIBUTING documents scope conventions for v0.3.0 phases up front:
   - `feat(billing):` for Tier 1 resources (Phases 12–16)
   - `feat(connect):` for Tier 2 (Phases 17–18)
   - `feat(sdk):` for cross-cutting (Phase 19)
2. Release Please v4 handles scopes — each `feat(...)` becomes a CHANGELOG section, any `feat:` bumps minor.
3. `BREAKING CHANGE:` footer bumps major. v0.3.0 is pre-1.0 so minor bumps for breaking changes is fine per SemVer, but document clearly. Avoid footer misuse.
4. Optional v0.3.0-rc1 pre-release after Phase 16 requires Release Please manifest mode with `prerelease: true`. Confirm v1 config supports this. Easier path: manual git tag `v0.3.0-rc1` outside Release Please (no Hex auto-publish, but downstream consumers can pin git ref).

**Phase:** 19 (release process doc). Decision point: Phase 16 transition (rc1 mechanism).

---

## Phase-Specific Warning Map

| Phase | Title | Critical | High | Medium |
|-------|-------|----------|------|--------|
| 12 | Products/Prices/Coupons/PromoCodes | — | H8 (params) | M3 |
| 13 | TestClocks | — | H4 (isolation/async/cleanup) | M3 |
| 14 | Invoices + upcoming | C1, C4 | H8 | M3 |
| 15 | Subscriptions | C1, C2 | H1, H8 | M2 |
| 16 | Subscription Schedules | C1, C5 | H1 | M4 (rc1 decision) |
| 17 | Connect Accounts/Links | C3 | H7 | — |
| 18 | Connect Transfers/Payouts/Balance | C3 | — | — |
| 19 | Cross-cutting | — | H2, H3, H5, H6 | M1, M3, M4 |

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Stripe API behaviors (C1–C5, H1, H4, H7, H8) | HIGH | Documented in Stripe API reference; well-known community post-mortems. |
| Webhook ordering / search consistency (H2, H3) | HIGH | Stripe documents these explicitly. |
| stripe-mock gap analysis (M3) | MEDIUM | Based on stripe-mock README and issue tracker patterns; exact gap set may have improved. Spike in Phase 13 to confirm clock simulation status before committing to two-tier strategy. |
| Community reception of strict-mode flags (M2) | MEDIUM | Pattern-inference from Ruby/Node ecosystems. Opt-in + default-off de-risks. |
| Release Please v4 multi-scope behavior (M4) | HIGH | v1.0 shipped successfully with Release Please v4; known-good foundation. |
| Meter/Portal forward-compat notes (H5, H6) | MEDIUM | Based on Stripe API docs for deferred modules; architectural impact low. |

---

## Gaps / Recommended Follow-ups

1. **stripe-mock clock simulation status** — spike at start of Phase 13 to confirm which assertions work against stripe-mock vs must defer to real test-mode.
2. **`require_explicit_proration` default** — ship opt-in for v0.3.0, revisit for v1.0 whether to flip default to `true`. Track via GitHub issue.
3. **`with_account/2` helper** (C3 prevention) — low-risk ergonomic. Decide in Phase 17 planning whether to ship or defer.
4. **`Account.update/3` Standard-account field allowlist** — Stripe doesn't expose machine-readable list. Not worth manual curation in v0.3.0; document behavior instead.
5. **Event type drift Mix task** — tripwire design in Phase 19. Decide whether to fetch OpenAPI at build time or commit a snapshot JSON.
