defmodule LatticeStripe do
  @moduledoc """
  A production-grade, idiomatic Elixir SDK for the Stripe API.
  """

  @stripe_api_version "2026-03-25.dahlia"

  @doc """
  Returns the Stripe API version this release of LatticeStripe is pinned to.

  This version is used as the default `Stripe-Version` header on all requests.
  Override per-client via the `:api_version` option in `LatticeStripe.Client.new!/1`,
  or per-request via the `:stripe_version` option in request opts.
  """
  @spec api_version() :: String.t()
  def api_version, do: @stripe_api_version
end
