defmodule LatticeStripe.Dispute.EvidenceDetails do
  @moduledoc """
  Represents evidence submission details nested on a Stripe Dispute.

  Unknown fields from the Stripe API response are preserved in `:extra` for
  forward compatibility.
  """

  @known_fields ~w[due_by has_evidence past_due submission_count enhanced_eligibility]

  @struct_fields Enum.map(@known_fields, &String.to_atom/1)

  # Equivalent to `defstruct @known_fields ++ [:extra]`, but atomized explicitly
  # for current Elixir versions where new struct fields must be atoms at compile time.
  defstruct @struct_fields ++ [extra: %{}]

  @type t :: %__MODULE__{
          due_by: integer() | nil,
          has_evidence: boolean() | nil,
          past_due: boolean() | nil,
          submission_count: integer() | nil,
          enhanced_eligibility: map() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
