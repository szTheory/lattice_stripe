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
end
