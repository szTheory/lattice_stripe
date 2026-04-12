defmodule LatticeStripe.Invoice.LineItem do
  @moduledoc """
  Represents a line item on a Stripe Invoice.

  ## InvoiceItem vs Invoice Line Item

  These are distinct Stripe objects and should not be confused:

  - `LatticeStripe.InvoiceItem` — a standalone billable item that gets attached to an
    invoice. Has its own CRUD surface (`/v1/invoiceitems`). Identified by `ii_...` IDs.
  - `LatticeStripe.Invoice.LineItem` — a read-only view of a line item as it appears on
    a finalized invoice. Accessed via `/v1/invoices/:id/lines`. Identified by `il_...` IDs.

  Invoice line items are returned inside Invoice objects and from
  `LatticeStripe.Invoice.list_line_items/3`. They cannot be created directly.

  ## Fields

  - `id` - Line item ID (`il_...`)
  - `object` - Always `"line_item"`
  - `amount` - Amount in smallest currency unit (e.g., cents)
  - `amount_excluding_tax` - Amount before taxes
  - `currency` - Three-letter ISO currency code
  - `description` - Human-readable description
  - `discount_amounts` - List of discount amount objects
  - `discountable` - Whether discounts apply to this line item
  - `discounts` - List of discount IDs or objects
  - `invoice` - Parent invoice ID
  - `invoice_item` - InvoiceItem ID (`ii_...`) if this line item originated from an InvoiceItem
  - `livemode` - Whether the object exists in live mode
  - `metadata` - Set of key-value pairs
  - `period` - Billing period map (`%{"start" => ..., "end" => ...}`)
  - `plan` - Plan object if the line item is from a subscription plan
  - `price` - Price object associated with this line item
  - `proration` - Whether this line item is a proration
  - `proration_details` - Details about the proration
  - `quantity` - Quantity for this line item
  - `subscription` - Subscription ID if applicable
  - `subscription_item` - SubscriptionItem ID if applicable
  - `tax_amounts` - List of tax amount objects
  - `tax_rates` - List of tax rate objects
  - `type` - Type of the line item: `"invoiceitem"` or `"subscription"`
  - `unit_amount_excluding_tax` - Unit amount excluding tax as a string decimal
  - `extra` - Unknown fields from Stripe not yet in this struct

  ## Stripe API Reference

  See the [Stripe Invoice line item object](https://docs.stripe.com/api/invoices/line_item)
  for field definitions.
  """

  @known_fields ~w[
    id object amount amount_excluding_tax currency description
    discount_amounts discountable discounts invoice invoice_item
    livemode metadata period plan price proration proration_details
    quantity subscription subscription_item tax_amounts tax_rates
    type unit_amount_excluding_tax
  ]

  defstruct [
    :id,
    :amount,
    :amount_excluding_tax,
    :currency,
    :description,
    :discount_amounts,
    :discountable,
    :discounts,
    :invoice,
    :invoice_item,
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
    :tax_amounts,
    :tax_rates,
    :type,
    :unit_amount_excluding_tax,
    object: "line_item",
    extra: %{}
  ]

  @typedoc """
  A line item on a Stripe Invoice.

  Accessed via `LatticeStripe.Invoice.list_line_items/3` or returned nested in
  Invoice objects. Cannot be created directly.

  See [Stripe Invoice line items](https://docs.stripe.com/api/invoices/line_item)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          amount_excluding_tax: integer() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          discount_amounts: list() | nil,
          discountable: boolean() | nil,
          discounts: list() | nil,
          invoice: String.t() | nil,
          invoice_item: String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          period: map() | nil,
          plan: map() | nil,
          price: map() | nil,
          proration: boolean() | nil,
          proration_details: map() | nil,
          quantity: integer() | nil,
          subscription: String.t() | nil,
          subscription_item: String.t() | nil,
          tax_amounts: list() | nil,
          tax_rates: list() | nil,
          type: String.t() | nil,
          unit_amount_excluding_tax: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%LineItem{}` struct.

  Maps all known line item fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost.

  Returns `nil` when given `nil`.

  ## Example

      iex> LatticeStripe.Invoice.LineItem.from_map(%{
      ...>   "id" => "il_test123",
      ...>   "object" => "line_item",
      ...>   "amount" => 2000,
      ...>   "currency" => "usd"
      ...> })
      %LatticeStripe.Invoice.LineItem{id: "il_test123", amount: 2000, currency: "usd", ...}
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "line_item",
      amount: known["amount"],
      amount_excluding_tax: known["amount_excluding_tax"],
      currency: known["currency"],
      description: known["description"],
      discount_amounts: known["discount_amounts"],
      discountable: known["discountable"],
      discounts: known["discounts"],
      invoice: known["invoice"],
      invoice_item: known["invoice_item"],
      livemode: known["livemode"],
      metadata: known["metadata"],
      period: known["period"],
      plan: known["plan"],
      price: known["price"],
      proration: known["proration"],
      proration_details: known["proration_details"],
      quantity: known["quantity"],
      subscription: known["subscription"],
      subscription_item: known["subscription_item"],
      tax_amounts: known["tax_amounts"],
      tax_rates: known["tax_rates"],
      type: known["type"],
      unit_amount_excluding_tax: known["unit_amount_excluding_tax"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.Invoice.LineItem do
  import Inspect.Algebra

  def inspect(item, opts) do
    # Show key display fields. Show extra only when non-empty to reduce noise.
    base_fields = [
      id: item.id,
      object: item.object,
      amount: item.amount,
      currency: item.currency,
      description: item.description,
      type: item.type
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

    concat(["#LatticeStripe.Invoice.LineItem<" | pairs] ++ [">"])
  end
end
