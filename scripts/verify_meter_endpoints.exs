# Probe stripe-mock for all Phase 20 metering endpoints.
#
# Confirms all 7 metering endpoints (8 HTTP calls) are served by stripe-mock
# without needing beta flags. Exit 0 when all succeed; exit 1 on any network
# error or 404.
#
# Usage:
#   elixir scripts/verify_meter_endpoints.exs
#   mix run scripts/verify_meter_endpoints.exs
#
# Requires stripe-mock running on port 12111:
#   docker run -p 12111:12111 stripe/stripe-mock:latest
#
# Outcomes per endpoint:
#   OK  {METHOD} {path}  -> {status}
#   FAIL {METHOD} {path}  -> {error}

stripe_mock_url = "http://localhost:12111"

# Handle :already_started gracefully when run via `mix run`
case :inets.start() do
  :ok -> :ok
  {:error, {:already_started, :inets}} -> :ok
end

case :ssl.start() do
  :ok -> :ok
  {:error, {:already_started, :ssl}} -> :ok
end

headers = [
  {~c"Authorization", ~c"Bearer sk_test_123"},
  {~c"Content-Type", ~c"application/x-www-form-urlencoded"},
  {~c"Stripe-Version", ~c"2026-03-25.dahlia"}
]

probe = fn method, path, body ->
  url = String.to_charlist(stripe_mock_url <> path)

  result =
    case method do
      :post ->
        :httpc.request(
          :post,
          {url, headers, ~c"application/x-www-form-urlencoded", String.to_charlist(body)},
          [{:timeout, 5000}],
          []
        )

      :get ->
        get_headers = List.keydelete(headers, ~c"Content-Type", 0)

        :httpc.request(
          :get,
          {url, get_headers},
          [{:timeout, 5000}],
          []
        )
    end

  case result do
    {:ok, {{_version, 404, _reason}, _resp_headers, _resp_body}} ->
      IO.puts("FAIL #{String.upcase(to_string(method))}  #{path}  -> 404 Not Found")
      :fail

    {:ok, {{_version, status, _reason}, _resp_headers, _resp_body}} ->
      IO.puts("OK  #{String.upcase(to_string(method))}  #{path}  -> #{status}")
      :ok

    {:error, {:failed_connect, _}} ->
      IO.puts("FAIL #{String.upcase(to_string(method))}  #{path}  -> connection_refused (is stripe-mock running?)")
      :fail

    {:error, reason} ->
      IO.puts("FAIL #{String.upcase(to_string(method))}  #{path}  -> #{inspect(reason)}")
      :fail
  end
end

IO.puts("=== stripe-mock metering endpoint probe ===")
IO.puts("Target: #{stripe_mock_url}")
IO.puts("")

results = [
  # 1. Create Meter
  probe.(:post, "/v1/billing/meters",
    "display_name=API+Calls&event_name=api_call&default_aggregation[formula]=count"),

  # 2. Retrieve Meter
  probe.(:get, "/v1/billing/meters/mtr_test123", ""),

  # 3. Update Meter
  probe.(:post, "/v1/billing/meters/mtr_test123",
    "display_name=Updated+API+Calls"),

  # 4. List Meters
  probe.(:get, "/v1/billing/meters", ""),

  # 5. Deactivate Meter
  probe.(:post, "/v1/billing/meters/mtr_test123/deactivate", ""),

  # 6. Reactivate Meter
  probe.(:post, "/v1/billing/meters/mtr_test123/reactivate", ""),

  # 7. Create MeterEvent
  probe.(:post, "/v1/billing/meter_events",
    "event_name=api_call&payload[stripe_customer_id]=cus_x&payload[value]=1"),

  # 8. Create MeterEventAdjustment
  probe.(:post, "/v1/billing/meter_event_adjustments",
    "event_name=api_call&cancel[identifier]=req_abc")
]

IO.puts("")
failures = Enum.count(results, &(&1 == :fail))
total = length(results)
ok_count = total - failures

IO.puts("=== Results: #{ok_count}/#{total} OK ===")

if failures > 0 do
  IO.puts("#{failures} endpoint(s) FAILED — check stripe-mock is running and accessible")
  System.halt(1)
else
  System.halt(0)
end
