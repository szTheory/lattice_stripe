defmodule LatticeStripe.ObjectTypesTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.ObjectTypes
  alias LatticeStripe.Test.Fixtures.Metering.MeterErrorReport, as: MeterErrorReportFixture
  alias LatticeStripe.Testing.Fixtures.Entitlements, as: EntitlementsFixture

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

    test "dispatches the public entitlement fixture to ActiveEntitlement.from_map/1" do
      # End-to-end tracer: the map comes from the PUBLIC fixture module that ships in the
      # Hex tarball, so this single assertion crosses both the registry row and the newly
      # published surface.
      map = EntitlementsFixture.active_entitlement_json()
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Entitlements.ActiveEntitlement{id: "ent_123"} = result
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

    test "dispatches tax.calculation map to Tax.Calculation.from_map/1" do
      map = %{"object" => "tax.calculation", "id" => "taxcalc_x", "currency" => "usd"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Calculation{id: "taxcalc_x"} = result
    end

    test "dispatches tax.transaction map to Tax.Transaction.from_map/1" do
      map = %{"object" => "tax.transaction", "id" => "tax_x", "type" => "transaction"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Transaction{id: "tax_x"} = result
    end

    test "dispatches tax.settings map to Tax.Settings.from_map/1" do
      map = %{
        "object" => "tax.settings",
        "status" => "active",
        "defaults" => %{"tax_behavior" => "exclusive"}
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Settings{status: :active} = result
    end

    test "dispatches tax.registration map to Tax.Registration.from_map/1" do
      map = %{
        "object" => "tax.registration",
        "id" => "taxreg_123",
        "country" => "US",
        "status" => "active"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Registration{id: "taxreg_123", status: :active} = result
    end

    test "dispatches tax_id map to TaxId.from_map/1" do
      map = %{"object" => "tax_id", "id" => "txi_123", "type" => "eu_vat"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.TaxId{id: "txi_123"} = result
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

    test "returns the meter error report payload unchanged — it has no object key" do
      # The structural reason the registry can never deserialize this payload:
      # it is event `data`, not an object, so it carries no "object" key for the
      # dispatch head to match. It comes back as the raw map it went in as.
      data = MeterErrorReportFixture.basic()

      result = ObjectTypes.maybe_deserialize(data)

      assert result == data
      refute is_struct(result)
    end
  end

  describe "fetch_module/1" do
    test "returns {:ok, LatticeStripe.Customer} for 'customer'" do
      assert ObjectTypes.fetch_module("customer") == {:ok, LatticeStripe.Customer}
    end

    test "returns {:ok, LatticeStripe.Invoice} for 'invoice'" do
      assert ObjectTypes.fetch_module("invoice") == {:ok, LatticeStripe.Invoice}
    end

    test "returns :error for unknown v2-namespaced type 'v2.core.account'" do
      # This is the v2-namespaced type which is intentionally NOT in @object_map
      # and will trigger the typed-error gate in fetch_related_object/3 (Phase 47 D-05).
      assert ObjectTypes.fetch_module("v2.core.account") == :error
    end

    test "returns :error for nil" do
      assert ObjectTypes.fetch_module(nil) == :error
    end

    test "returns :error for an empty string" do
      assert ObjectTypes.fetch_module("") == :error
    end

    test "carries no billing.meter_error_report key — the dispatch cannot reach it" do
      # maybe_deserialize/1 dispatches on `%{"object" => object_type}`. The
      # v1.billing.meter.error_report_triggered `data` payload has no "object"
      # key at all, so a registry row for it would be a DEAD key — present,
      # never reached, and assumed to work by the next contributor who sees it.
      # LatticeStripe.Billing.MeterErrorReport.from_event/1 must be called
      # explicitly. Phase 65's OBJ-01 excludes this key for the same reason;
      # this test is what keeps the exclusion from being quietly undone.
      refute Map.has_key?(ObjectTypes.object_map(), "billing.meter_error_report")
      assert ObjectTypes.fetch_module("billing.meter_error_report") == :error
    end

    test "resolves all five Tax family object types" do
      assert ObjectTypes.fetch_module("tax.calculation") == {:ok, LatticeStripe.Tax.Calculation}
      assert ObjectTypes.fetch_module("tax.transaction") == {:ok, LatticeStripe.Tax.Transaction}
      assert ObjectTypes.fetch_module("tax.settings") == {:ok, LatticeStripe.Tax.Settings}
      assert ObjectTypes.fetch_module("tax.registration") == {:ok, LatticeStripe.Tax.Registration}
      assert ObjectTypes.fetch_module("tax_id") == {:ok, LatticeStripe.TaxId}
    end
  end
end
