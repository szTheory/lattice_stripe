# Phase 30: Stripe API Drift Detection - Research

**Researched:** 2026-04-16
**Domain:** Elixir Mix task, OpenAPI spec parsing, GitHub Actions cron, field comparison
**Confidence:** HIGH

## Summary

Phase 30 adds a Mix task (`mix lattice_stripe.check_drift`) and a GitHub Actions weekly cron that detects when Stripe's published OpenAPI spec adds fields or resources not yet reflected in LatticeStripe's `@known_fields`. The implementation is additive — no changes to existing resource modules, no runtime behavior changes, no new Hex dependencies.

The key technical discovery is that **`@known_fields` is not persisted as a module attribute at runtime** — `LatticeStripe.Customer.__info__(:attributes)` returns only `:vsn`. Similarly, `@object_map` in `ObjectTypes` is not accessible at runtime without a public accessor function. This means the plan MUST include two small code changes: (1) add `def object_map, do: @object_map` to `LatticeStripe.ObjectTypes`, and (2) use source file parsing to extract `@known_fields` values. The source parsing approach is viable because the `~w[...]` pattern is extremely consistent across all 68 modules (both single-line and multi-line variants confirmed).

The Stripe OpenAPI spec at `https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json` is ~7.6MB, fully parseable by Jason, and uses an `object` property with a single-element `enum` to identify first-class resource schemas — exactly 168 first-class schemas found. The `ObjectTypes` registry covers 36 of these; the other 132 unregistered types become the "new resources not yet implemented" report (D-06). Real drift was verified live: the `invoice` schema has 8 fields in the spec not in `@known_fields` and 15 fields in `@known_fields` not in the spec.

**Primary recommendation:** Implement as two modules (`LatticeStripe.Drift` + `Mix.Tasks.LatticeStripe.CheckDrift`) using Finch (already a dep) for HTTP, Jason for JSON parsing, and source file parsing for `@known_fields` extraction. Add `object_map/0` to `ObjectTypes`. GitHub Actions workflow uses `gh issue create/edit` with a `stripe-drift` label for duplicate prevention.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — OpenAPI Spec Sourcing:** Fetch from `stripe/openapi` GitHub repo at runtime (`spec3.json`). No vendored snapshot. Mix task downloads on each run; CI caches with short TTL.

**D-02 — Drift Report Format:** Structured list grouped by module name, fields present in spec but absent from `@known_fields`. Exit code 1 on drift, 0 when clean.

**D-03 — CI Notification:** GitHub Actions weekly cron opens a GitHub issue when drift detected. Duplicate prevention: if open drift issue exists, update it (or add comment) rather than create new.

**D-04 — Field Matching:** Compare top-level `properties` keys from each OpenAPI schema against module's `@known_fields`. Use `ObjectTypes` registry to map Stripe object type names to modules. Nested struct fields checked independently at their own module level.

**D-05 — Removed/Renamed Fields:** Fields in `@known_fields` but absent from spec flagged as "removed/renamed" warnings (not errors).

**D-06 — New Resource Detection:** Stripe object types in spec with no entry in `ObjectTypes` registry reported separately as "new resources not yet implemented." Informational only — not a CI failure.

### Claude's Discretion

- Internal module structure (single module vs. separate parser/reporter modules)
- Whether to use Req or raw `:httpc` for the OpenAPI spec download (dev-only dependency consideration)
- Exact GitHub Actions workflow syntax and caching strategy
- Whether the drift report includes field types from the OpenAPI spec or just field names
- Test strategy (unit tests with fixture spec snippets vs. integration test against live spec)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-06 | CI detects when Stripe's OpenAPI spec adds new fields/resources not yet in `@known_fields` via weekly cron + Mix task | Spec fetch/parsing pattern verified; ObjectTypes accessor approach identified; GitHub Actions issue creation confirmed via `gh` CLI; real drift confirmed on invoice schema |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| OpenAPI spec fetch | Mix task (dev tooling) | — | No runtime concern; only needed during drift check execution |
| `@known_fields` extraction | Mix task / source parser | — | Compile-time attribute not persisted at runtime; source parsing is the access path |
| ObjectTypes enumeration | `LatticeStripe.ObjectTypes` | — | Registry owns the mapping; needs a public accessor added |
| Field comparison logic | `LatticeStripe.Drift` module | — | Separable business logic; unit-testable with fixture spec data |
| Report formatting + exit code | `Mix.Tasks.LatticeStripe.CheckDrift` | — | Thin shell: arg parsing, output formatting, `System.halt/1` |
| Weekly cron + issue creation | GitHub Actions (`drift.yml`) | — | CI concern; `gh issue create/edit` via `GITHUB_TOKEN` |

## Standard Stack

### Core (all already in `mix.exs`)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | ~> 0.21 | HTTP fetch of OpenAPI spec | Already a runtime dep; no new dep needed; started via `Mix.Task.run("app.start")` |
| Jason | ~> 1.4 | Parse the 7.6MB JSON spec | Already a runtime dep; fast, handles large payloads well |
| ExUnit | stdlib | Test the drift logic | Standard; unit tests with fixture spec snippets |

### Supporting (no new Hex deps required)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `:httpc` (OTP :inets) | OTP 26+ | Alternative HTTP for spec download | Only if we want to avoid `Mix.Task.run("app.start")` — not recommended, Finch is simpler |
| `gh` CLI | included in ubuntu-latest | Create/update GitHub issues in Actions | Available by default in GitHub Actions runners since 2021 |

**No new Hex dependencies required for this phase.** [VERIFIED: codebase grep + mix.exs]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Source file parsing for `@known_fields` | `Module.__info__(:attributes)` | `__info__(:attributes)` returns only `:vsn` at runtime — module attributes are not persisted by default in BEAM. Source parsing is the correct approach. [VERIFIED: live `mix run -e` test] |
| Source file parsing for `@known_fields` | Adding `def known_fields, do: @known_fields` to each module | Cleaner API but touches 50+ resource modules — out of scope for this phase. Source parsing with regex avoids those changes. |
| Finch for spec fetch | `:httpc` directly | `:httpc` avoids `app.start` but requires manual SSL cert config (`cacerts: :public_key.cacerts_get()`). Finch is cleaner and consistent with the rest of the codebase. |
| `gh issue create` in Actions | GitHub REST API via curl | `gh` CLI is already installed on ubuntu-latest; cleaner syntax and better error handling. |

## Architecture Patterns

### System Architecture Diagram

```
mix lattice_stripe.check_drift
         |
         v
Mix.Tasks.LatticeStripe.CheckDrift
  [arg parsing, output, exit code]
         |
         v
LatticeStripe.Drift.run/1
         |
    _____|_____
   |           |
   v           v
fetch_spec/0  extract_known_fields/1
(Finch HTTP)  (source file parsing)
   |           |
   v           v
parse_schemas  {module -> [field]}
(Jason decode)    map
   |           |
   |___________|
         |
         v
compare_fields/2
  [additions, removals, new_resources]
         |
         v
DriftResult struct
  [per_module_diff, new_resources]
         |
         v
  [caller formats report]
```

### Recommended Project Structure

```
lib/
├── lattice_stripe/
│   ├── drift.ex              # Core logic: fetch, parse, compare, report
│   └── object_types.ex       # ADD: def object_map, do: @object_map (1-line change)
├── mix/tasks/
│   └── lattice_stripe.check_drift.ex   # Thin shell: args, output, exit code
.github/workflows/
└── drift.yml                 # Weekly cron + gh issue create/edit
test/
├── lattice_stripe/
│   └── drift_test.exs        # Unit tests with fixture spec snippets
└── support/fixtures/
    └── openapi_spec_fixture.ex   # Minimal spec JSON for tests
```

### Pattern 1: Accessing the ObjectTypes Registry at Mix Task Runtime

The `@object_map` attribute in `LatticeStripe.ObjectTypes` is not persisted at runtime (confirmed via `__info__(:attributes)` returning only `:vsn`). Add one public function:

```elixir
# Source: verified via `mix run -e` — __info__(:attributes) returns [:vsn] only
# In lib/lattice_stripe/object_types.ex — ADD this function:
def object_map, do: @object_map
```

This is the minimal-change approach: one line added to one file, no impact on existing callers.

### Pattern 2: Extracting @known_fields via Source File Parsing

Since `@known_fields` is a compile-time attribute not persisted in BEAM bytecode, parse the source file. The pattern is consistent across all 68 modules (confirmed by grep). Two forms exist:

```elixir
# Source: VERIFIED by grep across all 68 modules with @known_fields

# Form 1: multi-line (most modules)
# @known_fields ~w[
#   id object field_a field_b
#   field_c
# ]

# Form 2: single-line (smaller structs, confirmed examples)
# @known_fields ~w[enabled mode proration_behavior]

# Extraction approach:
defp extract_known_fields_from_source(module) do
  # Get source file path from module beam file location
  source_path = module.__info__(:compile)[:source]
  source = File.read!(source_path)

  # Regex handles both single-line and multi-line ~w[...] sigils
  case Regex.run(~r/@known_fields\s+~w\[([^\]]+)\]/s, source) do
    [_, fields_str] ->
      fields_str
      |> String.split(~r/\s+/, trim: true)
      |> MapSet.new()
    nil ->
      MapSet.new()
  end
end
```

**Key insight:** `module.__info__(:compile)[:source]` returns the compiled source path as a charlist — use `List.to_string/1` to convert. This is reliable as long as the source file is present (true in dev and CI). [VERIFIED: OTP documentation on `__info__/1`] [ASSUMED: source path is correct when Mix task runs from project root]

### Pattern 3: Identifying First-Class Stripe Resource Schemas

The Stripe OpenAPI spec has 1,359 schemas. To identify first-class resources (schemas that correspond to real Stripe objects), filter for schemas whose `properties.object` field has a single-element `enum`. This identifies exactly 168 schemas. [VERIFIED: live curl + python analysis of spec3.json]

```elixir
# Source: VERIFIED against live spec3.json
defp first_class_schemas(spec) do
  get_in(spec, ["components", "schemas"])
  |> Enum.filter(fn {_name, schema} ->
    case get_in(schema, ["properties", "object", "enum"]) do
      [_single_value] -> true
      _ -> false
    end
  end)
  |> Map.new(fn {name, schema} ->
    object_type = get_in(schema, ["properties", "object", "enum"]) |> List.first()
    {object_type, schema}
  end)
end
```

This produces a `%{"customer" => schema, "invoice" => schema, ...}` map keyed by object type string — matching the `ObjectTypes` registry keys exactly. [VERIFIED: spot-checked `checkout.session`, `billing_portal.configuration`, `test_helpers.test_clock`, `invoiceitem` — all match exactly]

### Pattern 4: GitHub Actions Issue Create/Update with Duplicate Prevention

```yaml
# Source: ASSUMED pattern — gh CLI usage in Actions
- name: Check for existing drift issue
  id: find-issue
  run: |
    ISSUE_NUMBER=$(gh issue list \
      --label "stripe-drift" \
      --state open \
      --json number \
      --jq '.[0].number // empty')
    echo "issue_number=$ISSUE_NUMBER" >> $GITHUB_OUTPUT
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Create or update drift issue
  run: |
    if [ -n "${{ steps.find-issue.outputs.issue_number }}" ]; then
      gh issue comment "${{ steps.find-issue.outputs.issue_number }}" \
        --body "$(cat drift_report.txt)"
    else
      gh issue create \
        --title "Stripe API drift detected — $(date +%Y-%m-%d)" \
        --body "$(cat drift_report.txt)" \
        --label "stripe-drift"
    fi
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Required workflow permissions: `issues: write`, `contents: read`.

### Pattern 5: Spec Caching in GitHub Actions

```yaml
# Weekly cache key — refreshes once per week (ISO week number)
- name: Cache OpenAPI spec
  uses: actions/cache@v3
  with:
    path: /tmp/stripe-spec3.json
    key: stripe-openapi-${{ env.WEEK_KEY }}
  env:
    WEEK_KEY: ${{ runner.os }}-${{ steps.date.outputs.year }}-W${{ steps.date.outputs.week }}
```

Alternative: daily key (`$(date +%Y-%m-%d)`) is fine for a weekly cron — the cache will always be fresh. Simpler approach. [ASSUMED: actions/cache behavior with weekly-refreshing keys]

### Pattern 6: Existing Mix Task Pattern (follow exactly)

The existing `Mix.Tasks.LatticeStripe.TestClock.Cleanup` demonstrates the established patterns. For drift detection task:

- Use `Mix.Task.run("app.start")` to ensure Finch and all modules are loaded
- Use `OptionParser.parse/2` with `strict:` for type safety
- Use `Mix.shell().info/1` for output (not `IO.puts`)
- Use `Mix.raise/1` for fatal errors
- Add `@shortdoc` for `mix help` listing
- Add `@impl Mix.Task` on `run/1`
- For non-zero exit: `System.halt(1)` (not `Mix.raise` — that prints a stacktrace)

```elixir
# Source: VERIFIED from lib/mix/tasks/lattice_stripe.test_clock.cleanup.ex
defmodule Mix.Tasks.LatticeStripe.CheckDrift do
  use Mix.Task

  @shortdoc "Check for Stripe API drift against @known_fields"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [format: :string])
    Mix.Task.run("app.start")

    case LatticeStripe.Drift.run(opts) do
      {:ok, %{drift_count: 0, new_resources: []}} ->
        Mix.shell().info("No drift detected. @known_fields are up to date.")

      {:ok, result} ->
        Mix.shell().info(LatticeStripe.Drift.format_report(result))
        System.halt(1)

      {:error, reason} ->
        Mix.raise("Drift check failed: #{inspect(reason)}")
    end
  end
end
```

### Anti-Patterns to Avoid

- **Using `Module.get_attribute/2` at runtime:** Only works inside `defmodule` at compile time. At runtime, `__info__(:attributes)` is the API, but it returns only `:vsn` for private attributes. Source parsing is the correct approach.
- **Fetching spec with `:httpc` without SSL config:** Raw `:httpc` over HTTPS requires explicit `cacerts` setup. Finch handles this automatically.
- **Using `Mix.raise/1` for the drift-found case:** `Mix.raise` prints a stacktrace. Use `System.halt(1)` for a clean non-zero exit.
- **Creating duplicate GitHub issues:** Without the label-based search + update logic, each weekly run creates a new issue. Use `gh issue list --label stripe-drift --state open` to check first.
- **Embedding the spec in the binary:** The spec is 7.6MB — never bundle it. Fetch at task runtime.
- **Comparing schema names (not object type values):** The spec schema name (key in `components.schemas`) is usually the same as the object type, but not always. Always use the `properties.object.enum[0]` value to match against the `ObjectTypes` registry.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing of 7.6MB spec | Custom parser | Jason | Jason is already a dep; handles large payloads; no size concern |
| HTTP over HTTPS | Custom SSL/TLS | Finch | Already a dep; handles connection pooling, TLS, redirects |
| Issue deduplication | Complex state tracking | `gh issue list --label` | Single CLI call; stateless; no external state required |
| Field type extraction | Parse OpenAPI `$ref` chains | Report field names only | Types live in nested `$ref` schemas; resolving them is complex; field names are sufficient for drift detection |

**Key insight:** The hardest part is the `@known_fields` access problem — don't try to persist module attributes or add a registry. Source file parsing with a focused regex is the correct, minimal-change solution.

## Runtime State Inventory

> SKIPPED — this is a greenfield additive phase. No renames, refactors, or migrations. No existing runtime state affected.

## Common Pitfalls

### Pitfall 1: @known_fields Not Available at Runtime

**What goes wrong:** Code calls `LatticeStripe.Customer.__info__(:attributes)[:known_fields]` expecting the field list, gets `nil`.

**Why it happens:** In Elixir/BEAM, `@module_attribute` values are only stored in the bytecode if explicitly persisted (via `Module.register_attribute/3` with `persist: true`) or used in macros. LatticeStripe's `@known_fields` is a private compile-time helper — not persisted.

**How to avoid:** Parse the source file. Use `module.__info__(:compile)[:source]` to find the source path, then regex-extract the `~w[...]` content. Handles both single-line and multi-line forms.

**Warning signs:** `nil` return from `__info__(:attributes)[key]` when you expect a list.

### Pitfall 2: Schema Name vs. Object Type Mismatch

**What goes wrong:** Matching spec schema names directly against `ObjectTypes` registry keys fails for some entries (e.g., if a schema is named differently than its object type string).

**Why it happens:** The spec schema key (e.g., `"invoice_item"`) may differ from the object type enum value (e.g., `"invoiceitem"`). [VERIFIED: `invoiceitem` schema has `object.enum = ["invoiceitem"]`]

**How to avoid:** Always use `properties.object.enum[0]` as the lookup key, not the schema name. Confirmed: all ObjectTypes registry keys match the `object.enum[0]` values.

**Warning signs:** Registered modules appearing as "unregistered" in the report.

### Pitfall 3: Source File Path Unavailable

**What goes wrong:** `module.__info__(:compile)[:source]` returns `nil` or a stale path in certain build environments.

**Why it happens:** `:compile` metadata is embedded at compile time. In some production deploys or release builds, source files are stripped. For a Mix task (always dev/CI context), this is not an issue — but code should handle `nil` gracefully.

**How to avoid:** Pattern match on `nil` and return `MapSet.new()` (empty set) — the module will appear with no known fields, surfacing all spec fields as drift. Add a `{:warning, :no_source}` to the result so the operator knows.

**Warning signs:** Mix task reporting all fields as drift for a module that clearly has `@known_fields`.

### Pitfall 4: GitHub Actions Issue Label Not Created

**What goes wrong:** `gh issue create --label "stripe-drift"` fails because the label doesn't exist in the repo.

**Why it happens:** GitHub labels must be created before they can be applied to issues via `gh`.

**How to avoid:** Add a workflow step that creates the label if it doesn't exist: `gh label create "stripe-drift" --color "#e4e669" --description "Stripe OpenAPI drift" --force`. The `--force` flag makes it idempotent.

**Warning signs:** `gh` CLI error: `label not found`.

### Pitfall 5: Spec Download Timeout in CI

**What goes wrong:** The 7.6MB spec download exceeds the HTTP timeout in CI.

**Why it happens:** The raw GitHub URL is generally fast, but network conditions vary.

**How to avoid:** Set a reasonable timeout (30s) on the Finch request. The Actions cache should handle this on most runs — the live download only happens on cache miss (once per week).

**Warning signs:** Task hangs or times out in CI but works locally.

## Code Examples

### Extracting First-Class Schemas from Spec

```elixir
# Source: VERIFIED against live spec3.json (2026-04-16)
# 168 first-class schemas identified via this pattern
defp resource_schemas(spec) do
  spec
  |> get_in(["components", "schemas"])
  |> Enum.reduce(%{}, fn {_schema_name, schema}, acc ->
    case get_in(schema, ["properties", "object", "enum"]) do
      [object_type] ->
        properties = schema |> get_in(["properties"]) |> Map.keys() |> MapSet.new()
        Map.put(acc, object_type, properties)
      _ ->
        acc
    end
  end)
  # Returns %{"customer" => MapSet.new(["id", "email", ...]), ...}
end
```

### Source File Parsing for @known_fields

```elixir
# Source: VERIFIED — pattern confirmed across all 68 modules with @known_fields
# Handles both ~w[single line] and ~w[\n  multi\n  line\n]
defp known_fields_for(module) do
  case module.__info__(:compile)[:source] do
    nil ->
      {:error, :no_source}

    charlist ->
      source = List.to_string(charlist)
      case File.read(source) do
        {:ok, content} ->
          fields =
            case Regex.run(~r/@known_fields\s+~w\[([^\]]+)\]/s, content) do
              [_, fields_str] ->
                fields_str
                |> String.split(~r/\s+/, trim: true)
                |> MapSet.new()
              nil ->
                MapSet.new()
            end
          {:ok, fields}

        {:error, reason} ->
          {:error, {:file_read, reason}}
      end
  end
end
```

### Core Comparison Logic

```elixir
# Source: [ASSUMED] based on D-04, D-05 decisions
defp compare(spec_fields, known_fields) do
  %{
    additions: MapSet.difference(spec_fields, known_fields),  # In spec, not in known
    removals: MapSet.difference(known_fields, spec_fields),   # In known, not in spec
  }
end
```

### GitHub Actions Drift Workflow Skeleton

```yaml
# Source: ASSUMED — based on existing ci.yml patterns + gh CLI docs
name: Stripe API Drift Check

on:
  schedule:
    - cron: '0 9 * * 1'  # Mondays 9am UTC
  workflow_dispatch:       # Allow manual trigger

permissions:
  contents: read
  issues: write

jobs:
  drift-check:
    name: Stripe API Drift Check
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.19'
          otp-version: '28'

      - name: Cache deps
        uses: actions/cache@v3
        with:
          path: deps
          key: ${{ runner.os }}-1.19-28-mix-${{ hashFiles('**/mix.lock') }}

      - name: Cache _build
        uses: actions/cache@v3
        with:
          path: _build
          key: ${{ runner.os }}-1.19-28-build-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Ensure drift issue label exists
        run: |
          gh label create "stripe-drift" \
            --color "#e4e669" \
            --description "Stripe OpenAPI spec fields not yet in @known_fields" \
            --force
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run drift check
        id: drift
        run: |
          mix lattice_stripe.check_drift > /tmp/drift_report.txt 2>&1
          echo "exit_code=$?" >> $GITHUB_OUTPUT

      - name: Create or update drift issue
        if: steps.drift.outputs.exit_code != '0'
        run: |
          EXISTING=$(gh issue list --label "stripe-drift" --state open \
            --json number --jq '.[0].number // empty')
          if [ -n "$EXISTING" ]; then
            gh issue comment "$EXISTING" --body "$(cat /tmp/drift_report.txt)"
          else
            gh issue create \
              --title "Stripe API drift detected — $(date +%Y-%m-%d)" \
              --body "$(cat /tmp/drift_report.txt)" \
              --label "stripe-drift"
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Real Drift Found (Invoice Module)

```
# Source: VERIFIED — live comparison against spec3.json (2026-04-16)
# Fields in spec NOT in LatticeStripe.Invoice @known_fields (additions = real drift):
amount_overpaid, automatically_finalizes_at, confirmation_secret,
customer_account, parent, payments, total_pretax_credit_amounts, total_taxes

# Fields in @known_fields NOT in spec (removals/renames):
application_fee_amount, charge, deleted, discount, paid, paid_out_of_band,
payment_intent, quote, rendering_options, subscription, subscription_details,
subscription_proration_date, tax, total_tax_amounts, transfer_data
```

This confirms drift detection will immediately surface real actionable findings on first run.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Stripe spec vendored locally | Fetch from `stripe/openapi` GitHub raw URL | D-01 decision | Always compares against latest published spec |
| ExVCR for HTTP mocking | Fixture spec snippets (JSON structs in test) | Established project convention | Tests don't need network; deterministic; no cassette maintenance |
| `gh pr create` for notifications | `gh issue create/edit` | D-03 decision | Issues don't pollute PR list; searchable; closeable when addressed |

**Deprecated/outdated:**
- Vendored OpenAPI snapshots: Defeats the purpose; creates stale baseline. D-01 explicitly prohibits this.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `module.__info__(:compile)[:source]` reliably returns source path in Mix task context | Code Examples | Would need fallback: enumerate `lib/` files and match by module name derived from path |
| A2 | `gh issue list --label stripe-drift --state open` returns 0 or 1 results (not multiple) | Code Examples | Multiple open drift issues would require different deduplication logic (take first, close others, etc.) |
| A3 | Weekly cron with `actions/cache` and date-based key gives acceptable freshness | Architecture Patterns | Daily key is always safe alternative if weekly proves too stale |
| A4 | `System.halt(1)` is the correct non-zero exit approach for Mix tasks (vs `Mix.raise`) | Architecture Patterns | `Mix.raise` produces stacktrace — `System.halt` is cleaner for CI gate use, but exits without cleanup |
| A5 | The `~w[...]` regex pattern covers all `@known_fields` variants in the codebase | Code Examples | Verified for single-line and multi-line forms; risk is new modules using a different form |

## Open Questions

1. **Field types in report (Claude's discretion)**
   - What we know: Spec has `type` and `$ref` for each field; `$ref` resolution is complex
   - What's unclear: Whether adding `(string)` / `(object)` annotations to the report is worth the implementation complexity
   - Recommendation: Include `type` for simple types (`string`, `integer`, `boolean`, `number`); show `(object)` for `$ref` fields without resolving the ref. This matches the example in D-02.

2. **Module structure (Claude's discretion)**
   - Recommendation: Two modules — `LatticeStripe.Drift` (pure business logic, testable) + `Mix.Tasks.LatticeStripe.CheckDrift` (thin shell). Single-file would be 300+ lines; separation improves testability and matches the existing cleanup task pattern where logic lives in `LatticeStripe.TestHelpers.TestClock`.

3. **Test strategy (Claude's discretion)**
   - Recommendation: Unit tests with fixture spec snippets (minimal JSON matching the spec structure) for `LatticeStripe.Drift`. No network calls in tests. Integration test (tagged `@tag :integration`) optionally fetches live spec to verify end-to-end — but not required for CI gate.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Finch | OpenAPI spec HTTP fetch | Yes (already in deps) | ~> 0.21 | :httpc with manual SSL |
| Jason | Spec JSON parsing | Yes (already in deps) | ~> 1.4 | — |
| gh CLI | GitHub Actions issue creation | Yes (ubuntu-latest includes it) | ~2.x | REST API via curl |
| actions/cache@v3 | Spec caching in CI | Yes | v3 (used in ci.yml) | Disable caching, fetch every run |
| erlef/setup-beam@v1 | Elixir environment in drift workflow | Yes (used in ci.yml) | v1 | — |

[VERIFIED: ci.yml uses all tooling above; gh CLI is available by default on ubuntu-latest GitHub Actions runners since 2021]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/drift_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-06 | `Drift.run/1` returns additions/removals/new_resources from fixture spec | unit | `mix test test/lattice_stripe/drift_test.exs -x` | No — Wave 0 |
| DX-06 | Report format matches D-02 specification (grouped by module, `+` prefix) | unit | `mix test test/lattice_stripe/drift_test.exs::format` | No — Wave 0 |
| DX-06 | Exit code 1 when drift found, 0 when clean | unit | `mix test test/lattice_stripe/drift_test.exs::exit_code` | No — Wave 0 |
| DX-06 | Source file parsing correctly extracts `@known_fields` from both single-line and multi-line forms | unit | `mix test test/lattice_stripe/drift_test.exs::parsing` | No — Wave 0 |
| DX-06 | New resources (in spec, not in registry) reported separately (informational) | unit | `mix test test/lattice_stripe/drift_test.exs::new_resources` | No — Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/drift_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/drift_test.exs` — unit tests for `LatticeStripe.Drift`
- [ ] `test/support/fixtures/openapi_spec_fixture.ex` — minimal fixture spec (customer + invoice schemas)

## Security Domain

> `security_enforcement` is absent from config — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Mix task; no user auth |
| V3 Session Management | no | Stateless tool |
| V4 Access Control | no | Dev/CI tooling only |
| V5 Input Validation | yes | Jason handles JSON parse errors; validate spec has expected structure before accessing |
| V6 Cryptography | no | No encryption needed |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed/adversarial spec JSON | Tampering | Jason decode with error handling; validate `components.schemas` key exists before traversal |
| GITHUB_TOKEN with excess permissions | Elevation of Privilege | Workflow permissions scoped to `issues: write, contents: read` only — no `contents: write` |
| Spec URL redirect/MITM | Spoofing | Finch uses system CA store; raw.githubusercontent.com uses verified TLS |

## Sources

### Primary (HIGH confidence)
- Live inspection of `spec3.json` via curl + python3 — schema structure, first-class resource count (168), schema name vs. object type mapping
- `lib/lattice_stripe/object_types.ex` — registry contents, function list (only `maybe_deserialize/1` exported)
- `lib/mix/tasks/lattice_stripe.test_clock.cleanup.ex` — established Mix task pattern
- `.github/workflows/ci.yml` — existing workflow structure (erlef/setup-beam, cache keys, concurrency)
- `mix run -e` live tests — confirmed `__info__(:attributes)` returns only `:vsn` for both Customer and ObjectTypes modules
- `grep -r "@known_fields"` — confirmed 68 files, 53 multi-line + single-line forms

### Secondary (MEDIUM confidence)
- [Stripe OpenAPI repo](https://github.com/stripe/openapi) — spec3.json URL confirmed accessible at raw.githubusercontent.com
- Existing test at `test/lattice_stripe/testing/test_clock_mix_task_test.exs` — Mix task test patterns

### Tertiary (LOW confidence)
- None — all critical claims verified from live codebase or spec.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all deps already in mix.exs, no new deps needed
- Architecture: HIGH — @known_fields access problem identified and solved; spec structure verified live
- Pitfalls: HIGH — confirmed via live testing (nil from `__info__`, real drift in invoice module)
- GitHub Actions workflow: MEDIUM — pattern is assumed from existing workflows; exact `gh` CLI flags may need minor adjustment

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable domain; spec URL and schema structure are stable)
