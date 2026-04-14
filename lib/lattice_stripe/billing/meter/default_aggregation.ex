defmodule LatticeStripe.Billing.Meter.DefaultAggregation do
  @moduledoc """
  Aggregation formula for a `LatticeStripe.Billing.Meter`.

  One of three Stripe-documented formulas:
  - `"sum"` — sum of `value_settings.event_payload_key` across events
  - `"count"` — number of events (value_settings ignored)
  - `"last"` — most recent `value_settings.event_payload_key` in window
  """

  @type formula :: String.t()
  @type t :: %__MODULE__{formula: formula() | nil}
  defstruct [:formula]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil
  def from_map(map) when is_map(map), do: %__MODULE__{formula: map["formula"]}
end
