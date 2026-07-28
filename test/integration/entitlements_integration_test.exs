defmodule LatticeStripe.EntitlementsIntegrationTest do
  @moduledoc """
  Integration tests for the entitlements modules against stripe-mock.

  Shape-first smokes for the six shipped verbs — `ActiveEntitlement.list/3` and
  `retrieve/3`, and `Feature.create/3`, `retrieve/3`, `update/4` and `list/3`.
  stripe-mock proves request routing and typed decoding against a server generated
  from Stripe's own OpenAPI spec; it does not prove persistent entitlement lifecycle
  semantics.

  Pagination is deliberately **not** asserted here. stripe-mock ignores both the page
  size and the cursor parameter, and returns exactly one synthetic item per list, so
  auto-pagination is structurally unprovable against it. That proof lives in the Mox
  multi-page suites in `test/lattice_stripe/entitlements/`.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Entitlements.ActiveEntitlement
  alias LatticeStripe.Entitlements.Feature

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

  describe "ActiveEntitlement" do
    test "list/3 routes to the canonical list path and decodes typed items", %{client: client} do
      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               ActiveEntitlement.list(client, %{"customer" => "cus_test"})

      assert list.url == "/v1/entitlements/active_entitlements"

      # stripe-mock returns one synthetic item per list regardless of what was
      # asked for, so assert presence and type — never an exact count.
      assert list.data != []
      assert Enum.all?(list.data, &match?(%ActiveEntitlement{}, &1))
    end

    test "retrieve/3 returns a typed struct with the entitlements object tag", %{client: client} do
      assert {:ok, %ActiveEntitlement{} = entitlement} =
               ActiveEntitlement.retrieve(client, "ent_test")

      assert is_binary(entitlement.id)
      assert entitlement.object == "entitlements.active_entitlement"
    end
  end

  describe "Feature" do
    test "create/3 POSTs the list path and echoes the submitted fields", %{client: client} do
      assert {:ok, %Feature{} = feature} =
               Feature.create(client, %{
                 "lookup_key" => "premium_support",
                 "name" => "Premium Support"
               })

      assert feature.lookup_key == "premium_support"
      assert feature.name == "Premium Support"
      assert feature.active == true
    end

    test "retrieve/3 returns a typed struct", %{client: client} do
      assert {:ok, %Feature{} = feature} = Feature.retrieve(client, "feat_test")

      assert is_binary(feature.id)
      assert feature.object == "entitlements.feature"
    end

    test "update/4 POSTs the item path and returns a typed struct", %{client: client} do
      assert {:ok, %Feature{} = feature} =
               Feature.update(client, "feat_test", %{"name" => "Renamed"})

      assert is_binary(feature.id)
      assert feature.object == "entitlements.feature"
    end

    test "list/3 routes to the canonical list path", %{client: client} do
      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               Feature.list(client, %{})

      assert list.url == "/v1/entitlements/features"
      assert Enum.all?(list.data, &match?(%Feature{}, &1))
    end

    test "list/3 accepts the archived filter", %{client: client} do
      # The filter is accepted and routes; stripe-mock's synthetic response does
      # not vary by it, so this proves acceptance only, not filter semantics.
      assert {:ok, %LatticeStripe.Response{status: 200, data: %LatticeStripe.List{} = list}} =
               Feature.list(client, %{"archived" => "true"})

      assert list.url == "/v1/entitlements/features"
    end
  end
end
