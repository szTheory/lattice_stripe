defmodule LatticeStripe.Integration.SubscriptionScheduleTest do
  @moduledoc """
  Integration tests for `LatticeStripe.SubscriptionSchedule` against
  `stripe-mock` running on `localhost:12111`. Run via:

      mix test --include integration test/integration/subscription_schedule_integration_test.exs

  stripe-mock is stateless against our requests — it validates against the
  OpenAPI spec and returns canned-but-randomized responses. These tests
  assert SHAPE (structs, `is_binary(id)`, `is_list`) NOT SEMANTICS (status
  transitions). See 16-RESEARCH.md §stripe-mock Coverage for details.
  """
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Error, Price, Product, Subscription, SubscriptionSchedule}

  # Guard: stripe-mock must be reachable on localhost:12111. Start the
  # Finch pool used by `test_integration_client/0` for real HTTP traffic.
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
    {:ok, product} = Product.create(client, %{"name" => "Phase16 Test Product"})

    {:ok, price} =
      Price.create(client, %{
        "product" => product.id,
        "currency" => "usd",
        "unit_amount" => 1500,
        "recurring" => %{"interval" => "month"}
      })

    price
  end

  defp fresh_customer!(client, email) do
    {:ok, customer} = Customer.create(client, %{"email" => email})
    customer
  end

  defp create_basic_schedule!(client) do
    price = fresh_recurring_price!(client)

    customer =
      fresh_customer!(client, "phase16-#{System.unique_integer([:positive])}@example.com")

    {:ok, sched} =
      SubscriptionSchedule.create(client, %{
        "customer" => customer.id,
        "start_date" => "now",
        "end_behavior" => "release",
        "phases" => [
          %{
            "items" => [%{"price" => price.id, "quantity" => 1}],
            "iterations" => 12
          }
        ]
      })

    {sched, price}
  end

  # ---------------------------------------------------------------------------
  # create — Mode 2: customer + phases
  # ---------------------------------------------------------------------------

  test "create (customer + phases mode) returns shape-valid %SubscriptionSchedule{}", %{
    client: client
  } do
    {sched, _price} = create_basic_schedule!(client)

    assert %SubscriptionSchedule{} = sched
    assert is_binary(sched.id)
    assert is_list(sched.phases)
    assert sched.phases != []
    assert %SubscriptionSchedule.Phase{} = hd(sched.phases)
  end

  # ---------------------------------------------------------------------------
  # create — Mode 1: from_subscription
  # ---------------------------------------------------------------------------

  test "create (from_subscription mode) returns shape-valid %SubscriptionSchedule{}", %{
    client: client
  } do
    price = fresh_recurring_price!(client)
    customer = fresh_customer!(client, "phase16-fromsub@example.com")

    {:ok, sub} =
      Subscription.create(client, %{
        "customer" => customer.id,
        "items" => [%{"price" => price.id, "quantity" => 1}]
      })

    assert %Subscription{} = sub

    {:ok, sched} =
      SubscriptionSchedule.create(client, %{
        "from_subscription" => sub.id
      })

    assert %SubscriptionSchedule{} = sched
    assert is_binary(sched.id)
  end

  # ---------------------------------------------------------------------------
  # retrieve
  # ---------------------------------------------------------------------------

  test "retrieve/3 returns shape-valid %SubscriptionSchedule{}", %{client: client} do
    {sched, _price} = create_basic_schedule!(client)

    {:ok, retrieved} = SubscriptionSchedule.retrieve(client, sched.id)
    assert %SubscriptionSchedule{} = retrieved
    assert is_binary(retrieved.id)
  end

  # ---------------------------------------------------------------------------
  # update — exercises form encoder for phases[].items[] nested params
  # ---------------------------------------------------------------------------

  test "update/4 with phases[].proration_behavior succeeds (T-16-05 form-encoder guard)",
       %{client: client} do
    {sched, price} = create_basic_schedule!(client)

    # If the form encoder mis-encodes nested phases[][items][], stripe-mock
    # rejects against its OpenAPI spec. A successful update is the
    # server-side regression guard for T-16-05.
    {:ok, updated} =
      SubscriptionSchedule.update(client, sched.id, %{
        "phases" => [
          %{
            "items" => [%{"price" => price.id, "quantity" => 2}],
            "iterations" => 6,
            "proration_behavior" => "create_prorations"
          }
        ]
      })

    assert %SubscriptionSchedule{} = updated
  end

  # ---------------------------------------------------------------------------
  # cancel — POST sub-path (T-16-04 wire-verb regression guard)
  # ---------------------------------------------------------------------------

  test "cancel/4 uses POST and returns %SubscriptionSchedule{}", %{client: client} do
    {sched, _price} = create_basic_schedule!(client)

    # Wire-verb regression guard (T-16-04): stripe-mock returns 200 only if
    # POST is used. A DELETE to /cancel would 404 or 405 here.
    {:ok, canceled} =
      SubscriptionSchedule.cancel(client, sched.id, %{
        "invoice_now" => false,
        "prorate" => false
      })

    assert %SubscriptionSchedule{} = canceled
  end

  # ---------------------------------------------------------------------------
  # release — POST sub-path (T-16-04 wire-verb regression guard)
  # ---------------------------------------------------------------------------

  test "release/4 uses POST and returns %SubscriptionSchedule{}", %{client: client} do
    {sched, _price} = create_basic_schedule!(client)

    # Wire-verb regression guard (T-16-04): stripe-mock returns 200 only if
    # POST is used. A DELETE to /release would 404 or 405 here.
    {:ok, released} =
      SubscriptionSchedule.release(client, sched.id, %{"preserve_cancel_date" => false})

    assert %SubscriptionSchedule{} = released
  end

  # ---------------------------------------------------------------------------
  # list
  # ---------------------------------------------------------------------------

  test "list/3 returns a paginated response of %SubscriptionSchedule{} structs", %{client: client} do
    {:ok, resp} = SubscriptionSchedule.list(client, %{"limit" => 3})

    assert %LatticeStripe.Response{data: %LatticeStripe.List{data: data}} = resp
    assert is_list(data)

    if data != [] do
      assert match?(%SubscriptionSchedule{}, hd(data))
    end
  end

  # ---------------------------------------------------------------------------
  # stream!
  # ---------------------------------------------------------------------------

  test "stream!/3 yields %SubscriptionSchedule{} items", %{client: client} do
    items =
      SubscriptionSchedule.stream!(client, %{"limit" => 2})
      |> Enum.take(2)

    assert is_list(items)

    if items != [] do
      assert Enum.all?(items, &match?(%SubscriptionSchedule{}, &1))
    end
  end

  # ---------------------------------------------------------------------------
  # Proration guard (T-16-03) — fires pre-network even in integration context
  # ---------------------------------------------------------------------------

  test "strict client rejects update with phases[] missing proration_behavior (pre-network)" do
    strict_client = test_integration_client(require_explicit_proration: true)

    # Guard fails pre-network — no stripe-mock call is made.
    assert {:error, %Error{type: :proration_required}} =
             SubscriptionSchedule.update(strict_client, "sub_sched_fake", %{
               "phases" => [%{"items" => [%{"price" => "price_1"}]}]
             })
  end

  # ---------------------------------------------------------------------------
  # Idempotency (T-16-02) — opts[:idempotency_key] forwarding
  # ---------------------------------------------------------------------------

  test "idempotency_key is forwarded on create", %{client: client} do
    price = fresh_recurring_price!(client)
    customer = fresh_customer!(client, "phase16-idk@example.com")

    key = "test-ik-phase16-create-#{System.unique_integer([:positive])}"

    params = %{
      "customer" => customer.id,
      "start_date" => "now",
      "end_behavior" => "release",
      "phases" => [
        %{
          "items" => [%{"price" => price.id, "quantity" => 1}],
          "iterations" => 3
        }
      ]
    }

    {:ok, sched1} = SubscriptionSchedule.create(client, params, idempotency_key: key)
    assert %SubscriptionSchedule{} = sched1

    # Second call with the same key should still succeed — stripe-mock
    # honors the Idempotency-Key header. The forwarding-through-Client
    # pipeline is what we're verifying here.
    {:ok, sched2} = SubscriptionSchedule.create(client, params, idempotency_key: key)
    assert %SubscriptionSchedule{} = sched2
  end
end
