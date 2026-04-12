---
phase: 01-transport-client-configuration
plan: 05
subsystem: api
tags: [elixir, stripe, http-client, telemetry, mox, finch]

# Dependency graph
requires:
  - phase: 01-transport-client-configuration plan 01
    provides: Project scaffold with Mox mock definitions (MockTransport, MockJson)
  - phase: 01-transport-client-configuration plan 02
    provides: Transport behaviour with request/1 callback
  - phase: 01-transport-client-configuration plan 03
    provides: FormEncoder.encode/1, Error.from_response/3, Request struct
  - phase: 01-transport-client-configuration plan 04
    provides: Config.validate!/1, Config.validate/1 with NimbleOptions schema
provides:
  - LatticeStripe.Client struct (plain struct, no GenServer, no global state)
  - Client.new!/1 — creates validated client, raises on invalid opts
  - Client.new/1 — creates validated client, returns {:ok, client} | {:error, error}
  - Client.request/2 — dispatches Request through transport with full headers/encoding/decoding/telemetry
affects: [all phases using Client.request/2 for Stripe API calls, Phase 2 retry logic, Phase 9 integration tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Client is a plain struct with @enforce_keys for required fields — no GenServer, no application config"
    - ":telemetry.span/3 wraps transport call with telemetry_enabled flag for opt-out"
    - "@version module attribute captures Mix.Project version at compile time — never called at runtime"
    - "Per-request opts override client defaults via Keyword.get with client field as default"
    - "Transport contract accepts plain map, returns {:ok, response_map} | {:error, reason}"

key-files:
  created:
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/client_test.exs
  modified: []

key-decisions:
  - "telemetry_enabled flag on client allows disabling telemetry per-client (useful in tests and batch jobs)"
  - "@version module attribute used instead of Mix.Project.config() at runtime (Mix not available in production releases)"
  - "Per-request opts use Keyword.get with client field as default, enabling clean opt-by-opt override without merging structs"
  - "Stripe-Account header only added when non-nil (client default or per-request override)"

patterns-established:
  - "Pattern: Client struct with @enforce_keys [:api_key, :finch] validates required fields at struct creation"
  - "Pattern: Mox tests use test_client/1 helper with transport: MockTransport and telemetry_enabled: false by default"
  - "Pattern: Telemetry tests use :telemetry.attach_many/4 with on_exit handler detach"

requirements-completed: [CONF-03, CONF-04, CONF-05, TRNS-05]

# Metrics
duration: 5min
completed: 2026-04-01
---

# Phase 1 Plan 05: Client Module Summary

**LatticeStripe.Client struct with new!/1, new/1, and request/2 — ties all Phase 1 modules together with headers, form encoding, JSON decoding, error mapping, and telemetry span**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-01T05:14:34Z
- **Completed:** 2026-04-01T05:18:58Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Implemented `LatticeStripe.Client` as a plain struct (no GenServer, no global state) with `@enforce_keys [:api_key, :finch]`
- `request/2` builds all required Stripe headers (Authorization Bearer, Stripe-Version, User-Agent, Content-Type, Stripe-Account, Idempotency-Key), encodes POST bodies via FormEncoder, appends GET query strings, decodes JSON via configured codec, and maps errors via Error.from_response/3
- 28 comprehensive Mox-based tests covering constructors, all headers, encoding, response handling (200/400/401/429/connection errors), per-request overrides (api_key/stripe_account/timeout/stripe_version/idempotency_key/expand), telemetry on/off, and transport swapping — all passing with async: true

## Task Commits

Each task was committed atomically:

1. **Task 1: Client struct with new!/1, new/1 constructors** - `8c384d8` (feat)
2. **Task 2: Comprehensive Mox-based client tests** - `a0b70e0` (test)

**Plan metadata:** (added in final commit)

## Files Created/Modified

- `lib/lattice_stripe/client.ex` - Client struct, new!/1, new/1, request/2 with full header building, encoding, decoding, error handling, telemetry
- `test/lattice_stripe/client_test.exs` - 28 Mox-based tests in 7 describe blocks

## Decisions Made

- `telemetry_enabled` flag allows disabling telemetry per-client; tests default to `false` for cleaner output
- `@version Mix.Project.config()[:version]` captured as module attribute at compile time; `Mix.Project` never called at runtime (not available in production releases)
- Per-request opts override client defaults via `Keyword.get(req.opts, :key, client.default)` — clean one-opt-at-a-time override without struct merging
- `Stripe-Account` and `Idempotency-Key` headers are only added when non-nil

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed moduledoc code example using undefined variable `order_id`**
- **Found during:** Task 1 (compile step)
- **Issue:** Example in `@moduledoc` used string interpolation with `order_id` which is not in scope, causing compile error
- **Fix:** Replaced with literal string `"charge-unique-key-123"` in example
- **Files modified:** lib/lattice_stripe/client.ex
- **Verification:** `mix compile --warnings-as-errors` exits 0
- **Committed in:** 8c384d8 (Task 1 commit)

**2. [Rule 1 - Bug] Removed default argument from private `error_response/3` helper**
- **Found during:** Task 2 (test run)
- **Issue:** Elixir warned that default value for `message` argument in private `error_response/3` was never used (all callers pass explicit message)
- **Fix:** Removed the default value `\\ "An error occurred"` since all callers provide the argument
- **Files modified:** test/lattice_stripe/client_test.exs
- **Verification:** `mix test test/lattice_stripe/client_test.exs` passes with no warnings
- **Committed in:** a0b70e0 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug)
**Impact on plan:** Minor compile-time fixes, no scope creep. Plan executed as specified.

## Issues Encountered

- Pre-existing flaky test in `LatticeStripe.Transport.FinchTest` (`test "exports request/1"`) fails intermittently during parallel async test runs — not caused by Plan 05 changes. Logged to `deferred-items.md` in phase directory.
- Pre-existing Credo `Enum.map_join/3` suggestions in `lib/lattice_stripe/form_encoder.ex` (from Plan 03) remain — logged to `deferred-items.md` as out of scope.

## Next Phase Readiness

- Phase 1 is complete: Transport behaviour, Request struct, Error, FormEncoder, Config, Finch transport, and Client are all implemented and tested (85 tests passing)
- Phase 2 (retry logic) can build on `Client.request/2` since `max_retries` is already stored in the client struct
- All Phase 1 success criteria from ROADMAP.md are verified:
  1. Client creation with config validation
  2. Raw authenticated HTTP requests through Finch transport
  3. Transport swapping via behaviour (proven with Mox)
  4. Multiple independent clients
  5. Form-encoded request bodies

---
*Phase: 01-transport-client-configuration*
*Completed: 2026-04-01*

## Self-Check: PASSED

- lib/lattice_stripe/client.ex: FOUND
- test/lattice_stripe/client_test.exs: FOUND
- .planning/phases/01-transport-client-configuration/01-05-SUMMARY.md: FOUND
- Commit 8c384d8 (feat: client struct): FOUND
- Commit a0b70e0 (test: 28 client tests): FOUND
