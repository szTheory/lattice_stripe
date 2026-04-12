# Phase 8: Telemetry & Observability - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure all Stripe API interactions emit standard `:telemetry` events for monitoring and observability. Create a centralized `LatticeStripe.Telemetry` module that owns all event emission, provides a default logger, and documents the full event catalog. Refactor existing inline telemetry code in Client into this module. Add webhook verification telemetry.

</domain>

<decisions>
## Implementation Decisions

### Event Coverage Scope
- **D-01:** Emit telemetry for HTTP requests (existing) AND webhook signature verification (new). No pagination-aggregate events — each page is already an HTTP request with full telemetry.
- **D-02:** Webhook verification uses `[:lattice_stripe, :webhook, :verify, :start/stop/exception]` span. Captures result (`:ok`/`:error`), error_reason (`:invalid_signature`, `:stale_timestamp`, etc.).

### Metadata Completeness
- **D-03:** Add `resource` (e.g. `"customer"`, `"payment_intent"`) and `operation` (e.g. `"create"`, `"retrieve"`, `"list"`) to start+stop metadata. Low cardinality, enables per-operation dashboards.
- **D-04:** Add `api_version` and `stripe_account` (Connect header) to start+stop metadata. Structural, not secret.
- **D-05:** Parse `resource` and `operation` from URL path at the telemetry layer — zero changes to resource modules. E.g., `POST /v1/customers` → resource: `"customer"`, operation: `"create"`; `GET /v1/customers/:id` → resource: `"customer"`, operation: `"retrieve"`.

### Consumer Documentation
- **D-06:** Create `LatticeStripe.Telemetry` module with full event catalog in `@moduledoc` — every event name, measurements, metadata fields with types and descriptions.
- **D-07:** Include copy-paste `Telemetry.Metrics` definitions in `@moduledoc` for Prometheus/StatsD (summary for duration, counter for requests, distribution for latency by resource/operation).
- **D-08:** Ship `attach_default_logger/1` public function for opt-in instant visibility (Oban pattern). Structured one-liner format: `[info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123)`. Configurable log level.

### Telemetry Architecture
- **D-09:** Centralized helpers in `LatticeStripe.Telemetry` — event names as module attributes, private helper functions (`request_span/3`, `webhook_verify_span/3`, etc.). Single source of truth for event schemas.
- **D-10:** Extract and refactor all existing telemetry logic from `Client` into `Telemetry` module. Client calls `Telemetry.request_span(client, req, fun)`. Telemetry module handles the `telemetry_enabled` check, metadata construction, path extraction, stop metadata building.

### Webhook Telemetry
- **D-11:** Webhook verification uses `:telemetry.span/3` (not standalone `:telemetry.execute/3`) for consistency with request telemetry. Same attach pattern, same exception handling for consumers.

### Test Depth
- **D-12:** Full metadata contract tests — assert every metadata key, type, and value for every event type. Treat telemetry schema as public API. ~25-30 test cases covering: start metadata fields, stop metadata fields (success + error variants), exception metadata, retry event metadata, webhook verify metadata, default logger output, telemetry_enabled toggle.

### Claude's Discretion
- Path parsing logic for resource/operation derivation (regex patterns, edge cases for nested resources like checkout/sessions)
- Default logger handler ID naming convention
- Internal helper function signatures and module organization
- Telemetry.Metrics example specifics (which metric types for which events)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Implementation
- `lib/lattice_stripe/client.ex` — Current telemetry inline implementation (lines 190-218 span, 561-617 helpers). Must be extracted and refactored.
- `lib/lattice_stripe/config.ex` — `telemetry_enabled` option definition (line 85)
- `lib/lattice_stripe/webhook.ex` — Webhook verification module where verify span will be added
- `test/lattice_stripe/client_test.exs` — Existing telemetry tests (lines 431-484, 846-947) to be expanded

### Elixir Ecosystem Patterns
- `deps/finch/lib/finch/telemetry.ex` — Finch's centralized telemetry module pattern (private helpers, event docs)
- Oban.Telemetry (`hexdocs.pm/oban/Oban.Telemetry.html`) — Best-in-class event catalog docs + `attach_default_logger/1`
- Phoenix.Logger — Default logger handler pattern

### Requirements
- `.planning/REQUIREMENTS.md` §Telemetry — TLMT-01, TLMT-02, TLMT-03

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `:telemetry.span/3` already used in `Client.request/2` — established pattern to follow for webhook verify span
- `extract_path/1` helper in Client — will move to Telemetry module, reusable for resource/operation parsing
- `telemetry_stop_metadata/3` three-clause pattern match — well-structured, move as-is to Telemetry

### Established Patterns
- `:telemetry` is a required runtime dependency (already in `mix.exs`)
- `telemetry_enabled` boolean toggle on client struct controls emission
- Event prefix `[:lattice_stripe, :request, ...]` already established
- Per-retry standalone event `[:lattice_stripe, :request, :retry]` already exists
- Metadata uses atoms for status (`:ok`, `:error`), integers for `http_status`, strings for `request_id`

### Integration Points
- `Client.request/2` — will call `Telemetry.request_span/4` instead of inline `:telemetry.span`
- `Client.emit_retry_telemetry/6` — will move to `Telemetry.emit_retry/5`
- `Webhook.construct_event/4` — will be wrapped in `Telemetry.webhook_verify_span/3`
- `Webhook.Plug.call/2` — may call webhook verify span if verification happens at Plug level

</code_context>

<specifics>
## Specific Ideas

- Default logger format: `[info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123)` — structured one-liner, greppable
- Resource parsing examples: `/v1/customers` → `"customer"`, `/v1/payment_intents` → `"payment_intent"`, `/v1/checkout/sessions` → `"checkout.session"`
- Operation parsing: POST without ID → `"create"`, GET with ID → `"retrieve"`, GET without ID → `"list"`, POST with ID → `"update"`, DELETE → `"delete"`, POST with action suffix (e.g., `/confirm`) → `"confirm"`
- Webhook verify metadata should include `path` from Plug (which endpoint was hit) when available

</specifics>

<deferred>
## Deferred Ideas

- Pagination aggregate telemetry (`[:lattice_stripe, :pagination, :stop]` with page_count/total_items) — add later if users request it
- JSON decode sub-timing event — not needed unless decode becomes a bottleneck
- Grafana dashboard JSON template — aspirational, could be added in Phase 10 docs

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-telemetry-observability*
*Context gathered: 2026-04-03*
