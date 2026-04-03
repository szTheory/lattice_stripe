# Requirements: LatticeStripe

**Defined:** 2026-03-31
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Transport

- [x] **TRNS-01**: Library provides a Transport behaviour with a single `request/1` callback for HTTP abstraction
- [x] **TRNS-02**: Library ships a default Finch adapter implementing the Transport behaviour
- [x] **TRNS-03**: User can swap HTTP client by implementing the Transport behaviour
- [x] **TRNS-04**: Transport handles form-encoded request bodies (Stripe v1 API format)
- [x] **TRNS-05**: Transport supports configurable timeouts per-request and per-client

### Client Configuration

- [x] **CONF-01**: User can create a client struct with API key, base URL, timeouts, retry policy, API version, and telemetry toggle
- [x] **CONF-02**: Client configuration is validated at creation time with clear error messages (NimbleOptions)
- [x] **CONF-03**: User can override options per-request (idempotency_key, stripe_account, api_key, stripe_version, expand, timeout)
- [x] **CONF-04**: Client struct is a plain struct — no GenServer, no global state
- [x] **CONF-05**: Multiple independent clients can coexist in the same VM

### Error Handling

- [x] **ERRR-01**: All public API functions return `{:ok, result} | {:error, reason}`
- [x] **ERRR-02**: Bang variants (e.g., `create!/2`) are provided that raise on error
- [x] **ERRR-03**: Errors are structured, pattern-matchable structs with type, code, message, param, request_id
- [x] **ERRR-04**: Distinct error types exist for: card errors, invalid request, authentication, rate limit, API errors, idempotency conflicts
- [x] **ERRR-05**: Error structs include HTTP status, full error body, and actionable context for debugging
- [x] **ERRR-06**: Idempotency conflicts (409) surface as a distinct error type with original request_id

### Retry & Idempotency

- [x] **RTRY-01**: Library automatically retries failed requests with exponential backoff and jitter
- [x] **RTRY-02**: Retry logic respects the Stripe-Should-Retry response header
- [x] **RTRY-03**: Library auto-generates idempotency keys for mutating requests and reuses the same key on retry
- [x] **RTRY-04**: User can provide a custom idempotency key per-request
- [x] **RTRY-05**: Retry strategy is pluggable via a RetryStrategy behaviour (custom backoff, circuit breaking)
- [x] **RTRY-06**: Max retries are configurable per-client and per-request

### Pagination

- [x] **PAGE-01**: List endpoints return a struct with `data`, `has_more`, and pagination cursors
- [x] **PAGE-02**: User can paginate manually with `starting_after` and `ending_before` parameters
- [x] **PAGE-03**: Library provides auto-pagination via `Stream.resource/3` that lazily fetches all pages
- [x] **PAGE-04**: Auto-pagination streams are composable with Elixir's Stream and Enum modules
- [x] **PAGE-05**: Search endpoints support page-based pagination with `page` and `next_page` parameters
- [x] **PAGE-06**: Search pagination documents eventual consistency caveats clearly

### Expand & Response

- [x] **EXPD-01**: User can pass `expand` option to expand nested objects on any request
- [ ] **EXPD-02**: Expanded objects are deserialized into typed structs, unexpanded remain as string IDs
- [ ] **EXPD-03**: Nested expansion is supported (e.g., `expand: ["data.customer"]`)
- [x] **EXPD-04**: Response structs expose raw response metadata: request_id, HTTP status, headers
- [ ] **EXPD-05**: Pattern-matchable domain types use atoms for status fields (e.g., `:succeeded`, `:requires_action`)

### API Versioning

- [x] **VERS-01**: Library pins to a specific Stripe API version per release
- [x] **VERS-02**: User can override API version per-client
- [x] **VERS-03**: User can override API version per-request

### Telemetry

- [ ] **TLMT-01**: Library emits `[:lattice_stripe, :request, :start]` event before each HTTP request
- [ ] **TLMT-02**: Library emits `[:lattice_stripe, :request, :stop]` event after each HTTP request with duration, method, path, status, request_id
- [ ] **TLMT-03**: Library emits `[:lattice_stripe, :request, :exception]` event on request failure

### JSON Codec

- [x] **JSON-01**: Library uses Jason as default JSON encoder/decoder
- [x] **JSON-02**: JSON codec is pluggable via a behaviour for users with different JSON libraries

### Payments — PaymentIntents

- [x] **PINT-01**: User can create a PaymentIntent with amount, currency, and payment method options
- [x] **PINT-02**: User can retrieve a PaymentIntent by ID
- [x] **PINT-03**: User can update a PaymentIntent
- [x] **PINT-04**: User can confirm a PaymentIntent
- [x] **PINT-05**: User can capture a PaymentIntent (manual capture flow)
- [x] **PINT-06**: User can cancel a PaymentIntent
- [x] **PINT-07**: User can list PaymentIntents with filters and pagination

### Payments — SetupIntents

- [x] **SINT-01**: User can create a SetupIntent for saving payment methods
- [x] **SINT-02**: User can retrieve a SetupIntent by ID
- [x] **SINT-03**: User can update a SetupIntent
- [x] **SINT-04**: User can confirm a SetupIntent
- [x] **SINT-05**: User can cancel a SetupIntent
- [x] **SINT-06**: User can list SetupIntents with filters and pagination

### Payments — PaymentMethods

- [x] **PMTH-01**: User can create a PaymentMethod
- [x] **PMTH-02**: User can retrieve a PaymentMethod by ID
- [x] **PMTH-03**: User can update a PaymentMethod
- [x] **PMTH-04**: User can list PaymentMethods for a customer
- [x] **PMTH-05**: User can attach a PaymentMethod to a customer
- [x] **PMTH-06**: User can detach a PaymentMethod from a customer

### Payments — Customers

- [x] **CUST-01**: User can create a Customer with email, name, metadata
- [x] **CUST-02**: User can retrieve a Customer by ID
- [x] **CUST-03**: User can update a Customer
- [x] **CUST-04**: User can delete a Customer
- [x] **CUST-05**: User can list Customers with filters and pagination
- [x] **CUST-06**: User can search Customers (search API with page-based pagination)

### Payments — Refunds

- [x] **RFND-01**: User can create a Refund (full or partial) for a PaymentIntent
- [x] **RFND-02**: User can retrieve a Refund by ID
- [x] **RFND-03**: User can update a Refund
- [x] **RFND-04**: User can list Refunds with filters and pagination

### Checkout

- [ ] **CHKT-01**: User can create a Checkout Session in payment mode
- [ ] **CHKT-02**: User can create a Checkout Session in subscription mode
- [ ] **CHKT-03**: User can create a Checkout Session in setup mode
- [ ] **CHKT-04**: User can configure line items, customer prefill, and success/cancel URLs
- [ ] **CHKT-05**: User can retrieve a Checkout Session by ID
- [ ] **CHKT-06**: User can list Checkout Sessions with filters and pagination
- [ ] **CHKT-07**: User can expire an incomplete Checkout Session

### Webhooks

- [ ] **WHBK-01**: User can verify webhook signature against raw request body with timing-safe comparison
- [ ] **WHBK-02**: User can parse verified webhook payload into a typed Event struct
- [ ] **WHBK-03**: User can configure signature tolerance window (default 300 seconds)
- [ ] **WHBK-04**: Library provides a Phoenix Plug that handles raw body extraction and signature verification
- [ ] **WHBK-05**: Webhook Plug documents and solves the Plug.Parsers raw body consumption problem

### Documentation

- [ ] **DOCS-01**: Every public module has @moduledoc with purpose and usage examples
- [ ] **DOCS-02**: Every public function has @doc with arguments, return types, examples, and error cases
- [ ] **DOCS-03**: ExDoc generates grouped, navigable documentation published to HexDocs
- [ ] **DOCS-04**: README provides <60 second quickstart from install to first API call
- [ ] **DOCS-05**: Guides cover: Getting Started, Client Configuration, Payments, Checkout, Webhooks, Error Handling, Testing, Telemetry
- [ ] **DOCS-06**: Non-obvious code has short, readable comments with example input/output data shapes

### Testing

- [ ] **TEST-01**: Integration tests validate real HTTP request/response cycles via stripe-mock
- [ ] **TEST-02**: Unit tests cover pure logic: request building, response decoding, error normalization, pagination
- [ ] **TEST-03**: Mox-based tests validate Transport behaviour contract adherence
- [ ] **TEST-04**: Test helpers available for constructing mock webhook events
- [ ] **TEST-05**: CI runs formatter, compiler warnings, Credo, tests, ExDoc build
- [ ] **TEST-06**: CI tests across Elixir 1.15/OTP 26, 1.17/OTP 27, 1.19/OTP 28

### CI/CD

- [ ] **CICD-01**: GitHub Actions CI runs on PR and push to main (format, compile, credo, test, docs)
- [ ] **CICD-02**: Release Please automates versioning via Conventional Commits
- [ ] **CICD-03**: Hex publishing triggers automatically on release
- [ ] **CICD-04**: Dependabot keeps Mix dependencies and GitHub Actions updated
- [ ] **CICD-05**: stripe-mock runs in CI via Docker for integration tests

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Billing

- **BILL-01**: Products — create, retrieve, update, delete, list
- **BILL-02**: Prices — create, retrieve, update, list
- **BILL-03**: Subscriptions — create, retrieve, update, cancel, pause, resume, list, search
- **BILL-04**: Invoices — create, retrieve, update, finalize, pay, send, void, list, search
- **BILL-05**: Customer Portal Sessions — create with deep-linked flows
- **BILL-06**: Coupons and Promotion Codes
- **BILL-07**: Meters and Meter Events (usage-based billing)
- **BILL-08**: Billing Test Clocks for subscription testing

### Connect

- **CNCT-01**: Account lifecycle (retrieve, update, onboarding)
- **CNCT-02**: Transfers and Payouts
- **CNCT-03**: Destination charges vs separate charge/transfer patterns
- **CNCT-04**: Platform fee handling and reconciliation
- **CNCT-05**: Balance and Balance Transactions

### Advanced

- **ADVN-01**: v2 API namespace support and thin events
- **ADVN-02**: Code generation from Stripe OpenAPI spec for breadth coverage
- **ADVN-03**: Tax, Identity, Treasury, Issuing, Terminal resource coverage

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Dialyzer/Dialyxir | Feels janky; typespecs for documentation only, specs + pattern matching for safety |
| Higher-level billing abstractions (Pay gem style) | Separate project with different dependencies and change cadence |
| Global module-level configuration | Breaks multi-tenancy, test isolation, and concurrent usage |
| Ecto dependency | API client should not force Ecto on users |
| Phoenix dependency (except webhook Plug) | Core library must work outside Phoenix |
| Legacy Charges/Tokens/Sources as primary API | Stripe recommends PaymentIntents; legacy sends wrong signal |
| Mobile/frontend SDK | Backend only; Stripe.js handles the frontend |
| Automatic webhook event routing/dispatch | Belongs in higher-level layer, not API client |
| ExVCR/cassette-based testing | Brittle, hard to maintain; stripe-mock + Mox preferred |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRNS-01 | Phase 1 | Complete |
| TRNS-02 | Phase 1 | Complete |
| TRNS-03 | Phase 1 | Complete |
| TRNS-04 | Phase 1 | Complete |
| TRNS-05 | Phase 1 | Complete |
| CONF-01 | Phase 1 | Complete |
| CONF-02 | Phase 1 | Complete |
| CONF-03 | Phase 1 | Complete |
| CONF-04 | Phase 1 | Complete |
| CONF-05 | Phase 1 | Complete |
| JSON-01 | Phase 1 | Complete |
| JSON-02 | Phase 1 | Complete |
| ERRR-01 | Phase 2 | Complete |
| ERRR-02 | Phase 2 | Complete |
| ERRR-03 | Phase 2 | Complete |
| ERRR-04 | Phase 2 | Complete |
| ERRR-05 | Phase 2 | Complete |
| ERRR-06 | Phase 2 | Complete |
| RTRY-01 | Phase 2 | Complete |
| RTRY-02 | Phase 2 | Complete |
| RTRY-03 | Phase 2 | Complete |
| RTRY-04 | Phase 2 | Complete |
| RTRY-05 | Phase 2 | Complete |
| RTRY-06 | Phase 2 | Complete |
| PAGE-01 | Phase 3 | Complete |
| PAGE-02 | Phase 3 | Complete |
| PAGE-03 | Phase 3 | Complete |
| PAGE-04 | Phase 3 | Complete |
| PAGE-05 | Phase 3 | Complete |
| PAGE-06 | Phase 3 | Complete |
| EXPD-01 | Phase 3 | Complete |
| EXPD-02 | Phase 3 | Pending |
| EXPD-03 | Phase 3 | Pending |
| EXPD-04 | Phase 3 | Complete |
| EXPD-05 | Phase 3 | Pending |
| VERS-01 | Phase 3 | Complete |
| VERS-02 | Phase 3 | Complete |
| VERS-03 | Phase 3 | Complete |
| CUST-01 | Phase 4 | Complete |
| CUST-02 | Phase 4 | Complete |
| CUST-03 | Phase 4 | Complete |
| CUST-04 | Phase 4 | Complete |
| CUST-05 | Phase 4 | Complete |
| CUST-06 | Phase 4 | Complete |
| PINT-01 | Phase 4 | Complete |
| PINT-02 | Phase 4 | Complete |
| PINT-03 | Phase 4 | Complete |
| PINT-04 | Phase 4 | Complete |
| PINT-05 | Phase 4 | Complete |
| PINT-06 | Phase 4 | Complete |
| PINT-07 | Phase 4 | Complete |
| SINT-01 | Phase 5 | Complete |
| SINT-02 | Phase 5 | Complete |
| SINT-03 | Phase 5 | Complete |
| SINT-04 | Phase 5 | Complete |
| SINT-05 | Phase 5 | Complete |
| SINT-06 | Phase 5 | Complete |
| PMTH-01 | Phase 5 | Complete |
| PMTH-02 | Phase 5 | Complete |
| PMTH-03 | Phase 5 | Complete |
| PMTH-04 | Phase 5 | Complete |
| PMTH-05 | Phase 5 | Complete |
| PMTH-06 | Phase 5 | Complete |
| RFND-01 | Phase 6 | Complete |
| RFND-02 | Phase 6 | Complete |
| RFND-03 | Phase 6 | Complete |
| RFND-04 | Phase 6 | Complete |
| CHKT-01 | Phase 6 | Pending |
| CHKT-02 | Phase 6 | Pending |
| CHKT-03 | Phase 6 | Pending |
| CHKT-04 | Phase 6 | Pending |
| CHKT-05 | Phase 6 | Pending |
| CHKT-06 | Phase 6 | Pending |
| CHKT-07 | Phase 6 | Pending |
| WHBK-01 | Phase 7 | Pending |
| WHBK-02 | Phase 7 | Pending |
| WHBK-03 | Phase 7 | Pending |
| WHBK-04 | Phase 7 | Pending |
| WHBK-05 | Phase 7 | Pending |
| TLMT-01 | Phase 8 | Pending |
| TLMT-02 | Phase 8 | Pending |
| TLMT-03 | Phase 8 | Pending |
| TEST-01 | Phase 9 | Pending |
| TEST-02 | Phase 9 | Pending |
| TEST-03 | Phase 9 | Pending |
| TEST-04 | Phase 9 | Pending |
| TEST-05 | Phase 9 | Pending |
| TEST-06 | Phase 9 | Pending |
| DOCS-01 | Phase 10 | Pending |
| DOCS-02 | Phase 10 | Pending |
| DOCS-03 | Phase 10 | Pending |
| DOCS-04 | Phase 10 | Pending |
| DOCS-05 | Phase 10 | Pending |
| DOCS-06 | Phase 10 | Pending |
| CICD-01 | Phase 11 | Pending |
| CICD-02 | Phase 11 | Pending |
| CICD-03 | Phase 11 | Pending |
| CICD-04 | Phase 11 | Pending |
| CICD-05 | Phase 11 | Pending |

**Coverage:**
- v1 requirements: 99 total
- Mapped to phases: 99
- Unmapped: 0

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 after roadmap creation*
