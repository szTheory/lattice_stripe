defmodule LatticeStripe.Tax.Transaction do
  @moduledoc """
  Record and reverse tax via Stripe's standalone Tax Transactions API.

  ## Lifecycle

  Create a transaction from a live calculation ID with a globally unique
  `reference`, inspect it via `retrieve/3` or `list_line_items/4`, and reverse
  it with `create_reversal/3` when refunds or corrections require undoing
  recorded tax.

  ## Operational constraints

  Tax calculations expire after roughly **90 days** — create transactions from
  a calculation before `expires_at`. The `reference` you pass to
  `create_from_calculation/3` and `create_reversal/3` must be **globally
  unique** across all tax transactions in your Stripe account (for example
  `"order_\#{order_id}"`).

  ## Relationship to other tax surfaces

  This module is **not** `LatticeStripe.Invoice.AutomaticTax`. Automatic tax on
  Invoices, Subscriptions, and Quotes is configured via nested `automatic_tax`
  settings on those Billing resources. Use this Transactions API for custom
  payment flows that calculate tax with `LatticeStripe.Tax.Calculation` first.
  Filing, returns, and threshold monitoring are out of SDK scope.

  ## Usage

      reference = "order_\#{order.id}"

      {:ok, txn} =
        LatticeStripe.Tax.Transaction.create_from_calculation(client, %{
          "calculation" => calc.id,
          "reference" => reference
        })

      {:ok, reversal} =
        LatticeStripe.Tax.Transaction.create_reversal(client, %{
          "mode" => "full",
          "original_transaction" => txn.id,
          "reference" => "\#{reference}-rev"
        })

  See [Standalone Tax API](guides/tax.md) for the canonical calculate → record → reverse workflow.

  See [Stripe Tax Transactions](https://docs.stripe.com/api/tax/transactions).
  """

  alias LatticeStripe.{
    Client,
    Error,
    List,
    ObjectTypes,
    Request,
    Resource,
    Response
  }

  alias LatticeStripe.Tax.{CustomerDetails, ShippingCost}
  alias LatticeStripe.Tax.Transaction.LineItem

  @known_fields ~w[
    id object created currency customer customer_details line_items livemode metadata
    posted_at reference reversal shipping_cost tax_date type
  ]

  defstruct [
    :id,
    :created,
    :currency,
    :customer,
    :customer_details,
    :line_items,
    :livemode,
    :metadata,
    :posted_at,
    :reference,
    :reversal,
    :shipping_cost,
    :tax_date,
    :type,
    object: "tax.transaction",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          created: integer() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          customer_details: CustomerDetails.t() | nil,
          line_items: List.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          posted_at: integer() | nil,
          reference: String.t() | nil,
          reversal: map() | String.t() | nil,
          shipping_cost: ShippingCost.t() | nil,
          tax_date: integer() | nil,
          type: String.t() | nil,
          extra: map()
        }

  @doc """
  Creates a Tax Transaction from an existing Tax Calculation.
  """
  @spec create_from_calculation(Client.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create_from_calculation(%Client{} = client, params, opts \\ []) do
    %Request{
      method: :post,
      path: "/v1/tax/transactions/create_from_calculation",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create_from_calculation/3` but raises on failure."
  @spec create_from_calculation!(Client.t(), map(), keyword()) :: t()
  def create_from_calculation!(%Client{} = client, params, opts \\ []) do
    create_from_calculation(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Creates a reversal Tax Transaction.
  """
  @spec create_reversal(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create_reversal(%Client{} = client, params, opts \\ []) do
    %Request{
      method: :post,
      path: "/v1/tax/transactions/create_reversal",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create_reversal/3` but raises on failure."
  @spec create_reversal!(Client.t(), map(), keyword()) :: t()
  def create_reversal!(%Client{} = client, params, opts \\ []) do
    create_reversal(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a Tax Transaction by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/tax/transactions/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists line items for a Tax Transaction.
  """
  @spec list_line_items(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_line_items(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{
      method: :get,
      path: "/v1/tax/transactions/#{id}/line_items",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&LineItem.from_map/1)
  end

  @doc "Like `list_line_items/4` but raises on failure."
  @spec list_line_items!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list_line_items!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    list_line_items(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "tax.transaction",
      created: known["created"],
      currency: known["currency"],
      customer: ObjectTypes.maybe_deserialize(known["customer"]),
      customer_details: CustomerDetails.from_map(known["customer_details"]),
      line_items: parse_line_items(known["line_items"]),
      livemode: known["livemode"],
      metadata: known["metadata"],
      posted_at: known["posted_at"],
      reference: known["reference"],
      reversal: known["reversal"],
      shipping_cost: ShippingCost.from_map(known["shipping_cost"]),
      tax_date: known["tax_date"],
      type: known["type"],
      extra: extra
    }
  end

  defp parse_line_items(nil), do: nil

  defp parse_line_items(%{"object" => "list", "data" => data} = list) when is_list(data) do
    %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
  end

  defp parse_line_items(other), do: other
end
