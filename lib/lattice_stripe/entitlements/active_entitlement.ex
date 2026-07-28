defmodule LatticeStripe.Entitlements.ActiveEntitlement do
  @moduledoc """
  A customer's currently-active entitlement to a feature.

  Wire object `entitlements.active_entitlement`, ids prefixed `ent_`, served from the
  canonical list path `/v1/entitlements/active_entitlements`. One active entitlement means
  one customer currently has access to one feature, because they bought a Product that
  feature is attached to.

  > #### There is no `entitled?` helper — gate locally, fail closed {: .warning}
  >
  > This module deliberately ships **no** `entitled?`-style per-request predicate, and one
  > will not be added. An authorization check that makes a network call **fails open** under
  > network partition: the call times out, the caller has no answer, and the pragmatic
  > fallback is to let the request through — granting a customer access to something they
  > did not buy.
  >
  > Do this instead. Reconcile a customer's entitlements with `list/3` (or the streaming
  > variant, once it lands, for customers with more than one page), persist the result to a
  > local store keyed on `lookup_key`, and **gate against that local store** on every
  > request. When the local store is stale beyond your freshness budget, **fail closed** —
  > deny access and re-reconcile — rather than reaching for Stripe on the authorization
  > path. A local gate is fast, is available when Stripe is not, and has a failure mode you
  > choose rather than one the network chooses for you.

  ## Listing a customer's entitlements

  `customer` is a **required** filter — Stripe has no account-wide active-entitlement list,
  and `list/3` raises `ArgumentError` before any network call if it is missing. That guard
  is `LatticeStripe.Resource.require_param!/3`, which checks **presence, not emptiness**: a
  `customer` key whose value is `""` or `nil` passes the guard and fails at Stripe instead.

  Stripe's `limit` defaults to **10** and maxes at **100**. A customer with more
  entitlements than the page size will be silently truncated if you only read the first
  page, which is why full enumeration wants the streaming variant rather than a bare
  `list/3` call.

  Each entitlement carries its own `lookup_key`, mirroring the feature's. That is the field
  a local gate keys on, and it is present **without** expanding `feature` — so the common
  reconciliation read needs no `expand` param at all.

  ## Relationship to other feature surfaces

  The `feature` field decodes to a `LatticeStripe.Entitlements.Feature` — the entitlement
  feature *definition* (wire object `entitlements.feature`, ids prefixed `feat_`) — when
  Stripe expands it, and stays the bare `feat_` id string when it does not. It is **not**
  `LatticeStripe.Product.Feature`, which is the product *attachment* (wire object
  `product_feature`, ids prefixed `prodft_`).

  ## Usage

      {:ok, resp} =
        LatticeStripe.Entitlements.ActiveEntitlement.list(client, %{"customer" => "cus_123"})

      keys = Enum.map(resp.data.data, & &1.lookup_key)
  """

  alias LatticeStripe.{Client, Request, Resource}
  alias LatticeStripe.Entitlements.Feature

  # D-06: the canonical path lives here once. `list/3`, the streaming variant, and the
  # summary module's url rewrite all read it, so they physically cannot diverge.
  @list_path "/v1/entitlements/active_entitlements"

  # Exactly the five fields Stripe's spec marks required (research C-03) — note that
  # `lookup_key` is on the entitlement itself, not only on the feature.
  @known_fields ~w(id object feature lookup_key livemode)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          feature: Feature.t() | String.t() | nil,
          lookup_key: String.t() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  defstruct [
    :id,
    :feature,
    :lookup_key,
    :livemode,
    object: "entitlements.active_entitlement",
    extra: %{}
  ]

  @doc false
  def list_path, do: @list_path

  # ---------------------------------------------------------------------------
  # LIST
  # ---------------------------------------------------------------------------

  @doc """
  List a customer's active entitlements.

  `params` **must** contain `"customer"`. The guard is
  `LatticeStripe.Resource.require_param!/3`, which raises `ArgumentError` before any
  network call and checks key **presence, not value emptiness**.

  Supports Stripe's `limit` (default 10, max 100), `starting_after`, `ending_before`, and
  `expand` (for example `["data.feature"]`).
  """
  @spec list(Client.t(), map(), keyword()) ::
          {:ok, LatticeStripe.Response.t()} | {:error, LatticeStripe.Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    Resource.require_param!(
      params,
      "customer",
      "LatticeStripe.Entitlements.ActiveEntitlement.list/3 requires a customer param"
    )

    %Request{method: :get, path: @list_path, params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Bang variant of `list/3`. Raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: LatticeStripe.Response.t()
  def list!(client, params \\ %{}, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # DECODE
  # ---------------------------------------------------------------------------

  @doc """
  Decode a Stripe-shaped string-keyed map into an `%ActiveEntitlement{}`.

  The expandable `feature` field becomes a `LatticeStripe.Entitlements.Feature` when Stripe
  expanded it, and passes through unchanged (the bare `feat_` id string) when it did not.

  Idempotent: applied to an already-decoded struct it returns it unchanged, and
  `from_map(nil)` returns `nil`. Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil

  # The struct clause MUST precede the `is_map/1` clause — a struct is a map.
  def from_map(%__MODULE__{} = entitlement), do: entitlement

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "entitlements.active_entitlement",
      # Call Feature.from_map/1 DIRECTLY, not ObjectTypes.maybe_deserialize/1. Routing
      # through ObjectTypes would create a false dependency on Phase 65 (which owns the
      # registry rows) and would silently fall through to a raw map until that phase lands.
      feature:
        if(is_map(known["feature"]),
          do: Feature.from_map(known["feature"]),
          else: known["feature"]
        ),
      lookup_key: known["lookup_key"],
      livemode: known["livemode"],
      extra: extra
    }
  end
end
