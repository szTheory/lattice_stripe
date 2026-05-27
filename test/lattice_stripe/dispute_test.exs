defmodule LatticeStripe.DisputeTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Dispute

  alias LatticeStripe.{BalanceTransaction, Charge, Dispute, Error, List, Response}
  alias LatticeStripe.Dispute.{Evidence, EvidenceDetails, PaymentMethodDetails}

  setup :verify_on_exit!

  describe "retrieve/3" do
    test "sends GET /v1/disputes/:id and returns typed nested structs" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc")
        ok_response(dispute_json())
      end)

      assert {:ok,
              %Dispute{
                id: "dp_test1234567890abc",
                evidence: %Evidence{},
                evidence_details: %EvidenceDetails{},
                payment_method_details: %PaymentMethodDetails{}
              }} = Dispute.retrieve(client, "dp_test1234567890abc")
    end
  end

  describe "list/3" do
    test "sends GET /v1/disputes and returns typed list items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/disputes")
        ok_response(list_json([dispute_json()], "/v1/disputes"))
      end)

      assert {:ok, %Response{data: %List{data: [%Dispute{id: "dp_test1234567890abc"}]}}} =
               Dispute.list(client)
    end
  end

  describe "stream!/3" do
    test "streams %Dispute{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/disputes"
        ok_response(list_json([dispute_json()], "/v1/disputes"))
      end)

      assert [%Dispute{id: "dp_test1234567890abc"}] = Dispute.stream!(client) |> Enum.to_list()
    end
  end

  describe "update/4" do
    test "sends POST /v1/disputes/:id with metadata" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc")
        assert req.body =~ "metadata"
        ok_response(dispute_json(%{"metadata" => %{"order_id" => "ord_123"}}))
      end)

      assert {:ok, %Dispute{metadata: %{"order_id" => "ord_123"}}} =
               Dispute.update(client, "dp_test1234567890abc", %{
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end
  end

  describe "update_evidence/4" do
    test "sends evidence with submit=false" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc")
        assert req.body =~ "submit=false"
        assert req.body =~ "evidence[product_description]=Widget"

        ok_response(
          dispute_json(%{
            "evidence" => dispute_evidence_json(%{"product_description" => "Widget"})
          })
        )
      end)

      assert {:ok, %Dispute{evidence: %Evidence{product_description: "Widget"}}} =
               Dispute.update_evidence(client, "dp_test1234567890abc", %{
                 "product_description" => "Widget"
               })
    end

    test "strips stray submit key from evidence" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.body =~ "submit=false"
        assert req.body =~ "evidence[product_description]=Widget"
        refute req.body =~ "submit=true"
        ok_response(dispute_json())
      end)

      assert {:ok, %Dispute{}} =
               Dispute.update_evidence(client, "dp_test1234567890abc", %{
                 "product_description" => "Widget",
                 "submit" => true
               })
    end
  end

  describe "submit_evidence/3" do
    test "sends submit=true with no evidence body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc")
        assert req.body =~ "submit=true"
        refute req.body =~ "evidence"
        ok_response(dispute_json(%{"status" => "under_review"}))
      end)

      assert {:ok, %Dispute{status: :under_review}} =
               Dispute.submit_evidence(client, "dp_test1234567890abc")
    end
  end

  describe "close/3" do
    test "sends POST /v1/disputes/:id/close with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc/close")
        assert req.body in [nil, ""]
        ok_response(dispute_json(%{"status" => "lost"}))
      end)

      assert {:ok, %Dispute{status: :lost}} = Dispute.close(client, "dp_test1234567890abc")
    end
  end

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert Dispute.from_map(nil) == nil
    end

    test "deserializes dispute with nested structs" do
      dispute = Dispute.from_map(dispute_json())

      assert %Dispute{
               evidence: %Evidence{},
               evidence_details: %EvidenceDetails{},
               payment_method_details: %PaymentMethodDetails{type: "card"}
             } = dispute
    end

    test "atomizes known status values" do
      for {value, expected} <- [
            {"needs_response", :needs_response},
            {"warning_needs_response", :warning_needs_response},
            {"under_review", :under_review},
            {"warning_under_review", :warning_under_review},
            {"warning_closed", :warning_closed},
            {"won", :won},
            {"lost", :lost},
            {"charge_refunded", :charge_refunded},
            {"prevented", :prevented}
          ] do
        assert Dispute.from_map(dispute_json(%{"status" => value})).status == expected
      end
    end

    test "passes through unknown status as string" do
      assert Dispute.from_map(dispute_json(%{"status" => "future_status"})).status ==
               "future_status"
    end

    test "atomizes known reason values" do
      for {value, expected} <- [
            {"fraudulent", :fraudulent},
            {"duplicate", :duplicate},
            {"product_not_received", :product_not_received},
            {"general", :general},
            {"customer_initiated", :customer_initiated}
          ] do
        assert Dispute.from_map(dispute_json(%{"reason" => value})).reason == expected
      end
    end

    test "passes through unknown reason as string" do
      assert Dispute.from_map(dispute_json(%{"reason" => "future_reason"})).reason ==
               "future_reason"
    end

    test "deserializes balance_transactions as typed structs" do
      dispute =
        Dispute.from_map(
          dispute_json(%{
            "balance_transactions" => [
              %{
                "id" => "txn_123",
                "object" => "balance_transaction",
                "amount" => -1000,
                "type" => "adjustment"
              }
            ]
          })
        )

      assert [%BalanceTransaction{id: "txn_123"}] = dispute.balance_transactions
    end

    test "preserves unknown fields in extra" do
      dispute = Dispute.from_map(dispute_json(%{"unknown_field" => "value"}))
      assert dispute.extra["unknown_field"] == "value"
    end

    test "expand-deserializes charge when it is a map" do
      dispute =
        Dispute.from_map(
          dispute_json(%{"charge" => %{"id" => "ch_123", "object" => "charge", "amount" => 1000}})
        )

      assert %Charge{id: "ch_123"} = dispute.charge
    end

    test "keeps charge as string when not expanded" do
      dispute = Dispute.from_map(dispute_json())
      assert dispute.charge == "ch_test1234567890abc"
    end
  end

  describe "bang variants" do
    test "retrieve!/3 returns %Dispute{} directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(dispute_json())
      end)

      assert %Dispute{id: "dp_test1234567890abc"} =
               Dispute.retrieve!(client, "dp_test1234567890abc")
    end

    test "retrieve!/3 raises %Error{} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Dispute.retrieve!(client, "dp_missing")
      end
    end
  end

  describe "Inspect" do
    test "shows safe fields and hides sensitive ones" do
      inspected = dispute_json() |> Dispute.from_map() |> inspect()

      assert inspected =~ "#LatticeStripe.Dispute<"
      assert inspected =~ "id: \"dp_test1234567890abc\""
      assert inspected =~ "amount: 1000"
      assert inspected =~ "status: :needs_response"
      assert inspected =~ "reason: :fraudulent"
      refute inspected =~ "evidence:"
      refute inspected =~ "metadata:"
    end
  end
end
