defmodule LatticeStripe.Card do
  @moduledoc """
  A Stripe debit card attached to a Connect connected account (external account).

  Cards are one of the two sum-type members returned by
  `LatticeStripe.ExternalAccount` CRUDL operations; the other is
  `LatticeStripe.BankAccount`. All network operations live on
  `LatticeStripe.ExternalAccount` — this module owns only the struct shape,
  the `cast/1` / `from_map/1` helpers, and a PII-safe `Inspect`
  implementation.

  ## PII and Inspect

  `inspect/1` shows only `id`, `object`, `brand`, `country`, and `funding`.
  The following fields are deliberately hidden because they are cardholder
  data that must never appear in logs or error reports: `last4`,
  `dynamic_last4`, `fingerprint`, `exp_month`, `exp_year`, `name`, every
  `address_*` field, `address_line1_check`, `cvc_check`, `address_zip_check`.

  ## F-001 forward-compat

  Unknown keys from Stripe are preserved in the `:extra` map so new fields
  added by Stripe flow through without code changes. The `"deleted" => true`
  flag from a `DELETE` response is preserved in `:extra`.

  ## Stripe API Reference

  - https://docs.stripe.com/api/external_account_cards
  """

  alias LatticeStripe.ObjectTypes

  # Known top-level fields. String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object account address_city address_country address_line1
    address_line1_check address_line2 address_state address_zip
    address_zip_check available_payout_methods brand country currency
    customer cvc_check default_for_currency dynamic_last4 exp_month
    exp_year fingerprint funding last4 metadata name tokenization_method
  ]

  defstruct [
    :id,
    :account,
    :address_city,
    :address_country,
    :address_line1,
    :address_line1_check,
    :address_line2,
    :address_state,
    :address_zip,
    :address_zip_check,
    :available_payout_methods,
    :brand,
    :country,
    :currency,
    :customer,
    :cvc_check,
    :default_for_currency,
    :dynamic_last4,
    :exp_month,
    :exp_year,
    :fingerprint,
    :funding,
    :last4,
    :metadata,
    :name,
    :tokenization_method,
    object: "card",
    extra: %{}
  ]

  @typedoc "A Stripe debit card on a Connect connected account."
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          account: String.t() | nil,
          address_city: String.t() | nil,
          address_country: String.t() | nil,
          address_line1: String.t() | nil,
          address_line1_check: String.t() | nil,
          address_line2: String.t() | nil,
          address_state: String.t() | nil,
          address_zip: String.t() | nil,
          address_zip_check: String.t() | nil,
          available_payout_methods: [String.t()] | nil,
          brand: String.t() | nil,
          country: String.t() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          cvc_check: String.t() | nil,
          default_for_currency: boolean() | nil,
          dynamic_last4: String.t() | nil,
          exp_month: integer() | nil,
          exp_year: integer() | nil,
          fingerprint: String.t() | nil,
          funding: String.t() | nil,
          last4: String.t() | nil,
          metadata: map() | nil,
          name: String.t() | nil,
          tokenization_method: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Card{}` struct.

  Maps all known Stripe card fields. Any unrecognized fields are collected
  into `:extra` so no data is silently lost (F-001).
  """
  @spec cast(map() | nil) :: t() | nil
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "card",
      account: map["account"],
      address_city: map["address_city"],
      address_country: map["address_country"],
      address_line1: map["address_line1"],
      address_line1_check: map["address_line1_check"],
      address_line2: map["address_line2"],
      address_state: map["address_state"],
      address_zip: map["address_zip"],
      address_zip_check: map["address_zip_check"],
      available_payout_methods: map["available_payout_methods"],
      brand: map["brand"],
      country: map["country"],
      currency: map["currency"],
      customer:
        (if is_map(map["customer"]),
           do: ObjectTypes.maybe_deserialize(map["customer"]),
           else: map["customer"]),
      cvc_check: map["cvc_check"],
      default_for_currency: map["default_for_currency"],
      dynamic_last4: map["dynamic_last4"],
      exp_month: map["exp_month"],
      exp_year: map["exp_year"],
      fingerprint: map["fingerprint"],
      funding: map["funding"],
      last4: map["last4"],
      metadata: map["metadata"],
      name: map["name"],
      tokenization_method: map["tokenization_method"],
      extra: Map.drop(map, @known_fields)
    }
  end

  @doc "Alias for `cast/1`. Provided for callers that prefer the `from_map` naming."
  @spec from_map(map() | nil) :: t() | nil
  def from_map(map), do: cast(map)
end

defimpl Inspect, for: LatticeStripe.Card do
  import Inspect.Algebra

  def inspect(card, opts) do
    fields = [
      id: card.id,
      object: card.object,
      brand: card.brand,
      country: card.country,
      funding: card.funding
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Card<" | pairs] ++ [">"])
  end
end
