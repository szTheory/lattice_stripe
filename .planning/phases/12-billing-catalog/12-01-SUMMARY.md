---
phase: 12-billing-catalog
plan: 01
subsystem: billing-catalog
tags: [test-infrastructure, wave-0, stream-data, stubs]
requires: []
provides:
  - "stream_data test dep"
  - "Wave 0 test stubs (5 unit + 4 integration)"
  - "mix test discoverable stub files for Phase 12 resources"
affects:
  - mix.exs
  - mix.lock
tech_stack_added:
  - "stream_data ~> 1.1 (test-only)"
patterns:
  - "Wave 0 test stub pattern: tagged :wave0_stub with assert true placeholder"
key_files_created:
  - test/lattice_stripe/discount_test.exs
  - test/lattice_stripe/product_test.exs
  - test/lattice_stripe/price_test.exs
  - test/lattice_stripe/coupon_test.exs
  - test/lattice_stripe/promotion_code_test.exs
  - test/integration/product_integration_test.exs
  - test/integration/price_integration_test.exs
  - test/integration/coupon_integration_test.exs
  - test/integration/promotion_code_integration_test.exs
key_files_modified:
  - mix.exs
  - mix.lock
decisions:
  - "Use simplified stub template (no alias line) to avoid unused-alias warnings before modules exist"
  - "Tag integration stubs with both :integration (existing exclude) and :wave0_stub for future filtering"
metrics:
  duration_seconds: 97
  tasks_completed: 1
  tasks_total: 1
  files_created: 9
  files_modified: 2
  completed_date: 2026-04-12
requirements: [BILL-01, BILL-02, BILL-06, BILL-06b]
---

# Phase 12 Plan 01: Wave 0 Test Infrastructure Summary

Adds the `stream_data` test-only dependency and creates nine pending test stub files (5 unit + 4 stripe-mock integration) so every downstream Phase 12 plan has a discoverable test file from its first task.

## Objective Achieved

Wave 0 unblocker complete: `stream_data ~> 1.1` is installed, `mix.lock` carries the new deps, and ten (mix.exs + 9 test files) artifacts from the must-haves list exist on disk. `mix compile --warnings-as-errors` is clean; `mix test --exclude integration` reports `595 tests, 0 failures`.

## What Was Built

**Dependency addition (`mix.exs`):**
Added `{:stream_data, "~> 1.1", only: :test}` in the dev/test deps section immediately after the existing Mox entry. `mix deps.get` resolved cleanly and updated `mix.lock`.

**Unit test stubs (`test/lattice_stripe/`):**
Five files for the Phase 12 resources — `discount_test.exs`, `product_test.exs`, `price_test.exs`, `coupon_test.exs`, `promotion_code_test.exs`. Each uses `use ExUnit.Case, async: true`, is tagged `@moduletag :wave0_stub`, and contains a single `test "wave 0 stub" do assert true end` placeholder. A comment points to the downstream plan that will populate the file (12-03 Discount, 12-04 Product/Price, 12-05 Coupon, 12-06 PromotionCode).

**Integration test scaffolds (`test/integration/`):**
Four files — `product_integration_test.exs`, `price_integration_test.exs`, `coupon_integration_test.exs`, `promotion_code_integration_test.exs`. Each uses `use ExUnit.Case, async: false` (stripe-mock is shared state), tagged `@moduletag :integration` (already excluded by `test_helper.exs`) plus `@moduletag :wave0_stub`. The `test/integration/` directory did not previously exist — created implicitly via the first write.

## Verification Results

- `mix deps.get` — success, all new deps (stream_data + ex_doc/credo/mix_audit transitive) fetched cleanly
- `mix compile --warnings-as-errors` — clean (15 + 29 files compiled across deps + project)
- `mix test --exclude integration` — **595 tests, 0 failures** (up from previous baseline; 42 excluded by tag)
- Acceptance criteria (16 items): all satisfied — 9 stub files exist, `stream_data` + `~> 1.1` present in `mix.exs`, `mix.lock` contains `stream_data`, `@moduletag :wave0_stub` present in discount stub

## Decisions Made

- **Simplified stub template (no alias).** The plan's first template included an `alias LatticeStripe.Discount` line but the revised template in the same task dropped it because the aliased modules do not exist yet and the compiler would warn. Used the revised template for all 5 unit stubs.
- **Kept existing `test/test_helper.exs` unchanged.** It already has `ExUnit.configure(exclude: [:integration])`, so new integration tests tagged `:integration` are automatically excluded from the default run. Plan explicitly said not to modify it.
- **Integration stubs use `async: false`.** stripe-mock is a shared HTTP server; async integration tests would race. Matches the v1 phase 4-6 integration pattern.

## Deviations from Plan

**One incidental step: worktree fast-forward merge.**

The worktree started at commit `a01dadc` (main at time of worktree creation), which predated the five phase 12 planning commits (`620809b` → `a1b69b1`). A `git merge --ff-only main` was required before the plan file at `.planning/phases/12-billing-catalog/12-01-PLAN.md` existed in the worktree. This is a worktree-setup artifact (Rule 3 — blocking environmental issue), not a code deviation. No manual edits to planning files.

**Otherwise: None — plan executed exactly as written.**

No auto-fixed bugs (Rule 1), no missing critical functionality (Rule 2), no architectural decisions (Rule 4). No authentication gates encountered.

## Known Stubs

This plan is **entirely** Wave 0 stub scaffolding — that is its objective. Every file created is a deliberately stubbed placeholder:

| File | Stub reason | Resolved by |
|------|-------------|-------------|
| `test/lattice_stripe/discount_test.exs` | Discount module does not exist yet | Plan 12-03 |
| `test/lattice_stripe/product_test.exs` | Product module does not exist yet | Plan 12-04 |
| `test/lattice_stripe/price_test.exs` | Price module does not exist yet | Plan 12-04 |
| `test/lattice_stripe/coupon_test.exs` | Coupon module does not exist yet | Plan 12-05 |
| `test/lattice_stripe/promotion_code_test.exs` | PromotionCode module does not exist yet | Plan 12-06 |
| `test/integration/*_integration_test.exs` (×4) | stripe-mock integration landing zone | Plans 12-04, 12-05, 12-06 |

All stubs are documented in the plan's must-haves, tagged `:wave0_stub` for discoverability, and contain inline comments naming the plan that will populate them. Intentional by design per plan objective.

## Deferred Issues

None.

## Commits

| Task | Name                                                   | Commit  | Files                                              |
| ---- | ------------------------------------------------------ | ------- | -------------------------------------------------- |
| 1    | Add stream_data dep and create all Phase 12 test stubs | 8fda305 | mix.exs, mix.lock, 9 new test files (5 unit + 4 integration) |

## Self-Check: PASSED

- mix.exs — FOUND (stream_data ~> 1.1 present)
- mix.lock — FOUND (stream_data entry present)
- test/lattice_stripe/discount_test.exs — FOUND
- test/lattice_stripe/product_test.exs — FOUND
- test/lattice_stripe/price_test.exs — FOUND
- test/lattice_stripe/coupon_test.exs — FOUND
- test/lattice_stripe/promotion_code_test.exs — FOUND
- test/integration/product_integration_test.exs — FOUND
- test/integration/price_integration_test.exs — FOUND
- test/integration/coupon_integration_test.exs — FOUND
- test/integration/promotion_code_integration_test.exs — FOUND
- Commit 8fda305 — FOUND in git log
