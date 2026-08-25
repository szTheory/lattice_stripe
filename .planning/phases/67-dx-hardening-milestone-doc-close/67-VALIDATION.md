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
| 67-01-01 | 01 | 1 | DX-02 | T-67-01 | Strict delay-seconds parsing; raw headers preserved without request-header leakage | unit | `mix test test/lattice_stripe/error_test.exs` | ✅ extend | ⬜ pending |
| 67-01-02 | 01 | 1 | DX-02 | T-67-01 | JSON, non-JSON, connection, and final-retry paths expose only final response metadata | unit/Mox | `mix test test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs` | ✅ extend | ⬜ pending |
| 67-02-01 | 02 | 1 | DX-03 | T-67-02, T-67-03 | Raw webhook bytes accumulate exactly in byte order without hidden storage expansion | unit/integration | `mix test test/lattice_stripe/webhook/plug_test.exs` | ✅ extend | ⬜ pending |
| 67-02-02 | 02 | 1 | DX-03 | T-67-03 | Public module is documented, conditionally available, correctly grouped, and semver-locked | API/docs lock | `mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/docs_truth_test.exs` | ✅ extend | ⬜ pending |
| 67-03-01 | 03 | 1 | DOC-02 | — | Canonical Charge surfaces route initiation to PaymentIntent without obscuring SCA | docs truth + structural unit | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs` | ✅ extend | ⬜ pending |
| 67-04-01 | 04 | 2 | DOC-02 | — | Strict zero-warning and full quality gates remain enforced | docs/full gate | `mix docs --warnings-as-errors && mix ci` | ✅ existing | ⬜ pending |

*Task and plan identifiers are provisional until PLAN.md files are finalized; commands and requirement coverage are normative.*

---

## Wave 0 Requirements

- [ ] Extend `test/lattice_stripe/error_test.exs` and `test/lattice_stripe/client_test.exs` with header/parser and final-attempt cases before changing error behavior.
- [ ] Add the forced multi-chunk regression to `test/lattice_stripe/webhook/plug_test.exs` before promoting CacheBodyReader.
- [ ] Add section-scoped Charge policy assertions to `test/lattice_stripe/docs_truth_test.exs` before changing canonical prose.
- [ ] No framework installation is required; existing ExUnit/Mox infrastructure covers every phase requirement.

---

## Manual-Only Verifications

All phase behaviors have automated verification. The milestone audit rerun is a workflow evidence step, not a substitute for an automated behavior check.

---

## Threat References

- **T-67-01 — Information disclosure / input ambiguity:** response or request metadata is leaked, logged wholesale, or parsed permissively. Mitigate with response-only propagation, strict non-negative decimal parsing, and explicit documentation cautions.
- **T-67-02 — Tampering:** webhook verification sees altered, reordered, or truncated bytes. Mitigate with exact ordered chunk accumulation and integration coverage through `LatticeStripe.Webhook.Plug`.
- **T-67-03 — Information disclosure / denial of service:** global raw-body retention captures unrelated PII or increases memory pressure. Mitigate through fixed connection-lifetime storage, advanced-use positioning, multipart exclusion, and route-scoping guidance.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Targeted feedback latency is under 30 seconds.
- [ ] `nyquist_compliant: true` is set in frontmatter after execution validation.

**Approval:** pending
