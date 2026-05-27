---
phase: 47-thin-event-sdk-surface-webhook-reconciliation
plan: 01
subsystem: webhooks
tags: [thin-events, types, struct, dispatch, backwards-compat]
requires:
  - LatticeStripe.Event (existing)
  - LatticeStripe.ObjectTypes (existing)
provides:
  - LatticeStripe.EventNotification.t()
  - LatticeStripe.EventNotification.RelatedObject.t()
  - Event.t() :related_object field (THIN-04)
  - LatticeStripe.ObjectTypes.fetch_module/1
affects:
  - lib/lattice_stripe/event.ex
  - lib/lattice_stripe/object_types.ex
  - test/lattice_stripe/event_test.exs
  - test/lattice_stripe/object_types_test.exs
tech-stack:
  added: []
  patterns:
    - "Nested-sub-struct pattern (Invoice.LineItem analog)"
    - "Custom Inspect impl hiding noisy/auth-adjacent fields"
    - "Infallible from_map/1 with nil-handling clause"
    - "Typed-gate accessor over existing dispatch table"
key-files:
  created:
    - lib/lattice_stripe/event_notification.ex
    - lib/lattice_stripe/event_notification/related_object.ex
    - test/support/fixtures/event_notification.ex
    - test/lattice_stripe/event_notification_test.exs
  modified:
    - lib/lattice_stripe/event.ex
    - lib/lattice_stripe/object_types.ex
    - test/lattice_stripe/event_test.exs
    - test/lattice_stripe/object_types_test.exs
key-decisions:
  - "Encoded RESEARCH Finding 1: wire object value is 'v2.core.event' (not 'v2.core.event_notification' as CONTEXT D-01 originally stated)"
  - "Encoded RESEARCH Finding 2: EventNotification.created typed as String.t() | nil (ISO 8601); Event.created stays integer() (snapshot Unix seconds) — asymmetry preserved per Open Question 2 (a)"
  - "Single source of truth for RelatedObject: same module surfaces on both EventNotification.t() and Event.t()"
  - "Inspect hides :extra and :reason to avoid leaking request id + idempotency key (Pitfall 4)"
  - "ObjectTypes.fetch_module/1 added without any new dispatch entries (per D-05)"
requirements-completed: [THIN-04]
duration: ~30 min
completed: 2026-05-27
---

# Phase 47 Plan 01: Thin-Event Types Foundation Summary

Shipped the typed-data foundation for Phase 47: `LatticeStripe.EventNotification` + nested `RelatedObject` sub-struct (single source of truth for `related_object` across `EventNotification.t()` and `Event.t()`), the `Event.related_object` extension landing THIN-04, the `ObjectTypes.fetch_module/1` typed-gate helper that downstream `fetch_related_object/3` (Plan 04) will call before any HTTP request to fail fast on unknown types, and a canonical thin-event wire-payload fixture for downstream test reuse.

**Duration:** ~30 min
**Start:** 2026-05-27T09:24:00Z (approximate — env timestamp before Task 1 work began)
**End:** 2026-05-27T09:27:36Z
**Tasks:** 2 / 2 complete
**Files:** 8 (4 created, 4 modified)
**Tests:** 57 unit tests (event_notification + event + object_types), all green. Full suite: 1952 tests, 0 failures.

## Files Created

| File | Purpose |
|---|---|
| `lib/lattice_stripe/event_notification.ex` | Top-level `%EventNotification{}` typed struct + `from_map/1` + custom `Inspect`. Defaults `object` to `"v2.core.event"`, types `created: String.t() \| nil` (ISO 8601 per wire). |
| `lib/lattice_stripe/event_notification/related_object.ex` | Nested `%RelatedObject{}` sub-struct (`id`, `type`, `url` — all `String.t() \| nil`). `from_map(nil) -> nil` clause is load-bearing for both parent decoders. |
| `test/support/fixtures/event_notification.ex` | Canonical wire-format fixture builder: `event_notification_map/1` (with `related_object`) and `event_notification_map_no_related_object/1` (sets `related_object` to `nil`). |
| `test/lattice_stripe/event_notification_test.exs` | 19 tests across `from_map/1`, `Inspect`, `RelatedObject.from_map/1`, and `RelatedObject Inspect` — includes the Pitfall 4 security regression refute. |

## Files Modified

| File | Change |
|---|---|
| `lib/lattice_stripe/event.ex` | Added `alias LatticeStripe.EventNotification.RelatedObject`; extended `@known_fields`, `defstruct`, `@type t`, and `from_map/1` with `:related_object` decoded via `RelatedObject.from_map/1`. Snapshot-event backwards compat preserved (`Event.from_map(snapshot_payload) -> %Event{related_object: nil}`). |
| `lib/lattice_stripe/object_types.ex` | Added public `fetch_module/1` returning `{:ok, module()} \| :error`. Uses the same `Map.fetch(@object_map, type)` already used inside `maybe_deserialize/1` — exposed as a typed boundary for Plan 04's HTTP fail-fast gate. No new dispatch entries (per D-05). |
| `test/lattice_stripe/event_test.exs` | Added `alias RelatedObject`; added two cases under `"from_map/1"`: "decodes related_object map to %RelatedObject{} struct on v2-fetched events" and "related_object is nil on snapshot v1 events (backwards-compat)". |
| `test/lattice_stripe/object_types_test.exs` | Added `describe "fetch_module/1"` with 5 tests: customer/invoice known types, `"v2.core.account"` v2-namespace miss returns `:error`, nil input returns `:error`, empty string returns `:error`. |

## The EventNotification ↔ RelatedObject ↔ Event Triangle

```
   %EventNotification{                  %Event{
     id, object: "v2.core.event",         id, object: "event",
     type, created (ISO string),          type, created (integer),
     livemode, context,                   livemode, ..., context,
     related_object: ─┐                   related_object: ─┐
     reason, extra                        data, request,   │
   }                  │                   account, extra   │
                      │                                    │
                      └────────────┬───────────────────────┘
                                   ▼
                  %LatticeStripe.EventNotification.RelatedObject{
                    id, type, url, extra
                  }
                  # Single source of truth — shared sub-struct.
                  # Decoded by RelatedObject.from_map/1 unconditionally
                  # in both parent decoders; nil round-trips via
                  # def from_map(nil), do: nil clause.
```

This shape lets Plan 02 (`parse_event_notification/4`) decode straight into `%EventNotification{}` and Plan 04 (`fetch_event/3` + `fetch_related_object/3`) consume `%EventNotification.related_object`, dispatch through `ObjectTypes.fetch_module/1`, and (for `fetch_event/3`) unwrap into `%Event{related_object: %RelatedObject{...}}`.

## Wire-Format Corrections Encoded

Per RESEARCH.md, two wire-format facts overrode CONTEXT D-01's original wording:

1. **Finding 1:** `object: "v2.core.event"` (NOT `"v2.core.event_notification"`). The same string both on parsed notifications (no `data`/`changes` keys) and on fully-fetched events. Encoded in `EventNotification.defstruct` default and in fixture canonical map.
2. **Finding 2:** `created` is an ISO 8601 string like `"2026-03-09T13:00:28.435Z"` (NOT a Unix integer). Encoded in `@type t` and inline comments in both `defstruct` and `@type t` blocks.

## Fixture Map Contents

The canonical `event_notification_map/0` fixture matches the RESEARCH "Wire-format reference payload" block (lines 576-597 of `47-RESEARCH.md`, sourced from stripe-node v2 events test fixtures and Stripe Event Destinations docs):

- `id`: `"evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO"`
- `object`: `"v2.core.event"`
- `type`: `"v2.core.account.updated"`
- `livemode`: `false`
- `created`: `"2026-03-09T13:00:28.435Z"`
- `context`: `nil`
- `reason`: `%{"type" => "request", "request" => %{"id" => "req_v2y9y15XqG3Futmjg", "idempotency_key" => "ik_..."}}`
- `related_object`: `%{"id" => "acct_1T93Q4Pmpb34Vto6", "type" => "v2.core.account", "url" => "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"}`

The `event_notification_map_no_related_object/1` variant overrides `"related_object" => nil` for snapshot-style v2 event tests.

## Notes for Plan 04

### Open Question 2 (Event.created type widening)

RESEARCH.md flags `Event.created` type asymmetry as Open Question 2: when an `%Event{}` is fetched from `/v2/core/events/{id}` (Plan 04's `fetch_event/3`), the wire value of `created` arrives as an ISO 8601 string — but the current `Event.@type created` is `integer() | nil`. This plan (47-01) deliberately did NOT widen the type spec per the PLAN guidance: "Do NOT widen `Event.@type created` to also include `String.t()` in this plan — RESEARCH Open Question 2 flags it as a separate concern; plan 04 (`fetch_event/3`) will surface the asymmetry and the executor will note it in that plan's SUMMARY."

**Recommendation for Plan 04 executor:** Adopt option (a) from RESEARCH (widen `@type t` `created` from `integer() | nil` to `integer() | String.t() | nil` rather than coercing). This preserves Stripe's wire semantics verbatim and matches the choice already made for `EventNotification.created`. The decision should land in 47-04-SUMMARY.md.

### Plan 04 dispatch path

`fetch_related_object/3` should call `ObjectTypes.fetch_module(related_object.type)` BEFORE making any HTTP request:
- `{:ok, _module}` → proceed with `Client.request(client, %Request{path: notif.related_object.url})` then unwrap via `ObjectTypes.maybe_deserialize/1`.
- `:error` → return `{:error, {:unknown_object_type, type}}` (Phase 47 D-05 fail-fast).

The dispatch table currently does NOT have an entry for `"v2.core.account"` — this is intentional. The 47-04 fail-fast tests should exercise that exact path.

## Deviations from Plan

### Soft Deviation — Acceptance Criterion Grep Pattern

**Found during:** Task 2 acceptance gate verification
**Issue:** The acceptance criterion `grep ':related_object' lib/lattice_stripe/event.ex | grep -v '^#'` returns at least 3 matches (defstruct entry, @type t entry, from_map decode line)" is unsatisfiable by its literal pattern. Only the `defstruct` entry uses `:related_object,` (atom-with-leading-colon form); the `@type t` entry and the `from_map/1` decode line use Elixir keyword syntax (`related_object:` — no leading colon). The grep pattern returns 1, not 3.
**Resolution:** The intent of the criterion (all 3 locations are touched) is verifiably satisfied. Direct check via `grep -n 'related_object' lib/lattice_stripe/event.ex` confirms `defstruct` line, `@type t` line, and `from_map/1` decode line are all present, along with the moduledoc field-by-field entry and the alias. No code fix is needed; this is a plan-author error in the grep pattern. Flagging here so the criterion can be re-worded in a future plan as `grep -E 'related_object[,:]' lib/lattice_stripe/event.ex` (which would correctly match all three forms).
**Files modified:** None (no fix needed)
**Verification:** Direct `grep -n 'related_object' lib/lattice_stripe/event.ex` shows 6 lines including the 3 intent-bearing ones (defstruct line 63, @type t line 105, from_map line 234). All structural locations are present.

**Total deviations:** 0 auto-fixes, 1 soft-deviation (acceptance-criterion wording, no code impact).
**Impact:** None.

## Threat Surface Scan

No new threat surface beyond what is already in the plan's `<threat_model>`. All decoders are infallible-deserialize / drop-unknown-into-extra (no eval, no shell-out). The `RelatedObject.from_map(nil) -> nil` clause + `RelatedObject.from_map(map) when is_map(map)` clause together fail closed on non-map input (raises `FunctionClauseError` at the decode boundary).

## Self-Check: PASSED

- [x] `lib/lattice_stripe/event_notification.ex` exists on disk (verified)
- [x] `lib/lattice_stripe/event_notification/related_object.ex` exists on disk (verified)
- [x] `test/support/fixtures/event_notification.ex` exists on disk (verified)
- [x] `test/lattice_stripe/event_notification_test.exs` exists on disk (verified)
- [x] Task 1 commit `41bab90` reachable via `git log --oneline -3` (verified)
- [x] Task 2 commit `60c53a9` reachable via `git log --oneline -3` (verified)
- [x] `mix compile --warnings-as-errors` exits 0 (verified)
- [x] `mix test test/lattice_stripe/event_notification_test.exs test/lattice_stripe/event_test.exs test/lattice_stripe/object_types_test.exs` exits 0 — 57 tests pass (verified)
- [x] Full suite `mix test` exits 0 — 1952 tests, 0 failures (verified — no regressions)
- [x] All Task 1 source acceptance criteria pass (file existence, defstruct shape, from_map nil clause, object default, type spec, alias to RelatedObject, defimpl Inspect for both modules, fixture contents)
- [x] All Task 2 source acceptance criteria pass (test file existence, describe blocks present, Pitfall 4 refute test exists, alias added in event.ex, RelatedObject.from_map(map["related_object"]) decode line present, fetch_module/1 nil clause + binary clause present, describe fetch_module/1 present)
- [x] Soft deviation documented above
- [x] No accidental file deletions (`git diff --diff-filter=D --name-only HEAD~2 HEAD` returned empty)

## Continuation Note

Plan 02 (`parse_event_notification/4`) can now `Jason.decode!/1` payload → `EventNotification.from_map/1` to produce `%EventNotification{}`. Plan 04 (`fetch_event/3` + `fetch_related_object/3`) can now (a) consume `%EventNotification.related_object`, (b) gate HTTP via `ObjectTypes.fetch_module/1`, and (c) for `fetch_event/3`, unwrap into `%Event{related_object: %RelatedObject{...}}`. Plan 05 (`Testing.event_notification/1`) can call `EventNotification.from_map/1` directly.

THIN-04 fully landed.
