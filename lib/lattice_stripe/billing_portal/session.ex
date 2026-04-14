defmodule LatticeStripe.BillingPortal.Session do
  @moduledoc """
  Operations on Stripe Billing Portal Session objects.

  The Stripe Customer Portal is a hosted UI that lets customers manage their
  subscriptions and billing details — update payment methods, cancel or change
  subscriptions, download invoices, and update billing information. Your app
  creates a portal session and redirects the customer to the returned URL;
  Stripe handles the rest and redirects back to your `return_url` when the
  customer is done.

  ## Creating a portal session

  `create/3` is the only operation exposed by the Stripe API — portal sessions
  cannot be retrieved, listed, updated, or deleted.

  The `"customer"` param is required. All other params are optional:

  - `"return_url"` — URL to redirect the customer after they are done in the portal.
    Should be an absolute HTTPS URL you control.
  - `"flow_data"` — Deep-links the customer into a specific flow instead of the
    default portal homepage. See `LatticeStripe.BillingPortal.Session.FlowData`
    for the full schema and per-flow required sub-fields.
  - `"configuration"` — A `bpc_*` Billing Portal configuration ID. In v1.1,
    portal configuration is managed via the Stripe Dashboard;
    `LatticeStripe.BillingPortal.Configuration` is planned for v1.2+.
  - `"locale"` — Override the portal language (e.g. `"en"`, `"fr"`, `"auto"`).
  - `"on_behalf_of"` — Connect account ID when creating a portal session for a
    connected account. See the `stripe_account:` opt for per-request Connect routing.

  ## Flow types (deep-link into a specific portal view)

  The `"flow_data"` param accepts four `"type"` values:

  - `"subscription_cancel"` — requires `flow_data.subscription_cancel.subscription`
  - `"subscription_update"` — requires `flow_data.subscription_update.subscription`
  - `"subscription_update_confirm"` — requires `flow_data.subscription_update_confirm.subscription`
    AND `flow_data.subscription_update_confirm.items` (non-empty list)
  - `"payment_method_update"` — no required sub-fields

  `LatticeStripe.BillingPortal.Guards` validates these shapes pre-network and raises
  `ArgumentError` with an actionable message if required sub-fields are missing.
  See `LatticeStripe.BillingPortal.Session.FlowData` for the full nested struct schema.

  ## Examples

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Basic portal session (customer lands on default portal homepage)
      {:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
        "customer" => "cus_123",
        "return_url" => "https://example.com/account"
      })
      redirect_to(conn, session.url)

      # Deep-link into subscription cancellation flow
      {:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
        "customer" => "cus_123",
        "return_url" => "https://example.com/account",
        "flow_data" => %{
          "type" => "subscription_cancel",
          "subscription_cancel" => %{"subscription" => "sub_abc"}
        }
      })

      # Deep-link into payment method update flow
      {:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
        "customer" => "cus_123",
        "flow_data" => %{"type" => "payment_method_update"}
      })

      # Connect platform: create a portal session on behalf of a connected account
      {:ok, session} = LatticeStripe.BillingPortal.Session.create(
        client,
        %{"customer" => "cus_123"},
        stripe_account: "acct_connect_123"
      )

  ## Security note — the `:url` field

  `session.url` is a single-use, short-lived (~5 minutes) authenticated redirect
  that grants the customer full access to their portal session. It is a bearer
  credential for the portal scope — treat it like a password.

  LatticeStripe masks `:url` (and `:flow`) from default `Inspect` output to prevent
  accidental leaks via `Logger`, APM agents, crash dumps, or telemetry handlers.
  Access the URL directly when redirecting: `session.url`.

  To inspect all fields including `:url` and `:flow` during debugging:

      IO.inspect(session, structs: false)
      # or access directly:
      session.url
      session.flow

  ## Portal configuration

  Portal configuration (branding, allowed features, default behavior) is managed
  via the Stripe Dashboard in v1.1. `LatticeStripe.BillingPortal.Configuration`
  is planned for v1.2+. Pass a `bpc_*` configuration ID in `params["configuration"]`
  to select a specific portal configuration at session creation time.

  ## Stripe API Reference

  See the [Stripe Billing Portal Session API](https://docs.stripe.com/api/customer_portal/sessions)
  for the full object reference and available parameters.
  """

  alias LatticeStripe.BillingPortal.Guards
  alias LatticeStripe.BillingPortal.Session.FlowData
  alias LatticeStripe.{Client, Request, Resource}

  @known_fields ~w(id object customer url return_url created livemode locale configuration on_behalf_of flow)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          customer: String.t() | nil,
          url: String.t() | nil,
          return_url: String.t() | nil,
          created: integer() | nil,
          livemode: boolean() | nil,
          locale: String.t() | nil,
          configuration: String.t() | nil,
          on_behalf_of: String.t() | nil,
          flow: FlowData.t() | nil,
          extra: map()
        }

  defstruct [
    :id,
    :object,
    :customer,
    :url,
    :return_url,
    :created,
    :livemode,
    :locale,
    :configuration,
    :on_behalf_of,
    :flow,
    extra: %{}
  ]

  @doc """
  Create a Stripe Billing Portal Session.

  Returns `{:ok, %Session{url: url}}` on success. The `url` is a single-use,
  short-lived (~5 minutes) authenticated redirect — redirect the customer to it
  immediately. Do not cache or log it.

  ## Required params

  - `"customer"` — The Stripe customer ID (`cus_*`) whose portal session to create.

  ## Optional params

  - `"return_url"` — Absolute HTTPS URL to redirect the customer after the portal session.
  - `"flow_data"` — Deep-link into a specific flow. See module docs for flow type details.
    Omit to render the default portal homepage.
  - `"configuration"` — Billing Portal configuration ID (`bpc_*`). Defaults to the
    account default configured in the Stripe Dashboard.
  - `"locale"` — Portal language override (`"en"`, `"fr"`, `"auto"`, etc.).
  - `"on_behalf_of"` — Connect account ID for platform-to-connected-account sessions.

  ## Options

  - `stripe_account:` — Connect per-request account routing. Adds `Stripe-Account` header.

  ## Examples

      {:ok, session} = Session.create(client, %{
        "customer" => "cus_123",
        "return_url" => "https://example.com/account"
      })

      # With flow deep-link
      {:ok, session} = Session.create(client, %{
        "customer" => "cus_123",
        "flow_data" => %{
          "type" => "subscription_cancel",
          "subscription_cancel" => %{"subscription" => "sub_abc"}
        }
      })

      # Connect platform routing
      {:ok, session} = Session.create(client, %{"customer" => "cus_123"},
        stripe_account: "acct_connect_123"
      )

  ## Raises

  - `ArgumentError` — immediately (pre-network) when `"customer"` is missing
  - `ArgumentError` — immediately (pre-network) when `"flow_data"` is present but
    has an unknown `"type"` or is missing required sub-fields

  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(
      params,
      "customer",
      "LatticeStripe.BillingPortal.Session.create/3 requires a customer param"
    )

    Guards.check_flow_data!(params)

    %Request{method: :post, path: "/v1/billing_portal/sessions", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Bang variant of `create/3`. Returns `%Session{}` on success, raises
  `LatticeStripe.Error` on API failure.
  """
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%Session{}`.

  The `"flow"` sub-object is decoded into `%FlowData{}` via `FlowData.from_map/1`.
  Unknown top-level keys land in `:extra`.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      customer: map["customer"],
      url: map["url"],
      return_url: map["return_url"],
      created: map["created"],
      livemode: map["livemode"],
      locale: map["locale"],
      configuration: map["configuration"],
      on_behalf_of: map["on_behalf_of"],
      flow: FlowData.from_map(map["flow"]),
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.BillingPortal.Session do
  import Inspect.Algebra

  def inspect(session, opts) do
    # Allowlist structural + routing fields only. Hide:
    #
    #   :url  — short-lived (~5 min), single-use authenticated redirect
    #           that impersonates the customer for the portal session.
    #           Leaks via Logger, APM, crash dumps, or telemetry handlers
    #           are an account-takeover vector within the TTL window.
    #           This is the asset Phase 21 SC #4 protects.
    #
    #   :flow — nested %FlowData{} sub-object. Hidden to keep Inspect
    #           output a structural one-liner (matches Customer /
    #           MeterEvent / Checkout.Session shape) and to avoid
    #           surfacing flow-specific redirect/confirmation data
    #           field-by-field. Access directly via `session.flow`
    #           when debugging flow_data deep links.
    #
    # Debugging escape hatch — see every field including :url and :flow:
    #
    #     IO.inspect(session, structs: false)
    #     # or
    #     session.url
    #     session.flow
    #
    # Precedent: Customer (lib/lattice_stripe/customer.ex),
    # MeterEvent (lib/lattice_stripe/billing/meter_event.ex),
    # Checkout.Session (lib/lattice_stripe/checkout/session.ex) —
    # all three allowlist structural fields and hide the sensitive
    # surface. Checkout.Session already hides its own :url, establishing
    # the "Stripe session URLs are uniformly masked" SDK invariant.
    fields = [
      id: session.id,
      object: session.object,
      livemode: session.livemode,
      customer: session.customer,
      configuration: session.configuration,
      on_behalf_of: session.on_behalf_of,
      created: session.created,
      return_url: session.return_url,
      locale: session.locale
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.BillingPortal.Session<" | pairs] ++ [">"])
  end
end
