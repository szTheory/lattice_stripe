defmodule LatticeStripe.Test.Fixtures.LoginLink do
  @moduledoc false

  @doc """
  Basic LoginLink fixture (Express-only). Includes an unknown top-level key to exercise
  F-001 `:extra` map split.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "login_link",
        "created" => 1_700_000_000,
        "url" => "https://connect.stripe.com/express/Ln7F...",
        "zzz_forward_compat_field" => "extra_value"
      },
      overrides
    )
  end
end
