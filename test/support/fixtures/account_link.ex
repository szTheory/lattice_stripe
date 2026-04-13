defmodule LatticeStripe.Test.Fixtures.AccountLink do
  @moduledoc false

  @doc """
  Basic AccountLink fixture. Includes an unknown top-level key to exercise F-001 `:extra` map split.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "account_link",
        "created" => 1_700_000_000,
        "expires_at" => 1_700_000_300,
        "url" => "https://connect.stripe.com/setup/e/acct_test/xyz",
        "zzz_forward_compat_field" => "extra_value"
      },
      overrides
    )
  end
end
