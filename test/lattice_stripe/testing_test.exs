defmodule LatticeStripe.TestingTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Event, Testing, Webhook}

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
      object_data = %{"id" => "pi_123", "amount" => 2000, "status" => "succeeded"}
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
      object_data = %{"id" => "pi_test123", "status" => "succeeded"}

      {payload, sig_header} =
        Testing.generate_webhook_payload(type, object_data, secret: secret)

      assert {:ok, %Event{} = event} = Webhook.construct_event(payload, sig_header, secret)
      assert event.type == type
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
