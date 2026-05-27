# Phase 47: Thin-Event SDK Surface & Webhook Reconciliation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 47-Thin-Event SDK Surface & Webhook Reconciliation
**Areas discussed:** Notification struct shape & location, WEBFIX-01 direction, Client binding for fetch helpers, Unknown related_object.type behavior
**Mode:** advisor (USER-PROFILE.md present) + text overlay (`workflow.text_mode: true`)
**Calibration tier:** minimal_decisive (`vendor_philosophy: opinionated`)
**Research:** 4 parallel `gsd-advisor-researcher` agents (model: sonnet) — each researched cross-SDK reference patterns, Elixir ecosystem idioms, and the `prompts/` master research baseline before producing a 5-column comparison table

---

## Notification Struct Shape & Location

| Option | Description | Selected |
|--------|-------------|----------|
| (A) New top-level `LatticeStripe.EventNotification` + nested `EventNotification.RelatedObject` typed struct | Distinct type from `Event.t()`; atom-key `notification.related_object.id`; mirrors `Stripe.V2.EventNotification` (node) + `V2BaseEvent` (go); uses LatticeStripe's nested-module-struct precedent | ✓ |
| (B) Nested `LatticeStripe.Webhook.EventNotification` module | Colocated with `Webhook` family | Not advanced — minor variant of (A), no decisive DX benefit |
| (C) Reuse `Event.t()` with `data: nil` + populated `related_object` | No new module; smallest API surface | |

**User's choice:** (A) — approved as part of "approve" of all four recommendations.
**Notes:** Decisive on type clarity — `fetch_event/2` accepting `Event.t()` as both input (thin notification) and output (full event) would be a recognized Elixir anti-pattern. `RelatedObject` sub-struct is **shared** between `EventNotification` and `Event` per D-02 (single source of truth).

---

## WEBFIX-01 Direction (`tolerance: 0` semantics)

| Option | Description | Selected |
|--------|-------------|----------|
| (A) Docstring-fix: rewrite docstring to honestly say "`0` rejects" | Zero behavior change, zero semver risk, one file | |
| (B) Code-fix: make `tolerance: 0` actually disable staleness; reconcile Plug schema `:pos_integer` → `:non_neg_integer`; rewrite locked-in test; CHANGELOG entry | Aligns with every canonical Stripe SDK (stripe-node, stripe-ruby, stripe-go); resolves Plug schema inconsistency in same pass; CHANGELOG narrative matches the docs-truth milestone identity | ✓ |
| (C) `:infinity`/`:disabled` atom sentinel | Most expressive long-term; deprecates `0` as disable sentinel | Not advanced — adds API surface, diverges from cross-SDK convention |

**User's choice:** (B) — approved.
**Notes:** Cross-SDK alignment was decisive. The Plug NimbleOptions schema already blocked `0`, so no real adopter relied on `0`-rejects semantics — the perceived semver risk evaporates on inspection. CHANGELOG narrative for v1.5 (first new Hex release since 1.3.0): "WEBFIX-01: `Webhook.check_tolerance/2` `tolerance: 0` now correctly disables the staleness check as documented; `Webhook.Plug` NimbleOptions schema updated to accept `0`."

---

## Client Binding for `fetch_event/2` and `fetch_related_object/2`

| Option | Description | Selected |
|--------|-------------|----------|
| (A) Embed client at parse time — `parse_event_notification/4` takes `:client` opt and embeds it in notification; 1-arg fetchers | Matches stripe-node v49 ergonomics | |
| (B) Explicit client at fetch time — `fetch_event(client, notification_or_id, opts)`; parse is client-free | Uniform with all 30+ existing resource fetchers; `construct_event/4` already client-free; Plug unchanged; notification is pure serializable data (safe in ETS, logs, distributed Erlang); stripe-python/go/ruby all use this | ✓ |
| (C) Both — explicit client wins; embedded client as fallback | stripe-node-style ergonomics where wanted | Not advanced — adds opts complexity for a footgun |

**User's choice:** (B) — approved.
**Notes:** THIN-02 REQ-ID language "honors per-request opts (`:client`, ...)" maps unambiguously to per-request client. Stripe-node is the **lone outlier** among canonical Stripe SDKs on the embed-at-parse pattern. Avoided footgun: API-key leakage via inadvertent serialization of a notification carrying `%Client{}` across ETS / log lines / distributed-Erlang boundaries.

---

## Unknown `related_object.type` Behavior in `fetch_related_object/3`

| Option | Description | Selected |
|--------|-------------|----------|
| (A) Silent fallback (raw map) | Reuse `ObjectTypes.maybe_deserialize/1` as-is; forward-compat by default | |
| (B) Typed error `{:error, {:unknown_object_type, type_string}}` | Adopter sees boundary explicitly; matches stripe-java `Optional.empty()` precedent + stripe-node `Promise<unknown>` signal; aligns with v1.4 "surface drift loudly" posture | ✓ |
| (C) Two functions — strict + lax (e.g., `fetch_related_object_raw/3`) | Adopters pick | Not advanced — permanent lax path normalizes ignoring the error signal; deferred to backlog |
| (D) Tagged tuple `{:ok, {:unknown, type, raw_map}}` on miss | Distinct from silent fallback; signals drift without erroring | Not advanced — overloaded shape on `:ok` channel violates "no overloaded shapes" Elixir idiom |

**User's choice:** (B) — approved.
**Notes:** Dispatch lookup happens **before** any HTTP request — fail fast, no wasted call. The escape hatch (`fetch_related_object_raw/3` or `:raw_on_unknown` opt) is deferred to the deferred-ideas backlog; reconsider only if real adopter pull surfaces friction. Avoided footgun: adopter `{:ok, %Customer{} = c} = ...` crashing with opaque `CaseClauseError` at 3am with zero hint of root cause.

---

## Claude's Discretion

- Exact module/file layout for `LatticeStripe.EventNotification` + `EventNotification.RelatedObject` (planner picks per existing `Invoice.LineItem` etc. precedent)
- Internal helper extraction for shared verification step between `parse_event_notification/4` and `construct_event/4` (implementation detail)
- ExDoc grouping for the new module (group with `Event` + `Webhook` under existing "Webhooks" section)
- Whether `EventNotification` gets a custom `Inspect` impl mirroring `Event`'s

## Deferred Ideas

- Thin-event-aware `LatticeStripe.Webhook.Plug` dispatch mode (path-based vs content-shape-based vs handler-attribute-based — deserves its own discuss-phase; v1.5.x or v1.6 follow-up)
- `fetch_related_object_raw/3` escape hatch for unknown types (reconsider if adopter pull surfaces friction)
- `LatticeStripe.Webhook.Handler` callback parallel for thin events (`handle_event_notification/1`) — hold until Plug-dispatch question above is answered
- `fetch_related_object/3` auto-fall-through to `fetch_event/3` when `related_object: nil` — tempting but conflates two operations; keep them separate
- `/v2/`-namespaced resource module surface beyond webhook helpers — locked out of v1.5 per REQUIREMENTS.md "Out of Scope"
- Bulk thin-event replay / dead-letter / processor abstractions — application concern; downstream in Accrue or adopter code (locked v1.0 scope-discipline decision)
