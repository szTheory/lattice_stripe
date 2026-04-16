defmodule LatticeStripe.WarmUpTest do
  use ExUnit.Case, async: true
  import Mox

  alias LatticeStripe.Client

  setup :verify_on_exit!

  defp test_client(overrides \\ []) do
    defaults = [
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false
    ]
    Client.new!(Keyword.merge(defaults, overrides))
  end

  describe "warm_up/1" do
    test "returns {:ok, :warmed} when transport returns {:ok, 200 response}" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{method: :get, url: url, body: nil} ->
        assert String.ends_with?(url, "/v1/")
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      assert {:ok, :warmed} = LatticeStripe.warm_up(test_client())
    end

    test "returns {:ok, :warmed} when transport returns {:ok, 404 response}" do
      # Stripe returns 404 from GET /v1/ — this is EXPECTED; TLS handshake succeeded
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        {:ok, %{status: 404, headers: [], body: ~s({"error":{"type":"invalid_request_error"}})}}
      end)

      assert {:ok, :warmed} = LatticeStripe.warm_up(test_client())
    end

    test "returns {:error, reason} when transport returns {:error, reason}" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = LatticeStripe.warm_up(test_client())
    end

    test "returns {:error, reason} when transport returns {:error, econnrefused}" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = LatticeStripe.warm_up(test_client())
    end

    test "sends GET request to base_url <> /v1/ with auth header" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{method: method, url: url, headers: headers, body: body, opts: opts} ->
        assert method == :get
        assert url == "https://api.stripe.com/v1/"
        assert body == nil
        assert {"authorization", "Bearer sk_test_123"} in headers
        assert Keyword.get(opts, :finch) == :test_finch
        assert Keyword.get(opts, :timeout) == 30_000
        {:ok, %{status: 404, headers: [], body: "{}"}}
      end)

      assert {:ok, :warmed} = LatticeStripe.warm_up(test_client())
    end

    test "uses custom base_url when configured" do
      LatticeStripe.MockTransport
      |> expect(:request, fn %{url: url} ->
        assert url == "http://localhost:12111/v1/"
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      client = test_client(base_url: "http://localhost:12111")
      assert {:ok, :warmed} = LatticeStripe.warm_up(client)
    end

    test "does NOT go through Client.request/2 retry pipeline — only 1 transport call" do
      # warm_up/1 calls transport directly — only 1 transport call, never retried
      LatticeStripe.MockTransport
      |> expect(:request, 1, fn _req -> {:error, :econnrefused} end)

      assert {:error, :econnrefused} = LatticeStripe.warm_up(test_client())
    end
  end

  describe "warm_up!/1" do
    test "returns :warmed on success" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        {:ok, %{status: 404, headers: [], body: "{}"}}
      end)

      assert :warmed = LatticeStripe.warm_up!(test_client())
    end

    test "raises RuntimeError on transport failure" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        {:error, :timeout}
      end)

      assert_raise RuntimeError, ~r/warm-up failed/, fn ->
        LatticeStripe.warm_up!(test_client())
      end
    end
  end
end
