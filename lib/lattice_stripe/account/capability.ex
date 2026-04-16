defmodule LatticeStripe.Account.Capability do
  @moduledoc """
  A single capability entry from `Account.capabilities`.

  The outer `capabilities` map on `%Account{}` is keyed by Stripe's
  open-ended capability name strings (e.g. `"card_payments"`,
  `"transfers"`, `"us_bank_account_payments"`). Each value is a
  `%Capability{}`. The inner shape is stable; new capability *names*
  added by Stripe flow through automatically as new map keys.

      iex> account.capabilities["card_payments"]
      %LatticeStripe.Account.Capability{status: "active", requested: true, ...}

      iex> LatticeStripe.Account.Capability.status_atom(
      ...>   account.capabilities["card_payments"]
      ...> )
      :active
  """

  @known_fields ~w(status requested requested_at requirements disabled_reason)a

  defstruct @known_fields ++ [extra: %{}]

  @type t :: %__MODULE__{
          status: atom() | String.t() | nil,
          requested: boolean() | nil,
          requested_at: integer() | nil,
          requirements: map() | nil,
          disabled_reason: String.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      status: atomize_status(known["status"]),
      requested: known["requested"],
      requested_at: known["requested_at"],
      requirements: known["requirements"],
      disabled_reason: known["disabled_reason"],
      extra: extra
    )
  end

  # ---------------------------------------------------------------------------
  # Private: atomization helpers
  # ---------------------------------------------------------------------------

  defp atomize_status("active"),      do: :active
  defp atomize_status("inactive"),    do: :inactive
  defp atomize_status("pending"),     do: :pending
  defp atomize_status("unrequested"), do: :unrequested
  defp atomize_status("disabled"),    do: :disabled
  defp atomize_status(other),         do: other

  @deprecated "Status is now automatically atomized in cast/1. Access capability.status directly."
  @spec status_atom(t() | String.t() | nil) :: atom()
  def status_atom(%__MODULE__{status: s}), do: s
  def status_atom(nil), do: nil
  def status_atom(s) when is_atom(s), do: s
  def status_atom(s), do: atomize_status(s)
end
