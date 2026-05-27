defmodule LatticeStripe.EventNotificationTest do
  use ExUnit.Case, async: true

  import LatticeStripe.Test.Fixtures.EventNotification

  alias LatticeStripe.EventNotification
  alias LatticeStripe.EventNotification.RelatedObject

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps all known fields correctly" do
      notif = EventNotification.from_map(event_notification_map())

      assert notif.id == "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO"
      assert notif.object == "v2.core.event"
      assert notif.type == "v2.core.account.updated"
      assert notif.created == "2026-03-09T13:00:28.435Z"
      assert notif.livemode == false
      assert notif.context == nil

      assert notif.reason == %{
               "type" => "request",
               "request" => %{
                 "id" => "req_v2y9y15XqG3Futmjg",
                 "idempotency_key" => "ik_TgmEI3jHxXt8RFw4jS7ve2QcAReDQWBjPAkAEUm"
               }
             }
    end

    test "decodes nested related_object map to %RelatedObject{} struct" do
      notif = EventNotification.from_map(event_notification_map())

      assert %RelatedObject{
               id: "acct_1T93Q4Pmpb34Vto6",
               type: "v2.core.account",
               url: "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
             } = notif.related_object
    end

    test "related_object is nil when wire map sets it to nil" do
      notif = EventNotification.from_map(event_notification_map_no_related_object())
      assert notif.related_object == nil
    end

    test "defaults object to 'v2.core.event' when missing" do
      notif = EventNotification.from_map(%{"id" => "evt_abc"})
      assert notif.object == "v2.core.event"
    end

    test "unknown fields go to extra map" do
      map = event_notification_map(%{"custom_field" => "some_value", "another_unknown" => 42})
      notif = EventNotification.from_map(map)

      assert notif.extra == %{"custom_field" => "some_value", "another_unknown" => 42}
    end

    test "missing fields are nil" do
      notif = EventNotification.from_map(%{"id" => "evt_abc"})

      assert notif.type == nil
      assert notif.created == nil
      assert notif.context == nil
      assert notif.livemode == nil
      assert notif.related_object == nil
      assert notif.reason == nil
    end

    test "extra is empty map when no unknown fields" do
      notif = EventNotification.from_map(event_notification_map())
      assert notif.extra == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "shows id, type, object, created, livemode, related_object" do
      notif = EventNotification.from_map(event_notification_map())
      inspected = inspect(notif)

      assert inspected =~ "id:"
      assert inspected =~ "type:"
      assert inspected =~ "object:"
      assert inspected =~ "created:"
      assert inspected =~ "livemode:"
      assert inspected =~ "related_object:"

      assert inspected =~ "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO"
      assert inspected =~ "v2.core.account.updated"
      assert inspected =~ "v2.core.event"
      assert inspected =~ "2026-03-09T13:00:28.435Z"
    end

    test "does NOT show extra" do
      notif =
        EventNotification.from_map(
          event_notification_map(%{"custom_secret_field" => "leaky_value"})
        )

      inspected = inspect(notif)

      refute inspected =~ "extra:"
      refute inspected =~ "custom_secret_field"
      refute inspected =~ "leaky_value"
    end

    test "does NOT show reason (contains request id + idempotency_key)" do
      notif = EventNotification.from_map(event_notification_map())
      inspected = inspect(notif)

      refute inspected =~ "reason:"
      refute inspected =~ "req_v2y9y15XqG3Futmjg"
      refute inspected =~ "ik_TgmEI3jHxXt8RFw4jS7ve2QcAReDQWBjPAkAEUm"
    end

    test "Pitfall 4 security regression — does not leak credentials" do
      # Per RESEARCH Pitfall 4: notification structs are pure serializable data,
      # and Inspect output must never expose Client/api_key/secret-key fragments.
      # Build a notification whose extra map includes credential-shaped strings
      # to assert the Inspect impl hides them via the :extra-suppression rule.
      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "api_key" => "sk_live_DEADBEEF_NEVER_LEAK_ME",
            "client" => "%LatticeStripe.Client<sk_live_...>"
          })
        )

      inspected = inspect(notif)

      refute inspected =~ "sk_"
      refute inspected =~ "api_key"
      refute inspected =~ "%LatticeStripe.Client"
    end
  end

  # ---------------------------------------------------------------------------
  # RelatedObject.from_map/1
  # ---------------------------------------------------------------------------

  describe "RelatedObject.from_map/1" do
    test "returns nil for nil input" do
      assert RelatedObject.from_map(nil) == nil
    end

    test "maps id, type, url for a wire-format map" do
      result =
        RelatedObject.from_map(%{
          "id" => "cus_123",
          "type" => "customer",
          "url" => "/v1/customers/cus_123"
        })

      assert %RelatedObject{
               id: "cus_123",
               type: "customer",
               url: "/v1/customers/cus_123",
               extra: %{}
             } = result
    end

    test "unknown fields go to extra map" do
      result =
        RelatedObject.from_map(%{
          "id" => "cus_123",
          "type" => "customer",
          "url" => "/v1/customers/cus_123",
          "future_field" => "future_value"
        })

      assert result.extra == %{"future_field" => "future_value"}
    end

    test "missing fields default to nil" do
      result = RelatedObject.from_map(%{"id" => "cus_123"})

      assert result.id == "cus_123"
      assert result.type == nil
      assert result.url == nil
    end
  end

  describe "RelatedObject Inspect" do
    test "shows id, type, url" do
      obj =
        RelatedObject.from_map(%{
          "id" => "acct_1T93Q4Pmpb34Vto6",
          "type" => "v2.core.account",
          "url" => "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
        })

      inspected = inspect(obj)

      assert inspected =~ "id:"
      assert inspected =~ "type:"
      assert inspected =~ "url:"
      assert inspected =~ "acct_1T93Q4Pmpb34Vto6"
      assert inspected =~ "v2.core.account"
    end

    test "hides extra when empty" do
      obj =
        RelatedObject.from_map(%{
          "id" => "cus_123",
          "type" => "customer",
          "url" => "/v1/customers/cus_123"
        })

      inspected = inspect(obj)
      refute inspected =~ "extra:"
    end
  end
end
