defmodule LatticeStripe.Test.Fixtures.Transfer do
  @moduledoc false

  import LatticeStripe.Test.Fixtures.TransferReversal, only: [transfer_reversal_json: 1]

  @transfer_id "tr_1OoMnpJ2eZvKYlo21fGhIjKl"
  @destination "acct_1Nv0FGQ9RKHgCVdK"

  def transfer_id, do: @transfer_id
  def destination, do: @destination

  def transfer_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => @transfer_id,
        "object" => "transfer",
        "amount" => 1_000,
        "amount_reversed" => 0,
        "balance_transaction" => "txn_1OoMnpJ2eZvKYlo2abcdefgh",
        "created" => 1_700_000_000,
        "currency" => "usd",
        "description" => "Payout to connected account",
        "destination" => @destination,
        "destination_payment" => "py_1OoMnpJ2eZvKYlo2destpay01",
        "livemode" => false,
        "metadata" => %{},
        "reversals" => %{
          "object" => "list",
          "data" => [],
          "has_more" => false,
          "url" => "/v1/transfers/#{@transfer_id}/reversals",
          "total_count" => 0
        },
        "reversed" => false,
        "source_transaction" => nil,
        "source_type" => "card",
        "transfer_group" => "ORDER_100"
      },
      overrides
    )
  end

  def transfer_with_reversals_json do
    reversals = [
      transfer_reversal_json(%{"id" => "trr_1OoMpqJ2eZvKYlo20a", "amount" => 100}),
      transfer_reversal_json(%{"id" => "trr_1OoMpqJ2eZvKYlo20b", "amount" => 200}),
      transfer_reversal_json(%{"id" => "trr_1OoMpqJ2eZvKYlo20c", "amount" => 300})
    ]

    transfer_json(%{
      "amount_reversed" => 600,
      "reversals" => %{
        "object" => "list",
        "data" => reversals,
        "has_more" => false,
        "url" => "/v1/transfers/#{@transfer_id}/reversals",
        "total_count" => 3
      }
    })
  end

  def transfer_list_json(items \\ nil) do
    default_items = items || [transfer_json()]

    %{
      "object" => "list",
      "data" => default_items,
      "has_more" => false,
      "url" => "/v1/transfers"
    }
  end
end
