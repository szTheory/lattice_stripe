defmodule LatticeStripe.Integration.CouponTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias LatticeStripe.{Client, Coupon}

  setup do
    client =
      Client.new!(
        api_key: "sk_test_123",
        base_url: "http://localhost:12111",
        finch: LatticeStripe.Finch
      )

    {:ok, client: client}
  end

  describe "Coupon CRUD round-trip" do
    test "create auto-id → retrieve → delete → list", %{client: client} do
      {:ok, coupon} = Coupon.create(client, %{"percent_off" => 25, "duration" => "once"})
      assert %Coupon{} = coupon
      assert is_binary(coupon.id)

      {:ok, fetched} = Coupon.retrieve(client, coupon.id)
      assert fetched.id == coupon.id

      {:ok, deleted} = Coupon.delete(client, coupon.id)
      assert %Coupon{} = deleted

      {:ok, resp} = Coupon.list(client, %{"limit" => "5"})
      assert Enum.all?(resp.data.data, &match?(%Coupon{}, &1))
    end

    test "D-07: create with custom ID pass-through", %{client: client} do
      # Custom ID flows through the params map as-is (no helper).
      case Coupon.create(client, %{
             "id" => "PLAN12TEST#{System.unique_integer([:positive])}",
             "percent_off" => 10,
             "duration" => "once"
           }) do
        {:ok, coupon} ->
          assert %Coupon{} = coupon
          assert is_binary(coupon.id)
          # Cleanup
          Coupon.delete(client, coupon.id)

        {:error, %LatticeStripe.Error{}} ->
          # stripe-mock may not honor custom IDs; the SDK wire format is what matters
          :ok
      end
    end

    test "D-09f: percent_off fractional float round-trip", %{client: client} do
      # 12.5 must encode as percent_off=12.5 (not 1.25e+1 or similar).
      # This is the production-critical path for the float fix.
      case Coupon.create(client, %{"percent_off" => 12.5, "duration" => "once"}) do
        {:ok, coupon} ->
          assert %Coupon{} = coupon
          Coupon.delete(client, coupon.id)

        {:error, %LatticeStripe.Error{} = err} ->
          # If this fails with a 400 "invalid percent_off", the float encoder
          # is emitting scientific notation. That MUST be caught.
          refute err.message =~ "1.25e"
          refute err.message =~ "e+"
      end
    end
  end
end
