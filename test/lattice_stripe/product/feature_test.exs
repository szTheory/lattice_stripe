defmodule LatticeStripe.Product.FeatureTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Entitlements.Feature, as: EntitlementsFeature
  alias LatticeStripe.Product.Feature

  setup :verify_on_exit!

  @product_id "prod_123"
  @path "/v1/products/#{@product_id}/features"

  defp attachment_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "prodft_123",
        "object" => "product_feature",
        "livemode" => false,
        "entitlement_feature" => %{
          "id" => "feat_123",
          "object" => "entitlements.feature",
          "active" => true,
          "lookup_key" => "premium_support",
          "name" => "Premium Support",
          "metadata" => %{},
          "livemode" => false
        }
      },
      overrides
    )
  end

  @tag :tracer
  test "create/4 posts to the scoped product collection and returns a typed attachment" do
    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, @path)
      assert req.body =~ "entitlement_feature=feat_123"
      assert {"stripe-account", "acct_123"} in req.headers

      ok_response(attachment_json())
    end)

    assert {:ok,
            %Feature{
              id: "prodft_123",
              object: "product_feature",
              entitlement_feature: %EntitlementsFeature{id: "feat_123"}
            }} =
             Feature.create(
               test_client(),
               @product_id,
               %{"entitlement_feature" => "feat_123"},
               stripe_account: "acct_123"
             )
  end

  describe "create/4 pre-network guards" do
    test "requires entitlement_feature before transport" do
      assert_raise ArgumentError,
                   "LatticeStripe.Product.Feature.create/4 requires an entitlement_feature param",
                   fn -> Feature.create(test_client(), @product_id, %{}) end
    end

    test "rejects nil and empty product IDs before transport" do
      for product_id <- [nil, ""] do
        assert_raise ArgumentError,
                     "LatticeStripe.Product.Feature.create/4 requires a non-empty product id",
                     fn -> Feature.create(test_client(), product_id, %{"entitlement_feature" => "feat_123"}) end
      end
    end
  end

  describe "Product.Feature.from_map/1" do
    test "returns nil for nil" do
      assert Feature.from_map(nil) == nil
    end

    test "is idempotent on an already-typed attachment" do
      once = Feature.from_map(attachment_json())
      assert Feature.from_map(once) == once
    end

    test "decodes exact defaults, the nested definition, and unknown extras" do
      attachment = Feature.from_map(attachment_json(%{"future_field" => "surprise"}))

      assert %Feature{
               id: "prodft_123",
               object: "product_feature",
               deleted: false,
               entitlement_feature: %EntitlementsFeature{id: "feat_123"},
               extra: %{"future_field" => "surprise"}
             } = attachment
    end
  end
end
