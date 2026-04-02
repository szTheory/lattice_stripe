defmodule LatticeStripe.Response do
  @moduledoc """
  Wraps a successful Stripe API response with metadata.

  `%LatticeStripe.Response{}` holds the decoded response body (in `data`),
  HTTP status code, response headers, and the extracted `request_id` from
  the `Request-Id` header.

  ## Bracket Access

  For singular object responses, bracket access delegates to `data`:

      {:ok, resp} = LatticeStripe.Client.request(client, req)
      resp["id"]       # same as resp.data["id"]
      resp["object"]   # same as resp.data["object"]

  When `data` is a `%LatticeStripe.List{}`, bracket access always returns `nil`.
  Use `resp.data.has_more`, `resp.data.data`, etc. directly for list responses.

  ## Request ID

  The `request_id` field is extracted from the `Request-Id` response header
  for convenience — it's the most common header value needed for debugging.
  Use `get_header/2` for any other header values.
  """

  @behaviour Access

  defstruct [:data, :status, :request_id, headers: []]

  @type t :: %__MODULE__{
          data: map() | LatticeStripe.List.t() | nil,
          status: non_neg_integer() | nil,
          headers: [{String.t(), String.t()}],
          request_id: String.t() | nil
        }

  @doc """
  Returns all values for the given header name (case-insensitive).

  Returns `[]` if the header is not found.

  ## Examples

      Response.get_header(resp, "Request-Id")
      # => ["req_abc123"]

      Response.get_header(resp, "x-custom")
      # => []
  """
  @spec get_header(t(), String.t()) :: [String.t()]
  def get_header(%__MODULE__{headers: headers}, name) do
    downcased = String.downcase(name)
    for {k, v} <- headers, String.downcase(k) == downcased, do: v
  end

  @impl Access
  def fetch(%__MODULE__{data: data}, key) when is_map(data) and not is_struct(data) do
    Map.fetch(data, key)
  end

  def fetch(_, _), do: :error

  @impl Access
  def get_and_update(%__MODULE__{data: data} = resp, key, fun)
      when is_map(data) and not is_struct(data) do
    {current, new_data} = Map.get_and_update(data, key, fun)
    {current, %{resp | data: new_data}}
  end

  def get_and_update(resp, _key, _fun) do
    {nil, resp}
  end

  @impl Access
  def pop(%__MODULE__{data: data} = resp, key) when is_map(data) and not is_struct(data) do
    {value, new_data} = Map.pop(data, key)
    {value, %{resp | data: new_data}}
  end

  def pop(resp, _key), do: {nil, resp}
end

defimpl Inspect, for: LatticeStripe.Response do
  def inspect(resp, opts) do
    sanitized = sanitize(resp)
    Inspect.Any.inspect(sanitized, opts)
  end

  defp sanitize(resp) do
    data_summary =
      cond do
        is_struct(resp.data, LatticeStripe.List) ->
          items = resp.data.data
          "LatticeStripe.List<#{length(items)} items>"

        is_map(resp.data) and not is_struct(resp.data) ->
          resp.data |> Map.take(["id", "object"]) |> Map.put("...", :truncated)

        true ->
          resp.data
      end

    %{resp | data: data_summary, headers: "(#{length(resp.headers)} headers)"}
  end
end
