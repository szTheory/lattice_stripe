# Phase 3: Pagination & Response - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

List pagination with auto-pagination streams, expand parameter support, raw response metadata access, and API version pinning. Developers can paginate through lists manually or via lazy Elixir Streams, expand nested objects, access response metadata (request_id, status, headers), and control API versioning per-client and per-request.

Requirements: PAGE-01..06, EXPD-01..05, VERS-01..03 (14 total)

</domain>

<decisions>
## Implementation Decisions

### Auto-Pagination Stream API
- **D-01:** Both layers: `LatticeStripe.List` module provides `stream!(client, req)` one-shot and `stream(list, client)` from-existing-list. Phase 4+ resource modules add sugar (e.g., `Customer.stream(client, opts)`). Matches ExAws `Stream.resource/3` pattern adapted for Stripe.
- **D-02:** Explicit client passing — List struct is pure data (no client reference for streaming). `stream(list, client)` takes client as second argument. Matches idiomatic Elixir (Ecto, ExAws, Finch, Tesla all pass context explicitly). Structs hold data, functions receive actors.
- **D-03:** `stream!` raises on any page fetch error (after retries exhausted). Matches ExAws `stream!`, all 4 official Stripe SDKs. No Elixir library emits `{:ok, item} | {:error, reason}` from streams — it breaks Stream/Enum composability. Retries already happened internally via `Client.request/2`.
- **D-04:** Streams emit individual items (flattened), not pages. Matches all official Stripe SDKs. Consumers use `Stream.filter`, `Stream.take`, `Enum.map` etc. naturally.
- **D-05:** No collect-all safety guard. Elixir developers use `Stream.take(N)` to limit. Document memory risk in `@doc`. Matches ExAws, Ecto (no guards). Node's `autoPagingToArray` guard exists for JavaScript-specific reasons.
- **D-06:** Auto-detect backward pagination from `ending_before` param presence. Same as all official SDKs.
- **D-07:** Named `stream!` / `stream` — Elixir convention (ExAws, Ecto, File all name stream-returning functions `stream`). Not `auto_paginate`.
- **D-08:** `stream(list, client)` re-emits first page items then fetches remaining. Matches Ruby/Python/Node behavior. Stream represents "all items matching this query."
- **D-09:** Exhausted lists (`has_more: false`) — `stream`/`stream!` emit existing items and halt. No extra API call. No error. Matches all SDKs.

### List Struct Design
- **D-10:** Single `%LatticeStripe.List{}` struct for both cursor-based (list endpoints) and page-based (search endpoints). Optional `next_page` field for search. `stream!` auto-detects pagination mode from response. Matches Ruby/Node (same type for both).
- **D-11:** Fields: `data`, `has_more`, `url`, `total_count`, `next_page`, `object`, `extra` (catch-all map). `object` included (all SDKs have it, useful for list vs search detection). `extra` follows Phase 1 D-12 forward-compat pattern.
- **D-12:** Internal `_params` and `_opts` fields (underscore-prefixed) on List struct. Set by `Client.request/2` when wrapping list responses. Carries original query params and request opts so `stream(list, client)` can reconstruct page requests with correct limit, expand, etc. Matches how Ruby stores `@filters`/`@opts`, Python stores `_retrieve_params`.
- **D-13:** List does NOT implement `Enumerable` protocol. `Enum.map(list, ...)` would mislead — looks like all items but is only page 1. Use `list.data` for this page, `List.stream!` for all pages. Prevents footgun. stripity_stripe agrees.
- **D-14:** Custom `Inspect` on List — shows item count + first item summary (id/object). Hides PII. Payment library safety consistent with Response Inspect. Follows Plug.Conn precedent.
- **D-15:** All in one file: `lib/lattice_stripe/list.ex` contains struct, stream!, stream, Inspect, helpers. ~200 lines is well within Elixir norms (Ecto.Repo is 600+). One concept, one file.

### Search Pagination
- **D-16:** Auto-detect search vs cursor pagination from `"object"` field in response JSON. `"list"` → cursor-based (`starting_after`), `"search_result"` → page-based (`next_page` token). Matches Ruby/Python/Node detection pattern.
- **D-17:** Eventual consistency documented on Phase 4+ search resource functions (`Customer.search/2` @doc), with a brief note in List `@moduledoc`. Prominent per-function warnings in Phase 4, general awareness in Phase 3.

### Response Struct
- **D-18:** `%LatticeStripe.Response{}` with fields: `data` (decoded JSON body — map or `%List{}`), `status` (HTTP status integer), `headers` (raw response header list), `request_id` (extracted convenience field). Implements `Access` behaviour so `resp["name"]` delegates to `resp.data["name"]` when data is a plain map.
- **D-19:** `Client.request/2` returns `{:ok, %Response{}}` on success. `Client.request!/2` returns `%Response{}` (same minus `{:ok, _}` wrapper). Matches Req.request! pattern. Preserves metadata access in bang mode.
- **D-20:** Response wraps List: `{:ok, %Response{data: %List{...}, status: 200, request_id: "req_abc"}}`. List field stays `data` matching Stripe's JSON field name. `resp.data.data` is rare in practice (streaming/resource modules handle most cases).
- **D-21:** Access on Response returns nil when `data` is a `%List{}` struct (not a plain map). Bracket access only meaningful for singular responses. List responses use `resp.data.has_more` etc. directly.
- **D-22:** `Response.get_header(resp, name)` returns `[binary()]` (list). Case-insensitive matching. Matches Req/Plug pattern. `request_id` already extracted as top-level convenience field for the most common case.
- **D-23:** Custom `Inspect` on Response — shows `id`/`object` from data (if present), `status`, `request_id`. Truncates PII. Hides header details (shows count). Follows Plug.Conn pattern. Payment library safety.
- **D-24:** No `String.Chars` on Response (no natural string form, no Elixir HTTP lib does this). No `Jason.Encoder` (prevents accidental PII serialization — matches Phase 2 D-04 security stance, all Stripe SDKs hide response from serialization).
- **D-25:** List detection in `Client.request/2`: check decoded JSON `"object"` field. `"list"` or `"search_result"` → wrap in `%List{}`. Anything else → plain map. Matches all official SDKs. Stripe guarantees `"object"` on every response.
- **D-26:** Phase 4+ resource modules return `{:ok, %Customer{}}` directly (clean typed struct). Client.request returns `{:ok, %Response{}}` with metadata. Two tiers: ergonomic sugar (resources) and power tool (Client). Telemetry covers request_id logging.

### Error Struct
- **D-27:** Error struct keeps current fields (no response headers added). `request_id` and `status` cover 99% of error debugging. Retry loop already consumes `Stripe-Should-Retry` and `Retry-After` internally. Adding headers is additive/non-breaking later if needed.

### Expand & Typed Structs
- **D-28:** Phase 3 passes expand params through, returns expanded objects as nested plain maps. Typed deserialization (type registry, struct decode, EXPD-02 typed structs) deferred to Phase 4 when resource modules exist. All official SDKs build types and expand together. Expand already works functionally in Phase 3.

### API Versioning
- **D-29:** `LatticeStripe.api_version/0` public function on top-level module. Single source of truth — Config defaults and Client struct reference it. Matches all official SDKs (Ruby `Stripe.api_version`, Python `stripe.API_VERSION`, Go `stripe.APIVersion`).
- **D-30:** User-Agent header enhanced to include OTP version: `LatticeStripe/0.1.0 elixir/1.17.3 otp/26.2`. New `X-Stripe-Client-User-Agent` JSON header with bindings_version, lang, platform, otp_version. Matches all official Stripe SDKs. Good ecosystem citizenship.

### Per-Request Options in Streaming
- **D-31:** All request opts (stripe_account, api_key, stripe_version, timeout, max_retries, expand) carry forward across page fetches. Idempotency key excluded (page fetches are GET, auto-generation only for POST). Matches all official SDKs.

### Testing Strategy
- **D-32:** Follow Phase 1/2 test layer pattern. Unit tests for Response/List struct logic (Access, get_header, Inspect, deserialization). Mox-based tests for Client.request Response wrapping, multi-page streaming, error mid-stream, search pagination, stream laziness (Mox expect counts enforce "no extra calls"). All `async: true`, zero-delay retry strategy.
- **D-33:** Existing Phase 1/2 tests updated in the same plan that introduces `%Response{}`. Pattern match updates: `{:ok, map}` → `{:ok, %Response{data: map}}`.
- **D-34:** Test helpers stay inline in test files for now (matches Phase 1/2). Extract to `test/support/` when Phase 4+ resource tests need shared builders.

### Claude's Discretion
- Internal `Stream.resource` implementation details (start/next/cleanup functions)
- Exact `from_json/1` deserialization logic for List struct
- Exact `Access` implementation details on Response
- Internal helper function organization within modules
- Test fixture data shapes and assertion style
- Exact `X-Stripe-Client-User-Agent` JSON field set
- API version string value (use current stable)
- Backward pagination cursor logic (use first item ID for `ending_before`)
- `extra` field population logic (Map.drop known keys)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — Core value, constraints, design philosophy, key decisions
- `.planning/REQUIREMENTS.md` — Full v1 requirements with traceability (Phase 3: PAGE-01..06, EXPD-01..05, VERS-01..03)
- `.planning/ROADMAP.md` — Phase structure, dependencies, success criteria

### Prior phase context (builds on these)
- `.planning/phases/01-transport-client-configuration/01-CONTEXT.md` — D-04/D-05 (Request struct pipeline), D-07 (Transport behaviour shape), D-12 (extra field pattern), D-13 (typed structs in Phase 4), D-17 (flat module structure), D-18 (test layers)
- `.planning/phases/02-error-handling-retry/02-CONTEXT.md` — D-14 (retry loop in Client.request), D-15 (Process.sleep for delays), D-24 (telemetry metadata), D-25 (telemetry only, no Logger), D-27 (non-JSON response handling), D-29 (test layers)

### Existing implementation (modify these)
- `lib/lattice_stripe/client.ex` — `request/2`, `request!/2`, header building, transport dispatch, retry loop, telemetry span. Phase 3 changes return type to `%Response{}`, adds list detection, adds `_params`/`_opts` to List, enhances User-Agent headers.
- `lib/lattice_stripe/config.ex` — NimbleOptions schema. Phase 3 makes `api_version` default reference `LatticeStripe.api_version/0`.
- `lib/lattice_stripe.ex` — Top-level module. Phase 3 adds `api_version/0` function.
- `lib/lattice_stripe/request.ex` — Request struct (unchanged, but important context for streaming)
- `lib/lattice_stripe/error.ex` — Error struct (unchanged in Phase 3)

### New files (create these)
- `lib/lattice_stripe/response.ex` — `%Response{}` struct, Access behaviour, get_header/2, custom Inspect
- `lib/lattice_stripe/list.ex` — `%List{}` struct, stream!/2, stream/2, from_json/1, custom Inspect

### Research findings
- `.planning/research/STACK.md` — Technology recommendations
- `.planning/research/ARCHITECTURE.md` — Component boundaries, data flow
- `.planning/research/PITFALLS.md` — Domain-specific pitfalls including pagination gotchas

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Client.request/2` — Already has retry loop, telemetry span, transport dispatch, header building, expand merging. Phase 3 wraps the return in `%Response{}` and adds list detection.
- `LatticeStripe.Client.build_headers/5` — Already builds User-Agent, auth, version, content-type, stripe-account, idempotency headers. Phase 3 enhances User-Agent and adds X-Stripe-Client-User-Agent.
- `LatticeStripe.Client.decode_response/4` — Already decodes JSON and extracts request_id. Phase 3 adds list detection (`"object"` field check) and wraps in Response/List.
- `LatticeStripe.Client.merge_expand/2` — Already handles expand param merging with indexed bracket notation. Reused in page fetches.
- `LatticeStripe.FormEncoder` — Already handles nested param encoding. Used for page request params.
- `LatticeStripe.MockTransport` (Mox) — Already set up for testing. Phase 3 uses ordered `expect` chains for multi-page sequences.
- Zero-delay test retry strategy — Already built in Phase 2 for fast retry verification. Reused for stream page fetch tests.

### Established Patterns
- Behaviour + default adapter: `Transport` → `Transport.Finch`, `Json` → `Json.Jason`, `RetryStrategy` → `RetryStrategy.Default`. List follows same pattern (module with functions, no behaviour needed).
- NimbleOptions `:atom` type for module fields. Config already validates all client options.
- `defexception` with custom `message/1` on Error. Custom Inspect on Response/List follows same "PII-safe for payment library" philosophy.
- Plain maps for behaviour inputs (Transport, RetryContext). Response/List are structs (richer contract than plain maps for public-facing types).
- `@version` module attribute from `mix.exs`. Phase 3 adds `@stripe_api_version` on top-level module.

### Integration Points
- Phase 4 (Customers & PaymentIntents): First resource modules consuming Response/List. `Customer.list` returns `{:ok, %Response{data: %List{}}}` internally, unwraps to `{:ok, %Customer{}}` for typed returns. `Customer.stream` wraps `List.stream!`. Type registry extends the `"object"` field detection.
- Phase 5-6 (more resources): Same pattern as Phase 4, using the foundation built here.
- Phase 8 (Telemetry): Documents telemetry events. Response metadata (request_id, attempts) already emitted.
- Phase 9 (Testing): Integration tests against stripe-mock exercise real pagination flows. Test helpers may be extracted to `test/support/`.
- Phase 10 (Documentation): Response, List, streaming, expand, versioning all need guides and examples.

</code_context>

<specifics>
## Specific Ideas

- List struct modeled after Ruby's `ListObject` — carries original params internally for seamless page fetching, but adapted to Elixir idiom (explicit client passing, no hidden object state)
- Response struct inspired by Req.Response — struct with status/headers/body, Access behaviour for bracket syntax convenience
- Stream implementation follows ExAws's `Stream.resource/3` pattern — the proven Elixir approach for lazy HTTP pagination
- Custom Inspect on both Response and List follows Plug.Conn precedent — security-first for a payment library, truncate PII, show enough to debug
- `X-Stripe-Client-User-Agent` header matches all official Stripe SDKs — good ecosystem citizenship, helps Stripe support debug SDK-specific issues
- Two-tier return type (Response for Client, typed structs for resources) separates "power tool" from "ergonomic sugar" — developers choose their level
- `object` field as type discriminator for list detection matches all official SDKs and naturally extends to Phase 4 resource type registry

</specifics>

<deferred>
## Deferred Ideas

- **Typed deserialization for expanded objects** — EXPD-02 typed structs deferred to Phase 4 when resource modules exist. Expand works functionally with plain maps in Phase 3.
- **Delete response handling** — Stripe returns `{"deleted": true}` on deletes. Whether to use separate `DeletedCustomer` struct or `deleted` field on `Customer` is a Phase 4 resource module decision.
- **Response headers on Error struct** — Could add full headers to Error. Deferred because request_id + status cover 99% of use cases. Additive/non-breaking to add later.

</deferred>

---

*Phase: 03-pagination-response*
*Context gathered: 2026-04-02*
