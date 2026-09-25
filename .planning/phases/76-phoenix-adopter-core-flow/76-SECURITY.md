---
phase: "76"
slug: "phoenix-adopter-core-flow"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-24"
---

# Phase 76 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|-----------|-------------|---------------|
| Phoenix Checkout request to SDK Client/Transport | Host request parameters pass through the SDK encoder; the test host substitutes a synthetic Mox response. | Checkout parameters and synthetic response data |
| Raw webhook request to verified Event handler | Untrusted bytes and the Stripe-Signature header pass through the Phoenix Endpoint and SDK webhook Plug. | Raw event bytes and signature |
| Hex dependencies to isolated host app | Phoenix, Plug, and Mox resolve in the adopter-local Mix project and lockfile. | Dependency artifacts and package code |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-76-01 | Spoofing/Tampering | PhoenixAdopter.Endpoint webhook path | high | mitigate | The SDK webhook Plug is mounted before Plug.Parsers; tests prove signed event acceptance and modified-body rejection before handler dispatch. | closed |
| T-76-02 | Information disclosure | Host fixtures and README | medium | mitigate | Configuration and tests use fixed synthetic-only credentials and IDs, assert test mode, and do not use environment lookups or persistence. | closed |
| T-76-03 | Denial of service | Checkout outbound call | medium | mitigate | Checkout uses an explicit Mox transport with deterministic expectations; the test path does not make network requests. | closed |
| T-76-04 | Tampering | Host dependency resolution | low | mitigate | Phoenix and Mox are locked in the adopter-local `mix.lock`; package runtime dependencies remain unchanged. | closed |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-24 | 4 | 4 | 0 | Codex, ASVS L1 artifact review |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-24
