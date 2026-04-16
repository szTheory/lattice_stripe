# Phase 28: meter_event_stream v2 - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers who need high-throughput metering can send batches of meter events via Stripe's v2 session-token API. This phase adds `LatticeStripe.Billing.MeterEventStream` with a two-step API: create a short-lived session (token + expiry), then send event batches within it.

This phase adds one new module (`Billing.MeterEventStream`) and possibly a session struct. It does NOT modify Client, Request, Transport, Error, or any existing resource modules. The v2 session-token auth model is self-contained within the new module — the existing `Client.request/2` pipeline is not reused for event sending (different auth scheme), though `Client` is still passed for configuration (transport, base_url, json_codec, telemetry).

</domain>

<decisions>
## Implementation Decisions

### Session Lifecycle Management

- **D-01:** Stateless session management — no GenServer, no process state. `create_session/2` returns a `%MeterEventStream.Session{}` struct with `token` and `expires_at` fields. Callers hold the session struct and pass it to `send_events/3`. Consistent with LatticeStripe's pure-functional, no-global-state philosophy (PROJECT.md: "processes only when truly needed").

### Transport / Auth Integration

- **D-02:** Reuse the existing `Transport` behaviour for HTTP. The `Transport.request/1` contract is auth-agnostic — it sends HTTP requests with whatever headers are provided. `MeterEventStream` builds its own v2-specific headers (session token auth instead of Bearer API key) and calls through `client.transport.request/1` directly. No new transport behaviour or module needed.

- **D-03:** The v2 base URL may differ from v1 (`https://meter-events.stripe.com/v2/billing/meter_event_stream` or similar). Research phase must confirm the exact endpoint URL and base. The module should construct the full URL independently of `client.base_url` if the v2 endpoint has a different host.

### API Surface

- **D-04:** Two public functions — explicit two-step API matching the Stripe v2 contract:
  1. `MeterEventStream.create_session(client, opts \\ [])` — creates a session, returns `{:ok, %Session{}}` or `{:error, Error.t()}`
  2. `MeterEventStream.send_events(client, session, events, opts \\ [])` — sends a batch of events within an active session, returns `{:ok, results}` or `{:error, :session_expired}` / `{:error, Error.t()}`

  No higher-level auto-session wrapper. Callers manage session reuse explicitly. This is more Elixir-idiomatic (no hidden state) and aligns with how stripe-python/ruby expose this endpoint.

- **D-05:** Session struct: `%MeterEventStream.Session{token: String.t(), expires_at: DateTime.t() | integer(), authentication_token: String.t()}` — fields based on what Stripe's session creation endpoint returns. Research phase must confirm exact response shape.

### Error Handling

- **D-06:** Client-side expiry check before sending — `send_events/3` checks `session.expires_at` against current time and returns `{:error, :session_expired}` immediately if expired (saves network round-trip). If the server returns a session-expired error anyway (clock skew), normalize to the same `{:error, :session_expired}` atom. No automatic session renewal.

- **D-07:** Events validation — `send_events/3` validates that events list is non-empty. Each event should have the same shape as `MeterEvent.create/3` params (`event_name`, `payload`, optional `timestamp`, optional `identifier`).

### Telemetry

- **D-08:** Emit telemetry events for both session creation and event sending:
  - `[:lattice_stripe, :meter_event_stream, :create_session, :start/:stop/:exception]`
  - `[:lattice_stripe, :meter_event_stream, :send_events, :start/:stop/:exception]`
  These are distinct from the standard `[:lattice_stripe, :request, *]` events because the v2 pipeline is separate from `Client.request/2`.

### Testing Strategy

- **D-09:** Research phase must probe stripe-mock for v2 endpoint support (`/v2/billing/meter_event_stream`). If supported: full integration tests via stripe-mock. If not supported: unit tests via Mox (mock Transport behaviour for session create + event send), integration test file with `@tag :skip` and a clear "stripe-mock does not support v2 endpoints" comment. Do not block the phase on stripe-mock v2 support.

### Claude's Discretion

- Internal module organization (whether Session struct lives in a nested module or inline)
- Exact telemetry metadata fields
- Whether to include a convenience `with_session/3` function that creates a session, calls a user function, and handles expiry (only if it doesn't add complexity — can be deferred)
- Documentation structure within `@doc` and whether to create a `guides/meter-event-stream.md` or fold into existing `guides/metering.md`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Metering Implementation
- `lib/lattice_stripe/billing/meter_event.ex` — v1 single-event create endpoint; reference for param validation, Inspect masking, `@doc` patterns
- `lib/lattice_stripe/billing/meter.ex` — Meter CRUDL; reference for Billing module conventions
- `lib/lattice_stripe/billing/guards.ex` — Billing-specific param guards (value_settings trap)

### Request Pipeline
- `lib/lattice_stripe/client.ex` — `Client.request/2` pipeline; v2 module builds its own headers but reuses `client.transport`
- `lib/lattice_stripe/transport.ex` — Transport behaviour contract; v2 calls go through same `request/1` callback

### Prior Phase Patterns
- `lib/lattice_stripe/batch.ex` — Batch module; reference for concurrent request patterns and error isolation
- `guides/metering.md` — Existing metering guide; v2 stream docs may extend or cross-link

### Stripe v2 API (Research Required)
- Stripe docs for `/v2/billing/meter_event_stream` — exact endpoint URL, session creation payload, event batch format, auth header scheme, expiry semantics. **Research phase must fetch and document these.**

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Transport` behaviour: auth-agnostic HTTP contract — reusable for v2 calls with different headers
- `Billing.MeterEvent`: v1 event struct and Inspect implementation — reference for v2 event shape
- `Resource` module helpers: `unwrap_singular/2`, `require_param!/3` — may be reusable for session creation
- `Error` struct: existing error normalization — v2 errors should normalize to same `%Error{}` type
- `Batch` module: concurrent request patterns — prior art for multi-request coordination

### Established Patterns
- `from_map/1` + `@known_fields` + `extra` for struct deserialization
- `Inspect` protocol implementation for PII-safe logging (MeterEvent masks payload)
- Resource modules follow `create/3`, `retrieve/3`, `list/3` naming conventions
- `@doc` with ## Params, ## Opts, ## Example sections

### Integration Points
- New module at `lib/lattice_stripe/billing/meter_event_stream.ex`
- Nested struct at `lib/lattice_stripe/billing/meter_event_stream/session.ex` (Claude's discretion)
- Tests at `test/lattice_stripe/billing/meter_event_stream_test.exs`
- Guide addition or cross-link in `guides/metering.md`
- ExDoc group: fits in existing "Billing" or "Billing Metering" group

</code_context>

<specifics>
## Specific Ideas

- The v2 API uses a different authentication scheme (session token vs Bearer API key) — this is the core architectural novelty of the phase
- Session tokens are short-lived (Stripe docs will specify exact TTL — likely 5-15 minutes)
- The create-session endpoint likely uses the standard v1 Bearer auth; it's the send-events endpoint that uses the session token
- STATE.md explicitly flags: "needs research during planning to confirm stripe-mock v2 endpoint support"
- FEAT-02 requirement text: "create session, send events, handle expiry"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 28-meter-event-stream-v2*
*Context gathered: 2026-04-16*
