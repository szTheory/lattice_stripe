defmodule LatticeStripe.Checkout.Session do
  @moduledoc """
  Operations on Stripe Checkout Session objects.

  Checkout Sessions represent a one-time payment page hosted by Stripe. They support
  three modes:

  - **payment** — one-time payment with line items
  - **subscription** — recurring payment linked to a subscription
  - **setup** — collect payment method details without charging

  ## Key behaviors

  - The `mode` parameter is required when creating a session — an `ArgumentError` is
    raised immediately (pre-network) if it is missing.
  - Checkout Sessions cannot be updated after creation. Use `expire/4` to cancel
    an open session.
  - Some fields can be modified via the Stripe Dashboard but not through the API.
  - The `client_secret` field is hidden from `Inspect` output for security.
  - PII fields (`customer_email`, `customer_details`, `shipping_details`) are hidden
    from `Inspect` output.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a payment mode session
      {:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
        "mode" => "payment",
        "success_url" => "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
        "cancel_url" => "https://example.com/cancel",
        "line_items" => [%{"price" => "price_...", "quantity" => 1}]
      })

      # Create a subscription mode session
      {:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
        "mode" => "subscription",
        "success_url" => "https://example.com/success",
        "line_items" => [%{"price" => "price_monthly_...", "quantity" => 1}]
      })

      # Create a setup mode session (collect payment method, no charge)
      {:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
        "mode" => "setup",
        "success_url" => "https://example.com/success",
        "customer" => "cus_..."
      })

      # Retrieve a session
      {:ok, session} = LatticeStripe.Checkout.Session.retrieve(client, session.id)

      # Expire an open session
      {:ok, expired} = LatticeStripe.Checkout.Session.expire(client, session.id)

      # List line items
      {:ok, resp} = LatticeStripe.Checkout.Session.list_line_items(client, session.id)
      items = resp.data.data  # [%LineItem{}, ...]

      # Stream all sessions lazily
      client
      |> LatticeStripe.Checkout.Session.stream!()
      |> Stream.take(100)
      |> Enum.each(&process_session/1)

  ## Stripe API Reference

  See the [Stripe Checkout Session API](https://docs.stripe.com/api/checkout/sessions) for
  the full object reference and available parameters.
  """

  alias LatticeStripe.Checkout.LineItem
  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe Checkout Session object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object adaptive_pricing after_expiration allow_promotion_codes amount_subtotal
    amount_total automatic_tax billing_address_collection cancel_url client_reference_id
    client_secret consent consent_collection created currency currency_conversion
    custom_fields custom_text customer customer_creation customer_details customer_email
    discounts expires_at invoice invoice_creation line_items livemode locale metadata
    mode payment_intent payment_link payment_method_collection
    payment_method_configuration_details payment_method_options payment_method_types
    payment_status phone_number_collection recovered_from redirect_on_completion
    return_url setup_intent shipping_address_collection shipping_cost shipping_details
    shipping_options status submit_type subscription success_url tax_id_collection
    total_details ui_mode url
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :adaptive_pricing,
    :after_expiration,
    :allow_promotion_codes,
    :amount_subtotal,
    :amount_total,
    :automatic_tax,
    :billing_address_collection,
    :cancel_url,
    :client_reference_id,
    :client_secret,
    :consent,
    :consent_collection,
    :created,
    :currency,
    :currency_conversion,
    :custom_fields,
    :custom_text,
    :customer,
    :customer_creation,
    :customer_details,
    :customer_email,
    :discounts,
    :expires_at,
    :invoice,
    :invoice_creation,
    :line_items,
    :livemode,
    :locale,
    :metadata,
    :mode,
    :payment_intent,
    :payment_link,
    :payment_method_collection,
    :payment_method_configuration_details,
    :payment_method_options,
    :payment_method_types,
    :payment_status,
    :phone_number_collection,
    :recovered_from,
    :redirect_on_completion,
    :return_url,
    :setup_intent,
    :shipping_address_collection,
    :shipping_cost,
    :shipping_details,
    :shipping_options,
    :status,
    :submit_type,
    :subscription,
    :success_url,
    :tax_id_collection,
    :total_details,
    :ui_mode,
    :url,
    object: "checkout.session",
    extra: %{}
  ]

  @typedoc """
  A Stripe Checkout Session object.

  See the [Stripe Checkout Session API](https://docs.stripe.com/api/checkout/sessions/object) for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          adaptive_pricing: map() | nil,
          after_expiration: map() | nil,
          allow_promotion_codes: boolean() | nil,
          amount_subtotal: integer() | nil,
          amount_total: integer() | nil,
          automatic_tax: map() | nil,
          billing_address_collection: String.t() | nil,
          cancel_url: String.t() | nil,
          client_reference_id: String.t() | nil,
          client_secret: String.t() | nil,
          consent: map() | nil,
          consent_collection: map() | nil,
          created: integer() | nil,
          currency: String.t() | nil,
          currency_conversion: map() | nil,
          custom_fields: [map()] | nil,
          custom_text: map() | nil,
          customer: String.t() | nil,
          customer_creation: String.t() | nil,
          customer_details: map() | nil,
          customer_email: String.t() | nil,
          discounts: [map()] | nil,
          expires_at: integer() | nil,
          invoice: String.t() | nil,
          invoice_creation: map() | nil,
          line_items: map() | nil,
          livemode: boolean() | nil,
          locale: String.t() | nil,
          metadata: map() | nil,
          mode: String.t() | nil,
          payment_intent: String.t() | nil,
          payment_link: String.t() | nil,
          payment_method_collection: String.t() | nil,
          payment_method_configuration_details: map() | nil,
          payment_method_options: map() | nil,
          payment_method_types: [String.t()] | nil,
          payment_status: String.t() | nil,
          phone_number_collection: map() | nil,
          recovered_from: String.t() | nil,
          redirect_on_completion: String.t() | nil,
          return_url: String.t() | nil,
          setup_intent: String.t() | nil,
          shipping_address_collection: map() | nil,
          shipping_cost: map() | nil,
          shipping_details: map() | nil,
          shipping_options: [map()] | nil,
          status: String.t() | nil,
          submit_type: String.t() | nil,
          subscription: String.t() | nil,
          success_url: String.t() | nil,
          tax_id_collection: map() | nil,
          total_details: map() | nil,
          ui_mode: String.t() | nil,
          url: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: Core operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Checkout Session.

  Sends `POST /v1/checkout/sessions` with the given params and returns
  `{:ok, %Checkout.Session{}}`. The `mode` param is required — an `ArgumentError`
  is raised immediately (before any network call) if it is missing.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of session attributes. **Required:** `"mode"` (`"payment"`, `"subscription"`, or `"setup"`).
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Checkout.Session{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Notes

  - For `"payment"` and `"subscription"` modes, `"success_url"` is typically required.
  - For embedded mode sessions (`ui_mode: "embedded"`), use `"return_url"` instead.
  - The hosted Checkout page URL is in `session.url`.

  ## Examples

      # Payment mode
      {:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
        "mode" => "payment",
        "success_url" => "https://example.com/success",
        "cancel_url" => "https://example.com/cancel",
        "line_items" => [%{"price" => "price_...", "quantity" => 1}]
      })

      # Subscription mode
      {:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
        "mode" => "subscription",
        "success_url" => "https://example.com/success",
        "line_items" => [%{"price" => "price_monthly_...", "quantity" => 1}]
      })

      # Setup mode (collect payment method, no charge)
      {:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
        "mode" => "setup",
        "success_url" => "https://example.com/success",
        "customer" => "cus_..."
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    Resource.require_param!(
      params,
      "mode",
      ~s|Checkout.Session.create/3 requires a "mode" key in params. Valid values: "payment", "subscription", "setup". Example: %{"mode" => "payment", "success_url" => "https://..."}|
    )

    %Request{method: :post, path: "/v1/checkout/sessions", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a Checkout Session by ID.

  Sends `GET /v1/checkout/sessions/:id` and returns `{:ok, %Checkout.Session{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The session ID string (e.g., `"cs_..."`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Checkout.Session{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/checkout/sessions/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists Checkout Sessions with optional filters.

  Sends `GET /v1/checkout/sessions` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%Checkout.Session{}` items. All params are optional.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "20", "customer" => "cus_..."}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Checkout.Session{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/checkout/sessions", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Expires an open Checkout Session.

  Sends `POST /v1/checkout/sessions/:id/expire` and returns `{:ok, %Checkout.Session{status: "expired"}}`.
  Only sessions with `status: "open"` can be expired.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The session ID string
  - `params` - Optional params (typically empty `%{}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Checkout.Session{status: "expired"}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, session} = LatticeStripe.Checkout.Session.expire(client, "cs_...")
  """
  @spec expire(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def expire(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{
      method: :post,
      path: "/v1/checkout/sessions/#{id}/expire",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Searches Checkout Sessions using Stripe's search query language.

  Sends `GET /v1/checkout/sessions/search` with the query string and returns typed results.
  Note: search results have eventual consistency — newly created sessions may not
  appear immediately.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string (e.g., `"status:'open'"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Checkout.Session{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.Checkout.Session.search(client, "status:'open'")
  """
  @spec search(Client.t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
    %Request{
      method: :get,
      path: "/v1/checkout/sessions/search",
      params: %{"query" => query},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all Checkout Sessions matching the given params (auto-pagination).

  Emits individual `%Checkout.Session{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Checkout.Session{}` structs.

  ## Example

      client
      |> LatticeStripe.Checkout.Session.stream!()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/checkout/sessions", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Returns a lazy stream of Checkout Sessions matching the search query (auto-pagination).

  Emits individual `%Checkout.Session{}` structs, fetching additional search pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `query` - Stripe search query string
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Checkout.Session{}` structs.
  """
  @spec search_stream!(Client.t(), String.t(), keyword()) :: Enumerable.t()
  def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    req = %Request{
      method: :get,
      path: "/v1/checkout/sessions/search",
      params: %{"query" => query},
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Lists the line items for a Checkout Session.

  Sends `GET /v1/checkout/sessions/:session_id/line_items` and returns typed
  `%LineItem{}` items in the list.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `session_id` - The session ID string (e.g., `"cs_..."`)
  - `params` - Filter params (e.g., `%{"limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%LineItem{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.Checkout.Session.list_line_items(client, "cs_...")
      items = resp.data.data  # [%LineItem{}, ...]
  """
  @spec list_line_items(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list_line_items(%Client{} = client, session_id, params \\ %{}, opts \\ [])
      when is_binary(session_id) do
    %Request{
      method: :get,
      path: "/v1/checkout/sessions/#{session_id}/line_items",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&LineItem.from_map/1)
  end

  @doc """
  Returns a lazy stream of line items for a Checkout Session (auto-pagination).

  Emits individual `%LineItem{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `session_id` - The session ID string
  - `params` - Filter params
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%LineItem{}` structs.
  """
  @spec stream_line_items!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream_line_items!(%Client{} = client, session_id, params \\ %{}, opts \\ [])
      when is_binary(session_id) do
    req = %Request{
      method: :get,
      path: "/v1/checkout/sessions/#{session_id}/line_items",
      params: params,
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&LineItem.from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc """
  Like `create/3` but raises `LatticeStripe.Error` on failure.
  Also raises `ArgumentError` when `mode` param is missing.
  """
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `expire/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec expire!(Client.t(), String.t(), map(), keyword()) :: t()
  def expire!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    expire(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `search/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec search!(Client.t(), String.t(), keyword()) :: Response.t()
  def search!(%Client{} = client, query, opts \\ []) when is_binary(query) do
    search(client, query, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `list_line_items/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec list_line_items!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list_line_items!(%Client{} = client, session_id, params \\ %{}, opts \\ [])
      when is_binary(session_id) do
    list_line_items(client, session_id, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Checkout.Session{}` struct.

  Maps all known Stripe Checkout Session fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  ## Example

      session = LatticeStripe.Checkout.Session.from_map(%{
        "id" => "cs_...",
        "object" => "checkout.session",
        "mode" => "payment",
        "status" => "open"
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "checkout.session",
      adaptive_pricing: map["adaptive_pricing"],
      after_expiration: map["after_expiration"],
      allow_promotion_codes: map["allow_promotion_codes"],
      amount_subtotal: map["amount_subtotal"],
      amount_total: map["amount_total"],
      automatic_tax: map["automatic_tax"],
      billing_address_collection: map["billing_address_collection"],
      cancel_url: map["cancel_url"],
      client_reference_id: map["client_reference_id"],
      client_secret: map["client_secret"],
      consent: map["consent"],
      consent_collection: map["consent_collection"],
      created: map["created"],
      currency: map["currency"],
      currency_conversion: map["currency_conversion"],
      custom_fields: map["custom_fields"],
      custom_text: map["custom_text"],
      customer: map["customer"],
      customer_creation: map["customer_creation"],
      customer_details: map["customer_details"],
      customer_email: map["customer_email"],
      discounts: map["discounts"],
      expires_at: map["expires_at"],
      invoice: map["invoice"],
      invoice_creation: map["invoice_creation"],
      line_items: map["line_items"],
      livemode: map["livemode"],
      locale: map["locale"],
      metadata: map["metadata"],
      mode: map["mode"],
      payment_intent: map["payment_intent"],
      payment_link: map["payment_link"],
      payment_method_collection: map["payment_method_collection"],
      payment_method_configuration_details: map["payment_method_configuration_details"],
      payment_method_options: map["payment_method_options"],
      payment_method_types: map["payment_method_types"],
      payment_status: map["payment_status"],
      phone_number_collection: map["phone_number_collection"],
      recovered_from: map["recovered_from"],
      redirect_on_completion: map["redirect_on_completion"],
      return_url: map["return_url"],
      setup_intent: map["setup_intent"],
      shipping_address_collection: map["shipping_address_collection"],
      shipping_cost: map["shipping_cost"],
      shipping_details: map["shipping_details"],
      shipping_options: map["shipping_options"],
      status: map["status"],
      submit_type: map["submit_type"],
      subscription: map["subscription"],
      success_url: map["success_url"],
      tax_id_collection: map["tax_id_collection"],
      total_details: map["total_details"],
      ui_mode: map["ui_mode"],
      url: map["url"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.Checkout.Session do
  import Inspect.Algebra

  def inspect(session, opts) do
    # Show only non-PII structural fields.
    # Hide: customer_email, customer_details, shipping_details (PII),
    # and client_secret (sensitive credential for embedded mode).
    fields = [
      id: session.id,
      object: session.object,
      mode: session.mode,
      status: session.status,
      payment_status: session.payment_status,
      amount_total: session.amount_total,
      currency: session.currency
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Checkout.Session<" | pairs] ++ [">"])
  end
end
