defmodule LatticeStripe.StripeExplorerNotebookIntegrationTest do
  @moduledoc """
  Shift-left verification for the Stripe explorer notebook.

  This treats the LiveBook file as a presentation artifact over executable SDK
  flows. CI verifies the underlying behavior against `stripe-mock`; notebook UI
  rendering is intentionally not a release gate.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{
    Account,
    AccountLink,
    BillingPortal,
    Customer,
    Error,
    Event,
    List,
    PaymentIntent,
    Price,
    Product,
    Refund,
    Response,
    Subscription,
    SubscriptionSchedule,
    Transfer
  }

  alias LatticeStripe.Billing.{Meter, MeterEvent}
  alias LatticeStripe.TestSupport.StripeExplorerHarness

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  test "notebook flows execute against stripe-mock with the documented v2 boundary", %{
    client: client
  } do
    assert {:ok, results} = StripeExplorerHarness.run(client)

    assert %Customer{id: "cus_" <> _} = results.customer

    assert %PaymentIntent{id: intent_id} = results.payment_intent
    assert %PaymentIntent{id: ^intent_id} = results.retrieved_payment_intent
    assert %PaymentIntent{id: ^intent_id} = results.confirmed_payment_intent

    assert %Response{data: %List{data: payment_intents}} = results.payment_intent_list
    assert Enum.all?(payment_intents, &match?(%PaymentIntent{}, &1))

    assert %Refund{} = results.refund
    assert %Product{id: "prod_" <> _} = results.product
    assert %Price{id: "price_" <> _} = results.price

    assert %Subscription{id: subscription_id} = results.subscription
    assert %Subscription{id: ^subscription_id} = results.canceled_subscription
    assert %Response{data: %List{data: subscriptions}} = results.subscription_list
    assert Enum.all?(subscriptions, &match?(%Subscription{}, &1))

    assert %SubscriptionSchedule{} = results.schedule
    assert %Meter{event_name: "api_call"} = results.meter
    assert %MeterEvent{event_name: "api_call"} = results.meter_event

    assert {:stripe_mock_unsupported,
            %Error{type: :invalid_request_error, code: "invalid_v2_key"}} =
             results.meter_event_stream

    assert %BillingPortal.Session{} = results.portal_session
    assert %Account{id: account_id} = results.account
    assert %Account{id: ^account_id} = results.retrieved_account
    assert %AccountLink{} = results.account_link
    assert %Transfer{destination: ^account_id} = results.transfer

    assert [
             {:ok, %Customer{}},
             {:ok, %Response{data: %List{data: [_ | _]}}},
             {:ok, %Response{data: %List{}}}
           ] = results.batch_results

    assert %Subscription{customer: %Customer{}} = results.expanded_subscription
    assert %Event{id: "evt_test_001", type: "payment_intent.succeeded"} = results.webhook_event
  end
end
