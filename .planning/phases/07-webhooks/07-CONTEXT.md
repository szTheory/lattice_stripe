# Phase 7: Webhooks - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 delivers secure webhook event reception and verification for Stripe webhooks, plus the Event API resource. This includes:

- Signature verification with timing-safe HMAC-SHA256 comparison
- Event struct with typed top-level fields and raw maps for nested data
- Phoenix Plug with optional handler behaviour for dispatch
- Raw body extraction solution (CacheBodyReader + fallback)
- Event as a first-class API resource (retrieve, list, stream)
- Test helper for generating valid webhook signatures
- Inline documentation for all modules

This phase does NOT include telemetry events (Phase 8), integration tests against stripe-mock (Phase 9), or documentation guides (Phase 10).

</domain>

<decisions>
## Implementation Decisions

### Module Structure
- **D-01:** Split by concern: `LatticeStripe.Webhook` (pure verification functions), `LatticeStripe.Event` (top-level resource struct like Customer/PaymentIntent), `LatticeStripe.Webhook.Plug` (Phoenix Plug), `LatticeStripe.Webhook.Handler` (behaviour for Plug dispatch). Matches every official Stripe SDK's separation of Webhook from Event.
- **D-02:** Event is a top-level resource module — not nested under Webhook — because it's also a Stripe API resource (`GET /v1/events/:id`, `GET /v1/events`). `LatticeStripe.Event.retrieve(client, "evt_123")` works like `Customer.retrieve`.

### Event Struct Design
- **D-03:** Fully typed top-level fields: id, type, data, request, account, api_version, created, livemode, pending_webhooks, object (default "event"), extra (catch-all `%{}`). Follows established resource pattern with `@known_fields` + `from_map/1` + `Map.drop` for extra.
- **D-04:** `data` field is a raw decoded map — `%{"object" => %{...}, "previous_attributes" => %{...}}`. NOT parsed into typed structs because `data.object` varies by event type (Customer, PaymentIntent, Invoice, etc.) and may be a type LatticeStripe doesn't model yet.
- **D-05:** `request` field is a raw decoded map or nil — `%{"id" => "req_...", "idempotency_key" => "..."}`. No nested struct.
- **D-06:** `from_map/1` is infallible — missing fields become nil, unknown fields go to `extra`. Follows existing resource pattern. No validation in from_map.

### Event Inspect
- **D-07:** Manual `defimpl Inspect` whitelist showing: id, type, object, created, livemode. Hides: data (contains full PII objects), request (has idempotency key), account, extra. Follows existing Customer/PaymentIntent pattern with `#LatticeStripe.Event<...>` format.

### Event API Resource
- **D-08:** Event ships with retrieve/2, retrieve!/2, list/2, list!/2, stream/2, stream!/2 in Phase 7. Read-only (no create/update/delete). Follows standard resource pattern. List params support Stripe's event filters: type, created, delivery_success.

### Event Type Constants
- **D-09:** Event types remain as raw strings ("payment_intent.succeeded"). No constants module, no atom conversion. 250+ types that change per API version — constants would be maintenance burden. String pattern matching with `<>` operator works well for wildcards (`"invoice." <> _`).

### Plug Integration
- **D-10:** Webhook.Plug operates in two modes controlled by the optional `handler:` option. Without handler: verifies signature, parses Event, assigns to `conn.assigns.stripe_event`, passes through (user's controller responds). With handler: additionally dispatches to a Handler behaviour callback, returns 200/400 based on handler return, halts.
- **D-11:** Handler behaviour contract: `@callback handle_event(Event.t()) :: :ok | {:ok, term} | :error | {:error, term}`. Pure Elixir types — no Plug.Conn references in callbacks.

### Plug Response Behavior
- **D-12:** Verify-gate pattern. Bad signature → 400 + halt. No handler → assign event + pass through. Handler `{:ok, _}` or `:ok` → 200 + halt. Handler `{:error, _}` or `:error` → 400 + halt. Handler exception → re-raise (bubbles to Plug/Phoenix error handler). Invalid handler returns → raise RuntimeError with clear message listing expected returns.
- **D-13:** Non-POST requests to the webhook path return 405 Method Not Allowed with `Allow: POST` header + halt. Technically correct per HTTP spec, more informative than a generic 400.

### Plug Configuration
- **D-14:** NimbleOptions validation in `init/1`. Schema: secret (required, string or list of strings or MFA tuple or function), handler (optional, atom), at (optional, string), tolerance (optional, pos_integer, default 300).
- **D-15:** Optional `at:` path matching. When provided, Plug matches the path and passes through non-matching requests (endpoint-level mounting). When omitted, Plug processes every request (router-level mounting via `forward`). Uses stripity_stripe's same-variable pattern match trick.
- **D-16:** Assigns key is `:stripe_event` — namespaced to avoid collision with user assigns.

### Raw Body Strategy
- **D-17:** Ship `LatticeStripe.Webhook.CacheBodyReader` module (~15 lines). Stashes raw body in `conn.private[:raw_body]`. Plug checks `conn.private[:raw_body]` first; if not present, falls back to `Plug.Conn.read_body/2` directly. This supports both mounting strategies: endpoint-level (before Plug.Parsers, direct read) and router-level (CacheBodyReader configured in Plug.Parsers, Plug reads from private).

### Multi-Secret Support
- **D-18:** `construct_event` and Plug accept `String.t() | [String.t(), ...]` for secrets. Guard-based normalization: single string → `[string]`, then iterate. Tries each secret, returns first match. HMAC is microsecond-cheap. Covers Stripe Connect (two endpoints, two secrets) and rotation overlap. Follows Ecto's `Repo.preload` pattern for "one or many" inputs. Named `@type secret :: String.t() | [String.t(), ...]`.

### MFA Secret Resolution
- **D-19:** Plug accepts `{Module, :function, [args]}` tuples and zero-arity functions for runtime secret resolution. Resolved in `call/2` (runtime), not `init/1` (compile time). Solves Docker/K8s env var problem where secrets aren't available at compile time. MFA can return a string or list of strings.

### Tolerance Configuration
- **D-20:** Configurable in both `construct_event/4` keyword opts and Plug init options. Default 300 seconds everywhere. Independent call sites — Plug passes its configured tolerance to `construct_event`. NimbleOptions validates as `:pos_integer`.

### Verification Errors
- **D-21:** Specific atoms for each failure case: `:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`. Follows Plug.Crypto/Phoenix.Token convention (`{:error, :expired}`, `{:error, :invalid}`). Translates Go SDK's sentinel pattern to Elixir idiom. `@type verify_error` documents all cases in typespec.

### Bang Variants & Exception
- **D-22:** Ship `construct_event!/3`, `construct_event!/4`, `verify_signature!/3`, `verify_signature!/4`. Raise `LatticeStripe.Webhook.SignatureVerificationError` with `:message` (human-readable) and `:reason` (the atom from verify_error). Follows D-02/D-09 bang convention + Ruby/Node pattern of dedicated webhook exception type.

### Public API Surface
- **D-23:** Five public functions in `LatticeStripe.Webhook`:
  - `construct_event(payload, sig_header, secret, opts \\ [])` → `{:ok, Event.t()} | {:error, verify_error()}`
  - `construct_event!(payload, sig_header, secret, opts \\ [])` → `Event.t()` (raises)
  - `verify_signature(payload, sig_header, secret, opts \\ [])` → `{:ok, integer()} | {:error, verify_error()}`
  - `verify_signature!(payload, sig_header, secret, opts \\ [])` → `integer()` (raises)
  - `generate_test_signature(payload, secret, opts \\ [])` → `String.t()`
  - Opts: `[tolerance: pos_integer()]` for verify/construct, `[timestamp: integer()]` for generate_test_signature.

### Compile Guards
- **D-24:** Only `Webhook.Plug` and `Webhook.CacheBodyReader` wrapped in `if Code.ensure_loaded?(Plug)`. They import `Plug.Conn`. All other modules compile unconditionally: Webhook (uses `Plug.Crypto` from required `plug_crypto` dep), Event (pure struct), Handler (pure behaviour, no Plug types), SignatureVerificationError (pure exception). Matches stripity_stripe + Tesla + Guardian patterns.

### Dependencies
- **D-25:** `{:plug_crypto, "~> 2.0"}` as required dep (for `Plug.Crypto.secure_compare/2`). `{:plug, "~> 1.16", optional: true}` for Webhook.Plug and CacheBodyReader. CI validates with `mix compile --no-optional-deps --warnings-as-errors`.

### Logging & Telemetry
- **D-26:** No Logger calls in webhook code. No telemetry events in Phase 7. Phase 8 adds `[:lattice_stripe, :webhook, :verify, :start/:stop/:exception]` events. Libraries should not log directly — users control logging via error returns and telemetry handlers.

### Documentation
- **D-27:** Ship `@moduledoc` and `@doc` with every module in Phase 7. Webhook.Plug @moduledoc covers both mounting strategies and the raw body problem. Follows existing pattern — all LatticeStripe modules already have inline docs.

### Testing
- **D-28:** Two test files. `webhook_test.exs`: pure crypto tests for construct_event, verify_signature, generate_test_signature with known payloads/secrets. `webhook/plug_test.exs`: Plug integration tests using `Plug.Test.conn/3` + `generate_test_signature`, testing both handler and no-handler modes, 200/400/405 responses. All async: true.

### Claude's Discretion
- Internal HMAC implementation details (how to parse the `t=...v1=...` header format)
- Exact NimbleOptions schema structure for Plug init
- File organization within `lib/lattice_stripe/webhook/`
- Test fixture organization and helper module structure
- SignatureVerificationError `defexception` field details beyond :message and :reason

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Webhooks — WHBK-01 through WHBK-05

### Existing Patterns (follow these)
- `lib/lattice_stripe/resource.ex` — Resource helper pattern (unwrap_singular, unwrap_list, unwrap_bang!)
- `lib/lattice_stripe/customer.ex` — Reference resource implementation (struct, from_map, @known_fields, Inspect, CRUD, stream)
- `lib/lattice_stripe/payment_intent.ex` — Resource with lifecycle actions (confirm, capture, cancel pattern)
- `lib/lattice_stripe/config.ex` — NimbleOptions validation pattern for Plug.init/1

### Prior Phase Context
- `.planning/phases/01-transport-client-configuration/01-CONTEXT.md` — D-12 (typed structs with extra), D-14 (NimbleOptions), D-16 (telemetry span), D-17 (flat module naming), D-19 (deps including plug/plug_crypto)

### External References
- [Stripe Webhook Signature Verification](https://docs.stripe.com/webhooks/signatures) — HMAC-SHA256, v1 scheme, header format
- [Stripe Event Object](https://docs.stripe.com/api/events/object) — 11 top-level fields
- [Stripe Webhook Best Practices](https://docs.stripe.com/webhooks/best-practices) — return 2xx fast, process async
- [Plug.Parsers body_reader option](https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader) — CacheBodyReader pattern
- [Plug.Crypto.secure_compare/2](https://hexdocs.pm/plug_crypto/Plug.Crypto.html#secure_compare/2) — timing-safe comparison

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Resource` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` for Event retrieve/list/stream
- `LatticeStripe.Client` — `request/2` for Event API calls (retrieve, list)
- `LatticeStripe.List` — List struct with pagination for Event.list responses
- `LatticeStripe.Config` — NimbleOptions pattern to replicate for Plug.init/1
- `@known_fields` + `from_map/1` + `extra` — established pattern across all resource modules

### Established Patterns
- Flat module naming: `LatticeStripe.Event` not `LatticeStripe.Webhooks.Event`
- `defimpl Inspect` with field whitelist — Customer, PaymentIntent, SetupIntent all do this
- Bang variants via `Resource.unwrap_bang!/1` — apply to Event retrieve/list
- `async: true` on all tests — Mox allows concurrency

### Integration Points
- `LatticeStripe.Client` — Event.retrieve/list/stream need client for API calls
- `LatticeStripe.Response` — Event list responses wrap in Response struct
- `LatticeStripe.Error` — Event API errors (not webhook verification errors) use existing Error struct
- `mix.exs` — Add `{:plug_crypto, "~> 2.0"}` required + `{:plug, "~> 1.16", optional: true}`

</code_context>

<specifics>
## Specific Ideas

- Multi-secret support (`String.t() | [String.t()]`) is a DX improvement over every official Stripe SDK and stripity_stripe — none accept multiple secrets
- MFA/function secret resolution follows stripity_stripe and Phoenix conventions for runtime config
- 405 Method Not Allowed (not 400) for non-POST requests — technically correct per HTTP spec
- Verification error atoms (`:missing_header`, etc.) follow Plug.Crypto/Phoenix.Token convention — a deliberate improvement over stripity_stripe's string errors
- `generate_test_signature/2` ships with the feature, not deferred to Phase 9 — every official SDK provides this

</specifics>

<deferred>
## Deferred Ideas

- Webhook telemetry events (`[:lattice_stripe, :webhook, :verify, :start/:stop/:exception]`) — Phase 8
- Integration tests against stripe-mock — Phase 9
- `LatticeStripe.Testing` module with webhook event factory helpers — Phase 9
- Documentation guides (Webhooks guide, handler patterns, mounting strategy guide) — Phase 10
- Auto-parsing `data.object` into typed structs based on event type — future enhancement if users request it
- Event type constants/atoms module — explicitly rejected, but could revisit if users request compile-time safety

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-webhooks*
*Context gathered: 2026-04-03*
