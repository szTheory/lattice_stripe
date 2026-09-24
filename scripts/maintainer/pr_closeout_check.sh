#!/usr/bin/env bash
set -euo pipefail

LEDGER=""
REPOSITORY=""
INVENTORY_FILE=""
TIMELINE_DIR=""

usage() {
  cat <<'USAGE'
Usage: pr_closeout_check.sh --ledger FILE [--repo OWNER/REPO]
       [--inventory-file FILE --timeline-dir DIR]

Read-only check that every currently open PR has one matching dated ledger
record and contributor-visible timeline evidence. Test inputs can replace the
GitHub inventory and timeline API responses.
USAGE
}

while (($#)); do
  case "$1" in
    --ledger) LEDGER="${2:?missing ledger path}"; shift 2 ;;
    --repo) REPOSITORY="${2:?missing repository}"; shift 2 ;;
    --inventory-file) INVENTORY_FILE="${2:?missing inventory file}"; shift 2 ;;
    --timeline-dir) TIMELINE_DIR="${2:?missing timeline directory}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$LEDGER" ]]; then
  echo "[BLOCK] --ledger is required" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[BLOCK] jq is required" >&2
  exit 2
fi
if ! jq -e 'type == "object" and (.entries | type == "array")' "$LEDGER" >/dev/null 2>&1; then
  echo "[BLOCK] malformed ledger JSON or missing entries array: $LEDGER" >&2
  exit 2
fi

if [[ -n "$INVENTORY_FILE" ]]; then
  INVENTORY="$INVENTORY_FILE"
else
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "[BLOCK] GitHub CLI is unavailable or unauthenticated; open-PR inventory is unknown" >&2
    exit 2
  fi
  if [[ -z "$REPOSITORY" ]]; then
    REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || {
      echo "[BLOCK] could not resolve the GitHub repository" >&2
      exit 2
    }
  fi
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  INVENTORY="$TEMP_DIR/open-prs.json"
  if ! gh pr list --repo "$REPOSITORY" --state open --limit 1000 \
    --json number,url,headRefOid,statusCheckRollup >"$INVENTORY"; then
    echo "[BLOCK] failed to fetch the complete open-PR inventory" >&2
    exit 2
  fi
fi

if ! jq -e 'type == "array" and all(.[]; (.number | type == "number") and (.url | type == "string") and (.headRefOid | type == "string"))' "$INVENTORY" >/dev/null 2>&1; then
  echo "[BLOCK] malformed open-PR inventory" >&2
  exit 2
fi
if [[ -n "$REPOSITORY" ]]; then
  REPO_PATH="$REPOSITORY"
else
  REPO_PATH="$(jq -r '.[0].url // empty | sub("^https://github.com/"; "") | split("/pull/")[0]' "$INVENTORY")"
fi

BLOCKS=0
block() {
  printf '[BLOCK] %s\n' "$1"
  BLOCKS=$((BLOCKS + 1))
}

if [[ -z "$(jq -r '.generated_at // empty' "$LEDGER")" ]]; then
  block "ledger generated_at is missing"
fi

dupes="$(jq -r '[.entries[].pr_number] | group_by(.)[] | select(length > 1) | .[0]' "$LEDGER")"
while IFS= read -r number; do
  [[ -z "$number" ]] || block "PR #$number has duplicate ledger entries"
done <<<"$dupes"

while IFS= read -r pr; do
  number="$(jq -r '.number' <<<"$pr")"
  url="$(jq -r '.url' <<<"$pr")"
  head="$(jq -r '.headRefOid' <<<"$pr")"
  entry="$(jq -c --argjson number "$number" '[.entries[] | select(.pr_number == $number)]' "$LEDGER")"
  count="$(jq 'length' <<<"$entry")"
  if [[ "$count" == 0 ]]; then
    block "PR #$number has no ledger entry"
    continue
  fi
  if [[ "$count" != 1 ]]; then
    continue
  fi
  item="$(jq -c '.[0]' <<<"$entry")"
  [[ "$(jq -r '.pr_url // empty' <<<"$item")" == "$url" ]] || block "PR #$number pr_url does not match the current inventory"
  [[ "$(jq -r '.head_sha // empty' <<<"$item")" == "$head" ]] || block "PR #$number ledger head_sha is stale"
  disposition="$(jq -r '.disposition // empty' <<<"$item")"
  case "$disposition" in
    merge|request_changes|defer|close) ;;
    *) block "PR #$number has missing or unrecognized disposition '$disposition'" ;;
  esac
  [[ -n "$(jq -r '.rationale // empty' <<<"$item")" ]] || block "PR #$number rationale is missing"
  if [[ "$disposition" == defer ]]; then
    [[ -n "$(jq -r '.next_action // empty' <<<"$item")" ]] || block "PR #$number deferred disposition lacks next_action"
    [[ "$(jq -r '.next_action_date // empty' <<<"$item")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || block "PR #$number deferred disposition lacks a YYYY-MM-DD next_action_date"
  fi
  check_head="$(jq -r '.required_checks.head_sha // empty' <<<"$item")"
  [[ "$check_head" == "$head" ]] || block "PR #$number required_checks.head_sha is missing or stale"
  if [[ "$disposition" == merge ]]; then
    [[ "$(jq -r '.required_checks.state // empty' <<<"$item")" == success ]] || block "PR #$number merge disposition lacks successful required checks"
    [[ "$(jq -r '.required_checks.ci_gate // empty' <<<"$item")" == success ]] || block "PR #$number merge disposition lacks successful ci-gate"
  fi

  timeline_url="$(jq -r '.timeline.url // empty' <<<"$item")"
  decision_text="$(jq -r '.timeline.decision_text // empty' <<<"$item")"
  if [[ -z "$timeline_url" || -z "$decision_text" ]]; then
    block "PR #$number contributor-visible timeline URL or decision_text is missing"
    continue
  fi
  expected_prefix="https://github.com/${REPO_PATH}/pull/${number}#"
  [[ "$timeline_url" == "$expected_prefix"* ]] || {
    block "PR #$number timeline URL does not belong to this PR"
    continue
  }

  if [[ -n "$TIMELINE_DIR" ]]; then
    timeline_file="$TIMELINE_DIR/$number.json"
    if [[ ! -f "$timeline_file" ]] || ! jq -e 'type == "array"' "$timeline_file" >/dev/null 2>&1; then
      block "PR #$number timeline fixture is missing or malformed"
      continue
    fi
    timeline_match="$(jq -r --arg url "$timeline_url" --arg decision "$decision_text" \
      '[.[] | select((.html_url == $url) and ((.body // "") | ascii_downcase | contains($decision | ascii_downcase)))] | length' "$timeline_file")"
  elif [[ -n "$INVENTORY_FILE" ]]; then
    block "PR #$number timeline cannot be verified without --timeline-dir"
    continue
  else
    if ! gh api --paginate "repos/${REPOSITORY}/issues/${number}/comments" >"$TEMP_DIR/comments-$number.json" 2>/dev/null ||
       ! gh api --paginate "repos/${REPOSITORY}/pulls/${number}/reviews" >"$TEMP_DIR/reviews-$number.json" 2>/dev/null; then
      block "PR #$number timeline API request failed"
      continue
    fi
    # gh --paginate emits one JSON page per line; normalize both feeds to arrays.
    jq -s 'add' "$TEMP_DIR/comments-$number.json" >"$TEMP_DIR/comments-flat-$number.json" 2>/dev/null || {
      block "PR #$number comments response is malformed"
      continue
    }
    jq -s 'add' "$TEMP_DIR/reviews-$number.json" >"$TEMP_DIR/reviews-flat-$number.json" 2>/dev/null || {
      block "PR #$number reviews response is malformed"
      continue
    }
    timeline_match="$(jq -s 'add' "$TEMP_DIR/comments-flat-$number.json" "$TEMP_DIR/reviews-flat-$number.json" |
      jq -r --arg url "$timeline_url" --arg decision "$decision_text" \
        '[.[] | select(((.html_url // "") == $url) and ((.body // "") | ascii_downcase | contains($decision | ascii_downcase)))] | length')"
  fi
  [[ "$timeline_match" -gt 0 ]] || block "PR #$number timeline URL does not resolve to a same-PR comment/review carrying the recorded decision"
done < <(jq -c '.[]' "$INVENTORY")

for number in $(jq -r '.entries[].pr_number' "$LEDGER" | sort -n -u); do
  if ! jq -e --argjson number "$number" 'any(.[]; .number == $number)' "$INVENTORY" >/dev/null; then
    block "ledger PR #$number is not in the current open-PR inventory"
  fi
done

if ((BLOCKS)); then
  printf 'Result: blocked (%s issue(s))\n' "$BLOCKS"
  exit 1
fi
echo "Result: all open PRs have current disposition evidence"
