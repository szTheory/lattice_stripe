#!/usr/bin/env bash
set -euo pipefail

MODE="local"
RUN_MIX_CI=1
REMOTE="${LATTICE_STRIPE_HYGIENE_REMOTE:-origin}"
MAX_OPEN_DEPENDABOT_WARN=5

usage() {
  cat <<'EOF'
Usage: repo_hygiene_check.sh [--ci] [--skip-mix-ci]

Checks whether the repo is in a disciplined release-prep state.

Modes:
  --ci           Run only repo-owned drift checks that GitHub can prove.
  --skip-mix-ci  Skip the local mix ci contributor gate rerun.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --ci)
      MODE="ci"
      ;;
    --skip-mix-ci)
      RUN_MIX_CI=0
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "[BLOCK] git: required command is not installed" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

declare -a RESULTS=()
PASS_COUNT=0
WARN_COUNT=0
BLOCK_COUNT=0

record_result() {
  local level="$1"
  local label="$2"
  local detail="$3"

  RESULTS+=("[$level] $label: $detail")

  case "$level" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    BLOCK) BLOCK_COUNT=$((BLOCK_COUNT + 1)) ;;
  esac
}

have_gh() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

mix_version() {
  sed -nE 's/.*@version[[:space:]]+"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' mix.exs | head -n 1
}

manifest_version() {
  sed -nE 's/.*"\.":[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' .release-please-manifest.json | head -n 1
}

changelog_version() {
  sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -n 1
}

release_train_version() {
  sed -nE 's/^- Latest released version: `([0-9]+\.[0-9]+\.[0-9]+)`/\1/p' .planning/RELEASE-TRAIN.md | head -n 1
}

release_train_has_required_lines() {
  grep -Fq 'sustaining maintenance' .planning/RELEASE-TRAIN.md &&
    grep -Fq 'milestone: none' .planning/RELEASE-TRAIN.md &&
    grep -Fq 'Patch-eligible merged changes' .planning/RELEASE-TRAIN.md &&
    grep -Fq 'ci-gate' .planning/RELEASE-TRAIN.md
}

open_release_please_pr_bad_bump() {
  have_gh || return 1
  local current="$1"
  local major minor patch title pr_major pr_minor
  IFS=. read -r major minor patch <<<"$current"

  while IFS= read -r title; do
    [[ -z "$title" ]] && continue
    [[ "$title" =~ release[[:space:]]+([0-9]+)\.([0-9]+)\.([0-9]+) ]] || continue
    pr_major="${BASH_REMATCH[1]}"
    pr_minor="${BASH_REMATCH[2]}"
    if [[ "$pr_major" -gt "$major" ]] || [[ "$pr_major" -eq "$major" && "$pr_minor" -gt "$minor" ]]; then
      echo "$title"
      return 0
    fi
  done < <(gh pr list --state open --limit 30 --json title,labels \
    --jq '.[] | select([.labels[].name] | index("autorelease: pending")) | .title' 2>/dev/null)

  return 1
}

repo_owned_checks() {
  local mix_ver manifest_ver changelog_ver release_train_ver
  mix_ver="$(mix_version)"
  manifest_ver="$(manifest_version)"
  changelog_ver="$(changelog_version)"
  release_train_ver="$(release_train_version)"

  if [[ -n "$mix_ver" && "$mix_ver" == "$manifest_ver" && "$mix_ver" == "$changelog_ver" ]]; then
    record_result "PASS" "release versions" "mix.exs, manifest, and top changelog entry all point at $mix_ver"
  else
    record_result "BLOCK" "release versions" "mix.exs=$mix_ver manifest=$manifest_ver changelog=$changelog_ver"
  fi

  if [[ -n "$release_train_ver" && "$release_train_ver" == "$mix_ver" ]] && release_train_has_required_lines; then
    record_result "PASS" "release train ledger" "RELEASE-TRAIN.md matches $mix_ver and preserves the maintenance train contract"
  else
    record_result "BLOCK" "release train ledger" "RELEASE-TRAIN.md is missing, malformed, or out of sync with mix.exs=$mix_ver"
  fi

  if grep -Fq '"release-type": "elixir"' release-please-config.json &&
     grep -Fq '"include-v-in-tag": true' release-please-config.json; then
    record_result "PASS" "release-please config" "root Elixir package policy is intact"
  else
    record_result "BLOCK" "release-please config" "release-please-config.json drifted from maintained policy"
  fi

  if grep -Fq 'release-preflight' .github/workflows/release.yml &&
     grep -Fq 'googleapis/release-please-action' .github/workflows/release.yml &&
     grep -Fq 'ci-gate' .github/workflows/release.yml; then
    record_result "PASS" "release workflow" "release.yml includes preflight and ci-gate publish gate"
  else
    record_result "BLOCK" "release workflow" "release.yml no longer matches the trusted release lane"
  fi

  if grep -Fq './scripts/maintainer/repo_hygiene_check.sh' docs/maintainer-release.md &&
     grep -Fq 'ci-gate' docs/maintainer-release.md; then
    record_result "PASS" "maintainer docs" "maintainer-release.md points to hygiene and ci-gate"
  else
    record_result "BLOCK" "maintainer docs" "maintainer-release.md is missing required hygiene references"
  fi

  if grep -Fq 'needs:.*ci-gate' .github/workflows/ci.yml 2>/dev/null ||
     grep -Fq 'name: ci-gate' .github/workflows/ci.yml; then
    record_result "PASS" "ci-gate job" "ci.yml defines the required ci-gate terminal job"
  else
    record_result "BLOCK" "ci-gate job" "ci.yml is missing the ci-gate required lane"
  fi
}

local_checks() {
  local branch status_output
  branch="$(git rev-parse --abbrev-ref HEAD)"
  record_result "PASS" "current branch" "$branch"

  status_output="$(git status --porcelain)"
  if [[ -z "$status_output" ]]; then
    record_result "PASS" "working tree" "clean"
  else
    record_result "BLOCK" "working tree" "dirty state detected; commit, stash, or discard local changes first"
  fi

  git fetch "$REMOTE" --prune >/dev/null 2>&1 || true

  if git show-ref --verify --quiet "refs/heads/main" && git show-ref --verify --quiet "refs/remotes/$REMOTE/main"; then
    local ahead behind
    read -r behind ahead <<<"$(git rev-list --left-right --count "$REMOTE/main...main")"

    if [[ "$behind" == "0" && "$ahead" == "0" ]]; then
      record_result "PASS" "main divergence" "local main matches $REMOTE/main"
    elif [[ "$behind" != "0" ]]; then
      record_result "BLOCK" "main divergence" "local main is behind $REMOTE/main by $behind commit(s)"
    else
      record_result "WARN" "main divergence" "local main is ahead of $REMOTE/main by $ahead commit(s)"
    fi
  else
    record_result "WARN" "main divergence" "could not compare local main to $REMOTE/main"
  fi

  if have_gh; then
    local bad_rp dependabot_count latest_ci
    mix_ver="$(mix_version)"

    if bad_rp="$(open_release_please_pr_bad_bump "$mix_ver")"; then
      record_result "BLOCK" "release please PR" "open Release PR proposes unexpected minor/major: $bad_rp"
    else
      record_result "PASS" "release please PR" "no open Release Please PR with maintenance-incompatible bump"
    fi

    dependabot_count="$(gh pr list --state open --author 'app/dependabot' --json number --jq 'length' 2>/dev/null || echo 0)"
    if [[ "$dependabot_count" -le "$MAX_OPEN_DEPENDABOT_WARN" ]]; then
      record_result "PASS" "dependabot queue" "$dependabot_count open Dependabot PR(s)"
    else
      record_result "WARN" "dependabot queue" "$dependabot_count open Dependabot PRs (threshold $MAX_OPEN_DEPENDABOT_WARN)"
    fi

    latest_ci="$(gh run list --workflow ci.yml --branch main --limit 1 --json conclusion,status,url 2>/dev/null || true)"
    if [[ "$latest_ci" == *'"conclusion":"success"'* ]]; then
      record_result "PASS" "latest CI" "latest main CI workflow succeeded"
    elif [[ "$latest_ci" == *'"status":"in_progress"'* || "$latest_ci" == *'"status":"queued"'* ]]; then
      record_result "WARN" "latest CI" "main CI is still running"
    elif [[ -n "$latest_ci" && "$latest_ci" != "[]" ]]; then
      record_result "BLOCK" "latest CI" "latest main CI workflow is not green (check ci-gate)"
    else
      record_result "WARN" "latest CI" "could not read recent main CI history"
    fi
  else
    record_result "WARN" "GitHub checks" "gh unavailable or unauthenticated; skipped PR and CI checks"
  fi

  if git tag -l 'v1.8' 'v1.9' 'v1.8.*' 'v1.9.*' 2>/dev/null | grep -q .; then
    record_result "WARN" "milestone tags" "local v1.8/v1.9 tags exist; remove or document before release prep"
  else
    record_result "PASS" "milestone tags" "no stray v1.8/v1.9 tags locally"
  fi

  if [[ "$RUN_MIX_CI" == "1" ]] && command -v mix >/dev/null 2>&1; then
    if mix ci >/dev/null; then
      record_result "PASS" "mix ci" "local contributor gate passed"
    else
      record_result "BLOCK" "mix ci" "local contributor gate failed"
    fi
  elif [[ "$RUN_MIX_CI" == "0" ]]; then
    record_result "WARN" "mix ci" "skipped by flag"
  else
    record_result "WARN" "mix ci" "mix not available; skipped"
  fi
}

repo_owned_checks

if [[ "$MODE" != "ci" ]]; then
  local_checks
fi

printf 'LatticeStripe repo hygiene report (%s)\n' "$MODE"
printf '%s\n' "${RESULTS[@]}"
printf 'Summary: %s PASS, %s WARN, %s BLOCK\n' "$PASS_COUNT" "$WARN_COUNT" "$BLOCK_COUNT"

if [[ "$BLOCK_COUNT" -gt 0 ]]; then
  echo "Result: not ready"
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "Result: proceed with caution"
  exit 0
fi

echo "Result: safe to start release prep"
