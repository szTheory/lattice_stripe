# Phase 47: Thin-Event SDK Surface & Webhook Reconciliation - Research

**Researched:** 2026-05-27
**Domain:** Stripe webhooks — `/v2/events` thin-event verification and fetch-after-verify primitives for an Elixir SDK
**Confidence:** HIGH (Standard Stack, Patterns, Pitfalls), MEDIUM (Telemetry parity), LOW (rate-limit numerics — citation provided but unaudited)

## Summary

Phase 47 ships net-new thin-event helpers (`Webhook.parse_event_notification/4`, `Webhook.fetch_event/3`, `Webhook.fetch_related_object/3`), the `LatticeStripe.EventNotification` typed struct + nested `RelatedObject` sub-struct, an `Event.related_object` field extension, `Testing.generate_thin_event_payload/3` + `Testing.event_notification/1`, and a four-surface reconciliation of `Webhook.check_tolerance/2` `tolerance: 0` (code + plug schema + test + docstring + CHANGELOG). Stack is unchanged — pure-Elixir, reuses Finch/Jason/Plug.Crypto/Telemetry already wired in.

The research surfaced **three meaningful corrections** the CONTEXT.md decisions did not anticipate (see "Critical Findings" below). None of them invalidate the eight locked decisions, but two of them materially change implementation details and **must** propagate into the plans:

1. **The wire-format `object` field is `"v2.core.event"`**, not `"v2.core.event_notification"` (CONTEXT D-01 misstated). Same `object` value as a fully-fetched v2 event. Stripe-node uses **presence-of-`data`** as the discriminator, not the `object` string.
2. **`created` on thin events is an ISO 8601 string** (e.g. `"2026-03-09T13:00:28.435Z"`), not a Unix integer. `Event.created` on v1/snapshot events stays integer. Two-mode field if we share types — easier to type as `String.t() | integer() | nil` on `EventNotification`.
3. **`fetch_event/3` retrieval endpoint is `/v2/core/events/{id}`**, not `/v1/events/{id}`. CONTEXT D-04's "internally calls `Event.retrieve/3`" needs revision — `Event.retrieve/3` hits the v1 endpoint. Phase 47 needs **either** a new v2-aware `Event.retrieve_v2/3` helper **or** for `fetch_event/3` to call `Client.request/2` directly with the `/v2/core/events/` path.

**Primary recommendation:** Plan in five plans matching the natural seams: (1) `EventNotification` + `RelatedObject` types + `Event.related_object` extension, (2) `parse_event_notification/4` + bang variant + telemetry wrap, (3) WEBFIX-01 four-surface reconciliation (deliberately separate plan — bounded blast radius), (4) `fetch_event/3` + `fetch_related_object/3` + `ObjectTypes.fetch_module/1` + bang variants, (5) `Testing.generate_thin_event_payload/3` + `Testing.event_notification/1` + Wave 0 thin-event fixtures.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HMAC signature verification | Pure functional core (`LatticeStripe.Webhook`) | — | Already lives there; thin events reuse `verify_signature/4` byte-for-byte |
| Thin-event payload decode | Pure functional core (`LatticeStripe.EventNotification`) | — | Mirrors `Event.from_map/1` precedent; no I/O |
| Authoritative-state fetch (`/v2/core/events/{id}`) | Client/HTTP pipeline (`LatticeStripe.Client.request/2`) | `LatticeStripe.Webhook.fetch_event/3` (binding) | Reuses existing HTTP pipeline incl. retry/idempotency/telemetry |
| Related-object fetch (`related_object.url`) | Client/HTTP pipeline (`LatticeStripe.Client.request/2`) | `LatticeStripe.Webhook.fetch_related_object/3` (binding) | URL comes from Stripe verbatim; dispatch happens client-side |
| Typed deserialization of related object | Pure functional core (`LatticeStripe.ObjectTypes.maybe_deserialize/1`) | New `ObjectTypes.fetch_module/1` (D-05) | Dispatch table is single source of truth |
| Plug-level snapshot dispatch | Plug boundary (`LatticeStripe.Webhook.Plug`) | — | Unchanged in v1.5 per D-08 |
| Signed test-payload generation | Test helper (`LatticeStripe.Testing`) | `LatticeStripe.Webhook.generate_test_signature/3` (sign step) | Mirrors existing snapshot Testing helper layout |
| Telemetry span (verify boundary) | Telemetry helper (`LatticeStripe.Telemetry.webhook_verify_span/2`) | — | Same span as `construct_event/4` — verify boundary is identical |

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 (Notification Struct Shape & Location):** Ship a new top-level `LatticeStripe.EventNotification` module with a nested `LatticeStripe.EventNotification.RelatedObject` typed struct. `EventNotification.t()` exposes `id, type, created, context, related_object` (plus `object` and `livemode`); `RelatedObject.t()` exposes `id, type, url` (all `String.t() | nil`). `Webhook.parse_event_notification/4` returns `{:ok, %EventNotification{}} | {:error, reason}`.

> **Research correction (HIGH confidence, [VERIFIED: stripe-node source]):** The CONTEXT-asserted `object: "v2.core.event_notification"` value is **incorrect**. Verified `object` value on the wire is `"v2.core.event"` — same string both on the parsed notification AND on the fully-fetched event. Stripe-node uses presence-of-`data`/`changes` (or in the constructEvent codepath, the inverse: `jsonPayload.object === 'v2.core.event'` to *reject* a thin payload from snapshot helpers). Plans must encode the correct value.

**D-02 (Event.t() Extension):** Add `related_object: nil` to `LatticeStripe.Event` `defstruct` and `@known_fields`. Type as `EventNotification.RelatedObject.t() | nil` — **share the same `RelatedObject` sub-struct** between `EventNotification` and `Event`. `Event.from_map/1` decodes `related_object` map → `RelatedObject` struct via `RelatedObject.from_map/1`.

**D-03 (WEBFIX-01 — `tolerance: 0` Reconciliation):** Code-fix path. Change `lib/lattice_stripe/webhook.ex:268-273` `check_tolerance(_timestamp, 0)` to return `:ok`. Plug schema `:tolerance` from `:pos_integer` to `:non_neg_integer`. Rewrite `test/lattice_stripe/webhook_test.exs:121`. Update inline comment + CHANGELOG entry.

**D-04 (Client Binding for Fetch Helpers):** Explicit client at fetch time. `parse_event_notification/4` is client-free. Both fetchers take the client explicitly. `fetch_event(%Client{}, notification_or_id, opts \\ [])` and `fetch_related_object(%Client{}, %EventNotification{}, opts \\ [])`. Notification struct stays pure serializable data.

> **Research correction (HIGH confidence, [VERIFIED: stripe-node source + stripe-go source + Stripe v2 API docs]):** `Event.retrieve/3` calls `/v1/events/{id}` (see `lib/lattice_stripe/event.ex:124`). The v2 endpoint is `/v2/core/events/{id}`. CONTEXT D-04's "internally calls `Event.retrieve/3`" needs revision. Two options for plans: (a) `fetch_event/3` builds its own `Request{path: "/v2/core/events/#{id}"}` and uses `Resource.unwrap_singular(&Event.from_map/1)`, or (b) add a new `Event.retrieve_v2/3` helper. Option (a) keeps phase scope tight; option (b) creates v1/v2 retrieval parity for future surface. Recommend (a) for v1.5.

**D-05 (Unknown `related_object.type` Behavior):** Typed error. `fetch_related_object/3` returns `{:error, {:unknown_object_type, type_string}}` on dispatch miss. Fail fast — before HTTP request. Introduce `ObjectTypes.fetch_module/1 :: {:ok, module()} | :error`. No raw-fallback escape hatch.

**D-06 (Testing Helper API Surface):** Add new `LatticeStripe.Testing.generate_thin_event_payload/3` paralleling `generate_webhook_payload/3`. Signature: `generate_thin_event_payload(type, related_object_data, opts) :: {payload :: String.t(), sig_header :: String.t()}`. Opts: `:secret` (required), `:timestamp`, `:id`, `:context`, `:livemode`. Add `LatticeStripe.Testing.event_notification/1` parallel to `dispute/1` etc.

**D-07 (Verification + Error Atom Set):** `parse_event_notification/4` reuses **exactly** the same error atom set as `construct_event/4`. Same HMAC scheme. `fetch_related_object/3` adds `{:unknown_object_type, type}` + `:no_related_object`. `fetch_event/3` returns standard `Error.t()` HTTP errors + `:no_event_id` defensive case.

**D-08 (Webhook.Plug Routing):** `LatticeStripe.Webhook.Plug` and `LatticeStripe.Webhook.Handler` behaviour are **unchanged** in v1.5 (other than the `:tolerance` schema reconciliation from D-03). Thin-event adopters wire their own Phoenix controller.

### Claude's Discretion

- Exact module/file layout: `lib/lattice_stripe/event_notification.ex` + `lib/lattice_stripe/event_notification/related_object.ex` per the `Invoice.LineItem` / `CreditNote.LineItem` precedent.
- Internal helper extraction (e.g., factoring `parse_event_notification/4` and `construct_event/4` shared verification step) is implementation-detail; planner decides.
- ExDoc grouping for `LatticeStripe.EventNotification` — group with `LatticeStripe.Event` + `LatticeStripe.Webhook` under the existing "Webhooks" section.

### Deferred Ideas (OUT OF SCOPE)

- Thin-event-aware `LatticeStripe.Webhook.Plug` dispatch mode.
- `fetch_related_object_raw/3` (or `:raw_on_unknown` opt) escape hatch.
- `LatticeStripe.Webhook.Handler` callback parallel for thin events (`handle_event_notification/1`).
- `fetch_related_object/3` with `nil` related_object auto-fall-through to `fetch_event/3`.
- `/v2/`-namespaced resource module surface beyond webhook helpers.
- Bulk thin-event replay / dead-letter / processor abstractions.
- `guides/webhooks-thin-events.md` canonical Phoenix guide (Phase 48 / GUIDE-03).
- Integration test surface against real Stripe API (Phase 48 / VERIFY-03).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| THIN-01 | `Webhook.parse_event_notification/4` verifies thin-event signature + returns typed notification struct. | Wire format verified [VERIFIED: stripe-node `parseEventNotification` source]. HMAC scheme verified identical to snapshot [VERIFIED: stripe-node Webhooks.ts — same `signature.verifyHeader` codepath]. Error atom set verified reusable [CITED: lib/lattice_stripe/webhook/signature_verification_error.ex]. |
| THIN-02 | `Webhook.fetch_event/3` retrieves full `Event.t()` for a thin-event notification. | v2 retrieval path **`/v2/core/events/{id}`** verified [VERIFIED: stripe-node `EventResource.retrieve` source + Stripe v2 API docs]. Per-request opts `:client`, `:api_version`, `:idempotency_key` already supported via `Client.request/2` opts [CITED: lib/lattice_stripe/client.ex:195-200]. |
| THIN-03 | `Webhook.fetch_related_object/3` retrieves typed underlying resource via `ObjectTypes` dispatch. | `related_object.url` is verbatim Stripe-provided path [VERIFIED: stripe-node `fetchRelatedObject` source uses it as-is]. `ObjectTypes.maybe_deserialize/1` already implements the dispatch [CITED: lib/lattice_stripe/object_types.ex:55]. Expand machinery available via `:expand` opt [CITED: lib/lattice_stripe/client.ex:200]. |
| THIN-04 | `Event` struct surfaces `context` and `related_object`. | `context` already exists in `Event.@known_fields` and `defstruct` [CITED: lib/lattice_stripe/event.ex:46,57]. Need to add `:related_object` field + decode in `from_map/1`. |
| WEBFIX-01 | `check_tolerance/2` `tolerance: 0` reconciliation. | Four-surface drift verified [CITED: lib/lattice_stripe/webhook.ex:84 docstring, :268-273 code, lib/lattice_stripe/webhook/plug.ex:142-146 schema, test/lattice_stripe/webhook_test.exs:121 test]. Code-fix path aligns with every canonical Stripe SDK [VERIFIED: stripe-node DEFAULT_TOLERANCE behavior, stripe-go IgnoreTolerance flag]. |
| TESTING-01 | `LatticeStripe.Testing.generate_thin_event_payload/3` + signature-compatible builder. | `generate_webhook_payload/3` provides the exact pattern template [CITED: lib/lattice_stripe/testing.ex:197-221]. `generate_test_signature/3` is the same HMAC sign function used for both shapes [CITED: lib/lattice_stripe/webhook.ex:206-212]. |

## Critical Findings (Wire-Format Corrections vs. CONTEXT.md)

These three corrections were discovered during this research and **must** be addressed by the planner. They do not invalidate any of the 8 locked decisions but they change implementation details inside the decisions.

### Finding 1 — `object` value [HIGH confidence, [VERIFIED: stripe-node source code]]

**CONTEXT.md D-01 says:** `object: "v2.core.event_notification"`
**Wire reality:** `object: "v2.core.event"`

The actual on-the-wire payload has `"object": "v2.core.event"`. The same value appears on the parsed notification (no `data`/`changes` fields) and on the fully-fetched event (has `data`/`changes`). Stripe-node distinguishes them by **presence of `data`**, not by the `object` string. The `constructEvent` function explicitly rejects payloads where `object === 'v2.core.event'` because those are thin-event notifications, not snapshot events.

**Impact:**
- `EventNotification.@known_fields` should default `"object" => "v2.core.event"`, not `"v2.core.event_notification"`.
- `Testing.generate_thin_event_payload/3` must emit `"object": "v2.core.event"`.
- `parse_event_notification/4` documentation should reference `"v2.core.event"`.

### Finding 2 — `created` is an ISO 8601 string, not Unix integer [HIGH confidence, [VERIFIED: stripe-node + stripe-go]]

**CONTEXT.md D-01 implies:** integer (consistent with `Event.created :: integer()`)
**Wire reality:** ISO 8601 string like `"2026-03-09T13:00:28.435Z"`

stripe-go types it as `time.Time` and parses; stripe-node leaves it as the raw string. Test fixtures in stripe-node show `"created": "1970-01-12T21:42:34.472Z"`.

**Impact:**
- `EventNotification.t()` `created` field type: `String.t() | nil` (we keep raw string; downstream parses with `DateTime.from_iso8601/1` if needed). **Do not** auto-parse — that creates a behavior split vs. `Event.created :: integer()` and forces a DateTime dep posture decision we don't need to make in v1.5.
- `RelatedObject.from_map/1` is independent — its fields are all strings already.
- `Event.created` stays integer (snapshot events use Unix seconds — unchanged).
- This is a **legitimate type asymmetry** between `EventNotification.created` (ISO string) and `Event.created` (integer). Document this in `EventNotification` docstring + the Phase 48 guide. Adopters who need a DateTime should call `DateTime.from_iso8601/1` themselves.

### Finding 3 — `fetch_event` calls `/v2/core/events/{id}`, NOT `/v1/events/{id}` [HIGH confidence, [VERIFIED: stripe-node + Stripe v2 API docs]]

**CONTEXT.md D-04 says:** `fetch_event/3` "internally calls `Event.retrieve/3`"
**Wire reality:** `Event.retrieve/3` hits `/v1/events/{id}` (see lib/lattice_stripe/event.ex:124). Thin events live at `/v2/core/events/{id}`.

stripe-node's `fetchEvent()` method explicitly calls `GET /v2/core/events/{id}`. The v1 and v2 event endpoints return **different payload shapes** — v2 has the new `reason`/`context`/`related_object` structure; v1 has the old `data`/`request`/`pending_webhooks` structure. Passing a v2 ID to `/v1/events/` will 404.

**Impact (recommended for planner):**
- `fetch_event/3` builds its own `%Request{method: :get, path: "/v2/core/events/#{id}"}` and pipes through `Client.request/2` + `Resource.unwrap_singular(&Event.from_map/1)`. **Do not** call `Event.retrieve/3`.
- `Event.from_map/1` already handles both shapes safely — unknown fields go into `:extra`. The v2 payload has fields v1 doesn't (`reason`, `related_object`) and lacks v1 fields (`pending_webhooks`, `request`). `from_map/1`'s drop-unknown-into-extra pattern Just Works.
- For the v2 fetch path, `Event.from_map/1` decodes `related_object` map → `RelatedObject` struct (per D-02).
- Defensive note: when `Event.from_map/1` receives a v2-shape payload, `Event.created` will be set to the ISO 8601 string. Two options: (a) accept the type asymmetry, set `Event.@type created :: integer() | String.t() | nil`; (b) call `DateTime.from_iso8601/1` and coerce. **Recommend (a)** — Stripe ships the wire value verbatim, and the snapshot/thin split is real domain semantics worth preserving in the type. Document this on `Event.t()`.
- Optional: add a `Stripe-Request-Trigger: event={id}` request header on this call per stripe-node convention. Not required for correctness; signals to Stripe-side analytics that this fetch was triggered by a webhook. Implementation: pass via `:additional_headers` opt if `Client.request/2` supports it, else defer.

## Standard Stack

### Core (no new dependencies — entirely additive to shipped v1.4 stack)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | ~> 0.21 (already pinned) | HTTP transport via existing `LatticeStripe.Transport.Finch` for the two new fetcher HTTP calls | Unchanged — uses the same `Client.request/2` pipeline |
| Jason | ~> 1.4 (already pinned) | Decode thin-event payload after signature verify; encode test payloads | Same as snapshot path |
| Plug.Crypto | ~> 2.0 (already pinned) | `Plug.Crypto.secure_compare/2` for timing-safe HMAC compare | Unchanged — `verify_signature/4` already uses it |
| Telemetry | ~> 1.0 (already pinned) | `LatticeStripe.Telemetry.webhook_verify_span/2` wraps both `construct_event/4` and the new `parse_event_notification/4` | Verify boundary is identical → same span event |
| NimbleOptions | ~> 1.0 (already pinned) | `Webhook.Plug` `:tolerance` schema reconciliation (`:pos_integer` → `:non_neg_integer`) | Already wired |

### Dev/Test (no new dev deps)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit | (stdlib) | Test framework | All Phase 47 tests |
| Mox | ~> 1.2 (already pinned) | Mock `LatticeStripe.Transport` behaviour for the two fetcher functions | `fetch_event/3` and `fetch_related_object/3` tests |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Reusing `verify_signature/4` byte-for-byte | Extracting a shared helper | Mechanical refactor for ~5 lines of duplication. Defer — D-07 already says reuse exact codepath. |
| `Event.retrieve_v2/3` helper module | Inline `Client.request/2` call in `fetch_event/3` | Inline is tighter for v1.5; the v2 retrieval pattern can graduate to a public `Event.retrieve_v2/3` if v1.6+ adds more `/v2/core/*` retrieval methods. |
| ISO 8601 → DateTime auto-parse on `EventNotification.created` | Keep as raw string | Auto-parse forces adopters to depend on `DateTime` shape; keeping raw string mirrors Stripe wire semantics and matches stripe-node's choice. |

**Installation:** No `mix deps.get` needed — all dependencies already on lock file.

**Version verification:** `mix.exs:267-272` confirms `finch ~> 0.21`, `jason ~> 1.4`, `telemetry ~> 1.0`, `nimble_options ~> 1.0`, `plug_crypto ~> 2.0`, `plug ~> 1.16` (optional). All pinned and matching CLAUDE.md stack table.

## Package Legitimacy Audit

**Not applicable** — Phase 47 installs **zero** new packages. All work uses already-pinned dependencies from `mix.exs:264-283`. The slopcheck protocol is skipped under its own graceful-degradation clause.

## Architecture Patterns

### System Architecture Diagram

```
                  +-----------------------------+
                  |   Stripe (sends webhook)    |
                  +--------------+--------------+
                                 |
                  Stripe-Signature header (t=...,v1=...)
                  Body: thin-event JSON (object: "v2.core.event")
                                 |
                                 v
+---------------------------------------------------------------+
|  Adopter Phoenix controller (Phase 48 documents the pattern)  |
|  - reads raw body                                             |
|  - reads stripe-signature header                              |
+----------------------------+----------------------------------+
                             |
                             v
              Webhook.parse_event_notification/4
                             |
              +--------------+---------------+
              |                              |
              v                              v
       verify_signature/4         {:error, atom}  -> caller handles
       (same HMAC scheme as              (:missing_header / :invalid_header /
        snapshot, same secret)            :no_matching_signature /
              |                            :timestamp_expired)
              v
       Jason.decode! payload
              |
              v
       EventNotification.from_map/1
              |
              v
       {:ok, %EventNotification{
                id, type, created (ISO string), context,
                livemode, object: "v2.core.event",
                related_object: %RelatedObject{} | nil}}
                             |
              +--------------+--------------+
              |                             |
              v                             v
    Webhook.fetch_event/3        Webhook.fetch_related_object/3
              |                             |
              v                             v
  Client.request(client,        ObjectTypes.fetch_module/1
   %Request{path:                       |
   "/v2/core/events/#{id}"})    +-------+--------+
              |                  |                |
              v                {:ok, mod}      :error
       Event.from_map/1          |                |
              |                  v                v
              v          Client.request   {:error,
       {:ok, %Event{                       {:unknown_object_type,
        related_object,         (path = notif.       type}}
        context,                 related_object.url)
        data, ...}}                      |
                                         v
                              ObjectTypes.maybe_deserialize/1
                                         |
                                         v
                                  {:ok, %Customer{} |
                                        %Invoice{} | ...}
```

### Recommended Project Structure (additions only)

```
lib/lattice_stripe/
├── event_notification.ex                  # NEW — top-level EventNotification module
├── event_notification/
│   └── related_object.ex                  # NEW — nested RelatedObject sub-struct
├── event.ex                               # MODIFIED — add related_object field + from_map decode
├── object_types.ex                        # MODIFIED — add fetch_module/1
├── testing.ex                             # MODIFIED — add generate_thin_event_payload/3 + event_notification/1
├── webhook.ex                             # MODIFIED — add parse_event_notification/4 + fetch_event/3 + fetch_related_object/3 + bang variants; fix tolerance: 0 clause
└── webhook/
    └── plug.ex                            # MODIFIED — :tolerance schema :pos_integer → :non_neg_integer

test/lattice_stripe/
├── event_notification_test.exs            # NEW — RelatedObject + EventNotification from_map tests + Inspect
├── event_test.exs                         # MODIFIED — add related_object decode test
├── object_types_test.exs                  # MODIFIED — add fetch_module/1 tests
├── testing_test.exs                       # MODIFIED — add generate_thin_event_payload + event_notification tests
├── webhook_test.exs                       # MODIFIED — rewrite :121 tolerance: 0 test; add parse_event_notification/4 tests
├── webhook/
│   ├── fetch_test.exs                     # NEW — fetch_event/3 + fetch_related_object/3 Mox-driven tests
│   └── plug_test.exs                      # MODIFIED — add tolerance: 0 plug-boundary test

test/support/fixtures/
└── event_notification.ex                  # NEW — canonical thin-event fixtures (with/without related_object)
```

### Pattern 1: Nested-Module Typed Struct with `from_map/1` (per `Invoice.LineItem` precedent)

**What:** Define a sub-struct in `lib/lattice_stripe/<parent>/<sub>.ex` with `@known_fields`, `defstruct`, `@type t`, and `from_map/1` that splits known vs. extra fields.
**When to use:** For `EventNotification.RelatedObject` and any future sub-struct of `EventNotification`.
**Example:**
```elixir
# Source: lib/lattice_stripe/credit_note/line_item.ex (existing precedent)
defmodule LatticeStripe.EventNotification.RelatedObject do
  @moduledoc """..."""

  @known_fields ~w[id type url]

  defstruct [:id, :type, :url, extra: %{}]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t() | nil,
          url: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {_known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: map["id"],
      type: map["type"],
      url: map["url"],
      extra: extra
    }
  end
end
```

### Pattern 2: Top-Level Notification Module with Custom Inspect

**What:** `EventNotification` follows the `Event` module shape but with the thin-event field set. Custom `Inspect` impl hides `extra` (large noise) and shows only `id`, `type`, `created`, `livemode`, `related_object`.
**When to use:** For `EventNotification` (this phase). Pattern is well-trodden in `Event`.
**Example:**
```elixir
# Source: lib/lattice_stripe/event.ex:232-255 (existing precedent)
defmodule LatticeStripe.EventNotification do
  alias LatticeStripe.EventNotification.RelatedObject

  @known_fields ~w[id object type created context livemode related_object reason]

  defstruct [
    :id,
    :type,
    :created,        # ISO 8601 string per wire
    :context,
    :livemode,
    :related_object,
    :reason,
    object: "v2.core.event",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          type: String.t() | nil,
          created: String.t() | nil,      # NOTE: ISO 8601 string, NOT Unix integer
          context: String.t() | nil,
          livemode: boolean() | nil,
          related_object: RelatedObject.t() | nil,
          reason: map() | nil,
          extra: map()
        }

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "v2.core.event",
      type: map["type"],
      created: map["created"],
      context: map["context"],
      livemode: map["livemode"],
      related_object: RelatedObject.from_map(map["related_object"]),
      reason: map["reason"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.EventNotification do
  import Inspect.Algebra
  def inspect(n, opts), do: # ... (mirror Event Inspect impl) ...
end
```

### Pattern 3: Reuse the verify-then-decode codepath

**What:** `parse_event_notification/4` follows the exact shape of `construct_event/4` (lib/lattice_stripe/webhook.ex:93-108) — wrap in telemetry span, call `verify_signature/4`, decode JSON, build typed struct.
**When to use:** For `parse_event_notification/4`. Mechanically identical except for the decode-target module.
**Example:**
```elixir
# Source: lib/lattice_stripe/webhook.ex:93-108 (existing precedent)
@spec parse_event_notification(String.t(), String.t() | nil, secret(), keyword()) ::
        {:ok, EventNotification.t()} | {:error, verify_error()}
def parse_event_notification(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
  LatticeStripe.Telemetry.webhook_verify_span([], fn ->
    case verify_signature(payload, sig_header, secret, opts) do
      {:ok, _timestamp} ->
        notification =
          payload
          |> Jason.decode!()
          |> EventNotification.from_map()

        {:ok, notification}

      {:error, _reason} = error ->
        error
    end
  end)
end
```

### Pattern 4: Typed-error gate before HTTP (D-05)

**What:** `fetch_related_object/3` checks `ObjectTypes.fetch_module/1` **before** making any HTTP request. On `:error`, returns `{:error, {:unknown_object_type, type}}` immediately.
**When to use:** For `fetch_related_object/3` (this phase).
**Example:**
```elixir
@spec fetch_related_object(Client.t(), EventNotification.t(), keyword()) ::
        {:ok, struct()}
        | {:error, Error.t() | {:unknown_object_type, String.t()} | :no_related_object}
def fetch_related_object(%Client{} = _client, %EventNotification{related_object: nil}, _opts) do
  {:error, :no_related_object}
end

def fetch_related_object(%Client{} = client, %EventNotification{related_object: %RelatedObject{type: type, url: url}}, opts) do
  case ObjectTypes.fetch_module(type) do
    {:ok, _module} ->
      %Request{method: :get, path: url, params: %{}, opts: opts}
      |> then(&Client.request(client, &1))
      |> case do
        {:ok, %Response{data: raw}} ->
          {:ok, ObjectTypes.maybe_deserialize(raw)}

        {:error, %Error{}} = error ->
          error
      end

    :error ->
      {:error, {:unknown_object_type, type}}
  end
end
```

### Pattern 5: Bang-variant raising shared error type

**What:** `parse_event_notification!/4` raises `SignatureVerificationError` for verify failures (same as `construct_event!/4`). `fetch_event!/3` and `fetch_related_object!/3` raise `LatticeStripe.Error` for HTTP errors. For typed-error atoms (`{:unknown_object_type, _}`, `:no_related_object`), construct a minimal `LatticeStripe.Error{type: :invalid_request, message: "..."}` so bang variants behave consistently.
**Why:** Three failure shapes (signature verify / typed atom / HTTP error) collapse to two exception types (`SignatureVerificationError` / `LatticeStripe.Error`) at the bang boundary. Matches v1.0+ convention.

### Anti-Patterns to Avoid

- **Don't extract a shared `verify_and_decode/{module,opts}` private helper.** Two callsites (`construct_event/4`, `parse_event_notification/4`) is fewer than three; extracting one helper to share five lines of code adds a layer of indirection that obscures the verify-then-decode flow each function needs to be readable on its own. Defer until a third callsite appears.
- **Don't embed `%Client{}` inside `%EventNotification{}`** (already locked by D-04; restated here to lock in plans). Notification struct must be safely serializable for logs / ETS / queues / distributed messaging.
- **Don't auto-call `fetch_event/3` from `fetch_related_object/3` when `related_object == nil`.** Two distinct operations; D-04 locks them separate. Return `{:error, :no_related_object}` and let the adopter decide.
- **Don't introduce a new dispatch table for thin events.** D-05 locks reuse of `ObjectTypes.maybe_deserialize/1`. The `/v2/events` `related_object.type` values are the same Stripe object type strings (`customer`, `invoice`, `charge`, etc.) — they already round-trip through the existing dispatch.
- **Don't parse `created` into a `DateTime` automatically.** Stripe ships the ISO 8601 string; keeping it as a string lets adopters opt into `DateTime.from_iso8601/1` if needed and avoids type-leak through the SDK surface.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HMAC-SHA256 timing-safe compare | Custom `Equal?(a, b)` loop | `Plug.Crypto.secure_compare/2` (already used by `Webhook.signatures_match?/2`) | Timing-attack resistance is impossible to verify in custom code; battle-tested. |
| Stripe-Signature header parsing | Custom parser | Existing `Webhook.parse_header/1` (lib/lattice_stripe/webhook.ex:228-255) | Same header format on thin events — verified [VERIFIED: stripe-node `verifyHeader` reuse]. |
| HMAC signature computation | Custom `:crypto.mac` wrapper | Existing `Webhook.compute_signature/3` (lib/lattice_stripe/webhook.ex:308-313) | Same Stripe signing scheme on thin events. |
| JSON parsing | Hand-rolled | Existing `Jason.decode!/1` per CLAUDE.md stack | Standard. |
| Telemetry span emission | Manual `:telemetry.execute/3` | `LatticeStripe.Telemetry.webhook_verify_span/2` | Already exists, same verify-boundary semantics. |
| Object-type dispatch | New dispatch table | `LatticeStripe.ObjectTypes.maybe_deserialize/1` + new `fetch_module/1` helper | Single source of truth per D-05; one-line PR to add a new type. |
| Pagination / list response handling | Custom unwrap | `Resource.unwrap_singular/2` (lib/lattice_stripe/resource.ex) | Same shape as every existing fetcher. |
| Retry / idempotency | Custom retry loop | `Client.request/2` (lib/lattice_stripe/client.ex) | Phase 47 fetchers route through this; retry + idempotency are free. |

**Key insight:** Phase 47 is an additive layer on top of a fully-built foundation. Every new helper is composition over reuse. The only **new** internal helper is `ObjectTypes.fetch_module/1` (≤ 6 lines), and that's a typed-gate accessor on the existing dispatch table, not a parallel dispatch.

## Runtime State Inventory

Not applicable — this phase is purely additive (new modules) and intra-process (no external services, no stored state, no OS registration). The only modified surface is in-process: code under `lib/`, schemas in `NimbleOptions`, and one test file. No data migration, no service config touch, no OS-registered state, no secret/env-var changes, no build artifacts that need rebuilding beyond the standard `mix compile`.

**Verified by:**
- No grep matches for `0.0.0` versioned API, no SQLite/database mentions in lib/, no `tag`/`description` strings hardcoded in OS-level config.
- `mix.exs` version stays `1.3.0` (will become `1.5.0` at release time per the v1.5 milestone plan, but that's outside Phase 47's task scope).

## Common Pitfalls

### Pitfall 1: Confusing `Event.t()` and `EventNotification.t()` in handler `case` blocks

**What goes wrong:** Adopter writes `case Webhook.parse_event_notification(...)` expecting `%Event{}` (their existing snapshot handlers), gets `%EventNotification{}`, falls through to a no-match clause and the request 500s.
**Why it happens:** Module names look similar; the snapshot path returns `%Event{}` from `construct_event/4`.
**How to avoid:** D-01 already addresses this by making `EventNotification` a **distinct** typed struct. Phase 47 plans must (a) include a docstring on `EventNotification.t()` that explicitly contrasts it with `Event.t()`, (b) ensure `parse_event_notification/4`'s docstring cross-references `construct_event/4` saying "for snapshot/v1 events, use `construct_event/4` instead", and (c) add a `Webhook` module-doc section "Snapshot events vs thin events: when to use which."
**Warning signs:** Adopter test fails with `CaseClauseError` matching on `%Event{}`.

### Pitfall 2: Treating `EventNotification.created` as a Unix integer

**What goes wrong:** Adopter does `DateTime.from_unix!(notif.created)` and crashes because `created` is `"2026-03-09T13:00:28.435Z"`, an ISO string.
**Why it happens:** `Event.created` is a Unix integer; adopters reasonably assume the parallel field follows the same convention. **Stripe broke parity here, not LatticeStripe.**
**How to avoid:** Type the field as `String.t() | nil` in `EventNotification.@type t`. Note this explicitly in the field-by-field docstring section. Optional convenience: in the Phase 48 guide, show `DateTime.from_iso8601(notif.created)` as the canonical parse.
**Warning signs:** Adopter code that mixes `notif.created` with `Event.created` will throw `FunctionClauseError` on the first.

### Pitfall 3: Passing a v2 ID to `Event.retrieve/3` and getting 404

**What goes wrong:** Adopter takes `notification.id` and calls `Event.retrieve(client, notification.id)` — the v1 endpoint doesn't know the v2 ID, returns 404, adopter is confused.
**Why it happens:** Two endpoints, same ID-string shape (`evt_...`), but the API expects type-correct routing. v1 events live at `/v1/events`, v2 at `/v2/core/events`.
**How to avoid:** Plans MUST keep `fetch_event/3` as the documented path for thin events. The `fetch_event/3` docstring must say "for v1/snapshot event IDs, use `LatticeStripe.Event.retrieve/3` instead." Cross-reference both directions.
**Warning signs:** A `LatticeStripe.Error{type: :invalid_request_error}` with 404 status during fetch-after-verify.

### Pitfall 4: Storing `%Client{}` in a notification and leaking API keys to logs/queues

**What goes wrong:** A developer adds `%Client{}` to the notification struct for "convenience"; the struct lands in a `Logger.info inspect(notif)` line; API key is now in the log retention pipeline.
**Why it happens:** Tempting "fluent" API ergonomics; both stripe-node and stripe-go bake the parsing client into the parsed notification via closures. Elixir doesn't have closure semantics for serialized data — plain struct is plain data.
**How to avoid:** D-04 already locks this. Plans must include a test that asserts `inspect(%EventNotification{...})` does NOT contain the strings `"api_key"`, `"sk_"`, or `"%Client{"`. Adopter `Inspect` impl on `EventNotification` follows `Event`'s pattern (hide `extra`).
**Warning signs:** PR review finds a `client` field on `EventNotification.defstruct`. Hard-block.

### Pitfall 5: `tolerance: 0` semantics drift coming back

**What goes wrong:** Future contributor "fixes" `check_tolerance/2` to "be stricter" and the four surfaces drift again.
**Why it happens:** The 0 case looks semantically weird ("zero tolerance means disabled? but zero tolerance also means rejects everything!") — invites recurring drift.
**How to avoid:** D-03 locks the four-surface fix. Plans must include (a) an inline source comment in `check_tolerance/2` explicitly documenting the decision, (b) a test that asserts `tolerance: 0` skips the staleness check at the function boundary AND at the Plug boundary, (c) a CHANGELOG entry under v1.5 noting the reconciliation, (d) a doctest or example in the moduledoc using `tolerance: 0`.
**Warning signs:** A future PR reintroduces `tolerance: 0 → :timestamp_expired` and the test catches it.

### Pitfall 6: `:non_neg_integer` schema breakage for existing adopters

**What goes wrong:** Plug schema change from `:pos_integer` to `:non_neg_integer` is a constraint **relaxation**, so it's strictly additive — but if a future tightening pass swaps the direction (e.g., a separate "validate `:tolerance` is at most 86400" change), that's a behavior break.
**Why it happens:** NimbleOptions schemas are part of the public Plug surface.
**How to avoid:** Plans include a test asserting `Webhook.Plug.init(secret: "x", tolerance: 0)` succeeds and a test asserting `Webhook.Plug.init(secret: "x", tolerance: -1)` raises `NimbleOptions.ValidationError` (since `:non_neg_integer` excludes negatives).
**Warning signs:** Plug-level test failure on negative tolerance.

### Pitfall 7: Test-only behavior for `Stripe-Request-Trigger` header

**What goes wrong:** Plans add `Stripe-Request-Trigger: event=<id>` to the `fetch_event/3` HTTP request, then phase-47 unit tests assert on it; but `Client.request/2` doesn't currently expose a public `:additional_headers` opt. Tests pass via Mox but production behavior diverges.
**Why it happens:** Misalignment between what's plumbed and what's tested.
**How to avoid:** **Defer adding this header entirely.** Phase 47 fetchers don't need it for correctness; deferring keeps the v1.5 scope tight and avoids the headers-plumbing detour. If the planner disagrees, the header plumbing becomes its own task with a dedicated test.

## Code Examples

### Verifying a thin-event payload (parse_event_notification/4)

```elixir
# Source: derived from lib/lattice_stripe/webhook.ex:93-108 (construct_event/4 precedent)
case LatticeStripe.Webhook.parse_event_notification(payload, sig_header, secret) do
  {:ok, %LatticeStripe.EventNotification{
     type: "v2.core.account.updated",
     related_object: %LatticeStripe.EventNotification.RelatedObject{
       type: "v2.core.account",
       id: account_id,
       url: account_url
     }} = notif} ->
    handle_account_update(notif, account_id)

  {:ok, %LatticeStripe.EventNotification{related_object: nil} = notif} ->
    # Snapshot-style v2 event (no related object) — fetch full event for context
    {:ok, %LatticeStripe.Event{} = event} = LatticeStripe.Webhook.fetch_event(client, notif)
    handle_full_event(event)

  {:error, :timestamp_expired} ->
    Logger.warning("Stripe webhook expired; check clock skew")
    {:error, :replay_protection}

  {:error, :no_matching_signature} ->
    Logger.error("Stripe webhook signature invalid — possible attack")
    {:error, :invalid_signature}
end
```

### Fetch related object with typed-error gate (D-05)

```elixir
# Source: derived from lib/lattice_stripe/object_types.ex:55 + lib/lattice_stripe/client.ex:200
case LatticeStripe.Webhook.fetch_related_object(client, notification) do
  {:ok, %LatticeStripe.Customer{} = customer} ->
    sync_customer_to_local_db(customer)

  {:ok, %LatticeStripe.Invoice{} = invoice} ->
    queue_invoice_for_reconciliation(invoice)

  {:error, {:unknown_object_type, type}} ->
    # Stripe shipped a new resource type we haven't added to the dispatch table.
    # Don't crash — log and queue for SDK update.
    Logger.warning("Unknown Stripe object type from thin event: #{type}")
    {:error, :unsupported_type}

  {:error, :no_related_object} ->
    # Snapshot-style v2 event — fetch the event itself
    LatticeStripe.Webhook.fetch_event(client, notification)

  {:error, %LatticeStripe.Error{} = error} ->
    {:error, error}
end
```

### Building a signed thin-event payload for tests (TESTING-01)

```elixir
# Source: derived from lib/lattice_stripe/testing.ex:197-221 (generate_webhook_payload/3 precedent)
{payload, sig_header} =
  LatticeStripe.Testing.generate_thin_event_payload(
    "v2.core.account.updated",
    %{
      "id" => "acct_test_123",
      "type" => "v2.core.account",
      "url" => "/v2/core/accounts/acct_test_123"
    },
    secret: "whsec_test"
  )

{:ok, notif} = LatticeStripe.Webhook.parse_event_notification(payload, sig_header, "whsec_test")
assert notif.type == "v2.core.account.updated"
assert notif.related_object.id == "acct_test_123"
```

### Wire-format reference payload (with related_object)

```json
{
  "id": "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO",
  "object": "v2.core.event",
  "type": "v2.core.account.updated",
  "livemode": false,
  "created": "2026-03-09T13:00:28.435Z",
  "context": null,
  "reason": {
    "type": "request",
    "request": {
      "id": "req_v2y9y15XqG3Futmjg",
      "idempotency_key": "ik_TgmEI3jHxXt8RFw4jS7ve2QcAReDQWBjPAkAEUm"
    }
  },
  "related_object": {
    "id": "acct_1T93Q4Pmpb34Vto6",
    "type": "v2.core.account",
    "url": "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
  }
}
```

Source: [Stripe Event Destinations docs](https://docs.stripe.com/event-destinations) + stripe-node `test/resources/V2/Core/Events.spec.js` test fixture.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Stripe.ThinEvent` (stripe-node 18.x) | `Stripe.V2.EventNotification` (stripe-node 19+) | 2024 — stripe-node v19.0.0 rename | Naming parity reference for `LatticeStripe.EventNotification` |
| `parseThinEvent` (stripe-node) | `parseEventNotification` (stripe-node) | 2024 — same release | Method-name parity reference for `parse_event_notification/4` |
| No `fetchRelatedObject` on Node V2 events | Added in stripe-node | 2024 — stripe-node PR #2201 | Confirms the fetch-after-verify pattern is the canonical thin-event API across SDKs |
| Untyped `unknown` related object | `Optional<StripeObject>` (stripe-java), `Promise<unknown>` (stripe-node) requiring narrowing | Ongoing | Precedent for D-05's typed `{:error, {:unknown_object_type, _}}` |
| Snapshot-only webhooks | Snapshot + thin-event coexistence per endpoint | 2024 — `/v2/events` GA | Adopters need both code paths; LatticeStripe's separate `construct_event/4` vs `parse_event_notification/4` matches every other SDK |

**Deprecated/outdated:**
- `Stripe.ThinEvent` legacy name — superseded by `Stripe.V2.EventNotification` in stripe-node v19+.
- Hand-coded retry loops for fetch-after-verify — `Client.request/2` retry machinery (v1.2) covers this for free.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Stripe's 100 req/s rate-limit ceiling applies in live mode; sandbox is ~25 req/s | (referenced for Phase 48 context only) | Low — Phase 47 doesn't depend on the number; the number lives in Phase 48 guide. [ASSUMED: cross-confirmed via search engine but Stripe docs page wasn't fetched in this research session.] |
| A2 | `Stripe-Request-Trigger: event=<id>` is a documented public header convention | Pitfall 7 | Low — we defer the header entirely in Phase 47 per Pitfall 7. [ASSUMED based on stripe-node source convention; not Stripe-docs-confirmed in this session.] |
| A3 | `:non_neg_integer` is a valid NimbleOptions type | D-03 implementation | Low — NimbleOptions has documented support for the type, but exact spelling needs verification at plan time. [ASSUMED based on NimbleOptions ~> 1.0 type catalog; cross-check during plan execution with `iex> NimbleOptions.validate([tolerance: 0], [tolerance: [type: :non_neg_integer]])`.] |

**If this table is empty:** Most claims in this research are [VERIFIED: stripe-node source] / [VERIFIED: stripe-go source] / [VERIFIED: Stripe v2 API docs] / [CITED: lib/lattice_stripe/...]. Only three soft assumptions remain, all rated low-risk.

## Open Questions

1. **`Stripe-Request-Trigger` header — include or defer?**
   - What we know: stripe-node sends it on `fetchEvent`/`fetchRelatedObject` ([VERIFIED: stripe-node source]). It signals to Stripe-side that the request was triggered by a webhook delivery.
   - What's unclear: Whether Stripe acts on the header (analytics? rate-limit isolation? nothing?). Not documented in Stripe's public API reference.
   - Recommendation: **Defer.** Phase 47 ships without it. Add as a follow-up if Stripe support confirms it has runtime effect, OR if a future adopter asks. Phase 48 guide can mention "set this header yourself if you want stripe-node parity" without us baking it in.

2. **`Event.created` type when fetched from `/v2/core/events/{id}` — coerce or accept asymmetry?**
   - What we know: v1 events have `created: integer()`, v2 events have `created: String.t()` (ISO 8601).
   - What's unclear: Whether to (a) loosen `Event.@type created` to `integer() | String.t() | nil` (accept asymmetry), or (b) auto-parse ISO → Unix integer on decode (force parity at the cost of round-trip).
   - Recommendation: **Accept asymmetry.** Loosening the type matches Stripe's wire reality; auto-parse would hide a real distinction. Document on `Event.t()` that v2-fetched events have string `created`. The discuss-phase didn't anticipate this; flag to user via Phase 47 plan-check if it's important to surface.

3. **`fetch_event/3` — accept `EventNotification.t() | String.t()` or just one shape?**
   - What we know: CONTEXT D-04 says "accepts `EventNotification.t()` or a bare `String.t()` id."
   - What's unclear: Whether `String.t()` form is genuinely useful in v1.5 (you'd already have a parsed notification at the point you call this) vs. just YAGNI overhead.
   - Recommendation: **Ship both shapes per D-04.** The string form is two extra lines via pattern match and gives operators an "I have an event ID but no payload, fetch it" escape hatch. Implementation: dispatch via two function clauses, one for `%EventNotification{id: id}` (extract id) and one for `String.t()`.

## Environment Availability

No external dependencies — Phase 47 work runs entirely against in-process Elixir + already-installed Hex deps. No new tools required.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All work | ✓ | 1.15+ (per CLAUDE.md) | — |
| OTP | All work | ✓ | 26+ | — |
| Finch | HTTP transport for fetchers | ✓ (already in mix.lock) | ~> 0.21 | — |
| Jason | JSON encode/decode | ✓ (already in mix.lock) | ~> 1.4 | — |
| Plug.Crypto | HMAC compare | ✓ (already in mix.lock) | ~> 2.0 | — |
| NimbleOptions | Plug schema | ✓ (already in mix.lock) | ~> 1.0 | — |
| Mox | Transport mocking in tests | ✓ (already in mix.lock, test-only) | ~> 1.2 | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) + Mox ~> 1.2 |
| Config file | `test/test_helper.exs` (existing — declares `LatticeStripe.MockTransport`, `LatticeStripe.MockJson`, `LatticeStripe.MockRetryStrategy`) |
| Quick run command | `mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/event_notification_test.exs test/lattice_stripe/webhook/fetch_test.exs test/lattice_stripe/testing_test.exs` |
| Full suite command | `mix test` |
| CI alias | `mix ci` (runs `format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `test`, `docs --warnings-as-errors`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THIN-01 | `parse_event_notification/4` happy path returns `{:ok, %EventNotification{}}` | unit | `mix test test/lattice_stripe/webhook_test.exs --only describe:parse_event_notification/4` | ❌ Wave 0 — new file |
| THIN-01 | `parse_event_notification/4` returns each verify_error atom (`:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`) | unit | (same) | ❌ Wave 0 |
| THIN-01 | `parse_event_notification!/4` raises `SignatureVerificationError` on failure | unit | (same) | ❌ Wave 0 |
| THIN-02 | `fetch_event/3` accepts `%EventNotification{}` and returns `{:ok, %Event{}}` via Mox transport | unit | `mix test test/lattice_stripe/webhook/fetch_test.exs` | ❌ Wave 0 — new file |
| THIN-02 | `fetch_event/3` accepts bare `String.t()` id form | unit | (same) | ❌ Wave 0 |
| THIN-02 | `fetch_event/3` builds `/v2/core/events/{id}` URL path (regression: NOT `/v1/events/`) | unit | (same) | ❌ Wave 0 |
| THIN-02 | `fetch_event/3` honors `:api_version` + `:idempotency_key` opts | unit | (same) | ❌ Wave 0 |
| THIN-02 | `fetch_event!/3` raises `LatticeStripe.Error` on HTTP error | unit | (same) | ❌ Wave 0 |
| THIN-03 | `fetch_related_object/3` returns `{:ok, struct()}` typed via ObjectTypes dispatch for known type | unit | (same) | ❌ Wave 0 |
| THIN-03 | `fetch_related_object/3` returns `{:error, {:unknown_object_type, type}}` for unknown type (BEFORE any HTTP call — Mox expectation count = 0) | unit | (same) | ❌ Wave 0 |
| THIN-03 | `fetch_related_object/3` returns `{:error, :no_related_object}` when `related_object == nil` | unit | (same) | ❌ Wave 0 |
| THIN-03 | `fetch_related_object/3` honors `:expand` opt | unit | (same) | ❌ Wave 0 |
| THIN-03 | `fetch_related_object/3` uses `related_object.url` verbatim as request path | unit | (same) | ❌ Wave 0 |
| THIN-04 | `Event.from_map/1` decodes v2 payload with `related_object` map → `%RelatedObject{}` struct | unit | `mix test test/lattice_stripe/event_test.exs` | ✓ exists, add cases |
| THIN-04 | `Event.t().related_object` is `nil` on snapshot v1 events (backwards compat) | unit | (same) | ✓ exists, add case |
| THIN-04 | `EventNotification.from_map/1` decodes thin-event JSON shape (all known fields + extra) | unit | `mix test test/lattice_stripe/event_notification_test.exs` | ❌ Wave 0 — new file |
| THIN-04 | `Inspect` impl on `EventNotification` hides `:extra`, shows `id`/`type`/`created`/`livemode`/`related_object` | unit | (same) | ❌ Wave 0 |
| WEBFIX-01 | `Webhook.verify_signature/4` with `tolerance: 0` returns `{:ok, ts}` for any-age timestamp | unit | `mix test test/lattice_stripe/webhook_test.exs --only describe:verify_signature/4` | ✓ rewrite existing :121 test |
| WEBFIX-01 | `Webhook.Plug.init/1` accepts `tolerance: 0` (schema change) | unit | `mix test test/lattice_stripe/webhook/plug_test.exs` | ✓ add case |
| WEBFIX-01 | `Webhook.Plug.init/1` rejects `tolerance: -1` (`:non_neg_integer` still rejects negatives) | unit | (same) | ❌ Wave 0 — add case |
| WEBFIX-01 | `Webhook.Plug` end-to-end with `tolerance: 0` and an old timestamp returns 200 (not 400) | unit (Plug.Test) | (same) | ❌ Wave 0 — add case |
| WEBFIX-01 | CHANGELOG entry exists for v1.5 documenting the reconciliation | docs-truth regression | grep test in `test/lattice_stripe/docs_truth_test.exs` | ✓ exists, extend |
| TESTING-01 | `Testing.generate_thin_event_payload/3` produces `{payload, sig_header}` that passes `parse_event_notification/4` | unit | `mix test test/lattice_stripe/testing_test.exs` | ✓ exists, add cases |
| TESTING-01 | `Testing.generate_thin_event_payload/3` accepts `nil` for `related_object_data` (snapshot-style v2 event) | unit | (same) | ❌ Wave 0 |
| TESTING-01 | `Testing.event_notification/1` builds `%EventNotification{}` from a fixture map without signing | unit | (same) | ❌ Wave 0 |
| TESTING-01 | `Testing.generate_webhook_payload/3` (existing snapshot helper) is unchanged | unit (regression) | (same) | ✓ exists |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/event_notification_test.exs test/lattice_stripe/webhook/fetch_test.exs test/lattice_stripe/testing_test.exs test/lattice_stripe/event_test.exs test/lattice_stripe/object_types_test.exs test/lattice_stripe/webhook/plug_test.exs` (≤ 5 seconds locally)
- **Per wave merge:** `mix test` (full suite ≤ 30 seconds)
- **Phase gate:** `mix ci` green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/event_notification_test.exs` — new file. Covers THIN-04 EventNotification + RelatedObject from_map + Inspect.
- [ ] `test/lattice_stripe/webhook/fetch_test.exs` — new file. Covers THIN-02 + THIN-03 with Mox-driven `LatticeStripe.MockTransport`.
- [ ] `test/support/fixtures/event_notification.ex` — new fixture module. Canonical thin-event JSON maps (with/without `related_object`, with/without `context`).
- [ ] Extension to `test/lattice_stripe/webhook_test.exs` — new `describe "parse_event_notification/4"` block + rewrite of :121.
- [ ] Extension to `test/lattice_stripe/webhook/plug_test.exs` — `tolerance: 0` Plug-level case + negative-tolerance rejection case.
- [ ] Extension to `test/lattice_stripe/testing_test.exs` — `generate_thin_event_payload/3` + `event_notification/1` cases.
- [ ] Extension to `test/lattice_stripe/object_types_test.exs` — `fetch_module/1` `{:ok, _}` and `:error` cases.
- [ ] Extension to `test/lattice_stripe/event_test.exs` — `related_object` decode case + backwards-compat (nil on snapshot events) case.

*Framework install: none — all deps already in `mix.lock`.*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Webhook secret is a pre-shared symmetric key; not a user-auth concern |
| V3 Session Management | no | Stateless verify; no sessions |
| V4 Access Control | no | No multi-user auth boundary in this code |
| V5 Input Validation | yes | `parse_event_notification/4` decodes adversary-controlled JSON; `Jason.decode!` will raise on invalid JSON. Document the verification-vs-payload-shape failure boundary (handled by the caller's `rescue Jason.DecodeError`). NimbleOptions validates Plug schema. |
| V6 Cryptography | yes | HMAC-SHA256 via `:crypto.mac` + `Plug.Crypto.secure_compare/2`. Never hand-roll. Same scheme as v1.0+ snapshot path. |
| V7 Error Handling | yes | Typed errors don't leak secrets in messages. `SignatureVerificationError` reasons are atoms, not user-supplied strings. |
| V8 Data Protection | yes | Don't log `payload`, `secret`, or `sig_header` in telemetry metadata. `webhook_verify_span/2` currently only logs `path` — verify this remains the case. |
| V9 Communications | partial | Stripe → app is HTTPS-terminated upstream of LatticeStripe; the SDK doesn't open inbound listeners. Outbound fetch-after-verify uses Finch over TLS (default). |
| V14 Configuration | yes | Secret resolution supports MFA / 0-arity fun to avoid compile-time embedding ([CITED: lib/lattice_stripe/webhook/plug.ex:122-128]). |

### Known Threat Patterns for thin-event webhooks

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replay attack (resend a captured valid webhook later) | Tampering | `tolerance` timestamp window (default 300s); D-03 keeps `tolerance: 0` as opt-out for testing only |
| Forged webhook (attacker submits payload with bad/missing signature) | Spoofing | HMAC-SHA256 verify before any business logic; `Plug.Crypto.secure_compare/2` timing-safe |
| Timing-based signature oracle (attacker probes byte-by-byte equality timing) | Information disclosure | `Plug.Crypto.secure_compare/2` (constant-time over equal-length inputs) |
| Signature secret rotation gap | Denial of service | Multi-secret list support (already shipped) — pass `[old_secret, new_secret]` |
| Unknown-related-object DoS (Stripe ships a new resource type; fetcher crashes) | Denial of service | D-05 typed error `{:error, {:unknown_object_type, _}}` — fail fast with clear signal, no crash |
| API-key leakage via inspect/logs | Information disclosure | D-04: notification struct contains no `%Client{}` — safe to log/serialize. Plans MUST include an `Inspect` assertion test. |
| `parse_event_notification/4` called with snapshot payload (or vice versa) — silent mis-decode | Tampering / consistency | Document the verification-vs-payload-shape boundary in both function docstrings. Optionally: detect `object: "event"` in `parse_event_notification/4` and return `{:error, :wrong_payload_shape}` (mirrors stripe-node's defensive check at line 160-164 of `Webhooks.ts`). **Planner decision needed** — recommended as a follow-up, not v1.5 scope. |

## Sources

### Primary (HIGH confidence — verified)

- **stripe-node `parseEventNotification` source** — `src/stripe.core.ts:1566-1722` ([VERIFIED via `gh api repos/stripe/stripe-node/contents/src/stripe.core.ts`]). Confirms: reuses `verifyHeader`, asserts `object !== 'event'`, sets `eventNotification.fetchEvent` to `/v2/core/events/${id}`, sets `eventNotification.fetchRelatedObject` to use `related_object.url` verbatim.
- **stripe-node `constructEvent` rejection branch** — `src/Webhooks.ts:127-131,160-164` ([VERIFIED]). Confirms the `object === 'v2.core.event'` discriminator string and that `constructEvent` rejects thin-event payloads.
- **stripe-node v2 Events resource** — `src/resources/V2/Core/Events.ts:1-220` ([VERIFIED]). Confirms: `interface EventBase { object: 'v2.core.event'; created: string; reason?: Reason; ... }`, `EventNotificationBase extends Omit<EventBase, 'context'>` (no `data`/`changes`), and `RelatedObject { id: string; type: string; url: string }`.
- **stripe-node v2 events test fixture** — `test/resources/V2/Core/Events.spec.js:6-50` ([VERIFIED]). Concrete payload examples confirming wire shape and `"created": "1970-01-12T21:42:34.472Z"` ISO format.
- **stripe-go V2BaseEvent + V2CoreEventReason** — `v2core_event.go:1-60` ([VERIFIED via `gh api repos/stripe/stripe-go/contents/v2core_event.go`]). Cross-confirms `Object string`, `Created time.Time` (ISO parsed), `Reason *V2CoreEventReason`, `Context string`. Same shape across two reference SDKs.
- **Stripe v2 Events API docs** — https://docs.stripe.com/api/v2/core/events ([CITED]). Confirms `/v2/core/events/{id}` is the retrieval endpoint.
- **Stripe Event Destinations docs** — https://docs.stripe.com/event-destinations ([CITED]). Reference payload with `object: "v2.core.event"` and ISO 8601 `created`.
- **Stripe webhook migration guide** — https://docs.stripe.com/webhooks/migrate-snapshot-to-thin-events ([CITED]). Confirms separate webhook secrets per shape and shared signing scheme.
- **LatticeStripe shipped surface** — all `[CITED: lib/lattice_stripe/...]` references are direct reads of the v1.4-shipped code at HEAD.

### Secondary (MEDIUM confidence — single-source or summarized)

- stripe-node v19.0.0 release notes (https://github.com/stripe/stripe-node/releases) — confirms `parseThinEvent → parseEventNotification` rename.
- stripe-node PR #2370 (typed EventNotifications) — surfaces `UnknownEventNotification` precedent for D-05.
- stripe-node PR #2201 (`fetchRelatedObject` addition) — confirms cross-SDK convergence on the fetch-after-verify pattern.
- stripe-java `EventDataObjectDeserializer.getObject() → Optional<StripeObject>` (https://stripe.dev/stripe-java/com/stripe/model/EventDataObjectDeserializer.html) — precedent for D-05's typed-empty-on-unknown response.

### Tertiary (LOW confidence — single source, flagged)

- 100 req/s Stripe rate-limit ceiling — referenced as background context only; A1 in Assumptions Log. The number lives in Phase 48 / GUIDE-03 scope, not Phase 47.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps, all pinned versions verified against mix.exs at HEAD.
- Architecture: HIGH — patterns verified against shipped LatticeStripe code at HEAD and against stripe-node + stripe-go source at master.
- Pitfalls: HIGH — pitfalls 1-6 are mechanically derivable from the wire-format corrections + the four-surface drift; pitfall 7 is a deferral recommendation, not a research gap.
- Telemetry parity: MEDIUM — `webhook_verify_span/2` exists and shape-matches what `parse_event_notification/4` needs; planner should confirm at task time that the span's start metadata (just `:path`) is enough or whether to enrich it with `event_shape: :thin | :snapshot`.

**Research date:** 2026-05-27
**Valid until:** 2026-06-26 (30 days — Stripe wire format and SDK API surface are stable; Elixir stack pinned to mature majors)

---

*This research deliberately surfaces three corrections to CONTEXT.md (wire-format `object` value, `created` ISO string vs. integer, `/v2/core/events/{id}` retrieval path). These are mechanical implementation details discovered by reading the actual stripe-node + stripe-go source code — the 8 locked CONTEXT.md decisions all remain valid; only the implementation details inside D-01 and D-04 need adjustment. Plans must encode the corrected values.*
