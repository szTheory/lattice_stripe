---
phase: 64-meter-event-summary-reads
plan: 10
type: execute
wave: 6
status: complete
autonomous: false
requirements: [MTR-01, MTR-02, MTR-03, MTR-04]
completed: 2026-07-28
---

# 64-10 — D-29 Differential Phase Gate

Verification and recording only. This plan produced no code, no documentation, and no files
beyond this summary and the status update to `64-VALIDATION.md`.

Gate run at `3c52d54` (Waves 1–5 all merged, working tree clean).

## Why the differential gate, and not `mix ci`

`mix ci` was **not** run as the gate, per D-29 and the explicit prohibition in this plan.

Its steps are `format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`,
`test`, and `docs --warnings-as-errors`. The final step is **RED at clean HEAD** on ExDoc
warnings that predate this phase and belong to unrelated modules (`Tax.*` hidden types,
`webhook.ex:376`, `guides/recipes.md`'s `File.create/3`). Running it would have produced a red
result carrying no information about Phase 64. Steps 1–4 were run individually below; step 5
was deliberately replaced by the differential comparison.

Note that CI's own Quality lane runs plain `mix docs` (`ci.yml:254`), **not**
`--warnings-as-errors` — so the aggregate alias is stricter than the pipeline it is named for.

## The five steps

| # | Step | Command | Result |
|---|------|---------|--------|
| 1 | Format | `mix format --check-formatted` | exit **0** |
| 1 | Compile | `mix compile --warnings-as-errors` | exit **0** |
| 2 | Lint | `mix credo --strict` | exit **0** — 2294 mods/funs, **no issues** |
| 3 | Tests | `mix test` | **2305 tests, 0 failures, 1 skipped** (214 excluded) — floor 2188, and **up** from it, not down |
| 4 | Docs build | `mix docs` | exit **0**, **38 warnings** — ≤ baseline, never up |
| 5 | Metering-scoped docs | `mix docs 2>&1 \| grep -ci meter` | **0** |

Step 5 was left as the plain `meter` substring. It was not rescoped to an enumerated path
list, and no fallback branch was added.

### On the step-4 baseline: it moved twice this phase, downward both times

The number recorded during planning was **42**. It is now **38**, and both decrements were
required by plan acceptance criteria rather than incidental:

| Point | Count | Cause |
|-------|-------|-------|
| Phase start (`a22e197`) | 42 | pre-existing debt |
| After 64-09 | 40 | cleared both *"Illegal attributes … ignored in IAL"* warnings at `meter_event_stream.ex:15` and `:24` — the cause was pinned by 64-03 as a code-block line beginning `{:`. This clearing is what lets step 5 be a single substring check. |
| After 64-08 (final) | 38 | repairing `guides/scope.md`'s absolute `../README.md` link necessarily cleared its two warnings (one per ExDoc pass) — required by that plan's "zero warnings naming `scope.md`" criterion |

The baseline was **never raised to make a step pass**. Every movement was downward and
demanded by a stated criterion. 64-08 verified via a sorted-set diff that exactly those two
lines were removed and nothing else shifted.

**The next phase's differential gate must use 38**, not the 42 that still appears in older
planning prose.

## Confirmations outside the five steps

| Check | Result |
|-------|--------|
| `mix.lock` unchanged **since pre-phase** (`a22e197`) | clean — zero dependencies added |
| `lib/lattice_stripe/object_types.ex` unchanged **since pre-phase** | clean — that file is Phase 65's |
| Integration suite genuinely executed | `mix test --only integration test/integration/meter_event_summary_integration_test.exs` → **10 tests, 0 failures, 0 excluded** |

The plan's own acceptance command for the first two was `git diff --quiet mix.lock`, which
compares the working tree to HEAD and is trivially true after any commit. The claim being made
is that the files are unchanged *across the phase*, so both were additionally diffed against
the pre-phase commit `a22e197`. Both pass at that stronger reading.

The integration suite was re-run here against a live stripe-mock (probed **200** before the
run) rather than inferred from 64-09's record. A green default `mix test` is **not** evidence:
it excludes 214 tests, and 10 of those are precisely this suite.

## Requirement coverage

Every requirement binds to at least one green automated command.

| Requirement | Command(s) | Result |
|---|---|---|
| **MTR-01** | `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | 32 tests, 0 failures |
| | `mix test test/lattice_stripe/billing/meter_guards_test.exs` | 33 tests, 0 failures |
| | `mix test test/lattice_stripe/billing/guards_test.exs` | 18 tests, 0 failures |
| | `mix test test/lattice_stripe/billing/meter_test.exs` | 31 tests, 0 failures |
| | `mix test --only integration test/integration/…` | 10 tests, 0 failures |
| **MTR-02** | `mix test test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` | 15 tests, 0 failures |
| **MTR-03** | `mix test test/lattice_stripe/billing/meter_error_report_test.exs` | 29 tests, 0 failures |
| | `mix test test/lattice_stripe/object_types_test.exs` | 30 tests, 0 failures |
| **MTR-04** | `mix test test/lattice_stripe/form_encoder_test.exs` | 36 tests, 0 failures |
| | `mix test test/lattice_stripe/billing/meter_event_test.exs` | 10 tests, 0 failures |
| | `mix test test/lattice_stripe/docs_truth_test.exs` | 50 tests, 0 failures |
| | `mix test --only integration test/integration/…` (nested-payload 400) | 10 tests, 0 failures |

All eleven files named in `64-VALIDATION.md`'s map exist. 25 status cells moved from
`⬜ pending` to `✅ green`.

## HexDocs publication

All five new modules publish under the **Billing Metering** group, confirmed by parsing
`doc/dist/sidebar_items-AB3D2A87.js` rather than by assuming the `mix.exs` config took effect:

- `LatticeStripe.Billing.MeterEventSummary`
- `LatticeStripe.Billing.MeterErrorReport`
- `LatticeStripe.Billing.MeterErrorReport.Reason`
- `LatticeStripe.Billing.MeterErrorReport.ErrorType`
- `LatticeStripe.Billing.MeterErrorReport.SampleError`

## Carried forward

- **A pre-existing flake**, not introduced by this phase and not fixed by it:
  `test/lattice_stripe/client_test.exs:912` asserts `metadata.attempts == 2` on retry telemetry
  and intermittently reads `1` — reproduced twice across ~145 runs by 64-02, suspected to be a
  globally-attached `:telemetry` handler in an `async: true` test catching another test's stop
  event. Logged in `deferred-items.md`. It did not fire during this gate.
- **`guides/getting-started.md` carries the identical broken `../README.md` link** that 64-08
  repaired in `scope.md` (2 of the remaining 38 warnings). Out of that plan's `files_modified`;
  a one-line follow-up.
- **The anchor form in 64-07's report was wrong** and is corrected here for anyone linking to
  it later: the Rule 4 heading renders as
  `rule-4-dimensions-are-write-only-on-the-generally-available-api` — **single** hyphen. Earmark
  collapses the em-dash separator. Verified against generated HTML by 64-08 and independently
  re-checked against `doc/metering.html`.
- **Eight edge questions remain deliberately unresolved** (recorded in this plan's
  `planner_assumptions_surfaced`), including whether `end_time` is inclusive or exclusive —
  Stripe's own spec contradicts itself, and neither reading is asserted anywhere in shipped code
  or prose. Each shipped sentence was chosen to stay true under every possible answer. If any is
  later settled by a live probe, the correct response is an additive change, not a retrofit.

## Task 2 — operator sign-off

**Status: APPROVED** by the operator on 2026-07-28, resume-signal `"approved"`, no issues raised.

Task 2 is a `checkpoint:human-verify` gate and was not self-signed.
The automated half of it is green (`mix docs` exits 0;
`doc/LatticeStripe.Billing.MeterEventSummary.html`, `doc/metering.html` and `doc/scope.html`
all exist), and the objective claims above are verified — but the seven-step walkthrough is an
operator judgment call and is recorded as outstanding.

Per this plan: if the operator reports an issue it is to be recorded verbatim and routed to a
follow-up plan or quick task — **not** fixed inside this plan, because a gate plan that also
changes code cannot honestly report on itself.

### Pre-verification of the seven steps

Each step's objectively checkable content was verified against the built artifacts, so the
operator is confirming a checked claim rather than an unchecked one. This does **not** substitute
for the sign-off.

| Step | Objective check | Result |
|---|---|---|
| 1 | `MeterEventSummary` in sidebar group, admonition present | group `Billing Metering` (parsed from `sidebar_items-AB3D2A87.js`); 2 admonition blocks; "eventually consistent" present |
| 2 | "Reading usage back" exists; total-vs-series taught first | heading present; `A total, or a series` is its first subsection |
| 3 | ten codes; three labelled unverified; handler opens with a fetch | **10** code rows; **3** `(unverified)`; `fetch_event` present; retired `meter_event_value_not_found` **absent (0)** |
| 4 | guard raises naming value, rule, cause, floor **and** ceil | verified by live probe — see below |
| 5 | gate results | recorded above, all five green |
| 6 | integration explicit, 0 excluded | re-run here: 10 tests, 0 failures, 0 excluded |
| 7 | dimension-read limit present; build fence absent | "Deferred by design" present, dimensions covered; build-fence language (`no new metering write`, `Billing.Meter.event_summaries`, `MTR-0*`) **absent** |

Step 4's probe, run via `mix run` against a client with a throwaway key (the guard raises
pre-network, so no live credential is involved) — `start_time` deliberately off-by-one second:

```
RAISED ArgumentError:
LatticeStripe.Billing.MeterEventSummary.list/4: start_time 1753660801 is not aligned to a UTC
day boundary (00:00 UTC). Stripe requires day-aligned timestamps when value_grouping_window is
"day", and rejects unaligned values with HTTP 400.

Subscription current_period_start/current_period_end derive from billing_cycle_anchor and are
almost never aligned. Align them yourself — this library will not choose floor vs. ceil for you,
because that choice changes which usage the window includes:

    start_time = Integer.floor_div(start_time, 86400) * 86400   # floor
    end_time   = -Integer.floor_div(-end_time, 86400) * 86400   # ceil
```

All four required elements are present: the offending value, the rule, the
`billing_cycle_anchor` cause, and both expressions.

**What remains genuinely subjective** and is the operator's to judge: step 2's requirement that
the two Phase 65 stubs "read as real prose rather than placeholders," and the overall quality of
the rewritten sections.

### CI

PR [#46](https://github.com/szTheory/lattice_stripe/pull/46) (draft). All 12 checks green,
including `ci-gate`, `Integration Tests`, `Docs Truth`, `Quality`, and the test matrix across
Elixir 1.15/OTP 26, 1.17/OTP 27 and 1.19/OTP 28.
