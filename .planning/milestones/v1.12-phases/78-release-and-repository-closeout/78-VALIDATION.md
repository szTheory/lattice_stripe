---
phase: "78"
slug: "release-and-repository-closeout"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-24"
---

# Phase 78 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for the Elixir package and Phoenix adopter; shell/GitHub CLI probes for release and worktree inventory |
| **Config file** | `.github/workflows/ci.yml`; `test_apps/phoenix_adopter/test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/version_prose_test.exs test/lattice_stripe/api_surface_lock_test.exs` (compatibility/pre-release checks) |
| **Full suite command** | `mix ci`; `cd test_apps/phoenix_adopter && mix deps.get --check-locked && mix test --warnings-as-errors`; required remote `ci-gate` on exact release SHA |
| **Estimated runtime** | Use the latest `ci-gate` run duration; no local runtime was measured during planning |

---

## Sampling Rate

- **After each workflow/probe task:** run the focused shell fixture or ExUnit check for that change.
- **After every plan wave:** run focused package checks and the adopter suite when files under either boundary changed.
- **Before `$gsd-verify-work`:** require `mix ci`, adopter gate, and exact-SHA release evidence to be green.
- **Max feedback latency:** Keep local focused checks under 30 seconds; remote CI and registry propagation use bounded workflow timeouts and explicit failure diagnostics.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 78-01-01 | 01 | 1 | REL-01 | — | Release version follows reviewed API compatibility and unchanged default API pin | compatibility | `mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/version_prose_test.exs` | ✅ | ⬜ pending |
| 78-01-02 | 01 | 1 | REL-02 | — | Published package source/version and versioned docs resolve to release metadata | package + adopter smoke | isolated Hex resolution for exact version; compile and run selected synthetic adopter tests | ❌ Wave 0 | ⬜ pending |
| 78-01-03 | 01 | 1 | CLOSE-01 | — | Required `ci-gate` is successful for the immutable release SHA on `main` | GitHub checks probe | query `ci-gate` by full release SHA and assert main/tag/release SHA association | ❌ Wave 0 | ⬜ pending |
| 78-01-04 | 01 | 1 | CLOSE-02 | — | Every currently open PR has a contributor-visible disposition and linked ledger entry | inventory/evidence | `gh pr list --state open` plus a completeness verifier over PR state and the closeout ledger | ❌ Wave 0 | ⬜ pending |
| 78-01-05 | 01 | 1 | CLOSE-03 | — | Primary checkout and every linked worktree are clean, with untracked files included | shell/Git probe | `git worktree list --porcelain -z` and per-path `git status --porcelain=v1 --untracked-files=all` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add deterministic fixtures/tests for the worktree probe: clean, tracked dirty, untracked, path with whitespace, missing/uninspectable worktree, and command error.
- [ ] Add fixtures/tests for release-evidence mismatches: wrong SHA/version, missing `ci-gate`, unavailable versioned docs, package resolution to a path dependency, and Hex version mismatch.
- [ ] Add a published-Hex execution mode or isolated consumer fixture that asserts exact Hex source and version; preserve the current local path-dependency mode for fast PR CI.
- [ ] Add an open-PR inventory/ledger completeness check that fails closed when remote state or an individual disposition cannot be inspected.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Resolve an ambiguous PR's contribution fit, security concern, or contributor intent | CLOSE-02 | CI and metadata cannot infer project fit or author intent. Escalate only if the open PR inventory contains such a genuine ambiguity; record the decision and rationale in GitHub and the ledger. | Review the specific PR and its required checks; record merge/request-changes/defer/close with a reason and next step. |

No blanket release UAT is required when all named checks pass. Never discard or force-remove a dirty or unowned worktree to clear CLOSE-03.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for local focused checks
- [ ] `nyquist_compliant: true` set in frontmatter after required checks are implemented and pass

**Approval:** pending
