defmodule LatticeStripe.Billing.Meter.ValueSettings do
  @moduledoc """
  Value-extraction settings for sum/last meters. `event_payload_key` names
  the field inside `MeterEvent.payload` from which Stripe reads the numeric
  value. Defaults server-side to `"value"` when omitted in `Meter.create/3`.
  """

  @type t :: %__MODULE__{event_payload_key: String.t() | nil}
  defstruct [:event_payload_key]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map),
    do: %__MODULE__{event_payload_key: map["event_payload_key"]}
end
