defmodule LatticeStripe.Balance.SourceTypesTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Balance.SourceTypes

  describe "cast/1" do
    test "happy path: all three known fields populated" do
      st = SourceTypes.cast(%{"card" => 10_000, "bank_account" => 2_000, "fpx" => 345})

      assert %SourceTypes{
               card: 10_000,
               bank_account: 2_000,
               fpx: 345,
               extra: extra
             } = st

      assert extra == %{}
    end

    test "nil returns nil" do
      assert SourceTypes.cast(nil) == nil
    end

    test "unknown payment-method keys preserved in :extra (typed-inner-open-outer)" do
      st =
        SourceTypes.cast(%{
          "card" => 10_000,
          "bank_account" => 2_000,
          "fpx" => 345,
          "ach_credit_transfer" => 5_000,
          "link" => 999
        })

      assert st.card == 10_000
      assert st.extra == %{"ach_credit_transfer" => 5_000, "link" => 999}
    end

    test "missing keys default to nil" do
      st = SourceTypes.cast(%{"card" => 100})

      assert st.card == 100
      assert st.bank_account == nil
      assert st.fpx == nil
      assert st.extra == %{}
    end
  end

  describe "F-001 round-trip" do
    test "unknown future field survives in :extra" do
      raw = %{"card" => 1, "future_method" => 42}
      st = SourceTypes.cast(raw)

      assert st.card == 1
      assert st.extra["future_method"] == 42
    end
  end
end
