defmodule LatticeStripe.Quote do
  @moduledoc """
  Operations on Stripe Quote objects.

  > #### Name shadowing {: .warning}
  >
  > `alias LatticeStripe.Quote` makes the bare atom `Quote` refer to this module. It does
  > not break the `quote/1` special form, which is lowercase, but it does shadow Elixir's
  > `Quote`-prefixed references. Prefer fully qualifying, or alias under another name:
  >
  >     alias LatticeStripe.Quote, as: StripeQuote

  Quotes model a proposal before it becomes billable downstream Stripe objects.
  LatticeStripe exposes the Stripe-shaped Quote resource surface directly:
  create and iterate on a draft, finalize it into an open quote, optionally
  inspect or download its PDF, then accept or cancel it with explicit verbs.

  ## Lifecycle

  ```
  draft --> (finalize) --> open --> (accept) --> accepted
      \\                      \\
       \\                      (cancel) --> canceled
        \\
         (cancel) --> canceled
  ```

  Accepting a quote may create downstream billing objects such as an Invoice,
  Subscription, or SubscriptionSchedule. This module intentionally stops at the
  Stripe resource boundary and does not add application-level orchestration or
  prediction helpers.

  ## Line-item surfaces

  Quotes expose three different line-item views:

  - `quote.line_items` and `quote.computed.*.line_items` are embedded snapshots
  - `list_line_items/4` returns the paginated quoted-input line items
  - `list_computed_upfront_line_items/4` returns the paginated upfront-only
    computed line items

  ## PDF access

  `pdf/3` returns raw PDF binary, not a `%Quote{}`. Stripe only generates PDFs
  for shareable/finalized states, so `draft` and `canceled` quote PDF requests
  may return 404.
  """

  alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}
  alias LatticeStripe.Quote.{Computed, LineItem, StatusTransitions}

  @known_fields ~w[
    id object amount_subtotal amount_total application application_fee_amount
    application_fee_percent automatic_tax collection_method computed created
    currency customer default_tax_rates description discounts expires_at footer
    from_quote header invoice invoice_settings line_items livemode metadata
    number on_behalf_of status status_transitions subscription
    subscription_data subscription_schedule test_clock total_details transfer_data
  ]

  # Stripe Quote objects carry a large field surface; mirroring the API shape is intentional.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :amount_subtotal,
    :amount_total,
    :application,
    :application_fee_amount,
    :application_fee_percent,
    :automatic_tax,
    :collection_method,
    :computed,
    :created,
    :currency,
    :customer,
    :default_tax_rates,
    :description,
    :discounts,
    :expires_at,
    :footer,
    :from_quote,
    :header,
    :invoice,
    :invoice_settings,
    :line_items,
    :livemode,
    :metadata,
    :number,
    :on_behalf_of,
    :status,
    :status_transitions,
    :subscription,
    :subscription_data,
    :subscription_schedule,
    :test_clock,
    :total_details,
    :transfer_data,
    object: "quote",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount_subtotal: integer() | nil,
          amount_total: integer() | nil,
          application: String.t() | nil,
          application_fee_amount: integer() | nil,
          application_fee_percent: float() | integer() | nil,
          automatic_tax: map() | nil,
          collection_method: atom() | String.t() | nil,
          computed: Computed.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          default_tax_rates: list() | nil,
          description: String.t() | nil,
          discounts: list() | nil,
          expires_at: integer() | nil,
          footer: String.t() | nil,
          from_quote: map() | nil,
          header: String.t() | nil,
          invoice: LatticeStripe.Invoice.t() | String.t() | nil,
          invoice_settings: map() | nil,
          line_items: List.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          number: String.t() | nil,
          on_behalf_of: String.t() | nil,
          status: atom() | String.t() | nil,
          status_transitions: StatusTransitions.t() | nil,
          subscription: LatticeStripe.Subscription.t() | String.t() | nil,
          subscription_data: map() | nil,
          subscription_schedule: LatticeStripe.SubscriptionSchedule.t() | String.t() | nil,
          test_clock: String.t() | nil,
          total_details: map() | nil,
          transfer_data: map() | nil,
          extra: map()
        }

  @doc """
  Creates a Quote.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params, opts \\ []) do
    %Request{method: :post, path: "/v1/quotes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a Quote by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/quotes/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Updates a Quote by ID.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/quotes/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists Quotes with optional filters.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/quotes", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of Quotes matching the given filters.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/quotes", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Finalizes a draft quote and transitions it to `open`.

  Stripe accepts optional finalize-time params, so this function preserves the
  raw request map instead of constraining it locally.
  """
  @spec finalize(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def finalize(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/quotes/#{id}/finalize", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `finalize/4` but raises on failure."
  @spec finalize!(Client.t(), String.t(), map(), keyword()) :: t()
  def finalize!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    finalize(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Accepts an open quote.

  Accepting a quote is a terminal lifecycle transition that may generate
  downstream Stripe billing objects such as an Invoice, Subscription, or
  SubscriptionSchedule.
  """
  @spec accept(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def accept(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/quotes/#{id}/accept", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `accept/3` but raises on failure."
  @spec accept!(Client.t(), String.t(), keyword()) :: t()
  def accept!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    accept(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Cancels a draft or open quote.

  This is a terminal lifecycle transition. Stripe documents no request params for
  this endpoint, so the public API is intentionally parameterless apart from
  per-request opts.
  """
  @spec cancel(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/quotes/#{id}/cancel", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `cancel/3` but raises on failure."
  @spec cancel!(Client.t(), String.t(), keyword()) :: t()
  def cancel!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    cancel(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists the quoted-input line items for a Quote.
  """
  @spec list_line_items(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_line_items(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    do_list_line_items(client, "/v1/quotes/#{id}/line_items", params, opts)
  end

  @doc "Like `list_line_items/4` but raises on failure."
  @spec list_line_items!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list_line_items!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    list_line_items(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of quoted-input line items for a Quote.
  """
  @spec stream_line_items!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream_line_items!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    do_stream_line_items(client, "/v1/quotes/#{id}/line_items", params, opts)
  end

  @doc """
  Lists the computed upfront-only line items for a Quote.
  """
  @spec list_computed_upfront_line_items(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_computed_upfront_line_items(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    do_list_line_items(client, "/v1/quotes/#{id}/computed_upfront_line_items", params, opts)
  end

  @doc "Like `list_computed_upfront_line_items/4` but raises on failure."
  @spec list_computed_upfront_line_items!(Client.t(), String.t(), map(), keyword()) ::
          Response.t()
  def list_computed_upfront_line_items!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    list_computed_upfront_line_items(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of computed upfront-only line items for a Quote.
  """
  @spec stream_computed_upfront_line_items!(Client.t(), String.t(), map(), keyword()) ::
          Enumerable.t()
  def stream_computed_upfront_line_items!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    do_stream_line_items(client, "/v1/quotes/#{id}/computed_upfront_line_items", params, opts)
  end

  @doc """
  Downloads a Quote PDF as raw binary.

  This calls Stripe's binary PDF endpoint and unwraps the transport `%Response{}`
  into `{:ok, binary}` at the resource layer.

  Stripe may return 404 for `draft` and `canceled` quotes because PDFs are only
  available for shareable/finalized states.
  """
  @spec pdf(Client.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def pdf(%Client{} = client, id, opts \\ []) when is_binary(id) do
    case Client.download(client, "/v1/quotes/#{id}/pdf", opts) do
      {:ok, %Response{data: data}} when is_binary(data) -> {:ok, data}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  @doc "Like `pdf/3` but raises on failure."
  @spec pdf!(Client.t(), String.t(), keyword()) :: binary()
  def pdf!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    pdf(client, id, opts) |> Resource.unwrap_bang!()
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "quote",
      amount_subtotal: known["amount_subtotal"],
      amount_total: known["amount_total"],
      application: known["application"],
      application_fee_amount: known["application_fee_amount"],
      application_fee_percent: known["application_fee_percent"],
      automatic_tax: known["automatic_tax"],
      collection_method: atomize_collection_method(known["collection_method"]),
      computed: Computed.from_map(known["computed"]),
      created: known["created"],
      currency: known["currency"],
      customer: ObjectTypes.maybe_deserialize(known["customer"]),
      default_tax_rates: known["default_tax_rates"],
      description: known["description"],
      discounts: known["discounts"],
      expires_at: known["expires_at"],
      footer: known["footer"],
      from_quote: known["from_quote"],
      header: known["header"],
      invoice: ObjectTypes.maybe_deserialize(known["invoice"]),
      invoice_settings: known["invoice_settings"],
      line_items: parse_line_items(known["line_items"]),
      livemode: known["livemode"],
      metadata: known["metadata"],
      number: known["number"],
      on_behalf_of: known["on_behalf_of"],
      status: atomize_status(known["status"]),
      status_transitions: StatusTransitions.from_map(known["status_transitions"]),
      subscription: ObjectTypes.maybe_deserialize(known["subscription"]),
      subscription_data: known["subscription_data"],
      subscription_schedule: ObjectTypes.maybe_deserialize(known["subscription_schedule"]),
      test_clock: known["test_clock"],
      total_details: known["total_details"],
      transfer_data: known["transfer_data"],
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

  defp parse_line_items(nil), do: nil

  defp parse_line_items(%{"object" => "list", "data" => data} = list) when is_list(data) do
    %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
  end

  defp parse_line_items(other), do: other

  defp atomize_collection_method("charge_automatically"), do: :charge_automatically
  defp atomize_collection_method("send_invoice"), do: :send_invoice
  defp atomize_collection_method(other), do: other

  defp atomize_status("draft"), do: :draft
  defp atomize_status("open"), do: :open
  defp atomize_status("accepted"), do: :accepted
  defp atomize_status("canceled"), do: :canceled
  defp atomize_status(other), do: other
end
