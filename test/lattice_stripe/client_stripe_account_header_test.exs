# Regression guard for Phase 17 T-17-03 (tenant confusion).
# Claim: lib/lattice_stripe/client.ex:174-199 + 423-427 thread per-request
# :stripe_account opts ahead of %Client{}.stripe_account AND omit the header
# entirely when both are nil. Phase 17 resource modules (Account, AccountLink,
# LoginLink) depend on this claim — if this test ever goes red, the Connect
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
