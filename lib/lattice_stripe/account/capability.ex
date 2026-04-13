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
          status: String.t() | nil,
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
      status: known["status"],
      requested: known["requested"],
      requested_at: known["requested_at"],
      requirements: known["requirements"],
      disabled_reason: known["disabled_reason"],
      extra: extra
    )
  end

  @known_statuses ~w(active inactive pending unrequested disabled)

  # Ensure atoms pre-exist in the atom table so String.to_existing_atom/1 is safe.
  # These literals compile the atoms into the BEAM module at load time, meaning
  # @known_statuses (string list) can safely call String.to_existing_atom/1 for any
  # of these five values — the atoms already exist before that call is reached.
  @known_status_atoms [:active, :inactive, :pending, :unrequested, :disabled]
  @doc false
  def known_status_atoms, do: @known_status_atoms

  @doc """
  Returns `status` as an atom from a known set, or `:unknown` for
  forward compatibility. Never calls `String.to_atom/1` on user input.
  """
  @spec status_atom(t() | String.t() | nil) :: atom()
  # CONTEXT D-02 code example shorthand corrected: %__MODULE__{s} → %__MODULE__{status: s}
  def status_atom(%__MODULE__{status: s}), do: status_atom(s)
  def status_atom(nil), do: nil
  def status_atom(s) when s in @known_statuses, do: String.to_existing_atom(s)
  def status_atom(_), do: :unknown
end
