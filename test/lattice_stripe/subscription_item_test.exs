defmodule LatticeStripe.SubscriptionItemTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, List, Response, SubscriptionItem}
  alias LatticeStripe.Test.Fixtures.SubscriptionItem, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionItem.from_map(nil) == nil
    end

    test "maps basic known fields" do
      item = SubscriptionItem.from_map(Fixtures.basic())

      assert item.id == "si_test1234567890"
      assert item.object == "subscription_item"
      assert item.subscription == "sub_test1234567890"
      assert item.quantity == 1
      assert is_map(item.price)
      assert item.price["id"] == "price_test1"
    end

    test "unknown fields land in :extra" do
      item = SubscriptionItem.from_map(Fixtures.basic(%{"future_field" => "hi"}))
      assert item.extra == %{"future_field" => "hi"}
    end

    test "from_map/1 preserves id (stripity_stripe regression guard)" do
      # Simulate the nested-items-data decode path: Subscription.from_map/1
      # receives an items map with data=[item_map], iterates, and the id
      # MUST survive the round-trip. stripity_stripe's decoder dropped id here.
      raw = Fixtures.basic(%{"id" => "si_regressionguard_xyz"})
      item = SubscriptionItem.from_map(raw)
      assert item.id == "si_regressionguard_xyz"
      refute is_nil(item.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/subscription_items and returns {:ok, %SubscriptionItem{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscription_items")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{id: "si_test1234567890"}} =
               SubscriptionItem.create(client, %{
                 "subscription" => "sub_test1234567890",
                 "price" => "price_test1",
                 "quantity" => 1
               })
    end

    test "create/3 returns proration_required under strict client when missing" do
      client = test_client(require_explicit_proration: true)

      assert {:error, %Error{type: :proration_required}} =
               SubscriptionItem.create(client, %{
                 "subscription" => "sub_test1234567890",
                 "price" => "price_test1"
               })
    end

    test "forwards opts[:idempotency_key]" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-si-create"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.create(
                 client,
                 %{"subscription" => "sub_test1234567890", "price" => "price_test1"},
                 idempotency_key: "ik-si-create"
               )
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/subscription_items/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/subscription_items/si_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{id: "si_test1234567890"}} =
               SubscriptionItem.retrieve(client, "si_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/subscription_items/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscription_items/si_test1234567890")
        ok_response(Fixtures.basic(%{"quantity" => 5}))
      end)

      assert {:ok, %SubscriptionItem{quantity: 5}} =
               SubscriptionItem.update(client, "si_test1234567890", %{"quantity" => 5})
    end

    test "update/4 returns proration_required under strict client" do
      client = test_client(require_explicit_proration: true)

      assert {:error, %Error{type: :proration_required}} =
               SubscriptionItem.update(client, "si_test1234567890", %{"quantity" => 2})
    end

    test "update/4 with explicit proration_behavior reaches Transport under strict client" do
      client = test_client(require_explicit_proration: true)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.update(client, "si_test1234567890", %{
                 "quantity" => 2,
                 "proration_behavior" => "create_prorations"
               })
    end

    test "update forwards opts[:idempotency_key]" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-si-update"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.update(client, "si_test1234567890", %{"quantity" => 2},
                 idempotency_key: "ik-si-update"
               )
    end
  end

  # ---------------------------------------------------------------------------
  # delete/3 and delete/4
  # ---------------------------------------------------------------------------

  describe "delete/3 and delete/4" do
    test "delete/3 (no params) sends DELETE with empty query" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/subscription_items/si_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.delete(client, "si_test1234567890")
    end

    test "delete/4 passes clear_usage param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert req.url =~ "clear_usage"
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.delete(
                 client,
                 "si_test1234567890",
                 %{"clear_usage" => true},
                 []
               )
    end

    test "delete under strict client without proration_behavior returns error" do
      client = test_client(require_explicit_proration: true)

      assert {:error, %Error{type: :proration_required}} =
               SubscriptionItem.delete(client, "si_test1234567890", %{}, [])
    end

    test "delete under strict client WITH proration_behavior reaches Transport" do
      client = test_client(require_explicit_proration: true)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.delete(
                 client,
                 "si_test1234567890",
                 %{"proration_behavior" => "none"},
                 []
               )
    end

    test "delete/3 forwards idempotency_key" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-si-delete"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionItem{}} =
               SubscriptionItem.delete(client, "si_test1234567890",
                 idempotency_key: "ik-si-delete"
               )
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "list/3 raises when subscription param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/subscription/, fn ->
        SubscriptionItem.list(client, %{})
      end
    end

    test "list/3 with subscription param sends GET and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/subscription_items"
        assert req.url =~ "subscription"
        ok_response(Fixtures.list_response(2))
      end)

      assert {:ok, %Response{data: %List{data: items}}} =
               SubscriptionItem.list(client, %{"subscription" => "sub_test1234567890"})

      assert [%SubscriptionItem{id: "si_test1"}, %SubscriptionItem{id: "si_test2"}] = items
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/2
  # ---------------------------------------------------------------------------

  describe "stream!/2" do
    test "raises when subscription param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/subscription/, fn ->
        SubscriptionItem.stream!(client, %{}) |> Enum.take(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "bang variants" do
    test "create! returns struct on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %SubscriptionItem{} =
               SubscriptionItem.create!(client, %{
                 "subscription" => "sub_test1234567890",
                 "price" => "price_test1"
               })
    end

    test "create! raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        SubscriptionItem.create!(client, %{
          "subscription" => "sub_test1234567890",
          "price" => "price_test1"
        })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "masks metadata and billing_thresholds values" do
      item =
        SubscriptionItem.from_map(
          Fixtures.basic(%{
            "metadata" => %{"customer_tier" => "gold", "secret_note" => "do_not_log"},
            "billing_thresholds" => %{"usage_gte" => 1_000_000}
          })
        )

      inspected = inspect(item)

      refute inspected =~ "do_not_log"
      refute inspected =~ "usage_gte"
      assert inspected =~ "#LatticeStripe.SubscriptionItem<"
      assert inspected =~ "metadata: :present"
      assert inspected =~ "billing_thresholds: :present"
    end
  end
end
