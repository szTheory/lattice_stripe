# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe aims to be the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. **Shipped v1.0.0 to Hex.pm on 2026-04-13** with full Payments + Billing + Connect coverage. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising. **Still the right priority** — validated by shipped milestones and a downstream consumer (Accrue) already building on top.

## Current State

**Latest shipped milestone:** v1.3 Production Coverage & Adoption Polish (archived 2026-05-25)

**What shipped:**

- File upload/download transport plus `File` and `FileLink`
- Disputes, CreditNotes, Mandates, SetupAttempts, and Quotes
- DX follow-through, verifier closure, and planning-truth reconciliation

**Close posture:**

- v1.3 is archived and v1.4 is now the active milestone.
- One accepted follow-through remains outside the milestone headline: Phase `41.1` is still `pending-external-verification` for real-sandbox Quote downstream proof.
- v1.4 starts from a fresh requirements pass rather than extending the archived v1.3 planning files in place.

## Current Milestone: v1.4 Adoption Closure

**Goal:** Make the shipped `1.3.x` surface obvious, trustworthy, and easier to evaluate for serious Elixir and Phoenix SaaS teams.

**Target features:**

- Public package/version/install truth agrees across README, CHANGELOG, Getting Started, cheatsheet, and HexDocs-facing guides.
- Docs-truth regression coverage fails on first-run onboarding drift instead of only README drift.
- Guide discovery is tighter for already-shipped high-leverage surfaces.
- Three to four flagship recipe/operator guides cover the most important already-shipped SaaS flows without turning LatticeStripe into a billing workflow package.
- Planning truth preserves the narrow Phase `41.1` external Quote proof boundary instead of flattening it into a false full-close story.

**Why now:** The library is already broad for its intended SDK scope; adopter trust, support truth, and first-run clarity now unlock more value than another narrow Stripe resource family.

## Context

**Ecosystem gap:** At project start, the Elixir ecosystem lacked a modern, maintained Stripe SDK. `stripity_stripe` was outdated, with known issues around nested encoding and stale API coverage. LatticeStripe fills that gap with a production-minded Elixir-first surface.

**Target users:** Elixir developers building SaaS products who need Stripe integrations that are correct, documented, and unsurprising. Early adopter signal remains strong: Accrue already consumes LatticeStripe as a downstream billing layer.

**Design philosophy:**

- Pure-functional core; processes only where the runtime boundary needs them
- Behaviours for extensibility (`Transport`, `RetryStrategy`, `Json`)
- `{:ok, result} | {:error, reason}` everywhere, with bang variants layered on top
- Pattern-matchable returns and explicit verbs for destructive or irreversible operations
- Principle of least surprise for Elixir developers

**Testing philosophy:**

- Integration specs first, with real request-pipeline proof where feasible
- Shift-left verification by default when a flow can be executed truthfully in CI
- Unit tests for pure logic and Mox for behaviour contracts

## Constraints

- **Language**: Elixir 1.15+, OTP 26+
- **License**: MIT
- **No Dialyzer**: Typespecs remain documentation-first
- **HTTP**: Finch default transport behind a behaviour boundary
- **JSON**: Jason

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Handwritten v1 surface | Polish and Elixir ergonomics mattered more than breadth-first codegen | Good |
| Integration-first proof posture | Real boundaries catch drift earlier than mock-only tests | Good |
| Explicit verbs over magical updates | Clearer SDK semantics for irreversible actions | Good |
| Shift-left verification default | Docs/example flows should become executable proof where feasible | Good |
| Keep LatticeStripe lower-level than Accrue | Billing-engine abstractions belong downstream, not in the SDK | Good |
| Prioritize adoption closure before new breadth | Public truth and guide clarity now unlock more user value than another narrow Stripe family | Good |
| Treat public docs/support truth as a milestone-grade surface | For a near-done SDK, first-run trust and flagship guidance now change adoption more than another small API family | Good |
| Keep recipe/operator guidance primitive-first | Recipes should stitch shipped primitives together without becoming an app workflow product or Accrue substitute | Good |
| Treat the library as near-done for scope | Remaining leverage is mostly adopter truth, thin-event evolution, and selected breadth, not missing foundation | Good |
| Treat first-run docs truth as verifier-worthy surface, not editorial cleanup | A green narrow docs test can still hide adopter-facing drift in install/onboarding guides | Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-26 after v1.4 milestone definition*
