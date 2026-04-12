defmodule LatticeStripe.Invoice do
  @moduledoc """
  Operations on Stripe Invoice objects.

  An Invoice is the document Stripe generates when it is time to bill a customer.
  Invoices track charges, taxes, discounts, and payment lifecycle. They can be
  created manually or automatically by subscriptions.

  ## Lifecycle

  ```
  draft --> (finalize) --> open --> (pay) --> paid
                             |
                           (void) --> void
                             |
                     (mark_uncollectible) --> uncollectible
  ```

  ## Common Workflow

  For manually managed invoices:

      # 1. Create a draft invoice (auto_advance: false prevents automatic finalization)
      {:ok, invoice} = LatticeStripe.Invoice.create(client, %{
        "customer" => customer_id,
        "auto_advance" => false
      })

      # 2. Add InvoiceItems to the invoice
      {:ok, _item} = LatticeStripe.InvoiceItem.create(client, %{
        "customer" => customer_id,
        "invoice" => invoice.id,
        "amount" => 5000,
        "currency" => "usd",
        "description" => "Professional services"
      })

      # 3. Finalize the invoice (locks line items, moves to open)
      {:ok, open_invoice} = LatticeStripe.Invoice.finalize(client, invoice.id)

      # 4. Pay the invoice
      {:ok, paid_invoice} = LatticeStripe.Invoice.pay(client, open_invoice.id)

  ## auto_advance

  When `auto_advance` is `true` (the default for subscription invoices), Stripe
  automatically finalizes the draft invoice after approximately 1 hour. Set
  `auto_advance: false` when creating invoices manually so you can add line items
  before finalization.

  ## Stripe API Reference

  See the [Stripe Invoice API](https://docs.stripe.com/api/invoices) for the full
  object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}
  alias LatticeStripe.Invoice.{AutomaticTax, LineItem, StatusTransitions}

  # Known top-level fields from the Stripe Invoice object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object account_country account_name account_tax_ids amount_due amount_paid
    amount_remaining amount_shipping application application_fee_amount attempt_count
    attempted auto_advance automatic_tax billing_reason charge collection_method
    created currency customer customer_address customer_email customer_name
    customer_phone customer_shipping customer_tax_exempt customer_tax_ids
    custom_fields default_payment_method default_source default_tax_rates
    description discount discounts due_date effective_at ending_balance footer
    from_invoice hosted_invoice_url invoice_pdf issuer last_finalization_error
    latest_revision lines livemode metadata next_payment_attempt number
    on_behalf_of paid paid_out_of_band payment_intent payment_settings period_end
    period_start post_payment_credit_notes_amount pre_payment_credit_notes_amount
    quote receipt_number rendering rendering_options shipping_cost shipping_details
    starting_balance statement_descriptor status status_transitions subscription
    subscription_details subscription_proration_date subtotal subtotal_excluding_tax
    tax test_clock threshold_reason total total_discount_amounts total_excluding_tax
    total_tax_amounts transfer_data webhooks_delivered_at deleted
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :account_country,
    :account_name,
    :account_tax_ids,
    :amount_due,
    :amount_paid,
    :amount_remaining,
    :amount_shipping,
    :application,
    :application_fee_amount,
    :attempt_count,
    :attempted,
    :auto_advance,
    :automatic_tax,
    :billing_reason,
    :charge,
    :collection_method,
    :created,
    :currency,
    :customer,
    :customer_address,
    :customer_email,
    :customer_name,
    :customer_phone,
    :customer_shipping,
    :customer_tax_exempt,
    :customer_tax_ids,
    :custom_fields,
    :default_payment_method,
    :default_source,
    :default_tax_rates,
    :description,
    :discount,
    :discounts,
    :due_date,
    :effective_at,
    :ending_balance,
    :footer,
    :from_invoice,
    :hosted_invoice_url,
    :invoice_pdf,
    :issuer,
    :last_finalization_error,
    :latest_revision,
    :lines,
    :livemode,
    :metadata,
    :next_payment_attempt,
    :number,
    :on_behalf_of,
    :paid,
    :paid_out_of_band,
    :payment_intent,
    :payment_settings,
    :period_end,
    :period_start,
    :post_payment_credit_notes_amount,
    :pre_payment_credit_notes_amount,
    :quote,
    :receipt_number,
    :rendering,
    :rendering_options,
    :shipping_cost,
    :shipping_details,
    :starting_balance,
    :statement_descriptor,
    :status,
    :status_transitions,
    :subscription,
    :subscription_details,
    :subscription_proration_date,
    :subtotal,
    :subtotal_excluding_tax,
    :tax,
    :test_clock,
    :threshold_reason,
    :total,
    :total_discount_amounts,
    :total_excluding_tax,
    :total_tax_amounts,
    :transfer_data,
    :webhooks_delivered_at,
    object: "invoice",
    deleted: false,
    extra: %{}
  ]

  @typedoc """
  A Stripe Invoice object.

  See the [Stripe Invoice API](https://docs.stripe.com/api/invoices/object) for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          account_country: String.t() | nil,
          account_name: String.t() | nil,
          account_tax_ids: list() | nil,
          amount_due: integer() | nil,
          amount_paid: integer() | nil,
          amount_remaining: integer() | nil,
          amount_shipping: integer() | nil,
          application: String.t() | nil,
          application_fee_amount: integer() | nil,
          attempt_count: integer() | nil,
          attempted: boolean() | nil,
          auto_advance: boolean() | nil,
          automatic_tax: AutomaticTax.t() | nil,
          billing_reason: atom() | String.t() | nil,
          charge: String.t() | nil,
          collection_method: atom() | String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          customer: String.t() | nil,
          customer_address: map() | nil,
          customer_email: String.t() | nil,
          customer_name: String.t() | nil,
          customer_phone: String.t() | nil,
          customer_shipping: map() | nil,
          customer_tax_exempt: atom() | String.t() | nil,
          customer_tax_ids: list() | nil,
          custom_fields: list() | nil,
          default_payment_method: String.t() | nil,
          default_source: String.t() | nil,
          default_tax_rates: list() | nil,
          description: String.t() | nil,
          discount: map() | nil,
          discounts: list() | nil,
          due_date: integer() | nil,
          effective_at: integer() | nil,
          ending_balance: integer() | nil,
          footer: String.t() | nil,
          from_invoice: map() | nil,
          hosted_invoice_url: String.t() | nil,
          invoice_pdf: String.t() | nil,
          issuer: map() | nil,
          last_finalization_error: map() | nil,
          latest_revision: String.t() | nil,
          lines: List.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          next_payment_attempt: integer() | nil,
          number: String.t() | nil,
          on_behalf_of: String.t() | nil,
          paid: boolean() | nil,
          paid_out_of_band: boolean() | nil,
          payment_intent: String.t() | nil,
          payment_settings: map() | nil,
          period_end: integer() | nil,
          period_start: integer() | nil,
          post_payment_credit_notes_amount: integer() | nil,
          pre_payment_credit_notes_amount: integer() | nil,
          quote: String.t() | nil,
          receipt_number: String.t() | nil,
          rendering: map() | nil,
          rendering_options: map() | nil,
          shipping_cost: map() | nil,
          shipping_details: map() | nil,
          starting_balance: integer() | nil,
          statement_descriptor: String.t() | nil,
          status: atom() | String.t() | nil,
          status_transitions: StatusTransitions.t() | nil,
          subscription: String.t() | nil,
          subscription_details: map() | nil,
          subscription_proration_date: integer() | nil,
          subtotal: integer() | nil,
          subtotal_excluding_tax: integer() | nil,
          tax: integer() | nil,
          test_clock: String.t() | nil,
          threshold_reason: map() | nil,
          total: integer() | nil,
          total_discount_amounts: list() | nil,
          total_excluding_tax: integer() | nil,
          total_tax_amounts: list() | nil,
          transfer_data: map() | nil,
          webhooks_delivered_at: integer() | nil,
          deleted: boolean(),
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Invoice.

  Sends `POST /v1/invoices` with the given params and returns `{:ok, %Invoice{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of invoice attributes. Common params:
    - `"customer"` - Customer ID (required for manual invoices)
    - `"auto_advance"` - Whether to auto-finalize (default `true` for subscriptions)
    - `"collection_method"` - `"charge_automatically"` or `"send_invoice"`
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Invoice{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/invoices", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves an Invoice by ID.

  Sends `GET /v1/invoices/:id` and returns `{:ok, %Invoice{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The invoice ID string (e.g., `"in_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Invoice{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/invoices/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates an Invoice by ID.

  Sends `POST /v1/invoices/:id` with the given params and returns `{:ok, %Invoice{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The invoice ID string
  - `params` - Map of fields to update
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Invoice{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/invoices/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Deletes a draft Invoice by ID.

  Sends `DELETE /v1/invoices/:id` and returns `{:ok, %Invoice{}}`.

  Only applicable to draft invoices. Finalized invoices cannot be deleted;
  use `void/3` to cancel a finalized invoice.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The invoice ID string
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Invoice{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :delete, path: "/v1/invoices/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Invoices with optional filters.

  Sends `GET /v1/invoices` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%Invoice{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"customer" => "cus_123", "status" => "open"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Invoice{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/invoices", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Invoices matching the given params (auto-pagination).

  Emits individual `%Invoice{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"customer" => "cus_123"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Invoice{}` structs.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/invoices", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
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
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `update/4` but raises `LatticeStripe.Error` on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `delete/3` but raises `LatticeStripe.Error` on failure."
  @spec delete!(Client.t(), String.t(), keyword()) :: t()
  def delete!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    delete(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `list/3` but raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Invoice{}` struct.

  Maps all known Stripe Invoice fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost.

  Atomizes status, collection_method, billing_reason, and customer_tax_exempt
  using a whitelist — unknown values pass through as strings to avoid atom
  table exhaustion from unexpected Stripe API values.

  ## Example

      invoice = LatticeStripe.Invoice.from_map(%{
        "id" => "in_123",
        "status" => "open",
        "collection_method" => "charge_automatically",
        "object" => "invoice"
      })
      # => %LatticeStripe.Invoice{id: "in_123", status: :open, ...}
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "invoice",
      account_country: known["account_country"],
      account_name: known["account_name"],
      account_tax_ids: known["account_tax_ids"],
      amount_due: known["amount_due"],
      amount_paid: known["amount_paid"],
      amount_remaining: known["amount_remaining"],
      amount_shipping: known["amount_shipping"],
      application: known["application"],
      application_fee_amount: known["application_fee_amount"],
      attempt_count: known["attempt_count"],
      attempted: known["attempted"],
      auto_advance: known["auto_advance"],
      automatic_tax: AutomaticTax.from_map(known["automatic_tax"]),
      billing_reason: atomize_billing_reason(known["billing_reason"]),
      charge: known["charge"],
      collection_method: atomize_collection_method(known["collection_method"]),
      created: known["created"],
      currency: known["currency"],
      customer: known["customer"],
      customer_address: known["customer_address"],
      customer_email: known["customer_email"],
      customer_name: known["customer_name"],
      customer_phone: known["customer_phone"],
      customer_shipping: known["customer_shipping"],
      customer_tax_exempt: atomize_customer_tax_exempt(known["customer_tax_exempt"]),
      customer_tax_ids: known["customer_tax_ids"],
      custom_fields: known["custom_fields"],
      default_payment_method: known["default_payment_method"],
      default_source: known["default_source"],
      default_tax_rates: known["default_tax_rates"],
      description: known["description"],
      discount: known["discount"],
      discounts: known["discounts"],
      due_date: known["due_date"],
      effective_at: known["effective_at"],
      ending_balance: known["ending_balance"],
      footer: known["footer"],
      from_invoice: known["from_invoice"],
      hosted_invoice_url: known["hosted_invoice_url"],
      invoice_pdf: known["invoice_pdf"],
      issuer: known["issuer"],
      last_finalization_error: known["last_finalization_error"],
      latest_revision: known["latest_revision"],
      lines: parse_lines(known["lines"]),
      livemode: known["livemode"],
      metadata: known["metadata"],
      next_payment_attempt: known["next_payment_attempt"],
      number: known["number"],
      on_behalf_of: known["on_behalf_of"],
      paid: known["paid"],
      paid_out_of_band: known["paid_out_of_band"],
      payment_intent: known["payment_intent"],
      payment_settings: known["payment_settings"],
      period_end: known["period_end"],
      period_start: known["period_start"],
      post_payment_credit_notes_amount: known["post_payment_credit_notes_amount"],
      pre_payment_credit_notes_amount: known["pre_payment_credit_notes_amount"],
      quote: known["quote"],
      receipt_number: known["receipt_number"],
      rendering: known["rendering"],
      rendering_options: known["rendering_options"],
      shipping_cost: known["shipping_cost"],
      shipping_details: known["shipping_details"],
      starting_balance: known["starting_balance"],
      statement_descriptor: known["statement_descriptor"],
      status: atomize_status(known["status"]),
      status_transitions: StatusTransitions.from_map(known["status_transitions"]),
      subscription: known["subscription"],
      subscription_details: known["subscription_details"],
      subscription_proration_date: known["subscription_proration_date"],
      subtotal: known["subtotal"],
      subtotal_excluding_tax: known["subtotal_excluding_tax"],
      tax: known["tax"],
      test_clock: known["test_clock"],
      threshold_reason: known["threshold_reason"],
      total: known["total"],
      total_discount_amounts: known["total_discount_amounts"],
      total_excluding_tax: known["total_excluding_tax"],
      total_tax_amounts: known["total_tax_amounts"],
      transfer_data: known["transfer_data"],
      webhooks_delivered_at: known["webhooks_delivered_at"],
      deleted: known["deleted"] || false,
      extra: extra
    }
  end

  # ---------------------------------------------------------------------------
  # Private: atomization helpers (whitelist per D-14g)
  # ---------------------------------------------------------------------------

  # Invoice status values
  defp atomize_status("draft"), do: :draft
  defp atomize_status("open"), do: :open
  defp atomize_status("paid"), do: :paid
  defp atomize_status("void"), do: :void
  defp atomize_status("uncollectible"), do: :uncollectible
  defp atomize_status(other), do: other

  # Invoice collection_method values
  defp atomize_collection_method("charge_automatically"), do: :charge_automatically
  defp atomize_collection_method("send_invoice"), do: :send_invoice
  defp atomize_collection_method(other), do: other

  # Invoice billing_reason values
  defp atomize_billing_reason("subscription_cycle"), do: :subscription_cycle
  defp atomize_billing_reason("subscription_create"), do: :subscription_create
  defp atomize_billing_reason("subscription_update"), do: :subscription_update
  defp atomize_billing_reason("subscription_threshold"), do: :subscription_threshold
  defp atomize_billing_reason("subscription"), do: :subscription
  defp atomize_billing_reason("manual"), do: :manual
  defp atomize_billing_reason("upcoming"), do: :upcoming
  defp atomize_billing_reason(other), do: other

  # Invoice customer_tax_exempt values
  defp atomize_customer_tax_exempt("none"), do: :none
  defp atomize_customer_tax_exempt("exempt"), do: :exempt
  defp atomize_customer_tax_exempt("reverse"), do: :reverse
  defp atomize_customer_tax_exempt(other), do: other

  # ---------------------------------------------------------------------------
  # Private: nested struct parsers
  # ---------------------------------------------------------------------------

  # Parse lines: Stripe returns lines as an embedded List object with
  # "object" => "list". Parse it into a %List{} with typed %LineItem{} data.
  defp parse_lines(nil), do: nil

  defp parse_lines(%{"object" => "list"} = lines_map) do
    List.from_json(lines_map) |> Map.update!(:data, fn items ->
      Enum.map(items, &LineItem.from_map/1)
    end)
  end

  defp parse_lines(_), do: nil
end

defimpl Inspect, for: LatticeStripe.Invoice do
  import Inspect.Algebra

  def inspect(invoice, opts) do
    # Show key structural fields. Show extra only when non-empty to reduce noise.
    base_fields = [
      id: invoice.id,
      object: invoice.object,
      status: invoice.status,
      amount_due: invoice.amount_due,
      currency: invoice.currency,
      livemode: invoice.livemode
    ]

    fields =
      if invoice.extra == %{} do
        base_fields
      else
        base_fields ++ [extra: invoice.extra]
      end

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Invoice<" | pairs] ++ [">"])
  end
end
