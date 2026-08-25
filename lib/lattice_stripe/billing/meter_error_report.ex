defmodule LatticeStripe.Billing.MeterErrorReport do
  @moduledoc """
  The typed `data` payload of a `v1.billing.meter.error_report_triggered` event:
  which meter rejected usage, over which window, with which error codes, and —
  most importantly — the idempotency key of every failing write.

  Async meter event ingestion answers `202` and validates later. When validation
  fails, Stripe reports it here, minutes after the fact, on an event that names
  no meter event and carries no usage payload. This module is the diagnose half
  of the metering surface: it turns that report into something you can join
  against your own records.

  ## You must fetch the event first — the webhook body does not contain `data`

  This is the single thing adopters get wrong. `v1.billing.meter.*` events are
  **v2 thin events**. The body Stripe POSTs to your endpoint carries only
  `id`, `type`, `created`, `related_object` and a `reason` — it has **no `data`
  member at all**. `data` is a *fetched attribute*: you must re-request the
  versioned event over your authenticated channel to obtain it.

  That re-fetch is also what makes the payload trustworthy. The delivered body
  is attacker-reachable; the fetched event is not. `from_event/1` therefore
  accepts only a `%LatticeStripe.Event{}` — which is precisely what
  `LatticeStripe.Webhook.fetch_event/3` returns — and never a raw request body.

  All seven official Stripe SDKs encode this structurally, by giving their
  event-notification classes no `data` member whatsoever. Treat a notification
  as an announcement, not as a payload.

      alias LatticeStripe.{EventNotification, Webhook}
      alias LatticeStripe.Billing.MeterErrorReport
      alias LatticeStripe.Billing.MeterErrorReport.{ErrorType, SampleError}

      def handle_notification(
            %EventNotification{type: "v1.billing.meter.error_report_triggered"} = notif,
            client
          ) do
        # `data` is a fetched attribute — the webhook body does not contain it.
        {:ok, event} = Webhook.fetch_event(client, notif)
        report = MeterErrorReport.from_event(event)

        for %ErrorType{code: code, sample_errors: samples} <- report.reason.error_types,
            %SampleError{request_identifier: key, error_message: msg} <- samples do
          MyApp.Billing.MeterEvents.mark_failed_by_idempotency_key(key, code, msg)
        end
      end

  ## The webhook object registry cannot reach this payload

  LatticeStripe's internal webhook object registry deserializes a payload by
  matching a map that carries an `"object"` key. This payload has none — it is
  event data, not an object — so it falls straight through the registry's
  dispatch and comes back as a raw map. There is no registry entry
  for it and there cannot be one: a registry row would be a dead key that a
  later contributor would assume works. Call `from_event/1` (or `from_map/1`)
  explicitly. This is a structural fact about the wire format, not a gap.

  ## Why this module is flat while its parts nest

  `MeterErrorReport` sits at depth 2 and its `Reason`, `ErrorType` and
  `SampleError` sit at depth 3. That is one rule applied twice.

  Depth 2 is for things addressed directly. `LatticeStripe.Billing.MeterEventSummary`
  is flat because it **is a resource**. This module is flat because it is **not a
  resource at all** — no endpoint, no `id`, no `object` string, nothing to
  address. Both are top-level concepts a caller reaches for by name.

  Depth 3 is for value objects that own no request and are only ever reached
  through their parent. The three sub-modules issue no HTTP call and construct
  no request; they exist to give every level of the payload a name instead of
  leaving nested raw maps behind.

  ## The window: `validation_start` and `validation_end`

  These delimit the window of usage the report covers — the only thing that
  tells an operator *which* usage was rejected. They pair directly with the
  window a reconciler reads through
  `LatticeStripe.Billing.MeterEventSummary.list/4`: a report covering
  `[validation_start, validation_end)` explains a hole in the summaries over the
  same span.

  > #### NOTE: these are ISO 8601 strings, not Unix integers {: .info}
  >
  > `validation_start` and `validation_end` arrive as RFC3339 strings like
  > `"2024-09-26T17:46:10.000Z"`. This is a legitimate type asymmetry against
  > every v1 object in this library, whose timestamps are Unix seconds
  > (`LatticeStripe.Billing.MeterEventSummary`'s `start_time` and `end_time`
  > among them). Stripe ships the v2 wire value verbatim and LatticeStripe
  > preserves it, matching the `LatticeStripe.EventNotification` `created`
  > precedent. Adopters who need a `DateTime` should call
  > `DateTime.from_iso8601/1` themselves.
  >
  > One official Stripe SDK types v2 timestamps as integers. That is wrong for
  > this payload, and it is deliberately not copied here.

  ## This struct will put idempotency keys in your logs

  There is **no** custom `Inspect` implementation here, deliberately. A bare
  `inspect(report)` — or a `Logger.error("…: \#{inspect(report)}")` — will emit
  every `request_identifier` the report carries, and those are idempotency keys.

  `LatticeStripe.EventNotification` hides its `:reason` field for exactly this
  reason, and that precedent deliberately does **not** transfer: there, the key
  is incidental metadata; here, the key **is** the diagnostic payload, and
  hiding it would defeat this module's entire purpose. You are told so you can
  decide what reaches your logs.

  ## Design: no `list`, no `retrieve`, no `create`

  This module ships no read or write verbs, and that is **not a gap**. Stripe
  serves this payload from no endpoint at all — there is no
  `/v1/billing/meter_error_reports` collection, no `billing.meter_error_report`
  object, and nothing to retrieve one *from*. The only way to obtain one is to
  receive the event and fetch it.

  Nor does it ship grouping or counting helpers: Stripe already groups by
  `error_types` and supplies `error_count` at both levels. See
  `LatticeStripe.Billing.MeterErrorReport.Reason`.
  """

  alias LatticeStripe.Billing.MeterErrorReport.Reason
  alias LatticeStripe.Event

  # Exactly the four fields the published `data` tree carries. String sigil
  # (no `a`) matches Jason's default string-key output, and square brackets
  # rather than parentheses to match the surrounding convention.
  @known_fields ~w[
    developer_message_summary reason validation_start validation_end
  ]

  @type t :: %__MODULE__{
          developer_message_summary: String.t() | nil,
          reason: Reason.t() | nil,
          validation_start: String.t() | nil,
          validation_end: String.t() | nil,
          meter: String.t() | nil,
          extra: map()
        }

  # There is deliberately NO :id, NO :object and NO :livemode field. This is
  # event *data*, not an addressable resource: the published payload tree has
  # none of the three, and inventing any of them would fake a field Stripe never
  # sends. Do not "fix" this.
  #
  # :meter is the mirror-image case — it is NOT a wire field of `data` either,
  # but it is genuinely knowable: it is lifted from the event envelope's
  # related_object by from_event/1. from_map/1 leaves it nil because from_map/1
  # never sees the envelope.
  defstruct [
    :developer_message_summary,
    :reason,
    :validation_start,
    :validation_end,
    :meter,
    extra: %{}
  ]

  # DECODE

  @doc """
  Decode a fetched `%LatticeStripe.Event{}` into a `%MeterErrorReport{}`.

  **This is the primary constructor.** It is the only one that can populate
  `:meter`, because the meter id lives in the event's `related_object` and never
  in `data`.

      {:ok, event} = LatticeStripe.Webhook.fetch_event(client, notification)
      report = LatticeStripe.Billing.MeterErrorReport.from_event(event)

      report.meter
      #=> "mtr_test_61RCjiqdTDC91zgip41IqPCzPnxqqSVc"

  An event carrying no `related_object` decodes fine and leaves `:meter` nil.
  That is the shape of the sibling `v1.billing.meter.no_meter_found` event,
  which ships this payload byte-for-byte with no related object at all —
  reasonably enough, since the whole point of that event is that no meter was
  found.

  Raises `ArgumentError` if the event carries no `data`. That is the signature
  of passing a *delivered webhook body* rather than a fetched event; see the
  module documentation.
  """
  @spec from_event(Event.t()) :: t()
  def from_event(%Event{data: data, related_object: related}) when is_map(data) do
    # `related` is nil on no_meter_found, which carries no related_object key.
    %{from_map(data) | meter: related && related.id}
  end

  def from_event(%Event{} = event) do
    raise ArgumentError, """
    LatticeStripe.Billing.MeterErrorReport.from_event/1 got an event with no `data`.

    `data` is a *fetched* attribute on a v2 thin event — the webhook body Stripe
    delivers does not contain it. Call LatticeStripe.Webhook.fetch_event/3 with the
    notification first, and pass the event it returns:

        {:ok, event} = LatticeStripe.Webhook.fetch_event(client, notification)
        report = LatticeStripe.Billing.MeterErrorReport.from_event(event)

    Got event id: #{inspect(event.id)}, type: #{inspect(event.type)}
    """
  end

  @doc """
  Decode the raw `data` map into a `%MeterErrorReport{}`.

  The low-level constructor. Prefer `from_event/1`, which is the only one that
  can fill in `:meter`.

  `:meter` is **always** nil here, and that is an asserted contract rather than
  an oversight: `data` never names the meter, so this function structurally
  cannot know it.

  Idempotent: applied to an already-decoded struct it returns it unchanged, and
  `from_map(nil)` returns `nil`. A nil `reason` (it is nullable on the wire)
  decodes to nil. Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil

  # The struct clause MUST precede the `is_map/1` clause — a struct is a map.
  def from_map(%__MODULE__{} = report), do: report

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      developer_message_summary: known["developer_message_summary"],
      reason: Reason.from_map(known["reason"]),
      validation_start: known["validation_start"],
      validation_end: known["validation_end"],
      # Asserted contract, not an oversight: the meter id is in the event
      # envelope, which from_map/1 never sees. from_event/1 fills it in.
      meter: nil,
      extra: extra
    }
  end
end
