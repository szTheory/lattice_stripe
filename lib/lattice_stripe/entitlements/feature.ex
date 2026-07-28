defmodule LatticeStripe.Entitlements.Feature do
  @moduledoc """
  Stripe Entitlements Feature — the **definition** of a feature you sell.

  A feature is created once per capability in your product catalog (wire object
  `entitlements.feature`, ids prefixed `feat_`), given an immutable `lookup_key` that your
  own system keys on, and then attached to Products so that customers who buy those
  Products receive a matching `LatticeStripe.Entitlements.ActiveEntitlement`.

  ## Relationship to other feature surfaces

  This module is **not** `LatticeStripe.Product.Feature`. This module is the entitlement
  feature *definition* — wire object `entitlements.feature`, ids prefixed `feat_`.
  `LatticeStripe.Product.Feature` is the product *attachment* — wire object
  `product_feature`, ids prefixed `prodft_` — which records that a given Product grants a
  given feature. The attachment carries the full definition under its `entitlement_feature`
  field as a direct reference; that field is **never** a bare id string, so it always
  decodes to a `LatticeStripe.Entitlements.Feature`.
  """

  # NOTE: `alias LatticeStripe.{Client, Request, Resource}` lands in 63-03 alongside the verb
  # surface. Adding it here would be an unused alias, and `mix compile --warnings-as-errors`
  # is a per-task gate for this plan.

  @list_path "/v1/entitlements/features"

  @known_fields ~w(id object active lookup_key name metadata livemode)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          active: boolean() | nil,
          lookup_key: String.t() | nil,
          name: String.t() | nil,
          metadata: map() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  defstruct [
    :id,
    :active,
    :lookup_key,
    :name,
    :metadata,
    :livemode,
    object: "entitlements.feature",
    extra: %{}
  ]

  # ---------------------------------------------------------------------------
  # DECODE
  # ---------------------------------------------------------------------------

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%Feature{}`.

  Idempotent: `from_map/1` applied to an already-decoded `%Feature{}` returns it unchanged,
  and `from_map(nil)` returns `nil`. Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil

  # The struct clause MUST precede the `is_map/1` clause — a struct is a map.
  def from_map(%__MODULE__{} = feature), do: feature

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "entitlements.feature",
      active: known["active"],
      lookup_key: known["lookup_key"],
      name: known["name"],
      metadata: known["metadata"],
      livemode: known["livemode"],
      extra: extra
    }
  end

  @doc false
  def list_path, do: @list_path
end
