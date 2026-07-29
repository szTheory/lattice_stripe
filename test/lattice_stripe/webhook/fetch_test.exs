defmodule LatticeStripe.Webhook.FetchTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Event, only: [event_map: 1]
  import LatticeStripe.Test.Fixtures.EventNotification
  import LatticeStripe.Testing.Fixtures.Customer, only: [customer_json: 1]

  alias LatticeStripe.{Customer, Error, Event, EventNotification, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # fetch_event/3 (THIN-02)
  # ---------------------------------------------------------------------------

  describe "fetch_event/3" do
    test "sends GET /v2/core/events/{id} and returns {:ok, %Event{}}" do
      client = test_client()
      notif = EventNotification.from_map(event_notification_map())

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v2/core/events/#{notif.id}")
        # RESEARCH Finding 3 regression-lock: MUST NOT use the v1 path.
        refute String.contains?(req.url, "/v1/events/")
        ok_response(event_map(%{"id" => notif.id}))
      end)

      assert {:ok, %Event{id: id}} = Webhook.fetch_event(client, notif)
      assert id == notif.id
    end

    test "accepts bare String.t() id form" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v2/core/events/evt_test_123")
        refute String.contains?(req.url, "/v1/events/")
        ok_response(event_map(%{"id" => "evt_test_123"}))
      end)

      assert {:ok, %Event{id: "evt_test_123"}} =
               Webhook.fetch_event(client, "evt_test_123")
    end

    test "returns {:error, :no_event_id} for %EventNotification{id: nil} (no HTTP)" do
      client = test_client()

      # No expect(LatticeStripe.MockTransport, ...) call — :verify_on_exit!
      # enforces that zero transport requests are made on this code path.
      assert {:error, :no_event_id} =
               Webhook.fetch_event(client, %EventNotification{id: nil})
    end

    test "honors :api_version opt" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        # Per-request :stripe_version override is forwarded via Client.request/2.
        # The Stripe-Version request header is built from the effective version.
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "stripe-version" and v == "2024-09-30.acacia"
               end)

        ok_response(event_map(%{"id" => "evt_test_123"}))
      end)

      assert {:ok, %Event{}} =
               Webhook.fetch_event(client, "evt_test_123", stripe_version: "2024-09-30.acacia")
    end

    test "honors :idempotency_key opt" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        # Per-request idempotency_key opt is forwarded via Client.request/2 and
        # surfaces as the Idempotency-Key request header.
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik_test_phase47"
               end)

        ok_response(event_map(%{"id" => "evt_test_123"}))
      end)

      assert {:ok, %Event{}} =
               Webhook.fetch_event(client, "evt_test_123", idempotency_key: "ik_test_phase47")
    end

    test "decodes v2 payload with related_object map into %RelatedObject{} on returned Event" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(
          event_map(%{
            "id" => "evt_test_v2",
            "related_object" => %{
              "id" => "cus_1",
              "type" => "customer",
              "url" => "/v1/customers/cus_1"
            }
          })
        )
      end)

      assert {:ok,
              %Event{
                related_object: %RelatedObject{
                  id: "cus_1",
                  type: "customer",
                  url: "/v1/customers/cus_1"
                }
              }} = Webhook.fetch_event(client, "evt_test_v2")
    end

    test "returns {:error, %Error{}} on HTTP error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Webhook.fetch_event(client, "evt_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_event!/3 (THIN-02 bang variant)
  # ---------------------------------------------------------------------------

  describe "fetch_event!/3" do
    test "returns %Event{} on happy path" do
      client = test_client()
      notif = EventNotification.from_map(event_notification_map())

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(event_map(%{"id" => notif.id}))
      end)

      assert %Event{id: id} = Webhook.fetch_event!(client, notif)
      assert id == notif.id
    end

    test "raises %LatticeStripe.Error{} on HTTP error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Webhook.fetch_event!(client, "evt_test_123")
      end
    end

    test "raises %LatticeStripe.Error{type: :invalid_request_error} on {:error, :no_event_id}" do
      client = test_client()
      # No transport expect — :verify_on_exit! ensures no HTTP request was made.

      assert_raise Error, ~r/EventNotification id is nil/, fn ->
        Webhook.fetch_event!(client, %EventNotification{id: nil})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_related_object/3 (THIN-03)
  # ---------------------------------------------------------------------------

  describe "fetch_related_object/3" do
    test "returns {:ok, %Customer{}} for known related_object.type" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "cus_1",
              "type" => "customer",
              "url" => "/v1/customers/cus_1"
            }
          })
        )

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        # related_object.url is used verbatim as the request path.
        assert String.contains?(req.url, "/v1/customers/cus_1")
        ok_response(customer_json(%{"id" => "cus_1"}))
      end)

      assert {:ok, %Customer{id: "cus_1"}} = Webhook.fetch_related_object(client, notif)
    end

    test "returns {:error, {:unknown_object_type, type}} BEFORE any HTTP call (D-05 fail-fast)" do
      client = test_client()

      # `"v2.core.account"` is NOT in `LatticeStripe.ObjectTypes.@object_map`
      # (intentionally — phase 47 plan 01 task 2 acceptance criteria).
      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "acct_1",
              "type" => "v2.core.account",
              "url" => "/v2/core/accounts/acct_1"
            }
          })
        )

      # No expect(LatticeStripe.MockTransport, ...) — :verify_on_exit! enforces
      # zero transport requests on this typed-error fail-fast path.
      assert {:error, {:unknown_object_type, "v2.core.account"}} =
               Webhook.fetch_related_object(client, notif)
    end

    test "returns {:error, :no_related_object} when related_object is nil" do
      client = test_client()
      notif = EventNotification.from_map(event_notification_map_no_related_object())

      # No expect — :verify_on_exit! verifies no transport call.
      assert {:error, :no_related_object} = Webhook.fetch_related_object(client, notif)
    end

    test "honors :expand opt (flows through Client.request/2 merge_expand machinery)" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "cus_1",
              "type" => "customer",
              "url" => "/v1/customers/cus_1"
            }
          })
        )

      expect(LatticeStripe.MockTransport, :request, fn req ->
        # Client.request/2 merges :expand into the params and serializes them
        # into the URL query string as expand[0]=...&expand[1]=...
        assert String.contains?(req.url, "expand")
        assert String.contains?(req.url, "customer")
        assert String.contains?(req.url, "invoice")
        ok_response(customer_json(%{"id" => "cus_1"}))
      end)

      assert {:ok, %Customer{id: "cus_1"}} =
               Webhook.fetch_related_object(client, notif, expand: ["customer", "invoice"])
    end

    test "uses related_object.url verbatim as request path" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "cus_xyz",
              "type" => "customer",
              "url" => "/v1/customers/cus_xyz"
            }
          })
        )

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert String.contains?(req.url, "/v1/customers/cus_xyz")
        ok_response(customer_json(%{"id" => "cus_xyz"}))
      end)

      assert {:ok, %Customer{id: "cus_xyz"}} = Webhook.fetch_related_object(client, notif)
    end

    test "returns {:error, %Error{}} on HTTP error response" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "cus_missing",
              "type" => "customer",
              "url" => "/v1/customers/cus_missing"
            }
          })
        )

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Webhook.fetch_related_object(client, notif)
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_related_object!/3 (THIN-03 bang variant)
  # ---------------------------------------------------------------------------

  describe "fetch_related_object!/3" do
    test "raises %Error{type: :invalid_request_error} on {:error, {:unknown_object_type, _}}" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "acct_1",
              "type" => "v2.core.account",
              "url" => "/v2/core/accounts/acct_1"
            }
          })
        )

      # No transport expect — :verify_on_exit! ensures no HTTP request.
      assert_raise Error, ~r/Unknown Stripe object type/, fn ->
        Webhook.fetch_related_object!(client, notif)
      end
    end

    test "raises %Error{type: :invalid_request_error} on {:error, :no_related_object}" do
      client = test_client()
      notif = EventNotification.from_map(event_notification_map_no_related_object())

      assert_raise Error, ~r/no related_object/, fn ->
        Webhook.fetch_related_object!(client, notif)
      end
    end

    test "raises %LatticeStripe.Error{} on HTTP error response" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "cus_missing",
              "type" => "customer",
              "url" => "/v1/customers/cus_missing"
            }
          })
        )

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Webhook.fetch_related_object!(client, notif)
      end
    end

    test "returns the typed resource on happy path" do
      client = test_client()

      notif =
        EventNotification.from_map(
          event_notification_map(%{
            "related_object" => %{
              "id" => "cus_1",
              "type" => "customer",
              "url" => "/v1/customers/cus_1"
            }
          })
        )

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(customer_json(%{"id" => "cus_1"}))
      end)

      assert %Customer{id: "cus_1"} = Webhook.fetch_related_object!(client, notif)
    end
  end
end
