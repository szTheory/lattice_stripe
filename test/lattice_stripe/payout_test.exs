defmodule LatticeStripe.PayoutTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Payout

  alias LatticeStripe.{Error, List, Payout, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/payouts and returns {:ok, %Payout{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payouts")
        assert req.body =~ "amount=5000"
        assert req.body =~ "currency=usd"
        ok_response(basic())
      end)

      assert {:ok, %Payout{id: "po_1OoMpqJ2eZvKYlo20wxYzAbC", amount: 5000, currency: "usd"}} =
               Payout.create(client, %{"amount" => 5000, "currency" => "usd"})
    end

    test "threads method + source_type as plain params (no atom guard)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "method=instant"
        assert req.body =~ "source_type=card"
        ok_response(basic(%{"method" => "instant"}))
      end)

      assert {:ok, %Payout{method: :instant}} =
               Payout.create(client, %{
                 "amount" => 5000,
                 "currency" => "usd",
                 "method" => "instant",
                 "source_type" => "card"
               })
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert {:error, %Error{type: :invalid_request_error}} =
               Payout.create(client, %{"amount" => 5000, "currency" => "usd"})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/payouts/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/payouts/po_1OoMpqJ2eZvKYlo20wxYzAbC")
        ok_response(basic())
      end)

      assert {:ok, %Payout{id: "po_1OoMpqJ2eZvKYlo20wxYzAbC"}} =
               Payout.retrieve(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
    end

    test "raises ArgumentError on empty id" do
      client = test_client()

      assert_raise ArgumentError, ~r/payout id/, fn ->
        Payout.retrieve(client, "")
      end
    end

    test "raises ArgumentError on nil id" do
      client = test_client()

      assert_raise ArgumentError, ~r/payout id/, fn ->
        Payout.retrieve(client, nil)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/payouts/:id with metadata" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payouts/po_1OoMpqJ2eZvKYlo20wxYzAbC")
        assert req.body =~ "metadata"
        ok_response(basic(%{"metadata" => %{"order_id" => "ord_42"}}))
      end)

      assert {:ok, %Payout{metadata: %{"order_id" => "ord_42"}}} =
               Payout.update(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC", %{
                 "metadata" => %{"order_id" => "ord_42"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/payouts and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/payouts")
        ok_response(list_response())
      end)

      assert {:ok, %Response{data: %List{data: [%Payout{id: "po_1OoMpqJ2eZvKYlo20wxYzAbC"}]}}} =
               Payout.list(client)
    end

    test "threads status filter into query string" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "status=paid"
        ok_response(list_response())
      end)

      assert {:ok, %Response{data: %List{}}} = Payout.list(client, %{"status" => "paid"})
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "yields Payout structs lazily" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_response())
      end)

      results = Payout.stream!(client) |> Enum.to_list()
      assert [%Payout{id: "po_1OoMpqJ2eZvKYlo20wxYzAbC"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/4 — D-03 canonical shape
  # ---------------------------------------------------------------------------

  describe "cancel/4 default params" do
    test "Payout.cancel(client, id) works without explicit params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payouts/po_1OoMpqJ2eZvKYlo20wxYzAbC/cancel")
        ok_response(cancelled())
      end)

      assert {:ok, %Payout{status: :canceled}} =
               Payout.cancel(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
    end
  end

  describe "cancel/4 with expand" do
    test "threads expand param into POST body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payouts/po_1OoMpqJ2eZvKYlo20wxYzAbC/cancel")
        # expand is form-encoded as expand[0]=balance_transaction
        assert req.body =~ "expand"
        assert req.body =~ "balance_transaction"
        ok_response(cancelled())
      end)

      assert {:ok, %Payout{status: "canceled"}} =
               Payout.cancel(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC", %{
                 "expand" => ["balance_transaction"]
               })
    end
  end

  describe "cancel/4 id validation" do
    test "raises ArgumentError on empty id pre-network" do
      client = test_client()

      assert_raise ArgumentError, ~r/payout id/, fn ->
        Payout.cancel(client, "")
      end
    end

    test "raises ArgumentError on nil id pre-network" do
      client = test_client()

      assert_raise ArgumentError, ~r/payout id/, fn ->
        Payout.cancel(client, nil)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # reverse/4 — D-03 canonical shape
  # ---------------------------------------------------------------------------

  describe "reverse/4 default params" do
    test "Payout.reverse(client, id) works without explicit params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payouts/po_1OoMpqJ2eZvKYlo20wxYzAbC/reverse")
        ok_response(reversed())
      end)

      assert {:ok, %Payout{reversed_by: "po_reversal123"}} =
               Payout.reverse(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
    end
  end

  describe "reverse/4 with metadata + expand" do
    test "threads metadata and expand into POST body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payouts/po_1OoMpqJ2eZvKYlo20wxYzAbC/reverse")
        assert req.body =~ "metadata"
        assert req.body =~ "expand"
        ok_response(reversed())
      end)

      assert {:ok, %Payout{}} =
               Payout.reverse(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC", %{
                 "metadata" => %{"k" => "v"},
                 "expand" => ["balance_transaction"]
               })
    end
  end

  describe "reverse/4 id validation" do
    test "raises ArgumentError on empty id" do
      client = test_client()

      assert_raise ArgumentError, ~r/payout id/, fn ->
        Payout.reverse(client, "")
      end
    end

    test "raises ArgumentError on nil id" do
      client = test_client()

      assert_raise ArgumentError, ~r/payout id/, fn ->
        Payout.reverse(client, nil)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1 — trace_id decoding
  # ---------------------------------------------------------------------------

  describe "from_map/1 trace_id decoding" do
    test "decodes trace_id map into %Payout.TraceId{} struct" do
      payout = Payout.from_map(with_trace_id())

      assert %Payout{
               trace_id: %LatticeStripe.Payout.TraceId{
                 status: "supported",
                 value: "FED12345"
               }
             } = payout
    end

    test "decodes nil trace_id as nil" do
      payout = Payout.from_map(basic())
      assert payout.trace_id == nil
    end

    test "pattern-match on nested trace_id.status works" do
      payout = Payout.from_map(with_trace_id())

      result =
        case payout do
          %Payout{trace_id: %LatticeStripe.Payout.TraceId{status: "supported", value: v}} ->
            {:ok, v}

          _ ->
            :other
        end

      assert result == {:ok, "FED12345"}
    end
  end

  describe "from_map/1 expandable references" do
    test "destination stays as string when not expanded" do
      payout = Payout.from_map(with_destination_string())
      assert payout.destination == "ba_test_dest_string"
    end

    test "destination is a map when expanded" do
      payout = Payout.from_map(with_destination_expanded())
      assert is_map(payout.destination)
      assert payout.destination["object"] == "bank_account"
      assert payout.destination["last4"] == "6789"
    end
  end

  describe "from_map/1 F-001 round-trip" do
    test "unknown future field survives in :extra" do
      payout = Payout.from_map(basic(%{"future_field" => "maybe_blockchain"}))
      assert payout.extra == %{"future_field" => "maybe_blockchain"}
    end

    test "known fields never leak into :extra" do
      payout = Payout.from_map(basic())
      refute Map.has_key?(payout.extra, "amount")
      refute Map.has_key?(payout.extra, "status")
      refute Map.has_key?(payout.extra, "trace_id")
    end

    test "defaults object to 'payout'" do
      payout = Payout.from_map(%{"id" => "po_abc"})
      assert payout.object == "payout"
    end

    test "from_map(nil) returns nil" do
      assert Payout.from_map(nil) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1 — atomization
  # ---------------------------------------------------------------------------

  describe "from_map/1 status atomization" do
    test "atomizes 'paid' to :paid" do
      payout = Payout.from_map(basic(%{"status" => "paid"}))
      assert payout.status == :paid
    end

    test "atomizes 'pending' to :pending" do
      payout = Payout.from_map(basic(%{"status" => "pending"}))
      assert payout.status == :pending
    end

    test "atomizes 'in_transit' to :in_transit" do
      payout = Payout.from_map(basic(%{"status" => "in_transit"}))
      assert payout.status == :in_transit
    end

    test "atomizes 'canceled' to :canceled" do
      payout = Payout.from_map(basic(%{"status" => "canceled"}))
      assert payout.status == :canceled
    end

    test "atomizes 'failed' to :failed" do
      payout = Payout.from_map(basic(%{"status" => "failed"}))
      assert payout.status == :failed
    end

    test "passes through unknown status string" do
      payout = Payout.from_map(basic(%{"status" => "future_status"}))
      assert payout.status == "future_status"
    end

    test "passes through nil status" do
      payout = Payout.from_map(basic(%{"status" => nil}))
      assert payout.status == nil
    end
  end

  describe "from_map/1 type atomization" do
    test "atomizes 'bank_account' to :bank_account" do
      payout = Payout.from_map(basic(%{"type" => "bank_account"}))
      assert payout.type == :bank_account
    end

    test "atomizes 'card' to :card" do
      payout = Payout.from_map(basic(%{"type" => "card"}))
      assert payout.type == :card
    end

    test "passes through unknown type string" do
      payout = Payout.from_map(basic(%{"type" => "future_type"}))
      assert payout.type == "future_type"
    end
  end

  describe "from_map/1 method atomization" do
    test "atomizes 'standard' to :standard" do
      payout = Payout.from_map(basic(%{"method" => "standard"}))
      assert payout.method == :standard
    end

    test "atomizes 'instant' to :instant" do
      payout = Payout.from_map(basic(%{"method" => "instant"}))
      assert payout.method == :instant
    end

    test "passes through unknown method string" do
      payout = Payout.from_map(basic(%{"method" => "future_method"}))
      assert payout.method == "future_method"
    end
  end

  describe "from_map/1 expand guards" do
    test "balance_transaction stays as string when not expanded" do
      payout = Payout.from_map(basic(%{"balance_transaction" => "txn_abc"}))
      assert payout.balance_transaction == "txn_abc"
    end

    test "balance_transaction dispatches to BalanceTransaction.from_map when expanded map" do
      payout =
        Payout.from_map(
          basic(%{
            "balance_transaction" => %{
              "id" => "txn_abc",
              "object" => "balance_transaction",
              "amount" => 1000,
              "currency" => "usd"
            }
          })
        )

      assert %LatticeStripe.BalanceTransaction{id: "txn_abc"} = payout.balance_transaction
    end

    test "destination dispatches to BankAccount.from_map when expanded bank_account map" do
      payout = Payout.from_map(with_destination_expanded())
      assert %LatticeStripe.BankAccount{id: "ba_test_dest_expanded"} = payout.destination
    end

    test "failure_balance_transaction stays as nil when absent" do
      payout = Payout.from_map(basic())
      assert payout.failure_balance_transaction == nil
    end

    test "failure_balance_transaction dispatches to BalanceTransaction.from_map when expanded" do
      payout =
        Payout.from_map(
          basic(%{
            "failure_balance_transaction" => %{
              "id" => "txn_fail",
              "object" => "balance_transaction",
              "amount" => -5000,
              "currency" => "usd"
            }
          })
        )

      assert %LatticeStripe.BalanceTransaction{id: "txn_fail"} =
               payout.failure_balance_transaction
    end
  end

  # ---------------------------------------------------------------------------
  # Module surface — D-03 / D-04 guards
  # ---------------------------------------------------------------------------

  describe "module surface" do
    test "cancel is exported at arity 2 AND arity 4 (default params)" do
      assert function_exported?(Payout, :cancel, 2)
      assert function_exported?(Payout, :cancel, 4)
    end

    test "no arity-5 cancel variant (D-04 no atom guards)" do
      refute function_exported?(Payout, :cancel, 5)
    end

    test "reverse is exported at arity 2 AND arity 4 (default params)" do
      assert function_exported?(Payout, :reverse, 2)
      assert function_exported?(Payout, :reverse, 4)
    end

    test "no arity-5 reverse variant (D-04 no atom guards)" do
      refute function_exported?(Payout, :reverse, 5)
    end

    test "does not derive Jason.Encoder" do
      source = File.read!("lib/lattice_stripe/payout.ex")
      refute source =~ "Jason.Encoder"
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "bang variants" do
    test "create! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn ->
        Payout.create!(client, %{"amount" => 100, "currency" => "usd"})
      end
    end

    test "retrieve! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn ->
        Payout.retrieve!(client, "po_missing")
      end
    end

    test "update! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn ->
        Payout.update!(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC", %{"metadata" => %{}})
      end
    end

    test "cancel! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn ->
        Payout.cancel!(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
      end
    end

    test "reverse! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn ->
        Payout.reverse!(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
      end
    end

    test "list! raises on error" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn -> Payout.list!(client) end
    end

    test "cancel! returns bare struct on success" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response(cancelled()) end)

      assert %Payout{status: :canceled} = Payout.cancel!(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
    end

    test "reverse! returns bare struct on success" do
      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response(reversed()) end)

      assert %Payout{} = Payout.reverse!(client, "po_1OoMpqJ2eZvKYlo20wxYzAbC")
    end
  end
end
