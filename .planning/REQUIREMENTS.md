# Requirements: v1.11 Reader-First Quality Closure

**Defined:** 2026-08-25
**Package baseline:** 2.2.0
**Target package:** 2.2.1
**Milestone intent:** Improve the mature SDK to the point of diminishing returns, then return it to reactive maintenance without changing its public contract.

## Reader Surface and Repository Hygiene

- [x] **READ-01** — Production and test code contains no decorative separator banners or planning-history-only commentary; comments that explain invariants, constraints, or non-obvious tradeoffs remain.
- [x] **READ-02** — The contributor entry point describes the current architecture and verification workflow accurately, without generated or tool-specific scaffolding.
- [x] **READ-03** — `prompts/` has one clearly identified current field guide, historical research is explicitly archived, generated research cache is ignored, and obsolete generated debris is absent.

## Internal Consistency

- [x] **INT-01** — Expandable deserialization has one total, identity-preserving internal contract, and callers do not repeat redundant map guards around it.
- [x] **INT-02** — Canonical test-support fixtures replace duplicate local fixture families without weakening behavioral assertions.

## Client and Test Architecture

- [x] **ARCH-01** — Request construction, execution, and response decoding are cohesive private modules; `LatticeStripe.Client` remains the stable public façade.
- [x] **ARCH-02** — Client characterization tests are organized by behavior so failures lead a maintainer to the responsible contract quickly.
- [x] **ARCH-03** — Test helper documentation and examples use real module paths, accurate lifecycle semantics, and adopter-first microcopy.
- [x] **ARCH-04** — The exact 3,463-entry public API snapshot remains unchanged across all internal refactors.

## Reliability, CI, and Security

- [x] **REL-01** — Batch test accounting is concurrency-safe and the prior low-frequency error-isolation flake survives repeated stress execution.
- [x] **REL-02** — Telemetry tests use module-based handlers and remain isolated under concurrent integration execution.
- [x] **REL-03** — Fuse and OpenTelemetry integrations have explicit required CI lanes, and the test suite has no unexplained skips.
- [x] **REL-04** — CI uses immutable action/container inputs and checks formatting, warnings, locked/unused dependencies, no-optional-dependency compilation, action syntax, retired/vulnerable Hex packages, and package publishability.
- [x] **REL-05** — A truthful 80% line-coverage floor is enforced, supported by meaningful Finch adapter success and failure tests rather than incidental assertions.
- [x] **REL-06** — Matrix jobs report all supported-version failures instead of stopping at the first one.
- [x] **SEC-01** — Dependency vulnerability alerts and automated security updates are enabled; final `main` protection requires the current-head `ci-gate`, resolved conversations, and forbids force pushes/deletion.

## Adopter DX and Documentation Truth

- [x] **DOC-01** — Public and planning surfaces agree on the 2.2.x release line, supported scope, JTBD routes, change history, and maintenance posture.
- [x] **DOC-02** — The 2.x SemVer policy distinguishes public callable surface, return/result contracts, and struct value-shape compatibility.
- [x] **DOC-03** — Documentation and executable coverage establish that `stripe_account: nil` suppresses the connected-account header.
- [x] **DOC-04** — Idempotency guidance derives durable keys from business operations and explains retry boundaries without adding a new hook.
- [x] **DOC-05** — Pagination guidance explains lazy streaming, bounded memory, request timing, and partial-failure semantics.
- [x] **DOC-06** — Testing guidance presents a practical unit/Mox/stripe-mock/live-sandbox pyramid and states stripe-mock's limits honestly.
- [x] **DOC-07** — HexDocs navigation, examples, links, and adopter microcopy are warning-free and verified against source truth.

## Release and Maintenance Pause

- [x] **CLOSE-01** — Planning, release-train, issue/PR, and external-verification ledgers reflect current truth; obsolete windows and probes are retired or explicitly accepted.
- [x] **CLOSE-02** — Fresh local and remote gates pass: full CI, optional-feature lanes, coverage, package build/dry-run, docs truth, API lock, and repository hygiene.
- [x] **CLOSE-03** — Package 2.2.1 is published and verified on GitHub Releases, Hex.pm, and HexDocs from the exact green release SHA.
- [x] **CLOSE-04** — Remote `main` is green and protected, open PRs are resolved, open issues are triaged, temporary worktrees are removed, and the project records a reactive-maintenance handoff.

## Future Requirements

These ideas remain deliberately outside v1.11. They require independent adopter evidence and compatibility design before reconsideration:

- DateTime conversion or other struct value-shape changes
- Deep `to_map` conversion
- A second account-header suppression option
- Function-valued idempotency-key hooks
- A public stub/fake transport
- Named client registries
- Webhook error-shape unification
- New Stripe resource families
- Macro/DSL/code-generation rewrites
- Dialyzer adoption or a vanity coverage target above demonstrated meaningful coverage
- A standalone marketing/UI surface

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| READ-01 | Phase 68 — Reader Surface & Repository Hygiene | Complete |
| READ-02 | Phase 68 — Reader Surface & Repository Hygiene | Complete |
| READ-03 | Phase 68 — Reader Surface & Repository Hygiene | Complete |
| INT-01 | Phase 69 — Internal Consistency | Complete |
| INT-02 | Phase 69 — Internal Consistency | Complete |
| ARCH-01 | Phase 70 — Client Core & Test Architecture | Complete |
| ARCH-02 | Phase 70 — Client Core & Test Architecture | Complete |
| ARCH-03 | Phase 70 — Client Core & Test Architecture | Complete |
| ARCH-04 | Phase 70 — Client Core & Test Architecture | Complete |
| REL-01 | Phase 71 — Reliability, CI & Security | Complete |
| REL-02 | Phase 71 — Reliability, CI & Security | Complete |
| REL-03 | Phase 71 — Reliability, CI & Security | Complete |
| REL-04 | Phase 71 — Reliability, CI & Security | Complete |
| REL-05 | Phase 71 — Reliability, CI & Security | Complete |
| REL-06 | Phase 71 — Reliability, CI & Security | Complete |
| SEC-01 | Phase 71 — Reliability, CI & Security | Complete |
| DOC-01 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| DOC-02 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| DOC-03 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| DOC-04 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| DOC-05 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| DOC-06 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| DOC-07 | Phase 72 — Adopter DX & Documentation Truth | Complete |
| CLOSE-01 | Phase 73 — Release & Maintenance Pause | Complete |
| CLOSE-02 | Phase 73 — Release & Maintenance Pause | Complete |
| CLOSE-03 | Phase 73 — Release & Maintenance Pause | Complete |
| CLOSE-04 | Phase 73 — Release & Maintenance Pause | Complete |

**Coverage:** 27 requirements mapped; 27 total; 0 unmapped.

---
*Requirements defined from the v1.11 codebase assessment, three parallel ecosystem/DX/DevOps research passes, SEED-006 triage, and the approved reader-first closure scope.*
