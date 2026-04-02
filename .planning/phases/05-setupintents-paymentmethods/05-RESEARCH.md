# Phase 5: SetupIntents & PaymentMethods - Research

**Researched:** 2026-04-02
**Domain:** Stripe SetupIntents API, Stripe PaymentMethods API, Elixir SDK resource module pattern extension
**Confidence:** HIGH

## Summary

Phase 5 extends an already-working pattern from Phase 4. The resource module architecture
(struct + from_map/1 + CRUD functions + bang variants + Inspect impl) is proven and just needs
to be applied to two new Stripe objects. The unique work in this phase is:

1. Extracting the duplicate `unwrap_singular/unwrap_list/unwrap_bang!` helpers from Customer and
   PaymentIntent into a shared `LatticeStripe.Resource` module.
2. Adding `PaymentIntent.search/3` and `PaymentIntent.search_stream!/3` (missed in Phase 4).
3. Extracting shared test helpers to `test/support/test_helpers.ex`.
4. Building `SetupIntent` (7 public operations: CRUD + confirm/cancel/verify_microdeposits + list/stream).
5. Building `PaymentMethod` (8 public operations: CRUD + attach/detach + list with customer validation + stream).

The primary technical discovery is the PaymentMethod struct design: it has ~45 top-level type-specific
fields (card, us_bank_account, sepa_debit, etc.) that are almost always nil. This is idiomatic and
zero-cost in Elixir — struct fields are just tuple positions.

The Stripe API behavior that most affects planning: `PaymentMethod.list` technically does NOT require
`customer` at the API level, but the SDK enforces it as a local validation (D-13) because calling
without it in practice returns all payment methods unscoped — almost never what SDK users want.

**Primary recommendation:** Follow the established Phase 4 pattern exactly. Extract helpers first
(plan 05-01), then build PaymentMethod on the clean foundation (plan 05-02).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Hand-written modules, no macro DSL — same as Phase 4 D-01
- **D-02:** Request struct → Client.request → unwrap — same as Phase 4 D-02
- **D-03:** Public API convention: create/2, retrieve/2, update/3, list/2, plus resource-specific action verbs — same as Phase 4 D-03
- **D-04:** All functions accept opts keyword for per-request overrides — same as Phase 4 D-04
- **D-05:** Extract `LatticeStripe.Resource` helper module (`@moduledoc false`, not public API). Contains: `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3`
- **D-06:** Refactor existing Customer.ex and PaymentIntent.ex to use `Resource` helpers in plan 05-01 (alongside SetupIntent creation). Verify zero behavior change with existing tests.
- **D-07:** Add `PaymentIntent.search/3` and `PaymentIntent.search_stream!/3` while refactoring PI.ex in 05-01. Same pattern as Customer.search.
- **D-08:** Extract common test helpers to `test/support/test_helpers.ex`: `test_client/1`, `ok_response/1`, `error_response/0`, `list_json/2`
- **D-09:** Resource-specific JSON builders (e.g., `setup_intent_json/1`, `payment_method_json/1`) stay in their respective test files.
- **D-10:** Refactor existing Customer and PaymentIntent tests to use shared helpers in 05-01.
- **D-11:** `PaymentMethod.attach/4` and `PaymentMethod.detach/3` use the params map pattern — `attach(client, id, params \\ %{}, opts \\ [])`. Customer ID goes in params as `%{"customer" => "cus_..."}`.
- **D-12:** Detach returns `{:ok, %PaymentMethod{customer: nil}}` naturally via `from_map/1`. No special handling needed.
- **D-13:** `PaymentMethod.list/3` validates that `"customer"` key exists in params. Raises `ArgumentError` with descriptive message if missing.
- **D-14:** `PaymentMethod.stream!/3` applies the same customer param validation as list.
- **D-15:** Validation uses `Resource.require_param!/3` from the shared helper module.
- **D-16:** Local validation applied case-by-case for known Stripe required params — not a blanket rule.
- **D-17:** Both structs use plain `defstruct` with `from_map/1`, `@known_fields`, and `extra` map.
- **D-18:** PaymentMethod struct includes ALL ~45 type-specific fields (card, us_bank_account, sepa_debit, acss_debit, etc.) as struct keys. Most are nil.
- **D-19:** SetupIntent.latest_attempt is a raw value — string ID (unexpanded) or plain map (expanded). Same pattern as PaymentIntent.latest_charge.
- **D-20:** SetupIntent.cancellation_reason is a struct field — same as PaymentIntent.
- **D-21:** Status fields remain as strings (not atoms).
- **D-22:** SetupIntent Inspect shows: `id`, `object`, `status`, `usage`. Hides `client_secret` entirely.
- **D-23:** PaymentMethod Inspect shows: `id`, `object`, `type`, plus `card.brand` and `card.last4` when type is card. Hides: `billing_details`, `card.fingerprint`, `card.exp_month`, `card.exp_year`, and all other PII/payment data.
- **D-24:** Include `SetupIntent.verify_microdeposits/4` — same action verb pattern as confirm/cancel.
- **D-25:** PaymentMethod has no delete endpoint. No `delete` function. Moduledoc notes: "PaymentMethods cannot be deleted. Use `detach/3` to remove from a customer."
- **D-26:** `PaymentMethod.create/3` is pure pass-through — no local validation of `type` or type-specific params. Stripe validates.
- **D-27:** Two plans: `05-01-PLAN.md` (Resource helpers + refactor + SetupIntent) and `05-02-PLAN.md` (PaymentMethod).
- **D-28:** Moduledocs follow Phase 4 structure. PaymentMethod docs must note: (1) `list` requires `customer` param, (2) no delete, (3) type-specific nested objects.

### Claude's Discretion

- Internal `from_map/1` implementation details for both structs
- Exact struct field lists (follow Stripe's API reference for SetupIntent and PaymentMethod)
- `@moduledoc` and `@doc` content, examples, and formatting
- Test fixture data shapes (resource-specific JSON builders)
- How to handle optional/nilable fields on structs
- Whether to verify customer==nil in detach tests
- Helper function organization within modules
- Ordering of tasks within each plan

### Deferred Ideas (OUT OF SCOPE)

- **Type registry** — `%{"customer" => Customer, ...}` for automatic deserialization. Deferred to Phase 7.
- **Typed expansion** (EXPD-02) — Expanded nested objects. Deferred.
- **Status atom conversion** (EXPD-05) — All-resources-at-once sweep. Deferred.
- **Shared resource macro/DSL** — Not needed.
- **Nested resource helpers** — e.g., `Customer.list_payment_methods/2`. Use `PaymentMethod.list(client, %{"customer" => cus_id})`.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SINT-01 | User can create a SetupIntent for saving payment methods | `POST /v1/setup_intents` — same pattern as PaymentIntent.create |
| SINT-02 | User can retrieve a SetupIntent by ID | `GET /v1/setup_intents/:id` — same pattern as retrieve in all resources |
| SINT-03 | User can update a SetupIntent | `POST /v1/setup_intents/:id` — same pattern as update |
| SINT-04 | User can confirm a SetupIntent | `POST /v1/setup_intents/:id/confirm` — same pattern as PaymentIntent.confirm |
| SINT-05 | User can cancel a SetupIntent | `POST /v1/setup_intents/:id/cancel` — same pattern as PaymentIntent.cancel |
| SINT-06 | User can list SetupIntents with filters and pagination | `GET /v1/setup_intents` — same list/stream! pattern |
| PMTH-01 | User can create a PaymentMethod | `POST /v1/payment_methods` — pure pass-through, no local validation |
| PMTH-02 | User can retrieve a PaymentMethod by ID | `GET /v1/payment_methods/:id` — standard retrieve |
| PMTH-03 | User can update a PaymentMethod | `POST /v1/payment_methods/:id` — standard update |
| PMTH-04 | User can list PaymentMethods for a customer | `GET /v1/payment_methods` with required `customer` param validation via `Resource.require_param!/3` |
| PMTH-05 | User can attach a PaymentMethod to a customer | `POST /v1/payment_methods/:id/attach` — params map pattern, `%{"customer" => "cus_..."}` |
| PMTH-06 | User can detach a PaymentMethod from a customer | `POST /v1/payment_methods/:id/detach` — returns `%PaymentMethod{customer: nil}` naturally |
</phase_requirements>

---

## Standard Stack

This phase adds no new dependencies. All tooling is established from Phases 1-4.

### Core (already in mix.exs)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | ~> 0.21 | HTTP transport (default adapter) | Already used, handles connection pooling |
| Jason | ~> 1.4 | JSON encoding/decoding | Already used, ecosystem standard |
| Mox | ~> 1.2 | Behaviour-based test mocks | Already used for Transport mocking |
| ExUnit | (stdlib) | Test framework | Already used throughout |

**No new installations required for this phase.**

## Architecture Patterns

### Recommended Project Structure (after Phase 5)

```
lib/lattice_stripe/
├── resource.ex          # NEW: shared helpers (@moduledoc false)
├── setup_intent.ex      # NEW: SetupIntent resource module
├── payment_method.ex    # NEW: PaymentMethod resource module
├── customer.ex          # MODIFIED: uses Resource helpers
├── payment_intent.ex    # MODIFIED: uses Resource helpers + search added
├── client.ex
├── request.ex
├── response.ex
└── list.ex

test/
├── support/
│   └── test_helpers.ex  # NEW: shared test helpers
└── lattice_stripe/
    ├── resource_test.exs           # NEW
    ├── setup_intent_test.exs       # NEW
    ├── payment_method_test.exs     # NEW
    ├── customer_test.exs           # MODIFIED: uses shared helpers
    └── payment_intent_test.exs     # MODIFIED: uses shared helpers
```

### Pattern 1: Resource Helper Module

The `LatticeStripe.Resource` module centralizes the three private helpers that are currently
duplicated identically in Customer and PaymentIntent. After extraction, each resource module
calls these as `Resource.unwrap_singular(result, &from_map/1)` or uses private delegating
wrappers.

**Key design choice from CONTEXT.md D-05:** `@moduledoc false` — this is an internal SDK
helper, not public API surface. Users interact with resource modules directly.

```elixir
# Source: CONTEXT.md D-05, extrapolated from Customer/PaymentIntent implementations
defmodule LatticeStripe.Resource do
  @moduledoc false

  alias LatticeStripe.{Error, List, Response}

  @spec unwrap_singular({:ok, Response.t()} | {:error, Error.t()}, (map() -> struct())) ::
          {:ok, struct()} | {:error, Error.t()}
  def unwrap_singular({:ok, %Response{data: data}}, from_map_fn) do
    {:ok, from_map_fn.(data)}
  end
  def unwrap_singular({:error, %Error{}} = error, _from_map_fn), do: error

  @spec unwrap_list({:ok, Response.t()} | {:error, Error.t()}, (map() -> struct())) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def unwrap_list({:ok, %Response{data: %List{} = list} = resp}, from_map_fn) do
    typed_items = Enum.map(list.data, from_map_fn)
    {:ok, %{resp | data: %{list | data: typed_items}}}
  end
  def unwrap_list({:error, %Error{}} = error, _from_map_fn), do: error

  @spec unwrap_bang!({:ok, term()} | {:error, Error.t()}) :: term()
  def unwrap_bang!({:ok, result}), do: result
  def unwrap_bang!({:error, %Error{} = error}), do: raise(error)

  @spec require_param!(map(), String.t(), String.t()) :: :ok
  def require_param!(params, key, message) do
    unless Map.has_key?(params, key) do
      raise ArgumentError, message
    end
    :ok
  end
end
```

### Pattern 2: SetupIntent Module

SetupIntent follows PaymentIntent almost exactly — same lifecycle verbs (confirm/cancel), same
`client_secret` hiding in Inspect, same `latest_attempt` raw-value pattern.

Key differences from PaymentIntent:
- `usage` field (instead of `capture_method`) — values: `"off_session"`, `"on_session"`, `"online"`
- `verify_microdeposits` action verb (bonus endpoint, D-24)
- No `amount`/`currency` — SetupIntent is for saving, not charging
- Inspect shows `id`, `object`, `status`, `usage` (not `amount`/`currency`)

**Stripe API endpoints (HIGH confidence — verified via official docs):**

| Operation | HTTP | Path |
|-----------|------|------|
| create | POST | `/v1/setup_intents` |
| retrieve | GET | `/v1/setup_intents/:id` |
| update | POST | `/v1/setup_intents/:id` |
| confirm | POST | `/v1/setup_intents/:id/confirm` |
| cancel | POST | `/v1/setup_intents/:id/cancel` |
| list | GET | `/v1/setup_intents` |
| verify_microdeposits | POST | `/v1/setup_intents/:id/verify_microdeposits` |

**SetupIntent struct fields (from Stripe API reference — HIGH confidence):**

```
id, object, application, attach_to_self, automatic_payment_methods,
cancellation_reason, client_secret, created, customer, customer_account,
description, excluded_payment_method_types, flow_directions,
last_setup_error, latest_attempt, livemode, mandate, metadata,
next_action, on_behalf_of, payment_method, payment_method_configuration_details,
payment_method_options, payment_method_types, single_use_mandate, status, usage
```

**cancellation_reason values:** `"abandoned"`, `"duplicate"`, `"requested_by_customer"`

**status values:** `"requires_payment_method"`, `"requires_confirmation"`, `"requires_action"`,
`"processing"`, `"canceled"`, `"succeeded"`

### Pattern 3: PaymentMethod Module

PaymentMethod is the most field-heavy struct in the SDK (~45 top-level fields). Key unique
behaviors:

- `attach/4`: `POST /v1/payment_methods/:id/attach` with `%{"customer" => "cus_..."}` in params
- `detach/3`: `POST /v1/payment_methods/:id/detach` — returns PaymentMethod with `customer: nil`
- `list/3`: requires `"customer"` in params — enforced via `Resource.require_param!/3`
- `stream!/3`: same customer validation before building request
- No `delete` function — Stripe API does not offer delete for PaymentMethods

**Stripe API endpoints (HIGH confidence — verified via official docs):**

| Operation | HTTP | Path |
|-----------|------|------|
| create | POST | `/v1/payment_methods` |
| retrieve | GET | `/v1/payment_methods/:id` |
| update | POST | `/v1/payment_methods/:id` |
| list | GET | `/v1/payment_methods` (requires customer param per SDK policy) |
| attach | POST | `/v1/payment_methods/:id/attach` |
| detach | POST | `/v1/payment_methods/:id/detach` |

**PaymentMethod struct fields (from Stripe API reference — HIGH confidence):**

Top-level: `id`, `object`, `type`, `created`, `livemode`, `customer`, `metadata`,
`allow_redisplay`, `billing_details`, `radar_options`

Type-specific nested objects (all nil unless type matches):
`card`, `card_present`, `us_bank_account`, `sepa_debit`, `au_becs_debit`, `bacs_debit`,
`acss_debit`, `nz_bank_account`, `paypal`, `alipay`, `wechat_pay`, `kakao_pay`, `naver_pay`,
`samsung_pay`, `link`, `ideal`, `fpx`, `eps`, `klarna`, `affirm`, `afterpay_clearpay`,
`alma`, `billie`, `boleto`, `sofort`, `cashapp`, `p24`, `giropay`, `bancontact`, `oxxo`,
`konbini`, `grabpay`, `paynow`, `promptpay`, `zip`, `revolut_pay`, `swish`, `twint`,
`mobilepay`, `multibanco`, `customer_balance`, `interac_present`

### Pattern 4: PaymentMethod Inspect with Conditional Card Fields

The Inspect implementation for PaymentMethod is unique — it shows card brand/last4 when
`type == "card"`, which requires a conditional in the Inspect impl.

```elixir
# Source: CONTEXT.md D-23, Inspect.Algebra pattern from Phase 4 PaymentIntent
defimpl Inspect, for: LatticeStripe.PaymentMethod do
  import Inspect.Algebra

  def inspect(pm, opts) do
    base_fields = [
      id: pm.id,
      object: pm.object,
      type: pm.type
    ]

    card_fields =
      if pm.type == "card" && pm.card do
        [card_brand: pm.card["brand"], card_last4: pm.card["last4"]]
      else
        []
      end

    fields = base_fields ++ card_fields

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.PaymentMethod<" | pairs] ++ [">"])
  end
end
```

### Pattern 5: Shared Test Helpers Extraction

The `test_client/0`, `ok_response/1`, `error_response/0`, and `list_json/2` helpers are
currently defined identically (with minor variations) in both CustomerTest and PaymentIntentTest.
Extract to `test/support/test_helpers.ex` using `defmodule LatticeStripe.TestHelpers`.

Key: the `list_json/2` function signature generalizes to accept a `url` parameter:
```elixir
def list_json(items, url \\ "/v1/objects") do
  %{
    "object" => "list",
    "data" => items,
    "has_more" => false,
    "url" => url
  }
end
```

The `test_client/1` should accept optional overrides so tests can vary specific settings:
```elixir
def test_client(overrides \\ []) do
  defaults = [
    api_key: "sk_test_123",
    finch: :test_finch,
    transport: LatticeStripe.MockTransport,
    telemetry_enabled: false,
    max_retries: 0
  ]
  Client.new!(Keyword.merge(defaults, overrides))
end
```

For `test/support/` to be compiled in tests, `mix.exs` must include the path. Check existing
`mix.exs` for `elixirc_paths` — may need `"test/support"` added for the `:test` env.

### Anti-Patterns to Avoid

- **Duplicating `unwrap_*` helpers again:** Now that `Resource` module exists, new resource modules
  must use it rather than copying private helpers. The resource test (`resource_test.exs`) validates
  the helpers in isolation.
- **Validating `type` in PaymentMethod.create:** D-26 explicitly says no local validation. Let Stripe
  return a clear error. Defensive validation here would duplicate Stripe's own validation logic.
- **Raising for `list` without customer on PaymentMethod:** Use `ArgumentError` (not
  `LatticeStripe.Error`). The check happens before any network call — it's a programming error,
  not an API error.
- **Making attach/detach return special types:** Both return `%PaymentMethod{}` through the normal
  `unwrap_singular` path — no special return types needed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP request execution | Custom HTTP | `Client.request/2` (existing) | Already handles retry, telemetry, transport dispatch |
| Auto-pagination | Custom stream logic | `List.stream!/2` (existing) | Already handles cursor-based and search pagination |
| Form encoding | Custom encoder | `FormEncoder` (existing) | Already handles nested maps |
| Inspect output | `inspect/1` callback or `__struct__` override | `Inspect.Algebra` (as in Phase 4) | Consistent with PaymentIntent pattern, properly hides secrets |
| Required param validation | Inline guard/if/raise | `Resource.require_param!/3` | Centralizes validation, consistent error message format |
| JSON building in tests | Inline maps | `LatticeStripe.TestHelpers` helper functions | DRY, consistent test fixtures |

**Key insight:** This phase is almost entirely composition of existing building blocks. The value
is in applying the established pattern correctly to two new Stripe objects, not in novel
infrastructure work.

## Common Pitfalls

### Pitfall 1: test/support/ Not Compiled

**What goes wrong:** `LatticeStripe.TestHelpers` module not found at compile time in tests.

**Why it happens:** Elixir only compiles files in `elixirc_paths`, which defaults to `["lib"]`
in `:test` env. `test/support/` files must be explicitly added.

**How to avoid:** In `mix.exs`, ensure:
```elixir
def project do
  [
    ...
    elixirc_paths: elixirc_paths(Mix.env()),
    ...
  ]
end

defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]
```

**Warning signs:** `UndefinedFunctionError` or `CompileError` referencing `TestHelpers` during
`mix test`.

### Pitfall 2: Resource.unwrap_singular/2 Arity Change During Refactor

**What goes wrong:** Customer/PaymentIntent currently call `unwrap_singular(result)` (1-arg
private function). After extraction to `Resource`, the signature adds `from_map_fn` as second
argument. Refactoring callers but missing some private call sites causes compile errors.

**Why it happens:** The private helpers are called by name in many places — easy to miss one.

**How to avoid:** After extraction, each resource module should have a private delegating wrapper
that captures `&from_map/1` locally, keeping call sites in CRUD functions unchanged:

```elixir
defp unwrap_singular(result), do: Resource.unwrap_singular(result, &from_map/1)
defp unwrap_list(result), do: Resource.unwrap_list(result, &from_map/1)
defp unwrap_bang!(result), do: Resource.unwrap_bang!(result)
```

This approach minimizes the diff in CRUD functions during refactor and is simpler than changing
every call site.

### Pitfall 3: PaymentMethod List Validation Skipped in stream!/3

**What goes wrong:** `list/3` validates the customer param but `stream!/3` does not, allowing
a stream to be constructed then fail on first page fetch rather than at construction time.

**Why it happens:** Stream functions build a lazy structure; the validation must happen eagerly
before `List.stream!/2` is called.

**How to avoid:** D-14 is explicit — call `Resource.require_param!/3` at the top of `stream!/3`
before constructing the `%Request{}`.

**Warning signs:** A test that calls `stream!` without customer param compiles and constructs
a stream object rather than raising immediately.

### Pitfall 4: PaymentMethod @known_fields Missing Type-Specific Fields

**What goes wrong:** If type-specific fields like `card`, `us_bank_account` etc. are not in
`@known_fields`, they end up in the `extra` map instead of dedicated struct fields. Accessing
`pm.card` returns `nil` even when a card PM is returned.

**Why it happens:** The `extra: Map.drop(map, @known_fields)` pattern requires ALL known fields
to be listed in `@known_fields`.

**How to avoid:** `@known_fields` must include both top-level scalar fields AND all type-specific
nested object keys (card, us_bank_account, etc.).

### Pitfall 5: SetupIntent Inspect Shows client_secret Field Name

**What goes wrong:** If `client_secret` appears as a key in inspect output (even with `nil`
value), it leaks that the field exists in the struct and could confuse future log analysis.

**Why it happens:** Using `Inspect.Any.inspect(pi, opts)` or default struct inspect shows all
fields.

**How to avoid:** Use `Inspect.Algebra` with an explicit field list — same pattern as
PaymentIntent. The field name `client_secret` must not appear in output at all (D-22).

### Pitfall 6: detach/3 vs detach/4 Arity

**What goes wrong:** Using `detach(client, id, params \\ %{}, opts \\ [])` (4 args) instead
of `detach(client, id, opts \\ [])` (3 args as per D-11 naming convention) would be inconsistent
since detach takes no meaningful params.

**Why it happens:** Cargo-culting the action verb pattern from confirm/capture/cancel which have
optional params.

**How to avoid:** Detach sends no body params to Stripe — use `detach(client, id, opts \\ [])`.
The request is `POST /v1/payment_methods/:id/detach` with empty body.

## Code Examples

### Resource Module Helper Usage in Resource Module

```elixir
# Source: CONTEXT.md D-05, pattern extrapolated from Customer/PaymentIntent
defmodule LatticeStripe.SetupIntent do
  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/setup_intents", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> unwrap_singular()
  end

  def confirm(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/setup_intents/#{id}/confirm", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> unwrap_singular()
  end

  def verify_microdeposits(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{
      method: :post,
      path: "/v1/setup_intents/#{id}/verify_microdeposits",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> unwrap_singular()
  end

  # Private delegating wrappers — keeps CRUD call sites unchanged after Resource extraction
  defp unwrap_singular(result), do: Resource.unwrap_singular(result, &from_map/1)
  defp unwrap_list(result), do: Resource.unwrap_list(result, &from_map/1)
  defp unwrap_bang!(result), do: Resource.unwrap_bang!(result)
end
```

### PaymentMethod Attach/Detach

```elixir
# Source: CONTEXT.md D-11, D-12, verified against Stripe API docs
def attach(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{
    method: :post,
    path: "/v1/payment_methods/#{id}/attach",
    params: params,
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> unwrap_singular()
end

def detach(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{
    method: :post,
    path: "/v1/payment_methods/#{id}/detach",
    params: %{},
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> unwrap_singular()
end
```

### PaymentMethod List with Validation

```elixir
# Source: CONTEXT.md D-13, D-15
def list(%Client{} = client, params \\ %{}, opts \\ []) do
  Resource.require_param!(params, "customer",
    "PaymentMethod.list/3 requires a \"customer\" param. " <>
    "Pass %{\"customer\" => \"cus_...\"} as the second argument.")
  %Request{method: :get, path: "/v1/payment_methods", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> unwrap_list()
end

def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  Resource.require_param!(params, "customer",
    "PaymentMethod.stream!/3 requires a \"customer\" param. " <>
    "Pass %{\"customer\" => \"cus_...\"} as the second argument.")
  req = %Request{method: :get, path: "/v1/payment_methods", params: params, opts: opts}
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

### Shared Test Helper Usage

```elixir
# Source: CONTEXT.md D-08, D-09, extrapolated from CustomerTest patterns
defmodule LatticeStripe.SetupIntentTest do
  use ExUnit.Case, async: true
  import Mox
  import LatticeStripe.TestHelpers   # test_client/1, ok_response/1, etc.

  alias LatticeStripe.{Client, Error, List, Response, SetupIntent}

  setup :verify_on_exit!

  # Resource-specific fixture builder stays in this file (D-09)
  defp setup_intent_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "seti_test123",
        "object" => "setup_intent",
        "status" => "requires_payment_method",
        "usage" => "off_session",
        "client_secret" => "seti_test123_secret_abc",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{}
      },
      overrides
    )
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Duplicate helpers in each resource | Shared `Resource` module | Phase 5 | DRY; new resources just import |
| Per-test-file `test_client/0` | Shared `TestHelpers.test_client/1` | Phase 5 | DRY; consistent test setup |
| No customer scoping enforcement | `require_param!` for PM list | Phase 5 | Developer experience: fail fast |

**Not deprecated, still current:**
- `@known_fields` + `extra: Map.drop(...)` pattern — continues for all resources
- `Inspect.Algebra` pattern — continues for all resources with secrets

## Open Questions

1. **`Resource.unwrap_singular/2` vs private delegating wrappers**
   - What we know: CONTEXT.md D-05 specifies the Resource module API with `from_map_fn` argument
   - What's unclear: Whether callers use `Resource.unwrap_singular(result, &from_map/1)` directly
     or each resource keeps a private `defp unwrap_singular(result)` wrapper
   - Recommendation: Use private delegating wrappers in each resource module — minimizes diff
     during refactor and keeps CRUD function bodies identical to pre-refactor

2. **`test/support/test_helpers.ex` module name**
   - What we know: D-08 specifies the file path
   - What's unclear: Module name convention — `LatticeStripe.TestHelpers` vs bare `TestHelpers`
   - Recommendation: Use `LatticeStripe.TestHelpers` for consistency with the project namespace

3. **PaymentMethod @known_fields completeness**
   - What we know: ~45 type-specific fields from Stripe API reference
   - What's unclear: Whether Stripe has added new payment method types since API reference was
     checked (April 2026)
   - Recommendation: Use the list researched above; `extra` map catches any new types gracefully

## Environment Availability

Step 2.6: SKIPPED — this phase adds no external dependencies. All tooling (Elixir, Mix, Mox,
ExUnit) is already verified operational from Phases 1-4.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, Elixir 1.15+) |
| Config file | `test/test_helper.exs` (exists — defines MockTransport, MockJson, MockRetryStrategy mocks) |
| Quick run command | `mix test test/lattice_stripe/setup_intent_test.exs test/lattice_stripe/payment_method_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SINT-01 | `SetupIntent.create/3` returns `{:ok, %SetupIntent{}}` | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ Wave 0 |
| SINT-02 | `SetupIntent.retrieve/3` returns `{:ok, %SetupIntent{}}` | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ Wave 0 |
| SINT-03 | `SetupIntent.update/4` returns `{:ok, %SetupIntent{}}` | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ Wave 0 |
| SINT-04 | `SetupIntent.confirm/4` returns `{:ok, %SetupIntent{}}` | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ Wave 0 |
| SINT-05 | `SetupIntent.cancel/4` returns `{:ok, %SetupIntent{}}` | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ Wave 0 |
| SINT-06 | `SetupIntent.list/3` returns typed list with pagination | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ Wave 0 |
| PMTH-01 | `PaymentMethod.create/3` returns `{:ok, %PaymentMethod{}}` | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ Wave 0 |
| PMTH-02 | `PaymentMethod.retrieve/3` returns `{:ok, %PaymentMethod{}}` | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ Wave 0 |
| PMTH-03 | `PaymentMethod.update/4` returns `{:ok, %PaymentMethod{}}` | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ Wave 0 |
| PMTH-04 | `PaymentMethod.list/3` raises when customer missing, returns typed list when present | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ Wave 0 |
| PMTH-05 | `PaymentMethod.attach/4` posts to `/attach` and returns `{:ok, %PaymentMethod{}}` | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ Wave 0 |
| PMTH-06 | `PaymentMethod.detach/3` posts to `/detach` and returns `{:ok, %PaymentMethod{customer: nil}}` | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/resource_test.exs test/lattice_stripe/customer_test.exs test/lattice_stripe/payment_intent_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/support/test_helpers.ex` — shared helpers (test_client, ok_response, error_response, list_json)
- [ ] `test/lattice_stripe/resource_test.exs` — unit tests for Resource helper module
- [ ] `test/lattice_stripe/setup_intent_test.exs` — covers SINT-01 through SINT-06
- [ ] `test/lattice_stripe/payment_method_test.exs` — covers PMTH-01 through PMTH-06
- [ ] `mix.exs` elixirc_paths: verify `test/support` is in `:test` env paths

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 5 |
|-----------|-------------------|
| No Dialyzer | Typespecs on Resource module and new structs are for docs only |
| Jason for JSON | No changes — already used throughout |
| Minimal dependencies | No new deps — Resource module uses existing aliases |
| Transport behaviour with Finch default | No changes — resource modules use `Client.request/2` |
| Typespecs for documentation only | Include `@spec` on all public functions but don't enforce |
| No Jason.Encoder on structs | SetupIntent and PaymentMethod must NOT derive Jason.Encoder |
| Mox for testing | Resource-specific tests use `LatticeStripe.MockTransport` |
| No GenServer for state | No process-based state — all struct-based |

## Sources

### Primary (HIGH confidence)

- Stripe API Reference: SetupIntents object — `https://docs.stripe.com/api/setup_intents/object` — field list, status values, cancellation reasons verified
- Stripe API Reference: SetupIntents endpoints — `https://docs.stripe.com/api/setup_intents/create` — all 7 endpoints verified (create/retrieve/update/confirm/cancel/list/verify_microdeposits)
- Stripe API Reference: PaymentMethods object — `https://docs.stripe.com/api/payment_methods/object` — field list, type-specific nested objects verified
- Stripe API Reference: PaymentMethods attach — `https://docs.stripe.com/api/payment_methods/attach` — `POST /v1/payment_methods/:id/attach` with `customer` param verified
- Stripe API Reference: PaymentMethods detach — `https://docs.stripe.com/api/payment_methods/detach` — `POST /v1/payment_methods/:id/detach`, response has `customer: null` verified
- Stripe API Reference: PaymentMethods list — `https://docs.stripe.com/api/payment_methods/list` — `GET /v1/payment_methods`, `customer` optional at API level (SDK enforces per D-13) verified
- Existing codebase: `lib/lattice_stripe/customer.ex` — established pattern for Resource module extraction
- Existing codebase: `lib/lattice_stripe/payment_intent.ex` — established pattern for action verbs (confirm/cancel)
- Existing codebase: `test/lattice_stripe/customer_test.exs` — established test helper patterns for extraction
- CONTEXT.md decisions D-01 through D-28 — authoritative for all implementation decisions

### Secondary (MEDIUM confidence)

None required — Stripe official docs and existing codebase provide sufficient HIGH confidence basis.

### Tertiary (LOW confidence)

None — no unverified claims.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no new dependencies, all existing
- Architecture (SetupIntent): HIGH — verified Stripe endpoints + direct Pattern 2 (PaymentIntent) extension
- Architecture (PaymentMethod): HIGH — verified Stripe endpoints + unique attach/detach/list validation patterns verified against docs
- Resource module extraction: HIGH — exact code exists in Customer and PaymentIntent, extraction is mechanical
- PaymentMethod struct fields: HIGH — verified against Stripe API reference (April 2026)
- Test patterns: HIGH — extrapolated from existing test files with no ambiguity

**Research date:** 2026-04-02
**Valid until:** 2026-07-02 (Stripe API reference is stable; resource module pattern is locked)
