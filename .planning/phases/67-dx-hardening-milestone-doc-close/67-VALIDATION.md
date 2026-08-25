---
phase: 67
slug: dx-hardening-milestone-doc-close
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
---

# Phase 67 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox transport seams |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/charge_test.exs test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Targeted tests under 30 seconds; full CI timing is environment-dependent |

---

## Sampling Rate

- **After every task commit:** Run the task's targeted ExUnit command plus `mix format --check-formatted`.
- **After every plan wave:** Run `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs --warnings-as-errors` and `mix docs --warnings-as-errors`.
- **Before `$gsd-verify-work`:** `mix ci` must be green, then rerun the normal milestone audit.
- **Max feedback latency:** 30 seconds for targeted task feedback; the full gate runs at wave/phase boundaries.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 67-01-01 | 01 | 1 | DX-02 | T-67-01 | Records prior approval of the exact one-way Error contract without reopening D-01/D-02/D-04 | locked-decision checkpoint | `rg -n 'D-01:|D-02:|D-04:' .planning/phases/67-dx-hardening-milestone-doc-close/67-CONTEXT.md` | ✅ existing | ⬜ pending |
| 67-01-02 | 01 | 1 | DX-02 | T-67-01, T-67-05 | JSON, non-JSON, connection, and final-retry paths expose only final response metadata | unit/Mox tracer | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 67-01-03 | 01 | 1 | DX-02 | T-67-01, T-67-04 | Strict delay-seconds parsing, repeatability, parallel purity, and non-blocking guidance | unit/docs | `mix test test/lattice_stripe/error_test.exs --warnings-as-errors && mix format --check-formatted` | ✅ extend | ⬜ pending |
| 67-02-01 | 02 | 1 | DX-03 | T-67-02, T-67-03 | Raw webhook bytes accumulate exactly in byte order without hidden storage expansion | unit/integration | `mix test test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors && mix format --check-formatted` | ✅ extend | ⬜ pending |
| 67-02-02 | 02 | 1 | DX-03 | T-67-02 | Error passthrough and the Webhook.Plug consumer retain the completed signed byte stream | integration | `mix test test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 67-03-01 | 03 | 2 | DX-03 | T-67-02, T-67-03 | Records prior approval of the exact one-way conditional CacheBodyReader contract without reopening D-07/D-09 | locked-decision checkpoint | `rg -n 'D-07:|D-09:' .planning/phases/67-dx-hardening-milestone-doc-close/67-CONTEXT.md` | ✅ existing | ⬜ pending |
| 67-03-02 | 03 | 2 | DX-03 | T-67-03 | Public guidance makes conditional availability and PII/memory/multipart limits explicit | docs | `mix docs --warnings-as-errors && mix format --check-formatted` | ✅ extend | ⬜ pending |
| 67-03-03 | 03 | 2 | DX-03 | T-67-02, T-67-03 | Public module is grouped, conditionally documented, exact-byte tested, and semver-locked | API/docs lock | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors && mix lattice_stripe.api_surface --check` | ✅ extend | ⬜ pending |
| 67-04-01 | 04 | 1 | DOC-02 | T-67-06, T-67-07 | Canonical Charge surfaces route initiation to PaymentIntent without obscuring SCA | docs truth + structural unit | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs --warnings-as-errors && mix docs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 67-04-02 | 04 | 1 | DOC-02 | T-67-07 | Canonical policy ownership remains deterministic under repeated and parallel reads | docs truth + structural unit | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 67-05-01 | 05 | 3 | DX-02, DX-03, DOC-02 | T-67-01, T-67-02, T-67-03, T-67-04 | Focused behavior, strict ExDoc, and API evidence is sampled before the long gate | focused phase gate | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/charge_test.exs test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs --warnings-as-errors && mix docs --warnings-as-errors && mix lattice_stripe.api_surface --check` | ✅ existing/extend | ⬜ pending |
| 67-05-02 | 05 | 3 | DX-02, DX-03, DOC-02 | T-67-08 | Full CI, API-coverage disposition, protected paths, and historical-audit hash converge | full/scope gate | `mix ci` plus the exact Task 2 detector/hash/protected-path command | ✅ existing | ⬜ pending |
| 67-05-03 | 05 | 3 | DX-02, DX-03, DOC-02 | T-67-08 | Normal milestone audit produces current evidence at the explicit non-overwrite path | workflow checkpoint | `test -s .planning/v1.10-POST-PHASE-67-MILESTONE-AUDIT.md && rg -n '^milestone: v1\.10$|^audited:|^status:' .planning/v1.10-POST-PHASE-67-MILESTONE-AUDIT.md` plus the fixed historical SHA-256 check | ⬜ create | ⬜ pending |

*The 13 rows above map every current task in the five submitted plans. Plan 67-03 is Wave 2 and Plan 67-05 is Wave 3; checkpoint rows retain executable evidence while requiring the indicated human confirmation/workflow action.*

---

## Wave 0 Requirements

- [ ] Extend `test/lattice_stripe/error_test.exs` and `test/lattice_stripe/client_test.exs` with header/parser and final-attempt cases before changing error behavior.
- [ ] Add the forced multi-chunk regression to `test/lattice_stripe/webhook/plug_test.exs` before promoting CacheBodyReader.
- [ ] Add section-scoped Charge policy assertions to `test/lattice_stripe/docs_truth_test.exs` before changing canonical prose.
- [ ] No framework installation is required; existing ExUnit/Mox infrastructure covers every phase requirement.

---

## Manual-Only Verifications

All phase behaviors have automated verification. The milestone audit rerun is a workflow evidence step with an automated produced-path/frontmatter/hash assertion; it is not a substitute for behavior checks.

---

## Threat References

- **T-67-01 — Information disclosure / input ambiguity:** response or request metadata is leaked, logged wholesale, or parsed permissively. Mitigate with response-only propagation, strict non-negative decimal parsing, and explicit documentation cautions.
- **T-67-02 — Tampering:** webhook verification sees altered, reordered, or truncated bytes. Mitigate with exact ordered chunk accumulation and integration coverage through `LatticeStripe.Webhook.Plug`.
- **T-67-03 — Information disclosure / denial of service:** global raw-body retention captures unrelated PII or increases memory pressure. Mitigate through fixed connection-lifetime storage, advanced-use positioning, multipart exclusion, and route-scoping guidance.
- **T-67-04 — Denial of service:** consumer Retry-After handling blocks request processes. Mitigate with bounded guide truth requiring delayed background work and no SDK scheduling changes.
- **T-67-05 — Tampering:** retry context and terminal error diverge across attempts. Mitigate with Mox assertions for the same final-attempt header evidence.
- **T-67-06 — Spoofing / information disclosure:** payment guidance obscures the authentication boundary. Mitigate with section-scoped client/SCA prose locks.
- **T-67-07 — Tampering:** Charge policy prose diverges from the actual public surface. Mitigate with docs truth plus structural mutation refutations.
- **T-67-08 — Repudiation:** stale or overwritten milestone evidence falsely certifies closure. Mitigate with observed commands, an explicit current audit path, and a fixed historical SHA-256 check.

## ASVS L1 Evidence Summary

- **V5 Input Validation applies** to 67-01-02, 67-01-03, and 67-05-01/02: the Error suite proves strict trimmed non-negative decimal-seconds parsing while preserving malformed raw evidence.
- **V6 Cryptographic Integrity applies** to 67-02-01/02, 67-03-02/03, and 67-05-01/02: the webhook suite proves exact signed bytes reach the existing HMAC verifier, while docs/API locks bind that invariant to the public contract.
- **V2 Authentication, V3 Session Management, and V4 Access Control are non-applicable** because Phase 67 adds no identity, session, or authorization mechanism; each plan's threat model records the plan-specific rationale.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Targeted feedback latency is under 30 seconds.
- [ ] `nyquist_compliant: true` is set in frontmatter after execution validation.

**Approval:** pending
