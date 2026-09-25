# Phase 76: Phoenix Adopter Core Flow - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `76-CONTEXT.md`; this log preserves alternatives considered.

**Date:** 2026-09-24  
**Phase:** 76-phoenix-adopter-core-flow  
**Areas discussed:** Host-app shape, adopter flow, command and CI boundary, webhook trust boundary, proof ergonomics

---

## Host-app shape

| Option | Description | Selected |
|--------|-------------|----------|
| A: Standalone Phoenix app at `test_apps/phoenix_adopter`, using a local path dependency | Proves the checked-out package boundary and normal host boot without turning the SDK into an umbrella app; an isolated lockfile keeps host tooling separate. | ✓ Recommended default |
| B: Add Phoenix/Ecto dependencies to the library test environment | Easier to share root test helpers, but blurs optional host integrations into the library and does not prove an independent consumer project. | |
| C: Add a production-style example application | More realistic operations, but expands deployment, persistence, and application policy beyond the phase goal. | |

**Auto-mode choice:** A — recommended default. No interactive question was asked because autonomous discuss mode was requested.
**Notes:** Keep Phoenix and Plug at the adopter boundary; no Ecto Repo is needed to prove setup, supervision, and the common flow.

## Adopter flow

| Option | Description | Selected |
|--------|-------------|----------|
| A: Subscription-mode Checkout Session plus one verified completion event | Exercises one cohesive common SaaS spine and typed response/event handling at the host boundary. | ✓ Recommended default |
| B: One-time Checkout only | Simpler, but does not exercise the recurring-signup job most relevant to the current guides and requirements. | |
| C: Several signup/lifecycle flows | Broader coverage, but duplicates Phase 77 edge-profile work and raises fixture/maintenance cost. | |

**Auto-mode choice:** A — recommended default.
**Notes:** Keep controllers thin and do not encode entitlements or durable billing state.

## Command and CI boundary

| Option | Description | Selected |
|--------|-------------|----------|
| A: Run `cd test_apps/phoenix_adopter && mix test`; add it to root CI in Phase 77 | Clear local proof command with isolated dependency graph; broader CI integration remains in its assigned phase. | ✓ Recommended default |
| B: Add a root alias and CI job now | One-command root convenience, but pulls a future phase's CI scope forward and risks obscuring the independent Mix project boundary. | |

**Auto-mode choice:** A — recommended default.
**Notes:** Document the command in a short host README and keep a committed host lockfile.

## Webhook trust boundary

| Option | Description | Selected |
|--------|-------------|----------|
| A: Real host Plug path with raw signed synthetic bytes | Proves route ordering, signature verification, and typed event handoff using the library contract. | ✓ Recommended default |
| B: Call the webhook handler directly with a decoded event | Cheap unit proof, but bypasses signature and raw-body integration at the host boundary. | |
| C: Call live Stripe or stripe-mock | Adds external service behavior, but is unnecessary for synthetic signature and host-wiring proof and conflicts with the no-live-credentials success criterion. | |

**Auto-mode choice:** A — recommended default.
**Notes:** Use the library's test signing helper and fixed synthetic secret; do not claim to prove Stripe delivery or persistent deduplication.

## Proof ergonomics

| Option | Description | Selected |
|--------|-------------|----------|
| A: Standard Phoenix endpoint tests, explicit Mox transport, one documented command | Familiar, deterministic, and directly demonstrates the dependency and runtime boundary. | ✓ Recommended default |
| B: Direct Client calls only | Minimal setup but does not prove a Phoenix host application can use the dependency. | |
| C: Custom DSL/generator and broad CI redesign | Could automate future consumers, but adds abstraction and scope before the core proof exists. | |

**Auto-mode choice:** A — recommended default.
**Notes:** No visual UI/brand work applies to the headless library. Phase 77 owns the broader adopter CI gate.

## the agent's Discretion

- Choose the narrowest Phoenix dependency version compatible with the repository's supported Elixir/OTP policy.
- Set exact test fixture paths and Phoenix module names to match conventional Phoenix structure.
- Reuse existing transport and webhook helpers where their public contract supports the host boundary.

## Deferred Ideas

- Phase 77's B2B invoicing, usage reconciliation, Connect context, additional failure-boundary profiles, and repeatable CI gate.
- Ecto persistence, durable event deduplication, production operations/deployment, multiple sample apps, and visual UI.
