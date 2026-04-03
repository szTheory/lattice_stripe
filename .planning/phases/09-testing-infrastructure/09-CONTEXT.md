# Phase 9: Testing Infrastructure - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 9 delivers comprehensive test coverage and test helpers for downstream users. This phase audits existing tests, adds integration tests via stripe-mock, creates a public `LatticeStripe.Testing` module for downstream users, and ensures all quality gates (format, compile, Credo, tests, docs) pass. CI/CD wiring (GitHub Actions, matrix builds) is Phase 11's responsibility — Phase 9 ensures the checks themselves work locally.

</domain>

<decisions>
## Implementation Decisions

### stripe-mock Integration Testing
- **D-01:** Integration tests use `@tag :integration` and are skipped by default (`ExUnit.configure(exclude: [:integration])`). Enable with `mix test --include integration`. This keeps default `mix test` fast and CI-independent.
- **D-02:** stripe-mock runs as a Docker container (`stripe/stripe-mock:latest`) on ports 12111-12112. Tests connect to `http://localhost:12111` with real Finch HTTP calls (not mocked transport).
- **D-03:** Integration tests cover all resource modules: Customer, PaymentIntent, SetupIntent, PaymentMethod, Refund, Checkout.Session — CRUD + action verbs + list + error cases.
- **D-04:** Integration test client uses a dedicated `test_integration_client/0` helper with real Finch transport (not MockTransport), configured for stripe-mock's base URL.

### Test Helper Module (LatticeStripe.Testing)
- **D-05:** `LatticeStripe.Testing` is a public module shipped with the hex package, providing helpers for downstream app tests. It is NOT a dev-only dependency — users import it in their test code.
- **D-06:** Testing module provides: `generate_webhook_event/2` (constructs a realistic Event struct with valid signatures for testing webhook handlers), `generate_webhook_payload/2` (raw signed payload + signature header pair for Plug-level testing).
- **D-07:** Testing module does NOT provide a mock transport or test client — those are internal concerns. It focuses on webhook event construction since that's the primary pain point for downstream users.

### Coverage Gap Analysis Approach
- **D-08:** Audit existing 535 tests against Phase 9 success criteria. Focus on gaps, not rewriting what works. Existing Mox-based unit tests are already strong — the main gap is integration tests (TEST-01) and the public Testing module (TEST-04).
- **D-09:** Unit test gaps to fill: edge cases in form encoding, error normalization for unusual Stripe error shapes, pagination cursor management edge cases, telemetry metadata completeness.

### CI Quality Gates (Local)
- **D-10:** Create a `mix ci` alias that runs: `mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict && mix test && mix docs --warnings-as-errors`. Phase 11 will invoke this alias from GitHub Actions.
- **D-11:** Credo config (`.credo.exs`) should be created if not present, with strict mode and sensible defaults for a library project.

### Claude's Discretion
- Integration test granularity: Claude decides which specific stripe-mock endpoints to test per resource (CRUD minimum, action verbs where applicable)
- Test file organization: Claude decides whether integration tests go in a separate `test/integration/` directory or alongside existing tests with tags
- Fixture reuse: Claude decides how much of the existing fixture infrastructure to reuse vs creating integration-specific fixtures

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Foundation
- `.planning/PROJECT.md` — Core value, design philosophy, testing philosophy
- `.planning/REQUIREMENTS.md` — TEST-01 through TEST-06 acceptance criteria
- `.planning/ROADMAP.md` — Phase 9 success criteria and dependency chain

### Existing Test Infrastructure
- `test/test_helper.exs` — Mox mock definitions (MockTransport, MockJson, MockRetryStrategy)
- `test/support/test_helpers.ex` — test_client/1, ok_response/1, error_response/0, list_json/2
- `test/support/fixtures/` — All fixture modules (customer, payment_intent, setup_intent, payment_method, refund, checkout_session, checkout_line_item, event)

### Key Source Modules
- `lib/lattice_stripe/webhook.ex` — construct_event/4, generate_test_signature/2 (basis for Testing module)
- `lib/lattice_stripe/event.ex` — Event struct (used by Testing module helpers)
- `lib/lattice_stripe/transport.ex` — Transport behaviour (Mox contract to verify)
- `lib/lattice_stripe/transport/finch.ex` — Finch adapter (used in integration tests)

### stripe-mock
- `https://github.com/stripe/stripe-mock` — Official Stripe mock HTTP server, OpenAPI-spec-driven

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/support/test_helpers.ex` — `test_client/1` creates a Mox-backed client; extend with `test_integration_client/0` for stripe-mock
- `test/support/fixtures/` — 8 fixture modules with realistic Stripe response data; reusable in integration tests
- `LatticeStripe.Webhook.generate_test_signature/2` — Already generates valid webhook signatures; basis for Testing module

### Established Patterns
- All resource tests use Mox `expect` for MockTransport with `verify_on_exit!`
- Tests are `async: true` except where global state is needed (telemetry handlers)
- Each resource test file covers: create, retrieve, update, delete/cancel/expire, list, stream, bang variants, error cases
- Fixture modules return plain maps matching Stripe API response shapes

### Integration Points
- `LatticeStripe.Transport.Finch` — Real HTTP adapter for integration tests
- `LatticeStripe.Client.new!/1` — Client constructor accepts `base_url` override for stripe-mock
- ExUnit tag system — `@tag :integration` for conditional test inclusion

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

- **TEST-06 (CI matrix across Elixir versions):** TEST-06 requires running tests across Elixir 1.15/OTP 26, 1.17/OTP 27, 1.19/OTP 28. This is Phase 11 scope — it requires GitHub Actions matrix configuration, not local test infrastructure. Phase 9 ensures all quality gates pass locally via `mix ci`; Phase 11 wires `mix ci` into a CI matrix. TEST-06 is claimed by Plan 09-03 for traceability but the actual matrix execution is deferred to Phase 11.

</deferred>

---

*Phase: 09-testing-infrastructure*
*Context gathered: 2026-04-03*
