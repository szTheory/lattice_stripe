# Phase 76: Phoenix Adopter Core Flow - Context

**Gathered:** 2026-09-24  
**Status:** Ready for planning

<domain>
## Phase Boundary

Give LatticeStripe maintainers a repeatable proof that a host Phoenix application can add the checked-out library as a path dependency, start with documented host configuration and supervision, and perform one synthetic common SaaS Checkout/subscription flow through typed response decoding and verified webhook handling. The proof uses no live Stripe credentials or adopter data.

This is a headless SDK adoption harness, not a shipped Phoenix product. It does not add browser UI, an Ecto Repo/database, application-owned billing policy, production deployment infrastructure, edge adopter profiles, or new library runtime dependencies. Phase 77 owns the broader edge profiles and CI gate.

</domain>

<decisions>
## Implementation Decisions

### Host-app shape and dependency boundary
- **D-01:** Use one small, standalone, test-only Phoenix Mix project at `test_apps/phoenix_adopter`, importing the checked-out LatticeStripe package with a relative path dependency. Keep Phoenix/Plug and their host configuration inside the adopter project; do not add Phoenix or Ecto to LatticeStripe's runtime dependencies. — **Reversibility:** costly — moving the proof later changes its dependency resolution, CI entry point, and maintainers' run instructions.
- **D-02:** Prove normal Phoenix/OTP application boot and the documented Finch/configuration ownership. Let LatticeStripe's application start its existing default pool; do not create a duplicate host pool unless the test specifically demonstrates the documented explicit-pool option. No Ecto Repo is needed for this phase's criteria.

### Adopter JTBD and integrated flow
- **D-03:** Model the adopter as an Elixir maintainer verifying setup and an application engineer implementing recurring signup: start the host app, request a subscription-mode Checkout Session, receive a typed SDK response, then accept a signed webhook at the host boundary. Keep the route/controller and handler intentionally thin; application entitlements and durable billing state remain app-owned and out of scope.
- **D-04:** Exercise the host boundary, not only direct library functions: drive the Phoenix endpoint with test connections; stub only the outbound Stripe HTTP transport and assert the request contract and typed response. Do not make network calls to Stripe or bypass the SDK Client/Transport seam with mutable global client state.

### Webhook trust and deterministic fixtures
- **D-05:** Mount the existing `LatticeStripe.Webhook.Plug` at the host endpoint before body parsing can consume or transform the raw bytes. Use a deterministic synthetic payload, a fixed test-only webhook secret, and the library's supported webhook test-signing helper. Assert signature verification and that the host handler receives the decoded typed event; do not imply this proves Stripe's live delivery or durable duplicate handling.
- **D-06:** Keep all keys and payloads visibly synthetic and local to tests. No environment credential lookup, production adopter records, persistent database, external service, or live Stripe sandbox is part of the core proof.

### Proof ergonomics and user experience
- **D-07:** Make one obvious command run the adopter test project, with a short README or adjacent instructions explaining its path dependency and synthetic-only boundary. Prefer conventional Phoenix routes, endpoint tests, ExUnit assertions, and explicit setup over custom generator/DSL abstractions. Reuse or cross-link existing Checkout and webhook guides only if the host proof reveals a concrete documentation gap.
- **D-08:** Use a separate host lockfile and make the local invocation explicit (`cd test_apps/phoenix_adopter && mix test`). Wire it into root CI only in Phase 77, after the isolated app is deterministic. This keeps local proof easy to discover without pulling consumer-only dependencies into the package project.
- **D-09:** This library has no visual UI or brand system. Apply UX quality to the maintainer journey instead: clear setup steps, actionable failure output, least-surprise Phoenix conventions, deterministic tests, and no exposure of backend implementation details beyond what is needed to run the proof.

### the agent's Discretion
- Choose the smallest supported Phoenix version and exact fixture layout after checking the repository's Elixir/OTP support and dependency policy.
- Choose an endpoint/controller organization that matches standard Phoenix conventions while keeping the flow minimal.
- Use the existing MockTransport/Mox and webhook signing helpers where their contracts permit; add narrowly scoped fixture helpers only when they simplify the adopter test without hiding behavior.
- Add no schema/database, extra profile, broad CI redesign, dependency generator, or user-facing product UI unless research finds a direct requirement-level reason and replanning is requested.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and project boundaries
- `.planning/ROADMAP.md` §"Phase 76: Phoenix Adopter Core Flow" — goal, requirements, success criteria, and boundary.
- `.planning/REQUIREMENTS.md` §"Phoenix Adopter Proof" — ADOPT-01 and ADOPT-02 for this phase; ADOPT-03 through ADOPT-05 remain Phase 77.
- `.planning/PROJECT.md` §"Maintainer Intent" and §"Verification and Automation Default" — adopter-first quality, SDK/application boundary, and proportionate proof.
- `.planning/STATE.md` §"Accumulated Context" — one shared test-only adopter, distinct profiles deferred to Phase 77, and no expansion into a billing engine.
- `.planning/threads/v1-12-next-milestone-assessment.md` — milestone rationale and explicit scope for the minimal Phoenix adopter.
- `.planning/JTBD-MAP.md` §"Audience and Domain Lenses" and §"Common denominator and edge-profile rule" — adopter roles, JTBD, and the common SaaS spine.

### Domain and adopter experience
- `prompts/README.md` — current prompt source-of-truth policy and no separate brand book; archived research is subordinate to current code/docs/planning.
- `prompts/payments_domain_field_guide.md` §§"Checkout", "Subscriptions", "Webhooks", and "Testing" — Stripe nouns, event timing, and synthetic test guidance.
- `guides/checkout-signup-and-portal.md` — existing subscription Checkout adopter flow and success/webhook truth boundary.
- `guides/webhooks.md` — signature verification, raw-body ordering, Plug integration, and handler response contract.
- `guides/testing.md` — supported fixtures, webhook helpers, and transport-testing practices.
- `.planning/phases/76-phoenix-adopter-core-flow/76-RESEARCH.md` — Phase 76-specific ecosystem and implementation tradeoffs.
- `.planning/phases/76-phoenix-adopter-core-flow/76-PATTERNS.md` — source-backed file/pattern map; refresh it to agree with this context and research before planning.

### Existing implementation and test patterns
- `mix.exs` — package dependencies, supported Elixir versions, and optional Plug boundary.
- `lib/lattice_stripe/application.ex` — existing application supervision and Finch startup.
- `lib/lattice_stripe/client.ex` and `lib/lattice_stripe/transport.ex` — explicit immutable client configuration and HTTP injection boundary.
- `lib/lattice_stripe/checkout/session.ex` and `test/lattice_stripe/checkout/session_test.exs` — typed Checkout Session contract and Mox transport expectations.
- `lib/lattice_stripe/webhook/plug.ex` and `test/lattice_stripe/webhook/plug_test.exs` — signature verification, Plug request boundary, and raw-body behavior.
- `lib/lattice_stripe/testing.ex` and `test/support/test_helpers.ex` — supported synthetic event payload/signature helpers and test transport setup.
- `.github/workflows/ci.yml` — current matrix and adoption-contract command conventions; this phase does not redesign CI.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Client` accepts an explicit API key, Finch name, and transport; tests already use a Mox-backed `LatticeStripe.MockTransport` with retries disabled for deterministic assertions.
- Checkout has focused typed response tests and documented subscription signup flow.
- `LatticeStripe.Webhook.Plug`, its raw-body/signature contract, and synthetic signing helpers already exist; the adopter proof should compose them through a Phoenix host endpoint.
- LatticeStripe starts its default Finch pool through its application callback; Plug integration is optional, and the library itself has no Phoenix/Ecto runtime requirement.

### Established Patterns
- Keep Stripe calls explicit through a Client value and assert method/path/body at the transport boundary.
- Use Phoenix/Plug test connections and standard ExUnit setup; test the actual host request path where the success criterion is host integration.
- Verify webhook signatures over the original raw bytes before parsing; do not claim a success redirect establishes subscription state.
- Use synthetic, deterministic values and avoid mutable global application config in parallel tests.

### Integration Points
- The nested Mix project resolves the repository package by path and boots its application with the host application's Phoenix endpoint/supervision.
- A minimal host route invokes Checkout Session creation; its response is decoded by the library and represented at the host boundary.
- The webhook route mounts the library Plug before body parsers and hands a verified typed event to a minimal host handler.
- The existing top-level CI remains a later integration point; Phase 77 decides the repeatable full adopter CI gate.

</code_context>

<specifics>
## Specific Ideas

- Favor one `mode: :subscription` Checkout Session and one representative verified completion event to keep the end-to-end spine coherent and cheap to maintain.
- Assert the outbound request is correct, the returned object is the expected typed Checkout Session, the webhook signature is checked using raw bytes, and the host receives a typed event.
- Keep the example honest about asynchronous Stripe truth: the Checkout success path is user experience; verified webhooks are the state-confirmation boundary.
- No browser UI is required. The observable interaction is an endpoint request exercised with Phoenix.ConnTest.
</specifics>

<deferred>
## Deferred Ideas

- Phase 77: opt-in B2B invoicing, usage reconciliation, and Connect tenant-context profiles; expanded error/pagination/streaming/idempotency cases; and the full adopter CI gate.
- A production example app, deployment setup, Ecto schema/Repo, durable entitlements, retry orchestration, duplicate-event storage, or industry billing policy is outside Phase 76.
- No visual brand, design-system, or accessible browser UI work applies to this headless SDK proof.
</deferred>

---

*Phase: 76-phoenix-adopter-core-flow*  
*Context gathered: 2026-09-24*
