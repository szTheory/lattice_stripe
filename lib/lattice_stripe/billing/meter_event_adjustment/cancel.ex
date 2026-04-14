defmodule LatticeStripe.Billing.MeterEventAdjustment.Cancel do
  @moduledoc """
  The `cancel` sub-object of a `LatticeStripe.Billing.MeterEventAdjustment`.

  Single field: `identifier` (a string matching a previously-reported
  `MeterEvent.identifier`). This struct exists to anchor the exact Stripe
  wire shape — the field is **`cancel.identifier`**, never top-level
  `identifier`, never `cancel.id`, never `cancel.event_id`. Developers
  passing the wrong shape hit a Stripe 400 at runtime; round-trip tests
  against this struct prevent regressions.
  """

  @type t :: %__MODULE__{identifier: String.t() | nil}
  defstruct [:identifier]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map),
    do: %__MODULE__{identifier: map["identifier"]}
end
