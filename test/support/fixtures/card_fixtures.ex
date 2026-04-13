defmodule LatticeStripe.Test.Fixtures.Card do
  @moduledoc false

  @doc """
  Returns a realistic string-keyed `card` map matching the Stripe
  `/v1/accounts/:account/external_accounts/card_*` response shape.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "card_1OoKqrJ2eZvKYlo2C9hXqGtR",
        "object" => "card",
        "account" => "acct_1OoKpqJ2eZvKYlo2",
        "address_city" => nil,
        "address_country" => nil,
        "address_line1" => nil,
        "address_line1_check" => nil,
        "address_line2" => nil,
        "address_state" => nil,
        "address_zip" => nil,
        "address_zip_check" => nil,
        "available_payout_methods" => ["standard"],
        "brand" => "Visa",
        "country" => "US",
        "currency" => "usd",
        "customer" => nil,
        "cvc_check" => nil,
        "default_for_currency" => false,
        "dynamic_last4" => nil,
        "exp_month" => 12,
        "exp_year" => 2030,
        "fingerprint" => "fp_card_abcdef1234567890",
        "funding" => "debit",
        "last4" => "4242",
        "metadata" => %{},
        "name" => "Jane Doe",
        "tokenization_method" => nil
      },
      overrides
    )
  end

  @doc "Deleted response returned by DELETE on an external card."
  def deleted(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "card_1OoKqrJ2eZvKYlo2C9hXqGtR",
        "object" => "card",
        "deleted" => true
      },
      overrides
    )
  end
end
