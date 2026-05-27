# v1.7 Next-Milestone Assessment

Updated: 2026-05-27

## Why this thread exists

After v1.6 Tax shipped and archived (2026-05-27), a fresh adopter-first assessment was run before defining v1.7 to (a) re-check how close LatticeStripe is to "done enough" for its intended v1.x SDK scope, (b) confirm the single highest-leverage next milestone, and (c) retain research so `/gsd-new-milestone` starts informed.

This thread captures durable findings, the v1.7 recommendation (with one scope upgrade), and the planned stop signal after v1.7.

## Done estimate

**~88-90%** (band: 80-89% strong, meaningful wedges remain — trending toward 92-95% after v1.7)

| Rubric dimension | Score | Notes |
|---|---|---|
| Core JTBD coverage | ~92% | PI-first payments, Checkout, subscriptions, portal, metering, invoices, Connect, disputes/files/credits/quotes all shipped |
| Breadth vs category expectations | ~85% | Charge is the only mainstream payment resource with multi-endpoint Stripe API but retrieve-only SDK surface |
| Docs / onboarding / install | ~82% | Excellent ladder + 4 flagship recipes + tax + thin events; version/install truth lags code by 2 milestones |
| Operator / diagnostic posture | ~78% | Strong fragments; missing production checklist + event debugging playbook |
| Proof / CI honesty | ~90% | Mox-at-Transport chains, stripe-mock, docs-truth; Phase 41.1 honestly pending |

## Repo-truth findings (verified by lib/ scan, not planning docs alone)

### Shipped surface (post-v1.6)

- ~152 modules under `lib/lattice_stripe/`, 49 `ObjectTypes` entries, 36 integration test files.
- Full Payments/Checkout/Refunds/SetupIntent/PaymentMethod surface.
- Full Billing surface plus Meter/MeterEvent/MeterEventStream.
- Connect + money movement (Transfer/TransferReversal/Payout).
- Webhook stack: snapshot + thin events (`parse_event_notification`, fetch-after-verify), Plug, Testing helpers.
- v1.3 breadth: File/FileLink, Dispute, CreditNote, Mandate, SetupAttempt, Quote.
- v1.6 Tax: Calculation, Transaction, Settings, Registration, TaxId + `guides/tax.md` + adoption contract tests.
- Docs: 30 guides, layered ExDoc groups, 4 flagship recipes, docs-truth regression contract.

### Remaining code gap (verified)

**`Charge` module is unusually thin.** Only `retrieve/3`, `retrieve!/3`, and `from_map/1` (`lib/lattice_stripe/charge.ex`). No `list`, `search`, `update`, or `capture`. Intentional per Phase 18 D-06; tests encode retrieve-only as contract. PI-first apps rarely touch Charge directly, but support/reconciliation/audit workflows do. **Action:** v1.7 adds `list/3`, `search/3`, `update/4`, `capture/4` (+ bangs, stream variants per PaymentIntent pattern).

### Remaining docs/adoption gaps

- **`mix.exs` `@version "1.3.0"`** while code ships v1.5 thin events + v1.6 Tax — top adopter friction.
- README/getting-started lock `~> 1.3` by docs-truth design; thin-events guide alone says `~> 1.5`.
- **Missing:** `guides/production-checklist.md`, `guides/event-debugging.md` (planned v1.7).
- **JTBD-MAP stale** until refreshed in this assessment pass (thin events, tax, flagship recipes were marked missing).

### NOT shipped (correctly deferred)

- Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, Reporting.
- Tax narrow follow-ups TAX-01 (tax_codes), TAX-02 (transaction list) — adopter pull only.

## Wedge analysis

### Wedge A — v1.7 Polish & Operator (SELECTED)

**Scope upgrade from prior plan:** fold Hex release prep into v1.7 capstone (was "out-of-band") — public install truth is now the biggest adoption leak, not missing Stripe families.

**Phase breakdown:**

1. **Charge surface** — list/search/update/capture + integration tests; four-surface triangulation (moduledoc + code + tests + docs-truth).
2. **Operator guides** — `production-checklist.md`, `event-debugging.md`; wire into ExDoc Operations + README ladder.
3. **Release truth capstone** — bump to 1.7.0, CHANGELOG v1.4–1.7, lockstep `~> 1.7` docs-truth flip, README HexDocs index refresh, Hex publish.
4. **Closure** — Phase 41.1 retire as `accepted-external-verification` (recommended) unless sandbox creds are ready; document and stop carrying.

**Done enough:** Charge parity with sibling list/search resources; two operator guides; version/docs/install truth matches code; Phase 41.1 disposition recorded; v1.x stop signal published.

**Overbuilding line:** no new Stripe families, no billing-engine facades, no extra flagship recipes.

### Wedge B — Hex release only (subsumed into v1.7)

Previously marked out-of-band in PROJECT.md. Assessment upgrade: release truth is essential stop-milestone work, not optional housekeeping.

### Wedge C — JTBD-MAP refresh (housekeeping)

Prevents re-deriving stale gaps (thin events, tax, recipes already shipped). Updated in same assessment pass.

### Wedge D — Phase 41.1 disposition (narrow)

Quote→invoice sandbox proof never closed. **Recommend retire** as accepted external boundary — does not change adopter value. Do not block v1.7 on sandbox access.

### Wedges E+ — Defer indefinitely

Specialist Stripe families, disputes/files full operator playbooks, Product/Price catalog dedicated guide, LiveBook event inspector, Tax TAX-01/02.

## Recommended ordering

1. **v1.7 — Polish & Operator** (Charge + operator guides + Hex capstone + Phase 41.1 retire) ← SELECTED
2. **Stop** — publicly call library "done for v1.x scope"
3. **Maintenance mode** — bugfixes, Stripe API drift, adopter-driven narrow additions only

After v1.7 the library is ~92-95% done by any reasonable SDK-scope definition. Further code work risks Accrue scope creep; further docs work hits diminishing returns.

## Why v1.7 is still the right pick (post-v1.6)

- v1.5→v1.6 sequencing executed cleanly (thin events → Tax).
- Charge is the only embarrassing mainstream surface gap in an otherwise PI-parity codebase.
- Operator guides are what evaluators expect from a "production-grade" SDK label.
- Hex/version drift is now worse than any missing Stripe family for adoption.
- Explicit v1.x stop signal prevents perpetual milestone churn.

## Graduation candidates

Reusable cross-project rules confirmed or upgraded by this assessment:

- **Source-truth grep before milestone scope-lock** — planning docs missed Charge thinness and `tolerance: 0` bug for four milestones until v1.5 grep.
- **Stop milestone must include release truth, not just code** — out-of-band Hex publish creates adopter truth lag; fold into capstone.
- **Audit-before-archive close order** — v1.6 audit was retroactive; future milestones should audit → complete → archive.
- **Per-pattern docs-truth assertions** — aggregate greps mask missing anchors (v1.4 Connect UAT lesson).
- **Four-surface triangulation for security-adjacent fixes** — reuse for v1.7 Charge work.
- **Explicit stop milestone naming** — v1.7 is the planned v1.x stop; reject scope creep with reference.

## Files consulted

- `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/MILESTONES.md`, `.planning/RETROSPECTIVE.md`, `.planning/JTBD-MAP.md`
- `.planning/threads/v1-5-next-milestone-assessment.md`, `.planning/threads/thin-event-webhook-evaluation.md`, `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md`
- `.planning/milestones/v1.6-MILESTONE-AUDIT.md`
- `lib/lattice_stripe/charge.ex`, `payment_intent.ex`, `customer.ex`, `refund.ex`, `object_types.ex`
- `README.md`, `CHANGELOG.md`, `mix.exs`, `guides/`, `test/lattice_stripe/docs_truth_test.exs`
