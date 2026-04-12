defmodule LatticeStripe.SubscriptionSchedule.CurrentPhase do
  @moduledoc """
  The current phase of a Subscription Schedule, or `nil` if the schedule has
  not yet started or has completed.

  Contains two Unix timestamps bounding the currently-active phase. This is a
  small read-only summary view — for the full phase configuration, look up the
  matching element of `schedule.phases` by date range.
  """

  @known_fields ~w[start_date end_date]

  defstruct [:start_date, :end_date, extra: %{}]

  @typedoc "The current phase summary on a Stripe Subscription Schedule."
  @type t :: %__MODULE__{
          start_date: integer() | nil,
          end_date: integer() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%CurrentPhase{}` struct.

  Returns `nil` when given `nil` (schedule has no current phase).
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      start_date: known["start_date"],
      end_date: known["end_date"],
      extra: extra
    }
  end
end
