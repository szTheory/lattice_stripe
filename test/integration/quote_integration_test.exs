defmodule LatticeStripe.QuoteIntegrationTest do
  @moduledoc """
  Integration proof for Quote routing under `stripe-mock`.

  These tests verify request encoding, binary transport, and typed top-level
  decode sanity for the shipped Quote API surface. They do not treat
  `stripe-mock` as a persisted Quote lifecycle oracle.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Quote

  @moduletag :integration

  alias LatticeStripe.{Invoice, Quote, Subscription, SubscriptionSchedule}

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

  test "create/retrieve/update/list/stream prove quote routing with product-backed price_data", %{
    client: client
  } do
    customer = create_quote_customer!(client, %{"customer_email" => "quote-create@example.com"})
    product = create_quote_product!(client, %{"product_name" => "Integration quote product"})

    {:ok, quote} =
      Quote.create(client, %{
        "customer" => customer.id,
        "line_items" => [
          %{
            "price_data" => %{
              "currency" => "usd",
              "product" => product.id,
              "unit_amount" => 2_000,
              "recurring" => %{"interval" => "month"}
            },
            "quantity" => 1
          }
        ]
      })

    assert %Quote{} = quote
    assert is_binary(quote.id)

    {:ok, retrieved} = Quote.retrieve(client, quote.id)

    assert %Quote{} = retrieved
    assert retrieved.id == quote.id

    {:ok, updated} = Quote.update(client, quote.id, %{"header" => "Updated integration quote"})

    assert %Quote{} = updated
    assert updated.id == quote.id

    {:ok, list_resp} = Quote.list(client, %{"limit" => "5"})

    assert %LatticeStripe.Response{} = list_resp
    assert %LatticeStripe.List{} = list_resp.data
    assert Enum.all?(list_resp.data.data, &match?(%Quote{}, &1))

    assert [%Quote{} | _] = Quote.stream!(client, %{"limit" => "5"}) |> Enum.take(1)
  end

  test "finalize/pdf/accept records the current downstream boundary exactly once", %{
    client: client
  } do
    quote = create_quote!(client, %{"customer_email" => "quote-lifecycle@example.com"})

    {:ok, finalized} = Quote.finalize(client, quote.id, %{})

    assert %Quote{} = finalized
    assert finalized.id == quote.id

    assert {:ok, pdf_binary} = Quote.pdf(client, quote.id)
    assert is_binary(pdf_binary)
    assert byte_size(pdf_binary) > 0

    {:ok, accepted} = Quote.accept(client, quote.id)

    assert %Quote{} = accepted
    assert accepted.id == quote.id

    assert_downstream_follow_through(client, accepted)
  end

  test "cancel/3 returns a typed quote without claiming persisted lifecycle semantics", %{
    client: client
  } do
    quote = create_quote!(client, %{"customer_email" => "quote-cancel@example.com"})

    {:ok, canceled} = Quote.cancel(client, quote.id)

    assert %Quote{} = canceled
    assert canceled.id == quote.id
  end

  test "list_line_items/4 and stream_line_items!/4 return typed line item lists", %{
    client: client
  } do
    quote = create_quote!(client, %{"customer_email" => "quote-lines@example.com"})

    {:ok, resp} = Quote.list_line_items(client, quote.id)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
    assert Enum.all?(resp.data.data, &match?(%Quote.LineItem{}, &1))

    assert [%Quote.LineItem{} | _] =
             Quote.stream_line_items!(client, quote.id, %{"limit" => "5"})
             |> Enum.take(1)
  end

  defp assert_downstream_follow_through(client, accepted_quote) do
    case downstream_reference(accepted_quote) do
      {:invoice, invoice_id} ->
        assert {:ok, %Invoice{id: ^invoice_id}} = Invoice.retrieve(client, invoice_id)

      {:subscription, subscription_id} ->
        assert {:ok, %Subscription{id: ^subscription_id}} =
                 Subscription.retrieve(client, subscription_id)

      {:subscription_schedule, schedule_id} ->
        assert {:ok, %SubscriptionSchedule{id: ^schedule_id}} =
                 SubscriptionSchedule.retrieve(client, schedule_id)

      :none ->
        assert accepted_quote.invoice == nil
        assert accepted_quote.subscription == nil
        assert accepted_quote.subscription_schedule == nil
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
end
