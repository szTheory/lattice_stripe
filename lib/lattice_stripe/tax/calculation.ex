defmodule LatticeStripe.Tax.Calculation do
  @moduledoc """
  Calculate tax for custom payment flows via Stripe's standalone Tax Calculations API.

  ## Lifecycle

  Create a calculation with `create/3`, inspect it with `retrieve/3` or
  `list_line_items/4`, then (within roughly **90 days**, before `expires_at`)
  record tax by creating a `LatticeStripe.Tax.Transaction` from the calculation ID.
  Calculations are ephemeral working snapshots — they are not durable tax records.

  ## Relationship to other tax surfaces

  This module is **not** `LatticeStripe.Invoice.AutomaticTax`. Automatic tax on
  Invoices, Subscriptions, and Quotes is configured via nested `automatic_tax`
  settings on those Billing resources. Use this Calculations API when you own
  the payment flow and need explicit tax amounts before charging. Filing,
  returns, and threshold monitoring are out of SDK scope.

  ## Usage

      {:ok, calc} =
        LatticeStripe.Tax.Calculation.create(client, %{
          "currency" => "usd",
          "customer_details" => %{
            "address" => %{
              "line1" => "123 Main St",
              "city" => "Seattle",
              "state" => "WA",
              "postal_code" => "98101",
              "country" => "US"
            },
            "address_source" => "shipping"
          },
          "line_items" => [
            %{
              "amount" => 1000,
              "reference" => "line-1",
              "tax_behavior" => "exclusive",
              "tax_code" => "txcd_99999999"
            }
          ]
        })

  See [Standalone Tax API](guides/tax.md) for the canonical calculate → record → reverse workflow.

  See [Stripe Tax Calculations](https://docs.stripe.com/api/tax/calculations).
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

  alias LatticeStripe.Tax.Calculation.LineItem
  alias LatticeStripe.Tax.{CustomerDetails, ShipFromDetails, ShippingCost, TaxBreakdown}

  @known_fields ~w[
    id object amount_total currency customer customer_details expires_at line_items
    livemode ship_from_details shipping_cost tax_amount_exclusive tax_amount_inclusive
    tax_breakdown tax_date
  ]

  defstruct [
    :id,
    :amount_total,
    :currency,
    :customer,
    :customer_details,
    :expires_at,
    :line_items,
    :livemode,
    :ship_from_details,
    :shipping_cost,
    :tax_amount_exclusive,
    :tax_amount_inclusive,
    :tax_breakdown,
    :tax_date,
    object: "tax.calculation",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount_total: integer() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          customer_details: CustomerDetails.t() | nil,
          expires_at: integer() | nil,
          line_items: List.t() | nil,
          livemode: boolean() | nil,
          ship_from_details: ShipFromDetails.t() | nil,
          shipping_cost: ShippingCost.t() | nil,
          tax_amount_exclusive: integer() | nil,
          tax_amount_inclusive: integer() | nil,
          tax_breakdown: list(TaxBreakdown.t()) | nil,
          tax_date: integer() | nil,
          extra: map()
        }

  @doc """
  Creates a Tax Calculation.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params, opts \\ []) do
    %Request{method: :post, path: "/v1/tax/calculations", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a Tax Calculation by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/tax/calculations/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists line items for a Tax Calculation.
  """
  @spec list_line_items(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_line_items(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{
      method: :get,
      path: "/v1/tax/calculations/#{id}/line_items",
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
      object: known["object"] || "tax.calculation",
      amount_total: known["amount_total"],
      currency: known["currency"],
      customer: parse_expandable(known["customer"]),
      customer_details: CustomerDetails.from_map(known["customer_details"]),
      expires_at: known["expires_at"],
      line_items: parse_line_items(known["line_items"]),
      livemode: known["livemode"],
      ship_from_details: ShipFromDetails.from_map(known["ship_from_details"]),
      shipping_cost: ShippingCost.from_map(known["shipping_cost"]),
      tax_amount_exclusive: known["tax_amount_exclusive"],
      tax_amount_inclusive: known["tax_amount_inclusive"],
      tax_breakdown: parse_tax_breakdown(known["tax_breakdown"]),
      tax_date: known["tax_date"],
      extra: extra
    }
  end

  defp parse_expandable(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_expandable(value), do: value

  defp parse_line_items(nil), do: nil

  defp parse_line_items(%{"object" => "list", "data" => data} = list) when is_list(data) do
    %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
  end

  defp parse_line_items(other), do: other

  defp parse_tax_breakdown(nil), do: nil

  defp parse_tax_breakdown(items) when is_list(items),
    do: Enum.map(items, &TaxBreakdown.from_map/1)

  defp parse_tax_breakdown(other), do: other
end
