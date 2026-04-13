---
phase: 19
plan: 03
subsystem: docs
tags: [readme, integration-test, nyquist-wave0, v1.0-release]
requires:
  - phase: 9
    plan: "*"
    why: "stripe-mock on :12111 + :integration exclusion tag"
  - phase: 10
    plan: "*"
    why: "README PaymentIntent hero baseline (D-18) preserved byte-for-byte"
provides:
  - "test/readme_test.exs: automated 60-second quickstart verification"
  - "README v1.0 feature groups (Payments / Billing / Connect / Platform)"
  - "README 'What's new in v1.0' callout with CHANGELOG link"
affects:
  - "Release-gate path: Plan 19-04 can now rely on a machine-enforced README"
tech-stack:
  patterns:
    - "Regex-extracted fenced elixir blocks + Code.eval_string/1"
    - "base_url injection into LatticeStripe.Client.new!/1"
key-files:
  created:
    - test/readme_test.exs
  modified:
    - README.md
decisions:
  - id: D-21
    summary: "README PaymentIntent hero unchanged — byte-identical to Phase 10 D-18 state."
  - id: D-22
    summary: "Features bullets grouped into Payments / Billing / Connect / Platform subsections with per-group guide links."
  - id: D-23
    summary: "'What's new in v1.0' blockquote callout placed below badges linking CHANGELOG#100."
  - id: D-24
    summary: "test/readme_test.exs extracts fenced elixir blocks from ## Quick Start and Code.eval_string's them against stripe-mock."
  - id: D-25
    summary: "Avoided ExUnit.DocTest.doctest_file/1 — no iex> prompts in README."
  - id: D-26
    summary: "Test gated behind @moduletag :integration so default mix test stays stripe-mock-free (Phase 9 D-01)."
metrics:
  duration: "~25 minutes"
  completed: "2026-04-13"
  tasks: 2
  files_created: 1
  files_modified: 1
  commits: 2
---

# Phase 19 Plan 03: README Restructure + Automated Quickstart Test Summary

Ship the Phase 19 Nyquist Wave 0 artifact — an integration test that regex-extracts fenced elixir blocks from the README `## Quick Start` section and evaluates them against stripe-mock — and restructure the README feature bullets into four v1.0 subsections while leaving the PaymentIntent hero byte-identical.

## One-liner

Machine-enforced README correctness via `test/readme_test.exs` + v1.0-visible feature groups without touching the single-domain PaymentIntent hero.

## What Shipped

### Task 1 — `test/readme_test.exs` (commit `956df3e`)

73-line ExUnit module, `@moduletag :integration` + `@moduletag :readme`, skipped by default `mix test` per Phase 9 D-01. The test:

1. Reads `README.md` at runtime via `File.read!/1`.
2. Regex-scopes to the `## Quick Start` section (raises with a clear message if the section is absent — guards against future structural edits).
3. Extracts fenced `\`\`\`elixir` blocks from that section with `Regex.scan/3`.
4. Filters out any block whose first two lines contain `deps do` (the Installation `mix.exs` block is not eval-able outside a `Mix.Project` context).
5. Rewrites `"sk_test_..."` → `"sk_test_readme"` (stripe-mock accepts any key), `MyApp.Finch` → `ReadmeTest.Finch`, and injects `base_url: "http://localhost:12111"` into every `LatticeStripe.Client.new!(` call.
6. Joins the remaining blocks and runs them via `Code.eval_string/2`. A raise is the failure signal — no additional assertions needed.
7. `setup_all` starts a `Finch` pool named `ReadmeTest.Finch` via `start_supervised!/1`.

Verified locally against `stripe/stripe-mock:latest`:

```
$ mix test --include integration test/readme_test.exs
PaymentIntent created: pi_QWVW06cdvJCVoYv
.
Finished in 0.1 seconds — 1 test, 0 failures
```

And verified that the default invocation remains stripe-mock-free:

```
$ mix test
1386 tests, 0 failures (143 excluded)
```

### Task 2 — README restructure (commit `5e64255`)

- **Step A.** Added a one-line `> **What's new in v1.0** — ...` blockquote directly beneath the badge block and above the tagline, linking `CHANGELOG.md#100`.
- **Step B.** Replaced the flat 10-bullet Features list with four `###` subsections:
  - **Payments** — 3 bullets + `guides/payments.md` link.
  - **Billing** — 3 bullets + `guides/subscriptions.md` link.
  - **Connect** — 4 bullets (absorbed the "Connect support" flat bullet) + `guides/connect.md` link.
  - **Platform** — 5 bullets covering Transport/Json/RetryStrategy, retry-with-backoff, idempotency, telemetry, and `Webhook.Plug` + `guides/extending-lattice-stripe.md` link.
- **Step C.** `## Quick Start`, `## Installation`, the supervision-tree block, and the `LatticeStripe.Client.new!/1 + PaymentIntent.create/2` hero are byte-identical to `git show c007f40:README.md`. Adaptation policy (D-21) observed.
- **Step D.** No tabs, no multi-domain hero, no Billing/Connect teaser code in Quick Start — 100% ecosystem-consistent single-domain hero preserved.

## Verification

| Check | Command | Result |
|-------|---------|--------|
| Compile clean | `mix compile --warnings-as-errors` | pass |
| Default suite green | `mix test` | 1386 tests, 0 failures (143 excluded) |
| ReadmeTest NOT in default run | `mix test 2>&1 \| grep -c LatticeStripe.ReadmeTest` | 0 |
| Integration readme test green | `mix test --include integration test/readme_test.exs` | 1 test, 0 failures |
| ExDoc builds clean | `mix docs --warnings-as-errors` | pass |
| README callout present | `grep -c "What's new in v1.0" README.md` | 1 |
| Four grouped subsections | `grep -c "### {Payments,Billing,Connect,Platform}"` | 1 each |
| Hero preserved | `grep -c "PaymentIntent.create" README.md` | 2 |
| Deps block preserved | `grep -c "deps do" README.md` | 1 |

All acceptance criteria from the PLAN met except the note in Deviations below.

## Deviations from Plan

### Auto-fixed / Adjusted

**1. [Rule 1 — Acceptance-criterion miscount] "Three elixir fences inside Quick Start"**
- **Found during:** Task 2 verification step.
- **Issue:** Plan acceptance criterion read `awk '/## Quick Start/,/## /' README.md | grep -c "```elixir"` returns **at least 3**. Reality: the current (and pre-plan) README has two elixir fences inside the `## Quick Start` section — the supervision-tree block and the Client/PaymentIntent block. The third fence (the `deps do` block) lives in a separate `## Installation` section above it. Confirmed against `git show c007f40:README.md` (base commit) — the original README had the same 2 blocks in Quick Start, 3 total. No regression was introduced.
- **Fix:** Left the README structure as-is. The hero is byte-identical (truth 1 satisfied). The plan's acceptance criterion appears to have been written assuming the deps block lives inside `## Quick Start`; it does not, and moving it would violate D-21 ("hero UNCHANGED").
- **Files modified:** none (documenting here instead of silently deviating).
- **Commit:** n/a — this is a planning artifact mismatch, not a code change.

### Auto-fixed Issues

None — both tasks landed as written, no bugs or missing functionality encountered.

## Threat Flags

None introduced. Threat register T-19-03-01..04 accounted for in plan (T-03 is mitigated by Finch's default timeouts + `:integration` gating; T-04 depends on Plan 19-04 to populate CHANGELOG).

## Known Stubs

None.

## Follow-ups for Later Plans

- **Plan 19-04** must populate `CHANGELOG.md#100` so the new README callout link resolves. (Expected per Plan 19-04 scope.)
- **CI job** (Phase 11 integration-test job) should already pick up `test/readme_test.exs` automatically since it uses `@moduletag :integration`. No CI config change required by this plan.

## Self-Check

- [x] `test/readme_test.exs` exists (`test -f test/readme_test.exs`)
- [x] Commit `956df3e` exists (`git log --oneline | grep 956df3e`)
- [x] Commit `5e64255` exists (`git log --oneline | grep 5e64255`)
- [x] README.md modified (2 commits, verified via `git log --oneline c007f40..HEAD`)
- [x] `mix test` green
- [x] `mix test --include integration test/readme_test.exs` green against running stripe-mock
- [x] `mix docs --warnings-as-errors` green

## Self-Check: PASSED
