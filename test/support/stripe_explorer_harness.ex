defmodule LatticeStripe.TestSupport.StripeExplorerHarness do
  @moduledoc false

  alias LatticeStripe.{
    Account,
    AccountLink,
    Batch,
    Customer,
    Error,
    Event,
    Invoice,
    PaymentIntent,
    Price,
    Product,
    Refund,
    Subscription,
    SubscriptionSchedule,
    Transfer,
    Webhook
  }

  alias LatticeStripe.Billing.{Meter, MeterEvent, MeterEventStream}
  alias LatticeStripe.BillingPortal.Session, as: PortalSession
  alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder

  def run(client) do
    with {:ok, customer} <- create_customer(client),
         {:ok, payment_intent} <- create_payment_intent(client, customer),
         {:ok, retrieved_payment_intent} <- PaymentIntent.retrieve(client, payment_intent.id),
         {:ok, payment_intent_list} <- PaymentIntent.list(client, %{"limit" => "5"}),
         {:ok, confirmed_payment_intent} <- confirm_payment_intent(client, payment_intent),
         {:ok, refund} <- Refund.create(client, %{"payment_intent" => payment_intent.id}),
         {:ok, product} <- Product.create(client, %{"name" => "Explorer Pro Plan"}),
         {:ok, price} <- create_price(client, product),
         {:ok, subscription} <- create_subscription(client, customer, price),
         {:ok, subscription_list} <- Subscription.list(client, %{"customer" => customer.id}),
         {:ok, canceled_subscription} <- Subscription.cancel(client, subscription.id),
         {:ok, schedule} <- create_schedule(client, customer, price),
         {:ok, meter} <- create_meter(client),
         {:ok, meter_event} <- create_meter_event(client, customer),
         {:ok, portal_session} <- PortalSession.create(client, portal_params(customer.id)),
         {:ok, account} <- Account.create(client, account_params()),
         {:ok, retrieved_account} <- Account.retrieve(client, account.id),
         {:ok, account_link} <- AccountLink.create(client, account_link_params(account.id)),
         {:ok, transfer} <- Transfer.create(client, transfer_params(account.id)),
         {:ok, batch_results} <- batch_results(client, customer.id),
         {:ok, expanded_subscription} <-
           Subscription.retrieve(client, subscription.id, expand: ["customer"]),
         {:ok, event} <- webhook_event() do
      {:ok,
       %{
         customer: customer,
         payment_intent: payment_intent,
         retrieved_payment_intent: retrieved_payment_intent,
         payment_intent_list: payment_intent_list,
         confirmed_payment_intent: confirmed_payment_intent,
         refund: refund,
         product: product,
         price: price,
         subscription: subscription,
         subscription_list: subscription_list,
         canceled_subscription: canceled_subscription,
         schedule: schedule,
         meter: meter,
         meter_event: meter_event,
         meter_event_stream: meter_event_stream_boundary(client),
         portal_session: portal_session,
         account: account,
         retrieved_account: retrieved_account,
         account_link: account_link,
         transfer: transfer,
         batch_results: batch_results,
         expanded_subscription: expanded_subscription,
         webhook_event: event
       }}
    end
  end

  defp create_customer(client) do
    Customer.create(client, %{
      "email" => "explorer@example.com",
      "name" => "SDK Explorer"
    })
  end

  defp create_payment_intent(client, customer) do
    PaymentIntent.create(client, %{
      "amount" => "2000",
      "currency" => "usd",
      "customer" => customer.id
    })
  end

  defp confirm_payment_intent(client, payment_intent) do
    PaymentIntent.confirm(client, payment_intent.id, %{
      "payment_method" => "pm_card_visa"
    })
  end

  defp create_price(client, product) do
    Price.create(client, %{
      "product" => product.id,
      "currency" => "usd",
      "unit_amount" => "2000",
      "recurring" => %{"interval" => "month"}
    })
  end

  defp create_subscription(client, customer, price) do
    Subscription.create(client, %{
      "customer" => customer.id,
      "items" => [%{"price" => price.id}]
    })
  end

  defp create_schedule(client, customer, price) do
    params =
      SSBuilder.new()
      |> SSBuilder.customer(customer.id)
      |> SSBuilder.start_date(:now)
      |> SSBuilder.end_behavior(:release)
      |> SSBuilder.add_phase(
        SSBuilder.phase_new()
        |> SSBuilder.phase_items([%{"price" => price.id, "quantity" => 1}])
        |> SSBuilder.phase_iterations(3)
        |> SSBuilder.phase_build()
      )
      |> SSBuilder.build()

    SubscriptionSchedule.create(client, params)
  end

  defp create_meter(client) do
    Meter.create(client, %{
      "display_name" => "API Calls",
      "event_name" => "api_call",
      "default_aggregation" => %{"formula" => "sum"},
      "customer_mapping" => %{
        "event_payload_key" => "stripe_customer_id",
        "type" => "by_id"
      },
      "value_settings" => %{"event_payload_key" => "value"}
    })
  end

  defp create_meter_event(client, customer) do
    MeterEvent.create(client, %{
      "event_name" => "api_call",
      "payload" => %{
        "stripe_customer_id" => customer.id,
        "value" => "1"
      },
      "identifier" => "notebook_#{System.unique_integer([:positive])}"
    })
  end

  defp meter_event_stream_boundary(client) do
    case MeterEventStream.create_session(client) do
      {:error, %Error{type: :invalid_request_error, code: "invalid_v2_key"} = error} ->
        {:stripe_mock_unsupported, error}

      other ->
        other
    end
  end

  defp portal_params(customer_id) do
    %{
      "customer" => customer_id,
      "return_url" => "https://example.com/account"
    }
  end

  defp account_params do
    %{
      "type" => "express",
      "email" => "merchant@example.com"
    }
  end

  defp account_link_params(account_id) do
    %{
      "account" => account_id,
      "type" => "account_onboarding",
      "refresh_url" => "https://example.com/reauth",
      "return_url" => "https://example.com/return"
    }
  end

  defp transfer_params(account_id) do
    %{
      "amount" => "1000",
      "currency" => "usd",
      "destination" => account_id
    }
  end

  defp batch_results(client, customer_id) do
    with {:ok, results} <-
           Batch.run(client, [
             {Customer, :retrieve, [customer_id]},
             {Subscription, :list, [%{"customer" => customer_id}]},
             {Invoice, :list, [%{"customer" => customer_id}]}
           ]) do
      {:ok, Enum.map(results, &normalize_batch_result/1)}
    end
  end

  defp normalize_batch_result({:ok, value}), do: {:ok, value}
  defp normalize_batch_result({:error, value}), do: {:error, value}

  defp webhook_event do
    raw_body = ~s({"id":"evt_test_001","object":"event","type":"payment_intent.succeeded"})
    secret = "whsec_test_secret_for_notebook"
    sig_header = Webhook.generate_test_signature(raw_body, secret)

    with {:ok, %Event{} = event} <- Webhook.construct_event(raw_body, sig_header, secret) do
      {:ok, event}
    end
  end
end
