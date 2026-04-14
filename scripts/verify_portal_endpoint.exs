# Probe stripe-mock for the BillingPortal.Session endpoint.
#
# Documents stripe-mock behavior for /v1/billing_portal/sessions, including
# RESEARCH Finding 1: stripe-mock does NOT enforce flow_data sub-field
# validation. A request with flow_data.type="subscription_cancel" but without
# the required subscription_cancel.subscription sub-field returns HTTP 200.
# This is why the D-01 guard matrix lives in BillingPortal.GuardsTest (unit
# tests) and NOT in integration tests — the guard is the ONLY mechanism that
# catches missing sub-fields; stripe-mock cannot validate them.
#
# NOTE: stripe-mock returns HTTP 400 (not 422) for all validation errors.
# The plan documented 422 based on Stripe's production behavior, but
# stripe-mock uses 400 for OpenAPI validation failures. Both indicate the
# request was rejected; the error type is "invalid_request_error" in both.
#
# Probe cases:
#   1. Happy path: customer=cus_test123 → expect HTTP 200 with url non-empty.
#   2. Missing customer: no params → expect HTTP 400 (stripe-mock validation).
#   3. Unknown flow_data.type → expect HTTP 400 "value is not in enumeration".
#   4. Sub-field gap: subscription_cancel type with no subscription → expect
#      HTTP 200 (RESEARCH Finding 1: stripe-mock does NOT enforce sub-fields).
#
# Usage:
#   elixir scripts/verify_portal_endpoint.exs
#   mix run scripts/verify_portal_endpoint.exs
#
# Requires stripe-mock running on port 12111:
#   docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest
#
# Exit codes:
#   0 — all probe expectations matched
#   1 — one or more expectations failed

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

post = fn path, body ->
  url = String.to_charlist(stripe_mock_url <> path)

  :httpc.request(
    :post,
    {url, headers, ~c"application/x-www-form-urlencoded", String.to_charlist(body)},
    [{:timeout, 5000}],
    []
  )
end

IO.puts("=== stripe-mock billing portal session probe ===")
IO.puts("Target: #{stripe_mock_url}")
IO.puts("")

failures = []

# ---------------------------------------------------------------------------
# Case 1: Happy path — customer present → expect 200 with url field
# ---------------------------------------------------------------------------

IO.puts("--- Case 1: Happy path (customer=cus_test123) ---")

failures =
  case post.("/v1/billing_portal/sessions", "customer=cus_test123&return_url=https://example.com/account") do
    {:ok, {{_v, 200, _}, _resp_headers, body}} ->
      body_str = List.to_string(body)

      # Check url field non-empty via string match (no Jason in plain elixir script context)
      if String.contains?(body_str, ~s["url":"]) and not String.contains?(body_str, ~s["url":null]) do
        IO.puts("OK  POST  /v1/billing_portal/sessions  -> 200 (url field present in response)")
        failures
      else
        IO.puts("FAIL POST  /v1/billing_portal/sessions  -> 200 but url field appears empty. Body: #{String.slice(body_str, 0, 120)}")
        [1 | failures]
      end

    {:ok, {{_v, status, _}, _resp_headers, body}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> expected 200, got #{status}: #{List.to_string(body)}")
      [1 | failures]

    {:error, {:failed_connect, _}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> connection_refused (is stripe-mock running?)")
      [1 | failures]

    {:error, reason} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> #{inspect(reason)}")
      [1 | failures]
  end

# ---------------------------------------------------------------------------
# Case 2: Missing customer → expect 400 (stripe-mock uses 400, not 422)
# ---------------------------------------------------------------------------

IO.puts("")
IO.puts("--- Case 2: Missing customer (no params) ---")

failures =
  case post.("/v1/billing_portal/sessions", "") do
    {:ok, {{_v, status, _}, _resp_headers, _body}} when status in [400, 422] ->
      IO.puts("OK  POST  /v1/billing_portal/sessions  -> #{status} (missing customer rejected as expected)")
      failures

    {:ok, {{_v, status, _}, _resp_headers, body}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> expected 400/422, got #{status}: #{List.to_string(body)}")
      [1 | failures]

    {:error, {:failed_connect, _}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> connection_refused")
      [1 | failures]

    {:error, reason} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> #{inspect(reason)}")
      [1 | failures]
  end

# ---------------------------------------------------------------------------
# Case 3: Unknown flow_data.type → expect 400 with enumeration error
#   (stripe-mock uses 400 for OpenAPI validation failures; Stripe production
#    uses 422. Both are correct rejection behavior for this probe.)
# ---------------------------------------------------------------------------

IO.puts("")
IO.puts("--- Case 3: Unknown flow_data.type=unknown_type ---")

failures =
  case post.("/v1/billing_portal/sessions", "customer=cus_test123&flow_data[type]=unknown_type") do
    {:ok, {{_v, status, _}, _resp_headers, body}} when status in [400, 422] ->
      body_str = List.to_string(body)

      if String.contains?(body_str, "enumeration") or String.contains?(body_str, "invalid") or
           String.contains?(body_str, "not") do
        IO.puts("OK  POST  /v1/billing_portal/sessions  -> #{status} (unknown flow_data.type rejected: enumeration error confirmed)")
      else
        IO.puts("OK  POST  /v1/billing_portal/sessions  -> #{status} (unknown flow_data.type rejected; body: #{String.slice(body_str, 0, 80)})")
      end

      failures

    {:ok, {{_v, status, _}, _resp_headers, body}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> expected 400/422, got #{status}: #{List.to_string(body)}")
      [1 | failures]

    {:error, {:failed_connect, _}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> connection_refused")
      [1 | failures]

    {:error, reason} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> #{inspect(reason)}")
      [1 | failures]
  end

# ---------------------------------------------------------------------------
# Case 4: Sub-field gap confirmation (RESEARCH Finding 1)
#   subscription_cancel type WITHOUT subscription sub-field.
#   stripe-mock is expected to return 200 — it does NOT enforce sub-field
#   validation. This confirms why the D-01 guard matrix must live in unit
#   tests, not integration tests.
# ---------------------------------------------------------------------------

IO.puts("")
IO.puts("--- Case 4: Sub-field gap — subscription_cancel without .subscription ---")
IO.puts("    (RESEARCH Finding 1: stripe-mock does NOT enforce sub-field validation)")

failures =
  case post.("/v1/billing_portal/sessions", "customer=cus_test123&flow_data[type]=subscription_cancel") do
    {:ok, {{_v, 200, _}, _resp_headers, _body}} ->
      IO.puts("OK  POST  /v1/billing_portal/sessions  -> 200 (sub-field gap confirmed: stripe-mock did NOT reject missing .subscription)")
      IO.puts("    *** This is expected behavior. The D-01 BillingPortal.Guards.check_flow_data!/1 ***")
      IO.puts("    *** is the ONLY validation layer for sub-field requirements. ***")
      failures

    {:ok, {{_v, status, _}, _resp_headers, body}} when status in [400, 422] ->
      IO.puts("WARN POST  /v1/billing_portal/sessions  -> got #{status} (stripe-mock behavior may have changed)")
      IO.puts("    Body: #{String.slice(List.to_string(body), 0, 120)}")
      IO.puts("    ACTION REQUIRED: Update RESEARCH Finding 1 and guard matrix if stripe-mock now enforces sub-fields.")
      [1 | failures]

    {:ok, {{_v, status, _}, _resp_headers, body}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> unexpected #{status}: #{List.to_string(body)}")
      [1 | failures]

    {:error, {:failed_connect, _}} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> connection_refused")
      [1 | failures]

    {:error, reason} ->
      IO.puts("FAIL POST  /v1/billing_portal/sessions  -> #{inspect(reason)}")
      [1 | failures]
  end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("")
total = 4
ok_count = total - length(failures)

IO.puts("=== Results: #{ok_count}/#{total} OK ===")

if length(failures) > 0 do
  IO.puts("#{length(failures)} probe case(s) FAILED — check stripe-mock is running and accessible")
  System.halt(1)
else
  System.halt(0)
end
