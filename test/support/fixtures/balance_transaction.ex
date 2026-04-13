defmodule LatticeStripe.Test.Fixtures.BalanceTransaction do
  @moduledoc false

  alias LatticeStripe.Test.Fixtures.BalanceTransactionFeeDetail, as: FeeDetailFixture

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "txn_test1234567890abc",
        "object" => "balance_transaction",
        "amount" => 2_000,
        "available_on" => 1_700_086_400,
        "created" => 1_700_000_000,
        "currency" => "usd",
        "description" => "Test charge",
        "exchange_rate" => nil,
        "fee" => 59,
        "fee_details" => [FeeDetailFixture.stripe_fee()],
        "net" => 1_941,
        "reporting_category" => "charge",
        "source" => "ch_test1234567890abc",
        "status" => "available",
        "type" => "charge"
      },
      overrides
    )
  end

  def with_application_fee(overrides \\ %{}) do
    Map.merge(
      basic(%{
        "fee" => 89,
        "net" => 1_911,
        "fee_details" => [
          FeeDetailFixture.stripe_fee(),
          FeeDetailFixture.application_fee(),
          FeeDetailFixture.tax()
        ]
      }),
      overrides
    )
  end

  def with_source_string(overrides \\ %{}) do
    Map.merge(basic(%{"source" => "ch_test1234567890abc"}), overrides)
  end

  def with_source_expanded(overrides \\ %{}) do
    Map.merge(
      basic(%{
        "source" => %{
          "id" => "ch_test1234567890abc",
          "object" => "charge",
          "amount" => 2_000,
          "currency" => "usd"
        }
      }),
      overrides
    )
  end

  @doc """
  A list-response batch simulating BalanceTransaction.list filtered by payout.
  Produces 3 entries — one application_fee, one stripe_fee, one tax.
  """
  def payout_batch(payout_id \\ "po_test1234567890abc") do
    [
      basic(%{"id" => "txn_test_a", "source" => payout_id, "type" => "payout"}),
      with_application_fee(%{"id" => "txn_test_b"}),
      basic(%{"id" => "txn_test_c", "type" => "charge"})
    ]
  end
end
