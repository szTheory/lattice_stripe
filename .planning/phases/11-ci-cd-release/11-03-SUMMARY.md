---
phase: 11-ci-cd-release
plan: 03
subsystem: infra
tags: [github, open-source, contributing, security, community]

# Dependency graph
requires:
  - phase: 11-ci-cd-release
    provides: CI workflow and Release Please infrastructure built in plans 01-02
provides:
  - CONTRIBUTING.md with dev setup, stripe-mock integration test instructions, Conventional Commits guide, PR process
  - SECURITY.md with private vulnerability reporting channel and response SLAs
  - GitHub issue templates (YAML form format) for bug reports and feature requests
  - PR template with quality checklist including mix format, credo, and Conventional Commits
affects: [contributors, maintainers, open-source-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "YAML form issue templates (.github/ISSUE_TEMPLATE/*.yml) for structured GitHub issue intake"
    - "PR template checklist pattern enforcing mix format + credo + Conventional Commits"

key-files:
  created:
    - CONTRIBUTING.md
    - SECURITY.md
    - .github/ISSUE_TEMPLATE/bug_report.yml
    - .github/ISSUE_TEMPLATE/feature_request.yml
    - .github/PULL_REQUEST_TEMPLATE.md
  modified: []

key-decisions:
  - "Docs-only PR bypass caveat documented in CONTRIBUTING.md — CI skips for .md/.planning/guides changes so maintainer bypass may be needed"
  - "security@latticestripe.dev as private reporting channel with 48h acknowledgment, 7-day assessment, 30-day patch SLA"
  - "YAML form templates chosen over markdown templates for structured GitHub issue intake"

patterns-established:
  - "Community files at repo root (CONTRIBUTING.md, SECURITY.md) follow OSS conventions"
  - "Issue templates use YAML body fields with validations.required for mandatory fields"

requirements-completed: [CICD-01, CICD-02, CICD-03, CICD-04, CICD-05]

# Metrics
duration: 3min
completed: 2026-04-04
---

# Phase 11 Plan 03: Community Files Summary

**CONTRIBUTING, SECURITY, YAML issue templates, and PR checklist template for professional OSS repo infrastructure**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-04T00:21:50Z
- **Completed:** 2026-04-04T00:22:53Z
- **Tasks:** 1 auto + 1 checkpoint (auto-approved)
- **Files modified:** 5

## Accomplishments

- CONTRIBUTING.md with complete dev setup (deps, test, CI), stripe-mock Docker integration test instructions, Conventional Commits examples, PR process with branch naming convention, and docs-only PR bypass note
- SECURITY.md with private email reporting, 48-hour acknowledgment SLA, 7-day assessment timeline, 30-day patch commitment
- YAML form issue templates for bug reports (version, Elixir/OTP, steps, expected/actual) and feature requests (problem, solution, Stripe API field)
- PR template with type-of-change checklist, quality gate checklist (mix format, mix credo --strict, mix test), and Conventional Commits reference

## Task Commits

1. **Task 1: Create community files** - `36d6a7a` (feat)
2. **Task 2: Verify CI/CD and repo settings** - auto-approved checkpoint (human action deferred per auto_advance config)

**Plan metadata:** _(pending final docs commit)_

## Files Created/Modified

- `/Users/jon/projects/lattice_stripe/CONTRIBUTING.md` - Full contributor guide with stripe-mock, Conventional Commits, PR process
- `/Users/jon/projects/lattice_stripe/SECURITY.md` - Private vulnerability reporting policy
- `/Users/jon/projects/lattice_stripe/.github/ISSUE_TEMPLATE/bug_report.yml` - Structured bug report form
- `/Users/jon/projects/lattice_stripe/.github/ISSUE_TEMPLATE/feature_request.yml` - Structured feature request form
- `/Users/jon/projects/lattice_stripe/.github/PULL_REQUEST_TEMPLATE.md` - PR checklist template

## Decisions Made

- Docs-only PR bypass caveat documented in CONTRIBUTING.md — CI is configured to skip documentation-only paths, so maintainer bypass of status checks may be needed for docs PRs
- YAML form templates (`.yml`) chosen over markdown templates for structured GitHub issue intake with field validation
- security@latticestripe.dev as private reporting email with explicit SLA timeline (48h ack, 7d assessment, 30d patch)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

The following manual GitHub repo configuration steps are required (per `user_setup` in plan frontmatter):

**hex.pm:**
- Generate HEX_API_KEY scoped to `lattice_stripe` package at hex.pm -> Account Settings -> Keys
- Add as GitHub repo secret: Settings -> Secrets and variables -> Actions -> New repository secret

**GitHub repo settings:**
- Settings -> General -> Pull Requests: enable squash merge only, enable auto-delete head branches
- Settings -> Branches: add rule for `main` — require status checks (lint, test, integration), prevent force push, allow maintainer bypass
- Repo About (gear icon): add topics `elixir`, `stripe`, `payments`, `sdk`

## Next Phase Readiness

Phase 11 (CI/CD & Release) is fully complete:
- Plan 01: GitHub Actions CI workflow (lint, test matrix, integration)
- Plan 02: Release Please, Dependabot, Hex publishing
- Plan 03: Community files (CONTRIBUTING, SECURITY, issue/PR templates)

Repository is ready for open-source release pending manual GitHub settings and HEX_API_KEY secret.

## Self-Check: PASSED

---
*Phase: 11-ci-cd-release*
*Completed: 2026-04-04*
