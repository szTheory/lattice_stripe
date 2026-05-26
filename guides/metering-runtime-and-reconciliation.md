# Metering Runtime and Reconciliation

Use this guide when your catalog is already defined and the real problem is operational:
report usage on the hot path, avoid duplicates, reconcile asynchronous failures, and
correct bad events without pretending usage billing is a synchronous counter update.

This is a runtime-first playbook. It stays inside the SDK boundary on purpose: no fake
billing engine, no entitlement layer, and no invented read-after-write guarantees.

## Prerequisites, kept intentionally short

Before the runtime path below, you still need the setup-once pieces in place:

- a meter with the right `event_name`, `customer_mapping`, and `value_settings`
- a metered price attached to the subscription shape you actually bill
- webhook handling for downstream truth

Use the canonical guides for those foundations:

- [Metering](metering.md)
- [Subscriptions](subscriptions.md)
- [Webhooks](webhooks.md)

## The runtime mental model

Metering is event ingestion:

```text
billable app event
  -> build stable event identifier + correlation metadata
  -> MeterEvent.create(..., identifier, idempotency_key)
  -> Stripe accepts or rejects the request now
  -> Stripe validates and applies the event asynchronously
  -> webhook/operator path reconciles failures
  -> MeterEventAdjustment corrects mistakes later
```

The create response tells you what Stripe accepted for processing. It does not prove that
the customer mapping, value coercion, and downstream billing truth are already settled.

## 1. Emit usage facts with stable identity

Treat every reported event as a durable business fact with a reproducible identifier.
That identifier should let you answer "did we already report this exact usage event?"
without inventing fuzzy heuristics later.

```elixir
def report_api_call(client, customer_id, request_id, account_id) do
  event_id = "api_call:#{account_id}:#{request_id}"

  LatticeStripe.Billing.MeterEvent.create(client, %{
    "event_name" => "api_call",
    "payload" => %{
      "stripe_customer_id" => customer_id,
      "value" => "1",
      "account_id" => account_id,
      "request_id" => request_id
    },
    "identifier" => event_id
  }, idempotency_key: event_id)
end
```

Three details matter on the normal path, not just in postmortems:

- `identifier` is the business-level dedup key.
- `idempotency_key:` is the transport-level dedup key.
- correlation metadata such as `request_id` or account identifiers make later
  reconciliation possible.

## 2. Use two-layer idempotency every time

Do not choose between `identifier` and `idempotency_key:`. Use both.

- `identifier` protects against duplicate domain events.
- `idempotency_key:` protects against network retries and retried HTTP requests.

If your worker crashes, the queue retries, or your network flakes at the wrong moment, the
two layers protect different failure classes. Metering is one of the clearest places where
idempotency is part of the happy path rather than an optional hardening pass.

## 3. Keep the hot path asynchronous and classify failures honestly

Usage reporting should not pretend to be a synchronous counter increment. A practical
pattern is to emit from a supervised task or worker and classify the immediate result into
transient vs permanent failure buckets.

```elixir
case report_api_call(client, customer_id, request_id, account_id) do
  {:ok, _meter_event} ->
    :accepted_for_processing

  {:error, %LatticeStripe.Error{type: type}}
  when type in [:rate_limit_error, :api_error, :connection_error] ->
    :retry_later

  {:error, %LatticeStripe.Error{}} ->
    :drop_and_investigate
end
```

That `{:ok, ...}` result still means accepted for processing, not "the customer is now
definitively billed correctly."

## 4. Reconcile from webhooks and operator follow-through

Metering truth is asynchronous. Your reconciliation path should assume that some events
will fail later even after the initial API request looked fine.

Use your webhook handling to route downstream meter-processing failures into operator or
repair workflows:

```elixir
defmodule MyApp.StripeWebhookHandler do
  @behaviour LatticeStripe.Webhook.Handler

  @impl true
  def handle_event(%LatticeStripe.Event{type: "v1.billing.meter.error_report_triggered"} = event) do
    error_report = event.data["object"]
    MyApp.Billing.enqueue_meter_reconciliation(error_report["id"])
    :ok
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

This is where the correlation metadata from the original meter event starts paying for
itself. When an operator needs to trace the failure back to a request, account, or internal
job, the event identity should already exist.

## 5. Correct mistakes with `MeterEventAdjustment`

When the wrong usage fact was accepted, fix it with an adjustment rather than pretending a
fresh query proves the original event is harmless.

```elixir
{:ok, adjustment} =
  LatticeStripe.Billing.MeterEventAdjustment.create(client, %{
    "event_name" => "api_call",
    "type" => "cancel",
    "cancel" => %{"identifier" => "api_call:acct_42:req_123"}
  })
```

Corrections belong in the operational story, not as a hidden appendix. If your product
ships usage billing, you need a deliberate path for over-reports, duplicated work, and
late repair.

## 6. Test and replay the runtime story safely

The testing story matters because usage billing bugs are often replay bugs:

- a queue message runs twice
- an operator retries a failed job
- a webhook is replayed
- a request times out after Stripe already processed it

Keep test fixtures and replay-safe worker logic close to the metering path. Verify that:

- your event identifiers are deterministic
- retries reuse the same `identifier` and `idempotency_key:`
- webhook-triggered reconciliation is idempotent
- correction flows can be exercised without inventing a new reporting path

## Runtime footguns to keep in view

- Do not emit bare integers when the meter expects a numeric string payload value.
- Do not let browser code own meter-event writes.
- Do not treat accepted create responses as billed truth.
- Do not rely on immediate re-query or search as your main correctness story.
- Do not defer all reporting into a giant nightly batch flush.

## Read next

- [Metering](metering.md)
- [Webhooks](webhooks.md)
- [Testing](testing.md)
- [Error Handling](error-handling.md)
- [Subscriptions](subscriptions.md)
