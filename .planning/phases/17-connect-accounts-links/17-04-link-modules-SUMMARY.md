---
phase: 17
plan: "04"
subsystem: connect
tags: [connect, account-link, login-link, onboarding, bearer-token, d04c, t17-02]
dependency_graph:
  requires:
    - test/support/fixtures/account_link.ex (17-01)
    - test/support/fixtures/login_link.ex (17-01)
  provides:
    - lib/lattice_stripe/account_link.ex
    - lib/lattice_stripe/login_link.ex
    - test/lattice_stripe/account_link_test.exs
    - test/lattice_stripe/login_link_test.exs
  affects:
    - Plan 17-05 (integration tests for AccountLink and LoginLink)
    - Plan 17-06 (guide and ExDoc referencing both modules)
tech_stack:
  added: []
  patterns:
    - "F-001 @known_fields + :extra split pattern (matches customer.ex, subscription_schedule.ex)"
    - "create(client, params, opts) standard 3-arity shape for AccountLink (D-04c)"
    - "create(client, account_id, params, opts) 4-arity deviation for LoginLink (URL-path-scoped ID)"
    - "refute function_exported? regression guards for D-04c and create-only constraints"
    - "Mox req._params assertion for verifying params forwarding (transport receives encoded body, _params retains original map)"
key_files:
  created:
    - lib/lattice_stripe/account_link.ex
    - lib/lattice_stripe/login_link.ex
    - test/lattice_stripe/account_link_test.exs
    - test/lattice_stripe/login_link_test.exs
  modified: []
decisions:
  - "D-04c enforced: AccountLink.create/3 takes params map; no 4-arity positional-type variant; locked by regression test"
  - "LoginLink signature deviation documented in moduledoc: account_id as 2nd positional arg because Stripe endpoint is URL-path-scoped"
  - "T-17-02 bearer-token warning present in both moduledocs — 'Do not log the URL' explicit text"
  - "is_binary(account_id) guard on LoginLink.create/4 rejects non-string inputs with FunctionClauseError before any HTTP call"
  - "req._params used in Mox assertions (transport receives encoded body string in :body; original map preserved in :_params)"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-13T00:45:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
---

# Phase 17 Plan 04: Link Modules Summary

**One-liner:** AccountLink (create/3, D-04c map-based shape) and LoginLink (create/4, account_id as 2nd positional arg) with T-17-02 bearer-token warnings and create-only regression guards.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | LatticeStripe.AccountLink — create/3 + create!/3 + tests | 7161f34 | lib/lattice_stripe/account_link.ex, test/lattice_stripe/account_link_test.exs |
| 2 | LatticeStripe.LoginLink — create/4 (account_id 2nd arg) + tests | 0bd48d7 | lib/lattice_stripe/login_link.ex, test/lattice_stripe/login_link_test.exs |

---

## Public API Surface

### `LatticeStripe.AccountLink`

| Function | Arity | Description |
|----------|-------|-------------|
| `create/3` | `(client, params, opts \\ [])` | POST /v1/account_links |
| `create!/3` | `(client, params, opts \\ [])` | Bang variant, raises on error |
| `from_map/1` | `(map \| nil)` | Decodes Stripe response map to %AccountLink{} |

Struct fields: `object`, `created`, `expires_at`, `url`, `extra`.

### `LatticeStripe.LoginLink`

| Function | Arity | Description |
|----------|-------|-------------|
| `create/4` | `(client, account_id, params \\ %{}, opts \\ [])` | POST /v1/accounts/:account_id/login_links |
| `create!/4` | `(client, account_id, params \\ %{}, opts \\ [])` | Bang variant, raises on error |
| `from_map/1` | `(map \| nil)` | Decodes Stripe response map to %LoginLink{} |

Struct fields: `object`, `created`, `url`, `extra`.

---

## D-04c Enforcement

Decision: reject 4-arity `create(client, type, params, opts)` variant for AccountLink. The `type` field belongs in the params map with all other required fields.

Regression test in `test/lattice_stripe/account_link_test.exs`:

```elixir
describe "D-04c: no positional type arg" do
  test "create/4 does not exist — SDK-wide create(client, params, opts) shape preserved" do
    refute function_exported?(LatticeStripe.AccountLink, :create, 4)
  end
  test "create!/4 does not exist — bang variant also guards D-04c" do
    refute function_exported?(LatticeStripe.AccountLink, :create!, 4)
  end
end
```

Result: Both refute assertions pass — D-04c is locked in.

---

## LoginLink Signature Deviation Documentation

Documented in `lib/lattice_stripe/login_link.ex` moduledoc under "Signature deviation: `account_id` is the second positional argument":

> Unlike the SDK-wide `create(client, params, opts)` shape, `LoginLink.create/4` takes the connected `account_id` as its second positional argument. This deviation is intentional: the Stripe endpoint is `POST /v1/accounts/:account_id/login_links`, where the account ID is URL-path-scoped rather than a request body parameter. Every other Stripe SDK (stripe-node, stripe-python, stripe-go, stripity_stripe) places the account ID as a path argument for this endpoint.

Regression test enforces the `is_binary(account_id)` guard:

```elixir
test "create(client, non_binary) raises FunctionClauseError" do
  assert_raise FunctionClauseError, fn ->
    LoginLink.create(client, %{"account" => "acct_test"})
  end
end
```

---

## T-17-02 Bearer-Token Warning Verification

Both moduledocs contain explicit "Do not log" warnings:

**AccountLink** (`lib/lattice_stripe/account_link.ex`, "Security" section):
> The `url` field is a bearer token granting the holder access to the connected account's onboarding flow. It expires ~300 seconds after creation. **Do not log the URL, do not store it in a database, do not include it in error reports or telemetry payloads.**

**LoginLink** (`lib/lattice_stripe/login_link.ex`, "Security" section):
> Like `LatticeStripe.AccountLink`, the returned `url` is a bearer token. **Do not log, store, or include the URL in telemetry payloads.** Redirect the user immediately (Phase 17 T-17-02).

---

## Test Counts

| File | Tests |
|------|-------|
| test/lattice_stripe/account_link_test.exs | 11 |
| test/lattice_stripe/login_link_test.exs | 13 |
| **Total** | **24** |

Full suite after this plan: 1122 tests, 0 failures (89 excluded integration).

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Mox transport req struct uses `_params` not `params`**
- **Found during:** Task 1 verification (params forwarding test)
- **Issue:** The plan's test template asserted `req.params == params`, but the Mox transport callback receives a struct where the original params map is stored under `:_params` (the `:body` key holds the encoded form string). This matches the existing pattern in `client_test.exs`.
- **Fix:** Updated the params forwarding test to assert `req._params == params` in both AccountLink and LoginLink test files.
- **Files modified:** test/lattice_stripe/account_link_test.exs, test/lattice_stripe/login_link_test.exs
- **Commit:** 7161f34 (caught before Task 2 started; applied same pattern to LoginLink)

---

## Known Stubs

None — both modules wire directly to Stripe API endpoints with no placeholder data.

---

## Threat Flags

No new security surface introduced beyond what is documented in the plan's threat model. Both modules produce short-lived bearer-token URLs with existing T-17-02 and T-17-INJECT-01 mitigations applied as designed.

---

## Self-Check: PASSED

Files exist:
- `lib/lattice_stripe/account_link.ex` — FOUND
- `lib/lattice_stripe/login_link.ex` — FOUND
- `test/lattice_stripe/account_link_test.exs` — FOUND
- `test/lattice_stripe/login_link_test.exs` — FOUND

Commits exist: 7161f34, 0bd48d7 — both in `git log --oneline`.
