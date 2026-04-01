defmodule LatticeStripe.Transport.FinchTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Transport.Finch, as: FinchTransport

  describe "behaviour" do
    test "declares @behaviour LatticeStripe.Transport" do
      behaviours = FinchTransport.__info__(:attributes)[:behaviour] || []
      assert LatticeStripe.Transport in behaviours
    end

    test "exports request/1" do
      assert function_exported?(FinchTransport, :request, 1)
    end
  end

  describe "request/1" do
    test "raises KeyError when :finch is missing from opts" do
      request = %{
        method: :get,
        url: "https://api.stripe.com/v1/customers",
        headers: [{"authorization", "Bearer sk_test_123"}],
        body: nil,
        opts: []
      }

      assert_raise KeyError, ~r/finch/, fn ->
        FinchTransport.request(request)
      end
    end
  end
end
