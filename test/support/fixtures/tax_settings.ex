defmodule LatticeStripe.Test.Fixtures.TaxSettings do
  @moduledoc false

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "tax.settings",
        "livemode" => false,
        "status" => "active",
        "defaults" => %{
          "tax_behavior" => "exclusive",
          "tax_code" => "txcd_99999999",
          "provider" => "stripe"
        },
        "head_office" => %{
          "address" => %{
            "line1" => "123 Main St",
            "city" => "San Francisco",
            "state" => "CA",
            "postal_code" => "94103",
            "country" => "US"
          }
        },
        "status_details" => %{
          "active" => %{"jurisdictions" => []},
          "pending" => %{}
        }
      },
      overrides
    )
  end
end
