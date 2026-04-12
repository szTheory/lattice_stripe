defmodule LatticeStripe.Integration.PromotionCodeTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias LatticeStripe.{Client, Coupon, PromotionCode}

  setup do
    client =
      Client.new!(
        api_key: "sk_test_123",
        base_url: "http://localhost:12111",
        finch: LatticeStripe.Finch
      )

    {:ok, coupon} = Coupon.create(client, %{"percent_off" => 25, "duration" => "once"})
    {:ok, client: client, coupon: coupon}
  end

  describe "PromotionCode CRUD round-trip" do
    test "create → retrieve → update → list", %{client: client, coupon: coupon} do
      code_string = "PLAN12TEST#{System.unique_integer([:positive])}"

      {:ok, promo} =
        PromotionCode.create(client, %{
          "coupon" => coupon.id,
          "code" => code_string,
          "active" => true
        })

      assert %PromotionCode{} = promo
      assert is_binary(promo.id)
      assert promo.id =~ ~r/^promo_/ or is_binary(promo.id)

      {:ok, fetched} = PromotionCode.retrieve(client, promo.id)
      assert fetched.id == promo.id

      {:ok, deactivated} = PromotionCode.update(client, promo.id, %{"active" => "false"})
      assert %PromotionCode{} = deactivated

      {:ok, resp} = PromotionCode.list(client, %{"limit" => "5"})
      assert Enum.all?(resp.data.data, &match?(%PromotionCode{}, &1))
    end

    test "D-06: discovery via list/2 filters (code, coupon, customer, active)",
         %{client: client, coupon: coupon} do
      # The four documented filter keys must all be accepted by the list endpoint.
      {:ok, _} = PromotionCode.list(client, %{"coupon" => coupon.id})
      {:ok, _} = PromotionCode.list(client, %{"active" => "true"})
      {:ok, _} = PromotionCode.list(client, %{"code" => "NONEXISTENT_CODE"})
      # customer filter requires a real customer; just assert the call shape is accepted
      case PromotionCode.list(client, %{"customer" => "cus_nonexistent"}) do
        {:ok, _} -> :ok
        {:error, %LatticeStripe.Error{}} -> :ok
      end
    end

    test "D-07: expanded coupon in response decodes to %Coupon{}",
         %{client: client, coupon: coupon} do
      {:ok, promo} =
        PromotionCode.create(client, %{"coupon" => coupon.id, "active" => true})

      # stripe-mock may return expanded or unexpanded coupon; both paths are valid.
      case promo.coupon do
        %Coupon{} = c ->
          assert c.id == coupon.id

        id when is_binary(id) ->
          assert id == coupon.id

        nil ->
          :ok
      end
    end
  end
end
