---
phase: 13-billing-test-clocks
reviewed: 2026-04-12T04:19:43Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - lib/lattice_stripe/client.ex
  - lib/lattice_stripe/config.ex
  - lib/lattice_stripe/error.ex
  - lib/lattice_stripe/test_helpers/test_clock.ex
  - lib/lattice_stripe/testing/test_clock.ex
  - lib/lattice_stripe/testing/test_clock/error.ex
  - lib/lattice_stripe/testing/test_clock/owner.ex
  - lib/mix/tasks/lattice_stripe.test_clock.cleanup.ex
  - test/support/real_stripe_case.ex
  - test/support/test_support.ex
  - test/test_helper.exs
  - test/lattice_stripe/test_helpers/test_clock_test.exs
  - test/lattice_stripe/testing/test_clock_test.exs
  - test/lattice_stripe/testing/test_clock_mix_task_test.exs
  - test/integration/test_clock_integration_test.exs
  - test/real_stripe/test_clock_real_stripe_test.exs
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-12T04:19:43Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 13 introduces Stripe Billing Test Clock support: a low-level SDK wrapper (`TestHelpers.TestClock`), an ExUnit ergonomic layer (`Testing.TestClock` with `use` macro, Owner GenServer, and `advance/2` helper), and a Mix task backstop for leaked clock cleanup. The implementation is well-structured with thorough documentation, correct Stripe API usage, and good test coverage across unit, integration, and real-Stripe levels.

One critical bug was found: the `use` macro's compile-time client binding is disconnected from the runtime client resolution path, meaning the documented `use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient` workflow will fail at runtime. Two warnings relate to a TOCTOU race in Owner cleanup and the `advance/2` API design mixing time units with client options in the same keyword list.

## Critical Issues

### CR-01: `__using__` macro client binding is disconnected from `resolve_client!/1`

**File:** `lib/lattice_stripe/testing/test_clock.ex:106-137` and `lib/lattice_stripe/testing/test_clock.ex:288-313`

**Issue:** The `__using__` macro (line 132) stores the client in a module attribute and defines `__lattice_test_clock_client__/0`, but `resolve_client!/1` (line 288) never calls that function. Instead, it looks up `Process.get(:__lattice_stripe_bound_client__)`, which is never populated by the macro or any setup callback.

This means the primary documented usage pattern fails at runtime:

```elixir
# In CaseTemplate:
use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient

# At runtime in a test:
clock = test_clock()  # => raises TestClockError: "No LatticeStripe client is bound"
```

The tests pass only because they manually call `Process.put(:__lattice_stripe_bound_client__, client)` in their setup blocks, bypassing the macro entirely.

**Fix:** Either (a) have `resolve_client!/1` call the `__lattice_test_clock_client__/0` function on the caller's module when the process dict is empty, or (b) have the `__using__` macro inject a `setup` callback that populates the process dict. Option (a) is cleaner:

```elixir
defp resolve_client!(opts) do
  case Keyword.get(opts, :client) do
    %LatticeStripe.Client{} = client ->
      client

    nil ->
      case Process.get(:__lattice_stripe_bound_client__) do
        nil ->
          # Fall back to the compile-time binding from the use-macro
          caller = self() |> Process.info(:dictionary) |> ...
          # This approach is complex; simpler: have the macro inject a setup
          # that calls Process.put with the resolved client.
          raise TestClockError, ...

        %LatticeStripe.Client{} = client -> client
        mod when is_atom(mod) -> apply(mod, :stripe_client, [])
      end

    mod when is_atom(mod) ->
      apply(mod, :stripe_client, [])
  end
end
```

More practically, add to the `__using__` macro's `quote` block:

```elixir
setup do
  client_spec = @__lattice_test_clock_client__
  client =
    if is_atom(client_spec) and function_exported?(client_spec, :stripe_client, 0) do
      apply(client_spec, :stripe_client, [])
    else
      client_spec
    end
  Process.put(:__lattice_stripe_bound_client__, client)
  :ok
end
```

## Warnings

### WR-01: TOCTOU race in `Owner.cleanup/2`

**File:** `lib/lattice_stripe/testing/test_clock/owner.ex:41-57`

**Issue:** `cleanup/2` checks `Process.alive?(owner)` at line 41, then calls `registered(owner)` and later `GenServer.stop(owner)` at line 54. If the Owner process dies between the `alive?` check and the `GenServer.call` (e.g., due to a linked process crash), the `GenServer.call` will raise `** (exit) no process`. The outer `rescue`/`catch` at lines 47-50 only wraps the `Backend.delete` call, not the `registered` call or the `GenServer.stop`.

**Fix:** Wrap the entire body in a try/catch, or use `GenServer.call` with a timeout that returns `{:error, ...}` on failure:

```elixir
def cleanup(owner, %Client{} = client) when is_pid(owner) do
  try do
    if Process.alive?(owner) do
      ids = registered(owner)

      for id <- ids do
        try do
          Backend.delete(client, id)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end

      if Process.alive?(owner), do: GenServer.stop(owner)
    end
  catch
    :exit, _ -> :ok
  end

  :ok
end
```

### WR-02: `advance/2` mixes time units with client option in the same keyword list

**File:** `lib/lattice_stripe/testing/test_clock.ex:189-193`

**Issue:** `advance/2` accepts `unit_opts` which is documented as containing time units (`days: 30`, `hours: 2`, etc.) but also used for client resolution via `resolve_client!(unit_opts)` which looks for a `:client` key. If a user passes `advance(clock, days: 30, client: my_client)`, the `delta_seconds!/1` function (line 267) will process all keys and the `:client` key will be silently ignored by the `cond` chain -- but `resolve_client!` will find it. This works but creates an ambiguous API contract where the same keyword list serves two purposes, and passing an unrecognized time key (e.g., `weeks: 2`) with a valid `:client` key will raise `ArgumentError` from `delta_seconds!` rather than a helpful "unsupported unit" message.

**Fix:** Separate concerns by either (a) documenting the `:client` key explicitly in `advance/2`'s `@doc`, or (b) splitting the opts: `advance(clock, time_unit, opts \\ [])`. At minimum, add `:client` to the `@doc` for `advance/2`.

## Info

### IN-01: Unused `@cleanup_marker` module attribute

**File:** `lib/lattice_stripe/testing/test_clock.ex:96-99`

**Issue:** `@cleanup_marker` is defined as `{"lattice_stripe_test_clock", "v1"}` and exposed via `cleanup_marker/0`, but it is never used in any production code path. The A-13g investigation confirmed Stripe does not support metadata on test clocks, so this marker serves no functional purpose. It exists as a forward-compatibility placeholder.

**Fix:** Consider removing the attribute and `cleanup_marker/0` function until Stripe adds metadata support. Alternatively, add a comment explaining it is a forward-compatibility stub to prevent future developers from wondering why it exists but is unused.

### IN-02: Mix task `resolve_client!/1` uses `String.to_existing_atom/1` which requires the module to be loaded

**File:** `lib/mix/tasks/lattice_stripe.test_clock.cleanup.ex:132-149`

**Issue:** `resolve_client!/1` uses `String.to_existing_atom/1` to resolve the `--client` module name. This works because `Mix.Task.run("app.start")` is called first (line 72), which loads all application modules. However, if a user's client module is in a dependency that hasn't been started, or if `app.start` fails silently, the `ArgumentError` from `to_existing_atom` will be caught and re-raised as a confusing Mix error. The rescue clause at line 143 handles this, but the error message could be clearer about the "module not loaded" root cause.

**Fix:** No code change needed -- this is defensive and works correctly in practice. The existing error message at line 145 is adequate. Noting for completeness.

---

_Reviewed: 2026-04-12T04:19:43Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
