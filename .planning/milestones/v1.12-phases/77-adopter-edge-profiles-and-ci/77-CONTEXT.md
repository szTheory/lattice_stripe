# Phase 77: Adopter Edge Profiles and CI - Context

**Gathered:** 2026-09-24  
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the test-only Phoenix adopter introduced in Phase 76 with opt-in B2B invoicing, usage reconciliation, and Connect tenant-context profiles. Prove a small number of distinct SDK contracts through deterministic synthetic inputs, cover relevant error, pagination or streaming, idempotency, and webhook-verification boundaries, and run the complete adopter suite as a repeatable CI gate. This remains a contract-test harness: application billing policy, compliance decisions, durable orchestration, live Stripe credentials, and production data are out of scope.

</domain>

<decisions>
## Implementation Decisions

### Profile shape and opt-in behavior
- **D-01:** Keep one shared Phoenix host app and make B2B, usage, and Connect scenarios independently selectable as test profiles (for example, focused ExUnit files or tags). Do not create one application per profile.

### Distinct contract coverage
- **D-02:** Give each profile a small, distinct SDK contract: typed invoice or reconciliation behavior for B2B, usage-summary pagination or streaming, and per-request Connect tenant context including account-header behavior. Confirm exact operations against existing SDK capabilities during research/planning.
- **D-03:** Cover shared error, idempotency, and webhook-verification boundaries where they are meaningful to the selected flows. Prefer executable assertions at the host/SDK seam and use synthetic fixtures; do not implement billing policy, persistent event processing, or application-owned orchestration.

### CI gate and determinism
- **D-04:** Add one dedicated adopter CI job using the repository's existing primary Elixir 1.19 / OTP 28 toolchain. It should resolve the nested adopter lockfile and run the complete adopter suite without secrets, live services, or production data. Preserve a single obvious local command.

### the agent's Discretion
- Select exact SDK calls and response fixtures after checking the supported typed surfaces and existing test seams.
- Choose ExUnit organization and whether profile selection uses tags, files, or both, provided the complete suite has one deterministic command.
- Keep the CI job proportional to the existing workflow; do not expand the package's Elixir/OTP matrix or redesign unrelated CI jobs.
- Add or adjust adopter instructions only as needed to explain the profiles and their local invocation.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` §"Phase 77: Adopter Edge Profiles and CI" — goal and success criteria.
- `.planning/REQUIREMENTS.md` §"Phoenix Adopter Proof" — ADOPT-03 through ADOPT-05.
- `.planning/PROJECT.md` §"Maintainer Intent" and §"Verification and Automation Default" — quality priorities, boundaries, and automation posture.
- `.planning/STATE.md` §"Accumulated Context" — decisions carried across the milestone.
- `.planning/JTBD-MAP.md` §"Audience and Domain Lenses" and §"Common denominator and edge-profile rule" — reasons for distinct adopter profiles and their application boundary.
- `.planning/threads/v1-12-next-milestone-assessment.md` §"Minimal Phoenix adopter" — bounded adopter proof rationale.

### Prior adopter decisions and implementation
- `.planning/phases/76-phoenix-adopter-core-flow/76-CONTEXT.md` — locked one-app path dependency, synthetic-only, transport and webhook boundaries.
- `.planning/phases/76-phoenix-adopter-core-flow/76-RESEARCH.md` — Phase 76 technical findings and ecosystem decisions.
- `.planning/phases/76-phoenix-adopter-core-flow/76-PATTERNS.md` — source-backed file map, test seams, and CI analog.
- `test_apps/phoenix_adopter/` — current nested Phoenix app, core flow test, lockfile, config, and run instructions.
- `.github/workflows/ci.yml` — current CI toolchain and focused adoption-contract job convention.

### SDK contract and reusable tests
- `lib/lattice_stripe/client.ex` and `lib/lattice_stripe/transport.ex` — explicit client configuration and HTTP transport seam.
- `lib/lattice_stripe/connect/` — Connect modules and tenant-context operations to evaluate for the profile.
- `lib/lattice_stripe/billing/` and `lib/lattice_stripe/invoice/` — existing usage and invoice surfaces to evaluate.
- `test/lattice_stripe/checkout/session_test.exs` and `test/lattice_stripe/webhook/plug_test.exs` — Mox-at-Transport and signature-verification patterns.
- `guides/testing.md`, `guides/webhooks.md`, and `guides/production-checklist.md` — supported test fixtures, webhook trust boundary, and Connect account-context guidance.

No separate product specification or UI contract applies; the adopter is headless test infrastructure.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test_apps/phoenix_adopter/` already has a Phoenix host application, checked-out package path dependency, isolated lockfile, synthetic MockTransport, Checkout host route, and signed/tampered webhook tests.
- `LatticeStripe.Client` and the `LatticeStripe.Transport` behavior support explicit per-test client configuration and deterministic request assertions.
- Existing invoice, Billing.Meter, and Connect SDK modules should supply the profile contracts; Phase 77 is not permission to expand resource breadth absent a demonstrated gap.
- Existing typed event fixtures and webhook signature helpers provide the common synthetic trust boundary.

### Established Patterns
- Keep the package's Phoenix dependency boundary unchanged; Phoenix remains a host-only dependency.
- Send Stripe calls through an explicit Client and injected transport rather than mutable global client state or live HTTP.
- Assert method, path, relevant headers/body, decoded typed results, and error semantics at the appropriate SDK/host boundary.
- Preserve webhook verification over raw request bytes and distinguish verified event receipt from durable processing.
- The current root CI uses Elixir 1.19 / OTP 28 for focused adoption checks; the package compatibility matrix remains separate.

### Integration Points
- Add profile tests within the nested app's `test/` tree, reusing its host wiring and test transport.
- The nested app's single `mix test` invocation is the complete adopter gate; CI should invoke it from `test_apps/phoenix_adopter` and include dependency resolution for its separate lockfile.
- Keep instructions in `test_apps/phoenix_adopter/README.md` aligned with the actual profile and CI invocation.

</code_context>

<specifics>
## Specific Ideas

- B2B should exercise an existing typed invoice/reconciliation path; usage should prove a meaningful pagination or streaming contract; Connect should prove request-scoped account context and header behavior.
- Reuse the existing shared Checkout/webhook flow as the app spine and add only enough edge-profile behavior to demonstrate different SDK contracts.
- Avoid equating synthetic contract proof with real Stripe delivery, production reconciliation, compliance, or durable event handling.
</specifics>

<deferred>
## Deferred Ideas

- Separate adopter applications, full industry-specific billing workflows, production deployment, live Stripe credentials, real adopter data, and persistence are outside the phase boundary.
- Additional profiles or Stripe resource families remain pull-driven and require a distinct adopter job and maintenance case.

</deferred>

---

*Phase: 77-adopter-edge-profiles-and-ci*  
*Context gathered: 2026-09-24*
