# Event Debugging

Production webhook pain rarely starts in your business logic — it starts at the
HTTP boundary: wrong secret, mutated body, stale timestamp, or a handler that
returns 5xx and triggers Stripe retries. This guide is the symptom spine for
diagnosis; build setup stays in [Webhooks](webhooks.md) and
[Webhooks: Thin Events](webhooks-thin-events.md).

Debug from the delivery boundary inward: Dashboard → HTTP status → signature →
payload shape → dispatch.

**Your app starts work. Webhooks confirm reality.**

Add LatticeStripe to your project:

```elixir
{:lattice_stripe, "~> 1.7"}
```

## Start here — snapshot vs thin

Pick the surface that matches your endpoint. Using the wrong parser produces
confusing "empty" structs — not a Stripe outage.

| Endpoint surface | Payload shape | First SDK call | Wrong symptom |
|------------------|---------------|----------------|---------------|
| Snapshot `/v1` (Plug) | Full `event` JSON | `Webhook.Plug` → handler | Thin controller calls `construct_event` on v2 body → mostly-nil fields |
| Thin `/v2/events` | `{id, type, related_object}` | `Webhook.parse_event_notification/4` | Snapshot handler expects nested `data.object` → decode errors or nil object |
| After verify (thin) | Notification only | `fetch_event/3` or `fetch_related_object/3` | Acting on notification JSON without fetch → stale or incomplete state |

If verification passes but fields look wrong, you are likely on the wrong guide:
switch to [Webhooks: Thin Events](webhooks-thin-events.md) or [Webhooks](webhooks.md).

## Symptom index

| Symptom | First checks | Deep section |
|---------|--------------|--------------|
| HTTP 400 on webhook | Secret, raw body, Plug order, clock skew | Signature verification failures |
| HTTP 500 after 400s fixed | Handler exceptions, fetch failures | Fetch-after-verify debugging |
| Duplicate side effects | Idempotency on `event.id`, not resource state | Delivery / replay |
| Events never arrive | Dashboard endpoint URL, firewall, wrong mode key | Delivery / replay |
| Slow 5xx retry storm | Handler timeout, enqueue-after-2xx missing | Common dispatch patterns |
| Thin payload, nil object | Wrong entry point for `/v2` | Start here table |

## Signature verification failures

Work through this list before changing application logic:

1. **Endpoint secret mismatch** — CLI `stripe listen` prints a signing secret; Dashboard
   endpoint has a different one. The secret in your app must match the **sender**.
2. **Raw body missing** — Verification needs `conn.private[:raw_body]` (or equivalent).
   If `Plug.Parsers` ran first, signatures will never match. See [Webhooks](webhooks.md).
3. **Plug order** — `LatticeStripe.Webhook.Plug` must be **before** `Plug.Parsers`.
4. **Clock skew** — `:timestamp_expired` means tolerance exceeded; sync NTP on nodes.
5. **Header present and well-formed** — `:missing_header`, `:invalid_header` before crypto.
6. **Secret rotation** — pass a list of secrets to the plug during rotation windows.

### Verify error vocabulary

LatticeStripe returns tagged errors (no raise) for verify failures on the thin path;
snapshot `Webhook.Plug` uses the same atoms:

| Error | Typical cause | Fix |
|-------|---------------|-----|
| `:missing_header` | Proxy stripped `Stripe-Signature` | Check load balancer / CDN config |
| `:invalid_header` | Malformed header string | Log header length only, not value |
| `:no_matching_signature` | Wrong secret or mutated body | Secret match + raw body invariant |
| `:timestamp_expired` | Clock drift or replay window | NTP + check tolerance config |

For thin controllers, `Webhook.parse_event_notification/4` verifies before JSON decode.
Payload shape errors (`Jason.DecodeError`) **raise** after verify — handle both paths
in your `receive/2` action.

### Snapshot vs thin verify entry points

```elixir
# Snapshot — plug verifies inside the pipeline
plug LatticeStripe.Webhook.Plug, at: "/webhooks/stripe", ...

# Thin — controller calls parse explicitly
{:ok, notif} = Webhook.parse_event_notification(raw_body, sig_header, secret)
```

Wrong entry point symptom: you call snapshot `construct_event` helpers on a thin body
and get a struct with mostly `nil` fields — switch guides, do not patch around nils.

Log event type and `event.id` only — not full payloads. Never use `IO.inspect` on
webhook bodies in production.

## Fetch-after-verify debugging

Thin events require a fetch after verify. Snapshot handlers may still call retrieve
for authoritative state. When fetch fails:

```elixir
{:error, %LatticeStripe.Error{request_id: request_id} = err} ->
  Logger.error("stripe fetch failed", request_id: request_id, code: err.code)
```

### Fetch paths

```elixir
# Full event object (either surface after thin verify)
{:ok, event} = Webhook.fetch_event(client, notif)

# Related resource when related_object is present
{:ok, obj} = Webhook.fetch_related_object(client, notif)
```

- **429 / rate limits** — back off; Stripe retries webhooks but your fetch loop can amplify load.
- **Race with your own writes** — key idempotency on **`event.id`**, not on "payment already
  processed" resource flags alone; duplicate deliveries are normal.
- **`:no_related_object`** — use `fetch_event/3` instead of `fetch_related_object/3`.
- **Unknown type** — `{:error, {:unknown_object_type, type}}` means dispatch table needs
  an explicit branch; do not silently ignore.

### Idempotency sketch

```elixir
case MyApp.IdempotentEvents.claim(event.id) do
  :ok -> process(event)
  :already_processed -> :ok
end
```

Store claims by Stripe `event.id` (or thin notification `id`), not by charge or PI id alone —
the same resource can emit multiple event types.

See [Error Handling](error-handling.md) for retry classification and support paths.

## Delivery, replay, and Stripe retries

Stripe delivers **at-least-once**. Automatic retries follow HTTP status: 2xx acks,
non-2xx schedules retry with backoff. Your handler must be idempotent.

### HTTP status decision table

| Your response | Stripe behavior | Operator note |
|---------------|-----------------|-----------------|
| 2xx | Delivery marked succeeded | Work may still fail async after ack |
| 4xx (except 429) | Generally no retry | Use for verify misconfig — fix secret/body |
| 5xx / timeout | Retries with backoff | Can look like "duplicate" events — idempotency required |
| 429 | Retry | Rate limit your handler if self-inflicted |

**Local replay:** `stripe events resend <event_id>` re-sends the same event id — useful
for reproducing handler bugs without waiting for live traffic.

**Dashboard "Resend"** — same semantics: duplicate `event.id`, not a new logical event.
Do not treat Resend as "generate a new payment event."

### Missing events checklist

1. Dashboard → Developers → Webhooks → select endpoint → **Event deliveries**
2. Confirm test vs live mode matches the key on the sending Stripe account
3. curl your endpoint URL from outside your VPC (TLS, cert, path)
4. Check if endpoint was disabled after repeated failures
5. For thin destinations, confirm `/v2/events` subscription includes the event types you expect

Missing events: confirm live vs test mode keys, endpoint URL reachable from Stripe,
and Dashboard delivery logs before assuming SDK bugs.

## Common dispatch patterns

Debug lens only — full controller spines live in canonical guides.

| Pattern | Risk | What to check |
|---------|------|----------------|
| 2xx after enqueue | Work lost if queue dies | Return 2xx only after durable write or accept replay cost |
| 5xx on slow work | Retry storm | Move work to `Task`/Oban; return 2xx when safely queued |
| Connect routing | Wrong tenant updated | Match `event.account` or thin `context` before dispatch |
| Always 200 on verify fail | Silent data loss | Return 4xx on verify failure so Stripe surfaces misconfig |

Keep dispatch modules under ~15 lines in logs — trace `event.type`, `event.id`, and
outcome status, not PII fields.

## Observability checklist

Ensure these events reach your metrics or APM:

- `[:lattice_stripe, :webhook, :verify, :stop]` — success/failure and timing
- `[:lattice_stripe, :request, :stop]` — include `request_id` metadata on failures

Correlate Dashboard delivery attempt timestamps with verify stop events. If verify
metrics are green but business state is wrong, the bug is post-verify dispatch.

### Minimum fields to log per delivery

| Field | Why |
|-------|-----|
| `event.id` | Idempotency and Dashboard correlation |
| `event.type` | Dispatch routing |
| HTTP status you returned | Explains retry behavior |
| `request_id` (on fetch errors) | Stripe support escalation |

Do not log full `data.object` blobs — card, bank, and PII fields belong in Stripe's
Dashboard, not your log index.

### Dashboard ↔ app correlation workflow

1. Copy `event.id` from Dashboard delivery detail
2. Search app logs for that id (or your idempotency claim row)
3. If absent, verify failed before dispatch — check verify telemetry
4. If present with 2xx but wrong state, inspect fetch + dispatch logs for that id

See [Telemetry](telemetry.md) for handler attachment examples.

## `charge.*` events

Charge is the **result record** of a payment attempt, not payment initiation. Use
`PaymentIntent` for payment flows; use `Charge` to read/reconcile existing charges.
Full workflows: [Payments — Charge reconciliation](payments.md#charge-reconciliation) and
`LatticeStripe.Charge` moduledoc.

For `charge.succeeded` and siblings:

- Prefer following `payment_intent` on the event when present — PI is the flow spine.
- Use `LatticeStripe.Charge.retrieve/3` when you need charge-specific fields
  (`balance_transaction`, `application_fee_amount`, etc.).
- **Anti-pattern:** do not use `LatticeStripe.Charge.search/3` to confirm a payment
  that just succeeded — search index lags; use retrieve or PaymentIntent state.
- Attach support context after dispatch: `LatticeStripe.Charge.update/4` (e.g. ticket id in metadata); idempotency still keyed on `event.id`
- **Anti-pattern:** do not call `LatticeStripe.Charge.capture/4` from `charge.*` handlers for PaymentIntent flows — use PaymentIntent state or [`PaymentIntent.capture/4`](payments.md#capturing-a-paymentintent-manual-capture)

## See also

- [Webhooks](webhooks.md) — snapshot plug setup and raw-body invariant
- [Webhooks: Thin Events](webhooks-thin-events.md) — `/v2/events` fetch-after-verify
- [Production Checklist](production-checklist.md) — pre-launch gate
- [Error Handling](error-handling.md) — `request_id`, retries, support
- [Testing](testing.md) — local webhook verification
