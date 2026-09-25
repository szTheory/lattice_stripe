# Phase 78: Release and Repository Closeout - Pattern Map

**Mapped:** 2026-09-24  
**Files analyzed:** 9 expected implementation/evidence surfaces  
**Analogs found:** 9 / 9

## File Classification

The research defines capability gaps rather than exact filenames. The files below are likely homes; the planner may combine the closeout checks into the existing hygiene script or a focused verifier, and should avoid duplicating release state.

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/release-pr-automerge.yml` | workflow/config | request-response / event-driven | same file | exact |
| `.github/workflows/ci.yml` | workflow/config | batch | same file | exact |
| `test_apps/phoenix_adopter/mix.exs` | config | dependency resolution / batch | same file | exact |
| `test_apps/phoenix_adopter/test/release_hex_adoption_test.exs` (or existing adopter test) | test | request-response | `test_apps/phoenix_adopter/test/core_flow_test.exs` | role-match |
| `scripts/maintainer/release_evidence_check.sh` (or equivalent) | utility | request-response / batch | `scripts/maintainer/repo_hygiene_check.sh` | role-match |
| `scripts/maintainer/repo_hygiene_check.sh` or focused closeout checker | utility | batch | same file | exact |
| `.planning/RELEASE-TRAIN.md` | documentation/evidence ledger | batch | same file | exact |
| `.planning/phases/78-release-and-repository-closeout/78-CLOSEOUT.md` (dated PR disposition ledger) | documentation/evidence ledger | batch | `.planning/RELEASE-TRAIN.md` | role-match |
| `docs/maintainer-release.md` | documentation | request-response | same file | exact |

## Pattern Assignments

### Release auto-merge workflow

**Analog:** `.github/workflows/release-pr-automerge.yml` (tracked)

This is the implementation site and the closest possible pattern. The current flow checks the head's latest `ci-gate`, attempts a protected squash merge, then has a branch-protection bypass. Retain the current shell/GitHub CLI conventions and remove the bypass. Relevant excerpt (lines 134-169):

```yaml
latest_ci_gate() {
  gh api "repos/${REPOSITORY}/commits/${HEAD_SHA}/check-runs" \
    --jq '[.check_runs[] | select(.name == "ci-gate")] | sort_by(.started_at) | last | .conclusion // "missing"'
}

for attempt in $(seq 1 12); do
  conclusion=$(latest_ci_gate)
  if [ "$conclusion" != "success" ]; then
    echo "Latest ci-gate on $HEAD_SHA is $conclusion (attempt ${attempt}/12); waiting 30s..."
    sleep 30
    continue
  fi

  if gh pr merge "$pr_number" --squash -R "$REPOSITORY"; then
    merge_sha=$(gh pr view "$pr_number" --json mergeCommit -q '.mergeCommit.oid' -R "$REPOSITORY")
    echo "merge_sha=${merge_sha}" >> "$GITHUB_ENV"
    echo "merged=true" >> "$GITHUB_ENV"
    exit 0
  fi

  # Current lines 156-162 retry with --admin. Remove this retry. On normal
  # merge failure report head SHA and merge/check state, then fail closed.
done
```

The workflow already uses `GITHUB_ENV` outputs and explicit workflow dispatches after bot merges (lines 171-187); preserve those event semantics. Make any diagnostic attributable to the PR number and immutable head SHA. Do not claim a green result from a different head.

### Published-Hex Phoenix adoption fixture

**Analogs:** `test_apps/phoenix_adopter/mix.exs`; `test_apps/phoenix_adopter/test/core_flow_test.exs`; `.github/workflows/ci.yml`

The nested app is deliberately an isolated Phoenix host. Preserve a fast local path dependency for normal CI while creating a release-only dependency mode that fails if it resolves locally. Dependency excerpt (`mix.exs`, lines 18-25):

```elixir
defp deps do
  [
    {:lattice_stripe, path: "../../"},
    {:phoenix, "~> 1.8.0"},
    {:plug, "~> 1.16"},
    {:mox, "~> 1.2", only: :test}
  ]
end
```

Existing behavior tests use ExUnit, `Phoenix.ConnTest`, Mox, synthetic responses, and a fixed test endpoint (core_flow_test.exs lines 1-15). The checkout/webhook proof (lines 38-88) calls a real SDK route with an expected Mox transport response, then verifies typed result/event behavior. Keep this fixture credential-free and reuse it; don't add Phoenix or Mox to package runtime dependencies or create a second host app. The existing suite also explicitly asserts negative/tampered webhook behavior (lines 90-102), a good pattern for verifier failures.

CI currently runs `mix deps.get --check-locked` and `mix test --warnings-as-errors` in `test_apps/phoenix_adopter` (ci.yml lines 201-219). Keep the recurring path mode there. Run published-Hex mode at the release boundary unless research/planning justifies its recurring cost; assert resolved source and exact version from Mix metadata, use isolated dependency/lock state, and record SHA/version/checksum.

### Release evidence and closeout probes

**Analogs:** `scripts/maintainer/repo_hygiene_check.sh`; `.github/workflows/release.yml`; `.github/workflows/publish-hex.yml`

The shell hygiene checker is the closest utility pattern: strict Bash (`set -euo pipefail`), small named helpers, `record_result LEVEL label detail`, accumulated PASS/WARN/BLOCK counts, and nonzero exit for blockers. Its version comparison (lines 120-147) is a good shape for independent facts with actionable mismatch messages. Its working-tree baseline (lines 165-192) runs `git status --porcelain` and compares main divergence, but only for the current checkout; extend or add a focused read-only verifier to parse `git worktree list --porcelain -z`, visit every path, and run `git -C "$path" status --porcelain=v1 --untracked-files=all`. Avoid path splitting and mutations.

The routine release workflow already resolves a tag to an immutable SHA and waits for `ci-gate` on that SHA (`.github/workflows/release.yml` lines 215-250); publication checks out the Release Please tag and validates `RELEASE_VERSION` (`lines 334-383`). Manual recovery validates input ref, records resolved SHA, waits for its CI, checks package version, uses Hex dry-run/idempotency, and polls the public package API (`publish-hex.yml` lines 42-80, 145-232). Reuse these steps/conventions instead of a custom release parser or publishing client. A post-publish check should reconcile SHA, main, tag, GitHub Release, Hex version/checksum, versioned docs and a cold consumer install; docs-only recovery needs honest separate source-SHA provenance.

Suggested result shape:

```bash
record_result() {
  local level="$1" label="$2" detail="$3"
  RESULTS+=("[$level] $label: $detail")
  # Update PASS/WARN/BLOCK counters; unknown/auth/parse failures are blockers.
}
```

Use `curl -fsS` with bounded retries for registry/docs propagation; report the expected URL, version and SHA on failure. Checksum representation must be proven against Hex's actual public response and local artifact before locking a comparison.

### PR disposition ledger and maintainer guidance

**Analogs:** `.planning/RELEASE-TRAIN.md`; `docs/maintainer-release.md`

`RELEASE-TRAIN.md` uses dated headings, explicit immutable SHA/version references, evidence links, and a distinction between package tag provenance and docs-only provenance (lines 7-15, 31-45). Extend its current release truth only after live checks. Keep the per-open-PR dated disposition ledger phase-local or linked from that canonical file. Each entry should contain PR URL/number, contributor-visible timeline evidence, disposition, rationale/next action/date, required-check state and merge outcome. Do not treat a stale snapshot as fresh truth, and do not gate on zero open PR count where explicit deferral is allowed.

Maintainer instructions should follow the existing release guide's command-oriented, recovery-first style; document when to run routine release vs authenticated docs-only/manual recovery, what exact ref is checked, and how to interpret blockers. Keep details consumer/maintainer task-focused rather than exposing workflow internals unless needed to diagnose a failed gate.

## Shared Patterns

### Exact-SHA provenance

**Sources:** `.github/workflows/release.yml` lines 221-250; `.github/workflows/publish-hex.yml` lines 56-80. Pass one full resolved SHA through CI/release evidence. A run, tag, docs page, package version or PR head that merely looks recent is not evidence for another SHA.

### Fail-closed evidence and non-destructive checks

**Sources:** `scripts/maintainer/repo_hygiene_check.sh` lines 120-147, 250-264; `test_apps/phoenix_adopter/test/core_flow_test.exs` lines 90-102. Missing auth, API failures, parse errors, unknown checks, unresolved checks and dirty worktrees should be explicit blockers/unknowns. Status probes must not stash, clean, force-remove, or alter a contributor's worktree.

### Release user experience

**Sources:** `docs/maintainer-release.md`; `test_apps/phoenix_adopter/README.md` lines 1-24. Give maintainers clear commands, concise failure reasons and next actions. Keep the package adopter test synthetic and easy to run. There is no visual UI or design-system work in this headless library phase.

## No Analog Found

| File/capability | Role | Data Flow | Reason |
|-----------------|------|-----------|--------|
| New PR closeout checker/ledger completeness validator | utility | batch | No current checker validates every PR's contributor-visible disposition against a dated ledger. Use existing hygiene result style and GitHub CLI/API; do not invent a second general-purpose framework. |
| Published-Hex adopter mode | test/config | dependency resolution / batch | Current adopter is path-based only. Reuse its host and tests, but exact Hex-source enforcement is a new boundary. |

## Metadata

**Analog search scope:** `.github/workflows/`, `scripts/maintainer/`, `test_apps/phoenix_adopter/`, `docs/`, `.planning/RELEASE-TRAIN.md`.  
**Files scanned:** 9 primary tracked analogs/references.  
**Tracked-source check:** all named code analogs are tracked (`git ls-files` confirmed, including `publish-hex.yml`); no ignored capability mirror paths used.  
**Pattern extraction date:** 2026-09-24
