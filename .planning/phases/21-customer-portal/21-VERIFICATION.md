---
phase: 21-customer-portal
verified: 2026-04-14T22:30:00Z
status: passed
score: 4/4
overrides_applied: 0
gaps: []
resolved_gaps:
  - truth: "mix docs --warnings-as-errors is clean"
    resolved_in: "commit 1d1d8af"
    fix: "Replaced @moduledoc false backtick refs in session.ex:41, customer-portal.md:52, and the pre-existing meter.ex:83 (drive-by) with plain prose. mix docs --warnings-as-errors now exits 0."
---

# Phase 21: Customer Portal Verification Report

**Phase Goal:** Elixir developers (and Accrue) can create a Stripe customer portal session with a single function call, receiving a short-lived URL they can redirect customers to — with deep-link flow support and early validation that prevents server-side 400s for missing required sub-fields.
**Verified:** 2026-04-14T22:00:00Z
**Status:** gaps_found (1 gap: mix docs --warnings-as-errors not clean)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `BillingPortal.Session.create/3` with valid customer returns `{:ok, %Session{url: url}}` with non-empty string, verified against stripe-mock | VERIFIED | 5 integration tests in `billing_portal_session_integration_test.exs` all green; test 1 asserts `url =~ ~r{^https://}` |
| 2 | `Session.create/3` raises `ArgumentError` pre-network for missing customer and for missing required flow sub-fields (`subscription`, `items`) | VERIFIED | `session_test.exs` tests "raises ArgumentError pre-network when customer param is missing" and "raises via Guards pre-network when flow_data is malformed"; `guards_test.exs` cases 3-9 cover all sub-field scenarios; `verify_on_exit!` Mox assertion confirms no Transport call is made |
| 3 | `Session.create/3` raises `ArgumentError` with clear message when unknown `flow_data.type` is passed | VERIFIED | `guards_test.exs` case 10 asserts `~r/unknown flow_data\.type/` and that all 4 valid type strings appear in the error message |
| 4 | `BillingPortal.Session` struct's Inspect implementation masks the `:url` field | VERIFIED | Three Inspect tests in `session_test.exs` — "masks :url and :flow in Inspect output" uses `refute output =~ session.url` and `refute output =~ "secret_abc"`; "url is masked in inspect output" and "flow is masked in inspect output" cover the live fixture path |

**Roadmap Score: 4/4 truths verified**

### Plan-Level Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `Session.create/3` returns `{:ok, %Session{}}` via Mox-mocked Transport | VERIFIED | `session_test.exs` test "returns {:ok, %Session{}} on success" |
| 2 | `Session.create/3` raises pre-network for missing customer | VERIFIED | `session_test.exs` test "raises ArgumentError pre-network when customer param is missing" |
| 3 | `Session.create/3` raises pre-network for all 4 guard-matrix missing-field cases | VERIFIED | `guards_test.exs` 13 cases green; all raise cases assert function-name prefix |
| 4 | `Session.create/3` raises for unknown `flow_data.type` enumerating 4 valid types | VERIFIED | `guards_test.exs` case 10 + "all raise cases include function name prefix" test |
| 5 | `Session.create!/3` bang variant raises on error | VERIFIED | `session_test.exs` test "raises LatticeStripe.Error on API error" via `create!` |
| 6 | `Session.create/3` threads `stripe_account:` opt through to request headers | VERIFIED | `session_test.exs` test "threads stripe_account: opt as Stripe-Account header" asserts `{"stripe-account", "acct_test"} in req_map.headers` via Mox |
| 7 | Session struct Inspect masks `:url` and `:flow` | VERIFIED | Three Inspect tests; `defimpl Inspect` at session.ex:250 implements allowlist |
| 8 | `Session.from_map/1` decodes all 10 PORTAL-05 fields + flow via `FlowData.from_map/1` | VERIFIED | `session_test.exs` "decodes all struct fields from basic fixture" asserts all 11 fields; "decodes flow field into %FlowData{} when present" asserts `session.flow.subscription_cancel.subscription == "sub_123"` |
| 9 | Integration test against stripe-mock creates portal session with non-empty url | VERIFIED | `billing_portal_session_integration_test.exs` test 1: `assert String.length(session.url) > 0 and session.url =~ ~r{^https://}` |
| 10 | `guides/customer-portal.md` exists at ~240 lines with 7 H2 sections per D-04 | VERIFIED | 280 lines (within 240 ± 40 envelope); exactly 7 H2 sections confirmed |
| 11 | `mix.exs groups_for_modules` has "Customer Portal" group with 6 modules | VERIFIED | `mix.exs` lines 87-94: `"Customer Portal": [Session, FlowData, FlowData.AfterCompletion, FlowData.SubscriptionCancel, FlowData.SubscriptionUpdate, FlowData.SubscriptionUpdateConfirm]` |
| 12 | `mix.exs extras` includes `guides/customer-portal.md` | VERIFIED | `mix.exs` line 34 |
| 13 | `guides/subscriptions.md` and `guides/webhooks.md` have reciprocal cross-links | VERIFIED | `subscriptions.md` lines 77 and 151 link to `customer-portal.html#canceling-a-subscription` and `customer-portal.html#updating-a-subscription`; `webhooks.md` line 443 links to `customer-portal.html#security-and-session-lifetime` |
| 14 | `mix docs --warnings-as-errors` is clean | FAILED | Two ExDoc warnings (see Gaps Summary) |

**Plan Score: 13/14 must-haves verified**

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/lattice_stripe/billing_portal/session.ex` | Session resource module + defimpl Inspect | VERIFIED | 304 lines; `create/3`, `create!/3`, `from_map/1`, `defimpl Inspect`; no retrieve/list/update/delete |
| `lib/lattice_stripe/billing_portal/guards.ex` | Pre-flight validator `check_flow_data!/1` | VERIFIED | 89 lines; `@moduledoc false`; full dispatch matrix per D-01 |
| `lib/lattice_stripe/billing_portal/session/flow_data.ex` | Parent FlowData struct with 5 fields + `:extra` | VERIFIED | Verbatim from CONTEXT.md D-02 interface; delegates to all 4 sub-structs |
| `lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex` | AfterCompletion sub-struct | VERIFIED | `@known_fields ~w(type redirect hosted_confirmation)`; `from_map/1` two-clause |
| `lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex` | SubscriptionCancel sub-struct | VERIFIED | `subscription`, `retention` fields; `retention` kept as raw map |
| `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex` | SubscriptionUpdate sub-struct | VERIFIED | `subscription` field only |
| `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex` | SubscriptionUpdateConfirm sub-struct | VERIFIED | `subscription`, `items`, `discounts`; leaf objects as raw maps |
| `test/support/fixtures/billing_portal.ex` | Fixture module with Session + 4 flow builders | VERIFIED | `LatticeStripe.Test.Fixtures.BillingPortal.Session` with `basic/1` + 4 `with_*_flow/1` builders covering all flow types |
| `test/lattice_stripe/billing_portal/session_test.exs` | Session unit tests | VERIFIED | 16 tests, 0 failures, 0 skipped |
| `test/lattice_stripe/billing_portal/guards_test.exs` | Guards unit tests | VERIFIED | 13 tests (10 matrix + 3 extras), 0 failures |
| `test/lattice_stripe/billing_portal/session/flow_data_test.exs` | FlowData unit tests | VERIFIED | 18 tests, 0 failures |
| `test/integration/billing_portal_session_integration_test.exs` | Integration test against stripe-mock | VERIFIED | 5 tests, `:integration` tagged, `setup` creates real Customer |
| `guides/customer-portal.md` | MODERATE-envelope guide (240 lines ± 40, 7 H2) | VERIFIED | 280 lines, 7 H2, all 4 flow types covered, Phoenix example, Inspect masking teaching |
| `scripts/verify_portal_endpoint.exs` | stripe-mock probe for 4 cases | VERIFIED | Probes happy path, missing customer, unknown type, sub-field gap; exits 0 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `session.ex create/3` | `guards.ex check_flow_data!/1` | `Guards.check_flow_data!(params)` call pre-network | VERIFIED | `session.ex` line 206 calls `Guards.check_flow_data!(params)` after `Resource.require_param!` and before `Client.request` |
| `session.ex from_map/1` | `session/flow_data.ex from_map/1` | `FlowData.from_map(map["flow"])` | VERIFIED | `session.ex` line 244 |
| `flow_data.ex from_map/1` | `flow_data/*.ex` sub-modules | `AfterCompletion.from_map`, `SubscriptionCancel.from_map`, `SubscriptionUpdate.from_map`, `SubscriptionUpdateConfirm.from_map` | VERIFIED | `flow_data.ex` lines 46-51 delegate to all 4 sub-struct modules |
| `mix.exs groups_for_modules "Customer Portal"` | 6 BillingPortal modules | 6-entry module list | VERIFIED | `mix.exs` lines 87-94 |
| `guides/subscriptions.md` | `guides/customer-portal.md` | See also links in §Lifecycle operations and §Proration | VERIFIED | Lines 77 and 151 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `session.ex create/3` | `{:ok, %Session{url: url}}` | `Client.request/2` → `Resource.unwrap_singular(&from_map/1)` → `map["url"]` | Yes — real Stripe API response via Transport; integration test confirms non-empty HTTPS url from stripe-mock | FLOWING |
| `flow_data.ex from_map/1` | `%FlowData{}` | Stripe response `map["flow"]`; all 4 branch fields populated via `SubModule.from_map/1` | Yes — integration test 3 asserts `%FlowData{} = session.flow` | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Result | Status |
|----------|--------|--------|
| 47 billing_portal unit tests (session + guards + flow_data) | All 47 pass, 0 failures | PASS |
| 18 flow_data decode tests (nil, happy path, extra capture, atom dot-access) | All 18 pass | PASS |
| `mix compile --warnings-as-errors` | Exits 0, no warnings | PASS |
| `mix docs` (without `--warnings-as-errors`) | Generates docs, 2 warnings (see gaps) | PARTIAL |
| No `@tag :skip` remaining in any billing_portal test file | Zero skip tags found | PASS |
| No retrieve/list/update/delete in session.ex | Zero matches | PASS |
| guide 280 lines, 7 H2 sections | 280 / 7 | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PORTAL-01 | Plans 21-03, 21-04 | `Session.create/3` returns `{:ok, %Session{url: url}}` | SATISFIED | Unit test via Mox + 5 integration tests against stripe-mock |
| PORTAL-02 | Plan 21-03 | `create!/3` exists; no retrieve/list/update/delete | SATISFIED | `create!/3` at session.ex:218; grep confirms zero retrieve/list/update/delete definitions |
| PORTAL-03 | Plan 21-02 | `flow_data` decoded into typed `FlowData` struct with `@known_fields + :extra` | SATISFIED | 5-module tree; 18 decode tests; atom dot-access verified |
| PORTAL-04 | Plan 21-03 | `Session.create/3` validates `flow_data.type` pre-network | SATISFIED | `Guards.check_flow_data!/1` 13-case test matrix all green |
| PORTAL-05 | Plan 21-03 | Session struct exposes 11 fields including `flow` | SATISFIED | `@known_fields` has 11 entries; `from_map/1` test asserts all fields decoded |
| PORTAL-06 | Plan 21-03 | `Session.create/3` honors `stripe_account:` opt | SATISFIED | Mox header assertion test + integration test 4 |
| TEST-02 | Plan 21-01 | `billing_portal.ex` fixture with Session + 4 flow builders | SATISFIED | `LatticeStripe.Test.Fixtures.BillingPortal.Session` with `basic/1` + 4 flow builders |
| TEST-04 | Plan 21-01 | stripe-mock probe confirms `/v1/billing_portal/sessions` behavior | SATISFIED | `scripts/verify_portal_endpoint.exs` probes 4 cases; documents sub-field gap |
| TEST-05 (portal) | Plan 21-04 | Full integration test creates portal session with real customer | SATISFIED | 5 integration tests; REQUIREMENTS.md traceability table shows "Pending" but tests exist and pass |
| DOCS-02 | Plan 21-04 | `guides/customer-portal.md` with Phoenix example | SATISFIED | 280-line guide; §End-to-end Phoenix example has `portal_url/2` wrapper + `BillingController.portal/2` |
| DOCS-03 (Customer Portal) | Plan 21-04 | `groups_for_modules` "Customer Portal" group + guide in `extras` | SATISFIED | `mix.exs` lines 34 and 87-94 |

**Note:** REQUIREMENTS.md traceability table marks TEST-05 (portal) as "Pending" — this is a stale status in the document. The integration tests exist and pass.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/lattice_stripe/billing_portal/session.ex` | 41 | Backtick reference to `@moduledoc false` module `LatticeStripe.BillingPortal.Guards` | Warning | Causes `mix docs --warnings-as-errors` to fail; plan 21-04 SC #5 requires clean docs build |

No TODO/FIXME/HACK/placeholder comments. No empty implementations. No hardcoded empty data flowing to rendering. No debug artifacts.

---

### Human Verification Required

None. All acceptance criteria are verifiable programmatically.

---

### Gaps Summary

**1 gap blocks plan 21-04 success criterion #5 (`mix docs --warnings-as-errors` clean).**

`lib/lattice_stripe/billing_portal/session.ex` line 41 contains:

```
`LatticeStripe.BillingPortal.Guards` validates these shapes pre-network and raises
```

Because `LatticeStripe.BillingPortal.Guards` has `@moduledoc false`, ExDoc emits a warning when it encounters a backtick reference to it. The fix is one line: replace the backtick module reference with plain prose. The `guides/customer-portal.md` guide already avoids this by using plain text. The SUMMARY (plan 21-04) documents this as "pre-existing before plan 21-04 changes" — which is accurate (plan 21-03 introduced it). The warning from `meter.ex` is from Phase 20 and is not Phase 21's responsibility.

**Root cause:** The `@moduledoc false` pattern for internal guard modules (established in Phase 20 D-01) creates a structural tension with ExDoc backtick cross-references in the companion resource module's moduledoc. The pattern is to use plain prose when referencing internal modules.

**Fix:** Change `lib/lattice_stripe/billing_portal/session.ex` line 41 from:
```
`LatticeStripe.BillingPortal.Guards` validates these shapes pre-network and raises
```
to:
```
The pre-flight guard validates these shapes pre-network and raises
```
(or similar plain prose — no backtick cross-reference to the hidden module)

---

_Verified: 2026-04-14T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
