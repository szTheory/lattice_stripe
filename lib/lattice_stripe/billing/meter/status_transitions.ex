defmodule LatticeStripe.Billing.Meter.StatusTransitions do
  @moduledoc """
  Lifecycle timestamps for `LatticeStripe.Billing.Meter`. Currently only
  `deactivated_at` (Unix epoch seconds, nil when the meter is active).
  `:extra` captures any future transitions Stripe adds.
  """

  @known_fields ~w(deactivated_at)

  @type t :: %__MODULE__{deactivated_at: integer() | nil, extra: map()}
  defstruct [:deactivated_at, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      deactivated_at: map["deactivated_at"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
