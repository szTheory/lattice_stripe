# Customer Portal

The Stripe Customer Portal is a Stripe-hosted UI for customer self-service billing:
updating payment methods, canceling or changing subscriptions, downloading invoices.
Your application creates a portal session and redirects the customer to `session.url`;
Stripe handles the interface and redirects back to your `return_url` when they finish.

## What the Customer Portal is

The portal is a Stripe-hosted page — you create a session and redirect. Four deep-link
flow types bypass the homepage and drop the customer into a specific task:
`subscription_cancel`, `subscription_update`, `subscription_update_confirm`, and
`payment_method_update`. Omit `flow_data` entirely to show the default portal homepage.

## Quickstart

Call `Session.create/3` with a customer ID and a `return_url`, then redirect to `session.url`:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
  finch: MyApp.Finch
)

{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => "cus_abc123",
    "return_url" => "https://example.com/account"
  })

# Redirect the customer to the hosted portal immediately.
# Do not log or cache session.url — it is a single-use bearer credential.
redirect(conn, external: session.url)
```

Omitting `flow_data` sends the customer to the portal homepage, where Stripe renders
whichever features your portal configuration (set via the Stripe Dashboard) allows.

The `"customer"` param is required. All other params are optional:

- `"return_url"` — Absolute HTTPS URL to redirect the customer after the portal.
- `"flow_data"` — Deep-link into a specific portal flow (see §Deep-link flows below).
- `"configuration"` — A `bpc_*` portal configuration ID. Defaults to the account
  default. Portal configuration is managed via the Stripe Dashboard in v1.1.
- `"locale"` — Override the portal language (`"en"`, `"fr"`, `"auto"`, etc.).
- `"on_behalf_of"` — Connect account ID for platform-to-connected-account sessions.

## Deep-link flows

Pass `"flow_data"` with a `"type"` key to bypass the portal homepage and take the
customer directly into a specific task. Each flow type has its own required sub-fields,
validated pre-network by a pre-flight guard module.

See `LatticeStripe.BillingPortal.Session.FlowData` for the full nested struct schema
returned on the session response.

### Updating a payment method

The `"payment_method_update"` flow takes the customer directly to a page where they
can add or replace their default payment method. No sub-fields are required:

```elixir
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => customer_id,
    "return_url" => "https://example.com/account",
    "flow_data" => %{"type" => "payment_method_update"}
  })
```

This is the simplest flow — useful after a failed payment when you want to
direct the customer straight to the payment update page.

### Canceling a subscription

The `"subscription_cancel"` flow requires the subscription ID to cancel:

```elixir
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => customer_id,
    "return_url" => "https://example.com/account",
    "flow_data" => %{
      "type" => "subscription_cancel",
      "subscription_cancel" => %{"subscription" => sub_id}
    }
  })
```

Missing `subscription_cancel.subscription` raises `ArgumentError` immediately
(pre-network), with a message naming the missing field path.

When the customer cancels through the portal, Stripe fires
`customer.subscription.deleted` (or `customer.subscription.updated` if canceling
at period end). Drive your application state from that webhook event, not from the
portal redirect. See [Subscriptions — Lifecycle operations](subscriptions.html#lifecycle-operations)
for the full lifecycle event table.

### Updating a subscription

The `"subscription_update"` flow opens the subscription change UI for the given
subscription. The customer can swap plan, change quantity, or add/remove items:

```elixir
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => customer_id,
    "return_url" => "https://example.com/account",
    "flow_data" => %{
      "type" => "subscription_update",
      "subscription_update" => %{"subscription" => sub_id}
    }
  })
```

Missing `subscription_update.subscription` raises `ArgumentError` immediately.

Portal subscription updates are subject to the same proration logic as SDK-driven
updates. See [Subscriptions — Proration](subscriptions.html#proration) for how
to control proration behavior. State changes from portal updates fire
`customer.subscription.updated` webhooks — do not rely on the return URL redirect
as the authoritative signal.

### Confirming a subscription update

The `"subscription_update_confirm"` flow presents the customer with a preview and
confirmation step for a pending plan change. This flow requires both a subscription
ID and a non-empty items list:

```elixir
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => customer_id,
    "return_url" => "https://example.com/account",
    "flow_data" => %{
      "type" => "subscription_update_confirm",
      "subscription_update_confirm" => %{
        "subscription" => sub_id,
        "items" => [
          %{"id" => subscription_item_id, "price" => new_price_id}
        ]
      }
    }
  })
```

Missing `subscription_update_confirm.subscription` OR an empty `items` list raises
`ArgumentError` immediately, naming the missing field path (`subscription AND .items`).

## End-to-end Phoenix example

Here is an Accrue-style wrapper that handles the common case: look up the Stripe
customer for the logged-in user, create a portal session, and redirect.

```elixir
defmodule MyApp.Billing do
  @doc """
  Creates a portal session URL for `user` and returns `{:ok, url}`.

  `return_to` is an absolute HTTPS path the customer is redirected to after
  the portal session ends (e.g. `Routes.account_path(conn, :index)`).
  """
  def portal_url(user, return_to) do
    client = MyApp.StripeClient.get()

    with {:ok, session} <-
           LatticeStripe.BillingPortal.Session.create(client, %{
             "customer" => user.stripe_customer_id,
             "return_url" => return_to
           }) do
      {:ok, session.url}
    end
  end
end
```

And the controller:

```elixir
defmodule MyAppWeb.BillingController do
  use MyAppWeb, :controller

  def portal(conn, _params) do
    return_to = Routes.account_url(conn, :index)

    case MyApp.Billing.portal_url(conn.assigns.current_user, return_to) do
      {:ok, url} ->
        redirect(conn, external: url)

      {:error, %LatticeStripe.Error{} = err} ->
        conn
        |> put_flash(:error, "Could not open billing portal: #{err.message}")
        |> redirect(to: Routes.account_path(conn, :index))
    end
  end

  def return(conn, _params) do
    # The customer has returned from the portal. Re-verify subscription state
    # server-side — the portal redirect is NOT authentication and does NOT
    # guarantee any state change occurred. Drive your application state from
    # webhook events, not from this redirect.
    conn
    |> put_flash(:info, "Your billing settings have been updated.")
    |> redirect(to: Routes.account_path(conn, :index))
  end
end
```

## Security and session lifetime

`session.url` is a single-use, short-lived (~5 minutes) authenticated redirect. It
grants the customer full access to their portal session — treat it like a password.

**Never log or persist `session.url`.** Any log line, APM trace, crash dump, or
telemetry handler that captures it creates an account-takeover vector for anyone with
log access during the TTL window.

LatticeStripe masks `:url` (and `:flow`) from default `Inspect` output to prevent
accidental leaks:

```elixir
# What you see in Logger / IO.inspect / crash dumps:
IO.inspect(session)
#=> #LatticeStripe.BillingPortal.Session<id: "bps_abc123",
#     object: "billing_portal.session", livemode: false,
#     customer: "cus_xyz", configuration: "bpc_def",
#     on_behalf_of: nil, created: 1712345678,
#     return_url: "https://example.com/account", locale: nil>
# Note: url and flow are absent — they are hidden by the Inspect implementation.
```

The `url` field is completely absent from the output. It is NOT redacted as
`"[FILTERED]"` — it simply does not appear. Access it directly when you need it:

```elixir
session.url  # "https://billing.stripe.com/session/..."
```

To see every field including `:url` and `:flow` during debugging, use the
`structs: false` escape hatch:

```elixir
IO.inspect(session, structs: false)
# => %{id: "bps_abc123", url: "https://billing.stripe.com/session/...", ...}
```

**Security rules:** Use an absolute HTTPS `return_url` (phishing risk otherwise). Redirect
immediately — do not persist `session.url` in a database or cache. The portal redirect
back to `return_url` is NOT authentication — use webhooks for state-change confirmation.
Portal configuration (branding, allowed features) is in the Stripe Dashboard, not per-session params.

## Common pitfalls

**`"customer"` is required.** `Session.create/3` raises `ArgumentError` immediately without
it. Pass the `cus_*` ID — not an email address.

**`return_url` must be absolute HTTPS.** Use `Routes.account_url/2` (not `account_path/2`)
to get an absolute URL. Non-HTTPS values raise `ArgumentError` pre-network.

**`flow_data.type` must be a known string key.** Valid types: `"subscription_cancel"`,
`"subscription_update"`, `"subscription_update_confirm"`, `"payment_method_update"`. Any
other binary raises `ArgumentError` listing all valid types. Atom keys bypass the guard
and result in a Stripe 400 — always use string keys.

**Do not cache or reuse `session.url`.** It is single-use and expires in ~5 minutes.
Create a fresh portal session on every redirect — a reused URL gives the customer a broken
link after the first use.

**Portal state changes fire webhooks, not return-URL payloads.** Cancellations, plan
changes, and payment method updates dispatch `customer.subscription.deleted`,
`customer.subscription.updated`, or `payment_method.attached` events. The `return_url`
redirect carries no payload. Wire your state to webhook events. See
[Webhooks](webhooks.html) for setup.

## See also

- [`LatticeStripe.BillingPortal.Session`](`LatticeStripe.BillingPortal.Session`) — API reference, options, and security note
- [Subscriptions](subscriptions.html) — `customer.subscription.*` lifecycle events and proration control
- [Webhooks](webhooks.html) — receiving portal state-change events
- [Checkout](checkout.html) — Stripe-hosted payment flow (complement to the portal)
