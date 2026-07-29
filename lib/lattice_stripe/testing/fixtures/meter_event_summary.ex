defmodule LatticeStripe.Testing.Fixtures.MeterEventSummary do
  @moduledoc """
  Canonical raw fixtures for Stripe billing meter event summary objects.
  """

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
  @spec basic(map()) :: map()
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
  @spec list_response(list()) :: map()
  def list_response(items \\ [basic()]) do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => "/v1/billing/meters/mtr_123/event_summaries"
    }
  end
end
