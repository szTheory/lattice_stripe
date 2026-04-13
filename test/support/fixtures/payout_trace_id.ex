defmodule LatticeStripe.Test.Fixtures.PayoutTraceId do
  @moduledoc false

  def supported(overrides \\ %{}) do
    Map.merge(
      %{
        "status" => "supported",
        "value" => "FED12345"
      },
      overrides
    )
  end

  def pending(overrides \\ %{}) do
    Map.merge(
      %{
        "status" => "pending",
        "value" => nil
      },
      overrides
    )
  end

  def unsupported(overrides \\ %{}) do
    Map.merge(
      %{
        "status" => "unsupported",
        "value" => nil
      },
      overrides
    )
  end
end
