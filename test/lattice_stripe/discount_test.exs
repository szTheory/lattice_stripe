defmodule LatticeStripe.DiscountTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Discount

  describe "from_map/1" do
    test "decodes a minimal discount map" do
      result = Discount.from_map(%{"id" => "di_1", "object" => "discount"})
      assert %Discount{id: "di_1", object: "discount"} = result
      assert result.extra == %{}
    end

    test "decodes start and end unix timestamps" do
      result = Discount.from_map(%{"start" => 1_700_000_000, "end" => 1_800_000_000})
      assert result.start == 1_700_000_000
      assert result.end == 1_800_000_000
    end

    test "the :end field is accessible at runtime (reserved-keyword safety)" do
      result = Discount.from_map(%{"end" => 42})
      # Dot access compiles to Map.get(:end) — this must not raise or return nil.
      assert result.end == 42
    end

    test "decodes all parent-ID fields" do
      result =
        Discount.from_map(%{
          "customer" => "cus_1",
          "subscription" => "sub_1",
          "invoice" => "in_1",
          "invoice_item" => "ii_1",
          "checkout_session" => "cs_1",
          "promotion_code" => "promo_1"
        })

      assert result.customer == "cus_1"
      assert result.subscription == "sub_1"
      assert result.invoice == "in_1"
      assert result.invoice_item == "ii_1"
      assert result.checkout_session == "cs_1"
      assert result.promotion_code == "promo_1"
    end

    test "coupon unexpanded (string ID) stays as string" do
      result = Discount.from_map(%{"coupon" => "cpn_abc"})
      assert result.coupon == "cpn_abc"
    end

    test "coupon expanded (map) decodes to %Coupon{} (Plan 06 tightening)" do
      coupon_map = %{"id" => "cpn_abc", "object" => "coupon", "percent_off" => 25}
      result = Discount.from_map(%{"coupon" => coupon_map})
      assert %LatticeStripe.Coupon{id: "cpn_abc", percent_off: 25} = result.coupon
    end

    test "coupon nil stays nil" do
      result = Discount.from_map(%{"coupon" => nil})
      assert result.coupon == nil
    end

    test "empty map produces struct with all fields nil, extra empty" do
      result = Discount.from_map(%{})
      assert %Discount{} = result
      assert result.id == nil
      assert result.coupon == nil
      assert result.extra == %{}
    end

    test "unknown fields land in extra" do
      result = Discount.from_map(%{"id" => "di_1", "unknown_future" => "x"})
      assert result.extra == %{"unknown_future" => "x"}
    end
  end

  describe "defstruct" do
    test "struct has default object of 'discount'" do
      assert %Discount{}.object == "discount"
    end

    test "struct has default extra of empty map" do
      assert %Discount{}.extra == %{}
    end
  end

  describe "from_map/1 — D-08 coupon dispatch (tightened in Plan 06)" do
    alias LatticeStripe.Coupon

    test "expanded coupon (map) decodes to %Coupon{}" do
      result =
        LatticeStripe.Discount.from_map(%{
          "id" => "di_1",
          "coupon" => %{"id" => "cpn_1", "object" => "coupon", "percent_off" => 25}
        })

      assert %Coupon{id: "cpn_1", percent_off: 25} = result.coupon
    end

    test "unexpanded coupon (string ID) stays as string" do
      result = LatticeStripe.Discount.from_map(%{"coupon" => "cpn_1"})
      assert result.coupon == "cpn_1"
    end

    test "nil coupon stays nil" do
      assert LatticeStripe.Discount.from_map(%{"coupon" => nil}).coupon == nil
    end
  end
end
