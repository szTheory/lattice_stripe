# Checkout Signup and Portal Follow-Through

Use this guide when you want the fastest safe recurring-billing path for a Phoenix or
Elixir SaaS: Stripe-hosted signup with Checkout, webhook-confirmed provisioning, and
Stripe-hosted follow-through for routine billing changes.

This is a workflow playbook, not a second API reference. It shows one recommended spine,
calls out the operational footguns inline, and routes you back to the canonical guides
when you need deeper surface detail.

## Why this is the default hosted path

If you already know you want recurring billing but do not want to own payment UI,
Checkout in subscription mode is usually the strongest default:

1. Look up or create the Stripe customer.
2. Create a Checkout Session in `"subscription"` mode.
3. Redirect immediately to `session.url`.
4. Treat the success page as UX only.
5. Provision and reconcile from webhooks.
6. Send routine billing changes to the customer portal.

That keeps the payment surface hosted by Stripe while preserving the production rule that
matters most:

**Your app starts the flow. Webhooks confirm reality.**

## The recurring-billing spine

```text
customer lookup/create
  -> Checkout.Session.create(mode="subscription")
  -> redirect to Stripe Checkout
  -> optional success-page retrieval for UX
  -> checkout.session.completed / invoice.* / customer.subscription.* webhooks
  -> local provisioning and billing-state projection
  -> BillingPortal.Session.create for self-serve follow-through
```

## 1. Reuse the customer when you already know them

Do not teach your app to create a fresh Stripe customer every time someone starts signup.
If you already have a `cus_*` ID for the account, reuse it so you do not normalize
duplicate customers or duplicate subscription confusion.

```elixir
def checkout_signup(conn, _params) do
  client = MyApp.Stripe.client()
  account = conn.assigns.current_account

  stripe_customer_id =
    case account.stripe_customer_id do
      nil ->
        {:ok, customer} =
          LatticeStripe.Customer.create(client, %{
            "email" => account.billing_email,
            "name" => account.name
          })

        customer.id

      customer_id ->
        customer_id
    end

  {:ok, session} =
    LatticeStripe.Checkout.Session.create(client, %{
      "mode" => "subscription",
      "customer" => stripe_customer_id,
      "success_url" => "https://example.com/billing/success?session_id={CHECKOUT_SESSION_ID}",
      "cancel_url" => "https://example.com/pricing",
      "line_items" => [%{"price" => "price_pro_monthly", "quantity" => 1}]
    })

  redirect(conn, external: session.url)
end
```

If you do not know the customer yet, create them once, store the `cus_*` ID, and reuse it
for retries, portal sessions, and later billing workflows.

## 2. Start hosted signup with Checkout subscription mode

Use `LatticeStripe.Checkout.Session.create/3` with `"mode" => "subscription"` and an
existing recurring price. Keep the controller thin: construct the session, redirect, and
let Stripe host the payment UI.

```elixir
{:ok, session} =
  LatticeStripe.Checkout.Session.create(client, %{
    "mode" => "subscription",
    "customer" => stripe_customer_id,
    "success_url" => "https://example.com/billing/success?session_id={CHECKOUT_SESSION_ID}",
    "cancel_url" => "https://example.com/pricing",
    "line_items" => [%{"price" => price_id, "quantity" => 1}]
  })

redirect(conn, external: session.url)
```

The app still owns runtime concerns around idempotency, local account mapping, and webhook
handling. What you are not owning is card UI, SCA flows, and the hosted payment surface.

## 3. Treat the success page as a UX optimization

The `session_id` template in `success_url` is useful for rendering a better confirmation
page, but it is not authoritative provisioning truth.

```elixir
def success(conn, %{"session_id" => session_id}) do
  {:ok, session} =
    LatticeStripe.Checkout.Session.retrieve(conn.assigns.stripe_client, session_id)

  render(conn, :success, checkout_session: session)
end
```

Use that retrieval to show the user what just happened. Do not use it as the only trigger
for entitlements, account upgrades, or internal billing state. The browser can disappear,
replay, or arrive before the downstream lifecycle is actually safe to trust.

## 4. Provision from webhook-confirmed truth

The durable version of the story lives in webhook events such as:

- `checkout.session.completed`
- `invoice.paid`
- `invoice.payment_failed`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Keep the webhook handler thin and push real work into your application boundary:

```elixir
defmodule MyApp.StripeWebhookHandler do
  @behaviour LatticeStripe.Webhook.Handler

  @impl true
  def handle_event(%LatticeStripe.Event{type: "checkout.session.completed"} = event) do
    session = event.data["object"]
    MyApp.Billing.enqueue_checkout_provisioning(session["id"], session["customer"])
    :ok
  end

  @impl true
  def handle_event(%LatticeStripe.Event{type: "customer.subscription.updated"} = event) do
    subscription = event.data["object"]
    MyApp.Billing.sync_subscription(subscription["id"])
    :ok
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

This is the line that keeps the guide honest: Checkout starts the hosted signup, but your
app should project subscription truth from webhook-confirmed events and any follow-up
retrievals you need for local state.

## 5. Use the customer portal for routine self-serve follow-through

After signup, the next high-leverage move is usually not a custom billing screen. It is
Stripe's hosted customer portal.

The default portal session is the best general-purpose entry point:

```elixir
{:ok, portal_session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => stripe_customer_id,
    "return_url" => "https://example.com/account/billing"
  })

redirect(conn, external: portal_session.url)
```

`session.url` is a bearer credential. Redirect to it immediately. Do not log it, cache it,
or persist it.

Portal is a strong default for common recurring SaaS tasks, but it is not a universal
subscription control plane for every pricing shape or workflow. When the flow becomes more
complex than Stripe's hosted portal supports, route back to the canonical subscription
primitives rather than inventing fake high-level helpers in this guide.

## 6. Deep-link the portal only when the task is already known

Use deep links to reduce support load and dead clicks when the user already knows what
billing task they need to perform.

### Payment method update after a failed invoice

```elixir
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => stripe_customer_id,
    "return_url" => "https://example.com/account/billing",
    "flow_data" => %{"type" => "payment_method_update"}
  })
```

This is the cleanest recovery path when your app has already detected a failed renewal and
needs the customer to fix the default payment method.

### Subscription cancellation from your account settings

```elixir
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => stripe_customer_id,
    "return_url" => "https://example.com/account/billing",
    "flow_data" => %{
      "type" => "subscription_cancel",
      "subscription_cancel" => %{"subscription" => subscription_id}
    }
  })
```

Treat the eventual `customer.subscription.updated` or `customer.subscription.deleted`
webhook as the authoritative signal. The portal return URL is just the browser returning
to your app.

## 7. Keep the app boundary honest

This guide deliberately stops before entitlement policy, dunning strategy, operator UI, or
product-specific billing orchestration. LatticeStripe gives you the primitives and the
hosted flow entry points. Your application still decides how local state, access, and
support workflows react to the confirmed Stripe lifecycle.

## Read next

- [Checkout](checkout.md)
- [Subscriptions](subscriptions.md)
- [Customer Portal](customer-portal.md)
- [Webhooks](webhooks.md)
- [Testing](testing.md)
- [Error Handling](error-handling.md)
