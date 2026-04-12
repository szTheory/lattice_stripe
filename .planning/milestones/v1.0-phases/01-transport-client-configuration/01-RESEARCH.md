# Phase 1: Transport & Client Configuration - Research

**Researched:** 2026-03-31
**Domain:** Elixir HTTP transport abstraction, client configuration, JSON codec, form encoding
**Confidence:** HIGH

## Summary

Phase 1 is the foundation layer for LatticeStripe. It delivers the HTTP transport behaviour (with Finch default adapter), the client configuration struct (validated by NimbleOptions), Stripe-compatible form encoding, JSON codec abstraction, basic error struct, and telemetry wiring. No Stripe resource modules yet -- this phase proves that a configured client can make authenticated, form-encoded HTTP requests through a swappable transport.

The decisions from CONTEXT.md are thorough and well-aligned with Elixir ecosystem conventions. The key technical challenges are: (1) correct recursive form encoding for Stripe's nested param format, (2) wiring NimbleOptions validation into both `new/1` and `new!/1` constructors, (3) designing the Transport behaviour callback to be narrow enough for easy implementation but complete enough for the Finch adapter, and (4) integrating `:telemetry.span/3` into the request path from day one.

**Primary recommendation:** Build bottom-up in strict dependency order: JSON codec behaviour, form encoder, error struct, request struct, transport behaviour, Finch adapter, NimbleOptions config, client module with telemetry. Each module is independently testable with pure unit tests before the client wires them together.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Explicit client struct only. `LatticeStripe.Client.new!(api_key: "sk_test_...")` returns a validated struct. The library NEVER reads `Application.get_env`.
- **D-02:** Provide both `new!/1` (raises on invalid config) and `new/1` (returns `{:ok, client} | {:error, error}`).
- **D-03:** Multiple independent clients can coexist in the same BEAM VM. No singleton, no global state.
- **D-04:** Request struct pipeline pattern (inspired by ExAws). Resource modules build a `%LatticeStripe.Request{}` data struct, then `Client.request/2` dispatches it through the transport.
- **D-05:** The `%Request{}` struct holds: method, path, params, opts. Pure data with no side effects.
- **D-06:** User manages the Finch pool. User adds `{Finch, name: MyApp.Finch}` to their supervision tree, then passes `finch: MyApp.Finch` to `Client.new!`. Library does not start processes.
- **D-07:** Single `request/1` callback receiving a plain map (`%{method, url, headers, body, opts}`), returning `{:ok, %{status, headers, body}} | {:error, term()}`.
- **D-08:** Default adapter: `LatticeStripe.Transport.Finch`. Users can swap by implementing the behaviour and passing `transport: MyAdapter` to `Client.new!`.
- **D-09:** Phase 1 ships a basic `%LatticeStripe.Error{}` struct with fields: type, code, message, status, request_id. Pattern-matchable via `:type` atom field.
- **D-10:** Phase 2 enriches errors with bang variants, retry logic, idempotency handling, richer context, pluggable retry strategy.
- **D-11:** Custom form encoder (~40 lines). Handles nested maps, arrays, deeply nested params.
- **D-12:** Typed structs with catch-all `extra` field. Plain maps for un-typed nested objects.
- **D-13:** Phase 1 response decoding returns decoded JSON maps. Typed response structs come in Phase 4.
- **D-14:** NimbleOptions validates all client options at creation time.
- **D-15:** JSON codec behaviour with Jason as default. Minimal interface: `encode!/1` and `decode!/1`.
- **D-16:** Wire `:telemetry.span/3` into `Client.request/2` from Phase 1. Emits `[:lattice_stripe, :request, :start/:stop/:exception]`.
- **D-17:** Flat resource modules. Behaviours in top-level files, adapters in sub-directories.
- **D-18:** Phase 1 tests are Layer 1 (pure unit) and Layer 2 (Mox-based transport mock). All `async: true`.
- **D-19:** Runtime deps: Finch ~> 0.19, Jason ~> 1.4, :telemetry ~> 1.0, NimbleOptions ~> 1.0. Dev: Mox ~> 1.2, ExDoc ~> 0.34, Credo ~> 1.7.

### Claude's Discretion
- Exact User-Agent header string format
- Stripe API version string to pin (use current stable)
- Internal helper function organization within modules
- Exact NimbleOptions schema field ordering
- Error message wording
- Test fixture data shapes

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRNS-01 | Library provides a Transport behaviour with a single `request/1` callback for HTTP abstraction | D-07: Single callback receiving plain map, returning ok/error tuple. Pattern verified against ExAws and Finch adapter conventions. |
| TRNS-02 | Library ships a default Finch adapter implementing the Transport behaviour | D-08: `LatticeStripe.Transport.Finch` uses `Finch.build/5` + `Finch.request/3`. Finch.Response has status/headers/body/trailers fields. |
| TRNS-03 | User can swap HTTP client by implementing the Transport behaviour | D-08: Pass `transport: MyAdapter` to `Client.new!`. Mox enables test doubles. |
| TRNS-04 | Transport handles form-encoded request bodies (Stripe v1 API format) | D-11: Custom recursive form encoder handles `metadata[key]=value`, `items[0][price]=price_123`, deep nesting. |
| TRNS-05 | Transport supports configurable timeouts per-request and per-client | Finch supports `:receive_timeout`, `:pool_timeout`, `:request_timeout` in `Finch.request/3` opts. Client struct holds default timeout, per-request opts override. |
| CONF-01 | User can create client struct with API key, base URL, timeouts, retry policy, API version, and telemetry toggle | D-01, D-14: NimbleOptions schema validates all fields. Struct fields documented below. |
| CONF-02 | Client configuration validated at creation time with clear error messages | D-14: NimbleOptions provides validation with auto-generated error messages. `new/1` returns error tuple, `new!/1` raises. |
| CONF-03 | User can override options per-request | D-04, D-05: Request struct `opts` field carries per-request overrides. Client.request/2 merges client defaults with request opts. |
| CONF-04 | Client struct is a plain struct -- no GenServer, no global state | D-01, D-03: Explicit struct, no processes, no Application.get_env. |
| CONF-05 | Multiple independent clients can coexist in the same VM | D-03: Each client is an independent struct. No shared state. |
| JSON-01 | Library uses Jason as default JSON encoder/decoder | D-15, D-19: Jason ~> 1.4 as runtime dep. Default codec. |
| JSON-02 | JSON codec is pluggable via a behaviour | D-15: Behaviour with `encode!/1` and `decode!/1` callbacks. User passes `json_codec: MyCodec` to Client.new!. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Language:** Elixir 1.15+, OTP 26+
- **License:** MIT
- **No Dialyzer:** Typespecs for documentation only
- **HTTP:** Transport behaviour with Finch as default adapter
- **JSON:** Jason (ecosystem standard)
- **Stripe API:** Pin to current stable version, support per-request override
- **Dependencies:** Minimal -- Finch, Jason, Telemetry, NimbleOptions core; Plug/Plug.Crypto for webhook (not this phase)
- **No GenServer for state**, no global Application config as primary interface
- **GSD Workflow:** Use `/gsd:execute-phase` for planned phase work

## Standard Stack

### Core (Phase 1 Dependencies)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | ~> 0.19 (current: 0.21.0) | Default HTTP transport | Mint-based, built-in connection pooling, async-friendly. Used by Req, Swoosh. Per D-19. |
| Jason | ~> 1.4 (current: 1.4.4) | Default JSON codec | Undisputed Elixir standard. Every Phoenix app has it. Per D-19. |
| :telemetry | ~> 1.0 (current: 1.4.1) | Instrumentation events | Erlang ecosystem standard for metrics/tracing. Zero overhead when no handler attached. Per D-19. |
| NimbleOptions | ~> 1.0 (current: 1.1.1) | Config validation | Dashbit-maintained, used by Finch/Broadway. Auto-generates docs. Per D-14, D-19. |

### Dev/Test
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Mox | ~> 1.2 (current: 1.2.0) | Behaviour-based test mocks | Concurrent-safe with `async: true`. Dashbit-maintained. Per D-18, D-19. |
| ExDoc | ~> 0.34 (current: 0.40.1) | Documentation generation | Official Elixir doc tool. Per D-19. |
| Credo | ~> 1.7 (current: 1.7.17) | Static analysis/linting | Code consistency. Not Dialyzer. Per D-19. |

### Not Used in Phase 1
| Library | When | Why Later |
|---------|------|-----------|
| Plug | Phase 7 | Only needed for webhook Plug |
| Plug.Crypto | Phase 7 | Only needed for HMAC verification |
| MixAudit | Phase 11 | CI security scanning |

## Architecture Patterns

### Phase 1 Module Structure
```
lib/
  lattice_stripe.ex                    # Top-level module (moduledoc, delegates later)
  lattice_stripe/
    client.ex                          # Client struct + request orchestration
    config.ex                          # NimbleOptions schema + validation
    request.ex                         # Request struct + form encoder
    response.ex                        # Response decoding (JSON maps in Phase 1)
    error.ex                           # Error struct + Stripe error parsing
    json.ex                            # JSON codec behaviour
    json/
      jason.ex                         # Default Jason implementation
    transport.ex                       # Transport behaviour definition
    transport/
      finch.ex                         # Default Finch adapter

test/
  test_helper.exs                      # ExUnit.start, Mox.defmock
  lattice_stripe/
    client_test.exs                    # Mox-based transport mock tests
    config_test.exs                    # NimbleOptions validation tests
    request_test.exs                   # Form encoding unit tests
    response_test.exs                  # JSON decoding unit tests
    error_test.exs                     # Error parsing unit tests
    json_test.exs                      # JSON codec tests
    transport/
      finch_test.exs                   # Finch adapter tests (Mox or basic)
```

### Pattern 1: NimbleOptions Config Validation
**What:** Define client options as a NimbleOptions schema. Validate at struct creation time.
**When to use:** `Client.new/1` and `Client.new!/1`.
**Example:**
```elixir
# Source: NimbleOptions docs + D-14
defmodule LatticeStripe.Config do
  @schema NimbleOptions.new!([
    api_key: [
      type: :string,
      required: true,
      doc: "Stripe API key (sk_test_... or sk_live_...)"
    ],
    base_url: [
      type: :string,
      default: "https://api.stripe.com",
      doc: "Stripe API base URL"
    ],
    api_version: [
      type: :string,
      default: "2025-12-18.acacia",
      doc: "Stripe API version to pin requests to"
    ],
    transport: [
      type: :atom,
      default: LatticeStripe.Transport.Finch,
      doc: "Transport module implementing LatticeStripe.Transport behaviour"
    ],
    json_codec: [
      type: :atom,
      default: LatticeStripe.Json.Jason,
      doc: "JSON codec module implementing LatticeStripe.Json behaviour"
    ],
    finch: [
      type: :atom,
      required: true,
      doc: "Name of the Finch pool to use for HTTP requests"
    ],
    timeout: [
      type: :pos_integer,
      default: 30_000,
      doc: "Default request timeout in milliseconds"
    ],
    max_retries: [
      type: :non_neg_integer,
      default: 0,
      doc: "Maximum number of retries (Phase 2 wires retry logic; Phase 1 stores the config)"
    ],
    stripe_account: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Default Stripe-Account header for Connect platforms"
    ],
    telemetry_enabled: [
      type: :boolean,
      default: true,
      doc: "Whether to emit telemetry events"
    ]
  ])

  def schema, do: @schema

  def validate(opts), do: NimbleOptions.validate(opts, @schema)
  def validate!(opts), do: NimbleOptions.validate!(opts, @schema)
end
```

### Pattern 2: Transport Behaviour (Narrow Contract)
**What:** Single `request/1` callback. Input is a plain map with known keys. Output is a plain map or error.
**When to use:** All HTTP dispatch goes through this behaviour.
**Example:**
```elixir
# Source: D-07, ExAws/Finch adapter pattern
defmodule LatticeStripe.Transport do
  @type request_map :: %{
    method: atom(),
    url: String.t(),
    headers: [{String.t(), String.t()}],
    body: binary() | nil,
    opts: keyword()
  }

  @type response_map :: %{
    status: pos_integer(),
    headers: [{String.t(), String.t()}],
    body: binary()
  }

  @callback request(request_map()) ::
    {:ok, response_map()} | {:error, term()}
end
```

### Pattern 3: Finch Adapter Implementation
**What:** Translates the Transport map contract into Finch.build/5 + Finch.request/3 calls.
**When to use:** Default transport for production use.
**Example:**
```elixir
# Source: Finch v0.21.0 docs
defmodule LatticeStripe.Transport.Finch do
  @behaviour LatticeStripe.Transport

  @impl true
  def request(%{method: method, url: url, headers: headers, body: body, opts: opts}) do
    finch_name = Keyword.fetch!(opts, :finch)
    timeout = Keyword.get(opts, :timeout, 30_000)

    method
    |> Finch.build(url, headers, body)
    |> Finch.request(finch_name, receive_timeout: timeout)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status: status, headers: headers, body: body}}
      {:error, exception} ->
        {:error, exception}
    end
  end
end
```

### Pattern 4: Recursive Form Encoder
**What:** Converts nested Elixir maps/keyword lists into Stripe's `application/x-www-form-urlencoded` format with bracket notation.
**When to use:** All POST/PUT request bodies for Stripe's v1 API.
**Example:**
```elixir
# Source: Stripe SDK conventions, D-11
defmodule LatticeStripe.FormEncoder do
  @doc """
  Encodes nested params into Stripe-compatible form-urlencoded string.

  ## Examples

      iex> encode(%{email: "j@example.com"})
      "email=j%40example.com"

      iex> encode(%{metadata: %{plan: "pro", source: "web"}})
      "metadata[plan]=pro&metadata[source]=web"

      iex> encode(%{items: [%{price: "price_123", quantity: 1}]})
      "items[0][price]=price_123&items[0][quantity]=1"
  """
  def encode(params) when is_map(params) or is_list(params) do
    params
    |> flatten([])
    |> Enum.map(fn {key, value} ->
      "#{URI.encode_www_form(key)}=#{URI.encode_www_form(to_string(value))}"
    end)
    |> Enum.sort()
    |> Enum.join("&")
  end

  defp flatten(params, prefix) do
    Enum.flat_map(params, fn {key, value} ->
      full_key = case prefix do
        [] -> to_string(key)
        _ -> "#{Enum.join(prefix, "")}[#{key}]"
      end

      case value do
        v when is_map(v) ->
          flatten(v, [full_key])
        v when is_list(v) and is_tuple(hd(v)) ->
          # Keyword list treated as map
          flatten(v, [full_key])
        v when is_list(v) ->
          # Array of values
          v
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, idx} ->
            case item do
              item when is_map(item) ->
                flatten(item, ["#{full_key}[#{idx}]"])
              _ ->
                [{full_key <> "[#{idx}]", item}]
            end
          end)
        _ ->
          [{full_key, value}]
      end
    end)
  end
end
```

### Pattern 5: Client Request Orchestration with Telemetry
**What:** Client.request/2 merges config, encodes the request, calls transport, decodes response, emits telemetry.
**When to use:** Every API call flows through this.
**Example:**
```elixir
# Source: D-04, D-16, :telemetry docs
defmodule LatticeStripe.Client do
  def request(%__MODULE__{} = client, %LatticeStripe.Request{} = request) do
    {method, url, headers, body} = build_http_request(client, request)
    transport_opts = [finch: client.finch, timeout: client.timeout]

    metadata = %{
      method: request.method,
      path: request.path,
      client: client
    }

    :telemetry.span(
      [:lattice_stripe, :request],
      metadata,
      fn ->
        result = client.transport.request(%{
          method: method,
          url: url,
          headers: headers,
          body: body,
          opts: transport_opts
        })

        case result do
          {:ok, %{status: status, headers: resp_headers, body: resp_body}} ->
            request_id = get_request_id(resp_headers)
            decoded = client.json_codec.decode!(resp_body)
            response = handle_response(status, decoded, request_id)
            {response, Map.merge(metadata, %{status: status, request_id: request_id})}

          {:error, reason} ->
            # telemetry.span will emit :exception automatically if we raise,
            # or we wrap the error
            {{:error, %LatticeStripe.Error{type: :connection_error, message: inspect(reason)}},
             metadata}
        end
      end
    )
  end
end
```

### Pattern 6: JSON Codec Behaviour
**What:** Two-callback behaviour for JSON encode/decode. Jason as default.
**Example:**
```elixir
# Source: D-15
defmodule LatticeStripe.Json do
  @callback encode!(term()) :: binary()
  @callback decode!(binary()) :: term()
end

defmodule LatticeStripe.Json.Jason do
  @behaviour LatticeStripe.Json

  @impl true
  def encode!(data), do: Jason.encode!(data)

  @impl true
  def decode!(data), do: Jason.decode!(data)
end
```

### Pattern 7: Mox Test Setup
**What:** Define a mock transport in test_helper.exs, use it in async tests.
**Example:**
```elixir
# test/test_helper.exs
Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)
Mox.defmock(LatticeStripe.MockJson, for: LatticeStripe.Json)
ExUnit.start()

# test/lattice_stripe/client_test.exs
defmodule LatticeStripe.ClientTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "request/2 sends authenticated request through transport" do
    LatticeStripe.MockTransport
    |> expect(:request, fn %{method: :get, url: url, headers: headers} ->
      assert url == "https://api.stripe.com/v1/customers/cus_123"
      assert {"authorization", "Bearer sk_test_123"} in headers
      {:ok, %{status: 200, headers: [], body: ~s({"id":"cus_123","object":"customer"})}}
    end)

    client = %LatticeStripe.Client{
      api_key: "sk_test_123",
      transport: LatticeStripe.MockTransport,
      json_codec: LatticeStripe.Json.Jason,
      finch: :unused_in_mock
    }

    request = %LatticeStripe.Request{method: :get, path: "/v1/customers/cus_123"}
    assert {:ok, %{"id" => "cus_123"}} = LatticeStripe.Client.request(client, request)
  end
end
```

### Anti-Patterns to Avoid
- **Application.get_env as primary config:** Breaks multi-tenancy and async tests. Client struct passed explicitly.
- **GenServer for client state:** Unnecessary process for stateless HTTP. Client is a plain struct.
- **Overloaded return types based on options:** `{:ok, result} | {:error, error}` always. No conditional return shapes.
- **Raising in non-bang functions:** `request/2` returns tuples. Bang variants come in Phase 2.
- **Hard-coding Finch pool name:** Accept as config option, never assume a default name.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Option validation | Custom validation logic with case statements | NimbleOptions | Handles types, required, defaults, docs, nested schemas. ~200 LOC battle-tested. |
| JSON encode/decode | Custom JSON parser | Jason (via behaviour) | Fastest pure-Elixir JSON. No reason to wrap it beyond the behaviour for swappability. |
| HTTP connection pooling | Custom pool manager | Finch (via Transport) | Mint-based, handles HTTP/1.1 and HTTP/2, connection reuse, backpressure. |
| Test mocking | Custom mock modules or process-based mocks | Mox | Concurrent-safe, behaviour-enforced, Dashbit-maintained. |
| Telemetry emission | Custom event system | :telemetry | Erlang ecosystem standard. Zero-overhead when no handlers. |
| URL encoding | Custom percent-encoding | URI.encode_www_form/1 | Stdlib, correct per RFC. |

**Key insight:** Phase 1 has exactly one piece of custom logic worth writing: the recursive form encoder (~40 lines). Everything else composes existing libraries.

## Common Pitfalls

### Pitfall 1: Finch Pool Name Not Configured
**What goes wrong:** User creates a client without specifying which Finch pool to use. Request fails with cryptic error about process not found.
**Why it happens:** Finch requires a named process started in the supervision tree. Library cannot assume a default name.
**How to avoid:** Make `finch` a required option in NimbleOptions schema. NimbleOptions gives a clear error: `required option :finch not found`.
**Warning signs:** `:noproc` errors at runtime.

### Pitfall 2: Form Encoder Missing Edge Cases
**What goes wrong:** Nested arrays of maps, empty maps, nil values, boolean values, or atoms not handled correctly. Stripe returns 400 with unhelpful error.
**Why it happens:** Stripe's form encoding has specific conventions: empty string to clear a value, boolean as literal "true"/"false", nil omitted.
**How to avoid:** Comprehensive test suite for the form encoder covering: flat params, nested maps, arrays of scalars, arrays of maps, deeply nested (3+ levels), metadata maps, empty string values, boolean values, nil values (omitted), atom keys converted to strings.
**Warning signs:** Stripe API returning `invalid_request_error` on seemingly correct params.

### Pitfall 3: Missing Request Headers
**What goes wrong:** Stripe returns 401 or unexpected behavior because required headers are missing or malformed.
**Why it happens:** Stripe expects specific headers on every request.
**How to avoid:** Client must always set these headers:
- `Authorization: Bearer sk_test_...`
- `Content-Type: application/x-www-form-urlencoded` (for POST/PUT/PATCH)
- `Stripe-Version: 2025-12-18.acacia` (pinned API version)
- `User-Agent: LatticeStripe/0.1.0 elixir/1.19.5`
- `Stripe-Account: acct_...` (only if stripe_account is set)
- `Idempotency-Key: ...` (only if provided, auto-generated in Phase 2)
**Warning signs:** 401 errors, unexpected API behavior, Stripe support unable to find requests.

### Pitfall 4: Transport Callback Contract Too Wide
**What goes wrong:** Transport behaviour accepts/returns complex structs, making it hard for users to implement custom transports.
**Why it happens:** Temptation to pass the full Client or Request struct through the transport layer.
**How to avoid:** Per D-07: plain map in, plain map out. Transport knows nothing about LatticeStripe internals. Any module that can take `%{method, url, headers, body, opts}` and return `%{status, headers, body}` works.
**Warning signs:** Custom transport implementations requiring LatticeStripe as a dependency.

### Pitfall 5: Telemetry Span Swallowing Errors
**What goes wrong:** `:telemetry.span/3` expects the function to return `{result, metadata}`. If the function raises, span emits `:exception` event. But if the function returns `{:error, ...}` (not raising), it emits `:stop` -- which is correct but the metadata should indicate the error.
**Why it happens:** Telemetry span distinguishes between exceptions (raised) and error tuples (returned).
**How to avoid:** On `{:error, _}` returns, include error info in the stop metadata. On transport exceptions (Finch connection refused), let them propagate to trigger the `:exception` event, then rescue and wrap in `{:error, %Error{}}` at the Client level.
**Warning signs:** Error requests showing up as successful in telemetry dashboards.

## Code Examples

### Complete Client Struct Definition
```elixir
# Source: D-01, D-06, D-08, D-14, D-15, ARCHITECTURE.md
defmodule LatticeStripe.Client do
  @moduledoc """
  A configured Stripe API client.

  Create a client with `new!/1` or `new/1`, then pass it to resource functions:

      client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)

  The client is a plain struct -- no GenServer, no global state. Multiple clients
  with different API keys can coexist in the same BEAM VM.
  """

  @enforce_keys [:api_key, :finch]
  defstruct [
    :api_key,
    :finch,
    :stripe_account,
    base_url: "https://api.stripe.com",
    api_version: "2025-12-18.acacia",
    transport: LatticeStripe.Transport.Finch,
    json_codec: LatticeStripe.Json.Jason,
    timeout: 30_000,
    max_retries: 0,
    telemetry_enabled: true
  ]

  def new!(opts) do
    opts
    |> LatticeStripe.Config.validate!()
    |> then(&struct!(__MODULE__, &1))
  end

  def new(opts) do
    case LatticeStripe.Config.validate(opts) do
      {:ok, validated} -> {:ok, struct!(__MODULE__, validated)}
      {:error, _} = error -> error
    end
  end
end
```

### Request Struct with Per-Request Options
```elixir
# Source: D-04, D-05, CONF-03
defmodule LatticeStripe.Request do
  @moduledoc """
  A Stripe API request as pure data.

  Resource modules build Request structs. Client.request/2 dispatches them.
  """

  defstruct [
    :method,       # :get | :post | :delete
    :path,         # "/v1/customers"
    params: %{},   # Body params (POST) or query params (GET)
    opts: []       # Per-request overrides: [stripe_account: "acct_...", timeout: 5_000, expand: ["data.customer"]]
  ]
end
```

### Error Struct (Phase 1 Minimal)
```elixir
# Source: D-09, PITFALLS.md Pitfall 11
defmodule LatticeStripe.Error do
  @moduledoc """
  A structured Stripe API error.

  Pattern match on `:type` for error category:

      case result do
        {:error, %LatticeStripe.Error{type: :authentication_error}} -> ...
        {:error, %LatticeStripe.Error{type: :invalid_request_error}} -> ...
      end
  """

  defexception [
    :type,         # :card_error | :invalid_request_error | :authentication_error | :rate_limit_error | :api_error | :connection_error
    :code,         # "card_declined", "resource_missing", etc.
    :message,      # Human-readable message
    :status,       # HTTP status code (nil for connection errors)
    :request_id    # Stripe Request-Id header value
  ]

  @impl true
  def message(%__MODULE__{message: msg, type: type}) do
    "(#{type}) #{msg}"
  end

  @doc "Parse a Stripe API error response body into an Error struct."
  def from_response(status, %{"error" => error}, request_id) do
    %__MODULE__{
      type: parse_type(error["type"]),
      code: error["code"],
      message: error["message"],
      status: status,
      request_id: request_id
    }
  end

  def from_response(status, _body, request_id) do
    %__MODULE__{
      type: :api_error,
      message: "Unexpected error response (HTTP #{status})",
      status: status,
      request_id: request_id
    }
  end

  defp parse_type("card_error"), do: :card_error
  defp parse_type("invalid_request_error"), do: :invalid_request_error
  defp parse_type("authentication_error"), do: :authentication_error
  defp parse_type("rate_limit_error"), do: :rate_limit_error
  defp parse_type("api_error"), do: :api_error
  defp parse_type(_), do: :api_error
end
```

### Stripe API Version
```
Current stable: 2025-12-18.acacia (latest named release as of research date)
Monthly releases within a named version are backward-compatible.
The 2026-03-25.dahlia version was referenced in ARCHITECTURE.md -- verify at implementation time.
```

**Recommendation for User-Agent string:**
```
LatticeStripe/0.1.0 elixir/#{System.version()}
```
This follows Stripe's convention used by stripe-node (`stripe-node/17.x.x`) and stripe-python (`stripe-python/11.x.x`).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Application.get_env config | Explicit client struct | 2023-2024 (Goth 1.4, Req) | Multi-tenancy support, async tests |
| HTTPoison/Hackney | Finch (Mint-based) | 2021-2022 | Better memory management, HTTP/2 |
| Poison JSON | Jason | 2019 | Faster, actively maintained |
| Ad-hoc option validation | NimbleOptions | 2021 | Clear errors, auto-docs |
| Custom telemetry helpers | :telemetry.span/3 | telemetry 1.0 (2021) | Standard span pattern |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Runtime | Not installed locally | -- | Install via asdf/mise or use CI only |
| Erlang/OTP | Runtime | Not installed locally | -- | Install via asdf/mise or use CI only |
| Finch (Hex) | HTTP transport | Hex.pm | 0.21.0 | -- |
| Jason (Hex) | JSON codec | Hex.pm | 1.4.4 | -- |
| :telemetry (Hex) | Instrumentation | Hex.pm | 1.4.1 | -- |
| NimbleOptions (Hex) | Config validation | Hex.pm | 1.1.1 | -- |
| Mox (Hex) | Test mocks | Hex.pm | 1.2.0 | -- |

**Missing dependencies with no fallback:**
- Elixir and Erlang/OTP are not installed on this machine. The planner should include a Wave 0 task for project initialization (`mix new lattice_stripe --module LatticeStripe`) that assumes the developer has Elixir installed on their machine.

**Missing dependencies with fallback:**
- None. All Hex dependencies are available and current.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, ships with Elixir) |
| Config file | `test/test_helper.exs` (Wave 0 creation) |
| Quick run command | `mix test --max-failures 1` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRNS-01 | Transport behaviour defines `request/1` callback | unit | `mix test test/lattice_stripe/transport_test.exs -x` | Wave 0 |
| TRNS-02 | Finch adapter implements Transport behaviour | unit | `mix test test/lattice_stripe/transport/finch_test.exs -x` | Wave 0 |
| TRNS-03 | Custom transport can be swapped in | unit (Mox) | `mix test test/lattice_stripe/client_test.exs -x` | Wave 0 |
| TRNS-04 | Form-encoded request bodies | unit | `mix test test/lattice_stripe/request_test.exs -x` | Wave 0 |
| TRNS-05 | Configurable timeouts | unit (Mox) | `mix test test/lattice_stripe/client_test.exs -x` | Wave 0 |
| CONF-01 | Client struct with all config fields | unit | `mix test test/lattice_stripe/config_test.exs -x` | Wave 0 |
| CONF-02 | Validation at creation time | unit | `mix test test/lattice_stripe/config_test.exs -x` | Wave 0 |
| CONF-03 | Per-request option overrides | unit (Mox) | `mix test test/lattice_stripe/client_test.exs -x` | Wave 0 |
| CONF-04 | Plain struct, no GenServer | unit | `mix test test/lattice_stripe/client_test.exs -x` | Wave 0 |
| CONF-05 | Multiple independent clients | unit (Mox) | `mix test test/lattice_stripe/client_test.exs -x` | Wave 0 |
| JSON-01 | Jason as default codec | unit | `mix test test/lattice_stripe/json_test.exs -x` | Wave 0 |
| JSON-02 | Pluggable JSON codec behaviour | unit | `mix test test/lattice_stripe/json_test.exs -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test --max-failures 1`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `mix new lattice_stripe --module LatticeStripe` -- project scaffolding
- [ ] `mix.exs` -- add all Phase 1 dependencies
- [ ] `test/test_helper.exs` -- Mox.defmock setup
- [ ] `.formatter.exs` -- configure formatter
- [ ] `.credo.exs` -- configure Credo

## Open Questions

1. **Exact Stripe API version to pin**
   - What we know: `2025-12-18.acacia` was the latest named release found. Architecture doc referenced `2026-03-25.dahlia`.
   - What's unclear: Which is actually current at implementation time.
   - Recommendation: Check `https://docs.stripe.com/api/versioning` at implementation time and pin to the latest stable named version. Store as a module attribute for easy updating.

2. **NimbleOptions `finch` field -- required vs optional**
   - What we know: D-06 says user must pass `finch: MyApp.Finch`. But if user swaps to a non-Finch transport, `finch` is irrelevant.
   - What's unclear: Should `finch` be required only when transport is `Transport.Finch`?
   - Recommendation: Make `finch` required by default. If user provides a custom transport, they can pass `finch: :not_used` (an atom). Or use a custom NimbleOptions validator that requires `finch` only when `transport` is `Transport.Finch`. The simpler approach (always required) is preferable for Phase 1.

3. **`:telemetry.span/3` return shape for error tuples**
   - What we know: span expects `fn -> {result, metadata} end`. On raise, it emits `:exception`.
   - What's unclear: When Client.request returns `{:error, ...}`, should we still return it from the span function (emitting `:stop`) or raise and catch (emitting `:exception`)?
   - Recommendation: Return `{:error, ...}` from span (emitting `:stop` with error metadata). Only transport-level exceptions (connection refused) should propagate as `:exception` events. This matches how Ecto.Repo handles it.

## Sources

### Primary (HIGH confidence)
- [Finch v0.21.0 docs](https://hexdocs.pm/finch/Finch.html) - build/5, request/3 API, Response struct
- [Finch.Response docs](https://hexdocs.pm/finch/Finch.Response.html) - struct fields: status, headers, body, trailers
- [NimbleOptions v1.1.1 docs](https://hexdocs.pm/nimble_options/NimbleOptions.html) - schema definition, types, validation API
- [telemetry v1.4.1 docs](https://hexdocs.pm/telemetry/telemetry.html) - span/3 usage, event naming
- [Mox v1.2.0 docs](https://hexdocs.pm/mox/Mox.html) - defmock, expect, verify_on_exit!
- [Stripe API Versioning](https://docs.stripe.com/api/versioning) - current version 2025-12-18.acacia confirmed
- [Stripe Metadata API](https://docs.stripe.com/api/metadata) - form encoding for nested params

### Secondary (MEDIUM confidence)
- [Stripe FormEncoder (Java SDK)](https://stripe.dev/stripe-java/com/stripe/net/FormEncoder.html) - bracket notation reference
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) - no global config for libraries

### Tertiary (LOW confidence)
- Stripe API version `2026-03-25.dahlia` referenced in ARCHITECTURE.md but not verified against current Stripe docs. May be the actual current version -- verify at implementation time.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries verified on Hex.pm with current versions, locked by CONTEXT.md decisions
- Architecture: HIGH - patterns from ARCHITECTURE.md and PITFALLS.md are thorough, verified against official library docs
- Pitfalls: HIGH - comprehensive pitfall analysis exists in project research, cross-referenced with Stripe/Elixir docs
- Form encoding: MEDIUM - pattern verified against Java SDK FormEncoder, needs thorough test coverage
- Telemetry integration: MEDIUM - span/3 API verified, but error-tuple-in-span semantics need validation during implementation

**Research date:** 2026-03-31
**Valid until:** 2026-04-30 (stable domain, slow-moving dependencies)
