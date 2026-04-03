defmodule LatticeStripe.Test.Fixtures.Checkout.Session do
  @moduledoc false

  def checkout_session_payment_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cs_test1234567890abc",
        "object" => "checkout.session",
        "mode" => "payment",
        "status" => "open",
        "payment_status" => "unpaid",
        "amount_subtotal" => 2000,
        "amount_total" => 2000,
        "currency" => "usd",
        "cancel_url" => "https://example.com/cancel",
        "success_url" => "https://example.com/success",
        "url" => "https://checkout.stripe.com/c/pay/cs_test1234567890abc",
        "payment_intent" => "pi_test1234567890abc",
        "subscription" => nil,
        "setup_intent" => nil,
        "customer" => nil,
        "customer_email" => nil,
        "customer_details" => nil,
        "client_secret" => nil,
        "created" => 1_700_000_000,
        "expires_at" => 1_700_086_400,
        "livemode" => false,
        "metadata" => %{},
        "line_items" => nil,
        "locale" => nil,
        "phone_number_collection" => %{"enabled" => false},
        "shipping_address_collection" => nil,
        "shipping_cost" => nil,
        "shipping_details" => nil,
        "shipping_options" => [],
        "tax_id_collection" => %{"enabled" => false},
        "total_details" => %{
          "amount_discount" => 0,
          "amount_shipping" => 0,
          "amount_tax" => 0
        },
        "ui_mode" => "hosted",
        "return_url" => nil,
        "redirect_on_completion" => "always",
        "payment_method_types" => ["card"],
        "payment_method_options" => %{}
      },
      overrides
    )
  end

  def checkout_session_subscription_json(overrides \\ %{}) do
    Map.merge(
      checkout_session_payment_json(%{
        "mode" => "subscription",
        "subscription" => "sub_test123",
        "payment_intent" => nil,
        "payment_status" => "unpaid"
      }),
      overrides
    )
  end

  def checkout_session_setup_json(overrides \\ %{}) do
    Map.merge(
      checkout_session_payment_json(%{
        "mode" => "setup",
        "setup_intent" => "seti_test123",
        "payment_intent" => nil,
        "subscription" => nil,
        "amount_subtotal" => nil,
        "amount_total" => nil,
        "currency" => nil,
        "payment_status" => "no_payment_required"
      }),
      overrides
    )
  end

  def checkout_session_expired_json(overrides \\ %{}) do
    Map.merge(
      checkout_session_payment_json(%{
        "status" => "expired",
        "url" => nil
      }),
      overrides
    )
  end
end
