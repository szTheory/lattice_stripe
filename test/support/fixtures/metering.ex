# MeterEvent, MeterEventSummary, and MeterErrorReport public fixtures live in
# lib/lattice_stripe/testing/fixtures/ under the flat LatticeStripe.Testing.Fixtures namespace.
# This support module keeps Meter, MeterEventAdjustment, and MeterEventStreamSession private;
# promoting them would expand the semver-covered API without a demonstrated downstream need.
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
end
