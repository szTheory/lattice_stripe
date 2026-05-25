defmodule LatticeStripe.Testing.Fixtures.SetupAttempt do
  @moduledoc """
  Canonical raw fixtures for Stripe SetupAttempt objects.
  """

  @spec setup_attempt_json(map()) :: map()
  def setup_attempt_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "setatt_test1234567890abc",
        "object" => "setup_attempt",
        "status" => "succeeded",
        "usage" => "off_session",
        "created" => 1_700_000_000,
        "livemode" => false,
        "setup_intent" => "seti_test1234567890abc",
        "payment_method" => "pm_test1234567890abc",
        "payment_method_details" => %{
          "card" => %{"network" => "visa", "three_d_secure" => nil}
        },
        "setup_error" => nil
      },
      overrides
    )
  end

  @spec setup_attempt_setup_error_json(map()) :: map()
  def setup_attempt_setup_error_json(overrides \\ %{}) do
    Map.merge(
      %{
        "type" => "card_error",
        "code" => "card_declined",
        "message" => "Your card was declined.",
        "decline_code" => "generic_decline",
        "doc_url" => "https://docs.stripe.com/error-codes/card-declined",
        "param" => "payment_method",
        "payment_method" => "pm_test1234567890abc"
      },
      overrides
    )
  end

  @spec setup_attempt_with_error_json(map()) :: map()
  def setup_attempt_with_error_json(overrides \\ %{}) do
    setup_attempt_json(
      Map.merge(
        %{"setup_error" => setup_attempt_setup_error_json()},
        overrides
      )
    )
  end
end
