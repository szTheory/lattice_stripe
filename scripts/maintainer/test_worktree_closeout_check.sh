#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECKER="$ROOT/scripts/maintainer/worktree_closeout_check.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/worktree-closeout-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PRIMARY="$TMP/primary checkout"
LINKED="$TMP/linked checkout with spaces"
RELEASE_SHA=0123456789abcdef0123456789abcdef01234567
MODE=clean
mkdir -p "$TMP/bin"
cat >"$TMP/bin/git" <<'MOCK_GIT'
#!/usr/bin/env bash
set -eu
case "$1" in
  worktree)
    [[ "${MODE:-clean}" != inventory_fail ]] || { echo 'synthetic inventory error' >&2; exit 19; }
    [[ "${MODE:-clean}" != omit_primary ]] || { printf 'worktree %s\0HEAD %s\0branch refs/heads/main\0\0' "$LINKED" "$RELEASE_SHA"; exit 0; }
    if [[ "${MODE:-clean}" == wrong_branch ]]; then
      printf 'worktree %s\0HEAD %s\0branch refs/heads/feature\0\0' "$PRIMARY" "$RELEASE_SHA"
    elif [[ "${MODE:-clean}" == wrong_release ]]; then
      printf 'worktree %s\0HEAD ffffffffffffffffffffffffffffffffffffffff\0branch refs/heads/main\0\0' "$PRIMARY"
    else
      printf 'worktree %s\0HEAD %s\0branch refs/heads/main\0\0' "$PRIMARY" "$RELEASE_SHA"
    fi
    if [[ "${MODE:-clean}" != omit_link ]]; then
      printf 'worktree %s\0HEAD %s\0branch refs/heads/agent-owner\0locked maintenance\0\0' "$LINKED" "$RELEASE_SHA"
    fi
    ;;
  rev-parse)
    if [[ "$2" == --path-format=absolute && "$3" == --git-common-dir ]]; then printf '%s/.git\n' "$PRIMARY"
    elif [[ "$2" == --verify ]]; then
      [[ "${MODE:-clean}" != remote_fail ]] || { echo 'synthetic missing remote ref' >&2; exit 20; }
      printf '%s\n' "${REMOTE_SHA:-$RELEASE_SHA}"
    else exit 2; fi
    ;;
  -C)
    path="$2"; shift 2
    [[ "$1" == status ]] || exit 2
    if [[ "$path" == "$LINKED" && "${MODE:-clean}" == status_fail ]]; then echo 'synthetic status failure' >&2; exit 21; fi
    if [[ "$path" == "$LINKED" && "${MODE:-clean}" == tracked_dirty ]]; then printf ' M tracked.ex\0'; fi
    if [[ "$path" == "$LINKED" && "${MODE:-clean}" == untracked_dirty ]]; then printf '?? new file.ex\0'; fi
    ;;
  *) exit 2 ;;
esac
MOCK_GIT
chmod +x "$TMP/bin/git"

write_owners() {
  local include_link="${1:-yes}"
  if [[ "$include_link" == yes ]]; then
    jq -n --arg path "$LINKED" '{owners:{($path):"fixture owner"}}' >"$TMP/owners.json"
  else jq -n '{owners:{}}' >"$TMP/owners.json"; fi
}
run() {
  env PATH="$TMP/bin:$PATH" WORKTREE_CLOSEOUT_GIT="$TMP/bin/git" \
    PRIMARY="$PRIMARY" LINKED="$LINKED" RELEASE_SHA="$RELEASE_SHA" \
    MODE="$MODE" REMOTE_SHA="${REMOTE_SHA:-$RELEASE_SHA}" \
    bash "$CHECKER" --owners "$TMP/owners.json" "$@"
}
expect_pass() {
  local name="$1"; shift
  if ! run "$@" >"$TMP/output" 2>&1; then cat "$TMP/output"; echo "FAIL: $name unexpectedly blocked" >&2; exit 1; fi
  echo "PASS: $name"
}
expect_block() {
  local name="$1" expected="$2"; shift 2
  if run "$@" >"$TMP/output" 2>&1; then cat "$TMP/output"; echo "FAIL: $name unexpectedly passed" >&2; exit 1; fi
  if ! grep -Fq "$expected" "$TMP/output"; then cat "$TMP/output"; echo "FAIL: $name missing blocker '$expected'" >&2; exit 1; fi
  echo "PASS: $name"
}

write_owners
MODE=clean
expect_pass "clean inventory" --final --release-sha "$RELEASE_SHA"
grep -Fq "linked path=$(printf '%q' "$LINKED")" "$TMP/output" || { echo 'FAIL: path with spaces was not reported safely'; exit 1; }
grep -Fq 'locked=1' "$TMP/output" || { echo 'FAIL: locked worktree metadata was not reported'; exit 1; }

MODE=tracked_dirty
expect_block "tracked dirty worktree" "dirty worktree" --final --release-sha "$RELEASE_SHA"
grep -Fq 'tracked.ex' "$TMP/output" || { echo 'FAIL: tracked status entry missing'; exit 1; }
MODE=untracked_dirty
expect_block "untracked worktree file" "dirty worktree" --final --release-sha "$RELEASE_SHA"
grep -Fq 'new' "$TMP/output" || { echo 'FAIL: untracked status entry missing'; exit 1; }

MODE=clean
write_owners no
expect_block "missing linked owner" "no owner association" --final --release-sha "$RELEASE_SHA"
write_owners
MODE=status_fail
expect_block "uninspectable worktree" "status inspection failed" --final --release-sha "$RELEASE_SHA"
MODE=inventory_fail
expect_block "inventory command failure" "synthetic inventory error" --final --release-sha "$RELEASE_SHA"
MODE=omit_primary
expect_block "missing primary inventory record" "not present exactly once" --final --release-sha "$RELEASE_SHA"
MODE=clean
REMOTE_SHA=ffffffffffffffffffffffffffffffffffffffff
expect_block "release main mismatch" "does not equal release SHA" --final --release-sha "$RELEASE_SHA"
REMOTE_SHA="$RELEASE_SHA"
MODE=wrong_branch
expect_block "primary branch mismatch" "expected main" --final --release-sha "$RELEASE_SHA"
MODE=wrong_release
expect_block "primary release SHA mismatch" "does not equal release SHA" --final --release-sha "$RELEASE_SHA"
MODE=remote_fail
expect_block "missing fetched remote ref" "synthetic missing remote ref" --final --release-sha "$RELEASE_SHA"

DOC="$ROOT/docs/maintainer-release.md"
grep -Fq "bash scripts/maintainer/worktree_closeout_check.sh --owners .planning/phases/78-release-and-repository-closeout/78-WORKTREE-OWNERS.json --final --release-sha \"\$RELEASE_SHA\"" "$DOC" || {
  echo 'FAIL: maintainer docs command does not match checker interface' >&2; exit 1;
}
grep -Fq '"owners"' "$DOC" || { echo 'FAIL: maintainer docs omit owner mapping format'; exit 1; }
echo 'PASS: documented invocation and owner mapping'
