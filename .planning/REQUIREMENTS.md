# Requirements: LatticeStripe v1.3

**Defined:** 2026-04-16
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.3 Requirements

Requirements for v1.3 (Production Coverage & Adoption Polish). Each maps to roadmap phases.

### Risk & Disputes

- [x] **DISP-01**: Developer can retrieve and list disputes with auto-pagination via `stream!/3`
- [x] **DISP-02**: Developer can update dispute metadata via `Dispute.update/4`
- [x] **DISP-03**: Developer can close (accept) a dispute via explicit `Dispute.close/3` verb
- [x] **DISP-04**: Developer can stage evidence without submitting via `Dispute.update_evidence/4` (always `submit: false`)
- [x] **DISP-05**: Developer can irreversibly submit evidence via `Dispute.submit_evidence/3` with clear warning
- [x] **DISP-06**: Dispute evidence deserializes into typed `Dispute.Evidence` struct with `@known_fields`
- [x] **DISP-07**: Dispute evidence details deserializes into typed `Dispute.EvidenceDetails` struct

### Invoice Credits

- [x] **CRDN-01**: Developer can create, retrieve, update, list credit notes with auto-pagination via `stream!/3`
- [x] **CRDN-02**: Developer can void a credit note via explicit `CreditNote.void/3` verb
- [x] **CRDN-03**: Developer can preview a credit note before creating via `CreditNote.preview/3`
- [x] **CRDN-04**: Developer can list and stream credit note line items via `CreditNote.list_line_items/4` and `stream_line_items!/4`
- [x] **CRDN-05**: Developer can list preview line items via `CreditNote.list_preview_line_items/3`
- [x] **CRDN-06**: Credit note line items deserialize into typed `CreditNote.LineItem` struct

### Payment Authorization

- [x] **AUTH-01**: Developer can retrieve mandate details via `Mandate.retrieve/3`
- [x] **AUTH-02**: Developer can list setup attempts filtered by setup_intent via `SetupAttempt.list/3` and `stream!/3`

### File Management

- [x] **FILE-01**: Developer can upload files via multipart to `files.stripe.com` using `File.create/3`
- [x] **FILE-02**: Developer can retrieve and list files with auto-pagination via `stream!/3`
- [x] **FILE-03**: Developer can create, retrieve, update, list file links via `FileLink` CRUDL with `stream!/3`
- [x] **FILE-04**: `Client.upload/3` handles multipart/form-data encoding with correct boundary headers
- [x] **FILE-05**: `Client.download/3` handles binary responses (skips JSON decode) for file/PDF downloads

### Quotes & Proposals

- [x] **QUOT-01**: Developer can create, retrieve, update, list quotes with auto-pagination via `stream!/3`
- [x] **QUOT-02**: Developer can finalize, accept, and cancel quotes via explicit verbs
- [x] **QUOT-03**: Developer can list and stream quote line items via `Quote.list_line_items/4` and `stream_line_items!/4`
- [x] **QUOT-04**: Developer can download quote PDF as raw binary via `Quote.pdf/3`
- [x] **QUOT-05**: Quote line items deserialize into typed `Quote.LineItem` struct

### Developer Experience

- [x] **DX-01**: Webhooks guide includes copy-paste Phoenix router + handler recipe
- [x] **DX-02**: `LatticeStripe.Testing` exposes fixture builders for all v1.3 resource families
- [x] **DX-03**: `guides/recipes.md` provides end-to-end patterns for common workflows
- [x] **DX-04**: All guides have consistent version refs, cross-links, and current examples

## Future Requirements

Deferred to v1.4+. Tracked but not in current roadmap.

### Specialist Resource Families

- **TAX-01**: Tax Calculation and Tax Registration resources
- **IDV-01**: Identity VerificationSession and VerificationReport resources
- **TREAS-01**: Treasury FinancialAccount, Transaction, and flow resources
- **ISS-01**: Issuing Card, Cardholder, Authorization, Transaction resources
- **TERM-01**: Terminal Reader, Location, ConnectionToken resources

### Advanced Features

- **ADV-01**: Thin event support (v2 webhook style)
- **ADV-02**: Code generation from Stripe OpenAPI spec
- **ADV-03**: LiveView payment helpers

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Dialyzer/Dialyxir | Typespecs are documentation-only; Credo strict handles lint |
| Higher-level abstractions | That's Accrue (separate repo consuming LatticeStripe) |
| Mobile/frontend SDK | Backend library only |
| Builder for Dispute.Evidence | Flat 27-field struct; raw map sufficient. Add later if user feedback demands it |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FILE-01 | Phase 38 | Verified |
| FILE-02 | Phase 38 | Verified |
| FILE-03 | Phase 38 | Verified |
| FILE-04 | Phase 38 | Verified |
| FILE-05 | Phase 38 | Verified |
| DISP-01 | Phase 38 | Verified |
| DISP-02 | Phase 38 | Verified |
| DISP-03 | Phase 38 | Verified |
| DISP-04 | Phase 38 | Verified |
| DISP-05 | Phase 38 | Verified |
| DISP-06 | Phase 38 | Verified |
| DISP-07 | Phase 38 | Verified |
| CRDN-01 | Phase 39 | Verified |
| CRDN-02 | Phase 39 | Verified |
| CRDN-03 | Phase 39 | Verified |
| CRDN-04 | Phase 39 | Verified |
| CRDN-05 | Phase 39 | Verified |
| CRDN-06 | Phase 39 | Verified |
| AUTH-01 | Phase 40 | Verified |
| AUTH-02 | Phase 40 | Verified |
| QUOT-01 | Phase 41 | Verified |
| QUOT-02 | Phase 41 | Verified |
| QUOT-03 | Phase 41 | Verified |
| QUOT-04 | Phase 41 | Verified |
| QUOT-05 | Phase 41 | Verified |
| DX-01 | Phase 42 | Verified |
| DX-02 | Phase 42 | Verified |
| DX-03 | Phase 42 | Verified |
| DX-04 | Phase 42 | Verified |

**Coverage:**
- v1.3 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-05-25 — gap closure phases 38-42 added after milestone audit*
