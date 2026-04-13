defmodule LatticeStripe.Test.Fixtures.Balance do
  @moduledoc false

  @doc """
  A multi-currency Balance response with every amount list populated,
  `issuing.available` populated, and `source_types` with a forward-compat
  unknown payment-method key (`"ach_credit_transfer"`) for
  typed-inner-open-outer verification.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "balance",
        "livemode" => false,
        "available" => [
          %{
            "amount" => 12_345,
            "currency" => "usd",
            "source_types" => %{
              "card" => 10_000,
              "bank_account" => 2_000,
              "fpx" => 345,
              "ach_credit_transfer" => 500
            }
          },
          %{
            "amount" => 6_789,
            "currency" => "eur",
            "source_types" => %{"card" => 6_789, "bank_account" => 0, "fpx" => 0}
          }
        ],
        "pending" => [
          %{
            "amount" => 1_000,
            "currency" => "usd",
            "source_types" => %{"card" => 1_000, "bank_account" => 0, "fpx" => 0}
          }
        ],
        "connect_reserved" => [
          %{
            "amount" => 500,
            "currency" => "usd",
            "source_types" => %{"card" => 500, "bank_account" => 0, "fpx" => 0}
          }
        ],
        "instant_available" => [
          %{
            "amount" => 2_000,
            "currency" => "usd",
            "source_types" => %{"card" => 2_000, "bank_account" => 0, "fpx" => 0},
            "net_available" => [
              %{"amount" => 1_950, "destination" => "ba_123"}
            ]
          }
        ],
        "issuing" => %{
          "available" => [
            %{
              "amount" => 750,
              "currency" => "usd",
              "source_types" => %{"card" => 750, "bank_account" => 0, "fpx" => 0}
            }
          ]
        }
      },
      overrides
    )
  end
end
