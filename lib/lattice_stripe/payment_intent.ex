defmodule LatticeStripe.PaymentIntent do
  @moduledoc """
  Operations on Stripe PaymentIntent objects.

  A PaymentIntent guides you through the process of collecting a payment from
  your customer. It tracks the lifecycle of a payment — from initial creation
  through confirmation, capture, and completion.

  PaymentIntents are the recommended way to accept payments for most Stripe
  integrations. They handle complex flows like 3D Secure authentication,
  SCA requirements, and multi-step payment methods.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a PaymentIntent (amount in smallest currency unit, e.g., cents)
      {:ok, pi} = LatticeStripe.PaymentIntent.create(client, %{
        "amount" => 2000,
        "currency" => "usd",
        "metadata" => %{"order_id" => "ord_123"}
      })

      # Confirm a PaymentIntent with a payment method
      {:ok, pi} = LatticeStripe.PaymentIntent.confirm(client, pi.id, %{
        "payment_method" => "pm_card_visa"
      })

      # Capture a manually-captured PaymentIntent
      {:ok, pi} = LatticeStripe.PaymentIntent.capture(client, pi.id)

      # Cancel a PaymentIntent
      {:ok, pi} = LatticeStripe.PaymentIntent.cancel(client, pi.id, %{
        "cancellation_reason" => "abandoned"
      })

      # List PaymentIntents with filters
      {:ok, resp} = LatticeStripe.PaymentIntent.list(client, %{"limit" => "10"})
      payment_intents = resp.data.data  # [%PaymentIntent{}, ...]

      # Stream all PaymentIntents lazily (auto-pagination)
      client
      |> LatticeStripe.PaymentIntent.stream!()
      |> Stream.take(100)
      |> Enum.each(&process_payment/1)

  ## Security and Inspect

  The `Inspect` implementation hides `client_secret` — this value must never
  appear in logs. Only `id`, `object`, `amount`, `currency`, and `status` are
  shown in inspect output.

  Note: PaymentIntents cannot be deleted. There is no `delete/3` function.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe PaymentIntent object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount amount_capturable amount_details amount_received
    application application_fee_amount automatic_payment_methods canceled_at
    cancellation_reason capture_method client_secret confirmation_method
    created currency customer customer_account description
    excluded_payment_method_types hooks last_payment_error latest_charge
    livemode metadata next_action on_behalf_of payment_method
    payment_method_configuration_details payment_method_options
    payment_method_types processing receipt_email review setup_future_usage
    shipping source statement_descriptor statement_descriptor_suffix status
    transfer_data transfer_group
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :amount,
    :amount_capturable,
    :amount_details,
    :amount_received,
    :application,
    :application_fee_amount,
    :automatic_payment_methods,
    :canceled_at,
    :cancellation_reason,
    :capture_method,
    :client_secret,
    :confirmation_method,
    :created,
    :currency,
    :customer,
    :customer_account,
    :description,
    :excluded_payment_method_types,
    :hooks,
    :last_payment_error,
    :latest_charge,
    :livemode,
    :metadata,
    :next_action,
    :on_behalf_of,
    :payment_method,
    :payment_method_configuration_details,
    :payment_method_options,
    :payment_method_types,
    :processing,
    :receipt_email,
    :review,
    :setup_future_usage,
    :shipping,
    :source,
    :statement_descriptor,
    :statement_descriptor_suffix,
    :status,
    :transfer_data,
    :transfer_group,
    object: "payment_intent",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          amount_capturable: integer() | nil,
          amount_details: map() | nil,
          amount_received: integer() | nil,
          application: String.t() | nil,
          application_fee_amount: integer() | nil,
          automatic_payment_methods: map() | nil,
          canceled_at: integer() | nil,
          cancellation_reason: String.t() | nil,
          capture_method: String.t() | nil,
          client_secret: String.t() | nil,
          confirmation_method: String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer: String.t() | nil,
          customer_account: map() | nil,
          description: String.t() | nil,
          excluded_payment_method_types: [String.t()] | nil,
          hooks: map() | nil,
          last_payment_error: map() | nil,
          latest_charge: String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          next_action: map() | nil,
          on_behalf_of: String.t() | nil,
          payment_method: String.t() | nil,
          payment_method_configuration_details: map() | nil,
          payment_method_options: map() | nil,
          payment_method_types: [String.t()] | nil,
          processing: map() | nil,
          receipt_email: String.t() | nil,
          review: String.t() | nil,
          setup_future_usage: String.t() | nil,
          shipping: map() | nil,
          source: String.t() | nil,
          statement_descriptor: String.t() | nil,
          statement_descriptor_suffix: String.t() | nil,
          status: String.t() | nil,
          transfer_data: map() | nil,
          transfer_group: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new PaymentIntent.

  Sends `POST /v1/payment_intents` with the given params and returns
  `{:ok, %PaymentIntent{}}`. The `amount` and `currency` params are required
  by Stripe.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of PaymentIntent attributes (e.g., `%{"amount" => 2000, "currency" => "usd"}`)
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %PaymentIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pi} = LatticeStripe.PaymentIntent.create(client, %{
        "amount" => 2000,
        "currency" => "usd"
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/payment_intents", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a PaymentIntent by ID.

  Sends `GET /v1/payment_intents/:id` and returns `{:ok, %PaymentIntent{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentIntent ID string (e.g., `"pi_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/payment_intents/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a PaymentIntent by ID.

  Sends `POST /v1/payment_intents/:id` with the given params and returns
  `{:ok, %PaymentIntent{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentIntent ID string
  - `params` - Map of fields to update
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/payment_intents/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Confirms a PaymentIntent, attempting to collect payment.

  Sends `POST /v1/payment_intents/:id/confirm` with optional params and returns
  `{:ok, %PaymentIntent{}}`. After confirmation, the PaymentIntent will have a
  `status` indicating whether payment succeeded or requires additional steps.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentIntent ID string
  - `params` - Optional confirmation params (e.g., `%{"payment_method" => "pm_..."}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pi} = LatticeStripe.PaymentIntent.confirm(client, pi.id, %{
        "payment_method" => "pm_card_visa"
      })
  """
  @spec confirm(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def confirm(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/payment_intents/#{id}/confirm", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Captures an authorized PaymentIntent.

  Sends `POST /v1/payment_intents/:id/capture` with optional params and returns
  `{:ok, %PaymentIntent{}}`. Only applicable when `capture_method` is `"manual"`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentIntent ID string
  - `params` - Optional capture params (e.g., `%{"amount_to_capture" => 1500}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pi} = LatticeStripe.PaymentIntent.capture(client, pi.id)
  """
  @spec capture(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def capture(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/payment_intents/#{id}/capture", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Cancels a PaymentIntent.

  Sends `POST /v1/payment_intents/:id/cancel` with optional params and returns
  `{:ok, %PaymentIntent{status: "canceled"}}`. A PaymentIntent can be canceled
  when it is in `requires_payment_method`, `requires_capture`,
  `requires_confirmation`, or `requires_action` status.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentIntent ID string
  - `params` - Optional cancel params (e.g., `%{"cancellation_reason" => "abandoned"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentIntent{status: "canceled"}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pi} = LatticeStripe.PaymentIntent.cancel(client, pi.id, %{
        "cancellation_reason" => "abandoned"
      })
  """
  @spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/payment_intents/#{id}/cancel", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists PaymentIntents with optional filters.

  Sends `GET /v1/payment_intents` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%PaymentIntent{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "10", "customer" => "cus_123"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%PaymentIntent{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.PaymentIntent.list(client, %{"limit" => "20"})
      Enum.each(resp.data.data, &IO.inspect/1)
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/payment_intents", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all PaymentIntents matching the given params (auto-pagination).

  Emits individual `%PaymentIntent{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%PaymentIntent{}` structs.

  ## Example

      client
      |> LatticeStripe.PaymentIntent.stream!()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/payment_intents", params: params, opts: opts}
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
  Like `confirm/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec confirm!(Client.t(), String.t(), map(), keyword()) :: t()
  def confirm!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    confirm(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `capture/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec capture!(Client.t(), String.t(), map(), keyword()) :: t()
  def capture!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    capture(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `cancel/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec cancel!(Client.t(), String.t(), map(), keyword()) :: t()
  def cancel!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    cancel(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Searches PaymentIntents using Stripe's search query language.

  Sends `GET /v1/payment_intents/search` with the query string and returns typed results.
  Note: search results have eventual consistency — newly created PaymentIntents may not
  appear immediately.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string (e.g., `"status:'succeeded' AND currency:'usd'"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%PaymentIntent{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.PaymentIntent.search(client, "status:'succeeded'")
  """
  @spec search(Client.t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    %Request{
      method: :get,
      path: "/v1/payment_intents/search",
      params: %{"query" => query},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Like `search/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec search!(Client.t(), String.t(), keyword()) :: Response.t()
  def search!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    search(client, query, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of all PaymentIntents matching the search query (auto-pagination).

  Emits individual `%PaymentIntent{}` structs, fetching additional search pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%PaymentIntent{}` structs.
  """
  @spec search_stream!(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/payment_intents/search",
      params: %{"query" => query},
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%PaymentIntent{}` struct.

  Maps all known Stripe PaymentIntent fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  ## Example

      pi = LatticeStripe.PaymentIntent.from_map(%{
        "id" => "pi_123",
        "amount" => 2000,
        "currency" => "usd",
        "status" => "requires_payment_method"
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "payment_intent",
      amount: map["amount"],
      amount_capturable: map["amount_capturable"],
      amount_details: map["amount_details"],
      amount_received: map["amount_received"],
      application: map["application"],
      application_fee_amount: map["application_fee_amount"],
      automatic_payment_methods: map["automatic_payment_methods"],
      canceled_at: map["canceled_at"],
      cancellation_reason: map["cancellation_reason"],
      capture_method: map["capture_method"],
      client_secret: map["client_secret"],
      confirmation_method: map["confirmation_method"],
      created: map["created"],
      currency: map["currency"],
      customer: map["customer"],
      customer_account: map["customer_account"],
      description: map["description"],
      excluded_payment_method_types: map["excluded_payment_method_types"],
      hooks: map["hooks"],
      last_payment_error: map["last_payment_error"],
      latest_charge: map["latest_charge"],
      livemode: map["livemode"],
      metadata: map["metadata"],
      next_action: map["next_action"],
      on_behalf_of: map["on_behalf_of"],
      payment_method: map["payment_method"],
      payment_method_configuration_details: map["payment_method_configuration_details"],
      payment_method_options: map["payment_method_options"],
      payment_method_types: map["payment_method_types"],
      processing: map["processing"],
      receipt_email: map["receipt_email"],
      review: map["review"],
      setup_future_usage: map["setup_future_usage"],
      shipping: map["shipping"],
      source: map["source"],
      statement_descriptor: map["statement_descriptor"],
      statement_descriptor_suffix: map["statement_descriptor_suffix"],
      status: map["status"],
      transfer_data: map["transfer_data"],
      transfer_group: map["transfer_group"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.PaymentIntent do
  import Inspect.Algebra

  def inspect(pi, opts) do
    # Show only structural/non-sensitive fields.
    # CRITICAL: client_secret MUST be hidden — it grants ability to complete payment.
    # Also hide: receipt_email (PII), shipping (PII).
    fields = [
      id: pi.id,
      object: pi.object,
      amount: pi.amount,
      currency: pi.currency,
      status: pi.status
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.PaymentIntent<" | pairs] ++ [">"])
  end
end
