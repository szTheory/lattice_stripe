# Milestones

## v1.10 Accrue Surface Closure (Hex 1.8.0) (Shipped: 2026-08-25)

**Delivered:** The Accrue-driven surface closure: zero-config Finch operation, Stripe-native Entitlements, metering reads, typed webhook fixtures, Product Feature attachments, and hardened consumer guidance.

**Phases completed:** 61-67 (7 phases, 37 plans, 71 tasks)

**Key accomplishments:**

- Added an optional `LatticeStripe.Application` and default Finch pool while preserving explicit-pool and opt-out behavior.
- Shipped typed, paginated Entitlements reads and Feature management, with fail-closed local authorization guidance instead of a network-calling gate helper.
- Added meter event-summary reads, typed meter error reports, exact webhook object dispatch, and public entitlement/meter/core-billing fixtures.
- Added typed Product Feature attachment CRUD and complete streaming while preserving existing Product marketing fields as raw maps.
- Published the 1.1→1.7 migration guide and hardened `Retry-After`, `CacheBodyReader`, multi-chunk webhook bodies, and PaymentIntent-first Charge guidance.
- Closed at 19/19 requirements, 7/7 verified phases, 19/19 integration joins, 6/6 adopter flows, zero ExDoc warnings, and a passing 2,440-test CI run.

**Audit:** No completion blockers; bounded tech debt accepted. See [v1.10-MILESTONE-AUDIT.md](milestones/v1.10-MILESTONE-AUDIT.md).

**Stats:** 291 files changed, +47,548/-603 lines; current `lib/` + `test/` Elixir source is 71,101 lines.

**Git range:** `fce2907` → `003a959`

**Timeline:** 30 calendar days (2026-07-27 → 2026-08-25)

**Release truth:** The milestone was planned as Hex 1.8.0; a fixture API rename made the package release 2.0.0, followed by 2.1.0. Later Phase 66-67 work remains on `main` pending the next package release.

**What's next:** Reactive maintenance. Start a new milestone only on concrete adopter pull or Stripe drift; SEED-006 retains deferred Accrue DX candidates.

---

## v1.9 CI & Doc Honesty (Shipped: 2026-05-27)

**Phases completed:** 2 phases (59–60), 4 plans

**Key accomplishments:**

- checkout.md atom stream filter + status-values callout + docs_truth locks (Phase 59)
- README canonical error atoms + docs_truth describe lock (Phase 59)
- CI-01 paths-ignore narrowed — guide/md PRs run full CI including docs_truth (Phase 60)
- JTBD-MAP post-v1.9 refresh; milestone audit and maintenance posture (Phase 60)

**Audit:** PASSED — 8/8 required requirements, 2/2 phases verified. See [v1.9-MILESTONE-AUDIT.md](milestones/v1.9-MILESTONE-AUDIT.md).
**Post-close hygiene:** PLAN-01 — `54-VERIFICATION.md` backfilled 2026-05-28 (quick 260527-tqf)

**Timeline:** 2026-05-27 (single-day milestone)

---

## v1.8 Adopter Truth & Doc Routing Polish (Shipped: 2026-05-27)

**Phases completed:** 3 phases (56–58), 10 plans

**Key accomplishments:**

- getting-started release-status prose + docs_truth prose SSOT locks (TRUTH-01/02, Phase 56)
- payments.md atom status, stream filter, search/3 fixes + VERIFY-04 locks (GUIDE-01..03, Phase 57)
- PI-first Charge reconciliation section in payments.md (ROUTE-01, Phase 57)
- operator guide update/capture routing spines (ROUTE-02, Phase 57)
- planning truth close — JTBD-MAP refresh, MILESTONES/RETROSPECTIVE, tax proof commit (ROUTE-03, PLAN-01/02, PROOF-01, Phase 58)

**Audit:** PASSED — 12/12 requirements, 3/3 phases verified. See [v1.8-MILESTONE-AUDIT.md](milestones/v1.8-MILESTONE-AUDIT.md).
**Known deferred at close:** CI-01 paths-ignore (guide-only PRs skip docs_truth)

**Git range:** `ff8dd13` → `082ec7991e8baa9d70c17534b1098435b7cfc708`
**Source diff:** 115 files, +7948/-6279 lines
**Timeline:** 2026-05-27 (single-day milestone)

---

## v1.7 Polish & Operator (Shipped: 2026-05-27)

**Phases completed:** 4 phases (52–55), 17 plans

**Stop signal:** As of **1.7.0** on Hex.pm, LatticeStripe is **feature-complete for its intended v1.x scope** — mainstream SaaS payments, billing, Connect, tax, webhooks, and operator diagnostics. Further **1.x** work is **maintenance and adoption-driven**.

**Key accomplishments:**

- Expanded `LatticeStripe.Charge` from retrieve-only to list/search/update/capture parity with PI-first moduledoc, Mox wire tests, stripe-mock integration smokes, and docs-truth regression lock (CHRG-01..05).
- Shipped operator playbooks — `guides/production-checklist.md` and `guides/event-debugging.md` — wired into ExDoc Operations & DX, README hardening route, and JTBD operator route (OPS-01, OPS-02).
- Reconciled release truth — `@version` 1.7.0, CHANGELOG v1.4–v1.7, lockstep `~> 1.7` install contract across seven public surfaces, SSOT docs-truth migration (REL-01..03).
- Published `lattice_stripe` **1.7.0** to Hex.pm via Publish Hex Recovery CI workflow (REL-04).
- Retired Phase `41.1` as `accepted-external-verification` and published the v1.x stop signal in README, `guides/scope.md`, PROJECT.md, CHANGELOG, and ExDoc (CLOSE-01, CLOSE-02).

**Audit:** PASSED — 13/13 requirements, 0 critical gaps, 4/5 E2E flows. **Tech debt at close:** missing `54-VERIFICATION.md`; doc-routing gaps (getting-started prose, payments/operator Charge routing). **Resolved in v1.8** (Phases 56–57). See [v1.7-MILESTONE-AUDIT.md](milestones/v1.7-MILESTONE-AUDIT.md).

**Known deferred items at close:** 1 (260402-wte webhook plug research — substantively complete; see STATE.md Deferred Items)

**Git range:** `5baf5c6` → `ff8dd13`
**Source diff:** 138 files, +7527/-538 lines
**Timeline:** 2026-05-27 (single-day milestone)

---

## v1.6 Tax (Shipped: 2026-05-27)

**Phases completed:** 3 phases (49, 50, 51), 9 plans

**Key accomplishments:**

- Shipped `Tax.Calculation` with nested `CustomerDetails`, `ShippingCost`, `ShipFromDetails`, `TaxBreakdown`, and paginated line items — `create/3`, `retrieve/3`, `list_line_items/4` on `/v1/tax/calculations` (CALC-01..03).
- Shipped `Tax.Transaction` with `create_from_calculation/3`, `create_reversal/3`, `retrieve/3`, and `list_line_items/4` — moduledocs document 90-day calculation expiry, globally unique `reference`, and `Invoice.AutomaticTax` scope boundary (TXN-01..04).
- Added chained Mox-at-Transport integration spec `calculation_transaction_test.exs` proving calculate → record → retrieve → reverse (DX-03).
- Shipped `Tax.Settings` as the codebase's first singleton resource (`retrieve/2`, `update/3` on `/v1/tax/settings`) plus `Tax.Registration` CRUDL with jurisdiction `country_options` and authority disclaimer moduledocs (CONF-01..04).
- Shipped `LatticeStripe.TaxId` with guard-disambiguated dual-path CRUDL (top-level `/v1/tax_ids` and customer-nested `/v1/customers/:id/tax_ids`), nested `Verification`/`Owner` structs, PII-redacted `Inspect`, and `tax_id` ObjectTypes dispatch (TAXID-01..04).
- Promoted Tax wire fixtures to public `LatticeStripe.Testing` helpers with expand-through-parent proof for all five Tax object types; published `guides/tax.md` (351 lines) wired into ExDoc Canonical Guides and the JTBD discovery ladder (DX-01, DX-02, DX-04).
- Extended docs-truth regression with Tax guide ExDoc locks, content anchors, cross-link graph, and five-module moduledoc greps (DX-05).

**Audit:** PASSED (retroactive 2026-05-27) — 20/20 requirements satisfied, 0 critical integration gaps, full standalone Tax adopter flow wired. Tech debt: non-blocking WR-01/02/IN-01 from Phase 51 review (WR-01/02 patched post-audit in `ee305c8`, `11ca590`). Nyquist partial (phases 49–50 `nyquist_compliant: false` despite green verification). See [milestones/v1.6-MILESTONE-AUDIT.md](milestones/v1.6-MILESTONE-AUDIT.md).

**Outstanding follow-through (resolved at v1.7 close):** Phase 41.1 retired as `accepted-external-verification` in Phase 55. Hex publish at `1.7.0` shipped in v1.7 (REL-04).

**Known deferred items at close:** 1 (260402-wte webhook plug research — substantively complete; see STATE.md Deferred Items)

**Git range:** `edef019` → `c0d4e43`
**Source diff:** 83 files, +6988/-73 lines
**Timeline:** 2026-05-27 (single-day milestone)

---

## v1.5 Thin-Event Webhooks (Shipped: 2026-05-27)

**Phases completed:** 2 phases (47, 48), 11 plans

**Key accomplishments:**

- Shipped the thin-event SDK surface — `Webhook.parse_event_notification/4` (+ bang variant) verifying signatures and returning typed `EventNotification` structs exposing `id`, `type`, `created`, `context`, and a `related_object` reference, using the same error atoms as `construct_event/3`.
- Added typed fetch-after-verify helpers — `Webhook.fetch_event/2,3` (hitting `/v2/core/events/{id}`) and `Webhook.fetch_related_object/2,3` returning typed resources via the existing `ObjectTypes` registry (no new dispatch table), honoring per-request `:client`, `:api_version`, and `:idempotency_key`.
- Extended `Event.t()` with a `related_object` field and added net-new `EventNotification` + `EventNotification.RelatedObject` modules (custom `Inspect` impls, infallible `from_map/1`) plus `ObjectTypes.fetch_module/1` typed-gate accessor.
- Reconciled `Webhook.check_tolerance/2` `tolerance: 0` drift across four surfaces — docstring, code clause, `Webhook.Plug` NimbleOptions schema, and tests — documented inline against future "fix it to be stricter" drift, locked by a CHANGELOG v1.5 entry and a docs-truth grep regression.
- Published `guides/webhooks-thin-events.md` — a Phoenix controller spine teaching verify → fetch-after-verify → idempotent dispatch keyed on `event.id`, with rate-limit guidance (<90/s under Stripe's 100 req/s ceiling), Connect/context-aware routing, and the verification-vs-payload-shape failure boundary — wired into ExDoc `Operations & DX`, the README hardening-ops route, `guides/webhooks.md` closing section, and the JTBD discovery ladder.
- Added `LatticeStripe.Testing` thin-event helpers — `generate_thin_event_payload/3` produces signed wire payloads parseable by `parse_event_notification/4`, `event_notification/1` is a typed builder mirroring `dispute/1`/`customer/1`; snapshot helpers remain backwards-compatible.
- Locked the new surface with `test/lattice_stripe/webhook/thin_event_test.exs` — a chained Mox-at-Transport integration suite proving happy-path, fetch-after-verify roundtrip, malformed-payload boundary, and `tolerance: 0` reconciliation — plus five new docs-truth grep blocks (3A guide content, 3B `~> 1.5` install canary, 3C ExDoc placement, 3D cross-link graph, 3E Plug `@moduledoc` `tolerance: 0` testing-only).
- Closed Phase 47's deferred WR-04 inside Phase 48 by extending `Webhook.Plug` `@moduledoc` with `tolerance: 0` testing-only language enforced by a dotall regex docs-truth grep.

**Audit:** PASSED — 8/8 requirements satisfied (THIN-01..04, WEBFIX-01, TESTING-01, GUIDE-03, VERIFY-03), 0 critical integration gaps, full E2E adopter flow wired. Tech debt limited to non-blocking polish (WR-01/02/03/05, IN-01..04, Phase 48 VALIDATION.md per-task map placeholder).

**Outstanding follow-through (resolved at v1.7 close):** Phase 41.1 retired as `accepted-external-verification` in Phase 55 (optional manual probe via `scripts/verify_quote_follow_through.exs`).

**Known deferred items at close:** 1 (260402-wte webhook plug research — substantively complete, catalog status flag only; see STATE.md Deferred Items)

**Git range:** `0bd04a9` → `eb56c0c`
**Source diff:** 21 files (lib/test/guides/CHANGELOG), +2343/-23 lines
**Timeline:** 2026-05-27 (single-day milestone)

---

## v1.4 Adoption Closure (Shipped: 2026-05-27)

**Phases completed:** 4 phases, 8 plans, 18 tasks

**Key accomplishments:**

- Aligned the highest-visibility public docs surfaces to the shipped `1.3.x` package line so README, HexDocs Getting Started, cheatsheet, and changelog now tell one consistent onboarding story.
- Expanded docs-truth regression coverage from README-only checks to the real onboarding entry points, including ExDoc publication metadata and the Getting Started install contract.
- Reframed the public docs entry points as a deliberate discovery ladder so README, Getting Started, JTBD, recipes, and ExDoc now steer evaluators into the right shipped guide surfaces instead of a flat list.
- Connected the canonical guide graph with support-truth follow-through links and extended the docs-truth regression suite so discovery and ExDoc-role drift now fail fast.
- Published the hosted recurring-billing flagship guide and wired it into the public docs graph so evaluators can follow one honest path from Checkout signup through portal follow-through.
- Published the runtime-first metering flagship guide and connected it to the canonical trust rails so adopters can learn the live usage-billing path without false synchronous guarantees.
- Published the Connect and Quote flagship workflow guides and wired them into the docs graph so evaluators can follow two high-leverage shipped paths without false authority claims.
- Reconciled the active planning artifacts so v1.4 now reads as close-ready everywhere while still naming Phase 41.1 as the only accepted pending-external-verification follow-through.

---

## v1.3 Production Coverage & Adoption Polish (Shipped: 2026-05-25)

**Phases completed:** 12 phases, 26 plans, 53 tasks

**Key accomplishments:**

- Added multipart upload and binary download transport support, then shipped `File` and `FileLink` resource coverage for evidence and document workflows.
- Shipped the full Dispute lifecycle, including typed evidence structs, staged evidence updates, irreversible submission, and close/accept support.
- Added `CreditNote`, `Mandate`, `SetupAttempt`, and `Quote` resource families with the expected CRUD, verb, list/stream, and PDF surfaces.
- Closed the milestone verifier gaps for File, Dispute, CreditNote, Mandate, SetupAttempt, Quote, and DX planning truth.
- Published DX follow-through work: Phoenix webhook recipe, v1.3 fixture builders, recipe guides, and reconciled roadmap/requirements truth.
- Accepted one explicit deferred gap at close: Phase `41.1` remains `pending-external-verification` for real-sandbox Quote downstream follow-through proof.

**Git range:** `0534c69` -> `e2b7d9f`
**Diff stats:** 153 files changed, 25,036 insertions, 470 deletions
**Timeline:** 2026-04-16 -> 2026-05-25

---

## v1.2 Production Hardening & DX (Shipped: 2026-04-17)

**Phases completed:** 10 phases, 24 plans, 14 tasks

**Key accomplishments:**

- Compile-time ObjectTypes registry and typed expand deserialization across the shipped SDK surface.
- `BillingPortal.Configuration` CRUDL with typed nested structs and expand wiring.
- Per-operation timeouts, Finch warm-up, and performance guidance for production callers.
- Circuit breaker and OpenTelemetry guides for reliability and observability integrations.
- Request batching, param builders, Stripe API drift detection, and the LiveBook explorer notebook.

---

## v1.0 Foundation + Billing + Connect + 1.0 Release (Shipped: 2026-04-13)

**Phases completed:** 14 phases, 47 plans, 61 tasks

**Key accomplishments:**

- Built the transport, config, error, retry, pagination, and telemetry foundation for a production Elixir Stripe SDK.
- Shipped the core payment, webhook, testing, docs, CI/CD, Billing, and Connect surfaces.
- Cut and published the first stable Hex release with automated versioning and release infrastructure.
