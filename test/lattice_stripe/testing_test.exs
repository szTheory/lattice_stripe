defmodule LatticeStripe.TestingTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{
    Billing,
    CreditNote,
    Customer,
    Dispute,
    Entitlements,
    Event,
    EventNotification,
    File,
    FileLink,
    Invoice,
    Mandate,
    PaymentIntent,
    Quote,
    SetupAttempt,
    Subscription,
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
      assert is_map(Fixtures.MeterEvent.meter_event_json())
      assert is_map(Fixtures.MeterEventSummary.meter_event_summary_json())
      assert is_map(Fixtures.MeterEventSummary.meter_event_summary_list_json())
      assert is_map(Fixtures.MeterErrorReport.meter_error_report_json())
      assert is_map(Fixtures.MeterErrorReport.meter_error_report_event_json())
      assert is_map(Fixtures.MeterErrorReport.no_meter_found_meter_error_report_event_json())
    end

    test "meter builder overrides win over the canonical value" do
      overridden =
        Fixtures.MeterEventSummary.meter_event_summary_json(%{"aggregated_value" => 99.0})

      assert overridden["aggregated_value"] == 99.0
      assert overridden["object"] == "billing.meter_event_summary"
    end

    test "promoted core-billing builders are callable at arity 0 (OBJ-03 empty-input edge)" do
      # Q2 = move-and-rename: these three moved out of test/support/ with no private twin,
      # and Subscription's base builder is `subscription_json/1`, NOT `basic/1` — the name
      # is semver-covered public API from the Hex 1.8.0 tag onward.
      assert is_map(Fixtures.Customer.customer_json())
      assert is_map(Fixtures.PaymentIntent.payment_intent_json())
      assert is_map(Fixtures.Subscription.subscription_json())
      assert is_map(Fixtures.Subscription.subscription_with_items_json())
      assert is_map(Fixtures.Subscription.paused_subscription_json())
      assert is_map(Fixtures.Subscription.canceled_subscription_json())
    end

    test "core-billing builder overrides win over the canonical value" do
      overridden = Fixtures.Customer.customer_json(%{"email" => "override@example.com"})
      assert overridden["email"] == "override@example.com"
      assert overridden["object"] == "customer"
    end

    test "OBJ-03 ordering edge: a caller override beats both the variant and the base" do
      # with_items/1 composes on subscription_json/1, and each layer is a Map.merge where
      # the LAST map wins. The caller's map is merged into the variant's map before that
      # result reaches the base, so a caller key must beat:
      #   (a) the variant's own key      -> "items", set by with_items/1
      #   (b) the base canonical value   -> "status", set by subscription_json/1
      # If either assertion flips, the composition chain has been reordered and callers
      # silently lose the ability to override.
      overridden =
        Fixtures.Subscription.subscription_with_items_json(%{
          "items" => %{"object" => "list", "data" => [], "has_more" => false},
          "status" => "past_due"
        })

      assert overridden["items"]["data"] == []
      assert overridden["status"] == "past_due"

      # Un-overridden keys from both layers still come through.
      assert overridden["object"] == "subscription"

      assert Fixtures.Subscription.subscription_with_items_json()["items"]["data"] |> length() ==
               2
    end

    test "the authored invoice builder is callable at arity 0 (OBJ-03 empty-input edge)" do
      # Invoice is the one fixture with no prior source anywhere — it was authored,
      # not promoted. Q2 = move-and-rename fixes the builder name as `invoice_json/1`.
      assert is_map(Fixtures.Invoice.invoice_json())
    end

    test "OBJ-03 empty edge: the default invoice carries an EMPTY lines envelope" do
      # The empty collection is the canonical default, not an unfilled placeholder. A
      # populated default would silently change what every `lines` assertion means, and
      # callers who want line items pass them explicitly as an override.
      lines = Fixtures.Invoice.invoice_json()["lines"]

      assert lines["object"] == "list"
      assert lines["data"] == []
      assert lines["has_more"] == false
    end

    test "invoice builder overrides win over the canonical value" do
      overridden = Fixtures.Invoice.invoice_json(%{"status" => "paid"})
      assert overridden["status"] == "paid"
      assert overridden["object"] == "invoice"
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
      # Backwards-compat regression: explicitly requires the snapshot helper to
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
      # This load-bearing end-to-end assertion proves the EventNotification types,
      # signature verification/decoding, and signed-payload builder are mutually consistent.
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
      # nil related_object_data must produce a notification with
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

      # The Stripe object has no id property, so the struct has
      # no :id field. The public wrapper must not reintroduce one.
      refute Map.has_key?(summary, :id)
    end

    test "return typed meter structs from the promoted public fixtures" do
      # Match on :event_name, NOT :object — %Billing.MeterEvent{} has no :object field
      # (minimal struct), so result.object would raise KeyError.
      assert %Billing.MeterEvent{event_name: "api_call"} =
               Testing.meter_event(Fixtures.MeterEvent.meter_event_json())

      assert %Billing.MeterEventSummary{id: "mtrusg_123"} =
               Testing.meter_event_summary(Fixtures.MeterEventSummary.meter_event_summary_json())
    end

    test "return a typed Feature struct from the promoted public fixture" do
      # `entitlements.feature` is deliberately absent from @object_map (it is
      # not a webhook data.object payload), so this wrapper is the only typed decode
      # path the public surface offers for it.
      assert %Entitlements.Feature{id: "feat_123", lookup_key: "premium_support"} =
               Testing.feature(Fixtures.Entitlements.feature_json())
    end

    test "return a typed MeterErrorReport struct, with :meter always nil (from_map contract)" do
      report =
        Testing.meter_error_report(Fixtures.MeterErrorReport.meter_error_report_json())

      assert %Billing.MeterErrorReport{
               developer_message_summary: "There are 902 invalid events"
             } = report

      assert report.reason.error_count == 902

      # `data` never names the meter. from_map/1 structurally cannot fill
      # :meter — only from_event/1 can. The wrapper must not paper over that.
      assert report.meter == nil
    end

    test "return typed core-billing structs from the promoted public fixtures" do
      assert %Customer{id: "cus_test1234567890"} =
               Testing.customer(Fixtures.Customer.customer_json())

      assert %PaymentIntent{id: "pi_test1234567890abc"} =
               Testing.payment_intent(Fixtures.PaymentIntent.payment_intent_json())

      assert %Subscription{id: "sub_test1234567890"} =
               Testing.subscription(Fixtures.Subscription.subscription_json())
    end

    test "return a typed Invoice struct from the authored public fixture" do
      assert %Invoice{id: "in_test1234567890"} =
               Testing.invoice(Fixtures.Invoice.invoice_json())
    end

    test "keep wrapper shapes explicit instead of option-driven" do
      refute function_exported?(Testing, :generate_webhook_event, 4)
      refute function_exported?(Testing, :generate_webhook_payload, 4)
      # snapshot and thin-event paths stay separate — no :shape opt overload
      # that would push the thin helper to a higher arity.
      refute function_exported?(Testing, :generate_thin_event_payload, 4)
    end
  end
end
