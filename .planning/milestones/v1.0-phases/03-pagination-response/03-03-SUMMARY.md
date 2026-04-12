---
phase: 03-pagination-response
plan: 03
subsystem: api
tags: [elixir, streams, pagination, stripe, cursor, search]

# Dependency graph
requires:
  - phase: 03-pagination-response-01
    provides: List struct with _params/_opts fields and from_json/3
  - phase: 03-pagination-response-02
    provides: Client.request/2 returning {:ok, %Response{data: %List{}}}

provides:
  - "stream!/2 on LatticeStripe.List — lazy auto-pagination from client + request using Stream.resource/3"
  - "stream/2 on LatticeStripe.List — lazy stream from existing List, re-emits first page then fetches more"
  - "_first_id and _last_id fields on List struct for cursor tracking after buffer consumption"
  - "Cursor, backward, and search pagination modes auto-detected and handled"
  - "Per-request opts (stripe_account, api_key, stripe_version, timeout) forwarded across pages"
  - "Idempotency key excluded from page fetches (GET requests)"

affects: [04-customers-payment-intents, 05-resource-modules, 09-integration-testing, 10-documentation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stream.resource/3 for lazy HTTP pagination — start_fun fetches first page, next_fun is state machine, cleanup is noop"
    - "Cursor IDs (_first_id/_last_id) extracted in from_json/3 before buffer can be consumed"
    - "Three-way cond in build_next_page_request: search (next_page token), backward (ending_before -> _first_id), forward (starting_after -> _last_id)"
    - "Opts carry forward via Keyword.delete(list._opts, :idempotency_key) to strip non-GET fields"

key-files:
  created: []
  modified:
    - lib/lattice_stripe/list.ex
    - test/lattice_stripe/list_test.exs

key-decisions:
  - "stream!/2 uses Stream.resource/3 start_fun to make the initial fetch synchronously before stream evaluation (avoids lazy first-page fetch)"
  - "_first_id and _last_id computed in from_json/3 before data buffer consumption — required because next_item/2 drains data before needing cursor for next page"
  - "build_next_page_request uses cond for priority: search_result + next_page > ending_before in _params > default forward"
  - "Idempotency key stripped via Keyword.delete not set to nil — clean opts list for downstream Client.request/2"

patterns-established:
  - "Stream state machine pattern: three-clause next_item/2 — halt on empty+done, recurse-fetch on empty+more, emit on data present"
  - "Private helpers fetch_page!/2 and fetch_next_page!/2 separate concerns: initial fetch vs continuation fetch"

requirements-completed: [PAGE-03, PAGE-04]

# Metrics
duration: 3min
completed: 2026-04-02
---

# Phase 03 Plan 03: Auto-Pagination Streaming Summary

**Lazy Stream.resource/3 auto-pagination for both from-scratch (stream!/2) and from-existing-list (stream/2) with cursor, backward, and search pagination modes**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02T15:13:07Z
- **Completed:** 2026-04-02T15:16:15Z
- **Tasks:** 1 (TDD)
- **Files modified:** 2

## Accomplishments
- `stream!/2` creates a lazy `Stream.resource/3` from a client + request, making the initial fetch in the start function and lazily fetching subsequent pages as items are consumed
- `stream/2` creates a lazy stream from an existing `%List{}`, re-emitting page-1 items then fetching additional pages when `has_more: true`
- Three pagination modes handled: forward cursor (`starting_after` from `_last_id`), backward cursor (`ending_before` from `_first_id`), and search page tokens (`page` from `next_page`)
- `_first_id` and `_last_id` computed in `from_json/3` before the data buffer can be consumed by the stream state machine
- Per-request opts (stripe_account, stripe_version, timeout, expand) forwarded across page fetches; `idempotency_key` stripped
- 235 tests passing (42 in list_test.exs, up from 213 total before this plan)

## Task Commits

1. **Task 1: Implement stream!/2 and stream/2 with Stream.resource/3** - `dc2b01a` (feat)

**Plan metadata:** (docs commit)

_Note: TDD — tests written first (RED), then implementation (GREEN)_

## Files Created/Modified
- `lib/lattice_stripe/list.ex` — Added stream!/2, stream/2, next_item/2, fetch_page!/2, fetch_next_page!/2, build_next_page_request/1, _first_id/_last_id struct fields, first_item_id/1, last_item_id/1
- `test/lattice_stripe/list_test.exs` — Added 22 streaming tests: single-page, multi-page, laziness, error raising, backward pagination, search pagination, opts forwarding, from-existing-list variants

## Decisions Made
- `_first_id` and `_last_id` extracted at `from_json/3` time (not at stream consumption time) because when `next_item/2` hits `data: []` and needs a cursor, the buffer has already been fully drained. The IDs must be captured while `data` is still complete.
- `stream!/2` start_fun makes the first API call synchronously (inside the `Stream.resource/3` start function, which runs when evaluation begins). This ensures the stream truly is lazy — no fetch happens until the stream is evaluated.
- Backward pagination detection via `Map.has_key?(list._params, "ending_before")` on the original params, not the current data state.

## Deviations from Plan

None — plan executed exactly as written. The plan's implementation notes were followed closely, including the cursor ID correction note in step 7.

## Issues Encountered

None.

## Known Stubs

None — all streaming functionality is fully wired. The functions use real Client.request/2 calls through MockTransport in tests and through Finch in production.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- Phase 4 resource modules (Customers, PaymentIntents) can build ergonomic `stream/2` wrappers on top of `List.stream!/2`
- Pattern: `Customer.stream(client, opts)` → builds `%Request{}` → calls `List.stream!(client, req)`
- All pagination modes tested and verified via Mox expect counts enforcing laziness
