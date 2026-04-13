defmodule LatticeStripe.BalanceTransaction.FeeDetail do
  @moduledoc """
  A single fee line on a Stripe `BalanceTransaction`.

  Reconciliation code typically filters by `type` to extract platform fees:

      application_fees =
        Enum.filter(bt.fee_details, &(&1.type == "application_fee"))

  Stripe's known `type` enum values include `"application_fee"`,
  `"stripe_fee"`, `"payment_method_passthrough_fee"`, `"tax"`, and
  `"withheld_tax"`. The field stays typed as `String.t()` to remain
  forward-compatible with new fee categories.
  """

  @known_fields ~w(amount application currency description type)a

  defstruct @known_fields ++ [extra: %{}]

  @typedoc "A fee line on a Stripe BalanceTransaction."
  @type t :: %__MODULE__{
          amount: integer() | nil,
          application: String.t() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          type: String.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      amount: known["amount"],
      application: known["application"],
      currency: known["currency"],
      description: known["description"],
      type: known["type"],
      extra: extra
    )
  end
end
