defmodule LatticeStripe.TransferReversalTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.TransferReversal

  alias LatticeStripe.{Error, List, Response, TransferReversal}

  setup :verify_on_exit!

  @transfer_id "tr_1OoMnpJ2eZvKYlo21fGhIjKl"
  @reversal_id "trr_1OoMpqJ2eZvKYlo20wxYzAbC"

  # ---------------------------------------------------------------------------
  # create/4
  # ---------------------------------------------------------------------------

  describe "create/4" do
    test "sends POST /v1/transfers/:transfer_id/reversals and returns {:ok, %TransferReversal{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}/reversals")
        assert req.body =~ "amount=500"
        ok_response(transfer_reversal_json())
      end)

      assert {:ok, %TransferReversal{id: @reversal_id, amount: 500}} =
               TransferReversal.create(client, @transfer_id, %{"amount" => 500})
    end

    test "raises ArgumentError on empty transfer_id (pre-network)" do
      client = test_client()

      assert_raise ArgumentError, ~r/transfer id/, fn ->
        TransferReversal.create(client, "", %{})
      end
    end

    test "raises ArgumentError on nil transfer_id (pre-network)" do
      client = test_client()

      assert_raise ArgumentError, ~r/transfer id/, fn ->
        TransferReversal.create(client, nil, %{})
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert {:error, %Error{}} = TransferReversal.create(client, @transfer_id, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/4
  # ---------------------------------------------------------------------------

  describe "retrieve/4" do
    test "sends GET /v1/transfers/:transfer_id/reversals/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}/reversals/#{@reversal_id}")
        ok_response(transfer_reversal_json())
      end)

      assert {:ok, %TransferReversal{id: @reversal_id}} =
               TransferReversal.retrieve(client, @transfer_id, @reversal_id)
    end

    test "raises ArgumentError on empty transfer_id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        TransferReversal.retrieve(test_client(), "", @reversal_id)
      end
    end

    test "raises ArgumentError on empty reversal_id" do
      assert_raise ArgumentError, ~r/reversal id/, fn ->
        TransferReversal.retrieve(test_client(), @transfer_id, "")
      end
    end

    test "raises ArgumentError on nil reversal_id" do
      assert_raise ArgumentError, ~r/reversal id/, fn ->
        TransferReversal.retrieve(test_client(), @transfer_id, nil)
      end
    end

    test "returns {:error, %Error{}} on not found" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _ -> error_response() end)
      assert {:error, %Error{}} = TransferReversal.retrieve(client, @transfer_id, @reversal_id)
    end
  end

  # ---------------------------------------------------------------------------
  # update/5
  # ---------------------------------------------------------------------------

  describe "update/5" do
    test "sends POST /v1/transfers/:transfer_id/reversals/:id with metadata" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}/reversals/#{@reversal_id}")
        assert req.body =~ "metadata"
        ok_response(transfer_reversal_json(%{"metadata" => %{"k" => "v"}}))
      end)

      assert {:ok, %TransferReversal{metadata: %{"k" => "v"}}} =
               TransferReversal.update(client, @transfer_id, @reversal_id, %{
                 "metadata" => %{"k" => "v"}
               })
    end

    test "raises ArgumentError on empty transfer_id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        TransferReversal.update(test_client(), "", @reversal_id, %{})
      end
    end

    test "raises ArgumentError on empty reversal_id" do
      assert_raise ArgumentError, ~r/reversal id/, fn ->
        TransferReversal.update(test_client(), @transfer_id, "", %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list/4
  # ---------------------------------------------------------------------------

  describe "list/4" do
    test "returns wrapped %Response{data: %List{}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}/reversals")
        ok_response(transfer_reversal_list_json())
      end)

      assert {:ok, %Response{data: %List{data: items}}} =
               TransferReversal.list(client, @transfer_id)

      assert [%TransferReversal{}, %TransferReversal{}] = items
    end

    test "raises ArgumentError on empty transfer_id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        TransferReversal.list(test_client(), "")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/4
  # ---------------------------------------------------------------------------

  describe "stream!/4" do
    test "yields %TransferReversal{} structs lazily" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/transfers/#{@transfer_id}/reversals"
        ok_response(transfer_reversal_list_json())
      end)

      results = TransferReversal.stream!(client, @transfer_id) |> Enum.to_list()

      assert [%TransferReversal{}, %TransferReversal{}] = results
    end

    test "raises ArgumentError on empty transfer_id" do
      assert_raise ArgumentError, ~r/transfer id/, fn ->
        TransferReversal.stream!(test_client(), "")
      end
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
        TransferReversal.create!(client, @transfer_id, %{})
      end
    end

    test "retrieve! returns struct on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> ok_response(transfer_reversal_json()) end)

      assert %TransferReversal{id: @reversal_id} =
               TransferReversal.retrieve!(client, @transfer_id, @reversal_id)
    end

    test "update! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _ -> error_response() end)

      assert_raise Error, fn ->
        TransferReversal.update!(client, @transfer_id, @reversal_id, %{})
      end
    end

    test "list! returns response on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ ->
        ok_response(transfer_reversal_list_json())
      end)

      assert %Response{data: %List{data: [%TransferReversal{} | _]}} =
               TransferReversal.list!(client, @transfer_id)
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields explicitly" do
      tr = TransferReversal.from_map(transfer_reversal_json())

      assert tr.id == @reversal_id
      assert tr.object == "transfer_reversal"
      assert tr.amount == 500
      assert tr.currency == "usd"
      assert tr.transfer == @transfer_id
      assert tr.metadata == %{}
      assert tr.created == 1_700_000_000
    end

    test "unknown fields land in :extra (F-001)" do
      map = transfer_reversal_json(%{"future_field" => "forward_compat"})
      tr = TransferReversal.from_map(map)
      assert tr.extra["future_field"] == "forward_compat"
    end

    test "from_map(nil) returns nil" do
      assert TransferReversal.from_map(nil) == nil
    end

    test "defaults object when missing" do
      tr = TransferReversal.from_map(%{"id" => "trr_x"})
      assert tr.object == "transfer_reversal"
      assert tr.extra == %{}
    end
  end
end
