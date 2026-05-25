# Milestones

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
