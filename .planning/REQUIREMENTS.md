---
milestone: v1.5
milestone_name: Thin-Event Webhooks
status: defined
created: 2026-05-27
---

# v1.5 Thin-Event Webhooks — Requirements

**Goal:** Ship first-class thin-event (`/v2/events`) webhook handling — verify, resolve authoritative state, document the fetch-after-verify pattern, and reconcile the `tolerance: 0` webhook bug — so LatticeStripe adopters can consume modern Stripe webhook deliveries idiomatically in Phoenix.

**References:**
- `.planning/threads/v1-5-next-milestone-assessment.md` — full assessment + wedge dossier
- `.planning/threads/thin-event-webhook-evaluation.md` — locked-in v1.5 shape, API surface, reference SDK

## v1.5 Requirements

### Thin-Event Helpers (THIN-*)

- [ ] **THIN-01**: `Webhook.parse_event_notification/3` verifies a thin-event payload's HMAC signature using the existing secret + tolerance machinery and returns a typed notification struct exposing `id`, `type`, `created`, `context`, and a `related_object` reference (`%{id: String.t(), type: String.t()}` minimum). Returns `{:ok, notification}` or `{:error, reason}` with the same reason atoms used by `construct_event/3`.

- [ ] **THIN-02**: `Webhook.fetch_event/2` retrieves the full `Event.t()` for a thin-event notification. Accepts the notification struct (or its `id`), honors per-request opts (`:client`, `:api_version`, `:idempotency_key`), and returns `{:ok, Event.t()} | {:error, reason}`. Typed deserialization via existing `Event` from-map machinery.

- [ ] **THIN-03**: `Webhook.fetch_related_object/2` retrieves the underlying typed resource referenced by a thin-event notification (e.g. `Customer.t()`, `Invoice.t()`) via the existing `ObjectTypes` dispatch — no new dispatch table. Returns `{:ok, resource}` or `{:error, reason}`. Reuses v1.2 expand machinery for any inline expansions.

- [ ] **THIN-04**: `Event` struct surfaces `context` and `related_object` cleanly so adopters can pattern-match thin-event payloads without re-parsing maps. `context` already exists and must stay backwards-compatible; `related_object` is net-new and may be `nil` on snapshot events.

### Webhook Bug Reconciliation (WEBFIX-*)

- [ ] **WEBFIX-01**: `Webhook.check_tolerance/2` `tolerance: 0` semantics aligned. Docstring (`lib/lattice_stripe/webhook.ex:84`) and code path (`lib/lattice_stripe/webhook.ex:268-273`) currently disagree — either docstring updated to reflect that `0` rejects, or code path updated to disable the staleness check when `tolerance == 0`. Decision documented inline in the source. CHANGELOG entry included.

### Testing Helpers (TESTING-*)

- [ ] **TESTING-01**: `LatticeStripe.Testing` emits thin-event payload shapes with signature generation matching `Webhook.parse_event_notification/3`. Existing snapshot helpers remain working unchanged. Test helpers expose at minimum: build a thin-event payload, sign it with a provided secret, produce the matching `Stripe-Signature` header.

### Documentation (GUIDE-*)

- [ ] **GUIDE-03**: `guides/webhooks-thin-events.md` published — Phoenix handler skeleton, fetch-after-verify pattern, idempotency keyed on `event.id` (not on fetched resource state), rate-limit guidance (<90/s under Stripe's 100 req/s ceiling), Connect/context-aware routing via `event.context`, explicit verification-vs-payload-shape failure boundary. Linked into ExDoc layered grouping and JTBD discovery ladder.

### Verification (VERIFY-*)

- [ ] **VERIFY-03**: Integration test coverage for thin-event verification happy path, fetch-after-verify roundtrip, malformed-payload failure boundary, and `tolerance: 0` reconciliation. Tests live under existing `test/lattice_stripe/webhook*` namespace. Docs-truth regression suite extended so `webhooks-thin-events.md` install/handler snippets stay enforceable.

## Future Requirements (Deferred)

Captured from the v1.5 assessment but explicitly **not v1.5 scope** — queued behind v1.5:

- **v1.6 Tax** — `Tax.Calculation`, `Tax.Transaction`, `Tax.Settings`, `Tax.Registration`, `TaxId` nested under `Customer`. Scope discipline: SDK resource surface only; multi-jurisdiction filing strategy stays in Accrue.
- **v1.7 Polish & Operator** — `Charge.list/3`, `Charge.search/3`, `Charge.capture/4`, `Charge.update/4`; Phase 41.1 closure decision (re-run with valid sandbox creds or retire as accepted external-only follow-through); `guides/production-checklist.md`; `guides/event-debugging.md`. Planned stop signal for v1.x scope.

## Out of Scope

Excluded from v1.5 with explicit reasoning:

- **High-level workflow facades for webhook processing** — adopters compose primitives in their own application code. LatticeStripe stays lower-level than Accrue per the standing scope boundary decision. Building a `WebhookProcessor`-style state machine in this milestone would invert the scope discipline.
- **Auto-retry / dead-letter / replay infrastructure for failed thin-event handlers** — application-level concern. Stripe handles delivery retries; durable handler state belongs in the consuming app's persistence layer.
- **Generic `/v2/*` API surface beyond webhook-related endpoints** — `/v2` is only relevant to v1.5 insofar as `/v2/events` (thin events) need parsing/fetching support. Other `/v2` resources stay deferred until adopter pull surfaces them.
- **Tax / Charge / Identity / Treasury surface work** — explicit v1.6, v1.7, and post-v1.x scope per locked-in milestone plan.
- **Phase 41.1 closure** — carried as `pending-external-verification` follow-through; decision belongs to v1.7 per locked plan.

## Traceability

Maps each REQ-ID to the phase that delivers it. All 8 v1.5 requirements mapped to exactly one phase (100% coverage).

| REQ-ID | Phase |
|--------|-------|
| THIN-01 | Phase 47 |
| THIN-02 | Phase 47 |
| THIN-03 | Phase 47 |
| THIN-04 | Phase 47 |
| WEBFIX-01 | Phase 47 |
| TESTING-01 | Phase 47 |
| GUIDE-03 | Phase 48 |
| VERIFY-03 | Phase 48 |
