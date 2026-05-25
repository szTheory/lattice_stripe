# Phase 35: Mandate & SetupAttempt - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Add low-level, read-only Stripe resource coverage for payment authorization inspection:

- `LatticeStripe.Mandate` for retrieving a mandate by ID
- `LatticeStripe.SetupAttempt` for listing and streaming setup-attempt history for a required `setup_intent`

This phase is diagnostic and Stripe-shaped. It does not add higher-level recovery workflows, retry orchestration, parent-resource convenience layers, or Accrue-style billing abstractions.

Requirements: AUTH-01, AUTH-02

</domain>

<decisions>
## Implementation Decisions

### API surface and ownership

- **D-01:** `Mandate` is retrieve-only: `retrieve/3`, `retrieve!/3`. No `create`, `update`, `delete`, `list`, or action verbs.
- **D-02:** `SetupAttempt` is list-only: `list/3`, `list!/3`, `stream!/3`. No `retrieve/3`, `create/3`, `update/3`, or delete surface. Official Stripe API docs currently expose only `GET /v1/setup_attempts` with a required `setup_intent` filter.
- **D-03:** Do not add convenience aliases like `list_for_setup_intent/4`, `stream_for_setup_intent!/4`, or `SetupIntent.list_attempts/4`. The canonical API stays on `SetupAttempt` itself.
- **D-04:** `SetupAttempt.list/3` and `SetupAttempt.stream!/3` locally require `"setup_intent"` in params and raise `ArgumentError` when it is missing. This matches the project's existing DX-first validation pattern for known mandatory scoping params.

### Typing depth and nested-structure boundary

- **D-05:** Use selective typing, not full polymorphic modeling. Type the small, stable sub-objects that materially improve discoverability, and keep highly polymorphic payment-method snapshots as raw maps.
- **D-06:** `Mandate.customer_acceptance` gets a dedicated `%LatticeStripe.Mandate.CustomerAcceptance{}` struct. It is a bounded, high-signal object and central to the mandate-inspection use case.
- **D-07:** `Mandate.single_use` gets a tiny `%LatticeStripe.Mandate.SingleUse{}` struct because it is stable and semantically meaningful (`amount`, `currency`).
- **D-08:** `Mandate.multi_use` stays a raw map. Stripe models it as an effectively empty marker object; creating a dedicated empty struct adds ceremony without real value.
- **D-09:** `Mandate.payment_method_details` stays a raw map. It has a wide and evolving payment-method matrix, and typing it now would create maintenance debt and drift risk out of proportion to the value.
- **D-10:** `SetupAttempt.payment_method_details` also stays a raw map for the same reason: it is a diagnostic snapshot with many payment-method-specific branches and should remain Stripe-shaped.

### Historical error modeling

- **D-11:** `SetupAttempt.setup_error` gets a dedicated `%LatticeStripe.SetupAttempt.SetupError{}` struct instead of reusing `%LatticeStripe.Error{}` and instead of remaining a raw map.
- **D-12:** The reason for a dedicated nested struct is semantic precision: `setup_error` is historical data embedded on a successful resource response, not the failure channel returned by the client request pipeline. Reusing `%LatticeStripe.Error{}` would blur that distinction and create a footgun around return-shape expectations.
- **D-13:** `%SetupAttempt.SetupError{}` should model the stable Stripe nested-error fields (`code`, `message`, `type`, `decline_code`, `doc_url`, `param`, `payment_method`) and leave any unknown additions in `extra`.
- **D-14:** The nested error's `payment_method` field may use `ObjectTypes.maybe_deserialize/1` when expanded; otherwise keep the string ID or raw value unchanged.
- **D-15:** This sets a precedent for future cleanup of `SetupIntent.last_setup_error`, but that follow-on alignment is explicitly out of scope for Phase 35.

### Enum modeling and parse-time normalization

- **D-16:** Atomize top-level finite enums at parse time with unknown-string passthrough for forward compatibility.
- **D-17:** `Mandate.status` atomizes to known values `:active`, `:inactive`, `:pending`.
- **D-18:** `Mandate.type` atomizes to known values `:single_use`, `:multi_use`.
- **D-19:** `SetupAttempt.status` atomizes to known values documented by Stripe for setup attempts (for example `:requires_confirmation`, `:requires_action`, `:processing`, `:succeeded`, `:failed`, `:abandoned`), with string fallback for future values.
- **D-20:** `SetupAttempt.usage` atomizes to `:off_session` or `:on_session` with string fallback.
- **D-21:** `Mandate.CustomerAcceptance.type` should also atomize to `:online` or `:offline` because it lives inside a typed bounded struct and meaningfully improves pattern matching.
- **D-22:** Do not atomize deep polymorphic leaves inside raw-map `payment_method_details`. Keep those Stripe-shaped to avoid partial half-typed trees that are hard to explain.
- **D-23:** Do not add public `status_atom/1` or `type_atom/1` helper functions. Follow the post-Phase-22 convention: atomization happens during `from_map/1`.

### Expand deserialization and object registry

- **D-24:** Register `"mandate"` and `"setup_attempt"` in `LatticeStripe.ObjectTypes`.
- **D-25:** Expandable top-level references should use `ObjectTypes.maybe_deserialize/1` where the target type already exists, especially `Mandate.payment_method`, `SetupAttempt.setup_intent`, `SetupAttempt.customer`, `SetupAttempt.payment_method`, `SetupAttempt.application`, and `SetupAttempt.on_behalf_of`.
- **D-26:** Preserve the standard `@known_fields` + `extra` pattern on both top-level structs and new nested structs so unknown Stripe fields never crash decoding.

### Documentation and DX posture

- **D-27:** Both modules should state clearly in `@moduledoc` that these are read-only Stripe-created resources used for inspection and diagnosis, not creation workflows.
- **D-28:** `SetupAttempt` docs must make the required filter unmissable: listing always scopes to one `setup_intent`, and missing that param raises before a network call.
- **D-29:** Examples should emphasize the primary real-world path:
  - retrieve a mandate to inspect authorization state
  - list setup attempts for one setup intent and inspect the latest `setup_error`
- **D-30:** Keep the public surface intentionally small. Phase 35 should feel like disciplined resource coverage, not a mini troubleshooting framework.

### the agent's Discretion

- Exact `@known_fields` breadth and field ordering for `%Mandate{}`, `%SetupAttempt{}`, `%Mandate.CustomerAcceptance{}`, `%Mandate.SingleUse{}`, and `%SetupAttempt.SetupError{}`
- Whether either top-level struct needs custom `Inspect`; default inspect is acceptable unless sensitive fields or readability issues appear during implementation
- Internal helper extraction boundaries for enum atomization and nested parsing
- Exact wording of `ArgumentError` messages for missing `"setup_intent"`
- Test helper naming and fixture module layout

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set for this phase is: Stripe-shaped read-only APIs, selective typing, local fail-fast validation for the one required list filter, parse-time atomization for bounded enums, and semantic precision for historical errors.
- The core tradeoff intentionally rejected here is "generated-SDK completeness." Official Stripe clients often go deeper on nested typing or reuse broad shared error models, but that style is a worse fit for LatticeStripe's handwritten, Elixir-first surface.
- The second intentionally rejected tradeoff is "convenience creep." Even though `SetupIntent.list_attempts/4` might read nicely, it weakens resource ownership and creates precedent for parent-oriented helpers that belong closer to application code than SDK surface.
- The biggest maintenance trap is over-modeling `payment_method_details`. Stripe keeps adding payment-method variants, and the phase should not hard-code a combinatorial tree that becomes stale immediately.
- The biggest DX trap is semantic ambiguity around `setup_error`. A successful `{:ok, %SetupAttempt{}}` carrying `%LatticeStripe.Error{}` would look like the same concept as the request-failure channel even though it is not. The dedicated nested struct avoids that confusion cleanly.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and project context
- `.planning/ROADMAP.md` — Phase 35 goal, dependency, and success criteria
- `.planning/REQUIREMENTS.md` — AUTH-01 and AUTH-02 requirements
- `.planning/STATE.md` — milestone sequencing and current phase position
- `.planning/PROJECT.md` — design philosophy, SDK-vs-Accrue boundary, principle of least surprise
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — confirms this phase stays at low-level Stripe resource coverage

### Prior project decisions that apply directly
- `.planning/phases/05-setupintents-paymentmethods/05-CONTEXT.md` — resource-module pattern, required-param validation precedent, SetupIntent/PaymentMethod field conventions
- `.planning/phases/22-expand-deserialization-status-atomization/22-CONTEXT.md` — parse-time enum atomization and ObjectTypes registry conventions
- `.planning/phases/24-rate-limit-awareness-richer-errors/24-CONTEXT.md` — local DX-first validation philosophy and public Error-shape constraints
- `.planning/phases/33-disputes/33-CONTEXT.md` — explicit small public surface, typed-vs-raw nested-struct tradeoff pattern
- `.planning/phases/34-creditnote/34-CONTEXT.md` — selective typing and Stripe-shaped API discipline

### Existing code patterns to follow
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, bang helper pattern
- `lib/lattice_stripe/object_types.ex` — expand-deserialization registry
- `lib/lattice_stripe/setup_intent.ex` — related resource shape, existing setup-domain fields, atomization precedent for `status` and `usage`
- `lib/lattice_stripe/payment_method.ex` — required-param validation precedent and wide raw-map payment-method detail posture
- `lib/lattice_stripe/error.ex` — public request-failure error model; Phase 35 must not blur its semantics accidentally
- `test/support/fixtures/setup_intent.ex` — fixture style precedent for adjacent resource family
- `test/lattice_stripe/setup_intent_test.exs` — test style precedent for setup-domain resource modules

### Local research and prompts
- `.planning/research/FEATURES.md` — Mandate and SetupAttempt endpoint inventory, field analysis, and v1.3 feature positioning
- `.planning/research/PITFALLS.md` — read-only-resource and over-modeling warnings for this phase
- `.planning/research/ARCHITECTURE.md` — nested-struct depth proposals for the v1.3 resource families
- `.planning/research/STACK.md` — confirms no new transport/runtime dependencies are needed
- `prompts/elixir-best-practices-deep-research.md` — validate at boundaries, keep APIs explicit, prefer small focused structs over monster structs
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — bang/non-bang public API expectations for Elixir libraries
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Stripe-SDK surface design tradeoffs and restraint around API growth
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — DX emphasis on real operational workflows and debugging ergonomics
- `prompts/payments_domain_field_guide.md` — payments-domain terminology and authorization vocabulary

### External Stripe and ecosystem references
- `https://docs.stripe.com/api/mandates/retrieve` — authoritative retrieve-only mandate endpoint
- `https://docs.stripe.com/api/mandates/object` — Mandate object fields, bounded enums, and nested object shapes
- `https://docs.stripe.com/api/setup_attempts` — SetupAttempts overview; confirms list-only public endpoint
- `https://docs.stripe.com/api/setup_attempts/list` — required `setup_intent` filter and response shape
- `https://docs.stripe.com/api/setup_attempts/object` — SetupAttempt object fields, nested `setup_error`, and status values
- `https://hexdocs.pm/stripity_stripe/Stripe.SetupAttempt.html` — Elixir ecosystem precedent for low-level SetupAttempt coverage
- `https://hexdocs.pm/ecto/Ecto.Schema.html` — precedent for using raw maps where nested shapes are broad or fast-moving
- `https://hexdocs.pm/ecto/embedded-schemas.html` — precedent for typing bounded embedded structures only where they materially help

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Resource.unwrap_singular/2` — direct fit for `Mandate.retrieve/3`
- `LatticeStripe.Resource.unwrap_list/2` and `LatticeStripe.List.stream!/2` — direct fit for `SetupAttempt.list/3` and `stream!/3`
- `LatticeStripe.ObjectTypes.maybe_deserialize/1` — reusable for top-level expandable references on both new resources
- Existing private atomizer pattern from `SetupIntent`, `Dispute`, and other post-Phase-22 resources — direct precedent for parse-time enum normalization
- Required-param guard pattern from `PaymentMethod.list/3` — direct precedent for enforcing `"setup_intent"`

### Established Patterns
- Public resource modules stay small and Stripe-shaped when the underlying API is read-only or asymmetric
- Use structs for bounded developer-facing concepts; use raw maps for broad polymorphic payloads
- Unknown enum values fall through as strings to avoid forward-compatibility breakage
- No public `*_atom/1` helper clutter after the Phase 22 atomization sweep
- `@known_fields` plus `extra` remains the standard forward-compatibility mechanism

### Integration Points
- `lib/lattice_stripe/mandate.ex` — new retrieve-only resource module
- `lib/lattice_stripe/mandate/customer_acceptance.ex` — bounded nested struct
- `lib/lattice_stripe/mandate/single_use.ex` — bounded nested struct
- `lib/lattice_stripe/setup_attempt.ex` — new list-only resource module
- `lib/lattice_stripe/setup_attempt/setup_error.ex` — dedicated historical nested-error struct
- `lib/lattice_stripe/object_types.ex` — add `"mandate"` and `"setup_attempt"`
- `test/support/fixtures/mandate.ex` and `test/support/fixtures/setup_attempt.ex` — new fixture modules for unit and integration coverage

</code_context>

<deferred>
## Deferred Ideas

- Revisit `SetupIntent.last_setup_error` in a future phase to decide whether it should adopt the same dedicated nested-error struct as `SetupAttempt.setup_error`
- Typed `payment_method_details` sub-variants for Mandate and SetupAttempt if real downstream demand emerges for compile-time pattern matching on specific payment-method families
- Parent-oriented convenience helpers like `SetupIntent.list_attempts/4` if multiple future phases establish a broader policy for association-style helper APIs

</deferred>

---

*Phase: 35-mandate-setupattempt*
*Context gathered: 2026-05-24*
