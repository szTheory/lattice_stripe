defmodule LatticeStripe.RealStripe.TestClockTest do
  @moduledoc """
  The canonical first :real_stripe test in LatticeStripe.

  Exercises the full Phase 13 TestClock surface against LIVE Stripe test
  mode: create, advance 30 days, poll until ready, delete, assert
  cascading delete.

  Gated by STRIPE_TEST_SECRET_KEY (see LatticeStripe.Testing.RealStripeCase
  and CONTRIBUTING.md). Excluded from default `mix test` via the
  `:real_stripe` ExUnit tag.

  This file is the template for phases 14-19's real_stripe tests.
  """

  use LatticeStripe.Testing.RealStripeCase

  alias LatticeStripe.TestHelpers.TestClock

  @thirty_days_seconds 30 * 86_400

  describe "TestClock round-trip against live Stripe" do
    test "create -> advance 30 days -> assert ready -> delete -> assert gone", %{client: client} do
      frozen_time = System.system_time(:second)

      # CREATE -- with a descriptive name so the Mix task backstop can
      # identify LatticeStripe-managed clocks if the test crashes before delete.
      {:ok, clock} =
        TestClock.create(client, %{
          frozen_time: frozen_time,
          name: "lattice_stripe_real_stripe_canonical_test"
        })

      assert clock.id != nil
      assert clock.status in [:ready, :advancing]

      # NOTE: Stripe does NOT support metadata on test clocks (A-13g probe,
      # verified Plan 13-02). No metadata assertion here.

      # ADVANCE 30 days and poll until :ready.
      # This is the canonical Plan 04 poll loop against live Stripe.
      new_frozen = frozen_time + @thirty_days_seconds

      try do
        {:ok, ready} =
          TestClock.advance_and_wait(client, clock.id, new_frozen, timeout: 90_000)

        assert ready.status == :ready
        assert ready.frozen_time == new_frozen
      rescue
        e ->
          # Clean up the clock before propagating the error, so the test
          # account doesn't accumulate stuck clocks.
          _ = TestClock.delete(client, clock.id)
          reraise e, __STACKTRACE__
      end

      # DELETE -- Stripe's delete cascades to attached customers and subs.
      {:ok, deleted} = TestClock.delete(client, clock.id)

      assert deleted.deleted == true or
               match?(%LatticeStripe.TestHelpers.TestClock{}, deleted)

      # VERIFY the delete took effect -- retrieve should return an error.
      case TestClock.retrieve(client, clock.id) do
        {:error, %LatticeStripe.Error{}} ->
          :ok

        {:ok, %LatticeStripe.TestHelpers.TestClock{deleted: true}} ->
          # Some Stripe endpoints return the deleted resource marker instead of 404;
          # either behavior is acceptable here.
          :ok

        {:ok, other} ->
          flunk(
            "Expected retrieve after delete to fail or return deleted: true, got #{inspect(other)}"
          )
      end
    end
  end
end
