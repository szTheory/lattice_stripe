defmodule LatticeStripe.BalanceTransaction do
  @moduledoc """
  Operations on Stripe BalanceTransaction objects — the server-side ledger
  entries that back every Charge, Refund, Transfer, Payout, and fee on
  a Stripe account.

  BalanceTransactions are **created by Stripe**. There is no client-side
  `create`, `update`, or `delete` — the library exposes only `retrieve/3`,
  `list/3`, and `stream!/3`. Use the filter params on `list/3` to walk
  reconciliation reports:

      # Every ledger entry that landed in a given payout
      {:ok, resp} =
        LatticeStripe.BalanceTransaction.list(client, %{"payout" => "po_..."})

      # Stream the whole account ledger
      client
      |> LatticeStripe.BalanceTransaction.stream!(%{"type" => "charge"})
      |> Enum.take(1_000)

  Each BalanceTransaction carries a list of `fee_details` — individual
  platform, Stripe, and tax line items — so reconciliation code can
  pattern-match on them without extra calls:

      application_fees =
        Enum.filter(bt.fee_details, &(&1.type == "application_fee"))

  The `source` field is **polymorphic** (Stripe returns either a string ID
  or an expanded object map, spanning 16+ object types). Per D-05 rule 5 it
  stays as the raw `binary | map()` — users who want a typed source compose
  `LatticeStripe.Charge.from_map/1` (or the relevant resource) themselves.

  ## Stripe API Reference

  https://docs.stripe.com/api/balance_transactions
  """

  alias LatticeStripe.BalanceTransaction.FeeDetail
  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object amount available_on created currency description exchange_rate
    fee fee_details net reporting_category source status type
  ]

  defstruct [
    :id,
    :amount,
    :available_on,
    :created,
    :currency,
    :description,
    :exchange_rate,
    :fee,
    :fee_details,
    :net,
    :reporting_category,
    :source,
    :status,
    :type,
    object: "balance_transaction",
    extra: %{}
  ]

  @typedoc """
  A Stripe BalanceTransaction object.

  See the [Stripe BalanceTransaction API](https://docs.stripe.com/api/balance_transactions/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          available_on: integer() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          exchange_rate: number() | nil,
          fee: integer() | nil,
          fee_details: [FeeDetail.t()] | nil,
          net: integer() | nil,
          reporting_category: String.t() | nil,
          source: String.t() | map() | nil,
          status: String.t() | nil,
          type: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a BalanceTransaction by ID.

  Sends `GET /v1/balance_transactions/:id` and returns
  `{:ok, %BalanceTransaction{}}`. Raises `ArgumentError` (pre-network) if
  `id` is empty.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(client, id, opts \\ [])

  def retrieve(%Client{}, id, _opts) when id in [nil, ""] do
    raise ArgumentError,
          "BalanceTransaction.retrieve/3 requires a non-empty balance_transaction id"
  end

  def retrieve(%Client{} = client, id, opts) when is_binary(id) do
    %Request{method: :get, path: "/v1/balance_transactions/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(client, id, opts \\ [])

  def retrieve!(%Client{}, id, _opts) when id in [nil, ""] do
    raise ArgumentError,
          "BalanceTransaction.retrieve!/3 requires a non-empty balance_transaction id"
  end

  def retrieve!(%Client{} = client, id, opts) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists BalanceTransactions with optional filters.

  Supported Stripe filters (all optional, pass-through):
  `payout`, `source`, `type`, `currency`, `created`.

  Returns `{:ok, %Response{data: %List{data: [%BalanceTransaction{}, ...]}}}`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/balance_transactions", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of all BalanceTransactions matching the given filters
  (auto-pagination). Raises on any page failure.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/balance_transactions", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%BalanceTransaction{}` struct.

  - `fee_details` is decoded into a list of `%BalanceTransaction.FeeDetail{}`.
  - `source` is kept as the raw `binary | map()` (polymorphic per D-05 rule 5).
  - Unknown top-level fields survive in `:extra`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    fee_details =
      case map["fee_details"] do
        list when is_list(list) -> Enum.map(list, &FeeDetail.cast/1)
        _ -> nil
      end

    %__MODULE__{
      id: map["id"],
      object: map["object"] || "balance_transaction",
      amount: map["amount"],
      available_on: map["available_on"],
      created: map["created"],
      currency: map["currency"],
      description: map["description"],
      exchange_rate: map["exchange_rate"],
      fee: map["fee"],
      fee_details: fee_details,
      net: map["net"],
      reporting_category: map["reporting_category"],
      source: map["source"],
      status: map["status"],
      type: map["type"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
