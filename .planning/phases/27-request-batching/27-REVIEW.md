---
phase: 27-request-batching
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - lib/lattice_stripe/batch.ex
  - test/lattice_stripe/batch_test.exs
  - mix.exs
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 27: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 27 introduces `LatticeStripe.Batch`, a concurrent fan-out module wrapping `Task.async_stream/3`. The implementation is clean and idiomatic. The core logic — ordered results, per-task error isolation, rescue-to-error wrapping, and input validation — is correct. Three warnings deserve attention before this ships: an unmatched result clause that will crash at runtime on unexpected task return shapes, a missing timeout option that leaves callers with no per-task deadline, and a `fuse`/OTP dependency in `mix.exs` that ships to production consumers unintentionally. Two minor info items round out the review.

---

## Warnings

### WR-01: `map_stream_result/1` crashes on unexpected task return values

**File:** `lib/lattice_stripe/batch.ex:80-89`

**Issue:** The function has four clauses: `{:ok, {:ok, _}}`, `{:ok, {:error, %Error{}}}`, `{:exit, :timeout}`, and `{:exit, reason}`. The `on_timeout: :kill_task` option causes timed-out tasks to emit `{:exit, :timeout}` (handled), but any task that returns a value other than `{:ok, _}` or `{:error, %Error{}}` — for example a resource function that returns `{:error, "string reason"}`, a bare atom, or any non-`%Error{}` error struct — falls through to the `{:ok, {:error, %Error{}} = err}` clause without matching and raises a `FunctionClauseError` that crashes the caller's `Enum.map/2`. Since `valid_mfa?/1` only checks shape (atom module, atom function, list args) and not whether the target function conforms to the `{:ok, _} | {:error, %Error{}}` contract, this is a plausible path for misuse.

**Fix:** Add a catch-all clause that wraps unexpected returns into a `connection_error`:

```elixir
defp map_stream_result({:ok, {:ok, _} = ok}), do: ok
defp map_stream_result({:ok, {:error, %Error{}} = err}), do: err

defp map_stream_result({:ok, unexpected}) do
  {:error,
   %Error{
     type: :connection_error,
     message: "Task returned unexpected value: #{inspect(unexpected)}"
   }}
end

defp map_stream_result({:exit, :timeout}) do
  {:error, %Error{type: :connection_error, message: "Task timed out"}}
end

defp map_stream_result({:exit, reason}) do
  {:error, %Error{type: :connection_error, message: "Task exited: #{inspect(reason)}"}}
end
```

---

### WR-02: `timeout: :infinity` with no caller-facing timeout option creates unbounded hangs

**File:** `lib/lattice_stripe/batch.ex:71`

**Issue:** `Task.async_stream/3` is called with `timeout: :infinity`. The `on_timeout: :kill_task` option only applies when a finite timeout is set; with `:infinity` it is inert. A single Stripe call that hangs (e.g., due to a stalled connection that never times out at the TCP layer) will block the entire batch forever. The `opts` keyword list accepts `max_concurrency` but offers no way for callers to set a per-task timeout. Stripe SDK clients expect bounded operations.

**Fix:** Accept a `:timeout` option and pass it through. Default to a reasonable value (the Stripe dashboard shows p99 API latency well under 10 s; 30 s is a safe ceiling for an SDK default):

```elixir
def run(%Client{} = client, tasks, opts \\ []) when is_list(tasks) do
  with :ok <- validate_tasks(tasks) do
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 30_000)

    results =
      tasks
      |> Task.async_stream(
        fn {mod, fun, args} -> ... end,
        max_concurrency: max_concurrency,
        ordered: true,
        timeout: timeout,
        on_timeout: :kill_task
      )
      |> Enum.map(&map_stream_result/1)

    {:ok, results}
  end
end
```

---

### WR-03: `:fuse` and OpenTelemetry deps missing `optional: true`, shipping to library consumers

**File:** `mix.exs:200-203`

**Issue:** The dependencies `:fuse`, `:opentelemetry_exporter`, `:opentelemetry`, and `:opentelemetry_api` are declared `only: [:dev, :test]` but without `runtime: false`. More critically, they appear to be optional features (circuit-breaker, OTel tracing) that should not force consumers of the `lattice_stripe` Hex package to download and compile these libraries. A Hex package's `mix.exs` is evaluated at publish time: any dep without `only: :test` or `runtime: false` is included in the published package's dependency manifest and pulled in by downstream users. Declaring them `only: [:dev, :test]` is correct for local development but still appears in the lockfile and affects packages depending on `lattice_stripe` in production.

Additionally, if `:fuse` is intended as a first-class runtime circuit-breaker feature (as guided by `guides/circuit-breaker.md` in the docs extras), it belongs as an `optional: true` runtime dep, not a dev/test-only one. The current placement is inconsistent with the published docs referencing it.

**Fix:**

If `:fuse` and the OTel libraries are truly optional runtime features, declare them properly:

```elixir
{:fuse, "~> 2.5", optional: true},
{:opentelemetry_api, "~> 1.4", optional: true},
```

If they are only used in tests/guides and not referenced in `lib/`, restrict them correctly and add `runtime: false`:

```elixir
{:fuse, "~> 2.5", only: [:dev, :test], runtime: false},
{:opentelemetry_exporter, "~> 1.8", only: [:dev, :test], runtime: false},
{:opentelemetry, "~> 1.5", only: [:dev, :test], runtime: false},
{:opentelemetry_api, "~> 1.4", only: [:dev, :test], runtime: false},
```

Verify the intended use against the circuit-breaker guide and align the dep declaration accordingly.

---

## Info

### IN-01: Error isolation test uses `:counters` for ordering — fragile with `async: true` and `max_concurrency`

**File:** `test/lattice_stripe/batch_test.exs:74-95`

**Issue:** The error isolation test uses `:counters.new/2` and `:counters.add/3` to give the first transport call a success response and the second an error. This relies on the transport mock being called in strict insertion order. With `ordered: true` in `Task.async_stream`, *results* are ordered, but the underlying tasks are scheduled by the OTP scheduler and may call the transport in any order when `max_concurrency > 1` (the default here is `System.schedulers_online()`). On a multi-core CI machine, both requests may fire simultaneously, making which request gets index `0` non-deterministic.

**Fix:** Stub the transport based on the request content (e.g., `req.url`) rather than call order, matching the pattern used in the happy-path test:

```elixir
stub(LatticeStripe.MockTransport, :request, fn req ->
  if req.url =~ "cus_123" do
    ok_response(%{"id" => "cus_123", "object" => "customer"})
  else
    error_response()
  end
end)
```

---

### IN-02: No test for `max_concurrency` actually limiting concurrency

**File:** `test/lattice_stripe/batch_test.exs:135-148`

**Issue:** The `max_concurrency` option test verifies that passing `max_concurrency: 1` still returns correct results, but does not verify the concurrency constraint itself. This is an info-level observation — it does not risk incorrect behavior — but a test named "accepts max_concurrency option" that only checks the happy path gives false assurance that the option is wired correctly.

**Fix:** Consider renaming the test to "returns correct results when max_concurrency: 1 is set" to accurately describe what it asserts, or add a concurrency-measuring test using `Process.sleep` and timestamps if the constraint matters for correctness guarantees.

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
