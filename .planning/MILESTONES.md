# Milestones

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
