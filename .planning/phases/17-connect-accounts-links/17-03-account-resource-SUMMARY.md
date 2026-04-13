---
phase: 17
plan: "03"
subsystem: connect-accounts-links
tags: [connect, stripe, account, resource-module, reject, atom-guard, from_map]
dependency_graph:
  requires: [17-02]
  provides: [LatticeStripe.Account]
  affects: [17-04-link-modules, 17-05-integration-tests, 17-06-guide-and-exdoc]
tech_stack:
  added: []
  patterns:
    - "D-04a atom guard at function head (when reason in @reject_reasons)"
    - "D-04b: request_capability/4 absent; update/4 capability nested-map idiom documented"
    - "D-01 Requirements struct reuse at both requirements and future_requirements fields"
    - "F-001 @known_fields + :extra + Map.split pattern at Account level"
    - "cast_capabilities/1 private helper — Map.new over capabilities map to Capability.cast/1"
key_files:
  created:
    - lib/lattice_stripe/account.ex
    - test/lattice_stripe/account_test.exs
  modified: []
decisions:
  - "D-04a reject/4 atom guard: when is_binary(id) and reason in @reject_reasons at function head — FunctionClauseError on any other atom"
  - "D-04b request_capability/4 absent: regression guard test locks in the rejection"
  - "D-01 budget reframing: Requirements struct reused at both requirements and future_requirements; documented in moduledoc lines 32-41"
  - "from_map/1 uses String.to_existing_atom/1 via Map.new to convert known string keys to atoms safely"
metrics:
  duration: "3 minutes"
  completed: "2026-04-13"
  tasks_completed: 2
  files_created: 2
---

# Phase 17 Plan 03: Account Resource Summary

**One-liner:** Full `LatticeStripe.Account` Connect resource with D-04a atom-guarded `reject/4`, D-04b `request_capability` rejection enforced, D-01 Requirements struct reused at two fields, and 51 Mox-backed unit tests green.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | LatticeStripe.Account resource module — CRUD + list + stream + from_map | 92747d0 | lib/lattice_stripe/account.ex |
| 2 | Account unit tests — Mox-backed, 51 tests | 77e64b5 | test/lattice_stripe/account_test.exs |

## Public API Surface

`LatticeStripe.Account` exposes 14 public functions:

| Function | Arity | Description |
|----------|-------|-------------|
| `create/3` | `(client, params \\ %{}, opts \\ [])` | `POST /v1/accounts` |
| `create!/3` | same | bang variant |
| `retrieve/3` | `(client, id, opts \\ [])` | `GET /v1/accounts/:id` |
| `retrieve!/3` | same | bang variant |
| `update/4` | `(client, id, params, opts \\ [])` | `POST /v1/accounts/:id` |
| `update!/4` | same | bang variant |
| `delete/3` | `(client, id, opts \\ [])` | `DELETE /v1/accounts/:id` |
| `delete!/3` | same | bang variant |
| `reject/4` | `(client, id, reason, opts \\ [])` | `POST /v1/accounts/:id/reject` — D-04a guarded |
| `reject!/4` | same | bang variant |
| `list/3` | `(client, params \\ %{}, opts \\ [])` | `GET /v1/accounts` |
| `list!/3` | same | bang variant |
| `stream!/3` | `(client, params \\ %{}, opts \\ [])` | lazy auto-paginated stream |
| `from_map/1` | `(map() \| nil)` | wire-shape → typed struct casting |

No `request_capability/4` — intentionally absent per D-04b.

## D-04a Atom Guard Test Results

All 3 valid reason atoms tested (happy path) + 2 rejection tests:

| Test | Reason | Result |
|------|--------|--------|
| sends POST with `reason=fraud` | `:fraud` | PASS |
| sends POST with `reason=terms_of_service` | `:terms_of_service` | PASS |
| sends POST with `reason=other` | `:other` | PASS |
| raises FunctionClauseError for invalid atom | `:wrong_atom` | PASS |
| raises FunctionClauseError for typo | `:fruad` | PASS |

## D-04b Regression Guard Status

ACTIVE — `test/lattice_stripe/account_test.exs` line:

```elixir
refute function_exported?(LatticeStripe.Account, :request_capability, 4)
refute function_exported?(LatticeStripe.Account, :request_capability, 3)
```

This test will catch any future drift where a capability helper is accidentally added.

## D-01 Reframing Moduledoc Location

The D-01 budget reframing amendment is documented in `lib/lattice_stripe/account.ex` at **line 32**:

```
## D-01 nested struct budget reframing
```

The text matches the near-verbatim copy required by the plan, explaining that `LatticeStripe.Account.Requirements` is defined once and reused at both `%Account{}.requirements` and `%Account{}.future_requirements`.

## from_map/1 Nested Struct Casting

| Field | Cast To | Notes |
|-------|---------|-------|
| `business_profile` | `BusinessProfile.from_map/1` | F-001 extra capture |
| `requirements` | `Requirements.from_map/1` | D-01 reuse #1 |
| `future_requirements` | `Requirements.from_map/1` | D-01 reuse #2 |
| `tos_acceptance` | `TosAcceptance.from_map/1` | PII-safe Inspect |
| `company` | `Company.from_map/1` | PII-safe Inspect |
| `individual` | `Individual.from_map/1` | PII-safe Inspect; nil for company-type |
| `settings` | `Settings.from_map/1` | Depth-capped outer struct |
| `capabilities` | `cast_capabilities/1` → `Capability.cast/1` | `map(String, Capability)` per D-02 |

## Test Count and Credo Status

- **Test count:** 51 tests, 0 failures
- **Full suite:** 1149 tests, 0 failures (89 excluded integration)
- **Credo strict:** 0 issues found on `lib/lattice_stripe/account.ex`
- **Compile:** `mix compile --warnings-as-errors` exits 0
- **No `String.to_atom/1`:** `grep -R "String.to_atom(" lib/lattice_stripe/account.ex` returns zero matches

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes beyond the plan's `<threat_model>`.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `lib/lattice_stripe/account.ex` | FOUND |
| `test/lattice_stripe/account_test.exs` | FOUND |
| Task 1 commit `92747d0` | FOUND |
| Task 2 commit `77e64b5` | FOUND |
