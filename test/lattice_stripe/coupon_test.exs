defmodule LatticeStripe.CouponTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Coupon
  alias LatticeStripe.Coupon.AppliesTo

  describe "from_map/1 — D-03 atomization" do
    test "duration forever → :forever" do
      assert Coupon.from_map(%{"duration" => "forever"}).duration == :forever
    end

    test "duration once → :once" do
      assert Coupon.from_map(%{"duration" => "once"}).duration == :once
    end

    test "duration repeating → :repeating" do
      assert Coupon.from_map(%{"duration" => "repeating"}).duration == :repeating
    end

    test "duration unknown → raw string" do
      assert Coupon.from_map(%{"duration" => "quarterly"}).duration == "quarterly"
    end

    test "duration nil stays nil" do
      assert Coupon.from_map(%{}).duration == nil
    end
  end

  describe "from_map/1 — D-01 typed applies_to" do
    test "applies_to with products decodes to %Coupon.AppliesTo{}" do
      c = Coupon.from_map(%{"applies_to" => %{"products" => ["prod_a", "prod_b"]}})
      assert %AppliesTo{products: ["prod_a", "prod_b"]} = c.applies_to
    end

    test "applies_to nil stays nil" do
      assert Coupon.from_map(%{"applies_to" => nil}).applies_to == nil
    end

    test "absent applies_to stays nil" do
      assert Coupon.from_map(%{}).applies_to == nil
    end
  end

  describe "from_map/1 — percent_off and amount_off" do
    test "percent_off fractional float preserved on decode" do
      assert Coupon.from_map(%{"percent_off" => 12.5}).percent_off == 12.5
    end

    test "amount_off integer preserved" do
      assert Coupon.from_map(%{"amount_off" => 1000, "currency" => "usd"}).amount_off == 1000
    end
  end

  describe "function surface (D-05 forbidden ops absence)" do
    test "create / retrieve / delete / list / stream! exported" do
      assert function_exported?(Coupon, :create, 2)
      assert function_exported?(Coupon, :retrieve, 2)
      assert function_exported?(Coupon, :delete, 2)
      assert function_exported?(Coupon, :list, 1)
      assert function_exported?(Coupon, :stream!, 1)
    end

    test "D-05: Coupon.update is NOT exported (Coupons are immutable)" do
      refute function_exported?(Coupon, :update, 3)
      refute function_exported?(Coupon, :update, 4)
      refute function_exported?(Coupon, :update!, 3)
    end

    test "D-05: Coupon.search is NOT exported (endpoint does not exist)" do
      refute function_exported?(Coupon, :search, 2)
      refute function_exported?(Coupon, :search, 3)
      refute function_exported?(Coupon, :search!, 2)
    end
  end

  describe "documentation contracts (D-05)" do
    test "@moduledoc documents both forbidden operations" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Coupon)
      assert moduledoc =~ "Operations not supported by the Stripe API"
      assert moduledoc =~ "update"
      assert moduledoc =~ "search"
      assert moduledoc =~ "immutable"
      assert moduledoc =~ "/v1/coupons/search"
    end

    test "@moduledoc documents D-07 custom ID pass-through" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Coupon)
      assert moduledoc =~ "Custom IDs"
      assert moduledoc =~ "SUMMER25"
    end
  end
end
