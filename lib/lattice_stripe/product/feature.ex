defmodule LatticeStripe.Product.Feature do
  @moduledoc """
  Stripe Product Feature attachments.

  A `%Feature{}` is the `product_feature` attachment (an id prefixed `prodft_`)
  between a Product (`prod_`) and an `LatticeStripe.Entitlements.Feature`
  definition (`feat_`). It is not the Product's `marketing_features` display
  copy. See [Entitlements](guides/entitlements.md) for the catalog-to-access
  lifecycle.
  """

  alias LatticeStripe.{Client, List, Request, Resource, Response}
  alias LatticeStripe.Entitlements.Feature, as: EntitlementsFeature

  @known_fields ~w(id object livemode entitlement_feature deleted)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          livemode: boolean() | nil,
          entitlement_feature: EntitlementsFeature.t() | nil,
          deleted: boolean(),
          extra: map()
        }

  defstruct [
    :id,
    :livemode,
    :entitlement_feature,
    object: "product_feature",
    deleted: false,
    extra: %{}
  ]

  @doc """
  Attach an entitlement feature definition to a Product.

  `params` must contain the string key `"entitlement_feature"`; it has no
  default because Stripe's attachment endpoint requires that definition ID.
  """
  @spec create(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(client, product_id, params, opts \\ [])

  def create(%Client{}, product_id, _params, _opts) when product_id in [nil, ""] do
    validate_product_id!(product_id, :create)
  end

  def create(%Client{} = client, product_id, params, opts)
      when is_binary(product_id) and is_map(params) do
    Resource.require_param!(
      params,
      "entitlement_feature",
      "LatticeStripe.Product.Feature.create/4 requires an entitlement_feature param"
    )

    %Request{method: :post, path: collection_path(product_id), params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/4`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), String.t(), map(), keyword()) :: t()
  def create!(client, product_id, params, opts \\ []),
    do: client |> create(product_id, params, opts) |> Resource.unwrap_bang!()

  @doc "Retrieve one Product Feature attachment by its `prodft_` id."
  @spec retrieve(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def retrieve(client, product_id, product_feature_id, opts \\ [])

  def retrieve(%Client{}, product_id, _product_feature_id, _opts) when product_id in [nil, ""] do
    validate_product_id!(product_id, :retrieve)
  end

  def retrieve(%Client{}, _product_id, product_feature_id, _opts)
      when product_feature_id in [nil, ""] do
    validate_product_feature_id!(product_feature_id, :retrieve)
  end

  def retrieve(%Client{} = client, product_id, product_feature_id, opts)
      when is_binary(product_id) and is_binary(product_feature_id) do
    %Request{
      method: :get,
      path: item_path(product_id, product_feature_id),
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `retrieve/4`. Raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), String.t(), String.t(), keyword()) :: t()
  def retrieve!(client, product_id, product_feature_id, opts \\ []),
    do: client |> retrieve(product_id, product_feature_id, opts) |> Resource.unwrap_bang!()

  @doc "List Product Feature attachments for a Product."
  @spec list(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, LatticeStripe.Error.t()}
  def list(client, product_id, params \\ %{}, opts \\ [])

  def list(%Client{}, product_id, _params, _opts) when product_id in [nil, ""] do
    validate_product_id!(product_id, :list)
  end

  def list(%Client{} = client, product_id, params, opts)
      when is_binary(product_id) and is_map(params) do
    %Request{method: :get, path: collection_path(product_id), params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Bang variant of `list/4`. Raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list!(client, product_id, params \\ %{}, opts \\ []),
    do: client |> list(product_id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Lazily enumerate every Product Feature attachment for a Product.

  Pagination mechanics are delegated to `LatticeStripe.List.stream!/2`; each
  attachment is decoded as it is emitted. There is intentionally no non-bang
  stream variant because later-page failures raise while a stream is consumed.
  """
  @spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream!(client, product_id, params \\ %{}, opts \\ [])

  def stream!(%Client{}, product_id, _params, _opts) when product_id in [nil, ""] do
    validate_product_id!(product_id, :stream!)
  end

  def stream!(%Client{} = client, product_id, params, opts)
      when is_binary(product_id) and is_map(params) do
    %Request{method: :get, path: collection_path(product_id), params: params, opts: opts}
    |> then(&List.stream!(client, &1))
    |> Stream.map(&from_map/1)
  end

  @doc "Delete one Product Feature attachment by its `prodft_` id."
  @spec delete(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def delete(client, product_id, product_feature_id, opts \\ [])

  def delete(%Client{}, product_id, _product_feature_id, _opts) when product_id in [nil, ""] do
    validate_product_id!(product_id, :delete)
  end

  def delete(%Client{}, _product_id, product_feature_id, _opts)
      when product_feature_id in [nil, ""] do
    validate_product_feature_id!(product_feature_id, :delete)
  end

  def delete(%Client{}, _product_id, "feat_" <> _rest, _opts) do
    raise ArgumentError,
          "LatticeStripe.Product.Feature.delete/4 requires a product feature attachment id, not an entitlement feature definition id"
  end

  def delete(%Client{} = client, product_id, product_feature_id, opts)
      when is_binary(product_id) and is_binary(product_feature_id) do
    %Request{
      method: :delete,
      path: item_path(product_id, product_feature_id),
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `delete/4`. Raises `LatticeStripe.Error` on failure."
  @spec delete!(Client.t(), String.t(), String.t(), keyword()) :: t()
  def delete!(client, product_id, product_feature_id, opts \\ []),
    do: client |> delete(product_id, product_feature_id, opts) |> Resource.unwrap_bang!()

  @doc "Decode a Stripe Product Feature attachment map."
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil
  def from_map(%__MODULE__{} = feature), do: feature

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "product_feature",
      livemode: known["livemode"],
      entitlement_feature: EntitlementsFeature.from_map(known["entitlement_feature"]),
      deleted: known["deleted"] || false,
      extra: extra
    }
  end

  defp collection_path(product_id), do: "/v1/products/#{product_id}/features"

  defp item_path(product_id, product_feature_id),
    do: "#{collection_path(product_id)}/#{product_feature_id}"

  defp validate_product_id!(_product_id, operation) do
    raise ArgumentError,
          "LatticeStripe.Product.Feature.#{operation}/4 requires a non-empty product id"
  end

  defp validate_product_feature_id!(_product_feature_id, operation) do
    raise ArgumentError,
          "LatticeStripe.Product.Feature.#{operation}/4 requires a non-empty product feature id"
  end
end
