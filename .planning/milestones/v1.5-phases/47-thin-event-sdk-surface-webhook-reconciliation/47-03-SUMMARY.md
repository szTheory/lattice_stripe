---
phase: 47-thin-event-sdk-surface-webhook-reconciliation
plan: 03
subsystem: webhook
tags: [webhook, security, docs-truth, bugfix]
requires:
  - lib/lattice_stripe/webhook.ex (Webhook.check_tolerance/2, Webhook.verify_signature/4 docstring)
  - lib/lattice_stripe/webhook/plug.ex (NimbleOptions schema)
  - test/lattice_stripe/webhook_test.exs (broken :121 test)
  - test/lattice_stripe/webhook/plug_test.exs (obsolete init/1 tests)
  - test/lattice_stripe/docs_truth_test.exs (grep regression surface)
  - CHANGELOG.md (Unreleased section)
provides:
  - Reconciled `tolerance: 0` semantics across all four WEBFIX-01 surfaces (docstring + code clause + plug schema + tests)
  - Inline source comment on `check_tolerance(_timestamp, 0)` documenting the D-03 decision against future drift
  - Plug-boundary integration test proving the fix is reachable through the public Plug surface
  - CHANGELOG v1.5 entry recording the WEBFIX-01 reconciliation
  - Docs-truth grep regression test asserting the CHANGELOG entry stays present
affects:
  - lib/lattice_stripe/webhook.ex
  - lib/lattice_stripe/webhook/plug.ex
  - test/lattice_stripe/webhook_test.exs
  - test/lattice_stripe/webhook/plug_test.exs
  - test/lattice_stripe/docs_truth_test.exs
  - CHANGELOG.md
tech-stack:
  added: []
  patterns:
    - Four-surface docs-truth reconciliation (docstring + code + schema + test all agree)
    - Inline source-comment as load-bearing regression-prevention contract (RESEARCH Pitfall 5)
    - Grep-based docs-truth regression tests (mirror of existing CHANGELOG `## [1.3.0]` assertions)
key-files:
  created: []
  modified:
    - lib/lattice_stripe/webhook.ex
    - lib/lattice_stripe/webhook/plug.ex
    - test/lattice_stripe/webhook_test.exs
    - test/lattice_stripe/webhook/plug_test.exs
    - test/lattice_stripe/docs_truth_test.exs
    - CHANGELOG.md
decisions:
  - "D-03 (code-fix path): `check_tolerance(_timestamp, 0)` returns `:ok` (disables staleness check), matches every canonical Stripe SDK (stripe-node tolerance>0 gate, stripe-go IgnoreTolerance, stripe-ruby tolerance && ...)"
  - "Plug NimbleOptions schema relaxed `:tolerance` from `:pos_integer` to `:non_neg_integer` so `0` is reachable through the public Plug surface; negative integers still rejected"
  - "Inline source comment above the corrected clause is load-bearing for the regression-prevention contract per RESEARCH Pitfall 5 — do not abbreviate or remove in future refactors"
  - "CHANGELOG entry land in `## [Unreleased]` → `### [1.5.0] — Thin-Event SDK Surface & Webhook Reconciliation`; mix.exs version bump deferred to release time per plan scope"
  - "Existing `\"raises when tolerance is zero\"` test in plug_test.exs was a second instance of the broken behavior surface (enshrined `:pos_integer`); rewrote it as the new `accepts tolerance: 0` test rather than leaving it to fail"
metrics:
  duration: "~3 minutes"
  completed_date: 2026-05-27T09:27:05Z
  tasks_completed: 2
  files_modified: 6
  files_created: 0
  tests_added: 4
  tests_passing: 71
---

# Phase 47 Plan 03: Webhook tolerance: 0 four-surface reconciliation Summary

**One-liner:** Reconciled `Webhook.check_tolerance/2` `tolerance: 0` drift across docstring, code clause, Plug schema, and tests; added CHANGELOG v1.5 entry + docs-truth grep regression to lock the decision against future "fix it to be stricter" PRs.

## Outcome

The four-surface WEBFIX-01 drift documented in 47-CONTEXT D-03 is closed. Before this plan:

| Surface                                    | Said                                              |
| ------------------------------------------ | ------------------------------------------------- |
| `webhook.ex:84` docstring                  | "Set `0` to disable staleness check"              |
| `webhook.ex:268-273` code clause           | `{:error, :timestamp_expired}` (always rejects)   |
| `webhook/plug.ex:142-146` schema           | `:pos_integer` (rejects `0` at init time)         |
| `webhook_test.exs:121` test                | enshrined `tolerance: 0 → {:error, :timestamp_expired}` |

After:

| Surface                                    | Says                                                                          |
| ------------------------------------------ | ----------------------------------------------------------------------------- |
| `webhook.ex` `:tolerance` docstring        | "Set `0` to disable the staleness check (testing only)"                       |
| `webhook.ex` `check_tolerance(_, 0)` clause | `:ok` (+ load-bearing inline WEBFIX-01 / stripe-node + stripe-go comment)     |
| `webhook/plug.ex` `:tolerance` schema      | `:non_neg_integer` (`0` accepted, `-1` rejected)                              |
| `webhook_test.exs` test                    | `tolerance: 0 disables the staleness check (any age accepted)`                |
| `webhook/plug_test.exs` init/1 test        | `Webhook.Plug.init/1 accepts tolerance: 0 (schema :non_neg_integer)`          |
| `webhook/plug_test.exs` end-to-end test    | 86_400s-old timestamp + `tolerance: 0` → Plug returns `200`, not `400`        |
| `CHANGELOG.md` v1.5 entry                  | "WEBFIX-01 — Webhook.check_tolerance/2 tolerance: 0 ... now correctly..."     |
| `docs_truth_test.exs` grep regression      | Asserts `WEBFIX-01` + `## [1.5` present in CHANGELOG                          |

## Tasks Completed

### Task 1 — Fix `check_tolerance/2` + relax Plug schema + rewrite broken test (`8844163`)

- `lib/lattice_stripe/webhook.ex`: replaced the `check_tolerance(_timestamp, 0)` body with `:ok` plus an inline comment block that names WEBFIX-01, stripe-node, and stripe-go and labels itself "load-bearing for the four-surface regression contract".
- `lib/lattice_stripe/webhook.ex`: tightened the `verify_signature/4` `:tolerance` docstring bullet to cross-reference the WEBFIX-01 CHANGELOG entry + the inline comment.
- `lib/lattice_stripe/webhook/plug.ex`: NimbleOptions `:tolerance` schema row changed from `type: :pos_integer` to `type: :non_neg_integer` and the `doc:` string now reads "Max age of webhook timestamp in seconds. Set 0 to disable the staleness check (testing only)."
- `test/lattice_stripe/webhook_test.exs`: rewrote the broken `:121` test from "tolerance: 0 fails on any non-zero-age timestamp" to "tolerance: 0 disables the staleness check (any age accepted)"; assertion is `{:ok, ^ancient_ts}` against `System.system_time(:second) - 100_000`.

### Task 2 — Plug-boundary tests + CHANGELOG + docs-truth regression (`5ecdc50`)

- `test/lattice_stripe/webhook/plug_test.exs`:
  - Rewrote the obsolete "raises when tolerance is zero" `init/1` test (which enshrined `:pos_integer`) into the new "accepts tolerance: 0 (schema :non_neg_integer)" test.
  - Renamed the existing "raises when tolerance is negative" test to make the WEBFIX-01 / Pitfall 6 anchor explicit.
  - Added a new `describe "tolerance: 0 end-to-end (WEBFIX-01)"` block with a test that builds an 86_400-second-old `Stripe-Signature` header, configures the Plug with `tolerance: 0` and `OkHandler`, and asserts `conn.status == 200` + `conn.halted` — the integration regression proving all four surfaces agree.
- `CHANGELOG.md`: extended `## [Unreleased]` with a `### [1.5.0] — Thin-Event SDK Surface & Webhook Reconciliation` subsection and a `#### Fixed` block documenting both WEBFIX-01 surfaces (code path + Plug schema). Note explicitly says "Testing only — never set `tolerance: 0` in production".
- `test/lattice_stripe/docs_truth_test.exs`: appended `"CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5"` after the existing 1.3 release-truth test, mirroring the same `File.read!` + `=~` pattern; asserts both `"WEBFIX-01"` substring and `~r/##\s*\[?1\.5/` heading regex.

## The Inline Comment That Locks the Decision

Per RESEARCH Pitfall 5 "How to avoid", the inline source comment above `check_tolerance(_timestamp, 0)` is the load-bearing artifact against a future "make webhooks stricter" PR. Verbatim from the corrected source:

```elixir
# Checks that the webhook timestamp is within the tolerance window.
# Reconciled per WEBFIX-01 (CHANGELOG v1.5): `tolerance: 0` now disables the
# staleness check entirely, matching the docstring at `:tolerance` and every
# canonical Stripe SDK — stripe-node's `if (tolerance > 0 && ...)` gate and
# stripe-go's `IgnoreTolerance` flag. Use this in tests (with `:timestamp`
# overrides via `generate_test_signature/3`); never in production traffic —
# the canonical Phoenix guide will state this explicitly.
# Inline comment is load-bearing for the four-surface regression contract.
defp check_tolerance(_timestamp, 0), do: :ok
```

A future PR that flips this back to `{:error, :timestamp_expired}` must (a) delete the comment, (b) make `webhook_test.exs:121` fail, (c) make the Plug end-to-end test fail, and (d) make the docs-truth grep test fail if it also removes the CHANGELOG entry. Triangulation by design.

## Verification

```
$ mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/docs_truth_test.exs
Finished in 0.1 seconds (0.1s async, 0.00s sync)
71 tests, 0 failures
```

```
$ mix compile --warnings-as-errors
Compiling 134 files (.ex)
Generated lattice_stripe app
```

All acceptance criteria from `47-03-PLAN.md` task 1 and task 2 are satisfied (verified by grep checks during execution; details inline above).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Rewrote obsolete `webhook/plug_test.exs:84-88` init/1 test**

- **Found during:** Task 1 (the moment the Plug schema flipped to `:non_neg_integer`)
- **Issue:** The existing `test "raises when tolerance is zero"` test in `plug_test.exs` (originally lines 84-88) was a *second* instance of the broken-behavior surface — it asserted that the now-relaxed schema would reject `0`. With the schema correctly accepting `0`, that test would fail.
- **Fix:** Treated it as part of the broken-test surface that Task 1 / Task 2 must reconcile. Rewrote it into the new "accepts tolerance: 0 (schema :non_neg_integer)" `init/1` test (which Task 2 was supposed to add anyway as test #1 of three). The fix collapsed two redundant boundary tests into one canonically correct one.
- **Files modified:** `test/lattice_stripe/webhook/plug_test.exs` (the init/1 describe block)
- **Commits:** rewrite landed in `5ecdc50` (Task 2)
- **Why no checkpoint:** plan acceptance criteria for Task 2 explicitly required `grep -E 'tolerance: 0' test/lattice_stripe/webhook/plug_test.exs returns at least one match in an init/1-style test` — same surface, just couldn't leave the obsolete test around to silently fail.

### Notes

- **Existing "raises when tolerance is negative" test** (originally lines 90-94 of plug_test.exs) was kept and renamed to `Webhook.Plug.init/1 rejects tolerance: -1 (:non_neg_integer still rejects negatives)` to make the WEBFIX-01 / RESEARCH Pitfall 6 anchor explicit. It already asserted exactly what the plan's test #2 wanted (`assert_raise NimbleOptions.ValidationError` on `tolerance: -1`), so we did not add a duplicate.
- **CHANGELOG placement decision** — the plan said "If no v1.5 section exists yet, create one". `## [Unreleased]` existed but only said "No unreleased changes yet." We added the v1.5 entry as a `### [1.5.0]` subsection *under* `## [Unreleased]`. This:
  - Satisfies `grep -E '##\s*\[?1\.5'` (matches `### [1.5.0]`).
  - Keeps release-please / mix.exs version bump as the canonical promotion path at release time (plan scope explicitly excluded the version bump).
  - Avoids creating a confusing "released v1.5.0" surface in the changelog before the actual version bump and Hex publish happen.

## Authentication Gates

None encountered. No package installs (Phase 47 uses only pinned `mix.lock` deps per the threat model's T-47-SC row).

## Known Stubs

None. The plan touches existing surfaces only.

## Threat Flags

None. No new endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The Plug schema relaxation from `:pos_integer` → `:non_neg_integer` is documented in 47-03-PLAN.md `<threat_model>` rows T-47-08, T-47-09, T-47-10 and mitigated by the tests committed in Task 2.

## Forward Notes

- **Phase 48's canonical webhook guide (`guides/webhooks-thin-events.md`) MUST emphasize "never set `tolerance: 0` in production"** — the SDK provides the lever for tests; the production-safety teaching is the guide's job. The Plug schema `doc:` string and the inline source comment both label `tolerance: 0` as "testing only", but a one-line `doc:` is easy to miss. Phase 48 should add a dedicated callout box.
- **Adopters who copy-pasted `Webhook.Plug` config with `tolerance: 0` and saw it reject at `init/1` time before** will see their config now succeed. This is a behavior change at the Plug boundary but matches the documented intent — it is the intended fix per D-03. Adopters who actually wanted `0`-rejects had no way to express that intent (the docstring contradicted them) — there is no real adopter to break.
- **Telemetry on `tolerance: 0`?** Not in this plan's scope. Possible future enhancement: emit a one-time warning log line via `Logger.warning` when the Plug is initialized with `tolerance: 0` in `:prod` Mix env. Filed under "consider after Phase 48 guide ships" — would touch Plug boundary again, deserves its own discuss-phase.

## Self-Check: PASSED

- File `lib/lattice_stripe/webhook.ex` exists and contains `defp check_tolerance(_timestamp, 0), do: :ok` — FOUND
- File `lib/lattice_stripe/webhook/plug.ex` exists and contains `type: :non_neg_integer` — FOUND
- File `test/lattice_stripe/webhook_test.exs` contains `tolerance: 0 disables the staleness check` — FOUND
- File `test/lattice_stripe/webhook/plug_test.exs` contains `accepts tolerance: 0` and `rejects tolerance: -1` tests — FOUND
- File `test/lattice_stripe/docs_truth_test.exs` contains `CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5` — FOUND
- File `CHANGELOG.md` contains `WEBFIX-01` and `### [1.5.0]` — FOUND
- Commit `8844163` (Task 1 — fix WEBFIX-01 surfaces) — FOUND
- Commit `5ecdc50` (Task 2 — plug-boundary + CHANGELOG + docs-truth) — FOUND
- `mix test` over all three target test files: 71 tests, 0 failures
- `mix compile --warnings-as-errors`: clean
