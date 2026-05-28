# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27) — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — Phases 47-48 (shipped 2026-05-27) — [archive](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6 — Tax** — Phases 49-51 (shipped 2026-05-27) — [archive](milestones/v1.6-ROADMAP.md)
- ✅ **v1.7 — Polish & Operator** — Phases 52-55 (shipped 2026-05-27, v1.x stop signal) — [archive](milestones/v1.7-ROADMAP.md)
- ✅ **v1.8 — Adopter Truth & Doc Routing Polish** — Phases 56-58 (shipped 2026-05-27) — [archive](milestones/v1.8-ROADMAP.md)
- ✅ **v1.9 — CI & Doc Honesty** — Phases 59-60 (shipped 2026-05-27) — [archive](milestones/v1.9-ROADMAP.md)

## Current Status

**Active posture:** Maintenance mode — Stripe API drift, adopter-pull narrow adds (TAX-01/02), bugfixes. No pending v1.9 phases.

## Forward Work (maintenance only)

Reactive maintenance — no active milestone. Act only when triggered:

| Trigger | Response |
|---------|----------|
| User-reported bug | Fix + test; semver patch if needed |
| Stripe API drift | Narrow update + CHANGELOG |
| Adopter-pull new family | Scope in `guides/scope.md`; implement narrow surface |
| Doc defect | `/gsd-quick` + docs_truth |

**Deferred (adopter pull only):** TAX-01/02, specialist Stripe families, v2.core typed modules.

**Explicitly out of scope:** marketing website (README + HexDocs sufficient), v1.10 structured milestone, proactive doc polish.

See `.planning/threads/post-v1x-maintenance-posture.md`.

## Progress (v1.9 — archived)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 59. Checkout Guide & README Truth | v1.9 | 2/2 | Complete | 2026-05-27 |
| 60. CI Gate & Milestone Close | v1.9 | 2/2 | Complete    | 2026-05-27 |

## Next Step

**None** — operate as a finished v1.x library. Triage issues/PRs; use `/gsd-quick` for small fixes. See `.planning/threads/post-v1x-maintenance-posture.md`.
