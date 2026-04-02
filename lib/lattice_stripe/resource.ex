defmodule LatticeStripe.Resource do
  @moduledoc false

  alias LatticeStripe.{Error, List, Response}

  @spec unwrap_singular({:ok, Response.t()} | {:error, Error.t()}, (map() -> struct())) ::
          {:ok, struct()} | {:error, Error.t()}
  def unwrap_singular({:ok, %Response{data: data}}, from_map_fn) do
    {:ok, from_map_fn.(data)}
  end

  def unwrap_singular({:error, %Error{}} = error, _from_map_fn), do: error

  @spec unwrap_list({:ok, Response.t()} | {:error, Error.t()}, (map() -> struct())) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def unwrap_list({:ok, %Response{data: %List{} = list} = resp}, from_map_fn) do
    typed_items = Enum.map(list.data, from_map_fn)
    {:ok, %{resp | data: %{list | data: typed_items}}}
  end

  def unwrap_list({:error, %Error{}} = error, _from_map_fn), do: error

  @spec unwrap_bang!({:ok, term()} | {:error, Error.t()}) :: term()
  def unwrap_bang!({:ok, result}), do: result
  def unwrap_bang!({:error, %Error{} = error}), do: raise(error)

  @spec require_param!(map(), String.t(), String.t()) :: :ok
  def require_param!(params, key, message) do
    unless Map.has_key?(params, key) do
      raise ArgumentError, message
    end

    :ok
  end
end
