defmodule LatticeStripe.Charge do
  @moduledoc """
  Retrieve-only access to Stripe Charge objects.

  Stripe's modern API is PaymentIntent-first; use `LatticeStripe.PaymentIntent.create/3`
  to accept payments. This module exposes retrieve-only access for reading settled
  fee details during Connect platform fee reconciliation.

  Only three public functions exist — `retrieve/3`, `retrieve!/3`, and `from_map/1`.
  By design there is **no** `create`, `update`, `capture`, `cancel`, `list`, `stream!`,
  or `search` — Charges are created as a side effect of PaymentIntent confirmation and
  are never directly manipulated through this SDK. See Phase 18 decision D-06 for the
  full rationale.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Retrieve a settled charge by id
      {:ok, charge} = LatticeStripe.Charge.retrieve(client, "ch_3OoLqrJ...")

      # Expand the balance_transaction to read fee_details inline
      {:ok, charge} =
        LatticeStripe.Charge.retrieve(client, "ch_3OoLqrJ...",
          expand: ["balance_transaction"]
        )

      # Walk fee_details to find the application_fee entry (Connect platform fee)
      application_fees =
        charge.balance_transaction["fee_details"]
        |> Enum.filter(fn fd -> fd["type"] == "application_fee" end)

  ## Connect platform fee reconciliation

  This module's reason to exist: after a destination charge settles, platforms walk
  `PaymentIntent.latest_charge -> Charge.balance_transaction -> fee_details` to
  reconcile the application fee Stripe transferred into their platform balance.
  The typed `%Charge{}` return gives IDE-friendly completion and typespec coverage
  for that flow without forcing users to drop into `LatticeStripe.Client.request/2`.

  ## Security and Inspect

  `Inspect` shows only `[id, object, amount, currency, status, captured, paid]`.
  The following fields may contain customer PII and are **hidden** from inspect
  output so they do not leak into application logs:

    * `billing_details` (email, name, phone, address)
    * `payment_method_details` (card last4, fingerprint, etc.)
    * `fraud_details`
    * `receipt_email`, `receipt_number`, `receipt_url`
    * `customer`, `payment_method`

  If you explicitly access those fields on a `%Charge{}` struct, you own the
  disclosure decision.

  ## Stripe API Reference

  See the [Stripe Charge API](https://docs.stripe.com/api/charges/object) for the
  full object reference.
  """

  alias LatticeStripe.{Client, Error, ObjectTypes, Request, Resource}

  # Known top-level fields from the Stripe Charge object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount amount_captured amount_refunded application
    application_fee application_fee_amount balance_transaction billing_details
    captured created currency customer description destination failure_code
    failure_message fraud_details invoice livemode metadata on_behalf_of
    outcome paid payment_intent payment_method payment_method_details
    receipt_email receipt_number receipt_url refunded refunds review
    source_transfer statement_descriptor statement_descriptor_suffix status
    transfer_data transfer_group
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :amount,
    :amount_captured,
    :amount_refunded,
    :application,
    :application_fee,
    :application_fee_amount,
    :balance_transaction,
    :billing_details,
    :captured,
    :created,
    :currency,
    :customer,
    :description,
    :destination,
    :failure_code,
    :failure_message,
    :fraud_details,
    :invoice,
    :livemode,
    :metadata,
    :on_behalf_of,
    :outcome,
    :paid,
    :payment_intent,
    :payment_method,
    :payment_method_details,
    :receipt_email,
    :receipt_number,
    :receipt_url,
    :refunded,
    :refunds,
    :review,
    :source_transfer,
    :statement_descriptor,
    :statement_descriptor_suffix,
    :status,
    :transfer_data,
    :transfer_group,
    object: "charge",
    extra: %{}
  ]

  @typedoc """
  A Stripe Charge object.

  See the [Stripe Charge API](https://docs.stripe.com/api/charges/object) for field
  definitions. Unknown fields are preserved in `:extra` (F-001).
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          amount_captured: integer() | nil,
          amount_refunded: integer() | nil,
          application: String.t() | nil,
          application_fee: String.t() | nil,
          application_fee_amount: integer() | nil,
          balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil,
          billing_details: map() | nil,
          captured: boolean() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          description: String.t() | nil,
          destination: LatticeStripe.Account.t() | String.t() | nil,
          failure_code: String.t() | nil,
          failure_message: String.t() | nil,
          fraud_details: map() | nil,
          invoice: LatticeStripe.Invoice.t() | String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          on_behalf_of: String.t() | nil,
          outcome: map() | nil,
          paid: boolean() | nil,
          payment_intent: LatticeStripe.PaymentIntent.t() | String.t() | nil,
          payment_method: LatticeStripe.PaymentMethod.t() | String.t() | nil,
          payment_method_details: map() | nil,
          receipt_email: String.t() | nil,
          receipt_number: String.t() | nil,
          receipt_url: String.t() | nil,
          refunded: boolean() | nil,
          refunds: map() | nil,
          review: String.t() | nil,
          source_transfer: LatticeStripe.Transfer.t() | String.t() | nil,
          statement_descriptor: String.t() | nil,
          statement_descriptor_suffix: String.t() | nil,
          status: atom() | String.t() | nil,
          transfer_data: map() | nil,
          transfer_group: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: retrieve
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a Charge by ID.

  Sends `GET /v1/charges/:id` and returns `{:ok, %Charge{}}`.

  Raises `ArgumentError` (pre-network) if `id` is `nil` or an empty string.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The Charge ID string (e.g., `"ch_3OoLqrJ..."`)
  - `opts` - Per-request overrides. Supports `expand: ["balance_transaction", ...]`
    to inline expanded child objects.

  ## Returns

  - `{:ok, %Charge{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, charge} =
        LatticeStripe.Charge.retrieve(client, "ch_3OoLqrJ...",
          expand: ["balance_transaction"]
        )

      application_fees =
        charge.balance_transaction["fee_details"]
        |> Enum.filter(fn fd -> fd["type"] == "application_fee" end)
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(client, id, opts \\ [])

  def retrieve(%Client{}, id, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|Charge.retrieve/3 requires a non-empty "charge id"|
  end

  def retrieve(%Client{} = client, id, opts) when is_binary(id) do
    %Request{method: :get, path: "/v1/charges/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Like `retrieve/3` but returns the bare `%Charge{}` on success and raises
  `LatticeStripe.Error` on failure.

  Also raises `ArgumentError` (pre-network) when `id` is `nil` or empty.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(client, id, opts \\ [])

  def retrieve!(%Client{}, id, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|Charge.retrieve!/3 requires a non-empty "charge id"|
  end

  def retrieve!(%Client{} = client, id, opts) when is_binary(id) do
    client |> retrieve(id, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Charge{}` struct.

  Maps every known Stripe Charge field explicitly. Any unrecognized fields
  are collected into `:extra` (F-001) so no data is silently lost when Stripe
  adds new fields.

  `from_map(nil)` returns `nil` for use with optional/nullable charge payloads.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "charge",
      amount: known["amount"],
      amount_captured: known["amount_captured"],
      amount_refunded: known["amount_refunded"],
      application: known["application"],
      application_fee: known["application_fee"],
      application_fee_amount: known["application_fee_amount"],
      balance_transaction:
        (if is_map(known["balance_transaction"]),
          do: ObjectTypes.maybe_deserialize(known["balance_transaction"]),
          else: known["balance_transaction"]),
      billing_details: known["billing_details"],
      captured: known["captured"],
      created: known["created"],
      currency: known["currency"],
      customer:
        (if is_map(known["customer"]),
          do: ObjectTypes.maybe_deserialize(known["customer"]),
          else: known["customer"]),
      description: known["description"],
      destination:
        (if is_map(known["destination"]),
          do: ObjectTypes.maybe_deserialize(known["destination"]),
          else: known["destination"]),
      failure_code: known["failure_code"],
      failure_message: known["failure_message"],
      fraud_details: known["fraud_details"],
      invoice:
        (if is_map(known["invoice"]),
          do: ObjectTypes.maybe_deserialize(known["invoice"]),
          else: known["invoice"]),
      livemode: known["livemode"],
      metadata: known["metadata"],
      on_behalf_of: known["on_behalf_of"],
      outcome: known["outcome"],
      paid: known["paid"],
      payment_intent:
        (if is_map(known["payment_intent"]),
          do: ObjectTypes.maybe_deserialize(known["payment_intent"]),
          else: known["payment_intent"]),
      payment_method:
        (if is_map(known["payment_method"]),
          do: ObjectTypes.maybe_deserialize(known["payment_method"]),
          else: known["payment_method"]),
      payment_method_details: known["payment_method_details"],
      receipt_email: known["receipt_email"],
      receipt_number: known["receipt_number"],
      receipt_url: known["receipt_url"],
      refunded: known["refunded"],
      refunds: known["refunds"],
      review: known["review"],
      source_transfer:
        (if is_map(known["source_transfer"]),
          do: ObjectTypes.maybe_deserialize(known["source_transfer"]),
          else: known["source_transfer"]),
      statement_descriptor: known["statement_descriptor"],
      statement_descriptor_suffix: known["statement_descriptor_suffix"],
      status: atomize_status(known["status"]),
      transfer_data: known["transfer_data"],
      transfer_group: known["transfer_group"],
      extra: extra
    }
  end

  # ---------------------------------------------------------------------------
  # Private: atomization helpers
  # ---------------------------------------------------------------------------

  defp atomize_status("succeeded"), do: :succeeded
  defp atomize_status("pending"),   do: :pending
  defp atomize_status("failed"),    do: :failed
  defp atomize_status(other),       do: other
end

defimpl Inspect, for: LatticeStripe.Charge do
  import Inspect.Algebra

  def inspect(charge, opts) do
    # Show only structural/non-PII fields.
    # Hidden (see @moduledoc Security section): billing_details,
    # payment_method_details, fraud_details, receipt_email, receipt_number,
    # receipt_url, customer, payment_method.
    fields = [
      id: charge.id,
      object: charge.object,
      amount: charge.amount,
      currency: charge.currency,
      status: charge.status,
      captured: charge.captured,
      paid: charge.paid
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Charge<" | pairs] ++ [">"])
  end
end
