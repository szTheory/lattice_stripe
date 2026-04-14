---
phase: 20-billing-metering
plan: 07
type: execute
wave: 6
depends_on: [20-03, 20-04, 20-05]
files_modified:
  - test/lattice_stripe/billing/meter_integration_test.exs
autonomous: true
gap_closure: true
requirements:
  - TEST-05
must_haves:
  truths:
    - "The phase's metering integration test exercises MeterEvent.create/3 against stripe-mock after seeding a Meter"
    - "The phase's metering integration test exercises MeterEventAdjustment.create/3 against stripe-mock with the correct cancel.identifier nested shape"
    - "Both calls assert the decoded struct shape via {:ok, %MeterEvent{}} and {:ok, %MeterEventAdjustment{}} pattern matches"
    - "meter_integration_test.exs no longer accesses list_resp.data.data (double-nested Stripe list envelope bug)"
  artifacts:
    - path: "test/lattice_stripe/billing/meter_integration_test.exs"
      provides: "Extended full-lifecycle integration test covering Meter + MeterEvent + MeterEventAdjustment against stripe-mock"
      contains: "MeterEvent.create(client"
      also_contains: "MeterEventAdjustment.create(client"
  key_links:
    - from: "test/lattice_stripe/billing/meter_integration_test.exs"
      to: "lib/lattice_stripe/billing/meter_event.ex"
      via: "LatticeStripe.Billing.MeterEvent.create/3 against stripe-mock"
      pattern: "MeterEvent\\.create\\(client"
    - from: "test/lattice_stripe/billing/meter_integration_test.exs"
      to: "lib/lattice_stripe/billing/meter_event_adjustment.ex"
      via: "LatticeStripe.Billing.MeterEventAdjustment.create/3 with cancel.identifier shape"
      pattern: "MeterEventAdjustment\\.create\\(client"
---

<objective>
Close the single gap recorded in `.planning/phases/20-billing-metering/20-VERIFICATION.md`:
extend the existing Meter integration test so it reports a MeterEvent and creates a
MeterEventAdjustment against stripe-mock — the two calls that are currently missing
from ROADMAP SC #1 and REQUIREMENTS TEST-05 (metering side). Also fix the pre-existing
`list_resp.data.data` double-nested access bug discovered in code review IN-03 while
we are editing the same file.

Purpose: Satisfy SC #1 "report events via MeterEvent.create/3 … and the phase's test
suite passes against stripe-mock — including deactivate, reactivate, list-by-status,
and adjust lifecycles." Without this gap closure, Truth #1 in 20-VERIFICATION.md
remains PARTIAL.

Output: A single modified test file with one extended test (or one new tightly-coupled
test in the same describe block) that drives Meter → MeterEvent → MeterEventAdjustment
end-to-end against stripe-mock, plus the list envelope fix on line 57-58.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/20-billing-metering/20-VERIFICATION.md
@.planning/phases/20-billing-metering/20-CONTEXT.md
@test/lattice_stripe/billing/meter_integration_test.exs
@lib/lattice_stripe/billing/meter_event.ex
@lib/lattice_stripe/billing/meter_event_adjustment.ex
@lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex

<interfaces>
<!-- Exact signatures the gap test must call. Extracted from lib/. -->
<!-- Do NOT explore the codebase — these are the contracts. -->

From lib/lattice_stripe/billing/meter_event.ex:
```elixir
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
def create(%Client{} = client, params, opts \\ []) when is_map(params)
# Required params (string keys): "event_name", "payload"
# Optional params: "timestamp", "identifier"
# Struct fields: event_name, identifier, payload, timestamp, created, livemode
```

From lib/lattice_stripe/billing/meter_event_adjustment.ex:
```elixir
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
def create(%Client{} = client, params, opts \\ []) when is_map(params)
# Required params (string keys): "event_name", "cancel"
# "cancel" MUST be shaped as %{"identifier" => "<meter_event_identifier>"}
# Guards.check_adjustment_cancel_shape!/1 enforces this
# Struct fields: id, object, event_name, status, cancel (%Cancel{}), livemode, extra
```

From lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex:
```elixir
defstruct [:identifier]
# from_map/1 handles nil
```

stripe-mock note (already documented in existing test at lines 36-38):
> stripe-mock is stateless — state transitions (active→inactive) are NOT
> asserted. Only the return shape (%Meter{}) is checked for each verb.
>
> The same applies to MeterEvent and MeterEventAdjustment: shape-only assertions.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend meter_integration_test.exs with MeterEvent + MeterEventAdjustment calls and fix list envelope access</name>
  <files>test/lattice_stripe/billing/meter_integration_test.exs</files>

  <read_first>
    - test/lattice_stripe/billing/meter_integration_test.exs (full file, 63 lines)
    - lib/lattice_stripe/billing/meter_event.ex (signature + required params)
    - lib/lattice_stripe/billing/meter_event_adjustment.ex (signature + cancel.identifier shape)
    - .planning/phases/20-billing-metering/20-VERIFICATION.md (gap section lines 12-22)
  </read_first>

  <action>
    Make the following three edits to `test/lattice_stripe/billing/meter_integration_test.exs`, keeping everything else in the file untouched:

    **Edit 1 — Add alias lines (alphabetical order to also silently resolve the Credo warning noted in VERIFICATION.md anti-patterns section).**

    Replace the current alias block:
    ```elixir
    alias LatticeStripe.Client
    alias LatticeStripe.Billing.Meter
    ```

    With:
    ```elixir
    alias LatticeStripe.Billing.{Meter, MeterEvent, MeterEventAdjustment}
    alias LatticeStripe.Client
    ```

    **Edit 2 — Fix the list envelope double-nesting bug (IN-03) on the line currently reading `assert is_list(list_resp.data.data)`.**

    The `list/3` function returns `{:ok, list_resp}` where `list_resp` is already the decoded list response (a map with `"data"` key), not a wrapper around `.data`. Replace:
    ```elixir
    {:ok, list_resp} = Meter.list(client, %{"limit" => 3})
    assert is_list(list_resp.data.data)
    ```

    With:
    ```elixir
    {:ok, list_resp} = Meter.list(client, %{"limit" => 3})
    assert is_list(list_resp.data)
    ```

    (If local inspection reveals that `Meter.list/3` actually returns a struct whose `:data` field is itself a list envelope — i.e. the current `list_resp.data.data` is correct and the outer `list_resp` is a wrapper — then instead replace with `assert is_list(list_resp.data)` only if `list_resp.data` is a plain list; otherwise keep whichever single-level access yields `is_list/1 == true` against stripe-mock. Run the test to confirm. The goal is "one level of `.data`, not two." VERIFICATION IN-03 flagged this as suspect; the fix is to drop one level.)

    **Edit 3 — Extend the existing `test "full lifecycle …"` body with MeterEvent and MeterEventAdjustment calls.**

    Immediately after the line `assert is_binary(id)` and before the `Meter.retrieve(client, id)` line (so the new calls use the freshly-created meter's `event_name`), capture the meter's `event_name` and add the new calls.

    First, change the meter creation to capture `event_name`:
    ```elixir
    event_name = "api_call_#{System.unique_integer([:positive])}"

    {:ok, %Meter{id: id}} =
      Meter.create(client, %{
        "display_name" => "API Calls",
        "event_name" => event_name,
        "default_aggregation" => %{"formula" => "sum"},
        "customer_mapping" => %{
          "event_payload_key" => "stripe_customer_id",
          "type" => "by_id"
        },
        "value_settings" => %{"event_payload_key" => "value"}
      })

    assert is_binary(id)
    ```

    Then insert the new MeterEvent + MeterEventAdjustment block between `assert is_binary(id)` and `{:ok, %Meter{}} = Meter.retrieve(client, id)`:

    ```elixir
    # TEST-05 (metering side) — report an event through the meter we just created.
    # stripe-mock is stateless: we assert {:ok, %MeterEvent{}} shape only, NOT
    # that the event was persisted against any customer. The point of this test
    # is that the HTTP call round-trips through LatticeStripe.Billing.MeterEvent
    # and decodes via from_map/1 without raising or returning an error tuple.
    event_identifier = "req_#{System.unique_integer([:positive])}"

    assert {:ok, %MeterEvent{}} =
             MeterEvent.create(client, %{
               "event_name" => event_name,
               "payload" => %{"stripe_customer_id" => "cus_test_123", "value" => "1"},
               "identifier" => event_identifier
             })

    # TEST-05 continued — adjust the event we just reported, using the exact
    # cancel.identifier nested shape enforced by Guards.check_adjustment_cancel_shape!/1.
    # Shape-only assertion: stripe-mock does not enforce the 24-hour window or
    # verify the identifier exists.
    assert {:ok, %MeterEventAdjustment{}} =
             MeterEventAdjustment.create(client, %{
               "event_name" => event_name,
               "cancel" => %{"identifier" => event_identifier}
             })
    ```

    Do NOT change the test name. Do NOT split into a second test — the call graph
    (meter → event → adjustment) must stay in the same test body so the event_name
    and event_identifier flow through in scope. Do NOT add any additional setup or
    teardown. Do NOT touch the `setup_all` or `setup` blocks.

    Do NOT modify any file other than `test/lattice_stripe/billing/meter_integration_test.exs`.
    Do NOT touch any `lib/` file — this is strictly a test-only gap closure.
  </action>

  <verify>
    <automated>mix test test/lattice_stripe/billing/meter_integration_test.exs --include integration</automated>
  </verify>

  <acceptance_criteria>
    - File `test/lattice_stripe/billing/meter_integration_test.exs` contains the literal substring `MeterEvent.create(client` at least once
    - File contains the literal substring `MeterEventAdjustment.create(client` at least once
    - File contains the literal pattern `assert {:ok, %MeterEvent{}} =`
    - File contains the literal pattern `assert {:ok, %MeterEventAdjustment{}} =`
    - File contains the exact cancel shape `"cancel" => %{"identifier" => event_identifier}`
    - File no longer contains the substring `list_resp.data.data` (double-nesting fix confirmed)
    - File contains `alias LatticeStripe.Billing.{Meter, MeterEvent, MeterEventAdjustment}` OR three separate `alias LatticeStripe.Billing.*` lines in alphabetical order
    - Running `mix test test/lattice_stripe/billing/meter_integration_test.exs --include integration` against a running stripe-mock passes with 1 test, 0 failures
    - Running `mix compile --warnings-as-errors` produces no new warnings
    - No `lib/` file has been modified (`git diff --stat lib/` is empty)
    - Existing plans 20-01..20-06 PLAN.md files are untouched (`git diff --stat .planning/phases/20-billing-metering/20-01-*PLAN.md .planning/phases/20-billing-metering/20-02-*PLAN.md .planning/phases/20-billing-metering/20-03-*PLAN.md .planning/phases/20-billing-metering/20-04-*PLAN.md .planning/phases/20-billing-metering/20-05-*PLAN.md .planning/phases/20-billing-metering/20-06-*PLAN.md` is empty)
  </acceptance_criteria>

  <done>
    The integration test drives the full Meter → MeterEvent → MeterEventAdjustment
    lifecycle against stripe-mock in a single test body, shape-asserts both new
    structs via pattern match, fixes the `list_resp.data.data` double-nesting, and
    passes under `mix test --include integration`. VERIFICATION.md gap row can be
    flipped from `status: failed` to `status: verified`.
  </done>
</task>

</tasks>

<verification>
Run these after Task 1 is executed:

```bash
# 1. Compilation is clean
mix compile --warnings-as-errors

# 2. The integration test passes (requires stripe-mock on localhost:12111)
mix test test/lattice_stripe/billing/meter_integration_test.exs --include integration

# 3. No lib/ files were touched
git diff --stat lib/
# expected: empty

# 4. No existing plan files were touched
git diff --stat .planning/phases/20-billing-metering/20-0[1-6]-*PLAN.md
# expected: empty

# 5. Required patterns are present
grep -c "MeterEvent.create(client" test/lattice_stripe/billing/meter_integration_test.exs
# expected: >= 1
grep -c "MeterEventAdjustment.create(client" test/lattice_stripe/billing/meter_integration_test.exs
# expected: >= 1
grep -c "list_resp.data.data" test/lattice_stripe/billing/meter_integration_test.exs
# expected: 0
```
</verification>

<success_criteria>
- Gap row in 20-VERIFICATION.md is satisfied: integration test now calls both `MeterEvent.create/3` and `MeterEventAdjustment.create/3` against stripe-mock
- ROADMAP SC #1 fully achieved (was PARTIAL)
- REQUIREMENTS TEST-05 metering side fully achieved (was PARTIAL)
- Shape assertions `{:ok, %MeterEvent{}}` and `{:ok, %MeterEventAdjustment{}}` present
- `list_resp.data.data` double-nesting (IN-03) eliminated
- 1 integration test, 0 failures under `mix test --include integration`
- Zero `lib/` modifications; zero edits to plans 20-01..20-06
</success_criteria>

<output>
After completion, create `.planning/phases/20-billing-metering/20-07-SUMMARY.md`
summarizing:
- Which gap was closed (reference VERIFICATION.md row)
- The 3 edits made (alias block, list envelope fix, MeterEvent + MeterEventAdjustment calls)
- Final test run output (1 test, 0 failures)
- Confirmation that no `lib/` files were touched
</output>
