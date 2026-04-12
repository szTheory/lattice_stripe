defmodule LatticeStripe.Integration.SubscriptionItemTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Price, Product, Subscription, SubscriptionItem}

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

  defp setup_subscription!(client, email) do
    {:ok, product} = Product.create(client, %{"name" => "Phase15 SI Test"})

    {:ok, price} =
      Price.create(client, %{
        "product" => product.id,
        "currency" => "usd",
        "unit_amount" => 500,
        "recurring" => %{"interval" => "month"}
      })

    {:ok, customer} = Customer.create(client, %{"email" => email})

    {:ok, sub} =
      Subscription.create(client, %{
        "customer" => customer.id,
        "items" => [%{"price" => price.id, "quantity" => 1}]
      })

    %{price: price, customer: customer, subscription: sub}
  end

  # ---------------------------------------------------------------------------
  # CRUD round-trip
  # ---------------------------------------------------------------------------

  test "create -> retrieve -> update -> delete round-trip", %{client: client} do
    %{subscription: sub, price: price} =
      setup_subscription!(client, "si-crud@example.com")

    # Create a new SubscriptionItem on the existing subscription
    {:ok, item} =
      SubscriptionItem.create(client, %{
        "subscription" => sub.id,
        "price" => price.id,
        "quantity" => 1
      })

    assert %SubscriptionItem{} = item
    assert is_binary(item.id)

    # Retrieve
    {:ok, retrieved} = SubscriptionItem.retrieve(client, item.id)
    assert %SubscriptionItem{} = retrieved

    # Update
    {:ok, updated} =
      SubscriptionItem.update(client, item.id, %{
        "quantity" => 2,
        "proration_behavior" => "none"
      })

    assert %SubscriptionItem{} = updated

    # Delete
    {:ok, deleted} =
      SubscriptionItem.delete(client, item.id, %{"proration_behavior" => "none"}, [])

    assert %SubscriptionItem{} = deleted
  end

  # ---------------------------------------------------------------------------
  # list requires subscription param
  # ---------------------------------------------------------------------------

  test "list/3 requires subscription param", %{client: client} do
    assert_raise ArgumentError, ~r/subscription/, fn ->
      SubscriptionItem.list(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # list + stream! filtered by subscription
  # ---------------------------------------------------------------------------

  test "list + stream! filtered by subscription", %{client: client} do
    %{subscription: sub} = setup_subscription!(client, "si-list@example.com")

    {:ok, resp} = SubscriptionItem.list(client, %{"subscription" => sub.id})
    assert %LatticeStripe.Response{data: %LatticeStripe.List{data: items}} = resp
    assert is_list(items)

    streamed =
      SubscriptionItem.stream!(client, %{"subscription" => sub.id})
      |> Enum.take(5)

    assert is_list(streamed)
  end

  # ---------------------------------------------------------------------------
  # Strict client + explicit proration
  # ---------------------------------------------------------------------------

  test "update with proration_behavior succeeds against strict client" do
    strict_client = test_integration_client(require_explicit_proration: true)

    %{subscription: sub, price: price} =
      setup_subscription!(test_integration_client(), "si-strict@example.com")

    # Create an item under the permissive client (seed data).
    {:ok, item} =
      SubscriptionItem.create(test_integration_client(), %{
        "subscription" => sub.id,
        "price" => price.id,
        "quantity" => 1
      })

    # Update under strict client WITH explicit proration — guard should let
    # it through to stripe-mock, which validates against the real spec.
    {:ok, updated} =
      SubscriptionItem.update(strict_client, item.id, %{
        "quantity" => 2,
        "proration_behavior" => "create_prorations"
      })

    assert %SubscriptionItem{} = updated
  end

  # ---------------------------------------------------------------------------
  # Idempotency (T-15-02)
  # ---------------------------------------------------------------------------

  test "idempotency_key is forwarded on create", %{client: client} do
    %{subscription: sub, price: price} =
      setup_subscription!(client, "si-idk@example.com")

    key = "test-ik-si-#{System.unique_integer([:positive])}"

    {:ok, item} =
      SubscriptionItem.create(
        client,
        %{
          "subscription" => sub.id,
          "price" => price.id,
          "quantity" => 1
        },
        idempotency_key: key
      )

    assert %SubscriptionItem{} = item
  end
end
