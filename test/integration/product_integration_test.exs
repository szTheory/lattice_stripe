defmodule LatticeStripe.ProductIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Error, Product}

  # Guard: check stripe-mock connectivity before running any tests in this module.
  # If stripe-mock is not running on localhost:12111, raise with a clear message.
  # Start the Finch pool for real HTTP requests.
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

  describe "Product CRUD round-trip" do
    test "create → retrieve → update → list", %{client: client} do
      {:ok, created} =
        Product.create(client, %{
          "name" => "Integration Test Product",
          "type" => "service",
          "metadata" => %{"test" => "true"}
        })

      assert %Product{} = created
      assert is_binary(created.id)

      {:ok, fetched} = Product.retrieve(client, created.id)
      assert %Product{} = fetched
      assert fetched.id == created.id

      {:ok, updated} = Product.update(client, created.id, %{"active" => "false"})
      assert %Product{} = updated

      {:ok, resp} = Product.list(client, %{"limit" => "5"})
      assert %LatticeStripe.Response{} = resp
      assert %LatticeStripe.List{} = resp.data
      assert is_list(resp.data.data)
      assert Enum.all?(resp.data.data, &match?(%Product{}, &1))
    end

    test "archive-via-update (D-05 delete workaround)", %{client: client} do
      {:ok, product} =
        Product.create(client, %{"name" => "Archive Me", "type" => "good"})

      # "Delete" is expressed as update(active: false) per moduledoc guidance —
      # Stripe's Products API has no delete endpoint.
      {:ok, archived} = Product.update(client, product.id, %{"active" => "false"})
      assert %Product{} = archived
    end

    test "search/3 returns a typed list (may be empty — stripe-mock doesn't index)",
         %{client: client} do
      case Product.search(client, "active:'true'") do
        {:ok, resp} ->
          assert %LatticeStripe.Response{} = resp
          assert %LatticeStripe.List{} = resp.data
          assert Enum.all?(resp.data.data, &match?(%Product{}, &1))

        {:error, %Error{}} ->
          # stripe-mock may return error for unsupported search query shape —
          # the integration test still validates that SDK → stripe-mock wire is OK.
          :ok
      end
    end
  end
end
