# Billing Metering

Stripe's usage-based billing system lets you charge customers for what they
actually consume — API calls, messages sent, gigabytes stored — rather than a
flat recurring fee. LatticeStripe exposes three resources that form the metering
stack: `Billing.Meter` (the schema that defines what to measure),
`Billing.MeterEvent` (the fire-and-forget usage fact), and
`Billing.MeterEventAdjustment` (the correction mechanism when something goes
wrong).

This guide covers the full lifecycle: defining a meter, reporting usage on the
hot path with two-layer idempotency, correcting over-reports, reconciling
asynchronous failures via webhooks, and observing the pipeline in production.
Code examples throughout reflect the exact function signatures shipped in
Phase 20 (Plans 20-03 through 20-05).

## Mental model

```
Meter (schema)
  ├── event_name: "api_call"          <- the named stream you report against
  ├── default_aggregation.formula     <- how Stripe aggregates (sum / count / last)
  ├── customer_mapping                <- which payload key identifies the customer
  └── value_settings.event_payload_key <- which payload key carries the numeric value
          │
          │  MeterEvent.create/3 (real-time, fire-and-forget)
          ▼
MeterEvent (usage fact)
  ├── payload: %{"stripe_customer_id" => "cus_...", "value" => "5"}
  ├── identifier: "req_abc"           <- body-level idempotency
  └── timestamp: 1_700_000_000       <- when the usage occurred
          │
          │  Stripe's billing pipeline
          ▼
Subscription item with usage_type: "metered"
  └── Invoice line item calculated at period close
```

The key insight: `MeterEvent.create/3` is **accepted for processing** — it does
NOT mean the usage was applied to a customer. Customer-mapping validation,
value coercion, and aggregation happen asynchronously. You learn about failures
via the `v1.billing.meter.error_report_triggered` webhook, not from the create
response.

For setting up the Subscription side (metered price, `usage_type: "metered"`,
`aggregate_usage`), see [subscriptions.md](subscriptions.md#subscription-schedules).

## Defining a meter

Create a meter once, at deploy or setup time. The meter is the named schema;
individual usage facts reference it by `event_name`.

```elixir
client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

{:ok, meter} = LatticeStripe.Billing.Meter.create(client, %{
  "display_name" => "API Calls",
  "event_name" => "api_call",
  "default_aggregation" => %{"formula" => "sum"},
  "customer_mapping" => %{
    "event_payload_key" => "stripe_customer_id",
    "type" => "by_id"
  },
  "value_settings" => %{"event_payload_key" => "value"}
})
```

### Aggregation formulas

Three formulas are available. Choose based on what you want Stripe to count per
billing period:

**`"sum"`** — adds up all `value` fields across every event in the period.
Use for cumulative consumption (bytes transferred, API calls made, emails sent).
REQUIRES a well-formed `value_settings.event_payload_key`.

```elixir
"default_aggregation" => %{"formula" => "sum"},
"value_settings" => %{"event_payload_key" => "value"}
```

**`"count"`** — counts the number of distinct events, ignoring any numeric value
in the payload. Use when each event represents one unit of consumption (one login,
one webhook delivery, one file upload).

```elixir
"default_aggregation" => %{"formula" => "count"}
# value_settings is optional for count — no numeric payload key needed
```

**`"last"`** — takes the value from the most recent event in the period. Use for
high-watermark billing (peak seat count, maximum concurrent sessions, current
storage tier). REQUIRES a well-formed `value_settings.event_payload_key`.

```elixir
"default_aggregation" => %{"formula" => "last"},
"value_settings" => %{"event_payload_key" => "seats"}
```

> **Warning:** If you use `"sum"` or `"last"` without a correct
> `value_settings.event_payload_key`, every event you report will silently drop
> with `meter_event_value_not_found`. LatticeStripe's `GUARD-01`
> (`Billing.Guards.check_meter_value_settings!/1`) raises at call time if
> `value_settings` is missing or empty for these formulas. Fix the meter; do not
> bypass the guard.

### customer_mapping

Tells Stripe which payload key identifies the customer. The only supported type
is `"by_id"` (Stripe customer ID). If the key is missing or maps to a deleted
customer, Stripe silently drops the event (see
[Reconciliation via webhooks](#reconciliation-via-webhooks)).

> **Note:** LatticeStripe does not currently guard `customer_mapping` presence
> at call time (D-07 deferred). A meter without it drops every event silently
> with `meter_event_no_customer_defined`.

### value_settings

Specifies which payload key holds the numeric usage value. Required for `"sum"`
and `"last"` formulas. The value MUST be a numeric string (`"5"`, not `5`) —
integers trigger `meter_event_invalid_value` and are silently dropped.

```elixir
"value_settings" => %{"event_payload_key" => "value"}
```

### Lifecycle verbs

Meters support three lifecycle operations beyond create:

```elixir
# Retrieve a meter by id
{:ok, meter} = LatticeStripe.Billing.Meter.retrieve(client, "meter_abc123")

# Deactivate — stops accepting new events; subscription billing continues
# until period close
{:ok, meter} = LatticeStripe.Billing.Meter.deactivate(client, meter.id)

# Reactivate — restores event acceptance
{:ok, meter} = LatticeStripe.Billing.Meter.reactivate(client, meter.id)
```

Once deactivated, any new `MeterEvent.create/3` call against that meter's
`event_name` returns a synchronous `400` with `error_code: "archived_meter"`.
**Data is permanently lost** — no buffer, no catch-up. Alert immediately.

## Reporting usage (the hot path)

`MeterEvent.create/3` is your hot path. It should be called once per billable
action, inline or in a supervised background task, with full idempotency
discipline.

### The fire-and-forget idiom

The recommended production pattern: fire from a `Task.Supervisor` child so a
Stripe API hiccup never blocks your response path.

```elixir
defmodule AccrueLike.UsageReporter do
  require Logger
  alias LatticeStripe.Billing.MeterEvent

  # Non-blocking: schedules a supervised task. Returns :ok immediately.
  def report(client, event_name, customer_id, value, opts \\ []) do
    event_id = Keyword.get_lazy(opts, :identifier, fn ->
      "#{event_name}:#{customer_id}:#{System.unique_integer([:positive])}"
    end)

    Task.Supervisor.start_child(AccrueLike.TaskSupervisor, fn ->
      :telemetry.span([:accrue, :usage_report], %{event_name: event_name}, fn ->
        result = MeterEvent.create(client, %{
          "event_name" => event_name,
          "payload" => %{"stripe_customer_id" => customer_id, "value" => to_string(value)},
          "identifier" => event_id
        }, idempotency_key: event_id)

        case result do
          {:ok, _event} ->
            {:ok, %{event_name: event_name}}

          {:error, %LatticeStripe.Error{type: type} = err}
          when type in [:rate_limit_error, :api_error, :connection_error] ->
            # Transient — retry via your retry scheduler
            Logger.warning("transient usage report failure",
              event_name: event_name, type: type, request_id: err.request_id)
            {{:error, :transient}, %{event_name: event_name}}

          {:error, %LatticeStripe.Error{} = err} ->
            # Permanent — drop; retrying won't help
            Logger.error("permanent usage report failure — event dropped",
              event_name: event_name, type: err.type, request_id: err.request_id)
            {{:error, :permanent}, %{event_name: event_name}}
        end
      end)
    end)

    :ok
  end
end
```

Error classification: `:rate_limit_error`, `:api_error`, `:connection_error` are
transient (retry). All others — `:invalid_request_error`, `:authentication_error`,
`:idempotency_error` — are permanent (fix the bug, don't retry).

### Two-layer idempotency

Metering has two independent idempotency mechanisms. Use both in production.

**Layer 1 — body `identifier` (business-layer, 24-hour dedup)**

The `identifier` field in the request body is a Stripe-side deduplication key.
If you send two events with the same `identifier` and `event_name`, Stripe
processes only the first and silently discards the second.

```elixir
MeterEvent.create(client, %{
  "event_name" => "api_call",
  "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"},
  "identifier" => "inv_456:item_789"   # <-- body-level, business dedup
})
```

**Layer 2 — `idempotency_key:` opt (transport-layer, HTTP header)**

The `idempotency_key:` opt adds an `Idempotency-Key` HTTP header. If a network
request times out or the connection drops, retrying with the same key replays
the exact previous HTTP response — no second event accepted.

```elixir
MeterEvent.create(client, %{
  "event_name" => "api_call",
  "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"},
  "identifier" => "inv_456:item_789"
}, idempotency_key: "inv_456:item_789")   # <-- transport-layer, HTTP dedup
```

**Comparison table**

| Property | `identifier` (body) | `idempotency_key:` (HTTP header) |
|---|---|---|
| Where enforced | Stripe billing pipeline | Stripe API gateway |
| Dedup window | 24 hours | 24 hours |
| Scope | Per event_name | Per API key |
| Protects against | Duplicate domain events | Network retries |
| Survives process crash? | YES (Stripe holds it) | YES (Stripe holds it) |

**Set BOTH in production.** `identifier` catches business-level duplicates
(worker ran twice, same queue message delivered twice). `idempotency_key:`
catches transport-level duplicates (network timeout, process restarted mid-request).
They're orthogonal — neither replaces the other.

### Timestamp semantics

`MeterEvent.create/3` accepts an optional `timestamp` (Unix seconds integer).
When omitted, Stripe uses the current server time.

**35-day backdating window:** Events older than 35 days return a sync `400`
with `timestamp_too_far_in_past` — the most common batch-flush failure.

**5-minute future cap:** Events more than 5 minutes in the future return
`timestamp_in_future`. Fix clock skew (NTP, containerized drift) before going live.

```elixir
# Report usage that happened 2 hours ago
MeterEvent.create(client, %{
  "event_name" => "api_call",
  "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"},
  "timestamp" => System.system_time(:second) - 7_200,
  "identifier" => "req_abc:2h-ago"
}, idempotency_key: "req_abc:2h-ago")
```

### What NOT to do: nightly batch flush

> **Warning:** Do not buffer usage events in your database and flush them to
> Stripe in a nightly batch job. This pattern silently fails at scale and
> becomes catastrophically wrong at month boundaries.
>
> ```elixir
> # WRONG — do not do this
> def flush_usage do
>   Repo.all(PendingUsageEvent)
>   |> Enum.each(fn event ->
>     MeterEvent.create(stripe_client, %{
>       "event_name" => event.event_name,
>       "payload" => %{"stripe_customer_id" => event.customer_id,
>                      "value" => to_string(event.value)},
>       "timestamp" => DateTime.to_unix(event.occurred_at)
>     })
>   end)
> end
> ```
>
> **Why this fails:**
> 1. Events older than 35 days from `occurred_at` return a hard 400. Any backlog
>    older than 5 weeks is permanently unrecoverable.
> 2. Batch sends are rate-limited. A large backlog causes cascading 429s.
> 3. Without `identifier`, a crash mid-flush creates double-counted events.
> 4. No `idempotency_key:` means a killed batch process causes network-level
>    duplicates when restarted.

Report usage inline (or from a supervised task) at the moment it occurs:

```elixir
# CORRECT — report usage when it happens
def handle_api_request(conn, customer_id) do
  result = process_request(conn)

  # Fire and forget — does not block the response
  AccrueLike.UsageReporter.report(stripe_client, "api_call", customer_id, 1,
    identifier: conn.assigns.request_id)

  result
end
```

## Corrections and adjustments

### MeterEventAdjustment.create/3

If you report usage and later discover it was wrong (over-report, duplicate
event, test data leaked to production), you can cancel the original event within
Stripe's **24-hour cancellation window** using `MeterEventAdjustment.create/3`.

```elixir
{:ok, adjustment} = LatticeStripe.Billing.MeterEventAdjustment.create(client, %{
  "event_name" => "api_call",
  "cancel" => %{"identifier" => "req_abc"}
})
```

The `cancel` field MUST be a nested map with an `identifier` key. The most
common mistake is putting `identifier` at the top level:

```elixir
# WRONG — identifier at the top level
MeterEventAdjustment.create(client, %{
  "event_name" => "api_call",
  "identifier" => "req_abc"      # <- Stripe ignores this, returns 400
})

# CORRECT — identifier nested inside cancel
MeterEventAdjustment.create(client, %{
  "event_name" => "api_call",
  "cancel" => %{"identifier" => "req_abc"}   # <- correct shape
})
```

LatticeStripe's GUARD-03 (`Billing.Guards.check_adjustment_cancel_shape!/1`)
raises `ArgumentError` at call time if the `cancel` map is missing `identifier`
or the shape is wrong. This prevents the wrong shape from reaching the network.

The returned `%MeterEventAdjustment{}` has a `cancel` field decoded as
`%LatticeStripe.Billing.MeterEventAdjustment.Cancel{identifier: "req_abc"}` —
not `identifier` at the top level.

### Dunning-style over-report flow (worked example)

A real-world scenario: your usage reporter fires twice due to a process restart,
and you detect the duplicate via a metadata check. Here is the full correction
flow:

```elixir
defmodule AccrueLike.UsageCorrector do
  @moduledoc """
  Detect and cancel duplicate usage events within the 24-hour window.
  """

  require Logger
  alias LatticeStripe.Billing.MeterEventAdjustment

  @doc """
  Cancel a previously-reported event if it was a duplicate.

  `original_identifier` must be the exact `identifier` string used when
  the original MeterEvent was created.
  """
  def cancel_duplicate(client, event_name, original_identifier) do
    Logger.info("cancelling duplicate usage event",
      event_name: event_name, identifier: original_identifier)

    :telemetry.span([:accrue, :usage_correction], %{event_name: event_name}, fn ->
      result = MeterEventAdjustment.create(client, %{
        "event_name" => event_name,
        "cancel" => %{"identifier" => original_identifier}
      }, idempotency_key: "cancel:#{original_identifier}")

      case result do
        {:ok, %MeterEventAdjustment{status: "pending"}} ->
          Logger.info("adjustment accepted", event_name: event_name,
            identifier: original_identifier)
          {{:ok, :accepted}, %{event_name: event_name}}

        {:error, %LatticeStripe.Error{code: "out_of_window"} = err} ->
          # More than 24 hours have passed — cannot cancel
          Logger.error("adjustment window expired — event cannot be cancelled",
            event_name: event_name, identifier: original_identifier,
            request_id: err.request_id)
          {{:error, :window_expired}, %{event_name: event_name}}

        {:error, %LatticeStripe.Error{} = err} ->
          Logger.error("adjustment failed", event_name: event_name,
            identifier: original_identifier, type: err.type, request_id: err.request_id)
          {{:error, err.type}, %{event_name: event_name}}
      end
    end)
  end
end
```

Key shape to remember: `%{"cancel" => %{"identifier" => original_identifier}}`.
The nested shape is enforced by both GUARD-03 at call time and by Stripe's API.
Passing anything else returns a Stripe 400.

## Reconciliation via webhooks

### The error-report webhook

Most metering failure modes surface asynchronously. Stripe fires
`v1.billing.meter.error_report_triggered` when processing errors accumulate.
Wire it into your handler:

```elixir
def handle_event(%LatticeStripe.Event{
  type: "v1.billing.meter.error_report_triggered"} = event) do
  report = event.data["object"]
  MyApp.Billing.handle_meter_error(
    report["meter"],
    get_in(report, ["reason", "error_code"]),
    get_in(report, ["reason", "error_count"])
  )
  :ok
end
```

> **Note:** Keep this handler fast — log, enqueue, return `:ok`. No inline DB
> queries or external calls.

### Error codes you must handle

| `error_code` | When | Silent drop? | Remediation |
|---|---|---|---|
| `meter_event_customer_not_found` | customer deleted | YES (async) | Sweep job |
| `meter_event_no_customer_defined` | payload missing mapping key | YES (async) | Fix reporter |
| `meter_event_invalid_value` | value not numeric | YES (async) | Fix reporter |
| `meter_event_value_not_found` | sum/last but no value key | YES (async) | Fix payload (likely GUARD-01 bypass) |
| `archived_meter` | meter deactivated | NO (sync 400) | Alert — data PERMANENTLY LOST |
| `timestamp_too_far_in_past` | >35 days | NO (sync 400) | Drop batch flush anti-pattern |
| `timestamp_in_future` | >5 min future | NO (sync 400) | Fix clock skew |

The "Silent drop?" column is critical: async errors (YES) mean usage was silently
not recorded against the customer. These affect revenue. Sync errors (NO) are
surfaced as `{:error, %LatticeStripe.Error{}}` from `MeterEvent.create/3` directly.

### Remediation patterns

**`meter_event_customer_not_found`:** A customer was deleted between reporting
and processing. Add a sweep job reconciling deleted customer IDs against your
customer table.

**`meter_event_no_customer_defined`:** Your `payload` is missing the key named
in `customer_mapping.event_payload_key`. Fix the reporter key to match the meter
schema — every event is dropping silently until you do.

**`meter_event_invalid_value`:** The value is not a numeric string. Common
causes: integer instead of string (`1` vs `"1"`), `nil` for zero (send `"0"`),
or a formatted string like `"1,000"`.

**`meter_event_value_not_found`:** The payload is missing the key named in
`value_settings.event_payload_key`. This is exactly the failure mode GUARD-01
prevents. Fix the meter definition or the reporter payload key.

**`archived_meter`:** Immediately alert. No retry, no recovery. Events against
a deactivated meter are permanently lost.

## Observability

### Telemetry for the hot path

LatticeStripe emits `[:lattice_stripe, :request, :start | :stop | :exception]`
for every `MeterEvent.create/3` call. Filter on `metadata.resource ==
"BillingMeterEvent"` to isolate metering traffic:

```elixir
:telemetry.attach(
  "myapp-meter-event-rate",
  [:lattice_stripe, :request, :stop],
  fn _event, measurements, %{resource: "BillingMeterEvent"} = meta, _cfg ->
    ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    MyApp.Metrics.histogram("stripe.meter_event.duration_ms", ms, %{status: meta.status})
    MyApp.Metrics.increment("stripe.meter_event.total", %{status: meta.status})
  end,
  nil
)
```

Alert if `stripe.meter_event.total{status: error}` exceeds 1% of traffic.
Async pipeline errors (silent drops) appear via webhook, not here.

See [telemetry.md](telemetry.md#custom-telemetry-handlers) for the full event
schema and more handler recipes.

### Debugging with Inspect

`%LatticeStripe.Billing.MeterEvent{}` implements a custom `Inspect` protocol that
hides the `payload` field. This is intentional: the payload contains
`stripe_customer_id` (PII), and LatticeStripe's default Inspect output is safe to
appear in Logger output, crash dumps, and telemetry handlers.

```
iex> IO.inspect(event)
#LatticeStripe.Billing.MeterEvent<event_name: "api_call", identifier: "req_abc",
  timestamp: 1700000000, created: 1700000001, livemode: false>
```

**NEVER log raw `MeterEvent.payload` — it contains `stripe_customer_id` (PII).**

When you need to inspect the payload during debugging (never in production log
paths), use the escape hatches:

```elixir
# Escape hatch 1: disable struct printing to see all fields
IO.inspect(event, structs: false)

# Escape hatch 2: access the field directly (never in a Logger call)
event.payload
```

Both approaches bypass the custom Inspect protocol and reveal the raw payload.
Use only in a local IEx session or a one-off debug script, never in code that
runs in production.

## Guards and escape hatches

LatticeStripe ships two guards for the metering stack:

**GUARD-01 — `check_meter_value_settings!/1`**

Raises `ArgumentError` at call time if you attempt to create a meter with
`"sum"` or `"last"` formula but without a `value_settings.event_payload_key`.

```elixir
# This raises before hitting the network:
LatticeStripe.Billing.Meter.create(client, %{
  "event_name" => "api_call",
  "default_aggregation" => %{"formula" => "sum"}
  # missing value_settings!
})
# ** (ArgumentError) Billing.Guards: sum/last formula requires value_settings...
```

Frame this guard as "only relevant when porting from another SDK or writing
one-off scripts." Production code should have the meter schema correct before
deployment. Fix the meter definition, not the call.

**GUARD-03 — `check_adjustment_cancel_shape!/1`**

Raises `ArgumentError` if `MeterEventAdjustment.create/3` is called with
a `cancel` map that lacks `identifier`. See the dunning example above for the
correct shape.

**Bypassing guards (escape hatch)**

For porting or debugging, call the transport directly to skip SDK guards:

```elixir
LatticeStripe.Client.request(client, %LatticeStripe.Request{
  method: :post,
  path: "/v1/billing/meter_events",
  params: %{"event_name" => "api_call", "payload" => %{...}},
  opts: []
})
```

Never use this in production application paths.

## Common pitfalls

1. **Reporting usage for a deleted customer.** Stripe silently drops with
   `meter_event_customer_not_found`. Stop reporting before removing a customer
   from Stripe. See [Reconciliation via webhooks](#reconciliation-via-webhooks).

2. **Not setting `identifier`.** Without a body-level identifier, a process
   restart causes double-counted events. Derive from a stable domain ID
   (invoice line item, request ID). See [Two-layer idempotency](#two-layer-idempotency).

3. **Putting `identifier` in the wrong place for adjustments.** The cancel param
   must be `%{"cancel" => %{"identifier" => "..."}}`, not top-level.
   GUARD-03 catches this at call time. See [Corrections and adjustments](#corrections-and-adjustments).

4. **Sending numeric values as integers.** The payload value must be a string
   (`"5"`, not `5`). Integers trigger `meter_event_invalid_value` — silently
   dropped in the async pipeline.

5. **Batch flushing accumulated events.** Events older than 35 days cannot be
   reported. Report at occurrence time, not in a nightly job. See
   [What NOT to do: nightly batch flush](#what-not-to-do-nightly-batch-flush).

6. **Missing `v1.billing.meter.error_report_triggered` handler.** Without this
   webhook, silent drops are invisible. Wire it before going live. See
   [The error-report webhook](#the-error-report-webhook).

7. **Deactivating a live meter.** New events return sync 400s and usage is
   **permanently lost**. Migrate all reporters to a new `event_name` before
   deactivating. Treat it as a destructive migration, not a pause.

## High-throughput metering (v2 event stream)

For use cases where you need to send **100+ events per second**, the v1
`MeterEvent.create/3` approach has too much per-request overhead. Each call is
a separate HTTP request with form-encoding, idempotency key generation, and
API key authentication overhead.

Stripe's v2 Billing Meter Event Stream API solves this with a session-token
model and JSON batch encoding. You create a short-lived session once (15 minutes),
then send batches of up to 100 events per request to a dedicated high-throughput
host (`meter-events.stripe.com`).

For lower-volume use cases, see `MeterEvent.create/3` above.

### Key differences from v1

| Aspect | v1 `MeterEvent.create/3` | v2 `MeterEventStream.send_events/4` |
|--------|--------------------------|--------------------------------------|
| Auth | API key (Bearer) | Session token (Bearer, 15-min TTL) |
| Host | `api.stripe.com` | `meter-events.stripe.com` |
| Encoding | form-urlencoded | JSON |
| Batch size | Single event | Up to 100 events |
| Response | Returns event object | Returns empty `%{}` |
| Idempotency | `identifier` body field + `Idempotency-Key` header | `identifier` field per event |

### Two-step usage

**Step 1: Create a session**

Call `MeterEventStream.create_session/2` once. It uses your standard API key
to POST to `api.stripe.com` and returns a `%Session{}` containing an
`authentication_token` valid for 15 minutes.

```elixir
alias LatticeStripe.Billing.MeterEventStream

{:ok, session} = MeterEventStream.create_session(client)
# session.authentication_token — bearer credential for send_events/4
# session.expires_at — Unix timestamp when the session expires
```

**Step 2: Send event batches**

Use the session to send batches of events to `meter-events.stripe.com`. Each
event map has the same shape as v1: `event_name`, `payload`, and optional
`identifier` and `timestamp` fields.

```elixir
events = [
  %{
    "event_name" => "api_call",
    "payload" => %{"stripe_customer_id" => "cus_001", "value" => "1"},
    "identifier" => "req_abc"
  },
  %{
    "event_name" => "api_call",
    "payload" => %{"stripe_customer_id" => "cus_002", "value" => "3"},
    "identifier" => "req_def"
  }
]

case MeterEventStream.send_events(client, session, events) do
  {:ok, %{}} ->
    # Events accepted — fire-and-forget like v1
    :ok

  {:error, :session_expired} ->
    # Session token has expired — create a new session
    {:ok, new_session} = MeterEventStream.create_session(client)
    MeterEventStream.send_events(client, new_session, events)

  {:error, %LatticeStripe.Error{} = err} ->
    # Handle API or connection error
    Logger.error("meter event stream error", type: err.type, message: err.message)
    {:error, err}
end
```

### Session renewal

Sessions have a 15-minute TTL. `send_events/4` performs a **client-side expiry
check** before each call — if `session.expires_at` is in the past, it returns
`{:error, :session_expired}` immediately without making a network request.

If the server returns a 401 with code `billing_meter_event_session_expired`
(can happen due to clock skew within the TTL window), `send_events/4` also
normalizes this to `{:error, :session_expired}`.

There is **no automatic session renewal**. The recommended pattern is to hold
the session in your process state and refresh on expiry:

```elixir
defmodule MyApp.MeterEventWorker do
  @moduledoc """
  GenServer that maintains a live v2 meter event stream session and sends
  batched events at high throughput.
  """
  use GenServer

  alias LatticeStripe.Billing.MeterEventStream

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    {:ok, session} = MeterEventStream.create_session(client)
    {:ok, %{client: client, session: session}}
  end

  def send_batch(events), do: GenServer.call(__MODULE__, {:send, events})

  def handle_call({:send, events}, _from, %{client: client, session: session} = state) do
    case MeterEventStream.send_events(client, session, events) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, :session_expired} ->
        # Renew and retry once
        {:ok, new_session} = MeterEventStream.create_session(client)

        result = MeterEventStream.send_events(client, new_session, events)
        {:reply, result, %{state | session: new_session}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end
end
```

### Empty events list

`send_events/4` returns `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`
immediately if given an empty list. No network call is made.

```elixir
{:error, %LatticeStripe.Error{type: :invalid_request_error, message: msg}} =
  MeterEventStream.send_events(client, session, [])
# msg: "events list cannot be empty"
```

### Telemetry

`MeterEventStream` emits telemetry spans for both operations:

- `[:lattice_stripe, :meter_event_stream, :create_session, :start | :stop | :exception]`
- `[:lattice_stripe, :meter_event_stream, :send_events, :start | :stop | :exception]`

Attach handlers to measure session creation overhead and batch send latency
separately:

```elixir
:telemetry.attach(
  "myapp-meter-stream-send",
  [:lattice_stripe, :meter_event_stream, :send_events, :stop],
  fn _event, measurements, metadata, _cfg ->
    ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    MyApp.Metrics.histogram("stripe.meter_stream.send_ms", ms, %{status: metadata.status})
  end,
  nil
)
```

### Security — session token masking

`%MeterEventStream.Session{}` implements a custom `Inspect` protocol that hides
the `authentication_token` field. The token is a bearer credential valid for
15 minutes — leaking it in Logger output or crash dumps would allow unauthorized
event submissions during the TTL window.

```
iex> IO.inspect(session)
#LatticeStripe.Billing.MeterEventStream.Session<id: "mes_123",
  object: "v2.billing.meter_event_session", created: 1712345678,
  expires_at: 1712346578, livemode: false>
```

Access the token directly when needed:

```elixir
session.authentication_token
```

## See also

- [subscriptions.md](subscriptions.md#subscription-schedules) — setting up
  metered prices, `usage_type: "metered"`, and `aggregate_usage`
- [webhooks.md](webhooks.md#reconciliation-via-webhooks) — the
  `v1.billing.meter.error_report_triggered` event handler pattern
- [telemetry.md](telemetry.md#custom-telemetry-handlers) — attaching
  `:lattice_stripe` telemetry handlers for the hot path
- [error-handling.md](error-handling.md) — `%LatticeStripe.Error{}` struct
  reference and the full error type taxonomy
- [testing.md](testing.md) — Mox transport mocks for unit-testing usage
  reporters and `stripe-mock` for integration tests
