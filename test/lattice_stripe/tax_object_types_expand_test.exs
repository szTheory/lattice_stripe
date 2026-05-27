defmodule LatticeStripe.TaxObjectTypesExpandTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Customer, ObjectTypes, Product, Tax, TaxId}
  alias LatticeStripe.Tax.Calculation.LineItem
  alias LatticeStripe.Testing.Fixtures.TaxCalculation
  alias LatticeStripe.Testing.Fixtures.TaxId, as: TaxIdFixtures
  alias LatticeStripe.Testing.Fixtures.TaxTransaction

  test "Tax.Calculation.from_map/1 expands customer to %Customer{}" do
    calc =
      Tax.Calculation.from_map(
        TaxCalculation.tax_calculation_json(%{
          "customer" => %{
            "object" => "customer",
            "id" => "cus_tax_expand",
            "email" => "tax@example.com"
          }
        })
      )

    assert %Customer{id: "cus_tax_expand", email: "tax@example.com"} = calc.customer
  end

  test "Tax.Calculation.LineItem.from_map/1 expands product via ObjectTypes" do
    line_item =
      LineItem.from_map(
        TaxCalculation.tax_calculation_line_item_json(%{
          "product" => %{
            "object" => "product",
            "id" => "prod_tax_expand",
            "name" => "Taxable widget"
          }
        })
      )

    assert %Product{id: "prod_tax_expand", name: "Taxable widget"} = line_item.product
  end

  test "Tax.Transaction.from_map/1 expands customer to %Customer{}" do
    txn =
      Tax.Transaction.from_map(
        TaxTransaction.tax_transaction_json(%{
          "customer" => %{
            "object" => "customer",
            "id" => "cus_txn_expand",
            "email" => "txn@example.com"
          }
        })
      )

    assert %Customer{id: "cus_txn_expand", email: "txn@example.com"} = txn.customer
  end

  test "ObjectTypes.maybe_deserialize/1 on tax_id wire map returns %TaxId{}" do
    map = TaxIdFixtures.tax_id_json(%{"id" => "txi_expand_test"})
    assert %TaxId{id: "txi_expand_test"} = ObjectTypes.maybe_deserialize(map)
  end
end
