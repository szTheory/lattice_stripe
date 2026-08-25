---
phase: 73
slug: release-maintenance-pause
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-25
---

# Phase 73 — Security

## Threat Register

| Threat ID | Category | Severity | Disposition | Mitigation | Status |
|-----------|----------|----------|-------------|------------|--------|
| P73-T01 | Untested release SHA | high | mitigate | Automated release waits for exact-SHA aggregate `ci-gate`. | closed |
| P73-T02 | Credential exposure | high | mitigate | Hex key is scoped only to authenticated publish steps. | closed |
| P73-T03 | Manual-release bypass | high | mitigate | Recovery resolves an exact ref and requires its successful aggregate `ci-gate`; subset-job acceptance was removed. | closed |
| P73-T04 | Docs/package provenance divergence | medium | accept | Docs-only refresh may use later same-version green source; package/tag stays immutable and the split SHA is recorded publicly in the release ledger. | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R73-01 | P73-T04 | Correcting documentation without mutating the package is lower risk than a content-free package release; exact green docs SHA and immutable package SHA remain explicit. | maintainer | 2026-08-25 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-25 | 4 | 4 | 0 | gsd-security-auditor |

**Approval:** verified 2026-08-25
