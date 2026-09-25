defmodule PhoenixAdopter.ConnectContextProfileTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Balance, Client}

  @account_a "acct_connected_customer_a"
  @account_b "acct_connected_customer_b"

  setup :verify_on_exit!

  defp client(opts \\ []) do
    Client.new!(
      Keyword.merge(
        [
          api_key: "sk_test_synthetic_adopter_key",
          transport: PhoenixAdopter.MockTransport,
          max_retries: 0,
          telemetry_enabled: false
        ],
        opts
      )
    )
  end

  defp balance_response do
    {:ok,
     %{
       status: 200,
       headers: [{"content-type", "application/json"}],
       body:
         Jason.encode!(%{
           "object" => "balance",
           "livemode" => false,
           "available" => [%{"amount" => 1200, "currency" => "usd"}],
           "pending" => []
         })
     }}
  end

  defp assert_balance_request(request, expected_account, other_account \\ nil) do
    assert request.method == :get
    assert URI.parse(request.url).path == "/v1/balance"

    account_headers =
      Enum.filter(request.headers, fn {name, _value} ->
        String.downcase(name) == "stripe-account"
      end)

    case expected_account do
      nil -> assert account_headers == []
      account -> assert account_headers == [{"stripe-account", account}]
    end

    if other_account do
      refute Enum.any?(account_headers, fn {_name, value} -> value == other_account end)
    end

    balance_response()
  end

  test "connected balances use only their per-request tenant header" do
    expect(PhoenixAdopter.MockTransport, :request, fn request ->
      assert_balance_request(request, @account_a, @account_b)
    end)
    |> expect(:request, fn request ->
      assert_balance_request(request, @account_b, @account_a)
    end)

    platform_client = client()

    assert {:ok, %Balance{object: "balance", livemode: false}} =
             Balance.retrieve(platform_client, stripe_account: @account_a)

    assert {:ok, %Balance{object: "balance", livemode: false}} =
             Balance.retrieve(platform_client, stripe_account: @account_b)
  end

  test "nil request context suppresses client account without contaminating next request" do
    expect(PhoenixAdopter.MockTransport, :request, fn request ->
      assert_balance_request(request, nil)
    end)
    |> expect(:request, fn request ->
      assert_balance_request(request, @account_b, "acct_client_default")
    end)

    client_with_default = client(stripe_account: "acct_client_default")

    assert {:ok, %Balance{object: "balance", livemode: false}} =
             Balance.retrieve(client_with_default, stripe_account: nil)

    assert {:ok, %Balance{object: "balance", livemode: false}} =
             Balance.retrieve(client_with_default, stripe_account: @account_b)
  end
end
