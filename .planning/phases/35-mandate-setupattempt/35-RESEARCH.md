# Phase 35: Mandate & SetupAttempt - Research

**Researched:** 2026-05-24 [VERIFIED: local env + official Stripe docs]  
**Domain:** Stripe mandate retrieval and setup-attempt history in an Elixir SDK (`LatticeStripe`) [VERIFIED: .planning/ROADMAP.md]  
**Confidence:** HIGH [VERIFIED: codebase patterns][CITED: https://docs.stripe.com/api/mandates/retrieve][CITED: https://docs.stripe.com/api/mandates/object][CITED: https://docs.stripe.com/api/setup_attempts/list][CITED: https://docs.stripe.com/api/setup_attempts/object]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01..D-04:** `Mandate` is retrieve-only, `SetupAttempt` is list-only, and `SetupAttempt.list/3` plus `stream!/3` must locally require `"setup_intent"` before any network call. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md]
- **D-05..D-10:** Use selective typing. `Mandate.CustomerAcceptance`, `Mandate.SingleUse`, and `SetupAttempt.SetupError` get dedicated structs; `multi_use` and both `payment_method_details` branches stay raw maps. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md]
- **D-11..D-15:** `SetupAttempt.setup_error` must not reuse `%LatticeStripe.Error{}`. It is historical embedded data on a successful resource response, not the request-failure channel. `setup_error.payment_method` may expand-deserialize via `ObjectTypes.maybe_deserialize/1`. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md]
- **D-16..D-23:** Atomize bounded top-level enums at parse time with string passthrough for unknown values. `Mandate.status`, `Mandate.type`, `Mandate.CustomerAcceptance.type`, `SetupAttempt.status`, and `SetupAttempt.usage` follow the Phase 22 convention. No public helper functions. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md]
- **D-24..D-26:** Register `"mandate"` and `"setup_attempt"` in `LatticeStripe.ObjectTypes`, use `maybe_deserialize/1` for expandable top-level references, and preserve the `@known_fields` + `extra` pattern on all new structs. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md]
- **D-27..D-30:** Module docs should make the read-only diagnostic posture explicit, highlight `SetupAttempt`'s required `setup_intent` filter, and keep the public surface intentionally small. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md]

### Claude's Discretion

- Exact `@known_fields` breadth and ordering for `Mandate`, `SetupAttempt`, `Mandate.CustomerAcceptance`, `Mandate.SingleUse`, and `SetupAttempt.SetupError`
- Whether to add custom `Inspect` implementations; default inspect is acceptable unless execution finds a concrete readability or sensitivity problem
- Exact fixture helper naming and whether Mandate needs integration coverage beyond request-shape unit tests
- Precise `ArgumentError` wording for missing `"setup_intent"`

### Deferred Ideas (OUT OF SCOPE)

- Revisit `SetupIntent.last_setup_error` in a future phase to align it with `SetupAttempt.SetupError`
- Typing `payment_method_details` variants for Mandate or SetupAttempt
- Parent-oriented helpers such as `SetupIntent.list_attempts/4`
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | Developer can retrieve mandate details via `Mandate.retrieve/3` [VERIFIED: .planning/REQUIREMENTS.md] | Stripe currently exposes `GET /v1/mandates/:id` and returns a Mandate object with bounded top-level enums and a compact `customer_acceptance` sub-object. [CITED: https://docs.stripe.com/api/mandates/retrieve][CITED: https://docs.stripe.com/api/mandates/object] |
| AUTH-02 | Developer can list setup attempts filtered by setup_intent via `SetupAttempt.list/3` and `stream!/3` [VERIFIED: .planning/REQUIREMENTS.md] | Stripe currently exposes `GET /v1/setup_attempts` with required `setup_intent`, paginated list semantics, and embedded `setup_error` historical data. [CITED: https://docs.stripe.com/api/setup_attempts/list][CITED: https://docs.stripe.com/api/setup_attempts/object] |
</phase_requirements>

## Summary

Phase 35 is a low-risk resource-coverage phase. The transport, pagination, object dispatch, bang helpers, and required-param guard infrastructure already exist in the repo; the main work is choosing the right typing depth and preserving semantic clarity around historical setup failures. [VERIFIED: lib/lattice_stripe/resource.ex][VERIFIED: lib/lattice_stripe/object_types.ex]

The highest-value design choice is restraint. Stripe’s current docs still present Mandate as retrieve-only and SetupAttempt as list-only as of 2026-05-24, so the plan should not invent convenience verbs or deeper parent-oriented helpers. [CITED: https://docs.stripe.com/api/mandates/retrieve][CITED: https://docs.stripe.com/api/setup_attempts/list]

The main modeling nuance is `setup_error`: Stripe documents it as an embedded object on the SetupAttempt resource, with its own `code`, `message`, `decline_code`, `doc_url`, `param`, and optional embedded `payment_method`. That favors a small dedicated nested struct over reusing `%LatticeStripe.Error{}`. [CITED: https://docs.stripe.com/api/setup_attempts/object]

**Primary recommendation:** Plan this as two execution waves:
1. create the parser contracts, nested structs, object registration, ExDoc grouping, and fixtures
2. add the retrieve/list public APIs plus focused unit and integration coverage

## Project Constraints

- Public resource modules stay Stripe-shaped and low-magic. [VERIFIED: .planning/PROJECT.md]
- Required-param validation is acceptable when the library has strong certainty about a mandatory scope filter. [VERIFIED: lib/lattice_stripe/resource.ex][VERIFIED: lib/lattice_stripe/payment_method.ex]
- Enum atomization happens in `from_map/1` with unknown-string passthrough after Phase 22. [VERIFIED: .planning/phases/22-expand-deserialization-status-atomization/22-CONTEXT.md]
- `ObjectTypes.maybe_deserialize/1` is the central expand-deserialization boundary. [VERIFIED: lib/lattice_stripe/object_types.ex]
- ExDoc grouping is centrally managed in `mix.exs`; Phase 35 must slot into the existing Payments group. [VERIFIED: mix.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| `Mandate.retrieve/3` request routing | API / Backend | Stripe API | Standard JSON retrieve endpoint using existing request pipeline. [CITED: https://docs.stripe.com/api/mandates/retrieve] |
| `SetupAttempt.list/3` and `stream!/3` request routing | API / Backend | Stripe API | Standard paginated list endpoint with one required filter and existing `List.stream!/2` support. [CITED: https://docs.stripe.com/api/setup_attempts/list] |
| Typed deserialization and enum normalization | SDK struct layer | — | Pure SDK concern handled in `from_map/1` and nested structs. [VERIFIED: codebase patterns] |
| Expandable-object parsing | SDK registry | Stripe API | Stripe decides expansion; the SDK decides whether expanded maps dispatch to existing modules. [VERIFIED: lib/lattice_stripe/object_types.ex] |
| Historical error semantics | SDK struct layer | — | The distinction between embedded `setup_error` and request failure must be enforced locally in the type design. [VERIFIED: .planning/phases/35-mandate-setupattempt/35-CONTEXT.md] |

## Standard Stack

### Core

| Library / Module | Purpose | Why Standard |
|------------------|---------|--------------|
| `LatticeStripe.Client`, `Request`, `Resource`, `List` | Request construction, unwrap helpers, pagination streaming | Phase 35 uses only standard JSON retrieve/list behavior. [VERIFIED: codebase grep] |
| `LatticeStripe.ObjectTypes` | Expand-deserialization registry | Both new resources need registry entries and top-level expandable parsing. [VERIFIED: lib/lattice_stripe/object_types.ex] |
| ExUnit + Mox | Unit request-shape and parser testing | Existing pattern for resource module verification. [VERIFIED: test/lattice_stripe/setup_intent_test.exs] |
| `stripe-mock` integration test setup | Route sanity for list/retrieve behavior | Existing adjacent setup-domain integration style already exists. [VERIFIED: test/integration/setup_intent_integration_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated `SetupAttempt.SetupError` | Reuse `%LatticeStripe.Error{}` | Rejected because it collapses embedded historical data into the request-failure channel and weakens pattern-match semantics. |
| Local required-param guard for `"setup_intent"` | Let Stripe reject missing params remotely | Rejected because the repo already treats known mandatory scope filters as a local DX boundary. |
| Selective nested typing | Deep `payment_method_details` struct trees | Rejected because Stripe’s payment-method matrix is broad and fast-moving; raw maps avoid stale partial modeling. |

## Architecture Patterns

### Pattern 1: Retrieve-only resource module for Mandate

Use `SetupIntent.retrieve/3` and `Refund.retrieve/3` as the public API shape analog, but keep the surface limited to:

- `retrieve/3`, `retrieve!/3`
- `from_map/1`
- nested `%Mandate.CustomerAcceptance{}` and `%Mandate.SingleUse{}`

Current official Stripe docs still show only `GET /v1/mandates/:id` for this phase’s intended coverage. [CITED: https://docs.stripe.com/api/mandates/retrieve]

### Pattern 2: List-only resource module with required-param guard for SetupAttempt

Use `PaymentMethod.list/3` and `stream!/3` as the required-filter analog:

- `list/3`, `list!/3`, `stream!/3`
- `Resource.require_param!(params, "setup_intent", "...")`
- `Resource.unwrap_list(&from_map/1)` and `List.stream!(client, req) |> Stream.map(&from_map/1)`

Current official Stripe docs still require `setup_intent` on `GET /v1/setup_attempts` as of 2026-05-24. [CITED: https://docs.stripe.com/api/setup_attempts/list]

### Pattern 3: Bounded nested structs, broad raw maps

Use the `Dispute` nested-struct pattern for small bounded objects and the `PaymentMethod`/`SetupIntent` posture for broad payment-method branches:

- `Mandate.CustomerAcceptance`: typed
- `Mandate.SingleUse`: typed
- `Mandate.multi_use`: raw map
- `Mandate.payment_method_details`: raw map
- `SetupAttempt.payment_method_details`: raw map
- `SetupAttempt.SetupError`: typed with `extra`

### Pattern 4: Semantic historical-error struct

`setup_error` should parse to `%LatticeStripe.SetupAttempt.SetupError{}` with at least:

- `code`
- `message`
- `type`
- `decline_code`
- `doc_url`
- `param`
- `payment_method`
- `extra`

When `payment_method` is expanded, parse it with `ObjectTypes.maybe_deserialize/1`; otherwise leave the ID or raw value unchanged. [CITED: https://docs.stripe.com/api/setup_attempts/object]

## Validation Architecture

### Fast feedback path

- Quick parser/registry checks: `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors`
- Resource-unit checks: `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors`
- Full phase confidence: `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs test/integration/setup_attempt_integration_test.exs`

### Required sampling

- After parser-contract tasks: run `object_types` and relevant unit tests immediately
- After API-surface tasks: run unit tests for both resource modules
- Before phase verification: run unit + integration tests together, then `mix ci` if execution remains clean

### Manual-only checks

- Confirm the moduledocs clearly state read-only diagnostic posture
- Confirm `SetupAttempt` docs make the required `"setup_intent"` filter and local `ArgumentError` behavior unmissable

## Research Output

The planning artifacts should assume the following concrete file set unless execution discovers a simpler equivalent:

- `lib/lattice_stripe/mandate.ex`
- `lib/lattice_stripe/mandate/customer_acceptance.ex`
- `lib/lattice_stripe/mandate/single_use.ex`
- `lib/lattice_stripe/setup_attempt.ex`
- `lib/lattice_stripe/setup_attempt/setup_error.ex`
- `lib/lattice_stripe/object_types.ex`
- `mix.exs`
- `test/support/fixtures/mandate.ex`
- `test/support/fixtures/setup_attempt.ex`
- `test/lattice_stripe/object_types_test.exs`
- `test/lattice_stripe/mandate_test.exs`
- `test/lattice_stripe/setup_attempt_test.exs`
- `test/integration/setup_attempt_integration_test.exs`
