#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/pr_closeout_check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/timelines"

expect_pass() {
  local name="$1"
  if ! "$SCRIPT" --ledger "$TMP/ledger.json" --inventory-file "$TMP/inventory.json" \
    --timeline-dir "$TMP/timelines" >/dev/null; then
    echo "FAIL: expected $name to pass" >&2
    exit 1
  fi
  echo "PASS: $name"
}

expect_fail() {
  local name="$1"
  if "$SCRIPT" --ledger "$TMP/ledger.json" --inventory-file "$TMP/inventory.json" \
    --timeline-dir "$TMP/timelines" >/dev/null 2>&1; then
    echo "FAIL: expected $name to fail" >&2
    exit 1
  fi
  echo "PASS: $name"
}

jq -n '[]' >"$TMP/inventory.json"
jq -n --arg date "2026-09-24T12:00:00Z" '{generated_at:$date,entries:[]}' >"$TMP/ledger.json"
expect_pass "empty inventory"

jq -n '[{number:7,url:"https://github.com/acme/project/pull/7",headRefOid:"abc123",statusCheckRollup:[{name:"ci-gate",conclusion:"SUCCESS"}]}]' >"$TMP/inventory.json"
jq -n --arg date "2026-09-24T12:00:00Z" '{generated_at:$date,entries:[{pr_number:7,pr_url:"https://github.com/acme/project/pull/7",head_sha:"abc123",disposition:"defer",rationale:"Pending required checks.",next_action:"Re-run required checks and reassess.",next_action_date:"2026-09-25",required_checks:{head_sha:"abc123",state:"failure",ci_gate:"failure"},timeline:{url:"https://github.com/acme/project/pull/7#issuecomment-70",decision_text:"Disposition: defer"}}]}' >"$TMP/ledger.json"
jq -n '[{html_url:"https://github.com/acme/project/pull/7#issuecomment-70",body:"Disposition: defer. Pending required checks."}]' >"$TMP/timelines/7.json"
expect_pass "valid open deferral"

jq '.entries += [.entries[0]]' "$TMP/ledger.json" >"$TMP/duplicate.json"
cp "$TMP/duplicate.json" "$TMP/ledger.json"
expect_fail "duplicate PR entry"

jq -n --arg date "2026-09-24T12:00:00Z" '{generated_at:$date,entries:[]}' >"$TMP/ledger.json"
expect_fail "omitted open PR"

jq -n --arg date "2026-09-24T12:00:00Z" '{generated_at:$date,entries:[{pr_number:7,pr_url:"https://github.com/acme/project/pull/7",head_sha:"old",disposition:"merge",rationale:"Accept.",required_checks:{head_sha:"old",state:"success",ci_gate:"success"},timeline:{url:"https://github.com/acme/project/pull/7#issuecomment-70",decision_text:"Disposition: merge"}}]}' >"$TMP/ledger.json"
jq -n '[{html_url:"https://github.com/acme/project/pull/7#issuecomment-70",body:"Disposition: merge"}]' >"$TMP/timelines/7.json"
expect_fail "stale PR head and checks"

jq '.entries[0].head_sha="abc123" | .entries[0].required_checks.head_sha="abc123" | .entries[0].timeline.url=""' "$TMP/ledger.json" >"$TMP/no-url.json"
cp "$TMP/no-url.json" "$TMP/ledger.json"
expect_fail "missing timeline URL"

jq -n --arg date "2026-09-24T12:00:00Z" '{generated_at:$date,entries:[{pr_number:7,pr_url:"https://github.com/acme/project/pull/7",head_sha:"abc123",disposition:"defer",rationale:"Pending checks.",next_action:"Reassess." ,required_checks:{head_sha:"abc123",state:"failure",ci_gate:"failure"},timeline:{url:"https://github.com/acme/project/pull/7#issuecomment-70",decision_text:"Disposition: defer"}}]}' >"$TMP/ledger.json"
expect_fail "deferred item without next action date"

jq -n --arg date "2026-09-24T12:00:00Z" '{generated_at:$date,entries:[{pr_number:7,pr_url:"https://github.com/acme/project/pull/7",head_sha:"abc123",disposition:"merge",rationale:"Accept.",required_checks:{head_sha:"abc123",state:"failure",ci_gate:"failure"},timeline:{url:"https://github.com/acme/project/pull/7#issuecomment-70",decision_text:"Disposition: merge"}}]}' >"$TMP/ledger.json"
jq -n '[{html_url:"https://github.com/acme/project/pull/7#issuecomment-70",body:"Disposition: merge"}]' >"$TMP/timelines/7.json"
expect_fail "merge without successful current-head checks"

echo "All PR closeout checker fixtures passed."
