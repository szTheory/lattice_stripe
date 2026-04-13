defmodule LatticeStripe.Resource do
  @moduledoc false

  alias LatticeStripe.{Error, List, Response}

  @doc """
  Unwraps a singular resource response by applying `from_map_fn` to the response data.

  Used by resource modules to convert a raw decoded map from `Client.request/2` into
  a typed struct. Passes errors through unchanged.

  ## Parameters

  - `result` - `{:ok, %Response{}}` or `{:error, %Error{}}` from `Client.request/2`
  - `from_map_fn` - A function mapping a decoded map to a struct (e.g., `&Customer.from_map/1`)

  ## Returns

  - `{:ok, struct()}` on success — struct type depends on `from_map_fn`
  - `{:error, %LatticeStripe.Error{}}` on failure (passed through unchanged)

  ## Example

      %Request{method: :get, path: "/v1/customers/cus_123"}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_singular(&Customer.from_map/1)
      # => {:ok, %Customer{id: "cus_123", ...}}
  """
  @spec unwrap_singular({:ok, Response.t()} | {:error, Error.t()}, (map() -> struct())) ::
          {:ok, struct()} | {:error, Error.t()}
  def unwrap_singular({:ok, %Response{data: data}}, from_map_fn) do
    {:ok, from_map_fn.(data)}
  end

  def unwrap_singular({:error, %Error{}} = error, _from_map_fn), do: error

  @doc """
  Unwraps a list response by applying `from_map_fn` to each item in the list.

  Used by resource modules to convert a paginated response from `Client.request/2`
  into a typed list response. The `%Response{}` wrapper is preserved so callers
  can access `resp.data.has_more`, `resp.data.data`, etc.

  ## Parameters

  - `result` - `{:ok, %Response{data: %List{}}}` or `{:error, %Error{}}` from `Client.request/2`
  - `from_map_fn` - A function mapping each decoded map to a struct (e.g., `&Customer.from_map/1`)

  ## Returns

  - `{:ok, %Response{data: %List{data: [struct(), ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure (passed through unchanged)

  ## Example

      %Request{method: :get, path: "/v1/customers"}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_list(&Customer.from_map/1)
      # => {:ok, %Response{data: %List{data: [%Customer{...}, ...]}}}
  """
  @spec unwrap_list({:ok, Response.t()} | {:error, Error.t()}, (map() -> struct())) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def unwrap_list({:ok, %Response{data: %List{} = list} = resp}, from_map_fn) do
    typed_items = Enum.map(list.data, from_map_fn)
    {:ok, %{resp | data: %{list | data: typed_items}}}
  end

  def unwrap_list({:error, %Error{}} = error, _from_map_fn), do: error

  @doc """
  Unwraps a result tuple, returning the value on success or raising on failure.

  Used by bang variants (`create!/2`, `retrieve!/2`, etc.) to convert a
  `{:ok, result}` or `{:error, error}` tuple into a plain value or exception.

  ## Parameters

  - `result` - `{:ok, value}` or `{:error, %LatticeStripe.Error{}}`

  ## Returns

  - `value` on `{:ok, value}`
  - Raises `LatticeStripe.Error` on `{:error, error}`

  ## Example

      {:ok, customer} = create(client, params)
      |> Resource.unwrap_bang!()
      # On error, raises LatticeStripe.Error
  """
  @spec unwrap_bang!({:ok, term()} | {:error, Error.t()}) :: term()
  def unwrap_bang!({:ok, result}), do: result
  def unwrap_bang!({:error, %Error{} = error}), do: raise(error)

  @doc """
  Validates that a required parameter key is present in the params map.

  Raises `ArgumentError` immediately (before any network call) if the key is missing.
  Used by resource modules to enforce required params at the call site.

  ## Parameters

  - `params` - The request params map
  - `key` - The required key string (e.g., `"payment_intent"`, `"customer"`)
  - `message` - The error message to raise if the key is missing

  ## Returns

  - `:ok` if the key is present
  - Raises `ArgumentError` with `message` if the key is missing

  ## Example

      # In PaymentMethod.list/3:
      Resource.require_param!(params, "customer", "PaymentMethod.list requires a customer param")
  """
  @spec require_param!(map(), String.t(), String.t()) :: :ok
  def require_param!(params, key, message) do
    unless Map.has_key?(params, key) do
      raise ArgumentError, message
    end

    :ok
  end
end
