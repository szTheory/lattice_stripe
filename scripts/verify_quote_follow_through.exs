# Probe Quote downstream follow-through against a real Stripe sandbox.
#
# Purpose:
#   Prove the shipped SDK path can create, finalize, and accept a Quote, then
#   retrieve exactly one downstream resource in this priority order:
#   invoice -> subscription -> subscription_schedule.
#
# Usage:
#   STRIPE_SECRET_KEY=sk_test_... mix run scripts/verify_quote_follow_through.exs
#
# Required environment:
#   STRIPE_SECRET_KEY   Stripe sandbox or test-mode secret key
#
# Exit codes:
#   0  downstream reference exposed and one typed retrieve succeeded
#   1  probe failed, no downstream reference exposed, or typed retrieve failed

Mix.Task.run("app.start")

defmodule VerifyQuoteFollowThrough do
  alias LatticeStripe.{
    Client,
    Customer,
    Invoice,
    Product,
    Quote,
    Subscription,
    SubscriptionSchedule
  }

  @finch __MODULE__.Finch

  def run do
    start_finch!()

    client =
      Client.new!(
        api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
        finch: @finch,
        telemetry_enabled: false,
        max_retries: 0
      )

    unique = System.system_time(:millisecond)
    customer = create_customer!(client, unique)
    product = create_product!(client, unique)
    quote = create_quote!(client, customer.id, product.id)
    finalized = finalize_quote!(client, quote.id)
    accepted = accept_quote!(client, finalized.id)

    case downstream_reference(accepted) do
      {:invoice, invoice_id} ->
        retrieve_invoice!(client, accepted.id, invoice_id)

      {:subscription, subscription_id} ->
        retrieve_subscription!(client, accepted.id, subscription_id)

      {:subscription_schedule, schedule_id} ->
        retrieve_subscription_schedule!(client, accepted.id, schedule_id)

      :none ->
        IO.puts(
          "FAIL no downstream reference exposed after Quote.accept/3 quote_id=#{accepted.id}"
        )

        System.halt(1)
    end
  end

  defp start_finch! do
    case Supervisor.start_link([{Finch, name: @finch}], strategy: :one_for_one) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> raise "failed to start Finch: #{inspect(reason)}"
    end
  end

  defp create_customer!(client, unique) do
    case Customer.create(client, %{"email" => "quote-follow-through-#{unique}@example.com"}) do
      {:ok, customer} ->
        customer

      {:error, error} ->
        fail!("Customer.create/3", error)
    end
  end

  defp create_product!(client, unique) do
    case Product.create(client, %{"name" => "Quote Follow Through #{unique}"}) do
      {:ok, product} ->
        product

      {:error, error} ->
        fail!("Product.create/3", error)
    end
  end

  defp create_quote!(client, customer_id, product_id) do
    params = %{
      "customer" => customer_id,
      "line_items" => [
        %{
          "price_data" => %{
            "currency" => "usd",
            "product" => product_id,
            "unit_amount" => 2_000,
            "recurring" => %{"interval" => "month"}
          },
          "quantity" => 1
        }
      ]
    }

    case Quote.create(client, params) do
      {:ok, quote} ->
        quote

      {:error, error} ->
        fail!("Quote.create/3", error)
    end
  end

  defp finalize_quote!(client, quote_id) do
    case Quote.finalize(client, quote_id, %{}) do
      {:ok, quote} ->
        quote

      {:error, error} ->
        fail!("Quote.finalize/4", error)
    end
  end

  defp accept_quote!(client, quote_id) do
    case Quote.accept(client, quote_id) do
      {:ok, quote} ->
        quote

      {:error, error} ->
        fail!("Quote.accept/3", error)
    end
  end

  defp downstream_reference(quote) do
    cond do
      is_binary(quote.invoice) ->
        {:invoice, quote.invoice}

      is_binary(quote.subscription) ->
        {:subscription, quote.subscription}

      is_binary(quote.subscription_schedule) ->
        {:subscription_schedule, quote.subscription_schedule}

      true ->
        :none
    end
  end

  defp retrieve_invoice!(client, quote_id, invoice_id) do
    case Invoice.retrieve(client, invoice_id) do
      {:ok, %Invoice{id: ^invoice_id}} ->
        IO.puts(
          "SUCCESS downstream_type=invoice downstream_id=#{invoice_id} typed_struct=LatticeStripe.Invoice quote_id=#{quote_id}"
        )

      {:ok, other} ->
        fail!("Invoice.retrieve/3 returned unexpected payload", other)

      {:error, error} ->
        fail!("Invoice.retrieve/3", error)
    end
  end

  defp retrieve_subscription!(client, quote_id, subscription_id) do
    case Subscription.retrieve(client, subscription_id) do
      {:ok, %Subscription{id: ^subscription_id}} ->
        IO.puts(
          "SUCCESS downstream_type=subscription downstream_id=#{subscription_id} typed_struct=LatticeStripe.Subscription quote_id=#{quote_id}"
        )

      {:ok, other} ->
        fail!("Subscription.retrieve/3 returned unexpected payload", other)

      {:error, error} ->
        fail!("Subscription.retrieve/3", error)
    end
  end

  defp retrieve_subscription_schedule!(client, quote_id, schedule_id) do
    case SubscriptionSchedule.retrieve(client, schedule_id) do
      {:ok, %SubscriptionSchedule{id: ^schedule_id}} ->
        IO.puts(
          "SUCCESS downstream_type=subscription_schedule downstream_id=#{schedule_id} typed_struct=LatticeStripe.SubscriptionSchedule quote_id=#{quote_id}"
        )

      {:ok, other} ->
        fail!("SubscriptionSchedule.retrieve/3 returned unexpected payload", other)

      {:error, error} ->
        fail!("SubscriptionSchedule.retrieve/3", error)
    end
  end

  defp fail!(step, reason) do
    IO.puts("FAIL step=#{step} reason=#{inspect(reason)}")
    System.halt(1)
  end
end

VerifyQuoteFollowThrough.run()
