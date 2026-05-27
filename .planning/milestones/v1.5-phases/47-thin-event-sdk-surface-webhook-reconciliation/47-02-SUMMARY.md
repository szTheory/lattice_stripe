---
phase: 47-thin-event-sdk-surface-webhook-reconciliation
plan: 02
subsystem: webhooks
tags: [thin-events, parse, verify-then-decode, public-api, THIN-01]
requires:
  - LatticeStripe.EventNotification (plan 47-01)
  - LatticeStripe.EventNotification.RelatedObject (plan 47-01)
  - LatticeStripe.Webhook.verify_signature/4 (existing — unchanged)
  - LatticeStripe.Webhook.SignatureVerificationError (existing — unchanged)
  - LatticeStripe.Telemetry.webhook_verify_span/2 (existing — unchanged)
  - LatticeStripe.Test.Fixtures.EventNotification (plan 47-01)
provides:
  - LatticeStripe.Webhook.parse_event_notification/4
  - LatticeStripe.Webhook.parse_event_notification!/4
affects:
  - lib/lattice_stripe/webhook.ex
  - test/lattice_stripe/webhook_test.exs
tech-stack:
  added: []
  patterns:
    - "Verify-then-decode (verbatim copy of construct_event/4 pattern, swap decode target)"
    - "Public {:ok, t()} | {:error, reason} + bang variant raising SignatureVerificationError"
    - "Telemetry span reuse for shared verify boundary (no new event)"
    - "Moduledoc routing-guidance section to address Pitfall 1 (wrong entry point silently produces mostly-nil struct)"
key-files:
  created: []
  modified:
    - lib/lattice_stripe/webhook.ex
    - test/lattice_stripe/webhook_test.exs
key-decisions:
  - "D-07 implemented verbatim: parse_event_notification/4 reuses the same 4-atom verify_error set as construct_event/4 (:missing_header, :invalid_header, :no_matching_signature, :timestamp_expired). No new error atoms introduced."
  - "RESEARCH 'Anti-Patterns to Avoid' honored: no verify_and_decode private helper extracted. Five lines of duplication is fine for two callsites; defer extraction until a third callsite appears."
  - "RESEARCH 'Known Threat Patterns' final row honored: no defensive object == 'v2.core.event' discriminator added. Surfaced in moduledoc 'Snapshot events vs thin events' section + flagged as planner-decision follow-up if adopter feedback motivates strictness."
  - "Telemetry boundary unchanged: parse_event_notification/4 wraps the verify+decode block in the same webhook_verify_span/2 as construct_event/4 — verify primitive is shared (RESEARCH Architectural Responsibility Map)."
requirements-completed: [THIN-01]
duration: ~4 min
completed: 2026-05-27
---

# Phase 47 Plan 02: Thin-Event Public Parse Entry Points Summary

Shipped THIN-01 — the two public verify-then-decode entry points adopters call from their Phoenix controllers to handle Stripe `/v2/event-destinations` webhook traffic. `parse_event_notification/4` returns `{:ok, %EventNotification{}} | {:error, verify_error()}`; the bang variant `parse_event_notification!/4` mirrors `construct_event!/4` by raising `SignatureVerificationError`. Both reuse the existing `verify_signature/4` HMAC primitive verbatim (D-07), the existing `webhook_verify_span/2` telemetry span, and the typed `EventNotification.from_map/1` decoder from plan 47-01. The `LatticeStripe.Webhook` moduledoc grew a "Snapshot events vs thin events: when to use which" section so adopters route the right payload shape to the right entry point (RESEARCH Pitfall 1).

**Duration:** ~4 min
**Start:** 2026-05-27T09:31:50Z
**End:** 2026-05-27T09:36:09Z
**Tasks:** 2 / 2 complete
**Files:** 2 modified (no files created)
**Tests:** 39 tests in `webhook_test.exs` (was 30 — added 9). Full suite: 1963 tests, 0 failures, 1 skipped.

## Files Modified

| File | Change |
|---|---|
| `lib/lattice_stripe/webhook.ex` | (a) Added `alias LatticeStripe.EventNotification`. (b) Added moduledoc section "Snapshot events vs thin events: when to use which" — routing guidance Pitfall 1. (c) Added public `parse_event_notification/4` + matching `@spec`. (d) Added bang variant `parse_event_notification!/4` + matching `@spec`. Both placed immediately after `construct_event!/4`. |
| `test/lattice_stripe/webhook_test.exs` | (a) Added `import LatticeStripe.Test.Fixtures.EventNotification` for fixture builders. (b) Added aliases for `EventNotification` and `RelatedObject`. (c) Added `describe "parse_event_notification/4"` block with 6 tests. (d) Added `describe "parse_event_notification!/4"` block with 3 tests. |

## Function Surface Added

### `parse_event_notification/4`

```elixir
@spec parse_event_notification(String.t(), String.t() | nil, secret(), keyword()) ::
        {:ok, EventNotification.t()} | {:error, verify_error()}
def parse_event_notification(payload, sig_header, secret, opts \\ [])
```

Verify-then-decode mirror of `construct_event/4`. Telemetry span wraps the whole call; on `{:ok, _ts}` from `verify_signature/4` the payload is `Jason.decode!/1`'d and threaded through `EventNotification.from_map/1`; verify errors pass through unchanged.

### `parse_event_notification!/4`

```elixir
@spec parse_event_notification!(String.t(), String.t() | nil, secret(), keyword()) ::
        EventNotification.t()
def parse_event_notification!(payload, sig_header, secret, opts \\ [])
```

Bang variant: returns the struct on success, raises `LatticeStripe.Webhook.SignatureVerificationError` carrying the `:reason` atom from the verify error set on failure.

## Error Atom Set (D-07 — exact reuse)

| Atom | Trigger |
|---|---|
| `:missing_header` | `sig_header` is `nil` or empty string |
| `:invalid_header` | header missing `t=` or `v1=`, malformed timestamp, or completely garbage |
| `:no_matching_signature` | none of the provided secrets produced a matching HMAC |
| `:timestamp_expired` | timestamp older than the configured tolerance window |

All four are tested directly in the new `describe "parse_event_notification/4"` block via atom-equality assertions. The bang variant test verifies the exception carries the right atom in `:reason` via `e.reason == :no_matching_signature`.

## Wire-Format Regressions Locked

Per RESEARCH.md, two wire-format facts are now regression-locked by direct equality assertions in the happy-path test:

1. **Finding 1:** `object: "v2.core.event"` (NOT `"v2.core.event_notification"`). Assertion: `assert notif.object == "v2.core.event"`.
2. **Finding 2:** `created` is the ISO 8601 string `"2026-03-09T13:00:28.435Z"` (NOT a Unix integer). Assertion: `assert notif.created == "2026-03-09T13:00:28.435Z"`.

A future PR that drifts either wire value will trip these assertions immediately.

## Moduledoc Routing Section

Per RESEARCH Pitfall 1, the `LatticeStripe.Webhook` moduledoc now contains an explicit "Snapshot events vs thin events: when to use which" section. It explicitly states:

- Snapshot events (`object: "event"`, full `data` embedded, integer `created`) → `construct_event/4` → `%Event{}`.
- Thin events (`object: "v2.core.event"`, no `data`, ISO 8601 `created`, `related_object` reference) → `parse_event_notification/4` → `%EventNotification{}`.
- Calling the wrong entry point on a payload silently produces a mostly-nil struct because the JSON keys do not overlap.
- Routing is the adopter's responsibility — based on which webhook endpoint Stripe is calling, not on payload-shape sniffing.

This section is the documentation-level mitigation for threat row T-47-07 (no defensive `object` discriminator in this plan).

## Verification

```
$ mix compile --warnings-as-errors
[Compiling 136 files (.ex)]
Generated lattice_stripe app

$ mix test test/lattice_stripe/webhook_test.exs --color
Finished in 0.07 seconds (0.07s async, 0.00s sync)
39 tests, 0 failures

$ mix test --color
Finished in 2.5 seconds (1.8s async, 0.7s sync)
1963 tests, 0 failures, 1 skipped (191 excluded)
```

All acceptance criteria from `47-02-PLAN.md` Tasks 1 and 2 pass (verified via the grep checklist during execution — captured in the commit messages of `448bbe9` and `0c538e4`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Ran `mix deps.get` after first compile failure**

- **Found during:** Task 1 verification (first `mix compile --warnings-as-errors` invocation)
- **Issue:** Worktree spawned with an empty `deps/` cache; the compile bailed with `Unchecked dependencies for environment dev` listing every transitive Hex dep.
- **Fix:** Ran `mix deps.get` once. No package install attempted — `mix.lock` was already pinned; this is a transparent restore from the lock file, not the "package install" failure mode that Rule 3's package-install carve-out covers.
- **Files modified:** None (deps install is a worktree-local cache restore; no code changed).
- **Why no checkpoint:** transparent lockfile restore from the existing `mix.lock`. No new package added; no slopsquat surface.

### Notes

- **No `verify_and_decode` private helper extracted.** Per RESEARCH "Anti-Patterns to Avoid": five lines of duplication across two callsites is fine. Defer extraction until a third callsite appears (e.g., a future v1.6 thin-event-aware Plug dispatcher).
- **No defensive `object == "v2.core.event"` discriminator check added.** Per RESEARCH "Known Threat Patterns" final row + CONTEXT D-07 + threat row T-47-07: flagged as a planner-decision follow-up rather than v1.5 scope. Documentation-level mitigation lives in the moduledoc "Snapshot events vs thin events" section.

**Total deviations:** 1 auto-fix (Rule 3 — deps restore), 0 code-affecting deviations.
**Impact:** None on shipped surface.

## Authentication Gates

None encountered. No package installs (Phase 47 uses only pinned `mix.lock` deps per threat model T-47-SC).

## Known Stubs

None. The plan added two fully-implemented public functions with full `@spec`s, docstrings, and exhaustive test coverage.

## Threat Surface Scan

No new threat surface beyond what is already in the plan's `<threat_model>`. Both new functions reuse the existing `verify_signature/4` HMAC primitive verbatim — same secret type, same tolerance machinery, same `Plug.Crypto.secure_compare/2` timing-safe comparison. No new HTTP endpoints, no new auth paths, no new file access patterns. The decode target (`EventNotification.from_map/1`) was already threat-scanned in plan 47-01.

## Forward Notes

- **Plan 47-04** (`fetch_event/3` + `fetch_related_object/3`) can now build on `%EventNotification{}` returned by these entry points. The canonical adopter call chain is locked in by the new docstring example: `parse_event_notification/4` → pattern-match `related_object` → either `fetch_related_object/3` (with `%RelatedObject{}`) or `fetch_event/3` (with snapshot-style v2 events).
- **Plan 47-05** (`Testing.generate_thin_event_payload/3` + `Testing.event_notification/1`) can now reference these public entry points directly in the docstring examples — the test-helper-builds-payload → `parse_event_notification/4` roundtrip is the canonical adopter test pattern.
- **Phase 48** (`guides/webhooks-thin-events.md`) should anchor on the `parse_event_notification/4` docstring example as the canonical adopter handler shape. The moduledoc "Snapshot events vs thin events" section sets up the routing distinction; the guide will deepen it with Phoenix-controller-level scaffolding.
- **Defensive `object` discriminator (deferred per T-47-07).** If real adopter feedback surfaces friction (e.g., "I accidentally routed v1 webhook traffic to `parse_event_notification/4` and got a silent half-decoded struct"), reconsider adding a defensive `case` clause in `parse_event_notification/4` that returns `{:error, {:wrong_event_shape, "expected v2.core.event, got X"}}`. This is a v1.5.x follow-up at most, not v1.5 scope.

## Self-Check: PASSED

- [x] File `lib/lattice_stripe/webhook.ex` exists on disk (verified)
- [x] File `test/lattice_stripe/webhook_test.exs` exists on disk (verified)
- [x] Commit `448bbe9` (Task 1 — feat parse_event_notification/4 + bang variant) reachable via `git log --oneline -3` (verified)
- [x] Commit `0c538e4` (Task 2 — test parse_event_notification/4 + bang variant coverage) reachable via `git log --oneline -3` (verified)
- [x] All Task 1 source acceptance criteria pass (def + spec for both functions, EventNotification.from_map usage, webhook_verify_span count >= 2, alias EventNotification, raise SignatureVerificationError count >= 2)
- [x] All Task 2 source acceptance criteria pass (describe blocks present, 4 verify atoms asserted, assert_raise SignatureVerificationError in bang block, ISO 8601 created assertion present, "v2.core.event" object assertion present)
- [x] `mix compile --warnings-as-errors` exits 0 (verified)
- [x] `mix test test/lattice_stripe/webhook_test.exs` exits 0 — 39 tests pass (verified)
- [x] Full suite `mix test` exits 0 — 1963 tests, 0 failures (verified — no regression from Wave 1 baseline)
- [x] No accidental file deletions (`git diff --diff-filter=D --name-only HEAD~2 HEAD` returned empty)
- [x] No untracked files left behind

## Continuation Note

THIN-01 fully landed. Adopters can now call `Webhook.parse_event_notification/3` (the 4-arg with default opts) and pattern-match `id`/`type`/`created`/`context`/`livemode`/`related_object` on `%EventNotification{}` — the ROADMAP success criterion #1 for Phase 47. The bang variant `parse_event_notification!/4` is also shipped for adopters who prefer `try/rescue` flow control. Plans 47-04 (fetchers) and 47-05 (Testing helpers) can now compose on top of this typed boundary.
