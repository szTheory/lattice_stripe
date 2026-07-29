defmodule LatticeStripe.Testing.Fixtures.Entitlements do
  @moduledoc """
  Canonical raw fixtures for Stripe entitlement objects.
  """

  @doc """
  Wire-shaped `entitlements.active_entitlement` fixture.

  Returns a string-keyed map matching Stripe's wire format. The `feature` value is the
  unexpanded bare `feat_` id string; pass `%{"feature" => feature_json()}` to exercise
  the expanded form.
  """
  @spec active_entitlement_json(map()) :: map()
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
  @spec feature_json(map()) :: map()
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
  @spec active_entitlement_summary_json(map()) :: map()
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
  @spec active_entitlement_list_json(list(), boolean()) :: map()
  def active_entitlement_list_json(items \\ [active_entitlement_json()], has_more \\ false) do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => has_more,
      "url" => "/v1/entitlements/active_entitlements"
    }
  end
end
