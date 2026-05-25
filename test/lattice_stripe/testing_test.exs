defmodule LatticeStripe.TestingTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Event, Testing, Webhook}

  alias LatticeStripe.Testing.Fixtures

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
  end
end
