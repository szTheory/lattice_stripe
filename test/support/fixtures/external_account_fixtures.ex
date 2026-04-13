defmodule LatticeStripe.Test.Fixtures.ExternalAccount do
  @moduledoc false

  alias LatticeStripe.Test.Fixtures.{BankAccount, Card}

  @doc "A realistic bank_account response payload."
  def bank_account(overrides \\ %{}), do: BankAccount.basic(overrides)

  @doc "A realistic card response payload."
  def card(overrides \\ %{}), do: Card.basic(overrides)

  @doc "A synthetic future-object payload that exercises the `Unknown` fallback branch."
  def unknown(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "xa_future1234567890abc",
        "object" => "future_thing",
        "some_field" => "some_value",
        "nested" => %{"a" => 1}
      },
      overrides
    )
  end

  @doc """
  A mixed paginated list response containing both `bank_account` and `card`
  items (plus an `Unknown` object to prove the dispatcher never crashes on
  novel types).
  """
  def mixed_list(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "list",
        "data" => [
          bank_account(),
          card(),
          unknown()
        ],
        "has_more" => false,
        "url" => "/v1/accounts/acct_test/external_accounts"
      },
      overrides
    )
  end

  @doc "Deleted bank_account response returned by DELETE."
  def deleted_bank_account do
    %{
      "id" => "ba_1OoKqrJ2eZvKYlo2C9hXqGtR",
      "object" => "bank_account",
      "deleted" => true
    }
  end

  @doc "Deleted card response returned by DELETE."
  def deleted_card do
    %{
      "id" => "card_1OoKqrJ2eZvKYlo2C9hXqGtR",
      "object" => "card",
      "deleted" => true
    }
  end
end
