---
phase: "77"
slug: "adopter-edge-profiles-and-ci"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-25"
---

# Phase 77 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Adopter test to Stripe SDK transport | Explicit Client uses the test host's Mox transport | Synthetic Stripe-shaped fixtures only |
| Raw webhook request to host handler | Existing Endpoint verifies original request bytes before dispatch | Synthetic signed or modified webhook body |
| GitHub workflow to nested Mix project | CI resolves the adopter lockfile and runs the synthetic suite | Source, lockfile and test results; no credentials |
| Host-selected tenant to SDK request builder | Request-scoped account selection determines outbound header | Synthetic connected-account identifiers |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-77-01 | Spoofing/Tampering | Existing webhook Endpoint | high | mitigate | Signed success and changed-body rejection remain in the full adopter suite | closed |
| T-77-02 | Information disclosure | Adopter fixture and CI | high | mitigate | Synthetic values and Mox transport; no credential env or Stripe service in the adopter job | closed |
| T-77-03 | Tampering | Invoice versioned response | medium | mitigate | Named test asserts Stripe-Version and typed values against a synthetic response | closed |
| T-77-04 | Tampering | Meter event request | medium | mitigate | Named test separately asserts body identifier and HTTP idempotency key | closed |
| T-77-05 | Denial of service | Usage summary stream | medium | mitigate | Named test bounds stream to two pages and checks cursor and final-page behavior | closed |
| T-77-06 | Information disclosure | Usage test data | medium | mitigate | Synthetic customer and meter IDs; no credential or production lookup | closed |
| T-77-07 | Elevation of privilege/Information disclosure | Connect request account context | high | mitigate | Named tests assert exact per-request account headers, nil suppression and no context bleed | closed |
| T-77-08 | Spoofing | Synthetic connected accounts | medium | mitigate | Fixed test-only account IDs inspected at the Mox transport seam | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 8 | 8 | 0 | Codex verification |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-25
