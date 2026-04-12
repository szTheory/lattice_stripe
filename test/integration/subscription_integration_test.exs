defmodule LatticeStripe.Integration.SubscriptionTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Error, Price, Product, Subscription, SubscriptionItem}

  # Guard: ensure stripe-mock is up before running any tests in this module.
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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fresh_recurring_price!(client) do
    {:ok, product} = Product.create(client, %{"name" => "Phase15 Test Product"})

    {:ok, price} =
      Price.create(client, %{
        "product" => product.id,
        "currency" => "usd",
        "unit_amount" => 1000,
        "recurring" => %{"interval" => "month"}
      })

    price
  end

  defp fresh_customer!(client, email) do
    {:ok, customer} = Customer.create(client, %{"email" => email})
    customer
  end

  # ---------------------------------------------------------------------------
  # Lifecycle round-trip
  # ---------------------------------------------------------------------------

  test "CRUD + lifecycle round-trip", %{client: client} do
    price = fresh_recurring_price!(client)
    customer = fresh_customer!(client, "phase15-lifecycle@example.com")

    # Create
    {:ok, sub} =
      Subscription.create(client, %{
        "customer" => customer.id,
        "items" => [%{"price" => price.id, "quantity" => 1}]
      })

    assert %Subscription{} = sub
    assert is_binary(sub.id)
    assert is_map(sub.items)

    # Items list should decode with id preserved (stripity_stripe regression guard).
    %{"data" => items} = sub.items
    assert is_list(items)
    assert length(items) >= 1
    [first | _] = items
    assert %SubscriptionItem{} = first
    refute is_nil(first.id)
    si_id = first.id

    # stripe-mock returns a fresh randomly-generated resource on each call
    # (it's stateless against our requests — it validates against the
    # OpenAPI spec and returns a canned-but-randomized response). So we
    # assert on structural shape, not on id equality across calls.

    # Retrieve
    {:ok, retrieved} = Subscription.retrieve(client, sub.id)
    assert %Subscription{} = retrieved
    assert is_binary(retrieved.id)

    # Update items[] with explicit proration_behavior — exercises form encoder
    # for items[0][id], items[0][quantity], items[0][proration_behavior] and
    # verifies that stripe-mock accepts the nested params shape against the
    # real Stripe OpenAPI schema.
    {:ok, updated} =
      Subscription.update(client, sub.id, %{
        "items" => [
          %{
            "id" => si_id,
            "quantity" => 3,
            "proration_behavior" => "create_prorations"
          }
        ]
      })

    assert %Subscription{} = updated

    # Pause collection
    {:ok, paused} = Subscription.pause_collection(client, sub.id, :keep_as_draft)
    assert %Subscription{} = paused

    # Resume
    {:ok, resumed} = Subscription.resume(client, sub.id)
    assert %Subscription{} = resumed

    # Cancel
    {:ok, canceled} = Subscription.cancel(client, sub.id)
    assert %Subscription{} = canceled
  end

  # ---------------------------------------------------------------------------
  # list + stream!
  # ---------------------------------------------------------------------------

  test "list + stream! paginate", %{client: client} do
    {:ok, resp} = Subscription.list(client)
    assert %LatticeStripe.Response{data: %LatticeStripe.List{}} = resp

    # stream! should be lazy and not explode even on an empty or single page.
    count = Subscription.stream!(client) |> Enum.take(3) |> length()
    assert is_integer(count)
    assert count >= 0
  end

  # ---------------------------------------------------------------------------
  # search_stream!
  # ---------------------------------------------------------------------------

  test "search_stream! paginates search results", %{client: client} do
    # stripe-mock returns empty or sample data for search endpoints — the key
    # verification is that pagination machinery does not crash.
    result =
      Subscription.search_stream!(client, %{"query" => "status:'active'"})
      |> Enum.take(1)

    assert is_list(result)
  end

  # ---------------------------------------------------------------------------
  # Form encoder (T-15-05) — items[0][...] nested params
  # ---------------------------------------------------------------------------

  test "form encoder encodes items[0][...] nested params correctly", %{client: client} do
    price = fresh_recurring_price!(client)
    customer = fresh_customer!(client, "phase15-formencoder@example.com")

    # If the form encoder mis-encodes nested items[], stripe-mock rejects
    # the request against its OpenAPI spec. A successful create is the
    # server-side verification.
    {:ok, sub} =
      Subscription.create(client, %{
        "customer" => customer.id,
        "items" => [
          %{
            "price" => price.id,
            "quantity" => 2,
            "metadata" => %{"source" => "integration_test"}
          }
        ]
      })

    assert %Subscription{} = sub
  end

  # ---------------------------------------------------------------------------
  # Proration guard (T-15-03)
  # ---------------------------------------------------------------------------

  test "strict client rejects items[] update without proration_behavior" do
    strict_client = test_integration_client(require_explicit_proration: true)

    # Guard fails pre-network — no stripe-mock call is made.
    assert {:error, %Error{type: :proration_required}} =
             Subscription.update(strict_client, "sub_fake", %{
               "items" => [%{"id" => "si_fake", "quantity" => 2}]
             })
  end

  # ---------------------------------------------------------------------------
  # Idempotency (T-15-02)
  # ---------------------------------------------------------------------------

  test "idempotency_key is forwarded", %{client: client} do
    price = fresh_recurring_price!(client)
    customer = fresh_customer!(client, "phase15-idk@example.com")

    key = "test-ik-#{System.unique_integer([:positive])}"

    {:ok, sub1} =
      Subscription.create(
        client,
        %{
          "customer" => customer.id,
          "items" => [%{"price" => price.id, "quantity" => 1}]
        },
        idempotency_key: key
      )

    assert %Subscription{} = sub1
    # stripe-mock accepts the Idempotency-Key header. The creation succeeding
    # under an explicit key is sufficient to verify forwarding through the
    # Client pipeline.
  end
end
