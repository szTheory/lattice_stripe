---
phase: "77"
slug: "adopter-edge-profiles-and-ci"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-24"
---

# Phase 77 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, bundled with Elixir; Mox for the transport contract |
| **Config file** | `test_apps/phoenix_adopter/test/test_helper.exs` |
| **Quick run command** | `cd test_apps/phoenix_adopter && mix test` |
| **Full suite command** | `cd test_apps/phoenix_adopter && mix deps.get --check-locked && mix test --warnings-as-errors` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run the focused adopter test file changed by the task.
- **After every plan wave:** Run `cd test_apps/phoenix_adopter && mix test --warnings-as-errors`.
- **Before `$gsd-verify-work`:** Resolve the nested lockfile and run the full adopter suite.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 77-01-01 | 01 | 1 | ADOPT-03, ADOPT-05 | T-77-01 | Synthetic invoice response and no credential lookup | integration | `cd test_apps/phoenix_adopter && mix deps.get --check-locked && mix test --warnings-as-errors` | ✓ | pass |
| 77-01-02 | 01 | 1 | ADOPT-04 | T-77-01 | Structured SDK error decoded from synthetic response | integration | `cd test_apps/phoenix_adopter && mix test test/b2b_invoice_profile_test.exs` | ✓ | pass |
| 77-02-01 | 02 | 2 | ADOPT-03, ADOPT-04 | T-77-02 | Bounded synthetic stream with cursor continuation | integration | `cd test_apps/phoenix_adopter && mix test test/usage_reconciliation_profile_test.exs` | ✓ | pass |
| 77-02-02 | 02 | 2 | ADOPT-04 | T-77-02 | Body identifier and HTTP idempotency key are independently asserted | integration | `cd test_apps/phoenix_adopter && mix test --warnings-as-errors` | ✓ | pass |
| 77-03-01 | 03 | 2 | ADOPT-03 | T-77-03 | Each request carries only its requested tenant account header | integration | `cd test_apps/phoenix_adopter && mix test test/connect_context_profile_test.exs` | ✓ | pass |
| 77-03-02 | 03 | 2 | ADOPT-04, ADOPT-05 | T-77-03 | Explicit nil suppresses inherited account context; complete suite stays synthetic | integration | `cd test_apps/phoenix_adopter && mix test --warnings-as-errors` | ✓ | pass |

## Wave 0 Requirements

- Existing Phoenix/ExUnit/Mox infrastructure covers framework setup. Add profile tests in the corresponding plan tasks; no separate Wave 0 setup is needed.

## Manual-Only Verifications

All phase behaviors have automated verification; no live Stripe or manual UI check is in scope.

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter after verification

**Approval:** verified 2026-09-25

## Validation Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

The required nested locked-dependency check and complete warnings-as-errors suite passed: 9 tests, 0 failures.
