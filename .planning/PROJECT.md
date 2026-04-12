# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe aims to be the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## Current Milestone: v2.0 Billing & Connect

**Goal:** Close `lattice_stripe`'s Billing and Connect coverage gap so it's a complete Elixir Stripe SDK — the full Billing tier (Products, Prices, Subscriptions, Invoices, Schedules, Coupons, PromotionCodes, Test Clocks) and Stripe Connect (Accounts, Links, Transfers, Payouts, Balances) ship together, alongside cross-cutting SDK ergonomics (EventType catalog, Search pagination helper, proration discipline).

**Target features:**
- Products, Prices, Coupons, PromotionCodes (Phase 12)
- Billing Test Clocks (Phase 13, pulled forward to enable subscription lifecycle testing)
- Invoices + Invoice Line Items with `upcoming/2` proration preview (Phase 14)
- Subscriptions with pause/resume/cancel, validated `proration_behavior` enum, `require_explicit_proration` config flag, documented status lifecycle traps (Phase 15)
- Subscription Schedules for planned upgrades/downgrades (Phase 16)
- Stripe Connect — Accounts, AccountLinks, LoginLinks (Phase 17)
- Stripe Connect — Transfers, Payouts, Balance, BalanceTransactions (Phase 18)
- Cross-cutting: `LatticeStripe.EventType` catalog, `LatticeStripe.Search.stream!/3`, `LatticeStripe.Billing.ProrationBehavior` validator, Billing + Connect guides, milestone smoke test (Phase 19)

**Release target:** Hex `lattice_stripe` v0.3.0 after Phase 19. Optional v0.3.0-rc1 pre-release after Phase 16 to unblock downstream consumers (notably Accrue, a higher-level Elixir billing library that depends on `lattice_stripe` as a canary consumer — see plan at `~/.claude/plans/steady-sleeping-blum.md`).

**Design philosophy for this milestone:** `lattice_stripe` remains *the* Elixir Stripe SDK — decisions prioritize (1) consistency with v1 patterns, (2) completeness/coherence as an SDK, (3) great DX for any caller, (4) correctness around Stripe footguns, (5) downstream unblock only as a release-sequencing concern. Resources are added because Stripe's data model has them, not because one consumer asked. See `~/.claude/plans/steady-sleeping-blum.md` "Design Philosophy" section for the full framing.

## Requirements

### Validated

**Foundation**
- ✓ HTTP transport via pluggable `Transport` behaviour with default Finch adapter — v1.0 (Phase 1)
- ✓ Explicit client configuration (API key, base URL, timeouts, retries, API version, telemetry) — v1.0 (Phase 1)
- ✓ Per-request option overrides (idempotency_key, stripe_account, api_key, stripe_version, expand, timeout) — v1.0 (Phase 1)
- ✓ Structured error model with pattern-matchable error types (auth, card, validation, rate limit, server, idempotency_error) — v1.0 (Phase 2)
- ✓ Automatic retries with exponential backoff, respecting `Stripe-Should-Retry` header — v1.0 (Phase 2)
- ✓ Idempotency key generation and replay handling (auto `idk_ltc_<uuid4>`, user-overridable, retry-safe) — v1.0 (Phase 2)
- ✓ Cursor-based list pagination with auto-pagination via Elixir Streams — v1.0 (Phase 3)
- ✓ Raw response access (request ID, status, headers via `Response` struct) — v1.0 (Phase 3)
- ✓ API version pinning per library release with per-client and per-request override — v1.0 (Phase 3)
- ✓ Telemetry events for request lifecycle — v1.0 (Phase 8)

**Payments tier**
- ✓ Customers — create, retrieve, update, delete, list, search — v1.0 (Phase 4)
- ✓ PaymentIntents — create, retrieve, update, confirm, capture, cancel, list — v1.0 (Phase 4)
- ✓ SetupIntents — create, retrieve, update, confirm, cancel, verify_microdeposits, list — v1.0 (Phase 5)
- ✓ PaymentMethods — create, retrieve, update, list, attach, detach — v1.0 (Phase 5)
- ✓ Refunds — create, retrieve, update, cancel, list — v1.0 (Phase 6)
- ✓ Checkout Sessions — create (payment/subscription/setup modes), retrieve, list, expire, search, line items — v1.0 (Phase 6)

**Webhooks**
- ✓ Webhook signature verification with raw body capture, multi-secret rotation, configurable tolerance window — v1.0 (Phase 7)
- ✓ Event parsing for snapshot events (v1 style) — v1.0 (Phase 7)
- ✓ Phoenix Plug for webhook endpoint with raw body handling (`CacheBodyReader`) — v1.0 (Phase 7)

**Developer Experience**
- ✓ Comprehensive specs: integration tests (primary) via stripe-mock, unit tests via Mox — v1.0 (Phase 9)
- ✓ ExDoc documentation with guides, examples, and grouped modules — v1.0 (Phase 10)
- ✓ README with <60 second quickstart — v1.0 (Phase 10)
- ✓ CI/CD pipeline: GitHub Actions, Release Please, Hex publishing, Dependabot — v1.0 (Phase 11)

### Active

Defined for v2.0 via `/gsd-new-milestone`. See `.planning/REQUIREMENTS.md` (generated by the milestone workflow).

### Known Gaps (from v1.0)

Deferred during v1 execution, deliberately shipped without implementation. Expand support exists at the request-option level (raw paths passed through to Stripe), but typed deserialization was deferred:

- `EXPD-02` — Expanded objects are deserialized into typed structs, unexpanded remain as string IDs
- `EXPD-03` — Nested expansion (e.g., `expand: ["data.customer"]`)
- `EXPD-05` — Atom-based status fields on domain types (e.g., `:succeeded`, `:requires_action`)

Promote to a future milestone when typed-struct deserialization becomes a blocker.

### Out of Scope

- Dialyzer/Dialyxir — feels janky, relying on specs + pattern matching instead
- Code generation from OpenAPI spec — v1 is fully handwritten; generation is a future consideration (ADVN-02, deferred)
- Specialist families (Tax, Identity, Treasury, Issuing, Terminal) — ADVN-03, deferred beyond v2.0
- Higher-level payment abstractions (like Ruby's `pay` gem) — separate future project (in fact being built as Accrue, which depends on `lattice_stripe`)
- Thin event support (v2 API namespace) — v1 snapshot events first; v2 in future milestone (ADVN-01)
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
| Skip Dialyzer | Feels janky; specs + pattern matching provide better value | ✓ Good — v1 shipped clean with pattern-matchable error types, no Dialyzer friction |
| Handwritten v1, no codegen | First principles; polish and ergonomics over breadth for initial release | ✓ Good — v1 resource modules are consistent and ergonomic; codegen remains future consideration (ADVN-02) |
| Finch as default transport | Modern Elixir HTTP standard; mint-based, performant | ✓ Good — Finch performs well, no transport issues in v1 |
| Transport behaviour | Library shouldn't force HTTP client choice on users | ✓ Good — behaviour proved useful for Mox-based unit tests with `async: true` |
| LatticeStripe namespace | Unique on Hex, branded, no conflict with existing packages | ✓ Good — `lattice_stripe` published to Hex without conflict |
| Foundation-first architecture | HTTP/errors/pagination/webhooks must be solid before resource coverage | ✓ Good — Phases 12–19 (v2) reuse v1 foundation unchanged; zero behaviour additions planned |
| Integration specs primary | Test real behavior at boundaries; mocks hide bugs | ✓ Good — stripe-mock caught several param-shape bugs that Mox unit tests missed |
| v1 scope: Foundation + Payments + Checkout + Webhooks | Ship a useful, polished core; Billing/Connect in future milestones | ✓ Good — v1 shipped as v0.2.0; v2 now adds Billing + Connect |
| MIT license | Maximum adoption, standard for Elixir ecosystem | ✓ Good |
| Elixir 1.15+ / OTP 26+ | ~2 year coverage, good balance of features and reach | ✓ Good — CI matrix runs 1.15/1.17/1.19 × 26/27/28 cleanly |
| v2 proration_behavior as optional-but-validated | SDK parity with Stripe's own libs; opinionated strictness available via `require_explicit_proration` client flag | — Pending v2 execution |
| v2 split Connect into 2 phases (17 Accounts/Links, 18 Transfers/Payouts/Balance) | Matches Stripe's data model; phase 17 proves `stripe_account` header plumbing before transfer semantics layer on top | — Pending v2 execution |
| v2 TestClocks pulled forward to Phase 13 | Enables time-travel integration tests for Phases 14–16 (Invoices, Subscriptions, Schedules) | — Pending v2 execution |
| v2 LatticeStripe.EventType catalog is exhaustive (not Accrue-scoped) | SDK serves all consumers, not one; auto-verify against OpenAPI spec during Phase 19 | — Pending v2 execution |

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
*Last updated: 2026-04-12 after v1.0 milestone completion — v1.0 Foundation & Payments archived as Hex `lattice_stripe` v0.2.0. v2.0 Billing & Connect milestone initialized.*
