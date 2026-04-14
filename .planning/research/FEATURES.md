# Feature Research

**Domain:** Elixir SDK — Stripe Metering + Customer Portal (LatticeStripe v1.1)
**Researched:** 2026-04-13
**Confidence:** HIGH (Stripe API docs verified for all four resources)

---

## Context: v1.1 Scope

This research covers only the **three new resource families** added in v1.1. Everything in v1.0
(Subscriptions, Invoices, Payments, Connect, etc.) is already shipped. The downstream consumer
is **Accrue** — a billing/payments library built on LatticeStripe — and the features below are
driven entirely by Accrue's Phase 4 blockers.

Resources in scope:
- `LatticeStripe.Billing.Meter` — CRUDL + lifecycle verbs
- `LatticeStripe.Billing.MeterEvent` + `MeterEventAdjustment` — fire-and-forget usage reporting
- `LatticeStripe.BillingPortal.Session` — create-only portal redirect

---

## Category: Metering (Phase 20)

### Table Stakes

Features Accrue (and any downstream SaaS app) expects to work. Missing = integration is broken.

| Feature | Why Expected | Complexity | Accrue Usage Notes |
|---------|--------------|------------|-------------------|
| `Billing.Meter.create/3` | Required to bootstrap a meter before any events can flow | LOW | Accrue seeds meters in test/staging setup; also needed for Accrue admin UI (BILL-11) |
| `Billing.Meter.retrieve/3` | Fetch meter by id to verify config, render admin UI | LOW | Standard read-back after create; Accrue confirms meter settings |
| `Billing.Meter.update/4` | Change `display_name` + mutable fields; Stripe allows this post-create | LOW | Accrue admin UI can rename meters |
| `Billing.Meter.list/3` | List all meters for dashboard view | LOW | Accrue dashboard renders meter inventory |
| `Billing.Meter.stream!/3` | Auto-paginate large meter lists | LOW | Follows v1.0 `List.stream!/2` convention; Accrue uses for admin exports |
| `Billing.Meter.deactivate/3` | Explicit lifecycle verb — POST `/deactivate`; `status` -> `inactive` | LOW | Accrue deactivates retired feature meters |
| `Billing.Meter.reactivate/3` | Inverse verb — POST `/reactivate`; `status` -> `active` | LOW | Accrue reactivates paused meters |
| `Billing.MeterEvent.create/3` | Hot path — reports usage on every customer action | LOW | **Most critical function in v1.1.** Called by `Accrue.Billing.report_usage/3` on every event |
| `Billing.MeterEventAdjustment.create/3` | Cancels an over-reported event (created in error or wrong customer) | LOW | Accrue's dunning-style correction flow; can only cancel events within last 24 hours |
| Bang variants for all above | LatticeStripe convention — every function has `create!/3` etc. | TRIVIAL | Standard pattern; `Resource.unwrap_bang!/1` wraps tuples |
| `Meter.DefaultAggregation` nested struct | `formula` field (`:sum`, `:count`, `:last`) must be a typed struct, not raw map | LOW | Accrue reads `default_aggregation.formula` to display in admin UI |
| `Meter.CustomerMapping` nested struct | `type` + `event_payload_key` — determines how events map to customers | LOW | Accrue reads `customer_mapping.event_payload_key` to build event payloads correctly |
| `Meter.ValueSettings` nested struct | `event_payload_key` — the payload key Stripe reads as the numeric value | LOW | Accrue reads this to know which payload key to populate in MeterEvent |
| `Meter.StatusTransitions` nested struct | `deactivated_at` timestamp for audit trail | LOW | Accrue renders "deactivated on" in admin UI |
| `MeterEvent` minimal struct fields | `event_name`, `identifier`, `payload`, `timestamp`, `created`, `livemode` | LOW | Accrue does not read MeterEvent back beyond ack — thin struct is correct |
| `MeterEventAdjustment` minimal struct fields | `id`, `event_name`, `type` (`"cancel"`), `status`, `created`, `livemode`, `cancel` sub-map | LOW | Accrue confirms adjustment was accepted |
| `idempotency_key:` opt threading | Standard per-request opt already in v1.0 Client plumbing | TRIVIAL | Accrue passes caller-generated idempotency key through LatticeStripe |
| `stripe_account:` opt threading | Connect header forwarding — already in v1.0 | TRIVIAL | Required for Accrue Phase 5 (Connect metering) |

### Differentiators

Features that distinguish LatticeStripe's metering implementation from a naive wrapper.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| `identifier` field clarity in docs + `@moduledoc` | Stripe's `identifier` is a **domain-level deduplication key**, separate from `Stripe-Idempotency-Key` header. Documenting the distinction prevents misuse. | LOW | See "MeterEvent Idempotency Decision" section below |
| Explicit `deactivate/reactivate` verbs instead of status update | Matches LatticeStripe's established "explicit verbs for irreversible ops" philosophy (same pattern as `cancel`, `resume`, `reject` in v1.0) | TRIVIAL | Would be a regression to model this as `update(client, id, %{"status" => "inactive"})` |
| Aggregation formula semantics in `@moduledoc` | `sum` (add values), `count` (ignore value, count events), `last` (snapshot — last value in window wins). Not obvious from field name alone. | LOW | Stripe docs confirm three formulas; `max` does NOT exist — do not document it |
| `event_time_window` context in Meter struct docs | `"hour"` or `"day"` — determines the reset window for aggregation. Important for interpreting billing data. | LOW | Include in `Meter` `@typedoc` |
| `from_map/1` + `@known_fields` + `:extra` on all structs | Survive new Stripe fields without crashing — already the v1.0 pattern | TRIVIAL | Apply to all four new structs (Meter, MeterEvent, MeterEventAdjustment, BillingPortal.Session) |
| PII-safe `Inspect` for MeterEvent | `payload` map may contain customer identifiers — mask in Inspect output | LOW | Follows `Subscription` and `Checkout.Session` pattern |

### Anti-Features (Explicitly Out of Scope)

| Anti-Feature | Why Requested | Why Excluded for v1.1 | What to Do Instead |
|--------------|---------------|----------------------|-------------------|
| `meter_event_stream` (high-throughput streaming variant) | 10,000 events/second vs 1,000/second; looks like a natural upgrade | **Locked as D3.** Completely different semantics: stateless auth sessions, 15-minute token refresh, batch-oriented. Accrue does not need it for Phase 4. Adding it conflates two distinct APIs under one namespace. | Implement in v1.2+ as `Billing.MeterEventStream` with its own auth session management. Do NOT add a `stream: true` flag to `MeterEvent.create/3` |
| `Billing.Meter.search/3` | Other resources have search | Stripe does not expose a `/billing/meters/search` endpoint. No search endpoint exists for meters. | Use `list/3` with `status` filter param |
| `Billing.Meter.delete/3` | CRUD looks incomplete without delete | Stripe does not allow meter deletion. Meters can only be deactivated. | Use `deactivate/3` |
| Aggregated usage queries / `meter_event_summaries` | Useful for building billing dashboards | Different API family (`/v1/billing/meters/:id/event_summaries`). Not required by Accrue Phase 4. Triples scope. | Defer to v1.2+ |
| v2 API meter events (`/v2/billing/meter_events`) | Newer, synchronous validation | Accrue is pinned to `2026-03-25.dahlia`. The v2 path uses different auth flow and response shape. Mixing v1 and v2 endpoints in one minor is a footgun. | Revisit when Accrue upgrades API version |

---

## Category: Customer Portal (Phase 21)

### Table Stakes

| Feature | Why Expected | Complexity | Accrue Usage Notes |
|---------|--------------|------------|-------------------|
| `BillingPortal.Session.create/3` | Create a short-lived hosted URL for customers to manage their subscription | LOW | Accrue calls this and redirects customer to `session.url` — single call, single return |
| `BillingPortal.Session.create!/3` | Bang variant per LatticeStripe convention | TRIVIAL | Standard pattern |
| `session.url` field populated | The entire point of the resource — the hosted portal URL | TRIVIAL | Accrue reads `session.url` for the redirect |
| `session.customer` field | Confirms which customer the session belongs to | TRIVIAL | Accrue uses for audit/logging |
| `session.return_url` field | Where Stripe redirects after portal interaction | TRIVIAL | Accrue passes this on create; reads back to confirm |
| `session.flow` field (echoed back) | When `flow_data` is passed on create, `flow` is echoed in response | LOW | Accrue reads this to confirm deep-link was set up correctly |
| `session.configuration` field | Which portal configuration is active | TRIVIAL | Accrue may log this for debugging |
| `session.created`, `session.livemode` | Standard metadata | TRIVIAL | Logging / audit |
| `flow_data` create parameter support | Enables deep-linking to specific portal flows | MEDIUM | Accrue uses for `subscription_cancel` and `payment_method_update` deep links |
| `Session.FlowData` nested struct | Typed struct for `flow_data` input | LOW | Accrue passes `FlowData` for deep-link flows; keeping it typed prevents missing required sub-fields |
| `customer:` param required guard | Pre-network `ArgumentError` if `customer` is missing | LOW | Same pattern as `Checkout.Session` requiring `mode`; `customer` is required on BillingPortal.Session |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| All four `flow_data.type` values documented | `subscription_cancel`, `subscription_update`, `subscription_update_confirm`, `payment_method_update` — each has different required sub-fields | LOW | `subscription_cancel` requires subscription ID in `flow_data.subscription_cancel.subscription`; `subscription_update_confirm` requires `items` array. Document all four in `@moduledoc` to prevent API errors. |
| `flow_data.after_completion` struct support | `hosted_confirmation`, `portal_homepage`, or `redirect` — controls where user lands after completing a flow | LOW | Include in `FlowData` struct and document in guide |
| `on_behalf_of:` opt for Connect | Forwarded to Stripe for Connect platforms creating sessions on behalf of connected accounts | LOW | Accrue Phase 5 will need this; thread through as standard opt |
| Namespace mirrors `Checkout.Session` | `LatticeStripe.BillingPortal.Session` matches existing `LatticeStripe.Checkout.Session` naming — discoverable by convention | TRIVIAL | Module naming decision already locked |

### Anti-Features (Explicitly Out of Scope)

| Anti-Feature | Why Requested | Why Excluded for v1.1 | What to Do Instead |
|--------------|---------------|----------------------|-------------------|
| `BillingPortal.Configuration` CRUDL | Portal config seems like a natural companion to Session | **Locked as D4.** Full CRUDL with deep UX structs (features, business_profile, login_page, etc.) triples Phase 21 scope. Accrue explicitly does not need it — hosts manage portal config via Stripe Dashboard for v1.1. | Implement in v1.2+ as `LatticeStripe.BillingPortal.Configuration` |
| `Session.retrieve/3` | Looks like a missing CRUD operation | BillingPortal Sessions are **create-only** by Stripe's design. The API has no retrieve, list, update, or delete endpoint. Sessions are short-lived and expire after use. | N/A — this is a Stripe API constraint, not a LatticeStripe decision |
| `Session.list/3` | Same as above | Same Stripe API constraint | N/A |

---

## MeterEvent Idempotency Decision

This is the most nuanced feature decision in v1.1. Two separate idempotency mechanisms exist and
they are **orthogonal** — they operate at different layers and must not be conflated.

### Layer 1: `Stripe-Idempotency-Key` HTTP header

- Passed via `idempotency_key:` opt in LatticeStripe (already in v1.0 Client plumbing)
- Tells Stripe's API gateway to deduplicate the entire HTTP request
- If the same idempotency key is sent twice within Stripe's window, Stripe returns the cached
  HTTP response without re-executing the handler
- Scope: the HTTP request itself
- Stripe recommends using this for MeterEvent as well to prevent duplicate network submissions

### Layer 2: `identifier` field in MeterEvent create params

- A string field in the JSON request body (not a header)
- Stripe's billing engine uses this to deduplicate within the **metering domain**
- If the same `identifier` is received within the last ~24 hours, Stripe silently deduplicates
  the event (does not create a duplicate meter_event)
- Auto-generated by Stripe if not provided (max 100 characters)
- Scope: the billing event itself, within a rolling 24-hour window
- This is a **domain-level idempotency key** — survives across different HTTP connections,
  retries, or even manually re-sent events

### Why They Are Orthogonal, Not Redundant

```
HTTP request 1: idempotency_key="req_abc", body: {identifier: "evt_123", event_name: "api_call"}
HTTP request 2: idempotency_key="req_xyz", body: {identifier: "evt_123", event_name: "api_call"}
```

Request 2 has a different `idempotency_key` (different HTTP request) but the same `identifier`.
- The `Stripe-Idempotency-Key` header does NOT deduplicate request 2 (different header value)
- The `identifier` DOES deduplicate request 2 (same billing event identifier, within 24h)

This matters in Accrue's `report_usage/3` call pattern: Accrue generates a stable `identifier`
from its own domain logic (e.g., `"#{customer_id}:#{event_name}:#{period}"`) so that billing
events are idempotent regardless of retry behavior or process restarts. The `idempotency_key:`
opt is an additional layer protecting the HTTP call itself.

### SDK Recommendation

- LatticeStripe should accept **both** mechanisms independently:
  - `identifier` as a first-class key in the `params` map (JSON body)
  - `idempotency_key:` as a standard opt (maps to `Stripe-Idempotency-Key` header)
- Document both in `MeterEvent.create/3` `@doc` with clear labels ("domain-level deduplication"
  vs "request-level idempotency")
- Do NOT alias one to the other — they are not the same thing
- Recommendation: always pass a stable `identifier`; also pass `idempotency_key:` for network
  retry safety

---

## Meter Aggregation Formulas — Semantic Definitions

All three formulas confirmed from Stripe API docs. No `max` formula exists.

| Formula | Stripe Definition | Semantic Meaning | Example Use Case |
|---------|-------------------|-----------------|-----------------|
| `sum` | Sum each event's value | Accumulate: add every event's value within the window | API calls (value = 1 per call, sum = total calls) |
| `count` | Count the number of events | Ignore the value field; every event contributes 1 | Simple event counting where magnitude doesn't matter |
| `last` | Take the last event's value in the window | Snapshot: the most recent reading wins, previous values discarded | Seat counts, storage usage — where you want the current state, not the total |

`event_time_window` (`"hour"` or `"day"`) controls when the aggregation window resets. This
affects how `last` behaves: within the window, only the final event value is used. At window
reset, the meter starts fresh.

---

## Meter Status Transitions

| Status | Meaning | How to Reach It |
|--------|---------|----------------|
| `active` | Meter accepts events and aggregates usage | Default after `create/3`; also via `reactivate/3` |
| `inactive` | No new events accepted; existing data preserved | Via `deactivate/3` (POST `/v1/billing/meters/:id/deactivate`) |

`status_transitions.deactivated_at` (Unix timestamp) is populated when the meter transitions
to `inactive`. No `activated_at` field exists on the object — only `created` (the creation time).

No delete endpoint exists. `inactive` is the terminal state in the downward direction.

---

## Feature Dependencies

```
Billing.Meter nested structs (plan 20-02)
    |--> Meter.DefaultAggregation
    |--> Meter.CustomerMapping
    |--> Meter.ValueSettings
    +--> Meter.StatusTransitions
         all required-before: Billing.Meter resource module (plan 20-03)

Billing.Meter (plan 20-03)
    required-at-runtime-by: Billing.MeterEvent (plan 20-04)
    (event_name on MeterEvent must match event_name on a Meter)

Billing.MeterEventAdjustment (plan 20-04)
    sibling-of: Billing.MeterEvent (same plan, same file)

Session.FlowData nested struct (plan 21-02)
    required-before: BillingPortal.Session module (plan 21-03)

BillingPortal.Session (Phase 21)
    independent-of: Phase 20 (no code dependency, separate Stripe API family)

All new resources inherit v1.0 plumbing:
    Client / Request / Response / Error / Resource / List / Transport
    (no changes to existing modules required)
```

---

## v1.1 MVP Definition

### Phase 20: Ship All (required for Accrue BILL-11)

- [ ] `Billing.Meter` CRUDL + `deactivate/reactivate` + 4 nested structs + bang variants
- [ ] `Billing.MeterEvent.create/3` + `create!/3`
- [ ] `Billing.MeterEventAdjustment.create/3` + `create!/3`
- [ ] `guides/metering.md`
- [ ] Integration tests against stripe-mock

### Phase 21: Ship All (required for Accrue CHKT-02)

- [ ] `BillingPortal.Session.create/3` + `create!/3`
- [ ] `Session.FlowData` nested struct with all four flow types
- [ ] `guides/customer-portal.md` extension
- [ ] Integration test against stripe-mock

### Defer to v1.2+

- [ ] `Billing.MeterEventStream` (locked D3) — high-throughput streaming, different auth model
- [ ] `BillingPortal.Configuration` (locked D4) — full CRUDL with UX config structs
- [ ] `Billing.Meter.EventSummary` — aggregated usage queries per meter
- [ ] v2 API metering endpoints — requires API version upgrade planning

---

## Feature Prioritization Matrix

| Feature | Accrue Value | Implementation Cost | Priority |
|---------|-------------|---------------------|----------|
| `MeterEvent.create/3` | HIGH — hot path for all usage reporting | LOW | P1 |
| `Meter.create/3` + `retrieve/3` | HIGH — required to bootstrap and verify | LOW | P1 |
| `Meter.deactivate/3` + `reactivate/3` | HIGH — lifecycle management | LOW | P1 |
| `MeterEventAdjustment.create/3` | HIGH — correction flow required | LOW | P1 |
| `BillingPortal.Session.create/3` | HIGH — sole unblock for Accrue CHKT-02 | LOW | P1 |
| `Session.FlowData` struct (all 4 flow types) | MEDIUM — deep-link flows expected | LOW | P1 (cheap to add alongside create) |
| `guides/metering.md` | HIGH — Accrue contributors need idioms | LOW | P1 |
| `Meter.list/3` + `stream!/3` | MEDIUM — admin UI use case | LOW | P1 (negligible cost, follows existing pattern) |
| `Meter.update/4` | LOW — admin use case, rare | LOW | P1 (negligible cost) |
| `MeterEventStream` | LOW — Accrue doesn't need it | HIGH (separate auth model) | P3 (v1.2+) |
| `BillingPortal.Configuration` | LOW — Stripe Dashboard covers it for v1.1 | HIGH (deep structs) | P3 (v1.2+) |

---

## Sources

- [Stripe Billing Meter API Reference](https://docs.stripe.com/api/billing/meter) — object, status values, formula enum confirmed HIGH confidence
- [Stripe Billing Meter Create](https://docs.stripe.com/api/billing/meter/create) — all create parameters confirmed
- [Stripe Meter Object Fields](https://docs.stripe.com/api/billing/meter/object) — formula values `count`/`sum`/`last` confirmed; status `active`/`inactive` confirmed; `status_transitions.deactivated_at` confirmed
- [Stripe MeterEvent Create](https://docs.stripe.com/api/billing/meter-event/create) — `identifier`, `payload`, `event_name`, `timestamp` params confirmed; identifier 24-hour deduplication window confirmed
- [Stripe Recording Usage API](https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api) — identifier idempotency semantics, meter_event_stream 10k/s throughput comparison confirmed
- [Stripe BillingPortal Session Create](https://docs.stripe.com/api/customer_portal/sessions/create) — all four `flow_data.type` values confirmed; `after_completion` sub-object confirmed; session object fields confirmed
- [Stripe MeterEventAdjustment](https://docs.stripe.com/api/billing/meter-event-adjustment) — cancel semantics, 24-hour cancellation window, `status` field confirmed
- v1.1 brief: `.planning/v1.1-accrue-context.md` — locked decisions D1-D5, Accrue minimum API surfaces

---

*Feature research for: LatticeStripe v1.1 — Billing.Meter + MeterEvent + BillingPortal.Session*
*Researched: 2026-04-13*
