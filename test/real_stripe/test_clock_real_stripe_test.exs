defmodule LatticeStripe.RealStripe.TestClockTest do
  use ExUnit.Case, async: false

  @moduletag :real_stripe
  @moduletag :wave0_stub

  # Placeholder so `mix test --include real_stripe` discovers this file.
  # Real tests (and `use LatticeStripe.Testing.RealStripeCase`) land in Plan 13-06.
  # Excluded by default via ExUnit.configure(exclude: [..., :real_stripe]).
  test "wave 0 stub" do
    assert true
  end
end
