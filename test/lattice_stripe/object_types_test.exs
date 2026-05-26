defmodule LatticeStripe.ObjectTypesTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.ObjectTypes

  describe "maybe_deserialize/1" do
    test "returns nil for nil input" do
      assert ObjectTypes.maybe_deserialize(nil) == nil
    end

    test "returns string IDs unchanged" do
      assert ObjectTypes.maybe_deserialize("cus_123") == "cus_123"
      assert ObjectTypes.maybe_deserialize("pi_abc") == "pi_abc"
    end

    test "dispatches customer map to Customer.from_map/1" do
      map = %{"object" => "customer", "id" => "cus_123", "email" => "test@example.com"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Customer{id: "cus_123"} = result
    end

    test "dispatches payment_intent map to PaymentIntent.from_map/1" do
      map = %{
        "object" => "payment_intent",
        "id" => "pi_123",
        "amount" => 2000,
        "currency" => "usd"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.PaymentIntent{id: "pi_123"} = result
    end

    test "dispatches invoice map to Invoice.from_map/1" do
      map = %{"object" => "invoice", "id" => "in_123", "status" => "open"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Invoice{id: "in_123"} = result
    end

    test "dispatches expanded invoice quote back-reference to Quote.from_map/1" do
      invoice =
        ObjectTypes.maybe_deserialize(%{
          "object" => "invoice",
          "id" => "in_123",
          "quote" => %{
            "object" => "quote",
            "id" => "qt_123",
            "status" => "open"
          }
        })

      assert %LatticeStripe.Invoice{quote: %LatticeStripe.Quote{id: "qt_123"}} = invoice
    end

    test "dispatches mandate map to Mandate.from_map/1" do
      map = %{
        "object" => "mandate",
        "id" => "mandate_123",
        "status" => "active",
        "type" => "single_use"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Mandate{id: "mandate_123"} = result
    end

    test "dispatches credit_note map to CreditNote.from_map/1" do
      map = %{"object" => "credit_note", "id" => "cn_123", "status" => "issued"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.CreditNote{id: "cn_123"} = result
    end

    test "dispatches credit_note_line_item map to CreditNote.LineItem.from_map/1" do
      map = %{
        "object" => "credit_note_line_item",
        "id" => "cnli_123",
        "type" => "invoice_line_item"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.CreditNote.LineItem{id: "cnli_123"} = result
    end

    test "dispatches quote map to Quote.from_map/1" do
      map = %{"object" => "quote", "id" => "qt_123", "status" => "draft"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Quote{id: "qt_123"} = result
    end

    test "dispatches quote_line_item map to Quote.LineItem.from_map/1" do
      map = %{
        "object" => "quote_line_item",
        "id" => "qli_123",
        "description" => "Quoted item"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Quote.LineItem{id: "qli_123"} = result
    end

    test "dispatches setup_attempt map to SetupAttempt.from_map/1" do
      map = %{
        "object" => "setup_attempt",
        "id" => "setatt_123",
        "status" => "succeeded",
        "usage" => "off_session"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.SetupAttempt{id: "setatt_123"} = result
    end

    test "dispatches checkout.session map to Checkout.Session.from_map/1" do
      map = %{"object" => "checkout.session", "id" => "cs_123"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Checkout.Session{id: "cs_123"} = result
    end

    test "dispatches subscription map to Subscription.from_map/1" do
      map = %{"object" => "subscription", "id" => "sub_123"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Subscription{id: "sub_123"} = result
    end

    test "returns unknown object types as raw map" do
      map = %{"object" => "unknown_future_type", "id" => "foo_123"}
      assert ObjectTypes.maybe_deserialize(map) == map
    end

    test "returns maps without 'object' key as raw map" do
      map = %{"id" => "foo_123", "data" => "some_value"}
      assert ObjectTypes.maybe_deserialize(map) == map
    end

    test "returns empty map as raw map" do
      assert ObjectTypes.maybe_deserialize(%{}) == %{}
    end
  end
end
