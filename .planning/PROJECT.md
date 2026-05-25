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

- v1.3 is archived and no active milestone is defined.
- One accepted follow-through remains: Phase `41.1` is still `pending-external-verification` for real-sandbox Quote downstream proof.
- Next milestone planning should start from a fresh requirements pass, not by extending the v1.3 planning files in place.

## Next Milestone Goals

- Decide whether the Phase `41.1` sandbox proof still needs closure before or during v1.4.
- Refresh public package/docs/version truth so external adopters see the shipped surface accurately.
- Choose the next SDK wedge by fit with LatticeStripe’s lower-level scope: likely specialist Stripe families or thin-event support, not Accrue-style billing abstractions.

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
