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
Code examples throughout reflect the exact function signatures shipped in the
library.

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
> `value_settings.event_payload_key`, every event you report will silently drop in
> the async pipeline. `Billing.Guards.check_meter_value_settings!/1`
> raises at call time if
> `value_settings` is missing or empty for these formulas. Fix the meter; do not
> bypass the guard.

### customer_mapping

Tells Stripe which payload key identifies the customer. The only supported type
is `"by_id"` (Stripe customer ID). If the key is missing or maps to a deleted
customer, Stripe silently drops the event (see
[Reconciliation via webhooks](#reconciliation-via-webhooks)).

> **Note:** LatticeStripe does not currently guard `customer_mapping` presence
> at call time. A meter without it drops every event silently
> with `meter_event_no_customer_defined`.

### value_settings

Specifies which payload key holds the numeric usage value. Required for `"sum"`
and `"last"` formulas.

```elixir
"value_settings" => %{"event_payload_key" => "value"}
```

Pass that value as a decimal **string**. A plain integer is safe on the v1 path —
`5` and `"5"` produce byte-identical request bodies — but a float is not, and the
string form is the one that is safe everywhere. The full rules, and the table of
what each input shape actually puts on the wire, are in
[The payload contract](#the-payload-contract).

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
`event_name` fails with the `archived_meter` code. **Data is permanently lost** —
no buffer, no catch-up. Alert immediately. Whether that failure reaches you
synchronously as a `400`, asynchronously on the error-report webhook, or both, is
unverified — see [Error codes you must handle](#error-codes-you-must-handle).

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
  #
  # `value` is a decimal STRING, and `dimensions` is a flat map of extra payload
  # keys — see "The payload contract" for why both of those are the case.
  def report(client, event_name, customer_id, value, dimensions \\ %{}, opts \\ []) do
    event_id = Keyword.get_lazy(opts, :identifier, fn ->
      "#{event_name}:#{customer_id}:#{System.unique_integer([:positive])}"
    end)

    payload =
      Map.merge(dimensions, %{
        "stripe_customer_id" => customer_id,
        # Pass `value` in already as a decimal string. Do NOT call to_string/1 on
        # a float here — that call is the float hazard, not a fix for it.
        "value" => value
      })

    Task.Supervisor.start_child(AccrueLike.TaskSupervisor, fn ->
      :telemetry.span([:accrue, :usage_report], %{event_name: event_name}, fn ->
        # `idempotency_key:` is domain-derived on purpose: it is the only key
        # Stripe echoes back in an async error report.
        result = MeterEvent.create(client, %{
          "event_name" => event_name,
          "payload" => payload,
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

  # Fire and forget — does not block the response.
  # "1" is a string, and the dimensions map is flat: see The payload contract.
  AccrueLike.UsageReporter.report(stripe_client, "api_call", customer_id, "1",
    %{"region" => "us-west-2"},
    identifier: conn.assigns.request_id)

  result
end
```

## The payload contract

`payload` is the one part of a meter event you design yourself, and it is the one
part with no schema to check it against. Stripe types it as an object whose values
must all be strings; this library's encoder is a generic flattener that will
faithfully encode things Stripe then refuses. Here is what actually reaches the
wire.

| You pass | What goes on the wire | Verdict |
|---|---|---|
| `"value" => "5"` | `payload[value]=5` | Safe. The documented shape. |
| `"value" => 5` | `payload[value]=5` | Safe on v1 — byte-identical to the string form. |
| `"value" => "0.000001"` | `payload[value]=0.000001` | Safe. A string is passed through, never computed on. |
| `"value" => "0.123456789012345678901234567890123456"` | the same 36 digits | Safe. No rounding, no truncation. |
| `"value" => 0.0001` | `payload[value]=0.0001` | Survives — but it is a float. See Rule 2. |
| `"value" => 0.00001` | `payload[value]=1.0e-5` | **The cliff.** Exponent notation reaches Stripe. |
| `"value" => 0.1 + 0.2` | `payload[value]=0.30000000000000004` | Binary-float artifact, sent unrepaired. |
| `"region" => "us-west-2"` | `payload[region]=us-west-2` | Any dimension key you like. There is no allowlist. |
| `"meta" => %{"a" => "b"}` | `payload[meta][a]=b` | **Stripe rejects it.** Values must be strings. |
| `"tags" => ["a", "b"]` | `payload[tags][0]=a&payload[tags][1]=b` | Same — a list is not a string either. |
| `"value" => nil` | *(the key vanishes)* | Silently dropped. Send `"0"`, never `nil`. |

Four rules follow from that table, ordered by what they cost you when you get them
wrong.

### Rule 1 — flat only

Payload values must be strings as far as Stripe is concerned. This library's
encoder will happily flatten a nested map into bracketed keys, so the SDK lets you
build a request Stripe refuses; the rejection comes back naming the offending kind
(a map, a list). Keep every payload value a scalar, one level deep. If you have
structured data, flatten it into separate keys yourself before you call.

### Rule 2 — decimals as strings

A decimal passed as a **string** survives byte-exact to at least 36 significant
digits. A decimal passed as a **float** goes through Elixir's default stringifier,
which flips to scientific notation at `0.00001` — one decimal place away from
values people genuinely bill on, such as a per-token cost. The point is not that
the cliff exists somewhere far away; it is that the cliff is close.

Elixir's threshold is the narrowest in the ecosystem: Node flips a decimal place
later, and stripe-go formats with a verb that never emits exponent form at all.
Elixir is the language most likely to put an exponent on your wire.

Binary floating point also produces artifacts of its own, before any
stringification: adding two ordinary decimals can yield a long tail of digits
(`0.1 + 0.2` becomes `0.30000000000000004`), and that tail is sent as-is.

So: **pass decimals as strings, because Stripe does not document whether its parser
accepts exponent notation, so do not rely on it either way.**

One more consequence of the table: a `nil` value vanishes from the encoded body
entirely rather than being sent as empty, so a zero must be sent as a string zero
(`"0"`).

### Rule 3 — cardinality

Every distinct dimension value becomes its own series. Keep the value set bounded
and enumerable — `"region"`, `"sku"`, `"tenant_tier"` are dimensions; a user id, a
request id, or a session id is not. Never put an unbounded identifier in a
dimension.

### Rule 4 — dimensions are write-only on the generally available API

This is the rule that saves a week. On the GA API **you cannot read usage back
grouped by a custom dimension.** Stripe stores your dimensions, and offers no way
to group by them: the summary object has no dimensions field, a group-by parameter
on the read is rejected, and Stripe's canonical meter-configuration documentation
does not mention dimensions at all. Dimension grouping exists only in preview.

The workarounds are one meter per dimension value, or your own event store
alongside Stripe's. Choose before you design the payload, not after.

For what reads *are* possible today, see
[Reading usage back](#reading-usage-back).

### Why the idempotency key on a write is a read-path decision

When a meter event fails validation asynchronously, the only correlation key
Stripe hands back is the HTTP idempotency key of the failing request. This library
**auto-generates** one for every write when the caller does not supply
`idempotency_key:` — a value created inside the request, used once, and never
returned to you. Let it default and the only join key in the error report points
at something that exists nowhere in your system.

Pass a domain-derived `idempotency_key:` on every meter event write, one you can
look up later. The fire-and-forget recipe above already does this; the reason is
that error reports are useless without it. See
[Reconciliation via webhooks](#reconciliation-via-webhooks).

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

`Billing.Guards.check_adjustment_cancel_shape!/1`
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
The nested shape is enforced by `Billing.Guards.check_adjustment_cancel_shape!/1`
at call time and by Stripe's API.
Passing anything else returns a Stripe 400.

## Reading usage back

You reported the usage. Now something has to show it — a customer-facing "usage
this period" figure, an internal admin room, or a reconciliation job comparing
Stripe's totals against your own event store.

`LatticeStripe.Billing.MeterEventSummary` is the read half of the metering stack.
It serves exactly one Stripe endpoint,
`GET /v1/billing/meters/:meter_id/event_summaries`, and that is why the meter id
is a **positional argument** rather than a filter: Stripe offers no top-level
summary collection and no get-by-summary-id route, so every read is scoped to one
parent meter. `customer`, `start_time` and `end_time` are all required filters,
and the library raises `ArgumentError` before the request leaves your process if
any of them is missing.

### A total, or a series

This is the first decision, and the default is the trap.

**For a total, omit `value_grouping_window`.** Stripe aggregates server-side and
returns a single bucket: one request, no pagination, no client-side float
summation. This is what an admin screen showing "usage this period" almost always
wants.

```elixir
alias LatticeStripe.Billing.MeterEventSummary

# For a TOTAL: omit value_grouping_window -> one server-aggregated bucket,
# one request, no pagination, no client-side float summation.
{:ok, %{data: %{data: [summary]}}} =
  MeterEventSummary.list(client, meter.id, %{
    "customer" => sub.customer,
    "start_time" => aligned_start,
    "end_time" => aligned_end
  })

summary.aggregated_value
#=> 1042.0
```

**For a series, pass `value_grouping_window`** as `"hour"` or `"day"`, and read it
with `stream!/4` so that `has_more` is followed for you rather than silently
ignored.

```elixir
client
|> MeterEventSummary.stream!(meter.id, %{
  "customer" => sub.customer,
  "start_time" => aligned_start,
  "end_time" => aligned_end,
  "value_grouping_window" => "hour"
})
|> Enum.map(&{&1.start_time, &1.aggregated_value})
```

### The default page size returns a plausible wrong number

Stripe's `limit` ranges from 1 to 100 and **defaults to 10**. Ask for hourly
buckets across a 31-day month and the window holds **744** of them. Sum the ten
rows a bare `list/4` hands back, without checking `has_more`, and you get a
believable figure that is about one and a third percent of the truth. (That
percentage is an illustration assuming usage spread evenly across the buckets, not
a law — your real fraction depends on your data.)

The fix is usually not to paginate harder. It is to ask the question you actually
have. Rendering one usage figure for 200 customers costs roughly:

| How you ask | Requests across 200 customers |
|---|---|
| hourly buckets at the default limit of 10 | ~15,000 |
| hourly buckets at `"limit" => 100` | ~1,600 |
| no `value_grouping_window` at all | 200 |

`Enum.sum` over a `list/4` result is the warning sign. If you need every bucket,
use `stream!/4`; if you need one number, drop the window. See `LatticeStripe.List`
for the memory guidance that applies to any stream you do not bound with
`Stream.take/2`.

### Three things the signature will not tell you

**The summary never says which customer it belongs to.** The object has seven
fields — `id`, `object`, `aggregated_value`, `start_time`, `end_time`, `meter` and
`livemode` — not one of them names a customer, and it cannot be expanded to add
one. The customer is an *input* to the query and never an *output*. A reconciler
that lists summaries for several customers and merges the results has lost the
attribution completely, and the warning sign is easy to miss: grouping the merged
list by a customer field is not something you can even attempt, because the field
does not exist. Keep the association out of band, alongside the customer id you
filtered on.

**The figure is eventually consistent.** Stripe's specification says so in as many
words. There is no freshness field on the object and no published staleness SLA,
so a caller has no way to tell how old a number is. Label the figure in your UI
with the time you fetched it, never present it as live, and never treat it as a
billing source of truth — Stripe bills from the meter, not from these summaries.

**The end of the window is ambiguous, and this library asserts neither reading.**
Stripe's own specification contradicts itself. The `end_time` query parameter and
the `end_time` field on the returned object are both documented as *exclusive*,
while `aggregated_value`'s description on that same object says the aggregation
covers `start_time` through `end_time` *inclusive*. Two of the three say
exclusive. All three ship verbatim into every SDK's generated documentation, so
the same contradiction is waiting in Stripe's other libraries. If one boundary
event would change a decision you are making, do not settle it by reading
documentation — measure it against your own account.

One more, for anyone drawing a chart: do not assume a bucket exists for every
interval in the window. Fill gaps by `start_time`, never by index.

### Timestamps must be aligned, and this library will not align them for you

Stripe requires `start_time` and `end_time` to be aligned to **minute** boundaries
on every query, to **UTC hour** boundaries when `value_grouping_window` is
`"hour"`, and to **UTC day** boundaries (00:00 UTC) when it is `"day"`. The
timezone is UTC — not the account's, not the customer's.

The most natural inputs are the ones that violate this. A subscription's
`current_period_start` and `current_period_end` derive from its
`billing_cycle_anchor`, so they land on an arbitrary second and are almost never
aligned to anything.

`Billing.Guards.check_summary_window!/2` raises `ArgumentError` from both `list/4`
and `stream!/4` **before** the request is built, naming the offending value and
the boundary it missed. Stripe answers a misaligned window with an HTTP 400 whose
error code it does not document, so this failure can be prevented but not improved
after the fact.

The guard prints the arithmetic instead of applying it. Rounding changes what the
query means — floor the start and you sweep in usage from before the period, ceil
it and you drop usage that belongs to it — and that is a business decision, not a
formatting detail. Do it yourself, where you can see it:

```elixir
# Day-aligned window. Use 3_600 for "hour", and 60 when no grouping window is set.
start_time = Integer.floor_div(start_time, 86_400) * 86_400
end_time = -Integer.floor_div(-end_time, 86_400) * 86_400
```

`Integer.floor_div/2` rather than `div/2`: `div/2` truncates toward zero, which
rounds the wrong way for negative inputs.

### Testing

Meter summary reads are unit-tested the way every other resource family is: Mox at
the Transport boundary with wire-shaped fixture maps. That is also the only place
pagination can be proven — `stripe-mock` serves this path and validates the
required parameters and the window enum, but it returns a single synthetic item
and ignores both `limit` and `starting_after`, so it cannot exercise a second
page. The summary fixtures are private test support today; public
`LatticeStripe.Testing` fixtures for the metering objects land in a later release,
and this section will document them when they do. See [testing.md](testing.md)
for the Mox setup this family follows.

### Webhooks

Metering's asynchronous failures arrive as the
`v1.billing.meter.error_report_triggered` event, and its payload is decoded by
calling `LatticeStripe.Billing.MeterErrorReport.from_event/1` explicitly rather
than through the webhook object registry. The registry dispatches on an `"object"`
key that this payload does not carry — it is event data, not an object — so it
cannot reach it, and that is a structural fact about the wire format rather than a
gap. [Reconciliation via webhooks](#reconciliation-via-webhooks) below is the
working handler. Registry coverage for the other metering object types lands in a
later release, and this section will cover it when it does. See
[webhooks.md](webhooks.md) for signature verification and handler setup.

## Reconciliation via webhooks

### The error-report webhook

Most metering failure modes surface asynchronously. Stripe fires
`v1.billing.meter.error_report_triggered` when processing errors accumulate.

This is a **v2 thin event**: what Stripe POSTs to your endpoint is an
announcement, not a payload. Its body carries `id`, `type`, `created`,
`related_object` and a `reason` — and no `data` member at all. `data` is a
*fetched* attribute, so the handler's first move is to re-request the versioned
event over your authenticated channel. That re-fetch is also what makes the
payload trustworthy: the delivered body is attacker-reachable, the fetched event
is not.

```elixir
alias LatticeStripe.{EventNotification, Webhook}
alias LatticeStripe.Billing.MeterErrorReport
alias LatticeStripe.Billing.MeterErrorReport.{ErrorType, SampleError}

def handle_notification(
      %EventNotification{type: "v1.billing.meter.error_report_triggered"} = notif,
      client
    ) do
  # NOT optional, and the step every adopter gets wrong: `data` is a fetched
  # attribute — the webhook body does not contain it.
  {:ok, event} = Webhook.fetch_event(client, notif)
  report = MeterErrorReport.from_event(event)

  for %ErrorType{code: code, sample_errors: samples} <- report.reason.error_types,
      %SampleError{request_identifier: key, error_message: msg} <- samples do
    MyApp.Billing.MeterEvents.mark_failed_by_idempotency_key(key, code, msg)
  end
end
```

`report.meter` is the meter id, lifted from the event envelope — it is not in
`data`, so only `LatticeStripe.Billing.MeterErrorReport.from_event/1` can populate
it. `report.validation_start` and `report.validation_end` delimit the window of
usage the report covers, and they are RFC3339 strings rather than Unix integers.
That window is the one to re-read with
`LatticeStripe.Billing.MeterEventSummary.list/4` when you want to see the hole the
failures left.

There are no grouping or counting helpers to reach for, deliberately: Stripe
already groups by error type and supplies a count at both levels, so the wire
supplies the ergonomics.

> **Note:** Keep this handler fast — log, enqueue, return. No inline DB
> queries or external calls beyond the event fetch itself.

### Error codes you must handle

These are the ten values of the `code` field on
`reason.error_types[]`. Stripe documents the enum as **open**, so match on the
binary and always keep a catch-all clause — new values arrive without a version
bump, and Stripe has retired one already.

| `code` | When | Silent drop? | Remediation |
|---|---|---|---|
| `meter_event_customer_not_found` | customer deleted | YES (async) | Sweep job |
| `meter_event_no_customer_defined` | payload missing mapping key | YES (async) | Fix reporter |
| `meter_event_invalid_value` | value rejected by Stripe's parser | YES (async) | See [The payload contract](#the-payload-contract) |
| `meter_event_value_too_many_digits` | value exceeds Stripe's 15-digit limit | YES (async) | Round before reporting; do not send full float precision |
| `meter_event_dimension_count_too_high` | too many payload dimension keys | YES (async) | Reduce dimensions on the reporter |
| `missing_dimension_payload_keys` | `payload` is missing a dimension key the meter expects | YES (async) | Fix reporter payload keys |
| `no_meter` | no meter matches the `event_name` | YES (async) | Fix the `event_name`, or create the meter |
| `archived_meter` | meter deactivated | YES — also sync? (unverified) | Alert — data PERMANENTLY LOST |
| `timestamp_too_far_in_past` | >35 days | YES — also sync? (unverified) | Drop batch flush anti-pattern |
| `timestamp_in_future` | >5 min future | YES — also sync? (unverified) | Fix clock skew |

> **Why three rows carry a question mark.** Every code in this table is a value of
> the asynchronous error-report enum, so all ten can reach you asynchronously.
> This guide additionally used to classify `archived_meter`,
> `timestamp_too_far_in_past` and `timestamp_in_future` as synchronous-only
> `400`s, *exclusively*. That exclusive claim is unverified — Stripe could return
> a code synchronously and also report it asynchronously — so it is labelled here
> rather than restated. Handle these three on **both** paths.

The "Silent drop?" column is what makes this table worth reading. An asynchronous
failure means usage was silently not recorded against the customer, so it affects
revenue and you will only ever hear about it here. A synchronous failure comes
back directly as `{:error, %LatticeStripe.Error{}}` from `MeterEvent.create/3`.
The three rows above are documented on both paths without a verified resolution;
assume either can reach you.

### Remediation patterns

**`meter_event_customer_not_found`:** A customer was deleted between reporting
and processing. Add a sweep job reconciling deleted customer IDs against your
customer table.

**`meter_event_no_customer_defined`:** Your `payload` is missing the key named
in `customer_mapping.event_payload_key`. Fix the reporter key to match the meter
schema — every event is dropping silently until you do.

**`meter_event_invalid_value`:** Stripe could not parse the value. Common causes:
`nil` where you meant zero (a `nil` vanishes from the encoded body entirely — send
`"0"`), a formatted string like `"1,000"`, or a float that stringified into
exponent notation. Note that a plain integer is *not* a cause on the v1 path; see
[The payload contract](#the-payload-contract).

**A missing value key:** if the meter's formula is `"sum"` or `"last"` and the
payload has no key matching `value_settings.event_payload_key`, the event is
dropped. This is exactly the failure mode `check_meter_value_settings!/1` prevents
at call time. Fix the meter definition or the reporter payload key.

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

**`Billing.Guards.check_meter_value_settings!/1`**

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

**`Billing.Guards.check_adjustment_cancel_shape!/1`**

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
   `check_adjustment_cancel_shape!/1` catches this at call time. See [Corrections and adjustments](#corrections-and-adjustments).

4. **Sending a payload value as a float.** Elixir's default stringifier flips to
   scientific notation at `0.00001`, so a per-token cost can reach Stripe as
   `1.0e-5`. Pass decimals as strings. An integer is safe on the v1 path — `5` and
   `"5"` encode byte-identically — with one exception: the v2 event stream encodes
   as JSON, where the value genuinely must be a string. See
   [The payload contract](#the-payload-contract).

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
- [metering-runtime-and-reconciliation.md](metering-runtime-and-reconciliation.md) —
  runtime-first operator guidance for event ingestion, reconciliation, and correction
- [recipes.md](recipes.md) — compact job-to-primitive bridge before the deeper metering guide
