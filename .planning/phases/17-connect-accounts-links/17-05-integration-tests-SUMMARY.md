---
phase: 17
plan: "05"
subsystem: connect-accounts-links
tags: [connect, stripe, integration, stripe-mock, account, account-link, login-link]
dependency_graph:
  requires: [17-03, 17-04]
  provides:
    - test/integration/account_integration_test.exs
    - test/integration/account_link_integration_test.exs
    - test/integration/login_link_integration_test.exs
  affects: [17-06-guide-and-exdoc]
tech_stack:
  added: []
  patterns:
    - "stripe-mock connectivity guard via :gen_tcp.connect in setup_all"
    - "start_supervised!({Finch, name: LatticeStripe.IntegrationFinch}) per integration test module"
    - "test_integration_client/0 from LatticeStripe.TestHelpers (localhost:12111)"
    - "@moduletag :integration scopes all new tests"
    - "cast_capabilities/1 string-value normalization for stripe-mock compat"
key_files:
  created:
    - test/integration/account_integration_test.exs
    - test/integration/account_link_integration_test.exs
    - test/integration/login_link_integration_test.exs
  modified:
    - lib/lattice_stripe/account.ex
decisions:
  - "Reject test written normally (not skipped) — REJECT_SUPPORTED=true per 17-VALIDATION.md 2026-04-12 probe"
  - "cast_capabilities/1 normalizes stripe-mock's bare string capability values to %{status: val} maps before Capability.cast/1"
  - "LoginLink tests accept both 200 and 400 from stripe-mock — Express-only constraint not modeled by mock"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-13"
  tasks_completed: 2
  files_created: 3
  files_modified: 1
---

# Phase 17 Plan 05: Integration Tests Summary

**One-liner:** stripe-mock-backed integration tests for Account (full lifecycle + reject + nested structs), AccountLink (create POST wire path), and LoginLink (create POST path-scoped account_id), with auto-fix for stripe-mock capability string values.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Account full-lifecycle integration test + cast_capabilities fix | e1364a6 | test/integration/account_integration_test.exs, lib/lattice_stripe/account.ex |
| 2 | AccountLink + LoginLink integration tests | ecb7494 | test/integration/account_link_integration_test.exs, test/integration/login_link_integration_test.exs |

---

## Integration Test Counts

| File | Tests | Covers |
|------|-------|--------|
| `test/integration/account_integration_test.exs` | 9 | create, retrieve, update, list, stream!, reject(:fraud), delete, atom guard, nested struct casting |
| `test/integration/account_link_integration_test.exs` | 4 | create/3 url+expires_at shape, object field, create!/3 bang, D-04c missing-type passthrough |
| `test/integration/login_link_integration_test.exs` | 5 | create/4 wire path, empty params, create!/4 bang, FunctionClauseError on non-binary account_id, nil guard |
| **Total** | **18** | **Full Phase 17 Connect wire surface** |

---

## stripe-mock Reject Endpoint Disposition

**REJECT_SUPPORTED = true**

Confirmed via `scripts/verify_stripe_mock_reject.exs` on 2026-04-12 (Plan 17-01 Task 3 probe result recorded in `17-VALIDATION.md`). The integration test at `test/integration/account_integration_test.exs:115` asserts `{:ok, %Account{}}` from `Account.reject(client, id, :fraud)` — not skipped.

---

## Wire-Shape Discrepancies Found

### stripe-mock capabilities: plain strings vs full objects

**Found during:** Task 1 verification (all Account tests failing)

**Discrepancy:** stripe-mock returns `capabilities` as `%{"card_payments" => "active"}` (plain status strings) rather than `%{"card_payments" => %{"status" => "active", ...}}` (full capability objects as returned by real Stripe API).

**Impact:** `cast_capabilities/1` in `lib/lattice_stripe/account.ex` called `Capability.cast/1` with a string argument, triggering `FunctionClauseError` (only `nil` and `is_map` clauses existed).

**Fix applied (Rule 1 - Bug):** Added a string-normalizing clause to `cast_capabilities/1`:

```elixir
defp cast_capabilities(caps) when is_map(caps) do
  Map.new(caps, fn
    {name, obj} when is_binary(obj) -> {name, Capability.cast(%{"status" => obj})}
    {name, obj} -> {name, Capability.cast(obj)}
  end)
end
```

Real Stripe API responses will continue to use the map path (unchanged). stripe-mock's bare strings are normalized at the boundary.

---

## Runtime

~0.6 seconds for all 18 integration tests (stripe-mock on localhost:12111, no network latency).

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] cast_capabilities/1 crashed on stripe-mock string capability values**
- **Found during:** Task 1 execution — all Account integration tests failing
- **Issue:** stripe-mock returns `capabilities` map values as plain strings (e.g., `"active"`) rather than full maps. `Capability.cast/1` only matched `nil` and `is_map/1`.
- **Fix:** Added `when is_binary(obj)` guard clause in `cast_capabilities/1` to normalize `"active"` → `%{"status" => "active"}` before delegating to `Capability.cast/1`.
- **Files modified:** `lib/lattice_stripe/account.ex`
- **Commit:** e1364a6

**2. [Rule 1 - Bug] LatticeStripe.Error field is :status not :http_status**
- **Found during:** Task 2 compilation of login_link_integration_test.exs
- **Issue:** Plan template used `%LatticeStripe.Error{http_status: 400}` but the struct field is `:status`.
- **Fix:** Changed `http_status: 400` to `status: 400` in the LoginLink test.
- **Files modified:** test/integration/login_link_integration_test.exs

---

## Known Stubs

None — all integration tests exercise real HTTP paths through stripe-mock.

---

## Threat Flags

None — integration tests introduce no new network endpoints or security surface. All HTTP traffic is to localhost:12111 (stripe-mock).

---

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `test/integration/account_integration_test.exs` | FOUND |
| `test/integration/account_link_integration_test.exs` | FOUND |
| `test/integration/login_link_integration_test.exs` | FOUND |
| Task 1 commit `e1364a6` | FOUND |
| Task 2 commit `ecb7494` | FOUND |
| `mix test --exclude integration` | 1173 tests, 0 failures |
| `mix compile --warnings-as-errors` | exit 0 |
