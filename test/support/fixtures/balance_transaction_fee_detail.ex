defmodule LatticeStripe.Test.Fixtures.BalanceTransactionFeeDetail do
  @moduledoc false

  def application_fee(overrides \\ %{}) do
    Map.merge(
      %{
        "amount" => 30,
        "application" => "ca_test_app",
        "currency" => "usd",
        "description" => "Application fee",
        "type" => "application_fee"
      },
      overrides
    )
  end

  def stripe_fee(overrides \\ %{}) do
    Map.merge(
      %{
        "amount" => 59,
        "application" => nil,
        "currency" => "usd",
        "description" => "Stripe processing fees",
        "type" => "stripe_fee"
      },
      overrides
    )
  end

  def tax(overrides \\ %{}) do
    Map.merge(
      %{
        "amount" => 5,
        "application" => nil,
        "currency" => "usd",
        "description" => "VAT",
        "type" => "tax"
      },
      overrides
    )
  end
end
