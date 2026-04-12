# Phase 6: Refunds & Checkout - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Two resource areas: Refund operations (create full/partial refunds, retrieve, update metadata, cancel pending refunds, list, stream) and Checkout Sessions (create in payment/subscription/setup modes, retrieve, list, expire, search, stream, plus nested list_line_items endpoint with LineItem typed struct). Also includes retroactive extraction of test fixtures from Phase 4/5 resources into dedicated fixture modules.

Requirements: RFND-01..04, CHKT-01..07 (11 total)
Bonus: Refund.cancel (not in requirements, but completes the API)
Bonus: Checkout.Session.search + search_stream! (Stripe supports it)
Bonus: Checkout.Session.list_line_items + stream_line_items! (common fulfillment use case)
Infrastructure: Retroactive fixture extraction for all existing resources (Customer, PaymentIntent, SetupIntent, PaymentMethod)

</domain>

<decisions>
## Implementation Decisions

### Refund API Design
- **D-01:** PaymentIntent-only scoping for Refund.create. `payment_intent` is required in params. Charge-based refunds are legacy — not supported. If a developer passes `charge` alongside `payment_intent`, it's passed through without error (Stripe handles it).
- **D-02:** Refund.create validates `payment_intent` presence via `Resource.require_param!/3`. Raises `ArgumentError` if missing. DX-first — fail fast before network round-trip. Same pattern as PaymentMethod.list customer validation.
- **D-03:** Include `Refund.cancel/3` — same action verb pattern as PaymentIntent.cancel. `cancel(client, id, params \\ %{})`. Completes the Refund API for pending refunds.
- **D-04:** No required params for `Refund.list/2`. All params optional. Stripe allows listing all refunds without filters. Unlike PaymentMethod.list which requires customer.
- **D-05:** No local validation of `reason` param values (duplicate, fraudulent, requested_by_customer). Pass through to Stripe. Avoids hardcoding enum values that Stripe might expand.
- **D-06:** Include `Refund.stream!/2` for auto-pagination. Consistency with all other resources.
- **D-07:** No search endpoint — Stripe doesn't offer search for Refunds.
- **D-08:** All special params (reverse_transfer, refund_application_fee, metadata) are pure pass-through. No special handling.
- **D-09:** No `Refund.delete/2` — refunds are financial records, cannot be deleted. @moduledoc notes: "Use cancel/3 to cancel a pending refund."
- **D-10:** `Refund.update/3` @doc notes: "Only the metadata field can be updated on a Refund."
- **D-11:** `Refund.create/3` arity — `create(client, params, opts \\ [])`. Resources that require params use /3.

### Checkout Session Design
- **D-12:** Module name: `LatticeStripe.Checkout.Session`. Matches Stripe's `checkout.session` object type. File at `lib/lattice_stripe/checkout/session.ex`.
- **D-13:** All known top-level fields as struct keys + `extra` map. Same pattern as PaymentMethod (~53 fields). Nil fields have zero cost. Nested objects (payment_method_options, shipping_options, custom_text, total_details) remain as plain maps per Phase 4 D-06.
- **D-14:** `Checkout.Session.create/3` validates `mode` param via `require_param!/3`. Always required, vague Stripe error without it. Does NOT validate `success_url` or `line_items` — those depend on mode and configuration.
- **D-15:** Include `list_line_items/3` — `Checkout.Session.list_line_items(client, session_id, params)`. Nested list endpoint. Common fulfillment use case.
- **D-16:** Include `stream_line_items!/3` — wraps `List.stream!/2` with `LineItem.from_map/1`. Consistency with stream pattern.
- **D-17:** Include `search/3` + `search_stream!/3`. Stripe supports search for Checkout Sessions. Same pattern as Customer.search.
- **D-18:** `expire/3` — `expire(client, id, params \\ %{})`. Same action verb pattern. No local validation. Standard error pass-through if session can't be expired.
- **D-19:** Include `stream!/2` for auto-paginating list results. Consistency with all resources.
- **D-20:** No `update` function — Checkout Sessions cannot be updated via API. Omit entirely. @moduledoc notes: "Checkout Sessions cannot be updated after creation. Use expire/3 to cancel an open session."
- **D-21:** No `delete` function — same reasoning. @moduledoc notes this.
- **D-22:** Brief @moduledoc note: "Some fields can be modified via the Stripe Dashboard but not through the API."
- **D-23:** `create/3` arity — `create(client, params, opts \\ [])`. Same as Refund.

### Checkout LineItem
- **D-24:** Create `LatticeStripe.Checkout.LineItem` struct with `from_map/1`, `@known_fields`, `extra` map. Typed deserialization — consistent with all other resources. All official Stripe SDKs return typed LineItem objects.
- **D-25:** Separate file: `lib/lattice_stripe/checkout/line_item.ex`. One module per file.
- **D-26:** Public `@moduledoc` — developers pattern match on `%LineItem{}`. Notes provenance: "Represents a line item in a Checkout Session. Returned by `Checkout.Session.list_line_items/3`. Line items cannot be created or fetched independently."
- **D-27:** LineItem Inspect shows: `id`, `object`, `description`, `quantity`, `amount_total`. Drops currency (session already shows it). Description included for item identification.

### Inspect Implementation
- **D-28:** Refund Inspect shows: `id`, `object`, `amount`, `currency`, `status`. Hides payment_intent, reason, metadata, destination_details.
- **D-29:** Checkout.Session Inspect shows: `id`, `object`, `mode`, `status`, `payment_status`, `amount_total`, `currency` (7 fields). Hides customer_email, customer_details, shipping_details, and all PII. More fields than other resources but Checkout is complex.
- **D-30:** All PII fields hidden in Checkout.Session Inspect — customer_email, customer_details, shipping_details consistent with Customer/PaymentMethod PII-safe conventions.

### Struct Design
- **D-31:** Standard dot-access only — no custom Access behaviour. Consistent with all resources.
- **D-32:** All nested objects as plain maps (payment_method_options, shipping_options, total_details, etc.). Consistent with Phase 4 D-06. Typed expansion deferred with EXPD-02.
- **D-33:** Refund `destination_details` is a struct field with plain map value. Known Stripe field.

### Error Handling
- **D-34:** No new error types for Refund or Checkout. Use existing Error struct with type/code fields. Stripe's error type and code are already pattern-matchable.
- **D-35:** Standard error pass-through for expire on completed session, refund on fully-refunded PI, etc.
- **D-36:** `require_param!` raises `ArgumentError` (Elixir convention for invalid function arguments). Same as PaymentMethod.list.

### Bang Variants
- **D-37:** All tuple-returning functions get bang variants. No exceptions. create!/3, retrieve!/2, update!/3, cancel!/3, list!/2, search!/3, list_line_items!/3, expire!/3. Stream functions are already bang-only.

### Plan Structure
- **D-38:** Two plans:
  - `06-01-PLAN.md` — Retroactive fixture extraction (Customer, PaymentIntent, SetupIntent, PaymentMethod) + Refund resource (create, retrieve, update, cancel, list, stream + tests)
  - `06-02-PLAN.md` — Checkout.Session core (create 3 modes, retrieve, list, expire, search, stream) + LineItem struct + list_line_items + stream_line_items + tests
- **D-39:** 06-01 starts with fixture extraction as prep step, then builds Refund on the new fixture pattern. Single atomic commit for fixture migration.
- **D-40:** 06-02 builds Session first (core CRUD + expire + search), then adds LineItem struct + list_line_items + stream_line_items.
- **D-41:** Larger 06-02 is acceptable — Checkout follows established patterns, it's mechanical copy-adapt work.

### Test Strategy
- **D-42:** Separate fixture modules per resource in `test/support/fixtures/`. Module names: `LatticeStripe.Test.Fixtures.{Resource}`. One file per resource.
  - `test/support/fixtures/customer.ex` — LatticeStripe.Test.Fixtures.Customer
  - `test/support/fixtures/payment_intent.ex` — LatticeStripe.Test.Fixtures.PaymentIntent
  - `test/support/fixtures/setup_intent.ex` — LatticeStripe.Test.Fixtures.SetupIntent
  - `test/support/fixtures/payment_method.ex` — LatticeStripe.Test.Fixtures.PaymentMethod
  - `test/support/fixtures/refund.ex` — LatticeStripe.Test.Fixtures.Refund
  - `test/support/fixtures/checkout_session.ex` — LatticeStripe.Test.Fixtures.Checkout.Session
  - `test/support/fixtures/checkout_line_item.ex` — LatticeStripe.Test.Fixtures.Checkout.LineItem
- **D-43:** Fixture naming convention: `resource_json/0` for defaults, scenario variants with descriptive names. E.g., `refund_json/0`, `refund_partial_json/0`, `refund_pending_json/0`, `checkout_session_payment_json/0`, `checkout_session_subscription_json/0`, `checkout_session_expired_json/0`.
- **D-44:** Overridable fixtures: `refund_json/0` returns defaults, `refund_json/1` accepts a map and does `Map.merge(defaults, overrides)`. String keys matching Stripe JSON.
- **D-45:** Retroactive migration: existing Phase 4/5 inline JSON builders extracted to fixture modules. Same naming pattern: `customer_json/0`, `payment_intent_json/0`, etc. Enhanced with realistic-looking data during migration (real-looking Stripe IDs, realistic timestamps). Same commit for extraction + import updates.
- **D-46:** Fixture modules imported in test files: `import LatticeStripe.Test.Fixtures.Refund`. Consistent with TestHelpers import pattern.
- **D-47:** TestHelpers' response wrappers (ok_response/1, error_response/0, list_json/2) stay in test_helpers.ex — they're transport-level, not resource fixtures.
- **D-48:** Test all 3 Checkout create modes separately (payment, subscription, setup). Low effort since they differ only in params.
- **D-49:** Standard test coverage + mode-specific. No additional edge case tests beyond standard patterns.
- **D-50:** elixirc_paths(:test) already covers test/support/ recursively — no mix.exs changes needed.

### Documentation
- **D-51:** Key caveats only in @doc — things that affect SDK usage. Don't replicate Stripe's full docs. Link to Stripe for details.
- **D-52:** Link to Stripe API reference in each @moduledoc: "## Stripe API Reference\n[Refunds](https://stripe.com/docs/api/refunds)"
- **D-53:** Realistic params in @doc examples — real Stripe param names and plausible values. Developers copy-paste from docs.
- **D-54:** All 3 Checkout mode examples in create's @doc (not moduledoc). Payment, subscription, and setup mode examples.
- **D-55:** @doc for create notes: "url field contains the hosted Checkout page link. Only present when status is open. Expires 24 hours after creation."
- **D-56:** @doc for create notes embedded mode: "When ui_mode is embedded, success_url is not required — use return_url instead."
- **D-57:** No per-module API version documentation. SDK version pin is in Config/Client.
- **D-58:** LineItem @moduledoc notes provenance and non-fetchability.

### Claude's Discretion
- Internal `from_map/1` implementation details for all structs
- Exact struct field lists (follow Stripe's API reference)
- @moduledoc and @doc content, formatting, and example data beyond what's specified
- Helper function organization within modules
- Exact fixture data shapes and scenario coverage
- Task ordering within each plan
- How to handle optional/nilable fields on structs

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — Core value, constraints, design philosophy, key decisions
- `.planning/REQUIREMENTS.md` — Full v1 requirements (Phase 6: RFND-01..04, CHKT-01..07)
- `.planning/ROADMAP.md` — Phase structure, dependencies, success criteria

### Prior phase context (builds on these)
- `.planning/phases/01-transport-client-configuration/01-CONTEXT.md` — D-04/D-05 (Request struct pipeline), D-12 (extra field pattern), D-13 (typed structs), D-17 (flat module structure)
- `.planning/phases/02-error-handling-retry/02-CONTEXT.md` — D-04 (no Jason.Encoder), D-14 (retry in Client.request)
- `.planning/phases/03-pagination-response/03-CONTEXT.md` — D-01..09 (stream API), D-10..17 (List struct, search), D-18..26 (Response struct, return types)
- `.planning/phases/04-customers-paymentintents/04-CONTEXT.md` — D-01..18 (resource module pattern, struct design, Inspect, testing, return types)
- `.planning/phases/05-setupintents-paymentmethods/05-CONTEXT.md` — D-01..28 (Resource helpers, test helpers, attach/detach, require_param!, PaymentMethod struct)

### Existing implementation (modify/extend these)
- `lib/lattice_stripe/resource.ex` — Shared resource helpers (unwrap_singular/2, unwrap_list/2, unwrap_bang!/1, require_param!/3)
- `lib/lattice_stripe/client.ex` — `request/2`, `request!/2` — resource modules call these
- `lib/lattice_stripe/request.ex` — `%Request{}` struct resource modules build
- `lib/lattice_stripe/response.ex` — `%Response{}` returned by Client
- `lib/lattice_stripe/list.ex` — `%List{}` with `stream!/2`, `stream/2` — resource stream functions wrap these
- `test/support/test_helpers.ex` — ok_response/1, error_response/0, list_json/2 (stays here)

### Existing test files (migrate fixtures from these)
- `test/lattice_stripe/customer_test.exs` — Inline JSON builders to extract
- `test/lattice_stripe/payment_intent_test.exs` — Inline JSON builders to extract
- `test/lattice_stripe/setup_intent_test.exs` — Inline JSON builders to extract
- `test/lattice_stripe/payment_method_test.exs` — Inline JSON builders to extract

### New files (create these)
- `lib/lattice_stripe/refund.ex` — `%Refund{}` struct + create/retrieve/update/cancel/list/stream
- `lib/lattice_stripe/checkout/session.ex` — `%Checkout.Session{}` struct + create/retrieve/list/expire/search/stream/list_line_items/stream_line_items
- `lib/lattice_stripe/checkout/line_item.ex` — `%Checkout.LineItem{}` struct + from_map/1
- `test/support/fixtures/customer.ex` — LatticeStripe.Test.Fixtures.Customer
- `test/support/fixtures/payment_intent.ex` — LatticeStripe.Test.Fixtures.PaymentIntent
- `test/support/fixtures/setup_intent.ex` — LatticeStripe.Test.Fixtures.SetupIntent
- `test/support/fixtures/payment_method.ex` — LatticeStripe.Test.Fixtures.PaymentMethod
- `test/support/fixtures/refund.ex` — LatticeStripe.Test.Fixtures.Refund
- `test/support/fixtures/checkout_session.ex` — LatticeStripe.Test.Fixtures.Checkout.Session
- `test/support/fixtures/checkout_line_item.ex` — LatticeStripe.Test.Fixtures.Checkout.LineItem
- `test/lattice_stripe/refund_test.exs` — Refund resource tests
- `test/lattice_stripe/checkout/session_test.exs` — Checkout.Session resource tests

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Resource` — unwrap_singular/2, unwrap_list/2, unwrap_bang!/1, require_param!/3. All Phase 6 resources use these.
- `LatticeStripe.Client.request/2` and `request!/2` — Full request pipeline with retry, telemetry, transport dispatch.
- `LatticeStripe.List.stream!/2` and `stream/2` — Auto-pagination. Resource stream functions wrap these with typed from_map/1.
- `LatticeStripe.List.from_json/3` — List deserialization (auto-detected by Client).
- `LatticeStripe.FormEncoder` — Nested param encoding for POST bodies (Checkout line_items nesting).
- `LatticeStripe.TestHelpers` — test_client/1, ok_response/1, error_response/0, list_json/2.

### Established Patterns (from Customer, PaymentIntent, SetupIntent, PaymentMethod)
- Request struct pipeline: build `%Request{}` -> `Client.request/2` -> `%Response{}` -> unwrap via Resource helpers
- PII-safe custom `Inspect` via `Inspect.Algebra` on all public structs
- No `Jason.Encoder` on any struct
- `@known_fields` sigil + `extra: Map.drop(map, @known_fields)` pattern
- `from_map/1` constructor for JSON -> struct deserialization
- `require_param!/3` for DX-first local validation (PaymentMethod.list customer requirement)
- Mox-based testing with `LatticeStripe.MockTransport`
- Action verb functions (confirm, capture, cancel) use same unwrap_singular pattern

### Integration Points
- Phase 7 (Webhooks): Event parsing may reference Refund/Checkout.Session types. Type registry deferred.
- Phase 9 (Testing): Integration tests with stripe-mock will exercise these resources.
- Phase 10 (Documentation): Resource module guides and examples.

</code_context>

<specifics>
## Specific Ideas

- 06-01 starts with fixture infrastructure extraction (retroactive migration of Phase 4/5 test fixtures) as prep, then builds Refund on the clean foundation. Fixtures enhanced with realistic data during migration.
- 06-02 builds Checkout.Session core first, then adds LineItem struct and nested endpoints. Larger plan is acceptable.
- Refund is the simpler resource — build first to validate the fixture pattern, then Checkout adds complexity (3 modes, nested endpoints, LineItem struct).
- Checkout.Session is the first nested-namespace module (LatticeStripe.Checkout.Session) — establishes the pattern for any future nested resources.
- LineItem struct included for typed deserialization consistency — all official Stripe SDKs return typed LineItem objects. Stream variant included for pattern consistency at near-zero cost.
- Fixture modules use overridable Map.merge pattern: `refund_json/0` for defaults, `refund_json/1` with overrides. Imported in test files.

</specifics>

<deferred>
## Deferred Ideas

- **Type registry** — `%{"customer" => Customer, ...}` for automatic deserialization. Deferred to Phase 7 (Webhooks) which is the first consumer.
- **Typed expansion** (EXPD-02) — Expanded nested objects deserialized into typed structs. Deferred until more resources exist.
- **Status atom conversion** (EXPD-05) — Convert string status fields to atoms. All-resources-at-once sweep in a future phase.
- **Shared resource macro/DSL** — Not needed. Hand-written modules + Resource helper module is sufficient.

</deferred>

---

*Phase: 06-refunds-checkout*
*Context gathered: 2026-04-02*
