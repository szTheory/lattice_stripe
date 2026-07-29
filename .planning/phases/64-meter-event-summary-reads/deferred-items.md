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

## Pre-existing flaky test: Batch error isolation (SECOND, distinct flake)

- **Discovered during:** 64-10 phase-close verification (full-suite re-run after the gate).
- **Test:** `test/lattice_stripe/batch_test.exs:72` —
  `test run/3 — error isolation one failing task returns {:error, %Error{}} in its slot, others succeed`
- **Symptom:** `assert Enum.count(results, &match?({:ok, _}, &1)) == 1` fails with `left: 2,
  right: 1` at `batch_test.exs:94` — i.e. the task that was supposed to fail **succeeded**,
  so two slots came back `{:ok, _}` instead of one.
- **Frequency:** ~1 in 30 runs.
- **Proven pre-existing, not introduced by Phase 64.** Two independent lines of evidence:
  1. `git diff --name-only a22e197..HEAD` shows Phase 64 touched **no** Batch file — neither
     `lib/lattice_stripe/batch.ex` nor `test/lattice_stripe/batch_test.exs`.
  2. Reproduced on the **pre-phase commit `a22e197`** in a separate worktree with none of
     Phase 64's code present: 1 failure in 30 runs of `batch_test.exs` alone, with a
     byte-identical assertion message and stack frame.
- **This is a different flake from the client-retry one above** — different file, different
  test, different failure mode. It was initially and wrongly assumed to be the known one;
  capturing the actual output disproved that.
- **Likely cause (unconfirmed):** the "failing" task is made to fail by a mechanism that is
  timing- or ordering-dependent rather than deterministic, so under some schedules it
  completes successfully. Worth checking whether the intended failure is induced by a
  sleep/race rather than by a stubbed error return.
- **Why out of scope here:** 64-10 is a gate plan and changes no code — "a gate plan that
  also changes code cannot honestly report on itself." Route to a follow-up.
