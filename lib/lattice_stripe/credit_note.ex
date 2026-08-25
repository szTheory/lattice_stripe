defmodule LatticeStripe.CreditNote do
  @moduledoc """
  Operations on Stripe Credit Note objects.

  Credit notes let you reduce the amount of an invoice after it has been
  finalized. This module exposes Stripe-shaped CRUDL, preview, void, and
  line-item access without adding a local builder or workflow abstraction.

  Credit notes can only be created from finalized invoices. Previews use the
  same raw parameter shape as create, so the easiest way to validate a request
  is to send it through `preview/3` first.

  ## Common preview shapes

      LatticeStripe.CreditNote.preview(client, %{
        "invoice" => "in_123",
        "lines" => [
          %{
            "type" => "invoice_line_item",
            "invoice_line_item" => "il_123",
            "quantity" => 1
          }
        ]
      })

      LatticeStripe.CreditNote.preview(client, %{
        "invoice" => "in_123",
        "lines" => [
          %{
            "type" => "custom_line_item",
            "description" => "Goodwill credit",
            "quantity" => 1,
            "unit_amount" => 500
          }
        ]
      })
  """

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

  alias LatticeStripe.CreditNote.LineItem

  @known_fields ~w[
    id object amount amount_shipping created currency customer
    customer_balance_transaction effective_at invoice lines livemode memo metadata
    number out_of_band_amount pdf pre_payment_amount post_payment_amount reason
    refunds shipping_cost status subtotal subtotal_excluding_tax total
    total_excluding_tax total_taxes type voided_at
  ]

  defstruct [
    :id,
    :amount,
    :amount_shipping,
    :created,
    :currency,
    :customer,
    :customer_balance_transaction,
    :effective_at,
    :invoice,
    :lines,
    :livemode,
    :memo,
    :metadata,
    :number,
    :out_of_band_amount,
    :pdf,
    :pre_payment_amount,
    :post_payment_amount,
    :reason,
    :refunds,
    :shipping_cost,
    :status,
    :subtotal,
    :subtotal_excluding_tax,
    :total,
    :total_excluding_tax,
    :total_taxes,
    :type,
    :voided_at,
    object: "credit_note",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          amount_shipping: integer() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          customer_balance_transaction: BalanceTransaction.t() | String.t() | nil,
          effective_at: integer() | nil,
          invoice: LatticeStripe.Invoice.t() | String.t() | nil,
          lines: List.t() | nil,
          livemode: boolean() | nil,
          memo: String.t() | nil,
          metadata: map() | nil,
          number: String.t() | nil,
          out_of_band_amount: integer() | nil,
          pdf: String.t() | nil,
          pre_payment_amount: integer() | nil,
          post_payment_amount: integer() | nil,
          reason: atom() | String.t() | nil,
          refunds: list() | map() | nil,
          shipping_cost: map() | nil,
          status: atom() | String.t() | nil,
          subtotal: integer() | nil,
          subtotal_excluding_tax: integer() | nil,
          total: integer() | nil,
          total_excluding_tax: integer() | nil,
          total_taxes: list() | map() | nil,
          type: atom() | String.t() | nil,
          voided_at: integer() | nil,
          extra: map()
        }

  @doc """
  Creates a Credit Note.

  Sends `POST /v1/credit_notes` with the raw params map.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params, opts \\ []) do
    %Request{method: :post, path: "/v1/credit_notes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a Credit Note by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/credit_notes/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Updates a Credit Note by ID.

  Stripe currently only documents narrow mutable fields such as `memo` and
  `metadata`, but this function passes the raw params through unchanged.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/credit_notes/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists Credit Notes with optional filters.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/credit_notes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of Credit Notes matching the given filters.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/credit_notes", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Previews a Credit Note without creating it.

  The params shape matches `create/3` exactly.

  ## Example

      LatticeStripe.CreditNote.preview(client, %{
        "invoice" => "in_123",
        "lines" => [
          %{
            "type" => "invoice_line_item",
            "invoice_line_item" => "il_123",
            "quantity" => 1
          },
          %{
            "type" => "custom_line_item",
            "description" => "Goodwill credit",
            "quantity" => 1,
            "unit_amount" => 500
          }
        ]
      })
  """
  @spec preview(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def preview(%Client{} = client, params, opts \\ []) do
    %Request{method: :get, path: "/v1/credit_notes/preview", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `preview/3` but raises on failure."
  @spec preview!(Client.t(), map(), keyword()) :: t()
  def preview!(%Client{} = client, params, opts \\ []) do
    preview(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Voids a Credit Note.

  Sends `POST /v1/credit_notes/:id/void` with an empty body.

  ## Irreversibility

  Voiding is irreversible. Credit notes can only be created from finalized
  invoices, and voiding is only valid when the credit note is attached to an
  open invoice.
  """
  @spec void(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def void(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/credit_notes/#{id}/void", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `void/3` but raises on failure."
  @spec void!(Client.t(), String.t(), keyword()) :: t()
  def void!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    void(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists line items for an issued Credit Note.
  """
  @spec list_line_items(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_line_items(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    do_list_line_items(client, "/v1/credit_notes/#{id}/lines", params, opts)
  end

  @doc "Like `list_line_items/4` but raises on failure."
  @spec list_line_items!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list_line_items!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    list_line_items(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of line items for an issued Credit Note.
  """
  @spec stream_line_items!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream_line_items!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    do_stream_line_items(client, "/v1/credit_notes/#{id}/lines", params, opts)
  end

  @doc """
  Lists preview line items for a Credit Note preview request.
  """
  @spec list_preview_line_items(Client.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_preview_line_items(%Client{} = client, params \\ %{}, opts \\ []) do
    do_list_line_items(client, "/v1/credit_notes/preview/lines", params, opts)
  end

  @doc "Like `list_preview_line_items/3` but raises on failure."
  @spec list_preview_line_items!(Client.t(), map(), keyword()) :: Response.t()
  def list_preview_line_items!(%Client{} = client, params \\ %{}, opts \\ []) do
    list_preview_line_items(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of preview line items for a Credit Note preview request.
  """
  @spec stream_preview_line_items!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream_preview_line_items!(%Client{} = client, params \\ %{}, opts \\ []) do
    do_stream_line_items(client, "/v1/credit_notes/preview/lines", params, opts)
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "credit_note",
      amount: known["amount"],
      amount_shipping: known["amount_shipping"],
      created: known["created"],
      currency: known["currency"],
      customer: ObjectTypes.maybe_deserialize(known["customer"]),
      customer_balance_transaction:
        ObjectTypes.maybe_deserialize(known["customer_balance_transaction"]),
      effective_at: known["effective_at"],
      invoice: ObjectTypes.maybe_deserialize(known["invoice"]),
      lines: parse_lines(known["lines"]),
      livemode: known["livemode"],
      memo: known["memo"],
      metadata: known["metadata"],
      number: known["number"],
      out_of_band_amount: known["out_of_band_amount"],
      pdf: known["pdf"],
      pre_payment_amount: known["pre_payment_amount"],
      post_payment_amount: known["post_payment_amount"],
      reason: atomize_reason(known["reason"]),
      refunds: known["refunds"],
      shipping_cost: known["shipping_cost"],
      status: atomize_status(known["status"]),
      subtotal: known["subtotal"],
      subtotal_excluding_tax: known["subtotal_excluding_tax"],
      total: known["total"],
      total_excluding_tax: known["total_excluding_tax"],
      total_taxes: known["total_taxes"],
      type: atomize_type(known["type"]),
      voided_at: known["voided_at"],
      extra: extra
    }
  end

  defp do_list_line_items(%Client{} = client, path, params, opts) do
    %Request{method: :get, path: path, params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&LineItem.from_map/1)
  end

  defp do_stream_line_items(%Client{} = client, path, params, opts) do
    req = %Request{method: :get, path: path, params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&LineItem.from_map/1)
  end

  defp parse_lines(nil), do: nil

  defp parse_lines(%{"object" => "list", "data" => data} = list) when is_list(data) do
    %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
  end

  defp parse_lines(other), do: other

  defp atomize_status("issued"), do: :issued
  defp atomize_status("void"), do: :void
  defp atomize_status(other), do: other

  defp atomize_reason("duplicate"), do: :duplicate
  defp atomize_reason("fraudulent"), do: :fraudulent
  defp atomize_reason("order_change"), do: :order_change
  defp atomize_reason("product_unsatisfactory"), do: :product_unsatisfactory
  defp atomize_reason(other), do: other

  defp atomize_type("pre_payment"), do: :pre_payment
  defp atomize_type("post_payment"), do: :post_payment
  defp atomize_type("mixed"), do: :mixed
  defp atomize_type(other), do: other
end
