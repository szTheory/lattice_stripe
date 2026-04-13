---
phase: 17
plan: "02"
subsystem: connect-accounts-links
tags: [connect, stripe, nested-structs, pii, inspect]
dependency_graph:
  requires: [17-01]
  provides: [LatticeStripe.Account.BusinessProfile, LatticeStripe.Account.Requirements, LatticeStripe.Account.Settings, LatticeStripe.Account.TosAcceptance, LatticeStripe.Account.Company, LatticeStripe.Account.Individual, LatticeStripe.Account.Capability]
  affects: [17-03-account-resource]
tech_stack:
  added: []
  patterns: [F-001 @known_fields + :extra + Map.split, PII-safe Inspect via redaction loop, atom-safe status helper via @known_statuses guard]
key_files:
  created:
    - lib/lattice_stripe/account/business_profile.ex
    - lib/lattice_stripe/account/requirements.ex
    - lib/lattice_stripe/account/settings.ex
    - lib/lattice_stripe/account/tos_acceptance.ex
    - lib/lattice_stripe/account/company.ex
    - lib/lattice_stripe/account/individual.ex
    - lib/lattice_stripe/account/capability.ex
    - test/lattice_stripe/account/business_profile_test.exs
    - test/lattice_stripe/account/requirements_test.exs
    - test/lattice_stripe/account/settings_test.exs
    - test/lattice_stripe/account/tos_acceptance_test.exs
    - test/lattice_stripe/account/company_test.exs
    - test/lattice_stripe/account/individual_test.exs
    - test/lattice_stripe/account/capability_test.exs
    - test/support/fixtures/account.ex
  modified: []
decisions:
  - "PII Inspect uses redaction loop with [REDACTED] markers (not customer.ex omit-only approach) because plan tests require assert output =~ \"[REDACTED]\""
  - "Capability @known_status_atoms attribute exposes known_status_atoms/0 function to satisfy Elixir unused-attribute warning while ensuring atoms exist at compile time"
  - "Account fixture created in this plan (not 17-01) as Rule 3 deviation — blocking dependency for test round-trips"
metrics:
  duration: "5 minutes"
  completed: "2026-04-12"
  tasks_completed: 3
  files_created: 15
---

# Phase 17 Plan 02: Nested Structs Summary

7 nested struct modules for the `LatticeStripe.Account.*` namespace delivered — F-001 extra-capture, PII-safe Inspect for 3 modules, and atom-safe `status_atom/1` on Capability.

## Modules Delivered

| Module | Fields | PII Inspect | Extra Capture | Notes |
|--------|--------|-------------|---------------|-------|
| `LatticeStripe.Account.BusinessProfile` | 9 | No | Yes | D-01 #1 |
| `LatticeStripe.Account.Requirements` | 8 | No | Yes | D-01 #2 — reused at `requirements` AND `future_requirements` |
| `LatticeStripe.Account.Settings` | 9 | No | Yes | D-01 #6 — outer-only depth cap |
| `LatticeStripe.Account.TosAcceptance` | 4 | Yes — `ip`, `user_agent` | Yes | D-01 #3, T-17-01 |
| `LatticeStripe.Account.Company` | 15 | Yes — `tax_id`, `vat_id`, `phone`, `address*` | Yes | D-01 #4, T-17-01 |
| `LatticeStripe.Account.Individual` | 20 | Yes — 17 PII fields | Yes | D-01 #5, T-17-01 |
| `LatticeStripe.Account.Capability` | 5 + extra | No | Yes | D-02 (not in D-01 budget) |

**Total: 7 modules, 61 tests, all green.**

## PII Inspect Verification

All three PII-bearing modules use a redaction loop pattern that replaces non-nil PII field values with `"[REDACTED]"` in Inspect output, leaving nil fields unchanged (no spurious `[REDACTED]` for unset fields).

- **TosAcceptance:** `refute inspect(...) =~ "203.0.113.42"` — passes
- **Company:** `refute inspect(...) =~ "00-0000000"`, `refute inspect(...) =~ "+15555550101"` — passes
- **Individual:** `refute inspect(...) =~ "1234"`, `refute inspect(...) =~ "Jane"`, etc. — passes

## Capability Atom-Safety Test Result

- All 5 known statuses (active, inactive, pending, unrequested, disabled) round-trip correctly
- Unknown status `"zzz_totally_new_status_from_stripe_2030"` returns `:unknown` without raising
- Random unknown statuses return `:unknown` without raising or leaking atoms
- No `String.to_atom/1` call exists anywhere in `lib/lattice_stripe/account/` (verified by grep)

## D-02 Verbatim-Copy Corrections

One editorial correction was required from CONTEXT D-02 source:

| Location | CONTEXT shorthand | Corrected form |
|----------|-------------------|----------------|
| `def status_atom/1` head clause | `%__MODULE__{s}` | `%__MODULE__{status: s}` |

This is the only permitted correction per the plan. The correction was documented in the commit message.

Additionally, `@_ensure_atoms` from the plan's note became `@known_status_atoms` with a companion `def known_status_atoms/0` to satisfy Elixir's unused-module-attribute warning under `--warnings-as-errors`.

## mix credo --strict Status

Clean — 0 issues found on 147 project files.

## Deviations from Plan

### Auto-added Missing Critical Functionality

**1. [Rule 3 - Blocking] Created account fixture (test/support/fixtures/account.ex)**
- **Found during:** Task 1
- **Issue:** Plan 17-02 depends on `test/support/fixtures/account.ex` for round-trip tests, but this file is normally created by Plan 17-01 (wave 0 bootstrap). In the parallel worktree, Plan 17-01 had not been executed yet, so the fixture was missing.
- **Fix:** Created the fixture module following Plan 17-01's exact specification (4 functions: `basic/1`, `with_capabilities/2`, `deleted/1`, `list_response/1`) with full D-01 nested objects and D-02 capability shape.
- **Files modified:** `test/support/fixtures/account.ex`
- **Commit:** 4bd03c9

### Inspect Pattern Choice

**2. [Claude discretion] PII-safe Inspect uses redaction loop, not omit-all pattern**
- **Found during:** Task 2
- **Issue:** Existing implementations (customer.ex, checkout/session.ex) use `Inspect.Algebra` to show only selected non-PII fields, omitting PII fields entirely. The plan's behavior spec however requires `assert output =~ "[REDACTED]"`, which means fields must show as `[REDACTED]` rather than being absent.
- **Fix:** Used the plan's redaction loop approach — all fields shown, PII fields replaced with `"[REDACTED]"` string when non-nil. This honors the plan's behavior spec and is a distinct, arguably more transparent pattern.

## Self-Check: PASSED

All 7 module files confirmed present. All 3 task commits confirmed in git log.

| Check | Result |
|-------|--------|
| `lib/lattice_stripe/account/business_profile.ex` | FOUND |
| `lib/lattice_stripe/account/requirements.ex` | FOUND |
| `lib/lattice_stripe/account/settings.ex` | FOUND |
| `lib/lattice_stripe/account/tos_acceptance.ex` | FOUND |
| `lib/lattice_stripe/account/company.ex` | FOUND |
| `lib/lattice_stripe/account/individual.ex` | FOUND |
| `lib/lattice_stripe/account/capability.ex` | FOUND |
| Task 1 commit `4bd03c9` | FOUND |
| Task 2 commit `fddb864` | FOUND |
| Task 3 commit `3a80de4` | FOUND |
