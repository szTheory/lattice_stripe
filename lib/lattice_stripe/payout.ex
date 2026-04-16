defmodule LatticeStripe.Payout do
  @moduledoc """
  Operations on Stripe Payout objects.

  A Payout represents money moving from your Stripe balance to a connected
  bank account or debit card. Payouts are the outbound leg of money movement —
  inbound money arrives via `Charge` / `PaymentIntent`, and you (or Stripe's
  automatic schedule) trigger a `Payout` to settle the balance to a bank.

  ## Key behaviors

  - Full CRUDL: `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`.
  - `cancel/4` and `reverse/4` both use the canonical
    `(client, id, params \\\\ %{}, opts \\\\ [])` shape per D-03. Both endpoints
    accept at least `expand`, and `reverse` additionally accepts `metadata`.
  - The `trace_id` field decodes into a typed `%LatticeStripe.Payout.TraceId{}`
    — pattern-match on `payout.trace_id.status` to branch your reconciliation
    flow.
  - Unknown future fields from Stripe land in `:extra` (F-001).
  - `require_param!` validates the payout id pre-network on `retrieve`,
    `update`, `cancel`, and `reverse`.

  ## Expandable references

  The following fields are typed as `binary() | map() | nil` because Stripe
  returns an ID string by default and only inlines the expanded object when you
  pass `expand: [...]`:

  - `destination` — expand then cast via `LatticeStripe.BankAccount.cast/1` or
    `LatticeStripe.Card.cast/1` as appropriate.
  - `balance_transaction` and `failure_balance_transaction` — expand then cast
    via `LatticeStripe.BalanceTransaction.from_map/1`.

  Per D-05, these references stay polymorphic — the guide documents the
  "expand then cast via expected module" idiom.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Trigger a manual payout to the default external account
      {:ok, payout} = LatticeStripe.Payout.create(client, %{
        "amount" => 5000,
        "currency" => "usd"
      })

      # Retrieve and branch on trace_id availability
      {:ok, payout} = LatticeStripe.Payout.retrieve(client, "po_...")

      case payout.trace_id do
        %LatticeStripe.Payout.TraceId{status: "supported", value: trace} ->
          reconcile(trace)

        %LatticeStripe.Payout.TraceId{status: "pending"} ->
          # Stripe will populate trace_id asynchronously — listen for payout.updated
          :wait_for_webhook

        _ ->
          :skip
      end

      # Cancel a pending payout (no params needed)
      {:ok, _} = LatticeStripe.Payout.cancel(client, "po_...")

      # Cancel with expand for reconciliation
      {:ok, payout} =
        LatticeStripe.Payout.cancel(client, "po_...", %{
          "expand" => ["balance_transaction"]
        })

      # Reverse a completed payout with reconciliation metadata
      {:ok, reversed} =
        LatticeStripe.Payout.reverse(client, "po_...", %{
          "metadata" => %{"reason" => "customer_dispute"},
          "expand" => ["balance_transaction"]
        })

  ## Idempotency

  `create`, `cancel`, and `reverse` are money-moving operations. `Client.request/2`
  auto-generates an idempotency key for mutating requests and reuses it across
  retries. Pass `idempotency_key:` in `opts` to set your own stable key.

  ## Stripe API Reference

  - [Payouts](https://docs.stripe.com/api/payouts)
  - [Cancel a payout](https://docs.stripe.com/api/payouts/cancel)
  - [Reverse a payout](https://docs.stripe.com/api/payouts/reverse)
  """

  alias LatticeStripe.{Client, Error, List, ObjectTypes, Payout.TraceId, Request, Resource, Response}

  # Known top-level fields from the Stripe Payout object (string sigil — matches
  # Jason's default string-key output).
  @known_fields ~w[
    id object amount application_fee application_fee_amount arrival_date
    automatic balance_transaction created currency description destination
    failure_balance_transaction failure_code failure_message livemode metadata
    method original_payout reconciliation_status reversed_by source_type
    statement_descriptor status trace_id type
  ]

  defstruct [
    :id,
    :amount,
    :application_fee,
    :application_fee_amount,
    :arrival_date,
    :automatic,
    :balance_transaction,
    :created,
    :currency,
    :description,
    :destination,
    :failure_balance_transaction,
    :failure_code,
    :failure_message,
    :livemode,
    :metadata,
    :method,
    :original_payout,
    :reconciliation_status,
    :reversed_by,
    :source_type,
    :statement_descriptor,
    :status,
    :trace_id,
    :type,
    object: "payout",
    extra: %{}
  ]

  @typedoc """
  A Stripe Payout object.

  See the [Stripe Payout object](https://docs.stripe.com/api/payouts/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          application_fee: String.t() | nil,
          application_fee_amount: integer() | nil,
          arrival_date: integer() | nil,
          automatic: boolean() | nil,
          balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          destination: LatticeStripe.BankAccount.t() | LatticeStripe.Card.t() | String.t() | nil,
          failure_balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil,
          failure_code: String.t() | nil,
          failure_message: String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          method: atom() | String.t() | nil,
          original_payout: String.t() | nil,
          reconciliation_status: String.t() | nil,
          reversed_by: String.t() | nil,
          source_type: String.t() | nil,
          statement_descriptor: String.t() | nil,
          status: atom() | String.t() | nil,
          trace_id: TraceId.t() | nil,
          type: atom() | String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUDL
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Payout.

  Sends `POST /v1/payouts` with the given params.

  ## Parameters

  - `client` — A `%LatticeStripe.Client{}` struct
  - `params` — Payout attributes. Stripe requires `"amount"` and `"currency"`;
    LatticeStripe does not pre-validate — `Stripe` returns a `400` if missing.
  - `opts` — Per-request overrides (e.g., `[idempotency_key: "..."]`,
    `[stripe_account: "acct_..."]`)

  ## Example

      {:ok, payout} =
        LatticeStripe.Payout.create(client, %{
          "amount" => 5000,
          "currency" => "usd",
          "method" => "instant",
          "source_type" => "card"
        })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/payouts", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a Payout by ID.

  Sends `GET /v1/payouts/:id`. Raises `ArgumentError` (pre-network) if `id` is
  `nil` or an empty string.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(client, id, opts \\ [])

  def retrieve(%Client{}, id, _opts) when id in [nil, ""],
    do: raise(ArgumentError, ~s|Payout.retrieve/3 requires a non-empty "payout id"|)

  def retrieve(%Client{} = client, id, opts) when is_binary(id) do
    %Request{method: :get, path: "/v1/payouts/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a Payout by ID.

  Sends `POST /v1/payouts/:id`. Note: Stripe only supports updating `metadata`
  on a Payout.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(client, id, params, opts \\ [])

  def update(%Client{}, id, _params, _opts) when id in [nil, ""],
    do: raise(ArgumentError, ~s|Payout.update/4 requires a non-empty "payout id"|)

  def update(%Client{} = client, id, params, opts)
      when is_binary(id) and is_map(params) do
    %Request{method: :post, path: "/v1/payouts/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Payouts with optional filters.

  Sends `GET /v1/payouts` and returns a paginated `%Response{data: %List{}}`
  with typed `%Payout{}` items. All params are optional.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/payouts", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Payouts matching the given params.

  Emits individual `%Payout{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/payouts", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: cancel / reverse — D-03 canonical shape
  # ---------------------------------------------------------------------------

  @doc """
  Cancels a pending Payout.

  Sends `POST /v1/payouts/:id/cancel`. Only payouts with `status: "pending"`
  can be canceled.

  ## Signature (D-03)

  `cancel(client, id, params \\\\ %{}, opts \\\\ [])` — the `params` default is
  mandatory. Stripe's `/cancel` endpoint accepts `expand`, so dropping `params`
  would force a breaking change the first time a caller needs
  `expand: ["balance_transaction"]`.

  ## Example

      {:ok, payout} = LatticeStripe.Payout.cancel(client, "po_...")

      {:ok, payout} =
        LatticeStripe.Payout.cancel(client, "po_...", %{
          "expand" => ["balance_transaction"]
        })
  """
  @spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(client, id, params \\ %{}, opts \\ [])

  def cancel(%Client{}, id, _params, _opts) when id in [nil, ""],
    do: raise(ArgumentError, ~s|Payout.cancel/4 requires a non-empty "payout id"|)

  def cancel(%Client{} = client, id, params, opts) when is_binary(id) do
    %Request{method: :post, path: "/v1/payouts/#{id}/cancel", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Reverses a Payout.

  Sends `POST /v1/payouts/:id/reverse`. Only payouts with `status: "paid"` and
  `type: "bank_account"` can be reversed.

  ## Signature (D-03)

  `reverse(client, id, params \\\\ %{}, opts \\\\ [])` — the `params` default is
  mandatory. Stripe's `/reverse` endpoint accepts `metadata` and `expand`.

  ## Example

      {:ok, reversed} =
        LatticeStripe.Payout.reverse(client, "po_...", %{
          "metadata" => %{"reason" => "customer_dispute"},
          "expand" => ["balance_transaction"]
        })
  """
  @spec reverse(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def reverse(client, id, params \\ %{}, opts \\ [])

  def reverse(%Client{}, id, _params, _opts) when id in [nil, ""],
    do: raise(ArgumentError, ~s|Payout.reverse/4 requires a non-empty "payout id"|)

  def reverse(%Client{} = client, id, params, opts) when is_binary(id) do
    %Request{method: :post, path: "/v1/payouts/#{id}/reverse", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc "Like `create/3` but raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `retrieve/3` but raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `update/4` but raises `LatticeStripe.Error` on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(client, id, params, opts \\ [])

  def update!(%Client{}, id, _params, _opts) when id in [nil, ""],
    do: raise(ArgumentError, ~s|Payout.update!/4 requires a non-empty "payout id"|)

  def update!(%Client{} = client, id, params, opts)
      when is_binary(id) and is_map(params) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `list/3` but raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `cancel/4` but raises `LatticeStripe.Error` on failure."
  @spec cancel!(Client.t(), String.t(), map(), keyword()) :: t()
  def cancel!(%Client{} = client, id, params \\ %{}, opts \\ []) do
    cancel(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `reverse/4` but raises `LatticeStripe.Error` on failure."
  @spec reverse!(Client.t(), String.t(), map(), keyword()) :: t()
  def reverse!(%Client{} = client, id, params \\ %{}, opts \\ []) do
    reverse(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Payout{}` struct.

  Maps every known Stripe Payout field explicitly. The nested `trace_id` map
  is cast to a typed `%LatticeStripe.Payout.TraceId{}` struct. Unknown fields
  land in `:extra` (F-001).
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "payout",
      amount: known["amount"],
      application_fee: known["application_fee"],
      application_fee_amount: known["application_fee_amount"],
      arrival_date: known["arrival_date"],
      automatic: known["automatic"],
      balance_transaction:
        (if is_map(known["balance_transaction"]),
           do: ObjectTypes.maybe_deserialize(known["balance_transaction"]),
           else: known["balance_transaction"]),
      created: known["created"],
      currency: known["currency"],
      description: known["description"],
      destination:
        (if is_map(known["destination"]),
           do: ObjectTypes.maybe_deserialize(known["destination"]),
           else: known["destination"]),
      failure_balance_transaction:
        (if is_map(known["failure_balance_transaction"]),
           do: ObjectTypes.maybe_deserialize(known["failure_balance_transaction"]),
           else: known["failure_balance_transaction"]),
      failure_code: known["failure_code"],
      failure_message: known["failure_message"],
      livemode: known["livemode"],
      metadata: known["metadata"],
      method: atomize_method(known["method"]),
      original_payout: known["original_payout"],
      reconciliation_status: known["reconciliation_status"],
      reversed_by: known["reversed_by"],
      source_type: known["source_type"],
      statement_descriptor: known["statement_descriptor"],
      status: atomize_status(known["status"]),
      trace_id: TraceId.cast(known["trace_id"]),
      type: atomize_type(known["type"]),
      extra: extra
    }
  end

  # ---------------------------------------------------------------------------
  # Private: atomization helpers
  # ---------------------------------------------------------------------------

  defp atomize_status("paid"),       do: :paid
  defp atomize_status("pending"),    do: :pending
  defp atomize_status("in_transit"), do: :in_transit
  defp atomize_status("canceled"),   do: :canceled
  defp atomize_status("failed"),     do: :failed
  defp atomize_status(other),        do: other

  defp atomize_type("bank_account"), do: :bank_account
  defp atomize_type("card"),         do: :card
  defp atomize_type(other),          do: other

  defp atomize_method("standard"), do: :standard
  defp atomize_method("instant"),  do: :instant
  defp atomize_method(other),      do: other
end
