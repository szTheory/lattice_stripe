defmodule LatticeStripe.TransportTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  describe "Transport behaviour" do
    test "defines request/1 callback" do
      callbacks = LatticeStripe.Transport.behaviour_info(:callbacks)
      assert {:request, 1} in callbacks
    end
  end

  describe "MockTransport (success case)" do
    test "mock implementing Transport can return {:ok, response_map}" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{method: :get, url: url, headers: _, body: nil, opts: _} ->
        assert url == "https://api.stripe.com/v1/customers"
        {:ok, %{status: 200, headers: [], body: "{\"object\":\"list\"}"}}
      end)

      result =
        LatticeStripe.MockTransport.request(%{
          method: :get,
          url: "https://api.stripe.com/v1/customers",
          headers: [{"Authorization", "Bearer sk_test_123"}],
          body: nil,
          opts: []
        })

      assert {:ok, %{status: 200, body: "{\"object\":\"list\"}"}} = result
    end
  end

  describe "MockTransport (error case)" do
    test "mock implementing Transport can return {:error, reason}" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _request_map ->
        {:error, :timeout}
      end)

      result =
        LatticeStripe.MockTransport.request(%{
          method: :post,
          url: "https://api.stripe.com/v1/payment_intents",
          headers: [],
          body: "amount=1000&currency=usd",
          opts: [timeout: 5_000]
        })

      assert {:error, :timeout} = result
    end
  end
end
