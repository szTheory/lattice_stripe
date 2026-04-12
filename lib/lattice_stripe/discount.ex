defmodule LatticeStripe.Discount do
  @moduledoc """
  Represents a Stripe Discount applied to a Customer, Subscription, Invoice,
  or Checkout Session.

  A Discount is the applied form of a Coupon — it tracks when a coupon was
  attached to a parent object and, for repeating coupons, when the discount
  period ends. Discounts are never fetched on their own — they are always
  returned as a nested field on a parent object, and `from_map/1` is called
  by the parent's decoder.

  ## Fields

  - `id` — Discount ID (`di_...`); may be nil on freshly-created discounts
  - `object` — Always `"discount"`
  - `coupon` — The embedded Coupon object (or string ID when unexpanded)
  - `promotion_code` — PromotionCode ID if the discount originated from one
  - `customer` — Customer ID this discount applies to
  - `subscription` — Subscription ID this discount applies to
  - `invoice` — Invoice ID
  - `invoice_item` — InvoiceItem ID
  - `checkout_session` — CheckoutSession ID
  - `start` — Unix timestamp when the discount became active
  - `end` — Unix timestamp when the discount ends (for repeating coupons)

  ## Stripe API Reference

  See the [Stripe Discount object](https://docs.stripe.com/api/discounts/object).
  """

  @known_fields ~w[
    id object checkout_session coupon customer end invoice invoice_item
    promotion_code start subscription
  ]

  defstruct [
    :id,
    :checkout_session,
    :coupon,
    :customer,
    :end,
    :invoice,
    :invoice_item,
    :promotion_code,
    :start,
    :subscription,
    object: "discount",
    extra: %{}
  ]

  @typedoc """
  A Stripe Discount.

  `:coupon` is typed as `term()` until `LatticeStripe.Coupon` lands (Plan 12-06),
  at which point the typespec tightens to `LatticeStripe.Coupon.t() | String.t() | nil`.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          checkout_session: String.t() | nil,
          coupon: term() | nil,
          customer: String.t() | nil,
          end: integer() | nil,
          invoice: String.t() | nil,
          invoice_item: String.t() | nil,
          promotion_code: String.t() | nil,
          start: integer() | nil,
          subscription: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Discount{}` struct.

  The `coupon` field accepts three shapes:

  - `nil` — no embedded coupon
  - a string — unexpanded coupon ID, kept as-is
  - a map — expanded coupon object; kept as a raw map until `LatticeStripe.Coupon`
    lands in Plan 12-06, which replaces this branch to call `Coupon.from_map/1`.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "discount",
      checkout_session: map["checkout_session"],
      coupon: map["coupon"],
      customer: map["customer"],
      end: map["end"],
      invoice: map["invoice"],
      invoice_item: map["invoice_item"],
      promotion_code: map["promotion_code"],
      start: map["start"],
      subscription: map["subscription"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
