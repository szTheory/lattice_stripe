defmodule LatticeStripe.Account.Individual do
  @moduledoc """
  Represents the `individual` nested object on a Stripe Account.

  Active when `business_type` is `"individual"` on the parent `%Account{}`.
  Mutually exclusive with the `company` field.

  This struct holds significant PII. The following fields are redacted in `Inspect`
  output to prevent leakage into logs and IEx output (Phase 17 T-17-01). The PII
  field set is sourced from the
  [stripe-node PII audit](https://github.com/stripe/stripe-node) for fidelity:

  - `dob` — date of birth (map with day/month/year)
  - `ssn_last_4` — last 4 digits of US SSN
  - `id_number` — government-issued ID number
  - `first_name`, `first_name_kana`, `first_name_kanji` — given names
  - `last_name`, `last_name_kana`, `last_name_kanji` — family names
  - `maiden_name` — previous legal name
  - `full_name_aliases` — list of aliases
  - `address`, `address_kana`, `address_kanji` — residential address
  - `phone` — personal phone number
  - `email` — personal email address
  - `metadata` — user-supplied key/value pairs (may contain PII)

  Unknown fields from the Stripe API response are preserved in `:extra` per the
  F-001 forward-compatibility pattern.

  See [Stripe Account API](https://docs.stripe.com/api/accounts/object#account_object-individual).
  """

  @known_fields ~w[address address_kana address_kanji dob email first_name first_name_kana
                   first_name_kanji full_name_aliases gender id_number last_name last_name_kana
                   last_name_kanji maiden_name metadata phone political_exposure ssn_last_4
                   verification]

  defstruct [
    :address,
    :address_kana,
    :address_kanji,
    :dob,
    :email,
    :first_name,
    :first_name_kana,
    :first_name_kanji,
    :full_name_aliases,
    :gender,
    :id_number,
    :last_name,
    :last_name_kana,
    :last_name_kanji,
    :maiden_name,
    :metadata,
    :phone,
    :political_exposure,
    :ssn_last_4,
    :verification,
    extra: %{}
  ]

  @typedoc "Individual details for a Stripe Account. Contains significant PII (see module doc)."
  @type t :: %__MODULE__{
          address: map() | nil,
          address_kana: map() | nil,
          address_kanji: map() | nil,
          dob: map() | nil,
          email: String.t() | nil,
          first_name: String.t() | nil,
          first_name_kana: String.t() | nil,
          first_name_kanji: String.t() | nil,
          full_name_aliases: list() | nil,
          gender: String.t() | nil,
          id_number: String.t() | nil,
          last_name: String.t() | nil,
          last_name_kana: String.t() | nil,
          last_name_kanji: String.t() | nil,
          maiden_name: String.t() | nil,
          metadata: map() | nil,
          phone: String.t() | nil,
          political_exposure: String.t() | nil,
          ssn_last_4: String.t() | nil,
          verification: map() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Individual{}` struct.

  Returns `nil` when given `nil`.

  **Security:** This struct contains significant PII — see module doc for the full list.
  The `Inspect` implementation redacts all PII fields (T-17-01 mitigation).

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

defimpl Inspect, for: LatticeStripe.Account.Individual do
  import Inspect.Algebra

  # PII fields — redacted when non-nil to prevent leakage into logs (T-17-01).
  # Source: stripe-node PII audit for field-level fidelity.
  @redacted [
    :dob,
    :ssn_last_4,
    :id_number,
    :first_name,
    :first_name_kana,
    :first_name_kanji,
    :last_name,
    :last_name_kana,
    :last_name_kanji,
    :maiden_name,
    :full_name_aliases,
    :address,
    :address_kana,
    :address_kanji,
    :phone,
    :email,
    :metadata
  ]

  def inspect(struct, opts) do
    redacted =
      Enum.reduce(@redacted, struct, fn field, acc ->
        case Map.get(acc, field) do
          nil -> acc
          _ -> Map.put(acc, field, "[REDACTED]")
        end
      end)

    pairs =
      Map.from_struct(redacted)
      |> Enum.reject(fn {k, v} -> k == :extra and v == %{} end)
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Account.Individual<" | pairs] ++ [">"])
  end
end
