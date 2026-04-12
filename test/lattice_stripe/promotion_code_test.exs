defmodule LatticeStripe.PromotionCodeTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Coupon, PromotionCode}

  describe "from_map/1" do
    test "decodes minimal promotion code" do
      pc = PromotionCode.from_map(%{"id" => "promo_1", "code" => "SAVE10", "active" => true})
      assert pc.id == "promo_1"
      assert pc.code == "SAVE10"
      assert pc.active == true
      assert pc.object == "promotion_code"
    end

    test "coupon nil stays nil" do
      assert PromotionCode.from_map(%{"coupon" => nil}).coupon == nil
    end

    test "coupon unexpanded (string ID) stays as string" do
      assert PromotionCode.from_map(%{"coupon" => "SUMMER25"}).coupon == "SUMMER25"
    end

    test "coupon expanded (map) decodes to %Coupon{}" do
      pc =
        PromotionCode.from_map(%{
          "coupon" => %{
            "id" => "SUMMER25",
            "object" => "coupon",
            "percent_off" => 25,
            "duration" => "once"
          }
        })

      assert %Coupon{id: "SUMMER25", percent_off: 25, duration: :once} = pc.coupon
    end

    test "unknown fields land in extra" do
      pc = PromotionCode.from_map(%{"id" => "promo_1", "future_field" => "x"})
      assert pc.extra == %{"future_field" => "x"}
    end
  end

  describe "function surface (D-04 D-05 absences)" do
    setup do
      Code.ensure_loaded!(PromotionCode)
      :ok
    end

    test "CRUD-minus-delete-and-search exported" do
      assert function_exported?(PromotionCode, :create, 2)
      assert function_exported?(PromotionCode, :retrieve, 2)
      assert function_exported?(PromotionCode, :update, 3)
      assert function_exported?(PromotionCode, :list, 1)
      assert function_exported?(PromotionCode, :stream!, 1)
    end

    test "D-04/D-05: search is NOT exported (endpoint does not exist)" do
      refute function_exported?(PromotionCode, :search, 2)
      refute function_exported?(PromotionCode, :search, 3)
      refute function_exported?(PromotionCode, :search!, 2)
    end

    test "delete is NOT exported (not in Stripe API)" do
      refute function_exported?(PromotionCode, :delete, 2)
      refute function_exported?(PromotionCode, :delete, 3)
    end
  end

  describe "documentation contracts" do
    test "D-07: @moduledoc distinguishes the three identifiers" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(PromotionCode)
      assert moduledoc =~ "Identifiers"
      assert moduledoc =~ "Coupon.id"
      assert moduledoc =~ "PromotionCode.id"
      assert moduledoc =~ "PromotionCode.code"
      assert moduledoc =~ "SUMMER25USER"
      assert moduledoc =~ "promo_"
    end

    test "D-06: @moduledoc documents the list/2 discovery path with four filter keys" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(PromotionCode)
      assert moduledoc =~ "Finding promotion codes"
      assert moduledoc =~ ~r/\bcode\b/
      assert moduledoc =~ ~r/\bcoupon\b/
      assert moduledoc =~ ~r/\bcustomer\b/
      assert moduledoc =~ ~r/\bactive\b/
    end

    test "D-05: @moduledoc documents forbidden operations" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(PromotionCode)
      assert moduledoc =~ "Operations not supported by the Stripe API"
      assert moduledoc =~ "search"
      assert moduledoc =~ "delete"
      assert moduledoc =~ "/v1/promotion_codes/search"
    end
  end
end
