#!/usr/bin/env bash
set -euo pipefail

version="${1:-${MIX_LATTICE_STRIPE_HEX_VERSION:-}}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "BLOCKED: provide an exact Hex release version (for example 2.2.2)." >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
source_app="$repo_root/test_apps/phoenix_adopter"
if [[ ! -f "$source_app/mix.exs" ]]; then
  echo "BLOCKED: Phoenix adopter project was not found at $source_app." >&2
  exit 2
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lattice-stripe-hex-adopter.XXXXXX")"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT
cp -R "$source_app/." "$tmp_dir/"
rm -f "$tmp_dir/mix.lock"

export MIX_LATTICE_STRIPE_HEX_VERSION="$version"
export MIX_DEPS_PATH="$tmp_dir/deps"
export MIX_BUILD_PATH="$tmp_dir/_build"
export HEX_HOME="$tmp_dir/hex"
if command -v asdf >/dev/null 2>&1 && [[ -f "$repo_root/.tool-versions" ]]; then
  export ASDF_ELIXIR_VERSION="$(awk '$1 == "elixir" { print $2; exit }' "$repo_root/.tool-versions")"
  export ASDF_ERLANG_VERSION="$(awk '$1 == "erlang" { print $2; exit }' "$repo_root/.tool-versions")"
fi
unset STRIPE_SECRET_KEY STRIPE_API_KEY LATTICE_STRIPE_API_KEY STRIPE_WEBHOOK_SECRET
cd "$tmp_dir"

mix deps.get --only test
deps_output="$(mix deps)"
printf '%s\n' "$deps_output"
if ! grep -Eq '^[* ]*lattice_stripe[[:space:]]+\(Hex package\)([[:space:]]|$)' <<<"$deps_output"; then
  echo "BLOCKED: Mix did not resolve lattice_stripe $version from the Hex registry." >&2
  exit 1
fi
if ! grep -Fq "\"lattice_stripe\": {:hex, :lattice_stripe, \"$version\"" mix.lock; then
  echo "BLOCKED: isolated lockfile does not record a Hex registry source for lattice_stripe." >&2
  exit 1
fi

mix test test/core_flow_test.exs --warnings-as-errors
echo "PASS: Phoenix synthetic Checkout/webhook flow used lattice_stripe $version from Hex."
