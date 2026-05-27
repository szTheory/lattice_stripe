defmodule LatticeStripe.EventNotification do
  @moduledoc """
  Represents a Stripe **thin-event** notification (`/v2/events`).

  Thin events are the lightweight, fixed-shape webhook payloads Stripe delivers from
  `/v2/event-destinations`. Unlike snapshot v1 events (delivered to `/v1/webhooks` and
  returned by `LatticeStripe.Event.retrieve/3`), a thin-event notification carries only
  the event metadata + a `related_object` reference — adopters fetch the full
  `LatticeStripe.Event.t()` (and optionally the underlying typed resource) on demand.

  ## When to use this vs `LatticeStripe.Event`

  - **`%EventNotification{}`** — what you receive from `Webhook.parse_event_notification/4`
    on the `/v2/events` thin-event webhook path. Pure serializable data, no embedded
    `%Client{}`. Safe to put in ETS, log lines, GenServer state, or distributed messages.
  - **`%LatticeStripe.Event{}`** — the full snapshot event, either delivered to v1
    webhook endpoints (use `Webhook.construct_event/4`) or fetched from
    `/v2/core/events/{id}` (use `Webhook.fetch_event/3`).

  Do **not** confuse the two. They are distinct types so adopter handler `case` blocks
  fail loudly rather than fall through to no-match clauses.

  ## Wire format

  The thin-event wire payload has `"object": "v2.core.event"` — the same string both
  on a notification (no `data`/`changes`) and on the fully-fetched event (with `data`).
  Stripe distinguishes them by presence of `data`, not by the `object` string.

  ## Field-by-field

  - `id` — Event ID (`"evt_..."`)
  - `object` — Always `"v2.core.event"` (per Stripe wire format)
  - `type` — Event type string (e.g., `"v2.core.account.updated"`)
  - `created` — **ISO 8601 string** like `"2026-03-09T13:00:28.435Z"`. This is a
    legitimate type asymmetry vs. `LatticeStripe.Event.t()` `created :: integer()`
    (Unix seconds on v1/snapshot events) — Stripe ships the wire value verbatim and
    LatticeStripe preserves it. Adopters who need a `DateTime` should call
    `DateTime.from_iso8601/1` themselves.
  - `context` — Free-form context string from Stripe (or `nil`)
  - `livemode` — `true` for live mode, `false` for test mode
  - `related_object` — `%LatticeStripe.EventNotification.RelatedObject{}` (or `nil`
    for snapshot-style v2 events)
  - `reason` — Map describing what triggered the event (contains `request.id` and
    `request.idempotency_key`; hidden in `Inspect` because of that)
  - `extra` — Unknown fields from Stripe not yet in this struct

  ## Inspect

  The `Inspect` implementation hides `:reason` (contains request id + idempotency key)
  and `:extra` to keep output concise and avoid leaking auth-adjacent metadata.

  ## Stripe API Reference

  See [Stripe Event Destinations](https://docs.stripe.com/event-destinations) and
  [Stripe v2 Events API](https://docs.stripe.com/api/v2/events) for the full payload
  schema.
  """

  alias LatticeStripe.EventNotification.RelatedObject

  # Known top-level fields from the Stripe thin-event wire format.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[id object type created context livemode related_object reason]

  defstruct [
    :id,
    :type,
    # NOTE: ISO 8601 string per wire, NOT Unix integer (research Finding 2).
    # See Event.created which is integer() for snapshot/v1 events.
    :created,
    :context,
    :livemode,
    :related_object,
    :reason,
    object: "v2.core.event",
    extra: %{}
  ]

  @typedoc """
  A Stripe thin-event notification.

  Returned by `LatticeStripe.Webhook.parse_event_notification/4`. Safely serializable —
  contains no `%Client{}` or other credential material.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          type: String.t() | nil,
          # NOTE: ISO 8601 string per wire, NOT Unix integer (research Finding 2).
          # See Event.created which is integer() for snapshot/v1 events.
          created: String.t() | nil,
          context: String.t() | nil,
          livemode: boolean() | nil,
          related_object: RelatedObject.t() | nil,
          reason: map() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%EventNotification{}` struct.

  Maps all known thin-event wire fields. Any unrecognized fields are collected into
  the `extra` map so no data is silently lost. Always succeeds (infallible).

  Decodes the nested `related_object` map into a
  `%LatticeStripe.EventNotification.RelatedObject{}` struct via
  `RelatedObject.from_map/1`. When the wire payload sets `"related_object"` to `nil`
  (snapshot-style v2 events) or omits it, the field is `nil`.

  Defaults `object` to `"v2.core.event"` when the key is missing — this matches the
  Stripe wire format for v2 events.

  ## Example

      LatticeStripe.EventNotification.from_map(%{
        "id" => "evt_test_123",
        "object" => "v2.core.event",
        "type" => "v2.core.account.updated",
        "created" => "2026-03-09T13:00:28.435Z",
        "livemode" => false,
        "related_object" => %{
          "id" => "acct_1T93Q4Pmpb34Vto6",
          "type" => "v2.core.account",
          "url" => "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
        }
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "v2.core.event",
      type: map["type"],
      created: map["created"],
      context: map["context"],
      livemode: map["livemode"],
      related_object: RelatedObject.from_map(map["related_object"]),
      reason: map["reason"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.EventNotification do
  import Inspect.Algebra

  def inspect(notif, opts) do
    # Show only structural / safe fields. Hide :reason (contains request id +
    # idempotency key) and :extra (may be large/noisy) — same "hide noisy or
    # auth-adjacent fields" rule that LatticeStripe.Event follows for :data.
    fields = [
      id: notif.id,
      type: notif.type,
      object: notif.object,
      created: notif.created,
      livemode: notif.livemode,
      related_object: notif.related_object
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.EventNotification<" | pairs] ++ [">"])
  end
end
