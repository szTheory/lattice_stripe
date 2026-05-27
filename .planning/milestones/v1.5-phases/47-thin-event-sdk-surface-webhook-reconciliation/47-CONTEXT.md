# Phase 47: Thin-Event SDK Surface & Webhook Reconciliation - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Net-new helpers that let adopters verify a Stripe thin-event (`/v2/events`) payload, pattern-match a typed notification struct (carrying `id`, `type`, `created`, `context`, and `related_object`), then fetch the authoritative `Event.t()` and the underlying typed resource through the existing `LatticeStripe.ObjectTypes` dispatch — plus reconciling `Webhook.check_tolerance/2` `tolerance: 0` semantics across docstring + code + Plug schema + test, and shipping signed-payload thin-event Testing helpers paralleling the existing snapshot helpers.

**Locked deliverables (from REQUIREMENTS.md, all 6 REQ-IDs land in this phase):**
- `Webhook.parse_event_notification/4` (THIN-01)
- `Webhook.fetch_event/3` (THIN-02)
- `Webhook.fetch_related_object/3` (THIN-03)
- `Event.t()` extension surfacing `related_object` (THIN-04, plus existing `context` stays backwards-compatible)
- `Webhook.check_tolerance/2` `tolerance: 0` reconciliation across the 4 surfaces (WEBFIX-01)
- `LatticeStripe.Testing.generate_thin_event_payload/3` (TESTING-01)

Explicitly out of phase scope: the canonical Phoenix guide (GUIDE-03) + integration test surface (VERIFY-03) land in Phase 48.

</domain>

<decisions>
## Implementation Decisions

### Notification Struct Shape & Location (D-01)
- **D-01:** Ship a **new top-level `LatticeStripe.EventNotification` module** with a nested `LatticeStripe.EventNotification.RelatedObject` typed struct. `EventNotification.t()` exposes `id, type, created, context, related_object` (plus `object: "v2.core.event_notification"` and `livemode`); `RelatedObject.t()` exposes `id, type, url` (all `String.t() | nil`). `Webhook.parse_event_notification/4` returns `{:ok, %EventNotification{}} | {:error, reason}`. Rationale: distinct type prevents `Event.t()` ↔ `EventNotification.t()` confusion in handler `case` blocks; mirrors `Stripe.V2.EventNotification` (stripe-node v49+) and `V2BaseEvent` (stripe-go); typed sub-struct gives atom-key access (`notification.related_object.id`) per Elixir idiom; reuses LatticeStripe's nested-module-struct precedent (`Invoice.LineItem`, `CreditNote.LineItem`, `Quote.LineItem`).

### `Event.t()` Extension (D-02, THIN-04)
- **D-02:** Add `related_object: nil` to `LatticeStripe.Event` `defstruct` and `@known_fields`. Type as `EventNotification.RelatedObject.t() | nil` — **share the same `RelatedObject` sub-struct** between `EventNotification` and `Event` (single source of truth, no parallel duplicate). `context: String.t() | nil` stays as shipped (already exists, no change). `Event.from_map/1` decodes `related_object` map → `RelatedObject` struct via `RelatedObject.from_map/1`. `nil` on snapshot events. Backwards-compatible — `Event.t()` callers that don't pattern-match `related_object` see no change.

### WEBFIX-01 — `tolerance: 0` Reconciliation (D-03)
- **D-03:** **Code-fix path.** Change `lib/lattice_stripe/webhook.ex:268-273` `check_tolerance(_timestamp, 0)` clause to return `:ok` (disables staleness check, matching docstring intent). Reconcile `lib/lattice_stripe/webhook/plug.ex` NimbleOptions schema for `:tolerance` from `:pos_integer` to `:non_neg_integer` so `0` is reachable through the Plug. Rewrite `test/lattice_stripe/webhook_test.exs:121` (the `tolerance: 0 fails on any non-zero-age timestamp` test) — replace with a test asserting `tolerance: 0` skips staleness. Update inline comment in `check_tolerance/2` to document the decision. Add CHANGELOG entry under v1.5: "WEBFIX-01: `Webhook.check_tolerance/2` `tolerance: 0` now correctly disables the staleness check as documented; `Webhook.Plug` NimbleOptions schema updated to accept `0`." Rationale: aligns with every canonical Stripe SDK (stripe-node `if (tolerance > 0 && ...)`, stripe-ruby `if tolerance && ...`, stripe-go `IgnoreTolerance: true`); no real adopter relied on `0`-rejects (Plug schema already blocked it); avoids re-enshrining a docs-vs-reality gap in the docs-truth-anchored v1.5 milestone.

### Client Binding for Fetch Helpers (D-04, THIN-02 + THIN-03)
- **D-04:** **Explicit client at fetch time.** `parse_event_notification/4` is client-free (mirrors `construct_event/4`). Both fetchers take the client explicitly:
  - `Webhook.fetch_event(%Client{}, notification_or_id, opts \\ []) :: {:ok, Event.t()} | {:error, Error.t() | atom()}` — accepts `EventNotification.t()` or a bare `String.t()` id. Honors per-request opts `:client` override (no-op — already explicit), `:api_version`, `:idempotency_key`. Internally calls `Event.retrieve/3`.
  - `Webhook.fetch_related_object(%Client{}, %EventNotification{}, opts \\ []) :: {:ok, struct()} | {:error, Error.t() | {:unknown_object_type, String.t()} | :no_related_object}`. Returns `{:error, :no_related_object}` when `notification.related_object == nil` (snapshot events / events without a related object). Reuses v1.2 expand machinery for `:expand` opt.
- Notification struct is pure serializable data — no `%Client{}` embedded. Safe to put in ETS, log lines, GenServer state, distributed Erlang messages. Rationale: THIN-02 REQ-ID literally says "honors per-request opts (`:client`, ...)" — `:client` is a per-request opt; uniform with every existing LatticeStripe resource fetcher (`Event.retrieve/3`, etc.); Plug needs zero changes; Mox boundary stays at `Transport` (not at parse); avoids API-key leakage footgun from embedding `%Client{}` in serializable data.

### Unknown `related_object.type` Behavior (D-05, THIN-03 footgun)
- **D-05:** **Typed error.** `Webhook.fetch_related_object/3` returns `{:error, {:unknown_object_type, type_string}}` when `LatticeStripe.ObjectTypes` dispatch lookup misses for `notification.related_object.type`. The dispatch lookup happens **before** any HTTP request — fail fast, no wasted call. Reuses `ObjectTypes.maybe_deserialize/1` on the response only when type is known; introduces a small `ObjectTypes.fetch_module/1 :: {:ok, module()} | :error` helper to make the check explicit. No raw-fallback escape hatch in v1.5 (e.g., no `fetch_related_object_raw/3`, no `:raw_on_unknown` opt). Document the new error atom in the docstring + CHANGELOG. Rationale: silent `{:ok, raw_map}` would crash adopter `{:ok, %Customer{} = c} = ...` with opaque `CaseClauseError` at 3am with zero hint of root cause; matches stripe-java's `Optional.empty()` precedent + stripe-node's `Promise<unknown>` "you must narrow" signal; continues v1.4 "surface drift loudly" posture; the dispatch table is a one-line PR to add a new type, so the maintenance lag is bounded.

### Testing Helper API Surface (D-06, TESTING-01)
- **D-06:** Add **new** `LatticeStripe.Testing.generate_thin_event_payload/3` paralleling `generate_webhook_payload/3`. Signature: `generate_thin_event_payload(type, related_object_data, opts) :: {payload :: String.t(), sig_header :: String.t()}` where `related_object_data` is either `%{id: ..., type: ..., url: ...}` (or nil for snapshot-style v2 events). Opts: `:secret` (required), `:timestamp`, `:id`, `:context`, `:livemode`. Existing `generate_webhook_event/3` and `generate_webhook_payload/3` stay unchanged — no `:shape` opt overload. Also add `LatticeStripe.Testing.event_notification/1` (parallel to existing `LatticeStripe.Testing.dispute/1` etc.) for building a typed `%EventNotification{}` directly when adopters don't need a signed payload. Rationale: keep snapshot and thin-event test paths obviously distinct in adopter test suites; symmetric to the public API split between `construct_event/4` and `parse_event_notification/4`.

### Verification + Error Atom Set (D-07)
- **D-07:** `parse_event_notification/4` reuses **exactly** the same error atom set as `construct_event/4`: `:missing_header | :invalid_header | :no_matching_signature | :timestamp_expired`. Same HMAC scheme, same `verify_signature/4` codepath. Implementation pattern mirrors `construct_event/4`: call `verify_signature/4`, then on `{:ok, _ts}` decode JSON via `Jason.decode!/1` and map to `EventNotification` via `EventNotification.from_map/1`. `fetch_related_object/3` adds `{:unknown_object_type, type}` + `:no_related_object` on top of standard `Error.t()` HTTP errors. `fetch_event/3` returns only standard `Error.t()` HTTP errors + the `{:error, :no_event_id}` case if input is `%EventNotification{id: nil}` (defensive — shouldn't happen in practice).

### Webhook.Plug Routing (D-08, explicit boundary)
- **D-08:** `LatticeStripe.Webhook.Plug` and `LatticeStripe.Webhook.Handler` behaviour are **unchanged** in v1.5 (other than the `:tolerance` schema reconciliation from D-03). Thin-event adopters wire their own Phoenix controller calling `parse_event_notification/4` directly — this is the Phase 48 canonical-guide pattern (`guides/webhooks-thin-events.md`). A future "thin-event-aware Plug" that dispatches snapshot vs thin based on payload shape is **deferred** to a possible v1.5.x or v1.6 follow-up. Rationale: keeps v1.5 scope tight on helpers + bug; the explicit-controller pattern matches what Stripe-node's `parseEventNotification` callers do today; mixed-mode Plug dispatch is a real design problem (path-based? content-shape-based? handler-attribute-based?) that deserves its own discuss-phase.

### Claude's Discretion
- Exact module/file layout: `lib/lattice_stripe/event_notification.ex` + `lib/lattice_stripe/event_notification/related_object.ex` per the `Invoice.LineItem` / `CreditNote.LineItem` precedent. Planner may adjust if execution surfaces a better layout.
- Internal helper extraction (e.g., factoring `parse_event_notification/4` and `construct_event/4` shared verification step) is implementation-detail; planner decides.
- ExDoc grouping for `LatticeStripe.EventNotification` — group with `LatticeStripe.Event` + `LatticeStripe.Webhook` under the existing "Webhooks" section.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning & roadmap
- `.planning/PROJECT.md` — milestone shape, design philosophy, key decisions (incl. "verify shipped surface against lib/ source before every new milestone")
- `.planning/ROADMAP.md` §"Phase 47" — locked goal + 6 success criteria
- `.planning/REQUIREMENTS.md` — 6 v1.5 REQ-IDs landing in this phase (THIN-01..04, WEBFIX-01, TESTING-01) + 2 explicitly deferred to Phase 48 (GUIDE-03, VERIFY-03)
- `.planning/STATE.md` — current position (Phase 47 awaiting plan)

### v1.5 thread context (locked-in shape)
- `.planning/threads/thin-event-webhook-evaluation.md` — locked-in v1.5 surface + reference SDK + footgun catalog
- `.planning/threads/v1-5-next-milestone-assessment.md` §"Wedge A — Thin-Event Webhook Support (SELECTED for v1.5)" — concrete API surface, rate-limit guidance, scope discipline

### Source files this phase modifies
- `lib/lattice_stripe/webhook.ex` — `construct_event/4`, `verify_signature/4`, `check_tolerance/2` clause at :268-273 (WEBFIX-01), docstring at :84
- `lib/lattice_stripe/event.ex` — add `related_object` field per D-02 (THIN-04)
- `lib/lattice_stripe/webhook/plug.ex` — NimbleOptions `:tolerance` schema from `:pos_integer` to `:non_neg_integer` per D-03
- `lib/lattice_stripe/testing.ex` — add `generate_thin_event_payload/3` + `event_notification/1` per D-06 (TESTING-01)
- `lib/lattice_stripe/object_types.ex` — add `fetch_module/1` helper per D-05; no new dispatch entries (`/v2/events` resource types already covered by existing entries: customer, invoice, charge, etc.)
- `test/lattice_stripe/webhook_test.exs:121` — rewrite per D-03

### Source files this phase creates
- `lib/lattice_stripe/event_notification.ex` — new module per D-01
- `lib/lattice_stripe/event_notification/related_object.ex` — nested sub-struct per D-01

### Deep-research baseline (`prompts/`)
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — cross-SDK reference patterns; informed D-01, D-03, D-04
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — adopter user flows; informed D-04
- `prompts/elixir-best-practices-deep-research.md` — "assertive matching over defensive ambiguity"; informed D-05
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — semver hygiene; informed D-03
- `prompts/phoenix-best-practices-deep-research.md` — handler patterns; informed D-04, D-08
- `prompts/stripe-explanation-domain-language-deep-research.md` — thin event vs snapshot event domain language
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md` — overarching vision

### External Stripe references (for planner research-phase, not pre-read)
- Stripe docs: https://docs.stripe.com/event-destinations (thin events overview)
- Stripe docs: https://docs.stripe.com/api/v2/events (thin-event payload shape, `related_object` field set)
- stripe-node v49+: `Stripe.V2.EventNotification` type definition
- Stripe rate-limit ceiling: 100 req/s (planner research target — feeds into Phase 48 guide)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Webhook.verify_signature/4` — unchanged; thin-event verification uses the **same** HMAC scheme. `parse_event_notification/4` calls this verbatim, only the post-verify decode differs.
- `LatticeStripe.Webhook.generate_test_signature/3` — unchanged; thin-event Testing helper signs payloads with this same function. Confirms signature parity end-to-end.
- `LatticeStripe.Webhook.SignatureVerificationError` — bang variant raises this; reuse for `parse_event_notification!/4`.
- `LatticeStripe.Event.retrieve/3` — `fetch_event/3` internally delegates here. No new HTTP machinery.
- `LatticeStripe.ObjectTypes.maybe_deserialize/1` — used inside `fetch_related_object/3` **after** typed-error gate (D-05). No new dispatch table.
- `LatticeStripe.Client.request/2` + v1.2 expand machinery in `lib/lattice_stripe/client.ex:200,695-704` — `fetch_related_object/3` honors `:expand` opt via this path.
- `LatticeStripe.Testing.generate_webhook_payload/3` — pattern template for `generate_thin_event_payload/3`. Same JSON-encode + `generate_test_signature/3` pair.
- Nested-module-struct precedent: `LatticeStripe.Invoice.LineItem`, `LatticeStripe.CreditNote.LineItem`, `LatticeStripe.Quote.LineItem` — file layout pattern for `LatticeStripe.EventNotification.RelatedObject`.

### Established Patterns
- **`{:ok, t} | {:error, reason}` + bang variants** — every public function follows. `parse_event_notification/4` + `parse_event_notification!/4`, `fetch_event/3` + `fetch_event!/3`, `fetch_related_object/3` + `fetch_related_object!/3`. Bang raises `SignatureVerificationError` for verify failures and `LatticeStripe.Error` for HTTP / dispatch failures.
- **`Module.from_map/1` infallible deserialization** — Event, Customer, etc. all expose `from_map/1` that drops unknown fields into `extra`. Apply to `EventNotification.from_map/1` and `RelatedObject.from_map/1`.
- **Custom `Inspect` impl that hides large/sensitive fields** — `Event` already does this. `EventNotification` should follow: show `id`, `type`, `created`, `livemode`; hide `related_object.url` (Stripe's signed-URL semantics for v2 events) is **already** safe because `Inspect` shows the nested struct via `Inspect.Algebra` default, but flag for planner review.
- **`Resource.unwrap_singular/2` + `Resource.unwrap_list/2` + `Resource.unwrap_bang!/1`** — `fetch_event/3` and `fetch_related_object/3` use the same unwrap utilities.
- **NimbleOptions schemas at Plug boundaries** — `Webhook.Plug` already validates `:secret`, `:handler`, `:at`, `:tolerance` via NimbleOptions. The D-03 reconciliation touches this schema only.
- **`Plug.Crypto.secure_compare/2`** — unchanged; webhook signature comparison stays timing-safe.

### Integration Points
- `Webhook.Plug` snapshot mode keeps calling `construct_event/4` → `Event.t()` → `handler.handle_event/1`. **No change** in v1.5 (per D-08).
- Adopter thin-event controllers (Phase 48 guide) wire their own `Plug.Conn` → `parse_event_notification/4` → custom dispatch → `fetch_event/3` or `fetch_related_object/3`. Phase 48 documents this; Phase 47 only ships the primitives.
- `LatticeStripe.Telemetry.webhook_verify_span/2` — `parse_event_notification/4` should emit the same telemetry span as `construct_event/4` (verify boundary is identical). Planner: confirm via telemetry doc-truth test in Phase 48.
- The 2 new fetcher functions are first webhook-module functions that take a `%Client{}`. Their docstrings should explicitly cross-reference the snapshot path so adopters understand when to use which.

</code_context>

<specifics>
## Specific Ideas

- **Reference SDK shapes (user-confirmed during research):**
  - stripe-node v49+ `Stripe.V2.EventNotification` — `relatedObject: { id, type, url } | null`, plus `fetchEvent()` / `fetchRelatedObject()` methods bound to the parsing client.
  - stripe-go `V2BaseEvent` — `RelatedObject` embedded typed struct with `ID` field.
  - stripe-java `EventDataObjectDeserializer.getObject() → Optional<StripeObject>` — explicit `Optional.empty()` on unknown type (precedent for D-05).
- **Pattern-match target for adopters (D-01 + D-02 cohesion):**
  ```elixir
  case Webhook.parse_event_notification(payload, sig_header, secret) do
    {:ok, %EventNotification{related_object: %RelatedObject{type: "customer", id: id}} = notif} ->
      {:ok, %Customer{} = customer} = Webhook.fetch_related_object(client, notif)
      ...
    {:ok, %EventNotification{related_object: nil} = notif} ->
      {:ok, %Event{} = event} = Webhook.fetch_event(client, notif)
      ...
    {:error, :timestamp_expired} -> ...
    {:error, :no_matching_signature} -> ...
  end
  ```
  This is the canonical adopter shape; Phase 48 guide will use it.
- **Stripe-node naming parity (D-01):** module name `LatticeStripe.EventNotification` mirrors `Stripe.V2.EventNotification`; we drop the `V2.` namespace because LatticeStripe doesn't shadow Stripe's API-version namespacing in module paths (we use per-request `:api_version` opts instead, consistent with the rest of the SDK).

</specifics>

<deferred>
## Deferred Ideas

- **Thin-event-aware `LatticeStripe.Webhook.Plug` dispatch mode** — auto-route to snapshot vs thin based on payload shape (or via a new opt like `:event_shape`). Real design problem (path-based? content-shape-based? handler-attribute-based?); deserves its own discuss-phase. Likely v1.5.x patch or v1.6 follow-up.
- **`fetch_related_object_raw/3` (or `:raw_on_unknown` opt)** — explicit lax-mode escape hatch for unknown `related_object.type`. Reconsider only if real adopter pull surfaces friction with the strict default (D-05).
- **`LatticeStripe.Webhook.Handler` callback parallel for thin events** — e.g., `handle_event_notification/1` callback. Hold until the Plug-dispatch question above is answered; right now adopters call `parse_event_notification/4` directly in their controllers.
- **`fetch_related_object/3` with `nil` related_object behavior — auto-fall-through to `fetch_event/3`?** Tempting convenience but conflates two operations; keep them separate. Adopters explicitly handle `related_object: nil` → call `fetch_event/3`.
- **`/v2/`-namespaced resource module surface** beyond webhook helpers — out of v1.5 per REQUIREMENTS.md "Out of Scope".
- **Bulk thin-event replay / dead-letter / processor abstractions** — application concern, lives downstream in Accrue or adopter code (locked v1.0 scope-discipline decision; reaffirmed in REQUIREMENTS.md "Out of Scope").

</deferred>

---

*Phase: 47-Thin-Event SDK Surface & Webhook Reconciliation*
*Context gathered: 2026-05-27*
