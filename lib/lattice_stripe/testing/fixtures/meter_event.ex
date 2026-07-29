defmodule LatticeStripe.Testing.Fixtures.MeterEvent do
  @moduledoc """
  Canonical raw fixtures for Stripe billing meter event objects.
  """

  @doc """
  Basic MeterEvent fixture matching Stripe's wire format.

  The `payload` field intentionally includes both the customer mapping key
  (`stripe_customer_id`) and the value key (`value`). Tests for Inspect
  masking should assert that `:payload` is hidden in the string
  representation of `%LatticeStripe.Billing.MeterEvent{}`.
  """
  @spec meter_event_json(map()) :: map()
  def meter_event_json(overrides \\ %{}) do
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
