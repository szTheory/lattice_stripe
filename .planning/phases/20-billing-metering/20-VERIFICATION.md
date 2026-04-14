---
phase: 20-billing-metering
verified: 2026-04-14T00:00:00Z
status: gaps_found
score: 4/5 must-haves verified
overrides_applied: 0
overrides:
  - must_have: "Billing.Meter.create/3 raises ArgumentError when value_settings is absent for sum/last formula"
    reason: "D-01 in 20-CONTEXT.md explicitly amends ROADMAP SC #2: raise on present-but-malformed only, not on absence. Stripe defaults event_payload_key to 'value' when value_settings is omitted — this is a legal, documented wire shape. Raising on absence would break parity with every other Stripe SDK and reject valid input."
    accepted_by: "szTheory (locked in 20-CONTEXT.md D-01 pre-execution)"
    accepted_at: "2026-04-14T00:00:00Z"
gaps:
  - truth: "The phase's test suite exercises MeterEvent.create/3 and MeterEventAdjustment.create/3 against stripe-mock as part of the full metering lifecycle integration test"
    status: failed
    reason: "The integration test (meter_integration_test.exs) only covers the Meter lifecycle: create → retrieve → update → list → deactivate → reactivate. It does NOT call MeterEvent.create/3 or MeterEventAdjustment.create/3 against stripe-mock. ROADMAP SC #1 explicitly requires 'report events via MeterEvent.create/3' and 'adjust lifecycles' in the test suite. REQUIREMENTS TEST-05 requires 'seed a meter → report events through it → adjust one'. Unit tests for MeterEvent and MeterEventAdjustment pass (9 and 10 tests respectively) but these are mock-based, not against stripe-mock."
    artifacts:
      - path: "test/lattice_stripe/billing/meter_integration_test.exs"
        issue: "Missing MeterEvent.create/3 and MeterEventAdjustment.create/3 calls in the integration lifecycle test. The test covers Meter CRUDL verbs only."
    missing:
      - "Add MeterEvent.create/3 call in meter_integration_test.exs after creating the meter (report one event against the created meter)"
      - "Add MeterEventAdjustment.create/3 call with correct cancel.identifier nested shape"
      - "Both calls need only shape assertions (stripe-mock stateless caveat documented in existing test)"
---

# Phase 20: Billing Metering Verification Report

**Phase Goal:** Elixir developers (and Accrue) can configure usage-based billing meters, report metered usage events with correct idempotency, and make corrections — all with behavior and failure modes clearly documented so the silent-failure modes of Stripe's async metering pipeline cannot silently corrupt billing data.
**Verified:** 2026-04-14
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Developer can create a Meter, report events via MeterEvent.create/3, and the test suite passes against stripe-mock including deactivate, reactivate, list, and adjust lifecycles | PARTIAL | Meter lifecycle integration test green (stripe-mock); MeterEvent and MeterEventAdjustment have unit tests only — no integration test against stripe-mock for event reporting or adjustments |
| 2 | Billing.Meter.create/3 raises ArgumentError with clear message when value_settings is present-but-malformed for sum/last formulas | PASSED (override) | Override: D-01 amends ROADMAP SC #2 — raises on present-but-malformed, not absent. All 8 guard test cases green. |
| 3 | MeterEvent.create/3 @doc documents both idempotency layers and explicitly states {:ok, %MeterEvent{}} is "accepted for processing" with pointer to v1.billing.meter.error_report_triggered webhook | VERIFIED | meter_event.ex:49 contains "accepted for processing"; :34 "35-day"; :40 "idempotency_key"; :54 "v1.billing.meter.error_report_triggered". Code.fetch_docs test asserts all three strings — 1 test, 0 failures. |
| 4 | MeterEventAdjustment.create/3 @doc shows exact cancel.identifier nested shape and unit tests assert correct from_map/1 decoding | VERIFIED | cancel.ex defines Cancel struct with single :identifier field. from_map/1 decodes via Cancel.from_map(map["cancel"]). Test asserts %MeterEventAdjustment{cancel: %Cancel{identifier: "req_abc"}} = adj and refute Map.has_key?(adj, :identifier). 4 from_map/1 tests + 4 shape guard tests green. |
| 5 | guides/metering.md contains Monitoring section with v1.billing.meter.error_report_triggered error codes, two-layer idempotency example, backdating window warning, and cross-links from sibling guides | VERIFIED | 620 lines. Contains: "error_report_triggered" (multiple), "35-day", "UsageReporter" module ~40 lines, "Two-layer idempotency" H3, 7-row error code table with archived_meter/meter_event_customer_not_found/timestamp_too_far_in_past. All 5 sibling guides contain metering.md links. |

**Score:** 4/5 truths verified (SC #1 partial — integration test missing event + adjustment calls)

### Deferred Items

None.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---------|---------|--------|---------|
| `lib/lattice_stripe/billing/meter.ex` | Billing.Meter CRUDL + lifecycle verbs + bang variants + status_atom/1 + from_map/1 | VERIFIED | 14 exports confirmed: create/3, create!/3, retrieve/3, retrieve!/3, update/4, update!/4, list/3, list!/3, stream!/3, deactivate/3, deactivate!/3, reactivate/3, reactivate!/3, status_atom/1, from_map/1 |
| `lib/lattice_stripe/billing/meter/default_aggregation.ex` | Simple value struct, no :extra | VERIFIED | defstruct [:formula]; from_map/1 handles nil; no :extra field |
| `lib/lattice_stripe/billing/meter/customer_mapping.ex` | @known_fields + :extra capture | VERIFIED | @known_fields ~w(event_payload_key type); Map.drop/2 captures unknown fields |
| `lib/lattice_stripe/billing/meter/value_settings.ex` | Simple value struct, no :extra | VERIFIED | defstruct [:event_payload_key]; from_map/1 handles nil; no :extra field |
| `lib/lattice_stripe/billing/meter/status_transitions.ex` | @known_fields + :extra capture | VERIFIED | @known_fields ~w(deactivated_at); Map.drop/2 captures future timestamps |
| `lib/lattice_stripe/billing/meter_event.ex` | Create-only + Inspect masking + async-ack @doc | VERIFIED | defimpl Inspect excludes :payload; @doc contains required phrases; defstruct 6 fields only (no :extra) |
| `lib/lattice_stripe/billing/meter_event_adjustment.ex` | Create-only + from_map decodes cancel via Cancel.from_map | VERIFIED | Cancel.from_map(map["cancel"]) called in from_map/1; Guards.check_adjustment_cancel_shape! called in create/3 |
| `lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex` | Single :identifier field, no :extra | VERIFIED | defstruct [:identifier]; from_map/1 handles nil |
| `lib/lattice_stripe/billing/guards.ex` | All 3 guard functions present | VERIFIED | check_proration_required/2 (existing), check_meter_value_settings!/1 (new), check_adjustment_cancel_shape!/1 (new) — all 3 present |
| `test/support/fixtures/metering.ex` | LatticeStripe.Test.Fixtures.Metering with 3 submodules | VERIFIED | Namespace deviation from plan (LatticeStripe.Test.Fixtures vs LatticeStripe.Fixtures) — matches actual project convention, documented in 20-01-SUMMARY.md |
| `test/lattice_stripe/billing/meter_test.exs` | Unit tests for nested structs + Meter resource | VERIFIED | 13 describe blocks, 36 tests, 0 failures |
| `test/lattice_stripe/billing/meter_guards_test.exs` | 8-case guard matrix | VERIFIED | 8 tests labeled "1." through "8.", 0 failures |
| `test/lattice_stripe/billing/meter_event_test.exs` | MeterEvent unit tests with Inspect masking and @doc assertion | VERIFIED | 9 tests, 0 failures; Code.fetch_docs assertion green |
| `test/lattice_stripe/billing/meter_event_adjustment_test.exs` | MeterEventAdjustment round-trip + shape guard tests | VERIFIED | 10 tests, 0 failures |
| `test/lattice_stripe/billing/meter_integration_test.exs` | Meter lifecycle integration test against stripe-mock | PARTIAL | Covers Meter verbs only; missing MeterEvent.create/3 and MeterEventAdjustment.create/3 calls |
| `scripts/verify_meter_endpoints.exs` | stripe-mock endpoint probe for 8 metering endpoints | VERIFIED | Covers all 8 endpoints; uses :httpc (deviation from plan's LatticeStripe.Client suggestion — correct, documented) |
| `guides/metering.md` | 580 ± 40 lines, required content | VERIFIED | 620 lines (at ceiling per plan spec); contains all required strings and sections |
| `mix.exs` | "Billing Metering" ExDoc group + extras entry | VERIFIED | groups_for_modules contains "Billing Metering" with all 8 modules; extras contains "guides/metering.md" |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/lattice_stripe/billing/meter.ex` | `lib/lattice_stripe/billing/guards.ex` | `:ok = Billing.Guards.check_meter_value_settings!(params)` | WIRED | Line 98 of meter.ex; guard called after 3 require_param! calls |
| `lib/lattice_stripe/billing/meter.ex` | `lib/lattice_stripe/billing/meter/*.ex` | `DefaultAggregation/CustomerMapping/ValueSettings/StatusTransitions.from_map/1` | WIRED | Lines 242-245 of meter.ex; all 4 nested from_map/1 calls present |
| `lib/lattice_stripe/billing/meter_event_adjustment.ex` | `lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex` | `Cancel.from_map(map["cancel"])` | WIRED | Confirmed in from_map/1; typed struct decoding enforced |
| `lib/lattice_stripe/billing/meter_event_adjustment.ex` | `lib/lattice_stripe/billing/guards.ex` | `Guards.check_adjustment_cancel_shape!/1` | WIRED | Called in create/3 after require_param! calls |
| `guides/subscriptions.md` | `guides/metering.md` | markdown link | WIRED | Line 410: `metering.md#reporting-usage-the-hot-path` |
| `guides/webhooks.md` | `guides/metering.md` | markdown link | WIRED | Line 192: `metering.md#reconciliation-via-webhooks` |
| `guides/telemetry.md` | `guides/metering.md` | markdown link | WIRED | Line 221: `metering.md#observability` |
| `guides/error-handling.md` | `guides/metering.md` | markdown link | WIRED | Line 337: `metering.md#reconciliation-via-webhooks` |
| `guides/testing.md` | `guides/metering.md` | markdown link | WIRED | Line 479: `metering.md#what-not-to-do-nightly-batch-flush` |

### Data-Flow Trace (Level 4)

These are library modules, not UI components — data flows from API request through to typed struct decode. No dynamic rendering requiring Level 4 trace. Key data-flow verified via key link wiring above.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---------|---------|--------|--------|
| All 55 metering unit tests pass | `mix test test/lattice_stripe/billing/meter_test.exs test/lattice_stripe/billing/meter_guards_test.exs test/lattice_stripe/billing/meter_event_test.exs test/lattice_stripe/billing/meter_event_adjustment_test.exs` | 55 tests, 0 failures | PASS |
| Compile with warnings as errors | `mix compile --warnings-as-errors && echo COMPILE_OK` | COMPILE_OK | PASS |
| ExDoc builds clean | `mix docs 2>&1 \| grep -i error` | Only pre-existing @moduledoc false warning (not a new warning; not an error) | PASS |
| guides/metering.md line count in range | `wc -l guides/metering.md` | 620 lines (within 540-620 range) | PASS |
| All required guide content present | grep for error_report_triggered, 35-day, UsageReporter, archived_meter | All found | PASS |
| All 5 sibling guides cross-link to metering.md | grep metering.md in 5 guides | All 5 contain link | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| METER-01 | 20-03 | Create Meter returning %Meter{} struct | SATISFIED | Meter.create/3 implemented with require_param! + guard + POST /v1/billing/meters; from_map/1 decodes to %Meter{} |
| METER-02 | 20-03 | Retrieve Meter by ID | SATISFIED | Meter.retrieve/3 implemented; GET /v1/billing/meters/:id; unit test green |
| METER-03 | 20-03 | Update Meter mutable fields | SATISFIED | Meter.update/4 implemented; POST /v1/billing/meters/:id; unit test green |
| METER-04 | 20-03 | List Meters with cursor pagination and stream!/3 | SATISFIED | Meter.list/3 and stream!/3 implemented; list test green |
| METER-05 | 20-03 | deactivate/3 verb (POST .../deactivate) | SATISFIED | Meter.deactivate/3 implemented; sub-path POST; unit + integration tests green |
| METER-06 | 20-03 | reactivate/3 verb (POST .../reactivate) | SATISFIED | Meter.reactivate/3 implemented; sub-path POST; unit + integration tests green |
| METER-07 | 20-03 | Bang variants for all Meter functions | SATISFIED | All 7 bang variants confirmed: create!/3, retrieve!/3, update!/4, list!/3, stream!/3 (already bang), deactivate!/3, reactivate!/3 |
| METER-08 | 20-02 | 4 nested typed structs with @known_fields pattern | SATISFIED | DefaultAggregation, CustomerMapping, ValueSettings, StatusTransitions all implemented with correct :extra pattern |
| METER-09 | 20-03 | status_atom/1 helper :active/:inactive/:unknown | SATISFIED | status_atom/1 mirrors Account.Capability pattern; @known_statuses ~w(active inactive); 5 test cases green |
| EVENT-01 | 20-04 | MeterEvent.create/3 with event_name, payload, optional timestamp/identifier | SATISFIED | MeterEvent.create/3 implemented with require_param! for event_name + payload; opts passthrough for timestamp/identifier |
| EVENT-02 | 20-04 | MeterEvent honors idempotency_key: opt | SATISFIED | @doc explicitly documents idempotency_key: as transport-layer dedup; opts passed through to Client unchanged |
| EVENT-03 | 20-04 | MeterEvent honors stripe_account: opt | SATISFIED | @doc documents stripe_account: opt for Connect; opts passed through to Client unchanged |
| EVENT-04 | 20-05 | MeterEventAdjustment.create/3 with cancel.identifier nested shape | SATISFIED | Cancel struct enforces exact shape; Guards.check_adjustment_cancel_shape! rejects 4 wrong shapes; round-trip test green |
| EVENT-05 | 20-04 | MeterEvent struct: 6 known fields only, no back-read operations | SATISFIED | defstruct 6 fields (event_name, identifier, payload, timestamp, created, livemode); no :extra; no retrieve/list |
| GUARD-01 | 20-03 | Meter.create/3 raises/warns on value_settings issues | SATISFIED (with override) | 8-case matrix green; raises on present-but-malformed (D-01 amends SC #2 — absence is legal per Stripe docs) |
| GUARD-02 | 20-04 | @doc for MeterEvent.create/3 documents 35-day window, 24h identifier dedup, async nature | SATISFIED | @doc:34 "35-day"; @doc:43 "24-hour"; @doc:49 async-ack phrase; Code.fetch_docs test asserts all |
| GUARD-03 | 20-04 | {:ok, %MeterEvent{}} documented as "accepted for processing" | SATISFIED | @doc:49 "accepted for processing"; @doc:54 "v1.billing.meter.error_report_triggered"; Code.fetch_docs assertion green |
| TEST-01 | 20-01 | test/support/fixtures/metering.ex with Meter/MeterEvent/MeterEventAdjustment | SATISFIED | LatticeStripe.Test.Fixtures.Metering module with 3 submodules; all tests use it |
| TEST-03 | 20-01 | stripe-mock probe confirms metering endpoints + cancel shape | SATISFIED | scripts/verify_meter_endpoints.exs covers all 8 endpoints; 8/8 OK confirmed |
| TEST-05 (metering) | 20-03 | Full integration test: meter → events → adjust → deactivate → list → reactivate | PARTIAL | Meter lifecycle (create → retrieve → update → list → deactivate → reactivate) tested against stripe-mock. MeterEvent.create/3 and MeterEventAdjustment.create/3 NOT tested against stripe-mock — unit tests only. |
| DOCS-01 | 20-06 | guides/metering.md with full usage story | SATISFIED | 620 lines; 9 H2 sections; all required content verified |
| DOCS-03 (Billing Metering) | 20-06 | mix.exs "Billing Metering" group + extras entry | SATISFIED | "Billing Metering" group with 8 modules in groups_for_modules; "guides/metering.md" in extras |
| DOCS-04 | 20-06 | Cross-links from sibling guides to metering.md | SATISFIED | All 5 sibling guides (subscriptions, webhooks, telemetry, error-handling, testing) contain metering.md links |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/lattice_stripe/billing/meter_integration_test.exs` | 5-6 | Credo: `alias LatticeStripe.Client` before `alias LatticeStripe.Billing.Meter` violates alphabetical alias ordering | Warning | Style only; test compiles and runs correctly; no functional impact |
| `lib/lattice_stripe/billing/meter.ex` | 98 | `:ok = Billing.Guards.check_meter_value_settings!(params)` — MatchError trap if guard ever returns non-:ok (e.g. {:ok, :warned}) | Info | Identified in REVIEW WR-02; no current impact since all branches return :ok; fragile coupling |
| `lib/lattice_stripe/billing/meter_event_adjustment.ex` | 48-52 | Duplicate cancel-presence check (require_param! + guard both raise on missing cancel) | Info | Identified in REVIEW IN-02; redundant not incorrect |
| `lib/lattice_stripe/billing/guards.ex` | 2 | `@moduledoc false` causes mix docs warning when meter.ex @doc references check_meter_value_settings!/1 | Info | Pre-existing pattern in codebase; expected per REVIEW note; mix docs still builds |

### Human Verification Required

None — all automated checks completed.

### Gaps Summary

**1 gap blocking full SC #1 achievement:**

The meter integration test covers the Meter CRUDL lifecycle correctly but omits MeterEvent.create/3 and MeterEventAdjustment.create/3 calls against stripe-mock. ROADMAP SC #1 explicitly requires "report events via MeterEvent.create/3" and REQUIREMENTS TEST-05 requires "seed a meter → report events through it → adjust one" in the integration test suite. Unit tests for both modules pass (9 + 10 tests) but they use MockTransport, not stripe-mock.

**Fix:** Add to `test/lattice_stripe/billing/meter_integration_test.exs`:
```elixir
# After the meter create step, add:
{:ok, %LatticeStripe.Billing.MeterEvent{}} =
  LatticeStripe.Billing.MeterEvent.create(client, %{
    "event_name" => "api_call_<unique>",
    "payload" => %{"stripe_customer_id" => "cus_xxx", "value" => "1"},
    "identifier" => "req_#{System.unique_integer([:positive])}"
  })

{:ok, %LatticeStripe.Billing.MeterEventAdjustment{}} =
  LatticeStripe.Billing.MeterEventAdjustment.create(client, %{
    "event_name" => "api_call_<unique>",
    "cancel" => %{"identifier" => "req_<above_id>"}
  })
```

**Documented deviations (not gaps):**

- D-01 override: GUARD-01 raises on present-but-malformed value_settings only (not absent). Documented in 20-CONTEXT.md with full rationale. ROADMAP SC #2 explicitly amended pre-execution.
- Fixture namespace: `LatticeStripe.Test.Fixtures.Metering` (not `LatticeStripe.Fixtures.Metering`). Matches project convention. Documented in 20-01-SUMMARY.md.
- 9 H2 sections in metering.md (PLAN said 12). Content coverage is complete — section count discrepancy is in plan numbering, not guide content.
- mix docs has 2 pre-existing warnings about @moduledoc false on Guards — not a new warning, not a build error.

---

_Verified: 2026-04-14_
_Verifier: Claude (gsd-verifier)_
