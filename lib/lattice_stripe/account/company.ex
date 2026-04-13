defmodule LatticeStripe.Account.Company do
  @moduledoc """
  Represents the `company` nested object on a Stripe Account.

  Active when `business_type` is `"company"` on the parent `%Account{}`.
  Mutually exclusive with the `individual` field.

  This struct holds PII. The following fields are redacted in `Inspect` output
  to prevent leakage into logs and IEx output (Phase 17 T-17-01):

  - `tax_id` — federal tax identifier
  - `vat_id` — VAT registration number
  - `phone` — company phone number
  - `address` — registered address
  - `address_kana` — address in Kana script (Japan)
  - `address_kanji` — address in Kanji script (Japan)

  Unknown fields from the Stripe API response are preserved in `:extra` per the
  F-001 forward-compatibility pattern.

  See [Stripe Account API](https://docs.stripe.com/api/accounts/object#account_object-company).
  """

  @known_fields ~w[address address_kana address_kanji directors_provided executives_provided
                   name name_kana name_kanji owners_provided phone structure tax_id
                   tax_id_registrar vat_id verification]

  defstruct [
    :address,
    :address_kana,
    :address_kanji,
    :directors_provided,
    :executives_provided,
    :name,
    :name_kana,
    :name_kanji,
    :owners_provided,
    :phone,
    :structure,
    :tax_id,
    :tax_id_registrar,
    :vat_id,
    :verification,
    extra: %{}
  ]

  @typedoc "Company details for a Stripe Account. Contains PII (see module doc)."
  @type t :: %__MODULE__{
          address: map() | nil,
          address_kana: map() | nil,
          address_kanji: map() | nil,
          directors_provided: boolean() | nil,
          executives_provided: boolean() | nil,
          name: String.t() | nil,
          name_kana: String.t() | nil,
          name_kanji: String.t() | nil,
          owners_provided: boolean() | nil,
          phone: String.t() | nil,
          structure: String.t() | nil,
          tax_id: String.t() | nil,
          tax_id_registrar: String.t() | nil,
          vat_id: String.t() | nil,
          verification: map() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Company{}` struct.

  Returns `nil` when given `nil`.

  **Security:** Several fields contain PII — see module doc for the full list.
  The `Inspect` implementation redacts those fields (T-17-01 mitigation).

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

defimpl Inspect, for: LatticeStripe.Account.Company do
  import Inspect.Algebra

  # PII fields — redacted when non-nil to prevent leakage into logs (T-17-01).
  @redacted [:tax_id, :vat_id, :phone, :address, :address_kana, :address_kanji]

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

    concat(["#LatticeStripe.Account.Company<" | pairs] ++ [">"])
  end
end
