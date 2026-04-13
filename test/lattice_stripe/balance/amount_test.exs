defmodule LatticeStripe.Balance.AmountTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Balance.{Amount, SourceTypes}

  describe "cast/1" do
    test "happy path: decodes amount, currency, source_types" do
      amt =
        Amount.cast(%{
          "amount" => 12_345,
          "currency" => "usd",
          "source_types" => %{"card" => 10_000, "bank_account" => 2_345, "fpx" => 0}
        })

      assert %Amount{amount: 12_345, currency: "usd", source_types: %SourceTypes{} = st} = amt
      assert st.card == 10_000
      assert st.bank_account == 2_345
      assert amt.extra == %{}
    end

    test "nil returns nil" do
      assert Amount.cast(nil) == nil
    end

    test "nil source_types stays nil" do
      amt = Amount.cast(%{"amount" => 1, "currency" => "usd", "source_types" => nil})
      assert amt.source_types == nil
    end

    test "net_available (from instant_available[]) lands in :extra" do
      amt =
        Amount.cast(%{
          "amount" => 2_000,
          "currency" => "usd",
          "source_types" => %{"card" => 2_000, "bank_account" => 0, "fpx" => 0},
          "net_available" => [%{"amount" => 1_950, "destination" => "ba_123"}]
        })

      assert amt.amount == 2_000
      assert is_list(amt.extra["net_available"])
      assert [%{"amount" => 1_950}] = amt.extra["net_available"]
    end
  end

  describe "F-001" do
    test "unknown future field survives in :extra" do
      amt =
        Amount.cast(%{
          "amount" => 1,
          "currency" => "usd",
          "source_types" => %{"card" => 1},
          "future_field" => "hello"
        })

      assert amt.extra["future_field"] == "hello"
    end
  end
end
