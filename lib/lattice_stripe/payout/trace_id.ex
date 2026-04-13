defmodule LatticeStripe.Payout.TraceId do
  @moduledoc """
  Trace identifier for a Stripe Payout.

  Surfaces the rail-specific trace ID that lets you reconcile a payout against
  the recipient bank's settlement record. The `status` field is a clear
  pattern-match target — your reconciliation code typically branches on whether
  Stripe has obtained the trace ID yet.

      case payout.trace_id do
        %LatticeStripe.Payout.TraceId{status: "supported", value: trace} ->
          reconcile(trace)

        %LatticeStripe.Payout.TraceId{status: "pending"} ->
          :wait_for_webhook

        %LatticeStripe.Payout.TraceId{status: status} ->
          {:unsupported, status}
      end

  Unknown future fields from Stripe land in `:extra` per the F-001
  forward-compatibility rule — upgrading the SDK will never silently drop data.

  ## Stripe API Reference

  See the [Stripe Payout object — `trace_id`](https://docs.stripe.com/api/payouts/object#payout_object-trace_id)
  for the full field reference.
  """

  @known_fields ~w(status value)a

  defstruct @known_fields ++ [extra: %{}]

  @typedoc """
  A Stripe Payout trace ID.

  The `status` enum Stripe currently emits is one of
  `"supported" | "pending" | "unsupported" | "not_applicable"`, but it is typed
  as `String.t()` so user pattern matches stay forward-compatible when Stripe
  adds new values.
  """
  @type t :: %__MODULE__{
          status: String.t() | nil,
          value: String.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      status: known["status"],
      value: known["value"],
      extra: extra
    )
  end
end
