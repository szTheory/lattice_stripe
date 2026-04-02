# Phase 5: SetupIntents & PaymentMethods - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Two resource modules (SetupIntent, PaymentMethod) following the pattern established by Customer and PaymentIntent in Phase 4. SetupIntent has an intent lifecycle (create/confirm/cancel + verify_microdeposits). PaymentMethod adds attach/detach operations and requires customer-scoped listing. This phase also extracts shared resource helpers and test infrastructure.

Requirements: SINT-01..06, PMTH-01..06 (12 total)
Bonus: SetupIntent.verify_microdeposits (not in requirements, but trivial and completes the API)
Bonus: PaymentIntent.search + search_stream! (missed in Phase 4, added during refactor)

</domain>

<decisions>
## Implementation Decisions

### Resource Module Pattern (carries forward from Phase 4)
- **D-01:** Hand-written modules, no macro DSL — same as Phase 4 D-01
- **D-02:** Request struct → Client.request → unwrap — same as Phase 4 D-02
- **D-03:** Public API convention: create/2, retrieve/2, update/3, list/2, plus resource-specific action verbs — same as Phase 4 D-03
- **D-04:** All functions accept opts keyword for per-request overrides — same as Phase 4 D-04

### Shared Helper Extraction
- **D-05:** Extract `LatticeStripe.Resource` helper module (`@moduledoc false`, not public API). Contains:
  - `unwrap_singular/2` — takes `{:ok, %Response{}}` + `from_map_fn`, returns `{:ok, struct}`
  - `unwrap_list/2` — takes list response + `from_map_fn`, returns typed list items
  - `unwrap_bang!/1` — extract value or raise error
  - `require_param!/3` — raises ArgumentError if required param key missing from params map. Generic, reusable across resources.
- **D-06:** Refactor existing Customer.ex and PaymentIntent.ex to use `Resource` helpers in plan 05-01 (alongside SetupIntent creation). Verify zero behavior change with existing tests.
- **D-07:** Add `PaymentIntent.search/3` and `PaymentIntent.search_stream!/3` while refactoring PI.ex in 05-01. Same pattern as Customer.search.

### Shared Test Helper Extraction
- **D-08:** Extract common test helpers to `test/support/test_helpers.ex`:
  - `test_client/1` — creates Client with test defaults and optional overrides
  - `ok_response/1` — wraps body in 200 response map
  - `error_response/0` — returns 400 error response
  - `list_json/2` — builds list response JSON with items and url
- **D-09:** Resource-specific JSON builders (e.g., `setup_intent_json/1`, `payment_method_json/1`) stay in their respective test files. Only truly shared helpers get extracted.
- **D-10:** Refactor existing Customer and PaymentIntent tests to use shared helpers in 05-01.

### Attach/Detach API Design
- **D-11:** `PaymentMethod.attach/4` and `PaymentMethod.detach/3` use the params map pattern — `attach(client, id, params \\ %{}, opts \\ [])`. Customer ID goes in params as `%{"customer" => "cus_..."}`. Identical to confirm/capture/cancel pattern from Phase 4.
- **D-12:** Detach returns `{:ok, %PaymentMethod{customer: nil}}` naturally via `from_map/1`. No special handling needed.

### PaymentMethod List Scoping & Validation
- **D-13:** `PaymentMethod.list/3` validates that `"customer"` key exists in params. Raises `ArgumentError` with descriptive message if missing. Stripe requires this param — fail fast instead of wasting a network round-trip.
- **D-14:** `PaymentMethod.stream!/3` applies the same customer param validation as list.
- **D-15:** Validation uses `Resource.require_param!/3` from the shared helper module.
- **D-16:** Local validation applied case-by-case for known Stripe required params — not a blanket rule, but DX-first when we know a param is required.

### Struct Design
- **D-17:** Both structs use plain `defstruct` with `from_map/1`, `@known_fields`, and `extra` map — same as Phase 4 D-05/D-06/D-07.
- **D-18:** PaymentMethod struct includes ALL ~45 type-specific fields (card, us_bank_account, sepa_debit, acss_debit, etc.) as struct keys. Most are nil. Consistent access pattern regardless of payment method type. Nil struct fields have zero runtime cost in Elixir. Matches Phase 1 D-12 (known fields get struct keys).
- **D-19:** SetupIntent.latest_attempt is a raw value — string ID (unexpanded) or plain map (expanded). Same pattern as PaymentIntent.latest_charge. Typed expansion deferred with EXPD-02.
- **D-20:** SetupIntent.cancellation_reason is a struct field — same as PaymentIntent.
- **D-21:** Status fields remain as strings (not atoms). EXPD-05 stays deferred for an all-resources-at-once sweep. Piecemeal conversion creates worse DX than consistent strings.

### Inspect Implementation
- **D-22:** SetupIntent Inspect shows: `id`, `object`, `status`, `usage`. Hides `client_secret` entirely (field name excluded from output, matching PaymentIntent pattern using `Inspect.Algebra`).
- **D-23:** PaymentMethod Inspect shows: `id`, `object`, `type`, plus `card.brand` and `card.last4` when type is card. Hides: `billing_details`, `card.fingerprint`, `card.exp_month`, `card.exp_year`, and all other PII/payment data. `last4` and `brand` are Stripe's designated safe display values.

### Scope Additions
- **D-24:** Include `SetupIntent.verify_microdeposits/4` — same action verb pattern as confirm/cancel. Trivial to implement, completes the SetupIntent API for bank account verification flows.
- **D-25:** PaymentMethod has no delete endpoint. No `delete` function. Moduledoc notes: "PaymentMethods cannot be deleted. Use `detach/3` to remove from a customer."

### PaymentMethod Create
- **D-26:** `PaymentMethod.create/3` is pure pass-through — same `create(client, params, opts)` pattern. No local validation of `type` or type-specific params. Stripe validates. `@doc` examples show common patterns (card with token, card with raw details, bank account).

### Plan Structure
- **D-27:** Two plans, one per resource:
  - `05-01-PLAN.md` — Extract Resource helpers + refactor Customer/PI + add PI search + build SetupIntent + extract test helpers + refactor existing tests
  - `05-02-PLAN.md` — Build PaymentMethod (CRUD, attach/detach, list with validation, stream, Inspect) + tests

### Documentation
- **D-28:** Moduledocs follow Phase 4 structure: description, usage examples, security/Inspect notes, caveats. PaymentMethod docs must explicitly note: (1) `list` requires `customer` param, (2) no delete — use detach, (3) type-specific nested objects. Content details are Claude's discretion.

### Claude's Discretion
- Internal `from_map/1` implementation details for both structs
- Exact struct field lists (follow Stripe's API reference for SetupIntent and PaymentMethod)
- `@moduledoc` and `@doc` content, examples, and formatting
- Test fixture data shapes (resource-specific JSON builders)
- How to handle optional/nilable fields on structs
- Whether to verify customer==nil in detach tests
- Helper function organization within modules
- Ordering of tasks within each plan

### Deferred from Phase 4 (still deferred)
- Type registry (`%{"customer" => Customer, ...}`) — deferred to Phase 7 (Webhooks), which is the first consumer
- Typed expansion (EXPD-02) — nested expanded objects stay as plain maps
- Status atom conversion (EXPD-05) — all-resources-at-once in a future phase
- Shared resource macro/DSL — not needed; hand-written modules + Resource helper module is sufficient

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — Core value, constraints, design philosophy, key decisions
- `.planning/REQUIREMENTS.md` — Full v1 requirements (Phase 5: SINT-01..06, PMTH-01..06)
- `.planning/ROADMAP.md` — Phase structure, dependencies, success criteria

### Prior phase context (builds on these)
- `.planning/phases/01-transport-client-configuration/01-CONTEXT.md` — D-04/D-05 (Request struct pipeline), D-12 (extra field pattern), D-13 (typed structs), D-17 (flat module structure)
- `.planning/phases/02-error-handling-retry/02-CONTEXT.md` — D-04 (no Jason.Encoder), D-14 (retry in Client.request)
- `.planning/phases/03-pagination-response/03-CONTEXT.md` — D-01..09 (stream API), D-10..17 (List struct, search), D-18..26 (Response struct, return types)
- `.planning/phases/04-customers-paymentintents/04-CONTEXT.md` — D-01..18 (resource module pattern, struct design, Inspect, testing, return types). Phase 5 follows this pattern directly.

### Existing implementation (modify/extend these)
- `lib/lattice_stripe/client.ex` — `request/2`, `request!/2` — resource modules call these
- `lib/lattice_stripe/request.ex` — `%Request{}` struct resource modules build
- `lib/lattice_stripe/response.ex` — `%Response{}` returned by Client, unwrapped by resources
- `lib/lattice_stripe/list.ex` — `%List{}` with `stream!/2`, `stream/2` — resource stream functions wrap these
- `lib/lattice_stripe/customer.ex` — Refactor to use Resource helpers in 05-01
- `lib/lattice_stripe/payment_intent.ex` — Refactor to use Resource helpers + add search in 05-01
- `test/lattice_stripe/customer_test.exs` — Refactor to use shared test helpers in 05-01
- `test/lattice_stripe/payment_intent_test.exs` — Refactor to use shared test helpers in 05-01

### New files (create these)
- `lib/lattice_stripe/resource.ex` — Shared resource helpers (`@moduledoc false`)
- `lib/lattice_stripe/setup_intent.ex` — `%SetupIntent{}` struct + CRUD/confirm/cancel/verify_microdeposits/list/stream
- `lib/lattice_stripe/payment_method.ex` — `%PaymentMethod{}` struct + CRUD/attach/detach/list/stream
- `test/support/test_helpers.ex` — Shared test helpers (test_client, ok_response, etc.)
- `test/lattice_stripe/resource_test.exs` — Tests for shared Resource helpers
- `test/lattice_stripe/setup_intent_test.exs` — SetupIntent resource tests
- `test/lattice_stripe/payment_method_test.exs` — PaymentMethod resource tests

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Client.request/2` — Full request pipeline (retry, telemetry, transport dispatch)
- `LatticeStripe.Client.request!/2` — Bang variant for resource bang functions
- `LatticeStripe.List.stream!/2` and `stream/2` — Auto-pagination streams
- `LatticeStripe.List.from_json/3` — List deserialization (auto-detected by Client)
- `LatticeStripe.FormEncoder` — Nested param encoding for POST bodies
- `LatticeStripe.Response` — Access behaviour for bracket syntax

### Established Patterns (from Customer + PaymentIntent)
- `unwrap_singular/1` — `{:ok, %Response{data: data}} → {:ok, from_map(data)}` (to be extracted to Resource)
- `unwrap_list/1` — Maps list items through `from_map/1` (to be extracted to Resource)
- `unwrap_bang!/1` — `{:ok, result} → result`, `{:error, error} → raise(error)` (to be extracted to Resource)
- Custom Inspect via `Inspect.Algebra` — PII-safe, shows only structural fields
- No `Jason.Encoder` on any struct
- `@known_fields` sigil + `extra: Map.drop(map, @known_fields)` pattern
- Mox-based testing with per-file JSON builders

### Integration Points
- Phase 6 (Refunds + Checkout): Will use `Resource` helpers. Refund has no search. Checkout.create has required params (may use `require_param!/3`).
- Phase 7 (Webhooks): Event parsing will need type registry to dispatch to `from_map/1` — deferred.
- Phase 9 (Testing): Integration tests with stripe-mock will exercise these resources.
- Phase 10 (Documentation): Resource module guides and examples.

</code_context>

<specifics>
## Specific Ideas

- 05-01 is the "infrastructure + SetupIntent" plan: extract Resource helpers, refactor existing modules, add PI search, extract test helpers, then build SetupIntent on the clean foundation
- 05-02 is the "PaymentMethod" plan: builds on everything from 05-01, adds unique behaviors (attach/detach, customer-scoped list validation)
- PaymentMethod struct is the largest in the SDK (~55 fields with all type-specific fields) but most are nil. This is fine in Elixir — struct fields are tuple positions with zero cost when nil.
- The `require_param!/3` pattern is explicitly DX-first: pay a tiny abstraction cost to prevent developers from discovering required params via Stripe API errors

</specifics>

<deferred>
## Deferred Ideas

- **Type registry** — `%{"customer" => Customer, ...}` for automatic deserialization. Deferred to Phase 7 (Webhooks) which is the first consumer.
- **Typed expansion** (EXPD-02) — Expanded nested objects deserialized into typed structs. Deferred until more resources exist and the expansion patterns are clearer.
- **Status atom conversion** (EXPD-05) — Convert string status fields to atoms across all resources. Should be an all-resources-at-once sweep, not piecemeal.
- **Shared resource macro/DSL** — Not needed. Hand-written modules + Resource helper module provides enough DRY without the complexity of macros.
- **Nested resource helpers** — e.g., `Customer.list_payment_methods/2`. Accessible via top-level `PaymentMethod.list(client, %{"customer" => cus_id})` instead.

</deferred>

---

*Phase: 05-setupintents-paymentmethods*
*Context gathered: 2026-04-02*
