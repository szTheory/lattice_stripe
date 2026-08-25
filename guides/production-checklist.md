# Production Checklist

Use this guide as a pre-launch gate before you point real traffic at Stripe. It
composes the Operations & DX trust rails into a scannable checklist — you verify
boundaries here, then follow linked guides for full behavior truth.

Production Stripe integrations fail at boundaries — keys, raw bodies, idempotency,
and observability.

Add LatticeStripe to your release:

```elixir
{:lattice_stripe, "~> 2.2"}
```

## 1. Audience and scope

This checklist covers **SDK integration hygiene** for Elixir/Phoenix apps using
LatticeStripe — not Stripe Dashboard account setup (business verification, tax
settings, payout schedules). For Dashboard readiness, use
[Stripe's account checklist](https://docs.stripe.com/get-started/checklist/go-live).

After launch, when webhooks misbehave in production, switch to
[Event Debugging](event-debugging.md) — this guide is the pre-flight gate, not the
post-incident playbook.

## 2. Quick checklist

Print or copy this block. Each item should be true before go-live:

- [ ] Live secret key (`sk_live_...`) loaded from env, never committed
- [ ] Test and live keys isolated per environment
- [ ] Finch pool started in supervision tree before first API call
- [ ] `LatticeStripe.Client.new!/1` used with explicit `api_key` and `finch`
- [ ] Webhook endpoint secret resolved at runtime (MFA or env), not hardcoded
- [ ] `LatticeStripe.Webhook.Plug` mounted **before** `Plug.Parsers`
- [ ] Raw request body preserved for signature verification
- [ ] Idempotency keys on money-moving writes; SDK auto-keys POST by default
- [ ] `%LatticeStripe.Error{request_id: _}` logged on API failures
- [ ] Telemetry handlers attached for request and webhook verify events
- [ ] Circuit breaker configured (recommended before scale) — see [Circuit Breaker](circuit-breaker.md)
- [ ] Connect platform flows reviewed if you use `Stripe-Account` header routing
- [ ] Smoke tests pass against test mode; one live-mode $0 or refund test if policy allows
- [ ] Operator playbooks bookmarked: [Event Debugging](event-debugging.md), [Testing](testing.md)

## 3. API keys and environments

Never embed secret keys in source. Resolve at runtime:

```elixir
client =
  LatticeStripe.Client.new!(
    api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
    finch: MyApp.Finch
  )
```

Use `sk_test_...` in dev/CI and `sk_live_...` only in production deploys. Rotate
keys in Dashboard if any key ever appeared in logs, tickets, or git history.

See [Client Configuration](client-configuration.md) and
[Getting Started](getting-started.md) for optional client settings and test keys.

## 4. Client and Finch production wiring

Finch must be running before `Client.new!` issues its first request:

```elixir
# application.ex — Finch must start with your app
children = [
  {Finch, name: MyApp.Finch},
  MyAppWeb.Endpoint
]
```

Pool sizing, timeouts, and connection limits belong in
[Performance](performance.md) — this checklist only asserts Finch is supervised.

## 5. Webhook verification and endpoints

Mount the plug before parsers so Stripe signs the same bytes you verify:

```elixir
# lib/my_app_web/endpoint.ex
plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret: {MyApp.BillingConfig, :stripe_webhook_secret, []},
  handler: MyApp.StripeWebhookHandler

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Jason
```

**Your app starts work. Webhooks confirm reality.** API responses mean Stripe
accepted the request now; webhooks tell you what actually settled, failed, or
retried later.

For snapshot `/v1` webhooks, see [Webhooks](webhooks.md). For thin `/v2/events`,
see [Webhooks: Thin Events](webhooks-thin-events.md).

## 6. Idempotency and safe retries

LatticeStripe attaches idempotency keys to POST requests automatically. For
money-moving operations (creates, captures, refunds), pass explicit keys tied to
your domain operation so job restarts and message redelivery do not double-charge:

```elixir
LatticeStripe.PaymentIntent.create(client, params,
  idempotency_key: "payment_intent:create:order:#{order_id}:v1"
)
```

See [Client Configuration](client-configuration.md#idempotency-keys-that-survive-application-retries)
for durable-key boundaries, [Error Handling](error-handling.md) for indeterminate outcomes,
and [Metering](metering.md) if usage events must not duplicate.

## 7. Error handling and support posture

On `{:error, %LatticeStripe.Error{} = err}`, log `err.request_id` — Stripe support
and Dashboard logs correlate on that value. Do not log full card or bank payloads.

See [Error Handling](error-handling.md) for classification, retry policy, and
support escalation patterns.

## 8. Telemetry and observability

Attach handlers for `[:lattice_stripe, :request, :stop]` and
`[:lattice_stripe, :webhook, :verify, :stop]` before launch. You need request
duration, status, and verify outcomes in your metrics stack — not only application
logs.

See [Telemetry](telemetry.md) and [OpenTelemetry](opentelemetry.md) for handler
recipes and export wiring.

## 9. Resilience (recommended before scale)

Configure circuit breaking and backoff before traffic spikes — not after the
first outage. Defaults are tunable; the requirement is that failure isolation is
deliberate.

See [Performance](performance.md) and [Circuit Breaker](circuit-breaker.md).

## 10. Connect platforms (if applicable)

If you route requests with `Stripe-Account`, verify webhook handlers dispatch on
`event.account` (or thin-event context) and that money-movement reconciliation
matches your Connect charge model.

See [Connect](connect.md) and
[Connect Money Movement](connect-money-movement.md).

## 11. Final smoke tests

Run the integration paths you ship: checkout or PI confirm, webhook delivery to
your staging endpoint, and at least one idempotent retry simulation.

See [Testing](testing.md) for stripe-mock, Bypass patterns, and webhook test
harnesses — do not duplicate that guide here.

## Support and audit lookups

Charge is the **result record** of a payment attempt, not payment initiation. Use
`PaymentIntent` for payment flows; use `Charge` to read/reconcile existing charges.
Full workflows: [Payments — Charge reconciliation](payments.md#charge-reconciliation) and
`LatticeStripe.Charge` moduledoc.

For support tickets and audits:

- List or filter settled charges: `LatticeStripe.Charge.list/3`
- Search by Stripe query syntax: `LatticeStripe.Charge.search/3` — results are
  **eventually consistent**; do not rely on search for seconds-fresh payments
- Retrieve a known charge id from Dashboard/support: `LatticeStripe.Charge.retrieve/3`
- Update metadata or description on settled charges: `LatticeStripe.Charge.update/4` (not payment state)
- Capture uncaptured legacy direct charges only: `LatticeStripe.Charge.capture/4`; PI manual capture → [`PaymentIntent.capture/4`](payments.md#capturing-a-paymentintent-manual-capture)
- Connect fee reconciliation: follow balance transaction `fee_details` via
  [Connect Money Movement](connect-money-movement.md)

Route new payment work through PaymentIntent; use Charge modules for read/reconcile
only at launch review.

## Read next

- [Event Debugging](event-debugging.md) — post-incident webhook diagnosis
- [Webhooks](webhooks.md) — snapshot endpoint setup
- [Error Handling](error-handling.md) — errors, retries, `request_id`
- [Testing](testing.md) — CI and local verification
- [Telemetry](telemetry.md) — metrics and event handlers
