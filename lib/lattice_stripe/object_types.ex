defmodule LatticeStripe.ObjectTypes do
  @moduledoc false

  @object_map %{
    "account"                  => LatticeStripe.Account,
    "account_link"             => LatticeStripe.AccountLink,
    "balance"                  => LatticeStripe.Balance,
    "balance_transaction"      => LatticeStripe.BalanceTransaction,
    "bank_account"             => LatticeStripe.BankAccount,
    "card"                     => LatticeStripe.Card,
    "charge"                   => LatticeStripe.Charge,
    "coupon"                   => LatticeStripe.Coupon,
    "customer"                 => LatticeStripe.Customer,
    "event"                    => LatticeStripe.Event,
    "invoice"                  => LatticeStripe.Invoice,
    "invoiceitem"              => LatticeStripe.InvoiceItem,
    "login_link"               => LatticeStripe.LoginLink,
    "payment_intent"           => LatticeStripe.PaymentIntent,
    "payment_method"           => LatticeStripe.PaymentMethod,
    "payout"                   => LatticeStripe.Payout,
    "price"                    => LatticeStripe.Price,
    "product"                  => LatticeStripe.Product,
    "promotion_code"           => LatticeStripe.PromotionCode,
    "refund"                   => LatticeStripe.Refund,
    "setup_intent"             => LatticeStripe.SetupIntent,
    "subscription"             => LatticeStripe.Subscription,
    "subscription_item"        => LatticeStripe.SubscriptionItem,
    "subscription_schedule"    => LatticeStripe.SubscriptionSchedule,
    "transfer"                 => LatticeStripe.Transfer,
    "transfer_reversal"        => LatticeStripe.TransferReversal,
    "billing.meter"            => LatticeStripe.Billing.Meter,
    "billing_portal.session"   => LatticeStripe.BillingPortal.Session,
    "checkout.session"         => LatticeStripe.Checkout.Session,
    "test_helpers.test_clock"  => LatticeStripe.TestHelpers.TestClock,
    "line_item"                => LatticeStripe.Invoice.LineItem
  }

  @spec maybe_deserialize(map() | String.t() | nil) :: struct() | map() | String.t() | nil
  def maybe_deserialize(nil), do: nil
  def maybe_deserialize(val) when is_binary(val), do: val

  def maybe_deserialize(%{"object" => object_type} = map) do
    case Map.fetch(@object_map, object_type) do
      {:ok, module} -> module.from_map(map)
      :error        -> map
    end
  end

  def maybe_deserialize(map) when is_map(map), do: map
end
