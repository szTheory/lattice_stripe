# Phase 1: Transport & Client Configuration - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

HTTP abstraction layer, client struct, JSON codec, and basic error struct. Developers can create a configured client and make raw authenticated HTTP requests to Stripe's API. This phase delivers the foundation that every subsequent phase builds on.

Requirements: TRNS-01..05, CONF-01..05, JSON-01..02 (12 total)

</domain>

<decisions>
## Implementation Decisions

### Client API Surface
- **D-01:** Explicit client struct only. `LatticeStripe.Client.new!(api_key: "sk_test_...")` returns a validated struct. The library NEVER reads `Application.get_env`. Users wrap it however they want (e.g., their own `MyApp.Stripe.client/0` module that reads from app config). This follows the official Elixir Library Guidelines: "Leave as much control as possible to the consumer of your library."
- **D-02:** Provide both `new!/1` (raises on invalid config — standard for programmer errors) and `new/1` (returns `{:ok, client} | {:error, error}` — for runtime config from user input).
- **D-03:** Multiple independent clients can coexist in the same BEAM VM. No singleton, no global state.

### Request Interface
- **D-04:** Request struct pipeline pattern (inspired by ExAws). Resource modules build a `%LatticeStripe.Request{}` data struct describing the HTTP request, then `Client.request/2` dispatches it through the transport. Building and execution are cleanly separated.
- **D-05:** The `%Request{}` struct holds: method, path, params, opts. It is pure data with no side effects. This enables testing request building independently of HTTP dispatch.

### Finch Pool Management
- **D-06:** User manages the Finch pool. User adds `{Finch, name: MyApp.Finch}` to their supervision tree, then passes `finch: MyApp.Finch` to `Client.new!`. Library does not start processes — standard Elixir library convention.

### Transport Behaviour
- **D-07:** Single `request/1` callback receiving a plain map (`%{method, url, headers, body, opts}`), returning `{:ok, %{status, headers, body}} | {:error, term()}`. Narrowest possible behaviour — one function to implement, one to mock.
- **D-08:** Default adapter: `LatticeStripe.Transport.Finch`. Users can swap by implementing the behaviour and passing `transport: MyAdapter` to `Client.new!`.

### Error Boundaries (Phase 1 vs Phase 2)
- **D-09:** Phase 1 ships a basic `%LatticeStripe.Error{}` struct with fields: type (atom), code, message, status, request_id. Pattern-matchable from day one via the `:type` atom field (`:card_error`, `:invalid_request_error`, `:authentication_error`, `:rate_limit_error`, `:api_error`).
- **D-10:** Phase 2 enriches with: bang variants, retry logic, idempotency handling, richer error context, pluggable retry strategy. Phase 1 error struct is designed to be additive — Phase 2 adds fields, doesn't break.

### Form Encoding
- **D-11:** Custom form encoder (~40 lines of recursive Elixir code). Handles nested maps (`metadata[plan]=pro`), arrays (`items[0][price]=price_123`), and deeply nested params. No external dependency — every Stripe SDK does this internally.

### Response Decoding
- **D-12:** Typed structs with catch-all `extra` field for covered resources. Plain maps for un-typed nested objects. Structs provide dot access, pattern matching, and editor autocomplete. Unknown Stripe fields land in `.extra` so structs never break on API additions.
- **D-13:** In Phase 1, response decoding returns decoded JSON maps. Typed response structs for Customer, PaymentIntent, etc. are introduced in Phase 4 when resource modules are built. Phase 1 establishes the decoding pipeline and `extra` field pattern.

### Config Validation
- **D-14:** NimbleOptions validates all client options at creation time. Schema defines types, defaults, required fields, and doc strings. Auto-generates documentation for ExDoc. Catches typos and bad types immediately with clear error messages.

### JSON Codec
- **D-15:** JSON codec behaviour with Jason as default. Behaviour allows users to swap JSON library (e.g., future Elixir stdlib JSON module). Minimal interface: `encode!/1` and `decode!/1`.

### Telemetry Prep
- **D-16:** Wire `:telemetry.span/3` into `Client.request/2` from Phase 1. Emits `[:lattice_stripe, :request, :start/:stop/:exception]` events. Zero overhead when no handler is attached. Phase 8 documents events and adds metadata — no need to modify the core request path later.

### Module Structure
- **D-17:** Flat resource modules (`LatticeStripe.Customer`, not `LatticeStripe.Resources.Customer`). Nested only when Stripe nests (`LatticeStripe.Checkout.Session`). Behaviours in top-level files, adapters in sub-directories (`transport.ex` + `transport/finch.ex`).

### Test Strategy
- **D-18:** Phase 1 tests are Layer 1 (pure unit tests for encoder, config validation, error parsing) and Layer 2 (Mox-based transport mock tests for Client.request/2). All tests use `async: true`. Integration tests against stripe-mock come in Phase 9.

### Dependencies (mix.exs)
- **D-19:** Runtime: Finch ~> 0.19, Jason ~> 1.4, :telemetry ~> 1.0, NimbleOptions ~> 1.0, Plug ~> 1.16 (optional), Plug.Crypto ~> 2.0. Dev/test: Mox ~> 1.2, ExDoc ~> 0.34, Credo ~> 1.7. No Dialyxir.

### Claude's Discretion
- Exact User-Agent header string format
- Stripe API version string to pin (use current stable)
- Internal helper function organization within modules
- Exact NimbleOptions schema field ordering
- Error message wording
- Test fixture data shapes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — Core value, constraints, key decisions, design philosophy
- `.planning/REQUIREMENTS.md` — Full v1 requirements with traceability (Phase 1: TRNS-01..05, CONF-01..05, JSON-01..02)
- `.planning/ROADMAP.md` — Phase structure, dependencies, success criteria

### Research findings
- `.planning/research/STACK.md` — Technology recommendations with versions and rationale
- `.planning/research/ARCHITECTURE.md` — Component boundaries, data flow, build order
- `.planning/research/PITFALLS.md` — 14 domain-specific pitfalls with prevention strategies
- `.planning/research/FEATURES.md` — Feature landscape, table stakes vs differentiators
- `.planning/research/SUMMARY.md` — Synthesized research findings

### Background reference (not prescriptive — use for context)
- `prompts/` — Deep research documents on Stripe API, Elixir patterns, SDK comparisons

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — Phase 1 establishes the foundational patterns that all subsequent phases follow

### Integration Points
- Phase 2 (Error Handling & Retry) will wrap `Client.request/2` with retry logic and enrich the Error struct
- Phase 3 (Pagination) will use `Client.request/2` and the Response struct to build auto-pagination streams
- Phase 4 (Customers & PaymentIntents) will be the first resource modules using the Request struct pattern
- Phase 7 (Webhooks) depends on Plug.Crypto for HMAC verification
- Phase 8 (Telemetry) will document the events already wired in Phase 1

</code_context>

<specifics>
## Specific Ideas

- Client API should follow the pattern of Goth v1.4+ (Dashbit redesign) — explicit struct, no global state
- Request struct inspired by ExAws's operation struct pattern — pure data, separate execution
- Transport behaviour modeled after Finch's adapter pattern — single narrow callback
- Response structs with `extra` field catch-all — prevents breakage when Stripe adds fields (stripity_stripe's #1 issue category)
- Form encoder handles Stripe's nested param format (metadata[key]=value, items[0][price]=price_123)
- NimbleOptions for config validation — same as Finch, Broadway, and other Dashbit-maintained libraries

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-transport-client-configuration*
*Context gathered: 2026-03-31*
