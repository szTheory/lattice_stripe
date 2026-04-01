defmodule LatticeStripe.Transport do
  @moduledoc "HTTP transport behaviour. See Plan 03 for full implementation."

  @callback request(map()) :: {:ok, map()} | {:error, term()}
end
