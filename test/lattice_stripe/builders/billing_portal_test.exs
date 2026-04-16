defmodule LatticeStripe.Builders.BillingPortalTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Builders.BillingPortal, as: BPBuilder
  alias LatticeStripe.BillingPortal.Guards

  @moduletag :billing_portal

  describe "subscription_cancel/2" do
    test "subscription_cancel/1 with just subscription_id produces correct shape" do
      flow = BPBuilder.subscription_cancel("sub_abc")
      assert flow["type"] == "subscription_cancel"
      assert flow["subscription_cancel"]["subscription"] == "sub_abc"
      refute Map.has_key?(flow["subscription_cancel"], "retention")
    end

    test "subscription_cancel/2 with retention option includes retention key" do
      retention = %{"type" => "coupon_offer", "coupon_offer" => %{"coupon" => "10OFF"}}
      flow = BPBuilder.subscription_cancel("sub_abc", retention: retention)
      assert flow["subscription_cancel"]["retention"] == retention
    end

    test "subscription_cancel/2 with after_completion option includes after_completion key" do
      after_completion = %{"type" => "redirect", "redirect" => %{"return_url" => "https://example.com"}}
      flow = BPBuilder.subscription_cancel("sub_abc", after_completion: after_completion)
      assert flow["after_completion"] == after_completion
    end

    test "subscription_cancel output passes Guards.check_flow_data!/1" do
      flow = BPBuilder.subscription_cancel("sub_abc")
      assert Guards.check_flow_data!(%{"flow_data" => flow}) == :ok
    end
  end

  describe "subscription_update/2" do
    test "subscription_update/1 produces correct shape" do
      flow = BPBuilder.subscription_update("sub_abc")
      assert flow["type"] == "subscription_update"
      assert flow["subscription_update"]["subscription"] == "sub_abc"
    end

    test "subscription_update/2 with after_completion option includes after_completion key" do
      after_completion = %{"type" => "hosted_confirmation"}
      flow = BPBuilder.subscription_update("sub_abc", after_completion: after_completion)
      assert flow["after_completion"] == after_completion
    end

    test "subscription_update output passes Guards.check_flow_data!/1" do
      flow = BPBuilder.subscription_update("sub_abc")
      assert Guards.check_flow_data!(%{"flow_data" => flow}) == :ok
    end
  end

  describe "subscription_update_confirm/3" do
    test "subscription_update_confirm/2 with subscription and items produces correct shape" do
      items = [%{"id" => "si_abc", "price" => "price_123"}]
      flow = BPBuilder.subscription_update_confirm("sub_abc", items)
      assert flow["type"] == "subscription_update_confirm"
      assert flow["subscription_update_confirm"]["subscription"] == "sub_abc"
      assert flow["subscription_update_confirm"]["items"] == items
    end

    test "subscription_update_confirm/3 with discounts option includes discounts key" do
      items = [%{"id" => "si_abc"}]
      discounts = [%{"coupon" => "10OFF"}]
      flow = BPBuilder.subscription_update_confirm("sub_abc", items, discounts: discounts)
      assert flow["subscription_update_confirm"]["discounts"] == discounts
    end

    test "subscription_update_confirm/3 with after_completion option includes after_completion key" do
      items = [%{"id" => "si_abc"}]
      after_completion = %{"type" => "redirect", "redirect" => %{"return_url" => "https://example.com"}}
      flow = BPBuilder.subscription_update_confirm("sub_abc", items, after_completion: after_completion)
      assert flow["after_completion"] == after_completion
    end

    test "subscription_update_confirm output passes Guards.check_flow_data!/1" do
      items = [%{"id" => "si_abc"}]
      flow = BPBuilder.subscription_update_confirm("sub_abc", items)
      assert Guards.check_flow_data!(%{"flow_data" => flow}) == :ok
    end

    test "raises FunctionClauseError when items is empty list" do
      assert_raise FunctionClauseError, fn ->
        BPBuilder.subscription_update_confirm("sub_abc", [])
      end
    end
  end

  describe "payment_method_update/1" do
    test "payment_method_update/0 produces correct shape" do
      flow = BPBuilder.payment_method_update()
      assert flow["type"] == "payment_method_update"
      assert map_size(flow) == 1
    end

    test "payment_method_update/1 with after_completion option includes after_completion key" do
      after_completion = %{"type" => "hosted_confirmation"}
      flow = BPBuilder.payment_method_update(after_completion: after_completion)
      assert flow["after_completion"] == after_completion
    end

    test "payment_method_update output passes Guards.check_flow_data!/1" do
      flow = BPBuilder.payment_method_update()
      assert Guards.check_flow_data!(%{"flow_data" => flow}) == :ok
    end
  end
end
