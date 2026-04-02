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
  Use `list.data` for the current page. Use streaming functions (implemented in a
  future plan) to lazily consume all pages.

  ## Memory Warning

  When consuming an entire stream with no limit, you load all matching objects into
  memory. Use `Stream.take(N)` to limit results and avoid unexpected memory usage.
  """

  @known_keys ~w[object data has_more url total_count next_page]

  defstruct [
    :url,
    :total_count,
    :next_page,
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
          _opts: keyword()
        }

  @doc """
  Builds a `%List{}` struct from decoded Stripe JSON.

  Optionally stores the original request params and opts in `_params` and `_opts`
  so streaming functions can reconstruct subsequent page requests.

  ## Examples

      List.from_json(%{"object" => "list", "data" => [...], "has_more" => true, "url" => "/v1/customers"})

      List.from_json(decoded, %{limit: 10}, [stripe_account: "acct_123"])
  """
  @spec from_json(map(), map(), keyword()) :: t()
  def from_json(decoded, params \\ %{}, opts \\ []) do
    %__MODULE__{
      object: decoded["object"],
      data: decoded["data"] || [],
      has_more: decoded["has_more"] || false,
      url: decoded["url"],
      total_count: decoded["total_count"],
      next_page: decoded["next_page"],
      extra: Map.drop(decoded, @known_keys),
      _params: params,
      _opts: opts
    }
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
