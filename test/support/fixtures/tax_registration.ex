defmodule LatticeStripe.Test.Fixtures.TaxRegistration do
  @moduledoc false

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "taxreg_123",
        "object" => "tax.registration",
        "country" => "US",
        "status" => "active",
        "livemode" => false,
        "created" => 1_700_000_000,
        "active_from" => 1_700_000_000,
        "expires_at" => nil,
        "country_options" => %{
          "us" => %{"type" => "state_sales_tax", "state" => "CA"}
        }
      },
      overrides
    )
  end
end
