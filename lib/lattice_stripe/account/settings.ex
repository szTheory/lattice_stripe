defmodule LatticeStripe.Account.Settings do
  @moduledoc """
  Represents the `settings` nested object on a Stripe Account.

  Unlike other nested struct modules, `Account.Settings` is intentionally outer-only.
  The `branding`, `card_payments`, `dashboard`, `payments`, `payouts`, etc. sub-objects
  remain as plain maps rather than typed structs. This is a deliberate depth cap per
  Phase 17 D-01 — promoting them would blow the 5-module budget and yield little ergonomic
  value because `:extra` already handles forward-compat for key access patterns. To access
  a settings field, use map access: `account.settings.payouts["schedule"]["interval"]`.

  Unknown top-level keys from the Stripe API response are captured in `:extra` per the
  F-001 forward-compatibility pattern.

  See [Stripe Account API](https://docs.stripe.com/api/accounts/object#account_object-settings).
  """

  @known_fields ~w[branding card_issuing card_payments dashboard invoices payments
                   payouts sepa_debit treasury]

  defstruct [
    :branding,
    :card_issuing,
    :card_payments,
    :dashboard,
    :invoices,
    :payments,
    :payouts,
    :sepa_debit,
    :treasury,
    extra: %{}
  ]

  @typedoc """
  Account settings. All sub-objects remain as plain maps per the D-01 depth cap
  (see module doc for rationale).
  """
  @type t :: %__MODULE__{
          branding: map() | nil,
          card_issuing: map() | nil,
          card_payments: map() | nil,
          dashboard: map() | nil,
          invoices: map() | nil,
          payments: map() | nil,
          payouts: map() | nil,
          sepa_debit: map() | nil,
          treasury: map() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Settings{}` struct.

  Returns `nil` when given `nil`.

  Sub-objects like `branding`, `card_payments`, `dashboard`, `payments`, and
  `payouts` are kept as plain maps (outer-only depth cap, Phase 17 D-01).
  Unknown top-level keys land in `:extra` (F-001 pattern).
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
