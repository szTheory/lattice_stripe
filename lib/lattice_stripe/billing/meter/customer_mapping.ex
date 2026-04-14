defmodule LatticeStripe.Billing.Meter.CustomerMapping do
  @moduledoc """
  How a `LatticeStripe.Billing.MeterEvent` payload is mapped to a Stripe
  customer. Currently Stripe exposes `"by_id"` with `event_payload_key`
  naming the field inside `payload` that carries a `cus_*` customer ID.
  `:extra` captures any future mapping types Stripe adds.
  """

  @known_fields ~w(event_payload_key type)

  @type t :: %__MODULE__{
          event_payload_key: String.t() | nil,
          type: String.t() | nil,
          extra: map()
        }
  defstruct [:event_payload_key, :type, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      event_payload_key: map["event_payload_key"],
      type: map["type"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
