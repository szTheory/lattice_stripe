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

  describe "Transport behaviour contract completeness" do
    test "behaviour defines EXACTLY the expected callbacks: [request: 1]" do
      # The Transport behaviour should export exactly one callback — request/1.
      # This is an exact match so adding new callbacks without updating tests fails loudly.
      assert LatticeStripe.Transport.behaviour_info(:callbacks) == [request: 1]
    end

    test "MockTransport pattern-matches all request_map fields: method, url, headers, body, opts" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{
                               method: method,
                               url: url,
                               headers: headers,
                               body: body,
                               opts: opts
                             } ->
        assert is_atom(method)
        assert is_binary(url)
        assert is_list(headers)
        assert is_nil(body) or is_binary(body)
        assert is_list(opts)
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      LatticeStripe.MockTransport.request(%{
        method: :get,
        url: "https://api.stripe.com/v1/customers",
        headers: [{"authorization", "Bearer sk_test"}],
        body: nil,
        opts: [finch: :test_finch, timeout: 30_000]
      })
    end

    test "MockTransport can return {:error, :timeout} (atom error reason)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> {:error, :timeout} end)

      result = LatticeStripe.MockTransport.request(%{method: :get, url: "u", headers: [], body: nil, opts: []})
      assert result == {:error, :timeout}
    end

    test "MockTransport can return {:error, :closed} (connection-closed reason)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> {:error, :closed} end)

      result = LatticeStripe.MockTransport.request(%{method: :get, url: "u", headers: [], body: nil, opts: []})
      assert result == {:error, :closed}
    end

    test "MockTransport can return {:error, %RuntimeError{}} (exception as reason)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> {:error, %RuntimeError{message: "boom"}} end)

      result = LatticeStripe.MockTransport.request(%{method: :get, url: "u", headers: [], body: nil, opts: []})
      assert {:error, %RuntimeError{message: "boom"}} = result
    end

    test "MockTransport can return {:error, {:transport_error, reason}} (custom tuple reason)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> {:error, {:transport_error, "DNS resolution failed"}} end)

      result = LatticeStripe.MockTransport.request(%{method: :get, url: "u", headers: [], body: nil, opts: []})
      assert {:error, {:transport_error, "DNS resolution failed"}} = result
    end

    test "MockTransport handles nil body (GET request pattern)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{body: nil} ->
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      result =
        LatticeStripe.MockTransport.request(%{
          method: :get,
          url: "https://api.stripe.com/v1/customers",
          headers: [],
          body: nil,
          opts: []
        })

      assert {:ok, %{status: 200}} = result
    end

    test "MockTransport handles binary body (POST request pattern)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{body: "amount=1000&currency=usd"} ->
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      result =
        LatticeStripe.MockTransport.request(%{
          method: :post,
          url: "https://api.stripe.com/v1/payment_intents",
          headers: [],
          body: "amount=1000&currency=usd",
          opts: []
        })

      assert {:ok, %{status: 200}} = result
    end

    test "response_map includes all expected keys: status, headers, body" do
      expected_body = Jason.encode!(%{"id" => "cus_123", "object" => "customer"})

      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        {:ok,
         %{
           status: 200,
           headers: [{"content-type", "application/json"}, {"request-id", "req_test"}],
           body: expected_body
         }}
      end)

      {:ok, response} =
        LatticeStripe.MockTransport.request(%{
          method: :get,
          url: "https://api.stripe.com/v1/customers/cus_123",
          headers: [],
          body: nil,
          opts: []
        })

      assert Map.has_key?(response, :status)
      assert Map.has_key?(response, :headers)
      assert Map.has_key?(response, :body)
      assert response.status == 200
      assert is_list(response.headers)
      assert is_binary(response.body)
    end
  end
end
