# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe aims to be the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## Requirements

### Validated

- [x] HTTP transport via pluggable `Transport` behaviour with default Finch adapter — *Validated in Phase 1: Transport & Client Configuration*
- [x] Explicit client configuration (API key, base URL, timeouts, retries, API version, telemetry) — *Validated in Phase 1: Transport & Client Configuration*
- [x] Per-request option overrides (idempotency_key, stripe_account, api_key, stripe_version, expand, timeout) — *Validated in Phase 1: Transport & Client Configuration*
- [x] Structured error model with pattern-matchable error types (auth, card, validation, rate limit, server) — *Validated in Phase 2: Error Handling & Retry*
- [x] Automatic retries with exponential backoff, respecting Stripe-Should-Retry header — *Validated in Phase 2: Error Handling & Retry*
- [x] Idempotency key generation and replay handling — *Validated in Phase 2: Error Handling & Retry*
- [x] SetupIntents — create, retrieve, update, confirm, cancel, list — *Validated in Phase 5: SetupIntents & PaymentMethods*
- [x] PaymentMethods — create, retrieve, update, list, attach, detach — *Validated in Phase 5: SetupIntents & PaymentMethods*
- [x] Refunds — create, retrieve, update, cancel, list — *Validated in Phase 6: Refunds & Checkout*
- [x] Checkout Sessions — create (payment/subscription/setup modes), retrieve, list, expire, search — *Validated in Phase 6: Refunds & Checkout*

### Active

**Foundation (Tier 0)**
- [ ] ~~HTTP transport via pluggable `Transport` behaviour with default Finch adapter~~ *(moved to Validated)*
- [ ] ~~Explicit client configuration~~ *(moved to Validated)*
- [ ] ~~Per-request option overrides~~ *(moved to Validated)*
- [ ] ~~Structured error model with pattern-matchable error types~~ *(moved to Validated)*
- [ ] ~~Automatic retries with exponential backoff~~ *(moved to Validated)*
- [ ] ~~Idempotency key generation and replay handling~~ *(moved to Validated)*
- [ ] Cursor-based list pagination with auto-pagination via Elixir Streams
- [ ] Search pagination support (page-based, eventual consistency caveats documented)
- [ ] Expand support for nested object expansion
- [ ] Raw response access (request ID, status, headers)
- [ ] Telemetry events for request lifecycle
- [ ] API version pinning per library release with per-client and per-request override

**Payments (Tier 1)**
- [ ] PaymentIntents — create, retrieve, update, confirm, capture, cancel, list
- [ ] SetupIntents — create, retrieve, update, confirm, cancel, list
- [ ] PaymentMethods — create, retrieve, update, list, attach, detach
- [ ] Customers — create, retrieve, update, delete, list, search
- [ ] Refunds — create, retrieve, update, list

**Checkout (Tier 2)**
- [ ] Checkout Sessions — create, retrieve, list, expire
- [ ] Payment, subscription, and setup modes
- [ ] Line items, customer prefill, success/cancel URLs

**Webhooks**
- [ ] Webhook signature verification (raw body, tolerance window)
- [ ] Event parsing for snapshot events (v1 style)
- [ ] Phoenix Plug for webhook endpoint with raw body handling

**Developer Experience**
- [ ] ExDoc documentation with guides, examples, and grouped modules
- [ ] Comprehensive specs: integration tests (primary), unit tests for pure logic
- [ ] CI/CD pipeline: GitHub Actions, Release Please, Hex publishing
- [ ] README with <60 second quickstart

### Out of Scope

- Dialyzer/Dialyxir — feels janky, relying on specs + pattern matching instead
- Code generation from OpenAPI spec — v1 is fully handwritten; generation is a future consideration
- Billing (subscriptions, invoices, products, prices) — future milestone
- Connect (platform accounts, transfers, payouts) — future milestone
- Specialist families (Tax, Identity, Treasury, Issuing, Terminal) — future milestone
- Higher-level payment abstractions (like Ruby's `pay` gem) — separate future project
- Thin event support (v2 style) — v1 snapshot events first; v2 in future milestone
- Mobile/frontend SDK — backend only

## Context

**Ecosystem gap:** The Elixir ecosystem lacks a modern, maintained Stripe SDK. `stripity_stripe` is outdated and doesn't reflect Stripe's evolution into a full money-workflow platform with intent-based flows, /v1 and /v2 namespaces, and rich webhook semantics.

**Target users:** Elixir developers building SaaS applications who need to accept payments. Likely working at startups or integrating Stripe at their day job. They want a library that just works, has great docs, and doesn't surprise them.

**Design philosophy:**
- Pure-functional core — processes only when truly needed (connection pooling, not code organization)
- Behaviours for extensibility (transport, retry strategy, JSON codec)
- `{:ok, result} | {:error, reason}` everywhere, bang variants layered on top
- Pattern-matchable returns — domain-rich types, not boolean soup
- Principle of least surprise — Elixir developers feel at home immediately
- Comments for non-obvious mechanics with example input/output shapes
- No circular dependencies between internal modules
- Layered architecture following SRP — each module has one clear purpose

**Testing philosophy:**
- Integration specs are primary — test real behavior at boundaries
- Unit tests for pure logic (request building, response decoding, error normalization)
- High-value specs covering happy path + main error/boundary cases
- Very readable specs — specs are documentation
- Mox or similar for dependency injection in tests (Elixir convention for behaviours)
- Stripe CLI and stripe-mock for integration testing
- Fast CI that catches real problems

**CI/CD philosophy:**
- Automated, AI-friendly maintenance — scan GitHub issues, iterate programmatically
- Fast CI with high signal-to-noise ratio
- Release Please for automated versioning via Conventional Commits
- Hex publishing on release
- Dependabot for dependency updates

**Reference research:** Extensive deep research documents in `/prompts/` covering Stripe API surface, Elixir patterns, SDK comparisons, architecture patterns, and testing strategies.

## Constraints

- **Language**: Elixir 1.15+, OTP 26+
- **License**: MIT
- **No Dialyzer**: Typespecs for documentation only, not enforced
- **HTTP**: Transport behaviour with Finch as default adapter (library doesn't hard-depend on one client)
- **JSON**: Jason (Elixir ecosystem standard)
- **Stripe API**: Pin to current stable version, support per-request override
- **Dependencies**: Minimal — only what's truly needed (Finch, Jason, Telemetry, Plug for webhook)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Skip Dialyzer | Feels janky; specs + pattern matching provide better value | -- Pending |
| Handwritten v1, no codegen | First principles; polish and ergonomics over breadth for initial release | -- Pending |
| Finch as default transport | Modern Elixir HTTP standard; mint-based, performant | -- Pending |
| Transport behaviour | Library shouldn't force HTTP client choice on users | -- Pending |
| LatticeStripe namespace | Unique on Hex, branded, no conflict with existing packages | -- Pending |
| Foundation-first architecture | HTTP/errors/pagination/webhooks must be solid before resource coverage | -- Pending |
| Integration specs primary | Test real behavior at boundaries; mocks hide bugs | -- Pending |
| v1 scope: Foundation + Payments + Checkout + Webhooks | Ship a useful, polished core; Billing/Connect in future milestones | -- Pending |
| MIT license | Maximum adoption, standard for Elixir ecosystem | -- Pending |
| Elixir 1.15+ / OTP 26+ | ~2 year coverage, good balance of features and reach | -- Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-03 after Phase 7 completion — Webhook signature verification, Event struct, Phoenix Plug with CacheBodyReader*
