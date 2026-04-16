# Phase 30: Stripe API Drift Detection - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

CI automatically detects when Stripe's published OpenAPI specification adds new fields or resources that are not yet reflected in LatticeStripe's `@known_fields` — surfacing drift as a GitHub issue before it reaches users. A developer can also run the detection locally via `mix lattice_stripe.check_drift`.

This phase adds one Mix task, one GitHub Actions workflow (weekly cron), and supporting modules for OpenAPI spec parsing and field comparison. It does NOT modify existing resource modules, the request pipeline, or any runtime behavior.

</domain>

<decisions>
## Implementation Decisions

### OpenAPI Spec Sourcing
- **D-01:** Fetch the Stripe OpenAPI spec from `stripe/openapi` GitHub repo at runtime (raw JSON from `spec3.json`). No vendored snapshot — always compares against the latest published spec. The Mix task downloads on each run; CI caches the download with a short TTL.

  **Rationale:** The `stripe/openapi` repo is Stripe's canonical source. Vendoring creates a stale-by-default baseline that defeats the purpose of drift detection. A fresh fetch per run ensures we detect drift as soon as Stripe publishes.

### Drift Report Format
- **D-02:** The Mix task outputs a structured list grouped by module name, showing fields present in the OpenAPI spec but absent from `@known_fields`. Example:
  ```
  Drift detected in 3 modules:

  LatticeStripe.Customer (stripe object: "customer")
    + tax_exempt_override (string)
    + new_field_name (object)

  LatticeStripe.Invoice (stripe object: "invoice")
    + rendering (object)
  ```
  Exit code 1 when drift is found, 0 when clean. Machine-parseable for CI consumption.

### CI Notification Mechanism
- **D-03:** The GitHub Actions weekly cron opens a GitHub issue when drift is detected. Issue title includes a timestamp and count of drifted modules. Issue body contains the full drift report. If an open drift issue already exists, the workflow updates it (or adds a comment) rather than creating duplicates.

  **Rationale:** Issues are lower friction than draft PRs — they don't pollute the PR list, are searchable, and can be closed when addressed. The duplicate-prevention logic keeps the issue tracker clean.

### Field Matching Strategy
- **D-04:** Compare top-level `properties` keys from each OpenAPI schema definition against the corresponding module's `@known_fields`. Use the `LatticeStripe.ObjectTypes` registry (from Phase 22, D-01) to map Stripe object type names to LatticeStripe modules. Nested struct fields are NOT checked at the parent level — each nested struct module has its own `@known_fields` and is checked independently.

  **Rationale:** Matches the existing `@known_fields` pattern where each module only tracks its own top-level keys. The ObjectTypes registry already provides the Stripe-object-to-module mapping needed for enumeration.

- **D-05:** Fields present in `@known_fields` but absent from the OpenAPI spec are flagged as "removed/renamed" warnings (not errors) — Stripe rarely removes fields, but renames happen. This helps catch both additions and removals.

### New Resource Detection
- **D-06:** The Mix task also detects Stripe object types present in the OpenAPI spec that have no corresponding entry in the `ObjectTypes` registry. These are reported separately as "new resources not yet implemented." This is informational — not a CI failure condition (LatticeStripe intentionally does not cover all Stripe resources).

### Claude's Discretion
- Internal module structure (single module vs. separate parser/reporter modules)
- Whether to use `Req` or raw `:httpc` for the OpenAPI spec download (dev-only dependency consideration)
- Exact GitHub Actions workflow syntax and caching strategy
- Whether the drift report includes field types from the OpenAPI spec or just field names
- Test strategy (unit tests with fixture spec snippets vs. integration test against live spec)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Patterns
- `lib/mix/tasks/lattice_stripe.test_clock.cleanup.ex` — Existing Mix task pattern (flag parsing, Client setup, output formatting)
- `lib/lattice_stripe/customer.ex` — Example `@known_fields` usage and `Map.split/2` pattern
- `.github/workflows/ci.yml` — Existing CI workflow structure (setup-beam, caching, concurrency)

### External Specs
- Stripe OpenAPI spec: `https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json` — canonical source for field/resource comparison
- Phase 22 D-01: `ObjectTypes` registry maps Stripe object types to modules — essential for drift enumeration

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.ObjectTypes` (Phase 22): Registry mapping Stripe `"object"` strings to modules — provides the enumeration of all modules to check
- `lib/mix/tasks/lattice_stripe.test_clock.cleanup.ex`: Existing Mix task with flag parsing, `--dry-run`, client configuration — pattern to follow
- 68 modules with `@known_fields` module attribute: The baseline data that drift detection compares against

### Established Patterns
- `@known_fields ~w[...]` string sigil with `Map.split(map, @known_fields)` in `from_map/1` — consistent across all resource modules
- Mix task naming: `Mix.Tasks.LatticeStripe.<Name>` in `lib/mix/tasks/` directory
- CI: GitHub Actions with `erlef/setup-beam`, deps/build caching, `concurrency` groups

### Integration Points
- `ObjectTypes` registry: Enumerate all known modules and their Stripe object type strings
- Each module's `@known_fields`: Compile-time attribute accessible via `Module.get_attribute/2` at Mix task runtime (or extracted via code analysis)
- `.github/workflows/`: New `drift.yml` workflow alongside existing `ci.yml`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 30-stripe-api-drift-detection*
*Context gathered: 2026-04-16*
