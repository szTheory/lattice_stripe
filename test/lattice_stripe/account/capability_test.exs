defmodule LatticeStripe.Account.CapabilityTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Capability
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "cast/1" do
    test "returns nil for nil input" do
      assert Capability.cast(nil) == nil
    end

    test "casts fully-populated capability map" do
      result = Capability.cast(%{
        "status" => "active",
        "requested" => true,
        "requested_at" => 1_700_000_000,
        "requirements" => %{"currently_due" => []},
        "disabled_reason" => nil
      })

      assert %Capability{} = result
      assert result.status == "active"
      assert result.requested == true
      assert result.requested_at == 1_700_000_000
      assert result.requirements == %{"currently_due" => []}
      assert result.disabled_reason == nil
      assert result.extra == %{}
    end

    test "unknown top-level capability fields land in :extra" do
      result = Capability.cast(%{
        "status" => "active",
        "zzz_future" => "x"
      })

      assert result.status == "active"
      assert result.extra == %{"zzz_future" => "x"}
    end

    test "fixture round-trip: card_payments capability casts correctly" do
      cap = AccountFixtures.basic()["capabilities"]["card_payments"]
      result = Capability.cast(cap)

      assert %Capability{} = result
      assert result.status == "active"
      assert result.requested == true
    end
  end

  describe "status_atom/1" do
    test "returns :active for status 'active'" do
      assert Capability.status_atom(%Capability{status: "active"}) == :active
    end

    test "returns :inactive for status 'inactive'" do
      assert Capability.status_atom(%Capability{status: "inactive"}) == :inactive
    end

    test "returns :pending for status 'pending'" do
      assert Capability.status_atom(%Capability{status: "pending"}) == :pending
    end

    test "returns :unrequested for status 'unrequested'" do
      assert Capability.status_atom(%Capability{status: "unrequested"}) == :unrequested
    end

    test "returns :disabled for status 'disabled'" do
      assert Capability.status_atom(%Capability{status: "disabled"}) == :disabled
    end

    test "returns nil for nil status" do
      assert Capability.status_atom(%Capability{status: nil}) == nil
    end

    test "returns nil for nil argument" do
      assert Capability.status_atom(nil) == nil
    end

    test "accepts bare string 'active'" do
      assert Capability.status_atom("active") == :active
    end

    test "fixture round-trip: card_payments status_atom returns :active" do
      cap = AccountFixtures.basic()["capabilities"]["card_payments"] |> Capability.cast()
      assert Capability.status_atom(cap) == :active
    end
  end

  describe "status_atom/1 safety" do
    test "forward-compatible unknown status returns :unknown without raising" do
      assert Capability.status_atom(%Capability{status: "zzz_totally_new_status_from_stripe_2030"}) == :unknown
    end

    test "random unknown status returns :unknown without raising or leaking atoms" do
      unknown_status = "zzz_never_before_seen_#{:rand.uniform(1_000_000)}"
      result = Capability.status_atom(%Capability{status: unknown_status})
      assert result == :unknown
    end

    test "unknown bare string returns :unknown without raising" do
      assert Capability.status_atom("zzz_unknown_status") == :unknown
    end

    test "status_atom never calls String.to_atom on unknown input (safe fallthrough)" do
      # If this test runs without raising ArgumentError, the atom-leak guard is working.
      # String.to_existing_atom raises only if we call it on an unknown string,
      # but the @known_statuses guard prevents reaching that call.
      statuses = ["active", "inactive", "pending", "unrequested", "disabled", "zzz_new", nil]

      for s <- statuses do
        result = Capability.status_atom(%Capability{status: s})
        assert result in [:active, :inactive, :pending, :unrequested, :disabled, :unknown, nil]
      end
    end
  end
end
