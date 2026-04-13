defmodule LatticeStripe.Test.Fixtures.BankAccount do
  @moduledoc false

  @doc """
  Returns a realistic string-keyed `bank_account` map matching the Stripe
  `/v1/accounts/:account/external_accounts/ba_*` response shape.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "ba_1OoKqrJ2eZvKYlo2C9hXqGtR",
        "object" => "bank_account",
        "account" => "acct_1OoKpqJ2eZvKYlo2",
        "account_holder_name" => "Jane Doe",
        "account_holder_type" => "individual",
        "account_type" => "checking",
        "available_payout_methods" => ["standard", "instant"],
        "bank_name" => "STRIPE TEST BANK",
        "country" => "US",
        "currency" => "usd",
        "customer" => nil,
        "default_for_currency" => true,
        "fingerprint" => "fp_ba_abcdef1234567890",
        "last4" => "6789",
        "metadata" => %{},
        "routing_number" => "110000000",
        "status" => "new"
      },
      overrides
    )
  end

  @doc "Variant that includes the pre-tokenization `account_number` PII field (must stay out of inspect output)."
  def with_account_number(overrides \\ %{}) do
    basic(Map.merge(%{"account_number" => "000123456789"}, overrides))
  end

  @doc "Deleted response returned by DELETE on an external account."
  def deleted(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "ba_1OoKqrJ2eZvKYlo2C9hXqGtR",
        "object" => "bank_account",
        "deleted" => true
      },
      overrides
    )
  end
end
