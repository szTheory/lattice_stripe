defmodule LatticeStripe.Billing.MeterEventStreamTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.MeterEventStream
  alias LatticeStripe.Billing.MeterEventStream.Session
  alias LatticeStripe.Error
  alias LatticeStripe.Test.Fixtures.Metering

  setup :verify_on_exit!

  setup do
    %{client: test_client()}
  end

  describe "Session.from_map/1" do
    test "deserializes v2 session response into struct" do
      session = Session.from_map(Metering.MeterEventStreamSession.basic())

      assert %Session{} = session
      assert session.id == "mes_123"
      assert session.object == "v2.billing.meter_event_session"
      assert session.authentication_token == "tok_test_abc"
      assert session.created == 1_712_345_678
      assert session.expires_at == 1_712_346_578
      assert session.livemode == false
    end

    test "returns nil for nil input" do
      assert Session.from_map(nil) == nil
    end

    test "handles overrides in fixture" do
      session =
        Session.from_map(
          Metering.MeterEventStreamSession.basic(%{"livemode" => true})
        )

      assert session.livemode == true
      assert session.id == "mes_123"
    end
  end

  describe "Session Inspect masking" do
    setup do
      session = Session.from_map(Metering.MeterEventStreamSession.basic())
      %{session: session, rendered: inspect(session)}
    end

    test "renders with struct prefix", %{rendered: r} do
      assert r =~ "#LatticeStripe.Billing.MeterEventStream.Session<"
    end

    test "hides authentication_token value", %{rendered: r} do
      refute r =~ "tok_test_abc"
    end

    test "does not include authentication_token key", %{rendered: r} do
      refute r =~ "authentication_token:"
    end

    test "shows structural fields", %{rendered: r} do
      assert r =~ "id:"
      assert r =~ "object:"
      assert r =~ "created:"
      assert r =~ "expires_at:"
      assert r =~ "livemode:"
    end
  end

  describe "create_session/2" do
    test "returns Session struct on 200", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{
                                                         url: "https://api.stripe.com/v2/billing/meter_event_session",
                                                         method: :post
                                                       } ->
        {:ok, %{status: 200, headers: [], body: Jason.encode!(Metering.MeterEventStreamSession.basic())}}
      end)

      assert {:ok, %Session{authentication_token: "tok_test_abc", expires_at: 1_712_346_578}} =
               MeterEventStream.create_session(client)
    end

    test "sends API key auth (not session token)", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{headers: headers} = req ->
        assert req.url == "https://api.stripe.com/v2/billing/meter_event_session"
        assert {"authorization", "Bearer sk_test_123"} in headers
        {:ok, %{status: 200, headers: [], body: Jason.encode!(Metering.MeterEventStreamSession.basic())}}
      end)

      assert {:ok, %Session{}} = MeterEventStream.create_session(client)
    end

    test "sends Content-Type application/json", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{headers: headers} ->
        assert {"content-type", "application/json"} in headers
        {:ok, %{status: 200, headers: [], body: Jason.encode!(Metering.MeterEventStreamSession.basic())}}
      end)

      assert {:ok, %Session{}} = MeterEventStream.create_session(client)
    end

    test "sends empty JSON body", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{body: body} ->
        assert body == "{}"
        {:ok, %{status: 200, headers: [], body: Jason.encode!(Metering.MeterEventStreamSession.basic())}}
      end)

      assert {:ok, %Session{}} = MeterEventStream.create_session(client)
    end

    test "returns Error on non-200 response", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn _ ->
        {:ok,
         %{
           status: 400,
           headers: [],
           body:
             Jason.encode!(%{
               "error" => %{"type" => "invalid_request_error", "message" => "bad"}
             })
         }}
      end)

      assert {:error, %Error{type: :invalid_request_error}} = MeterEventStream.create_session(client)
    end

    test "returns connection error on transport failure", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn _ ->
        {:error, :timeout}
      end)

      assert {:error, %Error{type: :connection_error}} = MeterEventStream.create_session(client)
    end
  end

  describe "send_events/4" do
    defp valid_session do
      %Session{
        id: "mes_123",
        object: "v2.billing.meter_event_session",
        authentication_token: "tok_test_abc",
        created: 1_712_345_678,
        expires_at: System.system_time(:second) + 300,
        livemode: false
      }
    end

    defp sample_events do
      [%{"event_name" => "api_call", "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"}}]
    end

    test "returns {:ok, %{}} on successful send", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{
                                                         url: "https://meter-events.stripe.com/v2/billing/meter_event_stream",
                                                         method: :post
                                                       } ->
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      assert {:ok, %{}} = MeterEventStream.send_events(client, valid_session(), sample_events())
    end

    test "sends session token auth (not API key)", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{headers: headers} ->
        assert {"authorization", "Bearer tok_test_abc"} in headers
        refute {"authorization", "Bearer sk_test_123"} in headers
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      assert {:ok, %{}} = MeterEventStream.send_events(client, valid_session(), sample_events())
    end

    test "sends JSON-encoded events body", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn %{body: body} ->
        decoded = Jason.decode!(body)
        assert Map.has_key?(decoded, "events")
        assert is_list(decoded["events"])
        {:ok, %{status: 200, headers: [], body: "{}"}}
      end)

      assert {:ok, %{}} = MeterEventStream.send_events(client, valid_session(), sample_events())
    end

    test "returns {:error, :session_expired} when expires_at is in the past", %{client: client} do
      expired_session = %Session{
        id: "mes_123",
        authentication_token: "tok_test_abc",
        expires_at: System.system_time(:second) - 10
      }

      # No Mox expect — no HTTP call should be made for expired sessions
      assert {:error, :session_expired} =
               MeterEventStream.send_events(client, expired_session, sample_events())
    end

    test "returns {:error, :session_expired} on server 401 with billing_meter_event_session_expired",
         %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn _ ->
        {:ok,
         %{
           status: 401,
           headers: [],
           body:
             Jason.encode!(%{
               "error" => %{
                 "type" => "invalid_request_error",
                 "code" => "billing_meter_event_session_expired"
               }
             })
         }}
      end)

      assert {:error, :session_expired} =
               MeterEventStream.send_events(client, valid_session(), sample_events())
    end

    test "returns error when events list is empty", %{client: client} do
      assert {:error, %Error{type: :invalid_request_error, message: msg}} =
               MeterEventStream.send_events(client, valid_session(), [])

      assert msg =~ "empty"
    end

    test "returns Error on non-401 error response", %{client: client} do
      expect(LatticeStripe.MockTransport, :request, fn _ ->
        {:ok,
         %{
           status: 500,
           headers: [],
           body:
             Jason.encode!(%{
               "error" => %{"type" => "api_error", "message" => "internal"}
             })
         }}
      end)

      assert {:error, %Error{type: :api_error}} =
               MeterEventStream.send_events(client, valid_session(), sample_events())
    end
  end
end
