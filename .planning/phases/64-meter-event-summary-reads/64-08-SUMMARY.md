---
phase: 64-meter-event-summary-reads
plan: 08
subsystem: docs
tags: [metering, webhooks, thin-events, exdoc, scope, meter-error-report]

# Dependency graph
requires:
  - phase: 64-04
    provides: "MeterErrorReport + .Reason/.ErrorType/.SampleError and from_event/1 — the modules the rewritten handler calls"
  - phase: 64-07
    provides: "guides/metering.md's 'The payload contract' and 'Reconciliation via webhooks' sections — the cross-reference targets"
provides:
  - "guides/metering-runtime-and-reconciliation.md: a working error-report handler (fetch → decode → enqueue), replacing one wrong three independent ways"
  - "guides/scope.md: the dimensions-are-write-only limit under 'Deferred by design', with both workarounds named"
  - "guides/scope.md: the ../README.md adopter-docs link repaired at its cause, clearing 2 of the 40 baseline ExDoc warnings"
  - "LatticeStripe.Billing.MeterEvent.create/3 @doc: the payload bullet now admits arbitrary custom dimension keys and states the decimal-string rule"
affects: [64-10, phase-close, metering docs, ship gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Asymmetric doc placement: full treatment in the guide, one corrected sentence plus a pointer in the @doc (D-25)"
    - "Answer an ExDoc warning by fixing its cause, not by widening the tolerance (D-29 / STATE [63-07])"

key-files:
  created: []
  modified:
    - guides/metering-runtime-and-reconciliation.md
    - guides/scope.md
    - lib/lattice_stripe/billing/meter_event.ex
    - .planning/ROADMAP.md

key-decisions:
  - "The @doc pointer to the payload contract is a backticked path plus section name in prose, not a markdown link — matching the file's existing warning-free convention for the 'Reconciliation via webhooks' pointer, and avoiding any ExDoc link-resolution risk from a moduledoc base path"
  - "The rewritten handler drops @behaviour LatticeStripe.Webhook.Handler entirely: that behaviour's handle_event/1 takes a %LatticeStripe.Event{} (a v1 snapshot event), which is precisely the wrong shape for a v2 thin event and was one of the three original defects"
  - "The runtime guide's handler enqueues on the meter id and the validation window only; the per-sample-error walk stays in metering.md, cross-referenced rather than duplicated"

patterns-established:
  - "Cross-file guide anchors verified against generated HTML (doc/*.html) rather than an assumed slug rule"

requirements-completed: [MTR-03, MTR-04]

coverage:
  - id: D1
    description: "guides/metering-runtime-and-reconciliation.md's error-report handler rewritten to the working shape — notification match, Webhook.fetch_event/3, MeterErrorReport.from_event/1 — with the fetch marked mandatory"
    requirement: "MTR-03"
    verification:
      - kind: other
        ref: "grep -cF 'data[\"object\"]' guides/metering-runtime-and-reconciliation.md == 0; grep -cF 'error_report[\"id\"]' == 0; grep -c fetch_event >= 1; grep -c from_event >= 1"
        status: pass
      - kind: other
        ref: "mix run /tmp/scratch_handler.exs — snippet compiles against shipped modules and decodes a wire-shaped payload (meter, validation_start, validation_end, code, request_identifier all populate)"
        status: pass
    human_judgment: false
  - id: D2
    description: "That guide no longer reads an id off the error-report payload, because the payload has none (D-17)"
    requirement: "MTR-03"
    verification:
      - kind: other
        ref: "grep -cF 'error_report[\"id\"]' guides/metering-runtime-and-reconciliation.md == 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "guides/scope.md gains a 'Deferred by design' bullet stating that on the GA API usage cannot be read back grouped by a custom dimension, with both workarounds named (D-27)"
    requirement: "MTR-04"
    verification:
      - kind: other
        ref: "grep -ci dimension guides/scope.md == 5; grep -ci 'write surface' guides/scope.md == 0 (internal build fence not published)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs — 50 tests, 0 failures (scope.md structural assertions still green)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MeterEvent.create/3's @doc payload bullet amended from closed-set language to admit arbitrary custom dimension keys, plus the decimal-string rule and a pointer to the guide (D-24.3, D-25)"
    requirement: "MTR-04"
    verification:
      - kind: other
        ref: "Code.fetch_docs(LatticeStripe.Billing.MeterEvent) create/3 doc contains 'dimension' and 'strings**: a float'"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_test.exs — 10 tests, 0 failures"
        status: pass
      - kind: other
        ref: "git diff --numstat lib/lattice_stripe/billing/meter_event.ex — 10/3, single @doc hunk, no function body touched"
        status: pass
    human_judgment: false
  - id: D5
    description: "scope.md's adopter-docs link repaired at its cause so the plan's own zero-warnings-naming-either-guide gate is reachable (D-29)"
    verification:
      - kind: other
        ref: "grep -cF 'https://github.com/szTheory/lattice_stripe#readme' guides/scope.md == 1; mix docs warnings 40 -> 38, sorted-set diff shows exactly the two scope.md warnings cleared and nothing else"
        status: pass
    human_judgment: false
  - id: D6
    description: "Every cross-reference written into the guides resolves to a heading that exists"
    verification:
      - kind: other
        ref: "generated hrefs (doc/metering-runtime-and-reconciliation.html, doc/scope.html) -> metering.html#reconciliation-via-webhooks, metering.html#the-payload-contract; both ids present exactly once in doc/metering.html"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 08: Runtime-Guide Handler, Scope Limit, and the `@doc` Payload Bullet Summary

**Both shipped metering guides now teach a handler that actually works, the scope page states the dimensions-are-write-only limit that saves an adopter a week, and `MeterEvent.create/3`'s payload bullet no longer reads as a closed set — with the `scope.md` link repaired at its cause, dropping ExDoc warnings 40 → 38.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-28T20:29:00-04:00 (approx; wave-4 rebase + `mix deps.get`)
- **Completed:** 2026-07-28T20:34:13-04:00 (last task commit)
- **Tasks:** 2 of 2
- **Files modified:** 4 (3 source/docs + ROADMAP)

## Accomplishments

- **Replaced the second unworkable handler.** The snippet in `guides/metering-runtime-and-reconciliation.md` was wrong three independent ways at once: it declared `@behaviour LatticeStripe.Webhook.Handler` and pattern-matched `%LatticeStripe.Event{}` (a v1 snapshot event) for what is a **v2 thin event**; it read `event.data["object"]` from a body that carries no `data` member at all; and it then read `error_report["id"]` off a payload that has no `id` field. The replacement matches an `%EventNotification{}`, calls `Webhook.fetch_event(client, notif)` under a comment marking the step **NOT optional**, decodes with `MeterErrorReport.from_event/1`, and enqueues on `report.meter` plus the validation window.
- **Named the correlation key.** The paragraph about correlation metadata "paying for itself" now points at something real: `request_identifier` on each sample error, which *is* the HTTP idempotency key of the failing write — so a caller who lets the library auto-generate one has nothing to join against.
- **Added the dimension-read scope limit.** `guides/scope.md` states, under `## Deferred by design`, that on the GA API you cannot read usage back grouped by a custom dimension, with all four verifications and both workarounds (one meter per dimension value, or your own event store).
- **Repaired the `../README.md` link at its cause.** ExDoc resolves a relative documentation link from one extra only against the `extras` list, and the top-level readme is not in it (the changelog is). Swapped to the absolute canonical URL — the same shape the HexDocs link on that very line already uses.
- **Amended the `@doc` payload bullet.** It now states that the payload carries the customer-mapping key, the meter's configured value key, **plus any number of additional custom dimension keys**, which Stripe stores and this library passes through unfiltered — and that decimals go as strings because a float can reach the wire in scientific notation.

## Task Commits

1. **Task 1: Rewrite the second unworkable handler and add the dimension-read scope limit** — `c783e56` (docs)
2. **Task 2: Amend the payload bullet in `MeterEvent.create/3`'s `@doc`** — `5ec0e3a` (docs)

## Files Created/Modified

- `guides/metering-runtime-and-reconciliation.md` — handler rewritten to fetch → decode → enqueue; thin-event framing added above it; correlation paragraph extended with `request_identifier`; the bare-integer footgun bullet corrected to the float hazard.
- `guides/scope.md` — one new `## Deferred by design` bullet (dimension reads); `../README.md` link replaced with the absolute canonical URL.
- `lib/lattice_stripe/billing/meter_event.ex` — `create/3` `@doc` payload bullet only. No signature, arity, or function body change.
- `.planning/ROADMAP.md` — 64-08 checkbox ticked.

## Decisions Made

- **The `@doc` pointer is prose, not a markdown link.** `guides/metering.md` → "The payload contract" follows the convention already used two paragraphs down in the same `@doc` ("Reconciliation via webhooks"), which is warning-free at baseline. A markdown link from a moduledoc resolves against a different base than a guide-to-guide link, and the plan's own gate is zero warnings naming `meter_event.ex`; the prose form carries no resolution risk. Verified: `doc/LatticeStripe.Billing.MeterEvent.html` contains no `metering.html#...` href, and `meter_event.ex` names zero warnings.
- **Dropped the `Webhook.Handler` behaviour from the snippet.** Its `@callback handle_event(LatticeStripe.Event.t())` is genuinely the wrong contract for a thin-event notification; keeping the behaviour while fixing the body would have left the snippet still structurally wrong. The replacement is a plain two-arity function, matching `MeterErrorReport`'s moduledoc and `metering.md`.
- **Kept the runtime-guide handler short.** Per the plan, it enqueues on the meter id and window; the walk over `reason.error_types` / `sample_errors`, the error-code table and the remediation patterns stay in `metering.md` and are cross-referenced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected a false runtime footgun bullet contradicting `metering.md`**
- **Found during:** Task 1
- **Issue:** `guides/metering-runtime-and-reconciliation.md` carried the bullet "Do not emit bare integers when the meter expects a numeric string payload value." That is false and 64-07 had already retired the same claim from `metering.md`, whose payload-contract table now records `"value" => 5` as **"Safe on v1 — byte-identical to the string form."** The real hazard is floats (the exponent cliff at `0.00001`). Leaving it would have left the two shipped guides contradicting each other on a corrected fact — exactly the false-prose class this phase exists to eliminate — in a file this plan already owns.
- **Fix:** Rewrote the bullet to name the float hazard, noting parenthetically that a bare integer is fine on v1, with a cross-reference to `metering.md#the-payload-contract`.
- **Files modified:** `guides/metering-runtime-and-reconciliation.md`
- **Verification:** `mix test test/lattice_stripe/docs_truth_test.exs` green; `mix docs` warning count unchanged by this edit; claim checked against `guides/metering.md` lines 351-357 and 374-395.
- **Committed in:** `c783e56` (part of the Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 × Rule 1).
**Impact on plan:** Confined to a file already in `files_modified`, one bullet, doc-only. No scope creep; it removes a contradiction the plan's own success criteria would otherwise have shipped.

## Issues Encountered

- **The brief's `mix docs` gate of "exactly 40" is unsatisfiable jointly with this plan's mandated link repair.** Baseline at the base commit is 40 warnings, **2 of which are `guides/scope.md` "documentation references file `../README.md`"** (one per ExDoc pass). Task 1's acceptance criteria require both that `grep -cF 'https://github.com/szTheory/lattice_stripe#readme' guides/scope.md` return 1 **and** that zero warnings name `scope.md` — which necessarily clears those two. Final count is therefore **38**, satisfying the plan's stated ceiling (`no greater than 42`) and its zero-naming gate. A sorted-set diff of the warning output confirms **exactly** those two lines disappeared and nothing else moved; `webhook.ex:376` and the `Tax.*` hidden-type warnings are untouched and remain out of scope.
- **The brief's anchor guidance for `### Rule 4 — dimensions are write-only…` was wrong.** It stated a **double** hyphen (`rule-4--dimensions-…`). The rendered HTML is authoritative and shows a **single** hyphen: `<h3 id="rule-4-dimensions-are-write-only-on-the-generally-available-api">`. ExDoc/Earmark collapses the em-dash separator rather than emitting two hyphens. No link written by this plan used that anchor (both cross-references target `h2`-level anchors), so nothing was affected — but the correction is recorded so a later plan does not write the broken form on the brief's authority.
- **First scratch-script run reported `request_identifier=nil`** — a fault in the test fixture, not the library. Stripe nests the identifier one level deeper than the field it decodes into (`%{"request" => %{"identifier" => …}}`, per `SampleError`'s "Wire shape" moduledoc section). Corrected the fixture and the field populated. Worth noting because it is a trap for anyone hand-building a fixture from the struct's field names.
- **`deps/` was empty on spawn.** Ran `mix deps.get` (permitted by the brief). `git status --short mix.lock` is clean afterward — the lock is byte-identical, so no deviation.
- **The known `client_test.exs:912` retry-telemetry flake did not fire** in either full-suite run.

## Verification Results

| Gate | Result |
|---|---|
| `mix test` | **2305 tests, 0 failures, 1 skipped** (214 excluded) — matches the recorded baseline, exceeds the plan's `>= 2188` |
| `mix test test/lattice_stripe/docs_truth_test.exs` | 50 tests, 0 failures |
| `mix test test/lattice_stripe/billing/meter_event_test.exs` | 10 tests, 0 failures |
| `mix docs` | exit 0, **38 warnings** (baseline 40, −2 from the plan-mandated `scope.md` link repair) |
| Warnings naming `scope.md`, `metering-runtime`, `meter_event.ex` | **0** |
| `mix format --check-formatted` | exit 0 |
| `mix compile --force --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2294 mods/funs, **no issues** |
| Manual: snippet compiles against shipped modules | pass — `mix run /tmp/scratch_handler.exs`, all named fields populate from a wire-shaped payload |

**Cross-reference resolution (verified against generated HTML, not assumed):** the three links written by this plan render as `metering.html#reconciliation-via-webhooks` (runtime guide), `metering.html#the-payload-contract` (runtime guide and `scope.html`). Both target ids are present exactly once each in `doc/metering.html` (`<h2 id="reconciliation-via-webhooks">`, `<h2 id="the-payload-contract">`). The repaired readme link renders as `href="https://github.com/szTheory/lattice_stripe#readme"` in `doc/scope.html`.

## Known Stubs

None. No stub, placeholder, TODO, or skipped test was introduced.

## Threat Flags

None. No new network endpoint, auth path, file access pattern, or schema change — all three edits are documentation. T-64-08 (handler trusting webhook body data) and T-64-15 (closed-set `@doc` phrasing) are both mitigated as planned; T-64-17 (scope omission) is mitigated by the new bullet; T-64-SC stands accepted — zero packages installed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 64's documentation surface is complete. `64-10` owns VALIDATION step 4, the phase-wide differential warning count: **the recorded baseline it should compare against is now 38, not 40 or 42.** Wave 4's 64-09 took it 42 → 40; this plan takes it 40 → 38.
- Known pre-existing debt deliberately left alone: `guides/getting-started.md` carries the identical broken `../README.md` link (2 of the remaining 38 warnings). It is outside this plan's `files_modified` and no gate in this phase counts it — a one-line follow-up.
- No blockers.

## Self-Check: PASSED

- `guides/metering-runtime-and-reconciliation.md` — FOUND (modified, committed in `c783e56`)
- `guides/scope.md` — FOUND (modified, committed in `c783e56`)
- `lib/lattice_stripe/billing/meter_event.ex` — FOUND (modified, committed in `5ec0e3a`)
- `.planning/phases/64-meter-event-summary-reads/64-08-SUMMARY.md` — FOUND
- `.planning/ROADMAP.md` line 147 — 64-08 checkbox `[x]` — FOUND
- Commit `c783e56` — FOUND in git log
- Commit `5ec0e3a` — FOUND in git log

No claimed file or commit is missing.

---
*Phase: 64-meter-event-summary-reads*
*Completed: 2026-07-28*
