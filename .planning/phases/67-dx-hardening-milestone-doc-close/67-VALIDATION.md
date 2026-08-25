---
phase: 67
slug: dx-hardening-milestone-doc-close
status: validated
nyquist_compliant: true
wave_0_complete: true
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
- **Before `$gsd-verify-work`:** `mix ci` must be green. The milestone audit is a separate post-verification orchestration step and cannot run until `67-VERIFICATION.md` is present and passing.
- **Max feedback latency:** 30 seconds for targeted task feedback; the full gate runs at wave/phase boundaries.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 67-01-01 | 01 | 1 | DX-02 | T-67-01 | Records prior approval of the exact one-way Error contract without reopening D-01/D-02/D-04 | locked-decision checkpoint | `rg -n 'D-01:|D-02:|D-04:' .planning/phases/67-dx-hardening-milestone-doc-close/67-CONTEXT.md` | ✅ existing | ✅ pass — recorded locked contract |
| 67-01-02 | 01 | 1 | DX-02 | T-67-01, T-67-05 | JSON, non-JSON, connection, and final-retry paths expose only final response metadata | unit/Mox tracer | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs --warnings-as-errors` | ✅ extend | ✅ pass — covered by 67-05 focused suite |
| 67-01-03 | 01 | 1 | DX-02 | T-67-01, T-67-04 | Strict delay-seconds parsing, repeatability, parallel purity, and non-blocking guidance | unit/docs | `mix test test/lattice_stripe/error_test.exs --warnings-as-errors && mix format --check-formatted` | ✅ extend | ✅ pass — focused suite and format gate |
| 67-02-01 | 02 | 1 | DX-03 | T-67-02, T-67-03 | Raw webhook bytes accumulate exactly in byte order without hidden storage expansion | unit/integration | `mix test test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors && mix format --check-formatted` | ✅ extend | ✅ pass — covered by 67-05 focused suite |
| 67-02-02 | 02 | 1 | DX-03 | T-67-02 | Error passthrough and the Webhook.Plug consumer retain the completed signed byte stream | integration | `mix test test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors` | ✅ extend | ✅ pass — covered by 67-05 focused suite |
| 67-03-01 | 03 | 2 | DX-03 | T-67-02, T-67-03 | Records prior approval of the exact one-way conditional CacheBodyReader contract without reopening D-07/D-09 | locked-decision checkpoint | `rg -n 'D-07:|D-09:' .planning/phases/67-dx-hardening-milestone-doc-close/67-CONTEXT.md` | ✅ existing | ✅ pass — recorded locked contract |
| 67-03-02 | 03 | 2 | DX-03 | T-67-03 | Public guidance makes conditional availability and PII/memory/multipart limits explicit | docs | `mix docs --warnings-as-errors && mix format --check-formatted` | ✅ extend | ✅ pass — zero-warning ExDoc and format gate |
| 67-03-03 | 03 | 2 | DX-03 | T-67-02, T-67-03 | Public module is grouped, conditionally documented, exact-byte tested, and semver-locked | API/docs lock | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors && mix lattice_stripe.api_surface --check` | ✅ extend | ✅ pass — focused suite and 3463-entry lock |
| 67-04-01 | 04 | 1 | DOC-02 | T-67-06, T-67-07 | Canonical Charge surfaces route initiation to PaymentIntent without obscuring SCA | docs truth + structural unit | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs --warnings-as-errors && mix docs --warnings-as-errors` | ✅ extend | ✅ pass — focused suite and zero-warning ExDoc |
| 67-04-02 | 04 | 1 | DOC-02 | T-67-07 | Canonical policy ownership remains deterministic under repeated and parallel reads | docs truth + structural unit | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs --warnings-as-errors` | ✅ extend | ✅ pass — covered by 67-05 focused suite |
| 67-05-01 | 05 | 3 | DX-02, DX-03, DOC-02 | T-67-01, T-67-02, T-67-03, T-67-04 | Focused behavior, strict ExDoc, and API evidence is sampled before the long gate | focused phase gate | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/charge_test.exs test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs --warnings-as-errors && mix docs --warnings-as-errors && mix lattice_stripe.api_surface --check` | ✅ existing/extend | ✅ pass — 292 tests, zero ExDoc warnings, API lock 3463 entries (2026-08-25) |
| 67-05-02 | 05 | 3 | DX-02, DX-03, DOC-02 | T-67-08 | Full CI, API-coverage disposition, commit-aware D-18 blocks/cache evidence, persisted phase base, and historical-audit hash converge | full/scope gate | `mix ci` plus Task 2's exact base derivation, `git diff --name-only <base>..HEAD`, protected named-block/source comparisons, cache status/fingerprint, detector, and hash command | ✅ `67-PHASE-BASE.md` | ✅ pass — 2435 tests, scope and protected seams verified (2026-08-25) |

*The 12 rows above map every executable task in the five submitted plans. Plan 67-03 is Wave 2 and Plan 67-05 is Wave 3. Milestone re-audit is deliberately excluded because execute-plan does not create the Phase 67 verification artifact that the audit requires.*

## Post-verification orchestration

| Obligation | Trigger / Precondition | Requirement | Threat Ref | Verification Class | Machine-Verifiable Evidence | Output | Status |
|------------|------------------------|-------------|------------|--------------------|-----------------------------|--------|--------|
| D-17 milestone re-audit | Root auto-advance receives `PHASE COMPLETE`; `67-VERIFICATION.md` exists with `status: passed` | DX-02, DX-03, DOC-02 | T-67-08 | machine-verifiable workflow evidence after phase seal | Follow `67-POST-PHASE-SEAL.md`; require fresh/current Phase 67 audit status `passed` or `tech_debt`, identical source/destination hashes, fixed historical SHA-256, clean supported workspace removal | `.planning/v1.10-POST-PHASE-67-MILESTONE-AUDIT.md` | ⬜ pending |

Under `.agents/skills/lattice-verification-policy/SKILL.md`, this obligation does not require subjective human judgment: every acceptance fact has a named executable check. The supported workspace removal confirmation is an orchestration safety gate, not evidence replacing those checks.

---

## Wave 0 Requirements

- [ ] Extend `test/lattice_stripe/error_test.exs` and `test/lattice_stripe/client_test.exs` with header/parser and final-attempt cases before changing error behavior.
- [ ] Add the forced multi-chunk regression to `test/lattice_stripe/webhook/plug_test.exs` before promoting CacheBodyReader.
- [ ] Add section-scoped Charge policy assertions to `test/lattice_stripe/docs_truth_test.exs` before changing canonical prose.
- [ ] No framework installation is required; existing ExUnit/Mox infrastructure covers every phase requirement.

---

## Manual-Only Verifications

All phase behaviors have automated verification. There are no manual-only phase-verifier items. The milestone audit rerun occurs only after the phase seal and has separate machine-verifiable freshness, status, Phase 67 marker, path, workspace-removal, and historical-hash assertions.

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

- [x] All tasks have `<automated>` verification or Wave 0 dependencies.
- [x] Sampling continuity: no three consecutive tasks without automated verification.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Targeted feedback latency is under 30 seconds.
- [x] `nyquist_compliant: true` is set in frontmatter after execution validation.

**Approval:** validated — all executable Phase 67 evidence is mechanically green. D-17 remains a separate root-orchestrator obligation after a passing `67-VERIFICATION.md` exists.

---

## Observed Execution Evidence

### Task 67-05-01 — focused strict documentation and API sample

Observed 2026-08-25 before the full `mix ci` convergence gate:

- `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/charge_test.exs test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs --warnings-as-errors` — **PASS**; 292 tests, 0 failures.
- `mix docs --warnings-as-errors` — **PASS**; documentation generated with zero warnings.
- `mix lattice_stripe.api_surface --check` — **PASS**; `Public API surface matches priv/api/current.txt (3463 entries).`

Task 2 must still record the full CI result, final-scope disposition, immutable Phase 67 base, protected-block comparisons, cache fingerprint, historical-audit hash, and final Nyquist sign-off.

### Task 67-05-02 — full CI and final scope convergence

- `mix ci` — **PASS**; 2,435 tests, 0 failures, 1 skipped, 214 excluded; Credo strict, API lock, version prose, and strict ExDoc generation all completed successfully.
- Final detector — **detected: true** only because the Phase 67 planning text names an additive API. `COVERAGE.md` exists and contains the required reasoned declaration: `No external API integration: Phase 67 hardens existing LatticeStripe error metadata, Plug raw-body handling, semver locks, and docs; it adds no Stripe endpoint, verb, or external service.` No capability rows were added.
- Phase base — oldest Phase 67 task commit is `da7b6e8745435900637f301c6c3ec46fab4c8e89`; its first parent/base is `22108c1ea9a01c07b88f745c1af0bb97033d3772`, verified as an ancestor of `HEAD`. The derivation and literal SHAs are persisted in `67-PHASE-BASE.md`.
- Committed inventory from `git diff --name-only 22108c1ea9a01c07b88f745c1af0bb97033d3772..HEAD` contains the Phase 67 implementation/docs/tests and prior phase close-out artifacts only: `.planning/{REQUIREMENTS.md,ROADMAP.md,STATE.md}`, Phase 67 summaries/validation, guides, the four Phase 67 library seams, the API lock, and focused tests.
- Staged inventory — **empty**. Unstaged tracked inventory — **empty**. At the scope snapshot, only the newly created `67-PHASE-BASE.md` and the protected user-owned untracked cache/audit appeared in porcelain status.
- Protected seams — **PASS**: the exact Batch error-isolation test block, retry-telemetry test block, `lib/lattice_stripe/telemetry.ex`, and `Client.maybe_retry/5` block remain byte-identical to the Phase base. Intentional final-attempt header tests elsewhere in `client_test.exs` remain in scope.
- Protected user data — **PASS**: cache status is exactly `?? .planning/research/.cache/dda606cfeda5d4a510c525a62aca3da5743d07123b8fe9eff3f7a3ab1aae6af2.json`; deterministic content fingerprint is `e6f22a0f9abbaf0822b178c301fc2a4bae22ff67fc8cb6faa33340393e54c1c4`. Historical audit SHA-256 is `96d0ee3584c074566aaf3f3c516d005bb227e4916268b00cecf0073ba09d2726`.
- Rule 1 quality fix — initial `mix ci` found a Credo nested-body-depth violation in the prior Phase 67 Retry-After parser. `LatticeStripe.Error.retry_after/1` now delegates parsing to `parse_retry_after/1`; focused Error/Client tests (134), strict Credo, and the complete focused/full gates pass with the strict first-valid-header, trimmed non-negative decimal, uncapped semantics unchanged.
