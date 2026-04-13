defmodule LatticeStripe.BankAccount do
  @moduledoc """
  A Stripe bank account attached to a Connect connected account (external account).

  Bank accounts are one of the two sum-type members returned by
  `LatticeStripe.ExternalAccount` CRUDL operations; the other is
  `LatticeStripe.Card`. All network operations live on
  `LatticeStripe.ExternalAccount` — this module owns only the struct shape,
  the map-to-struct `cast/1` / `from_map/1` helpers, and a PII-safe
  `Inspect` implementation.

  ## PII and Inspect

  `inspect/1` shows only `id`, `object`, `bank_name`, `country`, `currency`,
  and `status`. The following fields are deliberately hidden because they are
  sensitive banking information that must never appear in logs or error
  reports: `routing_number`, `fingerprint`, `last4`, `account_holder_name`,
  `account_holder_type`.

  The struct intentionally does NOT define an `:account_number` field —
  Stripe strips the raw number after tokenization, and if a future API
  version ever returned it, it would flow into `:extra` (never into
  `Inspect` output). Never add `:account_number` to `defstruct`.

  ## F-001 forward-compat

  Unknown keys from Stripe are preserved in the `:extra` map so new fields
  added by Stripe flow through without code changes. The `"deleted" => true`
  flag from a `DELETE` response is preserved in `:extra`.

  ## Stripe API Reference

  - https://docs.stripe.com/api/external_account_bank_accounts
  """

  # Known top-level fields. String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object account account_holder_name account_holder_type account_type
    available_payout_methods bank_name country currency customer
    default_for_currency fingerprint last4 metadata routing_number status
  ]

  defstruct [
    :id,
    :account,
    :account_holder_name,
    :account_holder_type,
    :account_type,
    :available_payout_methods,
    :bank_name,
    :country,
    :currency,
    :customer,
    :default_for_currency,
    :fingerprint,
    :last4,
    :metadata,
    :routing_number,
    :status,
    object: "bank_account",
    extra: %{}
  ]

  @typedoc "A Stripe bank account on a Connect connected account."
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          account: String.t() | nil,
          account_holder_name: String.t() | nil,
          account_holder_type: String.t() | nil,
          account_type: String.t() | nil,
          available_payout_methods: [String.t()] | nil,
          bank_name: String.t() | nil,
          country: String.t() | nil,
          currency: String.t() | nil,
          customer: String.t() | nil,
          default_for_currency: boolean() | nil,
          fingerprint: String.t() | nil,
          last4: String.t() | nil,
          metadata: map() | nil,
          routing_number: String.t() | nil,
          status: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%BankAccount{}` struct.

  Maps all known Stripe bank account fields. Any unrecognized fields are
  collected into `:extra` so no data is silently lost (F-001).
  """
  @spec cast(map() | nil) :: t() | nil
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "bank_account",
      account: map["account"],
      account_holder_name: map["account_holder_name"],
      account_holder_type: map["account_holder_type"],
      account_type: map["account_type"],
      available_payout_methods: map["available_payout_methods"],
      bank_name: map["bank_name"],
      country: map["country"],
      currency: map["currency"],
      customer: map["customer"],
      default_for_currency: map["default_for_currency"],
      fingerprint: map["fingerprint"],
      last4: map["last4"],
      metadata: map["metadata"],
      routing_number: map["routing_number"],
      status: map["status"],
      extra: Map.drop(map, @known_fields)
    }
  end

  @doc "Alias for `cast/1`. Provided for callers that prefer the `from_map` naming."
  @spec from_map(map() | nil) :: t() | nil
  def from_map(map), do: cast(map)
end

defimpl Inspect, for: LatticeStripe.BankAccount do
  import Inspect.Algebra

  def inspect(ba, opts) do
    fields = [
      id: ba.id,
      object: ba.object,
      bank_name: ba.bank_name,
      country: ba.country,
      currency: ba.currency,
      status: ba.status
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.BankAccount<" | pairs] ++ [">"])
  end
end
