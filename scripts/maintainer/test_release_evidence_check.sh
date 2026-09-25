#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lattice-release-evidence-test.XXXXXX")"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT
mkdir -p "$tmp_dir/bin"
fixture_tar="$tmp_dir/package.tar"
printf 'synthetic hex tarball fixture\n' > "$fixture_tar"
fixture_checksum="$(shasum -a 256 "$fixture_tar" | awk '{print $1}')"

cat > "$tmp_dir/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == auth ]]; then exit 0; fi
if [[ "$1" == repo ]]; then printf 'owner/repo\n'; exit 0; fi
[[ "$1" == api ]] || exit 90
endpoint="$2"
case "$endpoint" in
  repos/owner/repo/git/ref/tags/v2.2.2)
    sha="1111111111111111111111111111111111111111"
    [[ "${FIXTURE_CASE:-}" != wrong_tag_sha ]] || sha="2222222222222222222222222222222222222222"
    printf '{"object":{"sha":"%s","type":"commit"}}\n' "$sha"
    ;;
  repos/owner/repo/releases/tags/v2.2.2)
    printf '{"tag_name":"v2.2.2","draft":false}\n'
    ;;
  repos/owner/repo/commits/main)
    printf '{"sha":"3333333333333333333333333333333333333333"}\n'
    ;;
  repos/owner/repo/compare/*)
    printf '{"status":"ahead","merge_base_commit":{"sha":"1111111111111111111111111111111111111111"}}\n'
    ;;
  repos/owner/repo/actions/workflows/ci.yml/runs\?*)
    printf '{"workflow_runs":[{"id":9,"head_sha":"1111111111111111111111111111111111111111","created_at":"2026-09-24T10:00:00Z"}]}\n'
    ;;
  repos/owner/repo/actions/runs/9/jobs\?*)
    conclusion=success
    [[ "${FIXTURE_CASE:-}" != stale_ci ]] || conclusion=failure
    printf '{"jobs":[{"name":"ci-gate","status":"completed","conclusion":"%s","completed_at":"2026-09-24T10:01:00Z","html_url":"https://example.test/run/9"}]}\n' "$conclusion"
    ;;
  *) echo "unexpected gh endpoint: $endpoint" >&2; exit 91 ;;
esac
GH

cat > "$tmp_dir/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($#)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
body=""
case "$url" in
  https://hex.pm/api/packages/lattice_stripe/releases/2.2.2)
    version=2.2.2
    checksum="$FIXTURE_CHECKSUM"
    [[ "${FIXTURE_CASE:-}" != wrong_hex_version ]] || version=2.3.0
    [[ "${FIXTURE_CASE:-}" != checksum_mismatch ]] || checksum=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    body="{\"version\":\"$version\",\"checksum\":\"$checksum\"}"
    ;;
  https://repo.hex.pm/tarballs/lattice_stripe-2.2.2.tar)
    cp "$FIXTURE_TARBALL" "$output"
    exit 0
    ;;
  https://hexdocs.pm/lattice_stripe/2.2.2/)
    [[ "${FIXTURE_CASE:-}" != missing_docs ]] || exit 22
    body='<title>LatticeStripe v2.2.2 — Documentation</title>'
    ;;
  *) echo "unexpected curl URL: $url" >&2; exit 92 ;;
esac
if [[ -n "$output" ]]; then printf '%s' "$body" > "$output"; else printf '%s\n' "$body"; fi
CURL

cat > "$tmp_dir/bin/mix" <<'MIX'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  deps.get)
    printf '"lattice_stripe": {:hex, :lattice_stripe, "2.2.2", "fixture", [], "hexpm", "", "", ""}\n' > mix.lock
    ;;
  deps)
    if [[ "${FIXTURE_CASE:-}" == wrong_hex_source ]]; then
      echo '* lattice_stripe 2.2.2 (../../, 2.3.0)'
    else
      echo '* lattice_stripe (Hex package) (mix)'
    fi
    ;;
  test) ;;
  *) echo "unexpected mix arguments: $*" >&2; exit 93 ;;
esac
MIX

chmod +x "$tmp_dir/bin/gh" "$tmp_dir/bin/curl" "$tmp_dir/bin/mix"
export PATH="$tmp_dir/bin:$PATH"
export FIXTURE_TARBALL="$fixture_tar"
export FIXTURE_CHECKSUM="$fixture_checksum"

check_case() {
  local case_name="$1" expected="$2" output_file="$tmp_dir/$1.out"
  if FIXTURE_CASE="$case_name" "$repo_root/scripts/maintainer/release_evidence_check.sh" \
    --version 2.2.2 --sha 1111111111111111111111111111111111111111 >"$output_file" 2>&1; then
    echo "FAIL: fixture '$case_name' unexpectedly passed" >&2
    cat "$output_file" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output_file"; then
    echo "FAIL: fixture '$case_name' did not report '$expected'" >&2
    cat "$output_file" >&2
    exit 1
  fi
  echo "PASS: $case_name reports $expected"
}

if ! "$repo_root/scripts/maintainer/release_evidence_check.sh" \
  --version 2.2.2 --sha 1111111111111111111111111111111111111111 > "$tmp_dir/valid.out" 2>&1; then
  cat "$tmp_dir/valid.out" >&2
  echo "FAIL: valid release-evidence fixture did not pass" >&2
  exit 1
fi
grep -Fq 'PASS: release evidence complete for v2.2.2' "$tmp_dir/valid.out"
echo "PASS: valid fixture"

check_case wrong_tag_sha 'tag v2.2.2 points to'
check_case stale_ci 'newest completed ci-gate'
check_case wrong_hex_version 'Hex metadata version or checksum'
check_case checksum_mismatch 'Hex checksum mismatch'
check_case missing_docs 'versioned HexDocs are unavailable'
check_case wrong_hex_source 'Mix did not resolve lattice_stripe 2.2.2 from the Hex registry'

for workflow in .github/workflows/release.yml .github/workflows/publish-hex.yml; do
  if ! grep -Fq 'scripts/maintainer/release_evidence_check.sh --version "$RELEASE_VERSION" --sha "${{ needs.gate-ci-green.outputs.sha }}"' "$repo_root/$workflow"; then
    echo "FAIL: $workflow does not pass the resolved immutable SHA and exact version to the evidence checker" >&2
    exit 1
  fi
  echo "PASS: $workflow wires the resolved SHA and exact release version"
done
if ! grep -Fq 'Record docs-only source provenance' "$repo_root/.github/workflows/publish-hex.yml" ||
  ! grep -Fq 'SOURCE_SHA: ${{ needs.gate-ci-green.outputs.sha }}' "$repo_root/.github/workflows/publish-hex.yml"; then
  echo "FAIL: manual docs-only recovery does not preserve its source-SHA provenance" >&2
  exit 1
fi
echo "PASS: manual docs-only recovery records its distinct source SHA"
