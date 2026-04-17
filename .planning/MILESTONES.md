# Milestones

## v1.2 Production Hardening & DX (Shipped: 2026-04-17)

**Phases completed:** 10 phases, 24 plans, 14 tasks

**Key accomplishments:**

- Compile-time ObjectTypes registry with 31 Stripe object strings, 4-clause maybe_deserialize/1 dispatch, and 10 passing unit tests — foundational module for all Phase 22 expand deserialization
- PaymentIntent (`lib/lattice_stripe/payment_intent.ex`)
- Payout (`lib/lattice_stripe/payout.ex`)
- 1. [Rule 1 - Bug] Elixir `if` keyword argument ambiguity in struct literals
- One-liner:
- BillingPortal.Configuration resource module with full CRUDL (create/retrieve/update/list/stream!) plus bang variants, typed features dispatch to Plan 01 sub-structs, and 16 passing Mox-based unit tests
- ObjectTypes expand dispatch for billing_portal.configuration wired into Session.from_map/1 with is_map guard, ExDoc Customer Portal group extended to 12 modules, and stripe-mock integration test added for full CRUDL lifecycle
- Task 1 — client.ex 3-tuple return:
- One-liner:
- One-liner:
- Config tests (8 new):
- One-liner:
- guides/performance.md
- 1. [Rule 1 - Bug] Fixed :fuse threshold semantics in integration test
- One-liner:
- One-liner:
- One-liner:
- 1. [Rule 1 - Bug] Fixed invalid defstruct keyword ordering in Phase inner module
- `LatticeStripe.ObjectTypes.object_map/0`
- `Mix.Tasks.LatticeStripe.CheckDrift`
- One-liner:
- One-liner:

---

## v1.0 v1.0 — Foundation + Billing + Connect + 1.0 Release (Shipped: 2026-04-13)

**Phases completed:** 14 phases, 47 plans, 61 tasks

**Key accomplishments:**

- Mix project with Finch, Jason, Telemetry, NimbleOptions, Mox, Credo -- compiles and tests clean
- Jason-backed JSON codec behaviour and recursive Stripe bracket-notation form encoder with 23 tests covering all edge cases
- Transport behaviour with typed request/1 callback, Request struct as pure data pipeline, and Error struct with Stripe error type parsing and pattern-matchable :type atoms
- LatticeStripe.Client struct with new!/1, new/1, and request/2 — ties all Phase 1 modules together with headers, form encoding, JSON decoding, error mapping, and telemetry span
- 10-field Error struct with idempotency_error type, String.Chars protocol, and 4-callback Json behaviour for graceful non-JSON response handling in the retry loop
- RetryStrategy behaviour with Default implementation: Stripe-Should-Retry authoritative, Retry-After capped at 5s, exponential backoff with jitter, 409 non-retriable
- One-liner:
- Response struct with Access/Inspect, List struct with from_json/Inspect, api_version/0 pinned to '2026-03-25.dahlia', and User-Agent enhanced with OTP version and X-Stripe-Client-User-Agent header
- Client.request/2 now returns {:ok, %Response{}} for all 2xx responses, with automatic %List{} detection for Stripe list/search_result objects and params/opts threading for pagination
- Lazy Stream.resource/3 auto-pagination for both from-scratch (stream!/2) and from-existing-list (stream/2) with cursor, backward, and search pagination modes
- One-liner:
- PaymentIntent resource module with confirm/capture/cancel action verbs, custom Inspect hiding client_secret, and 24 Mox-based tests
- Shared Resource helper module extracted, Customer/PaymentIntent refactored to use it, SetupIntent built with full lifecycle (CRUD, confirm, cancel, verify_microdeposits, list, stream!) and 26 tests — 323 total tests passing
- PaymentMethod resource built with CRUD, attach/detach, customer-validated list/stream, bang variants, conditional card Inspect, from_map/1 — 27 tests; 350 total tests passing
- 1. [Rule 1 - Bug] Double-replacement of client_secret assertion strings
- One-liner:
- One-liner:
- One-liner:
- 1. [Rule 1 - Bug] Fixed @doc override warning
- Webhook verification emits :telemetry.span events via webhook_verify_span/2, attach_default_logger/1 produces structured "POST /v1/customers => 200 in 145ms (1 attempt, req_xxx)" log lines, and 30 metadata contract tests treat telemetry event schemas as public API
- Integration test infrastructure with 6 resource test files (Customer, PaymentIntent, SetupIntent, PaymentMethod, Refund, Checkout.Session) using real Finch HTTP to stripe-mock, excluded from default test runs
- mix.exs changes:
- 55 new edge case tests across 5 test files covering FormEncoder encoding, Error normalization, List cursor extraction, Transport behaviour contract, and Telemetry metadata exhaustiveness
- 1. [Rule 3 - Blocking] Created minimal cheatsheet stub before Task 2
- Five complete developer guides covering the full LatticeStripe integration path — install to first PaymentIntent, all Client options, complete payment lifecycle, Checkout in 3 modes, and webhook setup with Phoenix integration
- One-liner:
- GitHub Actions CI with 3 parallel jobs (lint/test-matrix/integration), complete Hex package metadata, MIT LICENSE, and mix_audit security scanning
- Release Please manifest workflow + Hex.pm auto-publish + Dependabot for mix/github-actions with patch-only auto-merge
- CONTRIBUTING, SECURITY, YAML issue templates, and PR checklist template for professional OSS repo infrastructure
- One-liner:
- 1. [Rule 3 - Blocking] Created account fixture (test/support/fixtures/account.ex)
- One-liner:
- One-liner:
- One-liner:
- `LatticeStripe.Charge`
- `LatticeStripe.Transfer`
- LatticeStripe.Payout full CRUDL + D-03 canonical cancel/reverse with %Payout.TraceId{} typed nested struct decoded from trace_id field.
- None
- 1. [Rule 3 - Blocking] Pre-existing `mix format` failures in 10 Phase 17/18 test files
- Found during:
- 1. [Rule 1 - Bug] api_stability.md hidden-module backtick warnings
- 1. [Rule 1 — Acceptance-criterion miscount] "Three elixir fences inside Quick Start"
- 1. [Scope-adjustment — worktree-bounded execution] Task 2 split into two halves

---
