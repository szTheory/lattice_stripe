---
phase: 62
slug: 1-1-1-7-what-landed-migration-guide
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-24
---

# Phase 62 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Quick: <10 seconds; full: use current `mix ci` baseline |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **After every plan wave:** Run `mix docs --warnings-as-errors`
- **Before `$gsd-verify-work`:** `mix ci` must be green
- **Max feedback latency:** 10 seconds for task-level sampling

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 62-01-01 | 01 | 1 | DOC-01 | T-62-01 / T-62-02 | Historical scope and webhook safety boundaries remain explicit | semantic docs regression | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ extend existing | ✅ green — 57 tests, 0 failures |
| 62-01-02 | 01 | 1 | DOC-01 | T-62-01 / T-62-03 | Guide is historically correct, complete, and routes to canonical safe flows | docs build | `mix docs --warnings-as-errors` | ✅ | ✅ green |
| 62-01-03 | 01 | 1 | DOC-01 | — | Project-wide regressions remain absent | full CI | `mix ci` | ✅ | ✅ green — 2392 tests, 0 failures, 1 skipped (214 excluded) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Extend `test/lattice_stripe/docs_truth_test.exs` with the focused historical-guide contract specified by D-13 and D-14 before relying on task-level semantic sampling.

## Phase-start Scope Baseline

- **Phase-start SHA:** `cc87e3a0963f0e9bf7341bb009d80f12cae7f3d3`
- **Protected audit status:** `?? .planning/v1.10-MILESTONE-AUDIT.md`
- **Protected audit blob:** `cfa87dc36c3e6af085e8a5bb6da1caa2bb77fc42`

## Gap-closure Dirty-Worktree Baseline

Captured before the first 62-02 edit with
`git status --porcelain=v1 --untracked-files=all`. This is intentionally a
full porcelain baseline: untracked files are part of the later symmetric-delta
check and cannot bypass the scope audit.

<!-- phase62-full-status-baseline:start -->
?? .planning/research/.cache/dda606cfeda5d4a510c525a62aca3da5743d07123b8fe9eff3f7a3ab1aae6af2.json
?? .planning/v1.10-MILESTONE-AUDIT.md
<!-- phase62-full-status-baseline:end -->

<!-- phase62-audit-status: ?? .planning/v1.10-MILESTONE-AUDIT.md -->
<!-- phase62-audit-blob: cfa87dc36c3e6af085e8a5bb6da1caa2bb77fc42 -->
<!-- phase62-cache-status:start -->
?? .planning/research/.cache/dda606cfeda5d4a510c525a62aca3da5743d07123b8fe9eff3f7a3ab1aae6af2.json
<!-- phase62-cache-status:end -->
<!-- phase62-cache-fingerprint: e6f22a0f9abbaf0822b178c301fc2a4bae22ff67fc8cb6faa33340393e54c1c4 -->

The milestone audit and the research cache are user-owned, pre-existing,
untracked state. Their exact porcelain status and content fingerprints must
remain unchanged; neither belongs to Phase 62's allowlist.

The protected milestone audit existed before Phase 62 and is intentionally untracked.
Its final status and blob must match these exact values.

---

## Observed Gate Evidence

- `mix test test/lattice_stripe/docs_truth_test.exs` — PASS, 57 tests and 0 failures.
- `mix docs --warnings-as-errors` — PASS, generated HTML, Markdown, and EPUB docs with no warnings.
- `mix ci` — PASS, Credo found no issues; 2392 tests passed, 0 failed, 1 skipped, and 214 excluded; API surface and version prose checks passed; docs generated successfully.

### Gap-closure refresh (2026-08-24)

- `mix test test/lattice_stripe/docs_truth_test.exs` — PASS, 57 tests and 0 failures.
- `mix docs --warnings-as-errors` — PASS, generated HTML, Markdown, and EPUB docs with no warnings.
- `mix ci` — PASS, Credo found no issues; 2392 tests passed, 0 failed, 1 skipped, and 214 excluded; API surface lock reported 3427 entries; version prose matched 2.1.0; docs generated successfully.

## D-15 Immutable Executor Scope Audit

Recorded after staging the required workflow artifacts, using phase-start SHA
`cc87e3a0963f0e9bf7341bb009d80f12cae7f3d3`, with the immutable executor
endpoint `9d111dfb4c251d544570aebcce951094ba4161f4`. Its exact four-path
allowlist applies only to that executor range; it is not a retroactive claim
about later review, verification, or closure records.

| Surface | Observed paths | Result |
|---|---|---|
| `git diff --name-only cc87e3a0963f0e9bf7341bb009d80f12cae7f3d3..HEAD` | `62-VALIDATION.md`; `guides/upgrading-1-1-to-1-7.md`; `test/lattice_stripe/docs_truth_test.exs` | allowed |
| `git diff --cached --name-only` | `62-01-SUMMARY.md`; `62-VALIDATION.md` | allowed |
| `git diff --name-only` | *(empty)* | allowed |
| Protected audit status | `?? .planning/v1.10-MILESTONE-AUDIT.md` | matches baseline |
| Protected audit blob | `cfa87dc36c3e6af085e8a5bb6da1caa2bb77fc42` | matches baseline |

The executor-range combined committed, staged, and unstaged paths are limited
to the guide, docs-truth test, validation record, and required summary artifact.
No production module, dependency, schema, or API lock changed in that range.

## D-15 Lifecycle / Corrective Scope Model

The final lifecycle audit is a separate, fail-closed category proof. Its
closure endpoint is recorded only after the 62-02 summary content commit.

- **Permitted product deliverables:** exactly
  `guides/upgrading-1-1-to-1-7.md` and
  `test/lattice_stripe/docs_truth_test.exs`.
- **Permitted workflow records:** only Phase 62-local `NN-PLAN.md`,
  `NN-SUMMARY.md`, `62-VALIDATION.md`, `62-REVIEW.md`,
  `62-REVIEW-FIX.md`, and `62-VERIFICATION.md` records.
- **Everything else fails closed:** including a new untracked path, `lib/**`,
  `mix.exs`, `mix.lock`, dependency manifests/locks, schema or migration paths,
  and `priv/api/current.txt`.

The lifecycle audit will compare committed, staged, unstaged, and full-porcelain
surfaces against this model and re-check the preserved baseline fingerprints.

## Manual-Only Verifications

None. This headless library phase has no UI, click-path, or performance-feel
surface. The named executable checks above prove the documentation contract,
publication wiring, and build health.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10 seconds for task-level sampling
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated by named executable checks on 2026-08-24
