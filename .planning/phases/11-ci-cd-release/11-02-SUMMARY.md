---
phase: 11-ci-cd-release
plan: 02
subsystem: infra
tags: [github-actions, release-please, hex-publish, dependabot, ci-cd]

# Dependency graph
requires:
  - phase: 11-ci-cd-release
    provides: CI workflow foundation from plan 01
provides:
  - Release Please workflow with manifest mode for automated semver versioning
  - Hex.pm publishing triggered automatically on release creation
  - Dependabot config covering mix and github-actions ecosystems with weekly checks
  - Patch-only Dependabot auto-merge workflow gated on CI passing
affects: [future-releases, dependency-management, hex-publishing]

# Tech tracking
tech-stack:
  added:
    - googleapis/release-please-action@v4
    - dependabot/fetch-metadata@v2
  patterns:
    - Release Please manifest mode with release-please-config.json + .release-please-manifest.json
    - Hex publish job gated on release_created job output
    - Dependabot auto-merge via GitHub Actions workflow (not native Dependabot auto-merge) for CI gate

key-files:
  created:
    - .github/workflows/release.yml
    - release-please-config.json
    - .release-please-manifest.json
    - .github/dependabot.yml
    - .github/workflows/dependabot-automerge.yml
  modified: []

key-decisions:
  - "Release Please manifest mode (command: manifest) reads both config files — required for multi-package support and elixir release type"
  - "publish-hex job gates on release_created == 'true' output — prevents spurious publishes on non-release pushes"
  - "Dependabot auto-merge via GitHub Actions workflow (not native) — enables required CI status-check gate before merge"
  - "Patch-only auto-merge with --squash matches repo squash-merge strategy (D-35)"
  - "Dev deps grouped in dependabot.yml — reduces PR noise from test/lint dependency churn"

patterns-established:
  - "Pattern 1: Release Please manifest files (release-please-config.json + .release-please-manifest.json) must both exist at repo root for command: manifest to work"
  - "Pattern 2: Job output dependency pattern — jobs share data via outputs: block + needs.job-name.outputs.key in downstream if: condition"

requirements-completed: [CICD-02, CICD-03, CICD-04]

# Metrics
duration: 5min
completed: 2026-04-04
---

# Phase 11 Plan 02: Release Please, Hex Publishing, and Dependabot Summary

**Release Please manifest workflow + Hex.pm auto-publish + Dependabot for mix/github-actions with patch-only auto-merge**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-04T00:21:48Z
- **Completed:** 2026-04-04T00:26:50Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Release Please manifest config created tracking version 0.1.0 with elixir release type and changelog sections (feat, fix, perf, deps)
- Release workflow gates Hex.pm publish on release_created output — runs only when a release is actually created, not on every main push
- Dependabot configured for mix and github-actions ecosystems with Monday schedule, dev deps grouping, and chore(deps): commit prefix
- Auto-merge workflow for patch updates only, gated on CI passing via --auto flag and squash strategy

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Release Please workflow and manifest config** - `a478928` (feat)
2. **Task 2: Create Dependabot config and auto-merge workflow** - `12078f6` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `.github/workflows/release.yml` - Release Please + Hex.pm publish workflow; publish job gated on release_created output
- `release-please-config.json` - Release Please manifest config; elixir type, pre-1.0 bump strategy, changelog sections
- `.release-please-manifest.json` - Version tracking for Release Please; current version 0.1.0
- `.github/dependabot.yml` - Dependabot config for mix + github-actions; weekly Monday, grouped dev deps, 5 PR limit
- `.github/workflows/dependabot-automerge.yml` - Auto-merge workflow; patch-only, squash, CI-gated via --auto

## Decisions Made

- Release Please uses manifest mode (`command: manifest`) which reads both config files — required for the elixir release type to work correctly
- `publish-hex` job uses `if: ${{ needs.release-please.outputs.release_created == 'true' }}` — prevents publishing on non-release pushes to main
- Dependabot auto-merge is implemented as a GitHub Actions workflow rather than native Dependabot auto-merge — this is the correct approach per RESEARCH as it enables the required CI status-check gate before merge
- `--squash` in auto-merge command matches the repo's squash merge strategy (D-35)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

The following GitHub repository secrets must be configured before the release and Hex publish workflow will function:

- `HEX_API_KEY` — API key from hex.pm (Account Settings > API Keys, with `write` permission). Required for `mix hex.publish --yes` in the `publish-hex` job.

The `GITHUB_TOKEN` secret is automatically available in GitHub Actions — no manual configuration needed.

## Next Phase Readiness

- Release pipeline is complete: push conventional commits to main, Release Please creates version-bump PR, merging it triggers Hex.pm publish
- Dependabot will start checking dependencies on the next Monday after the workflow is pushed to main
- Phase 11 plan 03 (community/repo configuration) can proceed independently

---
*Phase: 11-ci-cd-release*
*Completed: 2026-04-04*
