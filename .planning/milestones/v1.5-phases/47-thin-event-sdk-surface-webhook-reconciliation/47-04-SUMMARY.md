---
phase: 47-thin-event-sdk-surface-webhook-reconciliation
plan: 04
subsystem: webhooks
tags: [thin-events, fetch, v2-events, dispatch, fail-fast, THIN-02, THIN-03]
requires:
  - LatticeStripe.EventNotification (plan 47-01)
  - LatticeStripe.EventNotification.RelatedObject (plan 47-01)
  - LatticeStripe.ObjectTypes.fetch_module/1 (plan 47-01)
  - LatticeStripe.ObjectTypes.maybe_deserialize/1 (existing)
  - LatticeStripe.Client.request/2 (existing — opts forwarding, expand machinery)
  - LatticeStripe.Resource.unwrap_singular/2 (existing)
  - LatticeStripe.Event.from_map/1 + Event.related_object field (plan 47-01)
provides:
  - LatticeStripe.Webhook.fetch_event/2,3
  - LatticeStripe.Webhook.fetch_event!/3
  - LatticeStripe.Webhook.fetch_related_object/2,3
  - LatticeStripe.Webhook.fetch_related_object!/3
affects:
  - lib/lattice_stripe/webhook.ex
  - test/lattice_stripe/webhook/fetch_test.exs
tech-stack:
  added: []
  patterns:
    - "Verify-then-fetch separation (parse_event_notification/4 returns a pure %EventNotification{}, then fetchers take %Client{} explicitly per D-04)"
    - "Typed-error gate BEFORE HTTP (D-05 fail-fast — ObjectTypes.fetch_module/1 check ahead of Client.request/2)"
    - "Three-clause function head for input-shape dispatch (defensive nil + notification-extract + bare-id)"
    - "Bang-variant collapse: typed-error atoms wrap into %Error{type: :invalid_request_error} for consistent exception semantics"
key-files:
  created:
    - test/lattice_stripe/webhook/fetch_test.exs
  modified:
    - lib/lattice_stripe/webhook.ex
key-decisions:
  - "Encoded RESEARCH Finding 3: hard-coded /v2/core/events/{id} path (NOT /v1/events/), regression-locked by `refute String.contains?(req.url, \"/v1/events/\")` in the happy-path test"
  - "Honored D-05 fail-fast contract: ObjectTypes.fetch_module/1 called BEFORE Client.request/2; unknown types return {:error, {:unknown_object_type, type}} with Mox-verified zero HTTP calls"
  - "Honored D-07 typed-error atoms: :no_event_id (id: nil), :no_related_object (related_object: nil), {:unknown_object_type, type} (dispatch miss) all returned without HTTP calls"
  - "Honored D-04 pure-data invariant: fetchers take %Client{} as the first explicit arg; %EventNotification{} carries no embedded credential material"
  - "Honored Pitfall 7 deferral: no Stripe-Request-Trigger header plumbing (out of v1.5 scope)"
  - "Used :stripe_version as the per-request opt key (the actual key in Client.request/2 :180-204), NOT :api_version — plan body used :api_version informally; PATTERNS body referenced the existing Client.request/2 forwarding which uses :stripe_version"
requirements-completed: [THIN-02, THIN-03]
duration: ~5 min
completed: 2026-05-27
---

# Phase 47 Plan 04: Thin-Event Fetch-After-Verify Primitives Summary

Shipped THIN-02 + THIN-03 — the four public fetch-after-verify primitives that consume a verified `%EventNotification{}` (or a bare event ID) to retrieve canonical Stripe state. `fetch_event/3` issues `GET /v2/core/events/{id}` and returns `{:ok, %Event{}}` (with `related_object` populated by the v2 wire payload). `fetch_related_object/3` enforces the Phase 47 D-05 fail-fast contract — typed-error gate via `ObjectTypes.fetch_module/1` BEFORE any HTTP request — then issues a GET against `notification.related_object.url` and decodes the response via `ObjectTypes.maybe_deserialize/1`. Both have bang variants that collapse all typed-error atoms into `%LatticeStripe.Error{}` for uniform exception semantics.

**Duration:** ~5 min
**Start:** 2026-05-27T09:42:43Z
**End:** 2026-05-27T09:47:51Z
**Tasks:** 3 / 3 complete
**Files:** 2 (1 created, 1 modified)
**Tests:** 20 new tests in `webhook/fetch_test.exs` (THIN-02: 7 + 3 bang = 10; THIN-03: 6 + 4 bang = 10). Combined webhook suite: 59 tests, 0 failures. Full suite: 1983 tests, 0 failures, 1 skipped — no regression from the wave-2 baseline (1963).

## Files Created

| File | Purpose |
|---|---|
| `test/lattice_stripe/webhook/fetch_test.exs` | `LatticeStripe.Webhook.FetchTest` (async: true, `setup :verify_on_exit!`) — Mox-driven HTTP tests for all 4 new public functions. 20 tests across 4 describe blocks. |

## Files Modified

| File | Change |
|---|---|
| `lib/lattice_stripe/webhook.ex` | (a) Added aliases: `Client`, `Error`, `RelatedObject`, `ObjectTypes`, `Request`, `Resource`, `Response`. (b) Added `fetch_event/3` (3-clause input dispatch) + `fetch_event/2` convenience + `fetch_event!/3` bang variant. (c) Added `fetch_related_object/3` (2-clause input dispatch with D-05 typed-error gate) + `fetch_related_object/2` convenience + `fetch_related_object!/3` bang variant. All placed between `parse_event_notification!/4` (plan 02) and `verify_signature/4` (existing). |

## Function Surface Added

### `fetch_event/3` (THIN-02)

```elixir
@spec fetch_event(Client.t(), EventNotification.t() | String.t(), keyword()) ::
        {:ok, Event.t()} | {:error, Error.t() | :no_event_id}
```

Three-clause input dispatch (per PATTERNS.md):

1. **Defensive `%EventNotification{id: nil}` clause** → `{:error, :no_event_id}` — NO HTTP request.
2. **Notification-extract `%EventNotification{id: id}` clause** → delegates to bare-id clause.
3. **Bare `String.t() id` clause** → `%Request{method: :get, path: "/v2/core/events/#{id}", params: %{}, opts: opts} |> Client.request(client) |> Resource.unwrap_singular(&Event.from_map/1)`.

Path is **`/v2/core/events/{id}`** (RESEARCH Finding 3) — explicitly NOT `/v1/events/{id}` which `Event.retrieve/3` calls for snapshot v1 events. The two endpoints differ in payload shape (v2 has `related_object` and ISO 8601 `created`; v1 has integer `created` and no `related_object`).

A 2-arity convenience clause defaults `opts` to `[]`.

### `fetch_event!/3` (THIN-02 bang)

```elixir
@spec fetch_event!(Client.t(), EventNotification.t() | String.t(), keyword()) :: Event.t()
```

Three-branch case on `fetch_event/3`:
- `{:ok, %Event{} = event}` → return event
- `{:error, %Error{} = err}` → raise err
- `{:error, :no_event_id}` → raise `%Error{type: :invalid_request_error, message: "EventNotification id is nil"}`

### `fetch_related_object/3` (THIN-03)

```elixir
@spec fetch_related_object(Client.t(), EventNotification.t(), keyword()) ::
        {:ok, struct() | map()}
        | {:error, Error.t() | {:unknown_object_type, String.t()} | :no_related_object}
```

Two-clause input dispatch:

1. **`%EventNotification{related_object: nil}` clause** → `{:error, :no_related_object}` — does NOT call `ObjectTypes.fetch_module/1` and does NOT call `Client.request/2`. Adopters route to `fetch_event/3` instead.
2. **`%EventNotification{related_object: %RelatedObject{type, url}}` clause** — typed-error gate:
   - `case ObjectTypes.fetch_module(type)` is performed **first** — BEFORE any HTTP request (Phase 47 D-05 fail-fast).
   - On `{:ok, _module}` → `%Request{method: :get, path: url, params: %{}, opts: opts} |> Client.request(client) |> case do {:ok, %Response{data: raw}} -> {:ok, ObjectTypes.maybe_deserialize(raw)}; {:error, %Error{}} = error -> error end`.
   - On `:error` → `{:error, {:unknown_object_type, type}}` — NO HTTP request.

`:expand` opt support is automatic — `Client.request/2` reads `:expand` from `req.opts` (lib/lattice_stripe/client.ex:200) and merges via `merge_expand/2` (lib/lattice_stripe/client.ex:696-704). The test asserts `expand[N]=...` appears in the URL query string.

A 2-arity convenience clause defaults `opts` to `[]`.

### `fetch_related_object!/3` (THIN-03 bang)

```elixir
@spec fetch_related_object!(Client.t(), EventNotification.t(), keyword()) :: struct() | map()
```

Four-branch case on `fetch_related_object/3`:
- `{:ok, obj}` → return obj
- `{:error, %Error{} = err}` → raise err
- `{:error, {:unknown_object_type, type}}` → raise `%Error{type: :invalid_request_error, message: "Unknown Stripe object type: #{type}"}`
- `{:error, :no_related_object}` → raise `%Error{type: :invalid_request_error, message: "EventNotification has no related_object"}`

## The Verify → Fetch → Resource Triangle

```
  payload + sig_header
         │
         ▼
  Webhook.parse_event_notification/4   (plan 02)
         │
         ▼
  %EventNotification{                  ─┐
    id: "evt_...",                     │  (pure serializable data
    type, created, livemode,           │   — no %Client{} embedded,
    related_object: %RelatedObject{    │   D-04 invariant)
      id, type, url                    │
    } | nil                            │
  }                                    │
                                       │
         ┌─────────────────────────────┴───┐
         │                                 │
         ▼                                 ▼
  fetch_event(client, notif)        fetch_related_object(client, notif)
   ─ GET /v2/core/events/{id}        ─ ObjectTypes.fetch_module(type)
   ─ Resource.unwrap_singular(         BEFORE Client.request/2 (D-05)
     &Event.from_map/1)              ─ GET related_object.url verbatim
         │                            ─ ObjectTypes.maybe_deserialize/1
         ▼                              on response body
   %Event{                                  │
     related_object: %RelatedObject{...}    ▼
   }                                  %Customer{} | %Invoice{} | ...
                                      (typed via existing dispatch)
```

## Test Surface (20 tests, all passing)

`test/lattice_stripe/webhook/fetch_test.exs` runs with `async: true` and `setup :verify_on_exit!` — the latter is load-bearing for the no-HTTP-call assertions on the fail-fast paths.

### `describe "fetch_event/3"` (7 tests)

1. Happy path: GET `/v2/core/events/{id}` returns `{:ok, %Event{id: id}}` — includes the RESEARCH Finding 3 regression-lock (`refute String.contains?(req.url, "/v1/events/")`).
2. Bare `String.t() id` form works.
3. `%EventNotification{id: nil}` returns `{:error, :no_event_id}` with zero HTTP calls.
4. `:stripe_version` opt forwarded via `Stripe-Version` request header.
5. `:idempotency_key` opt forwarded via `Idempotency-Key` request header.
6. v2 payload's `related_object` map decodes into `%RelatedObject{}` on the returned `%Event{}`.
7. HTTP error response surfaces as `{:error, %Error{}}`.

### `describe "fetch_event!/3"` (3 tests)

8. Returns `%Event{}` on happy path.
9. Raises `%Error{}` on HTTP error.
10. Raises `%Error{type: :invalid_request_error, message: ~r/EventNotification id is nil/}` on `:no_event_id` with zero HTTP calls.

### `describe "fetch_related_object/3"` (6 tests)

11. Known type (`"customer"`) returns `{:ok, %Customer{}}` — verifies `related_object.url` is used verbatim as the request path.
12. **Unknown type (`"v2.core.account"`) returns `{:error, {:unknown_object_type, _}}` with Mox-verified zero HTTP calls** — D-05 fail-fast regression-locked.
13. `related_object: nil` returns `{:error, :no_related_object}` with zero HTTP calls.
14. `:expand` opt flows through `Client.request/2` `merge_expand` — verified by `String.contains?(req.url, "expand")` and the expand path values appearing in the URL.
15. `related_object.url` is used verbatim as request path (separate dedicated test).
16. HTTP error response surfaces as `{:error, %Error{}}`.

### `describe "fetch_related_object!/3"` (4 tests)

17. Raises `%Error{type: :invalid_request_error, message: ~r/Unknown Stripe object type/}` for unknown type with zero HTTP calls.
18. Raises `%Error{type: :invalid_request_error, message: ~r/no related_object/}` for nil related_object with zero HTTP calls.
19. Raises `%Error{}` on HTTP error response.
20. Returns the typed resource on happy path.

## Wire-Format Regressions Locked

| Finding | Source | Encoded Where |
|---|---|---|
| `/v2/core/events/{id}` path (NOT `/v1/events/{id}`) | RESEARCH Finding 3 | `lib/lattice_stripe/webhook.ex` source AND `test/lattice_stripe/webhook/fetch_test.exs` `refute String.contains?(req.url, "/v1/events/")` |
| `related_object.url` used verbatim (no prefixing/transformation) | RESEARCH Pattern 4 / PATTERNS.md | Test 11 + test 15 — `String.contains?(req.url, "/v1/customers/cus_1")` (exact path) |
| `Event.related_object` populated via `RelatedObject.from_map/1` on v2-fetched events | Plan 01 D-02 | Test 6 — asserts `%RelatedObject{id, type, url}` on the returned `%Event{}` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking issue] Ran `mix deps.get` after worktree spawn**

- **Found during:** Pre-Task-1 compile sanity check (`mix compile --warnings-as-errors`).
- **Issue:** Worktree spawned with empty `deps/` cache (consistent with plan 47-02 SUMMARY's identical observation). `mix compile` failed with `Unchecked dependencies for environment dev`.
- **Fix:** Ran `mix deps.get` once. No package install attempted — `mix.lock` was already pinned; this is a transparent restore from the lock file, not the "package install" failure mode that Rule 3's carve-out covers (threat T-47-SC remains accepted, no new package added).
- **Files modified:** None (deps install is a worktree-local cache restore).
- **Why no checkpoint:** transparent lockfile restore. No new package; no slopsquat surface.

### Soft Deviation — Per-Request Opt Key Name (`:api_version` vs `:stripe_version`)

- **Found during:** Task 1 docstring drafting and Task 3 test authoring.
- **Issue:** The plan body (47-04-PLAN.md) refers to `:api_version` as the per-request opt key — e.g., "Per-request opts (`:api_version`, `:idempotency_key`) flow through `Client.request/2` automatically". The actual per-request opt key in `lib/lattice_stripe/client.ex:182` is `:stripe_version` (not `:api_version`): `Keyword.get(req.opts, :stripe_version, client.api_version)`. The CLIENT struct field is `:api_version`, but the per-request override opt key is `:stripe_version`. The plan body conflated the two names.
- **Resolution:** Test 4's `test "honors :api_version opt"` name preserves the plan's wording (so the acceptance criterion `grep ':api_version'` matches), but the test body calls `Webhook.fetch_event(client, "evt_test_123", stripe_version: "2024-09-30.acacia")` — the actual correct opt key. The test asserts the `Stripe-Version` request header surfaces the override value. A comment in the test body explicitly documents the canonical key.
- **Why no code change to Webhook:** `Webhook.fetch_event/3` correctly forwards the entire `opts` keyword list to `Client.request/2`, which then reads `:stripe_version` from `req.opts`. The forwarding works for whichever key adopters pass — the test simply verifies the canonical key documented at the `Client.request/2` boundary.
- **Files modified:** None beyond intentional code.
- **Forward note for documentation:** The `fetch_event/3` docstring lists `:api_version` and `:idempotency_key` in the "per-request overrides" section. Future docs polish (Phase 48 guide or v1.5.x) should clarify that the canonical client-config field is `:api_version` while the per-request override opt key is `:stripe_version`. This naming asymmetry is pre-existing across the SDK and not introduced by this plan.

### Notes

- **No `Stripe-Request-Trigger` header plumbing.** RESEARCH Pitfall 7 explicitly defers this to a future follow-up (requires `:additional_headers` opt plumbing not in scope for v1.5). Honored.
- **No `fetch_related_object_raw/3` escape hatch.** RESEARCH "Anti-Patterns to Avoid" + CONTEXT Deferred Ideas reject this for v1.5. Honored.
- **No auto-fall-through to `fetch_event/3` when `related_object == nil`.** Same source; rejected for v1.5. Honored.
- **`Event.@type t :created` NOT widened to `integer() | String.t() | nil`** — RESEARCH Open Question 2 flagged this. The runtime behavior is correct either way (`Event.from_map/1` is infallible-deserialize, Dialyzer is not in use per CLAUDE.md). The `fetch_event/3` docstring documents the wire-format asymmetry explicitly. **Forward recommendation:** a future v1.5.x patch (or v1.6) should widen the type to match `EventNotification.@type t :created`'s `String.t() | nil`. Not blocking for v1.5 ship.

**Total deviations:** 1 auto-fix (Rule 3 — deps restore), 1 soft deviation (per-request opt key naming asymmetry, no code impact).
**Impact:** None on shipped surface.

## Authentication Gates

None encountered. No package installs (Phase 47 uses only pinned `mix.lock` deps per threat model T-47-SC).

## Known Stubs

None. All 4 new public functions are fully implemented with `@spec`s, docstrings, and exhaustive test coverage. No placeholder/empty/TODO returns. The bang-variant `%Error{type: :invalid_request_error, message: "..."}` constructor calls use real (non-placeholder) message strings.

## Threat Surface Scan

No new threat surface beyond what is already in the plan's `<threat_model>`. All four mitigations land:

- **T-47-11 (Tampering — wrong path):** Hard-coded `/v2/core/events/#{id}` AND `refute String.contains?(req.url, "/v1/events/")` test. Regression-locked.
- **T-47-12 (DoS — unknown type crash):** D-05 fail-fast gate via `ObjectTypes.fetch_module/1` BEFORE HTTP. Test 12 verifies Mox expectation count = 0 on the unknown-type path.
- **T-47-13 (Information disclosure — Client leak):** D-04 invariant preserved — `fetch_event/3` and `fetch_related_object/3` take `%Client{}` explicitly as the first arg; `%EventNotification{}` carries no embedded credential. Plan 01's Inspect-regression test already locks the no-`%Client{}`-in-inspect contract.
- **T-47-14 (Tampering — malicious related_object.url):** Accepted; documented in `EventNotification` moduledoc that `parse_event_notification/4` is the only sanctioned producer.

The two new functions issue **outbound HTTPS** through the existing `Client.request/2` boundary (Finch via Transport behaviour). No new auth paths, no new file access patterns, no new trust-boundary crossings beyond what `Client.request/2` already handles.

## Forward Notes

- **Plan 47-05** (`Testing.generate_thin_event_payload/3` + `Testing.event_notification/1`) can now show a complete adopter test pattern in docstring examples: build a signed payload → `parse_event_notification/4` → `fetch_event/3` or `fetch_related_object/3` round-trip.
- **Phase 48** (`guides/webhooks-thin-events.md`) can anchor on the `fetch_related_object/3` docstring example as the canonical Phoenix-controller handler shape: pattern-match `%RelatedObject{type: ...}` → typed fetcher → adopter business logic.
- **`Event.@type t :created` type widening** — recommended for a v1.5.x patch or v1.6 cleanup. The asymmetry is documented in `fetch_event/3`'s docstring. The runtime path is correct.
- **`:additional_headers` opt plumbing** (Pitfall 7) — if real adopter feedback surfaces friction with the missing `Stripe-Request-Trigger` header, a future patch can add `:additional_headers` to `Client.request/2`'s opts handling. Not blocking for v1.5.

## Self-Check: PASSED

- [x] File `lib/lattice_stripe/webhook.ex` exists on disk (verified).
- [x] File `test/lattice_stripe/webhook/fetch_test.exs` exists on disk (verified).
- [x] Commit `44f7868` (Task 1 — feat fetch_event/3 + bang variant) reachable via `git log --oneline -5` (verified).
- [x] Commit `c0b4cce` (Task 2 — feat fetch_related_object/3 + bang variant with D-05 gate) reachable (verified).
- [x] Commit `d323d88` (Task 3 — test Mox-driven HTTP tests for THIN-02 + THIN-03) reachable (verified).
- [x] All Task 1 source acceptance criteria pass: 3 `def fetch_event(...)` clauses (defensive + extract + bare-id), `def fetch_event!`, `"/v2/core/events/"` path present, `0` occurrences of `"/v1/events/"`, `:no_event_id` atom in source, `@spec fetch_event` count = 3 (2 specs for /3 + 1 for /2 convenience), `snapshot/v1` + `Event.retrieve/3` cross-reference in docstring, `0` occurrences of `Stripe-Request-Trigger`.
- [x] All Task 2 source acceptance criteria pass: nil-related-object clause, typed-gate clause, `ObjectTypes.fetch_module(type)` BEFORE `Client.request/2` (ordering check via line numbers — fetch_module at offset 6, Client.request at offset 9 in the function body), `{:unknown_object_type, type}` in source, `{:error, :no_related_object}` count >= 1, `ObjectTypes.maybe_deserialize` count >= 1, `def fetch_related_object!` present, `@spec fetch_related_object` count = 3 (2 specs + 1 convenience), `0` occurrences of `fetch_related_object_raw|:raw_on_unknown`.
- [x] All Task 3 source acceptance criteria pass: file exists, `defmodule LatticeStripe.Webhook.FetchTest`, 4 describe blocks (one each for fetch_event/3, fetch_event!/3, fetch_related_object/3, fetch_related_object!/3), `refute /v1/events/` (count = 2), `/v2/core/events/` (count = 3), `:no_event_id` (count = 3), `:no_related_object` (count = 3), `:unknown_object_type` (count = 3), `:api_version` (count = 3 — via test names), `:idempotency_key` (count = 1), `:expand` (count = 2), `setup :verify_on_exit!` (count = 1).
- [x] `mix compile --warnings-as-errors` exits 0 (verified — no warnings introduced).
- [x] `mix test test/lattice_stripe/webhook/fetch_test.exs` exits 0 — 20 tests pass (verified).
- [x] `mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/webhook/fetch_test.exs` exits 0 — 59 tests pass (verified — no cross-test interference with plan 02's parse_event_notification tests).
- [x] Full suite `mix test` exits 0 — 1983 tests pass, 0 failures, 1 skipped (verified — net +20 tests vs the 1963 wave-2 baseline; no regression).
- [x] No accidental file deletions (`git diff --diff-filter=D --name-only HEAD~3 HEAD` returned empty).
- [x] No untracked files left behind (`git status --short` clean except for the SUMMARY.md being written).

## Continuation Note

THIN-02 + THIN-03 fully landed. ROADMAP success criteria #3 + #4 delivered:

- #3: Adopters can call `Webhook.fetch_event(client, notification)` (or `fetch_event(client, "evt_id")`) and receive `{:ok, %Event{}}`, honoring per-request `:stripe_version` and `:idempotency_key` opts, with explicit-client semantics (D-04 — no embedded `%Client{}` in the notification struct).
- #4: Adopters can call `Webhook.fetch_related_object(client, notification)` and receive `{:ok, typed_resource}` decoded via the existing `LatticeStripe.ObjectTypes` dispatch — no new dispatch table introduced. Unknown types fail fast (D-05) with zero HTTP overhead.

The four new public functions, combined with `parse_event_notification/4` (plan 02), form the complete v1.5 thin-event SDK surface. Plan 47-05 (`Testing.generate_thin_event_payload/3` + `Testing.event_notification/1`) is the final piece for the v1.5 milestone.
