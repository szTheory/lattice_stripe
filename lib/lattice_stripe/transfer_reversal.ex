defmodule LatticeStripe.TransferReversal do
  @moduledoc """
  Operations on Stripe Transfer Reversal objects — standalone top-level module.

  A Transfer Reversal returns some or all of a previously created Transfer
  from the destination connected account back to the platform balance. See
  the [Stripe Transfer Reversal API](https://docs.stripe.com/api/transfer_reversals).

  ## Design: standalone module, no `Transfer.reverse/4` delegator

  Phase 18 decision D-02 locks this as a top-level module addressed by
  `(transfer_id, reversal_id)`, mirroring `/v1/transfers/:transfer/reversals/:id`.
  `LatticeStripe.Transfer` deliberately does **not** expose a `reverse/4`
  delegator — users reach for `TransferReversal.create/4` directly. This
  mirrors the Phase 17 `AccountLink` / `LoginLink` precedent and stripe-java's
  own top-level `TransferReversal` class.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a full reversal (no amount = reverse the entire transfer)
      {:ok, reversal} = LatticeStripe.TransferReversal.create(client, "tr_...", %{})

      # Create a partial reversal
      {:ok, reversal} = LatticeStripe.TransferReversal.create(client, "tr_...", %{
        "amount" => 500,
        "description" => "Partial reversal — platform issue"
      })

      # Retrieve
      {:ok, reversal} = LatticeStripe.TransferReversal.retrieve(client, "tr_...", "trr_...")

      # Update metadata
      {:ok, reversal} = LatticeStripe.TransferReversal.update(client, "tr_...", "trr_...", %{
        "metadata" => %{"internal_id" => "rev_42"}
      })

      # List reversals for a transfer
      {:ok, resp} = LatticeStripe.TransferReversal.list(client, "tr_...")

      # Stream lazily (auto-pagination)
      client
      |> LatticeStripe.TransferReversal.stream!("tr_...")
      |> Enum.to_list()

  ## Pre-network param validation

  All public functions validate that `transfer_id` (and `reversal_id` where
  present) are non-empty binaries before any HTTP call. Passing `nil` or `""`
  raises `ArgumentError` immediately, so tests do not need mock setup to
  cover the missing-id path.

  ## Stripe API Reference

  See the [Stripe Transfer Reversal API](https://docs.stripe.com/api/transfer_reversals).
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe TransferReversal object.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount balance_transaction created currency
    destination_payment_refund metadata source_refund transfer
  ]

  defstruct [
    :id,
    :amount,
    :balance_transaction,
    :created,
    :currency,
    :destination_payment_refund,
    :metadata,
    :source_refund,
    :transfer,
    object: "transfer_reversal",
    extra: %{}
  ]

  @typedoc """
  A Stripe Transfer Reversal object.

  See the [Stripe Transfer Reversal API](https://docs.stripe.com/api/transfer_reversals/object)
  for field definitions. Unknown fields are preserved in `:extra` (F-001).
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          balance_transaction: String.t() | map() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          destination_payment_refund: String.t() | map() | nil,
          metadata: map() | nil,
          source_refund: String.t() | map() | nil,
          transfer: String.t() | map() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUDL
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new TransferReversal for the given transfer.

  Sends `POST /v1/transfers/:transfer_id/reversals` with the given params.

  Raises `ArgumentError` (pre-network) if `transfer_id` is `nil` or empty.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `transfer_id` - The Transfer ID (`"tr_..."`) to reverse
  - `params` - Optional params: `"amount"`, `"description"`, `"metadata"`,
    `"refund_application_fee"`, `"expand"`
  - `opts` - Per-request overrides
  """
  @spec create(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create(client, transfer_id, params \\ %{}, opts \\ [])

  def create(%Client{}, id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.create/4 requires a non-empty transfer id|
  end

  def create(%Client{} = client, transfer_id, params, opts) when is_binary(transfer_id) do
    %Request{
      method: :post,
      path: "/v1/transfers/#{transfer_id}/reversals",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/4` but raises on failure."
  @spec create!(Client.t(), String.t(), map(), keyword()) :: t()
  def create!(client, transfer_id, params \\ %{}, opts \\ []) do
    client |> create(transfer_id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a TransferReversal by transfer id and reversal id.

  Sends `GET /v1/transfers/:transfer_id/reversals/:reversal_id`.

  Raises `ArgumentError` (pre-network) if either id is `nil` or empty.
  """
  @spec retrieve(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def retrieve(client, transfer_id, reversal_id, opts \\ [])

  def retrieve(%Client{}, id, _reversal_id, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.retrieve/4 requires a non-empty transfer id|
  end

  def retrieve(%Client{}, _transfer_id, id, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.retrieve/4 requires a non-empty reversal id|
  end

  def retrieve(%Client{} = client, transfer_id, reversal_id, opts)
      when is_binary(transfer_id) and is_binary(reversal_id) do
    %Request{
      method: :get,
      path: "/v1/transfers/#{transfer_id}/reversals/#{reversal_id}",
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/4` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), String.t(), keyword()) :: t()
  def retrieve!(client, transfer_id, reversal_id, opts \\ []) do
    client |> retrieve(transfer_id, reversal_id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Updates a TransferReversal's metadata.

  Sends `POST /v1/transfers/:transfer_id/reversals/:reversal_id`.

  Raises `ArgumentError` (pre-network) if either id is `nil` or empty.
  """
  @spec update(Client.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def update(client, transfer_id, reversal_id, params, opts \\ [])

  def update(%Client{}, id, _reversal_id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.update/5 requires a non-empty transfer id|
  end

  def update(%Client{}, _transfer_id, id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.update/5 requires a non-empty reversal id|
  end

  def update(%Client{} = client, transfer_id, reversal_id, params, opts)
      when is_binary(transfer_id) and is_binary(reversal_id) do
    %Request{
      method: :post,
      path: "/v1/transfers/#{transfer_id}/reversals/#{reversal_id}",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/5` but raises on failure."
  @spec update!(Client.t(), String.t(), String.t(), map(), keyword()) :: t()
  def update!(client, transfer_id, reversal_id, params, opts \\ []) do
    client |> update(transfer_id, reversal_id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists TransferReversals for the given transfer.

  Sends `GET /v1/transfers/:transfer_id/reversals`.

  Raises `ArgumentError` (pre-network) if `transfer_id` is `nil` or empty.
  """
  @spec list(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list(client, transfer_id, params \\ %{}, opts \\ [])

  def list(%Client{}, id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.list/4 requires a non-empty transfer id|
  end

  def list(%Client{} = client, transfer_id, params, opts) when is_binary(transfer_id) do
    %Request{
      method: :get,
      path: "/v1/transfers/#{transfer_id}/reversals",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/4` but raises on failure."
  @spec list!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list!(client, transfer_id, params \\ %{}, opts \\ []) do
    client |> list(transfer_id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of all TransferReversals for the given transfer
  (auto-pagination).

  Raises `ArgumentError` (pre-network) if `transfer_id` is `nil` or empty.
  """
  @spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream!(client, transfer_id, params \\ %{}, opts \\ [])

  def stream!(%Client{}, id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.stream!/4 requires a non-empty transfer id|
  end

  def stream!(%Client{} = client, transfer_id, params, opts) when is_binary(transfer_id) do
    req = %Request{
      method: :get,
      path: "/v1/transfers/#{transfer_id}/reversals",
      params: params,
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%TransferReversal{}` struct.

  Maps all known Stripe Transfer Reversal fields explicitly. Any unrecognized
  fields are collected into `:extra` (F-001).

  `from_map(nil)` returns `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "transfer_reversal",
      amount: map["amount"],
      balance_transaction: map["balance_transaction"],
      created: map["created"],
      currency: map["currency"],
      destination_payment_refund: map["destination_payment_refund"],
      metadata: map["metadata"],
      source_refund: map["source_refund"],
      transfer: map["transfer"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
