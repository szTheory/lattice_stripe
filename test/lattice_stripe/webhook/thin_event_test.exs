defmodule LatticeStripe.Webhook.ThinEventTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  import LatticeStripe.Test.Fixtures.EventNotification, only: [event_notification_map: 0]

  import LatticeStripe.Test.Fixtures.Customer, only: [customer_json: 1]
  import LatticeStripe.Test.Fixtures.Event, only: [event_map: 1]

  alias LatticeStripe.{Customer, Event, EventNotification, Testing, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject

  setup :verify_on_exit!

  @secret "whsec_test_thinevent"

  # ---------------------------------------------------------------------------
  # DB1: verify happy path (Testing → parse)
  # ---------------------------------------------------------------------------

  describe "verify happy path (Testing → parse)" do
    test "generate_thin_event_payload + parse_event_notification returns typed EventNotification" do
      # Zero HTTP — parse is pure (verify-only, no fetch). :verify_on_exit! enforces
      # that no LatticeStripe.MockTransport.request/1 call is made in this test.
      related_object_data = %{
        "id" => "acct_1",
        "type" => "v2.core.account",
        "url" => "/v2/core/accounts/acct_1"
      }

      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          related_object_data,
          secret: @secret
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, @secret)

      assert notif.type == "v2.core.account.updated"
      assert notif.object == "v2.core.event"
      assert notif.livemode == false

      assert match?(
               %RelatedObject{id: "acct_1", type: "v2.core.account"},
               notif.related_object
             )

      assert notif.related_object.url == "/v2/core/accounts/acct_1"
    end
  end

  # ---------------------------------------------------------------------------
  # DB2: fetch-after-verify roundtrip — Event branch (parse → fetch_event)
  # ---------------------------------------------------------------------------

  describe "fetch-after-verify roundtrip — Event branch (parse → fetch_event)" do
    test "chained generate → parse → fetch_event/3 returns typed %Event{}" do
      # Generate a snapshot-style v2 event (no related_object) for this branch.
      # Adopters dispatch these to fetch_event/3 rather than fetch_related_object/3.
      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.event.snapshot",
          nil,
          secret: @secret
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, @secret)

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v2/core/events/#{notif.id}")
        # RESEARCH Finding 3 regression-lock: the v2 fetch MUST NOT hit the v1 path.
        # "/v1/events/" appears only in docstrings; the runtime path is /v2/core/events/{id}.
        refute String.contains?(req.url, "/v1/events/")
        ok_response(event_map(%{"id" => notif.id}))
      end)

      assert {:ok, %Event{id: id}} = Webhook.fetch_event(client, notif)
      assert id == notif.id
    end
  end

  # ---------------------------------------------------------------------------
  # DB3: fetch-after-verify roundtrip — RelatedObject branch (parse → fetch_related_object)
  # ---------------------------------------------------------------------------

  describe "fetch-after-verify roundtrip — RelatedObject branch (parse → fetch_related_object)" do
    test "chained generate → parse → fetch_related_object/3 returns typed %Customer{}" do
      # Use a Customer-typed related_object so fetch_related_object/3 dispatches
      # through ObjectTypes to LatticeStripe.Customer.from_map/1.
      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.customer.updated",
          %{"id" => "cus_1", "type" => "customer", "url" => "/v1/customers/cus_1"},
          secret: @secret
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, @secret)

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        # related_object.url is used verbatim as the request path.
        assert String.contains?(req.url, "/v1/customers/cus_1")
        ok_response(customer_json(%{"id" => "cus_1"}))
      end)

      assert {:ok, %Customer{id: "cus_1"}} = Webhook.fetch_related_object(client, notif)
    end
  end

  # ---------------------------------------------------------------------------
  # DB4: malformed-payload failure boundary
  # ---------------------------------------------------------------------------

  describe "malformed-payload failure boundary" do
    test "wrong secret returns {:error, :no_matching_signature}" do
      # Zero HTTP — signature verify fails before any decode/fetch.
      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          event_notification_map()["related_object"],
          secret: @secret
        )

      assert {:error, :no_matching_signature} =
               Webhook.parse_event_notification(payload, sig_header, "whsec_wrong")
    end

    test "missing header returns {:error, :missing_header}" do
      # Zero HTTP — nil header is detected before HMAC comparison.
      assert {:error, :missing_header} =
               Webhook.parse_event_notification("{}", nil, @secret)
    end

    test "malformed header returns {:error, :invalid_header}" do
      # Zero HTTP — unparseable header format fails before HMAC comparison.
      assert {:error, :invalid_header} =
               Webhook.parse_event_notification("{}", "not-a-real-header", @secret)
    end

    test "bad JSON post-verify currently raises Jason.DecodeError (Phase 47 contract)" do
      # This test documents the Phase 47 contract honestly: when the HMAC signature
      # is valid but the payload body is not valid JSON, Jason.decode! raises.
      # This is WR-02 — the v1 surface (`construct_event/4`) has the same behaviour.
      # WR-02 is intentionally deferred to v1.5.x / v1.6 with its own discuss-phase;
      # if WR-02 is resolved, this test gets rewritten in lockstep with the fix.
      bad_payload = "not-json-at-all"
      sig_header = Webhook.generate_test_signature(bad_payload, @secret)

      assert_raise Jason.DecodeError, fn ->
        Webhook.parse_event_notification(bad_payload, sig_header, @secret)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DB5: tolerance: 0 reconciled semantics on the thin-event surface
  # ---------------------------------------------------------------------------

  describe "tolerance: 0 reconciled semantics on the thin-event surface" do
    test "stale timestamp + tolerance: 0 returns {:ok, notif} (WEBFIX-01 extends to thin events)" do
      # Phase 47 D-03 / WEBFIX-01: tolerance: 0 disables the timestamp staleness
      # check entirely (returns :ok regardless of age). This test extends the
      # WEBFIX-01 regression net to parse_event_notification/4 specifically —
      # proving that the fix applies equally to both webhook surfaces (construct_event/4
      # and parse_event_notification/4).
      # Zero HTTP — parse-only path; :verify_on_exit! enforces no transport calls.
      old_ts = System.system_time(:second) - 86_400

      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          nil,
          secret: @secret,
          timestamp: old_ts
        )

      assert {:ok, %EventNotification{}} =
               Webhook.parse_event_notification(payload, sig_header, @secret, tolerance: 0)
    end

    test "stale timestamp + default tolerance still returns {:error, :timestamp_expired}" do
      # Counterpart to the tolerance: 0 test above — confirms that without the opt,
      # the default tolerance (300 seconds) correctly rejects a 24-hour-old timestamp.
      # This is the other branch of WEBFIX-01: opt-in disables the check; default
      # still enforces it. Zero HTTP — fails at verify before any decode/fetch.
      old_ts = System.system_time(:second) - 86_400

      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          nil,
          secret: @secret,
          timestamp: old_ts
        )

      assert {:error, :timestamp_expired} =
               Webhook.parse_event_notification(payload, sig_header, @secret)
    end
  end
end
