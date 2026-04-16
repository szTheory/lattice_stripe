defmodule LatticeStripe.InvoiceItem do
  @moduledoc """
  Operations on Stripe InvoiceItem objects.

  An InvoiceItem is a billable line that you create explicitly and attach to an invoice
  before it is finalized. InvoiceItems live at `/v1/invoiceitems` and are mutatable while
  the target invoice is in draft status.

  ## InvoiceItem vs Invoice Line Item

  **InvoiceItem** (this module) is a standalone resource you create explicitly at
  `/v1/invoiceitems`. Mutatable while the target invoice is in draft status.

  **Invoice Line Item** (`LatticeStripe.Invoice.LineItem`) is a read-only rendered row on
  a finalized invoice, accessed via `Invoice.list_line_items/4`. Invoice line items have
  `il_...` IDs; InvoiceItems have `ii_...` IDs.

  InvoiceItems can only be added to invoices in draft status. Once finalized, line items
  are locked.

  ## Operations not supported by the Stripe API

  - **search** — The `/v1/invoiceitems/search` endpoint does not exist. Use `list/2` with
    filters for discovery.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create an InvoiceItem and attach it to a draft invoice
      {:ok, item} = LatticeStripe.InvoiceItem.create(client, %{
        "customer" => "cus_123",
        "invoice" => "in_123",
        "amount" => 5000,
        "currency" => "usd",
        "description" => "Professional services"
      })

      # Retrieve an InvoiceItem
      {:ok, item} = LatticeStripe.InvoiceItem.retrieve(client, item.id)

      # List InvoiceItems for a customer
      {:ok, resp} = LatticeStripe.InvoiceItem.list(client, %{"customer" => "cus_123"})

  ## Stripe API Reference

  See the [Stripe InvoiceItem API](https://docs.stripe.com/api/invoiceitems) for the full
  object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}
  alias LatticeStripe.InvoiceItem.Period

  # Known top-level fields from the Stripe InvoiceItem object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount currency customer date description discountable discounts
    invoice livemode metadata period plan price proration proration_details
    quantity subscription subscription_item tax_rates test_clock unit_amount
    unit_amount_decimal unit_amount_excluding_tax deleted
  ]

  defstruct [
    :id,
    :amount,
    :currency,
    :customer,
    :date,
    :description,
    :discountable,
    :discounts,
    :invoice,
    :livemode,
    :metadata,
    :period,
    :plan,
    :price,
    :proration,
    :proration_details,
    :quantity,
    :subscription,
    :subscription_item,
    :tax_rates,
    :test_clock,
    :unit_amount,
    :unit_amount_decimal,
    :unit_amount_excluding_tax,
    object: "invoiceitem",
    deleted: false,
    extra: %{}
  ]

  @typedoc """
  A Stripe InvoiceItem object.

  See the [Stripe InvoiceItem API](https://docs.stripe.com/api/invoiceitems/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          date: integer() | nil,
          description: String.t() | nil,
          discountable: boolean() | nil,
          discounts: list() | nil,
          invoice: LatticeStripe.Invoice.t() | String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          period: Period.t() | nil,
          plan: map() | nil,
          price: map() | nil,
          proration: boolean() | nil,
          proration_details: map() | nil,
          quantity: integer() | nil,
          subscription: LatticeStripe.Subscription.t() | String.t() | nil,
          subscription_item: String.t() | nil,
          tax_rates: list() | nil,
          test_clock: String.t() | nil,
          unit_amount: integer() | nil,
          unit_amount_decimal: String.t() | nil,
          unit_amount_excluding_tax: String.t() | nil,
          deleted: boolean(),
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new InvoiceItem.

  Sends `POST /v1/invoiceitems` with the given params and returns `{:ok, %InvoiceItem{}}`.

  Only applicable to draft invoices. Once an invoice is finalized, its line items are locked.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of InvoiceItem attributes. Common params:
    - `"customer"` - Customer ID (required)
    - `"amount"` - Amount in smallest currency unit
    - `"currency"` - Three-letter ISO currency code
    - `"invoice"` - Invoice ID to attach to (must be in draft status)
    - `"description"` - Human-readable description
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %InvoiceItem{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/invoiceitems", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves an InvoiceItem by ID.

  Sends `GET /v1/invoiceitems/:id` and returns `{:ok, %InvoiceItem{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The InvoiceItem ID string (e.g., `"ii_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %InvoiceItem{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/invoiceitems/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates an InvoiceItem by ID.

  Sends `POST /v1/invoiceitems/:id` with the given params and returns `{:ok, %InvoiceItem{}}`.

  Only applicable to draft invoices. Once an invoice is finalized, its line items are locked.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The InvoiceItem ID string
  - `params` - Map of fields to update
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %InvoiceItem{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/invoiceitems/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Deletes an InvoiceItem by ID.

  Sends `DELETE /v1/invoiceitems/:id` and returns `{:ok, %InvoiceItem{}}`.

  Only applicable to draft invoices. Once an invoice is finalized, its line items are locked.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The InvoiceItem ID string
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %InvoiceItem{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :delete, path: "/v1/invoiceitems/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists InvoiceItems with optional filters.

  Sends `GET /v1/invoiceitems` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%InvoiceItem{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"customer" => "cus_123", "invoice" => "in_123"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%InvoiceItem{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/invoiceitems", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all InvoiceItems matching the given params (auto-pagination).

  Emits individual `%InvoiceItem{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"customer" => "cus_123"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%InvoiceItem{}` structs.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/invoiceitems", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc "Like `create/3` but raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `retrieve/3` but raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `update/4` but raises `LatticeStripe.Error` on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `delete/3` but raises `LatticeStripe.Error` on failure."
  @spec delete!(Client.t(), String.t(), keyword()) :: t()
  def delete!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    delete(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `list/3` but raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%InvoiceItem{}` struct.

  Maps all known Stripe InvoiceItem fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost.

  Parses the `period` field into a `%LatticeStripe.InvoiceItem.Period{}` struct.

  ## Example

      item = LatticeStripe.InvoiceItem.from_map(%{
        "id" => "ii_123",
        "amount" => 5000,
        "currency" => "usd",
        "customer" => "cus_123",
        "object" => "invoiceitem"
      })
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "invoiceitem",
      amount: known["amount"],
      currency: known["currency"],
      customer:
        (if is_map(known["customer"]),
           do: ObjectTypes.maybe_deserialize(known["customer"]),
           else: known["customer"]),
      date: known["date"],
      description: known["description"],
      discountable: known["discountable"],
      discounts: known["discounts"],
      invoice:
        (if is_map(known["invoice"]),
           do: ObjectTypes.maybe_deserialize(known["invoice"]),
           else: known["invoice"]),
      livemode: known["livemode"],
      metadata: known["metadata"],
      period: Period.from_map(known["period"]),
      plan: known["plan"],
      price: known["price"],
      proration: known["proration"],
      proration_details: known["proration_details"],
      quantity: known["quantity"],
      subscription:
        (if is_map(known["subscription"]),
           do: ObjectTypes.maybe_deserialize(known["subscription"]),
           else: known["subscription"]),
      subscription_item: known["subscription_item"],
      tax_rates: known["tax_rates"],
      test_clock: known["test_clock"],
      unit_amount: known["unit_amount"],
      unit_amount_decimal: known["unit_amount_decimal"],
      unit_amount_excluding_tax: known["unit_amount_excluding_tax"],
      deleted: known["deleted"] || false,
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.InvoiceItem do
  import Inspect.Algebra

  def inspect(item, opts) do
    # Show key structural fields. Show extra only when non-empty to reduce noise.
    base_fields = [
      id: item.id,
      object: item.object,
      amount: item.amount,
      currency: item.currency,
      description: item.description,
      livemode: item.livemode
    ]

    fields =
      if item.extra == %{} do
        base_fields
      else
        base_fields ++ [extra: item.extra]
      end

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.InvoiceItem<" | pairs] ++ [">"])
  end
end
