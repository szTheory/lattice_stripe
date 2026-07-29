defmodule LatticeStripe.TestingTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{
    Billing,
    CreditNote,
    Dispute,
    Entitlements,
    Event,
    EventNotification,
    File,
    FileLink,
    Mandate,
    Quote,
    SetupAttempt,
    Testing,
    Webhook
  }

  alias LatticeStripe.EventNotification.RelatedObject
  alias LatticeStripe.Testing.Fixtures
  import LatticeStripe.Test.Fixtures.EventNotification, only: [event_notification_map: 0]

  describe "public fixture builders" do
    test "expose canonical raw-map builders for each v1.3 family" do
      assert is_map(Fixtures.File.file_json())
      assert is_map(Fixtures.FileLink.file_link_json())
      assert is_map(Fixtures.Dispute.dispute_json())
      assert is_map(Fixtures.CreditNote.credit_note_json())
      assert is_map(Fixtures.Mandate.mandate_json())
      assert is_map(Fixtures.SetupAttempt.setup_attempt_json())
      assert is_map(Fixtures.Quote.quote_json())
    end

    test "promoted entitlement builders are callable at arity 0 (OBJ-02 empty-input edge)" do
      # Every promoted builder defaults `overrides` to %{}, so a no-argument call must
      # return the canonical map rather than raising on a missing argument.
      assert is_map(Fixtures.Entitlements.active_entitlement_json())
      assert is_map(Fixtures.Entitlements.feature_json())
      assert is_map(Fixtures.Entitlements.active_entitlement_summary_json())
      assert is_map(Fixtures.Entitlements.active_entitlement_list_json())
    end

    test "entitlement builder overrides win over the canonical value" do
      overridden = Fixtures.Entitlements.active_entitlement_json(%{"id" => "ent_override"})
      assert overridden["id"] == "ent_override"
      assert overridden["object"] == "entitlements.active_entitlement"
    end

    test "active_entitlement_list_json/0 returns a one-element list envelope" do
      envelope = Fixtures.Entitlements.active_entitlement_list_json()
      assert envelope["object"] == "list"
      assert length(envelope["data"]) == 1
    end

    test "promoted meter builders are callable at arity 0 (OBJ-02 empty-input edge)" do
      # Q1 = flat-three: exactly these three meter fixtures are public, and they are flat
      # (Testing.Fixtures.MeterEvent), never nested under a Metering namespace.
      assert is_map(Fixtures.MeterEvent.basic())
      assert is_map(Fixtures.MeterEventSummary.basic())
      assert is_map(Fixtures.MeterEventSummary.list_response())
      assert is_map(Fixtures.MeterErrorReport.basic())
      assert is_map(Fixtures.MeterErrorReport.event())
      assert is_map(Fixtures.MeterErrorReport.no_meter_found_event())
    end

    test "meter builder overrides win over the canonical value" do
      overridden = Fixtures.MeterEventSummary.basic(%{"aggregated_value" => 99.0})
      assert overridden["aggregated_value"] == 99.0
      assert overridden["object"] == "billing.meter_event_summary"
    end
  end

  describe "generate_webhook_event/2" do
    test "returns an %Event{} struct with matching type field" do
      event = Testing.generate_webhook_event("payment_intent.succeeded")
      assert %Event{} = event
      assert event.type == "payment_intent.succeeded"
    end

    test "returned event has id starting with evt_test_" do
      event = Testing.generate_webhook_event("customer.created")
      assert String.starts_with?(event.id, "evt_test_")
    end
  end

  describe "generate_webhook_event/3" do
    test "with object_data populates event.data[\"object\"]" do
      object_data = Fixtures.Dispute.dispute_json()
      event = Testing.generate_webhook_event("payment_intent.succeeded", object_data)
      assert event.data["object"] == object_data
    end

    test "with :id option overrides default id" do
      event = Testing.generate_webhook_event("customer.created", %{}, id: "evt_custom_123")
      assert event.id == "evt_custom_123"
    end

    test "with :livemode option sets livemode field" do
      event = Testing.generate_webhook_event("payment_intent.succeeded", %{}, livemode: true)
      assert event.livemode == true
    end

    test "with :livemode false sets livemode to false" do
      event = Testing.generate_webhook_event("payment_intent.succeeded", %{}, livemode: false)
      assert event.livemode == false
    end
  end

  describe "generate_webhook_payload/3" do
    test "returns a {binary, binary} tuple" do
      result = Testing.generate_webhook_payload("customer.created", %{}, secret: "whsec_test")
      assert {payload, sig_header} = result
      assert is_binary(payload)
      assert is_binary(sig_header)
    end

    test "signature round-trips through Webhook.construct_event/4 successfully" do
      secret = "whsec_test_secret_round_trip"
      type = "payment_intent.succeeded"
      object_data = Fixtures.Quote.quote_json()

      {payload, sig_header} =
        Testing.generate_webhook_payload(type, object_data, secret: secret)

      assert {:ok, %Event{} = event} = Webhook.construct_event(payload, sig_header, secret)
      assert event.type == type
      assert event.data["object"]["id"] == object_data["id"]
    end

    test "with custom :timestamp embeds that timestamp in signature" do
      secret = "whsec_timestamp_test"
      fixed_ts = System.system_time(:second)

      {_payload, sig_header} =
        Testing.generate_webhook_payload("customer.created", %{},
          secret: secret,
          timestamp: fixed_ts
        )

      assert sig_header =~ "t=#{fixed_ts}"
    end

    test "still produces 'object' => 'event' (NOT 'v2.core.event') — D-06 backwards-compat" do
      # Backwards-compat regression: D-06 explicitly requires the snapshot helper to
      # remain unchanged. A future contributor adding a :shape opt overload that
      # retargets behavior to thin-event shape would break this assertion.
      {payload, _sig} =
        Testing.generate_webhook_payload("customer.created", %{"id" => "cus_1"},
          secret: "whsec_test"
        )

      decoded = Jason.decode!(payload)
      assert decoded["object"] == "event"
      refute decoded["object"] == "v2.core.event"
    end
  end

  describe "generate_thin_event_payload/3" do
    test "produces a payload that round-trips through Webhook.parse_event_notification/4" do
      # The load-bearing end-to-end assertion for Phase 47: this proves plans 01
      # (EventNotification types), 02 (parse_event_notification/4 decode + verify),
      # and 05 (Testing helper signed-payload builder) are mutually consistent.
      secret = "whsec_test_roundtrip"

      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          %{
            "id" => "acct_test_123",
            "type" => "v2.core.account",
            "url" => "/v2/core/accounts/acct_test_123"
          },
          secret: secret
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, secret)

      assert notif.type == "v2.core.account.updated"
      assert notif.object == "v2.core.event"
      assert notif.livemode == false

      assert match?(
               %RelatedObject{
                 id: "acct_test_123",
                 type: "v2.core.account",
                 url: "/v2/core/accounts/acct_test_123"
               },
               notif.related_object
             )
    end

    test "accepts nil for related_object_data (snapshot-style v2 events)" do
      # D-06: nil related_object_data must produce a notification with
      # related_object: nil. Adopters dispatch these to fetch_event/3.
      secret = "whsec_test_nil"

      {payload, sig_header} =
        Testing.generate_thin_event_payload("v2.core.event.something", nil, secret: secret)

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, secret)

      assert notif.related_object == nil
    end

    test "encodes created as ISO 8601 string from the :timestamp opt" do
      # RESEARCH Finding 2: wire `created` is an ISO 8601 string derived from the
      # same Unix-seconds timestamp used for HMAC signing. Lock the encoding.
      secret = "whsec_test_ts"
      fixed_ts = 1_741_524_028
      expected_iso = DateTime.from_unix!(fixed_ts) |> DateTime.to_iso8601()

      {payload, sig_header} =
        Testing.generate_thin_event_payload("v2.core.account.updated", nil,
          secret: secret,
          timestamp: fixed_ts
        )

      decoded = Jason.decode!(payload)
      assert decoded["created"] == expected_iso
      # Signature embeds the same Unix-seconds timestamp (verify both ends agree).
      assert sig_header =~ "t=#{fixed_ts}"
    end

    test "uses 'v2.core.event' as object field (NOT 'v2.core.event_notification')" do
      # RESEARCH Finding 1: wire object value is "v2.core.event" — same string on
      # both notifications and fully-fetched events. Regression-lock the wire value.
      {payload, _sig} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          %{"id" => "acct_test_1", "type" => "v2.core.account", "url" => "/v2/x"},
          secret: "whsec_test"
        )

      decoded = Jason.decode!(payload)
      assert decoded["object"] == "v2.core.event"
      refute decoded["object"] == "v2.core.event_notification"
    end

    test "raises KeyError if :secret opt is missing" do
      # Keyword.pop!/2 raises KeyError on a missing required key — same contract
      # as generate_webhook_payload/3 (which uses the same Keyword.pop!).
      assert_raise KeyError, fn ->
        Testing.generate_thin_event_payload("v2.core.account.updated", nil, [])
      end
    end

    test "with :id, :context, :livemode opts overrides defaults" do
      secret = "whsec_test_opts"

      {payload, sig_header} =
        Testing.generate_thin_event_payload("v2.core.account.updated", nil,
          secret: secret,
          id: "evt_test_custom_id",
          context: "ctx_abc",
          livemode: true
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, secret)

      assert notif.id == "evt_test_custom_id"
      assert notif.context == "ctx_abc"
      assert notif.livemode == true
    end
  end

  describe "event_notification/1" do
    test "builds %EventNotification{} from a raw map (no signing, no HTTP)" do
      notif = Testing.event_notification(event_notification_map())

      assert match?(
               %EventNotification{
                 id: "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO",
                 type: "v2.core.account.updated"
               },
               notif
             )
    end
  end

  describe "typed wrappers" do
    test "return typed structs from canonical fixture maps" do
      assert %File{} = Testing.file(Fixtures.File.file_json())
      assert %FileLink{} = Testing.file_link(Fixtures.FileLink.file_link_json())
      assert %Dispute{} = Testing.dispute(Fixtures.Dispute.dispute_json())
      assert %CreditNote{} = Testing.credit_note(Fixtures.CreditNote.credit_note_json())
      assert %Mandate{} = Testing.mandate(Fixtures.Mandate.mandate_json())
      assert %SetupAttempt{} = Testing.setup_attempt(Fixtures.SetupAttempt.setup_attempt_json())
      assert %Quote{} = Testing.quote(Fixtures.Quote.quote_json())
    end

    test "return typed entitlement structs from the promoted public fixtures" do
      assert %Entitlements.ActiveEntitlement{id: "ent_123"} =
               Testing.active_entitlement(Fixtures.Entitlements.active_entitlement_json())

      summary =
        Testing.active_entitlement_summary(
          Fixtures.Entitlements.active_entitlement_summary_json()
        )

      assert %Entitlements.ActiveEntitlementSummary{customer: "cus_ABC123customer"} = summary

      # ENT-05 / Phase 63 F-02: the Stripe object has no id property, so the struct has
      # no :id field. The public wrapper must not reintroduce one.
      refute Map.has_key?(summary, :id)
    end

    test "return typed meter structs from the promoted public fixtures" do
      # Match on :event_name, NOT :object — %Billing.MeterEvent{} has no :object field
      # (EVENT-05 minimal struct), so result.object would raise KeyError.
      assert %Billing.MeterEvent{event_name: "api_call"} =
               Testing.meter_event(Fixtures.MeterEvent.basic())

      assert %Billing.MeterEventSummary{id: "mtrusg_123"} =
               Testing.meter_event_summary(Fixtures.MeterEventSummary.basic())
    end

    test "keep wrapper shapes explicit instead of option-driven" do
      refute function_exported?(Testing, :generate_webhook_event, 4)
      refute function_exported?(Testing, :generate_webhook_payload, 4)
      # D-06: snapshot and thin-event paths stay separate — no :shape opt overload
      # that would push the thin helper to a higher arity.
      refute function_exported?(Testing, :generate_thin_event_payload, 4)
    end
  end
end
