---
phase: 64-meter-event-summary-reads
reviewed: 2026-08-22T20:35:51Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - guides/metering-runtime-and-reconciliation.md
  - guides/metering.md
  - guides/scope.md
  - lib/lattice_stripe/billing/guards.ex
  - lib/lattice_stripe/billing/meter_error_report.ex
  - lib/lattice_stripe/billing/meter_error_report/error_type.ex
  - lib/lattice_stripe/billing/meter_error_report/reason.ex
  - lib/lattice_stripe/billing/meter_error_report/sample_error.ex
  - lib/lattice_stripe/billing/meter_event.ex
  - lib/lattice_stripe/billing/meter_event_stream.ex
  - lib/lattice_stripe/billing/meter_event_summary.ex
  - lib/lattice_stripe/drift.ex
  - test/integration/meter_event_summary_integration_test.exs
  - test/lattice_stripe/billing/meter_error_report_test.exs
  - test/lattice_stripe/billing/meter_event_summary_pagination_test.exs
  - test/lattice_stripe/billing/meter_event_summary_test.exs
  - test/lattice_stripe/billing/meter_event_test.exs
  - test/lattice_stripe/billing/meter_guards_test.exs
  - test/lattice_stripe/billing/meter_test.exs
  - test/lattice_stripe/docs_truth_test.exs
  - test/lattice_stripe/drift_test.exs
  - test/lattice_stripe/form_encoder_test.exs
  - test/lattice_stripe/object_types_test.exs
  - test/support/fixtures/metering.ex
findings:
  critical: 0
  warning: 3
  info: 0
  total: 3
status: issues_found
---

# Phase 64: Code Review Report

**Reviewed:** 2026-08-22T20:35:51Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

The summary-read API, decoders, pagination seam, metering guides, and associated tests were reviewed in context. Three warning-level defects remain: the alignment guard violates its own universal minute-alignment contract for unknown window values, and two production guide examples either discard reportable failures or crash on a documented nullable payload field. The focused test command could not compile because the checkout has stale dependency locks and Mix requires `mix deps.get`; no source files were modified during this review.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Unknown grouping windows bypass the mandatory minute-alignment check

**Classification:** WARNING

**File:** `/Users/jon/projects/lattice_stripe/lib/lattice_stripe/billing/guards.ex:205-227`

**Issue:** The implementation returns `:ok` for every unrecognised `value_grouping_window`, including a request such as `%{"value_grouping_window" => "week", "start_time" => 1, "end_time" => 2}`. This contradicts the documented and implemented contract that *every* query requires minute-aligned timestamps. Forward compatibility only requires avoiding an hour/day-specific restriction for a future enum value; it does not justify sending universally invalid timestamps to Stripe. The shipped test at `meter_guards_test.exs:222-232` locks this incorrect behavior in.

**Fix:** Preserve forward compatibility while retaining the universal rule:

```elixir
defp summary_divisor("hour"), do: 3_600
defp summary_divisor("day"), do: 86_400
defp summary_divisor(_window), do: 60
```

Update the forward-compatibility test to assert that unknown values pass minute-aligned windows and reject values misaligned to 60 seconds.

### WR-02: The recommended asynchronous reporter drops transient meter events instead of scheduling a retry

**Classification:** WARNING

**File:** `/Users/jon/projects/lattice_stripe/guides/metering.md:188-218`

**Issue:** The guide calls this the recommended production reporter and comments “retry via your retry scheduler,” but it only logs and returns `{{:error, :transient}, ...}` from the supervised task. Nothing consumes that return value, so rate-limit, API, and connection failures are permanently discarded. It also discards the `Task.Supervisor.start_child/2` result and always returns `:ok`, hiding task-start failures. Copying the example therefore loses billable usage under the very transient failures it claims to handle.

**Fix:** Make the example enqueue durable retry work with the same identifier and idempotency key, and propagate or explicitly handle task-start errors. For example, call an application-owned `enqueue_retry/5` in the transient branch and return `Task.Supervisor.start_child/2`'s result (or log/alert on `{:error, reason}`) instead of unconditionally returning `:ok`.

### WR-03: Reconciliation examples dereference a nullable `reason` and can fail the webhook handler

**Classification:** WARNING

**Files:** `/Users/jon/projects/lattice_stripe/guides/metering.md:726-729`; `/Users/jon/projects/lattice_stripe/lib/lattice_stripe/billing/meter_error_report.ex:42-45`

**Issue:** `MeterErrorReport.from_map/1` explicitly documents and implements `reason: nil` for a nullable wire field, but both canonical examples immediately evaluate `report.reason.error_types`. A fetched error-report event with `reason: null` raises `KeyError`/a bad map access in the webhook path, turning a valid notification into a failed delivery and preventing reconciliation.

**Fix:** Branch on the nullable field before iterating, for example:

```elixir
case report.reason do
  nil -> :ok
  %Reason{error_types: error_types} ->
    for %ErrorType{code: code, sample_errors: samples} <- error_types,
        %SampleError{request_identifier: key, error_message: msg} <- samples do
      MyApp.Billing.MeterEvents.mark_failed_by_idempotency_key(key, code, msg)
    end
end
```

Add a guide/example regression test or a compiled-doc snippet test covering a fetched event whose `reason` is `nil`.

---

_Reviewed: 2026-08-22T20:35:51Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
