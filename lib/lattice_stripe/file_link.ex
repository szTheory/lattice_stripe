defmodule LatticeStripe.FileLink do
  @moduledoc """
  Represents a link to a Stripe file that can be shared outside your account.

  FileLinks are top-level resources (not nested under File). They provide
  publicly accessible URLs with optional expiration. File links expire --
  they are not deleted.

  ## Create a Link

      {:ok, link} = LatticeStripe.FileLink.create(client, %{
        "file" => "file_abc123"
      })

  ## Update Expiration

      {:ok, link} = LatticeStripe.FileLink.update(client, "link_abc123", %{
        "expires_at" => 1700000000
      })

  ## List with Auto-Pagination

      LatticeStripe.FileLink.stream!(client)
      |> Enum.take(50)

  ## Stripe API Reference

  See the [Stripe FileLink API](https://docs.stripe.com/api/file_links) for the
  full object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}

  @known_fields ~w[
    id object created expired expires_at file livemode metadata url
  ]

  defstruct [
    :id,
    :created,
    :expired,
    :expires_at,
    :file,
    :livemode,
    :metadata,
    :url,
    object: "file_link",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          created: integer() | nil,
          expired: boolean() | nil,
          expires_at: integer() | nil,
          file: String.t() | LatticeStripe.File.t() | nil,
          livemode: boolean() | nil,
          metadata: map(),
          url: String.t() | nil,
          extra: map()
        }

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "file_link",
      created: map["created"],
      expired: map["expired"],
      expires_at: map["expires_at"],
      file: ObjectTypes.maybe_deserialize(map["file"]),
      livemode: map["livemode"],
      metadata: map["metadata"] || %{},
      url: map["url"],
      extra: Map.drop(map, @known_fields)
    }
  end

  @doc """
  Creates a new file link for a given file ID.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/file_links", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a file link by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/file_links/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a file link (e.g., sets or clears expiration).
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/file_links/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists file links with optional filters.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/file_links", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all file links, auto-paginating as needed.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/file_links", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Same as `create/3` but raises on error.
  """
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Same as `retrieve/3` but raises on error.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Same as `update/4` but raises on error.
  """
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Same as `list/3` but raises on error.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end
end

defimpl Inspect, for: LatticeStripe.FileLink do
  import Inspect.Algebra

  def inspect(file_link, opts) do
    fields = [
      id: file_link.id,
      object: file_link.object,
      expired: file_link.expired,
      livemode: file_link.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.FileLink<" | pairs] ++ [">"])
  end
end
