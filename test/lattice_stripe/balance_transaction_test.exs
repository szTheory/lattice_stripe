defmodule LatticeStripe.BalanceTransactionTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.BalanceTransaction

  alias LatticeStripe.{BalanceTransaction, Error, List, Response}
  alias LatticeStripe.BalanceTransaction.FeeDetail

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/balance_transactions/:id and returns {:ok, %BalanceTransaction{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/balance_transactions/txn_test1234567890abc")
        ok_response(basic())
      end)

      assert {:ok, %BalanceTransaction{id: "txn_test1234567890abc"}} =
               BalanceTransaction.retrieve(client, "txn_test1234567890abc")
    end

    test "raises ArgumentError on empty id (pre-network, no mock needed)" do
      client = test_client()

      assert_raise ArgumentError, ~r/balance_transaction id/, fn ->
        BalanceTransaction.retrieve(client, "")
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert {:error, %Error{}} = BalanceTransaction.retrieve(client, "txn_missing")
    end
  end

  describe "retrieve!/3" do
    test "raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise LatticeStripe.Error, fn ->
        BalanceTransaction.retrieve!(client, "txn_test1234567890abc")
      end
    end

    test "returns bare struct on success" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response(basic()) end)

      assert %BalanceTransaction{id: "txn_test1234567890abc"} =
               BalanceTransaction.retrieve!(client, "txn_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/balance_transactions with payout filter" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/balance_transactions"
        assert req.url =~ "payout=po_test1234567890abc"
        ok_response(list_json([basic()], "/v1/balance_transactions"))
      end)

      assert {:ok, %Response{data: %List{data: [%BalanceTransaction{}]}}} =
               BalanceTransaction.list(client, %{"payout" => "po_test1234567890abc"})
    end

    test "passes through multiple filters (payout, source, type, currency, created)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "payout=po_test1234567890abc"
        assert req.url =~ "source=ch_test1234567890abc"
        assert req.url =~ "type=charge"
        assert req.url =~ "currency=usd"
        assert req.url =~ "created"
        ok_response(list_json([basic()], "/v1/balance_transactions"))
      end)

      assert {:ok, %Response{data: %List{}}} =
               BalanceTransaction.list(client, %{
                 "payout" => "po_test1234567890abc",
                 "source" => "ch_test1234567890abc",
                 "type" => "charge",
                 "currency" => "usd",
                 "created" => "1700000000"
               })
    end

    test "returns wrapped %Response{data: %List{data: [%BalanceTransaction{}, ...]}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json(payout_batch(), "/v1/balance_transactions"))
      end)

      assert {:ok, %Response{data: %List{data: items}}} = BalanceTransaction.list(client)
      assert length(items) == 3
      assert Enum.all?(items, &match?(%BalanceTransaction{}, &1))
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert {:error, %Error{}} = BalanceTransaction.list(client)
    end
  end

  describe "list!/3" do
    test "returns bare %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([basic()], "/v1/balance_transactions"))
      end)

      assert %Response{data: %List{data: [%BalanceTransaction{}]}} =
               BalanceTransaction.list!(client)
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "yields BalanceTransaction structs lazily, honoring filters" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "/v1/balance_transactions"
        assert req.url =~ "payout=po_test1234567890abc"
        ok_response(list_json([basic()], "/v1/balance_transactions"))
      end)

      results =
        BalanceTransaction.stream!(client, %{"payout" => "po_test1234567890abc"})
        |> Enum.to_list()

      assert [%BalanceTransaction{id: "txn_test1234567890abc"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1 fee_details decoding" do
    test "decodes fee_details into [%FeeDetail{}]" do
      bt = BalanceTransaction.from_map(with_application_fee())

      assert [%FeeDetail{}, %FeeDetail{}, %FeeDetail{}] = bt.fee_details
    end

    test "reconciliation pattern works end-to-end" do
      bt = BalanceTransaction.from_map(with_application_fee())

      application_fees =
        Enum.filter(bt.fee_details, &(&1.type == "application_fee"))

      assert [%FeeDetail{type: "application_fee", amount: 30}] = application_fees
    end

    test "fee_details nil when absent from payload" do
      bt = BalanceTransaction.from_map(basic(%{"fee_details" => nil}))
      assert bt.fee_details == nil
    end
  end

  describe "from_map/1 source (D-05 rule 5)" do
    test "source is a string when not expanded" do
      bt = BalanceTransaction.from_map(with_source_string())
      assert bt.source == "ch_test1234567890abc"
    end

    test "source is a map when expanded, round-tripping without crashing" do
      bt = BalanceTransaction.from_map(with_source_expanded())
      assert %{"id" => "ch_test1234567890abc", "object" => "charge"} = bt.source
    end
  end

  describe "from_map/1 nil" do
    test "nil returns nil" do
      assert BalanceTransaction.from_map(nil) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Module surface
  # ---------------------------------------------------------------------------

  describe "module surface" do
    test "no create/update/delete exported (Stripe-managed, server-side only)" do
      refute function_exported?(LatticeStripe.BalanceTransaction, :create, 2)
      refute function_exported?(LatticeStripe.BalanceTransaction, :create, 3)
      refute function_exported?(LatticeStripe.BalanceTransaction, :update, 3)
      refute function_exported?(LatticeStripe.BalanceTransaction, :update, 4)
      refute function_exported?(LatticeStripe.BalanceTransaction, :delete, 2)
      refute function_exported?(LatticeStripe.BalanceTransaction, :delete, 3)
    end

    test "retrieve, list, stream! are exported" do
      assert function_exported?(LatticeStripe.BalanceTransaction, :retrieve, 2)
      assert function_exported?(LatticeStripe.BalanceTransaction, :retrieve, 3)
      assert function_exported?(LatticeStripe.BalanceTransaction, :list, 1)
      assert function_exported?(LatticeStripe.BalanceTransaction, :list, 2)
      assert function_exported?(LatticeStripe.BalanceTransaction, :stream!, 1)
      assert function_exported?(LatticeStripe.BalanceTransaction, :stream!, 2)
    end
  end

  describe "F-001" do
    test "unknown top-level field survives in :extra" do
      bt = BalanceTransaction.from_map(basic(%{"future_field" => "hello"}))
      assert bt.extra["future_field"] == "hello"
    end
  end
end
