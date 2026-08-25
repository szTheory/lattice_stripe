# Regression guard against connected-account tenant confusion.
# Per-request :stripe_account options take precedence over the client default, and the
# header is omitted when both are nil. Account, AccountLink, and LoginLink depend on
# this behavior; if this test ever goes red, the Connect
# integration is silently acting on the wrong connected account.
defmodule LatticeStripe.ClientStripeAccountHeaderTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, Request}

  setup :verify_on_exit!

  defp test_client(overrides) do
    defaults = [
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false,
      max_retries: 0
    ]

    Client.new!(Keyword.merge(defaults, overrides))
  end

  defp get_req(opts \\ []) do
    %Request{method: :get, path: "/v1/accounts/acct_xyz", params: %{}, opts: opts}
  end

  defp ok_response do
    {:ok, %{status: 200, headers: [{"request-id", "req_test"}], body: "{}"}}
  end

  # Test A: client-level stripe_account, no per-request override — header IS present
  test "client-level stripe_account with no per-request override sends stripe-account header" do
    client = test_client(stripe_account: "acct_client")

    expect(LatticeStripe.MockTransport, :request, fn req_map ->
      assert {"stripe-account", "acct_client"} in req_map.headers
      ok_response()
    end)

    assert {:ok, _} = Client.request(client, get_req())
  end

  # Test B: per-request :stripe_account wins over client-level — header uses per-request value
  test "per-request stripe_account overrides client-level stripe_account header" do
    client = test_client(stripe_account: "acct_client")

    expect(LatticeStripe.MockTransport, :request, fn req_map ->
      assert {"stripe-account", "acct_request"} in req_map.headers
      refute {"stripe-account", "acct_client"} in req_map.headers
      ok_response()
    end)

    assert {:ok, _} = Client.request(client, get_req(stripe_account: "acct_request"))
  end

  test "per-request nil stripe_account suppresses the client-level header" do
    client = test_client(stripe_account: "acct_client")

    expect(LatticeStripe.MockTransport, :request, fn req_map ->
      refute Enum.any?(req_map.headers, fn {name, _value} -> name == "stripe-account" end)
      ok_response()
    end)

    assert {:ok, _} = Client.request(client, get_req(stripe_account: nil))
  end

  # Test C: nil client stripe_account AND no per-request opt — header MUST NOT be present
  test "nil client stripe_account with no per-request opt omits stripe-account header entirely" do
    client = test_client(stripe_account: nil)

    expect(LatticeStripe.MockTransport, :request, fn req_map ->
      assert Enum.any?(req_map.headers, fn {k, _} -> k == "stripe-account" end) == false
      ok_response()
    end)

    assert {:ok, _} = Client.request(client, get_req())
  end

  # Test D: nil client stripe_account WITH per-request opt — header IS present from opt
  test "per-request stripe_account is sent even when client-level is nil" do
    client = test_client(stripe_account: nil)

    expect(LatticeStripe.MockTransport, :request, fn req_map ->
      assert {"stripe-account", "acct_request"} in req_map.headers
      ok_response()
    end)

    assert {:ok, _} = Client.request(client, get_req(stripe_account: "acct_request"))
  end
end
