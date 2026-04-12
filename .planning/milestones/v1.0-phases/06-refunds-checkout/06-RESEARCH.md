# Phase 6: Refunds & Checkout - Research

**Researched:** 2026-04-02
**Domain:** Stripe Refund API, Stripe Checkout Session API, Elixir resource module patterns
**Confidence:** HIGH

## Summary

Phase 6 adds two resource areas on top of the established resource module pattern from Phases 4 and 5. Refund is a straightforward resource with create/retrieve/update/cancel/list/stream — simpler than PaymentIntent because it has no multi-step lifecycle actions like confirm or capture. Checkout Session is the most complex resource so far: a deeply-nested object with 50+ fields, three create modes (payment/subscription/setup), a nested list_line_items endpoint, search support, and an expire action.

The phase also introduces a retroactive infrastructure improvement: extracting inline JSON builders from existing test files into dedicated fixture modules in `test/support/fixtures/`. This is prep work that gives all subsequent phases a clean, reusable test data layer.

The entire phase builds on patterns already proven in Phases 4 and 5. No new infrastructure is needed — `LatticeStripe.Resource`, `LatticeStripe.List`, and `LatticeStripe.TestHelpers` are all reused without modification. The Checkout.Session module introduces the first nested-namespace module (`LatticeStripe.Checkout.Session`), establishing the pattern for future nested resources.

**Primary recommendation:** Implement Plan 06-01 (fixture extraction + Refund) before 06-02 (Checkout Session + LineItem). This validates the fixture pattern on the simpler resource before the more complex one.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Refund API Design**
- D-01: PaymentIntent-only scoping for Refund.create. `payment_intent` is required in params. Charge-based refunds are legacy — not supported.
- D-02: Refund.create validates `payment_intent` presence via `Resource.require_param!/3`. Raises `ArgumentError` if missing.
- D-03: Include `Refund.cancel/3` — `cancel(client, id, params \\ %{})`. Completes the Refund API for pending refunds.
- D-04: No required params for `Refund.list/2`. All params optional.
- D-05: No local validation of `reason` param values. Pass through to Stripe.
- D-06: Include `Refund.stream!/2` for auto-pagination.
- D-07: No search endpoint — Stripe doesn't offer search for Refunds.
- D-08: All special params (reverse_transfer, refund_application_fee, metadata) are pure pass-through.
- D-09: No `Refund.delete/2` — refunds are financial records, cannot be deleted.
- D-10: `Refund.update/3` @doc notes: "Only the metadata field can be updated on a Refund."
- D-11: `Refund.create/3` arity — `create(client, params, opts \\ [])`. Resources that require params use /3.

**Checkout Session Design**
- D-12: Module name: `LatticeStripe.Checkout.Session`. File at `lib/lattice_stripe/checkout/session.ex`.
- D-13: All known top-level fields as struct keys + `extra` map. Nested objects (payment_method_options, shipping_options, custom_text, total_details) remain as plain maps per Phase 4 D-06.
- D-14: `Checkout.Session.create/3` validates `mode` param via `require_param!/3`. Does NOT validate `success_url` or `line_items`.
- D-15: Include `list_line_items/3` — `Checkout.Session.list_line_items(client, session_id, params)`.
- D-16: Include `stream_line_items!/3` — wraps `List.stream!/2` with `LineItem.from_map/1`.
- D-17: Include `search/3` + `search_stream!/3`. Same pattern as Customer.search.
- D-18: `expire/3` — `expire(client, id, params \\ %{})`. No local validation.
- D-19: Include `stream!/2` for auto-paginating list results.
- D-20: No `update` function — Checkout Sessions cannot be updated via API.
- D-21: No `delete` function.
- D-22: Brief @moduledoc note: "Some fields can be modified via the Stripe Dashboard but not through the API."
- D-23: `create/3` arity — `create(client, params, opts \\ [])`.

**Checkout LineItem**
- D-24: Create `LatticeStripe.Checkout.LineItem` struct with `from_map/1`, `@known_fields`, `extra` map.
- D-25: Separate file: `lib/lattice_stripe/checkout/line_item.ex`.
- D-26: Public `@moduledoc` noting provenance: "Represents a line item in a Checkout Session. Returned by `Checkout.Session.list_line_items/3`. Line items cannot be created or fetched independently."
- D-27: LineItem Inspect shows: `id`, `object`, `description`, `quantity`, `amount_total`.

**Inspect Implementation**
- D-28: Refund Inspect shows: `id`, `object`, `amount`, `currency`, `status`. Hides payment_intent, reason, metadata, destination_details.
- D-29: Checkout.Session Inspect shows: `id`, `object`, `mode`, `status`, `payment_status`, `amount_total`, `currency` (7 fields). Hides all PII.
- D-30: All PII fields hidden in Checkout.Session Inspect — customer_email, customer_details, shipping_details.

**Struct Design**
- D-31: Standard dot-access only — no custom Access behaviour.
- D-32: All nested objects as plain maps. Typed expansion deferred with EXPD-02.
- D-33: Refund `destination_details` is a struct field with plain map value.

**Error Handling**
- D-34: No new error types. Use existing Error struct.
- D-35: Standard error pass-through for expire on completed session, refund on fully-refunded PI.
- D-36: `require_param!` raises `ArgumentError`. Same as PaymentMethod.list.

**Bang Variants**
- D-37: All tuple-returning functions get bang variants. create!/3, retrieve!/2, update!/3, cancel!/3, list!/2, search!/3, list_line_items!/3, expire!/3.

**Plan Structure**
- D-38: Two plans: 06-01 (fixture extraction + Refund), 06-02 (Checkout Session + LineItem).
- D-39: 06-01 starts with fixture extraction as prep step.
- D-40: 06-02 builds Session first, then LineItem + nested endpoints.
- D-41: Larger 06-02 is acceptable.

**Test Strategy**
- D-42: Separate fixture modules per resource in `test/support/fixtures/`. Module names: `LatticeStripe.Test.Fixtures.{Resource}`.
- D-43: Naming: `refund_json/0`, `refund_partial_json/0`, `refund_pending_json/0`, `checkout_session_payment_json/0`, etc.
- D-44: Overridable fixtures: `refund_json/0` for defaults, `refund_json/1` accepts overrides map with `Map.merge`.
- D-45: Retroactive migration: inline JSON builders extracted to fixture modules with realistic-looking data.
- D-46: Fixture modules imported in test files: `import LatticeStripe.Test.Fixtures.Refund`.
- D-47: TestHelpers' response wrappers stay in test_helpers.ex.
- D-48: Test all 3 Checkout create modes separately.
- D-49: Standard test coverage + mode-specific. No additional edge case tests.
- D-50: `elixirc_paths(:test)` already covers `test/support/` recursively — no mix.exs changes needed.

**Documentation**
- D-51: Key caveats only in @doc — don't replicate Stripe's full docs.
- D-52: Link to Stripe API reference in each @moduledoc.
- D-53: Realistic params in @doc examples.
- D-54: All 3 Checkout mode examples in create's @doc.
- D-55: @doc for create notes: "url field contains the hosted Checkout page link. Only present when status is open. Expires 24 hours after creation."
- D-56: @doc for create notes embedded mode: "When ui_mode is embedded, success_url is not required — use return_url instead."
- D-57: No per-module API version documentation.
- D-58: LineItem @moduledoc notes provenance and non-fetchability.

### Claude's Discretion
- Internal `from_map/1` implementation details for all structs
- Exact struct field lists (follow Stripe's API reference)
- @moduledoc and @doc content, formatting, and example data beyond what's specified
- Helper function organization within modules
- Exact fixture data shapes and scenario coverage
- Task ordering within each plan
- How to handle optional/nilable fields on structs

### Deferred Ideas (OUT OF SCOPE)
- Type registry — `%{"customer" => Customer, ...}` for automatic deserialization. Deferred to Phase 7.
- Typed expansion (EXPD-02) — Expanded nested objects deserialized into typed structs.
- Status atom conversion (EXPD-05) — Convert string status fields to atoms.
- Shared resource macro/DSL — Not needed. Hand-written modules + Resource helper module is sufficient.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RFND-01 | User can create a Refund (full or partial) for a PaymentIntent | `Refund.create/3` with `require_param!` enforcing `"payment_intent"` key; POST /v1/refunds |
| RFND-02 | User can retrieve a Refund by ID | `Refund.retrieve/3`; GET /v1/refunds/:id |
| RFND-03 | User can update a Refund | `Refund.update/4`; POST /v1/refunds/:id; only metadata is updatable |
| RFND-04 | User can list Refunds with filters and pagination | `Refund.list/3` + `Refund.stream!/2`; GET /v1/refunds; no required params |
| CHKT-01 | User can create a Checkout Session in payment mode | `Checkout.Session.create/3` with `%{"mode" => "payment", ...}`; POST /v1/checkout/sessions |
| CHKT-02 | User can create a Checkout Session in subscription mode | Same function, `%{"mode" => "subscription", ...}` |
| CHKT-03 | User can create a Checkout Session in setup mode | Same function, `%{"mode" => "setup", ...}` |
| CHKT-04 | User can configure line items, customer prefill, and success/cancel URLs | Params pass-through; `require_param!` only enforces `"mode"`; all others pass-through |
| CHKT-05 | User can retrieve a Checkout Session by ID | `Checkout.Session.retrieve/3`; GET /v1/checkout/sessions/:id |
| CHKT-06 | User can list Checkout Sessions with filters and pagination | `Checkout.Session.list/3` + `stream!/2`; GET /v1/checkout/sessions |
| CHKT-07 | User can expire an incomplete Checkout Session | `Checkout.Session.expire/3`; POST /v1/checkout/sessions/:id/expire |
</phase_requirements>

---

## Standard Stack

No new dependencies. Phase 6 uses exactly the same stack as Phases 4 and 5.

### Core (already in mix.exs)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Jason | ~> 1.4 | JSON decode | Confirmed in mix.exs |
| Finch | ~> 0.19 | HTTP transport | Confirmed in mix.exs |
| Mox | ~> 1.2 | Test mocks | Confirmed in mix.exs, test only |

**Installation:** No new packages. All dependencies already present.

---

## Architecture Patterns

### Recommended Project Structure

```
lib/
└── lattice_stripe/
    ├── refund.ex                     # NEW — LatticeStripe.Refund
    └── checkout/
        ├── session.ex                # NEW — LatticeStripe.Checkout.Session
        └── line_item.ex              # NEW — LatticeStripe.Checkout.LineItem

test/
├── support/
│   ├── test_helpers.ex               # EXISTS — ok_response/1, error_response/0, list_json/2
│   └── fixtures/                     # NEW directory
│       ├── customer.ex               # NEW — extracted from customer_test.exs
│       ├── payment_intent.ex         # NEW — extracted from payment_intent_test.exs
│       ├── setup_intent.ex           # NEW — extracted from setup_intent_test.exs
│       ├── payment_method.ex         # NEW — extracted from payment_method_test.exs
│       ├── refund.ex                 # NEW — for Refund tests
│       ├── checkout_session.ex       # NEW — for Checkout.Session tests
│       └── checkout_line_item.ex     # NEW — for Checkout.LineItem tests
└── lattice_stripe/
    ├── refund_test.exs               # NEW
    └── checkout/
        └── session_test.exs          # NEW
```

### Pattern 1: Standard Resource Module

Every resource module in this project follows this exact structure. The planner MUST use this pattern for both Refund and Checkout.Session.

```elixir
# Source: lib/lattice_stripe/customer.ex (verified)
defmodule LatticeStripe.Refund do
  @moduledoc "..."

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[id object amount currency status ...]  # string sigil, no `a`

  defstruct [:id, :amount, ..., object: "refund", extra: %{}]

  @type t :: %__MODULE__{...}

  # CRUD functions — each builds %Request{}, calls Client.request/2, unwraps via Resource
  def create(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(params, "payment_intent", "...")  # validate BEFORE building request
    %Request{method: :post, path: "/v1/refunds", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/refunds/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # Action verbs (cancel, expire) follow same pattern as confirm/capture/cancel on PaymentIntent
  def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/refunds/#{id}/cancel", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # List uses unwrap_list
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/refunds", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  # Stream wraps List.stream! with Stream.map(&from_map/1)
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/refunds", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # Bang variants — all delegate to non-bang + unwrap_bang!
  def create!(%Client{} = client, params, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      # ... all fields
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.Refund do
  import Inspect.Algebra
  def inspect(refund, opts) do
    fields = [id: refund.id, object: refund.object, amount: refund.amount,
              currency: refund.currency, status: refund.status]
    pairs = fields |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
                   |> Enum.intersperse(", ")
    concat(["#LatticeStripe.Refund<" | pairs] ++ [">"])
  end
end
```

### Pattern 2: Nested Namespace Module (NEW in Phase 6)

`LatticeStripe.Checkout.Session` is the first module in a sub-namespace. The file lives at `lib/lattice_stripe/checkout/session.ex` and the module is declared as `defmodule LatticeStripe.Checkout.Session`. No special Elixir configuration needed — the directory structure is just for organization.

```elixir
# lib/lattice_stripe/checkout/session.ex
defmodule LatticeStripe.Checkout.Session do
  # Same pattern as other resource modules.
  # Module name uses dot notation for nesting — no special macro needed.
end
```

### Pattern 3: Nested List Endpoint

`list_line_items/3` uses a session-ID-scoped path and returns a typed list with `LineItem.from_map/1`:

```elixir
# POST to /v1/checkout/sessions/:id/line_items
def list_line_items(%Client{} = client, session_id, params \\ %{}, opts \\ [])
    when is_binary(session_id) do
  %Request{
    method: :get,
    path: "/v1/checkout/sessions/#{session_id}/line_items",
    params: params,
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&LineItem.from_map/1)
end

def stream_line_items!(%Client{} = client, session_id, params \\ %{}, opts \\ [])
    when is_binary(session_id) do
  req = %Request{
    method: :get,
    path: "/v1/checkout/sessions/#{session_id}/line_items",
    params: params,
    opts: opts
  }
  List.stream!(client, req) |> Stream.map(&LineItem.from_map/1)
end
```

### Pattern 4: Search Endpoint

Search follows the same pattern established in `Customer.search/3`:

```elixir
# Source: lib/lattice_stripe/customer.ex (verified)
def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
  %Request{
    method: :get,
    path: "/v1/checkout/sessions/search",
    params: %{"query" => query},
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&from_map/1)
end

def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
  req = %Request{
    method: :get,
    path: "/v1/checkout/sessions/search",
    params: %{"query" => query},
    opts: opts
  }
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

### Pattern 5: Fixture Module (NEW in Phase 6)

Each fixture module lives in `test/support/fixtures/`, is compiled as a real module (via `elixirc_paths(:test)`), and is imported in test files. Uses Map.merge for overridable defaults.

```elixir
# test/support/fixtures/refund.ex
defmodule LatticeStripe.Test.Fixtures.Refund do
  @moduledoc false

  def refund_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "re_test123abc",
        "object" => "refund",
        "amount" => 2000,
        "currency" => "usd",
        "status" => "succeeded",
        "payment_intent" => "pi_test123abc",
        "reason" => "requested_by_customer",
        "created" => 1_700_000_000,
        "metadata" => %{}
      },
      overrides
    )
  end

  def refund_partial_json(overrides \\ %{}) do
    Map.merge(refund_json(%{"amount" => 500}), overrides)
  end

  def refund_pending_json(overrides \\ %{}) do
    Map.merge(refund_json(%{"status" => "pending"}), overrides)
  end
end
```

```elixir
# In test file:
import LatticeStripe.Test.Fixtures.Refund

# Use:
ok_response(refund_json())
ok_response(refund_json(%{"status" => "pending"}))
ok_response(list_json([refund_json(), refund_partial_json()]))
```

### Pattern 6: Existing Inline JSON Extraction

The four existing test files have `defp resource_json(overrides \\ %{})` private functions near the top. Migration pattern:

1. Create `test/support/fixtures/customer.ex` with `def customer_json(overrides \\ %{})` (make public)
2. Remove `defp customer_json/1` from `test/lattice_stripe/customer_test.exs`
3. Add `import LatticeStripe.Test.Fixtures.Customer` to the test file
4. Enhance fixture data with realistic-looking Stripe IDs (e.g., `"cus_test1234567890"` not `"cus_123"`)

The existing inline functions are already overridable (take a map, merge with defaults) — the migration preserves that contract exactly. No test logic changes required.

### Anti-Patterns to Avoid

- **Do not add `use`-based macros** — Decisions explicitly defer a shared resource DSL. Each module is hand-written following the pattern.
- **Do not import LineItem module into Session module at compile time for struct matching** — `LineItem.from_map/1` is called at runtime. Use `alias LatticeStripe.Checkout.LineItem` in session.ex.
- **Do not add `Jason.Encoder` to any struct** — Phase 2 decision. Structs are for reading API responses, not for encoding.
- **Do not put fixture logic in TestHelpers** — D-47: transport-level helpers stay in TestHelpers. Resource fixture data goes in `test/support/fixtures/`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auto-pagination | Custom Stream loop | `LatticeStripe.List.stream!/2` | Already implemented in Phase 3; tested and handles cursor threading |
| Request pipeline | Custom HTTP code | `LatticeStripe.Client.request/2` | Handles retry, telemetry, transport dispatch, idempotency key injection |
| List deserialization | Custom JSON parsing | `LatticeStripe.List.from_json/3` | Auto-detected by Client; handles `has_more`, `url`, cursor extraction |
| Required param validation | `if` checks | `LatticeStripe.Resource.require_param!/3` | Established pattern; raises ArgumentError with clear message |
| Result unwrapping | Pattern matching in each function | `Resource.unwrap_singular/2`, `Resource.unwrap_list/2`, `Resource.unwrap_bang!/1` | Consistent, tested helpers |

**Key insight:** All the hard infrastructure is in place. Phase 6 is purely resource implementation on top of a complete foundation.

---

## Stripe API Reference — Verified Field Lists

### Refund Object Fields (HIGH confidence — verified via docs.stripe.com)

```
id, object, amount, currency, status, reason, payment_intent, charge,
destination_details, metadata, created, failure_reason,
failure_balance_transaction, balance_transaction, receipt_number,
source_transfer_reversal, transfer_reversal
```

**Status values:** `pending`, `requires_action`, `succeeded`, `failed`, `canceled`

**Reason values (pass-through, not validated):** `duplicate`, `fraudulent`, `requested_by_customer`, `expired_uncaptured_charge`

**Stripe API endpoints:**
- `POST /v1/refunds` — create
- `GET /v1/refunds/:id` — retrieve
- `POST /v1/refunds/:id` — update (metadata only)
- `POST /v1/refunds/:id/cancel` — cancel (pending refunds only)
- `GET /v1/refunds` — list

### Checkout Session Object Fields (HIGH confidence — verified via docs.stripe.com + stripity_stripe reference)

Core fields (confirmed):
```
id, object, adaptive_pricing, after_expiration, allow_promotion_codes,
amount_subtotal, amount_total, automatic_tax, billing_address_collection,
cancel_url, client_reference_id, client_secret, consent, consent_collection,
created, currency, currency_conversion, custom_fields, custom_text,
customer, customer_creation, customer_details, customer_email,
discounts, expires_at, invoice, invoice_creation, line_items,
livemode, locale, metadata, mode, payment_intent, payment_link,
payment_method_collection, payment_method_configuration_details,
payment_method_options, payment_method_types, payment_status,
phone_number_collection, recovered_from, redirect_on_completion,
return_url, setup_intent, shipping_address_collection, shipping_cost,
shipping_details, shipping_options, status, submit_type, subscription,
success_url, tax_id_collection, total_details, ui_mode, url
```

**Mode values:** `payment`, `subscription`, `setup`
**Status values:** `open`, `complete`, `expired`
**Payment status values:** `paid`, `unpaid`, `no_payment_required`

**Stripe API endpoints:**
- `POST /v1/checkout/sessions` — create (mode required)
- `GET /v1/checkout/sessions/:id` — retrieve
- `GET /v1/checkout/sessions` — list
- `POST /v1/checkout/sessions/:id/expire` — expire
- `GET /v1/checkout/sessions/search` — search
- `GET /v1/checkout/sessions/:id/line_items` — list_line_items

### Checkout LineItem Object Fields (HIGH confidence — verified via docs.stripe.com)

```
id, object, amount_discount, amount_subtotal, amount_tax, amount_total,
currency, description, price, quantity
```

---

## Common Pitfalls

### Pitfall 1: Checkout Session `client_secret` in Inspect
**What goes wrong:** The Session object has a `client_secret` field (used for embedded/custom UI mode). If included in Inspect output, it leaks a sensitive token to logs.
**Why it happens:** Easy to miss when listing 50+ fields — `client_secret` appears benign if you don't know what it's for.
**How to avoid:** D-29 specifies 7 safe Inspect fields. `client_secret` is NOT in that list. The Inspect implementation must only show `id`, `object`, `mode`, `status`, `payment_status`, `amount_total`, `currency`.
**Warning signs:** If the Inspect impl shows all fields or uses `Map.to_list`, audit for sensitive data.

### Pitfall 2: Nested Checkout Session `line_items` Field
**What goes wrong:** The Session object itself has a `line_items` field (a nested list object), but `list_line_items/3` calls a separate endpoint. The `line_items` field in the struct is the inline version Stripe may return; `list_line_items/3` is for paginated fetching.
**Why it happens:** Two different ways to get line items; inline may be truncated by Stripe.
**How to avoid:** Keep `line_items` in `@known_fields` and struct (it's a valid field). Document that `list_line_items/3` is for paginated access. The inline `line_items` field remains a plain map value.
**Warning signs:** Confusion between `session.line_items` (inline, may be nil/truncated) and `list_line_items(client, session_id)` (paginated endpoint).

### Pitfall 3: Checkout `success_url` and `line_items` Not Validated Locally
**What goes wrong:** Developers may expect `require_param!` to validate these fields, but D-14 locks the decision to only validate `mode`. Missing `success_url` or `line_items` is mode-dependent — payment mode requires `success_url`, but embedded mode uses `return_url` instead.
**Why it happens:** Mode-conditional required fields can't be validated locally without encoding complex Stripe business rules.
**How to avoid:** Only validate `mode` via `require_param!`. Document in @doc that `success_url` is required for payment mode unless `ui_mode: "embedded"` (D-55, D-56).
**Warning signs:** Adding more `require_param!` calls than just `mode` in `Checkout.Session.create/3`.

### Pitfall 4: Fixture Module Name Collision with Test File Module
**What goes wrong:** Module `LatticeStripe.Test.Fixtures.PaymentIntent` could clash if test file also defines helpers with the same name.
**Why it happens:** Elixir compiles all modules into the same namespace.
**How to avoid:** Use the `LatticeStripe.Test.Fixtures.` prefix consistently. Test file modules are `LatticeStripe.PaymentIntentTest` — no collision.
**Warning signs:** Compiler errors about duplicate module definitions.

### Pitfall 5: `elixirc_paths` for `test/support/fixtures/` Subdirectory
**What goes wrong:** Fixture files in `test/support/fixtures/` might not be compiled if the path configuration is wrong.
**Why it happens:** Elixir's `elixirc_paths` with `"test/support"` compiles all `.ex` files recursively in that directory — subdirectories are included automatically.
**How to avoid:** D-50 confirms `elixirc_paths(:test) => ["lib", "test/support"]` already in mix.exs covers `test/support/fixtures/` with no changes needed. Verified in mix.exs.
**Warning signs:** `UndefinedFunctionError` for fixture functions at test runtime.

### Pitfall 6: Refund `cancel/3` vs `cancel/4` Arity
**What goes wrong:** PaymentIntent.cancel is `cancel(client, id, params \\ %{}, opts \\ [])` — 4 args. Refund.cancel follows the same shape.
**Why it happens:** Action verb functions take optional params. Easy to define with wrong arity.
**How to avoid:** D-03 specifies `cancel(client, id, params \\ %{})`. All action verb functions accept optional params defaulting to `%{}`. Add opts as 4th arg for consistency with rest of API: `cancel(client, id, params \\ %{}, opts \\ [])`.
**Warning signs:** Omitting `opts` from action verb functions when all other resource functions accept it.

---

## Code Examples

### Refund.create with require_param! validation
```elixir
# Source: lib/lattice_stripe/payment_method.ex (verified pattern)
def create(%Client{} = client, params, opts \\ []) do
  Resource.require_param!(
    params,
    "payment_intent",
    ~s|Refund.create/3 requires a "payment_intent" key in params. | <>
      ~s|Charge-based refunds are not supported. | <>
      ~s|Example: Refund.create(client, %{"payment_intent" => "pi_123", "amount" => 500})|
  )

  %Request{method: :post, path: "/v1/refunds", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Checkout.Session.create with mode validation
```elixir
def create(%Client{} = client, params, opts \\ []) do
  Resource.require_param!(
    params,
    "mode",
    ~s|Checkout.Session.create/3 requires a "mode" key in params. | <>
      ~s|Valid values: "payment", "subscription", "setup". | <>
      ~s|Example: Checkout.Session.create(client, %{"mode" => "payment", ...})|
  )

  %Request{method: :post, path: "/v1/checkout/sessions", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Checkout.Session.expire action verb
```elixir
def expire(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{
    method: :post,
    path: "/v1/checkout/sessions/#{id}/expire",
    params: params,
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Fixture module with overridable/1 pattern
```elixir
# Source: test/lattice_stripe/payment_method_test.exs (verified pattern, extracted form)
defmodule LatticeStripe.Test.Fixtures.Checkout.Session do
  @moduledoc false

  def checkout_session_payment_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cs_test_a1b2c3d4e5f6",
        "object" => "checkout.session",
        "mode" => "payment",
        "status" => "open",
        "payment_status" => "unpaid",
        "amount_total" => 2000,
        "currency" => "usd",
        "success_url" => "https://example.com/success",
        "cancel_url" => "https://example.com/cancel",
        "payment_intent" => "pi_test123",
        "customer" => nil,
        "customer_email" => nil,
        "livemode" => false,
        "created" => 1_700_000_000,
        "expires_at" => 1_700_086_400,
        "metadata" => %{},
        "url" => "https://checkout.stripe.com/pay/cs_test_a1b2c3d4e5f6"
      },
      overrides
    )
  end

  def checkout_session_subscription_json(overrides \\ %{}) do
    Map.merge(
      checkout_session_payment_json(%{
        "mode" => "subscription",
        "payment_intent" => nil,
        "subscription" => "sub_test123"
      }),
      overrides
    )
  end

  def checkout_session_setup_json(overrides \\ %{}) do
    Map.merge(
      checkout_session_payment_json(%{
        "mode" => "setup",
        "payment_intent" => nil,
        "payment_status" => "no_payment_required",
        "setup_intent" => "seti_test123",
        "amount_total" => nil,
        "currency" => nil
      }),
      overrides
    )
  end

  def checkout_session_expired_json(overrides \\ %{}) do
    Map.merge(
      checkout_session_payment_json(%{"status" => "expired", "url" => nil}),
      overrides
    )
  end
end
```

### Test file structure for new resources
```elixir
# test/lattice_stripe/refund_test.exs
defmodule LatticeStripe.RefundTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Refund

  alias LatticeStripe.{Error, List, Refund, Response}

  setup :verify_on_exit!

  describe "create/3" do
    test "sends POST /v1/refunds and returns {:ok, %Refund{}}" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/refunds")
        ok_response(refund_json())
      end)
      assert {:ok, %Refund{id: "re_test123abc", status: "succeeded"}} =
               Refund.create(client, %{"payment_intent" => "pi_123", "amount" => 2000})
    end

    test "raises ArgumentError when payment_intent is missing" do
      client = test_client()
      assert_raise ArgumentError, fn ->
        Refund.create(client, %{"amount" => 2000})
      end
    end
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline `defp fixture_json/1` in test file | Shared fixture module in `test/support/fixtures/` | Phase 6 retroactive | Reusable across tests; imported not duplicated |
| Flat resource modules only | Nested namespace `LatticeStripe.Checkout.Session` | Phase 6 | Establishes pattern for sub-namespaced resources |

**Deprecated/outdated patterns being replaced in this phase:**
- Inline `defp customer_json/1` in `customer_test.exs` — replaced by `LatticeStripe.Test.Fixtures.Customer.customer_json/1`
- Same for `payment_intent_json/1`, `setup_intent_json/1`, `payment_method_json/1`

---

## Open Questions

1. **Checkout Session `branding_settings` and `collected_information` fields**
   - What we know: These appear in some Stripe API versions but not all documentation references
   - What's unclear: Whether they are stable top-level fields or preview features
   - Recommendation: Include in `@known_fields` and struct — they will map to nil if not present, and `extra` catches truly unknown fields

2. **Checkout.Session fixture module name**
   - What we know: D-42 specifies `test/support/fixtures/checkout_session.ex` with module `LatticeStripe.Test.Fixtures.Checkout.Session`
   - What's unclear: Whether file path and module name must match (they don't in Elixir — any file can define any module name)
   - Recommendation: Follow D-42 exactly. File is `checkout_session.ex` (flat in fixtures/), module is `LatticeStripe.Test.Fixtures.Checkout.Session`.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 6 is purely Elixir source code changes. No external tools, services, or CLI utilities beyond the existing project toolchain (already verified in prior phases).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/refund_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RFND-01 | create full refund, create partial refund, ArgumentError when payment_intent missing | unit | `mix test test/lattice_stripe/refund_test.exs --only describe:"create/3"` | Wave 0 |
| RFND-02 | retrieve by ID, error on not found | unit | `mix test test/lattice_stripe/refund_test.exs --only describe:"retrieve/3"` | Wave 0 |
| RFND-03 | update metadata, returns updated refund | unit | `mix test test/lattice_stripe/refund_test.exs --only describe:"update/4"` | Wave 0 |
| RFND-04 | list all refunds, list with filters, stream auto-paginates | unit | `mix test test/lattice_stripe/refund_test.exs --only describe:"list/3"` | Wave 0 |
| CHKT-01 | create session in payment mode | unit | `mix test test/lattice_stripe/checkout/session_test.exs --only describe:"create/3"` | Wave 0 |
| CHKT-02 | create session in subscription mode | unit | same file | Wave 0 |
| CHKT-03 | create session in setup mode | unit | same file | Wave 0 |
| CHKT-04 | line items, customer, urls pass-through in params | unit | same file | Wave 0 |
| CHKT-05 | retrieve by ID | unit | `mix test test/lattice_stripe/checkout/session_test.exs --only describe:"retrieve/3"` | Wave 0 |
| CHKT-06 | list, stream | unit | `mix test test/lattice_stripe/checkout/session_test.exs --only describe:"list/3"` | Wave 0 |
| CHKT-07 | expire open session, standard error pass-through on completed | unit | `mix test test/lattice_stripe/checkout/session_test.exs --only describe:"expire/3"` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/lattice_stripe/refund_test.exs` or `mix test test/lattice_stripe/checkout/session_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/support/fixtures/customer.ex` — LatticeStripe.Test.Fixtures.Customer (extracted from customer_test.exs)
- [ ] `test/support/fixtures/payment_intent.ex` — LatticeStripe.Test.Fixtures.PaymentIntent
- [ ] `test/support/fixtures/setup_intent.ex` — LatticeStripe.Test.Fixtures.SetupIntent
- [ ] `test/support/fixtures/payment_method.ex` — LatticeStripe.Test.Fixtures.PaymentMethod
- [ ] `test/support/fixtures/refund.ex` — LatticeStripe.Test.Fixtures.Refund
- [ ] `test/support/fixtures/checkout_session.ex` — LatticeStripe.Test.Fixtures.Checkout.Session
- [ ] `test/support/fixtures/checkout_line_item.ex` — LatticeStripe.Test.Fixtures.Checkout.LineItem
- [ ] `test/lattice_stripe/refund_test.exs` — Refund resource tests
- [ ] `test/lattice_stripe/checkout/session_test.exs` — Checkout.Session resource tests

---

## Sources

### Primary (HIGH confidence)
- `lib/lattice_stripe/customer.ex` — verified complete resource module pattern
- `lib/lattice_stripe/payment_method.ex` — verified `require_param!` pattern, 53-field struct, Inspect implementation
- `lib/lattice_stripe/resource.ex` — verified `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3`
- `test/support/test_helpers.ex` — verified `ok_response/1`, `error_response/0`, `list_json/2`
- `mix.exs` — verified `elixirc_paths(:test)` covers `test/support/` recursively
- `test/lattice_stripe/payment_method_test.exs` — verified fixture pattern (inline `defp payment_method_json/1`)
- `test/lattice_stripe/customer_test.exs` — verified fixture pattern (inline `defp customer_json/1`)
- [docs.stripe.com/api/refunds/object](https://docs.stripe.com/api/refunds/object) — Refund field list verified
- [docs.stripe.com/api/checkout/sessions/object](https://docs.stripe.com/api/checkout/sessions/object) — Checkout Session field list verified
- [docs.stripe.com/api/checkout/sessions/line_items](https://docs.stripe.com/api/checkout/sessions/line_items) — LineItem field list verified

### Secondary (MEDIUM confidence)
- [hexdocs.pm/stripity_stripe/Stripe.Checkout.Session.html](https://hexdocs.pm/stripity_stripe/Stripe.Checkout.Session.html) — cross-reference for Checkout Session fields; confirms field inventory

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all existing
- Architecture: HIGH — patterns verified directly from existing codebase
- Stripe field lists: HIGH — verified from official docs.stripe.com
- Pitfalls: HIGH — grounded in actual decisions and codebase patterns
- Test patterns: HIGH — verified from existing test files

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (Stripe API field additions are additive; `extra` map catches new fields safely)
