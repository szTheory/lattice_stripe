defmodule LatticeStripe.EventTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestSupport
  import LatticeStripe.Test.Fixtures.Event, only: [event_map: 0, event_map: 1]

  alias LatticeStripe.{Error, Event, List, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps all known fields correctly" do
      map = event_map()
      event = Event.from_map(map)

      assert event.id == "evt_1NxGkW2eZvKYlo2CvN93zMW1"
      assert event.object == "event"
      assert event.type == "payment_intent.succeeded"
      assert event.api_version == "2026-03-25.dahlia"
      assert event.created == 1_680_000_000
      assert event.livemode == false
      assert event.pending_webhooks == 1
      assert event.request == %{"id" => "req_abc123", "idempotency_key" => nil}
      assert event.account == nil
      assert event.context == nil
    end

    test "data is kept as raw map" do
      map = event_map()
      event = Event.from_map(map)

      assert event.data == %{
               "object" => %{
                 "id" => "pi_abc123",
                 "object" => "payment_intent",
                 "amount" => 2000,
                 "currency" => "usd",
                 "status" => "succeeded"
               }
             }
    end

    test "defaults object to 'event' when missing" do
      event = Event.from_map(%{"id" => "evt_abc"})
      assert event.object == "event"
    end

    test "unknown fields go to extra map" do
      map = event_map(%{"custom_field" => "some_value", "another_unknown" => 42})
      event = Event.from_map(map)

      assert event.extra == %{"custom_field" => "some_value", "another_unknown" => 42}
    end

    test "missing fields are nil" do
      event = Event.from_map(%{"id" => "evt_abc"})

      assert event.type == nil
      assert event.account == nil
      assert event.context == nil
      assert event.data == nil
      assert event.request == nil
    end

    test "extra is empty map when no unknown fields" do
      event = Event.from_map(event_map())
      assert event.extra == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "shows id, type, object, created, livemode" do
      event = Event.from_map(event_map())
      inspected = inspect(event)

      assert inspected =~ "evt_1NxGkW2eZvKYlo2CvN93zMW1"
      assert inspected =~ "payment_intent.succeeded"
      assert inspected =~ "event"
      assert inspected =~ "1680000000"
      assert inspected =~ "livemode"
    end

    test "does NOT show data" do
      event = Event.from_map(event_map())
      inspected = inspect(event)

      # data field contents (the nested payment intent object) should not be shown
      refute inspected =~ "pi_abc123"
      # amount and currency from data.object also should not appear
      refute inspected =~ "\"amount\""
      refute inspected =~ "\"currency\""
    end

    test "does NOT show request" do
      event = Event.from_map(event_map())
      inspected = inspect(event)

      refute inspected =~ "req_abc123"
    end

    test "does NOT show account" do
      event = Event.from_map(event_map(%{"account" => "acct_123"}))
      inspected = inspect(event)

      refute inspected =~ "acct_123"
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/events/:id and returns {:ok, %Event{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/events/evt_1NxGkW2eZvKYlo2CvN93zMW1")
        ok_response(event_map())
      end)

      assert {:ok, %Event{id: "evt_1NxGkW2eZvKYlo2CvN93zMW1"}} =
               Event.retrieve(client, "evt_1NxGkW2eZvKYlo2CvN93zMW1")
    end

    test "returns {:error, %Error{}} when event not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Event.retrieve(client, "evt_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve!/3
  # ---------------------------------------------------------------------------

  describe "retrieve!/3" do
    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Event.retrieve!(client, "evt_missing")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/events and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/events")
        ok_response(list_json([event_map()], "/v1/events"))
      end)

      assert {:ok, %Response{data: %List{data: [%Event{id: "evt_1NxGkW2eZvKYlo2CvN93zMW1"}]}}} =
               Event.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Event.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # list!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([event_map()], "/v1/events"))
      end)

      assert %Response{data: %List{data: [%Event{}]}} = Event.list!(client)
    end
  end
end
