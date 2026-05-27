# Milestones

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

**Outstanding follow-through:** Phase 41.1 remains `pending-external-verification` for real-sandbox Quote downstream proof — slated for v1.7 polish milestone per locked v1.5→v1.7 plan.

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
