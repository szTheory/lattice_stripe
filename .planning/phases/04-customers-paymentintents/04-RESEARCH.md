# Phase 4: Customers & PaymentIntents - Research

**Researched:** 2026-04-02
**Domain:** Elixir resource module pattern, Stripe Customer API, Stripe PaymentIntent API
**Confidence:** HIGH

## Summary

Phase 4 introduces the first two resource modules — `LatticeStripe.Customer` and `LatticeStripe.PaymentIntent` — built directly on top of the foundation established in Phases 1-3. The architecture is already decided in CONTEXT.md: hand-written standalone modules (no macro DSL), plain `defstruct` with `from_map/1`, and the `build_request → Client.request → unwrap_response` pipeline.

The key research value here is: (1) confirming exact Stripe API shapes (paths, HTTP methods, fields, params) so struct fields and request builders are correct the first time; (2) identifying subtle issues in how `delete`, `list`, and `stream` interact with the typed struct layer; and (3) documenting test infrastructure needs given both modules share patterns.

Customer is the simpler resource (CRUD + list + search). PaymentIntent adds action verbs (confirm, capture, cancel) and has additional complexity around status field values. Building Customer first establishes the `from_map/1` pattern, then PaymentIntent copies and extends it.

**Primary recommendation:** Build Customer module first (struct + CRUD + list + search + stream), commit, then build PaymentIntent module (struct + CRUD + actions + list + stream). Extract shared private helpers only if obvious duplication exists after both modules are written.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Resource Module Pattern**
- D-01: Hand-written modules with shared private helpers — no macro DSL, no `__using__` base module. Each resource module is standalone. Shared code extracted to private helper only when duplication is obvious after both modules exist.
- D-02: Pattern: `build_request → Client.request/2 → unwrap_response`. Each public function builds `%Request{}`, calls `Client.request/2`, unwraps `%Response{}` into typed struct.
- D-03: Public API: `create/2`, `retrieve/2`, `update/3`, `delete/2`, `list/2` plus resource-specific actions (`confirm/2`, `capture/2`, `cancel/2` on PaymentIntent). All take `(client, params_or_id)` or `(client, id, params)`. Bang variants layered on top.
- D-04: All functions accept `opts` keyword in params for per-request overrides. Threaded into `%Request{opts: opts}`.

**Typed Struct Design**
- D-05: Plain `defstruct` with `from_map/1` constructor. No Ecto, no validation on response data. Unknown fields go to `extra` map.
- D-06: Top-level struct only — expanded nested objects remain plain maps.
- D-07: Struct fields mirror Stripe JSON field names using snake_case atoms. No renaming.
- D-08: Custom `Inspect` on resource structs — show `id`, `object`, and 2-3 key fields. Hide PII (email, name, card details).
- D-09: No `Jason.Encoder` on resource structs.

**Delete Response Handling**
- D-10: `Customer.delete/2` returns `{:ok, %Customer{deleted: true}}`. `deleted` boolean field on struct (default `false`).
- D-11: PaymentIntent has no delete endpoint.

**Search API Ergonomics**
- D-12: `Customer.search/3` takes `(client, query, opts)`. Returns `{:ok, %Response{data: %List{}}}`.
- D-13: `Customer.search_stream!/3` wraps `List.stream!` for search results.

**Return Type Convention**
- D-14: Resource modules return `{:ok, %Customer{}}` / `{:ok, %PaymentIntent{}}`. Power users access metadata via `Client.request/2` directly.
- D-15: List operations return `{:ok, %Response{data: %List{}}}` where `list.data` items are typed structs.

**Testing Strategy**
- D-16: Mox-based unit tests. Test request building and response unwrapping.
- D-17: Test helpers for Stripe-like response JSON inline in test files. Extract to `test/support/fixtures.ex` if duplication emerges.
- D-18: Document eventual consistency for `Customer.search/3` in `@doc`.

### Claude's Discretion
- Internal `from_map/1` implementation details (which fields to extract, default values)
- Exact struct field lists for Customer and PaymentIntent (follow Stripe's API reference)
- Helper function organization within modules
- Test fixture data shapes
- How to handle optional/nilable fields on structs
- Whether to extract shared request-building helpers after both modules exist
- Exact `@moduledoc` and `@doc` content and examples

### Deferred Ideas (OUT OF SCOPE)
- Deep typed deserialization — nested objects as typed structs
- Type registry / object-to-module mapping
- Shared resource macro/DSL
- Nested resource helpers (e.g., `Customer.list_payment_methods/2`)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CUST-01 | User can create a Customer with email, name, metadata | POST /v1/customers with params; `from_map/1` parses response |
| CUST-02 | User can retrieve a Customer by ID | GET /v1/customers/:id; `from_map/1` parses response |
| CUST-03 | User can update a Customer | POST /v1/customers/:id with params |
| CUST-04 | User can delete a Customer | DELETE /v1/customers/:id; returns `%Customer{deleted: true}` |
| CUST-05 | User can list Customers with filters and pagination | GET /v1/customers with filters; returns `%Response{data: %List{}}` with typed items |
| CUST-06 | User can search Customers (search API with page-based pagination) | GET /v1/customers/search?query=...; eventual consistency documented |
| PINT-01 | User can create a PaymentIntent with amount, currency, and payment method options | POST /v1/payment_intents with required amount+currency |
| PINT-02 | User can retrieve a PaymentIntent by ID | GET /v1/payment_intents/:id |
| PINT-03 | User can update a PaymentIntent | POST /v1/payment_intents/:id with params |
| PINT-04 | User can confirm a PaymentIntent | POST /v1/payment_intents/:id/confirm |
| PINT-05 | User can capture a PaymentIntent (manual capture flow) | POST /v1/payment_intents/:id/capture |
| PINT-06 | User can cancel a PaymentIntent | POST /v1/payment_intents/:id/cancel |
| PINT-07 | User can list PaymentIntents with filters and pagination | GET /v1/payment_intents; returns `%Response{data: %List{}}` with typed items |
</phase_requirements>

## Standard Stack

### Core (already in mix.exs — no new dependencies)
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| Jason | ~> 1.4 | Already present | JSON decoding for `from_map/1` |
| Mox | ~> 1.2 | Already present | MockTransport for resource tests |

No new dependencies for this phase. All building blocks are in place from Phases 1-3.

**Version verification:** `mix deps.get` is not needed — no new deps. Current dep versions confirmed from mix.exs: finch ~> 0.19, jason ~> 1.4, mox ~> 1.2.

## Architecture Patterns

### Recommended Project Structure (new files only)
```
lib/lattice_stripe/
├── customer.ex          # %Customer{} struct + CRUD/list/search/stream functions
└── payment_intent.ex    # %PaymentIntent{} struct + CRUD/confirm/capture/cancel/list/stream functions

test/lattice_stripe/
├── customer_test.exs    # Customer resource tests
└── payment_intent_test.exs  # PaymentIntent resource tests
```

### Pattern 1: Resource Module Structure

Every resource module follows the same shape:

```elixir
defmodule LatticeStripe.Customer do
  @moduledoc "..."

  alias LatticeStripe.{Client, List, Request, Response, Error}

  @known_fields ~w[id object address balance created currency default_source
                   delinquent description discount email invoice_prefix
                   invoice_settings livemode metadata name next_invoice_sequence
                   phone preferred_locales shipping sources subscriptions
                   deleted]

  defstruct [
    :id, :address, :balance, :created, :currency, :default_source,
    :delinquent, :description, :discount, :email, :invoice_prefix,
    :invoice_settings, :livemode, :metadata, :name, :next_invoice_sequence,
    :phone, :preferred_locales, :shipping, :sources, :subscriptions,
    object: "customer",
    deleted: false,
    extra: %{}
  ]

  @type t :: %__MODULE__{...}

  # Public API functions...

  # Private: parse Stripe JSON map into typed struct
  defp from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "customer",
      deleted: map["deleted"] || false,
      address: map["address"],
      balance: map["balance"],
      # ... all known fields
      extra: Map.drop(map, @known_fields)
    }
  end
end
```

### Pattern 2: Request Building and Response Unwrapping

The pipeline for a singular resource function:

```elixir
def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
  req = %Request{method: :get, path: "/v1/customers/#{id}", opts: opts}
  case Client.request(client, req) do
    {:ok, %Response{data: data}} -> {:ok, from_map(data)}
    {:error, %Error{}} = error -> error
  end
end

def retrieve!(%Client{} = client, id, opts \\ []) do
  case retrieve(client, id, opts) do
    {:ok, customer} -> customer
    {:error, %Error{} = error} -> raise error
  end
end
```

### Pattern 3: Create and Update (POST with params)

```elixir
def create(%Client{} = client, params \\ %{}, opts \\ []) do
  {req_opts, body_params} = Keyword.pop_many(opts, [:idempotency_key, :stripe_account,
                                                      :stripe_version, :api_key, :timeout,
                                                      :expand, :max_retries])
  # opts keyword contains both per-request overrides AND non-param keys
  # Simplest approach: thread all opts as req opts, pass params as map
  req = %Request{method: :post, path: "/v1/customers", params: params, opts: opts}
  case Client.request(client, req) do
    {:ok, %Response{data: data}} -> {:ok, from_map(data)}
    {:error, %Error{}} = error -> error
  end
end
```

**Note on opts threading:** The `opts` keyword is passed directly as `Request.opts`. This is consistent with CONTEXT.md D-04 and how Phase 1 established the pattern. The Client reads per-request override keys (`idempotency_key`, `stripe_account`, etc.) from `req.opts` and passes remaining params through `FormEncoder`.

**CRITICAL:** `opts` in resource functions should be the per-request keyword list (idempotency_key, stripe_account, expand, etc.), NOT body parameters. Body params go in the `params` map argument. This is the consistent convention.

### Pattern 4: List Operations Returning %Response{data: %List{}}

```elixir
def list(%Client{} = client, params \\ %{}, opts \\ []) do
  req = %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
  # Client.request/2 auto-detects "list" object and wraps in %List{}
  # items in list.data are still plain maps — we type them here
  case Client.request(client, req) do
    {:ok, %Response{data: %List{} = list} = resp} ->
      typed_list = %{list | data: Enum.map(list.data, &from_map/1)}
      {:ok, %{resp | data: typed_list}}
    {:error, %Error{}} = error -> error
  end
end
```

**Key insight:** `Client.request/2` returns items in `list.data` as plain maps (raw Stripe JSON). The resource module's `list/2` must map `from_map/1` over `list.data` to produce typed structs. The `%Response{}` wrapper is preserved so callers can access `request_id`.

### Pattern 5: Stream Functions

```elixir
def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  req = %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
  client
  |> List.stream!(req)
  |> Stream.map(&from_map/1)
end

def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
  req = %Request{
    method: :get,
    path: "/v1/customers/search",
    params: %{"query" => query},
    opts: opts
  }
  client
  |> List.stream!(req)
  |> Stream.map(&from_map/1)
end
```

### Pattern 6: Delete Response Handling (Customer only)

Stripe DELETE /v1/customers/:id returns `{"id": "cus_...", "object": "customer", "deleted": true}`.

```elixir
def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
  req = %Request{method: :delete, path: "/v1/customers/#{id}", opts: opts}
  case Client.request(client, req) do
    {:ok, %Response{data: data}} -> {:ok, from_map(data)}
    {:error, %Error{}} = error -> error
  end
end
```

`from_map/1` already handles `deleted: map["deleted"] || false`, so a deleted response produces `%Customer{deleted: true}` naturally.

### Pattern 7: PaymentIntent Action Verbs

```elixir
def confirm(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  req = %Request{
    method: :post,
    path: "/v1/payment_intents/#{id}/confirm",
    params: params,
    opts: opts
  }
  case Client.request(client, req) do
    {:ok, %Response{data: data}} -> {:ok, from_map(data)}
    {:error, %Error{}} = error -> error
  end
end

def capture(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  req = %Request{method: :post, path: "/v1/payment_intents/#{id}/capture", params: params, opts: opts}
  case Client.request(client, req) do
    {:ok, %Response{data: data}} -> {:ok, from_map(data)}
    {:error, %Error{}} = error -> error
  end
end

def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  req = %Request{method: :post, path: "/v1/payment_intents/#{id}/cancel", params: params, opts: opts}
  case Client.request(client, req) do
    {:ok, %Response{data: data}} -> {:ok, from_map(data)}
    {:error, %Error{}} = error -> error
  end
end
```

### Pattern 8: Custom Inspect (PII-safe)

Following Phase 3 D-08 and the `Inspect` pattern from `LatticeStripe.Response`:

```elixir
defimpl Inspect, for: LatticeStripe.Customer do
  def inspect(customer, opts) do
    # Show id, object, livemode — hide email, name, phone (PII)
    sanitized = %{
      __struct__: LatticeStripe.Customer,
      id: customer.id,
      object: customer.object,
      livemode: customer.livemode,
      deleted: customer.deleted
    }
    Inspect.Any.inspect(sanitized, opts)
  end
end

defimpl Inspect, for: LatticeStripe.PaymentIntent do
  def inspect(pi, opts) do
    # Show id, object, amount, currency, status — hide client_secret
    sanitized = %{
      __struct__: LatticeStripe.PaymentIntent,
      id: pi.id,
      object: pi.object,
      amount: pi.amount,
      currency: pi.currency,
      status: pi.status
    }
    Inspect.Any.inspect(sanitized, opts)
  end
end
```

**PII fields to hide on Customer:** `email`, `name`, `phone`, `description`, `address`, `shipping`
**Sensitive fields to hide on PaymentIntent:** `client_secret` (used for client-side payment confirmation — must never be logged)

### Anti-Patterns to Avoid

- **Implementing `Jason.Encoder` on resource structs:** Explicitly prohibited by D-09 / Phase 2 D-04. Security risk.
- **Implementing `Enumerable` on resource structs:** The List module explicitly does not implement Enumerable (Phase 3 D-13). Resource modules should follow the same principle.
- **Accepting body params in `opts`:** `opts` is the per-request overrides keyword. Body params go in the `params` map. Mixing them causes confusion.
- **Calling `Client.request!/2` inside resource functions:** Use `Client.request/2` and pattern match. Let the bang variant (`retrieve!/2`) call the non-bang and raise.
- **Logging or storing `client_secret`:** PaymentIntent's `client_secret` is extremely sensitive — the Inspect implementation MUST hide it.
- **Passing opts directly as body params:** Opts keyword contains keys like `expand`, `idempotency_key`, `stripe_account` which should not go into the form-encoded body. The `Request` struct keeps opts separate from params for this reason.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form-encoded POST bodies | Custom param serializer | `LatticeStripe.FormEncoder` (already exists) | Handles nested maps, arrays, nil filtering — already battle-tested in Phase 1 |
| Pagination / streaming | Custom stream loop | `LatticeStripe.List.stream!/2` and `Stream.map/2` | Already implemented in Phase 3 with full test coverage |
| HTTP dispatch + retry | Custom HTTP call | `LatticeStripe.Client.request/2` | Handles retry, telemetry, idempotency, header building — don't duplicate |
| Error handling | Custom error construction | `{:error, %Error{}}` passthrough | Client already builds structured errors; resource modules just pass them through |
| JSON decoding | `Jason.decode` calls | Trust the decoded map from `Client.request/2` | Client already decodes JSON; resource modules receive plain maps |

**Key insight:** Resource modules are thin adapter layers. The heavy lifting (HTTP, retry, JSON, pagination, error structuring) is done by the foundation modules. Resource modules only: build Request structs, call Client.request, and map response data through `from_map/1`.

## Stripe API Reference (Verified)

### Customer Endpoints

| Operation | Method | Path | Notes |
|-----------|--------|------|-------|
| create | POST | `/v1/customers` | body params: email, name, metadata, phone, description, etc. |
| retrieve | GET | `/v1/customers/:id` | |
| update | POST | `/v1/customers/:id` | same body params as create |
| delete | DELETE | `/v1/customers/:id` | returns `{"deleted": true, "id": "cus_..."}` |
| list | GET | `/v1/customers` | query: email, created, limit, starting_after, ending_before |
| search | GET | `/v1/customers/search` | query: `query` (required), `limit`, `page`; object type: `"search_result"` |

**Customer create params (verified):** `address`, `balance`, `business_name`, `cash_balance`, `description`, `email`, `individual_name`, `invoice_prefix`, `invoice_settings`, `metadata`, `name`, `next_invoice_sequence`, `payment_method`, `phone`, `preferred_locales`, `shipping`, `source`, `tax`, `tax_exempt`, `tax_id_data`, `test_clock`

**Customer list filters:** `email`, `created` (range object), `limit`, `starting_after`, `ending_before`

**Customer search query syntax examples:**
- `"email:'jenny@example.com'"`
- `"name:'Jane Doe' AND metadata['key']:'value'"`

### Customer Object Fields (verified from Stripe docs)

| Field | Type | Notes |
|-------|------|-------|
| id | string | |
| object | string | always "customer" |
| address | map, nullable | nested object — stays as map (D-06) |
| balance | integer | |
| business_name | string, nullable | |
| cash_balance | map, nullable | expandable |
| created | integer | unix timestamp |
| currency | string, nullable | |
| customer_account | string, nullable | |
| default_source | string, nullable | expandable |
| delinquent | boolean, nullable | |
| description | string, nullable | |
| discount | map, nullable | |
| email | string, nullable | PII |
| individual_name | string, nullable | |
| invoice_credit_balance | map | expandable |
| invoice_prefix | string, nullable | |
| invoice_settings | map | |
| livemode | boolean | |
| metadata | map | |
| name | string, nullable | PII |
| next_invoice_sequence | integer, nullable | |
| phone | string, nullable | PII |
| preferred_locales | list, nullable | |
| shipping | map, nullable | PII |
| sources | map, nullable | expandable |
| subscriptions | map, nullable | expandable |
| deleted | boolean | only present on delete response |

### PaymentIntent Endpoints

| Operation | Method | Path | Notes |
|-----------|--------|------|-------|
| create | POST | `/v1/payment_intents` | required: amount, currency |
| retrieve | GET | `/v1/payment_intents/:id` | |
| update | POST | `/v1/payment_intents/:id` | |
| confirm | POST | `/v1/payment_intents/:id/confirm` | params: payment_method, capture_method, etc. |
| capture | POST | `/v1/payment_intents/:id/capture` | params: amount_to_capture, final_capture, etc. |
| cancel | POST | `/v1/payment_intents/:id/cancel` | params: cancellation_reason (optional) |
| list | GET | `/v1/payment_intents` | filters: customer, created, limit, starting_after, ending_before |

**PaymentIntent create required params:** `amount` (integer, in smallest currency unit), `currency` (ISO 3-letter)

**PaymentIntent confirm params:** `payment_method`, `payment_method_data`, `payment_method_options`, `confirmation_token`, `capture_method`, `off_session`, `mandate`, `mandate_data`, `error_on_requires_action`

**PaymentIntent capture params:** `amount_to_capture`, `amount_details`, `application_fee_amount`, `final_capture`, `metadata`, `payment_details`, `statement_descriptor`, `statement_descriptor_suffix`, `transfer_data`

**PaymentIntent cancel params:** `cancellation_reason` — values: `"duplicate"`, `"fraudulent"`, `"requested_by_customer"`, `"abandoned"`

**PaymentIntent list filters:** `customer`, `customer_account`, `created` (range), `limit`, `starting_after`, `ending_before`

### PaymentIntent Object Fields (verified from Stripe docs)

| Field | Type | Notes |
|-------|------|-------|
| id | string | |
| object | string | always "payment_intent" |
| amount | integer | in smallest currency unit |
| amount_capturable | integer | |
| amount_details | map, nullable | |
| amount_received | integer | |
| application | string, nullable | expandable |
| application_fee_amount | integer, nullable | |
| automatic_payment_methods | map, nullable | |
| canceled_at | integer, nullable | unix timestamp |
| cancellation_reason | string, nullable | enum |
| capture_method | string | enum: automatic, automatic_async, manual |
| client_secret | string, nullable | SENSITIVE — hide in Inspect |
| confirmation_method | string | enum |
| created | integer | unix timestamp |
| currency | string | |
| customer | string, nullable | expandable |
| customer_account | string, nullable | |
| description | string, nullable | |
| excluded_payment_method_types | list, nullable | |
| hooks | map, nullable | |
| last_payment_error | map, nullable | |
| livemode | boolean | |
| metadata | map | |
| next_action | map, nullable | |
| on_behalf_of | string, nullable | expandable |
| payment_method | string, nullable | expandable |
| payment_method_configuration_details | map, nullable | |
| payment_method_options | map, nullable | |
| payment_method_types | list | |
| processing | map, nullable | |
| receipt_email | string, nullable | PII |
| review | string, nullable | expandable |
| setup_future_usage | string, nullable | enum |
| shipping | map, nullable | PII |
| source | string, nullable | deprecated |
| statement_descriptor | string, nullable | |
| statement_descriptor_suffix | string, nullable | |
| status | string | enum: requires_payment_method, requires_confirmation, requires_action, processing, requires_capture, canceled, succeeded |
| transfer_data | map, nullable | |
| transfer_group | string, nullable | |

## Common Pitfalls

### Pitfall 1: `client_secret` in Logs
**What goes wrong:** Developer logs the `%PaymentIntent{}` struct, exposing `client_secret` to logs. Anyone with the client_secret can complete the payment on behalf of the customer.
**Why it happens:** Default Inspect for structs shows all fields.
**How to avoid:** Custom `Inspect` implementation MUST exclude `client_secret`. This is the most critical security concern in Phase 4.
**Warning signs:** Any `IO.inspect`, `Logger.debug`, or IEx paste of a PaymentIntent showing `client_secret`.

### Pitfall 2: Mixing opts and params
**What goes wrong:** Developer passes `expand: ["customer"]` as a body param key instead of in opts. FormEncoder encodes it into the body; Stripe ignores it or errors.
**Why it happens:** Elixir convention often conflates function opts with API params.
**How to avoid:** Resource functions must have clear arity separation: `create(client, params, opts \\ [])` where `params` is the API request body and `opts` is the per-request override keyword list.
**Warning signs:** `expand` not working, Stripe returning unexpected fields.

### Pitfall 3: List items not deserialized to typed structs
**What goes wrong:** `Customer.list/2` returns `%Response{data: %List{data: [%{"id" => ...}]}}` — plain maps instead of `%Customer{}` structs.
**Why it happens:** `Client.request/2` builds the `%List{}` from raw JSON. It does not know about resource types. The resource module must call `from_map/1` over `list.data`.
**How to avoid:** In `list/2`, after receiving the `%Response{data: %List{}}`, map `from_map/1` over `list.data` to produce typed items before returning.
**Warning signs:** Pattern matching on `%Customer{}` in list results fails.

### Pitfall 4: stream! items not deserialized
**What goes wrong:** `Customer.stream!/2` yields plain maps, not `%Customer{}` structs.
**Why it happens:** `List.stream!/2` yields raw map items from each page's JSON data.
**How to avoid:** Pipe through `Stream.map(&from_map/1)` after `List.stream!(req)`.

### Pitfall 5: search vs list pagination confusion
**What goes wrong:** Calling `Customer.search/3` and then trying to paginate with `starting_after`. Search uses `next_page` (page token), not cursor.
**Why it happens:** Two different pagination models on the same resource.
**How to avoid:** `Customer.search/3` docs must state clearly: "Search uses page-based pagination. Pass the `next_page` value from the previous response as the `page` param. Do NOT use `starting_after`."

### Pitfall 6: PaymentIntent confirm arity
**What goes wrong:** `PaymentIntent.confirm(client, id)` called without params — this is valid (Stripe accepts confirm with no params for automatic payment methods). Must default `params \\ %{}`.
**Why it happens:** Confirm can be called with no payment method params when `automatic_payment_methods` is configured.
**How to avoid:** `confirm/2` with `(client, id, params \\ %{}, opts \\ [])` — params defaults to empty map.

### Pitfall 7: `@known_fields` atom list vs string keys
**What goes wrong:** `from_map/1` reads `map["id"]` (string key from JSON decode) but `@known_fields` uses `~w[id ...]` string sigil for `Map.drop`. These must match (all strings or all atoms). Jason decodes to string keys by default.
**Why it happens:** Elixir maps can use string or atom keys; JSON decoding produces string keys.
**How to avoid:** `@known_fields ~w[id object ...]` (string sigil, no `a`), consistent with how `LatticeStripe.List` uses `@known_keys ~w[...]`.

## Code Examples

### Minimal Customer Module Skeleton

```elixir
defmodule LatticeStripe.Customer do
  @moduledoc """
  Manage Stripe Customer objects.
  ...
  """

  alias LatticeStripe.{Client, Error, List, Request, Response}

  @known_fields ~w[id object address balance business_name cash_balance created
                   currency customer_account default_source delinquent description
                   discount email individual_name invoice_credit_balance invoice_prefix
                   invoice_settings livemode metadata name next_invoice_sequence phone
                   preferred_locales shipping sources subscriptions deleted]

  defstruct [
    :id, :address, :balance, :business_name, :cash_balance, :created, :currency,
    :customer_account, :default_source, :delinquent, :description, :discount,
    :email, :individual_name, :invoice_credit_balance, :invoice_prefix,
    :invoice_settings, :livemode, :metadata, :name, :next_invoice_sequence,
    :phone, :preferred_locales, :shipping, :sources, :subscriptions,
    object: "customer",
    deleted: false,
    extra: %{}
  ]

  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :post, path: "/v1/customers", params: params, opts: opts}
    unwrap_singular(Client.request(client, req))
  end

  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    req = %Request{method: :get, path: "/v1/customers/#{id}", opts: opts}
    unwrap_singular(Client.request(client, req))
  end

  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    req = %Request{method: :post, path: "/v1/customers/#{id}", params: params, opts: opts}
    unwrap_singular(Client.request(client, req))
  end

  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    req = %Request{method: :delete, path: "/v1/customers/#{id}", opts: opts}
    unwrap_singular(Client.request(client, req))
  end

  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
    unwrap_list(Client.request(client, req))
  end

  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/customers/search",
      params: %{"query" => query},
      opts: opts
    }
    Client.request(client, req)
  end

  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
    client |> List.stream!(req) |> Stream.map(&from_map/1)
  end

  def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/customers/search",
      params: %{"query" => query},
      opts: opts
    }
    client |> List.stream!(req) |> Stream.map(&from_map/1)
  end

  # Bang variants
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    client |> create(params, opts) |> unwrap_bang!()
  end

  # ... other bangs follow same pattern

  # Private helpers
  defp unwrap_singular({:ok, %Response{data: data}}), do: {:ok, from_map(data)}
  defp unwrap_singular({:error, %Error{}} = error), do: error

  defp unwrap_list({:ok, %Response{data: %List{} = list} = resp}) do
    typed = %{list | data: Enum.map(list.data, &from_map/1)}
    {:ok, %{resp | data: typed}}
  end
  defp unwrap_list({:error, %Error{}} = error), do: error

  defp unwrap_bang!({:ok, result}), do: result
  defp unwrap_bang!({:error, %Error{} = error}), do: raise(error)

  defp from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "customer",
      deleted: map["deleted"] || false,
      address: map["address"],
      balance: map["balance"],
      business_name: map["business_name"],
      cash_balance: map["cash_balance"],
      created: map["created"],
      currency: map["currency"],
      customer_account: map["customer_account"],
      default_source: map["default_source"],
      delinquent: map["delinquent"],
      description: map["description"],
      discount: map["discount"],
      email: map["email"],
      individual_name: map["individual_name"],
      invoice_credit_balance: map["invoice_credit_balance"],
      invoice_prefix: map["invoice_prefix"],
      invoice_settings: map["invoice_settings"],
      livemode: map["livemode"],
      metadata: map["metadata"],
      name: map["name"],
      next_invoice_sequence: map["next_invoice_sequence"],
      phone: map["phone"],
      preferred_locales: map["preferred_locales"],
      shipping: map["shipping"],
      sources: map["sources"],
      subscriptions: map["subscriptions"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
```

### Test Pattern for Resource Modules

```elixir
defmodule LatticeStripe.CustomerTest do
  use ExUnit.Case, async: true
  import Mox

  alias LatticeStripe.{Client, Customer, Error, Request, Response}

  setup :verify_on_exit!

  defp test_client do
    Client.new!(
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false,
      max_retries: 0
    )
  end

  defp customer_json(overrides \\ %{}) do
    %{
      "id" => "cus_test123",
      "object" => "customer",
      "email" => "test@example.com",
      "name" => "Test User",
      "livemode" => false,
      "created" => 1_700_000_000,
      "metadata" => %{},
      "deleted" => false
    }
    |> Map.merge(overrides)
  end

  defp ok_response(body) do
    {:ok, %{status: 200, headers: [{"request-id", "req_test"}], body: Jason.encode!(body)}}
  end

  describe "create/3" do
    test "builds POST /v1/customers and returns %Customer{}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/customers")
        ok_response(customer_json())
      end)

      assert {:ok, %Customer{id: "cus_test123", email: "test@example.com"}} =
               Customer.create(client, %{"email" => "test@example.com"})
    end
  end

  describe "delete/3" do
    test "returns %Customer{deleted: true}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(%{"id" => "cus_test123", "object" => "customer", "deleted" => true})
      end)

      assert {:ok, %Customer{deleted: true}} = Customer.delete(client, "cus_test123")
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `stripity_stripe` global config | Per-client struct | This project | Multi-tenant safe, test-isolated |
| Macro-generated resource modules | Hand-written standalone modules | D-01 locked | Explicit, readable, copyable pattern |
| List returns raw maps | List items typed via `from_map/1` | Phase 4 (this phase) | Pattern-matchable domain types |
| Response returns plain map | Response wraps typed struct | Phase 4 (this phase) | Ergonomic resource-level API |

**Note on `stripity_stripe`:** The existing Elixir Stripe library uses a very different architecture (global config, macros, Poison). LatticeStripe deliberately diverges. Do not reference stripity_stripe patterns.

## Open Questions

1. **Search return type consistency**
   - What we know: D-12 says `Customer.search/3` returns `{:ok, %Response{data: %List{}}}` (raw response, not unwrapped)
   - What's unclear: This is inconsistent with `list/2` which also returns `{:ok, %Response{data: %List{}}}` but with typed items. Should `search/3` also type items in the list?
   - Recommendation: Yes — apply `from_map/1` to search result items via `unwrap_list/1` for consistency. The search stream already pipes through `Stream.map(&from_map/1)`.

2. **`update/3` param arity for PaymentIntent action verbs**
   - What we know: `confirm/2`, `capture/2`, `cancel/2` can all take optional params
   - What's unclear: Should arity be `confirm(client, id)` or `confirm(client, id, params \\ %{}, opts \\ [])`?
   - Recommendation: Use `(client, id, params \\ %{}, opts \\ [])` for all action verbs. Confirm especially often needs no params (automatic payment methods), so `params \\ %{}` default is correct.

3. **`extra` field collision with `deleted`**
   - What we know: Delete response has `{"id": ..., "object": "customer", "deleted": true}` — very few fields
   - What's unclear: `deleted` is in `@known_fields` so it maps to the struct field, not `extra`. This is correct.
   - Recommendation: Confirmed — include `"deleted"` in `@known_fields` so `Map.drop` excludes it from `extra`.

## Environment Availability

Step 2.6: SKIPPED — Phase 4 is purely code changes (new Elixir modules and tests). No external tools, services, databases, or CLI utilities beyond the existing project stack.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` (exists) |
| Quick run command | `mix test test/lattice_stripe/customer_test.exs test/lattice_stripe/payment_intent_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CUST-01 | create/3 builds POST /v1/customers, returns %Customer{} | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ Wave 0 |
| CUST-02 | retrieve/3 builds GET /v1/customers/:id, returns %Customer{} | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ Wave 0 |
| CUST-03 | update/4 builds POST /v1/customers/:id, returns %Customer{} | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ Wave 0 |
| CUST-04 | delete/3 builds DELETE /v1/customers/:id, returns %Customer{deleted: true} | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ Wave 0 |
| CUST-05 | list/3 builds GET /v1/customers, returns %Response{data: %List{}} with typed items | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ Wave 0 |
| CUST-06 | search/3 builds GET /v1/customers/search?query=..., items typed, eventual consistency documented in @doc | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ Wave 0 |
| PINT-01 | create/3 builds POST /v1/payment_intents with amount+currency, returns %PaymentIntent{} | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |
| PINT-02 | retrieve/3 builds GET /v1/payment_intents/:id, returns %PaymentIntent{} | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |
| PINT-03 | update/4 builds POST /v1/payment_intents/:id, returns %PaymentIntent{} | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |
| PINT-04 | confirm/4 builds POST /v1/payment_intents/:id/confirm, returns %PaymentIntent{} | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |
| PINT-05 | capture/4 builds POST /v1/payment_intents/:id/capture, returns %PaymentIntent{} | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |
| PINT-06 | cancel/4 builds POST /v1/payment_intents/:id/cancel, returns %PaymentIntent{} | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |
| PINT-07 | list/3 builds GET /v1/payment_intents, returns %Response{data: %List{}} with typed items | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave 0 |

### Additional Test Coverage (beyond requirements)
- Bang variant (`create!/3`, `retrieve!/3`, etc.) raises `LatticeStripe.Error` on error
- `stream!/2` yields typed structs
- `search_stream!/3` yields typed structs
- `from_map/1` maps all known fields; unknown fields go to `extra`
- Custom Inspect hides PII/sensitive fields

### Sampling Rate
- **Per task commit:** `mix test test/lattice_stripe/customer_test.exs test/lattice_stripe/payment_intent_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/lattice_stripe/customer_test.exs` — covers CUST-01 through CUST-06
- [ ] `test/lattice_stripe/payment_intent_test.exs` — covers PINT-01 through PINT-07

*(No new framework config needed — ExUnit + Mox already configured in `test/test_helper.exs`)*

## Project Constraints (from CLAUDE.md)

- **Language:** Elixir 1.15+, OTP 26+ — use `defstruct`, no macros
- **No Dialyzer:** Typespecs for documentation only
- **HTTP:** Do not add transport dependencies; use existing `LatticeStripe.Transport.Finch` / `Client.request/2`
- **JSON:** Jason only — no other JSON lib; no `Jason.Encoder` on resource structs
- **Dependencies:** Minimal — no new deps for Phase 4 (all needed tools already in mix.exs)
- **No GenServer for state:** Client struct is passed explicitly, not stored in process
- **GSD Workflow Enforcement:** All file changes through GSD workflow (`/gsd:execute-phase`)

## Sources

### Primary (HIGH confidence)
- Stripe API docs (docs.stripe.com/api/customers/object) — Customer object field list verified 2026-04-02
- Stripe API docs (docs.stripe.com/api/payment_intents/object) — PaymentIntent field list verified 2026-04-02
- Stripe API docs (docs.stripe.com/api/customers/search) — Search API params and pagination model verified
- Stripe API docs (docs.stripe.com/api/payment_intents/confirm) — Confirm endpoint params verified
- Stripe API docs (docs.stripe.com/api/payment_intents/capture) — Capture endpoint params verified
- Stripe API docs (docs.stripe.com/api/payment_intents/cancel) — Cancel endpoint params and cancellation_reason values verified
- Stripe API docs (docs.stripe.com/api/payment_intents/list) — List endpoint filters verified
- `lib/lattice_stripe/client.ex` — existing Client.request/2 pipeline confirmed
- `lib/lattice_stripe/list.ex` — existing List.stream!/2, from_json/3 confirmed
- `lib/lattice_stripe/response.ex` — existing Response struct and Inspect impl confirmed
- `test/lattice_stripe/client_test.exs` — test patterns (test_client helper, MockTransport usage) confirmed
- `test/test_helper.exs` — MockTransport, MockJson, MockRetryStrategy already defined
- `.planning/phases/04-customers-paymentintents/04-CONTEXT.md` — all decisions locked

### Secondary (MEDIUM confidence)
- `mix.exs` — dep versions (finch ~> 0.19 vs CLAUDE.md recommending ~> 0.21; not a blocking difference)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps, all building blocks verified in existing code
- Architecture: HIGH — pattern confirmed in CONTEXT.md decisions, code examples derived from existing modules
- Stripe API shapes: HIGH — field lists verified directly from Stripe docs 2026-04-02
- Pitfalls: HIGH — derived from code analysis and Stripe API semantics
- Test patterns: HIGH — derived from existing test files in project

**Research date:** 2026-04-02
**Valid until:** 2026-07-02 (Stripe API field shapes are stable; framework patterns very stable)
