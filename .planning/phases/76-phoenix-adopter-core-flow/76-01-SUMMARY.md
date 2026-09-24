---
phase: 76-phoenix-adopter-core-flow
plan: 01
subsystem: adopter-integration
tags: [phoenix, adopter, checkout, webhooks, integration-test]
requires: [75-typed-contract-updates]
provides:
  - "Test-only Phoenix host proving local path dependency setup and supervised SDK use"
  - "Synthetic subscription Checkout and signed webhook integration proof"
affects: [77-adopter-edge-profiles-and-ci]
actuals:
  tokens: 30000
  tasks: 2
  commits: 4
tech-stack:
  added: [Phoenix 1.8, Plug, Mox]
  patterns: [isolated nested Mix adopter, ConnTest through supervised Endpoint, explicit Mox transport, raw-body webhook verification]
key-files:
  created:
    - test_apps/phoenix_adopter/mix.exs
    - test_apps/phoenix_adopter/mix.lock
    - test_apps/phoenix_adopter/config/config.exs
    - test_apps/phoenix_adopter/config/dev.exs
    - test_apps/phoenix_adopter/config/test.exs
    - test_apps/phoenix_adopter/lib/phoenix_adopter.ex
    - test_apps/phoenix_adopter/test/test_helper.exs
    - test_apps/phoenix_adopter/test/core_flow_test.exs
    - test_apps/phoenix_adopter/README.md
  modified: []
key-decisions:
  - "Keep Phoenix and Mox scoped to the adopter host; the SDK runtime dependency list remains unchanged."
  - "Use Phoenix ConnTest with a supervised Endpoint and the SDK's default Finch child; inject Mox transport for the Checkout request."
  - "Mount webhook verification before Plug.Parsers and test rejection when the signed body is modified."
  - "Keep the harness synthetic-only and explicitly avoid claims about live delivery, durable handling, or duplicate processing."
patterns-established:
  - "A host-boundary example should exercise the consumer's real Plug pipeline while substituting only the outbound Stripe transport."
requirements-completed: [ADOPT-01, ADOPT-02]
coverage:
  - id: ADOPT-01
    description: "A Phoenix adopter uses the checked-out SDK through a separate path dependency and starts its Endpoint with the SDK's single Finch pool."
    requirement: ADOPT-01
    verification:
      - kind: integration
        ref: "cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test — 9 tests, 0 failures; host boots with checked-out dependency"
        status: pass
    human_judgment: false
  - id: ADOPT-02
    description: "A synthetic subscription Checkout returns a typed Session and the Phoenix webhook Plug dispatches a valid signed Event while rejecting a modified body."
    requirement: ADOPT-02
    verification:
      - kind: integration
        ref: "cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test — 9 tests, 0 failures; subscription checkout and signed completion event cross the host boundary; modified webhook body is rejected before handler dispatch"
        status: pass
    human_judgment: false
duration: 1h
completed: 2026-09-24
status: complete
---

# Phase 76: Phoenix Adopter Core Flow Summary

Added an isolated Phoenix host app that consumes the checked-out LatticeStripe SDK, exercises subscription Checkout through an explicit synthetic Mox transport, and verifies an unchanged signed webhook body at the actual Phoenix Endpoint boundary. A tampered body returns 400 without handler dispatch.

## Accomplishments

- Added an independent nested Mix project and lockfile; Phoenix, Plug, and Mox remain out of the SDK runtime dependency surface.
- Proved the host Endpoint and the SDK-owned Finch process are supervised, with no duplicate Finch pool.
- Exercised Checkout request encoding, typed `Checkout.Session` decoding, raw webhook signature verification, and typed `Event` delivery.
- Documented the reproducible command, local path dependency, synthetic-only boundary, and asynchronous webhook confirmation semantics.
- Kept CI workflow changes, live Stripe calls, databases, durable billing state, and UI out of scope.

## Verification Evidence

- `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test` — 9 tests, 0 failures (rerun during Phase 76 verification on 2026-09-24).
- `mix ci` — 2,462 tests, 0 failures, 1 skipped, 203 excluded; Credo and public API/version checks passed.
- `mix format` was run against the adopter app's Mix, config, source, and test files. The app does not define a standalone `.formatter.exs`, so the explicit file patterns were supplied.

## Deviations and Issues

- The nested Phoenix config imports environment-specific files; minimal development and test configuration files were therefore added under `test_apps/phoenix_adopter/config/` beyond the original file list.
- The GSD executor could not write Git metadata inside its restricted worktree. GSD's commit and worktree cleanup commands performed the commit and manifest-scoped merge after review.
- The first root CI attempt in the isolated worktree lacked the SDK dependency checkout. Root `mix ci` passed from the main checkout. Hex package cache writes required the authorized environment for the nested dependency fetch.

## Next Phase Readiness

Phase 77 can extend this same adopter host with the selected B2B, usage, and Connect edge profiles and establish the aggregate CI gate. This harness does not prove live Stripe delivery, durable event processing, or duplicate-event handling.

---
*Phase: 76-phoenix-adopter-core-flow*
*Completed: 2026-09-24*
