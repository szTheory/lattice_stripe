defmodule LatticeStripe.Account.Requirements do
  @moduledoc """
  Represents the requirements nested object on a Stripe Account.

  This struct is reused at both `%LatticeStripe.Account{}.requirements` and
  `%LatticeStripe.Account{}.future_requirements`; both have an identical Stripe
  wire shape per the Stripe API documentation.

  The `requirements` field contains the currently-active requirements Stripe
  needs to keep the account enabled. The `future_requirements` field contains
  requirements that will become active in the future (e.g., after a regulatory
  deadline or when the account tries to enable a new capability).

  Unknown fields from the Stripe API response are preserved in `:extra` per the
  F-001 forward-compatibility pattern.

  See [Stripe Account API](https://docs.stripe.com/api/accounts/object#account_object-requirements).
  """

  @known_fields ~w[alternatives current_deadline currently_due disabled_reason
                   errors eventually_due past_due pending_verification]

  defstruct [
    :alternatives,
    :current_deadline,
    :currently_due,
    :disabled_reason,
    :errors,
    :eventually_due,
    :past_due,
    :pending_verification,
    extra: %{}
  ]

  @typedoc "Requirements for a Stripe Account (used at both `requirements` and `future_requirements`)."
  @type t :: %__MODULE__{
          alternatives: list() | nil,
          current_deadline: integer() | nil,
          currently_due: list() | nil,
          disabled_reason: String.t() | nil,
          errors: list() | nil,
          eventually_due: list() | nil,
          past_due: list() | nil,
          pending_verification: list() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Requirements{}` struct.

  Returns `nil` when given `nil`.

  This function is used to cast both the `requirements` and `future_requirements`
  fields on `%LatticeStripe.Account{}` — both fields have the same wire shape.

  Unknown fields from the Stripe API are captured in `:extra` (F-001 pattern)
  for forward compatibility.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
