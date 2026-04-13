defmodule LatticeStripe.Account.IndividualTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Individual
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert Individual.from_map(nil) == nil
    end

    test "returns struct with all known fields nil and extra: %{} for empty map" do
      result = Individual.from_map(%{})
      assert %Individual{} = result
      assert result.ssn_last_4 == nil
      assert result.first_name == nil
      assert result.last_name == nil
      assert result.email == nil
      assert result.extra == %{}
    end

    test "casts known fields correctly" do
      result =
        Individual.from_map(%{
          "first_name" => "Jane",
          "last_name" => "Doe",
          "email" => "jane@test.invalid",
          "ssn_last_4" => "1234",
          "political_exposure" => "none",
          "gender" => "female"
        })

      assert result.first_name == "Jane"
      assert result.last_name == "Doe"
      assert result.email == "jane@test.invalid"
      assert result.ssn_last_4 == "1234"
      assert result.political_exposure == "none"
      assert result.gender == "female"
    end

    test "unknown fields land in :extra" do
      result = Individual.from_map(%{"first_name" => "Jane", "zzz_new_field" => "future"})
      assert result.first_name == "Jane"
      assert result.extra == %{"zzz_new_field" => "future"}
    end

    test "full fixture round-trip (individual is nil in company fixture)" do
      # In the fixture, individual is nil because business_type is "company"
      assert AccountFixtures.basic()["individual"] == nil
      assert Individual.from_map(nil) == nil
    end
  end

  describe "Inspect redaction (T-17-01)" do
    test "ssn_last_4, first_name, last_name, email, dob, id_number, address, phone, metadata are redacted" do
      individual = %Individual{
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@test.invalid",
        ssn_last_4: "1234",
        dob: %{"day" => 1, "month" => 1, "year" => 1990},
        id_number: "999-99-9999",
        address: %{"line1" => "123 Main St"},
        phone: "+15555550199",
        political_exposure: "none",
        verification: %{"status" => "verified"}
      }

      output = inspect(individual)

      refute output =~ "1234"
      refute output =~ "Jane"
      refute output =~ "Doe"
      refute output =~ "jane@test.invalid"
      refute output =~ "999-99-9999"
      refute output =~ "123 Main St"
      assert output =~ "[REDACTED]"
    end

    test "non-PII fields (political_exposure, verification) are still visible" do
      individual = %Individual{
        ssn_last_4: "1234",
        political_exposure: "none",
        verification: %{"status" => "verified"}
      }

      output = inspect(individual)

      assert output =~ "political_exposure"
      assert output =~ "verification"
    end

    test "nil PII fields do not print [REDACTED]" do
      individual = %Individual{ssn_last_4: nil, first_name: nil, last_name: nil}
      output = inspect(individual)
      refute output =~ "[REDACTED]"
    end

    test "dob values are redacted when dob is set" do
      individual = %Individual{
        dob: %{"day" => 1, "month" => 1, "year" => 1990}
      }

      output = inspect(individual)
      refute output =~ "1990"
      assert output =~ "[REDACTED]"
    end
  end
end
