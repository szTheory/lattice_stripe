defmodule LatticeStripe.Dispute do
  @moduledoc """
  Operations on Stripe Dispute objects.

  Disputes are created automatically by Stripe when a cardholder or bank
  challenges a payment. This module covers the dispute lifecycle after that
  point: retrieval, listing, metadata updates, safe evidence staging,
  irreversible evidence submission, and irreversible dispute closure.

  There is no `create/3` or `delete/3` API because disputes are not developer-
  created resources in Stripe.

  ## Evidence workflow

  - `update/4` is the raw power-user entry point for `POST /v1/disputes/:id`
  - `update_evidence/4` stages evidence safely and always forces `submit: false`
  - `submit_evidence/3` sends `submit: true` with no evidence payload

  ## Stripe API Reference

  See the [Stripe Disputes API](https://docs.stripe.com/api/disputes).
  """

  alias LatticeStripe.Dispute.{Evidence, EvidenceDetails, PaymentMethodDetails}

  alias LatticeStripe.{
    BalanceTransaction,
    Client,
    Error,
    List,
    ObjectTypes,
    Request,
    Resource,
    Response
  }

  @known_fields ~w[
    id object amount balance_transactions charge created currency
    enhanced_eligibility_types evidence evidence_details
    is_charge_refundable livemode metadata payment_intent
    payment_method_details reason status
  ]

  defstruct [
    :id,
    :amount,
    :balance_transactions,
    :charge,
    :created,
    :currency,
    :enhanced_eligibility_types,
    :evidence,
    :evidence_details,
    :is_charge_refundable,
    :livemode,
    :metadata,
    :payment_intent,
    :payment_method_details,
    :reason,
    :status,
    object: "dispute",
    extra: %{}
  ]

  @typedoc """
  A Stripe Dispute object.

  See the [Stripe Dispute object](https://docs.stripe.com/api/disputes/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          balance_transactions: [BalanceTransaction.t()] | nil,
          charge: LatticeStripe.Charge.t() | String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          enhanced_eligibility_types: [String.t()] | nil,
          evidence: Evidence.t() | nil,
          evidence_details: EvidenceDetails.t() | nil,
          is_charge_refundable: boolean() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          payment_intent: LatticeStripe.PaymentIntent.t() | String.t() | nil,
          payment_method_details: PaymentMethodDetails.t() | nil,
          reason: atom() | String.t() | nil,
          status: atom() | String.t() | nil,
          extra: map()
        }

  @doc """
  Retrieves a Dispute by ID.

  Sends `GET /v1/disputes/:id`.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/disputes/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists Disputes with optional filters.

  Sends `GET /v1/disputes`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/disputes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of Disputes matching the given filters.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/disputes", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Updates a Dispute by ID.

  This is the general-purpose update entry point for the underlying Stripe API.
  It accepts any supported dispute update params, including raw `evidence` and
  `submit` combinations for power users.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    do_update(client, id, params, opts)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Stages dispute evidence without submitting it to the issuing bank.

  This helper always sends `submit: false`, so it is impossible to
  accidentally lock the dispute response while attaching evidence.
  """
  @spec update_evidence(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def update_evidence(%Client{} = client, id, evidence, opts \\ []) when is_binary(id) do
    clean = Map.drop(evidence, ["submit", :submit])
    do_update(client, id, %{evidence: clean, submit: false}, opts)
  end

  @doc "Like `update_evidence/4` but raises on failure."
  @spec update_evidence!(Client.t(), String.t(), map(), keyword()) :: t()
  def update_evidence!(%Client{} = client, id, evidence, opts \\ []) when is_binary(id) do
    update_evidence(client, id, evidence, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Submits previously staged evidence to the issuing bank.

  ## Irreversibility

  Evidence submission locks the response sent to the issuing bank. Once
  submitted, you cannot modify the evidence or add new files. The dispute
  itself remains open, but the bank response is final.
  """
  @spec submit_evidence(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def submit_evidence(%Client{} = client, id, opts \\ []) when is_binary(id) do
    do_update(client, id, %{submit: true}, opts)
  end

  @doc "Like `submit_evidence/3` but raises on failure."
  @spec submit_evidence!(Client.t(), String.t(), keyword()) :: t()
  def submit_evidence!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    submit_evidence(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Closes a Dispute by accepting the loss.

  Sends `POST /v1/disputes/:id/close` with an empty body.

  ## Irreversibility

  Closing is irreversible. The dispute status changes to `lost` and the
  disputed amount plus any dispute fees are permanently deducted from your
  Stripe balance. This cannot be undone via the API or Stripe Dashboard.
  """
  @spec close(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def close(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/disputes/#{id}/close", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `close/3` but raises on failure."
  @spec close!(Client.t(), String.t(), keyword()) :: t()
  def close!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    close(client, id, opts) |> Resource.unwrap_bang!()
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "dispute",
      amount: known["amount"],
      balance_transactions: parse_balance_transactions(known["balance_transactions"]),
      charge: parse_expandable(known["charge"]),
      created: known["created"],
      currency: known["currency"],
      enhanced_eligibility_types: known["enhanced_eligibility_types"],
      evidence: Evidence.from_map(known["evidence"]),
      evidence_details: EvidenceDetails.from_map(known["evidence_details"]),
      is_charge_refundable: known["is_charge_refundable"],
      livemode: known["livemode"],
      metadata: known["metadata"],
      payment_intent: parse_expandable(known["payment_intent"]),
      payment_method_details: PaymentMethodDetails.from_map(known["payment_method_details"]),
      reason: atomize_reason(known["reason"]),
      status: atomize_status(known["status"]),
      extra: extra
    }
  end

  defp do_update(%Client{} = client, id, params, opts) do
    %Request{method: :post, path: "/v1/disputes/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  defp parse_balance_transactions(nil), do: nil

  defp parse_balance_transactions(list) when is_list(list) do
    Enum.map(list, &BalanceTransaction.from_map/1)
  end

  defp parse_balance_transactions(other), do: other

  defp parse_expandable(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_expandable(value), do: value

  defp atomize_status("needs_response"), do: :needs_response
  defp atomize_status("warning_needs_response"), do: :warning_needs_response
  defp atomize_status("under_review"), do: :under_review
  defp atomize_status("warning_under_review"), do: :warning_under_review
  defp atomize_status("warning_closed"), do: :warning_closed
  defp atomize_status("won"), do: :won
  defp atomize_status("lost"), do: :lost
  defp atomize_status("charge_refunded"), do: :charge_refunded
  defp atomize_status("prevented"), do: :prevented
  defp atomize_status(other), do: other

  defp atomize_reason("fraudulent"), do: :fraudulent
  defp atomize_reason("duplicate"), do: :duplicate
  defp atomize_reason("not_received"), do: :not_received
  defp atomize_reason("product_not_received"), do: :product_not_received
  defp atomize_reason("subscription_canceled"), do: :subscription_canceled
  defp atomize_reason("product_unacceptable"), do: :product_unacceptable
  defp atomize_reason("unrecognized"), do: :unrecognized
  defp atomize_reason("credit_not_processed"), do: :credit_not_processed
  defp atomize_reason("general"), do: :general
  defp atomize_reason("incorrect_account_details"), do: :incorrect_account_details
  defp atomize_reason("insufficient_funds"), do: :insufficient_funds
  defp atomize_reason("bank_cannot_process"), do: :bank_cannot_process
  defp atomize_reason("debit_not_authorized"), do: :debit_not_authorized
  defp atomize_reason("customer_initiated"), do: :customer_initiated
  defp atomize_reason("check_returned"), do: :check_returned
  defp atomize_reason("noncompliant"), do: :noncompliant
  defp atomize_reason(other), do: other
end

defimpl Inspect, for: LatticeStripe.Dispute do
  import Inspect.Algebra

  def inspect(dispute, opts) do
    fields = [
      id: dispute.id,
      object: dispute.object,
      amount: dispute.amount,
      currency: dispute.currency,
      status: dispute.status,
      reason: dispute.reason
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Dispute<" | pairs] ++ [">"])
  end
end
