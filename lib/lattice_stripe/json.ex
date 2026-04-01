defmodule LatticeStripe.Json do
  @moduledoc "JSON codec behaviour. See Plan 02 for full implementation."

  @callback encode!(term()) :: binary()
  @callback decode!(binary()) :: term()
end
