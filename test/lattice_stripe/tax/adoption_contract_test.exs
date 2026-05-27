defmodule LatticeStripe.Tax.AdoptionContractTest do
  @moduledoc """
  Phase 51 adoption contract — automated replacement for manual UAT.

  Authority: `.planning/milestones/v1.6-MILESTONE-AUDIT.md` (Phase 51 UAT checklist).
  Wire-path CRUDL is covered by `tax_id_test.exs` (Mox) and
  `integration/tax_id_integration_test.exs` (stripe-mock).

  CI gate:

      mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors

  Full Phase 51 slice (unit + integration):

      mix test test/lattice_stripe/tax/ test/lattice_stripe/tax_id_test.exs \\
        test/lattice_stripe/tax_object_types_expand_test.exs \\
        test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/testing_test.exs \\
        test/integration/tax_id_integration_test.exs --include integration
  """

  use ExUnit.Case, async: true

  alias LatticeStripe.{ObjectTypes, TaxId, Testing}
  alias LatticeStripe.TaxId.Verification
  alias LatticeStripe.Testing.Fixtures

  @tax_sources [
    "lib/lattice_stripe/tax/calculation.ex",
    "lib/lattice_stripe/tax/transaction.ex",
    "lib/lattice_stripe/tax/settings.ex",
    "lib/lattice_stripe/tax/registration.ex",
    "lib/lattice_stripe/tax_id.ex"
  ]

  describe "UAT-1/2: TaxId module surface (wire paths in tax_id_test.exs)" do
    test "exports dual-path CRUDL and rejects update/search" do
      assert function_exported?(TaxId, :create, 3)
      assert function_exported?(TaxId, :create, 4)
      assert function_exported?(TaxId, :retrieve, 3)
      assert function_exported?(TaxId, :retrieve, 4)
      assert function_exported?(TaxId, :list, 3)
      assert function_exported?(TaxId, :list, 4)
      assert function_exported?(TaxId, :delete, 3)
      assert function_exported?(TaxId, :delete, 4)

      refute function_exported?(TaxId, :update, 3)
      refute function_exported?(TaxId, :search, 2)
    end
  end

  describe "UAT-3: TaxId PII-redacted Inspect" do
    test "redacts value and nested verification PII" do
      tax_id = %TaxId{
        id: "txi_test123",
        type: "eu_vat",
        value: "DE123456789",
        verification: %Verification{
          status: :verified,
          verified_name: "Acme GmbH",
          verified_address: "Berlin, DE"
        }
      }

      output = inspect(tax_id)

      refute output =~ "DE123456789"
      refute output =~ "Acme GmbH"
      assert output =~ "[REDACTED]"
    end
  end

  describe "UAT-4: Testing fixtures produce typed structs" do
    test "tax_calculation/1, tax_transaction/1, and tax_id/1 round-trip from_map" do
      assert %LatticeStripe.Tax.Calculation{} =
               Testing.tax_calculation(Fixtures.TaxCalculation.tax_calculation_json())

      assert %LatticeStripe.Tax.Transaction{} =
               Testing.tax_transaction(Fixtures.TaxTransaction.tax_transaction_json())

      assert %TaxId{} = Testing.tax_id(Fixtures.TaxId.tax_id_json())
    end

    test "guides/testing.md documents Tax fixture workflow" do
      testing = File.read!("guides/testing.md")

      assert testing =~ "## Tax"
      assert testing =~ "tax_calculation_json"
      assert testing =~ "tax_transaction_json"
      assert testing =~ "tax_id_json"
      assert testing =~ "LatticeStripe.Testing.tax_calculation"
      assert testing =~ "Mox"
    end
  end

  describe "UAT-5: Canonical tax guide published" do
    test "guides/tax.md meets adoption contract" do
      tax_guide = File.read!("guides/tax.md")
      line_count = tax_guide |> String.split("\n", trim: false) |> length()

      assert line_count in 280..400
      assert tax_guide =~ "out of SDK scope"
      assert tax_guide =~ "Invoice.AutomaticTax"
      assert tax_guide =~ "Calculation.create"
      assert tax_guide =~ "create_from_calculation"
      assert tax_guide =~ "create_reversal"
      assert tax_guide =~ "LatticeStripe.TaxId"
      assert tax_guide =~ "testing.md"

      docs = LatticeStripe.MixProject.project()[:docs]
      groups = docs[:groups_for_extras] |> Map.new()

      assert "guides/tax.md" in docs[:extras]
      assert "guides/tax.md" in groups["Canonical Guides"]
    end
  end

  describe "UAT-6: Tax moduledoc guide links" do
    test "all five Tax modules link guides/tax.md with no Phase 51 placeholders" do
      for path <- @tax_sources do
        source = File.read!(path)
        assert source =~ "guides/tax.md", "expected guide link in #{path}"
        refute source =~ "Phase 51", "placeholder still present in #{path}"
      end
    end
  end

  describe "UAT-7: README and discovery ladder" do
    test "README and downstream docs link guides/tax.md" do
      readme = File.read!("README.md")
      payments = File.read!("guides/payments.md")
      jtbd = File.read!("guides/user-flows-and-jtbd.md")
      recipes = File.read!("guides/recipes.md")

      assert readme =~ "guides/tax.md"
      assert payments =~ "tax.md"
      assert jtbd =~ "tax.md"
      assert recipes =~ "tax.md"
    end
  end

  describe "UAT-8: ObjectTypes five-type Tax family" do
    test "fetch_module/1 resolves all five Tax types including tax_id" do
      assert ObjectTypes.fetch_module("tax.calculation") == {:ok, LatticeStripe.Tax.Calculation}
      assert ObjectTypes.fetch_module("tax.transaction") == {:ok, LatticeStripe.Tax.Transaction}
      assert ObjectTypes.fetch_module("tax.settings") == {:ok, LatticeStripe.Tax.Settings}
      assert ObjectTypes.fetch_module("tax.registration") == {:ok, LatticeStripe.Tax.Registration}
      assert ObjectTypes.fetch_module("tax_id") == {:ok, TaxId}
    end
  end
end
