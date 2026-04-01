# Requirements: LatticeStripe

**Defined:** 2026-03-31
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Transport

- [ ] **TRNS-01**: Library provides a Transport behaviour with a single `request/1` callback for HTTP abstraction
- [ ] **TRNS-02**: Library ships a default Finch adapter implementing the Transport behaviour
- [ ] **TRNS-03**: User can swap HTTP client by implementing the Transport behaviour
- [ ] **TRNS-04**: Transport handles form-encoded request bodies (Stripe v1 API format)
- [ ] **TRNS-05**: Transport supports configurable timeouts per-request and per-client

### Client Configuration

- [ ] **CONF-01**: User can create a client struct with API key, base URL, timeouts, retry policy, API version, and telemetry toggle
- [ ] **CONF-02**: Client configuration is validated at creation time with clear error messages (NimbleOptions)
- [ ] **CONF-03**: User can override options per-request (idempotency_key, stripe_account, api_key, stripe_version, expand, timeout)
- [ ] **CONF-04**: Client struct is a plain struct — no GenServer, no global state
- [ ] **CONF-05**: Multiple independent clients can coexist in the same VM

### Error Handling

- [ ] **ERRR-01**: All public API functions return `{:ok, result} | {:error, reason}`
- [ ] **ERRR-02**: Bang variants (e.g., `create!/2`) are provided that raise on error
- [ ] **ERRR-03**: Errors are structured, pattern-matchable structs with type, code, message, param, request_id
- [ ] **ERRR-04**: Distinct error types exist for: card errors, invalid request, authentication, rate limit, API errors, idempotency conflicts
- [ ] **ERRR-05**: Error structs include HTTP status, full error body, and actionable context for debugging
- [ ] **ERRR-06**: Idempotency conflicts (409) surface as a distinct error type with original request_id

### Retry & Idempotency

- [ ] **RTRY-01**: Library automatically retries failed requests with exponential backoff and jitter
- [ ] **RTRY-02**: Retry logic respects the Stripe-Should-Retry response header
- [ ] **RTRY-03**: Library auto-generates idempotency keys for mutating requests and reuses the same key on retry
- [ ] **RTRY-04**: User can provide a custom idempotency key per-request
- [ ] **RTRY-05**: Retry strategy is pluggable via a RetryStrategy behaviour (custom backoff, circuit breaking)
- [ ] **RTRY-06**: Max retries are configurable per-client and per-request

### Pagination

- [ ] **PAGE-01**: List endpoints return a struct with `data`, `has_more`, and pagination cursors
- [ ] **PAGE-02**: User can paginate manually with `starting_after` and `ending_before` parameters
- [ ] **PAGE-03**: Library provides auto-pagination via `Stream.resource/3` that lazily fetches all pages
- [ ] **PAGE-04**: Auto-pagination streams are composable with Elixir's Stream and Enum modules
- [ ] **PAGE-05**: Search endpoints support page-based pagination with `page` and `next_page` parameters
- [ ] **PAGE-06**: Search pagination documents eventual consistency caveats clearly

### Expand & Response

- [ ] **EXPD-01**: User can pass `expand` option to expand nested objects on any request
- [ ] **EXPD-02**: Expanded objects are deserialized into typed structs, unexpanded remain as string IDs
- [ ] **EXPD-03**: Nested expansion is supported (e.g., `expand: ["data.customer"]`)
- [ ] **EXPD-04**: Response structs expose raw response metadata: request_id, HTTP status, headers
- [ ] **EXPD-05**: Pattern-matchable domain types use atoms for status fields (e.g., `:succeeded`, `:requires_action`)

### API Versioning

- [ ] **VERS-01**: Library pins to a specific Stripe API version per release
- [ ] **VERS-02**: User can override API version per-client
- [ ] **VERS-03**: User can override API version per-request

### Telemetry

- [ ] **TLMT-01**: Library emits `[:lattice_stripe, :request, :start]` event before each HTTP request
- [ ] **TLMT-02**: Library emits `[:lattice_stripe, :request, :stop]` event after each HTTP request with duration, method, path, status, request_id
- [ ] **TLMT-03**: Library emits `[:lattice_stripe, :request, :exception]` event on request failure

### JSON Codec

- [ ] **JSON-01**: Library uses Jason as default JSON encoder/decoder
- [ ] **JSON-02**: JSON codec is pluggable via a behaviour for users with different JSON libraries

### Payments — PaymentIntents

- [ ] **PINT-01**: User can create a PaymentIntent with amount, currency, and payment method options
- [ ] **PINT-02**: User can retrieve a PaymentIntent by ID
- [ ] **PINT-03**: User can update a PaymentIntent
- [ ] **PINT-04**: User can confirm a PaymentIntent
- [ ] **PINT-05**: User can capture a PaymentIntent (manual capture flow)
- [ ] **PINT-06**: User can cancel a PaymentIntent
- [ ] **PINT-07**: User can list PaymentIntents with filters and pagination

### Payments — SetupIntents

- [ ] **SINT-01**: User can create a SetupIntent for saving payment methods
- [ ] **SINT-02**: User can retrieve a SetupIntent by ID
- [ ] **SINT-03**: User can update a SetupIntent
- [ ] **SINT-04**: User can confirm a SetupIntent
- [ ] **SINT-05**: User can cancel a SetupIntent
- [ ] **SINT-06**: User can list SetupIntents with filters and pagination

### Payments — PaymentMethods

- [ ] **PMTH-01**: User can create a PaymentMethod
- [ ] **PMTH-02**: User can retrieve a PaymentMethod by ID
- [ ] **PMTH-03**: User can update a PaymentMethod
- [ ] **PMTH-04**: User can list PaymentMethods for a customer
- [ ] **PMTH-05**: User can attach a PaymentMethod to a customer
- [ ] **PMTH-06**: User can detach a PaymentMethod from a customer

### Payments — Customers

- [ ] **CUST-01**: User can create a Customer with email, name, metadata
- [ ] **CUST-02**: User can retrieve a Customer by ID
- [ ] **CUST-03**: User can update a Customer
- [ ] **CUST-04**: User can delete a Customer
- [ ] **CUST-05**: User can list Customers with filters and pagination
- [ ] **CUST-06**: User can search Customers (search API with page-based pagination)

### Payments — Refunds

- [ ] **RFND-01**: User can create a Refund (full or partial) for a PaymentIntent
- [ ] **RFND-02**: User can retrieve a Refund by ID
- [ ] **RFND-03**: User can update a Refund
- [ ] **RFND-04**: User can list Refunds with filters and pagination

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
| TRNS-01 | TBD | Pending |
| TRNS-02 | TBD | Pending |
| TRNS-03 | TBD | Pending |
| TRNS-04 | TBD | Pending |
| TRNS-05 | TBD | Pending |
| CONF-01 | TBD | Pending |
| CONF-02 | TBD | Pending |
| CONF-03 | TBD | Pending |
| CONF-04 | TBD | Pending |
| CONF-05 | TBD | Pending |
| ERRR-01 | TBD | Pending |
| ERRR-02 | TBD | Pending |
| ERRR-03 | TBD | Pending |
| ERRR-04 | TBD | Pending |
| ERRR-05 | TBD | Pending |
| ERRR-06 | TBD | Pending |
| RTRY-01 | TBD | Pending |
| RTRY-02 | TBD | Pending |
| RTRY-03 | TBD | Pending |
| RTRY-04 | TBD | Pending |
| RTRY-05 | TBD | Pending |
| RTRY-06 | TBD | Pending |
| PAGE-01 | TBD | Pending |
| PAGE-02 | TBD | Pending |
| PAGE-03 | TBD | Pending |
| PAGE-04 | TBD | Pending |
| PAGE-05 | TBD | Pending |
| PAGE-06 | TBD | Pending |
| EXPD-01 | TBD | Pending |
| EXPD-02 | TBD | Pending |
| EXPD-03 | TBD | Pending |
| EXPD-04 | TBD | Pending |
| EXPD-05 | TBD | Pending |
| VERS-01 | TBD | Pending |
| VERS-02 | TBD | Pending |
| VERS-03 | TBD | Pending |
| TLMT-01 | TBD | Pending |
| TLMT-02 | TBD | Pending |
| TLMT-03 | TBD | Pending |
| JSON-01 | TBD | Pending |
| JSON-02 | TBD | Pending |
| PINT-01 | TBD | Pending |
| PINT-02 | TBD | Pending |
| PINT-03 | TBD | Pending |
| PINT-04 | TBD | Pending |
| PINT-05 | TBD | Pending |
| PINT-06 | TBD | Pending |
| PINT-07 | TBD | Pending |
| SINT-01 | TBD | Pending |
| SINT-02 | TBD | Pending |
| SINT-03 | TBD | Pending |
| SINT-04 | TBD | Pending |
| SINT-05 | TBD | Pending |
| SINT-06 | TBD | Pending |
| PMTH-01 | TBD | Pending |
| PMTH-02 | TBD | Pending |
| PMTH-03 | TBD | Pending |
| PMTH-04 | TBD | Pending |
| PMTH-05 | TBD | Pending |
| PMTH-06 | TBD | Pending |
| CUST-01 | TBD | Pending |
| CUST-02 | TBD | Pending |
| CUST-03 | TBD | Pending |
| CUST-04 | TBD | Pending |
| CUST-05 | TBD | Pending |
| CUST-06 | TBD | Pending |
| RFND-01 | TBD | Pending |
| RFND-02 | TBD | Pending |
| RFND-03 | TBD | Pending |
| RFND-04 | TBD | Pending |
| CHKT-01 | TBD | Pending |
| CHKT-02 | TBD | Pending |
| CHKT-03 | TBD | Pending |
| CHKT-04 | TBD | Pending |
| CHKT-05 | TBD | Pending |
| CHKT-06 | TBD | Pending |
| CHKT-07 | TBD | Pending |
| WHBK-01 | TBD | Pending |
| WHBK-02 | TBD | Pending |
| WHBK-03 | TBD | Pending |
| WHBK-04 | TBD | Pending |
| WHBK-05 | TBD | Pending |
| DOCS-01 | TBD | Pending |
| DOCS-02 | TBD | Pending |
| DOCS-03 | TBD | Pending |
| DOCS-04 | TBD | Pending |
| DOCS-05 | TBD | Pending |
| DOCS-06 | TBD | Pending |
| TEST-01 | TBD | Pending |
| TEST-02 | TBD | Pending |
| TEST-03 | TBD | Pending |
| TEST-04 | TBD | Pending |
| TEST-05 | TBD | Pending |
| TEST-06 | TBD | Pending |
| CICD-01 | TBD | Pending |
| CICD-02 | TBD | Pending |
| CICD-03 | TBD | Pending |
| CICD-04 | TBD | Pending |
| CICD-05 | TBD | Pending |

**Coverage:**
- v1 requirements: 82 total
- Mapped to phases: 0
- Unmapped: 82 ⚠️

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 after initial definition*
