defmodule LatticeStripe.Account.TosAcceptance do
  @moduledoc """
  Represents the `tos_acceptance` nested object on a Stripe Account.

  This struct holds PII (`ip`, `user_agent`). Its `Inspect` implementation
  redacts those fields to prevent leakage into logs and IEx output (Phase 17 T-17-01).

  Unknown fields from the Stripe API response are preserved in `:extra` per the
  F-001 forward-compatibility pattern.

  See [Stripe Account API](https://docs.stripe.com/api/accounts/object#account_object-tos_acceptance).
  """

  @known_fields ~w[date ip service_agreement user_agent]

  defstruct [
    :date,
    :ip,
    :service_agreement,
    :user_agent,
    extra: %{}
  ]

  @typedoc "TOS acceptance settings for a Stripe Account. Contains PII (`ip`, `user_agent`)."
  @type t :: %__MODULE__{
          date: integer() | nil,
          ip: String.t() | nil,
          service_agreement: String.t() | nil,
          user_agent: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%TosAcceptance{}` struct.

  Returns `nil` when given `nil`.

  **Security:** The `ip` and `user_agent` fields contain PII. Use `inspect/1` safely —
  this struct's `Inspect` implementation redacts those fields (T-17-01 mitigation).

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

defimpl Inspect, for: LatticeStripe.Account.TosAcceptance do
  import Inspect.Algebra

  # PII fields — redacted when non-nil to prevent leakage into logs (T-17-01).
  @redacted [:ip, :user_agent]

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

    concat(["#LatticeStripe.Account.TosAcceptance<" | pairs] ++ [">"])
  end
end
