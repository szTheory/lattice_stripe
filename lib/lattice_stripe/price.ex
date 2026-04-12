defmodule LatticeStripe.Price do
  @moduledoc """
  Operations on Stripe Price objects.

  A Price represents how much a Product costs and how it's billed — one-time or
  recurring, per-unit or tiered, flat or percent-based. Prices are immutable
  identifiers — to change a price, archive the old one (`update(active: false)`)
  and create a new one.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)

      # One-time price
      {:ok, price} = LatticeStripe.Price.create(client, %{
        "currency" => "usd",
        "unit_amount" => 2000,
        "product" => "prod_abc"
      })

      # Recurring price
      {:ok, price} = LatticeStripe.Price.create(client, %{
        "currency" => "usd",
        "unit_amount" => 2000,
        "product" => "prod_abc",
        "recurring" => %{"interval" => "month"}
      })

      # Search
      {:ok, resp} = LatticeStripe.Price.search(client, "active:'true' AND product:'prod_abc'")

  ## Operations not supported by the Stripe API

  - **delete** — Prices are immutable once created. To stop a Price from being used,
    archive it with `update/4`:

        LatticeStripe.Price.update(client, price_id, %{"active" => "false"})

  ## Stripe API Reference

  See the [Stripe Price API](https://docs.stripe.com/api/prices).
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object active billing_scheme created currency currency_options
    custom_unit_amount deleted livemode lookup_key metadata nickname
    product recurring tax_behavior tiers tiers_mode transform_quantity
    type unit_amount unit_amount_decimal
  ]

  defstruct [
    :id,
    :active,
    :billing_scheme,
    :created,
    :currency,
    :currency_options,
    :custom_unit_amount,
    :livemode,
    :lookup_key,
    :metadata,
    :nickname,
    :product,
    :recurring,
    :tax_behavior,
    :tiers,
    :tiers_mode,
    :transform_quantity,
    :type,
    :unit_amount,
    :unit_amount_decimal,
    object: "price",
    deleted: false,
    extra: %{}
  ]

  @typedoc """
  A Stripe Price object.

  See the [Stripe Price API](https://docs.stripe.com/api/prices/object) for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          active: boolean() | nil,
          billing_scheme: :per_unit | :tiered | String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          currency_options: map() | nil,
          custom_unit_amount: map() | nil,
          livemode: boolean() | nil,
          lookup_key: String.t() | nil,
          metadata: map() | nil,
          nickname: String.t() | nil,
          product: String.t() | nil,
          recurring: LatticeStripe.Price.Recurring.t() | nil,
          tax_behavior: :inclusive | :exclusive | :unspecified | String.t() | nil,
          tiers: [LatticeStripe.Price.Tier.t()] | nil,
          tiers_mode: String.t() | nil,
          transform_quantity: map() | nil,
          type: :one_time | :recurring | String.t() | nil,
          unit_amount: integer() | nil,
          unit_amount_decimal: String.t() | nil,
          deleted: boolean(),
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations (no delete — D-05)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Price.

  Sends `POST /v1/prices` with the given params and returns `{:ok, %Price{}}`.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/prices", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a Price by ID.

  Sends `GET /v1/prices/:id` and returns `{:ok, %Price{}}`.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/prices/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a Price by ID.

  Sends `POST /v1/prices/:id`. Use `update(client, id, %{"active" => "false"})`
  to archive a Price — the Stripe API does not support deletion.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/prices/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Prices with optional filters.

  Sends `GET /v1/prices`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/prices", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Searches Prices using Stripe's search query language.

  Sends `GET /v1/prices/search` with the query string.

  ## Searchable fields

  `active`, `currency`, `lookup_key`, `metadata`, `product`, `type`.

  ## Eventual consistency

  Search results have eventual consistency. Under normal operating conditions,
  newly created or updated objects appear in search results within ~1 minute.
  During Stripe outages, propagation may be slower. Do not use `search/3` in
  read-after-write flows where strict consistency is necessary. See
  https://docs.stripe.com/search#data-freshness.
  """
  @spec search(Client.t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    %Request{
      method: :get,
      path: "/v1/prices/search",
      params: %{"query" => query},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Prices (auto-pagination).
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/prices", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Prices matching a search query (auto-pagination).
  """
  @spec search_stream!(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/prices/search",
      params: %{"query" => query},
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants (no delete! — D-05)
  # ---------------------------------------------------------------------------

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `search/3` but raises on failure."
  @spec search!(Client.t(), String.t(), keyword()) :: Response.t()
  def search!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    search(client, query, opts) |> Resource.unwrap_bang!()
  end

  # NOTE: NO delete/2,3 and NO delete!/2,3 — D-05 forbidden op.
  # Prices cannot be deleted via the Stripe API; archive with `update(active: false)`.

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Price{}` struct.

  Atomizes `type`, `billing_scheme`, `tax_behavior` via whitelists (D-03).
  Decodes nested `recurring` to `%Price.Recurring{}` and each element of
  `tiers` to `%Price.Tier{}` (D-01).
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "price",
      active: map["active"],
      billing_scheme: atomize_billing_scheme(map["billing_scheme"]),
      created: map["created"],
      currency: map["currency"],
      currency_options: map["currency_options"],
      custom_unit_amount: map["custom_unit_amount"],
      livemode: map["livemode"],
      lookup_key: map["lookup_key"],
      metadata: map["metadata"],
      nickname: map["nickname"],
      product: map["product"],
      recurring: decode_recurring(map["recurring"]),
      tax_behavior: atomize_tax_behavior(map["tax_behavior"]),
      tiers: decode_tiers(map["tiers"]),
      tiers_mode: map["tiers_mode"],
      transform_quantity: map["transform_quantity"],
      type: atomize_type(map["type"]),
      unit_amount: map["unit_amount"],
      unit_amount_decimal: map["unit_amount_decimal"],
      deleted: map["deleted"] || false,
      extra: Map.drop(map, @known_fields)
    }
  end

  defp decode_recurring(nil), do: nil
  defp decode_recurring(%{} = m), do: LatticeStripe.Price.Recurring.from_map(m)

  defp decode_tiers(nil), do: nil

  defp decode_tiers(list) when is_list(list),
    do: Enum.map(list, &LatticeStripe.Price.Tier.from_map/1)

  # D-03 atomization helpers — whitelist only; unknown values pass through as strings.
  defp atomize_type("one_time"), do: :one_time
  defp atomize_type("recurring"), do: :recurring
  defp atomize_type(nil), do: nil
  defp atomize_type(other), do: other

  defp atomize_billing_scheme("per_unit"), do: :per_unit
  defp atomize_billing_scheme("tiered"), do: :tiered
  defp atomize_billing_scheme(nil), do: nil
  defp atomize_billing_scheme(other), do: other

  defp atomize_tax_behavior("inclusive"), do: :inclusive
  defp atomize_tax_behavior("exclusive"), do: :exclusive
  defp atomize_tax_behavior("unspecified"), do: :unspecified
  defp atomize_tax_behavior(nil), do: nil
  defp atomize_tax_behavior(other), do: other
end

defmodule LatticeStripe.Price.Recurring do
  @moduledoc """
  Typed representation of a Price's `recurring` nested object.

  Subscriptions and metered billing depend on pattern-matching against this
  struct — `%LatticeStripe.Price.Recurring{interval: :month}` is the idiomatic shape.
  """

  @known_fields ~w[aggregate_usage interval interval_count meter trial_period_days usage_type]

  defstruct [
    :aggregate_usage,
    :interval,
    :interval_count,
    :meter,
    :trial_period_days,
    :usage_type,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          aggregate_usage: :sum | :last_during_period | :last_ever | :max | String.t() | nil,
          interval: :day | :week | :month | :year | String.t() | nil,
          interval_count: integer() | nil,
          meter: String.t() | nil,
          trial_period_days: integer() | nil,
          usage_type: :licensed | :metered | String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe `recurring` map to a `%Price.Recurring{}` struct.

  Atomizes `interval`, `usage_type`, and `aggregate_usage` via whitelists (D-03).
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      aggregate_usage: atomize_aggregate_usage(map["aggregate_usage"]),
      interval: atomize_interval(map["interval"]),
      interval_count: map["interval_count"],
      meter: map["meter"],
      trial_period_days: map["trial_period_days"],
      usage_type: atomize_usage_type(map["usage_type"]),
      extra: Map.drop(map, @known_fields)
    }
  end

  defp atomize_interval("day"), do: :day
  defp atomize_interval("week"), do: :week
  defp atomize_interval("month"), do: :month
  defp atomize_interval("year"), do: :year
  defp atomize_interval(nil), do: nil
  defp atomize_interval(other), do: other

  defp atomize_usage_type("licensed"), do: :licensed
  defp atomize_usage_type("metered"), do: :metered
  defp atomize_usage_type(nil), do: nil
  defp atomize_usage_type(other), do: other

  defp atomize_aggregate_usage("sum"), do: :sum
  defp atomize_aggregate_usage("last_during_period"), do: :last_during_period
  defp atomize_aggregate_usage("last_ever"), do: :last_ever
  defp atomize_aggregate_usage("max"), do: :max
  defp atomize_aggregate_usage(nil), do: nil
  defp atomize_aggregate_usage(other), do: other
end

defmodule LatticeStripe.Price.Tier do
  @moduledoc """
  Typed representation of a single tier in a tiered Price.

  The final tier's `up_to` is the literal string `"inf"` in Stripe's API;
  this module converts it to the atom `:inf` for ergonomic pattern-matching.
  """

  @known_fields ~w[flat_amount flat_amount_decimal unit_amount unit_amount_decimal up_to]

  defstruct [
    :flat_amount,
    :flat_amount_decimal,
    :unit_amount,
    :unit_amount_decimal,
    :up_to,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          flat_amount: integer() | nil,
          flat_amount_decimal: String.t() | nil,
          unit_amount: integer() | nil,
          unit_amount_decimal: String.t() | nil,
          up_to: integer() | :inf | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe tier map to a `%Price.Tier{}` struct.

  Coerces `up_to: "inf"` to `:inf` for ergonomic pattern-matching on the final tier.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      flat_amount: map["flat_amount"],
      flat_amount_decimal: map["flat_amount_decimal"],
      unit_amount: map["unit_amount"],
      unit_amount_decimal: map["unit_amount_decimal"],
      up_to: coerce_up_to(map["up_to"]),
      extra: Map.drop(map, @known_fields)
    }
  end

  defp coerce_up_to("inf"), do: :inf
  defp coerce_up_to(n) when is_integer(n), do: n
  defp coerce_up_to(nil), do: nil
  defp coerce_up_to(other), do: other
end
