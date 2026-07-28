defmodule LatticeStripe.Entitlements.ActiveEntitlementSummaryTest do
  @moduledoc """
  ENT-05: the `entitlements.active_entitlement_summary` decode proof.

  Deliberately Mox-free and transport-free. Stripe serves this object from no HTTP
  endpoint — it arrives by webhook only — so a pure `from_map/1` transformation test is
  not a shortcut here, it is the only proof available.
  """
  use ExUnit.Case, async: true

  alias LatticeStripe.Entitlements.{ActiveEntitlement, ActiveEntitlementSummary}
  alias LatticeStripe.List
  alias LatticeStripe.Test.Fixtures.Entitlements

  # Overrides the fixture's nested envelope, preserving the webhook-shaped url so the
  # rewrite stays provable.
  defp summary_json(items, has_more) do
    Entitlements.active_entitlement_summary_json(%{
      "entitlements" => %{
        "object" => "list",
        "data" => items,
        "has_more" => has_more,
        "url" => "/v1/customer/cus_ABC123customer/entitlements"
      }
    })
  end

  defp entitlement(id), do: Entitlements.active_entitlement_json(%{"id" => id})

  describe "from_map/1" do
    test "deserializes the published summary payload into a typed struct" do
      summary = ActiveEntitlementSummary.from_map(Entitlements.active_entitlement_summary_json())

      assert %ActiveEntitlementSummary{} = summary
      # Neither nil nor a raw map fallthrough.
      refute is_nil(summary)
      assert is_struct(summary, ActiveEntitlementSummary)

      assert summary.customer == "cus_ABC123customer"
      assert summary.livemode == false
      assert summary.object == "entitlements.active_entitlement_summary"
    end

    test "the struct has no :id field" do
      # Encodes the design decision, not merely current behavior: the Stripe object has no
      # `id` property even as an optional one, so inventing one would fake a wire field.
      refute Map.has_key?(%ActiveEntitlementSummary{}, :id)
    end

    test "the nested entitlements field is a typed LatticeStripe.List" do
      summary =
        ActiveEntitlementSummary.from_map(
          summary_json([entitlement("ent_a"), entitlement("ent_b")], false)
        )

      assert %List{} = summary.entitlements
      assert length(summary.entitlements.data) == 2
      assert Enum.all?(summary.entitlements.data, &match?(%ActiveEntitlement{}, &1))
      assert Enum.map(summary.entitlements.data, & &1.id) == ["ent_a", "ent_b"]
    end

    test "has_more is preserved from the wire" do
      summary = ActiveEntitlementSummary.from_map(summary_json([entitlement("ent_a")], true))

      assert summary.entitlements.has_more == true
    end

    # THE ORDERING LOCK — this is why this file exists.
    #
    # `LatticeStripe.List.from_json/3` derives `_last_id` by pattern-matching
    # `%{"id" => id}` on RAW string-keyed maps. A refactor that types `data` into
    # `%ActiveEntitlement{}` structs BEFORE calling `from_json/3` compiles, passes every
    # other test in this suite, and silently leaves `_last_id` nil — after which
    # `build_next_page_request/1` falls to its empty-pagination-params branch and either
    # truncates the customer's entitlements at ten or re-requests page 1 forever. Zero
    # test failures anywhere else. This exact bug shipped in five official Stripe SDKs.
    #
    # Both assertions are deliberate: the equality names the correct value, the non-nil
    # refutation names the actual defect in the failure message.
    test "_last_id is derived from the raw maps before typing" do
      summary =
        ActiveEntitlementSummary.from_map(
          summary_json([entitlement("ent_a"), entitlement("ent_b")], true)
        )

      assert summary.entitlements._last_id == "ent_b"
      refute is_nil(summary.entitlements._last_id)
    end

    test "the nested list url is rewritten to the canonical path" do
      summary = ActiveEntitlementSummary.from_map(summary_json([entitlement("ent_a")], false))

      assert summary.entitlements.url == "/v1/entitlements/active_entitlements"
      refute summary.entitlements.url == "/v1/customer/cus_ABC123customer/entitlements"
    end

    test "the nested list carries the customer filter in _params" do
      summary = ActiveEntitlementSummary.from_map(summary_json([entitlement("ent_a")], false))

      assert summary.entitlements._params == %{"customer" => "cus_ABC123customer"}
    end

    test "an empty but truncated page still deserializes" do
      # The exact "customer paid but has no feature provisioned yet" shape — a real Stripe
      # state, not a curiosity.
      summary = ActiveEntitlementSummary.from_map(summary_json([], true))

      assert %ActiveEntitlementSummary{} = summary
      assert summary.entitlements.data == []
      assert summary.entitlements.has_more == true
    end

    test "from_map/1 is idempotent and nil-tolerant" do
      assert ActiveEntitlementSummary.from_map(nil) == nil

      json = Entitlements.active_entitlement_summary_json()
      once = ActiveEntitlementSummary.from_map(json)

      assert ActiveEntitlementSummary.from_map(once) == once
    end

    test "unknown wire keys land in extra" do
      summary =
        ActiveEntitlementSummary.from_map(
          Entitlements.active_entitlement_summary_json(%{"future_field" => 1})
        )

      assert summary.extra == %{"future_field" => 1}
    end
  end

  describe "surface" do
    test "there is no retrieve — no HTTP endpoint serves this object" do
      # `retrieve(client, id, opts \\ [])` would export arities 2 AND 3; refuting only 3
      # would leave a hole.
      refute function_exported?(ActiveEntitlementSummary, :retrieve, 2)
      refute function_exported?(ActiveEntitlementSummary, :retrieve, 3)
      refute function_exported?(ActiveEntitlementSummary, :retrieve!, 2)
      refute function_exported?(ActiveEntitlementSummary, :retrieve!, 3)
    end

    test "stream_entitlements! ships with no non-bang twin" do
      assert function_exported?(ActiveEntitlementSummary, :stream_entitlements!, 2)
      assert function_exported?(ActiveEntitlementSummary, :stream_entitlements!, 3)
      refute function_exported?(ActiveEntitlementSummary, :stream_entitlements, 2)
      refute function_exported?(ActiveEntitlementSummary, :stream_entitlements, 3)
    end
  end
end
