defmodule LatticeStripe.Subscription do
  @moduledoc """
  Operations on Stripe Subscription objects.

  A Subscription represents a customer's recurring charge against one or more
  Prices. Subscriptions drive Stripe's billing engine: they create Invoices on
  schedule, handle proration when items change, and transition through a
  well-defined lifecycle.

  ## Lifecycle

  ```
  incomplete
       |
       v
  incomplete_expired        (if first payment fails permanently)
       |
  trialing --> active --> past_due --> unpaid
                 |           |
               paused       canceled
  ```

  State transitions are driven by Stripe's internal billing engine, not by
  SDK calls. **Always drive your application state from webhook events**, not
  from SDK responses — an SDK response reflects the state at the moment of the
  call, but Stripe may transition the subscription a moment later (trial
  ending, payment failing, dunning retries, scheduled cancellation, etc.).

  Wire `customer.subscription.updated`, `customer.subscription.deleted`,
  `invoice.payment_failed`, and `invoice.payment_succeeded` into your webhook
  handler via `LatticeStripe.Webhook`.

  ## Proration

  When changing a subscription's items (swapping a price, changing quantity,
  adding/removing items), Stripe prorates charges by default. If your client
  was configured with `require_explicit_proration: true`, you MUST pass
  `"proration_behavior"` either at the top level of `params`, inside
  `"subscription_details"`, or inside any element of the `"items"` array.

  Valid values: `"create_prorations"` (default), `"always_invoice"`, `"none"`.

  ## Pause collection

  Use `pause_collection/5` to temporarily pause automatic invoice collection.
  The `behavior` atom is guarded at the function head — only `:keep_as_draft`,
  `:mark_uncollectible`, and `:void` are accepted. Any other value raises
  `FunctionClauseError` at compile-time (for literals) or runtime.

  ## Telemetry

  Subscription CRUD piggybacks on the general `[:lattice_stripe, :request, *]`
  events emitted by `Client.request/2`. No subscription-specific telemetry
  events are emitted — subscription state transitions belong to webhook
  handlers, not the SDK layer.

  ## Stripe API Reference

  See the [Stripe Subscriptions API](https://docs.stripe.com/api/subscriptions)
  for the full object reference and available parameters.
  """

  alias LatticeStripe.{Billing, Client, Error, List, Request, Resource, Response}
  alias LatticeStripe.Invoice.AutomaticTax
  alias LatticeStripe.Subscription.{CancellationDetails, PauseCollection, TrialSettings}
  alias LatticeStripe.SubscriptionItem

  # Known top-level fields from the Stripe Subscription object.
  @known_fields ~w[
    id object application application_fee_percent automatic_tax billing_cycle_anchor
    billing_thresholds cancel_at cancel_at_period_end canceled_at cancellation_details
    collection_method created currency current_period_end current_period_start customer
    days_until_due default_payment_method default_source default_tax_rates description
    discount discounts ended_at invoice_settings items latest_invoice livemode metadata
    next_pending_invoice_item_interval on_behalf_of pause_collection payment_settings
    pending_invoice_item_interval pending_setup_intent pending_update plan quantity
    schedule start_date status test_clock transfer_data trial_end trial_settings trial_start
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :application,
    :application_fee_percent,
    :automatic_tax,
    :billing_cycle_anchor,
    :billing_thresholds,
    :cancel_at,
    :cancel_at_period_end,
    :canceled_at,
    :cancellation_details,
    :collection_method,
    :created,
    :currency,
    :current_period_end,
    :current_period_start,
    :customer,
    :days_until_due,
    :default_payment_method,
    :default_source,
    :default_tax_rates,
    :description,
    :discount,
    :discounts,
    :ended_at,
    :invoice_settings,
    :items,
    :latest_invoice,
    :livemode,
    :metadata,
    :next_pending_invoice_item_interval,
    :on_behalf_of,
    :pause_collection,
    :payment_settings,
    :pending_invoice_item_interval,
    :pending_setup_intent,
    :pending_update,
    :plan,
    :quantity,
    :schedule,
    :start_date,
    :status,
    :test_clock,
    :transfer_data,
    :trial_end,
    :trial_settings,
    :trial_start,
    object: "subscription",
    extra: %{}
  ]

  @typedoc """
  A Stripe Subscription object.

  See the [Stripe Subscription API](https://docs.stripe.com/api/subscriptions/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          application: String.t() | nil,
          application_fee_percent: number() | nil,
          automatic_tax: AutomaticTax.t() | nil,
          billing_cycle_anchor: integer() | nil,
          billing_thresholds: map() | nil,
          cancel_at: integer() | nil,
          cancel_at_period_end: boolean() | nil,
          canceled_at: integer() | nil,
          cancellation_details: CancellationDetails.t() | nil,
          collection_method: String.t() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          current_period_end: integer() | nil,
          current_period_start: integer() | nil,
          customer: String.t() | nil,
          days_until_due: integer() | nil,
          default_payment_method: String.t() | nil,
          default_source: String.t() | nil,
          default_tax_rates: list() | nil,
          description: String.t() | nil,
          discount: map() | nil,
          discounts: list() | nil,
          ended_at: integer() | nil,
          invoice_settings: map() | nil,
          items: [SubscriptionItem.t()] | map() | nil,
          latest_invoice: String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          next_pending_invoice_item_interval: map() | nil,
          on_behalf_of: String.t() | nil,
          pause_collection: PauseCollection.t() | nil,
          payment_settings: map() | nil,
          pending_invoice_item_interval: map() | nil,
          pending_setup_intent: String.t() | nil,
          pending_update: map() | nil,
          plan: map() | nil,
          quantity: integer() | nil,
          schedule: String.t() | nil,
          start_date: integer() | nil,
          status: String.t() | nil,
          test_clock: String.t() | nil,
          transfer_data: map() | nil,
          trial_end: integer() | nil,
          trial_settings: TrialSettings.t() | nil,
          trial_start: integer() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Subscription.

  Sends `POST /v1/subscriptions`. Runs the proration guard before dispatching.

  ## Parameters

  - `client` - `%LatticeStripe.Client{}`
  - `params` - Map of subscription attributes. Common keys:
    - `"customer"` - Customer ID (required)
    - `"items"` - List of `%{"price" => "price_..."}` maps
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Subscription{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure or guard rejection
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    with :ok <- Billing.Guards.check_proration_required(client, params) do
      %Request{method: :post, path: "/v1/subscriptions", params: params, opts: opts}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_singular(&from_map/1)
    end
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Retrieves a Subscription by ID.

  Sends `GET /v1/subscriptions/:id`.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/subscriptions/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id),
    do: client |> retrieve(id, opts) |> Resource.unwrap_bang!()

  @doc """
  Updates a Subscription by ID.

  Sends `POST /v1/subscriptions/:id`. Runs the proration guard before dispatching.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    with :ok <- Billing.Guards.check_proration_required(client, params) do
      %Request{method: :post, path: "/v1/subscriptions/#{id}", params: params, opts: opts}
      |> then(&Client.request(client, &1))
      |> Resource.unwrap_singular(&from_map/1)
    end
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id),
    do: client |> update(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Cancels a Subscription.

  Sends `DELETE /v1/subscriptions/:id` with optional pass-through params such
  as `"prorate"`, `"invoice_now"`, and `"cancellation_details"`.

  The 3-arity form is a convenience for `cancel(client, id, %{}, opts)`.
  """
  @spec cancel(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, opts \\ []) when is_binary(id) and is_list(opts),
    do: cancel(client, id, %{}, opts)

  @spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, params, opts)
      when is_binary(id) and is_map(params) and is_list(opts) do
    %Request{method: :delete, path: "/v1/subscriptions/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `cancel/3` but raises on failure."
  @spec cancel!(Client.t(), String.t(), keyword()) :: t()
  def cancel!(%Client{} = client, id, opts \\ []) when is_binary(id) and is_list(opts),
    do: client |> cancel(id, opts) |> Resource.unwrap_bang!()

  @doc "Like `cancel/4` but raises on failure."
  @spec cancel!(Client.t(), String.t(), map(), keyword()) :: t()
  def cancel!(%Client{} = client, id, params, opts)
      when is_binary(id) and is_map(params) and is_list(opts),
      do: client |> cancel(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Resumes a paused Subscription.

  Sends `POST /v1/subscriptions/:id/resume`.
  """
  @spec resume(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def resume(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/subscriptions/#{id}/resume", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `resume/3` but raises on failure."
  @spec resume!(Client.t(), String.t(), keyword()) :: t()
  def resume!(%Client{} = client, id, opts \\ []) when is_binary(id),
    do: client |> resume(id, opts) |> Resource.unwrap_bang!()

  @doc """
  Pauses collection on a Subscription.

  Dispatches to `update/4` with `"pause_collection"` merged into params. The
  `behavior` is a compile-time atom — only `:keep_as_draft`,
  `:mark_uncollectible`, and `:void` are accepted. Any other atom raises
  `FunctionClauseError`.

  ## Example

      Subscription.pause_collection(client, "sub_123", :keep_as_draft)

      # With custom resumes_at:
      Subscription.pause_collection(client, "sub_123", :void, %{
        "pause_collection" => %{"resumes_at" => 1_800_000_000}
      })

  Note: Stripe has no dedicated pause endpoint — this helper is a thin wrapper
  around `update/4`. We expose it under the exact field name (`pause_collection`)
  rather than a generic `pause/4` so IDE autocomplete and Stripe docs align.
  """
  @spec pause_collection(Client.t(), String.t(), atom(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def pause_collection(%Client{} = client, id, behavior, params \\ %{}, opts \\ [])
      when is_binary(id) and behavior in [:keep_as_draft, :mark_uncollectible, :void] do
    existing = Map.get(params, "pause_collection", %{})
    merged_pause = Map.put(existing, "behavior", Atom.to_string(behavior))
    merged = Map.put(params, "pause_collection", merged_pause)
    update(client, id, merged, opts)
  end

  @doc "Like `pause_collection/5` but raises on failure."
  @spec pause_collection!(Client.t(), String.t(), atom(), map(), keyword()) :: t()
  def pause_collection!(%Client{} = client, id, behavior, params \\ %{}, opts \\ [])
      when is_binary(id) and behavior in [:keep_as_draft, :mark_uncollectible, :void],
      do:
        client
        |> pause_collection(id, behavior, params, opts)
        |> Resource.unwrap_bang!()

  @doc """
  Lists Subscriptions with optional filters.

  Sends `GET /v1/subscriptions`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/subscriptions", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of all Subscriptions matching the given params.

  Auto-paginates via `LatticeStripe.List.stream!/2`. Raises on fetch failure.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/subscriptions", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Searches Subscriptions.

  Sends `GET /v1/subscriptions/search`. Requires `"query"` in params.

  > #### Eventual Consistency {: .warning}
  >
  > Search results may not reflect changes made within the last ~1 second.
  """
  @spec search(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def search(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(
      params,
      "query",
      ~s|Subscription.search/3 requires a "query" key in params. Example: %{"query" => "status:'active'"}|
    )

    %Request{method: :get, path: "/v1/subscriptions/search", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `search/3` but raises on failure."
  @spec search!(Client.t(), map(), keyword()) :: Response.t()
  def search!(%Client{} = client, params, opts \\ []),
    do: client |> search(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of all Subscriptions matching a search query.

  Requires `"query"` in params. Raises on fetch failure.
  """
  @spec search_stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def search_stream!(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(
      params,
      "query",
      ~s|Subscription.search_stream!/3 requires a "query" key in params.|
    )

    req = %Request{method: :get, path: "/v1/subscriptions/search", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Subscription{}` struct.

  Decodes nested typed structs:
  - `automatic_tax` → `%LatticeStripe.Invoice.AutomaticTax{}`
  - `pause_collection` → `%LatticeStripe.Subscription.PauseCollection{}`
  - `cancellation_details` → `%LatticeStripe.Subscription.CancellationDetails{}`
  - `trial_settings` → `%LatticeStripe.Subscription.TrialSettings{}`
  - `items.data` → `[%LatticeStripe.SubscriptionItem{}]` (id preserved — regression guard against stripity_stripe #208)

  Unknown top-level fields are collected into `:extra`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "subscription",
      application: known["application"],
      application_fee_percent: known["application_fee_percent"],
      automatic_tax: AutomaticTax.from_map(known["automatic_tax"]),
      billing_cycle_anchor: known["billing_cycle_anchor"],
      billing_thresholds: known["billing_thresholds"],
      cancel_at: known["cancel_at"],
      cancel_at_period_end: known["cancel_at_period_end"],
      canceled_at: known["canceled_at"],
      cancellation_details: CancellationDetails.from_map(known["cancellation_details"]),
      collection_method: known["collection_method"],
      created: known["created"],
      currency: known["currency"],
      current_period_end: known["current_period_end"],
      current_period_start: known["current_period_start"],
      customer: known["customer"],
      days_until_due: known["days_until_due"],
      default_payment_method: known["default_payment_method"],
      default_source: known["default_source"],
      default_tax_rates: known["default_tax_rates"],
      description: known["description"],
      discount: known["discount"],
      discounts: known["discounts"],
      ended_at: known["ended_at"],
      invoice_settings: known["invoice_settings"],
      items: decode_items(known["items"]),
      latest_invoice: known["latest_invoice"],
      livemode: known["livemode"],
      metadata: known["metadata"],
      next_pending_invoice_item_interval: known["next_pending_invoice_item_interval"],
      on_behalf_of: known["on_behalf_of"],
      pause_collection: PauseCollection.from_map(known["pause_collection"]),
      payment_settings: known["payment_settings"],
      pending_invoice_item_interval: known["pending_invoice_item_interval"],
      pending_setup_intent: known["pending_setup_intent"],
      pending_update: known["pending_update"],
      plan: known["plan"],
      quantity: known["quantity"],
      schedule: known["schedule"],
      start_date: known["start_date"],
      status: known["status"],
      test_clock: known["test_clock"],
      transfer_data: known["transfer_data"],
      trial_end: known["trial_end"],
      trial_settings: TrialSettings.from_map(known["trial_settings"]),
      trial_start: known["trial_start"],
      extra: extra
    }
  end

  # Decode items field. Stripe returns `{"object" => "list", "data" => [...]}`.
  # Decode each element via SubscriptionItem.from_map/1 so `id` is preserved
  # (regression guard against stripity_stripe's well-known missing-id bug).
  defp decode_items(nil), do: nil

  defp decode_items(%{"object" => "list", "data" => data} = list) when is_list(data) do
    Map.put(list, "data", Enum.map(data, &SubscriptionItem.from_map/1))
  end

  defp decode_items(other), do: other
end

defimpl Inspect, for: LatticeStripe.Subscription do
  import Inspect.Algebra

  def inspect(sub, opts) do
    # Hide PII: customer, payment_settings, default_payment_method, latest_invoice.
    # Show only presence markers or safe structural fields.
    base = [
      id: sub.id,
      object: sub.object,
      status: sub.status,
      current_period_end: sub.current_period_end,
      livemode: sub.livemode,
      has_customer?: not is_nil(sub.customer),
      has_payment_settings?: not is_nil(sub.payment_settings),
      has_default_payment_method?: not is_nil(sub.default_payment_method),
      has_latest_invoice?: not is_nil(sub.latest_invoice)
    ]

    fields = if sub.extra == %{}, do: base, else: base ++ [extra: sub.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Subscription<" | pairs] ++ [">"])
  end
end
