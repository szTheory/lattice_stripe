defmodule LatticeStripe.Test.Fixtures.Payout do
  @moduledoc false

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "po_1OoMpqJ2eZvKYlo20wxYzAbC",
        "object" => "payout",
        "amount" => 5000,
        "application_fee" => nil,
        "application_fee_amount" => nil,
        "arrival_date" => 1_710_000_000,
        "automatic" => true,
        "balance_transaction" => "txn_test_payout_bt",
        "created" => 1_709_900_000,
        "currency" => "usd",
        "description" => "STRIPE PAYOUT",
        "destination" => "ba_test_bank_account_id",
        "failure_balance_transaction" => nil,
        "failure_code" => nil,
        "failure_message" => nil,
        "livemode" => false,
        "metadata" => %{},
        "method" => "standard",
        "original_payout" => nil,
        "reconciliation_status" => "not_applicable",
        "reversed_by" => nil,
        "source_type" => "card",
        "statement_descriptor" => nil,
        "status" => "in_transit",
        "trace_id" => nil,
        "type" => "bank_account"
      },
      overrides
    )
  end

  def with_trace_id(overrides \\ %{}) do
    Map.merge(
      basic(%{
        "trace_id" => %{
          "status" => "supported",
          "value" => "FED12345"
        }
      }),
      overrides
    )
  end

  def pending(overrides \\ %{}) do
    Map.merge(
      basic(%{
        "status" => "pending",
        "trace_id" => %{"status" => "pending", "value" => nil}
      }),
      overrides
    )
  end

  def cancelled(overrides \\ %{}) do
    Map.merge(basic(%{"status" => "canceled"}), overrides)
  end

  def reversed(overrides \\ %{}) do
    Map.merge(basic(%{"status" => "paid", "reversed_by" => "po_reversal123"}), overrides)
  end

  def with_destination_string(overrides \\ %{}) do
    Map.merge(basic(%{"destination" => "ba_test_dest_string"}), overrides)
  end

  def with_destination_expanded(overrides \\ %{}) do
    Map.merge(
      basic(%{
        "destination" => %{
          "id" => "ba_test_dest_expanded",
          "object" => "bank_account",
          "bank_name" => "STRIPE TEST BANK",
          "last4" => "6789",
          "currency" => "usd"
        }
      }),
      overrides
    )
  end

  def list_response(items \\ nil) do
    items = items || [basic()]

    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => "/v1/payouts"
    }
  end
end
