# Phase 13: Billing Test Clocks — Plan Summary

**Created:** 2026-04-12
**Planner:** gsd-planner (standard mode)
**Source:** 13-CONTEXT.md (14 locked decisions + 7 research amendments), 13-RESEARCH.md (9-question codebase audit)
**Plan count:** 7 plans across 4 waves
**Total tasks:** 18 tasks
**Autonomous:** all plans are `autonomous: true` (no human-verify checkpoints — the `:real_stripe` tier is gated by env var, not a user prompt)

## Wave structure

| Wave | Plans | Parallelizable? | Rationale |
|------|-------|-----------------|-----------|
| **0** | 13-01 | N/A (single plan) | Scaffolds & prerequisites (Error whitelist, Client :idempotency_key_prefix, TestHelpers→TestSupport rename, :real_stripe exclusion, test stubs, CONVENTIONS.md, CONTRIBUTING.md, .gitignore) |
| **1** | 13-02, 13-03, 13-04 | Sequential (02→03→04) | 02 = TestClock struct + from_map + A-13g metadata probe. 03 = CRUD layered on the struct. 04 = advance + advance_and_wait layered on CRUD. Could not cleanly parallelize because each plan extends the same `test_clock.ex` file. |
| **2** | 13-05 | N/A (single plan) | Testing.TestClock helper library + Owner GenServer + Mix task. Depends on 02-04 public API. This is the largest plan by LOC and DX surface. |
| **3** | 13-06, 13-07 | Parallelizable | 06 = RealStripeCase + canonical `:real_stripe` test. 07 = docs/CHANGELOG/quality gates. No shared files; run in parallel if reviewer bandwidth allows, otherwise serial 06→07 for clarity. |

Total waves: 4. Plans ship in strict topological order within each wave.

## Plans

| Plan | Wave | Tasks | Depends | Requirements | Scope |
|------|------|-------|---------|--------------|-------|
| [13-01-PLAN.md](13-01-PLAN.md) | 0 | 5 | — | foundational (all 5) | Extend `Error` type whitelist (A-13c), add `:idempotency_key_prefix` to `Config`/`Client` (A-13client, 3 files), rename `TestHelpers`→`TestSupport` (A-13support), update `test/test_helper.exs` `:real_stripe` exclusion (A-13i), create 3 pending test stubs, create `.planning/CONVENTIONS.md`, extend `CONTRIBUTING.md` with direnv section, add `.envrc` to `.gitignore` |
| [13-02-PLAN.md](13-02-PLAN.md) | 1 | 2 | 01 | BILL-08 | A-13g metadata probe task + `LatticeStripe.TestHelpers.TestClock` struct, `defstruct`, `@type t`, `@known_fields`, `from_map/1`, `atomize_status/1` (D-03), `@moduledoc` with probe result. NO CRUD or advance yet. |
| [13-03-PLAN.md](13-03-PLAN.md) | 1 | 2 | 01, 02 | BILL-08 | `create/2`, `retrieve/3`, `list/3`, `stream!/3`, `delete/3` + bang variants via `Resource.unwrap_*` pipeline. Stripe-mock CRUD integration test (no polling assertions per Pitfall 4). Explicit absence: no `update/3`, no `search/3`. |
| [13-04-PLAN.md](13-04-PLAN.md) | 1 | 2 | 01, 02, 03 | BILL-08, BILL-08b, BILL-08c | `advance/4` endpoint wrapper + `advance_and_wait/4` + `advance_and_wait!/4` + private `poll_until_ready/9` poll loop (A-13b: `max(500, :rand.uniform(delay))`, monotonic deadline, zero-delay first poll, 60s default timeout, exponential backoff 500→5000ms ×1.5) + `:telemetry.span/3`. Mox unit tests cover all 4 branches: happy / polling / timeout / internal_failure. Telemetry attach-and-assert tests. |
| [13-05-PLAN.md](13-05-PLAN.md) | 2 | 3 | 01, 02, 03, 04 | BILL-08c, TEST-09, TEST-10 | `LatticeStripe.Testing.TestClock` `use`-macro with compile-time `:client` validation (D-13d) + `test_clock/1` + `advance/2` (A-13d unit parser: seconds/minutes/hours/days/to only; months/years raise) + `freeze/1` + `create_customer/3` (D-13h) + `with_test_clock/1` + `@cleanup_marker` + 50-key metadata guard + `TestClockError` + `Owner` GenServer (`start_owner!`, `on_exit` per Ecto.Sandbox) + `TestHelpers.TestClock.cleanup_tagged/2` shared deletion core + `mix lattice_stripe.test_clock.cleanup` Mix task (safe-by-default with `--dry-run true` + `--yes false`). |
| [13-06-PLAN.md](13-06-PLAN.md) | 3 | 2 | 01, 02, 03, 04, 05 | TEST-10 | `LatticeStripe.Testing.RealStripeCase` CaseTemplate in `test/support/real_stripe_case.ex` (internal only) with D-13i safety gate: skip-local / flunk-CI / flunk-live-key / build-client-on-test-key. Canonical first `:real_stripe` test in `test/real_stripe/test_clock_real_stripe_test.exs` — create clock, advance 30 days, assert ready, assert marker, delete, assert cascading delete. Replaces Plan 01 stub. |
| [13-07-PLAN.md](13-07-PLAN.md) | 3 | 2 | 01-05 (and 06 for visibility) | polish / docs | Update `mix.exs` `groups_for_modules` for ExDoc, verify/extend moduledocs (ensure D-13d canonical example is verbatim in `Testing.TestClock`), add CHANGELOG.md `[Unreleased]` entry, run quality gates (`mix format --check-formatted`, `mix credo --strict`, `mix compile --warnings-as-errors`, `mix docs --warnings-as-errors`, `mix test --exclude integration`). Merge-gate. |

## Requirement → Plan coverage matrix

Every requirement from Phase 13's ROADMAP row appears in at least one plan's `requirements` frontmatter. Full delivery (not v1/partial):

| Requirement | Plan(s) | Delivery |
|-------------|---------|----------|
| **BILL-08** (TestClock CRUD + advance) | 02, 03, 04 | Full: struct in 02, CRUD in 03, advance in 04 |
| **BILL-08b** (`advance_and_wait/3` w/ timeout, struct error) | 04 | Full: poll loop + monotonic deadline + typed `%Error{}` w/ `:raw_body` context (A-13c) |
| **BILL-08c** (`Testing.TestClock` user-facing helper) | 04 (advance_and_wait! bang variant), 05 (the helper library) | Full |
| **TEST-09** (ExUnit CaseTemplate / helper coordinating fixtures w/ auto-cleanup) | 05 | Full: use-macro + Owner cleanup + create_customer wrapper + with_test_clock setup |
| **TEST-10** (Mix task backstop + `:real_stripe` tier with first test) | 05 (Mix task), 06 (RealStripeCase + canonical test) | Full |
| **Phase success criterion 4** (first `:real_stripe` test) | 06 | Full |

## CONTEXT decision → Plan coverage

All 14 locked decisions + 7 research amendments mapped to plans. Zero decisions are silently simplified — every locked decision ships at full fidelity.

| Decision / Amendment | Plan(s) | How addressed |
|----------------------|---------|---------------|
| **D-13a** (naming — `TestHelpers.TestClock`, `Testing.TestClock`, CONVENTIONS.md) | 01 (CONVENTIONS.md), 02 (TestHelpers.TestClock module), 05 (Testing.TestClock module) | Full |
| **A-13a** (Checkout is the existing nested precedent, not Phase 13) | 01 (CONVENTIONS.md text) | Full |
| **D-13b** (polling: 500/1.5/5000 exponential + zero-delay first + monotonic deadline + 500ms floor non-negotiable) | 04 | Full, with A-13b floor fix |
| **A-13b** (`max(500, :rand.uniform(delay))` — floor wins over jitter) | 04 | Full |
| **D-13c** (struct error implementing Exception; `:test_clock_timeout` / `:test_clock_failed`; bang variant) | 01 (Error whitelist), 04 (construction + bang) | Full |
| **A-13c** (no `:details` field — reuse `:raw_body` map) | 01 (no schema change), 04 (raw_body construction) | Full |
| **D-13d** (use-macro + compile-time `:client` + imported surface + per-call override + canonical example) | 05 | Full |
| **A-13d** (v1: seconds/minutes/hours/days/to only; months/years raise) | 05 (unit parser) | Full |
| **D-13e** (narrow scope: only clock lifecycle + advance + 1 customer wrapper) | 05 (explicit helper surface; no factories) | Full |
| **D-13f** (Owner via `start_owner!` + `on_exit`; Mix task backstop; shared `cleanup_tagged/2` core) | 05 (Owner + Mix task + cleanup_tagged) | Full |
| **D-13g** (`@cleanup_marker {"lattice_stripe_test_clock", "v1"}` + 50-key guard + mixed-version matching in Mix task) | 05 (marker merge + guard + version-agnostic matcher) | Full — conditional on A-13g probe |
| **A-13g** (metadata probe task in Plan 02; fallback if unsupported) | 02 (probe Task 1), 05 (fallback path in moduledoc if probe fails) | Full — Plan 02 Task 1 resolves the ambiguity |
| **D-13h** (`create_customer/3` auto-injects `test_clock:`; document direct-call bypass) | 05 | Full |
| **D-13i** (`:real_stripe` tag; CaseTemplate w/ setup_all gate; per-test idempotency prefix; canonical first test) | 01 (tag exclusion), 06 (CaseTemplate + canonical test) | Full |
| **A-13i** (no `mix.exs` `test_paths` change — default covers `test/real_stripe/`) | 01 (only `test_helper.exs` updated) | Full |
| **D-13j** (env var only; direnv + .envrc; .gitignore; CI secret) | 01 (CONTRIBUTING.md + .gitignore) | Full |
| **A-13support** (rename `TestHelpers`→`TestSupport`) | 01 (rename task) | Full |
| **A-13client** (`:idempotency_key_prefix` — 3-file Config/Client/resolve change) | 01 (task 2) | Full |

**No decision is marked Partial. No PHASE SPLIT RECOMMENDED — all 21 constraints fit within 7 plans across 4 waves without compressing any decision.**

## Open questions & blockers

1. **A-13g metadata support on Test Clocks** — resolved inline in Plan 02 Task 1 via a probe (docs check + optional live API call + optional stripe-mock probe). If metadata is NOT supported, Plan 05's Mix task falls back to age-only cleanup without marker filtering (materially worse UX, documented in moduledoc). Plan 02 Task 1 must complete BEFORE Plan 05 begins so the planner/executor knows which path to take. The Plan 02 SUMMARY carries the finding forward for Plan 05 consumption.

2. **Finch pool for real_stripe** — RESEARCH Open Question #7 recommended a separate `LatticeStripe.RealStripeFinch` pool. Plan 06 leaves the choice to the executor based on what the existing codebase does: if `test_helper.exs` already starts `LatticeStripe.Finch`, reuse it; otherwise start a dedicated pool lazily in the CaseTemplate. Low-risk, non-blocking.

3. **Oban.Testing use-macro pattern reference** — Plan 05 Task 2's use-macro implementation uses a process-dict-based client resolution sketch. The plan EXPLICITLY instructs the executor to read Oban.Testing's source on GitHub and adopt whichever pattern Oban.Testing uses (likely generated wrapper functions in the test module). This is a research-during-execution callout, not a blocker — the sketch in Plan 05 is a viable fallback.

4. **stripe-mock fixture `status` for `/advance`** — RESEARCH Assumption A3 says the fixture likely returns `status: "ready"`. If that's wrong and it returns `:advancing`, the zero-delay first poll in `advance_and_wait/4` does NOT satisfy against stripe-mock, and Plan 04's integration tests would fail. The integration test in Plan 03 is specifically structured to NOT assert polling semantics against stripe-mock (Pitfall 4), so this is a non-issue for the plans as written. Real polling behavior is covered by Plan 04's Mox unit tests + Plan 06's `:real_stripe` test.

No blocking unknowns that require a user decision before execution. All are either resolvable by the executor in-flight (Oban reference, Finch pool, stripe-mock fixture check) or resolved by Plan 02's probe task (metadata support).

## Plan file locations

```
.planning/phases/13-billing-test-clocks/
├── 13-CONTEXT.md          (input)
├── 13-RESEARCH.md         (input)
├── 13-PLAN-SUMMARY.md     ← this file
├── 13-01-PLAN.md          Wave 0: Scaffolds & preconditions
├── 13-02-PLAN.md          Wave 1: TestClock struct + from_map + A-13g probe
├── 13-03-PLAN.md          Wave 1: TestClock CRUD
├── 13-04-PLAN.md          Wave 1: advance + advance_and_wait + telemetry
├── 13-05-PLAN.md          Wave 2: Testing.TestClock helper + Owner + Mix task
├── 13-06-PLAN.md          Wave 3: RealStripeCase + canonical :real_stripe test
└── 13-07-PLAN.md          Wave 3: docs, CHANGELOG, quality gates
```

## Next steps

Run `/gsd-execute-phase 13` to execute Wave 0 (Plan 13-01). After each wave lands and its plans green, proceed to the next wave. Recommended cadence:

1. **Wave 0** — Plan 01 alone. Merge-gated for the rest of the phase.
2. **Wave 1** — Plans 02, 03, 04 in strict order. Plan 02 Task 1 (metadata probe) unblocks Plan 05's strategy.
3. **Wave 2** — Plan 05 alone. Largest single plan; executor should clear context and re-read CONTEXT.md + Plan 02's SUMMARY before starting.
4. **Wave 3** — Plans 06 and 07. Can run in parallel if executor bandwidth permits; serial otherwise.

After Plan 07 greens, run `/gsd-verify-work 13` for the phase-level verification pass (includes `mix test --include integration` and, if `STRIPE_TEST_SECRET_KEY` is set, `mix test --include real_stripe`).
