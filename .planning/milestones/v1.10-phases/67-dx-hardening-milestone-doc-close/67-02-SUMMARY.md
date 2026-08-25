---
phase: 67-dx-hardening-milestone-doc-close
plan: "02"
subsystem: webhook
tags: [elixir, plug, webhook, hmac, raw-body, testing]
requires:
  - phase: 67-dx-hardening-milestone-doc-close
    provides: Existing optional Plug boundary and Webhook.Plug signature-verification route
provides:
  - Exact ordered accumulation of Plug :more and :ok body chunks under conn.private[:raw_body]
  - Native Plug error passthrough and end-to-end typed-event verification of the completed raw body
affects: [67-03, webhook-api-surface, api-surface-lock]
tech-stack:
  added: []
  patterns: [fixed-key connection-private raw-body accumulation, forced multi-call Plug seam]
key-files:
  created: []
  modified:
    - lib/lattice_stripe/webhook/cache_body_reader.ex
    - test/lattice_stripe/webhook/plug_test.exs
key-decisions:
  - "Keep all accumulated request bytes in the existing fixed conn.private[:raw_body] key; no configurable or external storage path is introduced."
  - "Return Plug.Conn.read_body/2 tags and current chunks unchanged while separately retaining the complete byte stream for HMAC verification."
patterns-established:
  - "Webhook body-reader tests force Plug's :more → :ok boundary and then pass the resulting connection to Webhook.Plug."
requirements-completed: []
coverage:
  - id: D-06
    description: "Successive :more and terminal :ok chunks retain original byte order and preserve Plug's current tuple tag and chunk."
    requirement: DX-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/webhook/plug_test.exs#CacheBodyReader accumulates every read chunk in order while preserving Plug return tuples"
        status: pass
    human_judgment: false
  - id: D-07
    description: "Only the fixed raw_body private key retains the completed binary; unchanged read errors and the existing Webhook.Plug HMAC route remain reachable."
    requirement: DX-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/webhook/plug_test.exs#CacheBodyReader preserves Plug read errors unchanged"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/webhook/plug_test.exs#CacheBodyReader Webhook.Plug verifies the complete CacheBodyReader body"
        status: pass
    human_judgment: false
duration: 3min
completed: 2026-08-25
status: complete
---

# Phase 67 Plan 02: Exact Webhook Body Accumulation Summary

**Webhook raw-body caching now accumulates every Plug chunk in byte order, so signature verification receives the exact complete request body.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-25T17:53:00Z
- **Completed:** 2026-08-25T17:56:00Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Replaced per-chunk overwrites with ordered append-only accumulation under the fixed `conn.private[:raw_body]` key.
- Locked the forced `"abc"` then `"def"` Plug sequence, including native return tags and the final `"abcdef"` raw body.
- Proved native `{:error, :closed}` passthrough and passed a completed multi-chunk cached body through the existing `Webhook.Plug` signature-verification route.

## Task Commits

1. **Task 1 RED: multi-chunk regression** — `a9e2da7` (`test`)
2. **Task 1 GREEN: ordered body accumulation** — `df3e32c` (`fix`)
3. **Task 2: error and Webhook.Plug reachability proofs** — `44592bc` (`test`)

## Files Created/Modified

- `lib/lattice_stripe/webhook/cache_body_reader.ex` — Appends every successful Plug body chunk under the fixed raw-body key while retaining native tuples and error passthrough.
- `test/lattice_stripe/webhook/plug_test.exs` — Forced ordered chunk, error-adapter, and completed-body signature-verification regression tests.

## Decisions Made

- Kept the optional `if Code.ensure_loaded?(Plug)` compile boundary intact.
- Kept the connection-lifetime raw binary under one fixed private key; no storage configuration, multipart behavior, or alternate webhook consumer path was added.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - Plug's existing test adapter exercises the required native boundary.

## Next Phase Readiness

The corrected accumulator is ready for Plan 67-03 to publish and semver-lock `CacheBodyReader` without preserving the former byte-loss behavior.

## Self-Check: PASSED
