defmodule LatticeStripe.Account.CapabilityTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Capability
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "cast/1" do
    test "returns nil for nil input" do
      assert Capability.cast(nil) == nil
    end

    test "casts fully-populated capability map and auto-atomizes status" do
      result =
        Capability.cast(%{
          "status" => "active",
          "requested" => true,
          "requested_at" => 1_700_000_000,
          "requirements" => %{"currently_due" => []},
          "disabled_reason" => nil
        })

      assert %Capability{} = result
      assert result.status == :active
      assert result.requested == true
      assert result.requested_at == 1_700_000_000
      assert result.requirements == %{"currently_due" => []}
      assert result.disabled_reason == nil
      assert result.extra == %{}
    end

    test "unknown top-level capability fields land in :extra" do
      result =
        Capability.cast(%{
          "status" => "active",
          "zzz_future" => "x"
        })

      assert result.status == :active
      assert result.extra == %{"zzz_future" => "x"}
    end

    test "fixture round-trip: card_payments capability casts correctly" do
      cap = AccountFixtures.basic()["capabilities"]["card_payments"]
      result = Capability.cast(cap)

      assert %Capability{} = result
      assert result.status == :active
      assert result.requested == true
    end
  end

  describe "cast/1 status atomization" do
    test "atomizes 'active' to :active" do
      cap = Capability.cast(%{"status" => "active"})
      assert cap.status == :active
    end

    test "atomizes 'inactive' to :inactive" do
      cap = Capability.cast(%{"status" => "inactive"})
      assert cap.status == :inactive
    end

    test "atomizes 'pending' to :pending" do
      cap = Capability.cast(%{"status" => "pending"})
      assert cap.status == :pending
    end

    test "atomizes 'unrequested' to :unrequested" do
      cap = Capability.cast(%{"status" => "unrequested"})
      assert cap.status == :unrequested
    end

    test "atomizes 'disabled' to :disabled" do
      cap = Capability.cast(%{"status" => "disabled"})
      assert cap.status == :disabled
    end

    test "passes through nil status" do
      cap = Capability.cast(%{"status" => nil})
      assert cap.status == nil
    end

    test "passes through unknown future status string" do
      cap = Capability.cast(%{"status" => "zzz_future_2030"})
      assert cap.status == "zzz_future_2030"
    end
  end

  describe "status_atom/1 (deprecated — backward compat)" do
    test "struct with atom status returns atom directly (via apply)" do
      cap = Capability.cast(%{"status" => "active"})
      assert apply(Capability, :status_atom, [cap]) == :active
    end

    test "struct with inactive status returns :inactive (via apply)" do
      cap = Capability.cast(%{"status" => "inactive"})
      assert apply(Capability, :status_atom, [cap]) == :inactive
    end

    test "nil returns nil (via apply)" do
      assert apply(Capability, :status_atom, [nil]) == nil
    end

    test "bare atom :active returns :active (via apply)" do
      assert apply(Capability, :status_atom, [:active]) == :active
    end

    test "unknown string passthrough (via apply)" do
      # Now returns the string itself (not :unknown) since atomize_status/1 has no :unknown clause
      result = apply(Capability, :status_atom, ["zzz_unknown"])
      assert result == "zzz_unknown"
    end
  end
end
