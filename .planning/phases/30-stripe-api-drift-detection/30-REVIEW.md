---
phase: 30-stripe-api-drift-detection
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - .github/workflows/drift.yml
  - lib/lattice_stripe/drift.ex
  - lib/mix/tasks/lattice_stripe.check_drift.ex
  - test/lattice_stripe/drift_test.exs
  - test/support/fixtures/openapi_spec_fixture.ex
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 30: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

The drift detection feature is well-structured: clear separation between the core `Drift` module, the Mix task wrapper, and test fixtures. The logic for extracting schemas, comparing `@known_fields`, and formatting reports is correct. Three warnings and three informational items were found — none are critical, but two of the warnings are behavioral bugs (wrong exit code and silent source-path failures in CI).

## Warnings

### WR-01: `new_resources` list silently prints but exits 0 — CI misses new Stripe resources

**File:** `lib/mix/tasks/lattice_stripe.check_drift.ex:36-39`

**Issue:** When `drift_count == 0` but `new_resources` is non-empty, the task prints the report and exits with code 0. The workflow's `Create or update drift issue` step only fires on `exit_code == '1'`. So if Stripe adds entirely new object types (e.g., `tax.form`, `issuing.dispute`) that are not in `ObjectTypes` at all, the CI job prints the information to stdout and exits cleanly — no issue is created, and the drift goes unnoticed.

Per the task's own `@moduledoc`, exit code 1 means "drift detected", and `new_resources` is a form of drift (Stripe resources that have no coverage in the SDK).

**Fix:**
```elixir
# In Mix.Tasks.LatticeStripe.CheckDrift.run/1, replace the drift_count == 0 branch:
{:ok, %{drift_count: 0} = result} ->
  if result.new_resources != [] do
    Mix.shell().info(LatticeStripe.Drift.format_report(result))
    System.halt(1)   # <-- new resources ARE drift; trigger the issue workflow
  else
    Mix.shell().info("No drift detected. @known_fields are up to date.")
  end
```

---

### WR-02: `known_fields_for/1` reads source files by compile-time path — silently returns empty set in release/CI builds

**File:** `lib/lattice_stripe/drift.ex:164-191`

**Issue:** `module.__info__(:compile)[:source]` returns the absolute path to the `.ex` source file on the machine where the code was _compiled_. In GitHub Actions the build cache is reused across runs (`actions/cache@v3` keyed on `mix.lock`). When a cached `_build` is restored, `__info__(:compile)[:source]` still points to the path from the original compile run. If that path no longer exists on the runner's filesystem (e.g., different agent, ephemeral runner, or the cache was built on a different checkout location), `File.read/1` returns `{:error, :enoent}`, the `{:error, _reason}` clause in `known_fields_for/1` fires, and the field list for that module silently becomes an empty `MapSet`.

When `known_fields` is empty, `MapSet.difference(known_fields, spec_fields)` produces an empty set of removals, and `MapSet.difference(spec_fields, known_fields)` reports _every_ spec field as an addition — generating a massive, misleading drift report on the very first cache-hit run.

**Fix:** After `File.read` fails, fall back to a repo-relative path derived from `Application.app_dir/2` or `Mix.Project.app_path/0`:

```elixir
defp resolve_source_path(charlist) do
  absolute = List.to_string(charlist)
  if File.exists?(absolute) do
    absolute
  else
    # Compile-time path no longer valid; try relative to project root
    rel = Path.relative_to(absolute, "/") |> Path.join()
    project_root = Mix.Project.build_path() |> Path.join("../../") |> Path.expand()
    Path.join(project_root, rel)
  end
end
```

Alternatively, use `@external_resource` in each module to embed field lists at compile time rather than reading source files at runtime.

---

### WR-03: `throw/catch` used for control flow in `fetch_spec/0` — unconventional and potentially masks errors

**File:** `lib/lattice_stripe/drift.ex:208-231`

**Issue:** `fetch_spec/0` uses `throw({:finch_start_failed, reason})` to escape the function body and then catches it in a `catch` clause appended to the `defp` block. In Elixir, `throw/catch` is conventionally reserved for non-local exits from `Enum` or deeply nested recursion. Using it here prevents the `with` chain from propagating the Finch start failure through a normal `{:error, reason}` tuple — and any future clause added inside the `with` in `run/0` that calls `fetch_spec/0` won't compose cleanly.

**Fix:** Return `{:error, reason}` directly:

```elixir
defp fetch_spec do
  finch_name = LatticeStripe.Drift.Finch

  with :ok <- start_finch(finch_name),
       {:ok, response} <- do_request(finch_name) do
    Jason.decode(response.body)
  end
end

defp start_finch(name) do
  case Finch.start_link(name: name) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
    {:error, reason} -> {:error, {:finch_start_failed, reason}}
  end
end

defp do_request(finch_name) do
  :get
  |> Finch.build(@spec_url, [], nil)
  |> Finch.request(finch_name, receive_timeout: 30_000)
  |> case do
    {:ok, %Finch.Response{status: 200} = resp} -> {:ok, resp}
    {:ok, %Finch.Response{status: status}} -> {:error, {:http_error, status}}
    {:error, exception} -> {:error, exception}
  end
end
```

---

## Info

### IN-01: `OptionParser.parse(args, strict: [])` silently ignores all flags

**File:** `lib/mix/tasks/lattice_stripe.check_drift.ex:31`

**Issue:** `strict: []` means no options are declared, so any flag the user passes (e.g., `--spec-url`) is silently discarded. The parsed `opts` keyword list will always be empty and the `LatticeStripe.Drift.run(opts)` call never receives user-supplied options. This is harmless now, but the plumbing looks like it was designed for extensibility that is never exercised.

**Fix:** Either remove the `opts` parsing entirely and call `Drift.run()` directly, or document that the flag is reserved for future use:

```elixir
def run(_args) do
  Mix.Task.run("app.start")
  ...
```

---

### IN-02: `format_report/2` — empty `header` string when `drift_count == 0` but modules list is non-empty

**File:** `lib/lattice_stripe/drift.ex:77-119`

**Issue:** The second clause of `format_report/1` is reached when `drift_count > 0 OR new_resources != []`. However if called with `%{drift_count: 0, modules: [], new_resources: ["tax.form"]}` (which the Mix task does in the WR-01 scenario above), `header` is `""`, `module_sections` is `[]`, and `Enum.join([], "\n\n")` is `""`. The `parts` list then contains `["", "\nNew resources..."]` and the `Enum.reject` filter only removes items equal to `""` — so the leading empty string is dropped. The output is actually correct, but the logic is brittle. If `drift_count` is 0 and `modules` is empty but `new_resources` is non-empty, the `Enum.reject` filter correctly drops the empty header concatenation, but a future change that adds a different falsy value (e.g., `nil`) could break it.

**Fix:** Use `Enum.filter/2` with an explicit non-empty string guard, or restructure `parts` to not include the header when it is empty:

```elixir
parts =
  [
    if(header != "" or module_sections != [], do: header <> Enum.join(module_sections, "\n\n")),
    new_resources_section
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.reject(&(&1 == ""))
```

---

### IN-03: Fixture `openapi_spec_fixture.ex` is missing the `unregistered_resource` it documents

**File:** `test/support/fixtures/openapi_spec_fixture.ex:7`

**Issue:** The module's `@moduledoc` says:

> "unregistered_resource" schema: not in ObjectTypes registry (tests new resource detection)

But the `minimal_spec/0` map contains no `"unregistered_resource"` key under `components.schemas`. The test for new-resource detection in `drift_test.exs` does not exercise this fixture at all — `run/0` is not tested at the unit level (only `resource_schemas/1`, `compare/2`, `format_report/1`, and `known_fields_for/1` are tested). The documentation comment is misleading.

**Fix:** Either add the `"unregistered_resource"` entry to the fixture (matching the documented intent), or remove it from the `@moduledoc`:

```elixir
# Add to components.schemas map in minimal_spec/0:
"unregistered_resource" => %{
  "properties" => %{
    "id" => %{"type" => "string"},
    "object" => %{"enum" => ["unregistered_resource"], "type" => "string"}
  }
}
```

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
