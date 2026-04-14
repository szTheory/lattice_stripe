---
phase: 21-customer-portal
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - scripts/verify_portal_endpoint.exs
  - test/support/fixtures/billing_portal.ex
  - test/lattice_stripe/billing_portal/session_test.exs
  - test/lattice_stripe/billing_portal/guards_test.exs
  - test/lattice_stripe/billing_portal/session/flow_data_test.exs
  - test/integration/billing_portal_session_integration_test.exs
  - .planning/phases/21-customer-portal/21-VALIDATION.md
autonomous: true
requirements:
  - TEST-02
  - TEST-04
must_haves:
  truths:
    - "stripe-mock confirmed serving POST /v1/billing_portal/sessions with 200 on happy path"
    - "stripe-mock behavior documented: sub-field validation NOT enforced; unknown type → 422"
    - "Shared fixture module provides Session + one FlowData shape per flow type"
    - "Test file skeletons exist for every Wave 0 dependency referenced by later plans"
    - "21-VALIDATION.md Per-Task Verification Map populated with real task IDs"
  artifacts:
    - path: "scripts/verify_portal_endpoint.exs"
      provides: "stripe-mock probe for /v1/billing_portal/sessions documenting sub-field gap"
      contains: "/v1/billing_portal/sessions"
    - path: "test/support/fixtures/billing_portal.ex"
      provides: "LatticeStripe.Test.Fixtures.BillingPortal with Session + 4 flow-type fixtures"
      contains: "defmodule LatticeStripe.Test.Fixtures.BillingPortal"
    - path: "test/lattice_stripe/billing_portal/session_test.exs"
      provides: "Skeleton for PORTAL-01/02/05/06 + Inspect masking unit tests"
    - path: "test/lattice_stripe/billing_portal/guards_test.exs"
      provides: "Skeleton for PORTAL-04 guard matrix (10 cases)"
    - path: "test/lattice_stripe/billing_portal/session/flow_data_test.exs"
      provides: "Skeleton for PORTAL-03 FlowData.from_map decode cases"
    - path: "test/integration/billing_portal_session_integration_test.exs"
      provides: "Skeleton for TEST-05 portal integration"
  key_links:
    - from: "test/support/fixtures/billing_portal.ex"
      to: "test/lattice_stripe/billing_portal/*_test.exs"
      via: "alias LatticeStripe.Test.Fixtures.BillingPortal"
      pattern: "Test.Fixtures.BillingPortal"
---

<objective>
Wave 0 bootstrap for Phase 21: Customer Portal. Probe stripe-mock for `/v1/billing_portal/sessions`, build the canonical BillingPortal fixture module, and scaffold every test file referenced by later plans so that no downstream `<automated>` verify command hits MISSING. Populate 21-VALIDATION.md's Per-Task Verification Map.

Purpose: Unblock plans 21-02 through 21-04 by landing probe output, fixtures, and skeleton tests ahead of implementation.
Output: 1 probe script, 1 fixture module, 4 skeleton test files, 21-VALIDATION.md with real task IDs.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md
@.planning/phases/21-customer-portal/21-CONTEXT.md
@.planning/phases/21-customer-portal/21-RESEARCH.md
@.planning/phases/21-customer-portal/21-VALIDATION.md
@scripts/verify_meter_endpoints.exs
@test/support/fixtures/metering.ex
@test/integration/checkout_session_integration_test.exs

<interfaces>
<!-- Shape of LatticeStripe.Test.Fixtures.* modules (from metering.ex) -->
defmodule LatticeStripe.Test.Fixtures.Metering do
  @moduledoc false
  defmodule Meter do
    def basic(overrides \\ %{}), do: ...
  end
end

<!-- Canonical BillingPortal.Session response (from stripe-mock probe — RESEARCH.md "Stripe API Surface") -->
%{
  "id" => "bps_123",
  "object" => "billing_portal.session",
  "customer" => "cus_test123",
  "url" => "https://billing.stripe.com/session/test_token",
  "return_url" => "https://example.com/account",
  "configuration" => "bpc_123",
  "on_behalf_of" => nil,
  "locale" => nil,
  "created" => 1_712_345_678,
  "livemode" => false,
  "flow" => nil
}
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Probe stripe-mock + write verify_portal_endpoint.exs</name>
  <files>scripts/verify_portal_endpoint.exs</files>
  <action>
Mirror `scripts/verify_meter_endpoints.exs` using `:httpc` (NOT `LatticeStripe.Client` — anti-pattern per RESEARCH.md). Single endpoint: `POST http://localhost:12111/v1/billing_portal/sessions`. Probe THREE cases and print results:
  1. Happy path: `customer=cus_test123` → expect HTTP 200 with `url` field non-empty.
  2. Missing customer: no params → expect HTTP 422.
  3. Unknown flow_data.type: `customer=cus_test123&flow_data[type]=unknown_type` → expect HTTP 422 "value is not in enumeration".
  4. Sub-field gap confirmation: `customer=cus_test123&flow_data[type]=subscription_cancel` (no subscription) → document that stripe-mock returns HTTP 200 (this is the sub-field validation gap — RESEARCH Finding 1).
Exit 0 on all expectations matched; System.halt(1) with clear message otherwise. End with explicit `System.halt(0)` (per Phase 20 IN-04 fix). Header comment documents the RESEARCH Finding 1 gap as the reason the D-01 guard matrix lives in unit tests not integration tests.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && docker ps --format '{{.Names}}' | grep -q stripe-mock && elixir scripts/verify_portal_endpoint.exs</automated>
  </verify>
  <done>Script runs clean against stripe-mock, prints probe results for all 4 cases, exits 0.</done>
</task>

<task type="auto">
  <name>Task 2: Create BillingPortal fixture module</name>
  <files>test/support/fixtures/billing_portal.ex</files>
  <action>
Create `LatticeStripe.Test.Fixtures.BillingPortal` following `test/support/fixtures/metering.ex` shape (NOT `LatticeStripe.Fixtures.*` — that namespace is a Phase 20 anti-pattern per RESEARCH.md). Namespace convention: `LatticeStripe.Test.Fixtures.BillingPortal`.

Provide nested `Session` submodule with these builders, each taking `overrides \\ %{}` and returning a string-keyed map merged with overrides:

  - `basic/1` — canonical Session response (all 11 fields from interfaces block above, `"flow" => nil`).
  - `with_payment_method_update_flow/1` — basic + `"flow" => %{"type" => "payment_method_update", "after_completion" => %{"type" => "portal_homepage"}, "subscription_cancel" => nil, "subscription_update" => nil, "subscription_update_confirm" => nil}`.
  - `with_subscription_cancel_flow/1` — basic + flow with `"type" => "subscription_cancel"` and populated `"subscription_cancel" => %{"subscription" => "sub_123", "retention" => nil}`. Other three branch keys nil.
  - `with_subscription_update_flow/1` — flow with `"type" => "subscription_update"`, populated `"subscription_update" => %{"subscription" => "sub_456"}`.
  - `with_subscription_update_confirm_flow/1` — flow with `"type" => "subscription_update_confirm"`, populated `"subscription_update_confirm" => %{"subscription" => "sub_789", "items" => [%{"id" => "si_123", "price" => "price_abc"}], "discounts" => []}`.

TEST-02 requirement: fixture module exists with one FlowData shape per flow type. `@moduledoc false` on parent and nested Session module.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix compile --warnings-as-errors</automated>
  </verify>
  <done>Fixture module compiles; 5 builder functions exported from nested Session module; covers all 4 flow types for TEST-02.</done>
</task>

<task type="auto">
  <name>Task 3: Scaffold test skeletons + populate 21-VALIDATION.md</name>
  <files>test/lattice_stripe/billing_portal/session_test.exs, test/lattice_stripe/billing_portal/guards_test.exs, test/lattice_stripe/billing_portal/session/flow_data_test.exs, test/integration/billing_portal_session_integration_test.exs, .planning/phases/21-customer-portal/21-VALIDATION.md</action>
  <action>
Create four test-file skeletons. Each file is a valid ExUnit module that compiles and passes (zero tests or @tag :skip stubs — no red tests allowed in Wave 0).

1. `test/lattice_stripe/billing_portal/session_test.exs`
   - `defmodule LatticeStripe.BillingPortal.SessionTest do use ExUnit.Case, async: true`
   - `@moduletag :billing_portal`
   - `alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures`
   - Describe blocks (all skipped via `@tag :skip`):
     - `describe "create/3"` — PORTAL-01, PORTAL-02, PORTAL-06 (stripe_account: opt threads via Mox)
     - `describe "from_map/1"` — PORTAL-05 (all 10 struct fields decoded)
     - `describe "Inspect impl"` — D-03 (2 tests: visible fields present; `refute =~ session.url`, `refute =~ "FlowData"`)

2. `test/lattice_stripe/billing_portal/guards_test.exs`
   - `defmodule LatticeStripe.BillingPortal.GuardsTest do use ExUnit.Case, async: true`
   - `@moduletag :billing_portal`
   - `describe "check_flow_data!/1"` — PORTAL-04 ten-case guard matrix (CONTEXT.md D-01 test matrix #1-#10), all `@tag :skip`.

3. `test/lattice_stripe/billing_portal/session/flow_data_test.exs`
   - `defmodule LatticeStripe.BillingPortal.Session.FlowDataTest do use ExUnit.Case, async: true`
   - `@moduletag :billing_portal`
   - `describe "from_map/1"` — PORTAL-03 decode cases for all 4 flow types + nil + extra-capture of unknown keys; all `@tag :skip`.

4. `test/integration/billing_portal_session_integration_test.exs`
   - `defmodule LatticeStripe.BillingPortal.SessionIntegrationTest do use ExUnit.Case, async: false`
   - `@moduletag :integration`
   - `@moduletag :billing_portal`
   - Copy `setup_all` stripe-mock probe block from `test/integration/checkout_session_integration_test.exs` (lines 1-84 per RESEARCH Pattern 6).
   - `test "create/3 returns %Session{url: url} against stripe-mock", %{client: _client}` — `@tag :skip` stub.

Then edit `.planning/phases/21-customer-portal/21-VALIDATION.md`:
   - Set frontmatter `nyquist_compliant: true` and `wave_0_complete: true`.
   - Replace the TBD row in Per-Task Verification Map with real rows — one row per task across plans 21-01 through 21-04. Use task IDs matching the form `{plan}-T{NN}`. Reference the task numbers in this plan (01-T1, 01-T2, 01-T3) plus the planned tasks in 21-02/21-03/21-04 (see plan frontmatter for those). Columns: Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status.
   - Fill in Wave 0 Requirements checkboxes as ✅.
   - Tick the Validation Sign-Off box list.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix test test/lattice_stripe/billing_portal/ test/integration/billing_portal_session_integration_test.exs --include billing_portal --exclude integration 2>&1 | tail -20</automated>
  </verify>
  <done>All four test files compile and run green (skipped tests count). 21-VALIDATION.md Per-Task Verification Map has real task IDs for every task across plans 21-01..21-04. `nyquist_compliant: true`.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| fixture → test → log output | Fixture URLs are fake but establish the "url must never appear in logs" precedent tested by session_test.exs Inspect cases |
| probe script → stripe-mock | Local trusted loopback; no network exposure |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-21-01 | Information Disclosure | fixture `url` values in test output | accept | Fixture URLs are fake `https://billing.stripe.com/session/test_token` placeholders; no real bearer credential; session_test.exs asserts `refute inspect(session) =~ session.url` to catch Inspect regressions in 21-03. |
| T-21-02 | Tampering | probe script against non-local stripe-mock | accept | Script targets `localhost:12111` only; fails fast if docker container absent. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` clean
- `mix test test/lattice_stripe/billing_portal/ --include billing_portal` runs (all skipped, zero failures)
- `elixir scripts/verify_portal_endpoint.exs` exits 0 with all 4 probe cases matching expectations
- 21-VALIDATION.md Per-Task Verification Map populated for all 4 plans
</verification>

<success_criteria>
1. stripe-mock behavior documented in probe output (4 cases).
2. `LatticeStripe.Test.Fixtures.BillingPortal.Session` exports 5 builder functions.
3. 4 test files exist, compile, run green as skipped stubs.
4. 21-VALIDATION.md has no TBD rows; `nyquist_compliant: true`.
</success_criteria>

<output>
After completion, create `.planning/phases/21-customer-portal/21-01-wave0-bootstrap-SUMMARY.md`.
</output>
