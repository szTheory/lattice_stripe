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
                     fn ->
                       Feature.create(test_client(), product_id, %{
                         "entitlement_feature" => "feat_123"
                       })
                     end
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

  describe "retrieve/4" do
    test "GETs one explicit prodft attachment under its product" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "#{@path}/prodft_123")
        ok_response(attachment_json())
      end)

      assert {:ok, %Feature{id: "prodft_123"}} =
               Feature.retrieve(test_client(), @product_id, "prodft_123")
    end
  end

  describe "list/4" do
    test "returns a typed empty page" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ @path
        assert req.url =~ "limit=10"
        ok_response(list_json([], @path))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: []}}} =
               Feature.list(test_client(), @product_id, %{"limit" => 10})
    end

    test "preserves attachment wire order" do
      attachments = [
        attachment_json(%{"id" => "prodft_a"}),
        attachment_json(%{"id" => "prodft_b"})
      ]

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json(attachments, @path))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = page}} =
               Feature.list(test_client(), @product_id)

      assert Enum.map(page.data, & &1.id) == ["prodft_a", "prodft_b"]
    end
  end

  describe "delete/4" do
    test "delete addresses one prodft attachment directly and never resolves a feat definition" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "#{@path}/prodft_123")
        ok_response(%{"id" => "prodft_123", "object" => "product_feature", "deleted" => true})
      end)

      assert {:ok, %Feature{id: "prodft_123", object: "product_feature", deleted: true}} =
               Feature.delete(test_client(), @product_id, "prodft_123")
    end

    test "rejects a feat definition id before transport" do
      assert_raise ArgumentError,
                   "LatticeStripe.Product.Feature.delete/4 requires a product feature attachment id, not an entitlement feature definition id",
                   fn -> Feature.delete(test_client(), @product_id, "feat_123") end
    end
  end

  describe "pre-network ID validation" do
    test "every ordinary verb and bang twin rejects nil or empty required IDs before transport" do
      params = %{"entitlement_feature" => "feat_123"}

      for product_id <- [nil, ""] do
        for call <- [
              fn -> Feature.create(test_client(), product_id, params) end,
              fn -> Feature.create!(test_client(), product_id, params) end,
              fn -> Feature.retrieve(test_client(), product_id, "prodft_123") end,
              fn -> Feature.retrieve!(test_client(), product_id, "prodft_123") end,
              fn -> Feature.list(test_client(), product_id) end,
              fn -> Feature.list!(test_client(), product_id) end,
              fn -> Feature.stream!(test_client(), product_id) end,
              fn -> Feature.delete(test_client(), product_id, "prodft_123") end,
              fn -> Feature.delete!(test_client(), product_id, "prodft_123") end
            ] do
          assert_raise ArgumentError, call
        end
      end

      for attachment_id <- [nil, ""] do
        for call <- [
              fn -> Feature.retrieve(test_client(), @product_id, attachment_id) end,
              fn -> Feature.retrieve!(test_client(), @product_id, attachment_id) end,
              fn -> Feature.delete(test_client(), @product_id, attachment_id) end,
              fn -> Feature.delete!(test_client(), @product_id, attachment_id) end
            ] do
          assert_raise ArgumentError, call
        end
      end
    end
  end

  test "two create attempts preserve the caller idempotency key" do
    expect(LatticeStripe.MockTransport, :request, 2, fn req ->
      assert {"idempotency-key", "product-feature-key"} in req.headers
      ok_response(attachment_json())
    end)

    client = test_client()
    params = %{"entitlement_feature" => "feat_123"}

    assert {:ok, %Feature{}} =
             Feature.create(client, @product_id, params, idempotency_key: "product-feature-key")

    assert {:ok, %Feature{}} =
             Feature.create(client, @product_id, params, idempotency_key: "product-feature-key")
  end

  describe "bang twins and transport errors" do
    test "ordinary calls preserve tuples while bang twins return values or raise" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> ok_response(list_json([], @path)) end)
      |> expect(:request, fn _req -> error_response() end)
      |> expect(:request, fn _req -> error_response() end)

      assert %LatticeStripe.Response{} = Feature.list!(test_client(), @product_id)

      assert {:error, %LatticeStripe.Error{}} =
               Feature.retrieve(test_client(), @product_id, "prodft_missing")

      assert_raise LatticeStripe.Error, fn ->
        Feature.retrieve!(test_client(), @product_id, "prodft_missing")
      end
    end
  end

  describe "stream!/4" do
    test "streams typed attachments from the scoped collection" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, @path)
        ok_response(list_json([attachment_json()], @path))
      end)

      assert [%Feature{id: "prodft_123"}] =
               test_client() |> Feature.stream!(@product_id) |> Enum.to_list()
    end
  end

  describe "module surface" do
    test "exports exactly the canonical attachment surface and defaulted arities" do
      for {name, arities} <- [
            create: [3, 4],
            create!: [3, 4],
            retrieve: [3, 4],
            retrieve!: [3, 4],
            list: [2, 3, 4],
            list!: [2, 3, 4],
            stream!: [2, 3, 4],
            delete: [3, 4],
            delete!: [3, 4],
            from_map: [1]
          ],
          arity <- arities do
        assert function_exported?(Feature, name, arity), "expected #{name}/#{arity}"
      end

      for name <- [
            :attach,
            :detach,
            :remove,
            :stream,
            :delete_by_feature,
            :delete_by_entitlement_feature
          ],
          arity <- 1..4 do
        refute function_exported?(Feature, name, arity), "forbidden #{name}/#{arity} leaked"
      end
    end
  end
end
