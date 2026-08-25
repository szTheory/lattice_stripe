---
phase: 70
slug: client-core-test-architecture
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-25
---

# Phase 70 — Security

## Threat Register

| Threat ID | Category | Severity | Disposition | Mitigation | Status |
|-----------|----------|----------|-------------|------------|--------|
| P70-T01 | Credential/header loss | high | mitigate | Request builder constructs and tests Bearer authorization. | closed |
| P70-T02 | Cross-tenant routing | high | mitigate | Effective per-request account controls header inclusion and telemetry attribution; override and nil suppression are tested. | closed |
| P70-T03 | Duplicate write effects | high | mitigate | One idempotency key is resolved before execution and retained across retries. | closed |
| P70-T04 | Error-body disclosure/exhaustion | medium | mitigate | Non-JSON error bodies are bounded to 500 bytes. | closed |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-25 | 4 | 4 | 0 | gsd-security-auditor |

**Approval:** verified 2026-08-25
