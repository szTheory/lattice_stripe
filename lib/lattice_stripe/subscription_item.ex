defmodule LatticeStripe.SubscriptionItem do
  @moduledoc """
  Operations on Stripe Subscription Item objects.

  A SubscriptionItem is a single plan/price line on a Subscription. Manipulating
  items lets you add products, change quantities, and swap prices on a live
  subscription without re-creating it.

  This module is at the flat top-level namespace (`LatticeStripe.SubscriptionItem`)
  per Phase 1 D-17, matching `LatticeStripe.Customer`, `LatticeStripe.Invoice`,
  and friends.

  ## Listing requires a subscription

  `list/3` and `stream!/3` require the `"subscription"` param — unfiltered
  SubscriptionItem listing is an antipattern and produces confusing results
  (it returns items across all subscriptions, which is rarely what you want).
  Passing `%{}` raises `ArgumentError` immediately.

  ## Usage-based billing note

  Legacy Usage Records (`/v1/subscription_items/:id/usage_records`) are being
  deprecated by Stripe in favor of the Billing Meters API (`/v1/billing/meters`,
  `/v1/billing/meter_events`). Meters are not yet wired into LatticeStripe —
  see roadmap BILL-07. For new integrations, use Billing Meters directly via
  raw HTTP until that phase ships.

  ## Proration

  All mutations (`create/3`, `update/4`, `delete/3`/`delete/4`) run the
  `Billing.Guards.check_proration_required/2` guard before dispatching. If
  your client sets `require_explicit_proration: true`, you MUST pass
  `"proration_behavior"` in the params.

  ## Stripe API Reference

  See the [Stripe Subscription Items API](https://docs.stripe.com/api/subscription_items).
  """

  alias LatticeStripe.{Billing, Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object billing_thresholds created discounts metadata plan price
    proration_behavior quantity subscription tax_rates
  ]

  defstruct [
    :id,
    :billing_thresholds,
    :created,
    :discounts,
    :metadata,
    :plan,
    :price,
    :proration_behavior,
    :quantity,
    :subscription,
    :tax_rates,
    object: "subscription_item",
    extra: %{}
  ]

  @typedoc "A Stripe Subscription Item object."
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          billing_thresholds: map() | nil,
          created: integer() | nil,
          discounts: list() | nil,
          metadata: map() | nil,
          plan: map() | nil,
          price: map() | nil,
          proration_behavior: String.t() | nil,
          quantity: integer() | nil,
          subscription: String.t() | nil,
          tax_rates: list() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new SubscriptionItem.

  Sends `POST /v1/subscription_items`. Runs the proration guard before dispatching.

  ## Parameters

  - `client` - `%LatticeStripe.Client{}`
  - `params` - Map with at least `"subscription"` and `"price"`. Common keys:
    `"subscription"`, `"price"`, `"quantity"`, `"proration_behavior"`
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %SubscriptionItem{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure or guard rejection
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    with :ok <- Billing.Guards.check_proration_required(client, params) do
      %Request{method: :post, path: "/v1/subscription_items", params: params, opts: opts}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_singular(&from_map/1)
    end
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc "Retrieves a SubscriptionItem by ID."
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/subscription_items/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id),
    do: client |> retrieve(id, opts) |> Resource.unwrap_bang!()

  @doc """
  Updates a SubscriptionItem.

  Runs the proration guard before dispatching.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    with :ok <- Billing.Guards.check_proration_required(client, params) do
      %Request{method: :post, path: "/v1/subscription_items/#{id}", params: params, opts: opts}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_singular(&from_map/1)
    end
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id),
    do: client |> update(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Deletes a SubscriptionItem.

  Sends `DELETE /v1/subscription_items/:id` with optional params such as
  `"clear_usage"` and `"proration_behavior"`. Runs the proration guard before
  dispatching.

  The 3-arity form delegates to 4-arity with empty params.
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) and is_list(opts),
    do: delete(client, id, %{}, opts)

  @spec delete(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, params, opts)
      when is_binary(id) and is_map(params) and is_list(opts) do
    with :ok <- Billing.Guards.check_proration_required(client, params) do
      %Request{method: :delete, path: "/v1/subscription_items/#{id}", params: params, opts: opts}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_singular(&from_map/1)
    end
  end

  @doc "Like `delete/3` but raises on failure."
  @spec delete!(Client.t(), String.t(), keyword()) :: t()
  def delete!(%Client{} = client, id, opts \\ []) when is_binary(id) and is_list(opts),
    do: client |> delete(id, opts) |> Resource.unwrap_bang!()

  @doc "Like `delete/4` but raises on failure."
  @spec delete!(Client.t(), String.t(), map(), keyword()) :: t()
  def delete!(%Client{} = client, id, params, opts)
      when is_binary(id) and is_map(params) and is_list(opts),
      do: client |> delete(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Lists SubscriptionItems filtered by subscription.

  **Requires** `"subscription"` in params. Raises `ArgumentError` otherwise
  (OQ-2: unfiltered listing is an antipattern).
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(
      params,
      "subscription",
      ~s|SubscriptionItem.list/3 requires a "subscription" key in params. Example: %{"subscription" => "sub_..."}|
    )

    %Request{method: :get, path: "/v1/subscription_items", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Lazy stream of SubscriptionItems for a given subscription.

  **Requires** `"subscription"` in params.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(
      params,
      "subscription",
      ~s|SubscriptionItem.stream!/3 requires a "subscription" key in params.|
    )

    req = %Request{method: :get, path: "/v1/subscription_items", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%SubscriptionItem{}` struct.

  Returns `nil` when given `nil`.

  **`id` is always preserved.** stripity_stripe had a well-known bug where
  nested SubscriptionItems inside Subscription responses lost their id
  (see issue #208), making programmatic updates impossible. This decoder
  covers that case explicitly via the round-trip unit tests.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "subscription_item",
      billing_thresholds: known["billing_thresholds"],
      created: known["created"],
      discounts: known["discounts"],
      metadata: known["metadata"],
      plan: known["plan"],
      price: known["price"],
      proration_behavior: known["proration_behavior"],
      quantity: known["quantity"],
      subscription: known["subscription"],
      tax_rates: known["tax_rates"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.SubscriptionItem do
  import Inspect.Algebra

  def inspect(item, opts) do
    # Mask potentially sensitive nested maps via presence markers.
    metadata_repr = if is_nil(item.metadata) or item.metadata == %{}, do: nil, else: :present
    billing_repr = if is_nil(item.billing_thresholds), do: nil, else: :present

    base = [
      id: item.id,
      object: item.object,
      subscription: item.subscription,
      quantity: item.quantity,
      metadata: metadata_repr,
      billing_thresholds: billing_repr
    ]

    fields = if item.extra == %{}, do: base, else: base ++ [extra: item.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.SubscriptionItem<" | pairs] ++ [">"])
  end
end
