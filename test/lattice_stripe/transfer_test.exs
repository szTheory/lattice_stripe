defmodule LatticeStripe.TransferTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Transfer

  alias LatticeStripe.{Error, List, Response, Transfer, TransferReversal}

  setup :verify_on_exit!

  @transfer_id "tr_1OoMnpJ2eZvKYlo21fGhIjKl"
  @destination "acct_1Nv0FGQ9RKHgCVdK"

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/transfers and returns {:ok, %Transfer{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/transfers")
        assert req.body =~ "amount=1000"
        assert req.body =~ "currency=usd"
        assert req.body =~ "destination=#{@destination}"
        ok_response(transfer_json())
      end)

      assert {:ok, %Transfer{id: @transfer_id, amount: 1_000, currency: "usd"}} =
               Transfer.create(client, %{
                 "amount" => 1_000,
                 "currency" => "usd",
                 "destination" => @destination
               })
    end

    test "does NOT validate params client-side (empty params flows through)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      # No ArgumentError — Stripe 400 surfaces as {:error, %Error{}}
      assert {:error, %Error{type: :invalid_request_error}} = Transfer.create(client, %{})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _ -> error_response() end)
      assert {:error, %Error{}} = Transfer.create(client, %{"amount" => 1000})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/transfers/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}")
        ok_response(transfer_json())
      end)

      assert {:ok, %Transfer{id: @transfer_id}} = Transfer.retrieve(client, @transfer_id)
    end

    test "raises ArgumentError on empty id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        Transfer.retrieve(test_client(), "")
      end
    end

    test "raises ArgumentError on nil id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        Transfer.retrieve(test_client(), nil)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/transfers/:id with metadata" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}")
        assert req.body =~ "metadata"
        ok_response(transfer_json(%{"metadata" => %{"k" => "v"}}))
      end)

      assert {:ok, %Transfer{metadata: %{"k" => "v"}}} =
               Transfer.update(client, @transfer_id, %{"metadata" => %{"k" => "v"}})
    end

    test "raises ArgumentError on empty id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        Transfer.update(test_client(), "", %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "returns wrapped %Response{data: %List{data: [%Transfer{}]}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/transfers")
        ok_response(transfer_list_json())
      end)

      assert {:ok, %Response{data: %List{data: [%Transfer{}]}}} = Transfer.list(client)
    end

    test "passes destination filter through" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "destination=#{@destination}"
        ok_response(transfer_list_json())
      end)

      assert {:ok, %Response{}} = Transfer.list(client, %{"destination" => @destination})
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "yields %Transfer{} structs lazily" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/transfers"
        ok_response(transfer_list_json())
      end)

      results = Transfer.stream!(client) |> Enum.to_list()
      assert [%Transfer{id: @transfer_id}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "bang variants" do
    test "create! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _ -> error_response() end)

      assert_raise Error, fn ->
        Transfer.create!(client, %{"amount" => 1000})
      end
    end

    test "retrieve! returns struct" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _ -> ok_response(transfer_json()) end)
      assert %Transfer{id: @transfer_id} = Transfer.retrieve!(client, @transfer_id)
    end

    test "update! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _ -> error_response() end)

      assert_raise Error, fn ->
        Transfer.update!(client, @transfer_id, %{"metadata" => %{}})
      end
    end

    test "list! returns response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> ok_response(transfer_list_json()) end)

      assert %Response{data: %List{}} = Transfer.list!(client)
    end
  end

  # ---------------------------------------------------------------------------
  # D-02: no reverse/3 or reverse/4 delegator
  # ---------------------------------------------------------------------------

  describe "module surface (D-02)" do
    test "Transfer does NOT define reverse/3" do
      refute function_exported?(LatticeStripe.Transfer, :reverse, 3)
    end

    test "Transfer does NOT define reverse/4" do
      refute function_exported?(LatticeStripe.Transfer, :reverse, 4)
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1 — embedded reversals sublist decoding
  # ---------------------------------------------------------------------------

  describe "from_map/1 reversals decoding" do
    test "decodes reversals.data into [%TransferReversal{}] and preserves sublist metadata" do
      transfer = Transfer.from_map(transfer_with_reversals_json())

      # Plain list, not a %List{}
      assert is_list(transfer.reversals)
      assert length(transfer.reversals) == 3
      assert Enum.all?(transfer.reversals, &match?(%TransferReversal{}, &1))

      # Wrapper metadata preserved in :extra under reversals_meta
      assert %{"has_more" => false, "url" => _, "total_count" => 3, "object" => "list"} =
               transfer.extra["reversals_meta"]
    end

    test "empty reversals.data returns []" do
      map =
        transfer_json(%{
          "reversals" => %{
            "object" => "list",
            "data" => [],
            "has_more" => false,
            "url" => "/v1/transfers/#{@transfer_id}/reversals",
            "total_count" => 0
          }
        })

      transfer = Transfer.from_map(map)
      assert transfer.reversals == []
      assert transfer.extra["reversals_meta"]["total_count"] == 0
    end

    test "nil reversals field yields []" do
      map = Map.put(transfer_json(), "reversals", nil)
      transfer = Transfer.from_map(map)
      assert transfer.reversals == []
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1 — F-001 forward compat
  # ---------------------------------------------------------------------------

  describe "from_map/1 F-001" do
    test "unknown future field survives in :extra" do
      map = transfer_json(%{"future_field" => "forward_compat"})
      transfer = Transfer.from_map(map)
      assert transfer.extra["future_field"] == "forward_compat"
    end

    test "maps known fields" do
      transfer = Transfer.from_map(transfer_json())
      assert transfer.id == @transfer_id
      assert transfer.object == "transfer"
      assert transfer.amount == 1_000
      assert transfer.currency == "usd"
      assert transfer.destination == @destination
      assert transfer.source_type == "card"
      assert transfer.transfer_group == "ORDER_100"
    end

    test "from_map(nil) returns nil" do
      assert Transfer.from_map(nil) == nil
    end
  end
end
