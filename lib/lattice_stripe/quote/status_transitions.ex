defmodule LatticeStripe.Quote.StatusTransitions do
  @moduledoc """
  Tracks lifecycle Unix timestamps for a Stripe Quote.
  """

  defstruct [:accepted_at, :canceled_at, :finalized_at]

  @type t :: %__MODULE__{
          accepted_at: integer() | nil,
          canceled_at: integer() | nil,
          finalized_at: integer() | nil
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      accepted_at: map["accepted_at"],
      canceled_at: map["canceled_at"],
      finalized_at: map["finalized_at"]
    }
  end
end
