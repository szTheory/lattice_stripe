---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Billing & Connect
status: executing
stopped_at: Completed 13-05-PLAN.md
last_updated: "2026-04-12T04:03:56.607Z"
last_activity: 2026-04-12
progress:
  total_phases: 7
  completed_phases: 1
  total_plans: 14
  completed_plans: 13
  percent: 93
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.
**Current focus:** Phase 13 — billing-test-clocks

## Current Position

Phase: 13 (billing-test-clocks) — EXECUTING
Plan: 6 of 7
Status: Ready to execute
Last activity: 2026-04-12
Last activity: 2026-04-12

Progress: [██░░░░░░░░░░░░░░░░░░] 1/8 phases (13%) in v2.0 milestone

## Performance Metrics

**Velocity:**

- Total plans completed: 31 (v1.0 archived)
- v2.0 plans completed: 0
- Average duration: -
- Total execution time: (v1.0 archived)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 12–19 | 0 | 0 | - |

**Recent Trend:**

- Last 5 plans: v1.0 archived
- Trend: -

*Updated after each plan completion*
| Phase 12 P01 | 97 | 1 tasks | 11 files |
| Phase 12 P02 | 8min | 2 tasks | 2 files |
| Phase 12 P03 | 142 | 2 tasks | 3 files |
| Phase 12 P07 | 15m | 2 tasks | 3 files |
| Phase 13 P01 | 12min | 5 tasks | 19 files |
| Phase 13 P02 | 9min | 2 tasks | 2 files |
| Phase 13 P03 | 8min | 2 tasks | 4 files |
| Phase 13 P04 | 14min | 2 tasks | 2 files |
| Phase 13 P05 | 18min | 3 tasks | 7 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v2.0 phase structure: 8 phases (12–19), strictly topological — Catalog → TestClocks → Invoices → Subscriptions → Schedules → Connect Accounts → Connect Money → Cross-cutting
- TestClocks pulled forward to Phase 13 so Phases 14–16 can use them in integration tests (H4 mitigation)
- `require_explicit_proration` ships in Phase 15 (not deferred to 19) — validator + client flag land together with Subscriptions (C1 primary mitigation)
- `LatticeStripe.Search` is a **thin facade**, not a new engine module — v1 `List.stream!/2` already handles search pagination (UTIL-02)
- v0.3.0-rc1 cut decision deferred to Phase 16 transition (REL-03 / M4)
- Zero new runtime dependencies, zero behaviour additions, zero modifications to v1 HTTP/retry/pagination primitives
- Two-tier integration test strategy: stripe-mock (always) + `:real_stripe` (nightly, gated by `STRIPE_TEST_SECRET_KEY`) — first `:real_stripe` test ships in Phase 13
- [Phase 12]: D-09f: use :erlang.float_to_binary with [:compact, {:decimals, 12}] to avoid scientific notation on Stripe decimal fields
- [Phase 12]: 12-07: PromotionCode ships with 5-op surface (no search, no delete) — absence is the interface; three-identifier moduledoc table distinguishes Coupon.id / PromotionCode.id / PromotionCode.code
- [Phase 13]: Phase 13-01: rename test-only TestHelpers to TestSupport to free the public namespace for TestHelpers.TestClock submodule
- [Phase 13]: Phase 13-01: test_clock error context stashed in existing Error :raw_body field (no :details schema change)
- [Phase 13]: Phase 13-02: A-13g probe — Stripe does NOT support metadata on test clocks (verified OpenAPI + stripe-mock). Plan 13-05 cleanup strategy must fall back from marker to Owner-only + age-based Mix task.
- [Phase 13]: Phase 13-02: TestHelpers.TestClock struct intentionally omits :metadata field, reflecting Stripe's actual API surface.
- [Phase 13]: Phase 13-03: TestClock CRUD modeled on Coupon template (no update, no search — closest surface match)
- [Phase 13]: Phase 13-03: Integration test asserts request+response shape only; polling deferred to Plan 13-04 Mox + Plan 13-06 :real_stripe (Pitfall 4)
- [Phase 13]: Phase 13-04: backoff state bundled into a map to keep poll_until_ready under Credo max arity, preserving readable recursive call site
- [Phase 13]: Phase 13-04: advance_and_wait errors use string-keyed raw_body (clock_id, last_status, attempts, elapsed_ms) for consistency with Error.from_response
- [Phase 13]: Phase 13-05: A-13g metadata fallback — cleanup uses age-based filtering + name_prefix instead of metadata marker (Stripe doesn't support metadata on test clocks)
- [Phase 13]: Phase 13-05: Mix task requires both --no-dry-run and --yes for destructive delete (threat T-13-15)

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 12 open question:** `PromotionCode.search/2` capability — Stripe's published search list excludes it, but gap doc implies otherwise. Verify against live Stripe before exposing. Do not ship `PromotionCode.search/2` until confirmed (LOW confidence flag from research).
- **Phase 13 spike:** stripe-mock clock simulation fidelity may have improved since research; spike at phase start to confirm which assertions work against stripe-mock vs must defer to `:real_stripe` tier (M3 mitigation).

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260402-wte | Research how Elixir Plug-based libraries handle path matching and mounting strategies | 2026-04-03 | 8e7c6cd | [260402-wte-research-how-elixir-plug-based-libraries](./quick/260402-wte-research-how-elixir-plug-based-libraries/) |

## Session Continuity

Last session: 2026-04-12T04:03:56.604Z
Stopped at: Completed 13-05-PLAN.md
Resume file: None
Next action: `/gsd-plan-phase 12`
