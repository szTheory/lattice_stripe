defmodule LatticeStripe.BillingPortal.SessionIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration
  @moduletag :billing_portal

  # ---------------------------------------------------------------------------
  # TEST-05 (portal portion) — Full portal flow against stripe-mock
  # Implemented in plan 21-04 (Wave 3 integration tests).
  # ---------------------------------------------------------------------------

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  @tag :skip
  test "create/3 returns %Session{url: url} against stripe-mock", %{client: _client} do
    # TEST-05 portal integration — implement in plan 21-04
    # {:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
    #   "customer" => "cus_test123",
    #   "return_url" => "https://example.com/account"
    # })
    # assert %LatticeStripe.BillingPortal.Session{} = session
    # assert is_binary(session.url)
    # assert String.starts_with?(session.url, "https://")
  end
end
