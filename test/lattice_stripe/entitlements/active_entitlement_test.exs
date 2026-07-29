defmodule LatticeStripe.Entitlements.ActiveEntitlementTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Entitlements.{ActiveEntitlement, Feature}
  alias LatticeStripe.Testing.Fixtures.Entitlements

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # ENT-01 — list/3
  # ---------------------------------------------------------------------------

  describe "ActiveEntitlement.list/3" do
    test "GETs /v1/entitlements/active_entitlements with the customer filter" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/entitlements/active_entitlements"
        assert req.url =~ "customer=cus_123"

        ok_response(Entitlements.active_entitlement_list_json())
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               ActiveEntitlement.list(test_client(), %{"customer" => "cus_123"})

      assert [%ActiveEntitlement{id: "ent_123"}] = list.data
    end

    test "returns a typed empty list for an empty page" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.active_entitlement_list_json([], false))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               ActiveEntitlement.list(test_client(), %{"customer" => "cus_123"})

      assert list.data == []
      assert list.has_more == false
    end

    test "keeps entitlements sharing a lookup_key as distinct structs in wire order" do
      items = [
        Entitlements.active_entitlement_json(%{"id" => "ent_a"}),
        Entitlements.active_entitlement_json(%{"id" => "ent_b"})
      ]

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.active_entitlement_list_json(items))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               ActiveEntitlement.list(test_client(), %{"customer" => "cus_123"})

      assert [
               %ActiveEntitlement{id: "ent_a", lookup_key: "premium_support"},
               %ActiveEntitlement{id: "ent_b", lookup_key: "premium_support"}
             ] = list.data
    end
  end

  describe "ActiveEntitlement.list!/3" do
    test "returns the response directly" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.active_entitlement_list_json())
      end)

      assert %LatticeStripe.Response{data: %LatticeStripe.List{data: [%ActiveEntitlement{}]}} =
               ActiveEntitlement.list!(test_client(), %{"customer" => "cus_123"})
    end
  end

  # ---------------------------------------------------------------------------
  # ENT-03 — retrieve/3
  # ---------------------------------------------------------------------------

  describe "ActiveEntitlement.retrieve/3" do
    test "GETs /v1/entitlements/active_entitlements/{id} and returns a typed struct" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/entitlements/active_entitlements/ent_123")

        ok_response(Entitlements.active_entitlement_json())
      end)

      assert {:ok, %ActiveEntitlement{id: "ent_123", lookup_key: "premium_support"}} =
               ActiveEntitlement.retrieve(test_client(), "ent_123")
    end
  end

  describe "ActiveEntitlement.retrieve!/3" do
    test "returns the bare struct on success" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.active_entitlement_json())
      end)

      assert %ActiveEntitlement{id: "ent_123"} =
               ActiveEntitlement.retrieve!(test_client(), "ent_123")
    end

    test "raises LatticeStripe.Error when Stripe returns an error payload" do
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise LatticeStripe.Error, fn ->
        ActiveEntitlement.retrieve!(test_client(), "ent_nope")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ENT-01 — from_map/1 (decode, including the expandable feature field)
  # ---------------------------------------------------------------------------

  describe "ActiveEntitlement.from_map/1" do
    test "decodes an expanded feature into a %Feature{}" do
      wire = Entitlements.active_entitlement_json(%{"feature" => Entitlements.feature_json()})

      assert %ActiveEntitlement{feature: %Feature{id: "feat_123", lookup_key: "premium_support"}} =
               ActiveEntitlement.from_map(wire)
    end

    test "leaves an unexpanded feature as the bare id string" do
      assert %ActiveEntitlement{feature: "feat_123"} =
               ActiveEntitlement.from_map(Entitlements.active_entitlement_json())
    end

    test "captures unknown wire keys in :extra" do
      entitlement =
        ActiveEntitlement.from_map(
          Entitlements.active_entitlement_json(%{"future_field" => "surprise"})
        )

      assert entitlement.extra == %{"future_field" => "surprise"}
      refute Map.has_key?(Map.from_struct(entitlement), :future_field)
    end

    test "returns nil for nil" do
      assert ActiveEntitlement.from_map(nil) == nil
    end

    test "is idempotent" do
      wire = Entitlements.active_entitlement_json(%{"feature" => Entitlements.feature_json()})
      once = ActiveEntitlement.from_map(wire)

      assert ActiveEntitlement.from_map(once) == once
    end
  end

  describe "Feature.from_map/1" do
    test "decodes the wire object into a %Feature{}" do
      assert %Feature{
               id: "feat_123",
               object: "entitlements.feature",
               active: true,
               lookup_key: "premium_support",
               name: "Premium Support",
               livemode: false
             } = Feature.from_map(Entitlements.feature_json())
    end

    test "returns nil for nil and is idempotent" do
      assert Feature.from_map(nil) == nil

      once = Feature.from_map(Entitlements.feature_json())
      assert Feature.from_map(once) == once
    end
  end

  # ---------------------------------------------------------------------------
  # T-63-01 — the customer filter is enforced BEFORE any transport call (C-07)
  # ---------------------------------------------------------------------------

  describe "pre-network customer guard" do
    # No Mox expectation is set in either test below. `verify_on_exit!` therefore proves
    # the raise happened before the transport was ever reached — stripe-mock answers a
    # missing required param with a 400, and the client-side guard means we never get there.

    test "list/3 raises ArgumentError with no customer param and makes no transport call" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.ActiveEntitlement.list/3 requires a customer param",
                   fn -> ActiveEntitlement.list(test_client(), %{}) end
    end

    test "list/3 raises when params carry only unrelated keys — presence, not emptiness" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.ActiveEntitlement.list/3 requires a customer param",
                   fn -> ActiveEntitlement.list(test_client(), %{"limit" => "5"}) end
    end

    # Pitfall 6: `Stream.resource/3` defers its start function, so a guard built lazily
    # would not raise until the stream is consumed — far from the call site. There is
    # deliberately no `Enum` step below: the raise must happen while constructing the
    # stream, not while stepping it.
    test "stream!/3 raises ArgumentError at call time, before any Enum step" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.ActiveEntitlement.stream!/3 requires a customer param",
                   fn -> ActiveEntitlement.stream!(test_client(), %{}) end
    end

    test "stream!/3 raises when params carry only unrelated keys — presence, not emptiness" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.ActiveEntitlement.stream!/3 requires a customer param",
                   fn -> ActiveEntitlement.stream!(test_client(), %{"limit" => "100"}) end
    end
  end

  # ---------------------------------------------------------------------------
  # D-23 L1 — structural surface lock. With no Dialyzer and documentation-only
  # typespecs, this is the ONLY enforcement of public surface shape.
  # ---------------------------------------------------------------------------

  describe "module surface" do
    test "does not export a per-request network gate helper" do
      refute function_exported?(ActiveEntitlement, :entitled?, 2)
      refute function_exported?(ActiveEntitlement, :entitled?, 3)
      refute function_exported?(ActiveEntitlement, :entitled?, 4)
    end

    test "does not export write verbs — active entitlements are read-only" do
      refute function_exported?(ActiveEntitlement, :create, 2)
      refute function_exported?(ActiveEntitlement, :create, 3)
      refute function_exported?(ActiveEntitlement, :update, 3)
      refute function_exported?(ActiveEntitlement, :update, 4)
      refute function_exported?(ActiveEntitlement, :delete, 2)
      refute function_exported?(ActiveEntitlement, :delete, 3)
    end

    test "exports the shipped read surface" do
      assert function_exported?(ActiveEntitlement, :list, 1)
      assert function_exported?(ActiveEntitlement, :list, 3)
      assert function_exported?(ActiveEntitlement, :list!, 3)
      assert function_exported?(ActiveEntitlement, :retrieve, 3)
      assert function_exported?(ActiveEntitlement, :retrieve!, 3)
      assert function_exported?(ActiveEntitlement, :stream!, 3)
      assert function_exported?(ActiveEntitlement, :from_map, 1)
      assert function_exported?(ActiveEntitlement, :list_path, 0)
    end

    test "stream! has no non-bang twin — auto-pagination raises, it does not return tuples" do
      refute function_exported?(ActiveEntitlement, :stream, 1)
      refute function_exported?(ActiveEntitlement, :stream, 2)
      refute function_exported?(ActiveEntitlement, :stream, 3)
    end
  end
end
