---
gsd_state_version: 1.0
milestone: v1.10
milestone_name: Accrue Surface Closure (Hex 1.8.0)
current_phase: 63
current_phase_name: stripe-native-entitlements
status: executing
stopped_at: Completed 63-01-PLAN.md
last_updated: "2026-07-28T15:11:34.546Z"
last_activity: 2026-07-28
last_activity_desc: "63-01 complete: typed ActiveEntitlement.list/3 end-to-end (ENT-01)"
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 9
  completed_plans: 3
  percent: 33
---

# Project State

## Project Reference

See: .planning/PROJECT.md (reopened 2026-07-27 — v1.10 "Accrue Surface Closure" under adopter-pull gate, SEED-005)

**Core value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.
**Current focus:** Phase 63 — stripe-native-entitlements

## Current Position

Phase: 63 (stripe-native-entitlements) — EXECUTING
Plan: 1 of 7 complete (63-01 tracer done; Wave 2 = 63-02 + 63-03 next, parallelizable)
Status: Executing Phase 63
Last activity: 2026-07-28 -- 63-01 complete: typed ActiveEntitlement.list/3 end-to-end (ENT-01)

## Performance Metrics

**Velocity (v1.9):**

- Total phases: 2 (59–60)
- Total plans completed: 6
- Timeline: single-day (2026-05-27)

**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 63 P01 | 5min | 2 tasks | 6 files |

## Accumulated Context

### Decisions

- **v1.10 reopens the build track** — adopter-pull gate fired (Accrue's verified blocking need for Stripe-native Entitlements); scope narrow + additive → Hex minor bump 1.8.0. Numbering diverges: GSD milestone v1.10, Hex tag 1.8.0 (v1.8/v1.9 were doc-only).
- **Wave 0 first** — default Finch pool (live footgun, DX-01) + "1.1 → 1.7 what landed" migration guide (DOC-01) are near-zero-code, de-risk, and unblock the most downstream accrue work.
- **Entitlements: pull/pagination shape only** — NO per-request `entitled?` gate helper (actively harmful for accrue's fail-closed local gate).
- **No new metering writes** — accrue uses exactly one (`MeterEvent.create/3`); all four write surfaces already ship. Only reads (EventSummary) are missing.
- **SEED-005 §6 stability contracts FROZEN** — nil `stripe_account` omits header; per-request opts override per-client; api_version default `2026-03-25.dahlia`; `Client.new!/1` takes a keyword list.
- **Lower-priority DX deferred to SEED-006** — brief §3.2, 3.5–3.9, 3.11 are real but non-blocking; not in this milestone.
- **v1.x stop signal otherwise holds** — no broad resource-family breadth (Identity, Treasury, Issuing, Terminal, etc.) in this reopen.
- [Phase ?]: Phase 61 default Finch pool: LatticeStripe.Application starts LatticeStripe.Finch at boot; :finch defaults to it (was required); opt-out via config :lattice_stripe, start_default_finch: false
- **[63-01]** D-16 (one-way): no parent lib/lattice_stripe/entitlements.ex — LatticeStripe.Entitlements.ActiveEntitlement is the published semver name once v1.10 tags; renaming after release is breaking
- **[63-01]** D-06: ActiveEntitlement owns the canonical /v1/entitlements/active_entitlements path as one @list_path + list_path/0 accessor; 63-02 stream!/3 and 63-04's summary url rewrite read it rather than re-declaring it
- **[63-01]** T-63-04 mitigated structurally: refute function_exported?(:entitled?, 2/3/4) forbids the gate helper (a rename cannot defeat it); the moduledoc keeps the name entitled? PRESENT in prose (D-24) and ships the fail-closed local-gate replacement
- **[63-01]** Feature.ex ships decode-only; its alias LatticeStripe.{Client, Request, Resource} was omitted (unused-alias vs --warnings-as-errors) and 63-03 MUST add it with the verb surface — an in-source NOTE marks the spot
- **[63-01]** Clean-HEAD ExDoc warning baseline = 42, recorded for the 63-07 differential docs gate; mix ci stays un-run this phase because its docs --warnings-as-errors step is RED at clean HEAD (C-02)

### Blockers/Concerns

- **Requirement count**: REQUIREMENTS.md header says "17 v1 requirements" but the enumerated list contains **19 distinct IDs** (ENT×5, MTR×4, OBJ×3, PROD×2, DX×3, DOC×2). All 19 are mapped to phases (100% coverage). The "17" is a stale count in the source header, not a coverage gap.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 20260528-i13p | Issue #13 drift patches — Balance, BalanceTransaction, BillingPortal.Session | 2026-05-28 | 79f6baf | [20260528-issue-13-drift-patches](./quick/20260528-issue-13-drift-patches/) |
| 20260528-jnc | JTBD narrative close — Adopter-owned depth + Mandates reading order | 2026-05-28 | a49a0f7 | [20260528-jtbd-narrative-close](./quick/20260528-jtbd-narrative-close/) |
| 20260528-dts | Doc-truth Connect + Webhook sibling clusters | 2026-05-28 | a49a0f7 | [20260528-docs-truth-sibling-clusters](./quick/20260528-docs-truth-sibling-clusters/) |
| 20260528-car | Capstone assessment refresh — STATE/PROJECT/v1-10 thread | 2026-05-28 | 775c8c5 | [20260528-capstone-assessment-refresh](./quick/20260528-capstone-assessment-refresh/) |
| 260528-i13 | Issue #13 drift triage — categorized report + maintenance tracker | 2026-05-28 | 8fc5e4b | [260528-issue-13-drift-triage](./quick/260528-issue-13-drift-triage/) |
| 260528-rgw | Release gate polls for ci-gate before Hex publish | 2026-05-28 | 3934bef | [260528-release-gate-ci-wait](./quick/260528-release-gate-ci-wait/) |
| 260527-tkc | Wedge A doc defect hotfixes (payments fence, portal truth, JTBD gaps) | 2026-05-28 | e24e9a3 | [260527-tkc-doc-defect-hotfixes-wedge-a-payments-md-](./quick/260527-tkc-doc-defect-hotfixes-wedge-a-payments-md/) |
| 260527-tm1 | Wedge B disputes/files evidence narrative in recipes.md | 2026-05-28 | b5a78dc | [260527-tm1-wedge-b-disputes-files-evidence-narrativ](./quick/260527-tm1-wedge-b-disputes-files-evidence-narrativ/) |
| 260527-tp8 | Gap 2 Product/Price catalog + mandate/SetupAttempt narratives | 2026-05-28 | 4c636f4 | [260527-tp8-gap-2-narrative-product-price-catalog-st](./quick/260527-tp8-gap-2-narrative-product-price-catalog-st/) |
| 260527-tqf | PLAN-01 backfill 54-VERIFICATION.md | 2026-05-28 | 69c0134 | [260527-tqf-plan-01-backfill-54-verification-md-from](./quick/260527-tqf-plan-01-backfill-54-verification-md-from/) |
| Phase 61 P01 | 5min | 2 tasks | 7 files |
| Phase 61 P02 | 10m | 2 tasks | 3 files |

## Session Continuity

**Last session:** 2026-07-28T15:11:09.585Z
**Stopped at:** Completed 63-01-PLAN.md
**Resume file:** None

Seed: `.planning/seeds/SEED-005-stripe-native-entitlements.md`
Gap brief: `.planning/research/accrue-gap-brief-2026-07-27.txt`
Assessment thread: `.planning/threads/v1-10-next-milestone-assessment.md`
Deferred DX: `.planning/seeds/SEED-006-accrue-dx-ergonomics.md`

## Operator Next Steps

**Default:** Continue Phase 63. Wave 0 (61, 62) is done; Wave 1 (63-01, the tracer) is done.

| Trigger | Action |
|---------|--------|
| Ready to continue | `/gsd-execute-phase 63` — Wave 2 is 63-02 (`retrieve/3` + `stream!/3` + pagination) and 63-03 (`Feature` verb surface), parallelizable |
| Starting 63-03 | Add `alias LatticeStripe.{Client, Request, Resource}` to `lib/lattice_stripe/entitlements/feature.ex` — deliberately omitted in 63-01, marked with an in-source `NOTE:` |
| Bug / wrong Stripe behavior | `/gsd-quick` or `/gsd-debug` → fix + test |

**Do not:** broad resource-family breadth; new metering writes; a per-request `entitled?` gate helper; break SEED-005 §6 stability contracts.
