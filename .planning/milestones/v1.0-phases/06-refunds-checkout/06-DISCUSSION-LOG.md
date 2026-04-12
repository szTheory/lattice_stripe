# Phase 6: Refunds & Checkout - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 06-refunds-checkout
**Areas discussed:** Refund API design, Checkout Session complexity, Plan structure, Inspect & struct fields, Error handling specifics, Test strategy, Naming consistency, Documentation depth, Refund update semantics, Checkout Session no-update, Fixture naming conventions, Refund.create arity, Checkout.Session no-create mode, Bang variant completeness

---

## Refund API Design

### Refund Scoping

| Option | Description | Selected |
|--------|-------------|----------|
| PaymentIntent only | Matches modern Stripe API guidance. Charge-based refunds are legacy. | ✓ |
| Both PaymentIntent and Charge | Accept either. More flexible, matches full API surface. | |
| You decide | Claude picks based on SDK philosophy. | |

**User's choice:** PaymentIntent only
**Notes:** Modern API, clean and opinionated.

### Cancel Support

| Option | Description | Selected |
|--------|-------------|----------|
| Include cancel | Same action verb pattern. Completes the Refund API. | ✓ |
| Skip cancel | Not in requirements. Add later. | |
| You decide | Claude decides. | |

**User's choice:** Include cancel

### List Params

| Option | Description | Selected |
|--------|-------------|----------|
| No required params | All params optional. Stripe allows listing all refunds. | ✓ |
| Require payment_intent | Force scoping for safety. | |

**User's choice:** No required params

### Create Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Validate payment_intent | require_param!/3 raises ArgumentError. DX-first. | ✓ |
| No local validation | Let Stripe validate. Pure pass-through. | |
| You decide | Claude picks. | |

**User's choice:** Validate payment_intent

### Partial Refund Docs

| Option | Description | Selected |
|--------|-------------|----------|
| Show partial refund example | Include amount param example in @doc. Common use case. | ✓ |
| Minimal docs | Basic create only, link to Stripe. | |
| You decide | Claude decides. | |

**User's choice:** Show partial refund example

### Reason Param Validation

| Option | Description | Selected |
|--------|-------------|----------|
| No local validation | Pass through. Avoids hardcoding enum values. | ✓ |
| Validate with known values | Check against known values. Catches typos. | |
| You decide | Claude decides. | |

**User's choice:** No local validation

### Streaming

| Option | Description | Selected |
|--------|-------------|----------|
| Include stream | Consistency. Trivial to add. | ✓ |
| Skip stream | Refund lists typically small. | |
| You decide | Claude decides. | |

**User's choice:** Include stream

### Search

| Option | Description | Selected |
|--------|-------------|----------|
| No search | Stripe has no search endpoint for Refunds. | ✓ |
| You decide | Claude confirms. | |

**User's choice:** No search

### Edge Cases

| Option | Description | Selected |
|--------|-------------|----------|
| Pass-through only | All special params passed through. Stripe validates. | ✓ |
| Document Connect params | Add @doc notes for Connect params. | |

**User's choice:** Pass-through only

---

## Checkout Session Complexity

### Struct Size

| Option | Description | Selected |
|--------|-------------|----------|
| All known fields + extra map | Same pattern as PaymentMethod. Nil fields zero cost. | ✓ |
| Minimal struct + large extra map | Only ~15 most common fields as struct keys. | |
| You decide | Claude decides. | |

**User's choice:** All known fields + extra map

### Create Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Validate mode only | require_param!/3 for mode. Don't validate success_url or line_items. | ✓ |
| No local validation | Pure pass-through. | |
| Validate mode + success_url | Require both. | |
| You decide | Claude decides. | |

**User's choice:** Validate mode only

### list_line_items

| Option | Description | Selected |
|--------|-------------|----------|
| Include list_line_items | Common fulfillment use case. Nested list endpoint. | ✓ |
| Skip for now | Not in requirements. | |
| You decide | Claude decides. | |

**User's choice:** Include list_line_items

### Module Name

| Option | Description | Selected |
|--------|-------------|----------|
| LatticeStripe.Checkout.Session | Matches Stripe's object type. Leaves room for sub-resources. | ✓ |
| LatticeStripe.CheckoutSession | Flat, simpler. | |
| You decide | Claude decides. | |

**User's choice:** LatticeStripe.Checkout.Session

### Expire Validation

| Option | Description | Selected |
|--------|-------------|----------|
| No validation | Same pattern as PI.cancel. Standard error pass-through. | ✓ |
| You decide | Claude decides. | |

**User's choice:** No validation

### Streaming

| Option | Description | Selected |
|--------|-------------|----------|
| Include stream | Consistency. Users listing for reporting benefit. | ✓ |
| Skip stream | Sessions typically accessed individually. | |
| You decide | Claude decides. | |

**User's choice:** Include stream

### File Path

| Option | Description | Selected |
|--------|-------------|----------|
| checkout/session.ex is fine | Natural Elixir convention for nested modules. | ✓ |
| You decide | Claude follows conventions. | |

**User's choice:** checkout/session.ex

### LineItem Struct (Extended Discussion)

User requested deeper analysis from use case, best practices, and idiomatic Elixir perspectives before answering.

**Analysis provided:**
- Use case: order fulfillment needs typed access to price, quantity, amount_total
- Other SDKs: Ruby, Python, Node all return typed LineItem objects
- Idiomatic Elixir: pattern matching on %LineItem{} is natural; string-key maps feel foreign
- Principle of least surprise: every other endpoint returns typed structs

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both (struct + stream) | Create LineItem struct. Include stream_line_items!/3 for consistency. | ✓ |
| Struct yes, skip stream | Create struct but no stream. | |
| Skip both | Plain maps, no struct. | |

**User's choice:** Yes, both

### Search

| Option | Description | Selected |
|--------|-------------|----------|
| Include search + search_stream! | Stripe supports it. Same pattern as Customer.search. | ✓ |
| Skip search | Not in requirements. | |
| You decide | Claude decides. | |

**User's choice:** Include search + search_stream!

### Doc Examples

| Option | Description | Selected |
|--------|-------------|----------|
| Show all 3 modes | One example per mode in @doc. Developers copy-paste. | ✓ |
| Payment mode only + link | Show payment, note others exist. | |
| You decide | Claude decides. | |

**User's choice:** Show all 3 modes

### URL Lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| Note in @doc | Document url availability and 24h expiry. Saves debugging nil URLs. | ✓ |
| Skip | Stripe docs cover it. | |
| You decide | Claude decides. | |

**User's choice:** Note in @doc

### Extra Params

| Option | Description | Selected |
|--------|-------------|----------|
| Pass-through only | All config params are just params. Stripe validates. | ✓ |
| You decide | Claude decides. | |

**User's choice:** Pass-through only

### File Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Separate files | checkout/session.ex and checkout/line_item.ex. One module per file. | ✓ |
| Same file | Both in checkout/session.ex. | |
| You decide | Claude decides. | |

**User's choice:** Separate files

### LineItem Visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Public @moduledoc | Developers pattern match on %LineItem{}. Needs documentation. | ✓ |
| @moduledoc false | Implementation detail. | |
| You decide | Claude decides. | |

**User's choice:** Public @moduledoc

### Embedded Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Mention in create @doc | Note embedded mode doesn't need success_url, uses return_url. | ✓ |
| Skip | Too much detail. | |
| You decide | Claude decides. | |

**User's choice:** Mention in create @doc

---

## Plan Structure

### Plan Split

| Option | Description | Selected |
|--------|-------------|----------|
| Two plans: Refund then Checkout | 06-01: Refund. 06-02: Checkout.Session + LineItem. | ✓ |
| Three plans | Finer granularity. | |
| One combined plan | Single plan for everything. | |
| You decide | Claude decides. | |

**User's choice:** Two plans

### 06-01 Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Pure Refund + fixture extraction | Fixture migration as prep step, then Refund resource. | ✓ |
| Include any shared work | If shared work emerges, do it in 06-01. | |
| You decide | Claude decides. | |

**User's choice:** Pure Refund + fixture extraction

### Build Order (06-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Session first, LineItem after | Build Session core, then add LineItem + list_line_items. | ✓ |
| LineItem first | Define struct first as dependency. | |
| You decide | Claude decides. | |

**User's choice:** Session first, LineItem after

### Plan Sizing

| Option | Description | Selected |
|--------|-------------|----------|
| Larger 06-02 is fine | Mechanical copy-adapt work. One plan keeps context together. | ✓ |
| Split if too large | Split during planning if needed. | |
| You decide | Claude decides. | |

**User's choice:** Larger 06-02 is fine

---

## Inspect & Struct Fields

### Refund Inspect

| Option | Description | Selected |
|--------|-------------|----------|
| id, object, amount, currency, status | Essential refund info. Hides PII and metadata. | ✓ |
| id, object, amount, status, reason | Includes reason for debugging. | |
| You decide | Claude decides. | |

**User's choice:** id, object, amount, currency, status

### Session Inspect

| Option | Description | Selected |
|--------|-------------|----------|
| id, object, mode, status, payment_status, amount_total, currency | 7 fields for complex resource. Includes money fields. | ✓ |
| id, object, mode, status, payment_status | 5 most important structural fields. | |
| id, object, mode, status, url | Includes actionable URL. | |
| You decide | Claude decides. | |

**User's choice:** id, object, mode, status, payment_status, amount_total, currency

### LineItem Inspect

| Option | Description | Selected |
|--------|-------------|----------|
| id, object, description, quantity, amount_total | Drops currency (session shows it). Description for item identification. | ✓ |
| id, object, quantity, amount_total, currency | Money-focused. Hides description. | |
| You decide | Claude decides. | |

**User's choice:** id, object, description, quantity, amount_total

### Session PII

| Option | Description | Selected |
|--------|-------------|----------|
| Hide all PII fields | Exclude customer_email, customer_details, shipping_details. Consistent. | ✓ |
| You decide | Claude applies conventions. | |

**User's choice:** Hide all PII fields

### Access Behaviour

| Option | Description | Selected |
|--------|-------------|----------|
| Standard dot-access only | No custom Access. Consistent with all resources. | ✓ |
| You decide | Claude follows conventions. | |

**User's choice:** Standard dot-access only

### Nested Types

| Option | Description | Selected |
|--------|-------------|----------|
| All plain maps | Consistent with Phase 4 D-06. Typed expansion deferred. | ✓ |
| Type specific ones | Some frequently accessed nested objects get types. | |
| You decide | Claude follows pattern. | |

**User's choice:** All plain maps

### Destination Details

| Option | Description | Selected |
|--------|-------------|----------|
| Struct field, plain map value | Known Stripe field. Consistent with @known_fields convention. | ✓ |
| You decide | Claude follows convention. | |

**User's choice:** Struct field, plain map value

### LineItem Currency

| Option | Description | Selected |
|--------|-------------|----------|
| Description over currency | Session shows currency. Description more useful for item identification. | ✓ |
| Include both (6 fields) | Show all 6 fields. | |
| You decide | Claude decides. | |

**User's choice:** Description over currency

---

## Error Handling Specifics

### Refund Errors

| Option | Description | Selected |
|--------|-------------|----------|
| No new error types | Existing Error struct with type/code. Pattern-matchable. | ✓ |
| Add refund-specific helpers | Helper functions for common refund errors. | |
| You decide | Claude decides. | |

**User's choice:** No new error types

### Expire Errors

| Option | Description | Selected |
|--------|-------------|----------|
| Standard error pass-through | {:error, %Error{}} with Stripe's details. Consistent with PI.cancel. | ✓ |
| You decide | Claude follows patterns. | |

**User's choice:** Standard error pass-through

### Validation Error Type

| Option | Description | Selected |
|--------|-------------|----------|
| ArgumentError | Elixir convention. Consistent with require_param!/3. | ✓ |
| You decide | Claude follows convention. | |

**User's choice:** ArgumentError

### Dual Params (payment_intent + charge)

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore — pass through | Only ensure payment_intent IS present, not that charge ISN'T. Simplest. | ✓ |
| Raise if charge present | Actively reject charge param. | |
| You decide | Claude decides. | |

**User's choice:** Ignore — pass through

---

## Test Strategy

### Mode Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Test all 3 modes | One test per mode. Verifies request building for each. | ✓ |
| Payment mode only | Representative test. | |
| You decide | Claude decides. | |

**User's choice:** Test all 3 modes

### Fixtures Approach

**User's choice:** Rich fixtures with good names, covering happy path, main error cases, and boundary. Realistic looking, easy to discover.

### Fixture Location

| Option | Description | Selected |
|--------|-------------|----------|
| Separate fixture module | test/support/fixtures/{resource}.ex. Centralizes fixtures. | ✓ |
| In test file, well-organized | Keep in each test file with named functions. | |
| You decide | Claude decides. | |

**User's choice:** Separate fixture module

### Refund Fixtures

| Option | Description | Selected |
|--------|-------------|----------|
| Same rich approach | Named fixtures: refund_full_json/0, refund_partial_json/0, etc. Consistency. | ✓ |
| Minimal inline | Simple enough for inline maps. | |
| You decide | Claude decides. | |

**User's choice:** Same rich approach

### Fixture Organization

| Option | Description | Selected |
|--------|-------------|----------|
| One per resource | Separate files per resource. Easy to find. | ✓ |
| One combined module | Single fixtures.ex. | |
| You decide | Claude decides. | |

**User's choice:** One per resource

### Retroactive Migration

| Option | Description | Selected |
|--------|-------------|----------|
| Retroactively migrate | Move all Phase 4/5 fixtures to test/support/fixtures/ modules. | ✓ |
| Leave existing as-is | New convention from Phase 6 only. | |
| You decide | Claude decides. | |

**User's choice:** Retroactively migrate

### Migration Plan Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Prep step in 06-01 | First task: extract fixtures. Then build Refund. | ✓ |
| Separate 06-00 plan | Dedicated infrastructure plan. | |
| You decide | Claude decides. | |

**User's choice:** Prep step in 06-01

### Enhancement During Migration

| Option | Description | Selected |
|--------|-------------|----------|
| Enhance during migration | Make fixtures realistic. Better data for whole codebase. | ✓ |
| Preserve exact values | Pure mechanical extraction. Zero risk. | |
| You decide | Claude decides. | |

**User's choice:** Enhance during migration

### Override API

| Option | Description | Selected |
|--------|-------------|----------|
| Overridable fixtures | Map.merge pattern. refund_json/0 defaults, refund_json/1 with overrides. | ✓ |
| Static fixtures only | No params. | |
| You decide | Claude decides. | |

**User's choice:** Overridable fixtures

### File Naming

| Option | Description | Selected |
|--------|-------------|----------|
| test/support/fixtures/{resource}.ex | Organized in fixtures/ subdirectory. | ✓ |
| test/support/{resource}_fixtures.ex | Flat in support/. | |
| You decide | Claude decides. | |

**User's choice:** test/support/fixtures/{resource}.ex

### LineItem Fixture File

| Option | Description | Selected |
|--------|-------------|----------|
| Separate file | Consistent with separate module pattern. | ✓ |
| Combined with Session | Related code together. | |
| You decide | Claude decides. | |

**User's choice:** Separate file

### Migration Git Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Same commit | Atomic: extract + update imports together. | ✓ |
| Separate commits | Easier to bisect. | |
| You decide | Claude decides. | |

**User's choice:** Same commit

---

## Naming Consistency

### Nested List Function

| Option | Description | Selected |
|--------|-------------|----------|
| list_line_items/3 | Descriptive, reads naturally. Matches Stripe API naming. | ✓ |
| line_items/3 | Shorter but ambiguous. | |
| You decide | Claude decides. | |

**User's choice:** list_line_items/3

### Stream Variant Name

| Option | Description | Selected |
|--------|-------------|----------|
| stream_line_items!/3 | Follows list_X -> stream_X! pattern. | ✓ |
| line_items_stream!/3 | Reads more naturally in English. | |
| You decide | Claude decides. | |

**User's choice:** stream_line_items!/3

### Bang Variants for Compound Names

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include bang variant | list_line_items!/3. Consistent: every tuple-returning gets bang. | ✓ |
| Skip bang for nested | Reduces API surface. | |
| You decide | Claude decides. | |

**User's choice:** Yes, include bang

### Search Naming

| Option | Description | Selected |
|--------|-------------|----------|
| search/3 + search_stream!/3 | Consistent with Customer.search. Maps to /search endpoint. | ✓ |
| You decide | Claude follows conventions. | |

**User's choice:** search/3 + search_stream!/3

### Cancel Naming

| Option | Description | Selected |
|--------|-------------|----------|
| cancel/3 | Same as PI.cancel/3 and SI.cancel/3. Consistent action verb. | ✓ |
| You decide | Claude follows conventions. | |

**User's choice:** cancel/3

### Fixture Module Names

| Option | Description | Selected |
|--------|-------------|----------|
| LatticeStripe.Test.Fixtures.{Resource} | More explicit test-only namespace. | ✓ |
| LatticeStripe.Fixtures.{Resource} | Simple namespace. | |
| You decide | Claude decides. | |

**User's choice:** LatticeStripe.Test.Fixtures.{Resource}

### Import Style

| Option | Description | Selected |
|--------|-------------|----------|
| import | Functions available without prefix. Consistent with TestHelpers. | ✓ |
| alias + prefix | More explicit. | |
| You decide | Claude decides. | |

**User's choice:** import

---

## Documentation Depth

### Business Logic in Docs

| Option | Description | Selected |
|--------|-------------|----------|
| Key caveats only | Things that affect SDK usage. Link to Stripe for details. | ✓ |
| Comprehensive lifecycle | Self-contained docs. | |
| Minimal — link to Stripe | Only SDK interface. | |
| You decide | Claude decides. | |

**User's choice:** Key caveats only

### API Reference Links

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, link in moduledoc | Easy click-through to Stripe API reference. | ✓ |
| No external links | Links go stale. | |
| You decide | Claude decides. | |

**User's choice:** Yes, link in moduledoc

### Example Style

| Option | Description | Selected |
|--------|-------------|----------|
| Realistic params | Real param names, plausible values. Developers copy-paste. | ✓ |
| Minimal placeholders | Shorter, less maintenance. | |
| You decide | Claude follows patterns. | |

**User's choice:** Realistic params

### Mode Examples Location

| Option | Description | Selected |
|--------|-------------|----------|
| @doc on create | All 3 modes in create's @doc. Where developers look first. | ✓ |
| @moduledoc overview | Conceptual in moduledoc. | |
| You decide | Claude decides. | |

**User's choice:** @doc on create

### API Version Docs

| Option | Description | Selected |
|--------|-------------|----------|
| Skip per-module versioning | SDK version pin is in Config/Client. One central place. | ✓ |
| Note in moduledoc | Explicit version per resource. | |
| You decide | Claude decides. | |

**User's choice:** Skip per-module versioning

### LineItem Provenance

| Option | Description | Selected |
|--------|-------------|----------|
| Note provenance | Mention returned by Session.list_line_items, not independently fetchable. | ✓ |
| Skip — obvious | Developers discover through usage. | |
| You decide | Claude decides. | |

**User's choice:** Note provenance

---

## Refund Update Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Note in @doc | "Only metadata can be updated." Saves debugging. | ✓ |
| Pure pass-through | Don't document Stripe limitations. | |
| You decide | Claude decides. | |

**User's choice:** Note in @doc

## Checkout Session No-Update

| Option | Description | Selected |
|--------|-------------|----------|
| Omit update entirely | No update/3 function. Moduledoc notes limitation. | ✓ |
| Include update that raises | Clear error message. | |
| You decide | Claude decides. | |

**User's choice:** Omit update entirely

## Checkout Session No-Delete

| Option | Description | Selected |
|--------|-------------|----------|
| Omit delete | Same reasoning as no-update. | ✓ |
| You decide | Claude follows pattern. | |

**User's choice:** Omit delete

## Fixture Naming Conventions

### Function Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| resource_json/0 pattern | Prefix with resource name. Prevents collisions on import. | ✓ |
| Bare scenario names | Shorter but collision-prone. | |
| You decide | Claude decides. | |

**User's choice:** resource_json/0 pattern

### Checkout Mode Fixtures

| Option | Description | Selected |
|--------|-------------|----------|
| checkout_session_{mode}_json/0 | Verbose but unambiguous. Easy to grep. | ✓ |
| session_{mode}_json/0 | Shorter, drops checkout_. | |
| You decide | Claude decides. | |

**User's choice:** checkout_session_{mode}_json/0

### Override Parameter

| Option | Description | Selected |
|--------|-------------|----------|
| Map merge | Map.merge(defaults, overrides). String keys match Stripe JSON. | ✓ |
| Keyword list | More Elixir-idiomatic but mismatch with JSON keys. | |
| You decide | Claude decides. | |

**User's choice:** Map merge

### Migration Names

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern | customer_json/0, payment_intent_json/0. Consistent across all. | ✓ |
| You decide | Claude follows pattern. | |

**User's choice:** Same pattern

## Additional Decisions

### Refund.create Arity

| Option | Description | Selected |
|--------|-------------|----------|
| create/3: (client, params, opts) | Resources that require params use /3. Consistent with Checkout. | ✓ |
| create/2: (client, params) | Simpler, consistent with Customer. | |
| You decide | Claude decides. | |

**User's choice:** create/3

### Dashboard Edit Note

| Option | Description | Selected |
|--------|-------------|----------|
| Brief note in moduledoc | Some fields modifiable via Dashboard but not API. | ✓ |
| No acknowledgment | Dashboard behavior outside SDK scope. | |
| You decide | Claude decides. | |

**User's choice:** Brief note in moduledoc

### Bang Variant Matrix

| Option | Description | Selected |
|--------|-------------|----------|
| All tuple-returning functions | No exceptions. create!, retrieve!, update!, cancel!, list!, search!, list_line_items!, expire!. | ✓ |
| Core CRUD only | Smaller surface. | |
| You decide | Claude decides. | |

**User's choice:** All tuple-returning functions

### Refund Delete

| Option | Description | Selected |
|--------|-------------|----------|
| Omit delete | Financial records, cannot be deleted. Use cancel/3. | ✓ |
| You decide | Claude follows pattern. | |

**User's choice:** Omit delete

### Test Helper Location

| Option | Description | Selected |
|--------|-------------|----------|
| Stay in test_helpers.ex | Transport-level wrappers, not resource fixtures. Different purpose. | ✓ |
| Move to fixtures | Centralize all fixture-related code. | |
| You decide | Claude decides. | |

**User's choice:** Stay in test_helpers.ex

---

## Claude's Discretion

- Internal from_map/1 implementation details for all structs
- Exact struct field lists (follow Stripe's API reference)
- @moduledoc and @doc content, formatting, and example data beyond what's specified
- Helper function organization within modules
- Exact fixture data shapes and scenario coverage
- Task ordering within each plan
- How to handle optional/nilable fields on structs

## Deferred Ideas

- Type registry (Phase 7)
- Typed expansion (EXPD-02)
- Status atom conversion (EXPD-05)
- Shared resource macro/DSL (not needed)
