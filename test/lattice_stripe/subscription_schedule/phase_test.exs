defmodule LatticeStripe.SubscriptionSchedule.PhaseTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Invoice.AutomaticTax
  alias LatticeStripe.SubscriptionSchedule.{AddInvoiceItem, Phase, PhaseItem}

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert Phase.from_map(nil) == nil
    end

    test "decodes a full phase with automatic_tax + items + add_invoice_items" do
      map = %{
        "add_invoice_items" => [
          %{"price" => "price_setup", "quantity" => 1}
        ],
        "application_fee_percent" => nil,
        "automatic_tax" => %{"enabled" => true, "status" => "complete", "liability" => nil},
        "billing_cycle_anchor" => nil,
        "collection_method" => "charge_automatically",
        "currency" => "usd",
        "default_payment_method" => "pm_phase_test",
        "default_tax_rates" => [],
        "description" => "First phase",
        "discounts" => [],
        "end_date" => 1_702_678_400,
        "invoice_settings" => nil,
        "items" => [
          %{"price" => "price_test123", "quantity" => 1}
        ],
        "iterations" => 12,
        "metadata" => %{},
        "on_behalf_of" => nil,
        "proration_behavior" => "create_prorations",
        "start_date" => 1_700_000_000,
        "transfer_data" => nil,
        "trial_continuation" => nil,
        "trial_end" => nil
      }

      result = Phase.from_map(map)

      assert %Phase{} = result
      assert %AutomaticTax{enabled: true, status: "complete"} = result.automatic_tax
      assert [%PhaseItem{price: "price_test123", quantity: 1}] = result.items
      assert [%AddInvoiceItem{price: "price_setup", quantity: 1}] = result.add_invoice_items
      assert result.start_date == 1_700_000_000
      assert result.end_date == 1_702_678_400
      assert result.iterations == 12
      assert result.proration_behavior == "create_prorations"
      assert result.currency == "usd"
      assert result.description == "First phase"
      assert result.collection_method == "charge_automatically"
      assert result.default_payment_method == "pm_phase_test"
      assert result.extra == %{}
    end

    test "dual usage — default_settings-shaped map has nil timeline fields" do
      # default_settings shape: no start_date/end_date/iterations/trial_end/trial_continuation
      map = %{
        "application_fee_percent" => nil,
        "automatic_tax" => %{"enabled" => false, "liability" => nil},
        "billing_cycle_anchor" => "automatic",
        "collection_method" => "charge_automatically",
        "default_payment_method" => "pm_default_test",
        "invoice_settings" => %{"days_until_due" => nil},
        "transfer_data" => nil
      }

      result = Phase.from_map(map)

      assert %Phase{} = result
      assert result.start_date == nil
      assert result.end_date == nil
      assert result.iterations == nil
      assert result.trial_end == nil
      assert result.trial_continuation == nil
      assert result.billing_cycle_anchor == "automatic"
      assert result.collection_method == "charge_automatically"
      assert result.default_payment_method == "pm_default_test"
      assert %AutomaticTax{enabled: false} = result.automatic_tax
    end

    test "puts unknown fields in :extra" do
      result =
        Phase.from_map(%{
          "currency" => "usd",
          "future_field" => "hello"
        })

      assert result.currency == "usd"
      assert result.extra == %{"future_field" => "hello"}
    end

    test "items is empty list when input items is empty list" do
      result = Phase.from_map(%{"items" => []})
      assert result.items == []
    end

    test "items is nil when input has no items key" do
      result = Phase.from_map(%{})
      assert result.items == nil
    end
  end
end
