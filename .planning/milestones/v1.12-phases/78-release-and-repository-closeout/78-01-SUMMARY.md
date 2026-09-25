---
phase: 78-release-and-repository-closeout
plan: 01
subsystem: release
tags: [hex, github-actions, release-evidence, phoenix-adopter, mix]

requires: []
provides:
  - Exact-version published-Hex Phoenix adopter smoke with isolated Mix, build, lockfile, and Hex registry state.
  - SHA-bound release verifier for main ancestry, tag, GitHub Release, ci-gate, Hex checksum, versioned HexDocs, and adopter execution.
  - Routine and recovery publication workflow checks that retain separate docs-only source provenance.
affects: [78-02, 78-03, 78-04, 78-05, 78-06, maintainer-release]

actuals:
  tokens: 4962
  tasks: 2
  commits: 2
plan_head_before: 40bf169e810836cb62528ab9d731f16d84703671
commits: 2

tech-stack:
  added: []
  patterns:
    - Exact-version Mix dependency selection is opt-in; normal adopter CI keeps its local path dependency.
    - Public Hex release checksum is compared with the SHA-256 of the downloaded outer package tarball.
    - Recovery verification tools are checked out independently so older package tags remain recoverable.

key-files:
  created:
    - scripts/maintainer/published_hex_adopter_smoke.sh
    - scripts/maintainer/release_evidence_check.sh
    - scripts/maintainer/test_release_evidence_check.sh
    - .planning/phases/78-release-and-repository-closeout/deferred-items.md
  modified:
    - test_apps/phoenix_adopter/mix.exs
    - test_apps/phoenix_adopter/README.md
    - .github/workflows/release.yml
    - .github/workflows/publish-hex.yml
    - .planning/WINDOWS.md

key-decisions:
  - "Keep the checked-out SDK path dependency as the default; the published-Hex mode requires an exact version and asserts Hex package metadata plus its lock entry."
  - "Compare Hex's release checksum to the downloaded outer tarball SHA-256; the public 2.2.2 API checksum matched that representation exactly."
  - "Run full package evidence only for package publication recovery; docs-only recovery records its own resolved source SHA separately."

patterns-established:
  - "Post-publish verification joins remote release facts to one immutable full commit SHA before testing package bytes."
  - "The post-publish Phoenix smoke runs without Stripe or publishing credentials and with disposable registry/dependency/build state."

requirements-completed: [REL-02, CLOSE-01]
coverage:
  - id: D1
    description: "An exact Hex release version compiles in the Phoenix host and passes synthetic Checkout and webhook flows."
    requirement: REL-02
    verification:
      - kind: integration
        ref: "scripts/maintainer/release_evidence_check.sh --version 2.2.2 --sha 7f290b11ddc5dcdefc9e6e0aa5cad43e9d734440 (published_hex_adopter_smoke.sh; 3 tests passed)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The release tag, GitHub Release, main ancestry, newest completed ci-gate, Hex checksum, and versioned docs reconcile against one SHA."
    requirement: CLOSE-01
    verification:
      - kind: other
        ref: "scripts/maintainer/release_evidence_check.sh --version 2.2.2 --sha 7f290b11ddc5dcdefc9e6e0aa5cad43e9d734440 (ci-gate run 32899069618 succeeded; Hex checksum 0d990ceaeb2794a24de200e7f7cff769491cb284350c148abdc02946fb66fed8)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Mismatch fixtures fail with named blockers and both publication workflows pass the exact resolved SHA and version to the verifier."
    requirement: REL-02
    verification:
      - kind: unit
        ref: "bash scripts/maintainer/test_release_evidence_check.sh (valid fixture plus tag, CI, version, checksum, docs, source, and workflow cases passed)"
        status: pass
      - kind: other
        ref: "actionlint .github/workflows/release.yml .github/workflows/publish-hex.yml"
        status: pass
    human_judgment: false

duration: 17min
completed: 2026-09-24
status: complete
---

# Phase 78 Plan 01: Published Release Evidence Summary

**Exact-SHA release verification now joins GitHub CI and release metadata to Hex tarball checksum, versioned HexDocs, and a credential-free Phoenix adopter using the published package.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-09-24T23:46:16Z
- **Completed:** 2026-09-25T00:04:07Z
- **Tasks:** 2
- **Files modified:** 10, including this summary and the deferred skipped-test record

## Accomplishments

- Added an isolated exact-version Hex mode for the Phoenix adopter; the default local path dependency remains unchanged for PR CI.
- Added a read-only verifier joining tag, GitHub Release, main ancestry, the newest completed exact-SHA `ci-gate`, Hex package checksum, versioned HexDocs, and synthetic adopter tests.
- Wired the verifier after routine and package-recovery publication; docs-only recovery records its own source SHA, and recovery obtains verifier scripts from the workflow SHA.
- Verified published release 2.2.2 at SHA `7f290b11ddc5dcdefc9e6e0aa5cad43e9d734440`. Its `ci-gate` succeeded, Hex API checksum and downloaded outer tarball SHA-256 both equal `0d990ceaeb2794a24de200e7f7cff769491cb284350c148abdc02946fb66fed8`, versioned docs identify 2.2.2, and the Hex-backed Phoenix flow passed all three tests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Trace one published Hex release through registry, docs, and Phoenix consumption** - `bee0e0a` (feat)
2. **Task 2: Guard negative release cases and run the verifier at the publication boundary** - `ef253f5` (feat)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `scripts/maintainer/published_hex_adopter_smoke.sh` - resolves and tests an exact Hex release in disposable Mix, Hex, dependency, lockfile, and build state.
- `scripts/maintainer/release_evidence_check.sh` - verifies exact release provenance and executes the published-package smoke.
- `scripts/maintainer/test_release_evidence_check.sh` - exercises valid, mismatch, and workflow-wiring fixtures.
- `test_apps/phoenix_adopter/mix.exs` - selects the exact Hex dependency only when the release-mode environment variable is set.
- `test_apps/phoenix_adopter/README.md` - documents the published-package release command and source assertion.
- `.github/workflows/release.yml` - exports the immutable gated SHA and checks published evidence.
- `.github/workflows/publish-hex.yml` - checks package recovery and records docs-only source provenance.
- `.planning/WINDOWS.md`, `.planning/phases/78-release-and-repository-closeout/deferred-items.md` - track a pre-existing skipped integration spec found by the full CI run.

## Decisions Made

- Kept local path-based adopter resolution as the default and made Hex resolution explicit and exact-version-only.
- Confirmed experimentally that Hex's release API checksum matches the SHA-256 of the public outer package tarball.
- Kept Hex publishing credentials out of the smoke process; the GitHub read token is limited to the evidence step and is removed before launching the adopter.
- Kept docs-only refresh provenance distinct from the package release SHA.
- `REL-02` and `CLOSE-01` are complete for this plan, but shared requirement IDs are not marked in `REQUIREMENTS.md` because sibling Phase 78 plans remain unfinished.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Preserved toolchain and registry isolation for the temporary adopter**
- **Found during:** Task 1
- **Issue:** The temporary directory did not inherit the repository's asdf tool versions, and Hex attempted to write its shared registry cache outside the worktree.
- **Fix:** The smoke reads exact Elixir/Erlang versions from `.tool-versions` and sets `HEX_HOME`, deps, and build paths inside its disposable directory.
- **Files modified:** `scripts/maintainer/published_hex_adopter_smoke.sh`
- **Verification:** The 2.2.2 Hex smoke compiled the host and passed 3 synthetic tests without writing to the shared Hex cache.
- **Committed in:** `bee0e0a`

**2. [Rule 1 - Bug] Checked exact dependency version from the generated Hex lock entry**
- **Found during:** Task 1
- **Issue:** Mix's `deps` display identifies Hex package source but omits the version inline; an initial source/version check expected a version on that line.
- **Fix:** Asserted the Hex package source from Mix output and the exact requested version from the isolated lock entry.
- **Files modified:** `scripts/maintainer/published_hex_adopter_smoke.sh`
- **Verification:** The smoke passed with Hex 2.2.2; the wrong-source fixture failed with its named blocker.
- **Committed in:** `bee0e0a`

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking issue, 1 Rule 1 bug). **Impact:** Both adjustments were required to make isolated registry proof work correctly; no package or public SDK behavior changed.

## Issues Encountered

- Full `mix ci` passed: 2,462 tests, 0 failures, one pre-existing skipped test, with 203 integration-tagged tests excluded. The skipped meter-event stream integration spec at `test/lattice_stripe/billing/meter_event_stream_integration_test.exs:4` remains out of this plan's scope; its stated Stripe Mock limitation and Mox boundary were recorded in `.planning/WINDOWS.md` entry 2 and `deferred-items.md`.
- `actionlint` passed for both changed workflows. The path-mode Phoenix adopter passed 9 tests. No new test was skipped or left unrun.

## User Setup Required

None. Existing GitHub and Hex publication credentials are unchanged.

## Next Phase Readiness

- Plan 78-01 is complete and ready for the remaining Phase 78 plans.
- The known 2.2.2 release provides a passing baseline for the verifier; the next release will be checked at its own tag SHA after publication.
- The shared `REL-02` and `CLOSE-01` requirement checkboxes remain for phase-level completion after sibling plans finish.

## Self-Check: PASSED

- All three planned scripts, the summary, and deferred-item note exist.
- Task commits `bee0e0a` and `ef253f5` exist.
- Both requirement IDs are present in the plan frontmatter and this summary.

---
*Phase: 78-release-and-repository-closeout*
*Completed: 2026-09-24*
