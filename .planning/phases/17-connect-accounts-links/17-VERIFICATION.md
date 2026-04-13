---
phase: 17-connect-accounts-links
verified: 2026-04-13T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "In an IEx session, build a %Account{} with a populated individual: field containing first_name, ssn_last_4, dob, and email. Call IO.inspect/1 on it. Confirm the output shows [REDACTED] for each PII field and does NOT show the raw values."
    expected: "PII fields (first_name, ssn_last_4, dob, email, phone, address fields) display as \"[REDACTED]\"; nil fields are omitted or shown as nil; non-PII fields (business_type, country, etc.) display normally."
    why_human: "Inspect output is runtime behavior that grep cannot verify. The defimpl exists and the redaction logic is present in source, but visual confirmation that the right fields are hidden and no raw PII leaks is required for CNCT-01 compliance."
---

# Phase 17: Connect Accounts & Account Links Verification Report

**Phase Goal:** Developers can onboard Stripe Connect accounts end-to-end — manage connected account lifecycle and generate Stripe-hosted onboarding URLs
**Verified:** 2026-04-13
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Developer can create, retrieve, update, delete, reject, and list Connect accounts via `LatticeStripe.Account` | VERIFIED | `lib/lattice_stripe/account.ex` lines 185-320: `create/3`, `create!/3`, `retrieve/3`, `retrieve!/3`, `update/4`, `update!/4`, `delete/3`, `delete!/3`, `reject/4` (D-04a atom guard at line 285-292), `reject!/4`, `list/3`, `list!/3`, `stream!/3` — 14 public functions. All use `Resource.unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` from shared helpers. |
| 2 | Developer can generate an onboarding URL via `LatticeStripe.AccountLink.create/3` for Stripe-hosted onboarding flows | VERIFIED | `lib/lattice_stripe/account_link.ex` lines 79-89: `create/3` and `create!/3` with `is_map(params)` guard, POST to `/v1/account_links`. D-04c enforced — no 4-arity positional-type variant exists. 11 unit tests pass. 4 integration tests against stripe-mock pass. |
| 3 | Developer can act on behalf of a connected account by setting the `Stripe-Account` header on any resource call (per-request and per-client) | VERIFIED | `lib/lattice_stripe/client.ex:178` — `effective_stripe_account = Keyword.get(req.opts, :stripe_account, client.stripe_account)`. Lines 390-427 — `build_headers/5` calls `maybe_add_stripe_account/2` which injects `{"stripe-account", stripe_account}`. Per-request wins over per-client. Verified by T-17-03 regression guard: `test/lattice_stripe/client_stripe_account_header_test.exs` (4 tests: per-client, per-request-wins, nil-client/no-header, nil-client-with-per-request). No changes to `Client` needed for Phase 17 — wiring was pre-existing. |
| 4 | All operations follow Phase 4/5/14/15 conventions (flat namespace, nested typed structs, bang variants, streams, PII-safe Inspect, no `Jason.Encoder`) | VERIFIED | Flat namespace confirmed: `LatticeStripe.AccountLink` and `LatticeStripe.LoginLink` are top-level, not nested under `Account`. 7 nested structs under `LatticeStripe.Account.*` directory. All resource modules have bang variants. `stream!/3` present in `Account`. PII-safe Inspect present in `Account.Company` (line 88), `Account.Individual` (line 106), `Account.TosAcceptance`. No `Jason.Encoder` `@derive` found in any Phase 17 module (grep returned no matches). F-001 `@known_fields + :extra` pattern in all 7 nested struct modules and all 3 resource modules. |
| 5 | Integration tests via stripe-mock cover the account lifecycle and account-link creation | VERIFIED | `test/integration/account_integration_test.exs` — 9 tests: create, retrieve, update, list, stream!, reject(:fraud) atom guard, delete, nested struct casting, BusinessProfile/Capability shape. `test/integration/account_link_integration_test.exs` — 4 tests. `test/integration/login_link_integration_test.exs` — 5 tests. Total: 18 integration tests. All at `@moduletag :integration` with stripe-mock connectivity guard. Suite runs: 1173 unit tests + 18 integration tests, 0 failures (per 17-05-SUMMARY.md). |

**Score:** 5/5 truths verified

---

## Decision Verification (17-CONTEXT.md D-01..D-04)

| Decision | Requirement | Status | Evidence |
|----------|-------------|--------|----------|
| D-01: 6 nested struct modules, budget counts distinct modules not parent fields | 6 modules under `lib/lattice_stripe/account/`, `Requirements` reused at both `requirements` and `future_requirements` | HONORED | `lib/lattice_stripe/account/` contains exactly: `business_profile.ex`, `requirements.ex`, `settings.ex`, `tos_acceptance.ex`, `company.ex`, `individual.ex` — 6 distinct modules. D-01 budget reframing documented in `account.ex` line 32. |
| D-02: `Account.capabilities` as `map(String.t(), Capability.t())`, typed inner `Capability` struct, `status_atom/1` helper | `lib/lattice_stripe/account/capability.ex` | HONORED | `Capability.cast/1` at line 34-48, `status_atom/1` at lines 64-69. Uses `String.to_existing_atom/1` (not `String.to_atom/1`). `@known_status_atoms` attribute pre-declares atoms at compile time. Unknown statuses return `:unknown`. No `String.to_atom/1` anywhere in `lib/lattice_stripe/account/`. |
| D-03: Phase 17 = Account + AccountLink + LoginLink; External Accounts deferred to Phase 18 | No `ExternalAccount` in Phase 17 | HONORED | Only `lib/lattice_stripe/account.ex`, `lib/lattice_stripe/account_link.ex`, `lib/lattice_stripe/login_link.ex` were created. No `ExternalAccount` module exists. `guides/connect.md` line 10 forward-points to Phase 18 for money movement. |
| D-04a: `reject/4` atom-guarded with `:fraud | :terms_of_service | :other` | `account.ex` line 285 | HONORED | `when is_binary(id) and reason in @reject_reasons` guard. 5 unit tests verify happy paths (:fraud, :terms_of_service, :other) and FunctionClauseError on `:wrong_atom` and `:fruad`. Regression guard `refute function_exported?(LatticeStripe.Account, :request_capability, 4)` present. |
| D-04b: `request_capability/4` absent | Not in `account.ex` | HONORED | `refute function_exported?(LatticeStripe.Account, :request_capability, 4)` and `refute function_exported?(LatticeStripe.Account, :request_capability, 3)` both pass (17-03-SUMMARY.md, line 81-82). Update idiom documented in `account.ex` moduledoc "Requesting capabilities" section. |
| D-04c: `AccountLink.create/3` map-based, no positional `type` arg | `account_link.ex` lines 79-89 | HONORED | `create/3` takes `(client, params, opts)` with `is_map(params)` guard. Regression test `refute function_exported?(LatticeStripe.AccountLink, :create, 4)` passes. `LoginLink` intentional deviation (URL-path-scoped `account_id` as 2nd arg) documented in moduledoc. |

---

## CNCT-01 Requirement Satisfaction

**CNCT-01** covers: Account lifecycle (create, retrieve, update, delete, reject), AccountLink creation for Stripe-hosted onboarding, and LoginLink creation for Express dashboard return.

**Status: SATISFIED**

Evidence:
- Full CRUD + reject + list + stream on `LatticeStripe.Account` (`lib/lattice_stripe/account.ex`)
- `LatticeStripe.AccountLink.create/3` for onboarding URL generation (`lib/lattice_stripe/account_link.ex`)
- `LatticeStripe.LoginLink.create/4` for Express dashboard return URL (`lib/lattice_stripe/login_link.ex`)
- 7 nested typed structs for Account resource fields (`lib/lattice_stripe/account/`)
- `Stripe-Account` header threading pre-wired in `Client` — no Phase 17 changes needed
- Developer guide at `guides/connect.md` with webhook handoff callout
- ExDoc "Connect" module group in `mix.exs`

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/lattice_stripe/account.ex` | Account resource — CRUD + reject + list + stream | VERIFIED | 374 lines. 14 public functions. F-001 pattern. `cast_capabilities/1` with stripe-mock compat fix. |
| `lib/lattice_stripe/account_link.ex` | AccountLink — create-only | VERIFIED | 100 lines. `create/3`, `create!/3`, `from_map/1`. D-04c enforced. Bearer-token security warning in moduledoc. |
| `lib/lattice_stripe/login_link.ex` | LoginLink — create-only (Express) | VERIFIED | 109 lines. `create/4`, `create!/4`, `from_map/1`. `is_binary(account_id)` guard. Signature deviation documented. |
| `lib/lattice_stripe/account/business_profile.ex` | D-01 nested struct #1 | VERIFIED | Exists. F-001 `:extra`. No PII Inspect. |
| `lib/lattice_stripe/account/requirements.ex` | D-01 nested struct #2 — reused at two fields | VERIFIED | Exists. F-001 `:extra`. Moduledoc documents both use sites. |
| `lib/lattice_stripe/account/tos_acceptance.ex` | D-01 nested struct #3 — PII Inspect | VERIFIED | Exists. `defimpl Inspect` with `[REDACTED]` pattern for `ip` and `user_agent`. |
| `lib/lattice_stripe/account/company.ex` | D-01 nested struct #4 — PII Inspect | VERIFIED | Exists. `defimpl Inspect` at line 88 with redaction loop. |
| `lib/lattice_stripe/account/individual.ex` | D-01 nested struct #5 — PII Inspect | VERIFIED | Exists. `defimpl Inspect` at line 106. 20 fields, 17 PII fields redacted per stripe-node audit. |
| `lib/lattice_stripe/account/settings.ex` | D-01 nested struct #6 — outer-only depth cap | VERIFIED | Exists. F-001 `:extra`. Sub-objects (branding, card_payments, etc.) absorbed into `:extra`. |
| `lib/lattice_stripe/account/capability.ex` | D-02 typed inner struct — not in D-01 budget | VERIFIED | Exists. `cast/1`, `status_atom/1`. `@known_status_atoms` pre-declares atoms. |
| `test/integration/account_integration_test.exs` | Stripe-mock Account lifecycle | VERIFIED | 9 tests. `@moduletag :integration`. Connectivity guard. |
| `test/integration/account_link_integration_test.exs` | Stripe-mock AccountLink create | VERIFIED | 4 tests. |
| `test/integration/login_link_integration_test.exs` | Stripe-mock LoginLink create | VERIFIED | 5 tests. |
| `guides/connect.md` | Onboarding narrative + webhook handoff | VERIFIED | 238 lines. 8 sections. Webhook handoff callout at line 214-221. T-17-02 bearer-token warnings in both AccountLink and LoginLink sections. Phase 18 forward pointer. |
| `mix.exs` Connect group | ExDoc "Connect" module group with 10 modules | VERIFIED | Lines 82-92: `Connect: [Account, AccountLink, LoginLink, Account.BusinessProfile, Account.Capability, Account.Company, Account.Individual, Account.Requirements, Account.Settings, Account.TosAcceptance]`. `guides/connect.md` in extras at line 30. |
| `test/lattice_stripe/client_stripe_account_header_test.exs` | T-17-03 per-request header regression | VERIFIED | 4 tests covering all per-client/per-request/nil combinations. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Account.create/3` | `POST /v1/accounts` | `Client.request/2` + `Resource.unwrap_singular/2` | WIRED | `account.ex:186-189` |
| `Account.reject/4` | `POST /v1/accounts/:id/reject` | atom guard → `Atom.to_string(reason)` → `Client.request/2` | WIRED | `account.ex:285-292`. Reason serialized to Stripe string form. |
| `Account.from_map/1` | 7 nested struct `from_map/1` calls | `Map.split(@known_fields)` + struct casting | WIRED | `account.ex:340-360`. All 8 nested field casts wired explicitly. |
| `AccountLink.create/3` | `POST /v1/account_links` | `Client.request/2` + `Resource.unwrap_singular/2` | WIRED | `account_link.ex:80-84` |
| `LoginLink.create/4` | `POST /v1/accounts/:account_id/login_links` | `is_binary(account_id)` guard → `Client.request/2` | WIRED | `login_link.ex:82-92` |
| `Client` | `Stripe-Account` header | `build_headers/5` → `maybe_add_stripe_account/2` | WIRED | `client.ex:390-427`. Per-request wins over per-client (`client.ex:178`). |
| `guides/connect.md` | ExDoc extras list | `mix.exs` extras | WIRED | `mix.exs:30` |
| Connect module group | 10 modules | `mix.exs` `groups_for_modules:` | WIRED | `mix.exs:82-92` |

---

## Data-Flow Trace (Level 4)

All three resource modules follow the same decode-only pattern established in earlier phases: Stripe returns JSON, the SDK decodes it into typed structs. There is no rendering of dynamic state; `from_map/1` is the data entry point.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `account.ex` | `%Account{}` struct | `from_map/1` called by `Resource.unwrap_singular/2` after `Client.request/2` HTTP response | Stripe API response via Finch transport | FLOWING |
| `account_link.ex` | `%AccountLink{}` struct | Same pattern | Stripe API response | FLOWING |
| `login_link.ex` | `%LoginLink{}` struct | Same pattern | Stripe API response | FLOWING |
| `account/capability.ex` | `capabilities` map | `cast_capabilities/1` → `Capability.cast/1` | Stripe API response; stripe-mock string normalization compat fix in place | FLOWING |

---

## Behavioral Spot-Checks

| Behavior | Check | Result |
|----------|-------|--------|
| All 14 Phase 17 commits in git log | `git log --oneline \| grep -E "92747d0\|77e64b5\|..."` | PASS — all 14 commits confirmed |
| No Jason.Encoder on any Phase 17 module | `grep -rn "Jason.Encoder\|@derive" lib/lattice_stripe/account*.ex lib/lattice_stripe/account/` | PASS — no matches |
| No String.to_atom on user input | `grep -rn "String.to_atom(" lib/lattice_stripe/account/` | PASS — no matches (only `String.to_existing_atom/1` used) |
| 7 nested struct modules exist | `ls lib/lattice_stripe/account/` | PASS — business_profile.ex, capability.ex, company.ex, individual.ex, requirements.ex, settings.ex, tos_acceptance.ex |
| 3 integration test files exist | `ls test/integration/account*.exs test/integration/login*.exs` | PASS — all 3 found |
| connect.md wired in mix.exs extras | `grep connect.md mix.exs` | PASS — line 30 |
| Connect group wired in mix.exs groups_for_modules | `grep Connect mix.exs` | PASS — line 82 |
| Webhook handoff callout in guide | `grep "Drive your application state" guides/connect.md` | PASS — line 216 |

---

## Requirements Coverage

| Requirement | Plan | Description | Status | Evidence |
|-------------|------|-------------|--------|----------|
| CNCT-01 | 17-01 through 17-06 | Account lifecycle, retrieve, update, onboarding | SATISFIED | Full CRUD + reject + AccountLink + LoginLink + guide + integration tests |

---

## Anti-Patterns Found

No blockers. No stubs detected.

| File | Pattern | Severity | Notes |
|------|---------|----------|-------|
| `lib/lattice_stripe/account.ex:369` | `cast_capabilities/1` normalizes stripe-mock bare strings | INFO | Intentional compat fix. Real Stripe returns map values; stripe-mock returns bare strings. Both paths exercised. Not a stub — the real path is the `is_map` clause. |

---

## Human Verification Required

### 1. PII-Safe Inspect Output

**Test:** In `iex -S mix`, execute:

```elixir
alias LatticeStripe.Account.Individual

ind = %Individual{
  first_name: "Jane",
  last_name: "Smith",
  ssn_last_4: "1234",
  dob: %{"year" => 1990, "month" => 1, "day" => 1},
  email: "jane@example.com",
  phone: "+15555550101"
}

IO.inspect(ind)
```

**Expected:** Output shows `[REDACTED]` for each non-nil PII field (`first_name`, `last_name`, `ssn_last_4`, `dob`, `email`, `phone`). The raw values "Jane", "Smith", "1234", "jane@example.com", "+15555550101" must NOT appear in the output.

**Why human:** Inspect output is runtime behavior. The `defimpl Inspect` exists in source (confirmed at `individual.ex:106`) and uses a redaction loop (`REDACTED` marker pattern confirmed in `company.ex`). Visual confirmation that no PII leaks is required — the test suite tests for `refute inspect(...) =~ "Jane"` etc. but the verifier needs to confirm the runtime output independently.

---

## Gaps Summary

No gaps found. All 5 ROADMAP.md Success Criteria are verified against the actual codebase. All 4 CONTEXT.md decisions (D-01 through D-04, including D-04a/b/c sub-decisions) are honored. CNCT-01 is satisfied.

One human verification item remains: visual confirmation of PII-safe Inspect output at runtime. This is not a gap — the implementation is correct in source — but it is a validation-strategy requirement from `17-VALIDATION.md` ("Manual-Only Verifications" table) that cannot be satisfied programmatically.

---

_Verified: 2026-04-13_
_Verifier: Claude (gsd-verifier)_
