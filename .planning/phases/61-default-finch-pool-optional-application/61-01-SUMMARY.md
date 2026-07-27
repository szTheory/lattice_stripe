---
phase: 61-default-finch-pool-optional-application
plan: 01
subsystem: infra
tags: [finch, otp-application, supervision, nimble_options, elixir, dx]

# Dependency graph
requires: []
provides:
  - "LatticeStripe.Application OTP callback that starts a default LatticeStripe.Finch pool at boot"
  - ":finch option defaults to LatticeStripe.Finch (was required: true)"
  - ":finch dropped from Client @enforce_keys — zero-config Client.new!(api_key:) now works"
  - "start_default_finch: false opt-out toggle for BYO-supervision users"
  - "default_finch_pools app-config override for pool sizing"
affects: [migration-guide, entitlements, docs-update, getting-started]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Config-gated children list in Application.start/2 (Application.get_env read once at boot)"
    - "NimbleOptions default: <module-atom> for library-safe overridable config keys"

key-files:
  created:
    - lib/lattice_stripe/application.ex
    - test/lattice_stripe/application_test.exs
  modified:
    - mix.exs
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/config_test.exs
    - test/lattice_stripe/client_test.exs

key-decisions:
  - "Opt-out key locked as `config :lattice_stripe, start_default_finch: false` (RESEARCH Open Q1)"
  - "Pool-size override via `config :lattice_stripe, default_finch_pools: %{}` (Finch defaults when unset, D-06)"
  - "default_finch_children/0 made public with @doc false as a testability seam for the opt-out branch"
  - "Top supervisor named LatticeStripe.Supervisor for debuggability (RESEARCH Open Q2)"

patterns-established:
  - "Config-gated child spec: build children conditionally from Application.get_env/3 in start/2, never per-request"
  - "Default atom parity: config.ex default: LatticeStripe.Finch must match the Application-started pool name"

requirements-completed: [DX-01]

coverage:
  - id: D1
    description: "Client.new!(api_key:) with no :finch returns %Client{finch: LatticeStripe.Finch} without raising (SC-1)"
    requirement: "DX-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/config_test.exs#defaults :finch to LatticeStripe.Finch when omitted (SC-1)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/client_test.exs#new!/1 without finch defaults to LatticeStripe.Finch without raising"
        status: pass
    human_judgment: false
  - id: D2
    description: "A live default LatticeStripe.Finch pool is running after application boot (SC-2)"
    requirement: "DX-01"
    verification:
      - kind: integration
        ref: "test/lattice_stripe/application_test.exs#the LatticeStripe.Finch pool is running after application boot"
        status: pass
    human_judgment: false
  - id: D3
    description: "Explicit finch: overrides the default and existing explicit callers are unchanged (SC-3)"
    requirement: "DX-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/config_test.exs#explicit :finch overrides the LatticeStripe.Finch default (SC-3)"
        status: pass
    human_judgment: false
  - id: D4
    description: "start_default_finch: false yields an empty children list — default pool not started (SC-4)"
    requirement: "DX-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/application_test.exs#start_default_finch: false yields an empty children list"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-27
status: complete
---

# Phase 61 Plan 01: Default Finch Pool & Optional Application Summary

**Zero-config default Finch pool wired end-to-end via a new `LatticeStripe.Application` OTP callback, with `:finch` relaxed from required to defaulting to `LatticeStripe.Finch` and an opt-out toggle for BYO-supervision users**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-27T19:09:47-04:00
- **Completed:** 2026-07-27T19:13:46-04:00
- **Tasks:** 2
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments
- `LatticeStripe.Application` (`use Application`) starts a supervised `LatticeStripe.Finch` pool at boot; `Process.whereis(LatticeStripe.Finch)` is a live pid during `mix test` and consumer apps (SC-2).
- `Client.new!(api_key: "sk_test_x")` with no `:finch` now returns `%Client{finch: LatticeStripe.Finch}` — no `NimbleOptions.ValidationError`, no `@enforce_keys` `ArgumentError` (SC-1). Closes the accrue-verified footgun (SEED-005 §3.1).
- Backwards compatible: explicit `finch:` still validates and overrides the default; every existing explicit caller is unchanged (SC-3).
- Opt-out honored: `config :lattice_stripe, start_default_finch: false` yields an empty children list, and `default_finch_pools` allows pool-size overrides (SC-4, D-05/D-06).
- Full suite green: `mix test` 2114 tests, 0 failures, 1 pre-existing skip. `mix format --check-formatted`, `mix compile --warnings-as-errors`, and `mix credo --strict` all clean.

## Task Commits

Each task was committed atomically (Task 1 is a TDD tracer: RED → GREEN):

1. **Task 1 (RED): failing end-to-end test** - `b7d4402` (test)
2. **Task 1 (GREEN): wire default Finch pool end-to-end** - `299aa3d` (feat)
3. **Task 2: prove backwards-compat, override, opt-out** - `490cf1e` (test)
4. **Doc-reference fix (Rule 1)** - `455ad90` (fix)

## Files Created/Modified
- `lib/lattice_stripe/application.ex` - NEW. OTP Application callback; config-gated `default_finch_children/0` starts `{Finch, name: LatticeStripe.Finch, pools: ...}` under `LatticeStripe.Supervisor`.
- `mix.exs` - `application/0` gains `mod: {LatticeStripe.Application, []}`; `LatticeStripe.Application` added to ExDoc "Client & Configuration" group.
- `lib/lattice_stripe/config.ex` - `:finch` schema entry `required: true` → `default: LatticeStripe.Finch`; moduledoc moves `:finch` from Required to Optional.
- `lib/lattice_stripe/client.ex` - `@enforce_keys [:api_key, :finch]` → `[:api_key]`; typedoc + `new!/1` docs updated to reflect the default.
- `test/lattice_stripe/application_test.exs` - NEW. End-to-end pool-alive + no-finch-default proofs; opt-out decision-branch tests via `default_finch_children/0` + `Application.put_env`/`on_exit`.
- `test/lattice_stripe/config_test.exs` - Replaced stale "finch required raises" test with default (SC-1) + explicit-override-wins (SC-3).
- `test/lattice_stripe/client_test.exs` - Replaced stale "new!/1 without finch raises" test with no-finch-defaults-to-LatticeStripe.Finch.

## Decisions Made
- Treated `start_default_finch` as the locked opt-out key name (RESEARCH Open Q1 — echoed in CONTEXT SC-4).
- Named the top supervisor `LatticeStripe.Supervisor` for a debuggable handle (RESEARCH Open Q2).
- Exposed `default_finch_children/0` as a public `@doc false` function so the opt-out branch is testable without stopping/restarting the already-booted real pool mid-suite (RESEARCH Wave 0 Gaps).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ExDoc autolink warning from aliased `Config.validate!/1` reference**
- **Found during:** Post-Task-2 `mix ci` gate (SC-5 docs verification)
- **Issue:** The new `Client` typedoc bullet referenced `` `Config.validate!/1` `` (the alias short form). ExDoc cannot autolink an aliased module reference, adding a `--warnings-as-errors` warning that would fail the docs step.
- **Fix:** Used the fully-qualified `LatticeStripe.Config.validate!/1` so the reference resolves and docs stay warning-neutral.
- **Files modified:** lib/lattice_stripe/client.ex
- **Verification:** `mix docs --warnings-as-errors` — zero warnings reference any of my changed files (application.ex / config.ex / client.ex).
- **Committed in:** 455ad90

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary to keep the new module's docs warning-neutral (toward SC-5). No scope creep.

## Issues Encountered
- **Pre-existing `mix docs --warnings-as-errors` debt (42 warnings).** `mix ci`'s docs step is red, but verified pre-existing: running `mix docs --warnings-as-errors` against the pre-phase baseline commit `0ca2688` (in a throwaway worktree) produced the identical count of 42 warnings, none referencing this plan's files. They stem from hidden-module type refs (`LatticeStripe.Tax.*`, `LatticeStripe.TaxId.*`), hidden-function refs, and missing extras (`../README.md`, `../notebooks/stripe_explorer.livemd`). Out of scope — logged to `deferred-items.md`. This plan's changes are warning-neutral.

## Known Stubs
None — no stubs, placeholders, or TODOs introduced.

## User Setup Required
None - no external service configuration required. Consumers upgrading who already run their own Finch pool may optionally add `config :lattice_stripe, start_default_finch: false` to avoid a duplicate idle pool (documented in Plan 02 docs).

## Next Phase Readiness
- Plan 01 (code + tests) complete and green. Plan 02 (docs/README/getting-started/CHANGELOG updates for the new default pool + opt-out) is ready to execute.
- Note for Plan 02: stale "required" prose remains in `guides/getting-started.md` and `guides/client-configuration.md` (per RESEARCH State of the Art) and must be updated there.

## Self-Check: PASSED
- FOUND: lib/lattice_stripe/application.ex
- FOUND: test/lattice_stripe/application_test.exs
- FOUND commits: b7d4402, 299aa3d, 490cf1e, 455ad90

---
*Phase: 61-default-finch-pool-optional-application*
*Completed: 2026-07-27*
