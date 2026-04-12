# Project Research Summary

**Project:** LatticeStripe (Elixir Stripe SDK)
**Domain:** Elixir API client library / open-source Hex package
**Researched:** 2026-03-31
**Confidence:** HIGH

## Executive Summary

LatticeStripe is an Elixir Stripe SDK built to fill a genuine gap in the ecosystem: the incumbent library (`stripity_stripe`) targets a six-year-old Stripe API version, lacks automatic retry, has no auto-pagination Streams, and has a widely-reported webhook raw-body bug. The research is unambiguous about how to build this well: a pure-functional layered architecture, explicit client structs (no global config), behaviour-based extension points for transport and retry, and deep polish on a curated set of resources rather than shallow breadth. The stack is settled — Finch for HTTP, Jason for JSON, Telemetry for observability, Plug/Plug.Crypto for webhooks, Mox for testing — all well-established dependencies with minimal footprint.

The recommended build order flows strictly from dependencies: foundation (config, request encoding, error types, transport, retry, pagination) must precede all resource modules, and the foundation layer's design decisions — client struct shape, error hierarchy, response decoder tolerance, idempotency handling — are architectural and cannot be easily changed later. Resources then build in a pattern-establishing sequence: Customers first (simplest), PaymentIntents second (most complex lifecycle), then SetupIntents, PaymentMethods, Refunds, and Checkout Sessions. Webhooks are largely independent and can be parallelized.

The top risks are all in the foundation layer: using `==` for HMAC signature comparison (timing attack), using `Application.get_env` as primary config (breaks multi-tenancy and test isolation), retrying with new idempotency keys after ambiguous failures (double charges), and defining rigid structs without a catch-all for unknown Stripe fields (breaks on every Stripe API change). These are fully preventable with known mitigations and must be correct from day one — retrofitting is a breaking change or a security vulnerability.

## Key Findings

### Recommended Stack

The stack is lean by design. Finch is the right default HTTP transport for an SDK because it gives low-level control over connection pooling, timeouts, and request lifecycle without the high-level behaviors (retry, redirect, decompression) that Req adds on top — behaviors that would conflict with Stripe-specific semantics. The Transport behaviour abstracts Finch behind a one-function callback, so users can substitute any HTTP client. Jason is uncontested for JSON. NimbleOptions is worth the dependency for config validation and auto-generated docs. The CI matrix should cover Elixir 1.15/OTP 26, 1.17/OTP 27, and 1.19/OTP 28.

**Core technologies:**
- **Finch ~> 0.21**: default HTTP transport — Mint-based, connection pooling, correct level of control for an SDK
- **Jason ~> 1.4**: JSON codec — undisputed Elixir standard; wrap behind a JSON behaviour for future swap
- **:telemetry ~> 1.0**: observability — ecosystem standard, lets users plug in any monitoring stack
- **Plug ~> 1.16 + Plug.Crypto ~> 2.0**: webhook handling — Plug for the endpoint, Plug.Crypto for timing-safe HMAC comparison
- **NimbleOptions ~> 1.0**: config validation — 200 lines, battle-tested, auto-generates option docs
- **Mox ~> 1.2** (test): behaviour-based mocking — enforces Transport/RetryStrategy contracts, `async: true` safe
- **stripe-mock** (CI infrastructure): official Docker image, validates against Stripe's actual OpenAPI spec

**Do not use:** Req (high-level HTTP conflicts with SDK retry/error semantics), HTTPoison/Hackney (legacy, memory issues), Dialyzer (explicitly excluded), global `Application.get_env` as primary config, GenServer for client state, ExVCR/cassettes.

### Expected Features

Research identified a clear critical path. The foundation layer is a single cohesive unit — all components must be built together before any resource module is usable. Within the feature set, auto-pagination via Streams and comprehensive webhook support are the top community pain points that represent the clearest differentiation opportunity.

**Must have (table stakes):**
- HTTP transport with pluggable adapter — baseline for any API client
- Client configuration struct with per-request overrides — multi-tenancy and Connect support
- Structured, pattern-matchable error hierarchy — Elixir's pattern matching must work on errors
- Automatic retries with exponential backoff respecting `Stripe-Should-Retry` — all modern SDKs do this
- Idempotency key auto-generation and replay on retry — safety against double charges
- `{:ok, result} | {:error, reason}` returns with bang variants — non-negotiable Elixir convention
- Cursor-based pagination (manual) and auto-pagination via `Stream.resource/3` — auto-pagination is a top community request
- Webhook signature verification with Phoenix Plug and correct raw body handling — #1 Elixir community pain point
- Full Tier 1 resource coverage: Customers, PaymentIntents, SetupIntents, PaymentMethods, Refunds, Checkout Sessions

**Should have (competitive differentiators):**
- Telemetry events for request lifecycle — no existing Elixir Stripe lib does this well
- Search pagination support (page/next_page model, distinct from cursor pagination) — stripity_stripe lacks entirely
- Expand support as first-class concept with union types for id-vs-expanded-object
- Pattern-matchable domain types with atom-based status/type fields (`:succeeded`, `:requires_action`)
- Pluggable RetryStrategy behaviour for custom backoff/circuit breaking
- Test helpers: fixture factories, mock webhook event construction
- Stripe-Account header as first-class on every request (Connect support)
- Detailed error context: request_id, HTTP status, full error body on every error struct
- Up-to-date API version (2026-03-25.dahlia vs. stripity_stripe's 2019-12-03)

**Defer (v2+):**
- Billing resources (subscriptions, invoices, products, prices) — large surface, separate milestone
- Connect resources (accounts, transfers, payouts) — different user persona
- v2 API support (thin events, evolving semantics) — still changing
- Code generation from OpenAPI — consider after handwritten library proves architecture
- Higher-level billing layer with Ecto — separate package
- Tax, Identity, Treasury, Issuing, Terminal — specialist domains

### Architecture Approach

LatticeStripe follows a layered pure-functional-core architecture: Public API (resource modules) -> Client (orchestration) -> Transport (I/O boundary) -> Codec/Middleware (Request, Response, Error, Pagination, Retry) -> Cross-cutting concerns (Telemetry, Webhook). All layers below Transport are pure functions. The Client is a plain struct passed as the first argument to every API call — never a GenServer, never global state. The Transport and RetryStrategy are behaviours for extension and testability. Resource modules are hand-written, flat (not URL-path-mirrored), one module per Stripe resource.

**Major components:**
1. **LatticeStripe.Client** — config struct + request lifecycle orchestration; holds api_key, base_url, transport, json_codec, retry settings, api_version
2. **LatticeStripe.Transport (behaviour) + Transport.Finch** — HTTP I/O boundary; decouples SDK from HTTP client; test seam via Mox
3. **LatticeStripe.Request / Response / Error** — pure data structs; Request is built by resource modules, Response decodes JSON, Error carries full Stripe error hierarchy
4. **LatticeStripe.Pagination** — cursor + search pagination; `Stream.resource/3` for lazy auto-pagination
5. **LatticeStripe.Retry** — pure retry decision logic; reads `Stripe-Should-Retry` header, exponential backoff with jitter
6. **LatticeStripe.Telemetry** — emits `[:lattice_stripe, :request, :start|:stop|:exception]` events
7. **LatticeStripe.Webhook + Webhook.Plug** — HMAC-SHA256 signature verification (constant-time); Phoenix Plug that captures raw body before Plug.Parsers
8. **Resource modules** (Customer, PaymentIntent, etc.) — pure builders; construct Request structs, expose public API functions

### Critical Pitfalls

1. **Webhook raw body consumed by Plug.Parsers** — provide `LatticeStripe.WebhookPlug` that must be placed before `Plug.Parsers` in the Phoenix endpoint; document prominently with copy-paste Phoenix router example
2. **Timing attack on HMAC signature comparison** — use `:crypto.hash_equals/2` (OTP 25+) or XOR-reduce; never use `==`; add code comments explaining why
3. **Retry with new idempotency key causing double charges** — auto-generate idempotency keys for all POST requests; always reuse the same key on retry; respect `Stripe-Should-Retry`; never retry 400s except 409/429
4. **Rigid structs that break on Stripe API changes** — use tolerant decoders with an `__extra__` catch-all map for unknown keys; make all fields nil-able; implement Access behaviour
5. **Global Application config as primary interface** — client struct is the only primary config path; `Application.get_env` is fallback only; this enables `async: true` in all user tests

## Implications for Roadmap

Based on research, the dependency graph is clear and the build order has no ambiguity. Everything flows from the foundation layer.

### Phase 1: Foundation Core

**Rationale:** The entire library depends on this layer. Config, Request, Error, Response, Transport, Client, Retry, Pagination are tightly coupled — they must be built together. Design decisions here (client struct shape, error hierarchy, decoder tolerance, idempotency key handling) are architectural and cannot be retrofitted without breaking changes. This phase produces no user-visible Stripe API calls but is the hardest phase to change later.
**Delivers:** A working HTTP client layer that can make authenticated Stripe API calls, handle errors, retry safely, and paginate lazily — but with no resource modules yet
**Addresses:** Transport, client config, error model, retries, idempotency, list pagination, auto-pagination (FEATURES.md Tier 0)
**Avoids:** Global config anti-pattern (Pitfall 2), double-charge retry bug (Pitfall 5), rigid struct breakage (Pitfall 4), Finch pool ownership confusion (Pitfall 6), rate-limit-exhausting pagination (Pitfall 7)
**Research flag:** Standard patterns — well-documented in ExAws, Req, Finch, official Elixir library guidelines. No additional research needed.

### Phase 2: First Resource Modules (Pattern Validation)

**Rationale:** Customers is the simplest complete resource and validates the entire foundation stack end-to-end. PaymentIntents is the most important resource and validates complex multi-step state machine operations. Together they prove the pattern before it is replicated to 4+ additional resources.
**Delivers:** Full Customers CRUD + search; full PaymentIntents lifecycle (create, retrieve, update, confirm, capture, cancel, list); auto-pagination on both
**Addresses:** Customers, PaymentIntents, List struct, SearchResult struct (FEATURES.md Tier 1 Payments)
**Implements:** Resource module pattern, bang variants, expand support wired in
**Research flag:** Standard patterns — Stripe API docs are comprehensive. stripe-mock validates implementation.

### Phase 3: Webhooks

**Rationale:** Webhook infrastructure is independent from resource modules (pure crypto + Plug, no HTTP client needed). Can be parallelized with Phase 2. Solving the raw body problem and timing-safe comparison is the #1 Elixir community pain point and the clearest immediate differentiator. Must be correct from day one — webhook security is not refactorable.
**Delivers:** `Webhook.construct_event/3`, `Webhook.Plug`, Event struct, tolerance window configuration, documentation of Phoenix pipeline ordering, troubleshooting guide
**Addresses:** Webhook signature verification, Phoenix Plug (FEATURES.md Tier 0 + Webhook Handling)
**Avoids:** Raw body consumption (Pitfall 1), timing attack (Pitfall 3)
**Research flag:** Standard patterns — Stripe webhook docs are detailed. Plug raw body handling is well-understood. No additional research needed.

### Phase 4: Remaining Tier 1 Resources

**Rationale:** Pattern is established from Phase 2. Remaining resources follow the same structure with no new architectural decisions. SetupIntents, PaymentMethods, Refunds, and Checkout Sessions complete the payment story that developers evaluate when choosing a library.
**Delivers:** SetupIntents lifecycle, PaymentMethods CRUD + attach/detach, Refunds, Checkout Sessions (create/retrieve/list/expire)
**Addresses:** Tier 2 Checkout, full Tier 1 Payments completion (FEATURES.md)
**Research flag:** Standard patterns — same resource module pattern established in Phase 2.

### Phase 5: Developer Experience Polish

**Rationale:** The library is functionally complete after Phase 4 but rough around the edges. This phase elevates it to production-quality open source: guides, telemetry, test helpers, expand support finalization, and SearchResult struct. These items are independent of each other and can be developed in parallel.
**Delivers:** ExDoc guides (quickstart, webhook troubleshooting, error handling, testing strategy), telemetry events wired throughout, `LatticeStripe.Testing` helpers (fixture factories, mock webhook events), search pagination, expand support documentation
**Addresses:** Telemetry, test helpers, documentation, search pagination differentiators (FEATURES.md differentiators)
**Avoids:** Brittle test anti-pattern (Pitfall 10), missing request_id (Pitfall 12)
**Research flag:** Telemetry and test helper patterns are well-documented. ExDoc guides require no research. No additional research phase needed.

### Phase Ordering Rationale

- **Foundation must be phase 1**: every subsequent phase depends on Client, Transport, Error, Pagination, and Retry; these modules reference each other and cannot be incrementally extracted
- **First resources validate before replication**: building Customer + PaymentIntent before the other 4 resources prevents replicating architectural mistakes across the whole codebase
- **Webhooks are parallelizable**: they share no code with resource modules; the only dependency is Plug and the crypto primitives, which have no connection to the HTTP client layer
- **DX polish is last**: telemetry can be wired in alongside any phase, but guides and test helpers are more useful once the API surface is stable
- **All pitfalls in the critical path are in Phase 1**: the five critical pitfalls (timing attack, global config, double charge, rigid structs, raw body) all manifest in Foundation or Webhooks — solving them early eliminates the hardest retrofits

### Research Flags

Phases with standard patterns (no additional research phase needed):
- **Phase 1 (Foundation):** Finch, Jason, NimbleOptions, Transport behaviour patterns are extensively documented in official Elixir library guidelines, ExAws, Req, Finch source. Stripe retry/idempotency semantics are fully documented.
- **Phase 2 (First Resources):** Stripe Customers and PaymentIntents APIs are the most documented resources. stripe-mock validates correctness.
- **Phase 3 (Webhooks):** Plug raw body capture pattern is established. Stripe webhook signature spec is complete.
- **Phase 4 (Remaining Resources):** Pattern established. Stripe API docs sufficient.
- **Phase 5 (DX Polish):** Telemetry event naming patterns follow Elixir ecosystem conventions (Phoenix/Ecto). No novel territory.

No phases require a `research-phase` step. The combined research documents are comprehensive and the domain is well-understood.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All dependencies verified on Hex.pm with current version numbers. Version constraints verified against official Elixir compatibility table. Rationale cross-checked against official Elixir library guidelines. |
| Features | HIGH | Based on multiple deep-research documents including Stripe API surface mapping, community pain point analysis, competitive analysis of all known Elixir Stripe libraries, and official Stripe SDK documentation. |
| Architecture | HIGH | Patterns sourced from ExAws, Finch, Req source code and documentation. Official Elixir anti-patterns docs explicitly cover the pitfalls being avoided. Prior art is strong. |
| Pitfalls | HIGH | All critical pitfalls are documented in GitHub issues, ElixirForum threads, official security documentation, and official Stripe SDK source code. Not speculative. |

**Overall confidence:** HIGH

### Gaps to Address

- **Finch pool supervision tree example**: the exact recommended supervision tree for users who want to use their existing Finch instance vs. let LatticeStripe manage its own needs to be finalized during Phase 1 implementation. Both patterns are known; the question is which to make default.
- **Struct tolerance strategy (catch-all vs. Access behaviour)**: research recommends an `__extra__` catch-all field but the exact implementation (field name, Access implementation, how it interacts with struct pattern matching) needs to be decided during Phase 1 Response module design.
- **Expand union types**: the research identifies expand support as a differentiator but describes it as "High" complexity. The exact Elixir type representation for "field is either a string ID or an expanded struct" needs a concrete decision (tagged tuples vs. sum types via a behaviour vs. raw maps) before resource modules are written.
- **stripe-mock limitations for testing**: stripe-mock is stateless and cannot test all state-machine transitions. The testing guide will need to document which scenarios require Stripe test mode vs. stripe-mock. This is a documentation gap, not an implementation gap.

## Sources

### Primary (HIGH confidence)
- [Finch on Hex.pm](https://hex.pm/packages/finch) — v0.21.0, pool configuration
- [Jason on Hex.pm](https://hex.pm/packages/jason) — v1.4.4
- [Telemetry on Hex.pm](https://hex.pm/packages/telemetry) — v1.4.1
- [Plug on Hex.pm](https://hex.pm/packages/plug) — v1.19.1
- [Plug.Crypto docs](https://hexdocs.pm/plug_crypto/) — v2.1.1, HMAC verification
- [NimbleOptions on Hex.pm](https://hex.pm/packages/nimble_options) — v1.1.1
- [Mox on GitHub](https://github.com/dashbitco/mox) — v1.2.0
- [Elixir Compatibility Table](https://hexdocs.pm/elixir/compatibility-and-deprecations.html) — version matrix
- [Elixir Official Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) — avoid global config, prefer explicit APIs
- [Elixir Design Anti-Patterns](https://hexdocs.pm/elixir/design-anti-patterns.html) — overloaded return types, GenServer abuse
- [Stripe Idempotent Requests](https://docs.stripe.com/api/idempotent_requests) — retry semantics
- [Stripe Webhook Signature Verification](https://docs.stripe.com/webhooks/signature) — HMAC spec
- [Stripe API Versioning](https://docs.stripe.com/api/versioning) — version pinning
- [stripe-mock on GitHub](https://github.com/stripe/stripe-mock) — OpenAPI-backed test server
- [ExAws GitHub](https://github.com/ex-aws/ex_aws) — behaviour-based SDK architecture reference
- [Req GitHub](https://github.com/wojtekmach/req) — request-as-data pattern reference

### Secondary (MEDIUM confidence)
- [Dashbit Blog: SDKs with Req: Stripe](https://dashbit.co/blog/sdks-with-req-stripe) — SDK architecture guidance, Finch vs. Req rationale
- [Application Layering Pattern](https://aaronrenner.io/2019/09/18/application-layering-a-pattern-for-extensible-elixir-application-design.html) — layered architecture pattern
- [stripity-stripe GitHub issues](https://github.com/beam-community/stripity-stripe/issues) — documented community pain points
- [stripe-node auto-pagination issue #575](https://github.com/stripe/stripe-node/issues/575) — rate limit risk in auto-pagination
- [ElixirForum: Is Stripity Stripe maintained?](https://elixirforum.com/t/is-stripity-stripe-maintained/73673) — community sentiment
- [Stripe: Designing robust APIs with idempotency](https://stripe.com/blog/idempotency) — retry safety

### Tertiary (project-internal research documents)
- `/prompts/The definitive Stripe library gap in Elixir - a master research document.md` — comprehensive ecosystem gap analysis
- `/prompts/stripe-lib-priority-user-flows-deep-research.md` — Tier priority analysis
- `/prompts/stripe-sdk-api-surface-area-deep-research.md` — complete API surface mapping
- `/prompts/elixir-best-practices-deep-research.md` — Elixir patterns reference
- `/prompts/elixir-opensource-libs-best-practices-deep-research.md` — open source library conventions

---
*Research completed: 2026-03-31*
*Ready for roadmap: yes*
