defmodule LatticeStripe.ProductTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Product

  describe "from_map/1" do
    test "decodes a minimal product" do
      p = Product.from_map(%{"id" => "prod_1", "object" => "product", "name" => "T"})
      assert p.id == "prod_1"
      assert p.object == "product"
      assert p.name == "T"
    end

    test "D-03: atomizes type=good to :good" do
      p = Product.from_map(%{"type" => "good"})
      assert p.type == :good
    end

    test "D-03: atomizes type=service to :service" do
      p = Product.from_map(%{"type" => "service"})
      assert p.type == :service
    end

    test "D-03: unknown type passes through as raw string (forward compat)" do
      p = Product.from_map(%{"type" => "future_unknown"})
      assert p.type == "future_unknown"
    end

    test "D-03: nil type stays nil" do
      p = Product.from_map(%{})
      assert p.type == nil
    end

    test "unknown fields land in extra" do
      p = Product.from_map(%{"id" => "prod_1", "unknown" => "x"})
      assert p.extra == %{"unknown" => "x"}
    end

    test "deleted defaults to false" do
      p = Product.from_map(%{})
      assert p.deleted == false
    end

    test "deleted=true is captured and does not leak to extra" do
      p = Product.from_map(%{"id" => "prod_1", "deleted" => true})
      assert p.deleted == true
      refute Map.has_key?(p.extra, "deleted")
    end
  end

  describe "function surface (D-05 absence)" do
    test "create/2,3 exported" do
      assert function_exported?(Product, :create, 2)
      assert function_exported?(Product, :create, 3)
    end

    test "retrieve/2,3 exported" do
      assert function_exported?(Product, :retrieve, 2)
      assert function_exported?(Product, :retrieve, 3)
    end

    test "update/3,4 exported" do
      assert function_exported?(Product, :update, 3)
      assert function_exported?(Product, :update, 4)
    end

    test "list/1,2,3 exported" do
      assert function_exported?(Product, :list, 1)
    end

    test "stream!/1,2,3 exported" do
      assert function_exported?(Product, :stream!, 1)
    end

    test "search/2,3 exported (D-04)" do
      assert function_exported?(Product, :search, 2)
      assert function_exported?(Product, :search, 3)
    end

    test "search_stream!/2,3 exported" do
      assert function_exported?(Product, :search_stream!, 2)
    end

    test "D-05: delete is NOT exported (Stripe has no delete endpoint for Products)" do
      refute function_exported?(Product, :delete, 2)
      refute function_exported?(Product, :delete, 3)
      refute function_exported?(Product, :delete!, 2)
    end
  end

  describe "documentation contracts" do
    test "D-10: search/3 @doc contains eventual-consistency callout" do
      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Product)

      search_doc =
        Enum.find_value(docs, fn
          {{:function, :search, 3}, _, _, %{"en" => doc}, _} -> doc
          _ -> nil
        end)

      assert is_binary(search_doc)
      assert search_doc =~ "eventual consistency"
      assert search_doc =~ "https://docs.stripe.com/search#data-freshness"
    end

    test "D-05: @moduledoc documents absent delete operation" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Product)
      assert moduledoc =~ "Operations not supported by the Stripe API"
      assert moduledoc =~ "delete"
      assert moduledoc =~ "active"
    end
  end
end
