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
- ✅ **v1.10 — Accrue Surface Closure** — Phases 61-67 (shipped 2026-08-25; planned as Hex 1.8.0, synchronized release baseline reached 2.2.0) — [archive](milestones/v1.10-ROADMAP.md)
- 🚧 **v1.11 — Reader-First Quality Closure** — Phases 68-73 (2.2.0 baseline; targets 2.2.1)

## Phases

- [x] **Phase 68: Reader Surface & Repository Hygiene** - Make repository entry points and source reading frictionless without removing useful context.
- [x] **Phase 69: Internal Consistency** - Give repeated internal mechanics and fixture data one clear, safe home.
- [x] **Phase 70: Client Core & Test Architecture** - Preserve the public client contract while making its implementation and characterization suite easy to navigate.
- [x] **Phase 71: Reliability, CI & Security** - Make automated quality and security signals complete, reproducible, and honest.
- [x] **Phase 72: Adopter DX & Documentation Truth** - Let an Elixir adopter make correct production choices from current, source-backed guidance.
- [ ] **Phase 73: Release & Maintenance Pause** - Close the release and repository at a verified, low-maintenance stopping point. *(in progress)*

## Phase Details

### Phase 68: Reader Surface & Repository Hygiene
**Goal**: A maintainer can enter the repository, find current guidance, and read production or test code without decorative or historical noise obscuring its intent.
**Depends on**: Nothing
**Requirements**: READ-01, READ-02, READ-03
**Success Criteria** (what must be TRUE):
  1. A reader encounters comments that explain an invariant, constraint, or tradeoff rather than decorative separators or planning-history-only narration.
  2. A contributor can use the repository entry point to understand the present architecture and run the authoritative verification workflow.
  3. A researcher can identify the one current field guide in `prompts/`, distinguish archived research, and avoid generated cache or obsolete artifacts.
**Plans**: Complete — see `phases/68-reader-surface-repository-hygiene/68-VERIFICATION.md`

### Phase 69: Internal Consistency
**Goal**: Maintainers can follow expandable-object decoding and test data to one dependable implementation instead of reconciling repeated defensive code or fixture copies.
**Depends on**: Phase 68
**Requirements**: INT-01, INT-02
**Success Criteria** (what must be TRUE):
  1. Expandable values retain their existing identity behavior for every input while callers use one total internal deserialization contract.
  2. Behavioral tests obtain equivalent canonical fixture data from shared support rather than locally duplicated fixture families.
  3. The full test suite proves the consolidation preserved all supported behavior.
**Plans**: Complete — see `phases/69-internal-consistency/69-VERIFICATION.md`

### Phase 70: Client Core & Test Architecture
**Goal**: A maintainer can locate client request building, execution, decoding, and their behavioral proof quickly while adopters receive exactly the same public API.
**Depends on**: Phase 69
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04
**Success Criteria** (what must be TRUE):
  1. The public `LatticeStripe.Client` façade continues to accept and return the same supported values while cohesive private units own construction, execution, and decoding.
  2. A failed client characterization test identifies the responsible behavior group without searching a monolithic test file.
  3. Test-helper docs and examples point adopters to real module paths and lifecycle semantics.
  4. The 3,463-entry public API snapshot is unchanged after the refactor.
**Plans**: Complete — see `phases/70-client-core-test-architecture/70-VERIFICATION.md`

### Phase 71: Reliability, CI & Security
**Goal**: Maintainers can rely on CI and security automation to expose real regressions across supported configurations without noisy races, silent skips, or mutable dependencies.
**Depends on**: Phase 70
**Requirements**: REL-01, REL-02, REL-03, REL-04, REL-05, REL-06, SEC-01
**Success Criteria** (what must be TRUE):
  1. Repeated batch and telemetry runs remain isolated and deterministic under concurrent execution.
  2. CI explicitly proves Fuse and OpenTelemetry integrations, reports every supported-version result, and has no unexplained test skips.
  3. CI rejects mutable inputs, dependency, formatting, warning, optional-dependency, action-syntax, vulnerability, packaging, and meaningful-coverage regressions.
  4. Security update automation is enabled and protected `main` requires a current-head `ci-gate`, resolved conversations, and disallows force pushes and deletion.
**Plans**: Complete — see `phases/71-reliability-ci-security/71-VERIFICATION.md`

### Phase 72: Adopter DX & Documentation Truth
**Goal**: An Elixir developer can understand the SDK's stable contract and operate it correctly from current documentation without needing to infer backend implementation details.
**Depends on**: Phase 71
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07
**Success Criteria** (what must be TRUE):
  1. README, HexDocs, guides, change history, JTBD routes, and planning truth consistently describe the shipped 2.2.x scope and reactive-maintenance posture.
  2. An adopter can determine whether a change is SemVer-compatible, omit a connected-account header with `stripe_account: nil`, and create durable operation-derived idempotency keys.
  3. An adopter understands lazy stream timing, bounded memory, partial failures, and the appropriate unit/Mox/stripe-mock/live-sandbox test boundary.
  4. Documentation navigation, examples, links, and microcopy are warning-free and mechanically agree with the source contract.
**Plans**: Complete — see `phases/72-adopter-dx-documentation-truth/72-VERIFICATION.md`

### Phase 73: Release & Maintenance Pause
**Goal**: The repository and package line reach a demonstrably clean handoff point where maintainers can return to reactive work with no ambiguous release or operational tail.
**Depends on**: Phase 72
**Requirements**: CLOSE-01, CLOSE-02, CLOSE-03, CLOSE-04
**Success Criteria** (what must be TRUE):
  1. Planning, release, issue/PR, and external-verification records state current truth, with obsolete windows and probes retired or explicitly accepted.
  2. Fresh local and remote validation proves CI, optional features, coverage, package build/dry-run, docs truth, API lock, and repository hygiene from the release candidate.
  3. Version 2.2.1 is published and verifiable on GitHub Releases, Hex.pm, and HexDocs from the exact green release SHA.
  4. `main` is green and protected, PRs and issues are triaged, temporary worktrees are removed, and the repository records its reactive-maintenance handoff.
**Plans**: In progress — see `phases/73-release-maintenance-pause/73-VERIFICATION.md`

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 68. Reader Surface & Repository Hygiene | 1/1 | Complete | 2026-08-25 |
| 69. Internal Consistency | 1/1 | Complete | 2026-08-25 |
| 70. Client Core & Test Architecture | 1/1 | Complete | 2026-08-25 |
| 71. Reliability, CI & Security | 1/1 | Complete | 2026-08-25 |
| 72. Adopter DX & Documentation Truth | 1/1 | Complete | 2026-08-25 |
| 73. Release & Maintenance Pause | 0/1 | In progress | - |

## Current Status

**Active milestone:** v1.11 Reader-First Quality Closure.

**Current:** Phase 73 — Release & Maintenance Pause.

**Next:** Merge the green milestone PR, publish and verify 2.2.1, then record the clean reactive-maintenance handoff.
