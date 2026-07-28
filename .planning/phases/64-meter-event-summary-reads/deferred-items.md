# Deferred Items — Phase 64

Out-of-scope discoveries logged during execution. Not fixed here.

## Pre-existing flaky test: client retry telemetry attempts count

- **Discovered during:** 64-02 Task 2 (full-suite verification)
- **Test:** `test/lattice_stripe/client_test.exs:912` —
  `test request/2 retry telemetry stop event metadata includes attempts and retries counts`
- **Symptom:** intermittently `assert metadata.attempts == 2` fails with `left: 1`.
- **Frequency:** roughly 1 in 20 full-suite runs. Reproduced twice under
  `mix test --repeat-until-failure 60` / `80`; ~140 other runs were green.
- **Why out of scope:** 64-02 changes only `lib/lattice_stripe/drift.ex` (a regex used
  solely by the drift mix task) and four test files. Nothing in this plan touches the
  client retry or telemetry paths. The flake reproduces independently of this plan's changes.
- **Likely cause (unconfirmed):** a globally-attached `:telemetry` handler in an
  `async: true` test receiving a stop event emitted by a different test's request, so the
  captured metadata belongs to a single-attempt call rather than the retried one.
- **Suggested fix:** scope the handler by a unique per-test telemetry ref/config and filter
  received events by it, rather than asserting on the first event received.
