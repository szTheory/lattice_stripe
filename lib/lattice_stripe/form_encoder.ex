defmodule LatticeStripe.FormEncoder do
  @moduledoc """
  Recursive Stripe-compatible form encoder.

  Encodes Elixir maps and keyword lists into URL-encoded form strings
  compatible with Stripe's v1 API format.

  Stripe uses bracket notation for nested parameters:

  - Nested maps: `metadata[key]=value`
  - Arrays of maps: `items[0][price]=price_123`
  - Arrays of scalars: `expand[0]=data.customer`

  ## Example

      iex> LatticeStripe.FormEncoder.encode(%{email: "user@example.com"})
      "email=user%40example.com"

      iex> LatticeStripe.FormEncoder.encode(%{metadata: %{plan: "pro"}})
      "metadata[plan]=pro"

      iex> LatticeStripe.FormEncoder.encode(%{items: [%{price: "price_123", quantity: 1}]})
      "items[0][price]=price_123&items[0][quantity]=1"
  """

  @doc """
  Encodes a map or keyword list to a URL-encoded query string.

  - Nested maps use bracket notation: `parent[child]=value`
  - Arrays of maps use indexed bracket notation: `parent[0][key]=value`
  - Arrays of scalars use indexed bracket notation: `parent[0]=value`
  - Nil values are omitted entirely (Stripe interprets nil as "unset")
  - Empty strings are preserved (Stripe uses `""` to clear a field)
  - Boolean values are encoded as literal `"true"` or `"false"` strings
  - Atom keys and values are converted via `to_string/1`
  - Output is sorted alphabetically for deterministic results
  """
  @spec encode(map() | keyword()) :: binary()
  def encode(params) when is_map(params) or is_list(params) do
    params
    |> flatten(nil)
    |> Enum.sort_by(fn {key, _val} -> key end)
    |> Enum.map_join("&", fn {key, val} ->
      encode_key(key) <> "=" <> URI.encode_www_form(val)
    end)
  end

  # Flatten a map or keyword list recursively into a list of {key_string, value_string} pairs.
  # prefix is the parent key string (nil for top-level).
  defp flatten(map, prefix) when is_map(map) do
    Enum.flat_map(map, fn {key, value} ->
      child_key = build_key(prefix, to_string(key))
      flatten_value(value, child_key)
    end)
  end

  defp flatten(list, prefix) when is_list(list) do
    # Check if it's a keyword list or a plain list
    if Keyword.keyword?(list) do
      Enum.flat_map(list, fn {key, value} ->
        child_key = build_key(prefix, to_string(key))
        flatten_value(value, child_key)
      end)
    else
      # Indexed array encoding: parent[0], parent[1], ...
      list
      |> Enum.with_index()
      |> Enum.flat_map(fn {value, index} ->
        child_key = build_key(prefix, to_string(index))
        flatten_value(value, child_key)
      end)
    end
  end

  # Flatten a single value given its fully-qualified key.
  defp flatten_value(nil, _key) do
    # Omit nil values entirely
    []
  end

  defp flatten_value(value, key) when is_map(value) do
    flatten(value, key)
  end

  defp flatten_value(value, key) when is_list(value) do
    flatten(value, key)
  end

  defp flatten_value(value, key) do
    # Scalar: boolean, integer, float, atom, binary
    [{key, to_string(value)}]
  end

  # Encode a key name preserving bracket notation.
  # Stripe's v1 API uses literal brackets in keys for nested params.
  # We URL-encode the key segments but not the brackets themselves.
  defp encode_key(key) do
    key
    |> String.split(~r/(\[|\])/, include_captures: true)
    |> Enum.map_join(fn
      "[" -> "["
      "]" -> "]"
      segment -> URI.encode_www_form(segment)
    end)
  end

  # Build the encoded key for a child given the parent prefix.
  # Top-level (prefix nil): just the key name.
  # Nested: parent[child]
  defp build_key(nil, key), do: key
  defp build_key(prefix, key), do: "#{prefix}[#{key}]"
end
