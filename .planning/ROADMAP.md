# Roadmap: LatticeStripe

## Overview

LatticeStripe delivers a production-grade Elixir Stripe SDK by building from the inside out: a solid foundation layer (transport, config, errors, retry), then resource modules in dependency order (Customers first to validate the pattern, PaymentIntents for lifecycle complexity), then the remaining payment resources, Checkout, independent Webhooks, and finally developer experience layers (telemetry, testing infrastructure, documentation, CI/CD). Every phase delivers a verifiable capability that subsequent phases build on.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Transport & Client Configuration** - HTTP abstraction layer, client struct, and JSON codec (completed 2026-04-01)
- [ ] **Phase 2: Error Handling & Retry** - Structured errors, automatic retries, and idempotency
- [ ] **Phase 3: Pagination & Response** - List pagination, auto-pagination streams, expand support, API versioning
- [ ] **Phase 4: Customers & PaymentIntents** - First two resource modules to validate the foundation pattern
- [x] **Phase 5: SetupIntents & PaymentMethods** - Intent-based and method management resources (completed 2026-04-02)
- [x] **Phase 6: Refunds & Checkout** - Refund operations and Checkout Sessions (completed 2026-04-03)
- [ ] **Phase 7: Webhooks** - Signature verification, event parsing, and Phoenix Plug
- [ ] **Phase 8: Telemetry & Observability** - Request lifecycle events wired through the stack
- [ ] **Phase 9: Testing Infrastructure** - Integration tests, unit tests, Mox contracts, test helpers
- [ ] **Phase 10: Documentation & Guides** - ExDoc, moduledocs, guides, README quickstart
- [ ] **Phase 11: CI/CD & Release** - GitHub Actions, Release Please, Hex publishing, Dependabot

## Phase Details

### Phase 1: Transport & Client Configuration
**Goal**: Developers can create a configured client and make raw HTTP requests to Stripe's API
**Depends on**: Nothing (first phase)
**Requirements**: TRNS-01, TRNS-02, TRNS-03, TRNS-04, TRNS-05, CONF-01, CONF-02, CONF-03, CONF-04, CONF-05, JSON-01, JSON-02
**Success Criteria** (what must be TRUE):
  1. Developer can create a LatticeStripe client with API key and custom options, and the client validates configuration at creation time
  2. Developer can make a raw authenticated HTTP request to Stripe via the default Finch transport and receive a response
  3. Developer can swap the HTTP transport by implementing the Transport behaviour without modifying library code
  4. Multiple independent clients with different API keys can coexist in the same BEAM VM
  5. Request bodies are correctly form-encoded for Stripe's v1 API format
**Plans:** 5/5 plans complete

Plans:
- [x] 01-01-PLAN.md — Project scaffolding, dependencies, test infrastructure
- [x] 01-02-PLAN.md — JSON codec behaviour + Jason adapter + form encoder
- [x] 01-03-PLAN.md — Transport behaviour + Error struct + Request struct
- [x] 01-04-PLAN.md — NimbleOptions config validation + Finch adapter
- [x] 01-05-PLAN.md — Client module with telemetry + comprehensive tests

### Phase 2: Error Handling & Retry
**Goal**: All API calls return structured, pattern-matchable results with automatic retry safety
**Depends on**: Phase 1
**Requirements**: ERRR-01, ERRR-02, ERRR-03, ERRR-04, ERRR-05, ERRR-06, RTRY-01, RTRY-02, RTRY-03, RTRY-04, RTRY-05, RTRY-06
**Success Criteria** (what must be TRUE):
  1. Every public API function returns {:ok, result} | {:error, reason} with bang variants that raise
  2. Developer can pattern match on distinct error types (card, auth, rate limit, validation, server, idempotency conflict) to handle each case differently
  3. Failed requests are automatically retried with exponential backoff, respecting the Stripe-Should-Retry header, and the same idempotency key is reused across retries
  4. Developer can provide a custom idempotency key, configure max retries, or plug in a custom RetryStrategy behaviour
  5. Error structs carry HTTP status, request_id, full error body, and actionable debugging context
**Plans:** 3 plans

Plans:
- [x] 02-01-PLAN.md — Error struct enrichment, idempotency_error type, String.Chars, Json non-bang callbacks
- [x] 02-02-PLAN.md — RetryStrategy behaviour + Default implementation, Config schema updates
- [x] 02-03-PLAN.md — Client retry loop, auto-idempotency keys, bang variant, non-JSON handling

### Phase 3: Pagination & Response
**Goal**: Developers can paginate through lists, auto-paginate with Streams, expand nested objects, and pin API versions
**Depends on**: Phase 2
**Requirements**: PAGE-01, PAGE-02, PAGE-03, PAGE-04, PAGE-05, PAGE-06, EXPD-01, EXPD-02, EXPD-03, EXPD-04, EXPD-05, VERS-01, VERS-02, VERS-03
**Success Criteria** (what must be TRUE):
  1. List endpoints return a struct with data, has_more, and cursors; developer can paginate manually with starting_after/ending_before
  2. Developer can auto-paginate any list endpoint using Elixir Streams that lazily fetch pages and compose with Stream/Enum
  3. Search endpoints support page-based pagination with next_page, and documentation clearly states eventual consistency caveats
  4. Developer can pass expand option to expand nested objects into typed structs, including nested expansion paths
  5. Library pins to a specific Stripe API version per release, overridable per-client and per-request
**Plans:** 2/3 plans executed

Plans:
- [x] 03-01-PLAN.md — Response struct, List struct, api_version/0, Config update, User-Agent enhancement
- [x] 03-02-PLAN.md — Client.request/2 Response wrapping, list detection, existing test updates
- [x] 03-03-PLAN.md — List auto-pagination streaming (stream!/2, stream/2)

### Phase 4: Customers & PaymentIntents
**Goal**: Developers can manage Customers and PaymentIntents end-to-end, validating the resource module pattern
**Depends on**: Phase 3
**Requirements**: CUST-01, CUST-02, CUST-03, CUST-04, CUST-05, CUST-06, PINT-01, PINT-02, PINT-03, PINT-04, PINT-05, PINT-06, PINT-07
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, delete, and list Customers with filters and pagination
  2. Developer can search Customers using the Search API with page-based pagination
  3. Developer can create, retrieve, update, confirm, capture, cancel, and list PaymentIntents
  4. All Customer and PaymentIntent operations work with expand, idempotency keys, per-request overrides, and auto-pagination
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md — Customer struct, CRUD, list, search, stream, bang variants + tests
- [x] 04-02-PLAN.md — PaymentIntent struct, CRUD, confirm/capture/cancel, list, stream + tests

### Phase 5: SetupIntents & PaymentMethods
**Goal**: Developers can save payment methods for future use via SetupIntents and manage PaymentMethod lifecycle
**Depends on**: Phase 4
**Requirements**: SINT-01, SINT-02, SINT-03, SINT-04, SINT-05, SINT-06, PMTH-01, PMTH-02, PMTH-03, PMTH-04, PMTH-05, PMTH-06
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, confirm, cancel, and list SetupIntents
  2. Developer can create, retrieve, update, and list PaymentMethods for a customer
  3. Developer can attach a PaymentMethod to a customer and detach it
  4. All operations follow the same ergonomic pattern established by Customers and PaymentIntents
**Plans:** 2/2 plans complete

Plans:
- [x] 05-01-PLAN.md — Extract Resource helpers, refactor Customer/PI, add PI search, build SetupIntent + tests
- [x] 05-02-PLAN.md — PaymentMethod struct, CRUD, attach/detach, validated list, stream + tests

### Phase 6: Refunds & Checkout
**Goal**: Developers can issue refunds and create Checkout Sessions in all modes
**Depends on**: Phase 4
**Requirements**: RFND-01, RFND-02, RFND-03, RFND-04, CHKT-01, CHKT-02, CHKT-03, CHKT-04, CHKT-05, CHKT-06, CHKT-07
**Success Criteria** (what must be TRUE):
  1. Developer can create full or partial refunds for a PaymentIntent, and retrieve, update, and list refunds
  2. Developer can create a Checkout Session in payment, subscription, or setup mode with line items, customer prefill, and success/cancel URLs
  3. Developer can retrieve, list, and expire Checkout Sessions
**Plans:** 2/2 plans complete

Plans:
- [x] 06-01-PLAN.md — Fixture extraction (Customer, PI, SI, PM) + Refund resource (create, retrieve, update, cancel, list, stream + tests)
- [x] 06-02-PLAN.md — Checkout.Session (create 3 modes, retrieve, list, expire, search, stream) + LineItem struct + list_line_items + stream_line_items + tests

### Phase 7: Webhooks
**Goal**: Developers can securely receive and verify Stripe webhook events in their Phoenix application
**Depends on**: Phase 1
**Requirements**: WHBK-01, WHBK-02, WHBK-03, WHBK-04, WHBK-05
**Success Criteria** (what must be TRUE):
  1. Developer can verify a webhook signature against the raw request body using timing-safe comparison
  2. Developer can parse a verified webhook payload into a typed Event struct
  3. Developer can configure the signature tolerance window (default 300s)
  4. Library provides a Phoenix Plug that handles raw body extraction and signature verification, with clear documentation of the Plug.Parsers raw body consumption problem and its solution
**Plans:** 2 plans

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD

### Phase 8: Telemetry & Observability
**Goal**: Developers can observe and monitor all Stripe API interactions via standard Telemetry events
**Depends on**: Phase 2
**Requirements**: TLMT-01, TLMT-02, TLMT-03
**Success Criteria** (what must be TRUE):
  1. Library emits [:lattice_stripe, :request, :start] before each HTTP request with method, path, and metadata
  2. Library emits [:lattice_stripe, :request, :stop] after each request with duration, status, and request_id
  3. Library emits [:lattice_stripe, :request, :exception] on request failure with error details
**Plans:** 2 plans

Plans:
- [ ] 08-01: TBD

### Phase 9: Testing Infrastructure
**Goal**: The library has comprehensive test coverage and provides test helpers for downstream users
**Depends on**: Phase 6, Phase 7
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06
**Success Criteria** (what must be TRUE):
  1. Integration tests validate real HTTP request/response cycles via stripe-mock for all resource modules
  2. Unit tests cover pure logic: request building, response decoding, error normalization, pagination cursor management
  3. Mox-based tests verify Transport behaviour contract adherence
  4. LatticeStripe.Testing module provides helpers for constructing mock webhook events
  5. Test suite passes formatter, compiler warnings, Credo, tests, and ExDoc build checks
**Plans:** 2 plans

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD

### Phase 10: Documentation & Guides
**Goal**: Every public API is documented and developers can go from install to first API call in under 60 seconds
**Depends on**: Phase 6, Phase 7, Phase 8
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06
**Success Criteria** (what must be TRUE):
  1. Every public module has @moduledoc with purpose and usage examples; every public function has @doc with arguments, return types, examples, and error cases
  2. ExDoc generates grouped, navigable documentation that can be published to HexDocs
  3. README provides a quickstart that takes a developer from mix dependency to first Stripe API call in under 60 seconds
  4. Guides cover: Getting Started, Client Configuration, Payments, Checkout, Webhooks, Error Handling, Testing, and Telemetry
  5. Non-obvious code has short readable comments with example input/output data shapes
**Plans:** 2 plans

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

### Phase 11: CI/CD & Release
**Goal**: The library has automated CI, versioning, and publishing so releases are one-click
**Depends on**: Phase 9
**Requirements**: CICD-01, CICD-02, CICD-03, CICD-04, CICD-05
**Success Criteria** (what must be TRUE):
  1. GitHub Actions CI runs format, compile warnings, Credo, tests, and doc build on every PR and push to main
  2. CI tests across the Elixir/OTP matrix: 1.15/OTP 26, 1.17/OTP 27, 1.19/OTP 28 with stripe-mock via Docker
  3. Release Please automates version bumps via Conventional Commits and Hex publishing triggers on release
  4. Dependabot keeps Mix dependencies and GitHub Actions updated automatically
**Plans:** 2 plans

Plans:
- [ ] 11-01: TBD
- [ ] 11-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5/6/7 (5 and 6 after 4; 7 after 1) -> 8 -> 9 -> 10 -> 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Transport & Client Configuration | 5/5 | Complete   | 2026-04-01 |
| 2. Error Handling & Retry | 0/3 | Planned | - |
| 3. Pagination & Response | 2/3 | In Progress|  |
| 4. Customers & PaymentIntents | 0/2 | Planned | - |
| 5. SetupIntents & PaymentMethods | 2/2 | Complete   | 2026-04-02 |
| 6. Refunds & Checkout | 2/2 | Complete   | 2026-04-03 |
| 7. Webhooks | 0/0 | Not started | - |
| 8. Telemetry & Observability | 0/0 | Not started | - |
| 9. Testing Infrastructure | 0/0 | Not started | - |
| 10. Documentation & Guides | 0/0 | Not started | - |
| 11. CI/CD & Release | 0/0 | Not started | - |
