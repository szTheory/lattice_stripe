---
phase: 11
slug: ci-cd-release
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix ci` (format + compile + credo + test + docs) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test`
- **After every plan wave:** Run `mix ci`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | CICD-01 | config | `cat .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 1 | CICD-05 | config | `grep stripe-mock .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 11-01-03 | 01 | 1 | CICD-01 | config | `grep mix.exs .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 11-02-01 | 02 | 2 | CICD-02 | config | `cat release-please-config.json` | ❌ W0 | ⬜ pending |
| 11-02-02 | 02 | 2 | CICD-03 | config | `grep hex.publish .github/workflows/release.yml` | ❌ W0 | ⬜ pending |
| 11-02-03 | 02 | 2 | CICD-04 | config | `cat .github/dependabot.yml` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing test infrastructure covers all phase requirements — Phase 11 creates config files (YAML, JSON), not Elixir code requiring new tests.
- Validation is via file existence checks and content grep, not ExUnit tests.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CI workflow runs on GitHub | CICD-01 | Requires push to GitHub | Push branch, verify Actions tab shows workflow run |
| Release Please creates PR | CICD-02 | Requires Conventional Commit on main | Merge a `feat:` commit, verify Release Please PR appears |
| Hex publish succeeds | CICD-03 | Requires HEX_API_KEY secret | Set secret, merge release PR, verify hex.pm package |
| Dependabot creates PRs | CICD-04 | Requires GitHub repo with deps | Wait for Monday scan, verify PR appears |
| stripe-mock runs in CI | CICD-05 | Requires GitHub Actions runner | Push branch with integration tests, verify they pass |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
