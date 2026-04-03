defmodule LatticeStripe.Customer do
  @moduledoc """
  Operations on Stripe Customer objects.

  A Customer in Stripe represents a person or company you charge money from or
  send money to. Customers let you save payment methods, track charges, and
  associate subscriptions.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a customer
      {:ok, customer} = LatticeStripe.Customer.create(client, %{
        "email" => "user@example.com",
        "name" => "Jane Doe",
        "metadata" => %{"user_id" => "usr_123"}
      })

      # Retrieve a customer
      {:ok, customer} = LatticeStripe.Customer.retrieve(client, customer.id)

      # List customers with filters
      {:ok, resp} = LatticeStripe.Customer.list(client, %{"limit" => "10"})
      customers = resp.data.data  # [%Customer{}, ...]

      # Search customers
      {:ok, resp} = LatticeStripe.Customer.search(client, "email:'user@example.com'")

      # Stream all customers lazily (auto-pagination)
      client
      |> LatticeStripe.Customer.stream!()
      |> Stream.take(100)
      |> Enum.each(&process_customer/1)

  ## PII and Inspect

  The `Inspect` implementation hides personally-identifiable information
  (email, name, phone, description, address, shipping). Only `id`, `object`,
  `livemode`, and `deleted` are shown in inspect output.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe Customer object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object address balance business_name cash_balance created currency
    customer_account default_source delinquent description discount email
    individual_name invoice_credit_balance invoice_prefix invoice_settings
    livemode metadata name next_invoice_sequence phone preferred_locales
    shipping sources subscriptions deleted
  ]

  defstruct [
    :id,
    :address,
    :balance,
    :business_name,
    :cash_balance,
    :created,
    :currency,
    :customer_account,
    :default_source,
    :delinquent,
    :description,
    :discount,
    :email,
    :individual_name,
    :invoice_credit_balance,
    :invoice_prefix,
    :invoice_settings,
    :livemode,
    :metadata,
    :name,
    :next_invoice_sequence,
    :phone,
    :preferred_locales,
    :shipping,
    :sources,
    :subscriptions,
    object: "customer",
    deleted: false,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          address: map() | nil,
          balance: integer() | nil,
          business_name: String.t() | nil,
          cash_balance: map() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer_account: map() | nil,
          default_source: String.t() | nil,
          delinquent: boolean() | nil,
          description: String.t() | nil,
          discount: map() | nil,
          email: String.t() | nil,
          individual_name: String.t() | nil,
          invoice_credit_balance: map() | nil,
          invoice_prefix: String.t() | nil,
          invoice_settings: map() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          name: String.t() | nil,
          next_invoice_sequence: integer() | nil,
          phone: String.t() | nil,
          preferred_locales: [String.t()] | nil,
          shipping: map() | nil,
          sources: map() | nil,
          subscriptions: map() | nil,
          deleted: boolean(),
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Customer.

  Sends `POST /v1/customers` with the given params and returns `{:ok, %Customer{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of customer attributes (e.g., `%{"email" => "...", "name" => "..."}`)
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Customer{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, customer} = LatticeStripe.Customer.create(client, %{
        "email" => "user@example.com",
        "name" => "Jane Doe"
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/customers", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a Customer by ID.

  Sends `GET /v1/customers/:id` and returns `{:ok, %Customer{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The customer ID string (e.g., `"cus_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Customer{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/customers/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a Customer by ID.

  Sends `POST /v1/customers/:id` with the given params and returns `{:ok, %Customer{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The customer ID string
  - `params` - Map of fields to update
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Customer{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/customers/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Deletes a Customer by ID.

  Sends `DELETE /v1/customers/:id` and returns `{:ok, %Customer{deleted: true}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The customer ID string
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Customer{deleted: true}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :delete, path: "/v1/customers/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Customers with optional filters.

  Sends `GET /v1/customers` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%Customer{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "10", "email" => "user@example.com"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Customer{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.Customer.list(client, %{"limit" => "20"})
      Enum.each(resp.data.data, &IO.inspect/1)
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Searches Customers using Stripe's search query language.

  Sends `GET /v1/customers/search` with the query string and returns typed results.
  Note: search results have eventual consistency — newly created customers may not
  appear immediately.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string (e.g., `"email:'user@example.com'"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Customer{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.Customer.search(client, "email:'billing@company.com'")
  """
  @spec search(Client.t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    %Request{
      method: :get,
      path: "/v1/customers/search",
      params: %{"query" => query},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Customers matching the given params (auto-pagination).

  Emits individual `%Customer{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Customer{}` structs.

  ## Example

      client
      |> LatticeStripe.Customer.stream!()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/customers", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Customers matching the search query (auto-pagination).

  Emits individual `%Customer{}` structs, fetching additional search pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Customer{}` structs.
  """
  @spec search_stream!(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/customers/search",
      params: %{"query" => query},
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc """
  Like `create/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `update/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `delete/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec delete!(Client.t(), String.t(), keyword()) :: t()
  def delete!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    delete(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `search/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec search!(Client.t(), String.t(), keyword()) :: Response.t()
  def search!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    search(client, query, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Customer{}` struct.

  Maps all known Stripe Customer fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost.

  ## Example

      customer = LatticeStripe.Customer.from_map(%{
        "id" => "cus_123",
        "email" => "user@example.com",
        "object" => "customer"
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "customer",
      address: map["address"],
      balance: map["balance"],
      business_name: map["business_name"],
      cash_balance: map["cash_balance"],
      created: map["created"],
      currency: map["currency"],
      customer_account: map["customer_account"],
      default_source: map["default_source"],
      delinquent: map["delinquent"],
      description: map["description"],
      discount: map["discount"],
      email: map["email"],
      individual_name: map["individual_name"],
      invoice_credit_balance: map["invoice_credit_balance"],
      invoice_prefix: map["invoice_prefix"],
      invoice_settings: map["invoice_settings"],
      livemode: map["livemode"],
      metadata: map["metadata"],
      name: map["name"],
      next_invoice_sequence: map["next_invoice_sequence"],
      phone: map["phone"],
      preferred_locales: map["preferred_locales"],
      shipping: map["shipping"],
      sources: map["sources"],
      subscriptions: map["subscriptions"],
      deleted: map["deleted"] || false,
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.Customer do
  import Inspect.Algebra

  def inspect(customer, opts) do
    # Show only non-PII structural fields. Hide: email, name, phone,
    # description, address, shipping — all contain personally-identifiable data.
    fields = [
      id: customer.id,
      object: customer.object,
      livemode: customer.livemode,
      deleted: customer.deleted
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Customer<" | pairs] ++ [">"])
  end
end
