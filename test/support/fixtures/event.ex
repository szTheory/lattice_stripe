defmodule LatticeStripe.Test.Fixtures.Event do
  @moduledoc false

  def event_map(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "evt_1NxGkW2eZvKYlo2CvN93zMW1",
        "object" => "event",
        "type" => "payment_intent.succeeded",
        "api_version" => "2026-03-25.dahlia",
        "created" => 1_680_000_000,
        "livemode" => false,
        "pending_webhooks" => 1,
        "request" => %{"id" => "req_abc123", "idempotency_key" => nil},
        "data" => %{
          "object" => %{
            "id" => "pi_abc123",
            "object" => "payment_intent",
            "amount" => 2000,
            "currency" => "usd",
            "status" => "succeeded"
          }
        },
        "account" => nil,
        "context" => nil
      },
      overrides
    )
  end
end
