defmodule LatticeStripe.File do
  @moduledoc """
  Represents a file uploaded to Stripe.

  Files are created via multipart upload to `files.stripe.com` and used for
  dispute evidence, identity verification, and other purposes. Files are
  immutable after creation -- there is no update or delete operation.

  ## Upload

      binary = File.read!("evidence.pdf")
      {:ok, file} = LatticeStripe.File.create(client, %{
        "purpose" => "dispute_evidence",
        "file" => binary,
        "filename" => "evidence.pdf"
      })

  ## Retrieve

      {:ok, file} = LatticeStripe.File.retrieve(client, "file_abc123")

  ## List with Auto-Pagination

      LatticeStripe.File.stream!(client, %{"purpose" => "dispute_evidence"})
      |> Enum.take(50)

  ## Stripe API Reference

  See the [Stripe File API](https://docs.stripe.com/api/files) for the full
  object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, FileLink, List, Request, Resource, Response}

  @known_fields ~w[
    id object created expires_at filename links purpose size title type url
  ]

  defstruct [
    :id,
    :created,
    :expires_at,
    :filename,
    :links,
    :purpose,
    :size,
    :title,
    :type,
    :url,
    object: "file",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          created: integer() | nil,
          expires_at: integer() | nil,
          filename: String.t() | nil,
          links: LatticeStripe.List.t() | nil,
          purpose: String.t() | nil,
          size: integer() | nil,
          title: String.t() | nil,
          type: String.t() | nil,
          url: String.t() | nil,
          extra: map()
        }

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "file",
      created: map["created"],
      expires_at: map["expires_at"],
      filename: map["filename"],
      links: parse_links(map["links"]),
      purpose: map["purpose"],
      size: map["size"],
      title: map["title"],
      type: map["type"],
      url: map["url"],
      extra: Map.drop(map, @known_fields)
    }
  end

  @doc """
  Uploads a file to Stripe via multipart/form-data.

  The `params` map must include `"purpose"` (string) and `"file"` (raw binary).
  Optionally include `"filename"` (defaults to `"upload"`) and `"file_link_data"`.

  ## Examples

      binary = File.read!("evidence.pdf")
      LatticeStripe.File.create(client, %{
        "purpose" => "dispute_evidence",
        "file" => binary,
        "filename" => "evidence.pdf"
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    file_binary = Map.fetch!(params, "file")
    upload_params = Map.drop(params, ["file"])

    Client.upload(client, file_binary, upload_params, opts)
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a file by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/files/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists files with optional filters.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/files", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all files, auto-paginating as needed.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/files", params: params, opts: opts}
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
  Same as `list/3` but raises on error.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Private: nested links deserialization
  # Mirrors Invoice.parse_lines/1 pattern -- see lib/lattice_stripe/invoice.ex
  # ---------------------------------------------------------------------------

  defp parse_links(nil), do: nil

  defp parse_links(%{"object" => "list"} = links_map) do
    List.from_json(links_map)
    |> Map.update!(:data, fn items ->
      Enum.map(items, &FileLink.from_map/1)
    end)
  end

  defp parse_links(other), do: other
end

defimpl Inspect, for: LatticeStripe.File do
  import Inspect.Algebra

  def inspect(file, opts) do
    fields = [
      id: file.id,
      object: file.object,
      purpose: file.purpose,
      filename: file.filename,
      size: file.size
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.File<" | pairs] ++ [">"])
  end
end
