# Architecture Patterns

**Domain:** Elixir API SDK / Stripe client library
**Researched:** 2026-03-31

## Recommended Architecture

LatticeStripe follows a **layered, pure-functional-core architecture** with five distinct layers. This pattern is consistent across well-regarded Elixir API client libraries (ExAws, Finch, Req, stripity_stripe) and aligns with Elixir community guidance: modules/functions for code organization, processes only for runtime concerns (connection pooling), behaviours for extension points.

```
+---------------------------------------------------------------+
|                    PUBLIC API LAYER                            |
|  LatticeStripe.Customer, LatticeStripe.PaymentIntent, ...     |
|  (one module per Stripe resource, user-facing functions)       |
+---------------------------------------------------------------+
        |  builds Request structs, delegates to Client
        v
+---------------------------------------------------------------+
|                    CLIENT LAYER                                |
|  LatticeStripe.Client                                         |
|  (config struct, request execution, option merging)            |
+---------------------------------------------------------------+
        |  passes Request to Transport, gets raw response
        v
+---------------------------------------------------------------+
|                    HTTP / TRANSPORT LAYER                      |
|  LatticeStripe.Transport (behaviour)                          |
|  LatticeStripe.Transport.Finch (default adapter)              |
|  (HTTP execution, connection pooling, raw request/response)    |
+---------------------------------------------------------------+
        ^                                       |
        |  raw response                         |  HTTP over wire
        v                                       v
+---------------------------------------------------------------+
|                    CODEC / MIDDLEWARE LAYER                    |
|  LatticeStripe.Request (struct + builder)                     |
|  LatticeStripe.Response (struct + decoder)                    |
|  LatticeStripe.Error (structured error types)                 |
|  LatticeStripe.Pagination (cursor + search pagination)        |
|  LatticeStripe.Retry (backoff, Stripe-Should-Retry)           |
|  (encoding, decoding, error normalization, retry logic)        |
+---------------------------------------------------------------+
        |
        v
+---------------------------------------------------------------+
|                    CROSS-CUTTING CONCERNS                     |
|  LatticeStripe.Telemetry (event emission)                     |
|  LatticeStripe.Webhook (signature verification)               |
|  LatticeStripe.Webhook.Plug (Phoenix integration)             |
|  (observability, webhook handling)                             |
+---------------------------------------------------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | Purity |
|-----------|---------------|-------------------|--------|
| **Resource modules** (Customer, PaymentIntent, etc.) | Build typed params, construct Request structs, expose public API | Client, Request | Pure (builds data, delegates execution) |
| **Client** | Hold config, merge per-request opts, orchestrate request lifecycle | Transport, Request, Response, Error, Retry, Telemetry | Impure (orchestrates I/O) |
| **Transport behaviour** | Execute raw HTTP requests | External HTTP (Finch/network) | Impure (I/O boundary) |
| **Request** | Struct + builder for HTTP request data (method, path, params, headers) | None (data struct) | Pure |
| **Response** | Struct + decoder for HTTP response data, JSON-to-struct mapping | None (data struct + functions) | Pure |
| **Error** | Structured error types, pattern-matchable, Stripe error hierarchy | None (data struct) | Pure |
| **Pagination** | Cursor-based and search-based pagination, Stream.resource for auto-pagination | Client (to fetch next pages) | Mixed (Stream wraps I/O) |
| **Retry** | Exponential backoff logic, Stripe-Should-Retry header interpretation | None (pure decision logic, Client calls it) | Pure (decision logic) |
| **Telemetry** | Emit :telemetry events for request lifecycle | :telemetry library | Side-effect only |
| **Webhook** | Signature verification, event parsing | None (pure crypto + parsing) | Pure |
| **Webhook.Plug** | Phoenix Plug for webhook endpoints, raw body handling | Webhook module, Plug/Phoenix | Impure (Plug pipeline) |

### Data Flow

**Outbound request (happy path):**

```
User code
  |
  | LatticeStripe.Customer.create(client, %{email: "..."})
  v
Resource module
  |
  | Builds %LatticeStripe.Request{method: :post, path: "/v1/customers", params: %{...}}
  v
Client.request/2
  |
  | 1. Merges client config + per-request opts
  | 2. Emits [:lattice_stripe, :request, :start] telemetry
  | 3. Calls Request.encode/1 (params -> form-encoded body, headers assembled)
  v
Transport.request/1  (Finch adapter)
  |
  | Raw HTTP request over wire
  v
Stripe API
  |
  | Raw HTTP response (status, headers, body)
  v
Client (continued)
  |
  | 4. Response.decode/2 (JSON -> struct or error)
  | 5. If retryable error: Retry.should_retry?/2 -> loop back to Transport
  | 6. Emits [:lattice_stripe, :request, :stop] telemetry
  | 7. Returns {:ok, %Customer{}} or {:error, %LatticeStripe.Error{}}
  v
User code
```

**Webhook inbound flow:**

```
Stripe webhook POST
  |
  v
Webhook.Plug (in Phoenix endpoint, before Plug.Parsers)
  |
  | 1. Reads raw body from conn
  | 2. Calls Webhook.construct_event/3
  v
Webhook.construct_event/3
  |
  | 1. Verifies HMAC-SHA256 signature against raw body
  | 2. Checks timestamp tolerance
  | 3. Parses JSON body into event struct
  | 4. Returns {:ok, %LatticeStripe.Event{}} or {:error, reason}
  v
User's handler function
```

**Auto-pagination flow:**

```
LatticeStripe.Customer.stream(client, limit: 100)
  |
  v
Pagination.stream/3
  |
  | Uses Stream.resource/3:
  |   - init: fetch first page via Client.request/2
  |   - next: yield items from current page, fetch next page when exhausted
  |   - halt: cleanup (nothing to clean for HTTP)
  v
Lazy Stream (Enumerable)
  |
  | User composes with Stream/Enum:
  |   stream |> Stream.filter(...) |> Enum.take(10)
  v
Pages fetched on-demand as items are consumed
```

## Module Tree

```
lib/
  lattice_stripe.ex                          # Top-level convenience (delegates to Client)
  lattice_stripe/
    client.ex                                # Client struct + request orchestration
    config.ex                                # Config validation (NimbleOptions)
    request.ex                               # Request struct + encoder
    response.ex                              # Response struct + decoder
    error.ex                                 # Error types (ApiError, CardError, etc.)
    transport.ex                             # Transport behaviour definition
    transport/
      finch.ex                               # Default Finch adapter
    retry.ex                                 # Retry logic + backoff
    pagination.ex                            # Cursor/search pagination + Stream
    telemetry.ex                             # Telemetry event definitions + helpers
    webhook.ex                               # Signature verification + event parsing
    webhook/
      plug.ex                                # Phoenix Plug for webhook endpoints
    # --- Resource modules (Tier 0: none, Tier 1+) ---
    customer.ex                              # Stripe Customers API
    payment_intent.ex                        # Stripe PaymentIntents API
    setup_intent.ex                          # Stripe SetupIntents API
    payment_method.ex                        # Stripe PaymentMethods API
    refund.ex                                # Stripe Refunds API
    checkout/
      session.ex                             # Stripe Checkout Sessions API
    event.ex                                 # Stripe Events (webhook event struct)
    list.ex                                  # Stripe List wrapper struct
    search_result.ex                         # Stripe SearchResult wrapper struct
```

## Patterns to Follow

### Pattern 1: Client-as-struct, passed explicitly

**What:** The client is a plain struct holding config (API key, base URL, timeouts, etc.). It is passed as the first argument to all API calls. No global state, no GenServer for config.

**When:** Always. This is the canonical Elixir pattern for API clients (ExAws, Req, Finch all follow this).

**Why:** Supports multi-tenancy (different Stripe accounts per request), testing (pass mock-configured client), and avoids global Application env as primary config path.

**Example:**
```elixir
defmodule LatticeStripe.Client do
  @enforce_keys [:api_key]
  defstruct [
    :api_key,
    base_url: "https://api.stripe.com",
    api_version: "2026-03-25.dahlia",
    transport: LatticeStripe.Transport.Finch,
    json_codec: Jason,
    max_retries: 3,
    timeout: 30_000,
    telemetry_enabled: true,
    # Per-client defaults (overridable per-request)
    stripe_account: nil,
    idempotency_key: nil
  ]
end

# Usage
client = LatticeStripe.Client.new(api_key: "sk_test_...")
{:ok, customer} = LatticeStripe.Customer.create(client, %{email: "j@example.com"})
```

### Pattern 2: Transport behaviour for HTTP abstraction

**What:** A `@behaviour` defining a single `request/1` callback. The default implementation uses Finch. Users can swap in any HTTP client.

**When:** Always for the HTTP boundary.

**Why:** Decouples the SDK from any specific HTTP client. Enables test doubles via Mox. Follows ExAws and Tesla patterns.

**Example:**
```elixir
defmodule LatticeStripe.Transport do
  @callback request(LatticeStripe.Request.t()) ::
    {:ok, status :: pos_integer(), headers :: [{String.t(), String.t()}], body :: binary()}
    | {:error, Exception.t()}
end

defmodule LatticeStripe.Transport.Finch do
  @behaviour LatticeStripe.Transport

  @impl true
  def request(%LatticeStripe.Request{} = req) do
    # Build Finch request, execute against pool
  end
end
```

### Pattern 3: Request-as-data (operations as structs)

**What:** Each API call builds a `%Request{}` struct describing the HTTP operation. The struct is pure data -- it does not execute anything. Execution is separate (Client.request/2).

**When:** Always. This is the Finch/Req/ExAws pattern.

**Why:** Testable (inspect requests without executing), composable (middleware can transform requests), debuggable (log the struct).

**Example:**
```elixir
defmodule LatticeStripe.Request do
  defstruct [
    :method,      # :get | :post | :delete
    :path,        # "/v1/customers"
    :params,      # %{email: "..."} (body params for POST, query for GET)
    :headers,     # additional headers
    :opts         # per-request overrides (idempotency_key, expand, etc.)
  ]
end
```

### Pattern 4: Structured, pattern-matchable errors

**What:** Errors are structs with domain-specific fields, not raw maps or strings. They map to Stripe's error hierarchy.

**When:** All error returns from the SDK.

**Why:** Enables `case {:error, %LatticeStripe.Error{type: :card_error}} ->` pattern matching. Far better than inspecting string messages or HTTP status codes.

**Example:**
```elixir
defmodule LatticeStripe.Error do
  defexception [
    :type,           # :card_error | :invalid_request_error | :authentication_error | ...
    :code,           # "card_declined", "expired_card", etc.
    :message,        # Human-readable message from Stripe
    :param,          # Which parameter caused the error
    :http_status,    # 400, 401, 402, 403, 429, 500, etc.
    :request_id,     # Stripe request ID for support
    :stripe_code,    # Stripe's error code
    :decline_code,   # For card errors
    :charge          # For card errors, the charge ID
  ]
end

# Usage
case LatticeStripe.PaymentIntent.create(client, params) do
  {:ok, %LatticeStripe.PaymentIntent{} = pi} -> handle_success(pi)
  {:error, %LatticeStripe.Error{type: :card_error, code: "card_declined"}} -> handle_decline()
  {:error, %LatticeStripe.Error{type: :rate_limit_error}} -> back_off_and_retry()
  {:error, %LatticeStripe.Error{type: :authentication_error}} -> check_api_key()
end
```

### Pattern 5: Non-bang + bang function pairs

**What:** Every public API function has a tuple-returning version and a raising version.

**When:** All resource operations.

**Why:** Elixir convention. Tuple version for control flow, bang version for scripts/pipelines where failure should crash.

**Example:**
```elixir
defmodule LatticeStripe.Customer do
  def create(client, params, opts \\ []) do
    # Returns {:ok, %Customer{}} | {:error, %Error{}}
  end

  def create!(client, params, opts \\ []) do
    case create(client, params, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end
end
```

### Pattern 6: Stream.resource for auto-pagination

**What:** Wrap Stripe's cursor-based pagination in `Stream.resource/3` to produce a lazy Enumerable.

**When:** All list endpoints.

**Why:** Idiomatic Elixir. Composes with Stream/Enum. Fetches pages on-demand. No existing Elixir Stripe library provides this.

**Example:**
```elixir
defmodule LatticeStripe.Pagination do
  def stream(client, path, params \\ %{}, opts \\ []) do
    Stream.resource(
      fn -> fetch_page(client, path, params, opts) end,
      fn
        {:done} -> {:halt, :done}
        {items, cursor} ->
          case items do
            [] -> {:halt, :done}
            items -> {items, fetch_next_or_done(client, path, params, opts, cursor)}
          end
      end,
      fn _ -> :ok end
    )
  end
end
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Global Application config as primary interface

**What:** Using `Application.get_env(:lattice_stripe, :api_key)` as the main config path.

**Why bad:** Effectively global mutable state. Breaks multi-tenancy. Makes testing harder. Official Elixir library guidelines explicitly warn against this for libraries.

**Instead:** Client struct passed explicitly. Application config only as an optional convenience fallback.

### Anti-Pattern 2: GenServer for client state

**What:** Wrapping the client in a GenServer to hold config or manage request lifecycle.

**Why bad:** Unnecessary process for what is pure data + stateless HTTP calls. Creates a bottleneck (single process serializes requests). Official Elixir guidance: "don't hide plain computation behind a GenServer."

**Instead:** Client is a plain struct. Connection pooling is handled by Finch (which does need processes, but that is Finch's concern, not ours).

### Anti-Pattern 3: Macros for resource module generation

**What:** Using `use LatticeStripe.Resource` macros to generate CRUD functions at compile time.

**Why bad:** Obscures what code exists (hard to navigate, hard to document). Creates compile-time dependencies. Official Elixir guidance: macros are a last resort. stripity_stripe v3 used codegen from OpenAPI which is different -- but even there, the generated code should be readable standalone modules, not macro-expanded mystery code.

**Instead:** Hand-write each resource module (for v1). Each module is explicit, readable, documentable. Consider code generation from OpenAPI as a future evolution, but generate explicit modules, not macro-expanded ones.

### Anti-Pattern 4: Overloaded return types based on options

**What:** `Customer.create(params, raw: true)` returning sometimes `{:ok, %Customer{}}` and sometimes `{:ok, %Response{}}`.

**Why bad:** Official Elixir anti-pattern. Callers cannot pattern-match reliably.

**Instead:** Separate functions: `Customer.create/2` for decoded structs, provide raw response access through the Response struct's metadata fields or a separate function.

### Anti-Pattern 5: Deep module nesting mirroring Stripe's URL paths

**What:** `LatticeStripe.V1.Core.Customers.PaymentMethods.list/3` -- deeply nested modules following Stripe's API path structure.

**Why bad:** Verbose, hard to discover, hard to import. Stripe's URL hierarchy does not map cleanly to a good module hierarchy.

**Instead:** Flat-ish modules: `LatticeStripe.Customer`, `LatticeStripe.PaymentMethod`, `LatticeStripe.PaymentIntent`. Group by resource, not by URL path. Use subdirectories only for genuinely separate sub-domains (e.g., `LatticeStripe.Checkout.Session`).

## Suggested Build Order

The architecture has clear dependency layers. Build bottom-up:

### Phase 1: Foundation (no Stripe API calls yet)

Build the pure-functional core that everything else depends on. This phase produces no user-visible features but is the bedrock.

**Order within phase (strict dependencies):**

1. **Config** -- option validation schema (NimbleOptions). No dependencies.
2. **Request** -- request struct + form-encoding logic. No dependencies.
3. **Error** -- error structs + normalization from Stripe JSON error responses. No dependencies.
4. **Response** -- response struct + JSON decoding + error detection. Depends on: Error.
5. **Transport behaviour** -- behaviour definition only. Depends on: Request (for typespec).
6. **Transport.Finch** -- default adapter implementation. Depends on: Transport, Request.
7. **Client** -- config struct + request orchestration. Depends on: Config, Request, Response, Error, Transport.
8. **Retry** -- retry logic + backoff. Depends on: Response (to check status/headers). Called by Client.
9. **Telemetry** -- event definitions + emission helpers. No hard dependencies. Wired into Client.
10. **Pagination** -- cursor + search pagination + Stream. Depends on: Client, Response, List struct.

**Why this order:** Each layer depends only on layers above it. Request/Error/Response are pure data modules with no I/O. Transport is the I/O boundary. Client orchestrates everything. Pagination and Retry are features layered onto Client.

### Phase 2: First resource modules (validates the foundation)

Add the first Stripe resource to prove the architecture works end-to-end.

1. **List struct** -- wrapper for Stripe list responses (data, has_more, url).
2. **Customer** -- full CRUD + list + search. First resource module, validates the entire stack.
3. **PaymentIntent** -- create, retrieve, update, confirm, capture, cancel, list. Validates complex multi-step operations.

**Why this order:** Customer is the simplest complete resource. PaymentIntent validates the state-machine pattern. Together they prove the foundation handles real Stripe operations.

### Phase 3: Webhooks (independent from resources)

Can be built in parallel with Phase 2 resource modules.

1. **Webhook** -- signature verification + event parsing. Pure crypto, no HTTP needed.
2. **Event struct** -- Stripe Event representation.
3. **Webhook.Plug** -- Phoenix integration. Depends on: Webhook, Plug.

**Why this order:** Webhook verification is pure and self-contained. The Plug is a thin wrapper.

### Phase 4: Remaining Tier 1 resources

Straightforward once the pattern is established from Phase 2.

1. **SetupIntent** -- create, retrieve, update, confirm, cancel, list.
2. **PaymentMethod** -- create, retrieve, update, list, attach, detach.
3. **Refund** -- create, retrieve, update, list.
4. **Checkout.Session** -- create, retrieve, list, expire.

### Phase 5: Developer experience polish

1. **ExDoc** guides, module grouping, examples.
2. **Bang variants** for all resource functions.
3. **SearchResult struct** for search endpoints.
4. **Expand support** wired into all resource modules.

## Scalability Considerations

| Concern | At library launch | At 50+ resources | At v2 API support |
|---------|-------------------|-------------------|--------------------|
| Module count | ~20 modules, all hand-written | Consider code generation from OpenAPI | Separate v1/v2 namespaces |
| Test coverage | Integration tests against stripe-mock | Need fixture strategy for breadth | Separate test suites per API version |
| Connection pooling | Single Finch pool, default config | Per-Stripe-account pools for Connect | Same |
| Response types | Structs with optional fields | May need generated structs | Different struct shapes for v2 |
| Breaking changes | Pin to one Stripe API version | Version-aware response decoding | Explicit v1/v2 client methods |

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Client-as-struct, not GenServer | Pure functional, supports multi-tenancy, no bottleneck |
| Transport behaviour with Finch default | Decouples HTTP, enables testing, follows ExAws/Tesla pattern |
| Request-as-data structs | Testable, inspectable, composable -- standard Elixir SDK pattern |
| Flat module hierarchy | Discoverable, importable, avoids URL-path-mirroring trap |
| Hand-written resource modules (v1) | Quality over breadth, each module is polished and documented |
| Form-encoding in Request module | Stripe v1 uses form-encoded bodies, centralize this complexity |
| NimbleOptions for config validation | Ecosystem standard, generates docs, catches bad config early |
| Stream.resource for pagination | Idiomatic Elixir, lazy, composable -- a differentiator vs stripity_stripe |

## Sources

- [ExAws GitHub](https://github.com/ex-aws/ex_aws) -- behaviour-based SDK architecture pattern
- [Finch GitHub](https://github.com/sneako/finch) -- request-as-data, pool-based architecture
- [Req GitHub](https://github.com/wojtekmach/req) -- step pipeline, request struct pattern
- [stripity-stripe GitHub](https://github.com/beam-community/stripity-stripe) -- existing Stripe library structure
- [Andrea Leopardi: Breakdown of HTTP Clients in Elixir](https://andrealeopardi.com/posts/breakdown-of-http-clients-in-elixir/) -- HTTP client landscape
- [Application Layering Pattern](https://aaronrenner.io/2019/09/18/application-layering-a-pattern-for-extensible-elixir-application-design.html) -- extensible Elixir architecture
- [Elixir Official Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) -- avoid global config, prefer explicit APIs
- Project reference research: `prompts/elixir-best-practices-deep-research.md`, `prompts/elixir-opensource-libs-best-practices-deep-research.md`, `prompts/stripe-sdk-api-surface-area-deep-research.md`, `prompts/The definitive Stripe library gap in Elixir - a master research document.md`
