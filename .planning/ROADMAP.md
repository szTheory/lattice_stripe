# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25 with accepted external-proof gap) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27, Phase 41.1 preserved as `pending-external-verification`) — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — Phases 47-48 (shipped 2026-05-27) — [archive](milestones/v1.5-ROADMAP.md)

## Phases

<details>
<summary>✅ v1.5 Thin-Event Webhooks (Phases 47-48) — SHIPPED 2026-05-27</summary>

- [x] Phase 47: Thin-Event SDK Surface & Webhook Reconciliation (5/5 plans) — completed 2026-05-27
- [x] Phase 48: Thin-Event Adoption Surface — Guide & Integration Verification (6/6 plans) — completed 2026-05-27

</details>

## Outstanding Follow-Through

- **Phase 41.1** — `pending-external-verification` for real-sandbox Quote downstream follow-through proof. Accepted external-proof boundary, carried forward from v1.3 archive. Not a milestone-blocking gap; decide whether to re-run with valid sandbox credentials or retire as accepted external-only follow-through. (Planned to ride along with v1.7 polish milestone.)

## Next Milestone

Run `/gsd:new-milestone` to start **v1.6 — Tax** (`Tax.Calculation`, `Tax.Transaction`, `Tax.Settings`, `Tax.Registration`, `TaxId` nested under `Customer`). Negotiate scope in discuss-phase to keep filing orchestration downstream in Accrue (SDK ships Calculation/Transaction primitives only).
