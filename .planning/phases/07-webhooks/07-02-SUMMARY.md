---
phase: 07-webhooks
plan: "02"
subsystem: webhooks
tags: [plug, webhook, signature-verification, raw-body, nimbleoptions, cache-body-reader]
dependency_graph:
  requires: ["07-01"]
  provides: ["WHBK-04", "WHBK-05"]
  affects: ["lib/lattice_stripe/webhook/plug.ex", "lib/lattice_stripe/webhook/cache_body_reader.ex"]
tech_stack:
  added: []
  patterns:
    - "Code.ensure_loaded?(Plug) guard for optional Plug dependency"
    - "NimbleOptions.new! schema validated at init/1 time"
    - "Path matching via path_info pin in Plug.call/2 clauses"
    - "MFA and zero-arity function secret resolution at call time"
    - "Two-mode Plug: pass-through (assigns event) and handler (dispatches + HTTP response)"
key_files:
  created:
    - lib/lattice_stripe/webhook/cache_body_reader.ex
    - lib/lattice_stripe/webhook/plug.ex
    - test/lattice_stripe/webhook/plug_test.exs
  modified:
    - lib/lattice_stripe/webhook/plug.ex (formatting fix post-compile)
decisions:
  - "plug.ex uses four call/2 clauses ordered: POST+path match, POST+no-path, non-POST+path match, non-POST+no-path, fallthrough — pattern matching is the dispatch mechanism"
  - "dispatch_result/2 uses separate function clauses per return type rather than nested case — cleaner and avoids catch-all that would hide bugs"
  - "CacheBodyReader handles :more tuple for chunked bodies (stashes partial body), consistent with Plug.Conn.read_body semantics"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-03"
  tasks_completed: 2
  files_changed: 3
---

# Phase 07 Plan 02: Webhook Plug and CacheBodyReader Summary

**One-liner:** Phoenix Plug for webhook signature verification with two operation modes (handler dispatch / pass-through), at: path matching, MFA secret resolution, and CacheBodyReader for Plug.Parsers raw body preservation.

## What Was Built

### LatticeStripe.Webhook.CacheBodyReader

Drop-in `Plug.Parsers` body reader that stashes the raw request bytes in `conn.private[:raw_body]` before returning. Solves the fundamental problem that `Plug.Parsers` consumes the body and makes HMAC verification impossible. Wrapped in `Code.ensure_loaded?(Plug)` so the module only exists when Plug is available.

### LatticeStripe.Webhook.Plug

Full-featured Plug with:

- **NimbleOptions validation** at `init/1` time — clear errors for missing `:secret`, invalid `:tolerance`
- **Two operation modes:**
  - Pass-through: assigns `conn.assigns.stripe_event` and continues pipeline (no handler configured)
  - Handler mode: calls `handler.handle_event/1`, maps `:ok`/`{:ok,_}` to 200, `:error`/`{:error,_}` to 400
- **Path matching** via `at:` option: four ordered `call/2` clauses handle POST+match, POST+no-path, non-POST+match (405), fallthrough
- **MFA secret resolution:** `{Mod, :fun, [args]}`, zero-arity functions, strings, and lists all supported at call time
- **Raw body reading:** checks `conn.private[:raw_body]` (CacheBodyReader path), falls back to `Plug.Conn.read_body/2` (mount-before-parsers path)
- **405 Method Not Allowed** with `Allow: POST` header for non-POST to matched path

### Tests (32 tests, all passing)

Covers: `init/1` validation, no-handler mode, handler mode (all return types including raise and bad return), path matching, all three secret resolution strategies, multi-secret lists, CacheBodyReader, and the cached-body scenario.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 08eed78 | CacheBodyReader and Webhook.Plug implementation |
| Task 2 | e10f2f4 | 32 plug integration tests (all passing) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Formatting fix on plug.ex**
- **Found during:** Task 2 verification (`mix format --check-formatted`)
- **Issue:** Long doc string and multi-pattern `call/2` clause exceeded 98-char line limit
- **Fix:** Applied `mix format` to reformat the affected lines
- **Files modified:** `lib/lattice_stripe/webhook/plug.ex`
- **Commit:** e10f2f4 (included in Task 2 commit)

## Known Stubs

None. All functionality is fully wired.

## Self-Check: PASSED

Files exist:
- FOUND: lib/lattice_stripe/webhook/cache_body_reader.ex
- FOUND: lib/lattice_stripe/webhook/plug.ex
- FOUND: test/lattice_stripe/webhook/plug_test.exs

Commits exist:
- FOUND: 08eed78
- FOUND: e10f2f4

Full test suite: 78 tests, 0 failures (event + webhook + plug)
