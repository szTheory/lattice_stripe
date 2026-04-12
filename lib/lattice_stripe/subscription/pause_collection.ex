defmodule LatticeStripe.Subscription.PauseCollection do
  @moduledoc """
  Represents the `pause_collection` nested object on a Stripe Subscription.

  When set, Stripe pauses automatic invoice collection for the subscription
  with the given `behavior`:

  - `"keep_as_draft"` — invoices are created but left as drafts
  - `"mark_uncollectible"` — invoices are created and marked uncollectible
  - `"void"` — invoices are created and immediately voided

  Optionally, `resumes_at` is a Unix timestamp at which collection will
  automatically resume.

  See [Stripe Subscription API](https://docs.stripe.com/api/subscriptions/object#subscription_object-pause_collection).
  """

  @known_fields ~w[behavior resumes_at]

  defstruct [:behavior, :resumes_at, extra: %{}]

  @typedoc "Pause collection settings for a Stripe Subscription."
  @type t :: %__MODULE__{
          behavior: String.t() | nil,
          resumes_at: integer() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%PauseCollection{}` struct.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      behavior: known["behavior"],
      resumes_at: known["resumes_at"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.Subscription.PauseCollection do
  import Inspect.Algebra

  def inspect(pc, opts) do
    base = [behavior: pc.behavior, resumes_at: pc.resumes_at]
    fields = if pc.extra == %{}, do: base, else: base ++ [extra: pc.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Subscription.PauseCollection<" | pairs] ++ [">"])
  end
end
