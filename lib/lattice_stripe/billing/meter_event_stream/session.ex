defmodule LatticeStripe.Billing.MeterEventStream.Session do
  @moduledoc """
  Short-lived session struct returned by `MeterEventStream.create_session/2`.

  A `%MeterEventStream.Session{}` carries a session-scoped `authentication_token`
  that grants access to the high-volume v2 event stream endpoint. Sessions are
  valid for **15 minutes** from creation time (`expires_at`).

  ## Typical usage

  Callers hold this struct and pass it to `MeterEventStream.send_events/4`:

      {:ok, session} = MeterEventStream.create_session(client)
      {:ok, _result} = MeterEventStream.send_events(client, session, events)

  ## Security note — the `:authentication_token` field

  `authentication_token` is a bearer credential for the v2 meter event stream
  endpoint. LatticeStripe masks it in default `Inspect` output to prevent
  accidental leaks via `Logger`, APM agents, crash dumps, or telemetry handlers.

  Access the field directly when you need it:

      session.authentication_token

  To inspect all fields including the token during debugging:

      IO.inspect(session, structs: false)
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          authentication_token: String.t() | nil,
          created: integer() | nil,
          expires_at: integer() | nil,
          livemode: boolean() | nil
        }

  defstruct [:id, :object, :authentication_token, :created, :expires_at, :livemode]

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%Session{}`.

  Maps the v2 session response fields directly — the response shape is stable
  and does not require `@known_fields` / `:extra` handling.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      authentication_token: map["authentication_token"],
      created: map["created"],
      expires_at: map["expires_at"],
      livemode: map["livemode"]
    }
  end
end

defimpl Inspect, for: LatticeStripe.Billing.MeterEventStream.Session do
  import Inspect.Algebra

  def inspect(session, opts) do
    # Allowlist structural fields only. `:authentication_token` is hidden because
    # it is a bearer credential for the v2 meter event stream endpoint.
    # Leaks via Logger, APM, crash dumps, or telemetry handlers would allow
    # unauthorized event submissions for the duration of the 15-minute TTL.
    #
    # Debugging escape hatch — see every field including :authentication_token:
    #
    #     IO.inspect(session, structs: false)
    #     # or access directly:
    #     session.authentication_token
    #
    # Precedent: BillingPortal.Session (masks :url), MeterEvent (masks :payload),
    # Checkout.Session (masks :url) — all three allowlist structural fields
    # and hide the sensitive surface.
    fields = [
      id: session.id,
      object: session.object,
      created: session.created,
      expires_at: session.expires_at,
      livemode: session.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Billing.MeterEventStream.Session<" | pairs] ++ [">"])
  end
end
