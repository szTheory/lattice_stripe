defmodule LatticeStripe.Testing.Fixtures.TaxId do
  @moduledoc """
  Canonical raw fixtures for Stripe TaxId objects.
  """

  @spec tax_id_json(map()) :: map()
  def tax_id_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "txi_test123",
        "object" => "tax_id",
        "country" => "DE",
        "created" => 1_700_000_000,
        "livemode" => false,
        "type" => "eu_vat",
        "value" => "DE123456789",
        "verification" => %{"status" => "pending"}
      },
      overrides
    )
  end
end
