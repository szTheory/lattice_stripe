defmodule LatticeStripe.Transfer do
  @moduledoc """
  Operations on Stripe Transfer objects — the Connect separate-charge-and-transfer primitive.

  A Transfer moves funds from your platform balance to a connected account.
  See the [Stripe Transfer API](https://docs.stripe.com/api/transfers).

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a transfer
      {:ok, transfer} = LatticeStripe.Transfer.create(client, %{
        "amount" => 1000,
        "currency" => "usd",
        "destination" => "acct_1Nv0FGQ9RKHgCVdK"
      })

      # Retrieve
      {:ok, transfer} = LatticeStripe.Transfer.retrieve(client, "tr_...")

      # Update metadata
      {:ok, transfer} = LatticeStripe.Transfer.update(client, "tr_...", %{
        "metadata" => %{"internal_id" => "xfer_42"}
      })

      # List / stream
      {:ok, resp} = LatticeStripe.Transfer.list(client, %{"destination" => "acct_..."})

      client
      |> LatticeStripe.Transfer.stream!()
      |> Enum.take(500)

  ## Reversing a transfer: use `LatticeStripe.TransferReversal`

  This module deliberately does **not** define `reverse/3` or `reverse/4`.
  Phase 18 decision D-02 locks TransferReversal as a standalone top-level
  module addressed by `(transfer_id, reversal_id)`. To reverse a transfer:

      {:ok, reversal} = LatticeStripe.TransferReversal.create(client, "tr_...", %{})

  Mirrors stripe-java's own top-level `TransferReversal` class and the Phase 17
  `AccountLink` / `LoginLink` precedent.

  ## Embedded reversals sublist decoding

  The Stripe API returns an embedded (non-paginated) `reversals` sublist on
  every Transfer:

      {
        "reversals": {
          "object": "list",
          "data": [ {...}, {...} ],
          "has_more": false,
          "url": "/v1/transfers/tr_.../reversals",
          "total_count": 2
        }
      }

  `Transfer.from_map/1` decodes this specially:

  - `transfer.reversals` becomes `[%LatticeStripe.TransferReversal{}, ...]`
    (a plain Elixir list, **not** a `%LatticeStripe.List{}` struct)
  - The wrapper metadata (`has_more`, `url`, `total_count`) is preserved
    under `transfer.extra["reversals_meta"]` so no data is lost

  ## Idempotency for double-execution safety

  `Transfer.create/3` is a money-moving operation. `LatticeStripe.Client.request/2`
  already auto-generates idempotency keys for mutating requests and reuses them
  across retries (Phase 2 RTRY-03). For at-least-once safety in your own failure
  recovery loops, pass an explicit key:

      {:ok, transfer} =
        LatticeStripe.Transfer.create(client, params, idempotency_key: "my-xfer-42")

  ## No client-side validation

  Per Phase 15 D5 / Phase 18 D-04, `Transfer.create/3` does **not** pre-validate
  `amount`, `currency`, or `destination` beyond the standard CRUDL shape. Stripe's
  own 400 errors surface as `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`.

  ## Stripe API Reference

  See the [Stripe Transfer API](https://docs.stripe.com/api/transfers).
  """

  alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response, TransferReversal}

  # Known top-level fields from the Stripe Transfer object.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount amount_reversed balance_transaction created currency
    description destination destination_payment livemode metadata reversals
    reversed source_transaction source_type transfer_group
  ]

  defstruct [
    :id,
    :amount,
    :amount_reversed,
    :balance_transaction,
    :created,
    :currency,
    :description,
    :destination,
    :destination_payment,
    :livemode,
    :metadata,
    :reversed,
    :source_transaction,
    :source_type,
    :transfer_group,
    object: "transfer",
    reversals: [],
    extra: %{}
  ]

  @typedoc """
  A Stripe Transfer object.

  `reversals` is a plain list of `%LatticeStripe.TransferReversal{}` structs
  (NOT a `%LatticeStripe.List{}`). The original sublist wrapper metadata
  (`has_more`, `url`, `total_count`) is stashed under
  `extra["reversals_meta"]` by `from_map/1`.

  See the [Stripe Transfer API](https://docs.stripe.com/api/transfers/object).
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          amount_reversed: integer() | nil,
          balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          destination: LatticeStripe.Account.t() | String.t() | nil,
          destination_payment: LatticeStripe.Charge.t() | String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          reversals: [TransferReversal.t()],
          reversed: boolean() | nil,
          source_transaction: LatticeStripe.Charge.t() | String.t() | nil,
          source_type: String.t() | nil,
          transfer_group: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUDL
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Transfer.

  Sends `POST /v1/transfers`. No client-side validation of params (Stripe's 400
  surfaces as `{:error, %Error{}}`).
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) when is_map(params) do
    %Request{method: :post, path: "/v1/transfers", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    client |> create(params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a Transfer by ID.

  Raises `ArgumentError` (pre-network) if `id` is `nil` or empty.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(client, id, opts \\ [])

  def retrieve(%Client{}, id, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|Transfer.retrieve/3 requires a non-empty transfer id|
  end

  def retrieve(%Client{} = client, id, opts) when is_binary(id) do
    %Request{method: :get, path: "/v1/transfers/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(client, id, opts \\ []) do
    client |> retrieve(id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Updates a Transfer (typically only `metadata` / `description`).

  Raises `ArgumentError` (pre-network) if `id` is `nil` or empty.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(client, id, params, opts \\ [])

  def update(%Client{}, id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|Transfer.update/4 requires a non-empty transfer id|
  end

  def update(%Client{} = client, id, params, opts) when is_binary(id) and is_map(params) do
    %Request{method: :post, path: "/v1/transfers/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(client, id, params, opts \\ []) do
    client |> update(id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Lists Transfers with optional filters."
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/transfers", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    client |> list(params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Returns a lazy stream of all Transfers (auto-pagination)."
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/transfers", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Transfer{}` struct.

  Specially decodes the embedded `reversals` sublist into
  `[%TransferReversal{}]` (a plain list, not a `%List{}`), and preserves the
  wrapper metadata under `extra["reversals_meta"]`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    # Decode the embedded `reversals` sublist. F-001 requires that nothing
    # is silently lost: if Stripe ever returns an unexpected shape (e.g.
    # `false` or a bare string — API drift), preserve the raw value under
    # `extra["reversals_raw"]` rather than dropping it.
    {reversal_structs, reversals_meta, reversals_raw} =
      case map["reversals"] do
        %{"data" => data} = m when is_list(data) ->
          {Enum.map(data, &TransferReversal.from_map/1), Map.drop(m, ["data"]), nil}

        %{} = m ->
          {[], Map.drop(m, ["data"]), nil}

        nil ->
          {[], %{}, nil}

        other ->
          {[], %{}, other}
      end

    base_extra = Map.drop(map, @known_fields)

    extra =
      base_extra
      |> then(fn e ->
        if map_size(reversals_meta) > 0, do: Map.put(e, "reversals_meta", reversals_meta), else: e
      end)
      |> then(fn e ->
        if is_nil(reversals_raw), do: e, else: Map.put(e, "reversals_raw", reversals_raw)
      end)

    %__MODULE__{
      id: map["id"],
      object: map["object"] || "transfer",
      amount: map["amount"],
      amount_reversed: map["amount_reversed"],
      balance_transaction:
        (if is_map(map["balance_transaction"]),
           do: ObjectTypes.maybe_deserialize(map["balance_transaction"]),
           else: map["balance_transaction"]),
      created: map["created"],
      currency: map["currency"],
      description: map["description"],
      destination:
        (if is_map(map["destination"]),
           do: ObjectTypes.maybe_deserialize(map["destination"]),
           else: map["destination"]),
      destination_payment:
        (if is_map(map["destination_payment"]),
           do: ObjectTypes.maybe_deserialize(map["destination_payment"]),
           else: map["destination_payment"]),
      livemode: map["livemode"],
      metadata: map["metadata"],
      reversals: reversal_structs,
      reversed: map["reversed"],
      source_transaction:
        (if is_map(map["source_transaction"]),
           do: ObjectTypes.maybe_deserialize(map["source_transaction"]),
           else: map["source_transaction"]),
      source_type: map["source_type"],
      transfer_group: map["transfer_group"],
      extra: extra
    }
  end
end
