#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --version X.Y.Z --sha <full-commit-sha>" >&2
}

version=""
sha=""
while (($#)); do
  case "$1" in
    --version) (($# >= 2)) || { usage; exit 2; }; version="$2"; shift 2 ;;
    --sha) (($# >= 2)) || { usage; exit 2; }; sha="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "BLOCKED: --version must be an exact semantic version." >&2; exit 2
fi
if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "BLOCKED: --sha must be a full 40-character lowercase commit SHA." >&2; exit 2
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "BLOCKED: required command '$1' is unavailable." >&2; exit 2; }; }
need gh
need curl
need jq
need shasum
if ! gh auth status >/dev/null 2>&1; then
  echo "BLOCKED: GitHub CLI authentication is unavailable; run 'gh auth login' and retry." >&2
  exit 2
fi

fail() { echo "BLOCKED: $1" >&2; exit 1; }
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || fail "could not identify the GitHub repository"
[[ -n "$repo" ]] || fail "GitHub repository identity was empty"
tag="v$version"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lattice-release-evidence.XXXXXX")"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

tag_ref="$(gh api "repos/$repo/git/ref/tags/$tag" 2>/dev/null)" || fail "tag $tag is missing or unreadable"
tag_object_sha="$(jq -er '.object.sha' <<<"$tag_ref")" || fail "tag $tag response has no object SHA"
tag_object_type="$(jq -er '.object.type' <<<"$tag_ref")" || fail "tag $tag response has no object type"
if [[ "$tag_object_type" == tag ]]; then
  annotated="$(gh api "repos/$repo/git/tags/$tag_object_sha" 2>/dev/null)" || fail "annotated tag $tag could not be peeled"
  tag_sha="$(jq -er '.object | select(.type == "commit") | .sha' <<<"$annotated")" || fail "tag $tag does not peel directly to a commit"
elif [[ "$tag_object_type" == commit ]]; then
  tag_sha="$tag_object_sha"
else
  fail "tag $tag points to unsupported object type '$tag_object_type'"
fi
[[ "$tag_sha" == "$sha" ]] || fail "tag $tag points to $tag_sha, expected $sha"
echo "PASS: $tag peels to $sha"

release="$(gh api "repos/$repo/releases/tags/$tag" 2>/dev/null)" || fail "GitHub Release $tag is missing or unreadable"
jq -e --arg tag "$tag" '.tag_name == $tag and .draft == false' <<<"$release" >/dev/null || fail "GitHub Release does not match published tag $tag"
echo "PASS: GitHub Release $tag exists"

main_sha="$(gh api "repos/$repo/commits/main" --jq .sha 2>/dev/null)" || fail "could not read main SHA from GitHub"
comparison="$(gh api "repos/$repo/compare/$sha...$main_sha" 2>/dev/null)" || fail "could not compare release SHA with main"
jq -e --arg sha "$sha" '(.status == "ahead" or .status == "identical") and .merge_base_commit.sha == $sha' <<<"$comparison" >/dev/null || fail "$sha is not an ancestor of current main"
echo "PASS: $sha is on main (main=$main_sha)"

runs="$(gh api "repos/$repo/actions/workflows/ci.yml/runs?head_sha=$sha&per_page=100" 2>/dev/null)" || fail "could not read ci.yml runs for $sha"
run_ids=()
while IFS= read -r run_id; do
  [[ -n "$run_id" ]] && run_ids+=("$run_id")
done < <(jq -r --arg sha "$sha" '[.workflow_runs[] | select(.head_sha == $sha)] | sort_by(.created_at) | reverse | .[].id' <<<"$runs")
completed_jobs='[]'
for run_id in "${run_ids[@]}"; do
  jobs="$(gh api "repos/$repo/actions/runs/$run_id/jobs?per_page=100" 2>/dev/null)" || fail "could not read jobs for CI run $run_id"
  completed_jobs="$(jq -cn --argjson prior "$completed_jobs" --argjson next "$(jq -c '[.jobs[] | select(.name == "ci-gate" and .status == "completed") | {name, status, conclusion, completed_at, html_url}]' <<<"$jobs")" '$prior + $next')"
done
latest_gate="$(jq -c 'sort_by(.completed_at) | reverse | .[0] // empty' <<<"$completed_jobs")"
[[ -n "$latest_gate" ]] || fail "no completed ci-gate exists on $sha"
gate_conclusion="$(jq -r '.conclusion' <<<"$latest_gate")"
[[ "$gate_conclusion" == success ]] || fail "newest completed ci-gate on $sha concluded '$gate_conclusion'"
echo "PASS: newest completed ci-gate succeeded ($(jq -r '.html_url // "run URL unavailable"' <<<"$latest_gate"))"

api_url="https://hex.pm/api/packages/lattice_stripe/releases/$version"
release_json="$tmp_dir/hex-release.json"
if ! curl --fail --silent --show-error --location --retry 4 --retry-delay 2 --retry-all-errors --max-time 30 "$api_url" -o "$release_json"; then
  fail "Hex release metadata for $version is unavailable"
fi
jq -e --arg version "$version" '.version == $version and (.checksum | test("^[0-9a-f]{64}$"))' "$release_json" >/dev/null || fail "Hex metadata version or checksum is malformed/mismatched"
hex_checksum="$(jq -r .checksum "$release_json")"

tarball="$tmp_dir/lattice_stripe-$version.tar"
if ! curl --fail --silent --show-error --location --retry 4 --retry-delay 2 --retry-all-errors --max-time 30 "https://repo.hex.pm/tarballs/lattice_stripe-$version.tar" -o "$tarball"; then
  fail "Hex package tarball for $version is unavailable"
fi
tarball_checksum="$(shasum -a 256 "$tarball" | awk '{print $1}')"
[[ "$tarball_checksum" == "$hex_checksum" ]] || fail "Hex checksum mismatch: API=$hex_checksum downloaded-tarball-SHA256=$tarball_checksum"
echo "PASS: Hex $version checksum matches downloaded package tarball SHA-256 ($hex_checksum)"

docs_url="https://hexdocs.pm/lattice_stripe/$version/"
docs_file="$tmp_dir/docs.html"
if ! curl --fail --silent --show-error --location --retry 4 --retry-delay 2 --retry-all-errors --max-time 30 "$docs_url" -o "$docs_file"; then
  fail "versioned HexDocs are unavailable at $docs_url"
fi
grep -Fq "LatticeStripe v$version — Documentation" "$docs_file" || fail "HexDocs page does not identify version $version"
echo "PASS: versioned HexDocs identify $version ($docs_url)"

env -u GH_TOKEN -u GITHUB_TOKEN -u HEX_API_KEY "$script_dir/published_hex_adopter_smoke.sh" "$version"
echo "PASS: release evidence complete for $tag at $sha (Hex checksum $hex_checksum)"
