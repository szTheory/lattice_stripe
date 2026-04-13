defmodule LatticeStripe.Account.CompanyTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Company
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert Company.from_map(nil) == nil
    end

    test "returns struct with all known fields nil and extra: %{} for empty map" do
      result = Company.from_map(%{})
      assert %Company{} = result
      assert result.name == nil
      assert result.tax_id == nil
      assert result.phone == nil
      assert result.extra == %{}
    end

    test "casts known fields correctly" do
      result = Company.from_map(%{
        "name" => "Acme Corp",
        "tax_id" => "00-0000000",
        "phone" => "+15555550101",
        "directors_provided" => true,
        "owners_provided" => true,
        "structure" => nil
      })

      assert result.name == "Acme Corp"
      assert result.tax_id == "00-0000000"
      assert result.phone == "+15555550101"
      assert result.directors_provided == true
      assert result.owners_provided == true
      assert result.structure == nil
    end

    test "unknown fields land in :extra" do
      result = Company.from_map(%{"name" => "Acme", "zzz_new_field" => "future"})
      assert result.name == "Acme"
      assert result.extra == %{"zzz_new_field" => "future"}
    end

    test "full fixture round-trip" do
      result = AccountFixtures.basic()["company"] |> Company.from_map()
      assert %Company{} = result
      assert result.name == "Acme Corp"
      assert result.directors_provided == true
    end
  end

  describe "Inspect redaction (T-17-01)" do
    test "tax_id, vat_id, phone, address, address_kana, address_kanji are redacted" do
      company = %Company{
        name: "Acme Corp",
        tax_id: "00-0000000",
        phone: "+15555550101",
        address: %{"line1" => "123 Main St", "city" => "SF"},
        directors_provided: true,
        structure: nil
      }

      output = inspect(company)

      refute output =~ "00-0000000"
      refute output =~ "+15555550101"
      refute output =~ "123 Main St"
      assert output =~ "[REDACTED]"
    end

    test "non-PII fields (name, structure, directors_provided) are still visible" do
      company = %Company{
        name: "Acme Corp",
        tax_id: "00-0000000",
        directors_provided: true,
        structure: "sole_proprietorship"
      }

      output = inspect(company)

      assert output =~ "name"
      assert output =~ "directors_provided"
    end

    test "nil PII fields do not print [REDACTED]" do
      company = %Company{name: "Acme", tax_id: nil, phone: nil}
      output = inspect(company)
      refute output =~ "[REDACTED]"
    end
  end
end
