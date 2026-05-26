defmodule LatticeStripe.Test.Fixtures.Dispute do
  @moduledoc false

  def dispute_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "dp_test1234567890abc",
        "object" => "dispute",
        "amount" => 1000,
        "balance_transactions" => [],
        "charge" => "ch_test1234567890abc",
        "created" => 1_700_000_000,
        "currency" => "usd",
        "enhanced_eligibility_types" => [],
        "evidence" => dispute_evidence_json(),
        "evidence_details" => dispute_evidence_details_json(),
        "is_charge_refundable" => true,
        "livemode" => false,
        "metadata" => %{},
        "payment_intent" => "pi_test1234567890abc",
        "payment_method_details" => %{
          "type" => "card",
          "card" => %{"brand" => "visa", "network_reason_code" => "4853"}
        },
        "reason" => "fraudulent",
        "status" => "needs_response"
      },
      overrides
    )
  end

  def dispute_evidence_json(overrides \\ %{}) do
    Map.merge(
      %{
        "access_activity_log" => nil,
        "billing_address" => nil,
        "cancellation_policy" => nil,
        "cancellation_policy_disclosure" => nil,
        "cancellation_rebuttal" => nil,
        "customer_communication" => nil,
        "customer_email_address" => nil,
        "customer_name" => nil,
        "customer_purchase_ip" => nil,
        "customer_signature" => nil,
        "duplicate_charge_documentation" => nil,
        "duplicate_charge_explanation" => nil,
        "duplicate_charge_id" => nil,
        "enhanced_evidence" => nil,
        "product_description" => nil,
        "receipt" => nil,
        "refund_policy" => nil,
        "refund_policy_disclosure" => nil,
        "refund_refusal_explanation" => nil,
        "service_date" => nil,
        "service_documentation" => nil,
        "shipping_address" => nil,
        "shipping_carrier" => nil,
        "shipping_date" => nil,
        "shipping_documentation" => nil,
        "shipping_tracking_number" => nil,
        "uncategorized_file" => nil,
        "uncategorized_text" => nil
      },
      overrides
    )
  end

  def dispute_evidence_details_json(overrides \\ %{}) do
    Map.merge(
      %{
        "due_by" => 1_700_000_000,
        "has_evidence" => false,
        "past_due" => false,
        "submission_count" => 0,
        "enhanced_eligibility" => nil
      },
      overrides
    )
  end
end
