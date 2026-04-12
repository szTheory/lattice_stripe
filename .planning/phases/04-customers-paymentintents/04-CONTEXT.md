# Phase 4: Customers & PaymentIntents - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Mode:** Auto-selected (all recommended defaults)

<domain>
## Phase Boundary

First two resource modules (Customer, PaymentIntent) validating the resource module pattern for the entire SDK. Developers can CRUD customers, CRUD+confirm+capture+cancel payment intents, list with pagination, and search customers. This phase establishes the resource module conventions that Phases 5-6 will follow identically.

Requirements: CUST-01..06, PINT-01..07 (13 total)

</domain>

<decisions>
## Implementation Decisions

### Resource Module Pattern
- **D-01:** Hand-written modules with shared private helpers — no macro DSL, no `__using__` base module. Each resource module (`LatticeStripe.Customer`, `LatticeStripe.PaymentIntent`) is a standalone module with explicit functions. Shared code extracted to a private helper module only when duplication is obvious after both modules exist. Matches Elixir ecosystem norm (Ecto schemas are hand-written, not macro-generated). Establishes a clear, copyable pattern for Phases 5-6.
- **D-02:** Each public function builds a `%Request{}` struct, calls `Client.request/2`, and unwraps the `%Response{}` into a typed struct. Pattern: `build_request → Client.request → unwrap_response`. Follows Phase 1 D-04/D-05 (Request struct pipeline).
- **D-03:** Public API convention: `create/2`, `retrieve/2`, `update/3`, `delete/2`, `list/2`, plus resource-specific actions (`confirm/2`, `capture/2`, `cancel/2` on PaymentIntent). All take `(client, params_or_id)` or `(client, id, params)`. Bang variants (`create!/2` etc.) layered on top.
- **D-04:** All functions accept `opts` keyword in params for per-request overrides (stripe_account, idempotency_key, expand, etc.). Threaded into `%Request{opts: opts}`. Consistent with Phase 1 D-04.

### Typed Struct Design
- **D-05:** Plain `defstruct` with `from_map/1` constructor that maps JSON response keys to struct fields. No Ecto schema, no changeset, no validation on response data. Stripe's API is the source of truth — we just parse what they send. Known fields get struct keys, unknown fields go to `extra` map (Phase 1 D-12 pattern).
- **D-06:** Top-level struct only — expanded nested objects remain plain maps. `customer.address` is a map, not `%Address{}`. Type registry and deep deserialization can be added later as resources grow. Matches Phase 3 D-28 (typed expand deferred to when resource modules exist — now we exist, but start simple and add depth incrementally).
- **D-07:** Struct fields mirror Stripe's JSON field names using snake_case atoms. `payment_method_types`, `client_secret`, `latest_charge`, etc. No renaming, no transformation — what Stripe sends is what developers access.
- **D-08:** Custom `Inspect` on resource structs — show `id`, `object`, and 2-3 key fields. Hide PII (email, name, card details). Consistent with Phase 3 D-14/D-23 (Response/List PII-safe Inspect).
- **D-09:** No `Jason.Encoder` on resource structs — consistent with Phase 2 D-04 and Phase 3 D-24 (security-first, no accidental serialization of payment data).

### Delete Response Handling
- **D-10:** `Customer.delete/2` returns `{:ok, %Customer{deleted: true}}`. The `deleted` boolean field exists on the Customer struct (default `false`). Matches Stripe's JSON shape (`{"id": "cus_...", "object": "customer", "deleted": true}`). Single struct type, no separate `DeletedCustomer`. Ruby, Python, and Node all do this.
- **D-11:** PaymentIntent has no delete endpoint (Stripe doesn't support it). Only cancel.

### Search API Ergonomics
- **D-12:** `Customer.search/3` takes `(client, query, opts)` where `query` is the Stripe search query string. Returns `{:ok, %Response{data: %List{}}}` using Phase 3's search_result auto-detection. The List struct's `next_page` field carries the page token.
- **D-13:** `Customer.search_stream!/3` convenience function wraps `List.stream!` for search results. Handles page-token-based pagination transparently. Matches the `Customer.stream!/2` pattern for cursor-based list pagination.

### Return Type Convention
- **D-14:** Two tiers as decided in Phase 3 D-26. Resource modules return `{:ok, %Customer{}}` / `{:ok, %PaymentIntent{}}`. Under the hood, `Client.request/2` returns `%Response{}` — resource functions unwrap `response.data` and pass through `from_map/1`. Metadata (request_id, headers) available via `Client.request/2` directly for power users.
- **D-15:** List operations (`Customer.list/2`) return `{:ok, %Response{data: %List{}}}` — the List struct contains typed data items. Individual items in `list.data` are `%Customer{}` structs (deserialized via `from_map/1`). Stream operations yield individual typed structs.

### Testing Strategy
- **D-16:** Follow Phase 1/2/3 test pattern. Mox-based unit tests for each resource function. Test request building (correct method, path, params) and response unwrapping (JSON map → typed struct). Use `LatticeStripe.MockTransport` for transport mocking.
- **D-17:** Test helpers for building Stripe-like response JSON inline in test files. If duplication emerges between Customer and PaymentIntent tests, extract to `test/support/fixtures.ex`. Follows Phase 3 D-34 (extract when needed).
- **D-18:** Document eventual consistency for `Customer.search/3` in `@doc` as decided in Phase 3 D-17.

### Claude's Discretion
- Internal `from_map/1` implementation details (which fields to extract, default values)
- Exact struct field lists for Customer and PaymentIntent (follow Stripe's API reference)
- Helper function organization within modules
- Test fixture data shapes
- How to handle optional/nilable fields on structs
- Whether to extract shared request-building helpers after both modules exist
- Exact `@moduledoc` and `@doc` content and examples

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — Core value, constraints, design philosophy, key decisions
- `.planning/REQUIREMENTS.md` — Full v1 requirements with traceability (Phase 4: CUST-01..06, PINT-01..07)
- `.planning/ROADMAP.md` — Phase structure, dependencies, success criteria

### Prior phase context (builds on these)
- `.planning/phases/01-transport-client-configuration/01-CONTEXT.md` — D-04/D-05 (Request struct pipeline), D-12 (extra field pattern), D-13 (typed structs), D-17 (flat module structure)
- `.planning/phases/02-error-handling-retry/02-CONTEXT.md` — D-04 (no Jason.Encoder security stance), D-14 (retry in Client.request)
- `.planning/phases/03-pagination-response/03-CONTEXT.md` — D-01..09 (stream API), D-10..17 (List struct, search pagination), D-18..26 (Response struct, return types), D-28 (typed expand deferred to Phase 4)

### Existing implementation (modify/extend these)
- `lib/lattice_stripe/client.ex` — `request/2`, `request!/2` — resource modules call these
- `lib/lattice_stripe/request.ex` — `%Request{}` struct resource modules build
- `lib/lattice_stripe/response.ex` — `%Response{}` returned by Client, unwrapped by resources
- `lib/lattice_stripe/list.ex` — `%List{}` with `stream!/2`, `stream/2` — resource stream functions wrap these
- `lib/lattice_stripe/config.ex` — Client configuration schema
- `lib/lattice_stripe/error.ex` — Error struct for `{:error, %Error{}}` returns

### New files (create these)
- `lib/lattice_stripe/customer.ex` — `%Customer{}` struct + CRUD/list/search/stream functions
- `lib/lattice_stripe/payment_intent.ex` — `%PaymentIntent{}` struct + CRUD/confirm/capture/cancel/list/stream functions
- `test/lattice_stripe/customer_test.exs` — Customer resource tests
- `test/lattice_stripe/payment_intent_test.exs` — PaymentIntent resource tests

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Client.request/2` — Full request pipeline (retry, telemetry, transport dispatch). Resource modules call this with `%Request{}` structs.
- `LatticeStripe.Client.request!/2` — Bang variant. Resource bang functions can delegate to this.
- `LatticeStripe.List.stream!/2` and `stream/2` — Auto-pagination. Resource stream functions wrap these with typed item deserialization.
- `LatticeStripe.List.from_json/3` — List deserialization. Resource list responses already auto-detected by Client.
- `LatticeStripe.FormEncoder` — Nested param encoding for POST bodies (create/update operations).
- `LatticeStripe.Response` — Access behaviour for bracket syntax on singular responses.

### Established Patterns
- Request struct pipeline: build `%Request{}` → `Client.request/2` → get `%Response{}` (Phase 1 D-04)
- PII-safe custom `Inspect` on all public structs (Phase 3 D-14/D-23)
- No `Jason.Encoder` on any struct (Phase 2 D-04, Phase 3 D-24)
- `extra` map catch-all for unknown fields (Phase 1 D-12)
- `{:ok, result} | {:error, %Error{}}` everywhere, bang variants layered on top
- NimbleOptions for config validation, no validation on response data
- Mox-based testing with `LatticeStripe.MockTransport`

### Integration Points
- Phase 5-6 (SetupIntents, PaymentMethods, Refunds, Checkout): Will copy the resource module pattern established here
- Phase 7 (Webhooks): Event parsing may reference Customer/PaymentIntent types
- Phase 9 (Testing): Integration tests with stripe-mock will exercise these resources
- Phase 10 (Documentation): Resource module guides and examples

</code_context>

<specifics>
## Specific Ideas

- Customer is the simpler resource (CRUD + list + search) — build it first to establish the pattern, then PaymentIntent adds action verbs (confirm, capture, cancel)
- PaymentIntent is the most important Stripe resource for SaaS apps — it must feel ergonomic and well-documented
- The `from_map/1` pattern should be simple enough that adding a new resource in Phase 5 is mostly copy-paste-adapt
- Search API has eventual consistency — document prominently in `@doc` so developers don't build real-time features on search

</specifics>

<deferred>
## Deferred Ideas

- **Deep typed deserialization** — Nested objects (address, charges, payment_method) as typed structs. Start with plain maps, add depth incrementally as the type registry grows.
- **Type registry / object-to-module mapping** — A central `%{"customer" => Customer, "payment_intent" => PaymentIntent}` registry for automatic deserialization. May emerge naturally as more resources are added in Phases 5-6.
- **Shared resource macro/DSL** — If Phases 4-6 show extreme duplication, consider a `use LatticeStripe.Resource` macro. But premature abstraction is worse than some copy-paste.
- **Nested resource helpers** — e.g., `Customer.list_payment_methods/2`. Stripe has nested endpoints but they can also be accessed via top-level resources. Defer to Phase 5+.

</deferred>

---

*Phase: 04-customers-paymentintents*
*Context gathered: 2026-04-02*
