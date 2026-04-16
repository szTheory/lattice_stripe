---
phase: 26-circuit-breaker-opentelemetry-guides
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - guides/circuit-breaker.md
  - guides/opentelemetry.md
  - guides/extending-lattice-stripe.md
  - test/integration/circuit_breaker_integration_test.exs
  - test/integration/opentelemetry_integration_test.exs
  - mix.exs
  - test/test_helper.exs
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 26: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Seven files reviewed covering three new guides (circuit breaker, OpenTelemetry, extending LatticeStripe) and their supporting integration tests plus project plumbing. The guides are well-structured and the integration tests correctly compile the guide examples inline. Four warnings found: one factual error in guide documentation that would mislead users debugging a misconfigured fuse, one incorrect header normalization in the Req transport example that produces the wrong type (lists instead of strings), one unhandled case clause in the OTel stop handler that would crash on unexpected telemetry status values, and a test isolation gap in the circuit breaker integration tests. Two info items round out style nits.

---

## Warnings

### WR-01: Guide documents incorrect crash behavior for uninstalled `:fuse`

**File:** `guides/circuit-breaker.md:274`

**Issue:** The "Common Pitfalls" section states that when `:fuse.ask/2` returns `{:error, not_found}` (fuse not installed), "the circuit breaker silently does nothing." This is factually wrong. The `check_circuit_and_retry/2` function only has clauses for `:blown` and `:ok`. An unmatched `{:error, not_found}` return raises a `CaseClauseError` at runtime — the request crashes rather than silently bypassing the circuit check. A user who sees a crash and reads this guide text will look for the wrong cause.

**Fix:** Correct the description. Either:

1. Update the text to say the unmatched clause raises `CaseClauseError`, OR  
2. Add a catch-all clause to the guide example (recommended — aligns with the advice given two paragraphs later):

```elixir
defp check_circuit_and_retry(attempt, context) do
  case :fuse.ask(@fuse_name, :sync) do
    :blown ->
      :stop

    :ok ->
      retry_or_stop(attempt, context)

    {:error, :not_found} ->
      # Fuse not installed — log warning and fall through to normal retry
      require Logger
      Logger.warning("[LatticeStripe] Fuse #{@fuse_name} not installed; circuit breaker inactive")
      retry_or_stop(attempt, context)
  end
end
```

The same unhandled clause exists in the integration test's `FuseRetryStrategy` at `test/integration/circuit_breaker_integration_test.exs:30-34`.

---

### WR-02: `ReqTransport` header normalization produces wrong type (list values instead of strings)

**File:** `guides/extending-lattice-stripe.md:55`

**Issue:** In Req 0.4+, `Req.Response.headers` is a `%{String.t() => [String.t()]}` map (multi-value headers). When iterated with `Enum.map`, each entry is `{key, [value_list]}`. The identity transform `fn {k, v} -> {k, v} end` passes the list through unchanged, producing `[{"content-type", ["application/json"]}]` instead of the required `[{"content-type", "application/json"}]`. The `LatticeStripe.Transport` contract requires `[{String.t(), String.t()}]`. Passing list values will cause header parsing (e.g., `Stripe-Should-Retry`, `Request-Id`) to fail silently or crash downstream.

**Fix:** Flatten multi-value headers to individual 2-tuples:

```elixir
# Normalize Req's map-of-lists headers to [{String.t(), String.t()}] 2-tuples
headers_list =
  Enum.flat_map(resp_headers, fn {k, values} ->
    Enum.map(values, fn v -> {k, v} end)
  end)
```

---

### WR-03: OTel stop handler crashes on unexpected `metadata.status` values

**File:** `guides/opentelemetry.md:93-96` (also `test/integration/opentelemetry_integration_test.exs:65-68`)

**Issue:** The `handle_event/4` clause for `[:lattice_stripe, :request, :stop]` matches `metadata.status` against only `:ok` and `:error`:

```elixir
case metadata.status do
  :ok -> Tracer.set_status(:ok, "")
  :error -> Tracer.set_status(:error, "Stripe request failed")
end
```

Any other value raises `CaseClauseError`. While the current telemetry implementation emits only `:ok` / `:error`, telemetry metadata is not a hard contract — future versions or third-party telemetry middleware could emit additional values. The crash would silently lose the span (no `end_span` call) and surface as an unrelated error in the user's application.

The integration test at line 65-68 only exercises `:ok`, leaving the `:error` path untested and the unhandled case undetected.

**Fix:** Add a catch-all that ends the span regardless:

```elixir
case metadata.status do
  :ok -> Tracer.set_status(:ok, "")
  :error -> Tracer.set_status(:error, "Stripe request failed")
  _other -> :ok
end

Tracer.end_span()
```

Move `Tracer.end_span()` outside the `case` to ensure it always runs (currently it is inside the `:ok` / `:error` branches implicitly due to the surrounding handler function — actually it is called after the case at line 98, so the crash still skips it). Add a test covering the `:error` status path.

---

### WR-04: Circuit breaker integration test fuse not reset between tests — state leaks

**File:** `test/integration/circuit_breaker_integration_test.exs:68-73`

**Issue:** The `setup/0` block calls `:fuse.install(:test_stripe_api, ...)` before each test. However, `:fuse.install/2` on an already-installed fuse name resets it with new options — this is documented behavior in `:fuse`. The problem is that the fuse is a global gen_server process shared across all tests in the module. Since `async: false` is set and all tests use the same fuse name `:test_stripe_api`, the setup works correctly for sequential runs. However, the fuse state left by one test (e.g., a blown circuit) persists until the next `setup` call re-installs it. If a test fails mid-way, the fuse is in an undefined state for the next test.

More critically, `:fuse.install/2` called when `:fuse` is not running (the application not started) will crash the setup. The test module does not verify that the `:fuse` application is started. The `--include fuse_integration` tag implies `:fuse` is available, but there is no guard.

**Fix:** Add an explicit reset/guard and document the dependency:

```elixir
setup do
  # Ensure :fuse application is started (no-op if already running)
  {:ok, _} = Application.ensure_all_started(:fuse)

  # Reset fuse to known state: threshold 1, 10s window, 60s reset
  case :fuse.ask(:test_stripe_api, :sync) do
    {:error, :not_found} -> :ok
    _ -> :fuse.reset(:test_stripe_api)
  end

  :fuse.install(:test_stripe_api, {{:standard, 1, 10_000}, {:reset, 60_000}})
  :ok
end
```

---

## Info

### IN-01: `finch` required even when custom `transport` is provided — guide comment could be clearer

**File:** `guides/extending-lattice-stripe.md:73`

**Issue:** The comment `# still required for default; won't be called` is misleading. `finch` is in `@enforce_keys` in `LatticeStripe.Client` — it is always required regardless of which transport is used. The comment implies it is only needed to satisfy a default, which understates the requirement. Users building a custom transport for non-Finch environments (e.g., tests, custom HTTP clients) may be confused about why they need to name a Finch pool they never start.

This is an architecture design note rather than a guide bug, but the comment should accurately describe the constraint.

**Fix:** Update the comment:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,  # required by Client struct; ignored when transport: is set
  transport: MyApp.ReqTransport
)
```

---

### IN-02: Commented-out logo line in `mix.exs`

**File:** `mix.exs:22`

**Issue:** `# logo: "assets/logo.png",  # Add when logo asset is created` is commented-out code in a configuration file. Minor, but adds noise.

**Fix:** Either remove the comment entirely or track logo creation as a separate task and remove this placeholder from the docs config.

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
