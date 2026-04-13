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

  alias LatticeStripe.{Client, Error, Request, Resource}

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
          balance_transaction: String.t() | map() | nil,
          billing_details: map() | nil,
          captured: boolean() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer: String.t() | nil,
          description: String.t() | nil,
          destination: String.t() | nil,
          failure_code: String.t() | nil,
          failure_message: String.t() | nil,
          fraud_details: map() | nil,
          invoice: String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          on_behalf_of: String.t() | nil,
          outcome: map() | nil,
          paid: boolean() | nil,
          payment_intent: String.t() | nil,
          payment_method: String.t() | nil,
          payment_method_details: map() | nil,
          receipt_email: String.t() | nil,
          receipt_number: String.t() | nil,
          receipt_url: String.t() | nil,
          refunded: boolean() | nil,
          refunds: map() | nil,
          review: String.t() | nil,
          source_transfer: String.t() | nil,
          statement_descriptor: String.t() | nil,
          statement_descriptor_suffix: String.t() | nil,
          status: String.t() | nil,
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

  def retrieve(%Client{}, nil, _opts) do
    raise ArgumentError, ~s|Charge.retrieve/3 requires a non-empty "charge id"|
  end

  def retrieve(%Client{}, "", _opts) do
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

  def retrieve!(%Client{}, nil, _opts) do
    raise ArgumentError, ~s|Charge.retrieve!/3 requires a non-empty "charge id"|
  end

  def retrieve!(%Client{}, "", _opts) do
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
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "charge",
      amount: map["amount"],
      amount_captured: map["amount_captured"],
      amount_refunded: map["amount_refunded"],
      application: map["application"],
      application_fee: map["application_fee"],
      application_fee_amount: map["application_fee_amount"],
      balance_transaction: map["balance_transaction"],
      billing_details: map["billing_details"],
      captured: map["captured"],
      created: map["created"],
      currency: map["currency"],
      customer: map["customer"],
      description: map["description"],
      destination: map["destination"],
      failure_code: map["failure_code"],
      failure_message: map["failure_message"],
      fraud_details: map["fraud_details"],
      invoice: map["invoice"],
      livemode: map["livemode"],
      metadata: map["metadata"],
      on_behalf_of: map["on_behalf_of"],
      outcome: map["outcome"],
      paid: map["paid"],
      payment_intent: map["payment_intent"],
      payment_method: map["payment_method"],
      payment_method_details: map["payment_method_details"],
      receipt_email: map["receipt_email"],
      receipt_number: map["receipt_number"],
      receipt_url: map["receipt_url"],
      refunded: map["refunded"],
      refunds: map["refunds"],
      review: map["review"],
      source_transfer: map["source_transfer"],
      statement_descriptor: map["statement_descriptor"],
      statement_descriptor_suffix: map["statement_descriptor_suffix"],
      status: map["status"],
      transfer_data: map["transfer_data"],
      transfer_group: map["transfer_group"],
      extra: Map.drop(map, @known_fields)
    }
  end
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
