# Architecture Patterns

**Domain:** Elixir API SDK / Stripe client library — v1.2 Production Hardening & DX
**Researched:** 2026-04-16
**Confidence:** HIGH (based on direct codebase inspection)
**Scope:** How v1.2 target features integrate with the existing architecture.

---

## Existing Architecture Summary (Post-v1.1)

The foundation established in v1.0 and extended in v1.1 is stable. Nine target features must each
find their integration point without breaking the existing contract.

```
+-------------------------------------------------------------------+
|  PUBLIC API LAYER                                                 |
|  Resource modules: Customer, Invoice, Subscription, Billing.*,   |
|  BillingPortal.*, Checkout.*, Account, Transfer, Payout, ...     |
|  Each: defstruct + @known_fields + from_map/1                    |
|        → Client.request/2                                         |
|        → Resource.unwrap_singular/2 or unwrap_list/2             |
+-------------------------------------------------------------------+
           |                          |
           v                          v
+----------------------+    +---------------------+
|  RESOURCE HELPER     |    |  WEBHOOK LAYER      |
|  LatticeStripe.-     |    |  Webhook.Plug       |
|  Resource            |    |  Webhook.Handler    |
|  (unwrap_singular,   |    |  Webhook.Signature  |
|   unwrap_list,       |    |  Verification       |
|   unwrap_bang!,      |    +---------------------+
|   require_param!)    |
+----------------------+
           |
           v
+-------------------------------------------------------------------+
|  CLIENT LAYER — LatticeStripe.Client                             |
|  - Config: api_key, finch, transport, json_codec, retry_strategy |
|  - timeout (global default), max_retries, telemetry_enabled      |
|  - Idempotency key resolution (auto-gen for POST)                |
|  - Header building (auth, version, stripe-account, idk)         |
|  - Retry loop: do_request_with_retries/7                         |
|  - Response decode: JSON → Response/Error struct                 |
|  - Telemetry span wrap (always at this layer)                    |
+-------------------------------------------------------------------+
           |
           v
+-------------------------------------------------------------------+
|  RETRY LAYER — LatticeStripe.RetryStrategy behaviour            |
|  Default: exponential backoff, Stripe-Should-Retry header,       |
|  Retry-After header, 429/5xx status checks                       |
+-------------------------------------------------------------------+
           |
           v
+-------------------------------------------------------------------+
|  TRANSPORT LAYER — LatticeStripe.Transport behaviour            |
|  Default: Transport.Finch (Mint-based, connection pooling)        |
+-------------------------------------------------------------------+
           |
           v
+-------------------------------------------------------------------+
|  INFRASTRUCTURE                                                   |
|  Finch (HTTP/connection pool) | Jason (JSON) | Telemetry         |
+-------------------------------------------------------------------+
```

### Request Pipeline (detailed)

```
Resource.create(client, params, opts)
  → %Request{method: :post, path: "/v1/...", params: params, opts: opts}
  → Client.request(client, req)
      → resolve opts (api_key, api_version, timeout, stripe_account, expand)
      → resolve idempotency_key (auto-gen UUID for POST)
      → merge_expand (inject expand[] params)
      → build_url_and_body (FormEncoder.encode → bracket notation)
      → build_headers (auth, version, content-type, idk)
      → Telemetry.request_span(client, req, idk, fn →)
          → do_request_with_retries/7
              → client.transport.request(transport_request)
              → decode_response (json_codec.decode → Response/Error)
              → maybe_retry (RetryStrategy.retry?/2)
  → Resource.unwrap_singular(result, &Module.from_map/1)
  → {:ok, %Module{}} | {:error, %Error{}}
```

---

## Feature Integration Analysis

### 1. Expand Deserialization (EXPD-02/03/05)

**What it does:** `expand: ["customer"]` returns `%Customer{}` struct instead of raw string ID.
Dot-paths like `expand: ["data.customer"]` for nested expands. Status field atomization audit.

**Where it hooks in:** `Resource.unwrap_singular/2` and `Resource.unwrap_list/2` in `resource.ex`.

Currently these functions call `from_map_fn.(data)` on the raw decoded map. The raw map already
contains expanded sub-objects as maps when Stripe expands them — a customer becomes
`%{"id" => "cus_...", "object" => "customer", "email" => ...}` instead of `"cus_..."`.

The hook is `from_map/1` on each resource. When a field contains a map with `"object" => "customer"`,
the resource's `from_map/1` must recognize that and call `Customer.from_map/1` on it instead of
storing the raw map.

**New components needed:**
- `LatticeStripe.Expand` module (new) — a dispatch table mapping Stripe object type strings to their
  `from_map/1` functions. `Expand.decode_field(value)` checks if value is a map with `"object"` key,
  looks up the module, calls `from_map/1`.
- Per-resource `from_map/1` updates — each resource that can appear as an expanded field gets an
  updated `from_map/1` that calls `Expand.decode_field/1` on expandable fields.

**What stays the same:** `Client.request/2`, `Resource.unwrap_singular/2`, `Transport`, telemetry.
The `expand:` opt is already threaded through to the query params — that part is done. This is
purely response decoding.

**Status atomization (EXPD-05):** Audit all resources for string status fields and add `status_atom`
virtual getters or convert the field in `from_map/1`. Pattern: `Account.Capability.status_atom/1`
already exists as precedent. The sweep is surgical per-file, no architectural change needed.

**Integration point:** `from_map/1` in each resource module. No pipeline changes.

---

### 2. Circuit Breaker Pattern

**What it does:** Prevents cascading failures when Stripe is down. After N consecutive failures,
stop sending requests immediately (fail-fast) instead of exhausting retry budget.

**Where it hooks in:** The `RetryStrategy` behaviour is the correct integration point. The behaviour
already receives full error context including status codes and headers. A circuit breaker
`RetryStrategy` implementation can track state and open the circuit.

**The problem with stateless RetryStrategy:** Circuit breakers are inherently stateful — they track
failure counts across multiple requests. The current `RetryStrategy` behaviour is stateless
(pure function, `retry?(attempt, context) :: {:retry, delay} | :stop`). Circuit state cannot live
inside the behaviour callback.

**Two valid approaches:**

*Option A — `:fuse` integration (external GenServer state)*

`:fuse` is an Erlang OTP library that provides named circuit breakers backed by a GenServer. The
user starts a `:fuse` supervisor in their app tree, registers a fuse named `:stripe`, and wraps
calls with `:fuse.ask(:stripe, :sync)`. A custom `RetryStrategy` can call `:fuse.melt(:stripe)`
on failures to melt the fuse and `:fuse.ask(:stripe, :sync)` to check if blown.

This requires adding `:fuse` as an optional dep and the user running a supervisor. It is the
correct long-term solution for production circuit breaking.

*Option B — Custom RetryStrategy with ETS state*

A `RetryStrategy.CircuitBreaker` shipped in the library uses ETS for shared failure count state.
Callable without a separate supervisor. More complex to get right (counter TTL, reset logic).

**Recommended approach for v1.2:** Ship as a **guide + example custom RetryStrategy** using
`:fuse`, not as a built-in. Rationale:
- Circuit state is application-global, not per-client. The user's supervision tree must own it.
- The `RetryStrategy` behaviour already gives users the hook they need.
- Shipping a half-baked built-in circuit breaker creates a maintenance burden.
- The guide should show the `:fuse` pattern with a complete working implementation.

**Integration point:** `RetryStrategy` behaviour (existing hook). No new components in the library.
New file: `guides/circuit-breaker.md`.

---

### 3. Rate-Limit Awareness

**What it does:** Parse `RateLimit-*` response headers and expose via telemetry metadata so users
can back-pressure their own request rates.

**Stripe's actual headers (verified):**
- `Stripe-Rate-Limited-Reason` — present only on 429 responses; values: `global-rate`,
  `global-concurrency`, `endpoint-rate`, `endpoint-concurrency`, `resource-specific`
- Standard `Retry-After` — already parsed in `RetryStrategy.Default`

**Where it hooks in:** `Client.decode_response/6` already has `resp_headers` in scope. The
`build_stop_metadata/4` function in `Telemetry` builds the telemetry metadata map. Rate-limit
header data should appear in the `:stop` event metadata.

**Concrete change:** In `Client.build_decoded_response/6` (or a new private helper), extract
`Stripe-Rate-Limited-Reason` from resp_headers when present. Thread this into the `Response` struct
or pass it through to the telemetry stop metadata.

**Two sub-options:**

*A — Add to `Response` struct:* Add `rate_limit_reason: nil | String.t()` field to `%Response{}`.
Simple, lets users inspect it directly. Downside: only present on 429 errors, which become `Error`
not `Response` — so this field is always nil on success. Not useful.

*B — Add to telemetry stop metadata only:* In `Telemetry.build_stop_metadata/4`, extract
`Stripe-Rate-Limited-Reason` from the error's headers (currently available via the internal
`{:error, error, resp_headers}` 3-tuple) and add `:rate_limit_reason` to the stop metadata map.
Clean — telemetry is the right place for operational signals that users attach handlers to.

**Recommended:** Option B. Telemetry metadata addition. Users attach a handler to
`[:lattice_stripe, :request, :stop]` and inspect `:rate_limit_reason`.

**What changes:**
- `Client.apply_retry_decision/4` and `maybe_retry/5` already pass `resp_headers` to retry context.
  The headers are also available when building error telemetry stop metadata.
- `Telemetry.build_stop_metadata/4` — add `:rate_limit_reason` extraction from error struct's
  `raw_body` or thread headers differently. Currently the error case has `resp_headers` in scope
  in the retry loop but those headers aren't passed to `build_stop_metadata`. Minor threading change.
- `guides/rate-limits.md` — new guide documenting what to do with the signal.

**New telemetry metadata key:** `:rate_limit_reason` on `[:lattice_stripe, :request, :stop]` events.
Nil when not rate-limited, string value when 429.

**Integration point:** `Client.do_request/2` → `decode_response` → error branch → telemetry
metadata. Minimal threading change.

---

### 4. Richer Errors (Fuzzy Param Suggestions)

**What it does:** When Stripe returns `invalid_request_error` with a `:param` field, suggest
the correct param name using fuzzy string matching. "Did you mean `:payment_method_types`?"

**Where it hooks in:** `Error.from_response/3` in `error.ex`. This function constructs the
`%Error{}` struct from the decoded Stripe error body. It already extracts `param` from the
error map. A post-construction enrichment step can add a `:hint` field.

**New components needed:**
- `Error` struct — add `hint: nil | String.t()` field (new optional field, backward compatible).
- `Error.from_response/3` — after building the base error struct, call a hint generator if
  `type == :invalid_request_error` and `param != nil`.
- `LatticeStripe.Hints` (new internal module, `@moduledoc false`) — contains the fuzzy matching
  logic. Simple approach: Jaro-Winkler distance via `:string_distance` Erlang stdlib, or a
  curated list of common Stripe param names with a distance threshold.

**Scope constraint:** Keep it simple. The value is "Did you mean X?" for common typos — not a
full NLP system. A curated list of ~50 commonly mistyped Stripe param names plus Jaro-Winkler
distance (Elixir's stdlib `String.jaro_distance/2` — available in all supported versions) is
sufficient.

**Integration point:** `Error.from_response/3`. No pipeline changes.

**What changes:**
- `lib/lattice_stripe/error.ex` — add `:hint` field, call `Hints.suggest/1` in `from_response`.
- `lib/lattice_stripe/hints.ex` (new internal module) — curated param list + Jaro-Winkler.
- No changes to Client, Transport, Resource.

---

### 5. Request Batching / Concurrent Helpers

**What it does:** Ergonomic API for firing multiple Stripe requests in parallel using
`Task.async_stream`, collecting results.

**Where it hooks in:** This is a utility layer ON TOP of `Client.request/2`. It does not modify
the pipeline — it calls it concurrently.

**Approach:** A new `LatticeStripe.Batch` module (or `LatticeStripe.Concurrent` — naming TBD)
that wraps `Task.async_stream`. The public API could be:

```elixir
# Fetch multiple customers concurrently
requests = [
  %Request{method: :get, path: "/v1/customers/cus_a"},
  %Request{method: :get, path: "/v1/customers/cus_b"},
  %Request{method: :get, path: "/v1/customers/cus_c"}
]
results = LatticeStripe.Batch.run(client, requests)
# [{:ok, %Response{}}, {:ok, %Response{}}, {:error, %Error{}}]
```

Internally: `Task.async_stream(requests, &Client.request(client, &1), ordered: true, max_concurrency: N)`.

**Key design constraint:** No new processes owned by the library. `Task.async_stream` spawns
tasks in the caller's process group — supervised by the caller's supervisor. This is consistent
with the "no GenServers for state" philosophy.

**Integration point:** New module, calls `Client.request/2`. No changes to existing modules.

**What changes:**
- `lib/lattice_stripe/batch.ex` (new public module) — `run/3`, `run!/3` with configurable
  `max_concurrency` and timeout per task. Returns `[{:ok, result} | {:error, error}]`.
- Guide section on concurrent patterns.

---

### 6. Per-Operation Timeouts

**What it does:** Allow search/list operations (which can be slow) to use longer default timeouts
than create/retrieve. Currently the single `client.timeout` applies to everything.

**Where it hooks in:** `Client.request/2` resolves the effective timeout with:
```elixir
effective_timeout = Keyword.get(req.opts, :timeout, client.timeout)
```
The `:timeout` opt in `req.opts` already overrides the client default. Per-operation defaults
are a layer above this — they set `req.opts[:timeout]` to the operation-specific default if the
caller hasn't provided one.

**Two sub-options:**

*A — Resource module sets default timeout in opts*

```elixir
def list(client, params, opts \\ []) do
  opts = Keyword.put_new(opts, :timeout, 60_000)  # list gets 60s default
  %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&from_map/1)
end
```

Simple. No new infrastructure. User's explicit `:timeout` still wins (via `Keyword.put_new`).

*B — Client struct gains per-operation timeout map*

`%Client{timeout_overrides: %{list: 60_000, search: 90_000}}`. Client.request inspects the
request method and path to pick the right timeout.

More powerful but adds complexity to Client and breaks the "Client is a dumb config holder" pattern.

**Recommended:** Option A. Resource modules use `Keyword.put_new(opts, :timeout, N)` for operations
that commonly need longer timeouts (list/stream/search). Clean, no new infrastructure, user override
still works.

**Integration point:** Individual resource module operations. No changes to Client pipeline.

**What changes:** Surgical `Keyword.put_new` additions to slow operations across resource modules.
An audit identifies which operations warrant longer defaults. No new files.

---

### 7. meter_event_stream (v2 API)

**What it does:** High-throughput metering via Stripe's v2 endpoint. Two-step flow:
1. `POST /v2/billing/meter_event_session` — creates a short-lived session token (15 min TTL).
2. `POST /v2/billing/meter_event_stream` — submits events using the session token as auth.

**Architecture challenge:** This is NOT a standard `Client.request/2` call. Differences:
- The base URL is still `https://api.stripe.com` but the path is `/v2/billing/...` (not `/v1/...`).
- Authentication uses a session token (Bearer), not the API key.
- The session token expires and must be refreshed.
- The v2 endpoint accepts JSON body (not form-encoded) — `Content-Type: application/json`.

**Where it hooks in:**

The session creation (`POST /v2/billing/meter_event_session`) can go through `Client.request/2`
normally — it uses the API key for auth, just a different path. The response contains the session
token.

The event stream itself needs different header construction:
- `Authorization: Bearer <session_token>` instead of `Bearer <api_key>`
- `Content-Type: application/json` instead of `application/x-www-form-urlencoded`
- Path is `/v2/billing/meter_event_stream`

**Two options:**

*A — Expose raw Transport call in a dedicated module*

`LatticeStripe.Billing.MeterEventStream` holds the session and fires events directly via the
Transport behaviour, bypassing `Client.request/2`'s header-building. The session is managed
externally (caller stores the token, checks expiry, calls `refresh_session/2` when needed).

*B — Add v2 path + JSON body support to Client*

Extend `Client.request/2` to accept `content_type: :json` and `auth_token: token` opts in
`req.opts`. The `build_headers` private function branches on these opts.

**Recommended:** Option B with a thin wrapper module. Rationale: Transport layer already handles
different content types. Adding `content_type: :json` and `auth_token:` opts to the request
pipeline is surgical (two branches in `build_headers` and `build_url_and_body`). The
`MeterEventStream` module exposes a clean public API hiding the v2 complexity.

**New components:**
- `LatticeStripe.Billing.MeterEventStream` (new public module):
  - `create_session/2` — calls `/v2/billing/meter_event_session`, returns `%{token: ..., expires_at: ...}`
  - `send/3` — sends events to `/v2/billing/meter_event_stream` using session token
  - Session management is the caller's responsibility (Accrue or user app).
- `Client.request/2` — minor extension: recognize `:auth_token` opt (overrides api_key in auth
  header) and `:content_type` opt (`:json` triggers JSON encoding + `application/json` header).
- `Json.Jason` encode path — already exists for webhook, just needs to be callable from Client.

**Integration point:** `Client.build_headers/5` and `build_url_and_body/4`. Targeted changes.

---

### 8. BillingPortal.Configuration CRUDL

**What it does:** Full CRUD on `/v1/billing_portal/configurations`. Create/retrieve/update/list.
(No delete — Stripe deactivates, not deletes.)

**Where it hooks in:** Follows the exact same resource module pattern as every other CRUDL resource.

**Stripe API operations available (verified):**
- `POST /v1/billing_portal/configurations` — create
- `GET /v1/billing_portal/configurations/:id` — retrieve
- `POST /v1/billing_portal/configurations/:id` — update
- `GET /v1/billing_portal/configurations` — list

**Key nested structure:** `features` object with sub-objects `customer_update`, `invoice_history`,
`payment_method_update`, `subscription_cancel`, `subscription_update`. Plus `business_profile`,
`login_page`, `default_return_url`, `metadata`, `name`.

**New components:**
- `LatticeStripe.BillingPortal.Configuration` (new resource module) — standard CRUDL pattern.
- `LatticeStripe.BillingPortal.Configuration.Features` (new nested struct) — wraps the features
  sub-object. Each sub-feature (CustomerUpdate, InvoiceHistory, etc.) can start as raw maps —
  promote to typed structs only if Accrue needs to pattern-match their fields.
- `lib/lattice_stripe/billing_portal/guards.ex` (existing) — add any portal-specific guards here.

**Integration point:** New files. `mix.exs` group update to add `Configuration` to the
"Customer Portal" ExDoc group.

**What changes:**
- `lib/lattice_stripe/billing_portal/configuration.ex` (new) — CRUDL resource module.
- `lib/lattice_stripe/billing_portal/configuration/features.ex` (new) — nested typed struct.
- `mix.exs` — add `LatticeStripe.BillingPortal.Configuration` to "Customer Portal" group.

---

### 9. Changeset-Style Param Builders

**What it does:** Optional fluent builders for complex nested params like SubscriptionSchedule
phases and BillingPortal flows. Reduces the friction of building deeply nested maps.

**Where it hooks in:** These are pre-`Client` utilities. They produce the `params` map that the
caller passes to resource functions. They don't touch the pipeline.

**Approach:** Builder structs with an `encode/1` function that produces the Stripe-ready map:

```elixir
phase =
  LatticeStripe.Build.Phase.new()
  |> LatticeStripe.Build.Phase.add_item(price: "price_123", quantity: 1)
  |> LatticeStripe.Build.Phase.set_iterations(3)

params = %{"phases" => [LatticeStripe.Build.Phase.encode(phase)]}
```

**Scope for v1.2:** Start with the two highest-friction cases:
1. SubscriptionSchedule phase building (deeply nested, error-prone)
2. BillingPortal FlowData construction (already has a pre-flight guard — builder can make it
   impossible to build invalid flow data)

**New components:**
- `LatticeStripe.Build.*` namespace (new, `@moduledoc` showing it's optional DX sugar).
- Each builder is a plain struct with `new/0`, field setters, and `encode/1 :: map()`.
- No GenServers, no processes. Pure data transformation.

**Integration point:** Pre-`Client`. No changes to existing pipeline.

---

## Component Map: New vs Modified

### New Components

| Component | Type | Integration Layer |
|-----------|------|-------------------|
| `LatticeStripe.Expand` | New internal module | `from_map/1` in resource modules |
| `LatticeStripe.Hints` | New internal module | `Error.from_response/3` |
| `LatticeStripe.Batch` | New public module | Wraps `Client.request/2` |
| `LatticeStripe.Billing.MeterEventStream` | New public module | Client (with minor extension) |
| `LatticeStripe.BillingPortal.Configuration` | New resource module | Standard resource pattern |
| `LatticeStripe.BillingPortal.Configuration.Features` | New nested struct | `Configuration.from_map/1` |
| `LatticeStripe.Build.*` | New builder modules | Pre-Client, pure data |
| `guides/circuit-breaker.md` | Documentation | Guide only, no code |
| `guides/performance.md` | Documentation | Guide only, no code |
| `guides/opentelemetry.md` | Documentation | Guide only, no code |
| `guides/rate-limits.md` | Documentation | Guide only, no code |

### Modified Components

| Component | Change | Scope |
|-----------|--------|-------|
| `LatticeStripe.Error` | Add `:hint` field; call `Hints.suggest/1` in `from_response/3` | Backward compatible (nil default) |
| `LatticeStripe.Telemetry` | Add `:rate_limit_reason` to stop metadata | Additive to existing metadata map |
| `LatticeStripe.Client` | Add `:auth_token` and `:content_type` opts recognition | Gated by opt presence, backward compatible |
| Per-resource `from_map/1` (expandable fields) | Call `Expand.decode_field/1` on expandable fields | Additive — no behavior change when expand not used |
| Slow resource operations (list/search/stream) | `Keyword.put_new(opts, :timeout, N)` | No-op when caller provides explicit timeout |
| `mix.exs` groups_for_modules | Add Configuration to Customer Portal group | Additive |

### Unchanged Components

Transport, RetryStrategy.Default, RetryStrategy behaviour contract, Request, Response struct,
FormEncoder, Json, List (pagination), Webhook stack, existing resource module public APIs.

---

## Build Order (Dependency Graph)

Features grouped by dependency isolation:

### Isolated — No Dependencies on Other v1.2 Features

These can be built in any order, in parallel if desired:

1. **BillingPortal.Configuration CRUDL** — pure resource pattern, no new infrastructure needed.
   Standard template: bootstrap → nested structs → resource module → integration test → guide.

2. **Richer Errors (Hints)** — isolated to `error.ex` + new `hints.ex`. No pipeline changes.
   Can be a single small plan.

3. **Per-Operation Timeouts** — surgical `Keyword.put_new` across resource modules. Pure audit
   + one-liner additions. No new modules.

4. **Changeset-Style Builders** — new `Build.*` namespace, no changes to existing code.
   Start with SubscriptionSchedule Phase builder (highest pain point) + FlowData builder.

5. **Circuit Breaker Guide** — documentation only. Can be written anytime.

6. **Performance Guide** — documentation only. Covers Finch pool tuning, supervision, warm-up.

7. **OpenTelemetry Integration Guide** — documentation only.

### Light Dependency

8. **Rate-Limit Awareness** — depends on understanding exactly where headers are available in
   the error flow. Requires reading the Client internals carefully. Minor threading change to
   Telemetry. Small but requires attention to the internal `{:error, error, resp_headers}` 3-tuple.

9. **Status Atomization Audit (EXPD-05)** — parallel sweep across all resource `from_map/1`
   functions. No new infrastructure. Fastest to do after familiarizing with the codebase.

### Has Prerequisite

10. **Expand Deserialization (EXPD-02/03)** — depends on `LatticeStripe.Expand` dispatch module
    being built first, then per-resource `from_map/1` updates. The EXPD-05 status audit can
    happen concurrently (different field types).

11. **meter_event_stream** — depends on `Client.request/2` extension for `:auth_token`/
    `:content_type` opts (must be done before or alongside the new module). Can be done in one
    plan that does both the Client extension and the new module.

### Parallel

12. **Request Batching (Batch module)** — no changes to Client. Pure wrapper. Can be done
    anytime. Recommend building after MeterEventStream since concurrent patterns are relevant
    to high-throughput metering use cases.

### Recommended Build Sequence

```
Wave 1 (Quick wins, high value):
  - Status atomization audit (EXPD-05) — sweep + fix, establishes expand-readiness
  - BillingPortal.Configuration CRUDL — deferred feature, unblocks Accrue
  - Richer errors (Hints) — isolated, clear DX improvement
  - Per-operation timeouts — surgical, quick

Wave 2 (Infrastructure):
  - Expand deserialization (EXPD-02/03) — builds on EXPD-05 sweep
  - Rate-limit awareness (telemetry metadata)
  - meter_event_stream (Client extension + new module)

Wave 3 (DX sugar + docs):
  - Request batching (Batch module)
  - Changeset-style builders (Build.*)
  - Circuit breaker guide
  - Performance guide
  - OpenTelemetry guide
  - LiveBook notebook
```

---

## Data Flow Changes

### Before v1.2 (Current)

```
Client.decode_response → decoded map → Resource.unwrap_singular → from_map/1 → %Struct{}
                                                                              (expand fields = raw strings or maps)
```

### After EXPD-02 (Typed Expand)

```
Client.decode_response → decoded map → Resource.unwrap_singular → from_map/1
                                                                    → calls Expand.decode_field/1 on expandable fields
                                                                    → Expand dispatches to SubResource.from_map/1
                                                                    → %Struct{customer: %Customer{...}}
```

### After Rate-Limit Awareness

```
Client.do_request → {:error, error, resp_headers}
  → maybe_retry → Telemetry.build_stop_metadata
      → extracts Stripe-Rate-Limited-Reason from resp_headers
      → adds rate_limit_reason: "endpoint-rate" to stop metadata
      → [:lattice_stripe, :request, :stop] event carries :rate_limit_reason
```

### After meter_event_stream

```
MeterEventStream.send(client, session_token, events)
  → Client.request(client, %Request{
      method: :post,
      path: "/v2/billing/meter_event_stream",
      params: events,
      opts: [auth_token: session_token, content_type: :json]
    })
  → Client.build_headers detects :auth_token → uses token not api_key
  → Client.build_url_and_body detects :content_type :json → Json.encode(params)
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: GenServer for Circuit Breaker State

**What people do:** Ship a `CircuitBreaker.Server` GenServer inside the library that holds failure
counts globally.
**Why it's wrong:** The library doesn't own the user's supervision tree. A library GenServer
that crashes takes the user's supervision strategy hostage. `:fuse` is purpose-built and battle-tested.
**Do this instead:** Guide + example `RetryStrategy` using `:fuse`. User starts the fuse supervisor.

### Anti-Pattern 2: Expand Deserialization at the Client Layer

**What people do:** Put expansion logic inside `Client.decode_response/6` — inspect the decoded
map for known object types and auto-decode.
**Why it's wrong:** Client doesn't know about resource modules (that creates a circular dependency
since resource modules call Client). Expand belongs in `from_map/1`.
**Do this instead:** `Expand.decode_field/1` dispatch in each resource's `from_map/1`.

### Anti-Pattern 3: New Struct Fields for Rate-Limit Info

**What people do:** Add `:rate_limit_reason` to `%Response{}` struct.
**Why it's wrong:** Rate-limit info only exists on error responses (429), which become `%Error{}`,
not `%Response{}`. The field would always be nil on success.
**Do this instead:** Telemetry stop metadata. Users attach handlers; operational signals belong
in the observability layer.

### Anti-Pattern 4: Modifying the Transport Behaviour for v2 API

**What people do:** Add a new Transport callback for JSON requests or create a separate
`Transport.V2Finch` adapter.
**Why it's wrong:** The v2 difference is auth header and content-type, not transport semantics.
The Transport behaviour is already capable — it takes `headers` and `body` as raw values.
**Do this instead:** Let `Client.request/2` build different headers/body based on `req.opts`,
then pass to the existing Transport. No Transport changes needed.

### Anti-Pattern 5: Changeset Builders That Return Requests

**What people do:** Build `Build.Phase.to_request()` or similar that produce `%Request{}` structs.
**Why it's wrong:** Couples the builder to the request pipeline. Builders should produce Stripe
param maps, which the caller passes to the existing resource functions.
**Do this instead:** Builders produce `map()` via `encode/1`. The caller does:
`SubscriptionSchedule.create(client, %{"phases" => [Build.Phase.encode(phase)]})`.

---

## Sources

- Direct inspection of `lib/lattice_stripe/client.ex` — pipeline, header building, retry loop
- Direct inspection of `lib/lattice_stripe/retry_strategy.ex` — behaviour contract
- Direct inspection of `lib/lattice_stripe/telemetry.ex` — metadata building, event catalog
- Direct inspection of `lib/lattice_stripe/error.ex` — from_response/3 structure
- Direct inspection of `lib/lattice_stripe/resource.ex` — unwrap_singular/list pattern
- Direct inspection of `lib/lattice_stripe/response.ex` — Response struct fields
- Direct inspection of `lib/lattice_stripe/transport.ex` — Transport behaviour contract
- Direct inspection of `lib/lattice_stripe/billing/meter_event.ex` — existing metering pattern
- Direct inspection of `lib/lattice_stripe/billing_portal/session.ex` — BillingPortal namespace
- [Stripe Rate Limits documentation](https://docs.stripe.com/rate-limits) — `Stripe-Rate-Limited-Reason` header names
- [Stripe Meter Event Stream v2 API](https://docs.stripe.com/api/v2/billing-meter-stream) — two-step session token auth
- [Stripe BillingPortal Configuration create](https://docs.stripe.com/api/customer_portal/configurations/create) — available operations and fields
- [`:fuse` Erlang circuit breaker library](https://github.com/jlouis/fuse) — OTP-native circuit breaker
- [external_service Elixir library](https://github.com/jvoegele/external_service) — wraps `:fuse` for Elixir

---

*Architecture research for: LatticeStripe v1.2 Production Hardening & DX*
*Researched: 2026-04-16*
