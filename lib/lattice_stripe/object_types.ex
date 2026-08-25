defmodule LatticeStripe.ObjectTypes do
  @moduledoc false

  @object_map %{
    "account" => LatticeStripe.Account,
    "account_link" => LatticeStripe.AccountLink,
    "balance" => LatticeStripe.Balance,
    "balance_transaction" => LatticeStripe.BalanceTransaction,
    "bank_account" => LatticeStripe.BankAccount,
    "card" => LatticeStripe.Card,
    "charge" => LatticeStripe.Charge,
    "coupon" => LatticeStripe.Coupon,
    "credit_note" => LatticeStripe.CreditNote,
    "credit_note_line_item" => LatticeStripe.CreditNote.LineItem,
    "customer" => LatticeStripe.Customer,
    "dispute" => LatticeStripe.Dispute,
    "event" => LatticeStripe.Event,
    "file" => LatticeStripe.File,
    "file_link" => LatticeStripe.FileLink,
    "invoice" => LatticeStripe.Invoice,
    "invoiceitem" => LatticeStripe.InvoiceItem,
    "login_link" => LatticeStripe.LoginLink,
    "mandate" => LatticeStripe.Mandate,
    "payment_intent" => LatticeStripe.PaymentIntent,
    "payment_method" => LatticeStripe.PaymentMethod,
    "payout" => LatticeStripe.Payout,
    "price" => LatticeStripe.Price,
    "product" => LatticeStripe.Product,
    "product_feature" => LatticeStripe.Product.Feature,
    "promotion_code" => LatticeStripe.PromotionCode,
    "quote" => LatticeStripe.Quote,
    "quote_line_item" => LatticeStripe.Quote.LineItem,
    "refund" => LatticeStripe.Refund,
    "setup_attempt" => LatticeStripe.SetupAttempt,
    "setup_intent" => LatticeStripe.SetupIntent,
    "subscription" => LatticeStripe.Subscription,
    "subscription_item" => LatticeStripe.SubscriptionItem,
    "subscription_schedule" => LatticeStripe.SubscriptionSchedule,
    "tax.calculation" => LatticeStripe.Tax.Calculation,
    "tax.calculation_line_item" => LatticeStripe.Tax.Calculation.LineItem,
    "tax.registration" => LatticeStripe.Tax.Registration,
    "tax.settings" => LatticeStripe.Tax.Settings,
    "tax.transaction" => LatticeStripe.Tax.Transaction,
    "tax.transaction_line_item" => LatticeStripe.Tax.Transaction.LineItem,
    "tax_id" => LatticeStripe.TaxId,
    "transfer" => LatticeStripe.Transfer,
    "transfer_reversal" => LatticeStripe.TransferReversal,
    "billing.meter" => LatticeStripe.Billing.Meter,
    "billing.meter_event" => LatticeStripe.Billing.MeterEvent,
    "billing.meter_event_summary" => LatticeStripe.Billing.MeterEventSummary,
    "billing_portal.configuration" => LatticeStripe.BillingPortal.Configuration,
    "billing_portal.session" => LatticeStripe.BillingPortal.Session,
    "checkout.session" => LatticeStripe.Checkout.Session,
    "test_helpers.test_clock" => LatticeStripe.TestHelpers.TestClock,
    "line_item" => LatticeStripe.Invoice.LineItem,
    "entitlements.active_entitlement" => LatticeStripe.Entitlements.ActiveEntitlement,
    "entitlements.active_entitlement_summary" =>
      LatticeStripe.Entitlements.ActiveEntitlementSummary
  }

  @doc false
  def object_map, do: @object_map

  @doc """
  Looks up the LatticeStripe module for a Stripe object type string.

  Returns `{:ok, module}` for known types and `:error` for unknown types.
  Used by `LatticeStripe.Webhook.fetch_related_object/3` to gate HTTP requests
  behind dispatch-table membership (fail fast on unknown types — see Phase 47 D-05).
  """
  @spec fetch_module(String.t() | nil) :: {:ok, module()} | :error
  def fetch_module(nil), do: :error
  def fetch_module(type) when is_binary(type), do: Map.fetch(@object_map, type)

  @spec maybe_deserialize(term()) :: term()
  def maybe_deserialize(%{"object" => object_type} = map) do
    case Map.fetch(@object_map, object_type) do
      {:ok, module} -> module.from_map(map)
      :error -> map
    end
  end

  def maybe_deserialize(value), do: value
end
