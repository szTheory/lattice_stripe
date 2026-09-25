defmodule PhoenixAdopter.CoreFlowTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest
  import Mox

  alias LatticeStripe.{Checkout.Session, Event, Webhook}

  @endpoint PhoenixAdopter.Endpoint
  @secret "whsec_synthetic_adopter_test_secret"
  @event_id "evt_test_adopter_completed"
  @payload ~s({"id":"evt_test_adopter_completed","object":"event","type":"checkout.session.completed","api_version":"2026-03-25.dahlia","created":1800000000,"livemode":false,"pending_webhooks":1,"request":{"id":null,"idempotency_key":null},"data":{"object":{"id":"cs_test_adopter_123","object":"checkout.session","mode":"subscription","livemode":false}}})

  setup :verify_on_exit!

  test "host boots with checked-out dependency" do
    assert is_pid(Process.whereis(PhoenixAdopter.Endpoint))
    assert is_pid(Process.whereis(LatticeStripe.Finch))

    assert [{LatticeStripe.Finch, _pid, :worker, [Finch]}] =
             Supervisor.which_children(LatticeStripe.Supervisor)

    expect(PhoenixAdopter.MockTransport, :request, fn _request ->
      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body:
           Jason.encode!(%{id: "cs_test_boot", object: "checkout.session", mode: "subscription"})
       }}
    end)

    conn = post(build_conn(), "/checkout")
    assert conn.status == 201
  end

  test "subscription checkout and signed completion event cross the host boundary" do
    expect(PhoenixAdopter.MockTransport, :request, fn request ->
      assert request.method == :post
      assert String.ends_with?(request.url, "/v1/checkout/sessions")
      assert request.body =~ "mode=subscription"
      assert request.body =~ "success_url=https%3A%2F%2Fadopter.example.test%2Fsuccess"
      assert request.body =~ "cancel_url=https%3A%2F%2Fadopter.example.test%2Fcancel"
      assert request.body =~ "line_items[0][price]=price_test_monthly"

      assert Enum.any?(request.headers, fn {name, value} ->
               String.downcase(name) == "authorization" and
                 value == "Bearer sk_test_synthetic_adopter_key"
             end)

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body:
           Jason.encode!(%{
             id: "cs_test_adopter_123",
             object: "checkout.session",
             mode: "subscription",
             livemode: false,
             status: "open",
             url: "https://checkout.stripe.com/c/pay/cs_test_adopter_123"
           })
       }}
    end)

    checkout_conn = post(build_conn(), "/checkout")
    assert checkout_conn.status == 201
    assert json_response(checkout_conn, 201) == %{"id" => "cs_test_adopter_123"}

    assert %Session{id: "cs_test_adopter_123", mode: :subscription} =
             checkout_conn.assigns.checkout_session

    Process.put(:phoenix_adopter_test_pid, self())
    signature = Webhook.generate_test_signature(@payload, @secret)

    webhook_conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", signature)
      |> post("/webhooks/stripe", @payload)

    assert webhook_conn.status == 200

    assert_receive {:stripe_event,
                    %Event{type: "checkout.session.completed", id: @event_id, livemode: false}}
  end

  test "modified webhook body is rejected before handler dispatch" do
    signature = Webhook.generate_test_signature(@payload, @secret)
    tampered_payload = String.replace(@payload, "cs_test_adopter_123", "cs_test_tampered_123")

    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", signature)
      |> post("/webhooks/stripe", tampered_payload)

    assert conn.status == 400
    refute_received {:stripe_event, _event}
  end
end
