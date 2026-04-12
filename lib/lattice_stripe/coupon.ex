defmodule LatticeStripe.Coupon do
  @moduledoc """
  Operations on Stripe Coupon objects.

  A Coupon is a discount template — it does not become "applied" until it is
  attached to a Customer, Subscription, or Invoice, at which point Stripe
  materialises a `Discount` record referencing the Coupon. Coupons are
  immutable by design: once created, the discount terms cannot change.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)

      # Auto-generated ID
      {:ok, coupon} = LatticeStripe.Coupon.create(client, %{
        "percent_off" => 25,
        "duration" => "once"
      })

      # Custom ID (D-07 pass-through)
      {:ok, coupon} = LatticeStripe.Coupon.create(client, %{
        "id" => "SUMMER25",
        "percent_off" => 25,
        "duration" => "once"
      })

  ## Custom IDs

  Pass the desired ID directly in the params map as `"id"`. The SDK performs no
  client-side validation — malformed IDs flow through as Stripe errors. Stripe's
  charset and length constraints are the server's contract.

  ## Operations not supported by the Stripe API

  - **update** — Coupons are immutable by design. To change coupon terms, create
    a new Coupon with the new parameters and attach it to fresh discount records.
  - **search** — The `/v1/coupons/search` endpoint does not exist in Stripe's API.
    Use `list/2` with filters for discovery.

  ## Stripe API Reference

  See the [Stripe Coupon API](https://docs.stripe.com/api/coupons).
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}
  alias LatticeStripe.Coupon.AppliesTo

  @known_fields ~w[
    id object amount_off applies_to created currency currency_options deleted
    duration duration_in_months livemode max_redemptions metadata name
    percent_off redeem_by times_redeemed valid
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :amount_off,
    :applies_to,
    :created,
    :currency,
    :currency_options,
    :duration,
    :duration_in_months,
    :livemode,
    :max_redemptions,
    :metadata,
    :name,
    :percent_off,
    :redeem_by,
    :times_redeemed,
    :valid,
    object: "coupon",
    deleted: false,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount_off: integer() | nil,
          applies_to: LatticeStripe.Coupon.AppliesTo.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          currency_options: map() | nil,
          duration: :forever | :once | :repeating | String.t() | nil,
          duration_in_months: integer() | nil,
          livemode: boolean() | nil,
          max_redemptions: integer() | nil,
          metadata: map() | nil,
          name: String.t() | nil,
          percent_off: float() | nil,
          redeem_by: integer() | nil,
          times_redeemed: integer() | nil,
          valid: boolean() | nil,
          deleted: boolean(),
          extra: map()
        }

  @doc "Creates a Coupon. POST /v1/coupons. Pass \"id\" in params for a custom ID (D-07)."
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/coupons", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Retrieves a Coupon by ID. GET /v1/coupons/:id."
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/coupons/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Deletes a Coupon by ID. DELETE /v1/coupons/:id."
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :delete, path: "/v1/coupons/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Lists Coupons with optional filters. GET /v1/coupons."
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/coupons", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/coupons", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # Bang variants
  def create!(%Client{} = c, p \\ %{}, o \\ []), do: create(c, p, o) |> Resource.unwrap_bang!()

  def retrieve!(%Client{} = c, id, o \\ []) when is_binary(id),
    do: retrieve(c, id, o) |> Resource.unwrap_bang!()

  def delete!(%Client{} = c, id, o \\ []) when is_binary(id),
    do: delete(c, id, o) |> Resource.unwrap_bang!()

  def list!(%Client{} = c, p \\ %{}, o \\ []), do: list(c, p, o) |> Resource.unwrap_bang!()

  # NOTE: NO update/3,4 and NO search/2,3 — D-05 forbidden ops. Absence is the interface.

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "coupon",
      amount_off: map["amount_off"],
      applies_to: decode_applies_to(map["applies_to"]),
      created: map["created"],
      currency: map["currency"],
      currency_options: map["currency_options"],
      duration: atomize_duration(map["duration"]),
      duration_in_months: map["duration_in_months"],
      livemode: map["livemode"],
      max_redemptions: map["max_redemptions"],
      metadata: map["metadata"],
      name: map["name"],
      percent_off: map["percent_off"],
      redeem_by: map["redeem_by"],
      times_redeemed: map["times_redeemed"],
      valid: map["valid"],
      deleted: map["deleted"] || false,
      extra: Map.drop(map, @known_fields)
    }
  end

  defp decode_applies_to(nil), do: nil
  defp decode_applies_to(%{} = m), do: AppliesTo.from_map(m)

  # D-03 whitelist atomization
  defp atomize_duration("forever"), do: :forever
  defp atomize_duration("once"), do: :once
  defp atomize_duration("repeating"), do: :repeating
  defp atomize_duration(nil), do: nil
  defp atomize_duration(other), do: other
end

defmodule LatticeStripe.Coupon.AppliesTo do
  @moduledoc """
  Typed representation of a Coupon's `applies_to` restriction.

  When present, `products` lists the Product IDs this coupon is restricted to.
  When the parent Coupon's `applies_to` field is `nil`, the coupon has no
  product restrictions.
  """

  @known_fields ~w[products]

  defstruct [:products, extra: %{}]

  @type t :: %__MODULE__{
          products: [String.t()] | nil,
          extra: map()
        }

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{products: map["products"], extra: Map.drop(map, @known_fields)}
  end
end
