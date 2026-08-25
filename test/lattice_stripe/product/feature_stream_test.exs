defmodule LatticeStripe.Product.FeatureStreamTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Product.Feature

  setup :verify_on_exit!

  @product_id "prod_123"
  @path "/v1/products/#{@product_id}/features"

  test "page 2 preserves Product scope filters options cursor order and type" do
    params = %{"limit" => 2, "expand" => ["data.entitlement_feature"]}

    LatticeStripe.MockTransport
    |> expect(:request, fn req ->
      assert req.method == :get
      assert URI.parse(req.url).path == @path
      assert {"stripe-account", "acct_connected"} in req.headers
      assert {"idempotency-key", "product-feature-key"} in req.headers
      list_response([product_feature("prodft_a"), product_feature("prodft_b")], true)
    end)
    |> expect(:request, fn req ->
      assert req.method == :get
      assert URI.parse(req.url).path == @path
      assert {"stripe-account", "acct_connected"} in req.headers
      refute Enum.any?(req.headers, fn {key, _value} -> key == "idempotency-key" end)

      query = URI.decode_query(URI.parse(req.url).query)
      assert query["starting_after"] == "prodft_b"
      assert query["limit"] == "2"
      assert query["expand[0]"] == "data.entitlement_feature"

      list_response([product_feature("prodft_c")], false)
    end)

    items =
      test_client()
      |> Feature.stream!(
        @product_id,
        params,
        stripe_account: "acct_connected",
        idempotency_key: "product-feature-key"
      )
      |> Enum.to_list()

    assert Enum.map(items, & &1.id) == ["prodft_a", "prodft_b", "prodft_c"]
    assert Enum.all?(items, &match?(%Feature{}, &1))
  end

  test "early termination does not fetch page 2" do
    expect(LatticeStripe.MockTransport, :request, 1, fn _req ->
      list_response([product_feature("prodft_a"), product_feature("prodft_b")], true)
    end)

    assert [%Feature{id: "prodft_a"}] =
             test_client()
             |> Feature.stream!(@product_id)
             |> Stream.take(1)
             |> Enum.to_list()
  end

  test "an empty first page yields an empty stream in one call" do
    expect(LatticeStripe.MockTransport, :request, 1, fn _req -> list_response([], false) end)

    assert test_client() |> Feature.stream!(@product_id) |> Enum.to_list() == []
  end

  test "later page error raises instead of returning a partial catalog" do
    LatticeStripe.MockTransport
    |> expect(:request, fn _req -> list_response([product_feature("prodft_a")], true) end)
    |> expect(:request, fn _req -> error_response(500) end)

    assert_raise LatticeStripe.Error, fn ->
      test_client() |> Feature.stream!(@product_id) |> Enum.to_list()
    end
  end

  defp list_response(items, has_more) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_#{System.unique_integer([:positive])}"}],
       body:
         Jason.encode!(%{
           "object" => "list",
           "data" => items,
           "has_more" => has_more,
           "url" => @path
         })
     }}
  end

  defp error_response(status) do
    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_err_#{System.unique_integer([:positive])}"}],
       body:
         Jason.encode!(%{
           "error" => %{"type" => "api_error", "message" => "Server error", "code" => nil}
         })
     }}
  end

  defp product_feature(id, overrides \\ %{}) do
    %{
      "id" => id,
      "object" => "product_feature",
      "livemode" => false,
      "entitlement_feature" => %{
        "id" => "feat_#{id}",
        "object" => "entitlements.feature",
        "active" => true,
        "lookup_key" => "premium_support",
        "name" => "Premium Support",
        "metadata" => %{},
        "livemode" => false
      }
    }
    |> Map.merge(overrides)
  end
end
