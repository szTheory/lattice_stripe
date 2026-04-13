defmodule LatticeStripe.BalanceTransaction.FeeDetailTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BalanceTransaction.FeeDetail
  alias LatticeStripe.Test.Fixtures.BalanceTransactionFeeDetail, as: Fx

  describe "cast/1" do
    test "happy path: all five known fields populated" do
      fd = FeeDetail.cast(Fx.application_fee())

      assert %FeeDetail{
               amount: 30,
               application: "ca_test_app",
               currency: "usd",
               description: "Application fee",
               type: "application_fee",
               extra: %{}
             } = fd
    end

    test "unknown future field preserved in :extra" do
      fd = FeeDetail.cast(Fx.stripe_fee(%{"future_field" => "hello"}))

      assert fd.type == "stripe_fee"
      assert fd.extra["future_field"] == "hello"
    end

    test "nil returns nil" do
      assert FeeDetail.cast(nil) == nil
    end

    test "missing fields default to nil" do
      fd = FeeDetail.cast(%{"amount" => 100})
      assert fd.amount == 100
      assert fd.type == nil
      assert fd.application == nil
    end
  end

  describe "reconciliation pattern" do
    test "Enum.filter by :type extracts only matching entries" do
      fees =
        [Fx.stripe_fee(), Fx.application_fee(), Fx.tax()]
        |> Enum.map(&FeeDetail.cast/1)

      application_fees =
        Enum.filter(fees, &(&1.type == "application_fee"))

      assert [%FeeDetail{type: "application_fee", amount: 30}] = application_fees
    end
  end
end
