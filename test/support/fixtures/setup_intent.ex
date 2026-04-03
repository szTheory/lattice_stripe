defmodule LatticeStripe.Test.Fixtures.SetupIntent do
  @moduledoc false

  def setup_intent_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "seti_test1234567890abc",
        "object" => "setup_intent",
        "status" => "requires_payment_method",
        "usage" => "off_session",
        "client_secret" => "seti_test1234567890abc_secret_abc",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{}
      },
      overrides
    )
  end
end
