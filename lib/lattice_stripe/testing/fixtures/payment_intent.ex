defmodule LatticeStripe.Testing.Fixtures.PaymentIntent do
  @moduledoc """
  Canonical raw fixtures for Stripe PaymentIntent objects.
  """

  @spec payment_intent_json(map()) :: map()
  def payment_intent_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "pi_test1234567890abc",
        "object" => "payment_intent",
        "amount" => 2000,
        "currency" => "usd",
        "status" => "requires_payment_method",
        "client_secret" => "pi_test1234567890abc_secret_abc",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{}
      },
      overrides
    )
  end
end
