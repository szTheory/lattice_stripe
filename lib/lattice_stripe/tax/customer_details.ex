defmodule LatticeStripe.Tax.CustomerDetails do
  @moduledoc """
  The `customer_details` object embedded in a Stripe Tax calculation or transaction.

  Reachable from `t:LatticeStripe.Tax.Calculation.t/0` and
  `t:LatticeStripe.Tax.Transaction.t/0`. It records the address Stripe actually used to
  source the tax decision, which is what you inspect when a calculation lands in an
  unexpected jurisdiction.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[address address_source ip_address tax_ids taxability_override]

  defstruct [
    :address,
    :address_source,
    :ip_address,
    :tax_ids,
    :taxability_override,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          address: map() | nil,
          address_source: String.t() | nil,
          ip_address: String.t() | nil,
          tax_ids: list() | nil,
          taxability_override: atom() | String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      address: known["address"],
      address_source: known["address_source"],
      ip_address: known["ip_address"],
      tax_ids: known["tax_ids"],
      taxability_override: atomize_taxability_override(known["taxability_override"]),
      extra: extra
    }
  end

  defp atomize_taxability_override("none"), do: :none
  defp atomize_taxability_override("customer_exempt"), do: :customer_exempt
  defp atomize_taxability_override("reverse_charge"), do: :reverse_charge
  defp atomize_taxability_override(nil), do: nil
  defp atomize_taxability_override(other), do: other
end
