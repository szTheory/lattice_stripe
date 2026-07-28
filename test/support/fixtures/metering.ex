# PROMOTION TARGET (Phase 65 / OBJ-02): move this file to
# lib/lattice_stripe/testing/fixtures/metering.ex AND rename the module to
# LatticeStripe.Testing.Fixtures.Metering. The private test-support namespace is
# LatticeStripe.Test.Fixtures.*; the public one is LatticeStripe.Testing.Fixtures.* — the
# promotion is a move PLUS a module rename, and skipping the rename is a compile error.
# Function names and bodies transfer unchanged — do not re-author.
defmodule LatticeStripe.Test.Fixtures.Metering do
  @moduledoc false

  defmodule Meter do
    @moduledoc false

    @doc """
    Basic active Meter fixture with all Phase 20 nested struct fields populated.

    Returns a string-keyed map matching Stripe's wire format. Suitable for
    unit tests that call `LatticeStripe.Billing.Meter.from_map/1`.
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "mtr_123",
        "object" => "billing.meter",
        "display_name" => "API Calls",
        "event_name" => "api_call",
        "status" => "active",
        "default_aggregation" => %{"formula" => "sum"},
        "customer_mapping" => %{
          "event_payload_key" => "stripe_customer_id",
          "type" => "by_id"
        },
        "value_settings" => %{"event_payload_key" => "value"},
        "status_transitions" => %{"deactivated_at" => nil},
        "created" => 1_712_345_678,
        "livemode" => false,
        "updated" => 1_712_345_678
      }
      |> Map.merge(overrides)
    end

    @doc """
    Inactive (deactivated) Meter fixture.

    Sets `status` to `"inactive"` and `status_transitions.deactivated_at` to a
    non-nil Unix timestamp.
    """
    def deactivated(overrides \\ %{}) do
      basic(%{
        "status" => "inactive",
        "status_transitions" => %{"deactivated_at" => 1_712_400_000}
      })
      |> Map.merge(overrides)
    end

    @doc """
    Stripe list response wrapping one or more Meter fixtures.

    Defaults to a single `basic/1` item. Pass a custom list to override.
    """
    def list_response(items \\ [basic()]) do
      %{
        "object" => "list",
        "data" => items,
        "has_more" => false,
        "url" => "/v1/billing/meters"
      }
    end
  end

  defmodule MeterEvent do
    @moduledoc false

    @doc """
    Basic MeterEvent fixture matching Stripe's wire format.

    The `payload` field intentionally includes both the customer mapping key
    (`stripe_customer_id`) and the value key (`value`). Tests for Inspect
    masking should assert that `:payload` is hidden in the string
    representation of `%LatticeStripe.Billing.MeterEvent{}`.
    """
    def basic(overrides \\ %{}) do
      %{
        "object" => "billing.meter_event",
        "event_name" => "api_call",
        "identifier" => "req_abc",
        "payload" => %{
          "stripe_customer_id" => "cus_test_123",
          "value" => "1"
        },
        "timestamp" => 1_712_345_678,
        "created" => 1_712_345_679,
        "livemode" => false
      }
      |> Map.merge(overrides)
    end
  end

  defmodule MeterEventAdjustment do
    @moduledoc false

    @doc """
    Basic MeterEventAdjustment fixture.

    The `cancel` nested map contains a single `identifier` key — this shape
    is decoded into `%LatticeStripe.Billing.MeterEventAdjustment.Cancel{}`
    by `from_map/1`. Unit tests MUST assert `%Cancel{identifier: "req_abc"}`.
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "mea_123",
        "object" => "billing.meter_event_adjustment",
        "event_name" => "api_call",
        "status" => "pending",
        "cancel" => %{"identifier" => "req_abc"},
        "livemode" => false
      }
      |> Map.merge(overrides)
    end
  end

  defmodule MeterEventStreamSession do
    @moduledoc false

    @doc """
    Basic MeterEventStream.Session fixture matching Stripe's v2 wire format.

    Fields match the documented response shape from POST /v2/billing/meter_event_session.
    The `authentication_token` is a test placeholder — Inspect masking tests should
    assert it does NOT appear in the rendered string.
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "mes_123",
        "object" => "v2.billing.meter_event_session",
        "authentication_token" => "tok_test_abc",
        "created" => 1_712_345_678,
        "expires_at" => 1_712_346_578,
        "livemode" => false
      }
      |> Map.merge(overrides)
    end
  end

  defmodule MeterEventSummary do
    @moduledoc false

    @doc """
    Basic MeterEventSummary fixture matching Stripe's wire format.

    Carries exactly the seven fields Stripe's spec marks required — and no
    `customer`. You filter *by* customer, but the returned object never says
    which customer it belongs to (F-02), so a fixture that invented one would
    teach the wrong shape.

    `aggregated_value` is a **float** on the read path (F-05). Writes take a
    decimal string; reads return a JSON number. The fixture carries `42.5`
    rather than a whole number so a test can prove the value is never rounded
    or coerced to an integer.
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "mtrusg_123",
        "object" => "billing.meter_event_summary",
        "aggregated_value" => 42.5,
        "start_time" => 1_753_620_000,
        "end_time" => 1_753_706_400,
        "meter" => "mtr_123",
        "livemode" => false
      }
      |> Map.merge(overrides)
    end

    @doc """
    Stripe list response wrapping one or more MeterEventSummary fixtures.

    Defaults to a single `basic/1` item. Pass a custom list to override.
    """
    def list_response(items \\ [basic()]) do
      %{
        "object" => "list",
        "data" => items,
        "has_more" => false,
        "url" => "/v1/billing/meters/mtr_123/event_summaries"
      }
    end
  end

  defmodule MeterErrorReport do
    @moduledoc false

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
    def basic(overrides \\ %{}) do
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
    The fully-fetched `v2.core.event` wrapping `basic/1`.

    This is the shape `LatticeStripe.Webhook.fetch_event/3` returns — **not**
    the delivered webhook body, which carries no `data` at all. `related_object`
    names the meter, and it is the only place the meter id appears: `data` never
    mentions which meter failed.

    The top-level `reason` is `null` here, verbatim from the published example.
    Do not confuse it with `data.reason` — see
    `LatticeStripe.Billing.MeterErrorReport.SampleError` on the two
    near-identically named idempotency keys this event carries.
    """
    def event(overrides \\ %{}) do
      %{
        "id" => @event_id,
        "object" => "v2.core.event",
        "context" => nil,
        "created" => "2024-09-26T17:46:22.134Z",
        "data" => basic(),
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

    Its `data` tree is identical field-for-field to `event/1`'s — the two events
    share this payload byte-for-byte. The difference is that this one carries
    **no `related_object` key at all**, so there is no meter id to lift and
    `from_event/1` must leave `:meter` nil rather than raising.
    """
    def no_meter_found_event(overrides \\ %{}) do
      event()
      |> Map.delete("related_object")
      |> Map.put("type", "v1.billing.meter.no_meter_found")
      |> Map.merge(overrides)
    end

    @doc """
    The meter id carried by `event/1`'s related object.

    Exposed so a test can assert `from_event/1` lifted *this* value rather than
    re-stating the literal and proving nothing.
    """
    def meter_id, do: @meter_id
  end
end
