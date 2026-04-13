defmodule LatticeStripe.Test.Fixtures.Charge do
  @moduledoc false

  @doc """
  Returns a string-keyed map matching a `/v1/charges/ch_*` retrieve response
  with all Connect-relevant known fields populated with realistic values.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "ch_3OoLqrJ2eZvKYlo20wxYzAbC",
        "object" => "charge",
        "amount" => 2000,
        "amount_captured" => 2000,
        "amount_refunded" => 0,
        "application" => nil,
        "application_fee" => "fee_1OoLqrJ2eZvKYlo2AbCdEfGh",
        "application_fee_amount" => 200,
        "balance_transaction" => "txn_3OoLqrJ2eZvKYlo2BtXyZ",
        "billing_details" => %{
          "address" => nil,
          "email" => nil,
          "name" => nil,
          "phone" => nil
        },
        "captured" => true,
        "created" => 1_700_000_000,
        "currency" => "usd",
        "customer" => "cus_OoLqrJ2eZvKYlo2",
        "description" => "Charge for connect platform fee",
        "destination" => nil,
        "failure_code" => nil,
        "failure_message" => nil,
        "fraud_details" => %{},
        "invoice" => nil,
        "livemode" => false,
        "metadata" => %{},
        "on_behalf_of" => "acct_1Nv0FGQ9RKHgCVdK",
        "outcome" => %{
          "network_status" => "approved_by_network",
          "risk_level" => "normal",
          "seller_message" => "Payment complete.",
          "type" => "authorized"
        },
        "paid" => true,
        "payment_intent" => "pi_3OoLpqJ2eZvKYlo21fGhIjKl",
        "payment_method" => "pm_1OoLqrJ2eZvKYlo2NoPqRsTu",
        "payment_method_details" => %{
          "card" => %{
            "brand" => "visa",
            "last4" => "4242"
          },
          "type" => "card"
        },
        "receipt_email" => nil,
        "receipt_number" => nil,
        "receipt_url" => nil,
        "refunded" => false,
        "refunds" => %{
          "object" => "list",
          "data" => [],
          "has_more" => false,
          "total_count" => 0,
          "url" => "/v1/charges/ch_3OoLqrJ2eZvKYlo20wxYzAbC/refunds"
        },
        "review" => nil,
        "source_transfer" => nil,
        "statement_descriptor" => nil,
        "statement_descriptor_suffix" => nil,
        "status" => "succeeded",
        "transfer_data" => nil,
        "transfer_group" => nil
      },
      overrides
    )
  end

  @doc """
  Like `basic/1` but `balance_transaction` is an expanded object with realistic
  `fee_details` containing a single `application_fee` entry — used to exercise
  the Connect platform-fee reconciliation example from the Phase 18 guide.
  """
  def with_balance_transaction_expanded(overrides \\ %{}) do
    expanded_bt = %{
      "id" => "txn_3OoLqrJ2eZvKYlo2BtXyZ",
      "object" => "balance_transaction",
      "amount" => 2000,
      "currency" => "usd",
      "fee" => 259,
      "fee_details" => [
        %{
          "amount" => 59,
          "application" => nil,
          "currency" => "usd",
          "description" => "Stripe processing fees",
          "type" => "stripe_fee"
        },
        %{
          "amount" => 200,
          "application" => "ca_OoLqrJ2eZvKYlo2PlatformApp",
          "currency" => "usd",
          "description" => "Application fee",
          "type" => "application_fee"
        }
      ],
      "net" => 1741,
      "status" => "available",
      "type" => "charge"
    }

    Map.merge(basic(%{"balance_transaction" => expanded_bt}), overrides)
  end

  @doc """
  Returns a charge with sentinel PII values populated across every field
  the `Inspect` implementation is required to hide. Used to prove the
  hide-list with `refute String.contains?`.
  """
  def with_pii(overrides \\ %{}) do
    Map.merge(
      basic(%{
        "billing_details" => %{
          "address" => %{
            "city" => "SENTINEL_CITY",
            "country" => "US",
            "line1" => "SENTINEL_LINE1",
            "postal_code" => "SENTINEL_ZIP"
          },
          "email" => "sentinel.billing@example.com",
          "name" => "SENTINEL_BILLING_NAME",
          "phone" => "+15555550123"
        },
        "payment_method_details" => %{
          "card" => %{
            "brand" => "visa",
            "last4" => "SENTINEL4242",
            "exp_month" => 12,
            "exp_year" => 2030,
            "fingerprint" => "SENTINEL_FP"
          },
          "type" => "card"
        },
        "fraud_details" => %{
          "stripe_report" => "SENTINEL_FRAUD_REPORT",
          "user_report" => "SENTINEL_USER_REPORT"
        },
        "receipt_email" => "sentinel.receipt@example.com",
        "receipt_number" => "SENTINEL_RCPT_NUM",
        "receipt_url" => "https://pay.stripe.com/receipts/SENTINEL_RECEIPT_PATH"
      }),
      overrides
    )
  end
end
