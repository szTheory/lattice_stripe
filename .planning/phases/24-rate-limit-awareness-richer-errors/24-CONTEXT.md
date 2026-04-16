# Phase 24: Rate-Limit Awareness & Richer Errors - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers can observe Stripe rate-limit state via telemetry and receive actionable error messages that suggest the correct parameter name when they pass an invalid one. Two features: (1) `Stripe-Rate-Limited-Reason` header captured in telemetry stop event metadata on 429s, (2) fuzzy "Did you mean?" param suggestions appended to `invalid_request_error` messages.

This phase touches the telemetry pipeline (header threading + metadata enrichment), the Error module (message enrichment), and telemetry docs/guide. It does NOT add new struct fields to Error, Response, or Client, and does NOT change the request pipeline shape.

</domain>

<decisions>
## Implementation Decisions

### Rate-Limit Telemetry

- **D-01:** Thread raw response headers into telemetry via the `request_span` closure. The `fun` closure returned to `request_span` returns `{result, attempts, last_resp_headers}` instead of `{result, attempts}`. `build_stop_metadata` gains a `resp_headers` parameter and extracts `Stripe-Rate-Limited-Reason` (case-insensitive header lookup, same pattern as `parse_stripe_should_retry`). The telemetry stop event metadata includes `:rate_limited_reason` — a `String.t() | nil` key, nil when absent or non-429. This is purely additive and non-breaking per `:telemetry` conventions.

  **Why not attach to Error/Response structs:** The requirement is specifically about telemetry metadata exposure. Adding rate-limit fields to core structs would couple Stripe header knowledge into general-purpose types and expand the public API surface unnecessarily. The data is already available — `%Response{headers: ...}` on success, 3-tuple `resp_headers` on error — it just needs to reach `build_stop_metadata`.

### Fuzzy Param Source

- **D-02:** Use existing `@known_fields` from each resource module as the candidate list for fuzzy matching, filtered by a small `@response_only_fields` exclusion set (`~w[id object created livemode url]`). This leverages the field lists already maintained on all 84+ modules with zero new data to maintain.

  **Algorithm:** `String.jaro_distance/2` (Elixir stdlib since 1.5, well within 1.15+ floor). Threshold of 0.8 for match acceptance, minimum param length of 4 characters to avoid noisy short-name matches. Same algorithm Elixir's compiler uses for its own "did you mean?" suggestions in `UndefinedFunctionError`.

  **Scope:** Top-level param names only (not nested `card[number]` paths). The `Error.param` field from Stripe often uses bracket notation for nested params — extract the leaf key for matching (e.g., `"card[nubmer]"` → match `"number"` against Card's `@known_fields`).

  **Evolution path:** When Phase 30 (drift detection) lands proper per-operation param lists derived from Stripe's OpenAPI spec, the fuzzy matching can upgrade to precise per-resource param validation. The `@known_fields` proxy is good enough today with minimal false positives after exclusion filtering.

### Error Enrichment

- **D-03:** Append the "Did you mean?" suggestion to the `:message` string in `Error.from_response/3`. No new fields on the Error struct. A private `maybe_suggest_param/2` helper computes the Jaro-distance match and returns the suggestion suffix (or empty string). The suggestion is appended after Stripe's original message: `"No such parameter: payment_method_type; Did you mean :payment_method_types?"`.

  **Why message-append only:** The success criteria explicitly require the suggestion to appear in the `%Error{}` message and to not change any existing struct fields. Message-append satisfies both. The suggestion appears automatically in logs, `raise`, and `IO.inspect` with zero caller changes. This matches how Stripe's own API surfaces suggestions server-side and how Elixir's compiler formats `UndefinedFunctionError`.

  **Guard:** Only attempt fuzzy matching when `error.type` is `:invalid_request_error` and `error.param` is non-nil. All other error types pass through unchanged.

  **Param resolution:** The fuzzy matcher needs to know which resource module's `@known_fields` to search. Use the request path to determine the resource (same `parse_resource_and_operation` logic already in `Telemetry`), then look up the module via `ObjectTypes`. If no module match or no close param found, skip suggestion silently — never degrade the original error message.

### Telemetry Documentation & Default Logger

- **D-04:** Escalate 429 responses to `:warning` level in the default logger. Append `(rate_limited: {reason})` to the log line only when `:rate_limited_reason` is present in metadata. Non-429 responses keep existing format unchanged. Add `:rate_limited_reason` row to the stop-event metadata tables in both `Telemetry` moduledoc and `guides/telemetry.md`. Add a concise "Rate Limiting" subsection in the guide with: (a) the new metadata key explanation, (b) a `Telemetry.Metrics.counter` example tagged by `:rate_limited_reason`, (c) a custom handler recipe filtering `metadata[:rate_limited_reason]` for rate-limit-specific alerting.

  **Why warning level:** Rate limiting is an operational concern. The existing telemetry guide already shows warning-level 429 examples in its documentation — the code should match. Oban uses the same pattern (warning for throttled jobs). Teams that expect bulk 429s can configure their logger to filter.

### Claude's Discretion

- Whether to extract the fuzzy matching logic into a dedicated `LatticeStripe.ParamSuggestion` module or keep it as private functions in `Error`
- Exact contents of `@response_only_fields` exclusion set (start with `~w[id object created livemode url]`, researcher should verify completeness)
- Whether to also capture `Retry-After` header value in telemetry metadata (optional enrichment beyond the requirement)
- Test structure: unit tests for Jaro matching + integration tests for end-to-end error enrichment
- Exact wording of the "Did you mean?" suffix format
- Whether the rate-limit guide subsection goes under "Custom Telemetry Handlers" or as a top-level section

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Error & Telemetry Pipeline
- `lib/lattice_stripe/error.ex` — `Error.from_response/3` where suggestion enrichment happens; `parse_type/1` for error type atoms; `message/1` callback for formatting
- `lib/lattice_stripe/telemetry.ex` — `request_span/4` where headers must be threaded; `build_stop_metadata/4` where `:rate_limited_reason` is extracted; `handle_default_log/4` where warning escalation for 429s is added
- `lib/lattice_stripe/client.ex` — `do_request_with_retries/5` where `{result, attempts}` becomes `{result, attempts, resp_headers}`; `do_request/2` where the 3-tuple `{:error, error, resp_headers}` is already returned; `parse_stripe_should_retry/1` as pattern for case-insensitive header extraction

### Resource Field Lists
- `lib/lattice_stripe/customer.ex` — Reference `@known_fields` list (representative of the pattern across all 84+ modules)
- `lib/lattice_stripe/object_types.ex` — Registry for mapping resource names to modules (needed for D-03 param resolution)

### Telemetry Documentation
- `lib/lattice_stripe/telemetry.ex` `@moduledoc` — Stop-event metadata table that needs `:rate_limited_reason` row
- `guides/telemetry.md` — Guide that needs "Rate Limiting" subsection and updated metadata table
- `lib/lattice_stripe/response.ex` — `%Response{headers: resp_headers}` field (already carries headers on success path)

### Existing Patterns
- `lib/lattice_stripe/client.ex:557-568` — `parse_stripe_should_retry/1` as pattern for case-insensitive header extraction
- `lib/lattice_stripe/telemetry.ex:534-543` — `parse_resource_and_operation/2` for resource name extraction from path (reusable for D-03 param resolution)

### Project Constraints
- `.planning/PROJECT.md` — Core value, design philosophy, no-Dialyzer constraint
- `.planning/REQUIREMENTS.md` — PERF-05 (rate-limit telemetry), DX-01 (fuzzy param suggestions)
- `guides/api_stability.md` — Semver contract; these changes are additive (minor bump)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`parse_stripe_should_retry/1`** in Client — exact pattern for case-insensitive header extraction; copy for `Stripe-Rate-Limited-Reason`
- **`parse_resource_and_operation/2`** in Telemetry — extracts resource name from URL path; reusable for determining which module's `@known_fields` to search
- **`ObjectTypes.@object_map`** — maps resource type strings to modules; can be used to resolve which module's `@known_fields` to consult for param suggestions
- **`String.jaro_distance/2`** — Elixir stdlib; no dependency needed

### Established Patterns
- **Telemetry stop metadata** — `Map.merge(start_meta, %{...})` pattern; new keys are additive
- **`@known_fields ~w[...]`** — present on every resource module; ready to use as param candidate list
- **3-tuple error return** — `{:error, %Error{}, resp_headers}` internal to Client; headers already preserved for retry logic
- **Private helper pattern** — `defp atomize_status/1` style private helpers in modules; same pattern for `defp maybe_suggest_param/2`

### Integration Points
- **`request_span/4` closure** — return shape changes from `{result, attempts}` to `{result, attempts, resp_headers}`
- **`build_stop_metadata/4`** — gains `resp_headers` parameter, extracts `:rate_limited_reason`
- **`Error.from_response/3`** — gains `maybe_suggest_param/2` call for message enrichment
- **`handle_default_log/4`** — gains 429 warning escalation + rate-limit reason suffix
- **`guides/telemetry.md`** — new "Rate Limiting" subsection
- **Telemetry `@moduledoc`** — new row in stop-event metadata table

</code_context>

<specifics>
## Specific Ideas

- The fuzzy suggestion format should feel like Elixir's own compiler messages: `"; did you mean :payment_method_types?"` — lowercase "did", semicolon separator, atom-prefixed param name
- The `@response_only_fields` exclusion should be a module attribute on whatever module owns the suggestion logic, not scattered across resource modules
- The rate-limit warning log should include the reason string as-is from Stripe (e.g., `"too_many_requests"`) — don't atomize it in telemetry metadata to avoid atom table growth from unexpected values
- All 4 features are coherent: Error struct untouched (no new fields), telemetry contract purely additive (new optional key), fuzzy matching uses stdlib only, changes scoped to error/response path per v1.2 R2

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 24-rate-limit-awareness-richer-errors*
*Context gathered: 2026-04-16*
