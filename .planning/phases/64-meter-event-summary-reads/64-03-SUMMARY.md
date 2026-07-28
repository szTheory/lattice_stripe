---
phase: 64-meter-event-summary-reads
plan: 03
subsystem: api
tags: [stripe, billing, metering, meter-event-summary, pagination, stream, exdoc, elixir, mox]

# Dependency graph
requires:
  - phase: 64-meter-event-summary-reads
    provides: "64-01's tracer slice — the MeterEventSummary module, its private path/1 and validate_id!/2, the seven-field struct, and the Metering.MeterEventSummary fixtures"
  - phase: 63-stripe-native-entitlements
    provides: "LatticeStripe.List.stream!/2 cursor state machine, Resource.unwrap_bang!/1, the guard-first stream! ordering, and the refute function_exported? surface-lock practice"
provides:
  - "LatticeStripe.Billing.MeterEventSummary.list!/2..4 — the bang twin, returning %Response{} directly and raising LatticeStripe.Error on failure (MTR-01)"
  - "LatticeStripe.Billing.MeterEventSummary.stream!/2..4 — lazy full-window auto-pagination by delegation to LatticeStripe.List.stream!/2 (MTR-02)"
  - "The complete moduledoc carrying F-02 (no customer field), F-08 (the exclusive/inclusive contradiction), F-09 (eventual consistency), and the limit-10 truncation trap with the total-versus-series fix"
  - "The D-31 refutation block — every deliberately-absent function locked at every exported arity"
  - "validate_id!/2's second argument now carries the caller's fun/arity spelling, giving D-08 its two message sets from one helper"
affects: [64-05-guard-04-window-alignment, 64-06-pagination-proof, 64-07-metering-guide, 64-08-docs-gate, 64-09-artifact-inventory]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guard-first stream!: every guard is the function's literal first statement, because Stream.resource/3 defers its start function and a lazily-constructed guard would raise pages away from the caller"
    - "One private validate_id!/2 serving two callers, its second argument carrying the caller's own fun/arity so each error message names the function actually invoked"
    - "Surface refutation at EVERY exported arity, not the top arity alone — two defaulted args would otherwise let a lower arity slip through"

key-files:
  created: []
  modified:
    - lib/lattice_stripe/billing/meter_event_summary.ex
    - test/lattice_stripe/billing/meter_event_summary_test.exs

key-decisions:
  - "validate_id!/2's previously-unused second argument was given meaning (the caller's fun/arity spelling) rather than left inert — this is what lets stream!/4 report stream!/4 while list/4's message stays byte-identical, satisfying D-08's two message sets without a second helper"
  - "The alignment moduledoc section states the rule and the library's refusal to snap, but does NOT claim a present-tense pre-network raise — that guard lands in 64-05, and the plan required a section that reads correctly both before and after it"
  - "No incidence figure for the misalignment trap anywhere in the file (D-12): the mechanism is verified, the frequency is not"
  - "Moduledoc code examples deliberately avoid any line beginning with `{:` — that exact shape is what produces the two pre-existing 'Illegal attributes ... ignored in IAL' warnings on meter_event_stream.ex"

patterns-established:
  - "Pattern 1: a resource module hands LatticeStripe.List correctly-shaped state and nothing else — the cursor, base-params preservation and idempotency-key strip are never re-grown per resource"
  - "Pattern 2: a call-time-raise assertion is written by calling the streaming function inside assert_raise WITHOUT consuming the result, so a deferred guard fails the test"
  - "Pattern 3: documented absences carry their reason inline in a ## Design section, so the next contributor meets the rationale before the temptation"

requirements-completed: [MTR-01, MTR-02]

coverage:
  - id: D1
    description: "MeterEventSummary.list!/4 returns the %Response{} directly rather than an {:ok, _} tuple, and raises LatticeStripe.Error when Stripe rejects the call"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#returns the %Response{} directly rather than an {:ok, _} tuple"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#raises LatticeStripe.Error when Stripe rejects the call"
        status: pass
    human_judgment: false
  - id: D2
    description: "MeterEventSummary.stream!/4 returns a lazy Enumerable that yields decoded %MeterEventSummary{} structs, delegating the cursor state machine to LatticeStripe.List.stream!/2"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#yields decoded %MeterEventSummary{} structs across a single page"
        status: pass
      - kind: other
        ref: "grep -c 'LatticeStripe.List.stream!' lib/lattice_stripe/billing/meter_event_summary.ex => 1"
        status: pass
    human_judgment: false
  - id: D3
    description: "stream!/4's guards are its literal first statements, so an invalid call raises ArgumentError at call time rather than on the first Enum step, with the stream!/4 spelling in all four messages"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#stream!/4 raises on a nil meter id at call time, before any Enum step"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#stream!/4 raises when customer is missing, at call time"
        status: pass
    human_judgment: false
  - id: D4
    description: "The public surface is exactly list/2..4, list!/2..4, stream!/2..4 and from_map/1; retrieve, create, update, delete, stream and align_window are refuted at every exported arity while list/2 and list/3 are deliberately NOT refuted"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#exports the shipped read surface at every defaulted arity"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#stream! has no non-bang twin — auto-pagination raises, it does not return tuples"
        status: pass
      - kind: other
        ref: "MeterEventSummary.__info__(:functions) => exactly from_map/1, list/2..4, list!/2..4, stream!/2..4"
        status: pass
    human_judgment: false
  - id: D5
    description: "The moduledoc carries the four facts an adopter cannot discover from the type signature — no customer field, the ambiguous window boundary, eventual consistency, and the limit-10 truncation trap with the total-versus-series fix"
    requirement: "MTR-01"
    verification:
      - kind: other
        ref: "Code.fetch_docs/1 contains 'eventually consistent', 'mtrusg_', 'value_grouping_window', '744', 'exclusive' and 'inclusive'"
        status: pass
      - kind: other
        ref: "mix docs => exit 0, 42 warnings (baseline), 0 naming meter_event_summary.ex"
        status: pass
    human_judgment: true
    rationale: "Prose quality — whether the four facts actually land for a reader meeting them cold on HexDocs — is not mechanically checkable. The substring assertions prove the facts are present, not that they are well said."

# Metrics
duration: 12min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 03: MeterEventSummary Stream, Bang Twin and Moduledoc Summary

**`stream!/4` completes MTR-02 by handing `LatticeStripe.List` correctly-shaped state and growing no cursor of its own, and the moduledoc now tells an adopter — before they write a line — that the result cannot say which customer it belongs to, that Stripe's own spec contradicts itself on the window's end, that the figure is not live, and that the default page size truncates a month of hourly data to 1.3% of the truth.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-28T23:31:00Z
- **Completed:** 2026-07-28T23:43:11Z
- **Tasks:** 2 of 2
- **Files modified:** 2

## Accomplishments

- **`stream!/2..4` ships MTR-02 in full.** It builds a `%Request{}` from the shared private `path/1` and pipes it into `LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)`. The cursor, `base_params` preservation and the page-fetch idempotency-key strip are all `LatticeStripe.List`'s, unmodified — confirmed structurally: the module contains no `Stream.resource`, no `has_more` handling, no `_last_id` and no cursor assembly. This works only because the summary carries a required top-level `id` (F-01), which is what `List` matches on.
- **All four `stream!/4` guards are the function's literal first statements**, and each names `stream!/4` rather than `list/4`. Proven by calling `stream!/4` inside `assert_raise` **without consuming the returned stream** — a guard placed anywhere but first would defer through `Stream.resource/3` and the test would fail. No Mox expectation is set in any of those tests, so `verify_on_exit!` additionally proves nothing reached the transport.
- **`list!/2..4` added** as a defaults header piping `list/4` into `Resource.unwrap_bang!/1`, matching `transfer_reversal.ex:246-250` exactly.
- **The D-31 refutation block landed** with `stream` refuted at arities 1, 2 **and** 3 — not the top arity alone, which is the trap Phase 63 recorded in STATE `[63-02]` for functions with two defaulted arguments. `align_window/2` is refuted with an inline comment recording that this encodes the D-10 rejection structurally. `list`, `list!` and `stream!` at arities 2, 3 and 4 are **asserted**, with a comment stating that refuting them would be incorrect (D-31's explicit warning).
- **The moduledoc was replaced with the full treatment**: a warning admonition pairing F-02 and F-09, a `## The window boundary is ambiguous` section that names both readings and asserts neither, a `## Listing` section quantifying the 744-bucket trap and teaching the total-versus-series split, a `## Timestamp alignment` section, and a `## Design` section naming three absences with the reason for each.
- **The public surface is exactly what D-07 specifies.** `__info__(:functions)` returns `from_map/1`, `list/2..4`, `list!/2..4`, `stream!/2..4` and the two struct callbacks. Nothing else.

## Key Decisions

### `validate_id!/2`'s second argument was given meaning rather than left inert

64-01 shipped `validate_id!/2` with an unused `_name` argument and a message hardcoded to `list/4`, explicitly so that this plan's `stream!/4` would have a helper to call. But this plan requires the `stream!/4` spelling in **all four** of `stream!/4`'s messages (D-08 specifies two message sets), and a hardcoded `list/4` message cannot deliver that.

Resolution: the second argument now carries the caller's own `fun/arity` string and is interpolated into the message. The helper stays at **arity 2** as 64-01 intended and as the inherited context requires; `list/4`'s message is byte-identical to before (its five existing guard tests pass unchanged); and `stream!/4` gets its own message set from the same one helper rather than a duplicated second one. The source comment was updated to state this, replacing 64-01's note that "the message stays fixed."

### The alignment section does not claim a raise that does not exist yet

The plan's action text asks the `## Timestamp alignment` section to state "that this library raises before the network rather than aligning silently" — but the GUARD-04 raise lands in **64-05**, not here. The same paragraph also instructs: "write this section so it reads correctly both before and after that plan."

Those two instructions conflict for the duration of one wave. Shipping present-tense prose describing unimplemented behavior is precisely the "the prose says something false" failure mode D-26 exists to prevent, and it is what made `guides/metering.md` pitfall #4 wrong for four minor versions. So the section states the alignment rule, states that the natural inputs violate it, and states in bold that **this library will not align them for you** — with the floor/ceil arithmetic and the `Integer.floor_div/2` rationale. Every sentence is true today and stays true after 64-05 lands the guard, which then simply enforces the stance already documented.

**Handoff to 64-05:** the raise sentence is yours to add. The section is written to receive it without restructuring.

### Moduledoc examples avoid any line starting with `{:`

D-29's two known metering warnings (`meter_event_stream.ex:15` and `:24`) are `Illegal attributes ... ignored in IAL`, and the baseline output shows their exact cause: a code-block line beginning `{:ok, session} = ...`. Earmark parses the leading brace group as an inline attribute list. The total-versus-series examples therefore bind `resp` and destructure on the next line rather than opening with `{:ok, ...}`. `mix docs` reports zero warnings naming this file.

## Deviations from Plan

### 1. [Rule 3 - Blocking] `deps/` was absent in a fresh worktree

- **Found during:** pre-flight baseline run, before Task 1
- **Issue:** `mix test` refused to run — twelve dependencies "not available".
- **Fix:** ran `mix deps.get`, which the phase gates explicitly permit when `deps/` is missing.
- **`mix.lock` is byte-identical afterward.** SHA-256 `508562a3cd1f8dbd98726bead3a5172ed3080e6f59f0c1acbc58da702ab40b48` before and after; `git status --short mix.lock` reports no change. No dependency was added, updated or substituted.
- **Files modified:** none

### 2. [Documented judgment] Task 1 acceptance criterion 9 is met in intent, not by its literal grep

- **Criterion:** ``grep -v '^\s*#' lib/lattice_stripe/billing/meter_event_summary.ex | grep -c 'starting_after'`` returns 0, *"proving no bespoke cursor loop was grown."*
- **Actual:** it returns **1**.
- **Why:** the single non-comment occurrence is at line 95, inside 64-01's `@doc` for `list/4`: *"Also supports Stripe's `limit` (default **10**, max 100) and `starting_after` / `ending_before` cursors."* That is documentation naming Stripe's own query parameters, not a cursor loop. `grep -v '^\s*#'` strips comment lines but not `@doc` heredocs, and the criterion was written before 64-01 shipped that line.
- **The criterion's stated purpose is satisfied, and was verified directly instead:** the module contains no `Stream.resource`, no `has_more` handling, no `_last_id`, no `ending_before` handling and no page-assembly code. Every occurrence of those terms in the file is prose or comment. `grep -c 'LatticeStripe.List.stream!'` returns 1 — the delegation is the only pagination mechanism present.
- **Why the doc line was not deleted to satisfy the grep:** naming the exact wire parameter is house doctrine (Phase 63 D-08, *name after the exact wire field*), and it is the string an adopter greps for. Degrading correct documentation to satisfy a grep whose purpose is already met would be the wrong trade — and D-26 makes the general point that greps over prose are the weaker instrument.
- **Suggested for 64-08/64-09:** if this grep is carried into the phase-wide gate, scope it to exclude `@doc`/`@moduledoc` bodies, or replace it with the structural check above.

No other deviations. No auto-fixed bugs, no architectural changes, no authentication gates.

## Verification

All gates run at the final commit `d7c33a4`. `mix ci` was **not** run — per the phase gates it is red at clean HEAD on 42 pre-existing ExDoc warnings.

| Gate | Result |
|------|--------|
| `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | 32 tests, 0 failures |
| `mix test` | **2233 tests, 0 failures, 1 skipped** (204 excluded) — baseline was 2220; threshold was >= 2188 |
| `mix format --check-formatted` | exit 0 |
| `mix compile --force --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2241 mods/funs, **no issues** |
| `mix docs` | exit 0, **42 warnings** (== baseline, never up), **0** naming `meter_event_summary.ex` |
| `grep -c 'incidence\|100% of\|always fails'` on the module | 0 |

The pre-existing retry-telemetry flake at `test/lattice_stripe/client_test.exs:912` did not fire in any of the three full-suite runs.

### Success criteria

- [x] The public surface is exactly `list/2..4`, `list!/2..4`, `stream!/2..4`, `from_map/1` — verified against `__info__(:functions)`.
- [x] Every deliberately-absent function is refuted at every exported arity, and `list/2`/`list/3` are not refuted.
- [x] `stream!/4` raises at call time, proven without consuming the stream.
- [x] The moduledoc carries F-02, F-08, F-09 and the truncation trap, and states no incidence figure.

## Known Stubs

None. No placeholder values, no TODO/FIXME, no skipped tests were introduced. The one skipped test in the suite is pre-existing and unrelated.

## Threat Flags

None. This plan added no new network endpoint, auth path, file access pattern or schema change. `stream!/4` reaches the same single `GET` path `list/4` already used, through the same shared private `path/1`.

T-64-01 is mitigated as planned: `validate_id!/2` is `stream!/4`'s first statement, asserted by two call-time-raise tests. T-64-02 and T-64-03 are mitigated **by delegation** — `stream!/4` re-implements none of `List.build_next_page_request/1`, so `opts` (carrying `stripe-account`) and `base_params` (carrying `customer`) survive to page 2 by construction; 64-06 owns the assertions. T-64-07 is addressed by the moduledoc's cross-reference to `LatticeStripe.List`'s memory guidance and its `Stream.take/2` pointer. T-64-SC holds: zero packages installed, `mix.lock` byte-identical.

## For Next Phase

- **64-05 (GUARD-04)** — the `## Timestamp alignment` moduledoc section is written and awaits its raise sentence; the guard belongs between the `require_param!` block and `%Request{}` in **both** `list/4` and `stream!/4` now, since `stream!/4` exists. Note it will need its own message set: `stream!/4`'s guards already use the `stream!/4` spelling, and `validate_id!/2`'s second argument shows the mechanism for carrying it.
- **64-06 (pagination proof)** — `stream!/4` is live and delegating; all nine D-30 assertions are now writable. The cursor derives from the `mtrusg_` top-level id.
- **64-08 (docs gate)** — the `mix docs` baseline is unchanged at 42, and the IAL warning cause is now pinned exactly: a code-block line beginning `{:`. The two `meter_event_stream.ex` warnings D-29 offers to clear are at lines 15 and 24 and are that exact shape.
- **64-09 (artifact inventory)** — see deviation 2 above before carrying the `starting_after` grep into a phase-wide gate.

## Self-Check: PASSED

- `lib/lattice_stripe/billing/meter_event_summary.ex` — FOUND
- `test/lattice_stripe/billing/meter_event_summary_test.exs` — FOUND
- `.planning/phases/64-meter-event-summary-reads/64-03-SUMMARY.md` — FOUND
- Commit `4e03228` (test/RED) — FOUND
- Commit `0ebb1da` (feat/GREEN) — FOUND
- Commit `d7c33a4` (docs) — FOUND

## TDD Gate Compliance

Task 1 ran the full cycle and the gate sequence is present in git log in order: `test(64-03)` at `4e03228` (RED — 9 failures, all `UndefinedFunctionError` on the not-yet-written functions), then `feat(64-03)` at `0ebb1da` (GREEN — 32 tests, 0 failures). No REFACTOR commit: the implementation needed no cleanup, and an empty refactor commit would be noise. No test passed unexpectedly during RED — the four surface-refutation tests that were green at RED are `refute function_exported?` assertions, which correctly hold both before and after the implementation lands and are not gated behavior.
