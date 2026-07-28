# PROMOTION TARGET (Phase 65 / OBJ-02): move this file to
# lib/lattice_stripe/testing/fixtures/entitlements.ex AND rename the module to
# LatticeStripe.Testing.Fixtures.Entitlements. The private test-support namespace is
# LatticeStripe.Test.Fixtures.*; the public one is LatticeStripe.Testing.Fixtures.* — the
# promotion is a move PLUS a module rename, and skipping the rename is a compile error.
# Function names and bodies transfer unchanged — do not re-author.
defmodule LatticeStripe.Test.Fixtures.Entitlements do
  @moduledoc false

  @doc """
  Wire-shaped `entitlements.active_entitlement` fixture.

  Returns a string-keyed map matching Stripe's wire format. The `feature` value is the
  unexpanded bare `feat_` id string; pass `%{"feature" => feature_json()}` to exercise
  the expanded form.
  """
  def active_entitlement_json(overrides \\ %{}) do
    %{
      "id" => "ent_123",
      "object" => "entitlements.active_entitlement",
      "feature" => "feat_123",
      "lookup_key" => "premium_support",
      "livemode" => false
    }
    |> Map.merge(overrides)
  end

  @doc """
  Wire-shaped `entitlements.feature` fixture.
  """
  def feature_json(overrides \\ %{}) do
    %{
      "id" => "feat_123",
      "object" => "entitlements.feature",
      "active" => true,
      "lookup_key" => "premium_support",
      "name" => "Premium Support",
      "metadata" => %{},
      "livemode" => false
    }
    |> Map.merge(overrides)
  end

  @doc """
  Wire-shaped `entitlements.active_entitlement_summary` fixture.

  The nested `entitlements` envelope carries the **un-rewritten** webhook url
  `"/v1/customer/cus_ABC123customer/entitlements"` — the exact string Stripe publishes.
  The summary module rewrites it to the canonical list path, so the fixture must carry the
  original for that rewrite to be provable.
  """
  def active_entitlement_summary_json(overrides \\ %{}) do
    %{
      "object" => "entitlements.active_entitlement_summary",
      "customer" => "cus_ABC123customer",
      "livemode" => false,
      "entitlements" => %{
        "object" => "list",
        "data" => [active_entitlement_json()],
        "has_more" => false,
        "url" => "/v1/customer/cus_ABC123customer/entitlements"
      }
    }
    |> Map.merge(overrides)
  end

  @doc """
  Stripe list envelope wrapping one or more active entitlement fixtures.
  """
  def active_entitlement_list_json(items \\ [active_entitlement_json()], has_more \\ false) do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => has_more,
      "url" => "/v1/entitlements/active_entitlements"
    }
  end
end
