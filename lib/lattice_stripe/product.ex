defmodule LatticeStripe.Product do
  @moduledoc """
  Operations on Stripe Product objects.

  A Product in Stripe represents a good or service that you sell. Products are
  paired with Prices to define what customers pay. Products power subscriptions,
  checkout sessions, invoices, and one-off charges.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a product
      {:ok, product} = LatticeStripe.Product.create(client, %{
        "name" => "Premium Subscription",
        "type" => "service"
      })

      # Retrieve a product
      {:ok, product} = LatticeStripe.Product.retrieve(client, product.id)

      # List products
      {:ok, resp} = LatticeStripe.Product.list(client, %{"limit" => "10"})

      # Search products
      {:ok, resp} = LatticeStripe.Product.search(client, "active:'true' AND name~'shirt'")

      # Stream all products lazily (auto-pagination)
      client
      |> LatticeStripe.Product.stream!()
      |> Stream.take(100)
      |> Enum.each(&process_product/1)

  ## Operations not supported by the Stripe API

  - **delete** — Stripe's Products API does not expose a delete endpoint. To stop
    a Product from being used, archive it with `update/4`:

        LatticeStripe.Product.update(client, product_id, %{"active" => "false"})

  ## Stripe API Reference

  See the [Stripe Product API](https://docs.stripe.com/api/products) for the full
  object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe Product object.
  # Used to build the struct and separate known from extra (unknown) fields.
  @known_fields ~w[
    id object active attributes caption created default_price deleted
    description features images livemode marketing_features metadata
    name package_dimensions shippable statement_descriptor tax_code
    type unit_label updated url
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :active,
    :attributes,
    :caption,
    :created,
    :default_price,
    :description,
    :features,
    :images,
    :livemode,
    :marketing_features,
    :metadata,
    :name,
    :package_dimensions,
    :shippable,
    :statement_descriptor,
    :tax_code,
    :type,
    :unit_label,
    :updated,
    :url,
    object: "product",
    deleted: false,
    extra: %{}
  ]

  @typedoc """
  A Stripe Product object.

  See the [Stripe Product API](https://docs.stripe.com/api/products/object) for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          active: boolean() | nil,
          attributes: [String.t()] | nil,
          caption: String.t() | nil,
          created: integer() | nil,
          default_price: String.t() | nil,
          description: String.t() | nil,
          features: [map()] | nil,
          images: [String.t()] | nil,
          livemode: boolean() | nil,
          marketing_features: [map()] | nil,
          metadata: map() | nil,
          name: String.t() | nil,
          package_dimensions: map() | nil,
          shippable: boolean() | nil,
          statement_descriptor: String.t() | nil,
          tax_code: String.t() | nil,
          type: :good | :service | String.t() | nil,
          unit_label: String.t() | nil,
          updated: integer() | nil,
          url: String.t() | nil,
          deleted: boolean(),
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Product.

  Sends `POST /v1/products` with the given params and returns `{:ok, %Product{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of product attributes (e.g., `%{"name" => "...", "type" => "service"}`)
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Product{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, product} = LatticeStripe.Product.create(client, %{
        "name" => "Premium Plan",
        "type" => "service"
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/products", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a Product by ID.

  Sends `GET /v1/products/:id` and returns `{:ok, %Product{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The product ID string (e.g., `"prod_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Product{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/products/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a Product by ID.

  Sends `POST /v1/products/:id` with the given params and returns `{:ok, %Product{}}`.

  To archive a product (Stripe has no delete endpoint), pass `%{"active" => "false"}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The product ID string
  - `params` - Map of fields to update
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Product{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/products/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Products with optional filters.

  Sends `GET /v1/products` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%Product{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "10", "active" => "true"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Product{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.Product.list(client, %{"limit" => "20"})
      Enum.each(resp.data.data, &IO.inspect/1)
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/products", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Searches Products using Stripe's search query language.

  Sends `GET /v1/products/search` with the query string and returns typed results.

  ## Searchable fields

  `active`, `description`, `metadata`, `name`, `shippable`, `url`.

  ## Parameters

  - `client` — A `%LatticeStripe.Client{}` struct
  - `query` — Stripe search query string (e.g., `"active:'true' AND name~'shirt'"`)
  - `opts` — Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Product{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Eventual consistency

  Search results have eventual consistency. Under normal operating conditions,
  newly created or updated objects appear in search results within ~1 minute.
  During Stripe outages, propagation may be slower. Do not use `search/3` in
  read-after-write flows where strict consistency is necessary. See
  https://docs.stripe.com/search#data-freshness.

  ## Example

      {:ok, resp} = LatticeStripe.Product.search(client, "active:'true'")
  """
  @spec search(Client.t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    %Request{
      method: :get,
      path: "/v1/products/search",
      params: %{"query" => query},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Products matching the given params (auto-pagination).

  Emits individual `%Product{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Product{}` structs.

  ## Example

      client
      |> LatticeStripe.Product.stream!()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/products", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Products matching the search query (auto-pagination).

  Emits individual `%Product{}` structs, fetching additional search pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Product{}` structs.

  ## Eventual consistency

  Search results have eventual consistency. Under normal operating conditions,
  newly created or updated objects appear in search results within ~1 minute.
  During Stripe outages, propagation may be slower. Do not use `search_stream!/3`
  in read-after-write flows where strict consistency is necessary. See
  https://docs.stripe.com/search#data-freshness.
  """
  @spec search_stream!(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/products/search",
      params: %{"query" => query},
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc """
  Like `create/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `update/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `search/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec search!(Client.t(), String.t(), keyword()) :: Response.t()
  def search!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    search(client, query, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Product{}` struct.

  Maps all known Stripe Product fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost.

  Per D-03, the `type` field is atomized via a whitelist: `"good"` → `:good`,
  `"service"` → `:service`. Unknown values pass through as raw strings for
  forward compatibility with future Stripe enum additions.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "product",
      active: map["active"],
      attributes: map["attributes"],
      caption: map["caption"],
      created: map["created"],
      default_price: map["default_price"],
      description: map["description"],
      features: map["features"],
      images: map["images"],
      livemode: map["livemode"],
      marketing_features: map["marketing_features"],
      metadata: map["metadata"],
      name: map["name"],
      package_dimensions: map["package_dimensions"],
      shippable: map["shippable"],
      statement_descriptor: map["statement_descriptor"],
      tax_code: map["tax_code"],
      type: atomize_type(map["type"]),
      unit_label: map["unit_label"],
      updated: map["updated"],
      url: map["url"],
      deleted: map["deleted"] || false,
      extra: Map.drop(map, @known_fields)
    }
  end

  # D-03 whitelist atomization — unknown values pass through as raw strings.
  defp atomize_type("good"), do: :good
  defp atomize_type("service"), do: :service
  defp atomize_type(nil), do: nil
  defp atomize_type(other) when is_binary(other), do: other
  defp atomize_type(other), do: other
end
