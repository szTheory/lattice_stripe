defmodule LatticeStripe.Quote.Computed do
  @moduledoc """
  Bounded computed summary data for a Stripe Quote.

  Quote `computed` payloads contain stable top-level branches such as `upfront`
  and `recurring`, but deeper pricing breakdowns are broad and fast-moving. This
  module types only the stable boundary and preserves deeper maps as Stripe-shaped
  payloads.
  """

  alias LatticeStripe.List
  alias LatticeStripe.Quote.LineItem

  @known_fields ~w[recurring upfront]

  defstruct [:recurring, :upfront, extra: %{}]

  @type t :: %__MODULE__{
          recurring: map() | nil,
          upfront: map() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      recurring: parse_branch(known["recurring"]),
      upfront: parse_branch(known["upfront"]),
      extra: extra
    }
  end

  defp parse_branch(nil), do: nil

  defp parse_branch(%{"line_items" => %{"object" => "list", "data" => data} = list} = branch)
       when is_list(data) do
    typed_items = %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
    %{branch | "line_items" => typed_items}
  end

  defp parse_branch(%{"line_items" => data} = branch) when is_list(data) do
    %{branch | "line_items" => Enum.map(data, &LineItem.from_map/1)}
  end

  defp parse_branch(branch) when is_map(branch), do: branch
end
