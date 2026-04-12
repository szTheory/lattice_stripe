defmodule LatticeStripe.Subscription.TrialSettings do
  @moduledoc """
  Represents the `trial_settings` nested object on a Stripe Subscription.

  Currently exposes `end_behavior` as a plain map. The leaf field inside
  (`missing_payment_method`) is intentionally not promoted to a typed field —
  Stripe may add more end-behavior controls in future and `end_behavior` is
  documented as an open map.

  Example:

      %LatticeStripe.Subscription.TrialSettings{
        end_behavior: %{"missing_payment_method" => "cancel"}
      }

  See [Stripe Subscription API](https://docs.stripe.com/api/subscriptions/object#subscription_object-trial_settings).
  """

  @known_fields ~w[end_behavior]

  defstruct [:end_behavior, extra: %{}]

  @typedoc "Trial settings for a Stripe Subscription."
  @type t :: %__MODULE__{
          end_behavior: map() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%TrialSettings{}` struct.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      end_behavior: known["end_behavior"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.Subscription.TrialSettings do
  import Inspect.Algebra

  def inspect(ts, opts) do
    base = [end_behavior: ts.end_behavior]
    fields = if ts.extra == %{}, do: base, else: base ++ [extra: ts.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Subscription.TrialSettings<" | pairs] ++ [">"])
  end
end
