# Answer the single open question from 17-CONTEXT.md — does stripe-mock support
# POST /v1/accounts/:id/reject? Phase 17 Plan 17-05 (integration tests) needs
# the answer before it writes the reject test.
#
# Usage:
#   mix run scripts/verify_stripe_mock_reject.exs
#   elixir scripts/verify_stripe_mock_reject.exs
#
# Requires stripe-mock running on port 12111:
#   docker run -p 12111:12111 stripe/stripe-mock:latest
#
# Outcomes:
#   REJECT_SUPPORTED=true  (exit 0) — stripe-mock returns 200 for the reject path
#   REJECT_SUPPORTED=false (exit 0) — stripe-mock returns 404; reject path unknown
#   REJECT_PROBE_INCONCLUSIVE (exit 1) — stripe-mock not running / connection refused

stripe_mock_url = "http://localhost:12111"
reject_path = "/v1/accounts/acct_test/reject"
url = stripe_mock_url <> reject_path

# Use Erlang's built-in :httpc / :inets — no Mix.install needed
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
  {~c"Stripe-Version", ~c"2024-06-20"}
]

body = ~c"reason=fraud"

result =
  :httpc.request(
    :post,
    {String.to_charlist(url), headers, ~c"application/x-www-form-urlencoded", body},
    [{:timeout, 5000}],
    []
  )

case result do
  {:ok, {{_version, status, _reason}, _resp_headers, _resp_body}} when status in 200..299 ->
    IO.puts("REJECT_SUPPORTED=true")
    IO.puts("stripe-mock returned HTTP #{status} for POST #{reject_path}")
    System.halt(0)

  {:ok, {{_version, 404, _reason}, _resp_headers, _resp_body}} ->
    IO.puts("REJECT_SUPPORTED=false reason=404")
    IO.puts("stripe-mock returned 404 for POST #{reject_path} — route not in OpenAPI spec")
    System.halt(0)

  {:ok, {{_version, status, _reason}, _resp_headers, resp_body}} ->
    IO.puts("REJECT_SUPPORTED=false reason=http_#{status}")
    IO.puts("stripe-mock returned HTTP #{status} for POST #{reject_path}")
    IO.puts("Body: #{resp_body}")
    System.halt(0)

  {:error, {:failed_connect, _}} ->
    IO.puts(
      "REJECT_PROBE_INCONCLUSIVE reason=connection_refused " <>
        "start stripe-mock via: docker run -p 12111:12111 stripe/stripe-mock"
    )

    System.halt(1)

  {:error, reason} ->
    IO.puts("REJECT_PROBE_INCONCLUSIVE reason=#{inspect(reason)}")
    System.halt(1)
end
