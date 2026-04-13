---
phase: 17
plan: "01"
subsystem: connect
tags: [connect, fixtures, stripe-account-header, stripe-mock, bootstrap]
dependency_graph:
  requires: []
  provides:
    - test/support/fixtures/account.ex
    - test/support/fixtures/account_link.ex
    - test/support/fixtures/login_link.ex
    - test/lattice_stripe/client_stripe_account_header_test.exs
    - scripts/verify_stripe_mock_reject.exs
    - .planning/phases/17-connect-accounts-links/17-VALIDATION.md
  affects:
    - Plans 17-02 through 17-06 (consume these fixtures and rely on T-17-03 regression guard)
tech_stack:
  added: []
  patterns:
    - "String-keyed map fixtures with Map.merge(defaults, overrides) — same pattern as SubscriptionSchedule"
    - "Mox transport header capture via req_map.headers assertion inside expect/3 callback"
    - ":httpc/:inets for standalone HTTP probe scripts (already_started handled)"
key_files:
  created:
    - test/support/fixtures/account.ex
    - test/support/fixtures/account_link.ex
    - test/support/fixtures/login_link.ex
    - test/lattice_stripe/client_stripe_account_header_test.exs
    - scripts/verify_stripe_mock_reject.exs
    - .planning/phases/17-connect-accounts-links/17-VALIDATION.md
  modified: []
decisions:
  - "stripe-mock supports POST /v1/accounts/:id/reject (returns 200) — Plan 17-05 should write the reject integration test, not skip it"
  - "Fixture files use .ex module format (not .json) matching project convention from Phase 06"
  - "T-17-03 regression guard uses direct header assertion inside Mox expect/3 callback (same pattern as client_test.exs), not Process.put capture"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-13T00:09:09Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 0
---

# Phase 17 Plan 01: Wave 0 Bootstrap Summary

**One-liner:** Phase 17 test foundation with Account/AccountLink/LoginLink fixtures, T-17-03 stripe_account header regression guard (4 tests), and stripe-mock reject probe confirmed SUPPORTED.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Canonical Account/AccountLink/LoginLink fixtures | a1a101c | test/support/fixtures/account.ex, account_link.ex, login_link.ex |
| 2 | Regression guard — per-request stripe_account header (T-17-03) | acced1f | test/lattice_stripe/client_stripe_account_header_test.exs |
| 3 | stripe-mock reject endpoint verification | e3539e9 | scripts/verify_stripe_mock_reject.exs, .planning/.../17-VALIDATION.md |

---

## Fixture Modules Created

### `LatticeStripe.Test.Fixtures.Account` (`test/support/fixtures/account.ex`)

Fully-populated wire-shape fixture exercising all 6 D-01 nested struct modules:
- `business_profile` — with mcc, monthly_estimated_revenue, support_address, support_email/phone/url
- `capabilities` — 3 entries covering `active`, `pending`, `unrequested` statuses (D-02 inner shape)
- `company` — with address, tax_id, phone, directors_provided, owners_provided (business_type=company; individual=nil)
- `requirements` + `future_requirements` — same 8-field shape at both sites (validates struct reuse)
- `settings` — branding/card_payments/dashboard/payments/payouts sub-objects
- `tos_acceptance` — includes `"ip" => "203.0.113.42"` and `"user_agent"` as PII assertion targets for Plan 17-03

Forward-compat coverage: `"zzz_forward_compat_field"` at top level AND inside `business_profile` exercises F-001 `:extra` map split.

Variants: `with_capabilities/2`, `deleted/1`, `list_response/1`.

### `LatticeStripe.Test.Fixtures.AccountLink` (`test/support/fixtures/account_link.ex`)

`basic/1` with `object`, `created`, `expires_at`, `url`, plus unknown key for `:extra` split.

### `LatticeStripe.Test.Fixtures.LoginLink` (`test/support/fixtures/login_link.ex`)

`basic/1` with `object`, `created`, `url` (Express-only), plus unknown key for `:extra` split.

---

## Client Header Regression Test (T-17-03)

File: `test/lattice_stripe/client_stripe_account_header_test.exs`

4 tests green, locking in `client.ex:174-199 + 423-427` behavior as an enforced invariant:

| Test | Scenario | Assertion |
|------|----------|-----------|
| A | client `stripe_account: "acct_client"`, no per-request opt | `{"stripe-account", "acct_client"}` in headers |
| B | client `"acct_client"` + per-request `"acct_request"` | per-request wins; client value absent |
| C | client `stripe_account: nil`, no per-request opt | NO `stripe-account` key in headers at all |
| D | client `stripe_account: nil` + per-request `"acct_request"` | `{"stripe-account", "acct_request"}` in headers |

**Gotcha:** The Mox transport callback receives a `req_map` struct with `.headers` field — assertions go directly inside the `expect/3` callback, not via `Process.put` capture. This matches the existing `client_test.exs` pattern.

---

## stripe-mock Reject Probe Result

**Result: `REJECT_SUPPORTED=true`**

`POST /v1/accounts/acct_test/reject` returns HTTP 200 from stripe-mock running on port 12111.

**Impact on Plan 17-05:** The reject integration test SHOULD be written normally (no `@tag :skip` needed). stripe-mock's OpenAPI spec includes this endpoint.

Script handles three outcomes: 200 (supported), 404 (not supported), connection-refused (inconclusive). Also handles `:already_started` for `:inets`/`:ssl` when run via `mix run`.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `:inets.start()` raises `{:already_started, :inets}` when run via `mix run`**
- **Found during:** Task 3 verification
- **Issue:** Script used `:ok = :inets.start()` which pattern-matches and crashes when Elixir's Mix environment has already started `:inets`
- **Fix:** Replaced with `case :inets.start() do :ok -> :ok; {:error, {:already_started, :inets}} -> :ok end` (same for `:ssl`)
- **Files modified:** `scripts/verify_stripe_mock_reject.exs`
- **Commit:** e3539e9

**2. [Rule 2 - Convention] VALIDATION.md task table format used `.json` for fixture paths**
- **Found during:** Task 3 (updating VALIDATION.md)
- **Issue:** Wave 0 checklist referenced `.json` files but the project uses `.ex` fixture modules
- **Fix:** Updated checklist entries to `.ex` and added `✅` checkmarks for completed items
- **Files modified:** `.planning/phases/17-connect-accounts-links/17-VALIDATION.md`
- **Commit:** e3539e9

---

## Known Stubs

None — this plan creates only fixtures and test infrastructure. No resource modules with placeholder data.

---

## Self-Check: PASSED

Files exist:
- `test/support/fixtures/account.ex` — FOUND
- `test/support/fixtures/account_link.ex` — FOUND
- `test/support/fixtures/login_link.ex` — FOUND
- `test/lattice_stripe/client_stripe_account_header_test.exs` — FOUND
- `scripts/verify_stripe_mock_reject.exs` — FOUND
- `.planning/phases/17-connect-accounts-links/17-VALIDATION.md` — FOUND

Commits exist: a1a101c, acced1f, e3539e9 — all in `git log --oneline`.

Full suite: `mix test` → 1037 tests, 0 failures (89 excluded integration tests).
