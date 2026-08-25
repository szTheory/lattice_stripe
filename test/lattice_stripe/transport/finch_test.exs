defmodule LatticeStripe.Transport.FinchTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Transport.Finch, as: FinchTransport

  setup_all do
    start_supervised!({Finch, name: __MODULE__.Pool})
    :ok
  end

  describe "behaviour" do
    test "declares @behaviour LatticeStripe.Transport" do
      behaviours = FinchTransport.__info__(:attributes)[:behaviour] || []
      assert LatticeStripe.Transport in behaviours
    end

    test "exports request/1" do
      assert {:request, 1} in FinchTransport.__info__(:functions)
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

    test "normalizes a successful Finch response" do
      {port, server} = serve_once()

      assert {:ok, response} =
               FinchTransport.request(%{
                 method: :post,
                 url: "http://127.0.0.1:#{port}/adapter",
                 headers: [{"x-request-source", "finch-test"}],
                 body: "payload",
                 opts: [finch: __MODULE__.Pool, timeout: 1_000]
               })

      assert response.status == 201
      assert {"x-adapter", "finch"} in response.headers
      assert response.body == "ok"

      assert_receive {:adapter_request, request}
      assert request =~ "POST /adapter HTTP/1.1"
      assert request =~ "x-request-source: finch-test"
      Task.await(server)
    end

    test "returns Finch transport failures without adapter-level wrapping" do
      port = unused_local_port()

      assert {:error,
              %Finch.TransportError{
                reason: :econnrefused,
                source: %Mint.TransportError{reason: :econnrefused}
              }} =
               FinchTransport.request(%{
                 method: :get,
                 url: "http://127.0.0.1:#{port}/unreachable",
                 headers: [],
                 body: nil,
                 opts: [finch: __MODULE__.Pool, timeout: 1_000]
               })
    end
  end

  defp serve_once do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_address, port}} = :inet.sockname(listener)
    test_pid = self()

    server =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 1_000)
        {:ok, request} = :gen_tcp.recv(socket, 0, 1_000)
        send(test_pid, {:adapter_request, request})

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 201 Created\r\ncontent-length: 2\r\nx-adapter: finch\r\nconnection: close\r\n\r\nok"
          )

        :gen_tcp.close(socket)
        :gen_tcp.close(listener)
      end)

    {port, server}
  end

  defp unused_local_port do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_address, port}} = :inet.sockname(listener)
    :gen_tcp.close(listener)
    port
  end
end
