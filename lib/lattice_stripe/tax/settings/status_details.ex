defmodule LatticeStripe.Tax.Settings.StatusDetails do
  @moduledoc """
  The `status_details` object embedded in your account's Stripe Tax settings.

  Reachable from `t:LatticeStripe.Tax.Settings.t/0`. Exactly one of `:active` or
  `:pending` is populated, matching the parent's `:status` — the populated one carries
  the detail explaining why Tax is or is not yet operational.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[active pending]

  defstruct [
    :active,
    :pending,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          active: map() | nil,
          pending: map() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      active: known["active"],
      pending: known["pending"],
      extra: extra
    }
  end
end
