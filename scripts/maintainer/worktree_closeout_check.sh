#!/usr/bin/env bash
set -euo pipefail

REMOTE="${WORKTREE_CLOSEOUT_REMOTE:-origin}"
OWNERS_FILE=""
FINAL=0
EXPECTED_MAIN_SHA=""
GIT_BIN="${WORKTREE_CLOSEOUT_GIT:-git}"

usage() {
  cat <<'USAGE'
Usage: worktree_closeout_check.sh --owners <json-file> [--final --expected-main-sha <full-sha>]

Read-only inventory of the primary checkout and every linked Git worktree.
The owner file must contain {"owners":{"<absolute-worktree-path>":"<owner>"}}.
In --final mode local main and REMOTE/main must equal the expected current main SHA.
Release artifact identity is checked separately by release_evidence_check.sh.
Fetch REMOTE first; this script never fetches or changes Git state.
USAGE
}

while (($#)); do
  case "$1" in
    --owners) (($# >= 2)) || { usage >&2; exit 2; }; OWNERS_FILE="$2"; shift 2 ;;
    --final) FINAL=1; shift ;;
    --expected-main-sha) (($# >= 2)) || { usage >&2; exit 2; }; EXPECTED_MAIN_SHA="$2"; shift 2 ;;
    --remote) (($# >= 2)) || { usage >&2; exit 2; }; REMOTE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[BLOCK] unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

BLOCKS=0
block() { printf '[BLOCK] %s\n' "$1"; BLOCKS=$((BLOCKS + 1)); }
pass() { printf '[PASS] %s\n' "$1"; }

if [[ -z "$OWNERS_FILE" || ! -f "$OWNERS_FILE" ]]; then
  block "owner mapping is required and must exist (--owners <json-file>)"
  exit 1
fi
if ! jq -e '.owners | type == "object"' "$OWNERS_FILE" >/dev/null 2>&1; then
  block "owner mapping must be valid JSON with an owners object"
  exit 1
fi
if (( FINAL )) && [[ ! "$EXPECTED_MAIN_SHA" =~ ^[0-9a-fA-F]{40}$ ]]; then
  block "--final requires --expected-main-sha with a full 40-character commit SHA"
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/worktree-closeout.XXXXXX")" || {
  block "could not create temporary status capture directory"
  exit 1
}
trap 'rm -rf "$TMP_DIR"' EXIT

INVENTORY_FILE="$TMP_DIR/inventory"
if ! "$GIT_BIN" worktree list --porcelain -z >"$INVENTORY_FILE" 2>"$TMP_DIR/inventory.err"; then
  block "git worktree inventory failed: $(<"$TMP_DIR/inventory.err")"
  exit 1
fi

declare -a PATHS=() SHAS=() BRANCHES=() DETACHED=() LOCKED=()
REC_PATH="" REC_SHA="" REC_BRANCH="" REC_DETACHED=0 REC_LOCKED=0
flush_record() {
  [[ -z "$REC_PATH" ]] && return 0
  PATHS+=("$REC_PATH") SHAS+=("$REC_SHA") BRANCHES+=("$REC_BRANCH")
  DETACHED+=("$REC_DETACHED") LOCKED+=("$REC_LOCKED")
  REC_PATH="" REC_SHA="" REC_BRANCH="" REC_DETACHED=0 REC_LOCKED=0
}
while IFS= read -r -d '' FIELD; do
  if [[ -z "$FIELD" ]]; then
    flush_record
  elif [[ "$FIELD" == worktree\ * ]]; then
    flush_record
    REC_PATH="${FIELD#worktree }"
  elif [[ "$FIELD" == HEAD\ * ]]; then
    REC_SHA="${FIELD#HEAD }"
  elif [[ "$FIELD" == branch\ * ]]; then
    REC_BRANCH="${FIELD#branch refs/heads/}"
  elif [[ "$FIELD" == detached ]]; then
    REC_DETACHED=1
  elif [[ "$FIELD" == locked* ]]; then
    REC_LOCKED=1
  fi
done <"$INVENTORY_FILE"
flush_record

if ((${#PATHS[@]} == 0)); then
  block "Git returned an empty or malformed worktree inventory"
  exit 1
fi

COMMON_GIT_DIR="$($GIT_BIN rev-parse --path-format=absolute --git-common-dir 2>"$TMP_DIR/root.err" || true)"
PRIMARY="${COMMON_GIT_DIR%/.git}"
if [[ -z "$COMMON_GIT_DIR" || "$PRIMARY" == "$COMMON_GIT_DIR" ]]; then
  block "could not identify primary checkout from Git common directory: $(<"$TMP_DIR/root.err")"
  exit 1
fi
PRIMARY_COUNT=0
for i in "${!PATHS[@]}"; do
  [[ "${PATHS[$i]}" == "$PRIMARY" ]] && PRIMARY_COUNT=$((PRIMARY_COUNT + 1))
done
if (( PRIMARY_COUNT != 1 )); then
  block "primary checkout $PRIMARY was not present exactly once in worktree inventory"
fi

printf 'Worktree inventory (%d path(s))\n' "${#PATHS[@]}"
for i in "${!PATHS[@]}"; do
  path="${PATHS[$i]}"; sha="${SHAS[$i]}"; branch="${BRANCHES[$i]}"
  label="$(printf '%q' "$path")"
  [[ -n "$branch" ]] || branch="(detached)"
  owner="$(jq -r --arg path "$path" '.owners[$path] // empty' "$OWNERS_FILE")"
  if [[ "$path" == "$PRIMARY" ]]; then
    [[ -n "$owner" ]] && block "primary checkout must not use a linked-worktree owner entry: $label" || true
    printf '  primary path=%s branch=%s sha=%s\n' "$label" "$branch" "${sha:-unknown}"
  else
    printf '  linked path=%s branch=%s sha=%s detached=%s locked=%s owner=%s\n' \
      "$label" "$branch" "${sha:-unknown}" "${DETACHED[$i]}" "${LOCKED[$i]}" "${owner:-MISSING}"
    [[ -n "$owner" ]] || block "linked worktree has no owner association: $label"
  fi
  if [[ -z "$sha" ]]; then
    block "inventory omitted HEAD for $label"
  fi
  status_file="$TMP_DIR/status-$i"
  status_err="$TMP_DIR/status-$i.err"
  if ! "$GIT_BIN" -C "$path" status --porcelain=v1 -z --untracked-files=all >"$status_file" 2>"$status_err"; then
    block "status inspection failed for $label: $(<"$status_err")"
    continue
  fi
  if [[ -s "$status_file" ]]; then
    block "dirty worktree $label; porcelain entries follow"
    while IFS= read -r -d '' entry; do printf '    entry=%q\n' "$entry"; done <"$status_file"
  else
    pass "clean worktree $label"
  fi
done

if (( FINAL )); then
  primary_index=-1
  for i in "${!PATHS[@]}"; do [[ "${PATHS[$i]}" == "$PRIMARY" ]] && primary_index=$i; done
  if (( primary_index < 0 )); then
    block "cannot evaluate final release state without primary inventory record"
  else
    primary_branch="${BRANCHES[$primary_index]}"
    primary_sha="${SHAS[$primary_index]}"
    [[ "$primary_branch" == main ]] || block "primary checkout branch is '$primary_branch', expected main"
    [[ "$primary_sha" == "$EXPECTED_MAIN_SHA" ]] || block "primary HEAD $primary_sha does not equal expected main SHA $EXPECTED_MAIN_SHA"
    if ! REMOTE_SHA="$("$GIT_BIN" rev-parse --verify "refs/remotes/$REMOTE/main^{commit}" 2>"$TMP_DIR/remote.err")"; then
      block "could not read freshly fetched $REMOTE/main: $(<"$TMP_DIR/remote.err")"
    elif [[ "$REMOTE_SHA" != "$EXPECTED_MAIN_SHA" ]]; then
      block "$REMOTE/main $REMOTE_SHA does not equal expected main SHA $EXPECTED_MAIN_SHA"
    else
      pass "primary main and $REMOTE/main both equal expected main SHA $EXPECTED_MAIN_SHA"
    fi
  fi
fi

if (( BLOCKS > 0 )); then
  printf 'Result: BLOCKED (%d blocker(s)); no Git tree was modified.\n' "$BLOCKS"
  exit 1
fi
printf 'Result: PASS; inventory was read-only.\n'
