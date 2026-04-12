---
phase: 13
plan: 01
subsystem: billing-test-clocks
tags: [wave0, scaffolding, error, client, idempotency, conventions, real_stripe]
dependency_graph:
  requires: []
  provides:
    - ":test_clock_timeout / :test_clock_failed atoms in LatticeStripe.Error type whitelist"
    - "LatticeStripe.Client :idempotency_key_prefix option (Config + struct + threading)"
    - "LatticeStripe.TestSupport namespace (test-only, rename from TestHelpers)"
    - ":real_stripe tag excluded by default in test/test_helper.exs"
    - "3 wave-0 test stubs (TestHelpers.TestClock, Testing.TestClock, real_stripe round-trip)"
    - ".planning/CONVENTIONS.md (flat-core/nested-subproduct rule)"
    - "CONTRIBUTING.md :real_stripe + direnv section"
    - ".envrc gitignored"
  affects:
    - "all Phase 13 downstream plans (02-07)"
    - "Phase 17 Connect namespace lock-in (via CONVENTIONS.md)"
tech_stack:
  added: []
  patterns:
    - "Locally-constructed error atoms stash context in existing :raw_body free-form map (no schema change)"
    - "Client option threading: Config NimbleOptions schema → defstruct → @type t → private resolve fn"
    - "Wave-0 pending test stubs: tagged :wave0_stub with assert true placeholder so mix test discovers them"
key_files:
  created:
    - "test/support/test_support.ex"
    - "test/lattice_stripe/test_helpers/test_clock_test.exs"
    - "test/lattice_stripe/testing/test_clock_test.exs"
    - "test/real_stripe/test_clock_real_stripe_test.exs"
    - ".planning/CONVENTIONS.md"
  modified:
    - "lib/lattice_stripe/error.ex"
    - "lib/lattice_stripe/config.ex"
    - "lib/lattice_stripe/client.ex"
    - "test/test_helper.exs"
    - "test/lattice_stripe/error_test.exs"
    - "test/lattice_stripe/client_test.exs"
    - "test/integration/*_integration_test.exs (7 files — TestHelpers → TestSupport alias)"
    - "test/lattice_stripe/*_test.exs (7 files — TestHelpers → TestSupport alias)"
    - "CONTRIBUTING.md"
    - ".gitignore"
  deleted:
    - "test/support/test_helpers.ex"
decisions:
  - "Error :details field NOT added — context stashed in existing :raw_body free-form map (A-13c)"
  - "TestHelpers (test-only) renamed to TestSupport to free the namespace for the public Phase 13 submodule (A-13support)"
  - ":idempotency_key_prefix accepts {:or, [:string, nil]} via NimbleOptions, matching existing :stripe_account pattern (A-13client)"
  - "3 wave-0 test stubs tagged :wave0_stub + assert true so mix test discovers them without depending on production code yet to ship"
  - "CONVENTIONS.md cites Checkout.Session as the existing flat/nested precedent — Phase 13 is the second and third nested namespace, not the first (A-13a)"
metrics:
  duration: "~12 minutes"
  completed: "2026-04-11"
  tasks: 5
  files_touched: 19
  tests_added: 13
  tests_green: "711 tests, 0 failures (53 excluded)"
---

# Phase 13 Plan 01: Wave 0 Scaffolding Summary

**One-liner:** Landed every Phase 13 prerequisite — Error type whitelist extension, Client `:idempotency_key_prefix` option, TestHelpers→TestSupport rename, `:real_stripe` test tier scaffolding, CONVENTIONS.md, and the direnv CONTRIBUTING section — in one reviewable wave-0 unit, unblocking Plans 02-07 without a single line of TestClock production code.

## Scope

Plan 13-01 is the pure-plumbing wave for Phase 13. It introduces zero new public SDK resources and makes zero breaking changes. Every modification is additive or a private rename. Downstream Plans 02-07 depend on exactly the surface this plan establishes:

- Plan 02-04 (TestHelpers.TestClock CRUD + advance_and_wait) need `:test_clock_timeout` / `:test_clock_failed` atoms on `LatticeStripe.Error`
- Plan 05 (Testing.TestClock user-facing library) needs the `TestHelpers` namespace to be free of the internal rename collision
- Plan 06 (real_stripe round-trip test) needs `:real_stripe` excluded by default, the discoverable stub file, and the `:idempotency_key_prefix` client option
- Plan 07 (docs + CHANGELOG) expects `.planning/CONVENTIONS.md` to already document the flat-core / nested-subproduct rule

## Tasks Executed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Extend `LatticeStripe.Error` type whitelist with `:test_clock_timeout` / `:test_clock_failed` | `ff6b645` | `error.ex`, `error_test.exs` |
| 2 | Add `:idempotency_key_prefix` option (Config + Client defstruct + resolve threading) | `6c875d7` | `config.ex`, `client.ex`, `client_test.exs` |
| 3 | Rename `LatticeStripe.TestHelpers` (test-only) → `LatticeStripe.TestSupport` | `a813bca` | `test_support.ex` new, `test_helpers.ex` deleted, 14 test files updated |
| 4 | Update `test_helper.exs` `:real_stripe` exclusion + create 3 wave-0 test stubs | `3659b1d` | `test_helper.exs`, 3 new stub test files |
| 5 | Create `.planning/CONVENTIONS.md`, extend `CONTRIBUTING.md`, gitignore `.envrc` | `d97cfe7` | `CONVENTIONS.md`, `CONTRIBUTING.md`, `.gitignore` |

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix test` — **711 tests, 0 failures (53 excluded)**
- Acceptance grep checks all passed (see self-check below)

## Deviations from Plan

**None — plan executed exactly as written.**

One minor clarification: Task 1's RED step for the `:test_clock_timeout` type atom was green immediately because the `:type` field is a bare atom accepted by the struct regardless of the typedoc union. The typedoc update remains correct and documentation-accurate, but there was no compile-time RED gate. Tests still exercise the constructor, raise path, and pattern-match path end-to-end.

No authentication gates hit. No architectural decisions required. No out-of-scope discoveries.

## Known Stubs

Three wave-0 test stubs ship with `@moduletag :wave0_stub` and a single `assert true` body:

- `test/lattice_stripe/test_helpers/test_clock_test.exs` — will be populated by Plans 02-04
- `test/lattice_stripe/testing/test_clock_test.exs` — will be populated by Plan 05
- `test/real_stripe/test_clock_real_stripe_test.exs` — will be populated by Plan 06

These are intentional and documented in each file's comment block. They are NOT correctness gaps — they exist so downstream plans can add assertions to a file that already compiles and is discoverable.

## Self-Check: PASSED

- `lib/lattice_stripe/error.ex` — `:test_clock_timeout` present
- `lib/lattice_stripe/client.ex` — `idempotency_key_prefix` present
- `test/support/test_support.ex` — `LatticeStripe.TestSupport` defined
- `test/test_helper.exs` — `:real_stripe` in exclude list
- `.planning/CONVENTIONS.md` — exists
- `CONTRIBUTING.md` — `STRIPE_TEST_SECRET_KEY` documented
- `.gitignore` — `.envrc` present
- Commits `ff6b645`, `6c875d7`, `a813bca`, `3659b1d`, `d97cfe7` — all present in `git log`
- `mix test` — 711 tests, 0 failures
