defmodule LatticeStripe.Test.Fixtures.Customer do
  @moduledoc false

  def customer_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cus_test1234567890",
        "object" => "customer",
        "email" => "test@example.com",
        "name" => "Test User",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{},
        "deleted" => false
      },
      overrides
    )
  end
end
