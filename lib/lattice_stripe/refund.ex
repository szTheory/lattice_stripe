defmodule LatticeStripe.Refund do
  @moduledoc """
  Operations on Stripe Refund objects.

  A Refund represents a return of a charge to a customer's payment method.
  You can create a refund for a PaymentIntent or Charge.

  ## Key behaviors

  - The `payment_intent` parameter is required when creating a refund — an `ArgumentError`
    is raised immediately (pre-network) if it is missing.
  - Refunds cannot be deleted. Use `cancel/4` to cancel a pending refund.
  - Updates are limited to the `metadata` field only (Stripe API constraint).

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a full refund for a PaymentIntent
      {:ok, refund} = LatticeStripe.Refund.create(client, %{
        "payment_intent" => "pi_...",
        "reason" => "requested_by_customer"
      })

      # Create a partial refund
      {:ok, refund} = LatticeStripe.Refund.create(client, %{
        "payment_intent" => "pi_...",
        "amount" => 500
      })

      # Retrieve a refund
      {:ok, refund} = LatticeStripe.Refund.retrieve(client, "re_...")

      # Update a refund's metadata
      {:ok, refund} = LatticeStripe.Refund.update(client, "re_...", %{
        "metadata" => %{"order_id" => "ord_123"}
      })

      # Cancel a pending refund
      {:ok, refund} = LatticeStripe.Refund.cancel(client, "re_...")

      # List refunds with optional filters
      {:ok, resp} = LatticeStripe.Refund.list(client, %{"payment_intent" => "pi_..."})
      refunds = resp.data.data  # [%Refund{}, ...]

      # Stream all refunds lazily (auto-pagination)
      client
      |> LatticeStripe.Refund.stream!()
      |> Stream.take(100)
      |> Enum.each(&process_refund/1)

  ## Security and Inspect

  The `Inspect` implementation shows only `id`, `object`, `amount`, `currency`, and `status`.
  Payment intent IDs, charge IDs, and other operational details are hidden.

  ## Stripe API Reference

  https://stripe.com/docs/api/refunds
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe Refund object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount balance_transaction charge created currency destination_details
    failure_balance_transaction failure_reason instructions_email metadata
    next_action payment_intent reason receipt_number source_transfer_reversal
    status transfer_reversal
  ]

  defstruct [
    :id,
    :amount,
    :balance_transaction,
    :charge,
    :created,
    :currency,
    :destination_details,
    :failure_balance_transaction,
    :failure_reason,
    :instructions_email,
    :metadata,
    :next_action,
    :payment_intent,
    :reason,
    :receipt_number,
    :source_transfer_reversal,
    :status,
    :transfer_reversal,
    object: "refund",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          balance_transaction: String.t() | nil,
          charge: String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          destination_details: map() | nil,
          failure_balance_transaction: String.t() | nil,
          failure_reason: String.t() | nil,
          instructions_email: String.t() | nil,
          metadata: map() | nil,
          next_action: map() | nil,
          payment_intent: String.t() | nil,
          reason: String.t() | nil,
          receipt_number: String.t() | nil,
          source_transfer_reversal: String.t() | nil,
          status: String.t() | nil,
          transfer_reversal: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Refund for a PaymentIntent.

  Sends `POST /v1/refunds` with the given params and returns `{:ok, %Refund{}}`.
  The `payment_intent` param is required — an `ArgumentError` is raised immediately
  (before any network call) if it is missing.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of Refund attributes. **Required:** `"payment_intent"`.
    Optional: `"amount"` (omit for full refund), `"reason"`, `"metadata"`.
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Refund{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, refund} = LatticeStripe.Refund.create(client, %{
        "payment_intent" => "pi_3N...",
        "reason" => "requested_by_customer"
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    Resource.require_param!(
      params,
      "payment_intent",
      ~s|Refund.create/3 requires a "payment_intent" key in params. Example: %{"payment_intent" => "pi_..."}|
    )

    %Request{method: :post, path: "/v1/refunds", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a Refund by ID.

  Sends `GET /v1/refunds/:id` and returns `{:ok, %Refund{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The Refund ID string (e.g., `"re_..."`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Refund{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/refunds/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a Refund by ID.

  Sends `POST /v1/refunds/:id` with the given params and returns `{:ok, %Refund{}}`.
  Note: the Stripe API only supports updating the `metadata` field on a Refund.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The Refund ID string
  - `params` - Map of fields to update (only `"metadata"` is accepted by Stripe)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Refund{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/refunds/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Cancels a pending Refund.

  Sends `POST /v1/refunds/:id/cancel` and returns `{:ok, %Refund{status: "canceled"}}`.
  Only refunds with `status: "pending"` can be canceled.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The Refund ID string
  - `params` - Optional cancel params (typically empty `%{}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Refund{status: "canceled"}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, refund} = LatticeStripe.Refund.cancel(client, "re_...")
  """
  @spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/refunds/#{id}/cancel", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Refunds with optional filters.

  Sends `GET /v1/refunds` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%Refund{}` items. All params are optional.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"payment_intent" => "pi_...", "limit" => "20"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Refund{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.Refund.list(client, %{"payment_intent" => "pi_..."})
      Enum.each(resp.data.data, &IO.inspect/1)
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/refunds", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Refunds matching the given params (auto-pagination).

  Emits individual `%Refund{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"payment_intent" => "pi_...", "limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Refund{}` structs.

  ## Example

      client
      |> LatticeStripe.Refund.stream!()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/refunds", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc """
  Like `create/3` but raises `LatticeStripe.Error` on failure.
  Also raises `ArgumentError` when `payment_intent` param is missing.
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

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Refund{}` struct.

  Maps all known Stripe Refund fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  ## Example

      refund = LatticeStripe.Refund.from_map(%{
        "id" => "re_...",
        "amount" => 2000,
        "currency" => "usd",
        "status" => "succeeded"
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "refund",
      amount: map["amount"],
      balance_transaction: map["balance_transaction"],
      charge: map["charge"],
      created: map["created"],
      currency: map["currency"],
      destination_details: map["destination_details"],
      failure_balance_transaction: map["failure_balance_transaction"],
      failure_reason: map["failure_reason"],
      instructions_email: map["instructions_email"],
      metadata: map["metadata"],
      next_action: map["next_action"],
      payment_intent: map["payment_intent"],
      reason: map["reason"],
      receipt_number: map["receipt_number"],
      source_transfer_reversal: map["source_transfer_reversal"],
      status: map["status"],
      transfer_reversal: map["transfer_reversal"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.Refund do
  import Inspect.Algebra

  def inspect(refund, opts) do
    # Show only structural/non-sensitive fields.
    # Hide: payment_intent, charge, reason, metadata, and other operational details.
    fields = [
      id: refund.id,
      object: refund.object,
      amount: refund.amount,
      currency: refund.currency,
      status: refund.status
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Refund<" | pairs] ++ [">"])
  end
end
