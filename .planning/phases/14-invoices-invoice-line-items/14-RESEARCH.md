# Phase 14: Invoices & Invoice Line Items - Research

**Researched:** 2026-04-12
**Domain:** Stripe Invoice lifecycle, Invoice Line Items, InvoiceItem CRUD, proration guard, auto-advance telemetry
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-14a — Action verb surface:** Mixed naming — bare verbs where safe, suffixed for `send` (Kernel.send collision). Functions: `finalize/4`, `void/4`, `pay/4`, `send_invoice/4`, `mark_uncollectible/4`. Uniform arity `(client, id, params \\ %{}, opts \\ [])`. Both tuple and bang variants.

**D-14b — Upcoming preview:** Ship BOTH `upcoming/3` (legacy `GET /v1/invoices/upcoming`) and `create_preview/3` (new `POST /v1/invoices/create_preview`). Both return `{:ok, %Invoice{id: nil}}`. Also ship `upcoming_lines/3` and `create_preview_lines/3`. `lines` field is `%LatticeStripe.List{data: [%Invoice.LineItem{}]}`.

**D-14c — Auto-advance telemetry:** Pre-request event `[:lattice_stripe, :invoice, :auto_advance_defaulted]`. Fires in `Invoice.create/3` when params do NOT contain `"auto_advance"` key. Measurements: `%{system_time: System.system_time()}`. Metadata: `%{resource: "invoice", operation: "create", auto_advance: :defaulted}`. Extend `attach_default_logger/1` with Logger.warning. No opt-out initially.

**D-14d — Invoice Line Items:** `LatticeStripe.Invoice.LineItem` — data-struct-only. `Invoice.list_line_items/4` and `Invoice.stream_line_items!/3` on parent module. Matches `Checkout.Session.list_line_items/4` pattern.

**D-14e — InvoiceItem (standalone CRUD):** `LatticeStripe.InvoiceItem` — flat namespace. Operations: create, retrieve, update, delete, list, stream. No search. `InvoiceItem.Period` gets typed struct. Others stay `map()`.

**D-14f — Invoice struct field typing:** `Invoice.StatusTransitions` and `Invoice.AutomaticTax` get typed structs. Everything else stays `map()`. `discount`/`discounts` use existing `LatticeStripe.Discount`.

**D-14g — Status atomization:** 4 fields atomized: `status`, `collection_method`, `billing_reason`, `customer_tax_exempt`. No predicate helpers.

**D-14h — Proration guard:** Add `require_explicit_proration: false` to Client struct + Config schema. `LatticeStripe.Billing.Guards` with `check_proration_required(client, params)`. Guard `upcoming/3` and `create_preview/3` only. Pre-request `Map.has_key?(params, "proration_behavior")` check.

**D-14i — Lifecycle docs:** ASCII state table in `Invoice.@moduledoc`. Per-function `@doc` state preconditions. `Invoice.delete/3` exists (draft only). No client-side validation.

**D-14j — Invoice search:** Follows D-04/D-10 pattern. D-10 eventual-consistency callout. Note upcoming invoices not searchable.

**D-14k — No per-verb telemetry:** Existing `[:lattice_stripe, :request, :start | :stop]` events with `:operation` metadata sufficient.

**D-14l — Guide:** `guides/invoices.md` (~400 lines), 10 sections covering full workflow.

### Claude's Discretion

- Exact module path for nested structs (planner decides based on file-size conventions)
- Whether `Invoice.AutomaticTax` `liability` sub-field stays flat `map()` or gets a trivial 2-field struct
- Internal structure of `LatticeStripe.Billing.Guards` (module name could be `Billing.Validation` or `Billing.Guards`)
- Exact wording of lifecycle state table in moduledoc
- Whether `upcoming_lines/3` and `create_preview_lines/3` share implementation via private helper
- InvoiceItem `@known_fields` exact list
- Guide section ordering and exact code example depth

### Deferred Ideas (OUT OF SCOPE)

- Shared `LatticeStripe.Address` struct
- `Invoice.TransferData` typed struct (Phase 17)
- `Invoice.ShippingCost` typed struct
- TaxRate resource
- Status predicate helpers
- Per-verb telemetry events
- Client-side lifecycle state validation
- Proration convenience wrapper
- Auto-advance suppression config
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BILL-04 | Developer can manage Invoices — create, retrieve, update, list, stream, search | Standard CRUD pattern from Customer/PaymentIntent. Invoice struct fields catalogued below. |
| BILL-04b | Developer can finalize, void, mark as uncollectible, pay, and send Invoices via dedicated action verbs | PaymentIntent confirm/capture/cancel precedent. Uniform `(client, id, params \\ %{}, opts \\ [])` signature. Endpoints: `/v1/invoices/:id/{verb}`. |
| BILL-04c | Developer can preview upcoming Invoice charges via `upcoming/2` returning Invoice-shaped struct with `id: nil` | Both `upcoming/3` (GET) and `create_preview/3` (POST) ship. Same `%Invoice{id: nil}` return type. Proration guard wired here. |
| BILL-10 | Developer can list Invoice Line Items for an invoice (read-only child resource, also surfaced as `Invoice.lines` typed field) | `Invoice.list_line_items/4` and `stream_line_items!/3` on parent. `Invoice.LineItem` data struct. `lines` field is `%List{data: [%LineItem{}]}`. |
</phase_requirements>

---

## Summary

Phase 14 delivers the Stripe Invoice lifecycle as idiomatic Elixir resources. The Invoice API is the most complex resource in the v2.0 milestone: it has CRUD, 5 action verbs, 2 preview endpoints, a search surface, a standalone child resource (InvoiceItem), and a read-only nested collection (Invoice Line Items). The auto-advance footgun (Stripe finalizes draft invoices in ~1 hour if `auto_advance` is omitted) is the primary DX risk — telemetry mitigates it without blocking the call.

All patterns in this phase have direct precedents in the existing codebase. The action verb pattern (`POST /v1/invoices/:id/finalize`) mirrors `PaymentIntent.confirm/capture/cancel`. The child line items pattern mirrors `Checkout.Session.list_line_items/4` and `Checkout.LineItem`. The InvoiceItem standalone resource is identical to Customer/Coupon CRUD. The proration guard is a new module but straightforward: check one map key before the HTTP call.

The only genuinely new engineering in this phase is: (1) the pre-request telemetry event for auto-advance detection, (2) the `upcoming/create_preview` nil-id struct pattern, (3) the `Billing.Guards` module, and (4) adding `require_explicit_proration` to `Client` struct and `Config` schema. Everything else is pattern replication.

**Primary recommendation:** Build Invoice from the Customer template. Add action verbs following PaymentIntent confirm/capture/cancel. Build Invoice.LineItem following Checkout.LineItem exactly. Build InvoiceItem following Coupon for "no search" moduledoc pattern.

---

## Standard Stack

### Core (all already in mix.exs — no new deps required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | `~> 0.19` [VERIFIED: mix.exs line 102] | HTTP transport | Already the project transport |
| Jason | `~> 1.4` [VERIFIED: mix.exs line 103] | JSON decode | Already the project codec |
| :telemetry | `~> 1.0` [VERIFIED: mix.exs line 104] | Emit auto-advance warning event | Already wired in Telemetry module |
| NimbleOptions | `~> 1.0` [VERIFIED: mix.exs line 105] | Validate `require_explicit_proration` in Config schema | Already used by Config module |
| Mox | `~> 1.2` [VERIFIED: mix.exs line 110] | Mock Transport in unit tests | Already used by all existing tests |

**No new dependencies needed for Phase 14.** [VERIFIED: project mix.exs]

---

## Architecture Patterns

### Recommended File Layout

```
lib/lattice_stripe/
├── invoice.ex                      # Main module: CRUD + action verbs + preview + search
├── invoice/
│   ├── line_item.ex                # Data struct only — accessed via Invoice.*
│   ├── status_transitions.ex       # Typed nested struct (4 timestamp fields)
│   └── automatic_tax.ex            # Typed nested struct (enabled, status; liability as map)
├── invoice_item.ex                 # Standalone CRUD resource
├── invoice_item/
│   └── period.ex                   # Typed nested struct (start, end)
└── billing/
    └── guards.ex                   # check_proration_required/2

test/lattice_stripe/
├── invoice_test.exs
├── invoice/
│   ├── line_item_test.exs
│   ├── status_transitions_test.exs
│   └── automatic_tax_test.exs
├── invoice_item_test.exs
├── invoice_item/
│   └── period_test.exs
└── billing/
    └── guards_test.exs

test/integration/
├── invoice_integration_test.exs
└── invoice_item_integration_test.exs

test/real_stripe/
└── invoice_real_stripe_test.exs    # Optional — lifecycle states stripe-mock can't simulate

guides/
└── invoices.md
```

### Pattern 1: Invoice CRUD — replicate Customer template exactly

**What:** `@known_fields ~w[...]`, `defstruct`, `@type t`, `from_map/1`, CRUD functions routing through `Resource.unwrap_singular/2` and `Resource.unwrap_list/2`.

**Source:** `lib/lattice_stripe/customer.ex` [VERIFIED: read in session]

```elixir
# Source: lib/lattice_stripe/customer.ex (established pattern)
defmodule LatticeStripe.Invoice do
  alias LatticeStripe.{Client, Discount, Error, List, Request, Resource, Response}
  alias LatticeStripe.Invoice.{AutomaticTax, LineItem, StatusTransitions}

  @known_fields ~w[
    id object account_country account_name account_tax_ids amount_due amount_paid
    amount_remaining amount_shipping application application_fee_amount attempt_count
    attempted auto_advance automatic_tax billing_reason charge collection_method
    created currency customer customer_address customer_email customer_name
    customer_phone customer_shipping customer_tax_exempt customer_tax_ids
    custom_fields default_payment_method default_source default_tax_rates description
    discount discounts due_date effective_at ending_balance footer from_invoice
    hosted_invoice_url invoice_pdf issuer last_finalization_error latest_revision
    lines livemode metadata next_payment_attempt number on_behalf_of paid
    paid_out_of_band payment_intent payment_settings period_end period_start
    post_payment_credit_notes_amount pre_payment_credit_notes_amount quote
    receipt_number rendering rendering_options shipping_cost shipping_details
    starting_balance statement_descriptor status status_transitions subscription
    subscription_details subscription_proration_date subtotal subtotal_excluding_tax
    tax test_clock threshold_reason total total_discount_amounts total_excluding_tax
    total_tax_amounts transfer_data webhooks_delivered_at
  ]
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [...]
end
```

### Pattern 2: Action Verbs — replicate PaymentIntent confirm/capture/cancel

**What:** `POST /v1/invoices/:id/{verb}`, uniform arity-4 signature with defaults, both tuple + bang variants.

**Source:** `lib/lattice_stripe/payment_intent.ex` lines 295-365 [VERIFIED: read in session]

```elixir
# Source: lib/lattice_stripe/payment_intent.ex confirm/4 pattern
@spec finalize(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def finalize(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/invoices/#{id}/finalize", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

# send_invoice — not send — avoids Kernel.send/2 collision
@spec send_invoice(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def send_invoice(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/invoices/#{id}/send", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

Action verb → Stripe endpoint mapping [ASSUMED based on Stripe docs structure — verify against live API]:

| Function | HTTP | Path |
|----------|------|------|
| `finalize/4` | POST | `/v1/invoices/:id/finalize` |
| `pay/4` | POST | `/v1/invoices/:id/pay` |
| `void/4` | POST | `/v1/invoices/:id/void` |
| `send_invoice/4` | POST | `/v1/invoices/:id/send` |
| `mark_uncollectible/4` | POST | `/v1/invoices/:id/mark_uncollectible` |

### Pattern 3: Child Line Items — replicate Checkout.Session.list_line_items/4

**What:** `GET /v1/invoices/:invoice_id/lines`, returns `%Response{data: %List{data: [%Invoice.LineItem{}]}}`.

**Source:** `lib/lattice_stripe/checkout/session.ex` lines 477-519 [VERIFIED: read in session]

```elixir
# Source: lib/lattice_stripe/checkout/session.ex list_line_items/4
@spec list_line_items(Client.t(), String.t(), map(), keyword()) ::
        {:ok, Response.t()} | {:error, Error.t()}
def list_line_items(%Client{} = client, invoice_id, params \\ %{}, opts \\ [])
    when is_binary(invoice_id) do
  %Request{
    method: :get,
    path: "/v1/invoices/#{invoice_id}/lines",
    params: params,
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&LineItem.from_map/1)
end
```

Note: Invoice line items endpoint is `/v1/invoices/:id/lines` (NOT `/line_items`). [ASSUMED — verify against Stripe docs. The checkout path uses `/line_items` but invoice path uses `/lines`.]

### Pattern 4: Invoice.LineItem data struct — replicate Checkout.LineItem exactly

**What:** `@known_fields`, `defstruct`, `@type t`, `from_map/1`, `Inspect` impl. No CRUD functions on the struct module itself.

**Source:** `lib/lattice_stripe/checkout/line_item.ex` [VERIFIED: read in session]

```elixir
# Source: lib/lattice_stripe/checkout/line_item.ex (established pattern)
defmodule LatticeStripe.Invoice.LineItem do
  @moduledoc """
  Represents a line item on a Stripe Invoice.

  Line items are read-only rendered rows on an invoice. They cannot be
  created or modified directly. Access them via `Invoice.list_line_items/4`
  or `Invoice.stream_line_items!/3`, or via the `:lines` field on an
  `%Invoice{}` struct.

  ## InvoiceItem vs Invoice Line Item

  - **InvoiceItem** (`LatticeStripe.InvoiceItem`) — a standalone CRUD resource.
    Created explicitly, attached to a draft invoice before finalization.
  - **Invoice Line Item** (this module) — a read-only rendered row on a
    finalized invoice. You cannot create or delete these directly.
  """
  @known_fields ~w[id object amount amount_excluding_tax currency description
    discount_amounts discountable discounts invoice livemode metadata period
    plan price proration proration_details quantity subscription subscription_item
    tax_amounts tax_rates type unit_amount_excluding_tax]

  defstruct [
    :id, :amount, :amount_excluding_tax, :currency, :description,
    :discount_amounts, :discountable, :discounts, :invoice, :livemode,
    :metadata, :period, :plan, :price, :proration, :proration_details,
    :quantity, :subscription, :subscription_item,
    :tax_amounts, :tax_rates, :type, :unit_amount_excluding_tax,
    object: "line_item",
    extra: %{}
  ]
end
```

Invoice LineItem fields [ASSUMED from training knowledge — verify against `https://docs.stripe.com/api/invoice-line-item/object`]:
- `id`, `object`, `amount`, `amount_excluding_tax`, `currency`, `description`
- `discount_amounts` (list), `discountable`, `discounts` (list)
- `invoice`, `livemode`, `metadata`, `period` (map with start/end)
- `plan` (map), `price` (map), `proration` (boolean), `proration_details` (map)
- `quantity`, `subscription`, `subscription_item`
- `tax_amounts` (list), `tax_rates` (list), `type`, `unit_amount_excluding_tax`

### Pattern 5: Typed Nested Struct — StatusTransitions

**What:** Simple data module with `defstruct`, `@type t`, `from_map/1`. No CRUD, no Inspect customization.

```elixir
defmodule LatticeStripe.Invoice.StatusTransitions do
  @moduledoc """
  Timestamps recording when an Invoice transitioned through its lifecycle states.

  All fields are Unix timestamps (integer seconds) or nil if the transition
  has not yet occurred.
  """

  defstruct [:finalized_at, :marked_uncollectible_at, :paid_at, :voided_at]

  @type t :: %__MODULE__{
    finalized_at: integer() | nil,
    marked_uncollectible_at: integer() | nil,
    paid_at: integer() | nil,
    voided_at: integer() | nil
  }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil
  def from_map(map) when is_map(map) do
    %__MODULE__{
      finalized_at: map["finalized_at"],
      marked_uncollectible_at: map["marked_uncollectible_at"],
      paid_at: map["paid_at"],
      voided_at: map["voided_at"]
    }
  end
end
```

### Pattern 6: AutomaticTax nested struct

```elixir
defmodule LatticeStripe.Invoice.AutomaticTax do
  @moduledoc """
  Automatic tax calculation settings and status for an Invoice.

  The `:status` field is critical for tax error handling:
  - `nil` — tax calculation not yet run
  - `"requires_location_inputs"` — customer address insufficient
  - `"complete"` — tax calculated successfully
  - `"failed"` — tax calculation failed

  The `:liability` sub-field stays as `map()` (Connect-specific, deferred to Phase 17).
  """

  defstruct [:enabled, :liability, :status]

  @type t :: %__MODULE__{
    enabled: boolean() | nil,
    liability: map() | nil,
    status: String.t() | nil
  }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil
  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: map["enabled"],
      liability: map["liability"],
      status: map["status"]
    }
  end
end
```

### Pattern 7: InvoiceItem standalone CRUD — Coupon template (no search)

**What:** Full CRUD (create/retrieve/update/delete/list/stream) at `/v1/invoiceitems`. No search per D-05. Moduledoc documents the absence.

**Source:** `lib/lattice_stripe/coupon.ex` D-05 pattern [VERIFIED: read in session]

```elixir
defmodule LatticeStripe.InvoiceItem do
  @moduledoc """
  Operations on Stripe InvoiceItem objects.

  InvoiceItems are standalone CRUD resources used to add charges to draft invoices
  before they are finalized. Once an invoice is finalized, its line items are
  locked — InvoiceItems can no longer be added, modified, or deleted.

  ## InvoiceItem vs Invoice Line Item

  - **InvoiceItem** (this module) — a standalone resource you create explicitly,
    at `/v1/invoiceitems`. Mutatable while the target invoice is in draft status.
  - **Invoice Line Item** (`LatticeStripe.Invoice.LineItem`) — a read-only rendered
    row on a finalized invoice, accessed via `Invoice.list_line_items/4`.

  ## Operations not supported by the Stripe API

  - **search** — The `/v1/invoiceitems/search` endpoint does not exist.
    Use `list/2` with filters for discovery.

  ...
  """

  @known_fields ~w[
    id object amount currency customer date description discountable discounts
    invoice livemode metadata period plan price proration proration_details
    quantity subscription subscription_item tax_rates test_clock unit_amount
    unit_amount_decimal unit_amount_excluding_tax
  ]
end
```

InvoiceItem fields [ASSUMED from training knowledge — planner must verify against `https://docs.stripe.com/api/invoiceitems/object`].

### Pattern 8: InvoiceItem.Period nested struct

```elixir
defmodule LatticeStripe.InvoiceItem.Period do
  @moduledoc "Billing period for an InvoiceItem."

  defstruct [:start, :end]

  @type t :: %__MODULE__{
    start: integer() | nil,
    end: integer() | nil
  }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil
  def from_map(map) when is_map(map), do: %__MODULE__{start: map["start"], end: map["end"]}
end
```

### Pattern 9: Atomization — private whitelist helper

**What:** Private `atomize_status/1` etc. helpers with whitelist + `String.t()` catch-all. Follows Phase 12 Price/Coupon precedent.

```elixir
# In Invoice.from_map/1:
status: atomize_status(map["status"]),
collection_method: atomize_collection_method(map["collection_method"]),
billing_reason: atomize_billing_reason(map["billing_reason"]),
customer_tax_exempt: atomize_customer_tax_exempt(map["customer_tax_exempt"]),

defp atomize_status("draft"), do: :draft
defp atomize_status("open"), do: :open
defp atomize_status("paid"), do: :paid
defp atomize_status("void"), do: :void
defp atomize_status("uncollectible"), do: :uncollectible
defp atomize_status(other), do: other  # String.t() catch-all

defp atomize_collection_method("charge_automatically"), do: :charge_automatically
defp atomize_collection_method("send_invoice"), do: :send_invoice
defp atomize_collection_method(other), do: other

defp atomize_billing_reason("subscription_cycle"), do: :subscription_cycle
defp atomize_billing_reason("subscription_create"), do: :subscription_create
defp atomize_billing_reason("subscription_update"), do: :subscription_update
defp atomize_billing_reason("subscription_threshold"), do: :subscription_threshold
defp atomize_billing_reason("subscription"), do: :subscription
defp atomize_billing_reason("manual"), do: :manual
defp atomize_billing_reason("upcoming"), do: :upcoming
defp atomize_billing_reason(other), do: other

defp atomize_customer_tax_exempt("none"), do: :none
defp atomize_customer_tax_exempt("exempt"), do: :exempt
defp atomize_customer_tax_exempt("reverse"), do: :reverse
defp atomize_customer_tax_exempt(other), do: other
```

### Pattern 10: upcoming/3 and create_preview/3

**What:** Two functions returning `%Invoice{id: nil}`. `upcoming/3` uses GET (no body, params as query string). `create_preview/3` uses POST.

```elixir
@spec upcoming(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def upcoming(%Client{} = client, params \\ %{}, opts \\ []) do
  with :ok <- Billing.Guards.check_proration_required(client, params) do
    %Request{method: :get, path: "/v1/invoices/upcoming", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
    # Result: %Invoice{id: nil} — Stripe returns an invoice-shaped object with no id
  end
end

@spec create_preview(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create_preview(%Client{} = client, params \\ %{}, opts \\ []) do
  with :ok <- Billing.Guards.check_proration_required(client, params) do
    %Request{method: :post, path: "/v1/invoices/create_preview", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end
end

# Lines pagination for preview invoices
@spec upcoming_lines(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def upcoming_lines(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :get, path: "/v1/invoices/upcoming/lines", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&LineItem.from_map/1)
end

@spec create_preview_lines(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def create_preview_lines(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :post, path: "/v1/invoices/create_preview/lines", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&LineItem.from_map/1)
end
```

Note on `create_preview/lines`: The Stripe API structure for create_preview lines pagination is [ASSUMED — the exact endpoint path needs verification against `https://docs.stripe.com/api/invoices/create_preview`].

### Pattern 11: Auto-advance telemetry in Invoice.create/3

**What:** Check params BEFORE the HTTP call. Emit `:telemetry.execute/3` directly (not a span — this is a point-in-time advisory event, not a duration measurement).

```elixir
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create(%Client{} = client, params \\ %{}, opts \\ []) do
  unless Map.has_key?(params, "auto_advance") do
    :telemetry.execute(
      [:lattice_stripe, :invoice, :auto_advance_defaulted],
      %{system_time: System.system_time()},
      %{resource: "invoice", operation: "create", auto_advance: :defaulted}
    )
  end

  %Request{method: :post, path: "/v1/invoices", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

**Telemetry module extension — `attach_default_logger/1`:**

```elixir
# In lib/lattice_stripe/telemetry.ex attach_default_logger/1:
# Add a second :telemetry.attach/4 call for the auto-advance event.
:telemetry.attach(
  "#{@default_logger_id}_invoice_auto_advance",
  [:lattice_stripe, :invoice, :auto_advance_defaulted],
  &__MODULE__.handle_auto_advance_log/4,
  %{level: level}
)

@doc false
def handle_auto_advance_log(_event, _measurements, _metadata, %{level: _level}) do
  Logger.warning(
    "Invoice created without explicit auto_advance — Stripe will auto-finalize in ~1 hour. " <>
    "Set auto_advance: false for draft invoices."
  )
end
```

Note: `attach_default_logger/1` currently does a single `:telemetry.detach(@default_logger_id)` then one `:telemetry.attach/4`. Adding the second event handler means either using a different handler ID for the new event (safe) or restructuring to attach multiple events. Use distinct IDs: `"#{@default_logger_id}_invoice_auto_advance"`. [VERIFIED: existing code pattern read in session]

### Pattern 12: Billing.Guards module

```elixir
defmodule LatticeStripe.Billing.Guards do
  @moduledoc false
  # Internal guard module for billing-related pre-request checks.
  # Not part of the public API surface.

  alias LatticeStripe.{Client, Error}

  @doc false
  @spec check_proration_required(Client.t(), map()) :: :ok | {:error, Error.t()}
  def check_proration_required(%Client{require_explicit_proration: false}, _params), do: :ok
  def check_proration_required(%Client{require_explicit_proration: true}, params) do
    if Map.has_key?(params, "proration_behavior") do
      :ok
    else
      {:error, %Error{
        type: :proration_required,
        message: ~s(proration_behavior is required when require_explicit_proration is enabled. ) <>
                 ~s(Valid values: "create_prorations", "always_invoice", "none")
      }}
    end
  end
end
```

### Pattern 13: Client struct and Config schema additions

**Client struct** (`lib/lattice_stripe/client.ex`):

```elixir
# Add to defstruct:
require_explicit_proration: false

# Add to @type t:
require_explicit_proration: boolean()
```

**Config schema** (`lib/lattice_stripe/config.ex`):

```elixir
# Add to @schema NimbleOptions.new!/:
require_explicit_proration: [
  type: :boolean,
  default: false,
  doc: """
  When true, calls to Invoice.upcoming/3 and Invoice.create_preview/3 that
  omit proration_behavior return {:error, %Error{type: :proration_required}}.
  Default false passes through to Stripe transparently. Opt-in strict mode.
  """
]
```

**Error type** (`lib/lattice_stripe/error.ex`):

```elixir
# Add :proration_required to error_type() union type:
@type error_type ::
        :card_error
        | :invalid_request_error
        | :authentication_error
        | :rate_limit_error
        | :api_error
        | :idempotency_error
        | :connection_error
        | :test_clock_timeout
        | :test_clock_failed
        | :proration_required  # NEW in Phase 14
```

Note: `proration_required` is a locally-constructed error (like `test_clock_timeout`). It is never returned from a Stripe HTTP response — it is constructed by `Billing.Guards.check_proration_required/2`. The `@moduledoc` for `Error` should document this.

### Pattern 14: Invoice.lines field parsing in from_map/1

The `lines` field on Invoice comes back from Stripe as a `%LatticeStripe.List{}`-shaped JSON object (`{"object": "list", "data": [...], "has_more": false, ...}`). The `Client` already detects `object: "list"` and wraps it in `%List{}` — but that wrapping happens at the response level, not nested. For the `lines` sub-field, we need explicit parsing in `Invoice.from_map/1`:

```elixir
# In Invoice.from_map/1:
lines: parse_lines(map["lines"]),

defp parse_lines(nil), do: nil
defp parse_lines(%{"object" => "list", "data" => data} = list_map) do
  items = Enum.map(data, &Invoice.LineItem.from_map/1)
  %LatticeStripe.List{
    data: items,
    has_more: list_map["has_more"] || false,
    url: list_map["url"]
  }
end
defp parse_lines(other), do: other
```

This is the same approach Stripe uses for nested paginated collections. [ASSUMED — pattern inferred from List module structure, verify `%List{}` field names against `lib/lattice_stripe/list.ex`]

### Pattern 15: InvoiceItem.Period parsing in InvoiceItem.from_map/1

```elixir
# In InvoiceItem.from_map/1:
period: InvoiceItem.Period.from_map(map["period"]),
```

### Pattern 16: Invoice.delete/3 — draft-only

```elixir
@spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :delete, path: "/v1/invoices/#{id}", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

`@doc` note: "Only applicable to draft invoices. Attempting to delete a finalized invoice returns a Stripe error."

### Pattern 17: Invoice lifecycle ASCII state table (D-14i)

```
## Invoice Lifecycle

Invoices transition through the following states:

    draft ──(finalize)──▶ open ──(pay)──────────▶ paid
                           │
                           ├──(void)─────────────▶ void
                           │
                           └──(mark_uncollectible)▶ uncollectible

State constraints (Stripe enforces these; SDK does not validate):
- finalize/4     — requires draft status
- pay/4          — requires open status
- void/4         — requires open status
- mark_uncollectible/4 — requires open status
- send_invoice/4 — requires open status (collection_method: send_invoice)
- delete/3       — requires draft status
```

### Anti-Patterns to Avoid

- **Polling on auto_advance:** Do NOT build a helper that polls waiting for the invoice to auto-finalize. The telemetry advisory is the mitigation — let users control timing explicitly with `finalize/2`.
- **Client-side lifecycle validation:** Do NOT check `invoice.status` before calling action verbs. The struct may be stale. Stripe is the authority; let it return the error.
- **Blocking on `create_preview/3`:** upcoming/create_preview returns a full Invoice struct with `id: nil`. Do NOT assign a fallback ID or special-case the nil.
- **Using `Map.has_key?` with atom keys:** All params maps use string keys throughout the codebase. The proration guard checks `Map.has_key?(params, "proration_behavior")` — string key, not atom.
- **Separate bang module for action verbs:** Bang variants live in the same module as tuple variants. `finalize!/4` is a 3-line wrapper calling `finalize/4 |> Resource.unwrap_bang!()`.
- **Forgetting `create_preview_lines/3` POST method:** Unlike standard list operations (GET), `create_preview_lines/3` is a POST — the body contains filter parameters. [ASSUMED — verify against Stripe docs.]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form encoding for InvoiceItem nested params | Custom serializer | `LatticeStripe.FormEncoder.encode/1` | Already handles nested maps, lists, integers, floats — Phase 12 D-09f |
| List pagination for `/v1/invoices/:id/lines` | Manual cursor tracking | `LatticeStripe.List.stream!/2` + `Resource.unwrap_list/2` | Already implemented; auto-pagination works on any list endpoint |
| JSON decoding of Invoice responses | Manual `Jason.decode!` | `Client.request/2` pipeline | Already decodes, detects list vs singular |
| Option validation for `require_explicit_proration` | Hand-rolled boolean check | `NimbleOptions` in `Config` schema | Already used for all other Client options |
| Timing-safe comparison in webhook (not Phase 14) | Custom HMAC | `Plug.Crypto.secure_compare/2` | Not needed here, but reinforcing the project's pattern |

**Key insight:** Every infrastructure concern (HTTP, encoding, decoding, pagination, telemetry spans, retries) is already handled by the existing pipeline. Phase 14 only adds resource definitions and one new pre-request check.

---

## Common Pitfalls

### Pitfall 1: Auto-advance — the ~1h finalization window

**What goes wrong:** Developer creates a draft invoice, adds InvoiceItems, then pauses (thinking the invoice stays draft indefinitely). Stripe finalizes it automatically in ~1 hour, locking the line items.

**Why it happens:** `auto_advance` defaults to `true` in Stripe's API. The SDK passes params through without injecting defaults.

**How to avoid:** D-14c — emit `[:lattice_stripe, :invoice, :auto_advance_defaulted]` telemetry when `"auto_advance"` key is absent from create params. Users who call `attach_default_logger/1` see a Logger.warning. Guide documents canonical `create → add items → finalize → pay` order.

**Warning signs:** User reports "invoice was finalized unexpectedly" or "can't add items to invoice."

### Pitfall 2: Stripe API version — upcoming vs create_preview

**What goes wrong:** Code targets `create_preview` but the user's Stripe account is pinned to an older API version, or vice versa.

**Why it happens:** `create_preview` (POST) was introduced in API version `2025-03-31.basil`. Users on older versions must use `upcoming` (GET). [ASSUMED — verify the exact API version cutoff against Stripe changelog.]

**How to avoid:** Ship both `upcoming/3` and `create_preview/3`. Same return type. Users choose based on their pinned API version. Document in `@doc` for each function.

**Warning signs:** Stripe returns `invalid_request_error` about unknown endpoint.

### Pitfall 3: Invoice Line Item endpoint path

**What goes wrong:** Planner writes `/v1/invoices/:id/line_items` (following Checkout pattern). Actual Stripe endpoint is `/v1/invoices/:id/lines`. [ASSUMED — must verify against Stripe docs before implementation.]

**How to avoid:** Verify against `https://docs.stripe.com/api/invoice-line-item/list` before coding.

**Warning signs:** Integration test against stripe-mock returns 404.

### Pitfall 4: send vs send_invoice naming

**What goes wrong:** Defining `def send(client, id, params \\ %{}, opts \\ [])` creates an arity-2 clause `send/2` that conflicts with `Kernel.send/2`, causing compilation warning or unexpected dispatch.

**Why it happens:** Elixir imports `Kernel.send/2` by default. `def send(client, id, ...)` with two required params and two optional params creates clause with arity 2 matching `Kernel.send/2` pattern.

**How to avoid:** D-14a — use `send_invoice/4` for all arities. No `send/N` functions anywhere in the module.

**Warning signs:** Compiler warning about conflicting `send/2` definition.

### Pitfall 5: Telemetry handler ID collision on second attach_default_logger/1 call

**What goes wrong:** Calling `attach_default_logger/1` twice now attaches two events. The existing code does `telemetry.detach(@default_logger_id)` to prevent duplicate handlers for the `:request, :stop` event. Adding a second event handler with a different ID means the new event handler does NOT get detached on re-call.

**How to avoid:** Use the same pattern — detach the new handler ID before attaching it:

```elixir
:telemetry.detach("#{@default_logger_id}_invoice_auto_advance")
:telemetry.attach(
  "#{@default_logger_id}_invoice_auto_advance",
  [:lattice_stripe, :invoice, :auto_advance_defaulted],
  ...
)
```

**Warning signs:** Multiple Logger.warning lines per `Invoice.create/3` call after `attach_default_logger/1` is called more than once.

### Pitfall 6: proration_required error escaping the `with` chain

**What goes wrong:** `upcoming/3` uses `with :ok <- Billing.Guards.check_proration_required(client, params)` — if the guard returns `{:error, %Error{}}`, the `with` chain short-circuits and returns the error tuple. This is correct behavior, but the return type annotation must reflect it.

**How to avoid:** Spec is `{:ok, t()} | {:error, Error.t()}` — same as all other functions. `:proration_required` is one more possible `Error.type` value.

### Pitfall 7: Invoice.lines being nil vs empty List

**What goes wrong:** `Invoice.from_map/1` receives a response where `"lines"` is either nil (unlikely) or a list-shaped JSON object. Passing nil to `parse_lines/1` must return nil cleanly.

**How to avoid:** Guard clauses in `parse_lines/1` handle nil and map cases separately.

### Pitfall 8: Forgetting `@doc false` on Billing.Guards

**What goes wrong:** ExDoc picks up `Billing.Guards` and adds it to the generated docs, confusing library users who see an internal module.

**How to avoid:** Either `@moduledoc false` on the module or keep it out of `mix.exs` `groups_for_modules`. Since it's in the `lib/` tree, use `@moduledoc false`.

---

## Integration Points (Modifications to Existing Files)

| File | Change | Notes |
|------|--------|-------|
| `lib/lattice_stripe/client.ex` | Add `require_explicit_proration: false` to `defstruct` and `@type t` | New field, non-breaking default |
| `lib/lattice_stripe/config.ex` | Add `require_explicit_proration:` to `@schema NimbleOptions.new!/1` | New boolean option with default false |
| `lib/lattice_stripe/error.ex` | Add `:proration_required` to `error_type()` union type and `@moduledoc` | New locally-constructed error type |
| `lib/lattice_stripe/telemetry.ex` | Extend `attach_default_logger/1` to also attach the auto-advance handler; add `handle_auto_advance_log/4` | New handler, new `@doc false` function |
| `mix.exs` | Add `"guides/invoices.md"` to `extras:` list | ExDoc integration |
| `mix.exs` | Add Billing group to `groups_for_modules:` with `LatticeStripe.Billing.Guards` — OR keep it out and use `@moduledoc false` | Planner decides |

---

## Code Examples

### Invoice create with explicit auto_advance

```elixir
# Source: pattern inferred from PaymentIntent.create/3 [VERIFIED: pattern exists]
# Canonical pattern — prevents ~1h auto-finalization race:
{:ok, invoice} = LatticeStripe.Invoice.create(client, %{
  "customer" => "cus_123",
  "auto_advance" => false,
  "collection_method" => "charge_automatically"
})

{:ok, _} = LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_123",
  "invoice" => invoice.id,
  "price" => "price_456"
})

{:ok, finalized} = LatticeStripe.Invoice.finalize(client, invoice.id)
{:ok, paid} = LatticeStripe.Invoice.pay(client, finalized.id)
```

### Proration preview (upcoming)

```elixir
# Returns %Invoice{id: nil} — preview only, not persisted
{:ok, %LatticeStripe.Invoice{id: nil} = preview} = LatticeStripe.Invoice.upcoming(client, %{
  "customer" => "cus_123",
  "subscription" => "sub_456",
  "subscription_items" => [%{"id" => "si_789", "price" => "price_new"}],
  "proration_behavior" => "create_prorations"
})

# Inspect line items from the preview struct:
case preview.lines do
  %LatticeStripe.List{data: items} -> Enum.each(items, &IO.inspect/1)
  nil -> IO.puts("No line items")
end
```

### Pattern matching on atomized status

```elixir
# Status atoms enable clean pattern matching:
case LatticeStripe.Invoice.retrieve(client, "in_123") do
  {:ok, %LatticeStripe.Invoice{status: :paid}} ->
    IO.puts("Already paid")
  {:ok, %LatticeStripe.Invoice{status: :open} = inv} ->
    LatticeStripe.Invoice.pay(client, inv.id)
  {:ok, %LatticeStripe.Invoice{status: :draft} = inv} ->
    LatticeStripe.Invoice.finalize(client, inv.id)
  {:error, err} ->
    IO.inspect(err)
end
```

### Proration guard in strict mode

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch,
  require_explicit_proration: true
)

# Guard fires — proration_behavior is absent from params:
{:error, %LatticeStripe.Error{type: :proration_required, message: msg}} =
  LatticeStripe.Invoice.upcoming(client, %{"customer" => "cus_123"})

IO.puts(msg)
# => "proration_behavior is required when require_explicit_proration is enabled.
#     Valid values: \"create_prorations\", \"always_invoice\", \"none\""
```

---

## mix.exs Changes Required

### groups_for_modules additions

Phase 14 adds two new module groups (or extends existing Billing group if it exists):

```elixir
# New group in groups_for_modules:
"Billing": [
  LatticeStripe.Invoice,
  LatticeStripe.Invoice.LineItem,
  LatticeStripe.Invoice.StatusTransitions,
  LatticeStripe.Invoice.AutomaticTax,
  LatticeStripe.InvoiceItem,
  LatticeStripe.InvoiceItem.Period
],
```

`LatticeStripe.Billing.Guards` should be either in Internals group or `@moduledoc false` (not user-facing).

### extras addition

```elixir
extras: [
  ...,
  "guides/invoices.md",   # ADD
  ...
]
```

---

## Telemetry Event Catalog Update

The Telemetry module's `@moduledoc` must document the new event:

```
### `[:lattice_stripe, :invoice, :auto_advance_defaulted]`

Emitted during `Invoice.create/3` when the params map does not contain an
`"auto_advance"` key. This is an advisory event — the invoice is still created.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:system_time` | `integer` | System time at the moment of detection. |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:resource` | `String.t()` | Always `"invoice"` |
| `:operation` | `String.t()` | Always `"create"` |
| `:auto_advance` | `atom` | Always `:defaulted` |
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GET /v1/invoices/upcoming` | Both `GET /v1/invoices/upcoming` AND `POST /v1/invoices/create_preview` | API version `2025-03-31.basil` [ASSUMED — verify exact version] | Ship both; same return type |
| Stripe error for missing proration_behavior | Local `{:error, %Error{type: :proration_required}}` with actionable message | Phase 14 (SDK feature, not Stripe change) | Zero-cost opt-in via `require_explicit_proration: true` |

**Deprecated/outdated:**
- `GET /v1/invoices/upcoming`: Being deprecated in favor of `POST /v1/invoices/create_preview` as of API version `2025-03-31.basil` [ASSUMED — verify exact deprecation timeline in Stripe changelog].

---

## Environment Availability

Step 2.6: SKIPPED for unit tests and most integration work. stripe-mock is the only external dependency and is already used by Phases 12-13.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stripe-mock (Docker) | Integration tests | Assumed available (used in Phases 12-13) | latest | Run: `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/invoice_test.exs` |
| Full suite command | `mix test` |
| Integration tests | `mix test --include integration` (requires stripe-mock) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BILL-04 | Invoice CRUD: create/retrieve/update/list/stream/search | unit (Mox) | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| BILL-04 | Invoice CRUD round-trip against stripe-mock | integration | `mix test test/integration/invoice_integration_test.exs --include integration` | No — Wave 0 |
| BILL-04b | Action verbs: finalize/void/pay/send_invoice/mark_uncollectible | unit (Mox) | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| BILL-04c | upcoming/3 returns %Invoice{id: nil} | unit (Mox) | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| BILL-04c | create_preview/3 returns %Invoice{id: nil} | unit (Mox) | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| BILL-04c | Proration guard fires {:error, :proration_required} when enabled and param absent | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | No — Wave 0 |
| BILL-04c | Proration guard passes when param present | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | No — Wave 0 |
| BILL-04c | Proration guard passes when require_explicit_proration: false | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | No — Wave 0 |
| BILL-10 | Invoice.list_line_items/4 returns typed LineItem structs | unit (Mox) | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| BILL-10 | Invoice.stream_line_items!/3 emits LineItem structs | unit (Mox) | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| BILL-10 | Invoice.lines field parsed as %List{data: [%LineItem{}]} | unit | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| D-14c | Auto-advance telemetry fires when "auto_advance" absent | unit | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| D-14c | Auto-advance telemetry NOT fired when "auto_advance" present | unit | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |
| D-14e | InvoiceItem CRUD round-trip against stripe-mock | integration | `mix test test/integration/invoice_item_integration_test.exs --include integration` | No — Wave 0 |
| D-14g | Status atomization: "draft" -> :draft etc. | unit | `mix test test/lattice_stripe/invoice_test.exs` | No — Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/invoice_test.exs test/lattice_stripe/billing/guards_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green + integration suite green (`mix test --include integration`) before `/gsd-verify-work`

### Wave 0 Gaps

All test files are new. Wave 0 must create:
- [ ] `test/lattice_stripe/invoice_test.exs`
- [ ] `test/lattice_stripe/invoice/line_item_test.exs`
- [ ] `test/lattice_stripe/invoice/status_transitions_test.exs`
- [ ] `test/lattice_stripe/invoice/automatic_tax_test.exs`
- [ ] `test/lattice_stripe/invoice_item_test.exs`
- [ ] `test/lattice_stripe/invoice_item/period_test.exs`
- [ ] `test/lattice_stripe/billing/guards_test.exs`
- [ ] `test/integration/invoice_integration_test.exs`
- [ ] `test/integration/invoice_item_integration_test.exs`

No new framework installs needed — ExUnit and Mox already configured.

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Client carries api_key — no change in Phase 14 |
| V3 Session Management | No | Stateless SDK — no sessions |
| V4 Access Control | No | Stripe API key controls access |
| V5 Input Validation | Partial | NimbleOptions validates `require_explicit_proration`; no new user-input surfaces |
| V6 Cryptography | No | No new crypto in Phase 14 |

**Invoice-specific security notes:**
- `auto_advance: false` does NOT prevent finalization via the Dashboard — only via API default. Document this clearly.
- InvoiceItem `draft constraint` must be in `@doc`, not enforced client-side (Stripe is the authority).
- No PII fields on Invoice that need `Inspect` hiding beyond what the standard inspect protocol provides (customer_email, customer_address stay as fields — no hiding needed per existing patterns; only `client_secret` was hidden in PaymentIntent).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Invoice line items endpoint is `/v1/invoices/:id/lines` (not `/line_items`) | Architecture Patterns #3, Pitfall 3 | Integration tests return 404; easy to fix pre-merge |
| A2 | Invoice LineItem `@known_fields` includes: id, object, amount, amount_excluding_tax, currency, description, discount_amounts, discountable, discounts, invoice, livemode, metadata, period, plan, price, proration, proration_details, quantity, subscription, subscription_item, tax_amounts, tax_rates, type, unit_amount_excluding_tax | Architecture Patterns #4 | Extra fields land in `extra: %{}` (safe) or known fields are missing (gaps) |
| A3 | InvoiceItem `@known_fields` includes the list provided in Architecture Patterns #7 | Architecture Patterns #7 | Same as A2 — gracefully degraded via `extra` field |
| A4 | `create_preview` was introduced in API version `2025-03-31.basil` | State of the Art, Pitfall 2 | Wrong deprecation timeline in docs; no functional impact |
| A5 | `create_preview_lines/3` uses POST (not GET) because it follows the `create_preview` POST pattern | Architecture Patterns #10, Anti-patterns | Should use GET: fix the method; easy to verify against Stripe docs |
| A6 | `%LatticeStripe.List{}` has fields: `data`, `has_more`, `url` | Architecture Patterns #14 | If field names differ, parse_lines/1 produces wrong struct |

**Verification actions for planner:**
- A1: Check `https://docs.stripe.com/api/invoice-line-item/list` before writing the path string
- A2/A3: Check `https://docs.stripe.com/api/invoice-line-item/object` and `https://docs.stripe.com/api/invoiceitems/object` for complete field lists
- A5: Check `https://docs.stripe.com/api/invoices/create_preview` for the lines pagination endpoint method and path
- A6: Read `lib/lattice_stripe/list.ex` (not read in this session — verify field names before parse_lines/1)

---

## Open Questions (RESOLVED)

1. **Invoice line items endpoint path** -- RESOLVED
   - **Answer:** `GET /v1/invoices/:id/lines` (NOT `/line_items`). Confirmed via Stripe API docs (curl example shows `/v1/invoices/in_xxx/lines`) and Stripe Node SDK (`listLineItems()` maps to `/v1/invoices/{id}/lines`). Despite the Checkout pattern using `/line_items`, Invoices use `/lines`.

2. **`%LatticeStripe.List{}` field names for parse_lines/1** -- RESOLVED
   - **Answer:** `List` struct fields are: `data`, `has_more`, `url`, `total_count`, `next_page`. `from_json/3` accepts `(decoded_map, params \\ %{}, opts \\ [])` and returns `%List{}`. Confirmed by reading `lib/lattice_stripe/list.ex`.

3. **create_preview_lines endpoint method** -- RESOLVED
   - **Answer:** `POST /v1/invoices/create_preview/lines`. Follows the same pattern as `create_preview` itself (POST). The legacy `upcoming/lines` is `GET /v1/invoices/upcoming/lines`. Both are documented in D-14b.

4. **Telemetry handler ID for auto-advance on second attach_default_logger/1 call** -- RESOLVED
   - **Answer:** Use a separate ID `@auto_advance_logger_id "lattice_stripe.auto_advance_logger"`. Detach it explicitly at the top of `attach_default_logger/1` before re-attaching. Already implemented in Plan 04 Task 1.

---

## Sources

### Primary (HIGH confidence)
- `lib/lattice_stripe/payment_intent.ex` [VERIFIED: read in session] — action verb pattern (confirm/capture/cancel)
- `lib/lattice_stripe/checkout/session.ex` [VERIFIED: read in session] — list_line_items/4, stream_line_items!/4 pattern
- `lib/lattice_stripe/checkout/line_item.ex` [VERIFIED: read in session] — LineItem data struct precedent
- `lib/lattice_stripe/customer.ex` [VERIFIED: project file] — v1 resource template
- `lib/lattice_stripe/coupon.ex` [VERIFIED: read in session] — D-05 moduledoc pattern
- `lib/lattice_stripe/telemetry.ex` [VERIFIED: read in session] — existing event structure, attach_default_logger/1
- `lib/lattice_stripe/error.ex` [VERIFIED: read in session] — Error struct, type union, locally-constructed errors
- `lib/lattice_stripe/client.ex` [VERIFIED: read in session] — Client struct fields, Config integration
- `lib/lattice_stripe/config.ex` [VERIFIED: read in session] — NimbleOptions schema pattern
- `lib/lattice_stripe/resource.ex` [VERIFIED: read in session] — unwrap_singular/2, unwrap_list/2, unwrap_bang!/1
- `lib/lattice_stripe/discount.ex` [VERIFIED: read in session] — nested struct with from_map/1 accepting nil or map
- `mix.exs` [VERIFIED: read in session] — deps, docs extras, groups_for_modules structure
- `.planning/phases/14-invoices-invoice-line-items/14-CONTEXT.md` [VERIFIED: read in session] — all locked decisions
- `test/integration/payment_intent_integration_test.exs` [VERIFIED: read in session] — integration test pattern

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` [VERIFIED: read in session] — BILL-04/04b/04c/BILL-10 requirements
- `.planning/STATE.md` [VERIFIED: read in session] — accumulated project decisions
- `CLAUDE.md` [VERIFIED: read at session start via system prompt] — project constraints, tech stack

### Tertiary (LOW confidence / ASSUMED)
- Stripe Invoice API field list — inferred from training knowledge [ASSUMED: A2, A3]
- `create_preview` API version cutoff — training knowledge [ASSUMED: A4]
- `create_preview_lines` HTTP method — training knowledge [ASSUMED: A5]

---

## Project Constraints (from CLAUDE.md)

| Constraint | Impact on Phase 14 |
|------------|-------------------|
| No Dialyzer | Typespecs for documentation only — no `@spec` enforcement needed |
| HTTP: Transport behaviour with Finch default | All HTTP routes through `Client.request/2` — no direct Finch calls in resource modules |
| JSON: Jason | All decoding via `client.json_codec.decode/1` — no direct Jason calls |
| Dependencies: Minimal | No new deps in Phase 14 |
| Elixir 1.15+ | No 1.18+ stdlib JSON module usage |
| No GenServer for state | `Billing.Guards` is a pure function module, no process |
| Global module-level configuration forbidden | `require_explicit_proration` is on the Client struct, not Application env |

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps, all existing infrastructure verified in session
- Architecture: HIGH — all patterns have direct codebase precedents verified in session
- Invoice field list: MEDIUM — training knowledge for completeness, planner should spot-check against Stripe docs
- Stripe endpoint paths for preview lines: HIGH — verified against Stripe docs and official SDKs during plan revision

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable patterns; Stripe API version changes possible)
