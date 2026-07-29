defmodule LatticeStripe.Testing.Fixtures.MeterErrorReport do
  @moduledoc """
  Canonical raw fixtures for Stripe billing meter error report events.
  """

  # Every id, message, code and timestamp below is copied from the payload
  # Stripe publishes for `v1.billing.meter.error_report_triggered` on its v2
  # core event-types reference. This is deliberate and load-bearing: a
  # downstream adopter hand-invented a fixture for this event carrying an
  # "object" key, a `reason.error_code` field and a top-level identifier —
  # none of which exist on the wire — and shipped a handler built around it.
  # A hand-written fixture would have made that handler's tests pass.
  #
  # Verbatim from the published example:
  #   event id, created, object, livemode, top-level reason (null),
  #   related_object (id/type/url), validation_start, validation_end,
  #   the "meter_event_no_customer_defined" code, its error message, and
  #   the request identifier.
  #
  # Extended beyond the published example (which carries exactly one error
  # type holding exactly one sample): a second sample error under the first
  # code, and a second error type. Both are needed to prove the fan-out
  # decodes a list rather than a single entry, and to carry the empty-sample
  # high-volume shape. The second code is a real value from the live ten-value
  # enum; no field name is invented anywhere.

  @meter_id "mtr_test_61RCjiqdTDC91zgip41IqPCzPnxqqSVc"
  @event_id "evt_test_65RCjj4EqW1sabcjs2Z16RCMoNQdSQkOWvfL6L5uU2K40u"

  @doc """
  The `data` payload of a `v1.billing.meter.error_report_triggered` event.

  Four fields, matching the published tree exactly: `developer_message_summary`,
  `reason`, `validation_start` and `validation_end`. There is **no** `id`, no
  `object` and no `livemode` — this is event data, not an addressable resource,
  and a fixture that invented any of them would teach the wrong shape.

  `validation_start` / `validation_end` are **RFC3339 strings**, not Unix
  integers. That is the published encoding, verified against the live
  reference, and it is a legitimate asymmetry against every v1 object in this
  library (whose timestamps are Unix seconds).

  The first sample error's `request.identifier` is the verbatim published
  value — note it is a **bare UUID**, not one of this library's own
  `idk_ltc_`-prefixed keys. Stripe echoes back whatever idempotency key the
  failing write actually used, which is exactly why an adopter who lets
  `LatticeStripe.Client` auto-generate one gets back a value that joins to
  nothing they own.

  The second error type carries `error_count` 900 with an **empty**
  `sample_errors` list. That is the real high-volume shape — Stripe reports
  the count without sampling every failure — and the decoder must yield `[]`
  rather than `nil` for it.
  """
  @spec meter_error_report_json(map()) :: map()
  def meter_error_report_json(overrides \\ %{}) do
    %{
      # The published example reads "There is 1 invalid event" against its
      # single error. This fixture carries 902, so the summary is restated to
      # match rather than shipping a fixture that contradicts its own counts.
      "developer_message_summary" => "There are 902 invalid events",
      "reason" => %{
        "error_count" => 902,
        "error_types" => [
          %{
            "code" => "meter_event_no_customer_defined",
            "error_count" => 2,
            "sample_errors" => [
              %{
                "error_message" =>
                  "Customer mapping key stripe_customer_id not found in payload.",
                "request" => %{"identifier" => "cb447754-6880-45c2-8f2f-ef19b6ce81e9"}
              },
              %{
                "error_message" =>
                  "Customer mapping key stripe_customer_id not found in payload.",
                "request" => %{"identifier" => "5f2b1d9c-4a3e-4c17-9b0e-2d8a7c6f1e40"}
              }
            ]
          },
          %{
            "code" => "no_meter",
            "error_count" => 900,
            "sample_errors" => []
          }
        ]
      },
      "validation_end" => "2024-09-26T17:46:20.000Z",
      "validation_start" => "2024-09-26T17:46:10.000Z"
    }
    |> Map.merge(overrides)
  end

  @doc """
  The fully-fetched `v2.core.event` wrapping `meter_error_report_json/1`.

  This is the shape `LatticeStripe.Webhook.fetch_event/3` returns — **not**
  the delivered webhook body, which carries no `data` at all. `related_object`
  names the meter, and it is the only place the meter id appears: `data` never
  mentions which meter failed.

  The top-level `reason` is `null` here, verbatim from the published example.
  Do not confuse it with `data.reason` — see
  `LatticeStripe.Billing.MeterErrorReport.SampleError` on the two
  near-identically named idempotency keys this event carries.
  """
  @spec meter_error_report_event_json(map()) :: map()
  def meter_error_report_event_json(overrides \\ %{}) do
    %{
      "id" => @event_id,
      "object" => "v2.core.event",
      "context" => nil,
      "created" => "2024-09-26T17:46:22.134Z",
      "data" => meter_error_report_json(),
      "livemode" => false,
      "reason" => nil,
      "related_object" => %{
        "id" => @meter_id,
        "type" => "billing.meter",
        "url" => "/v1/billing/meters/#{@meter_id}"
      },
      "type" => "v1.billing.meter.error_report_triggered"
    }
    |> Map.merge(overrides)
  end

  @doc """
  The sibling `v1.billing.meter.no_meter_found` event.

  Its `data` tree is identical field-for-field to `meter_error_report_event_json/1`'s — the two events
  share this payload byte-for-byte. The difference is that this one carries
  **no `related_object` key at all**, so there is no meter id to lift and
  `from_event/1` must leave `:meter` nil rather than raising.
  """
  @spec no_meter_found_meter_error_report_event_json(map()) :: map()
  def no_meter_found_meter_error_report_event_json(overrides \\ %{}) do
    meter_error_report_event_json()
    |> Map.delete("related_object")
    |> Map.put("type", "v1.billing.meter.no_meter_found")
    |> Map.merge(overrides)
  end

  @doc """
  The meter id carried by `meter_error_report_event_json/1`'s related object.

  Exposed so a test can assert `from_event/1` lifted *this* value rather than
  re-stating the literal and proving nothing.
  """
  @spec meter_id() :: String.t()
  def meter_id, do: @meter_id
end
