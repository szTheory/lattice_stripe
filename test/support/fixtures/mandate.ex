defmodule LatticeStripe.Test.Fixtures.Mandate do
  @moduledoc false

  def mandate_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "mandate_test1234567890abc",
        "object" => "mandate",
        "status" => "active",
        "type" => "single_use",
        "livemode" => false,
        "payment_method" => "pm_test1234567890abc",
        "customer_acceptance" => mandate_customer_acceptance_json(),
        "single_use" => mandate_single_use_json(),
        "multi_use" => nil,
        "payment_method_details" => %{
          "card" => %{"network" => "visa", "last4" => "4242"}
        }
      },
      overrides
    )
  end

  def mandate_customer_acceptance_json(overrides \\ %{}) do
    Map.merge(
      %{
        "accepted_at" => 1_700_000_000,
        "type" => "online",
        "online" => %{
          "ip_address" => "127.0.0.1",
          "user_agent" => "Mozilla/5.0"
        },
        "offline" => nil
      },
      overrides
    )
  end

  def mandate_single_use_json(overrides \\ %{}) do
    Map.merge(
      %{
        "amount" => 2_000,
        "currency" => "usd"
      },
      overrides
    )
  end
end
