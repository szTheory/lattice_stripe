defmodule LatticeStripe.PromotionCode do
  @moduledoc """
  Operations on Stripe Promotion Code objects.

  A PromotionCode is the customer-facing form of a Coupon — it's the string
  a customer types at checkout (e.g., `"SUMMER25USER"`). Multiple PromotionCodes
  can share the same underlying Coupon, each with its own usage restrictions.

  ## Identifiers

  Three distinct identifiers are easy to confuse:

  | Field | Example | Notes |
  |-------|---------|-------|
  | `Coupon.id` | `"SUMMER25"` or `"8sXjvpGx"` | Coupon ID. May be user-supplied on Coupon.create (D-07) or auto-generated. |
  | `PromotionCode.id` | `"promo_1NxYz..."` | Always Stripe-generated, prefixed `promo_`. |
  | `PromotionCode.code` | `"SUMMER25USER"` | The customer-facing string. Assignable on create via the `"code"` param. |

  The customer types `PromotionCode.code` at checkout; the Stripe API accepts it
  and resolves it to the `PromotionCode.id`, which in turn references the
  underlying Coupon.

  ## Usage

      # Create a PromotionCode attached to an existing Coupon
      {:ok, promo} = LatticeStripe.PromotionCode.create(client, %{
        "coupon" => "SUMMER25",
        "code" => "SUMMER25USER",
        "active" => true,
        "max_redemptions" => 100
      })

      # Update (deactivate)
      {:ok, _} = LatticeStripe.PromotionCode.update(client, promo.id, %{"active" => "false"})

  ## Finding promotion codes

  PromotionCode has no `search/3` endpoint (verified absent from Stripe's OpenAPI
  spec — only 7 resources have search: charges, customers, invoices, payment_intents,
  prices, products, subscriptions). Discover existing promotion codes via `list/2`
  with filters:

  - `code` — find by customer-facing code string
  - `coupon` — all promotion codes attached to a coupon ID
  - `customer` — promotion codes restricted to a specific customer
  - `active` — filter to only active or inactive codes

  Example:

      {:ok, resp} =
        LatticeStripe.PromotionCode.list(client, %{
          "code" => "SUMMER25USER",
          "active" => "true"
        })

  ## Operations not supported by the Stripe API

  - **search** — The `/v1/promotion_codes/search` endpoint does not exist.
    Use `list/2` with filters (see above).
  - **delete** — PromotionCodes cannot be deleted. To deactivate, call
    `update/4` with `%{"active" => "false"}`.

  ## Stripe API Reference

  See the [Stripe Promotion Code API](https://docs.stripe.com/api/promotion_codes).
  """

  alias LatticeStripe.{Client, Coupon, Error, List, ObjectTypes, Request, Resource, Response}

  @known_fields ~w[
    id object active code coupon created customer expires_at livemode
    max_redemptions metadata restrictions times_redeemed
  ]

  defstruct [
    :id,
    :active,
    :code,
    :coupon,
    :created,
    :customer,
    :expires_at,
    :livemode,
    :max_redemptions,
    :metadata,
    :restrictions,
    :times_redeemed,
    object: "promotion_code",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          active: boolean() | nil,
          code: String.t() | nil,
          coupon: Coupon.t() | String.t() | nil,
          created: integer() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          expires_at: integer() | nil,
          livemode: boolean() | nil,
          max_redemptions: integer() | nil,
          metadata: map() | nil,
          restrictions: map() | nil,
          times_redeemed: integer() | nil,
          extra: map()
        }

  @doc "Creates a PromotionCode. POST /v1/promotion_codes. Pass \"code\" for the customer-facing string (D-07)."
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/promotion_codes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Retrieves a PromotionCode by ID (the `promo_...` ID, not the `code` string)."
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/promotion_codes/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc ~s(Updates a PromotionCode. POST /v1/promotion_codes/:id. Use `%{"active" => "false"}` to deactivate.)
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/promotion_codes/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists PromotionCodes with optional filters.

  Filters (per D-06 discovery path): `code`, `coupon`, `customer`, `active`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/promotion_codes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/promotion_codes", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # Bang variants
  def create!(%Client{} = c, p \\ %{}, o \\ []), do: create(c, p, o) |> Resource.unwrap_bang!()

  def retrieve!(%Client{} = c, id, o \\ []) when is_binary(id),
    do: retrieve(c, id, o) |> Resource.unwrap_bang!()

  def update!(%Client{} = c, id, p, o \\ []) when is_binary(id),
    do: update(c, id, p, o) |> Resource.unwrap_bang!()

  def list!(%Client{} = c, p \\ %{}, o \\ []), do: list(c, p, o) |> Resource.unwrap_bang!()

  # NOTE: NO search/2,3 (D-05, verified absent). NO delete/2,3 (not in Stripe API).
  # Absence is the interface.

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "promotion_code",
      active: map["active"],
      code: map["code"],
      coupon: decode_coupon(map["coupon"]),
      created: map["created"],
      customer:
        (if is_map(map["customer"]),
           do: ObjectTypes.maybe_deserialize(map["customer"]),
           else: map["customer"]),
      expires_at: map["expires_at"],
      livemode: map["livemode"],
      max_redemptions: map["max_redemptions"],
      metadata: map["metadata"],
      restrictions: map["restrictions"],
      times_redeemed: map["times_redeemed"],
      extra: Map.drop(map, @known_fields)
    }
  end

  # Coupon is expanded by default on PromotionCode responses (per Stripe docs).
  # Handle all three shapes: nil / string ID / expanded map.
  defp decode_coupon(nil), do: nil
  defp decode_coupon(id) when is_binary(id), do: id
  defp decode_coupon(%{} = coupon_map), do: Coupon.from_map(coupon_map)
end
