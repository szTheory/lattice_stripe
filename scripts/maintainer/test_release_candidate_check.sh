#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CHECKER="$ROOT/scripts/maintainer/release_candidate_check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo/priv/api" "$repo/lib" "$tmp/bin" "$tmp/proposal/lib"
git -C "$repo" init -q -b main
git -C "$repo" config user.name 'Release Candidate Test'
git -C "$repo" config user.email test@example.invalid

cat > "$repo/priv/api/current.txt" <<'EOF'
LatticeStripe.Invoice field amount_paid
LatticeStripe.Refund field currency
EOF
cat > "$repo/lib/lattice_stripe.ex" <<'EOF'
@stripe_api_version "2026-03-25.dahlia"
EOF
git -C "$repo" add .
git -C "$repo" commit -qm baseline
git -C "$repo" tag v2.2.2
cat >> "$repo/priv/api/current.txt" <<'EOF'
LatticeStripe.Invoice field amount_paid_off_stripe
LatticeStripe.Refund field customer
LatticeStripe.Refund field customer_account
LatticeStripe.Refund field payment_method
EOF
git -C "$repo" add .
git -C "$repo" commit -qm 'add reviewed optional fields'

cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 ${2:-}" in
  'repo view') printf '{"nameWithOwner":"example/lattice_stripe"}\n' ;;
  'pr list')
    case "${GH_FIXTURE:-valid}" in
      absent) printf '[]\n' ;;
      *) printf '[{"number":42,"title":"chore(main): release 2.3.0","headRefOid":"%s","url":"https://github.com/example/lattice_stripe/pull/42"}]\n' "${GH_LIST_HEAD:-candidate-sha}" ;;
    esac
    ;;
  'pr view')
    printf '{"state":"OPEN","headRefOid":"%s"}\n' "${GH_VIEW_HEAD:-candidate-sha}"
    ;;
  api\ *)
    path=${2#repos/example/lattice_stripe/contents/}
    path=${path%%\?*}
    file="$PROPOSAL_DIR/$path"
    [ -f "$file" ] || exit 1
    base64 < "$file" | tr -d '\n'
    ;;
  *) printf 'unexpected gh invocation: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
chmod +x "$tmp/bin/gh"

cat > "$tmp/proposal/mix.exs" <<'EOF'
@version "2.3.0"
EOF
cat > "$tmp/proposal/.release-please-manifest.json" <<'EOF'
{".": "2.3.0"}
EOF
cat > "$tmp/proposal/CHANGELOG.md" <<'EOF'
## [2.3.0] (2026-09-24)
EOF
cat > "$tmp/proposal/lib/lattice_stripe.ex" <<'EOF'
@stripe_api_version "2026-03-25.dahlia"
EOF

run_check() {
  (cd "$repo" && PATH="$tmp/bin:$PATH" PROPOSAL_DIR="$tmp/proposal" GH_REPO=example/lattice_stripe RELEASE_CANDIDATE_REPO_ROOT="$repo" "$CHECKER" "$@")
}
expect_block() {
  local expected=$1 output status=0
  output=$(run_check "$@" 2>&1) || status=$?
  if [ "$status" -eq 0 ] || ! grep -Fq "$expected" <<<"$output"; then
    printf 'FAIL: expected blocker containing %s (status=%s)\n%s\n' "$expected" "$status" "$output" >&2
    exit 1
  fi
  printf 'PASS: rejected fixture: %s\n' "$expected"
}

output=$(run_check "$@")
grep -Fq 'proposes 2.3.0' <<<"$output" || { printf 'FAIL: valid candidate rejected\n%s\n' "$output" >&2; exit 1; }
printf 'PASS: accepted valid additive 2.3.0 candidate\n'

awk '$0 != "LatticeStripe.Invoice field amount_paid"' "$repo/priv/api/current.txt" > "$tmp/current.txt"
mv "$tmp/current.txt" "$repo/priv/api/current.txt"
expect_block 'Breaking API lock removals'
git -C "$repo" checkout -q HEAD -- priv/api/current.txt

printf '@stripe_api_version "2027-01-01.alpha"\n' > "$repo/lib/lattice_stripe.ex"
expect_block 'Default Stripe API version changed'
printf '@stripe_api_version "2026-03-25.dahlia"\n' > "$repo/lib/lattice_stripe.ex"

GH_FIXTURE=absent expect_block 'Expected one open Release Please PR; found 0'
GH_LIST_HEAD=stale-sha GH_VIEW_HEAD=current-sha expect_block 'Stale Release Please PR head'
unset GH_LIST_HEAD GH_VIEW_HEAD

printf '@version "2.4.0"\n' > "$tmp/proposal/mix.exs"
expect_block 'mix.exs version is 2.4.0; expected 2.3.0'

printf 'PASS: all release candidate fixtures passed\n'
