---
phase: 71
slug: reliability-ci-security
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-25
---

# Phase 71 — Security

## Threat Register

| Threat ID | Category | Severity | Disposition | Mitigation | Status |
|-----------|----------|----------|-------------|------------|--------|
| P71-T01 | Credential exposure | high | mitigate | PR CI is read-only and uses `mix hex.build`; publish credentials exist only in authenticated release/recovery steps. | closed |
| P71-T02 | Supply-chain tampering | high | mitigate | Actions use immutable SHAs and stripe-mock uses a versioned digest. | closed |
| P71-T03 | Dependency/config regression | medium | mitigate | Supported/no-optional matrices, locked/unused dependency checks, Hex audit, and aggregate gate are required. | closed |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-25 | 3 | 3 | 0 | gsd-security-auditor |

**Approval:** verified 2026-08-25
