defmodule PhoenixAdopter.UsageReconciliationProfileTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, Billing.MeterEvent, Billing.MeterEventSummary}

  @meter_id "mtr_test_adopter_usage_123"
  @customer_id "cus_test_adopter_usage_123"
  @start_time 1_753_574_400
  @end_time 1_753_660_800
  @filters %{
    "customer" => @customer_id,
    "start_time" => @start_time,
    "end_time" => @end_time,
    "value_grouping_window" => "day"
  }

  setup :verify_on_exit!

  defp client do
    Client.new!(
      api_key: "sk_test_synthetic_adopter_key",
      transport: PhoenixAdopter.MockTransport,
      max_retries: 0,
      telemetry_enabled: false
    )
  end

  defp summary(id, value) do
    %{
      "id" => id,
      "object" => "billing.meter_event_summary",
      "aggregated_value" => value,
      "start_time" => @start_time,
      "end_time" => @end_time,
      "meter" => @meter_id,
      "livemode" => false
    }
  end

  defp list_response(items, has_more) do
    {:ok,
     %{
       status: 200,
       headers: [{"content-type", "application/json"}],
       body: Jason.encode!(%{
         "object" => "list",
         "url" => "/v1/billing/meters/#{@meter_id}/event_summaries",
         "data" => items,
         "has_more" => has_more
       })
     }}
  end

  defp query_params(request), do: request.url |> URI.parse() |> Map.get(:query) |> URI.decode_query()

  test "usage summary stream traverses two pages with a stable cursor" do
    expect(PhoenixAdopter.MockTransport, :request, fn request ->
      assert request.method == :get
      assert URI.parse(request.url).path == "/v1/billing/meters/#{@meter_id}/event_summaries"
      assert Map.take(query_params(request), Map.keys(@filters)) == Map.new(@filters, fn {k, v} -> {k, to_string(v)} end)
      refute Map.has_key?(query_params(request), "starting_after")

      list_response([summary("mtrusg_adopter_a", 12.5), summary("mtrusg_adopter_b", 9.0)], true)
    end)
    |> expect(:request, fn request ->
      params = query_params(request)
      assert URI.parse(request.url).path == "/v1/billing/meters/#{@meter_id}/event_summaries"
      assert Map.take(params, Map.keys(@filters)) == Map.new(@filters, fn {k, v} -> {k, to_string(v)} end)
      assert params["starting_after"] == "mtrusg_adopter_b"

      list_response([summary("mtrusg_adopter_c", 4.25)], false)
    end)

    rows =
      client()
      |> MeterEventSummary.stream!(@meter_id, @filters)
      |> Enum.to_list()

    assert Enum.all?(rows, &match?(%MeterEventSummary{}, &1))
    assert Enum.map(rows, & &1.id) == ["mtrusg_adopter_a", "mtrusg_adopter_b", "mtrusg_adopter_c"]
    assert Enum.map(rows, & &1.aggregated_value) == [12.5, 9.0, 4.25]
  end

  test "meter event carries body identifier and request idempotency key" do
    expect(PhoenixAdopter.MockTransport, :request, fn request ->
      assert request.method == :post
      assert URI.parse(request.url).path == "/v1/billing/meter_events"
      assert request.body =~ "identifier=invoice_line_123%3Ausage_456"
      assert request.body =~ "payload[stripe_customer_id]=cus_test_adopter_usage_123"
      assert request.body =~ "payload[value]=3.25"
      refute request.body =~ "usage-submit-attempt-789"
      assert {"idempotency-key", "usage-submit-attempt-789"} in request.headers

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body:
           Jason.encode!(%{
             "event_name" => "api_call",
             "identifier" => "invoice_line_123:usage_456",
             "payload" => %{"stripe_customer_id" => @customer_id, "value" => "3.25"},
             "created" => 1_753_574_400,
             "livemode" => false
           })
       }}
    end)

    assert {:ok,
            %MeterEvent{
              event_name: "api_call",
              identifier: "invoice_line_123:usage_456",
              payload: %{"stripe_customer_id" => @customer_id, "value" => "3.25"},
              created: 1_753_574_400,
              livemode: false
            }} =
             MeterEvent.create(
               client(),
               %{
                 "event_name" => "api_call",
                 "identifier" => "invoice_line_123:usage_456",
                 "payload" => %{"stripe_customer_id" => @customer_id, "value" => "3.25"}
               },
               idempotency_key: "usage-submit-attempt-789"
             )
  end
end
