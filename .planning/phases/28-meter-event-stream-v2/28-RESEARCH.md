# Phase 28: meter_event_stream v2 - Research

**Researched:** 2026-04-16
**Domain:** Stripe v2 Billing Meter Event Stream (session-token authentication, dual-endpoint HTTP, Elixir SDK module design)
**Confidence:** HIGH

## Summary

Phase 28 adds `LatticeStripe.Billing.MeterEventStream` — a self-contained v2 module that enables high-throughput meter event reporting via Stripe's session-token authenticated API. The core architectural novelty is that Stripe's v2 event stream uses a **different base host** (`meter-events.stripe.com`) and a **different auth model** (short-lived session token in Bearer header, not the API key). This makes it architecturally impossible to reuse `Client.request/2` for the send-events step — the module must build its own HTTP request and call `client.transport.request/1` directly.

The two-step contract is well-established across all official Stripe SDKs (Ruby, Node, Python, .NET, Go) and is identical in each: (1) POST to `api.stripe.com/v2/billing/meter_event_session` with the API key to obtain a short-lived `authentication_token` (valid 15 minutes), then (2) POST to `meter-events.stripe.com/v2/billing/meter_event_stream` with that token as the Bearer credential and an `events` array in the JSON body.

A critical blocker has been confirmed by live probe: **stripe-mock does not support v2 endpoints**. Both `/v2/billing/meter_event_session` and `/v2/billing/meter_event_stream` return 404 "Unrecognized request URL" from the running stripe-mock instance. Integration tests must use Mox with `@tag :skip` + explanatory comment for the stripe-mock-dependent test file.

**Primary recommendation:** Build two public functions (`create_session/2`, `send_events/4`) that directly call `client.transport.request/1` with appropriate headers. Session struct fields are `id`, `object`, `authentication_token`, `created`, `expires_at`, `livemode`. The event stream POST uses JSON body (not form-encoded), which requires special handling since `Client.request/2` uses form encoding throughout the rest of the SDK.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Stateless session management — no GenServer, no process state. `create_session/2` returns a `%MeterEventStream.Session{}` struct with `token` and `expires_at` fields. Callers hold the session struct and pass it to `send_events/3`.
- **D-02:** Reuse the existing `Transport` behaviour for HTTP. `MeterEventStream` builds its own v2-specific headers and calls through `client.transport.request/1` directly.
- **D-03:** The v2 base URL may differ from v1. Research phase must confirm the exact endpoint URL and base. Module constructs the full URL independently of `client.base_url` if v2 endpoint has a different host.
- **D-04:** Two public functions — `MeterEventStream.create_session(client, opts \\ [])` and `MeterEventStream.send_events(client, session, events, opts \\ [])`.
- **D-05:** Session struct: `%MeterEventStream.Session{token: String.t(), expires_at: DateTime.t() | integer(), authentication_token: String.t()}` — exact fields based on Stripe's session creation response. Research phase must confirm exact response shape.
- **D-06:** Client-side expiry check before sending — `send_events/3` checks `session.expires_at` against current time and returns `{:error, :session_expired}` immediately if expired. Server-side session-expired errors normalize to `{:error, :session_expired}`. No automatic session renewal.
- **D-07:** Events validation — `send_events/3` validates that events list is non-empty. Each event shape mirrors `MeterEvent.create/3` params.
- **D-08:** Emit telemetry events for both session creation and event sending, distinct from standard `[:lattice_stripe, :request, *]` events.
- **D-09:** Research phase must probe stripe-mock for v2 endpoint support. If not supported: unit tests via Mox, integration test file with `@tag :skip`. Do not block phase on stripe-mock v2 support.

### Claude's Discretion

- Internal module organization (whether Session struct lives in a nested module or inline)
- Exact telemetry metadata fields
- Whether to include a convenience `with_session/3` function
- Documentation structure within `@doc` and whether to create `guides/meter-event-stream.md` or fold into existing `guides/metering.md`

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FEAT-02 | Developer can send high-throughput meter events via `LatticeStripe.Billing.MeterEventStream` using Stripe's v2 session-token API (create session, send events, handle expiry) | Verified endpoint URLs, auth scheme, session struct fields, error codes, and testing strategy below |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Session creation | API / Backend (Elixir SDK module) | — | POST to api.stripe.com/v2/billing/meter_event_session with API key; pure HTTP |
| Event batch sending | API / Backend (Elixir SDK module) | — | POST to meter-events.stripe.com/v2/billing/meter_event_stream with session token; separate host |
| Session expiry check | API / Backend (Elixir SDK module) | — | Client-side DateTime.compare before network call; fast path, saves round-trip |
| Telemetry emission | API / Backend (Elixir SDK module) | — | Same telemetry pattern as existing request spans; module-local implementation |
| Session struct storage | Caller's process (application layer) | — | Stateless SDK; caller holds `%Session{}` struct explicitly |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `LatticeStripe.Transport` behaviour | (project) | HTTP request execution — auth-agnostic | Transport contract takes a plain map with method/url/headers/body; MeterEventStream builds its own header set and calls `client.transport.request/1` directly [VERIFIED: codebase read] |
| `Jason` | ~> 1.4 | JSON encoding for event body | The v2 event stream POST body is `Content-Type: application/json` (unlike v1 form-encoded) — `client.json_codec.encode/1` must be used [VERIFIED: Stripe API docs] |
| `:telemetry` | ~> 1.0 | Span emission for create_session and send_events | Project-wide observability standard; emit span events distinct from `[:lattice_stripe, :request, *]` [VERIFIED: codebase read] |
| `LatticeStripe.Error` | (project) | Normalized error struct | All SDK errors use the same `%Error{}` type; v2 errors normalize to this [VERIFIED: codebase read] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `DateTime` | (stdlib) | Session expiry comparison | `DateTime.compare/2` for client-side expiry check in `send_events/4` [VERIFIED: Elixir stdlib] |
| `Mox` | ~> 1.2 | Transport mock for unit tests | Existing pattern in the project; mock `LatticeStripe.Transport` to simulate session create + event send without real HTTP [VERIFIED: codebase read] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct `client.transport.request/1` | `Client.request/2` | `Client.request/2` hardcodes Bearer + form encoding + v1 base URL — none of these apply to v2. Direct transport call is the only viable approach. |
| Mox for integration tests | stripe-mock | stripe-mock does NOT support v2 endpoints (confirmed by live probe — 404 on both `/v2/billing/meter_event_session` and `/v2/billing/meter_event_stream`). Mox is the integration test strategy. |
| JSON body for event send | Form-encoded body | Stripe's v2 event stream endpoint requires `Content-Type: application/json` with a JSON body — not form-encoded. The existing `FormEncoder` is NOT used here. |

## Architecture Patterns

### System Architecture Diagram

```
Caller
  │
  ├─── MeterEventStream.create_session(client, opts)
  │         │
  │         │  POST api.stripe.com/v2/billing/meter_event_session
  │         │  Authorization: Bearer {api_key}
  │         │  Content-Type: application/json
  │         │  Stripe-Version: {api_version}
  │         │
  │         ├── client.transport.request/1
  │         │       └── Finch → Stripe API
  │         │
  │         ├── Decode JSON response
  │         │       └── %Session{id, authentication_token, expires_at, livemode}
  │         │
  │         └── {:ok, %Session{}} | {:error, %Error{}}
  │
  └─── MeterEventStream.send_events(client, session, events, opts)
            │
            ├── Client-side expiry check:
            │     expires_at < now? → {:error, :session_expired}
            │
            ├── Validate events list non-empty → {:error, %Error{}} if empty
            │
            │  POST meter-events.stripe.com/v2/billing/meter_event_stream
            │  Authorization: Bearer {session.authentication_token}
            │  Content-Type: application/json
            │  Stripe-Version: {api_version}
            │
            ├── client.transport.request/1
            │       └── Finch → meter-events.stripe.com
            │
            ├── Decode response:
            │   ├── 200 {}            → {:ok, %{}}
            │   ├── 401 billing_meter_event_session_expired → {:error, :session_expired}
            │   └── other 4xx/5xx     → {:error, %Error{}}
            │
            └── {:ok, map()} | {:error, :session_expired} | {:error, %Error{}}
```

### Recommended Project Structure

```
lib/lattice_stripe/billing/
├── meter_event_stream.ex             # Main module — create_session/2, send_events/4
└── meter_event_stream/
    └── session.ex                    # %MeterEventStream.Session{} struct + from_map/1

test/lattice_stripe/billing/
├── meter_event_stream_test.exs       # Unit tests via Mox
└── meter_event_stream_integration_test.exs  # @tag :skip (stripe-mock v2 not supported)
```

The nested `session.ex` is Claude's discretion per D-05, but the nested module pattern is consistent with existing project conventions (e.g., `Billing.MeterEventAdjustment.Cancel`, `BillingPortal.Session.FlowData`).

### Pattern 1: Session Creation via Direct Transport Call

The module bypasses `Client.request/2` entirely. Build the HTTP request map manually, call `client.transport.request/1`, then decode with `client.json_codec.decode/1`.

```elixir
# Source: VERIFIED pattern from codebase transport.ex + Stripe API docs
defp do_create_session(client, opts) do
  url = "https://api.stripe.com/v2/billing/meter_event_session"
  
  headers = [
    {"authorization", "Bearer #{client.api_key}"},
    {"stripe-version", client.api_version},
    {"content-type", "application/json"},
    {"accept", "application/json"},
    {"user-agent", "LatticeStripe/#{@version} elixir/#{System.version()}"}
  ]

  transport_request = %{
    method: :post,
    url: url,
    headers: headers,
    body: "{}",  # No parameters for session creation
    opts: [finch: client.finch, timeout: Keyword.get(opts, :timeout, client.timeout)]
  }

  case client.transport.request(transport_request) do
    {:ok, %{status: 200, body: body}} ->
      case client.json_codec.decode(body) do
        {:ok, map} -> {:ok, Session.from_map(map)}
        {:error, _} -> {:error, %Error{type: :api_error, message: "Non-JSON response"}}
      end
    {:ok, %{status: status, body: body}} ->
      {:error, decode_error(status, body, client)}
    {:error, reason} ->
      {:error, %Error{type: :connection_error, message: inspect(reason)}}
  end
end
```

### Pattern 2: Event Sending — Different Host, Session Token Auth

```elixir
# Source: VERIFIED endpoint from Stripe API docs
@stream_url "https://meter-events.stripe.com/v2/billing/meter_event_stream"

defp do_send_events(client, session, events, opts) do
  headers = [
    {"authorization", "Bearer #{session.authentication_token}"},
    {"stripe-version", client.api_version},
    {"content-type", "application/json"},
    {"accept", "application/json"},
    {"user-agent", "LatticeStripe/#{@version} elixir/#{System.version()}"}
  ]

  body = client.json_codec.encode!(%{"events" => serialize_events(events)})

  transport_request = %{
    method: :post,
    url: @stream_url,
    headers: headers,
    body: body,
    opts: [finch: client.finch, timeout: Keyword.get(opts, :timeout, client.timeout)]
  }

  case client.transport.request(transport_request) do
    {:ok, %{status: 200, body: body}} ->
      case client.json_codec.decode(body) do
        {:ok, result} -> {:ok, result}
        {:error, _} -> {:ok, %{}}  # 200 with no/empty body is valid
      end
    {:ok, %{status: 401, body: body}} ->
      handle_401(body, client)
    {:ok, %{status: status, body: body}} ->
      {:error, decode_error(status, body, client)}
    {:error, reason} ->
      {:error, %Error{type: :connection_error, message: inspect(reason)}}
  end
end
```

### Pattern 3: Session Expiry Check

```elixir
# Source: VERIFIED pattern from stripe-ruby, stripe-node, stripe-dotnet examples
defp check_expiry(%Session{expires_at: expires_at}) when is_integer(expires_at) do
  now = System.system_time(:second)
  if expires_at <= now, do: :expired, else: :valid
end
```

Stripe returns `expires_at` as a Unix timestamp integer. The CONTEXT.md D-05 mentions `DateTime.t() | integer()` — keep it as integer (matches Stripe wire format and existing project convention in MeterEvent where `timestamp`, `created` are integers).

### Pattern 4: Session-Expired Error Normalization

```elixir
# Source: VERIFIED from Stripe API docs — 401 with billing_meter_event_session_expired
defp handle_401(body, client) do
  case client.json_codec.decode(body) do
    {:ok, %{"error" => %{"code" => "billing_meter_event_session_expired"}}} ->
      {:error, :session_expired}
    {:ok, decoded} ->
      {:error, Error.from_response(401, decoded, nil)}
    {:error, _} ->
      {:error, %Error{type: :authentication_error, status: 401, message: "Unauthorized"}}
  end
end
```

### Pattern 5: Telemetry Span (matching existing project pattern)

```elixir
# Source: VERIFIED from lib/lattice_stripe/telemetry.ex — request_span pattern
defp session_span(client, fun) do
  if client.telemetry_enabled do
    :telemetry.span(
      [:lattice_stripe, :meter_event_stream, :create_session],
      %{},
      fn ->
        result = fun.()
        stop_meta = %{status: (if match?({:ok, _}, result), do: :ok, else: :error)}
        {result, stop_meta}
      end
    )
  else
    fun.()
  end
end
```

### Pattern 6: Session Struct

```elixir
# Source: VERIFIED from Stripe API docs (session/create response shape)
defmodule LatticeStripe.Billing.MeterEventStream.Session do
  @type t :: %__MODULE__{
    id: String.t() | nil,
    object: String.t() | nil,
    authentication_token: String.t() | nil,
    created: integer() | nil,
    expires_at: integer() | nil,
    livemode: boolean() | nil
  }
  
  defstruct [:id, :object, :authentication_token, :created, :expires_at, :livemode]
  
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      authentication_token: map["authentication_token"],
      created: map["created"],
      expires_at: map["expires_at"],
      livemode: map["livemode"]
    }
  end
end
```

Note on D-05 field naming: CONTEXT.md D-05 mentions `token` as a field, but the Stripe wire format uses `authentication_token`. The struct should use `authentication_token` to match the wire format (no translation layer needed in `from_map/1`). The CONTEXT.md description "`token` and `expires_at`" was speculative pre-research — `authentication_token` is the correct field name. [VERIFIED: Stripe API docs, confirmed by multiple SDK examples]

### Anti-Patterns to Avoid

- **Using `Client.request/2` for send_events**: `Client.request/2` uses Bearer API key, form encoding, `client.base_url` — none of which apply to the v2 stream endpoint. Always call `client.transport.request/1` directly.
- **Hardcoding `"https://api.stripe.com"` for the stream endpoint**: The session creation uses `api.stripe.com` but event streaming uses `meter-events.stripe.com`. These are different hosts. Hardcode both as module constants, not from `client.base_url`.
- **Form-encoding the event body**: The v2 endpoint requires `Content-Type: application/json` with a JSON body. The existing `FormEncoder` module MUST NOT be used for this endpoint.
- **Storing session in a GenServer**: PROJECT.md philosophy is "processes only when truly needed." Callers hold the `%Session{}` struct explicitly.
- **Automatic session refresh in `send_events/4`**: No hidden state mutations. Return `{:error, :session_expired}` and let the caller call `create_session/2` again.
- **Reusing the `@tag :integration` label for Mox-based tests**: Unit tests with Mox should run normally (not skip). Only the stripe-mock integration test file gets `@tag :skip`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON encoding of event body | Custom serializer | `client.json_codec.encode!/1` | Already injected in client; keeps codec behaviour consistent |
| Session expiry timestamp comparison | Custom time math | `System.system_time(:second)` vs `expires_at` | Simple integer comparison; no library needed |
| Transport HTTP dispatch | Custom Finch call | `client.transport.request/1` | Transport behaviour is auth-agnostic; exactly the right abstraction for this use case |
| Error struct creation | Custom error map | `LatticeStripe.Error.from_response/3` | Existing error normalization handles Stripe's error body format |

**Key insight:** The Transport behaviour's auth-agnostic design was specifically intended to support non-standard auth flows like this one. This is the correct architectural seam.

## Critical Findings (CONFIRMED by Research)

### D-03 Resolution: Endpoint URLs

Two separate hosts are confirmed. [VERIFIED: Stripe API docs — fetched directly]

| Step | URL | Auth Header |
|------|-----|-------------|
| 1. Create session | `POST https://api.stripe.com/v2/billing/meter_event_session` | `Authorization: Bearer {api_key}` |
| 2. Send events | `POST https://meter-events.stripe.com/v2/billing/meter_event_stream` | `Authorization: Bearer {authentication_token}` |

Both require `Stripe-Version` header and `Content-Type: application/json`.

### D-05 Resolution: Session Struct Fields

Stripe's `POST /v2/billing/meter_event_session` returns: [VERIFIED: Stripe API docs]

```json
{
  "id": "mes_...",
  "object": "v2.billing.meter_event_session",
  "authentication_token": "...",
  "created": 1712345678,
  "expires_at": 1712346578,
  "livemode": false
}
```

Session TTL: **15 minutes** from creation. [VERIFIED: Stripe API docs, multiple SDK examples]

Key correction to D-05: The field is `authentication_token`, not `token`. The struct should use `authentication_token` as the primary field name.

### D-09 Resolution: stripe-mock Does NOT Support v2 Endpoints

Live probe against running stripe-mock instance (localhost:12111): [VERIFIED: live curl probe]

```
POST /v2/billing/meter_event_session → 404
  {"error": {"message": "Unrecognized request URL", "type": "invalid_request_error"}}

POST /v2/billing/meter_event_stream → 404
  {"error": {"message": "Unrecognized request URL", "type": "invalid_request_error"}}
```

stripe-mock is powered by Stripe's OpenAPI spec but the v2 meter stream endpoints (hosted on `meter-events.stripe.com`) are not present in the OpenAPI spec that stripe-mock serves.

**Testing strategy consequence:**
- Unit tests: Mox mocking `LatticeStripe.Transport` — fully exercised, no skip
- Integration test file: `@tag :skip` with comment: `"stripe-mock does not support v2 billing endpoints (meter_event_session, meter_event_stream). Test shape verified via Mox in unit tests."`

### Body Encoding Difference: JSON not Form-Encoded

All existing resource modules use form-encoded bodies via `FormEncoder`. The v2 event stream uses JSON. Two implications:

1. Session creation POST: Empty JSON body `"{}"` (no parameters)
2. Event send POST: JSON body `{"events": [...]}` encoded with `client.json_codec.encode!/1`

This means the content-type header must be `application/json` (not `application/x-www-form-urlencoded`).

### Event Shape

Events in the `events` array for the stream endpoint: [VERIFIED: Stripe API docs]

```json
{
  "event_name": "string (required)",
  "payload": {"stripe_customer_id": "...", "value": "..."} (required),
  "identifier": "string (optional, UUID recommended)",
  "timestamp": "ISO 8601 string or Unix integer (optional)"
}
```

Batch limit: **up to 100 events per request**. Timestamp window: past 35 days or up to 5 minutes in the future.

Note: While v1 `MeterEvent.create/3` uses integer timestamps in the payload, the v2 stream may accept either ISO 8601 strings or integers. Recommend accepting both and passing through unchanged (let Stripe validate), consistent with the project's "don't over-validate" philosophy.

### Session-Expired Error Code

Stripe returns HTTP 401 with error code `"billing_meter_event_session_expired"` when the session token has expired server-side (e.g., clock skew). [VERIFIED: Stripe API docs]

## Common Pitfalls

### Pitfall 1: Using client.base_url for the Stream Endpoint

**What goes wrong:** `client.base_url` is `"https://api.stripe.com"`. If you build the event stream URL from `client.base_url`, you'll POST to `api.stripe.com/v2/billing/meter_event_stream` instead of `meter-events.stripe.com/v2/billing/meter_event_stream`. Stripe will return 404.

**Why it happens:** `Client.request/2` always prepends `client.base_url` to the path. The natural instinct is to follow that pattern.

**How to avoid:** Define `@stream_url` and `@session_url` as module-level constants with the full hardcoded URLs. Do not construct them from `client.base_url`.

**Warning signs:** HTTP 404 or "Unrecognized request URL" errors in tests or production.

### Pitfall 2: Form-Encoding the Event Body

**What goes wrong:** Using `FormEncoder.encode/1` for the event body produces `application/x-www-form-urlencoded` format. The v2 endpoint requires `application/json`. Stripe will reject the request or return malformed-body errors.

**Why it happens:** Every other module in the SDK uses `FormEncoder`. The v2 endpoint is the only exception.

**How to avoid:** Use `client.json_codec.encode!/1` (or `encode/1`) for the body. Set `Content-Type: application/json` explicitly in headers.

**Warning signs:** HTTP 400 with "invalid_request_error" or missing-parameter errors when events is non-empty.

### Pitfall 3: Wrong Auth Header for send_events

**What goes wrong:** Using `"Bearer #{client.api_key}"` for the stream endpoint instead of `"Bearer #{session.authentication_token}"`. You'll get 401 Unauthorized.

**Why it happens:** All other module calls use `client.api_key`. It's the wrong credential for the session-protected endpoint.

**How to avoid:** The session creation step uses `client.api_key`. The event stream step uses `session.authentication_token`. These are different.

**Warning signs:** HTTP 401 in tests or production for `send_events`.

### Pitfall 4: expires_at Integer vs DateTime Mismatch

**What goes wrong:** If you store `expires_at` as a `DateTime.t()` in the struct but Stripe returns an integer Unix timestamp, `from_map/1` will store the raw integer without conversion. Code that calls `DateTime.compare/2` will crash with a type error.

**Why it happens:** D-05 mentions `DateTime.t() | integer()` as a union type. Pre-research uncertainty.

**How to avoid:** Keep `expires_at` as an integer in the struct (consistent with existing project conventions — `MeterEvent.timestamp` and `MeterEvent.created` are integers). Expiry check: compare with `System.system_time(:second)` directly.

**Warning signs:** FunctionClauseError or ArgumentError in expiry check when `expires_at` is unexpectedly an integer.

### Pitfall 5: Empty Body vs nil for Session Creation POST

**What goes wrong:** Passing `body: nil` to `transport.request/1` for session creation. Some transports/proxies handle nil body differently than an empty string for POST requests.

**Why it happens:** nil is the conventional "no body" value for GET requests in the Transport contract.

**How to avoid:** For session creation, pass `body: "{}"` (empty JSON object string). This ensures `Content-Type: application/json` is consistent with the body.

**Warning signs:** Transport-level errors or Stripe returning unexpected parse errors.

### Pitfall 6: Race Between Client-Side Expiry Check and Network Latency

**What goes wrong:** Session passes the client-side expiry check (>0 seconds remaining) but by the time the HTTP request reaches Stripe, the token has expired. Stripe returns 401 with `billing_meter_event_session_expired`.

**Why it happens:** There's a narrow window in the last few seconds of a session's life where the client thinks it's valid but the server disagrees.

**How to avoid:** Always normalize Stripe's 401 `billing_meter_event_session_expired` response to `{:error, :session_expired}` (D-06 already covers this). Do not add a pre-emptive buffer to the expiry check — it complicates testing and is unnecessary since the server error is already normalized.

**Warning signs:** `{:error, :session_expired}` appearing unexpectedly when expires_at still shows time remaining.

## Code Examples

Verified patterns from official sources:

### Session Creation — Full Function Signature

```elixir
# Source: VERIFIED - based on Stripe API docs + existing codebase patterns
@spec create_session(Client.t(), keyword()) ::
  {:ok, Session.t()} | {:error, Error.t()}
def create_session(%Client{} = client, opts \\ []) do
  # Telemetry span wraps the HTTP call
  # URL: https://api.stripe.com/v2/billing/meter_event_session
  # Auth: Bearer {client.api_key}
  # Body: "{}" (empty JSON, no params required)
  # Content-Type: application/json
end
```

### send_events — Full Function Signature

```elixir
# Source: VERIFIED - Stripe API docs show events array with 100-event limit
@spec send_events(Client.t(), Session.t(), [map()], keyword()) ::
  {:ok, map()} | {:error, :session_expired} | {:error, Error.t()}
def send_events(%Client{} = client, %Session{} = session, events, opts \\ [])
    when is_list(events) do
  # 1. Check non-empty
  # 2. Client-side expiry check
  # 3. POST https://meter-events.stripe.com/v2/billing/meter_event_stream
  # Auth: Bearer {session.authentication_token}
  # Body: JSON {"events": [...]}
end
```

### Mox Test Pattern — Session Create

```elixir
# Source: VERIFIED - existing Mox patterns in test/support/test_helpers.ex
test "create_session/2 returns session struct on success", %{client: client} do
  session_response = %{
    "id" => "mes_123",
    "object" => "v2.billing.meter_event_session",
    "authentication_token" => "sk_live_session_token_abc",
    "created" => 1_712_345_678,
    "expires_at" => 1_712_346_578,  # +900 seconds (15 min)
    "livemode" => false
  }

  expect(LatticeStripe.MockTransport, :request, fn %{
    url: "https://api.stripe.com/v2/billing/meter_event_session",
    method: :post
  } ->
    {:ok, %{status: 200, headers: [], body: Jason.encode!(session_response)}}
  end)

  assert {:ok, %Session{authentication_token: "sk_live_session_token_abc"}} =
    MeterEventStream.create_session(client)
end
```

### Mox Test Pattern — Session Expired (server-side)

```elixir
# Source: VERIFIED - Stripe error code from API docs
test "send_events/4 returns :session_expired on 401", %{client: client} do
  session = %Session{
    authentication_token: "expired_token",
    expires_at: System.system_time(:second) + 60  # still looks valid client-side
  }

  error_body = %{
    "error" => %{"type" => "invalid_request_error", "code" => "billing_meter_event_session_expired"}
  }

  expect(LatticeStripe.MockTransport, :request, fn %{
    url: "https://meter-events.stripe.com/v2/billing/meter_event_stream"
  } ->
    {:ok, %{status: 401, headers: [], body: Jason.encode!(error_body)}}
  end)

  events = [%{"event_name" => "api_call", "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"}}]

  assert {:error, :session_expired} = MeterEventStream.send_events(client, session, events)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| v1 `POST /v1/billing/meter_events` (form-encoded, sync, single event) | v2 `POST /v2/billing/meter_event_stream` (JSON, async, batch up to 100 events, session-token auth) | 2024-09-30 (acacia API version) | 100x throughput; session-token model adds a mandatory session-creation step |
| API key for every meter event request | Short-lived session token for event stream, API key only for session creation | 2024-09-30 | Reduces API key exposure on high-throughput paths; token expires in 15 min |

**Note on v1 vs v2 coexistence:** Both endpoints exist simultaneously. v1 (`/v1/billing/meter_events`) is still supported. v2 is additive — higher throughput but different auth model. LatticeStripe already ships v1 via `Billing.MeterEvent.create/3`. Phase 28 adds v2 as a separate module.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `expires_at` is returned as a Unix integer (not ISO 8601 string) by session creation | Session Struct pattern | `from_map/1` expiry check would need to parse a string first; low risk since other Stripe timestamps are integers |
| A2 | The v2 event stream accepts events with integer `timestamp` fields (not just ISO 8601 strings) | Event Shape section | Events with integer timestamps would be rejected; medium risk — official docs show ISO 8601 in examples |
| A3 | `client.json_codec.encode!/1` is available (not just `encode/1`) | Code Examples | Would need to use `encode/1` and handle `{:error, _}` tuple instead |

## Open Questions

1. **Integer vs ISO 8601 timestamp in event payload**
   - What we know: Stripe v1 `MeterEvent.create/3` uses integer Unix timestamps in payload. Stripe v2 docs show ISO 8601 strings in examples.
   - What's unclear: Does the v2 stream endpoint accept integer timestamps, ISO 8601 strings, or both?
   - Recommendation: Accept both formats from callers and pass through unchanged. Stripe's validation will catch invalid formats. Document that integers (Unix seconds) are the recommended format for consistency with v1.

2. **should `send_events` return `{:ok, [result]}` or `{:ok, %{}}`**
   - What we know: The Stripe docs show the stream endpoint returns an empty JSON object `{}` on success.
   - What's unclear: CONTEXT.md D-04 mentions `{:ok, results}` which implies a meaningful list — but Stripe's API returns nothing.
   - Recommendation: Return `{:ok, %{}}` (the decoded empty JSON response). Document that the v2 stream is fire-and-forget (similar to v1 `MeterEvent.create/3` which returns the event back, but v2 stream has no per-event response).

3. **User-agent header completeness**
   - What we know: `Client.request/2` sends `x-stripe-client-user-agent` JSON header with bindings_version, lang, etc.
   - What's unclear: Whether MeterEventStream should replicate the full user-agent setup.
   - Recommendation: Include the same `user-agent` header as `Client.build_headers/5`. Omit `x-stripe-client-user-agent` unless simple to add — the JSON-encoding is done via `Jason.encode!/1` directly in `Client.client_user_agent_json/0` which is private. Expose a module attribute or helper.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stripe-mock (localhost:12111) | Integration tests | Partial | v0.197.0 | Mox for all v2 tests |
| `Jason` | JSON body encoding | Yes | ~> 1.4 | — |
| `Finch` via `client.finch` | HTTP transport | Yes | ~> 0.21 | Any Transport impl |
| `meter-events.stripe.com` | Production send_events | Network-dependent | — | N/A (production only) |

**stripe-mock v2 endpoint status:** CONFIRMED NOT SUPPORTED. Both `/v2/billing/meter_event_session` and `/v2/billing/meter_event_stream` return 404 from stripe-mock v0.197.0. stripe-mock serves v1 API endpoints only (its OpenAPI spec does not include the `meter-events.stripe.com` host).

**Missing dependencies with no fallback:** None that block development. All unit tests use Mox.

**Missing dependencies with fallback:** stripe-mock v2 endpoints → use Mox.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FEAT-02a | `create_session/2` returns `{:ok, %Session{}}` with correct fields | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02b | `create_session/2` returns `{:error, %Error{}}` on HTTP failure | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02c | `send_events/4` returns `{:error, :session_expired}` for expired session (client-side) | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02d | `send_events/4` returns `{:error, :session_expired}` on server 401 with billing_meter_event_session_expired | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02e | `send_events/4` returns `{:ok, %{}}` on successful batch send | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02f | `send_events/4` returns error when events list is empty | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02g | Session creation uses correct URL (`api.stripe.com`) and API key auth | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02h | Event send uses correct URL (`meter-events.stripe.com`) and session token auth | unit | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |
| FEAT-02i | Integration lifecycle test (stripe-mock skip) | integration (skip) | (skipped — stripe-mock no v2 support) | ❌ Wave 0 |
| FEAT-02j | `@doc` documents two-step auth model and that Client.request/2 is NOT used | doc_test / manual | `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/billing/meter_event_stream_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/billing/meter_event_stream_test.exs` — covers FEAT-02a through FEAT-02j
- [ ] `test/lattice_stripe/billing/meter_event_stream_integration_test.exs` — covers FEAT-02i with `@tag :skip`
- [ ] `test/support/fixtures/metering.ex` — add `MeterEventStream.Session.basic/1` fixture
- [ ] `lib/lattice_stripe/billing/meter_event_stream.ex` — main module (Wave 1)
- [ ] `lib/lattice_stripe/billing/meter_event_stream/session.ex` — Session struct (Wave 1)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Session token is short-lived (15 min TTL); no long-lived credentials on stream path |
| V3 Session Management | Yes | Stateless — `%Session{}` struct held by caller; no server-side session state in SDK |
| V4 Access Control | No | SDK does not enforce Stripe ACLs |
| V5 Input Validation | Yes | Non-empty events list check; event params passed through to Stripe for validation |
| V6 Cryptography | No | No crypto hand-rolled; authentication tokens are opaque strings from Stripe |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Session token leaked in logs | Information Disclosure | `Inspect` protocol implementation for `%Session{}` — mask `authentication_token` field (same pattern as `MeterEvent` masks `payload`) |
| Expired session token reuse | Spoofing | Client-side `expires_at` check before every `send_events/4` call; server-side 401 normalized to `{:error, :session_expired}` |
| API key exposure on high-volume path | Information Disclosure | v2 design intentionally minimizes API key usage — only used for session creation, not per-event requests |

**PII note:** `Inspect` protocol for `%Session{}` MUST mask `authentication_token`. This is the primary security requirement for the struct. Pattern mirrors `MeterEvent`'s payload masking.

## Sources

### Primary (HIGH confidence)

- Stripe API docs (WebFetch) — `POST /v2/billing/meter_event_session`: URL, auth, response shape, TTL
- Stripe API docs (WebFetch) — `POST /v2/billing/meter_event_stream`: URL, auth, event format, limits
- Live probe (Bash curl) — stripe-mock v0.197.0 returns 404 for both v2 endpoints: CONFIRMED unsupported
- Codebase read — `lib/lattice_stripe/transport.ex`, `lib/lattice_stripe/client.ex`, `lib/lattice_stripe/billing/meter_event.ex`, `lib/lattice_stripe/telemetry.ex`, `test/support/test_helpers.ex`

### Secondary (MEDIUM confidence)

- [stripe-ruby example](https://github.com/stripe/stripe-ruby/blob/master/examples/meter_event_stream.rb) — session creation flow, `refresh_meter_event_session` pattern, expiry check
- [stripe-node example](https://github.com/stripe/stripe-node/blob/master/examples/snippets/meter_event_stream.ts) — TypeScript implementation confirming session token used as new client credential
- [stripe-dotnet example](https://github.com/stripe/stripe-dotnet/blob/master/src/Examples/V2/MeterEventStream.cs) — C# implementation confirming `AuthenticationToken` field name and new-client pattern

### Tertiary (LOW confidence)

- WebSearch summaries (unverified) — stripe-mock version and general API description

## Metadata

**Confidence breakdown:**

- Endpoint URLs and auth scheme: HIGH — verified via direct WebFetch from official Stripe docs + live stripe-mock probe
- Session struct fields: HIGH — verified via official docs; corrects CONTEXT.md D-05 speculation
- stripe-mock support status: HIGH — verified by live curl probe (404 confirmed)
- Architecture patterns: HIGH — based on codebase read of existing Transport/Client/Telemetry
- Event shape: MEDIUM — verified from docs; timestamp format (integer vs ISO 8601) still uncertain

**Research date:** 2026-04-16
**Valid until:** 2026-07-16 (stable Stripe v2 API; stripe-mock support status may change if they add v2 endpoints)
