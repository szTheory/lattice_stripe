# Domain Pitfalls

**Domain:** LatticeStripe v1.1 — Billing.Meter, Billing.MeterEvent + MeterEventAdjustment, BillingPortal.Session
**Researched:** 2026-04-13
**Confidence:** HIGH (Stripe API docs verified; MEDIUM where undocumented behavior noted)

> **Scope note:** This file covers ONLY pitfalls specific to the three new v1.1 resources.
> The v1.0 foundation pitfalls (webhook raw-body, global config, retry double-charge, etc.)
> are resolved and are NOT carried forward — they are permanently closed as of v1.0.0.

---

## Critical Pitfalls

### Pitfall 1: MeterEvent Idempotency Two-Layer Trap

**What goes wrong:**

Two orthogonal idempotency mechanisms exist and they are NOT interchangeable:

- **Layer 1 — HTTP header:** `Stripe-Idempotency-Key` (maps to `idempotency_key:` opt in LatticeStripe). Deduplicates the HTTP *request* at Stripe's API gateway layer. Scope: the specific HTTP call. Stripe's standard 24-hour window for idempotency key replay.
- **Layer 2 — Body field:** `identifier` in the MeterEvent JSON body. Deduplicates within the *metering domain*. If two requests share the same `identifier`, the second event is silently ignored regardless of whether the HTTP idempotency key matches. The deduplication window is "at least 24 hours" (Stripe docs), rolling. Max 100 characters.

The trap: a developer who sets `idempotency_key:` but omits `identifier` (or auto-generates a new UUID each retry) is only protected at the HTTP layer. If the HTTP retry uses a different idempotency key (e.g., after a process restart that lost the in-memory key), no deduplication occurs and a duplicate billing event is created — double-charging the customer.

Conversely, a developer who uses `identifier` but omits `idempotency_key:` is protected against domain-level duplicates but not against concurrent racing requests that each send the same event before Stripe's dedup window fires.

stripe-mock is stateless and cannot reproduce the `identifier`-based dedup behavior. Tests that verify this layer must be documented as requiring real Stripe test mode.

**Why it happens:**

The two mechanisms look similar ("both prevent duplicates") but operate independently. Stripe's documentation describes them in separate sections and neither explicitly warns about the two-layer interaction. Most SDK docs show only the idempotency key header and don't mention `identifier`.

**How to avoid:**

1. Document both mechanisms clearly and separately in `MeterEvent.create/3` `@doc` — label them `identifier` (domain-level, 24h rolling, body field) and `idempotency_key:` (request-level, gateway, header).
2. In the `guides/metering.md`, show the recommended pattern:
   ```elixir
   # Generate a stable identifier from domain data (survives process restarts)
   identifier = "#{customer_id}:#{event_name}:#{unix_second}"
   MeterEvent.create(client, %{
     "event_name" => "api_call",
     "payload" => %{"stripe_customer_id" => customer_id, "value" => 1},
     "identifier" => identifier
   }, idempotency_key: identifier)
   ```
3. Do NOT alias or conflate the two in the implementation — `identifier` is a body param, `idempotency_key:` is an opt passed to `Client.request/2` as a header. They both accept the same string value in the recommended pattern above, but they travel through different code paths.
4. Add a doctest or note: "stripe-mock cannot reproduce identifier-based deduplication. Test domain-level idempotency against Stripe test mode."

**Warning signs:**

- Accrue's `report_usage/3` logs show duplicate `billing.meter_event.created` webhook events on retries.
- Stripe dashboard shows usage summed at 2× expected value for a period.
- MeterEvent test passes with stripe-mock but produces duplicates in staging.

**Phase to address:** Phase 20, Plan 20-04 (MeterEvent module) — `@doc` for `create/3` must contain both mechanisms. Plan 20-06 (guide) — `guides/metering.md` must show the stable `identifier` pattern.

---

### Pitfall 2: MeterEvent Timestamp Backdating Window

**What goes wrong:**

The `timestamp` field in a MeterEvent create request must be:
- No more than **35 calendar days** in the past — Stripe returns `timestamp_too_far_in_past` error (HTTP 400).
- No more than **5 minutes** in the future — Stripe returns `timestamp_in_future` error (HTTP 400).

If Accrue's usage reporting pipeline batches events and flushes them later (e.g., reporting yesterday's usage at batch time), any event timestamp older than 35 days is silently dropped by the batch with a 400. If the batch failure is not surfaced to the caller, the usage is permanently lost — Stripe cannot accept the event after the window closes.

**Why it happens:**

Developers assume Stripe accepts arbitrary backdated timestamps for reconciliation. The 35-day window is specific to the v1 `meter_events` endpoint and is not prominently documented in the SDK integration guides. The v2 endpoint has different constraints.

**How to avoid:**

1. Document the constraint prominently in `MeterEvent.create/3` `@doc` and `guides/metering.md`:
   - "timestamp must be within the past 35 calendar days and no more than 5 minutes in the future"
   - Include the exact error codes: `timestamp_too_far_in_past`, `timestamp_in_future`
2. Accrue's `report_usage/3` should pass `timestamp` at the time of the event (not at flush time). LatticeStripe does not need to enforce this — it passes through whatever timestamp the caller provides — but the guide must warn about batch-flush anti-patterns.
3. Note in docs: if no timestamp is provided, Stripe uses the current server time.

**Warning signs:**

- Batch billing reconciliation jobs return 400 errors with `timestamp_too_far_in_past` code.
- Usage for customers in a specific billing period is unexpectedly zero despite events being sent.
- Stripe `billing.meter.error_report_triggered` webhook fires with `timestamp_too_far_in_past` errors.

**Phase to address:** Phase 20, Plan 20-04 (`@doc` constraint) and Plan 20-06 (guide anti-pattern section).

---

### Pitfall 3: MeterEvent customer_mapping Key Silent-Drop

**What goes wrong:**

When a MeterEvent arrives at Stripe, the payload is checked for the key configured in `customer_mapping.event_payload_key` (typically `"stripe_customer_id"`). If that key is absent from the payload, Stripe does NOT return a synchronous 400 — it accepts the event with HTTP 200, processes it asynchronously, and then fires a `v1.billing.meter.error_report_triggered` webhook event with error code `meter_event_no_customer_defined`.

The result: the event is silently dropped from billing aggregation. No usage is recorded. No synchronous error surfaces to Accrue's `report_usage/3` call. The customer is not billed for real usage.

Similarly, if the customer ID value in the payload refers to a customer that does not exist in Stripe, the error code is `meter_event_customer_not_found` — same silent async failure pattern.

**Why it happens:**

Stripe's v1 meter events endpoint is fire-and-forget by design (high throughput, low latency). Synchronous validation is limited to request-level checks (auth, schema). Domain-level validation (does this customer exist? does the payload have the right key?) is asynchronous. Developers testing against stripe-mock see consistent 200s and do not discover the silent-drop until production billing data is missing.

**How to avoid:**

1. Document the async failure mode explicitly in `MeterEvent.create/3` `@doc`:
   - "A successful `{:ok, %MeterEvent{}}` response means Stripe accepted the event for processing, not that it was recorded. Subscribe to `v1.billing.meter.error_report_triggered` to catch customer mapping failures."
2. In `guides/metering.md`, include a "Monitoring" section with the `billing.meter.error_report_triggered` webhook and the relevant error codes: `meter_event_no_customer_defined`, `meter_event_customer_not_found`.
3. LatticeStripe does NOT need to pre-validate the payload key — that would require knowing the meter configuration at call time, coupling the two resources unnecessarily. The guide-level warning is sufficient.
4. Accrue must subscribe to the error webhook in its own webhook handler.

**Warning signs:**

- Billing period usage shows zero despite `{:ok, %MeterEvent{}}` responses.
- `v1.billing.meter.error_report_triggered` webhook fires repeatedly.
- Stripe error report shows `meter_event_no_customer_defined` or `meter_event_customer_not_found` samples.

**Phase to address:** Phase 20, Plan 20-04 (`@doc` on `create/3`) and Plan 20-06 (guide monitoring section). Note this during Plan 20-01 wave-0 probe — confirm stripe-mock returns 200 without validating the customer mapping key.

---

### Pitfall 4: formula: sum with No value_settings — Silent Zero Aggregation

**What goes wrong:**

When a Meter is created with `default_aggregation.formula = "sum"`, Stripe expects each MeterEvent's payload to contain a numeric value at the key specified in `value_settings.event_payload_key` (default key: `"value"`). If `value_settings` is omitted from the Meter create request, Stripe uses `"value"` as the default key — but if MeterEvents subsequently arrive with no `"value"` key in their payloads (or with a string instead of a number), Stripe fires `meter_event_value_not_found` or `meter_event_invalid_value` async error events, and the aggregated sum for the billing period is zero.

For `formula: "count"`, `value_settings` is irrelevant — Stripe counts events, not values. A developer who builds the count flow correctly may copy the same payload shape for a sum meter and forget to include the numeric value — the count meter worked fine, the sum meter silently aggregates zero.

**Why it happens:**

The `value_settings` field is optional on Meter create (it has a default), which masks the dependency. The async validation path means the error only surfaces at billing time, not at event submission time. stripe-mock does not validate numeric types in the payload.

**How to avoid:**

1. In `Meter.DefaultAggregation` `@typedoc`, document the formula semantics clearly:
   - `sum`: requires numeric value at `value_settings.event_payload_key` in each MeterEvent payload
   - `count`: ignores payload values; event presence is the unit
   - `last`: takes the last value in the window; same payload requirement as `sum`
2. In `guides/metering.md`, include a code example for each formula showing the corresponding MeterEvent payload shape.
3. Add a guard in `Meter.create/3` that raises when `default_aggregation.formula` is `"sum"` or `"last"` and `value_settings` is absent from params — fail fast before the API call rather than silently producing zero usage at billing time:
   ```elixir
   def create(%Client{} = client, params, opts \\ []) do
     formula = get_in(params, ["default_aggregation", "formula"])
     if formula in ["sum", "last"] and not Map.has_key?(params, "value_settings") do
       raise ArgumentError,
         "Meter.create/3 with formula \"#{formula}\" requires value_settings. " <>
         "Omitting value_settings means MeterEvent payloads must use the default key \"value\"."
     end
     # ... rest of create
   end
   ```
   Note: this is a warning guard, not a blocking error — Stripe itself allows omitting value_settings (it defaults to `"value"`). But the guide must document the implicit contract.

**Warning signs:**

- Billing period usage shows zero despite MeterEvents being reported.
- `meter_event_value_not_found` or `meter_event_invalid_value` in error reports.
- Swapping from a count meter to a sum meter without updating payload shape.

**Phase to address:** Phase 20, Plan 20-02 (nested struct `@typedoc` documentation) and Plan 20-03 (guard in `Meter.create/3`).

---

### Pitfall 5: Meter Status Lifecycle — Events to Inactive Meter Return archived_meter Error

**What goes wrong:**

When a meter is deactivated (status → `inactive`), any subsequent MeterEvent with a matching `event_name` returns an error with code `archived_meter`. This is a **synchronous** error — unlike customer mapping failures, this surfaces immediately as a non-200 response. LatticeStripe will correctly map this to `{:error, %Error{type: :invalid_request_error, code: "archived_meter"}}`.

However, Accrue's `report_usage/3` hot path may not be monitoring for this error code. If Accrue does not check `error.code` and treats all `{:error, _}` uniformly (e.g., retry), it will retry an event against a deactivated meter indefinitely, burning rate limit budget.

Deactivation is reversible via `reactivate/3` (POST `/v1/billing/meters/:id/reactivate`). Historical aggregation data from before deactivation persists — reactivation does not reset the meter's event history. However: events submitted while the meter was inactive are NOT retroactively processed; they are permanently lost.

**Why it happens:**

Meter lifecycle management is an ops concern. Accrue's hot path is built assuming the meter is always active. Deactivation of the wrong meter in a Stripe dashboard or via an admin script can silently break billing for all customers on that meter until the error is noticed.

**How to avoid:**

1. Document `deactivate/3` behavior clearly: "Deactivating a meter causes all subsequent MeterEvents with that event_name to fail with `archived_meter`. Events submitted during the inactive period are permanently lost — reactivation does not retroactively process them."
2. Add a `@doc` note to `MeterEvent.create/3`: "If the error code is `archived_meter`, do not retry. Reactivate the meter first via `Meter.reactivate/3`."
3. Accrue should pattern-match `archived_meter` as a non-retryable error in its billing pipeline — but this is Accrue's concern, not LatticeStripe's. LatticeStripe's job is to surface the error code clearly via `%Error{code: "archived_meter"}`.
4. Verify the `archived_meter` error is normalized into a pattern-matchable `error.code` in the existing error model (it should be, as all Stripe API errors flow through the same error normalization path in v1.0).

**Warning signs:**

- `{:error, %Error{code: "archived_meter"}}` responses from `MeterEvent.create/3`.
- Usage reporting stops for all customers simultaneously.
- Retry loops on `archived_meter` errors exhausting rate limits.

**Phase to address:** Phase 20, Plan 20-03 (document `deactivate/3` behavior) and Plan 20-04 (`@doc` on `MeterEvent.create/3`). Plan 20-05 integration test should assert shape of 400-level errors from stripe-mock when applicable.

---

### Pitfall 6: MeterEventAdjustment — Wrong Field Names in cancel Sub-Object

**What goes wrong:**

The `cancel` sub-object in `MeterEventAdjustment.create/3` params uses the field `cancel.identifier` — this is the `identifier` string from the original MeterEvent being cancelled, NOT a sub-object nested further. The exact shape is:

```elixir
%{
  "event_name" => "api_call",
  "type" => "cancel",
  "cancel" => %{
    "identifier" => "evt_abc123"
  }
}
```

Common mistake: using `"id"` or `"event_identifier"` instead of `"identifier"`. Stripe returns a 400 with a param error. A second mistake is sending `"identifier"` at the top level rather than nested inside `"cancel"`.

The 24-hour cancellation window is hard: events older than 24 hours cannot be adjusted. Stripe returns a 400. stripe-mock does not enforce the 24-hour window (stateless) — tests pass in CI but adjustments fail in production for events older than a day.

**Why it happens:**

The API shape is `cancel.identifier` but developers conflate it with the top-level `identifier` field on MeterEvent (a different field serving a different purpose). The naming is similar enough to cause confusion. stripe-mock's inability to simulate the time window gives false confidence.

**How to avoid:**

1. In `MeterEventAdjustment` `@typedoc` and `create/3` `@doc`, show the exact param map shape with a code example. Use the literal field names from Stripe docs (`"cancel"` → `"identifier"`).
2. In `MeterEventAdjustment` struct's `@typedoc`, explicitly document the `cancel` sub-field:
   - `cancel: %{identifier: String.t() | nil}` — the `identifier` of the original MeterEvent to cancel
3. In `guides/metering.md`, include a reconciliation example showing `MeterEventAdjustment.create/3` with the exact nested map.
4. In unit tests (Plan 20-04), assert the `from_map/1` correctly decodes `cancel.identifier` from the fixture.
5. Document the 24-hour limit with a note: "stripe-mock does not enforce the 24-hour cancellation window — integration test coverage is best-effort in CI; test against Stripe test mode for full validation."

**Warning signs:**

- `{:error, %Error{param: "cancel[identifier]"}}` or similar param errors from Stripe.
- Adjustment integration tests pass but production corrections fail with 400.
- Accrue correction flows silently fail when trying to fix over-reported events.

**Phase to address:** Phase 20, Plan 20-04 (MeterEventAdjustment module and unit tests).

---

### Pitfall 7: FlowData Type Validation — Server-Side 400 for Missing Required Sub-Fields

**What goes wrong:**

`BillingPortal.Session.create/3` accepts a `flow_data` parameter that deep-links the customer to a specific portal flow. The `type` field is an enum:

| Flow Type | Required sub-fields |
|-----------|-------------------|
| `payment_method_update` | None (type alone is sufficient) |
| `subscription_cancel` | `subscription_cancel.subscription` (subscription ID) |
| `subscription_update` | `subscription_update.subscription` |
| `subscription_update_confirm` | `subscription_update_confirm.subscription` + `subscription_update_confirm.items` array |

If a developer passes `flow_data: %{"type" => "subscription_cancel"}` without `"subscription_cancel" => %{"subscription" => "sub_..."}`, Stripe returns a 400 `invalid_request_error`. The error is late — it surfaces only after the HTTP round-trip, not at struct construction time.

The v1.0 precedent for this class of problem is `pause_collection/5`'s atom guard at the function head: `when behavior in [:keep_as_draft, :mark_uncollectible, :void]`. The analogue for FlowData is a client-side validation that raises early when required sub-fields are missing.

**Why it happens:**

Flow types have different required shapes, but all flow through the same `create/3` params map. Without client-side validation, the error is a generic 400 from Stripe that may not clearly identify which sub-field is missing. stripe-mock may or may not enforce required sub-fields for all flow types.

**How to avoid:**

Use `Resource.require_param!` (already in v1.0) for basic validation, and add a flow-type sub-field check in `Session.create/3` that mirrors the existing pattern:

```elixir
def create(%Client{} = client, params, opts \\ []) do
  Resource.require_param!(params, "customer",
    ~s|BillingPortal.Session.create/3 requires "customer". Example: %{"customer" => "cus_..."}|)

  case get_in(params, ["flow_data", "type"]) do
    nil -> :ok
    "payment_method_update" -> :ok
    "subscription_cancel" ->
      unless get_in(params, ["flow_data", "subscription_cancel", "subscription"]) do
        raise ArgumentError, ~s|flow_data.type "subscription_cancel" requires flow_data.subscription_cancel.subscription|
      end
    "subscription_update" ->
      unless get_in(params, ["flow_data", "subscription_update", "subscription"]) do
        raise ArgumentError, ~s|flow_data.type "subscription_update" requires flow_data.subscription_update.subscription|
      end
    "subscription_update_confirm" ->
      unless get_in(params, ["flow_data", "subscription_update_confirm", "subscription"]) do
        raise ArgumentError, ~s|flow_data.type "subscription_update_confirm" requires subscription + items|
      end
    unknown ->
      raise ArgumentError, ~s|Unknown flow_data.type "#{unknown}". Valid: payment_method_update, subscription_cancel, subscription_update, subscription_update_confirm|
  end
  # ... rest of create
end
```

This follows `pause_collection/5`'s atom guard precedent — fail fast at the SDK boundary before touching the network.

**Warning signs:**

- 400 errors from `Session.create/3` with param errors referencing `flow_data`.
- Accrue portal redirect fails for subscription cancellation deep links but works for plain sessions.
- stripe-mock returns 200 but Stripe test mode returns 400 (if stripe-mock is lenient about sub-fields).

**Phase to address:** Phase 21, Plan 21-03 (Session module) — the validation guard belongs in `create/3` alongside the `customer` require check.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Omit `identifier` in MeterEvent, rely only on `idempotency_key:` | Simpler call site | Double-billing on process-restart retries (different idempotency keys) | Never — always set a stable `identifier` |
| Raw map for `FlowData` sub-objects (`subscription_cancel`, etc.) instead of typed structs | Less code in Phase 21 | Pattern-match on `session.flow.subscription_cancel.subscription` fails with raw map | Acceptable for v1.1 — Accrue does not pattern-match sub-flow internals (confirmed in v1.1 brief) |
| Skip guard for `formula: sum` missing `value_settings` | Fewer lines in `Meter.create/3` | Silent zero usage at billing time; no early error | Never — add the warning guard |
| Omit webhook monitoring guidance for `billing.meter.error_report_triggered` | Shorter guide | Accrue operators unaware of silent payload drop failures | Never — include in `guides/metering.md` |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| MeterEvent + stripe-mock | Assuming stripe-mock validates customer mapping keys | stripe-mock returns 200 for any payload shape; domain validation is async in real Stripe. stripe-mock covers request shape only. |
| MeterEvent + stripe-mock | Assuming stripe-mock enforces `identifier` deduplication | stripe-mock is stateless — identical identifiers both succeed in tests. Test dedup against Stripe test mode only. |
| MeterEventAdjustment + stripe-mock | Assuming stripe-mock enforces the 24-hour cancellation window | stripe-mock accepts any adjustment. The window is only enforced by real Stripe. Document this constraint in the integration test file. |
| BillingPortal.Session + Connect | Using `stripe_account:` opt without awareness that `on_behalf_of` is a distinct param | `stripe_account:` routes the entire request through a connected account (direct charges). `on_behalf_of` filters which subscriptions appear in the portal. Both may be needed simultaneously for Connect platforms. Thread both through the existing v1.0 opts plumbing; document the distinction. |
| BillingPortal.Session URL | Attempting to reuse a session URL for multiple customers or browser sessions | Portal session URLs are single-use and short-lived. Create a new session per redirect. |
| Billing.Meter + Billing.MeterEvent | Using `event_name` that doesn't match any Meter's `event_name` | Stripe returns `no_meter` error (async). Create the Meter first and match event names exactly — Stripe is case-sensitive. |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Synchronous MeterEvent reporting on every user request in Accrue | p99 latency spikes when Stripe is slow | Accrue (not LatticeStripe) should enqueue events and flush asynchronously. LatticeStripe provides the flush call. | At any scale — Stripe's v1 endpoint is sub-100ms but blocking adds latency variability |
| `Meter.list/3` without `status` filter on large accounts | Slow list fetches, unnecessary data | Use `Meter.list(client, %{"status" => "active"})` to scope results. Document in guide. | At 50+ meters |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging MeterEvent `payload` map in production | PII exposure — payload typically contains `stripe_customer_id` and usage values; could contain PII if caller embeds email/name | Implement custom `Inspect` for `MeterEvent` struct that masks `:payload` field — same pattern as `Subscription` and `Checkout.Session` in v1.0 |
| Logging BillingPortal.Session `url` | The session URL is a single-use authentication link; logging it creates an audit trail that could be replayed | Add `Inspect` guard for `BillingPortal.Session` that masks `:url`. Treat it like a token. |
| Embedding customer ID in `identifier` and logging it | Structured logs may capture `identifier` values that encode customer IDs, leaking PII | Note in `guides/metering.md`: "if your identifier scheme encodes customer IDs, filter it from production log aggregation" |

---

## "Looks Done But Isn't" Checklist

- [ ] **MeterEvent.create/3 docs:** Mentions both `identifier` (domain-level, body, 24h) and `idempotency_key:` (request-level, header) — not just one.
- [ ] **MeterEvent.create/3 docs:** States the 35-day backdating limit and 5-minute future limit with exact error codes.
- [ ] **MeterEvent.create/3 docs:** Warns that `{:ok, %MeterEvent{}}` is an accepted-for-processing ack, not a billing-recorded confirmation. Points to `v1.billing.meter.error_report_triggered` webhook.
- [ ] **MeterEventAdjustment.create/3 docs + unit tests:** Uses `"cancel" => %{"identifier" => ...}` (nested), not `"identifier"` at top level.
- [ ] **Meter.create/3:** Guard raises `ArgumentError` when `formula` is `"sum"` or `"last"` and `value_settings` is absent.
- [ ] **Meter.deactivate/3 docs:** States that events submitted during inactive period are permanently lost (not queued).
- [ ] **BillingPortal.Session.create/3:** `Resource.require_param!` guard for `"customer"` present.
- [ ] **BillingPortal.Session.create/3:** Flow-type sub-field validation for `subscription_cancel`, `subscription_update`, `subscription_update_confirm` present.
- [ ] **BillingPortal.Session struct:** `Inspect` protocol implementation masks `:url` field.
- [ ] **MeterEvent struct:** `Inspect` protocol implementation masks `:payload` field.
- [ ] **guides/metering.md:** Contains "Monitoring" section covering `v1.billing.meter.error_report_triggered` and the relevant error codes.
- [ ] **Integration tests (Plan 20-05):** Contains comment explaining which behaviors cannot be verified against stripe-mock (identifier dedup, 24-hour windows).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| MeterEvent duplicate from two-layer idempotency misuse | HIGH — requires Stripe support to investigate billing anomalies | (1) Identify duplicate events via `billing.meter.event` webhook history. (2) Submit `MeterEventAdjustment.create/3` with `type: "cancel"` for the duplicate — only works within 24h. (3) After 24h: requires Stripe support ticket. Prevent recurrence by fixing `identifier` generation. |
| Events sent to inactive meter lost (archived_meter) | MEDIUM — usage data for the gap period is unrecoverable | (1) Reactivate meter via `Meter.reactivate/3`. (2) For lost events within the 35-day window: re-submit with original timestamps. (3) For events outside the 35-day window: data is permanently lost; file Stripe support ticket for manual adjustment. |
| Missing customer_mapping key in payload — silent drop | MEDIUM | (1) Subscribe to `billing.meter.error_report_triggered` to detect going forward. (2) Identify affected customers and time range. (3) Re-submit corrected events with original timestamps (only if within 35-day window). |
| FlowData missing required sub-field — 400 from Stripe | LOW — synchronous error, immediate recovery | Fix the `flow_data` params map in the calling code. No data loss, just a failed redirect attempt. |
| Timestamp outside 35-day window | HIGH — irrecoverable | Usage data permanently lost for that billing period. Prevention: always report events close to when they occur. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| MeterEvent two-layer idempotency trap | Phase 20 (Plan 20-04 + 20-06) | `@doc` mentions both mechanisms separately; `guides/metering.md` shows stable identifier pattern |
| Timestamp backdating window (35 days / 5 min) | Phase 20 (Plan 20-04 + 20-06) | `@doc` lists exact constraints and error codes; guide has anti-pattern warning |
| customer_mapping key silent drop | Phase 20 (Plan 20-04 + 20-06) | `@doc` warns about async validation; guide has monitoring section |
| formula: sum + missing value_settings | Phase 20 (Plans 20-02, 20-03) | `Meter.DefaultAggregation` `@typedoc` documents formula semantics; `Meter.create/3` has warning guard |
| Events to inactive meter (archived_meter) | Phase 20 (Plan 20-03 + 20-04) | `deactivate/3` and `MeterEvent.create/3` docs state behavior; error code pattern-matchable |
| MeterEventAdjustment cancel.identifier field name | Phase 20 (Plan 20-04) | Unit test asserts correct `from_map/1` on `cancel.identifier`; `@doc` shows exact param shape |
| FlowData type sub-field validation | Phase 21 (Plan 21-03) | `Session.create/3` has per-type guard; unit test exercises each flow type validation |
| PII in MeterEvent payload / Session url | Phase 20 + 21 (Plans 20-04, 21-03) | `Inspect` implementations present for `MeterEvent` and `BillingPortal.Session`; `mix run` with inspect call shows masked fields |
| Connect: stripe_account vs on_behalf_of distinction | Phase 21 (Plan 21-03 + 21-04) | Guide documents both opts; integration test uses `stripe_account:` opt |

---

## Sources

- [Stripe MeterEvent Create API](https://docs.stripe.com/api/billing/meter-event/create) — `identifier` field, 24-hour dedup window, 100-char max (HIGH confidence)
- [Stripe Recording Usage API Guide](https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api) — timestamp 35-day window, 5-minute future limit, async validation, error codes `timestamp_too_far_in_past`, `meter_event_no_customer_defined`, `meter_event_customer_not_found`, `archived_meter`, `meter_event_value_not_found` (HIGH confidence)
- [Stripe Meter Object API](https://docs.stripe.com/api/billing/meter/object) — `inactive` status description: "No more events for this meter will be accepted" (HIGH confidence)
- [Stripe MeterEventAdjustment Object](https://docs.stripe.com/api/billing/meter-event-adjustment/object) — exact `cancel.identifier` field name; 24-hour cancellation window (HIGH confidence)
- [Stripe MeterEventAdjustment Create](https://docs.stripe.com/api/billing/meter-event-adjustment/create) — `type: "cancel"`, required fields `event_name` and `type` (HIGH confidence)
- [Stripe Portal Deep Links Guide](https://docs.stripe.com/customer-management/portal-deep-links) — all four flow types, required sub-fields per type (HIGH confidence)
- [Stripe BillingPortal Session Create](https://docs.stripe.com/api/customer_portal/sessions/create) — `flow_data` parameter structure, `on_behalf_of` semantics (HIGH confidence)
- [Stripe BillingPortal Session Object](https://docs.stripe.com/api/customer_portal/sessions/object) — `url`, `flow`, `on_behalf_of` fields confirmed (HIGH confidence)
- [Stripe Configure a Meter Guide](https://docs.stripe.com/billing/subscriptions/usage-based/meters/configure) — formula semantics, `value_settings` default key `"value"` (MEDIUM confidence — silent zero behavior extrapolated from formula semantics)
- [stripe-mock GitHub (statelessness note)](https://github.com/stripe/stripe-mock) — confirmed stateless; dedup/time windows not simulated (HIGH confidence, per STACK.md v1.1 addendum)
- `lib/lattice_stripe/subscription.ex` — `pause_collection/5` atom guard pattern (`when behavior in [:keep_as_draft, :mark_uncollectible, :void]`) as precedent for FlowData type guard
- `lib/lattice_stripe/resource.ex` — `Resource.require_param!/3` pattern as precedent for `BillingPortal.Session.create/3` customer guard
- `.planning/v1.1-accrue-context.md` — locked decisions D1-D5, Accrue minimum API surfaces, confirmed Accrue does not pattern-match FlowData sub-flow internals
- FEATURES.md (sibling research, 2026-04-13) — idempotency two-layer system documented; formula semantics; flow types list
- STACK.md (sibling research, 2026-04-13) — stripe-mock statelessness; all endpoints confirmed present in stripe-mock without beta flags

---

*Pitfalls research for: LatticeStripe v1.1 — Billing.Meter + MeterEvent + MeterEventAdjustment + BillingPortal.Session*
*Researched: 2026-04-13*
