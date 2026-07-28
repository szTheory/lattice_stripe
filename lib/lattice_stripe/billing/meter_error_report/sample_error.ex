defmodule LatticeStripe.Billing.MeterErrorReport.SampleError do
  @moduledoc """
  One sampled failure from an async meter-event error report — an error message
  and, crucially, the identifier of the request that produced it.

  ## `request_identifier` is the join key

  `request_identifier` is the **HTTP idempotency key of the
  `LatticeStripe.Billing.MeterEvent.create/3` call that failed**. Async meter
  event ingestion returns `202` and validates later, so the failure surfaces
  minutes afterwards on an event that names no meter event and carries no
  usage payload. The idempotency key is therefore the only thread back from
  "Stripe rejected something" to "*this* row in your database" — it is the
  single reason this module is worth typing.

      for %SampleError{request_identifier: key, error_message: msg} <- samples do
        MyApp.Billing.MeterEvents.mark_failed_by_idempotency_key(key, msg)
      end

  ## The trap: by default this key maps to nothing you own

  `LatticeStripe.Client` **auto-generates** an `idk_ltc_`-prefixed UUID v4 for
  every POST when no `:idempotency_key` is supplied in `opts`. That key is
  created inside the request, used once, and never returned to you — so if you
  let it default, `request_identifier` comes back pointing at a value that
  exists nowhere in your system, and the join above resolves to nothing.

  **Pass a domain-derived `:idempotency_key` on every meter event write**, one
  you can look up later:

      LatticeStripe.Billing.MeterEvent.create(client, params,
        idempotency_key: "meter_event:" <> usage_row.id
      )

  ## Not to be confused with the event's own idempotency key

  The same event carries **two** near-identically named idempotency keys, five
  nesting levels apart, and they mean different things:

  - `data.reason.error_types[].sample_errors[].request.identifier` — **this
    field**. The key of the *failing meter event write*.
  - `reason.request.idempotency_key` on the event itself (see
    `LatticeStripe.EventNotification`) — the key of the request that *caused
    the event to fire*. Not a meter event, and not a join key for your usage
    rows.

  This field is deliberately named `request_identifier` rather than
  `idempotency_key` so the two can never read as the same thing.

  ## Wire shape

  Stripe nests the identifier one level deeper than the field it decodes into:

      %{"error_message" => "...", "request" => %{"identifier" => "..."}}

  The `request` object has exactly one member, so it gets no module of its own —
  `from_map/1` reaches through it. The alternate spelling `idempotency_key`
  under `request` is also accepted, with the documented `identifier` preferred
  when both are present.
  """

  @type t :: %__MODULE__{
          error_message: String.t() | nil,
          request_identifier: String.t() | nil
        }

  defstruct [:error_message, :request_identifier]

  @doc """
  Decode one wire `sample_errors[]` entry.

  `from_map(nil)` returns `nil`. A missing or `nil` `request` object leaves
  `request_identifier` nil rather than raising.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      error_message: map["error_message"],
      request_identifier: request_identifier(map["request"])
    }
  end

  # `request` is nullable on the wire and absent entirely on some shapes, so
  # every non-map falls through to nil rather than raising inside a decoder.
  defp request_identifier(request) when is_map(request),
    do: request["identifier"] || request["idempotency_key"]

  defp request_identifier(_request), do: nil
end
