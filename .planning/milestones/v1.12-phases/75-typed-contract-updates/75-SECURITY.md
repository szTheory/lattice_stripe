---
phase: "75"
slug: "typed-contract-updates"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-24"
---

# Phase 75 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Stripe response map → Invoice.from_map/1 | External JSON keys and values enter a public struct; only the selected compile-time key moves from extra to a field. | Stripe response values |
| Stripe response map → Refund.from_map/1 | External JSON values enter optional public fields; unknown keys remain in extra. | Stripe response values |
| Expanded object map → ObjectTypes.maybe_deserialize/1 | Known object discriminators become resource structs; deleted_customer and other unknown discriminators remain maps. | Expanded object data |
| Documentation and fixtures | Public examples use synthetic IDs and schema-derived values, with no credentials or live customer data. | Synthetic examples |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-75-01 | Tampering | Invoice.from_map/1 | medium | mitigate | Fixed known-field split, no dynamic atom creation, and focused integer/null/omission/unknown-key tests. | closed |
| T-75-02 | Information disclosure | Invoice docs | low | accept | Synthetic IDs and schema-derived amounts; no credentials or live customer data enter fixtures. | closed |
| T-75-03 | Tampering | Refund.from_map/1 | medium | mitigate | Fixed known-field split, existing ObjectTypes dispatch, and focused ID/object/null/unknown-key tests. | closed |
| T-75-04 | Information disclosure | Refund Inspect implementation | medium | mitigate | Existing redacted Inspect projection retained; tests assert attribution fields are absent from Inspect output. | closed |
| T-75-05 | Spoofing | Schema-derived fixtures | low | accept | Examples are labeled schema-derived with immutable provenance and are not represented as captured live responses. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-75-01 | T-75-02 | Documentation uses synthetic identifiers and schema-derived values; no sensitive customer data or credentials are included. | Phase plan | 2026-09-24 |
| R-75-02 | T-75-05 | Schema-derived examples prove decoder contracts but do not establish live Stripe payload frequency or event availability. | Phase plan | 2026-09-24 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-24 | 5 | 5 | 0 | Orchestrator (ASVS L1 plan-register review) |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-24
