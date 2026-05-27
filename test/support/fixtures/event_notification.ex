defmodule LatticeStripe.Test.Fixtures.EventNotification do
  @moduledoc false

  @doc """
  Canonical thin-event notification wire payload (with `related_object` populated).

  Values lifted from RESEARCH.md "Wire-format reference payload" — sourced from
  stripe-node v2 events test fixtures + Stripe Event Destinations docs.

  Encodes RESEARCH.md wire-format corrections:
  - Finding 1: `"object" => "v2.core.event"` (NOT `"v2.core.event_notification"`).
  - Finding 2: `"created"` is an ISO 8601 string (NOT a Unix integer).
  """
  def event_notification_map(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO",
        "object" => "v2.core.event",
        "type" => "v2.core.account.updated",
        "livemode" => false,
        "created" => "2026-03-09T13:00:28.435Z",
        "context" => nil,
        "reason" => %{
          "type" => "request",
          "request" => %{
            "id" => "req_v2y9y15XqG3Futmjg",
            "idempotency_key" => "ik_TgmEI3jHxXt8RFw4jS7ve2QcAReDQWBjPAkAEUm"
          }
        },
        "related_object" => %{
          "id" => "acct_1T93Q4Pmpb34Vto6",
          "type" => "v2.core.account",
          "url" => "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
        }
      },
      overrides
    )
  end

  @doc """
  Variant of `event_notification_map/1` with `"related_object" => nil`.

  Represents snapshot-style v2 events that have no related object — adopters dispatch
  these to `LatticeStripe.Webhook.fetch_event/3` rather than `fetch_related_object/3`.
  """
  def event_notification_map_no_related_object(overrides \\ %{}) do
    event_notification_map(Map.merge(%{"related_object" => nil}, overrides))
  end
end
