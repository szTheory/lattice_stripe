defmodule LatticeStripe.Account.BusinessProfile do
  @moduledoc """
  Represents the `business_profile` nested object on a Stripe Account.

  This struct is promoted from the Account API response per Phase 17 D-01, which
  identifies `business_profile` as a high-frequency pattern-match target — developers
  frequently read `name`, `url`, `mcc`, `support_email`, `support_phone`, and
  `product_description` in onboarding and dashboard flows.

  Unknown fields from the Stripe API response are preserved in `:extra` per the
  F-001 forward-compatibility pattern, ensuring unknown fields are never silently dropped.

  See [Stripe Account API](https://docs.stripe.com/api/accounts/object#account_object-business_profile).
  """

  @known_fields ~w[mcc monthly_estimated_revenue name product_description support_address
                   support_email support_phone support_url url]

  defstruct [
    :mcc,
    :monthly_estimated_revenue,
    :name,
    :product_description,
    :support_address,
    :support_email,
    :support_phone,
    :support_url,
    :url,
    extra: %{}
  ]

  @typedoc "Business profile settings for a Stripe Account."
  @type t :: %__MODULE__{
          mcc: String.t() | nil,
          monthly_estimated_revenue: map() | nil,
          name: String.t() | nil,
          product_description: String.t() | nil,
          support_address: map() | nil,
          support_email: String.t() | nil,
          support_phone: String.t() | nil,
          support_url: String.t() | nil,
          url: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%BusinessProfile{}` struct.

  Returns `nil` when given `nil`.

  Unknown fields from the Stripe API are captured in `:extra` (F-001 pattern)
  for forward compatibility.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
