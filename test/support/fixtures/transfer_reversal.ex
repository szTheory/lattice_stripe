defmodule LatticeStripe.Test.Fixtures.TransferReversal do
  @moduledoc false

  def transfer_reversal_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "trr_1OoMpqJ2eZvKYlo20wxYzAbC",
        "object" => "transfer_reversal",
        "amount" => 500,
        "balance_transaction" => "txn_1OoMpqJ2eZvKYlo2abcd1234",
        "created" => 1_700_000_000,
        "currency" => "usd",
        "destination_payment_refund" => nil,
        "metadata" => %{},
        "source_refund" => nil,
        "transfer" => "tr_1OoMnpJ2eZvKYlo21fGhIjKl"
      },
      overrides
    )
  end

  def transfer_reversal_list_json(items \\ nil, url \\ nil) do
    transfer_id = "tr_1OoMnpJ2eZvKYlo21fGhIjKl"
    default_url = url || "/v1/transfers/#{transfer_id}/reversals"

    default_items =
      items ||
        [
          transfer_reversal_json(),
          transfer_reversal_json(%{
            "id" => "trr_1OoMpqJ2eZvKYlo21aBcDeFgH",
            "amount" => 250
          })
        ]

    %{
      "object" => "list",
      "data" => default_items,
      "has_more" => false,
      "url" => default_url,
      "total_count" => length(default_items)
    }
  end
end
