defmodule LatticeStripe.Test.Fixtures.Refund do
  @moduledoc false

  def refund_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "re_test1234567890abc",
        "object" => "refund",
        "amount" => 2000,
        "currency" => "usd",
        "status" => "succeeded",
        "payment_intent" => "pi_test1234567890abc",
        "charge" => "ch_test1234567890abc",
        "reason" => "requested_by_customer",
        "created" => 1_700_000_000,
        "metadata" => %{},
        "balance_transaction" => "txn_test123",
        "receipt_number" => nil,
        "failure_reason" => nil,
        "failure_balance_transaction" => nil,
        "destination_details" => nil,
        "source_transfer_reversal" => nil,
        "transfer_reversal" => nil
      },
      overrides
    )
  end

  def refund_partial_json(overrides \\ %{}) do
    Map.merge(refund_json(%{"amount" => 500}), overrides)
  end

  def refund_pending_json(overrides \\ %{}) do
    Map.merge(refund_json(%{"status" => "pending"}), overrides)
  end
end
