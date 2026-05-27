defmodule LatticeStripe.TaxId.Owner do
  @moduledoc false

  alias LatticeStripe.ObjectTypes

  @known_fields ~w[account application customer customer_account type]

  defstruct [:account, :application, :customer, :customer_account, :type, extra: %{}]

  @type t :: %__MODULE__{
          account: struct() | String.t() | nil,
          application: struct() | String.t() | nil,
          customer: struct() | String.t() | nil,
          customer_account: String.t() | nil,
          type: atom() | String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      account: parse_expandable(known["account"]),
      application: parse_expandable(known["application"]),
      customer: parse_expandable(known["customer"]),
      customer_account: known["customer_account"],
      type: atomize_type(known["type"]),
      extra: extra
    }
  end

  defp parse_expandable(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_expandable(value), do: value

  defp atomize_type("account"), do: :account
  defp atomize_type("application"), do: :application
  defp atomize_type("customer"), do: :customer
  defp atomize_type("self"), do: :self
  defp atomize_type(nil), do: nil
  defp atomize_type(other), do: other
end
