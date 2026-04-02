defmodule LatticeStripe.List do
  @moduledoc """
  Represents a paginated list of Stripe objects.

  Stripe returns two kinds of paginated collections:

  - **Cursor-based lists** — standard list endpoints (e.g., `/v1/customers`). Use
    `starting_after` / `ending_before` to page through results.
  - **Search results** — search endpoints (e.g., `/v1/customers/search`). Use
    `next_page` token to page through results. Note: search endpoints have
    **eventual consistency** — newly created objects may not appear immediately.

  ## Accessing Items

  Use `list.data` to access items on the current page:

      {:ok, resp} = LatticeStripe.Client.request(client, req)
      resp.data.data  # list of decoded maps for this page

  `LatticeStripe.List` does NOT implement `Enumerable` — `Enum.map(list, ...)` would
  mislead callers into thinking they are consuming all pages when they only see page 1.
  Use `list.data` for the current page. Use `stream!/2` or `stream/2` to lazily consume
  all pages.

  ## Streaming All Pages

  Use `stream!/2` when you have a client and request and want all matching items:

      req = %LatticeStripe.Request{method: :get, path: "/v1/customers", params: %{"limit" => "100"}}
      client
      |> LatticeStripe.List.stream!(req)
      |> Stream.take(200)
      |> Enum.to_list()

  Use `stream/2` when you already have a list from a prior request and want the rest:

      {:ok, %Response{data: list}} = Client.request(client, req)
      list
      |> LatticeStripe.List.stream(client)
      |> Enum.each(&process_item/1)

  ## Memory Warning

  When consuming an entire stream with no limit, you load all matching objects into
  memory. Use `Stream.take(N)` to limit results and avoid unexpected memory usage.
  """

  alias LatticeStripe.{Client, Request, Response}

  @known_keys ~w[object data has_more url total_count next_page]

  defstruct [
    :url,
    :total_count,
    :next_page,
    :_first_id,
    :_last_id,
    data: [],
    has_more: false,
    object: "list",
    extra: %{},
    _params: %{},
    _opts: []
  ]

  @type t :: %__MODULE__{
          data: [map()],
          has_more: boolean(),
          url: String.t() | nil,
          total_count: non_neg_integer() | nil,
          next_page: String.t() | nil,
          object: String.t(),
          extra: map(),
          _params: map(),
          _opts: keyword(),
          _first_id: String.t() | nil,
          _last_id: String.t() | nil
        }

  @doc """
  Builds a `%List{}` struct from decoded Stripe JSON.

  Optionally stores the original request params and opts in `_params` and `_opts`
  so streaming functions can reconstruct subsequent page requests.

  Also computes `_first_id` and `_last_id` from data items for cursor-based
  pagination — these are used by streaming functions to build next-page requests
  after the data buffer has been fully consumed.

  ## Examples

      List.from_json(%{"object" => "list", "data" => [...], "has_more" => true, "url" => "/v1/customers"})

      List.from_json(decoded, %{limit: 10}, [stripe_account: "acct_123"])
  """
  @spec from_json(map(), map(), keyword()) :: t()
  def from_json(decoded, params \\ %{}, opts \\ []) do
    items = decoded["data"] || []

    %__MODULE__{
      object: decoded["object"],
      data: items,
      has_more: decoded["has_more"] || false,
      url: decoded["url"],
      total_count: decoded["total_count"],
      next_page: decoded["next_page"],
      extra: Map.drop(decoded, @known_keys),
      _params: params,
      _opts: opts,
      _first_id: first_item_id(items),
      _last_id: last_item_id(items)
    }
  end

  @doc """
  Creates a lazy stream that auto-paginates through all items matching the request.

  Makes the initial API call, then lazily fetches subsequent pages as the stream
  is consumed. Emits individual items (flattened from pages), not page structs.

  Raises `LatticeStripe.Error` if any page fetch fails (after retries are exhausted).

  ## Example

      req = %LatticeStripe.Request{method: :get, path: "/v1/customers", params: %{"limit" => "100"}}
      client
      |> LatticeStripe.List.stream!(req)
      |> Stream.take(50)
      |> Enum.to_list()

  ## Memory Warning

  Without `Stream.take/2`, the stream will fetch ALL matching objects.
  For large collections, always limit with `Stream.take/2`.
  """
  @spec stream!(Client.t(), Request.t()) :: Enumerable.t()
  def stream!(%Client{} = client, %Request{} = req) do
    Stream.resource(
      fn -> fetch_page!(client, req) end,
      fn acc -> next_item(acc, client) end,
      fn _acc -> :ok end
    )
  end

  @doc """
  Creates a lazy stream from an existing `%List{}`, re-emitting its items
  then fetching remaining pages.

  The stream includes items already present in the list, followed by items
  from subsequent pages (if `has_more` is true).

  Raises `LatticeStripe.Error` if any subsequent page fetch fails.

  ## Example

      {:ok, %Response{data: list}} = Client.request(client, req)
      # Process first page manually, then stream the rest:
      list
      |> LatticeStripe.List.stream(client)
      |> Enum.each(&process_customer/1)
  """
  @spec stream(t(), Client.t()) :: Enumerable.t()
  def stream(%__MODULE__{} = list, %Client{} = client) do
    Stream.resource(
      fn -> list end,
      fn acc -> next_item(acc, client) end,
      fn _acc -> :ok end
    )
  end

  # ---------------------------------------------------------------------------
  # Private: stream state machine
  # ---------------------------------------------------------------------------

  # Halt when buffer is empty and no more pages.
  defp next_item(%__MODULE__{data: [], has_more: false}, _client) do
    {:halt, :done}
  end

  # Buffer empty but more pages available — fetch next page and recurse.
  # The recursive call immediately starts draining the new buffer, avoiding
  # an empty emission that would cause Stream.resource to call next_fun again.
  defp next_item(%__MODULE__{data: [], has_more: true} = list, client) do
    next_page = fetch_next_page!(list, client)
    next_item(next_page, client)
  end

  # Emit one item and advance the buffer.
  defp next_item(%__MODULE__{data: [item | rest]} = list, _client) do
    {[item], %{list | data: rest}}
  end

  # ---------------------------------------------------------------------------
  # Private: page fetching
  # ---------------------------------------------------------------------------

  # Fetches the initial page from Client.request/2.
  # Raises LatticeStripe.Error on failure (bang semantics).
  defp fetch_page!(client, req) do
    case Client.request(client, req) do
      {:ok, %Response{data: %__MODULE__{} = list}} ->
        list

      {:ok, %Response{data: _other}} ->
        raise "Expected list response from #{req.path}"

      {:error, error} ->
        raise error
    end
  end

  # Builds the next-page request from the current list state and fetches it.
  defp fetch_next_page!(%__MODULE__{} = list, client) do
    req = build_next_page_request(list)
    fetch_page!(client, req)
  end

  # Builds the Request struct for the next page, handling all three pagination modes:
  # 1. Search pagination (object: "search_result"): use next_page token
  # 2. Backward cursor pagination (ending_before present): use _first_id
  # 3. Forward cursor pagination (default): use _last_id
  #
  # Strips starting_after/ending_before/page from base params to avoid conflicts,
  # then merges in the appropriate pagination param.
  #
  # Per-request opts carry forward (D-31) except idempotency_key (GET pages don't need it).
  defp build_next_page_request(%__MODULE__{} = list) do
    base_params = Map.drop(list._params, ["starting_after", "ending_before", "page"])

    pagination_params =
      cond do
        # Search pagination (D-16): use page token from response
        list.object == "search_result" && list.next_page ->
          %{"page" => list.next_page}

        # Backward cursor pagination (D-06): use first item ID from original page
        Map.has_key?(list._params, "ending_before") && list._first_id != nil ->
          %{"ending_before" => list._first_id}

        # Forward cursor pagination: use last item ID from original page
        list._last_id != nil ->
          %{"starting_after" => list._last_id}

        true ->
          %{}
      end

    # Strip idempotency_key from opts — page fetches are GET (D-31)
    opts = Keyword.delete(list._opts, :idempotency_key)

    %Request{
      method: :get,
      path: list.url,
      params: Map.merge(base_params, pagination_params),
      opts: opts
    }
  end

  # ---------------------------------------------------------------------------
  # Private: ID extraction helpers
  # ---------------------------------------------------------------------------

  # Extract ID from the first item in the list.
  # Called once during from_json/3 before the buffer can be consumed.
  defp first_item_id([%{"id" => id} | _]), do: id
  defp first_item_id(_), do: nil

  # Extract ID from the last item in the list.
  # Called once during from_json/3 before the buffer can be consumed.
  defp last_item_id([]), do: nil

  defp last_item_id(items) do
    case Enum.at(items, -1) do
      %{"id" => id} -> id
      _ -> nil
    end
  end
end

defimpl Inspect, for: LatticeStripe.List do
  def inspect(list, opts) do
    sanitized = sanitize(list)
    Inspect.Any.inspect(sanitized, opts)
  end

  defp sanitize(list) do
    item_count = length(list.data)

    first_summary =
      case list.data do
        [first | _] when is_map(first) ->
          first |> Map.take(["id", "object"]) |> Map.put("...", :truncated)

        _ ->
          nil
      end

    # Show structural info, hide PII in data items
    %{
      __struct__: LatticeStripe.List,
      object: list.object,
      url: list.url,
      has_more: list.has_more,
      total_count: list.total_count,
      data:
        "#{item_count} item(s)#{if first_summary, do: " [first: #{Kernel.inspect(first_summary)}]", else: ""}",
      next_page: list.next_page
    }
  end
end
