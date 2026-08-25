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
  > Do this instead. Reconcile a customer's entitlements with `stream!/3` (or `list/3` when
  > you genuinely only want one page), persist the result to a
  > local store keyed on `lookup_key`, and **gate against that local store** on every
  > request. When the local store is stale beyond your freshness budget, **fail closed** —
  > deny access and re-reconcile — rather than reaching for Stripe on the authorization
  > path. A local gate is fast, is available when Stripe is not, and has a failure mode you
  > choose rather than one the network chooses for you.

  See [Entitlements](guides/entitlements.md) for the end-to-end story.

  ## Listing a customer's entitlements

  The read surface is `list/3` (one page), `stream!/3` (every page, lazily), and
  `retrieve/3` (one entitlement by id), each with the usual bang twin where one applies.

  `customer` is a **required** filter — Stripe has no account-wide active-entitlement list,
  and both `list/3` and `stream!/3` raise `ArgumentError` before any network call if it is
  missing. That pre-network guard checks **presence, not emptiness**: a `customer` key
  whose value is `""` or `nil` passes the guard and fails at Stripe instead.

  Stripe's `limit` defaults to **10** and maxes at **100**, so a single `list/3` call
  silently returns a *partial* set for any customer with more than ten active entitlements —
  and a truncated set makes a paying customer look unentitled. `stream!/3` is therefore the
  reconciler's entry point: it follows `has_more` across every page and raises rather than
  quietly returning a short list.

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

      # Every page, not just the first:
      keys =
        client
        |> LatticeStripe.Entitlements.ActiveEntitlement.stream!(%{"customer" => "cus_123"})
        |> Enum.map(& &1.lookup_key)
  """

  alias LatticeStripe.{Client, Request, Resource}
  alias LatticeStripe.Entitlements.Feature

  # The canonical path lives here once. `list/3`, the streaming variant, and the
  # summary module's url rewrite all read it, so they physically cannot diverge.
  @list_path "/v1/entitlements/active_entitlements"

  # Exactly the five fields Stripe's spec marks required — note that
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

  # RETRIEVE

  @doc """
  Retrieve a single active entitlement by id.

  The id is the `ent_`-prefixed identifier from a `list/3` or `stream!/3` result, or from
  an `entitlements.active_entitlement_summary` webhook payload.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: @list_path <> "/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `retrieve/3`. Raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(client, id, opts \\ []),
    do: client |> retrieve(id, opts) |> Resource.unwrap_bang!()

  # LIST + STREAM

  @doc """
  List a customer's active entitlements.

  `params` **must** contain `"customer"`. The guard raises `ArgumentError` before any
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

  @doc """
  Returns a lazy stream of **all** of a customer's active entitlements (auto-pagination).

  Emits individual `%ActiveEntitlement{}` structs, following `has_more` and fetching each
  subsequent page as the stream is consumed. Raises `LatticeStripe.Error` if any page fetch
  fails, so a partial enumeration surfaces as an error rather than as a short list.

  `params` **must** contain `"customer"`, and the guard raises `ArgumentError` at call time —
  before the stream is stepped — so the failure lands at the call site rather than at the
  first `Enum` step.

  Consume it with `Enum.to_list/1` when you intend to hold every entitlement in memory, or
  bound it with `Stream.take/2` when you do not:

      client
      |> LatticeStripe.Entitlements.ActiveEntitlement.stream!(%{"customer" => "cus_123"})
      |> Stream.take(50)
      |> Enum.to_list()

  There is no non-bang `stream/3` twin — a lazy stream cannot return an error tuple at
  construction time for a failure that happens pages later.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    # MUST be the first statement. `Stream.resource/3` defers its start function, so a
    # guard constructed lazily would not raise until the stream is consumed.
    Resource.require_param!(
      params,
      "customer",
      "LatticeStripe.Entitlements.ActiveEntitlement.stream!/3 requires a customer param"
    )

    req = %Request{method: :get, path: @list_path, params: params, opts: opts}

    # The cursor state machine — base_params preservation, the starting_after cursor, and
    # the idempotency-key strip on page fetches — belongs to LatticeStripe.List and is not
    # re-grown here. This function's only job is to hand it correctly-shaped state.
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # DECODE

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
      # Call Feature.from_map/1 directly, not ObjectTypes.maybe_deserialize/1. Features are
      # deliberately absent from object-type dispatch because they are not webhook payloads.
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
