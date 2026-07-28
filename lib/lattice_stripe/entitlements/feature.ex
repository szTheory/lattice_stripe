defmodule LatticeStripe.Entitlements.Feature do
  @moduledoc """
  Stripe Entitlements Feature — the **definition** of a feature you sell.

  A feature is created once per capability in your product catalog (wire object
  `entitlements.feature`, ids prefixed `feat_`), given an immutable `lookup_key` that your
  own system keys on, and then attached to Products so that customers who buy those
  Products receive a matching `LatticeStripe.Entitlements.ActiveEntitlement`.

  The surface is `create/3`, `retrieve/3`, `update/4` and `list/3` — plus `stream!/3` — and
  that is the *complete* surface, not a partial one. Stripe ships no DELETE for features,
  so nothing here is deferred.

  See [Entitlements](guides/entitlements.md) for the end-to-end story.

  ## Archiving

  Two words, one concept. The feature object carries a boolean field named **`active`**.
  The list endpoint takes a boolean filter named **`archived`**, whose sense is
  **inverted**: a feature with `active: false` is one the `archived` filter calls archived.
  Nothing in a function signature surfaces that split.

  Stripe's own description of the `active` field states the consequence: *inactive features
  cannot be attached to new products and will not be returned from the features list
  endpoint*. So `list/3` and `stream!/3` return a **filtered view** by default — the
  sellable catalog, not the whole catalog.

  > #### Archived is not deleted {: .warning}
  >
  > A reconciler that diffs Stripe's feature catalog against a local configuration and
  > passes no filter will see archived features simply **vanish** from the response, and a
  > naive diff reports them as **deleted**. Acting on that — revoking access, pruning local
  > rows — can cut off a customer who still legitimately holds the entitlement.
  >
  > When the job is catalog reconciliation rather than "what can I sell today", pass
  > `%{"archived" => true}` explicitly and reconcile both views.

  There is deliberately **no `archive/3` verb**. Stripe ships no archive endpoint, and the
  house rule is that explicit verbs mirror explicit Stripe endpoints — a wrapper over
  `update/4` is named after the exact wire field it sets, which here would make it
  `set_active/4`. Archiving is therefore `update/4` with `active: false`, and unarchiving
  is `update/4` with `active: true`:

      {:ok, archived} =
        LatticeStripe.Entitlements.Feature.update(client, feature.id, %{"active" => false})

  `LatticeStripe.Price` and `LatticeStripe.Product` use the identical `active: false`
  archive mechanic and likewise ship no archive verb.

  ## Using lookup_key as your system identifier

  Filter `list/3` by lookup key:

      {:ok, resp} =
        LatticeStripe.Entitlements.Feature.list(client, %{"lookup_key" => "premium_support"})

  That returns a **list**, not a singleton, even when exactly one feature matches. Stripe
  defines no unique-lookup retrieval, so there is no `retrieve_by_lookup_key/3` here — a
  helper would have to invent semantics for the zero-result and multi-result cases that
  Stripe does not define. You decide what those mean for your system.

  The unlock is that **`lookup_key` is immutable after create**. It is absent from the
  update request body schema entirely, so Stripe silently ignores an attempt to change it
  rather than erroring. That immutability is what makes it safe to key host application
  configuration on the lookup key instead of on the generated `feat_` id — the string you
  chose at create time is the string that will still be there.

  ## Relationship to other feature surfaces

  This module is **not** `LatticeStripe.Product.Feature`. This module is the entitlement
  feature *definition* — wire object `entitlements.feature`, ids prefixed `feat_`.
  `LatticeStripe.Product.Feature` is the product *attachment* — wire object
  `product_feature`, ids prefixed `prodft_` — which records that a given Product grants a
  given feature. The attachment carries the full definition under its `entitlement_feature`
  field as a direct reference; that field is **never** a bare id string, so it always
  decodes to a `LatticeStripe.Entitlements.Feature`.
  """

  alias LatticeStripe.{Client, Request, Resource}

  # D-06: the canonical path lives here once. `create/3`, `retrieve/3`, `update/4`, `list/3`
  # and `stream!/3` all read it, so they physically cannot diverge. Item paths compose as
  # `@list_path <> "/#{id}"` rather than re-declaring the string.
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
  # CREATE
  # ---------------------------------------------------------------------------

  @doc """
  Create an entitlement feature.

  Requires `lookup_key` and `name` params (string keys — Stripe wire format). Both are
  guarded **before any network call**: the guard raises `ArgumentError` and checks key
  **presence, not value emptiness**, so a `lookup_key` whose value is `""` or `nil` passes
  the guard and fails at Stripe instead.

  `params` has no default. An argument-less create could only ever raise, so the arity that
  would allow one does not exist.

  `lookup_key` is **immutable after create** — see the moduledoc section
  *Using lookup_key as your system identifier*. Choose it deliberately.

  Optional params: `metadata`, `expand`.

      {:ok, feature} =
        LatticeStripe.Entitlements.Feature.create(client, %{
          "lookup_key" => "premium_support",
          "name" => "Premium Support"
        })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(
      params,
      "lookup_key",
      "LatticeStripe.Entitlements.Feature.create/3 requires a lookup_key param"
    )

    Resource.require_param!(
      params,
      "name",
      "LatticeStripe.Entitlements.Feature.create/3 requires a name param"
    )

    %Request{method: :post, path: @list_path, params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # RETRIEVE
  # ---------------------------------------------------------------------------

  @doc """
  Retrieve an entitlement feature by ID.

  The id is the `feat_`-prefixed identifier returned by `create/3`, `list/3` or
  `stream!/3`. There is no retrieval by `lookup_key` — Stripe defines none; filter `list/3`
  instead.
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

  # ---------------------------------------------------------------------------
  # UPDATE
  # ---------------------------------------------------------------------------

  @doc """
  Update an entitlement feature.

  Stripe accepts `active`, `name`, `metadata` and `expand`; other keys in `params` are
  passed through for forward compatibility. `lookup_key` is **not** an accepted update
  param — Stripe ignores it silently rather than erroring, which is precisely what makes it
  a safe key for host configuration.

  **This is the archive operation.** There is no `archive/3` verb; see the moduledoc
  section *Archiving* for why.

      {:ok, archived} =
        LatticeStripe.Entitlements.Feature.update(client, "feat_123", %{"active" => false})
  """
  @spec update(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def update(%Client{} = client, id, params, opts \\ [])
      when is_binary(id) and is_map(params) do
    %Request{method: :post, path: @list_path <> "/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `update/4`. Raises `LatticeStripe.Error` on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(client, id, params, opts \\ []),
    do: client |> update(id, params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # LIST + STREAM
  # ---------------------------------------------------------------------------

  @doc """
  List entitlement features.

  Unlike `LatticeStripe.Entitlements.ActiveEntitlement.list/3`, no filter is required —
  features are account-wide catalog objects, not customer-scoped.

  Supports Stripe's `archived` (boolean) and `lookup_key` filters, plus `limit` (default
  **10**, max 100), `starting_after`, `ending_before` and `expand`.

  **`archived` defaults to omitting archived features.** A catalog reconciler that passes
  no filter sees a *filtered view* and will report archived features as deleted — read the
  moduledoc section *Archiving* before diffing this against a local catalog.

  A `lookup_key` filter returns a **list**, not a singleton, even when exactly one feature
  matches.
  """
  @spec list(Client.t(), map(), keyword()) ::
          {:ok, LatticeStripe.Response.t()} | {:error, LatticeStripe.Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: @list_path, params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Bang variant of `list/3`. Raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: LatticeStripe.Response.t()
  def list!(client, params \\ %{}, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of **all** entitlement features (auto-pagination).

  Emits individual `%Feature{}` structs, following `has_more` and fetching each subsequent
  page as the stream is consumed. Raises `LatticeStripe.Error` if any page fetch fails, so
  a partial enumeration surfaces as an error rather than as a short list.

  This is the entry point for catalog drift detection: `limit` defaults to 10, so a single
  `list/3` call over a catalog of more than ten features silently returns a partial set.
  Filters pass through to every page, so pair it with `%{"archived" => true}` when
  reconciling.

      client
      |> LatticeStripe.Entitlements.Feature.stream!()
      |> Enum.map(& &1.lookup_key)

  There is no non-bang `stream/3` twin — a lazy stream cannot return an error tuple at
  construction time for a failure that happens pages later.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: @list_path, params: params, opts: opts}

    # The cursor state machine — base_params preservation, the starting_after cursor, and
    # the idempotency-key strip on page fetches — belongs to LatticeStripe.List and is not
    # re-grown here.
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end

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
end
