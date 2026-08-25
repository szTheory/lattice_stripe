---
phase: 67-dx-hardening-milestone-doc-close
plan: "03"
subsystem: webhook-api
tags: [elixir, plug, phoenix, webhooks, exdoc, semver]
requires:
  - phase: 67-02
    provides: "Exact multi-chunk CacheBodyReader accumulation and Webhook.Plug integration proof"
  - phase: 67-01
    provides: "Reviewed additive Error public-surface entries carried into the same API lock refresh"
provides:
  - "Conditionally public LatticeStripe.Webhook.CacheBodyReader and semver-locked read_body/2"
  - "Canonical Plug-before-Parsers guidance plus a bounded advanced parser body-reader route"
  - "Webhooks ExDoc grouping and docs-truth regression locks for safe CacheBodyReader use"
affects: [hexdocs, api-stability, webhook-integration, phase-67-plan-05]
tech-stack:
  added: []
  patterns:
    - "Optional framework integrations state conditional availability in public docs while retaining their compile guard."
    - "Advanced raw-body retention guidance names connection-lifetime copies, PII/no-log boundaries, route scope, and multipart exclusion."
key-files:
  created: []
  modified:
    - lib/lattice_stripe/webhook/cache_body_reader.ex
    - lib/lattice_stripe/webhook/plug.ex
    - guides/webhooks.md
    - guides/api_stability.md
    - test/lattice_stripe/docs_truth_test.exs
    - priv/api/current.txt
key-decisions:
  - "Confirmed the pre-approved conditional CacheBodyReader.read_body/2 contract without reopening naming, storage, availability, or return-shape decisions."
  - "Plug-before-Parsers remains canonical; CacheBodyReader is a narrow advanced, non-multipart alternative when endpoint ordering cannot change."
  - "The API lock accepts exactly CacheBodyReader's module and read_body/2 alongside the already-landed 67-01 Error additions."
coverage:
  - id: D-08
    description: "CacheBodyReader is conditionally documented, grouped with Webhooks, and positioned as the bounded advanced route behind the canonical endpoint ordering."
    requirement: DX-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#CacheBodyReader is conditionally public and grouped with Webhooks"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#advanced CacheBodyReader guide keeps the retention contract bounded"
        status: pass
      - kind: command
        ref: "mix docs --warnings-as-errors (pass)"
        status: pass
    human_judgment: false
  - id: D-09
    description: "The public CacheBodyReader module and read_body/2 are locked in the reviewed API snapshot without unrelated additions."
    requirement: DX-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/api_surface_lock_test.exs#the compiled public API surface matches the committed lock"
        status: pass
      - kind: command
        ref: "mix lattice_stripe.api_surface --check (pass, 3463 entries)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/webhook/plug_test.exs#CacheBodyReader accumulates every read chunk in order while preserving Plug return tuples"
        status: pass
    human_judgment: false
metrics:
  duration: 3min
  completed: 2026-08-25
status: complete
---

# Phase 67 Plan 03: CacheBodyReader Publication Summary

**CacheBodyReader is now a conditionally available, semver-locked webhook helper with Plug-before-Parsers preserved as the safe Phoenix default.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-25T18:03:00Z
- **Completed:** 2026-08-25T18:06:31Z
- **Tasks:** 3/3 (including the recorded locked-contract confirmation)
- **Files modified:** 6

## Accomplishments

- Confirmed the previously approved public contract: only `LatticeStripe.Webhook.CacheBodyReader.read_body/2`, under the existing optional-Plug guard and fixed `conn.private[:raw_body]` key.
- Replaced the hidden moduledoc with terminal exact-body semantics, current-chunk return behavior, conditional availability, and retention limits.
- Kept `LatticeStripe.Webhook.Plug` before `Plug.Parsers` as the canonical Phoenix route; documented the parser body reader as a narrow advanced alternative only when ordering cannot change.
- Added bounded DocsTruth checks for public docs, Webhooks placement, exact terminal-body language, PII/no-log protection, route scope, and multipart exclusion.
- Reviewed and regenerated the API snapshot: exactly six additions, comprising four already-landed Error entries and CacheBodyReader's module plus `read_body/2`.

## Verification

- `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/webhook/plug_test.exs --warnings-as-errors` — pass (108 tests).
- `mix docs --warnings-as-errors` — pass.
- `mix lattice_stripe.api_surface --check` — pass (3463 entries).
- `mix format --check-formatted` — pass.

## Task Commits

1. **Task 2: Document the conditional public contract and safe advanced route** — `353b5b9` (`feat`)
2. **Task 3 RED: lock CacheBodyReader publication** — `89f79d2` (`test`)
3. **Task 3 GREEN: lock CacheBodyReader public API** — `9bebd70` (`feat`)

## Files Created/Modified

- `lib/lattice_stripe/webhook/cache_body_reader.ex` — Public conditional Plug contract, exact terminal-body semantics, and retention boundaries.
- `lib/lattice_stripe/webhook/plug.ex` — Canonical mounting route and bounded advanced reader guidance.
- `guides/webhooks.md` — Safe Phoenix integration guidance for the advanced non-multipart route.
- `guides/api_stability.md` — Removes CacheBodyReader from internal exclusions.
- `test/lattice_stripe/docs_truth_test.exs` — Grouping and safety-regression assertions.
- `priv/api/current.txt` — Generated semver lock entries.

## Decisions Made

- Auto-confirmed `confirm-locked-reader`: the existing D-07/D-09 approval is recorded, not reopened.
- No configurable storage, alternate private key, disk spooling, multipart support, global retention promise, or alternate webhook API was added.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. This plan adds no endpoint, authentication, file-access, or schema boundary; its documentation explicitly constrains the existing parser-level retention boundary.

## User Setup Required

None.

## Next Phase Readiness

Plan 67-05 can rely on a public, ExDoc-grouped, semver-locked CacheBodyReader contract and its executable safety guidance.

## Self-Check: PASSED

- Found all six planned artifact files and this summary on disk.
- Found task commits `353b5b9`, `89f79d2`, and `9bebd70` in repository history.
