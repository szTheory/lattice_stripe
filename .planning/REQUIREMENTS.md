# Requirements: LatticeStripe v1.3

**Defined:** 2026-04-16
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.3 Requirements

Requirements for v1.3 (Production Coverage & Adoption Polish). Each maps to roadmap phases.

### Risk & Disputes

- [ ] **DISP-01**: Developer can retrieve and list disputes with auto-pagination via `stream!/3`
- [ ] **DISP-02**: Developer can update dispute metadata via `Dispute.update/4`
- [ ] **DISP-03**: Developer can close (accept) a dispute via explicit `Dispute.close/3` verb
- [ ] **DISP-04**: Developer can stage evidence without submitting via `Dispute.update_evidence/4` (always `submit: false`)
- [ ] **DISP-05**: Developer can irreversibly submit evidence via `Dispute.submit_evidence/3` with clear warning
- [ ] **DISP-06**: Dispute evidence deserializes into typed `Dispute.Evidence` struct with `@known_fields`
- [ ] **DISP-07**: Dispute evidence details deserializes into typed `Dispute.EvidenceDetails` struct

### Invoice Credits

- [ ] **CRDN-01**: Developer can create, retrieve, update, list credit notes with auto-pagination via `stream!/3`
- [ ] **CRDN-02**: Developer can void a credit note via explicit `CreditNote.void/3` verb
- [ ] **CRDN-03**: Developer can preview a credit note before creating via `CreditNote.preview/3`
- [ ] **CRDN-04**: Developer can list and stream credit note line items via `CreditNote.list_line_items/4` and `stream_line_items!/4`
- [ ] **CRDN-05**: Developer can list preview line items via `CreditNote.list_preview_line_items/3`
- [ ] **CRDN-06**: Credit note line items deserialize into typed `CreditNote.LineItem` struct

### Payment Authorization

- [ ] **AUTH-01**: Developer can retrieve mandate details via `Mandate.retrieve/3`
- [ ] **AUTH-02**: Developer can list setup attempts filtered by setup_intent via `SetupAttempt.list/3` and `stream!/3`

### File Management

- [ ] **FILE-01**: Developer can upload files via multipart to `files.stripe.com` using `File.create/3`
- [ ] **FILE-02**: Developer can retrieve and list files with auto-pagination via `stream!/3`
- [ ] **FILE-03**: Developer can create, retrieve, update, list file links via `FileLink` CRUDL with `stream!/3`
- [x] **FILE-04**: `Client.upload/3` handles multipart/form-data encoding with correct boundary headers
- [ ] **FILE-05**: `Client.download/3` handles binary responses (skips JSON decode) for file/PDF downloads

### Quotes & Proposals

- [ ] **QUOT-01**: Developer can create, retrieve, update, list quotes with auto-pagination via `stream!/3`
- [ ] **QUOT-02**: Developer can finalize, accept, and cancel quotes via explicit verbs
- [ ] **QUOT-03**: Developer can list and stream quote line items via `Quote.list_line_items/4` and `stream_line_items!/4`
- [ ] **QUOT-04**: Developer can download quote PDF as raw binary via `Quote.pdf/3`
- [ ] **QUOT-05**: Quote line items deserialize into typed `Quote.LineItem` struct

### Developer Experience

- [ ] **DX-01**: Webhooks guide includes copy-paste Phoenix router + handler recipe
- [ ] **DX-02**: `LatticeStripe.Testing` exposes fixture builders for all v1.3 resource families
- [ ] **DX-03**: `guides/recipes.md` provides end-to-end patterns for common workflows
- [ ] **DX-04**: All guides have consistent version refs, cross-links, and current examples

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
| FILE-01 | Phase 32 | Pending |
| FILE-02 | Phase 32 | Pending |
| FILE-03 | Phase 32 | Pending |
| FILE-04 | Phase 32 | Complete |
| FILE-05 | Phase 32 | Pending |
| DISP-01 | Phase 33 | Pending |
| DISP-02 | Phase 33 | Pending |
| DISP-03 | Phase 33 | Pending |
| DISP-04 | Phase 33 | Pending |
| DISP-05 | Phase 33 | Pending |
| DISP-06 | Phase 33 | Pending |
| DISP-07 | Phase 33 | Pending |
| CRDN-01 | Phase 34 | Pending |
| CRDN-02 | Phase 34 | Pending |
| CRDN-03 | Phase 34 | Pending |
| CRDN-04 | Phase 34 | Pending |
| CRDN-05 | Phase 34 | Pending |
| CRDN-06 | Phase 34 | Pending |
| AUTH-01 | Phase 35 | Pending |
| AUTH-02 | Phase 35 | Pending |
| QUOT-01 | Phase 36 | Pending |
| QUOT-02 | Phase 36 | Pending |
| QUOT-03 | Phase 36 | Pending |
| QUOT-04 | Phase 36 | Pending |
| QUOT-05 | Phase 36 | Pending |
| DX-01 | Phase 37 | Pending |
| DX-02 | Phase 37 | Pending |
| DX-03 | Phase 37 | Pending |
| DX-04 | Phase 37 | Pending |

**Coverage:**
- v1.3 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-04-16 — traceability filled after roadmap creation*
