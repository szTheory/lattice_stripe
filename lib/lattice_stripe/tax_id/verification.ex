defmodule LatticeStripe.TaxId.Verification do
  @moduledoc """
  The `verification` object embedded in a Stripe Tax ID.

  Reachable from `t:LatticeStripe.TaxId.t/0`. `:status` is the field to match on before
  trusting a customer-supplied tax ID — see the Tax guide for the full status set and
  what each one means for invoicing.

  This struct holds PII. `:verified_name` and `:verified_address` are redacted in
  `Inspect` output to keep them out of logs and IEx sessions; read them explicitly by
  field when you need them.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[status verified_address verified_name]

  defstruct [:status, :verified_address, :verified_name, extra: %{}]

  @type t :: %__MODULE__{
          status: atom() | String.t() | nil,
          verified_address: String.t() | nil,
          verified_name: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      status: atomize_status(known["status"]),
      verified_address: known["verified_address"],
      verified_name: known["verified_name"],
      extra: extra
    }
  end

  defp atomize_status("pending"), do: :pending
  defp atomize_status("verified"), do: :verified
  defp atomize_status("unverified"), do: :unverified
  defp atomize_status("unavailable"), do: :unavailable
  defp atomize_status(nil), do: nil
  defp atomize_status(other), do: other
end

defimpl Inspect, for: LatticeStripe.TaxId.Verification do
  import Inspect.Algebra

  @redacted [:verified_address, :verified_name]

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

    concat(["#LatticeStripe.TaxId.Verification<" | pairs] ++ [">"])
  end
end
