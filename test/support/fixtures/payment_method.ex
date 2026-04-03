defmodule LatticeStripe.Test.Fixtures.PaymentMethod do
  @moduledoc false

  def payment_method_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "pm_test1234567890abc",
        "object" => "payment_method",
        "type" => "card",
        "customer" => "cus_test456",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{},
        "card" => %{
          "brand" => "visa",
          "last4" => "4242",
          "exp_month" => 12,
          "exp_year" => 2030,
          "fingerprint" => "abc123"
        },
        "billing_details" => %{
          "email" => "test@example.com",
          "name" => "Test User"
        }
      },
      overrides
    )
  end
end
