defmodule LatticeStripe.Account.TosAcceptanceTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.TosAcceptance
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert TosAcceptance.from_map(nil) == nil
    end

    test "returns struct with all known fields nil and extra: %{} for empty map" do
      result = TosAcceptance.from_map(%{})
      assert %TosAcceptance{} = result
      assert result.date == nil
      assert result.ip == nil
      assert result.service_agreement == nil
      assert result.user_agent == nil
      assert result.extra == %{}
    end

    test "casts known fields correctly" do
      result = TosAcceptance.from_map(%{
        "date" => 1_700_000_000,
        "ip" => "203.0.113.42",
        "service_agreement" => "full",
        "user_agent" => "Mozilla/5.0 Test"
      })

      assert result.date == 1_700_000_000
      assert result.ip == "203.0.113.42"
      assert result.service_agreement == "full"
      assert result.user_agent == "Mozilla/5.0 Test"
      assert result.extra == %{}
    end

    test "unknown fields land in :extra" do
      result = TosAcceptance.from_map(%{"date" => 1_700_000_000, "zzz_new_field" => "future"})
      assert result.date == 1_700_000_000
      assert result.extra == %{"zzz_new_field" => "future"}
    end

    test "full fixture round-trip" do
      result = AccountFixtures.basic()["tos_acceptance"] |> TosAcceptance.from_map()
      assert %TosAcceptance{} = result
      assert result.ip == "203.0.113.42"
      assert result.service_agreement == "full"
    end
  end

  describe "Inspect redaction (T-17-01)" do
    test "ip and user_agent are redacted in Inspect output" do
      tos = %TosAcceptance{
        date: 1_700_000_000,
        ip: "203.0.113.42",
        service_agreement: "full",
        user_agent: "Mozilla/5.0 Test"
      }

      output = inspect(tos)

      refute output =~ "203.0.113.42"
      refute output =~ "Mozilla/5.0 Test"
      assert output =~ "[REDACTED]"
    end

    test "non-PII fields (date, service_agreement) are still visible in Inspect output" do
      tos = %TosAcceptance{
        date: 1_700_000_000,
        ip: "203.0.113.42",
        service_agreement: "full",
        user_agent: "Mozilla/5.0 Test"
      }

      output = inspect(tos)

      assert output =~ "date"
      assert output =~ "service_agreement"
    end

    test "nil PII fields do not print [REDACTED]" do
      tos = %TosAcceptance{date: 1_700_000_000, service_agreement: "full", ip: nil, user_agent: nil}
      output = inspect(tos)
      refute output =~ "[REDACTED]"
    end
  end
end
