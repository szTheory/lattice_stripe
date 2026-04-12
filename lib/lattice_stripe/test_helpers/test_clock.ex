defmodule LatticeStripe.TestHelpers.TestClock do
  @moduledoc """
  Operations on Stripe [Test Clock](https://docs.stripe.com/api/test_clocks)
  objects.

  Test Clocks let you simulate the passage of time in Stripe test mode —
  useful for exercising subscription renewals, invoice cycles, and billing
  lifecycle events without waiting real-world time. This module is the
  low-level SDK wrapper over `POST /v1/test_helpers/test_clocks` and sibling
  endpoints; for an ergonomic ExUnit helper built on top of it, see
  `LatticeStripe.Testing.TestClock`.

  ## Account limit

  Stripe enforces a hard limit of **100 test clocks per account**. If you
  hit the limit, `create/2` returns an error. The
  `LatticeStripe.Testing.TestClock` user-facing helper registers every
  created clock with a per-test ExUnit owner that cleans up on test exit,
  and `mix lattice_stripe.test_clock.cleanup` backstops SIGKILL/crash
  scenarios.

  ## Metadata support (A-13g)

  Verified against the Stripe OpenAPI spec (spec3.sdk.json) and
  `stripe/stripe-mock:latest` on 2026-04-11: `POST /v1/test_helpers/test_clocks`
  does **NOT** accept a `metadata` parameter, and the `test_helpers.test_clock`
  object schema has no `metadata` field. The request body schema exposes
  only `expand`, `frozen_time`, and `name`; the object schema exposes
  `created`, `deletes_after`, `frozen_time`, `id`, `livemode`, `name`,
  `object`, `status`, and `status_details`.

  Consequence: this struct intentionally omits `:metadata`.
  `LatticeStripe.Testing.TestClock` (Plan 13-05) falls back to
  Owner-only tracking plus an age-based Mix task for cleanup rather than
  tagging clocks with a metadata marker.

  ## Status values

  - `:ready` — clock is at its current `frozen_time` and idle
  - `:advancing` — an `advance/4` call is in progress server-side
  - `:internal_failure` — a server-side advancement failed; the clock is
    unusable and should be deleted

  Unknown server-returned status strings are passed through as raw strings
  (`String.t()`) for forward compatibility; tests should pattern-match
  against the known atoms or use `to_string/1` for display.

  ## Deletion cascades

  Deleting a test clock **cascades**: every Customer attached to the clock
  is deleted, every Subscription attached is canceled. Do not attach
  production-critical fixtures to a clock you intend to delete.

  ## Typical usage

  This module's functions land in subsequent plans (CRUD in Plan 13-03,
  advance/advance_and_wait in Plan 13-04). After those plans ship:

      {:ok, clock} = LatticeStripe.TestHelpers.TestClock.create(client, %{frozen_time: System.system_time(:second)})
      {:ok, ready} = LatticeStripe.TestHelpers.TestClock.advance_and_wait(client, clock.id, System.system_time(:second) + 86400 * 30)

  For a high-level ExUnit experience (automatic cleanup, setup callbacks,
  customer linkage), use `LatticeStripe.Testing.TestClock` instead.
  """

  # Known top-level fields from the Stripe test_helpers.test_clock object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # NOTE: `metadata` is intentionally absent — Stripe does not expose it on
  # test clocks (verified via OpenAPI spec + stripe-mock on 2026-04-11).
  @known_fields ~w[
    id object created deletes_after frozen_time livemode name status status_details
  ]

  defstruct [
    :id,
    :created,
    :deletes_after,
    :frozen_time,
    :livemode,
    :name,
    :status,
    :status_details,
    object: "test_helpers.test_clock",
    deleted: false,
    extra: %{}
  ]

  @typedoc """
  A Stripe Test Clock object.

  See the [Stripe Test Clock API](https://docs.stripe.com/api/test_clocks/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          created: integer() | nil,
          deletes_after: integer() | nil,
          frozen_time: integer() | nil,
          livemode: boolean() | nil,
          name: String.t() | nil,
          status: :ready | :advancing | :internal_failure | String.t() | nil,
          status_details: map() | nil,
          deleted: boolean(),
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%TestClock{}` struct.

  Maps all known Stripe test clock fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  Per D-03, the `status` field is atomized via a whitelist: `"ready"` →
  `:ready`, `"advancing"` → `:advancing`, `"internal_failure"` →
  `:internal_failure`. Unknown values pass through as raw strings for
  forward compatibility with future Stripe enum additions.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "test_helpers.test_clock",
      created: map["created"],
      deletes_after: map["deletes_after"],
      frozen_time: map["frozen_time"],
      livemode: map["livemode"],
      name: map["name"],
      status: atomize_status(map["status"]),
      status_details: map["status_details"],
      deleted: map["deleted"] || false,
      extra: Map.drop(map, @known_fields)
    }
  end

  # D-03 whitelist atomization — unknown values pass through as raw strings.
  defp atomize_status("ready"), do: :ready
  defp atomize_status("advancing"), do: :advancing
  defp atomize_status("internal_failure"), do: :internal_failure
  defp atomize_status(nil), do: nil
  defp atomize_status(other) when is_binary(other), do: other
  defp atomize_status(other), do: other
end
