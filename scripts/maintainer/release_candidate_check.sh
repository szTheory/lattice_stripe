#!/usr/bin/env bash
# Validate the current Release Please proposal against the reviewed 2.3.0 API delta.
set -euo pipefail

ROOT=${RELEASE_CANDIDATE_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
cd "$ROOT"

fail() {
  printf 'BLOCK: %s\n' "$*" >&2
  exit 1
}

for command in git gh jq; do
  command -v "$command" >/dev/null 2>&1 || fail "Required command is unavailable: $command"
done

BASE_REF=${RELEASE_CANDIDATE_BASE_REF:-v2.2.2}
EXPECTED_VERSION=${RELEASE_CANDIDATE_VERSION:-2.3.0}
EXPECTED_HEAD=${RELEASE_CANDIDATE_EXPECTED_HEAD:-}
REPOSITORY=${GH_REPO:-}

if [ -z "$REPOSITORY" ]; then
  REPOSITORY=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) ||
    fail 'Cannot resolve GitHub repository; authenticate gh and run from a GitHub checkout.'
fi

git rev-parse --verify "${BASE_REF}^{commit}" >/dev/null 2>&1 ||
  fail "Compatibility baseline $BASE_REF is not available locally. Fetch the release tag and retry."
trusted_branch=${RELEASE_CANDIDATE_TRUSTED_BRANCH:-main}
current_branch=$(git branch --show-current)
[ "$current_branch" = "$trusted_branch" ] ||
  fail "Candidate preflight must run from trusted branch $trusted_branch (currently ${current_branch:-detached})."

baseline=$(git show "${BASE_REF}:priv/api/current.txt") || fail "Cannot read API lock at $BASE_REF."
current=$(cat priv/api/current.txt) || fail 'Cannot read current API lock.'
removed=$(comm -23 <(printf '%s\n' "$baseline" | LC_ALL=C sort) <(printf '%s\n' "$current" | LC_ALL=C sort))
added=$(comm -13 <(printf '%s\n' "$baseline" | LC_ALL=C sort) <(printf '%s\n' "$current" | LC_ALL=C sort))
expected_added=$(printf '%s\n' \
  'LatticeStripe.Invoice field amount_paid_off_stripe' \
  'LatticeStripe.Refund field customer' \
  'LatticeStripe.Refund field customer_account' \
  'LatticeStripe.Refund field payment_method' | LC_ALL=C sort)

if [ -n "$removed" ]; then
  fail "Breaking API lock removals since $BASE_REF:\n$removed"
fi
if [ "$added" != "$expected_added" ]; then
  fail "API lock additions since $BASE_REF differ from the four reviewed fields. Expected:\n$expected_added\nFound:\n${added:-<none>}"
fi

api_version=$(sed -n 's/^[[:space:]]*@stripe_api_version[[:space:]]*"\([^"]*\)".*/\1/p' lib/lattice_stripe.ex | head -1)
[ "$api_version" = '2026-03-25.dahlia' ] ||
  fail "Default Stripe API version changed: expected 2026-03-25.dahlia, found ${api_version:-<missing>}"

prs=$(gh pr list --state open --head release-please--branches--main \
  --label 'autorelease: pending' --json number,title,headRefOid,url -R "$REPOSITORY") ||
  fail 'Could not list the open Release Please PR. Check GitHub authentication and permissions.'
count=$(jq 'length' <<<"$prs")
[ "$count" -eq 1 ] || fail "Expected one open Release Please PR; found $count."

pr_number=$(jq -r '.[0].number' <<<"$prs")
pr_title=$(jq -r '.[0].title' <<<"$prs")
pr_head=$(jq -r '.[0].headRefOid' <<<"$prs")
pr_url=$(jq -r '.[0].url' <<<"$prs")
[[ "$pr_title" =~ ^chore\(main\):\ release\  ]] || fail "PR #$pr_number has an unexpected title: $pr_title"
[ -n "$pr_head" ] && [ "$pr_head" != null ] || fail "PR #$pr_number has no head SHA."
[ -z "$EXPECTED_HEAD" ] || [ "$EXPECTED_HEAD" = "$pr_head" ] ||
  fail "Stale Release Please event: expected PR head $EXPECTED_HEAD, current head is $pr_head ($pr_url)."

current_pr=$(gh pr view "$pr_number" --json state,headRefOid -R "$REPOSITORY") ||
  fail "Could not re-read Release Please PR #$pr_number."
current_state=$(jq -r '.state' <<<"$current_pr")
current_head=$(jq -r '.headRefOid' <<<"$current_pr")
[ "$current_state" = OPEN ] || fail "Release Please PR #$pr_number is no longer open (state: $current_state)."
[ "$current_head" = "$pr_head" ] ||
  fail "Stale Release Please PR head: list returned $pr_head but current PR head is $current_head."

proposal_file() {
  local path=$1 encoded
  encoded=$(gh api "repos/$REPOSITORY/contents/$path?ref=$pr_head" --jq .content) ||
    fail "Cannot read proposed $path from PR head $pr_head."
  if base64 --decode >/dev/null 2>&1 <<<""; then
    printf '%s' "$encoded" | base64 --decode
  else
    printf '%s' "$encoded" | base64 -D
  fi
}

proposal_mix=$(proposal_file mix.exs)
proposal_manifest=$(proposal_file .release-please-manifest.json)
proposal_changelog=$(proposal_file CHANGELOG.md)
proposal_source=$(proposal_file lib/lattice_stripe.ex)
mix_version=$(sed -n 's/^[[:space:]]*@version[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$proposal_mix" | head -1)
manifest_version=$(jq -r 'to_entries[] | select(.key == "." or .key == "lattice_stripe") | .value' <<<"$proposal_manifest" | head -1)
changelog_version=$(sed -n 's/^## \[\([^]]*\)\].*/\1/p' <<<"$proposal_changelog" | head -1)
proposal_api_version=$(sed -n 's/^[[:space:]]*@stripe_api_version[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$proposal_source" | head -1)

for entry in "mix.exs:$mix_version" "manifest:$manifest_version" "CHANGELOG.md:$changelog_version"; do
  file=${entry%%:*}
  version=${entry#*:}
  [ "$version" = "$EXPECTED_VERSION" ] ||
    fail "PR #$pr_number proposal $file version is ${version:-<missing>}; expected $EXPECTED_VERSION."
done
[ "$proposal_api_version" = '2026-03-25.dahlia' ] ||
  fail "PR #$pr_number changes the default Stripe API version to ${proposal_api_version:-<missing>}."

printf 'PASS: Release Please PR #%s proposes %s with the reviewed additive API delta and unchanged Stripe API default.\n' \
  "$pr_number" "$EXPECTED_VERSION"
printf 'PR: %s\nHead: %s\nBaseline: %s\n' "$pr_url" "$pr_head" "$BASE_REF"
