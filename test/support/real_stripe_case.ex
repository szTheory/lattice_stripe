defmodule LatticeStripe.Testing.RealStripeCase do
  @moduledoc false
  # Internal CaseTemplate for tests that hit LIVE Stripe (test mode).
  # Used ONLY by tests under `test/real_stripe/`. Never shipped in `lib/`.
  #
  # Every real_stripe test is:
  # - Tagged `:real_stripe` (excluded from default `mix test` runs)
  # - Capped at 120s per test (real network is slow)
  # - Run with `async: false` (shared rate-limit budget)
  # - Gated by the STRIPE_TEST_SECRET_KEY env var with a hard safety
  #   guard against sk_live_ keys
  #
  # See CONTRIBUTING.md for the direnv workflow to set
  # STRIPE_TEST_SECRET_KEY locally.

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :real_stripe
      @moduletag timeout: 120_000

      import LatticeStripe.Testing.RealStripeCase
    end
  end

  setup_all do
    case System.get_env("STRIPE_TEST_SECRET_KEY") do
      nil ->
        if System.get_env("CI") in ["true", "1"] do
          flunk(
            "STRIPE_TEST_SECRET_KEY is not set in the CI environment. " <>
              ":real_stripe tests cannot run. Check the repo secret."
          )
        else
          {:skip,
           "STRIPE_TEST_SECRET_KEY not set; skipping :real_stripe tests. See CONTRIBUTING.md."}
        end

      "sk_live_" <> _rest ->
        flunk(
          "Refusing to run :real_stripe tests against a LIVE Stripe key. " <>
            "Use sk_test_* keys only. This guard is non-negotiable."
        )

      "sk_test_" <> _rest = key ->
        # Start a dedicated Finch pool for real-Stripe requests, matching
        # the pattern used by integration tests (start_supervised! per setup_all).
        {:ok, _} = start_supervised({Finch, name: LatticeStripe.RealStripeFinch})

        prefix = "lattice-test-#{System.system_time(:millisecond)}-"

        client =
          LatticeStripe.Client.new!(
            api_key: key,
            finch: LatticeStripe.RealStripeFinch,
            idempotency_key_prefix: prefix
          )

        {:ok, client: client}

      _other ->
        flunk(
          "STRIPE_TEST_SECRET_KEY must start with sk_test_ " <>
            "(got a value that does not match any known prefix)."
        )
    end
  end
end
