defmodule LatticeStripe.CreditNoteTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Testing.Fixtures.CreditNote

  alias LatticeStripe.{BalanceTransaction, CreditNote, Error, List, Response}
  alias LatticeStripe.CreditNote.LineItem

  setup :verify_on_exit!

  describe "retrieve/3" do
    test "sends GET /v1/credit_notes/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/credit_notes/cn_test1234567890abc")
        ok_response(credit_note_json())
      end)

      assert {:ok, %CreditNote{id: "cn_test1234567890abc"}} =
               CreditNote.retrieve(client, "cn_test1234567890abc")
    end
  end

  describe "create/3" do
    test "sends POST /v1/credit_notes and forwards raw nested lines params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/credit_notes")
        assert req.body =~ "lines[0][type]=invoice_line_item"
        assert req.body =~ "lines[0][invoice_line_item]=il_123"
        ok_response(credit_note_json())
      end)

      assert {:ok, %CreditNote{id: "cn_test1234567890abc"}} =
               CreditNote.create(client, %{
                 "invoice" => "in_123",
                 "lines" => [
                   %{
                     "type" => "invoice_line_item",
                     "invoice_line_item" => "il_123",
                     "quantity" => 1
                   }
                 ]
               })
    end
  end

  describe "update/4" do
    test "sends POST /v1/credit_notes/:id and forwards memo and metadata" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/credit_notes/cn_test1234567890abc")
        assert req.body =~ "memo=Updated+memo"
        assert req.body =~ "metadata[order_id]=ord_123"

        ok_response(
          credit_note_json(%{"memo" => "Updated memo", "metadata" => %{"order_id" => "ord_123"}})
        )
      end)

      assert {:ok, %CreditNote{memo: "Updated memo", metadata: %{"order_id" => "ord_123"}}} =
               CreditNote.update(client, "cn_test1234567890abc", %{
                 "memo" => "Updated memo",
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end
  end

  describe "list/3" do
    test "sends GET /v1/credit_notes and returns typed list items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/credit_notes")
        ok_response(list_json([credit_note_json()], "/v1/credit_notes"))
      end)

      assert {:ok, %Response{data: %List{data: [%CreditNote{id: "cn_test1234567890abc"}]}}} =
               CreditNote.list(client)
    end
  end

  describe "stream!/3" do
    test "streams %CreditNote{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/credit_notes"
        ok_response(list_json([credit_note_json()], "/v1/credit_notes"))
      end)

      assert [%CreditNote{id: "cn_test1234567890abc"}] =
               CreditNote.stream!(client) |> Enum.to_list()
    end
  end

  describe "preview/3" do
    test "sends GET /v1/credit_notes/preview" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/credit_notes/preview"
        assert req.url =~ "invoice=in_123"
        assert req.url =~ "invoice_line_item"
        ok_response(credit_note_json(%{"id" => nil}))
      end)

      assert {:ok, %CreditNote{id: nil}} =
               CreditNote.preview(client, %{
                 "invoice" => "in_123",
                 "lines" => [
                   %{
                     "type" => "invoice_line_item",
                     "invoice_line_item" => "il_123",
                     "quantity" => 1
                   }
                 ]
               })
    end
  end

  describe "void/3" do
    test "sends POST /v1/credit_notes/:id/void with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/credit_notes/cn_test1234567890abc/void")
        assert req.body in [nil, ""]
        ok_response(credit_note_json(%{"status" => "void"}))
      end)

      assert {:ok, %CreditNote{status: :void}} =
               CreditNote.void(client, "cn_test1234567890abc")
    end
  end

  describe "list_line_items/4" do
    test "hits /v1/credit_notes/:id/lines and returns typed line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/credit_notes/cn_test1234567890abc/lines"

        ok_response(
          list_json([credit_note_line_item_json()], "/v1/credit_notes/cn_test1234567890abc/lines")
        )
      end)

      assert {:ok, %Response{data: %List{data: [%LineItem{type: "invoice_line_item"}]}}} =
               CreditNote.list_line_items(client, "cn_test1234567890abc")
    end
  end

  describe "stream_line_items!/4" do
    test "streams typed issued line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/credit_notes/cn_test1234567890abc/lines"

        ok_response(
          list_json(
            [custom_credit_note_line_item_json()],
            "/v1/credit_notes/cn_test1234567890abc/lines"
          )
        )
      end)

      assert [%LineItem{type: "custom_line_item"}] =
               CreditNote.stream_line_items!(client, "cn_test1234567890abc") |> Enum.to_list()
    end
  end

  describe "list_preview_line_items/3" do
    test "hits /v1/credit_notes/preview/lines" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/credit_notes/preview/lines"
        assert req.url =~ "invoice=in_123"
        ok_response(list_json([credit_note_line_item_json()], "/v1/credit_notes/preview/lines"))
      end)

      assert {:ok, %Response{data: %List{data: [%LineItem{type: "invoice_line_item"}]}}} =
               CreditNote.list_preview_line_items(client, %{"invoice" => "in_123"})
    end
  end

  describe "stream_preview_line_items!/3" do
    test "streams typed preview line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/credit_notes/preview/lines"

        ok_response(
          list_json([custom_credit_note_line_item_json()], "/v1/credit_notes/preview/lines")
        )
      end)

      assert [%LineItem{type: "custom_line_item"}] =
               CreditNote.stream_preview_line_items!(client, %{"invoice" => "in_123"})
               |> Enum.to_list()
    end
  end

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert CreditNote.from_map(nil) == nil
    end

    test "atomizes known status values" do
      assert CreditNote.from_map(credit_note_json(%{"status" => "issued"})).status == :issued
      assert CreditNote.from_map(credit_note_json(%{"status" => "void"})).status == :void
    end

    test "passes through unknown status as string" do
      assert CreditNote.from_map(credit_note_json(%{"status" => "future_status"})).status ==
               "future_status"
    end

    test "atomizes known reason values" do
      for {value, expected} <- [
            {"duplicate", :duplicate},
            {"fraudulent", :fraudulent},
            {"order_change", :order_change},
            {"product_unsatisfactory", :product_unsatisfactory}
          ] do
        assert CreditNote.from_map(credit_note_json(%{"reason" => value})).reason == expected
      end
    end

    test "passes through unknown reason as string" do
      assert CreditNote.from_map(credit_note_json(%{"reason" => "future_reason"})).reason ==
               "future_reason"
    end

    test "atomizes known type values" do
      for {value, expected} <- [
            {"pre_payment", :pre_payment},
            {"post_payment", :post_payment},
            {"mixed", :mixed}
          ] do
        assert CreditNote.from_map(credit_note_json(%{"type" => value})).type == expected
      end
    end

    test "passes through unknown type as string" do
      assert CreditNote.from_map(credit_note_json(%{"type" => "future_type"})).type ==
               "future_type"
    end

    test "parses embedded lines into typed CreditNote.LineItem data" do
      note =
        CreditNote.from_map(
          credit_note_json(%{
            "lines" => %{
              "object" => "list",
              "data" => [credit_note_line_item_json(), custom_credit_note_line_item_json()],
              "has_more" => false,
              "url" => "/v1/credit_notes/cn_test1234567890abc/lines"
            }
          })
        )

      assert %List{
               data: [%LineItem{type: "invoice_line_item"}, %LineItem{type: "custom_line_item"}]
             } =
               note.lines
    end

    test "expanded customer, invoice, and customer_balance_transaction maps dispatch via ObjectTypes" do
      note =
        CreditNote.from_map(
          credit_note_json(%{
            "customer" => %{
              "object" => "customer",
              "id" => "cus_123",
              "email" => "credit@example.com"
            },
            "invoice" => %{"object" => "invoice", "id" => "in_123", "status" => "open"},
            "customer_balance_transaction" => %{
              "object" => "balance_transaction",
              "id" => "txn_123",
              "amount" => -500,
              "currency" => "usd",
              "type" => "adjustment"
            }
          })
        )

      assert %LatticeStripe.Customer{id: "cus_123"} = note.customer
      assert %LatticeStripe.Invoice{id: "in_123"} = note.invoice
      assert %BalanceTransaction{id: "txn_123"} = note.customer_balance_transaction
    end

    test "preserves line-item subtype strings for both variants" do
      issued =
        CreditNote.from_map(
          credit_note_json(%{
            "lines" => %{"object" => "list", "data" => [credit_note_line_item_json()]}
          })
        )

      custom = LineItem.from_map(custom_credit_note_line_item_json())

      assert [%LineItem{type: "invoice_line_item"}] = issued.lines.data
      assert %LineItem{type: "custom_line_item"} = custom
    end

    test "captures unknown top-level fields in extra" do
      note = CreditNote.from_map(credit_note_json(%{"unknown_field" => "value"}))
      assert note.extra["unknown_field"] == "value"
    end
  end

  describe "bang variants" do
    test "retrieve!/3 returns %CreditNote{} directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(credit_note_json())
      end)

      assert %CreditNote{id: "cn_test1234567890abc"} =
               CreditNote.retrieve!(client, "cn_test1234567890abc")
    end

    test "list_line_items!/4 returns list response directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(
          list_json([credit_note_line_item_json()], "/v1/credit_notes/cn_test1234567890abc/lines")
        )
      end)

      assert %Response{data: %List{data: [%LineItem{}]}} =
               CreditNote.list_line_items!(client, "cn_test1234567890abc")
    end

    test "list_preview_line_items!/3 returns list response directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([credit_note_line_item_json()], "/v1/credit_notes/preview/lines"))
      end)

      assert %Response{data: %List{data: [%LineItem{}]}} =
               CreditNote.list_preview_line_items!(client, %{"invoice" => "in_123"})
    end

    test "retrieve!/3 raises %Error{} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        CreditNote.retrieve!(client, "cn_test1234567890abc")
      end
    end
  end
end
