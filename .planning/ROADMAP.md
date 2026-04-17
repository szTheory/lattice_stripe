# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- 🚧 **v1.3 — Production Coverage & Adoption Polish** — Phases 32-37 (in progress)

## Phases

<details>
<summary>✅ v1.0 — Foundation + Billing + Connect + 1.0 Release (Phases 1-11, 14-19) — SHIPPED 2026-04-13</summary>

- [x] Phase 1: Transport & Client Configuration (5/5 plans)
- [x] Phase 2: Error Handling & Retry (3/3 plans)
- [x] Phase 3: Pagination & Response (3/3 plans) — cursor lists, `stream!/2`, `expand:` (IDs), API version pinning
- [x] Phase 4: Customers & PaymentIntents (2/2 plans) — first resource modules, pattern validated
- [x] Phase 5: SetupIntents & PaymentMethods (2/2 plans)
- [x] Phase 6: Refunds & Checkout (2/2 plans)
- [x] Phase 7: Webhooks (2/2 plans) — HMAC + Event + Plug
- [x] Phase 8: Telemetry & Observability (2/2 plans) — request spans + webhook verify spans
- [x] Phase 9: Testing Infrastructure (3/3 plans) — stripe-mock integration, `LatticeStripe.Testing`
- [x] Phase 10: Documentation & Guides (3/3 plans) — ExDoc, 16 guides, cheatsheet, README quickstart
- [x] Phase 11: CI/CD & Release (3/3 plans) — Release Please, Hex auto-publish, Dependabot
- ~~Phases 12-13: Product/Price/Coupon/TestClock~~ — deleted in commit `39b98c9`, rebuilt in Phase 14
- [x] Phase 14: Invoices & Invoice Line Items (PR #4)
- [x] Phase 15: Subscriptions & Subscription Items (PR #4)
- [x] Phase 16: Subscription Schedules (PR #4)
- [x] Phase 17: Connect Accounts & Account Links (CNCT-01)
- [x] Phase 18: Connect Money Movement (CNCT-02..CNCT-05) — Transfer, Payout, Balance, BalanceTransaction, ExternalAccount, Charge
- [x] Phase 19: Cross-cutting Polish & v1.0 Release — API surface lock, nine-group ExDoc, `api_stability.md`, CHANGELOG Highlights, release-please 1.0.0 cut

See `.planning/milestones/v1.0-ROADMAP.md` for full phase details and decisions.

</details>

<details>
<summary>✅ v1.1 — Accrue unblockers (Phases 20-21) — SHIPPED 2026-04-14</summary>

- [x] **Phase 20: Billing Metering** — `Billing.Meter` CRUDL + `deactivate/reactivate`, four nested typed structs, `MeterEvent.create/3`, `MeterEventAdjustment.create/3`, integration tests, `guides/metering.md` (completed 2026-04-14)
- [x] **Phase 21: Customer Portal** — `BillingPortal.Session.create/3`, `Session.FlowData` nested struct, integration tests, `guides/customer-portal.md` (completed 2026-04-14)

</details>

<details>
<summary>✅ v1.2 — Production Hardening & DX (Phases 22-31) — SHIPPED 2026-04-17</summary>

- [x] **Phase 22: Expand Deserialization & Status Atomization** — typed struct dispatch for `expand:`, dot-path support, status field atomization sweep across 84+ modules (completed 2026-04-16)
- [x] **Phase 23: BillingPortal.Configuration CRUDL** — portal branding/features customization resource, Level 1+2 typed structs (completed 2026-04-16)
- [x] **Phase 24: Rate-Limit Awareness & Richer Errors** — `RateLimit-*` header capture via telemetry, fuzzy param name suggestions (completed 2026-04-16)
- [x] **Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up** — `guides/performance.md`, opt-in `Client` timeout field, Finch warm-up helper (completed 2026-04-16)
- [x] **Phase 26: Circuit Breaker & OpenTelemetry Guides** — `:fuse` RetryStrategy guide, OTel guide with Honeycomb/Datadog (completed 2026-04-16)
- [x] **Phase 27: Request Batching** — `LatticeStripe.Batch` with `Task.async_stream`, crash isolation (completed 2026-04-16)
- [x] **Phase 28: meter_event_stream v2** — `Billing.MeterEventStream` session-token API (completed 2026-04-16)
- [x] **Phase 29: Changeset-Style Param Builders** — fluent builders for SubscriptionSchedule + BillingPortal (completed 2026-04-16)
- [x] **Phase 30: Stripe API Drift Detection** — Mix task + GitHub Actions weekly cron (completed 2026-04-16)
- [x] **Phase 31: LiveBook Notebook** — `notebooks/stripe_explorer.livemd` interactive SDK exploration (completed 2026-04-17)

See `.planning/milestones/v1.2-ROADMAP.md` for full phase details and decisions.

</details>

### v1.3 — Production Coverage & Adoption Polish (In Progress)

**Milestone Goal:** Production SaaS developers never need to drop to raw HTTP for common workflows. Onboarding friction minimized.

- [x] **Phase 32: File & FileLink** - Upload and download infrastructure with multipart/binary transport, File and FileLink CRUDL (completed 2026-04-17)
- [ ] **Phase 33: Disputes** - Full dispute lifecycle including evidence staging, submission, and close verb
- [ ] **Phase 34: CreditNote** - Invoice credit workflow with preview, void, and line item streaming
- [ ] **Phase 35: Mandate & SetupAttempt** - Read-only payment authorization tracking resources
- [ ] **Phase 36: Quote** - Proposal-to-invoice workflow with finalize/accept/cancel verbs and PDF download
- [ ] **Phase 37: DX Polish** - Phoenix webhook recipe, v1.3 fixture builders, recipes guide, guide consistency sweep

## Phase Details

### Phase 32: File & FileLink
**Goal**: Developers can upload files to Stripe, manage file links, and download binary content — enabling dispute evidence workflows and compliance document handling
**Depends on**: Phase 31 (previous milestone complete)
**Requirements**: FILE-01, FILE-02, FILE-03, FILE-04, FILE-05
**Success Criteria** (what must be TRUE):
  1. Developer can upload a file via `File.create/3` with multipart/form-data to `files.stripe.com` and receive a `%LatticeStripe.File{}` struct back
  2. Developer can retrieve and list files with `stream!/3` auto-pagination
  3. Developer can create, retrieve, update, and list file links via `FileLink` CRUDL with `stream!/3`
  4. `Client.upload/3` sends a correct `multipart/form-data` request with proper boundary headers — standard `Client.request/2` is not used for uploads
  5. `Client.download/3` returns raw binary content (skips JSON decode) — usable for file/PDF download responses
**Plans:** 3/3 plans complete
Plans:
- [x] 32-01-PLAN.md — MultipartEncoder, Config/Response extensions, fixture builders
- [x] 32-02-PLAN.md — Client.upload/4 and Client.download/2 transport functions
- [x] 32-03-PLAN.md — File and FileLink resource modules with tests

### Phase 33: Disputes
**Goal**: Developers can manage the full dispute lifecycle — retrieve, update metadata, stage evidence, irreversibly submit evidence, and accept disputes
**Depends on**: Phase 32 (File phase provides evidence file upload infrastructure)
**Requirements**: DISP-01, DISP-02, DISP-03, DISP-04, DISP-05, DISP-06, DISP-07
**Success Criteria** (what must be TRUE):
  1. Developer can retrieve and list disputes with `stream!/3` auto-pagination
  2. Developer can update dispute metadata via `Dispute.update/4`
  3. Developer can stage evidence without submitting via `Dispute.update_evidence/4` (always passes `submit: false`)
  4. Developer can irreversibly submit evidence via `Dispute.submit_evidence/3` — function name and docs make the irreversibility clear
  5. Developer can accept (close) a dispute via explicit `Dispute.close/3` verb
  6. Dispute responses deserialize into typed `%Dispute.Evidence{}` and `%Dispute.EvidenceDetails{}` nested structs with `@known_fields`
**Plans**: TBD

### Phase 34: CreditNote
**Goal**: Developers can issue full or partial invoice credits, preview credits before creating them, void issued notes, and stream line items
**Depends on**: Phase 31 (depends only on Invoice resource shipped in v1.0)
**Requirements**: CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05, CRDN-06
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, and list credit notes with `stream!/3` auto-pagination
  2. Developer can void a credit note via explicit `CreditNote.void/3` verb
  3. Developer can preview a credit note (without creating it) via `CreditNote.preview/3`
  4. Developer can list and stream credit note line items via `CreditNote.list_line_items/4` and `stream_line_items!/4`
  5. Developer can list preview line items via `CreditNote.list_preview_line_items/3`
  6. Credit note line item responses deserialize into typed `%CreditNote.LineItem{}` structs
**Plans**: TBD

### Phase 35: Mandate & SetupAttempt
**Goal**: Developers can inspect payment authorization mandates and diagnose setup intent failures by examining setup attempt history
**Depends on**: Phase 31 (read-only resources, depends only on existing PaymentMethod/SetupIntent shipped in v1.0)
**Requirements**: AUTH-01, AUTH-02
**Success Criteria** (what must be TRUE):
  1. Developer can retrieve mandate details via `Mandate.retrieve/3` and receive a typed `%LatticeStripe.Mandate{}` struct
  2. Developer can list setup attempts filtered by setup_intent via `SetupAttempt.list/3` and stream them via `stream!/3`
**Plans**: TBD

### Phase 36: Quote
**Goal**: Developers can manage the full proposal-to-invoice workflow — create and iterate on quotes, finalize, accept or cancel, stream line items, and download the PDF
**Depends on**: Phase 32 (Quote PDF download requires `Client.download/3` from the File phase)
**Requirements**: QUOT-01, QUOT-02, QUOT-03, QUOT-04, QUOT-05
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, and list quotes with `stream!/3` auto-pagination
  2. Developer can finalize, accept, and cancel quotes via explicit verbs (`Quote.finalize/3`, `Quote.accept/3`, `Quote.cancel/3`)
  3. Developer can list and stream quote line items via `Quote.list_line_items/4` and `stream_line_items!/4`
  4. Developer can download a quote PDF as raw binary via `Quote.pdf/3` — response is binary, not a decoded struct
  5. Quote line item responses deserialize into typed `%Quote.LineItem{}` structs
**Plans**: TBD

### Phase 37: DX Polish
**Goal**: New developers can copy-paste a working Phoenix webhook handler and reach end-to-end patterns for common workflows; existing guides are consistent and accurate
**Depends on**: Phase 36 (fixture builders need all 6 v1.3 resource structs to exist)
**Requirements**: DX-01, DX-02, DX-03, DX-04
**Success Criteria** (what must be TRUE):
  1. Webhooks guide contains a copy-paste Phoenix router + handler recipe that compiles and covers the common event types
  2. `LatticeStripe.Testing` exposes fixture builder functions for all v1.3 resource families (File, FileLink, Dispute, CreditNote, Mandate, SetupAttempt, Quote)
  3. `guides/recipes.md` provides end-to-end patterns for the most common workflows introduced in v1.3 (dispute handling, credit issuance, quote-to-invoice)
  4. All guides have consistent version references, working cross-links, and examples that reflect the current API surface
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-11, 14-19 | v1.0 | All | Complete | 2026-04-13 |
| 20-21 | v1.1 | 11/11 | Complete | 2026-04-14 |
| 22-31 | v1.2 | 24/24 | Complete | 2026-04-17 |
| 32. File & FileLink | v1.3 | 3/3 | Complete    | 2026-04-17 |
| 33. Disputes | v1.3 | 0/? | Not started | - |
| 34. CreditNote | v1.3 | 0/? | Not started | - |
| 35. Mandate & SetupAttempt | v1.3 | 0/? | Not started | - |
| 36. Quote | v1.3 | 0/? | Not started | - |
| 37. DX Polish | v1.3 | 0/? | Not started | - |
