defmodule LatticeStripe.Subscription.CancellationDetails do
  @moduledoc """
  Represents the `cancellation_details` nested object on a Stripe Subscription.

  Captures customer-provided context about why a subscription was canceled:

  - `reason` — the cancellation reason (e.g., `"cancellation_requested"`,
    `"payment_disputed"`, `"payment_failed"`)
  - `feedback` — standardized feedback code (e.g., `"too_expensive"`, `"switched_service"`)
  - `comment` — free-form customer comment (may contain PII)

  > #### PII safety {: .warning}
  >
  > The `comment` field may contain personal information. `Inspect` masks this
  > field as `"[FILTERED]"` by default. Access `struct.comment` directly to read
  > the raw value — and avoid logging it.

  See [Stripe Subscription API](https://docs.stripe.com/api/subscriptions/object#subscription_object-cancellation_details).
  """

  @known_fields ~w[reason feedback comment]

  defstruct [:reason, :feedback, :comment, extra: %{}]

  @typedoc "Cancellation details for a Stripe Subscription."
  @type t :: %__MODULE__{
          reason: String.t() | nil,
          feedback: String.t() | nil,
          comment: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%CancellationDetails{}` struct.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      reason: known["reason"],
      feedback: known["feedback"],
      comment: known["comment"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.Subscription.CancellationDetails do
  import Inspect.Algebra

  def inspect(details, opts) do
    # Mask comment field to avoid leaking customer PII into logs.
    comment_repr = if is_nil(details.comment), do: nil, else: "[FILTERED]"

    base = [
      reason: details.reason,
      feedback: details.feedback,
      comment: comment_repr
    ]

    fields = if details.extra == %{}, do: base, else: base ++ [extra: details.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Subscription.CancellationDetails<" | pairs] ++ [">"])
  end
end
