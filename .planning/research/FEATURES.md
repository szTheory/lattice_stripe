# Feature Research

**Domain:** Production Elixir SDK for Stripe API (LatticeStripe v1.2 — Production Hardening & DX)
**Researched:** 2026-04-16
**Confidence:** HIGH (most features verified against official Stripe docs, Finch docs, stripe-ruby/go/python source, Elixir ecosystem)

---

## Context: v1.2 Scope

This research covers 14 target features for v1.2. LatticeStripe v1.1 is live on Hex.pm with 84+
resource modules, 1,488 tests, full Payments + Billing + Connect + Metering + Customer Portal
coverage. The downstream consumer (Accrue) is already building on v1.1.

v1.2 goal: make LatticeStripe the SDK production teams recommend to each other — polish DX, add
reliability primitives, and close the remaining feature gaps.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume a production SDK provides. Missing these makes LatticeStripe feel incomplete
relative to stripe-ruby, stripe-go, stripe-python, or stripity_stripe.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Expand deserialization → typed structs | Every official Stripe SDK (ruby, go, python, node) returns typed objects from `expand:`. stripe-ruby returns `Stripe::Customer`; stripe-go uses custom `UnmarshalJSON` per type to handle ID-or-struct duality; stripe-python returns typed Python objects. LatticeStripe currently returns raw maps when `expand:` is used — the #1 ergonomic gap users notice. | HIGH | Requires a registry mapping Stripe's `"object"` field values (e.g., `"customer"`) to corresponding `from_map/1` functions. Stripe responses always include `"object": "customer"` in expanded payloads — this is the discriminator. The `from_map/1` + `@known_fields` + `extra` pattern already exists on all 84+ resources and is the exact foundation needed. `Resource.unwrap_singular/2` and `Resource.unwrap_list/2` need extension to apply the registry post-decode. |
| Status field atomization audit | Idiomatic Elixir uses atoms for finite enumerations. String statuses like `"active"`, `"canceled"`, `"incomplete"` force downstream `String.to_atom/1` calls or guard chains everywhere. The `status_atom/1` pattern was already proven in Phase 17 (`Account.Capability.status_atom/1`). Users expect it everywhere. | MEDIUM | Audit scope: Subscription, SubscriptionItem, Invoice, PaymentIntent, SetupIntent, Refund, Payout, Transfer, Meter, BillingPortal resources, ExternalAccount, Checkout.Session. Add `status_atom/1` helper per resource where a string-enum status field exists. Keep original string field — backward compatible. No changes to struct field names. |
| BillingPortal.Configuration CRUDL | Stripe provides a full CRUDL API for portal configurations (create/retrieve/update/list). `BillingPortal.Session` shipped in v1.1. Users building multi-tenant SaaS with branded portals need to configure the portal programmatically, not via the Stripe Dashboard. Stripe API docs confirm all four operations. | MEDIUM | Standard CRUDL module, same pattern as all other resource modules. No delete operation exists (Stripe doesn't allow configuration deletion). Configuration objects have a large nested `features` param (subscription cancellation, payment method update, invoice history, etc.) and a `business_profile` object. Typed nested structs or well-documented map params for these. |
| Per-operation timeout tuning | Production systems need different timeout budgets: search/list endpoints (Stripe can be slow on large datasets, especially searches with complex queries) need longer timeouts than creates. Finch supports `receive_timeout` and `request_timeout` per-request natively. Users expect SDK-level sensible defaults that they can override. | LOW | Finch natively supports `:pool_timeout` (default 5s), `:receive_timeout` (default 15s), `:request_timeout` (default infinity, HTTP/1 only) per-request — confirmed from Finch docs. Current LatticeStripe already threads `timeout:` through. Need: resource-level default constants (e.g., `@search_receive_timeout 30_000`, `@default_receive_timeout 15_000`) merged into per-request opts. Zero new dependencies. |
| Rate-limit awareness | Production apps hitting Stripe at scale need observability into rate limit headroom. Stripe returns `ratelimit-remaining`, `ratelimit-limit`, and `stripe-rate-limited-reason` (on 429s only) headers on all responses. Users expect these surfaced — at minimum via telemetry metadata. No official Stripe SDK exposes this prominently, but production teams always write their own header scrapers. | MEDIUM | Response headers are already captured in `Response.headers`. Pattern: extract rate limit headers in `Client` after receiving response, emit as metadata in `[:lattice_stripe, :request, :stop]` telemetry event, and optionally add `ratelimit_remaining` field to `Response` struct. Zero breaking changes. The `stripe-rate-limited-reason` header values: `global-concurrency`, `global-rate`, `endpoint-concurrency`, `endpoint-rate`, `resource-specific`. |
| Connection warm-up helper | Production apps want Finch pools established at startup, not lazily on first request. Cold-start latency on the first Stripe call is user-observable. Finch supports pre-configured pools in supervision tree config via `pools:` map at start time, plus dynamic `Finch.start_pool/3` for runtime addition. | LOW | Finch pool config in supervision tree (`pools: %{"https://api.stripe.com" => [size: 10]}`) is the primary mechanism. The SDK contribution: document correct config in `guides/performance.md` and provide a `LatticeStripe.warmup/1` function that fires a lightweight request (e.g., list with limit 1, or a health-check endpoint) to pre-establish connections. Finch also supports `Finch.find_pool/2` to check if pool exists. |

### Differentiators (Competitive Advantage)

Features that set LatticeStripe apart from stripity_stripe, other Elixir HTTP wrappers, and even
the official Stripe SDKs. Reinforce the "production-grade, idiomatic Elixir" positioning.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Circuit breaker pattern | Prevents cascading failures when Stripe is degraded. No other Elixir Stripe library provides guidance here. Production SaaS teams need their app to fail fast when Stripe returns repeated 5xx or times out — opening the circuit prevents thread exhaustion and gives Stripe time to recover. | MEDIUM | The right approach: document as a custom `RetryStrategy` callback pattern (no new dep). The existing `RetryStrategy` behaviour makes this composable. Show a concrete implementation that tracks failure count and timestamps. Separately, mention `:fuse` (Erlang OTP circuit breaker, ETS-backed, production battle-tested, on Hex.pm, used by BEAM ecosystem) as optional for teams wanting a managed state machine. Do NOT add `:fuse` as a default dep — most users don't need it. |
| Richer error context (fuzzy param suggestions) | `invalid_request_error` with `param: "payment_method_types"` is not actionable without a docs lookup. Client-side fuzzy suggestions ("Did you mean `:payment_method_types`?") in the SDK error enrichment substantially improve DX for new integrators. | MEDIUM | Stripe's API does NOT return hint/suggestion fields — confirmed by checking the full error object reference. This is 100% client-side SDK enrichment. Pattern: a `LatticeStripe.ParamSuggestions` module with a static map of `{resource, misspelled_key} => correct_key`. Applied when constructing `%Error{type: :invalid_request_error, param: param}`. Scope narrowly to ~30 common misspellings across Payment, Billing, Customer. A static lookup is more predictable and testable than Levenshtein distance. |
| Request batching / concurrent helpers | `Task.async_stream`-based parallel request ergonomics. Users retrieving 50 customers by ID, or bulk-creating meter events, write their own `Task.async_stream` wrappers with manual error handling. A `LatticeStripe.Concurrent.map/3` with configurable concurrency, timeout, and error-collection semantics is a genuine DX win. | MEDIUM | Pure Elixir, no new dependencies. `Task.async_stream` is OTP stdlib. Pattern: `Concurrent.map(client, ids, &Customer.retrieve/2, max_concurrency: 10)` returning `[{:ok, struct} \| {:error, error}]`. Works with any resource function that accepts `(client, id)`. Optionally: `Concurrent.map_ok/3` that raises on first error. Fits naturally into LatticeStripe's `{:ok, _} \| {:error, _}` idiom. |
| OpenTelemetry integration guide | The Elixir OTel ecosystem (opentelemetry_api, opentelemetry_phoenix, opentelemetry_ecto) expects span propagation. LatticeStripe already emits `:telemetry` events. The bridge from `:telemetry` to OTel spans is non-obvious. A concrete guide with working code is a top request from production teams running distributed tracing. | LOW | Pure documentation. LatticeStripe itself does not take a dep on opentelemetry_api (respects the "minimal deps" constraint). The guide shows: (1) adding `opentelemetry_api` + `opentelemetry` deps, (2) attaching a handler in `Application.start/2` that converts `[:lattice_stripe, :request, :stop]` events to OTel spans, (3) what telemetry metadata maps to OTel span attributes. No changes to LatticeStripe code. |
| LiveBook notebook | Interactive SDK exploration for onboarding, documentation, and integration demos. Livebook (`.livemd` files) can be embedded in HexDocs with a "Run in Livebook" badge. Libraries like Nx, Bumblebee, and Explorer use this pattern successfully. Lowers the barrier for new integrators and makes conference demos trivially easy. | LOW | A `.livemd` file in `notebooks/` or `guides/`. Uses `Mix.install([{:lattice_stripe, "~> 1.2"}])` for zero-config setup. Demonstrates: client setup with test API key, creating a customer, a payment intent, handling errors, auto-pagination via `stream!`. Add HexDocs badge to README. Pure documentation artifact. |
| Stripe API changelog / drift detection | CI mechanism detecting when Stripe adds new fields/resources to their OpenAPI spec that LatticeStripe has not yet modeled. The `stripe/openapi` repository on GitHub has 2,236+ versioned releases (v2241 as of April 2026) and updates frequently. A scheduled CI job diffing against the pinned spec surfaces new fields before users file bug reports. | HIGH | Complexity is in the diffing logic — parsing OpenAPI JSON and comparing field sets per resource against `@known_fields` in each module. Approach: `mix lattice_stripe.drift_check` Mix task that downloads latest Stripe OpenAPI spec JSON, diffs against `@known_fields` per resource, and reports new/removed fields as warnings. Wire to scheduled GitHub Actions workflow (weekly). OpenAPI JSON parsing in the Mix task (no prod dep needed — dev/test only). This is more important for LatticeStripe than for official SDKs because the official SDKs are auto-generated from the spec; LatticeStripe is handwritten and will inevitably drift. |
| Changeset-style param builders | Fluent builders for complex nested params. SubscriptionSchedule phases, BillingPortal.Configuration features, and PaymentIntent confirmation params have deeply nested structures that are error-prone to build as plain maps. A composable builder pattern improves DX for the most complex resources. | HIGH | Risk of scope creep if too broad. Elixir community does not have a universal "HTTP params builder" pattern — Ecto.Changeset is for DB validation, not API params. Scope narrowly to 2-3 most complex resources (SubscriptionSchedule phases, BillingPortal.Configuration features). Use simple `Builder` modules with pipe-friendly `put/3` helpers rather than full changeset semantics. Example: `SubscriptionSchedule.Builder.new() \|> put_phase(items: [...]) \|> build()`. |
| meter_event_stream v2 endpoint | High-throughput metering: 10,000 events/sec vs 1,000/sec for the v1 endpoint. Required for SaaS companies with high event volumes. Uses a two-step auth flow: `POST /v2/billing/meter_event_session` returns a 15-minute bearer token; `POST /v2/billing/meter_event_stream` uses that token. Deferred from v1.1 (locked as D3). | HIGH | The two-step auth with short-lived tokens (15-min expiry) maps to a GenServer or Agent holding the current token and proactively refreshing before expiry. This is a legitimate use of a process per PROJECT.md philosophy ("processes only when truly needed" — token lifecycle management IS that case). Users opt in by adding `LatticeStripe.Billing.MeterEventSession` to their supervision tree. The token manager handles: initial session creation, background refresh at ~12 minutes, error handling if session creation fails, vending current token to `MeterEventStream.create/3`. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Global rate limit auto-throttling (sleep between requests) | Users want the SDK to "handle" rate limits automatically by sleeping | Silently blocking the caller process is terrible in Elixir — blocks a BEAM scheduler thread (not just an OS thread), hurts concurrency, hides API abuse. 429s should propagate as `{:error, %Error{type: :rate_limit_error}}` and the caller should back off. | Expose rate limit headroom via telemetry metadata. Document retry-with-backoff pattern in `guides/performance.md`. Callers use `Task.async_stream` with `max_concurrency` to stay under limits proactively. |
| Automatic expand for all requests by default | Users want to avoid manually specifying `expand:` | Dramatically increases response payload sizes and API latency. Stripe charges per API call, not per field. Silent expansion would obscure what data is actually being fetched and create unexpected cost increases. | Keep `expand:` explicit per-request. Document common expand patterns in guides. The typed deserialization feature (EXPD-02) is the correct answer — once `expand:` returns typed structs, users are incentivized to use it intentionally and surgically. |
| SDK-managed idempotency key namespacing | Users want the SDK to namespace idempotency keys to prevent collisions | SDK has no knowledge of application-level namespacing. Auto-generated UUID4 keys already make collisions statistically impossible. Namespacing would require SDK config that varies per deployment. | Already auto-generate UUID4 idempotency keys per request (v1.0 behavior). Document that callers should provide their own deterministic keys when they need replay semantics (e.g., `idempotency_key: "order_#{order_id}_payment"`). |
| Webhook event replay / queuing | Users want the SDK to handle webhook deduplication and retry logic | This is application-level infrastructure. Every production app already has a database. Putting queuing in the SDK creates coupling to persistence and process supervision that belongs in the application layer. Violates "library, not framework" principle. | `LatticeStripe.Webhook.Handler` behaviour (already shipped) is the right abstraction. Guide users to implement idempotent handlers using their DB. Document that `event.id` is the dedup key. |
| `:fuse` as a required dep for circuit breaking | Adding circuit breaking to every LatticeStripe installation by default | Most LatticeStripe users don't need circuit breaking (normal SaaS load). Making `:fuse` required adds ETS-based global state and a process to every installation regardless of need. | Make circuit breaking optional via documentation. Show `RetryStrategy` callback pattern in `guides/circuit-breaker.md`. Users who want managed state add `:fuse` themselves. |
| Full Ecto.Changeset-style validation for all params | Users want server-side validation recreated client-side | Stripe's validation is the source of truth — duplicating it client-side means maintaining a parallel validation spec that drifts with each Stripe API release. Better to let Stripe validate and improve the error messages we surface. | Scoped param builders for the 2-3 most complex resources (SubscriptionSchedule, BillingPortal.Configuration). For everything else, let Stripe's `invalid_request_error` with improved fuzzy suggestions handle it. |

---

## Feature Dependencies

```
Expand deserialization (EXPD-02)
    └──requires──> Status atomization audit (EXPD-05)
                       (same from_map/1 resource sweep; do together)
    └──requires──> Nested dot-path parsing (EXPD-03)
                       (dot-path is a parsing layer on top of the registry in EXPD-02)
    └──builds_on──> @known_fields + from_map/1 pattern (already in all 84+ resources)

Rate-limit awareness
    └──enhances──> Telemetry (already shipped v1.0)
    └──enhances──> Circuit breaker guide
                       (rate limit headroom informs when to trip breaker)

Connection warm-up helper
    └──requires──> Performance guide (guides/performance.md)
                       (warm-up is one section of the broader guide)

Per-operation timeout tuning
    └──enhances──> Performance guide (guides/performance.md)
                       (timeout defaults table belongs in the guide)

meter_event_stream v2
    └──requires──> Session token GenServer (new supervised process)
    └──depends_on──> MeterEvent.create/3 (already shipped v1.1)
    └──uses──> v2 API base path (/v2/billing) with Bearer token auth (different from v1 API key auth)

BillingPortal.Configuration
    └──depends_on──> BillingPortal.Session (already shipped v1.1)
    └──scopes──> Changeset-style param builders (Configuration has most complex nested params)

Changeset-style param builders
    └──scoped_to──> SubscriptionSchedule phases + BillingPortal.Configuration features
    └──conflicts──> scope creep if extended to all resources

OpenTelemetry guide
    └──depends_on──> Telemetry events (already shipped v1.0)
    └──requires_no_code_changes──> to LatticeStripe itself

LiveBook notebook
    └──depends_on──> Stable v1.2 API surface (ships last)

Stripe API drift detection
    └──depends_on──> @known_fields accuracy (EXPD-05 sweep first)
    └──depends_on──> stripe/openapi GitHub repository (external)

Richer error context
    └──builds_on──> Error struct (already shipped v1.0)
    └──independent_of──> all other v1.2 features
```

### Dependency Notes

- **EXPD-02 and EXPD-05 are the same sweep:** Building the typed deserialization registry requires visiting every resource module anyway. The status atomization sweep is the same pass. Ship them together.
- **Performance guide is a forcing function for Wave 1:** Connection warm-up and per-operation timeout tuning are both sections of the same guide. Define the guide structure first, then implement the helpers the guide documents.
- **meter_event_stream v2 is self-contained:** The token manager GenServer does not depend on any other v1.2 feature. It can be designed and shipped independently, but is complex enough to warrant its own phase.
- **Drift detection needs clean @known_fields:** The EXPD-05 status sweep will correct and extend `@known_fields` across all resources. Run drift detection after that sweep to avoid false positives from fields already in `extra` but not yet in `@known_fields`.
- **BillingPortal.Configuration unblocks Changeset builders:** The Configuration `features` param is the best initial use case for a builder — complex enough to justify one, bounded enough to avoid open-ended scope.

---

## MVP Definition

### Wave 1 — High-Impact (ship first)

Minimum viable v1.2 — what makes the "production hardening" claim credible.

- [ ] **Expand deserialization → typed structs (EXPD-02/03)** — The #1 ergonomic gap vs every other Stripe SDK. Every official Stripe SDK does this. Without it, `expand:` is half-baked.
- [ ] **Status field atomization audit (EXPD-05)** — Natural companion to EXPD-02. Same resource sweep. Idiomatic Elixir. No additional complexity once you're touching all resource modules.
- [ ] **Performance guide + Finch pool tuning (guides/performance.md)** — High value, low effort. Answers the #1 question every production team asks. Includes connection warm-up patterns.
- [ ] **Circuit breaker guide** — Documentation + `RetryStrategy` example. No new dep. Answers the #2 question production teams ask. Can ship as a section of performance guide or standalone.

### Wave 2 — Focused Polish

- [ ] **Rate-limit awareness** — Emit `ratelimit-remaining` + `stripe-rate-limited-reason` via telemetry metadata. Low implementation cost, high production value.
- [ ] **BillingPortal.Configuration CRUDL** — Deferred from v1.1. Standard module pattern. Required for teams managing portals programmatically.
- [ ] **Request batching / concurrent helpers** — `LatticeStripe.Concurrent.map/3`. No new deps. Real DX win.
- [ ] **Per-operation timeout tuning** — Resource-level timeout defaults. Finch already supports it. Add to performance guide.
- [ ] **Richer error context** — Client-side fuzzy param suggestions. Scope to ~30 common misspellings.
- [ ] **OpenTelemetry integration guide** — Documentation only. High value for enterprise/platform adopters.

### Wave 3 — Feature Completion

- [ ] **meter_event_stream v2** — GenServer token lifecycle. Target high-volume metering users.
- [ ] **Changeset-style param builders** — Scope to SubscriptionSchedule + BillingPortal.Configuration.
- [ ] **Stripe API drift detection** — Mix task + scheduled CI. Best after EXPD-05 stabilizes `@known_fields`.
- [ ] **LiveBook notebook** — Ships last. Exercises finished v1.2 surface. Launch artifact.
- [ ] **Connection warm-up helper (`LatticeStripe.warmup/1`)** — Documented in performance guide; implement the function after guide is written.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Expand deserialization (EXPD-02/03) | HIGH | HIGH | P1 |
| Status atomization audit (EXPD-05) | HIGH | MEDIUM | P1 |
| Performance guide + pool tuning | HIGH | LOW | P1 |
| Circuit breaker guide/pattern | HIGH | LOW | P1 |
| BillingPortal.Configuration CRUDL | HIGH | MEDIUM | P1 |
| Rate-limit awareness (telemetry) | HIGH | LOW | P2 |
| Request batching / Concurrent helpers | MEDIUM | MEDIUM | P2 |
| Per-operation timeout tuning | MEDIUM | LOW | P2 |
| Richer error context (fuzzy params) | MEDIUM | MEDIUM | P2 |
| OpenTelemetry integration guide | MEDIUM | LOW | P2 |
| meter_event_stream v2 | MEDIUM | HIGH | P2 |
| Changeset-style param builders | MEDIUM | HIGH | P3 |
| Stripe API drift detection | LOW-MEDIUM | HIGH | P3 |
| LiveBook notebook | MEDIUM | LOW | P3 |
| Connection warm-up helper | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for v1.2 to claim "production hardening" — ships in Wave 1
- P2: Should have — increases production confidence and DX — ships in Wave 2
- P3: Nice to have — completes the story, good for launch marketing — ships in Wave 3

---

## Competitor Feature Analysis

| Feature | stripe-ruby | stripe-go | stripe-python | LatticeStripe v1.2 plan |
|---------|-------------|-----------|---------------|------------------------|
| Expand → typed structs | YES — `Util.convert_to_stripe_object` dispatches on `"object"` key | YES — custom `UnmarshalJSON` per type handles ID-or-struct duality | YES — typed Python classes from response | Registry of `"object"` → `from_map/1`, applied post-decode |
| Status field atoms | NO — strings throughout | NO — string constants | NO — strings throughout | YES — `status_atom/1` per resource; idiomatic Elixir advantage over all competitors |
| Rate-limit awareness | NO built-in exposure | NO built-in exposure | NO built-in exposure | YES — telemetry metadata on stop event; differentiator |
| Circuit breaker | NO — retry only | NO — retry only | NO — retry only | YES — `RetryStrategy` callback guide; `:fuse` optional |
| Per-operation timeout | YES — per-call options | YES — per-call context | YES — per-call timeout arg | YES — resource-level defaults + per-request override |
| Concurrent helpers | NO | NO | NO | YES — `LatticeStripe.Concurrent.map/3`; differentiator |
| Error param suggestions | NO | NO | NO | YES — client-side static fuzzy map; differentiator |
| OTel guide | NO | NO | NO | YES — documented bridge from :telemetry to OTel spans; differentiator |
| LiveBook | N/A | N/A | N/A | YES — Elixir-specific differentiator for onboarding |
| Drift detection | N/A — auto-generated from OpenAPI | N/A — auto-generated | N/A — auto-generated | Mix task + scheduled CI; necessary because LatticeStripe is handwritten |
| Changeset/fluent builders | NO | NO | NO | Scoped builders for 2-3 most complex resources |
| BillingPortal.Configuration | YES | YES | YES | YES — standard CRUDL module (deferred from v1.1) |
| meter_event_stream v2 | YES | YES | YES | YES — with GenServer token lifecycle |
| Connection warm-up | NO explicit helper | NO explicit helper | NO explicit helper | `LatticeStripe.warmup/1` + performance guide |

**Key insight on drift detection:** Official Stripe SDKs (ruby, go, python, node, java) are all
auto-generated from the `stripe/openapi` spec, which updates with every Stripe API release. They
cannot drift. LatticeStripe is handwritten, making drift an ongoing hygiene concern. A scheduled
CI check against the spec is more important for LatticeStripe than it would be for any official
SDK.

---

## Implementation Notes Per Feature

### Expand deserialization (EXPD-02/03)

The discriminator is Stripe's `"object"` field — every Stripe resource includes `"object": "customer"`,
`"object": "payment_intent"`, etc. in its JSON. When a field is expanded, Stripe returns the full
object map (with `"object"`) instead of a bare string ID.

Registry pattern:
```elixir
# In a new LatticeStripe.ObjectRegistry module
@registry %{
  "customer"         => &LatticeStripe.Customer.from_map/1,
  "payment_intent"   => &LatticeStripe.PaymentIntent.from_map/1,
  "payment_method"   => &LatticeStripe.PaymentMethod.from_map/1,
  # ... all 84+ resource "object" values
}

def from_object_map(%{"object" => type} = map) do
  case Map.fetch(@registry, type) do
    {:ok, from_map_fn} -> from_map_fn.(map)
    :error              -> map  # unknown type: pass through as raw map
  end
end
```

Applied recursively during response decode: walk response body, if a value is a map with
`"object"` key, apply registry. This handles arbitrary nesting without explicit path traversal.

Dot-path support (`expand: ["data.customer"]`) is automatic with the recursive walk — any expanded
object anywhere in the response gets typed, regardless of depth. Maximum expand depth per Stripe
docs is 4 levels.

### Status atomization (EXPD-05)

Pattern from Phase 17 (`Account.Capability.status_atom/1`):
```elixir
@status_map %{
  "active"     => :active,
  "canceled"   => :canceled,
  "incomplete" => :incomplete,
  # ... resource-specific values
}

@spec status_atom(t()) :: atom() | nil
def status_atom(%__MODULE__{status: status}), do: Map.get(@status_map, status)
```

Keep the original `status` string field untouched. Add `status_atom/1` as a convenience converter.
No breaking changes to existing users who pattern-match on string values.

### meter_event_stream v2

Two-phase auth (confirmed from Stripe docs):
1. `POST /v2/billing/meter_event_session` → `{authentication_token: "...", expires_at: unix_ts}` (15-min lifetime)
2. `POST /v2/billing/meter_event_stream` with `Authorization: Bearer <token>` (NOT the API secret key)

GenServer design:
```elixir
defmodule LatticeStripe.Billing.MeterEventSession do
  use GenServer
  # Holds current token + expiry
  # Refreshes proactively at ~12 minutes (3-min buffer before 15-min expiry)
  # Vends token via get_token/1 to MeterEventStream.create/3
  # Handles refresh failure (returns {:error, ...} to callers)
end
```

Users add to supervision tree:
```elixir
children = [
  {LatticeStripe.Billing.MeterEventSession, client: client}
]
```

This is a legitimate process per PROJECT.md philosophy — token lifecycle IS the kind of state that needs a process.

### Rate-limit awareness

Stripe rate limit headers on all responses:
- `ratelimit-remaining` — integer, requests remaining in current window
- `ratelimit-limit` — integer, total requests allowed per window
- `stripe-rate-limited-reason` — only on 429 responses; values: `global-concurrency`, `global-rate`, `endpoint-concurrency`, `endpoint-rate`, `resource-specific`

Implementation: Extract in `Client` after response received, add to telemetry metadata:
```elixir
:telemetry.execute(
  [:lattice_stripe, :request, :stop],
  %{duration: duration},
  %{
    # existing metadata...
    ratelimit_remaining: parse_int_header(headers, "ratelimit-remaining"),
    ratelimit_limit: parse_int_header(headers, "ratelimit-limit"),
    rate_limited_reason: get_header(headers, "stripe-rate-limited-reason")
  }
)
```

### Fuzzy param suggestions

Stripe's API does NOT return hint or suggestion fields — confirmed by reviewing the complete error
object schema. This is 100% client-side SDK enrichment.

Static lookup approach (not Levenshtein — too unpredictable):
```elixir
# LatticeStripe.ParamSuggestions
@suggestions %{
  "paymentMethodType"     => "payment_method_types",
  "paymentMethod_types"   => "payment_method_types",
  "PaymentMethodTypes"    => "payment_method_types",
  "customerId"            => "customer",
  # ~30 most common misspellings across major resources
}

def suggest(param_name) do
  Map.get(@suggestions, param_name)
end
```

Applied when constructing `%Error{type: :invalid_request_error}`:
```elixir
message =
  if suggestion = ParamSuggestions.suggest(param) do
    "#{original_message} (Did you mean '#{suggestion}'?)"
  else
    original_message
  end
```

---

## Sources

- [Stripe Expanding Objects API Reference](https://docs.stripe.com/api/expanding_objects) — expand behavior, `"object"` discriminator confirmed
- [Stripe Expand Documentation](https://docs.stripe.com/expand) — dot-path syntax, 4-level depth limit confirmed
- [Stripe API Errors Reference](https://docs.stripe.com/api/errors) — confirmed no hint/suggestion fields in error schema
- [Stripe Rate Limits Documentation](https://docs.stripe.com/rate-limits) — `ratelimit-remaining`, `ratelimit-limit`, `stripe-rate-limited-reason` headers confirmed
- [Stripe Meter Event Stream v2 Reference](https://docs.stripe.com/api/v2/billing-meter-stream) — 10,000 events/sec, 15-min token lifetime confirmed
- [Stripe Usage Recording API](https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api) — v1 (1,000/sec) vs v2 (10,000/sec) throughput limits confirmed
- [Stripe BillingPortal Configuration API](https://docs.stripe.com/api/customer_portal/configurations) — create/retrieve/update/list operations confirmed; no delete operation
- [Stripe OpenAPI Repository](https://github.com/stripe/openapi) — 2,236+ releases, v2241 as of April 2026, JSON + YAML, `/latest/` contains v1 + v2 specs
- [stripe-ruby GitHub](https://github.com/stripe/stripe-ruby) — typed deserialization via `Util.convert_to_stripe_object` dispatching on `"object"` key confirmed
- [stripe-go GitHub](https://github.com/stripe/stripe-go) — custom `UnmarshalJSON` per type for expand handling confirmed
- [fuse Erlang library](https://github.com/jlouis/fuse) — circuit breaker, ETS-backed, production battle-tested, on Hex.pm
- [Finch documentation](https://hexdocs.pm/finch/Finch.html) — `pool_timeout`, `receive_timeout`, `request_timeout` per-request confirmed; `Finch.start_pool/3` for dynamic pools confirmed
- [Livebook](https://livebook.dev/) — `.livemd` format, `Mix.install`, HexDocs badge integration confirmed
- [OpenTelemetry Erlang/Elixir](https://opentelemetry.io/docs/languages/erlang/) — `opentelemetry_api` + `:telemetry` bridge pattern confirmed
- [oasdiff GitHub Action](https://github.com/oasdiff/oasdiff-action) — OpenAPI drift detection in CI

---

*Feature research for: LatticeStripe v1.2 — Production Hardening & DX*
*Researched: 2026-04-16*
