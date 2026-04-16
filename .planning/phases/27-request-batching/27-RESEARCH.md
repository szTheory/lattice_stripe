# Phase 27: Request Batching - Research

**Researched:** 2026-04-16
**Domain:** Elixir concurrent task coordination (`Task.async_stream`), MFA dispatch, fault isolation
**Confidence:** HIGH

## Summary

Phase 27 adds `LatticeStripe.Batch`, a single-module, single-function additive unit. The implementation is wholly built on Elixir stdlib primitives — `Task.async_stream` with `on_timeout: :kill_task` and a `try/rescue` wrapper per task body. No new dependencies are required. No existing modules are modified.

The critical design insight already locked in CONTEXT.md is that `Task.async_stream/5`'s default `on_timeout: :exit` kills the *caller* on timeout — which is the opposite of what we want. We must use `on_timeout: :kill_task` to isolate timeout failures to individual task slots. Combined with `try/rescue` inside each task body, the caller process is fully protected.

`Task.async_stream` returns `{:ok, value}` or `{:exit, reason}` per slot. The batch module maps these to the SDK's universal `{:ok, result} | {:error, %Error{}}` contract. Every non-success result (exception in `try/rescue`, `{:exit, :timeout}`, `{:exit, reason}`) becomes `{:error, %Error{type: :connection_error}}`.

**Primary recommendation:** Implement `LatticeStripe.Batch` as a single file (`lib/lattice_stripe/batch.ex`) using `Task.async_stream` with `on_timeout: :kill_task`, `ordered: true`, `timeout: :infinity`. Wrap each task body in `try/rescue`. Map stream results to the SDK error contract. Add `LatticeStripe.Batch` to the `"Client & Configuration"` group in `mix.exs`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01: Input format** — MFA tuples `{module, :function, args}`. Client is prepended automatically. No anonymous function support.
- **D-02: max_concurrency** — Configurable via `opts`, defaults to `System.schedulers_online()`. Maps directly to `Task.async_stream`'s `:max_concurrency`.
- **D-03: Timeout behavior** — No batch-level timeout. `Task.async_stream` `:timeout` set to `:infinity`. Client per-request timeouts are authoritative. Client-level timeout produces `{:error, %Error{type: :connection_error}}` in the task slot.
- **D-04: Result contract** — `Batch.run/2` returns `{:ok, results}` (list of `{:ok, struct} | {:error, %Error{}}`). Top-level `{:error, reason}` only for argument validation failures. `try/rescue` per task body mandatory. `{:exit, :timeout}` maps to `{:error, %Error{type: :connection_error, message: "Task timed out"}}`.
- **D-05: No batch telemetry** — Each task emits its own request telemetry via the existing pipeline. No additional batch-level events.
- **D-06: API surface** — `run/2` (opts as third arg via `run/3`). No bang variant. Typespec:
  ```elixir
  @type task :: {module(), atom(), [term()]}
  @type result :: {:ok, term()} | {:error, Error.t()}
  @spec run(Client.t(), [task()], keyword()) :: {:ok, [result()]} | {:error, Error.t()}
  ```

### Claude's Discretion

- Whether to add an `ordered: false` option for callers who don't need order preservation
- Internal module structure — single file or split helpers
- Exact validation logic for MFA tuples (arity checking, module existence, etc.)
- Test organization — unit tests with Mox transport vs integration tests with stripe-mock
- `@doc` examples — how many usage examples to include

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-02 | Developer can execute multiple API calls concurrently via a `LatticeStripe.Batch` module using `Task.async_stream` with proper error handling (no linked task crashes) | `Task.async_stream` with `on_timeout: :kill_task` provides crash isolation; `try/rescue` catches exceptions; result mapping to `{:ok,_}\|{:error,%Error{}}` contract is well-understood from existing codebase |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fan-out concurrency coordination | SDK Client layer | — | Batch is a client-side helper; it calls `Client.request/2` per task, same as any resource module |
| Per-task timeout enforcement | Client.request/2 (existing) | — | The three-tier timeout cascade already lives in Client; Batch must not duplicate it |
| Error isolation (crash protection) | Batch module | Task.async_stream `:on_timeout` | Batch owns `try/rescue` per task body; async_stream owns process-level kill on OTP timeout |
| Result ordering | Task.async_stream `ordered: true` | — | Stream option, not a Batch concern to implement manually |
| Input validation | Batch module | — | Guard on empty list and non-MFA shapes before spawning tasks |
| Telemetry | Existing request pipeline | — | Each task emits events via existing `Telemetry.request_span`; no new events needed |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Task (Elixir stdlib) | Elixir 1.15+ | Concurrent task coordination | Built-in; `Task.async_stream` is the canonical fan-out primitive in Elixir |
| `LatticeStripe.Client` | (project) | Per-task HTTP dispatch | Already contains telemetry, retry, timeout cascade — batch tasks reuse it entirely |
| `LatticeStripe.Error` | (project) | Error struct for task failures | Universal error contract already established across all resource modules |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `System.schedulers_online/0` | Elixir stdlib | Default max_concurrency value | Called once at runtime to size the default concurrency cap |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Task.async_stream` | `Task.async` + `Task.await` pairs | Manual pairs require zipping results back to inputs; async_stream handles ordering, concurrency cap, and streaming semantics out of the box |
| `Task.async_stream` | `GenServer` worker pool | Massive overengineering for a stateless fan-out; GenServer adds process lifecycle complexity with no benefit |
| `on_timeout: :kill_task` | `on_timeout: :exit` (default) | `:exit` kills the caller — exactly wrong. `:kill_task` terminates only the timed-out task and emits `{:exit, :timeout}` in the stream |

**Installation:** No new dependencies. `Task` is part of the Elixir standard library.

---

## Architecture Patterns

### System Architecture Diagram

```
Caller
  │
  ▼
LatticeStripe.Batch.run(client, tasks, opts)
  │
  ├── validate_input(tasks)  ──► {:error, %Error{}} on empty/invalid
  │
  ▼
Task.async_stream(tasks, &dispatch_task(client, &1), opts)
  │
  ├── [task 1]  apply(mod, fun, [client | args])
  │     try/rescue ──► {:ok, result} | {:error, %Error{}}
  │
  ├── [task 2]  apply(mod, fun, [client | args])
  │     try/rescue ──► {:ok, result} | {:error, %Error{}}
  │
  └── [task N]  ...
        │
        ▼
   Stream emits: {:ok, {:ok, result}}
               | {:ok, {:error, %Error{}}}
               | {:exit, :timeout}            ← on_timeout: :kill_task
               | {:exit, reason}
        │
        ▼
  map_result/1  ──►  {:ok, result}
                   | {:error, %Error{type: :connection_error}}
        │
        ▼
  {:ok, [result_per_task]}   (order preserved)
```

### Recommended Project Structure

```
lib/
└── lattice_stripe/
    └── batch.ex          # New module — LatticeStripe.Batch

test/
└── lattice_stripe/
    └── batch_test.exs    # Unit tests with MockTransport
```

No subdirectory needed. `Batch` is a single-function module ~100 lines.

### Pattern 1: Task.async_stream with :kill_task

**What:** Fan-out enumerable over a function, killing individual timed-out tasks without crashing the caller.
**When to use:** Any time you need N independent HTTP requests in parallel with result-per-slot contract.
**Example:**
```elixir
# Source: https://hexdocs.pm/elixir/1.19.3/Task.html
results =
  tasks
  |> Task.async_stream(
    fn {mod, fun, args} ->
      try do
        apply(mod, fun, [client | args])
      rescue
        e -> {:error, %LatticeStripe.Error{type: :connection_error, message: Exception.message(e)}}
      end
    end,
    max_concurrency: max_concurrency,
    ordered: true,
    timeout: :infinity,
    on_timeout: :kill_task
  )
  |> Enum.map(&map_stream_result/1)
```

### Pattern 2: Stream Result Mapping

**What:** Convert `Task.async_stream`'s `{:ok, val} | {:exit, reason}` output to SDK error contract.
**When to use:** Always — async_stream's output shape is not the SDK's shape.
**Example:**
```elixir
defp map_stream_result({:ok, {:ok, result}}), do: {:ok, result}
defp map_stream_result({:ok, {:error, %Error{}} = err}), do: err
defp map_stream_result({:exit, :timeout}) do
  {:error, %Error{type: :connection_error, message: "Task timed out"}}
end
defp map_stream_result({:exit, reason}) do
  {:error, %Error{type: :connection_error, message: "Task exited: #{inspect(reason)}"}}
end
```

### Pattern 3: Input Validation

**What:** Guard the MFA tuple list before spawning any tasks.
**When to use:** At the top of `run/3` before any task work.
**Example:**
```elixir
defp validate_tasks([]), do:
  {:error, %Error{type: :invalid_request_error, message: "tasks list cannot be empty"}}
defp validate_tasks(tasks) when is_list(tasks) do
  invalid = Enum.find(tasks, &(not valid_mfa?(&1)))
  if invalid,
    do: {:error, %Error{type: :invalid_request_error, message: "invalid MFA tuple: #{inspect(invalid)}"}},
    else: :ok
end

defp valid_mfa?({mod, fun, args})
     when is_atom(mod) and is_atom(fun) and is_list(args), do: true
defp valid_mfa?(_), do: false
```

### Pattern 4: ExDoc Grouping

**What:** `LatticeStripe.Batch` belongs in the `"Client & Configuration"` group in `mix.exs`.
**When to use:** When adding `LatticeStripe.Batch` to `groups_for_modules` in `mix.exs`.
**Example:**
```elixir
# In mix.exs docs: [...] groups_for_modules: [...]
"Client & Configuration": [
  LatticeStripe,
  LatticeStripe.Client,
  LatticeStripe.Batch,        # add here
  LatticeStripe.Config,
  LatticeStripe.Error,
  ...
]
```

### Anti-Patterns to Avoid

- **`on_timeout: :exit` (the default):** This kills the *caller process* on timeout. Always use `on_timeout: :kill_task` in `Batch`.
- **`timeout: 5000` (the default):** The default `Task.async_stream` timeout is 5000ms per task *across all running tasks*, not per-task. Setting `:infinity` and relying on `Client.request/2` timeouts is correct per D-03.
- **No `try/rescue`:** Without it, an unexpected exception inside a task body propagates as `{:exit, reason}`, but we still want to normalize it to `%Error{}`.
- **Calling `apply` without prepending client:** Each resource function signature is `def operation(%Client{} = client, ...)` — the client must be the first arg.
- **`Task.async` + `Task.await` instead of `async_stream`:** Loses built-in concurrency cap, requires manual ordering, and is harder to reason about for N-item lists.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Concurrent task fan-out with result ordering | Custom pool + GenServer + mailbox draining | `Task.async_stream` | It handles ordering, max_concurrency, backpressure, and timeout isolation — all the tricky parts |
| Per-task timeout isolation | Manual `Task.async`/`receive` with timers | `Task.async_stream` with `on_timeout: :kill_task` | Process monitor/demonitor and selective receive are error-prone to get right |
| Task crash isolation | Process links + trapping exits | `try/rescue` + `on_timeout: :kill_task` | Trapping exits inside a library module leaks into the calling application's process semantics |

**Key insight:** The complexity of concurrent fan-out with isolation is already solved by `Task.async_stream` options. The batch module's job is thin glue: validate → dispatch → normalize results.

---

## Common Pitfalls

### Pitfall 1: Default `on_timeout` Kills the Caller
**What goes wrong:** `Task.async_stream` defaults to `on_timeout: :exit`, which causes the calling process to exit when any task times out. The caller crashes and returns nothing.
**Why it happens:** The default is designed for pipelines where a timeout should abort everything. SDKs need per-slot failure instead.
**How to avoid:** Always specify `on_timeout: :kill_task`. This terminates only the timed-out task and emits `{:exit, :timeout}` in the stream.
**Warning signs:** Tests with short timeouts crash ExUnit instead of returning `{:error, %Error{}}`.

### Pitfall 2: Default `timeout: 5000` Creates Spurious Failures
**What goes wrong:** `Task.async_stream`'s `:timeout` defaults to 5000ms. Long-running Stripe calls (list operations, slow connections) that the Client would allow through get killed by the batch layer.
**Why it happens:** The timeout was set globally on the stream, not per-task relative to `Client.request/2`.
**How to avoid:** Set `timeout: :infinity` per D-03. The Client's own timeout cascade is the authoritative deadline.
**Warning signs:** Batch tests pass in isolation but fail in CI where Stripe-mock is slow.

### Pitfall 3: Client Not Prepended to Args
**What goes wrong:** `apply(mod, fun, args)` is called without inserting `client` as the first argument, causing `FunctionClauseError` because resource functions require `%Client{}` first.
**Why it happens:** MFA tuples in D-01 intentionally omit the client from `args` to avoid repetition.
**How to avoid:** Always call `apply(mod, fun, [client | args])` — prepend the client inside the dispatch function.
**Warning signs:** `FunctionClauseError` on first batch run with any resource function.

### Pitfall 4: `async_stream` Emits `{:ok, inner_result}` Wrapping
**What goes wrong:** Task success yields `{:ok, {:ok, struct}}` (double-wrapped). Forgetting the outer wrapper causes pattern match failures when collecting results.
**Why it happens:** `async_stream` wraps every successful task result in `{:ok, _}`, regardless of what the task returns.
**How to avoid:** The `map_stream_result/1` helper must pattern-match `{:ok, {:ok, result}}` and `{:ok, {:error, err}}` explicitly.
**Warning signs:** Results are `{:ok, {:ok, struct}}` instead of `{:ok, struct}` in the returned list.

### Pitfall 5: Mox Expects Must Allow Concurrent Calls
**What goes wrong:** `expect(MockTransport, :request, fn _ -> ... end)` allows only one call by default. Batch with N tasks needs `N` expects or a single `stub`.
**Why it happens:** Mox is designed for strict call counting; concurrent tasks each call `MockTransport.request/1`.
**How to avoid:** Use `stub(MockTransport, :request, fn _ -> ... end)` for batch tests, or `expect` N times. Tests must use `async: true` with `verify_on_exit!`.
**Warning signs:** Mox raises "unexpected call" on the second task in a batch test.

---

## Code Examples

### Complete Batch Module Skeleton
```elixir
# Source: Elixir stdlib Task.async_stream docs + existing LatticeStripe patterns
defmodule LatticeStripe.Batch do
  @moduledoc """
  Execute multiple Stripe API calls concurrently.

  ## When to use

  `Batch.run/2` is designed for **fan-out patterns** — situations where you need
  to fetch several independent Stripe resources in parallel for a single user request.

  Typical example: loading a dashboard that needs a customer, their active
  subscriptions, and their recent invoices simultaneously:

      {:ok, results} = LatticeStripe.Batch.run(client, [
        {LatticeStripe.Customer, :retrieve, ["cus_123"]},
        {LatticeStripe.Subscription, :list, [%{customer: "cus_123"}]},
        {LatticeStripe.Invoice, :list, [%{customer: "cus_123"}]}
      ])

      [customer_result, subscriptions_result, invoices_result] = results

  ## What it is NOT

  `Batch.run/2` is **not** a substitute for Stripe's native batch API. It executes
  each call as an independent HTTP request — there is no server-side batching,
  no atomic transaction, and no reduced HTTP overhead. Use it when you want
  concurrent fan-out in your application layer; use Stripe's batch endpoint when
  you need atomic multi-resource operations.

  ## Error isolation

  Individual task failures do **not** crash the caller or cancel other tasks.
  Each slot in the result list independently resolves to `{:ok, result}` or
  `{:error, %LatticeStripe.Error{}}`.

      for result <- results do
        case result do
          {:ok, resource} -> process(resource)
          {:error, err} -> Logger.warning("Stripe call failed: \#{err}")
        end
      end
  """

  alias LatticeStripe.{Client, Error}

  @type task :: {module(), atom(), [term()]}
  @type result :: {:ok, term()} | {:error, Error.t()}

  @spec run(Client.t(), [task()], keyword()) :: {:ok, [result()]} | {:error, Error.t()}
  def run(%Client{} = client, tasks, opts \\ []) when is_list(tasks) do
    with :ok <- validate_tasks(tasks) do
      max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

      results =
        tasks
        |> Task.async_stream(
          fn {mod, fun, args} ->
            try do
              apply(mod, fun, [client | args])
            rescue
              e ->
                {:error,
                 %Error{
                   type: :connection_error,
                   message: "Task raised exception: #{Exception.message(e)}"
                 }}
            end
          end,
          max_concurrency: max_concurrency,
          ordered: true,
          timeout: :infinity,
          on_timeout: :kill_task
        )
        |> Enum.map(&map_stream_result/1)

      {:ok, results}
    end
  end

  defp map_stream_result({:ok, {:ok, _} = ok}), do: ok
  defp map_stream_result({:ok, {:error, %Error{}} = err}), do: err

  defp map_stream_result({:exit, :timeout}) do
    {:error, %Error{type: :connection_error, message: "Task timed out"}}
  end

  defp map_stream_result({:exit, reason}) do
    {:error, %Error{type: :connection_error, message: "Task exited: #{inspect(reason)}"}}
  end

  defp validate_tasks([]) do
    {:error, %Error{type: :invalid_request_error, message: "tasks list cannot be empty"}}
  end

  defp validate_tasks(tasks) when is_list(tasks) do
    case Enum.find(tasks, &(not valid_mfa?(&1))) do
      nil -> :ok
      bad -> {:error, %Error{type: :invalid_request_error, message: "invalid task: #{inspect(bad)}"}}
    end
  end

  defp valid_mfa?({mod, fun, args})
       when is_atom(mod) and is_atom(fun) and is_list(args), do: true
  defp valid_mfa?(_), do: false
end
```

### Unit Test Skeleton
```elixir
# test/lattice_stripe/batch_test.exs
defmodule LatticeStripe.BatchTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Batch, Error}

  setup :verify_on_exit!

  describe "run/3 — happy path" do
    test "returns {:ok, results} with one {:ok, _} per task" do
      client = test_client()

      stub(LatticeStripe.MockTransport, :request, fn req ->
        case req.url do
          url when url =~ "customers/cus_123" -> ok_response(%{"id" => "cus_123", "object" => "customer"})
          url when url =~ "subscriptions" -> ok_response(%{"object" => "list", "data" => [], "has_more" => false, "url" => "/v1/subscriptions"})
          _ -> ok_response(%{"id" => "inv_1", "object" => "invoice"})
        end
      end)

      tasks = [
        {LatticeStripe.Customer, :retrieve, ["cus_123"]},
        {LatticeStripe.Subscription, :list, [%{}]},
        {LatticeStripe.Invoice, :list, [%{}]}
      ]

      assert {:ok, results} = Batch.run(client, tasks)
      assert length(results) == 3
      assert [{:ok, _}, {:ok, _}, {:ok, _}] = results
    end
  end

  describe "run/3 — isolation" do
    test "one failing task returns {:error, %Error{}} in its slot, others succeed" do
      # ...
    end

    test "empty task list returns {:error, %Error{type: :invalid_request_error}}" do
      client = test_client()
      assert {:error, %Error{type: :invalid_request_error}} = Batch.run(client, [])
    end
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Task.async` + manual `receive` | `Task.async_stream` | Elixir 1.4 (2016) | `async_stream` handles ordering, concurrency cap, and timeout options declaratively |
| `on_timeout: :exit` awareness | `on_timeout: :kill_task` needed explicitly | Elixir 1.6 (2017) | Must always opt into `:kill_task` for library code that must not crash callers |

**No deprecated patterns relevant to this phase.**

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `LatticeStripe.Batch` belongs in the `"Client & Configuration"` ExDoc group (not a new group) | Architecture Patterns / ExDoc Grouping | Minor — planner would create the wrong group, requiring a mix.exs fixup |

**All other claims were verified against Elixir 1.19.3 docs via Context7 or directly from the project codebase.**

---

## Open Questions

1. **`ordered: false` opt-in (discretionary)**
   - What we know: D-02 doesn't mention ordering as a locked choice; CONTEXT.md lists it as discretionary
   - What's unclear: Whether the performance benefit of `ordered: false` is meaningful enough to expose as an option in v1.2
   - Recommendation: Default `ordered: true` (predictable, user-friendly); add `ordered: false` as a passthrough opt if the planner wants it — it's one additional line in the `async_stream` opts call

2. **MFA validation depth (discretionary)**
   - What we know: CONTEXT.md leaves "exact validation logic for MFA tuples" to Claude's discretion
   - What's unclear: Whether to also check `function_exported?(mod, fun, length(args) + 1)` (the +1 for client prepend)
   - Recommendation: Skip module/function existence check at `validate_tasks/1` time — it adds a compile-time coupling risk and the apply call will raise a clear error anyway, which `try/rescue` already catches

---

## Environment Availability

Step 2.6: SKIPPED — Phase 27 is purely additive Elixir code using Elixir stdlib (`Task`). No external tools, services, or CLI utilities beyond the existing project stack are required. `Task.async_stream` is available in all Elixir 1.15+ runtimes the project targets.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/batch_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-02 | Multiple concurrent calls return one result per task | unit | `mix test test/lattice_stripe/batch_test.exs --include describe:"run/3"` | Wave 0 |
| DX-02 | Individual task failure returns `{:error, %Error{}}` in its slot, caller not crashed | unit | `mix test test/lattice_stripe/batch_test.exs --include describe:"isolation"` | Wave 0 |
| DX-02 | Task timeout returns `{:error, %Error{type: :connection_error}}` | unit | `mix test test/lattice_stripe/batch_test.exs --include describe:"timeout"` | Wave 0 |
| DX-02 | Empty task list returns validation error | unit | `mix test test/lattice_stripe/batch_test.exs --include describe:"validation"` | Wave 0 |
| DX-02 | `@doc` includes "when to use" / "not a substitute for Stripe batch API" | manual | inspect module doc | N/A |

### Sampling Rate
- **Per task commit:** `mix test test/lattice_stripe/batch_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green + `mix credo --strict` before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/lattice_stripe/batch_test.exs` — covers DX-02 all test rows above
- [ ] No framework install needed — ExUnit ships with Elixir

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Auth handled by `Client.request/2` per task — no change |
| V3 Session Management | no | Stateless HTTP calls |
| V4 Access Control | no | Access controlled by API key in Client |
| V5 Input Validation | yes | MFA tuple validation in `validate_tasks/1` — prevent `apply` on arbitrary atoms |
| V6 Cryptography | no | No crypto in this module |

### Known Threat Patterns for Batch / MFA dispatch

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Arbitrary code execution via unvalidated MFA | Tampering | `valid_mfa?/1` guard: `is_atom(mod) and is_atom(fun) and is_list(args)` — no string eval, no dynamic atom creation |
| Resource exhaustion via unbounded `max_concurrency` | Denial of Service | Default to `System.schedulers_online()`; user-provided value is caller responsibility |

---

## Sources

### Primary (HIGH confidence)
- [/websites/hexdocs_pm_elixir_1_19_3] — `Task.async_stream/5` options: `on_timeout`, `ordered`, `timeout`, `max_concurrency`; verified `on_timeout: :kill_task` emits `{:exit, :timeout}` not a crash
- Project codebase: `lib/lattice_stripe/client.ex`, `lib/lattice_stripe/error.ex`, `mix.exs` — verified resource function signatures, Error struct fields, ExDoc group structure

### Secondary (MEDIUM confidence)
- `.planning/phases/27-request-batching/27-CONTEXT.md` — all locked decisions consumed directly

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `Task.async_stream` is stdlib; verified via Context7 Elixir 1.19.3 docs
- Architecture: HIGH — all patterns derive from locked CONTEXT.md decisions + existing codebase patterns
- Pitfalls: HIGH — `on_timeout: :exit` vs `:kill_task` and double-wrapping verified against official docs; Mox concurrent behavior from project's existing test patterns

**Research date:** 2026-04-16
**Valid until:** 2026-10-16 (stable stdlib primitives; 6-month validity is conservative)
