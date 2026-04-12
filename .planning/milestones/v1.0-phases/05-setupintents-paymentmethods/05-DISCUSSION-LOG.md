# Phase 5: SetupIntents & PaymentMethods - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 05-setupintents-paymentmethods
**Areas discussed:** Attach/Detach API, PM list scoping, Sensitive field handling, Plan structure, PM type handling, Stream convenience, verify_microdeposits, Shared helper extraction, SI confirm params, PM create scope, Resource helper refactor scope, PM delete behavior, Status atom mapping, SI search API, PM struct field coverage, Local validation pattern, Test helpers, SI cancellation_reason, Type registry, SI latest_attempt, PM detach behavior, Moduledoc pattern
**Rounds:** 8 rounds of gray area selection

---

## Round 1: Core Design Decisions

### Attach/Detach API Design

| Option | Description | Selected |
|--------|-------------|----------|
| A: Params map | attach(client, pm_id, params) — same as confirm/capture/cancel | ✓ |
| B: Positional customer_id | attach(client, pm_id, customer_id) — required in signature | |
| C: Both forms | Pattern match string vs map, accept either | |

**User's choice:** A: Params map (Recommended)
**Notes:** Consistency with Phase 4 action verb pattern was the deciding factor.

---

### PaymentMethod List Scoping

| Option | Description | Selected |
|--------|-------------|----------|
| A: Same list/2, Stripe enforces | Uniform pattern, let Stripe return error | |
| B: Validate locally | ArgumentError before HTTP call if customer missing | ✓ |
| C: Convenience function | Add list_for_customer/3 alongside standard list/2 | |

**User's choice:** B: Validate locally
**Notes:** User prefers fail-fast over wasted HTTP round-trip. Follow-up confirmed ArgumentError (not error tuple) — this is a programmer mistake.

**Follow-up: Scope of validation**

| Option | Description | Selected |
|--------|-------------|----------|
| Only where known required | Case-by-case when Stripe requires a param | ✓ |
| Never again | PM list is the exception | |

**User's choice:** Only where known required

---

### Sensitive Field Handling — PaymentMethod Inspect

| Option | Description | Selected |
|--------|-------------|----------|
| A: type + brand + last4 | Show id, object, type, card.brand, card.last4. Hide billing, fingerprint, exp | ✓ |
| B: Only type | Show id, object, type only. Maximum safety | |
| C: type + brand only | No last4. Middle ground | |

**User's choice:** A: type + brand + last4 (Recommended)

### Sensitive Field Handling — SetupIntent Inspect

| Option | Description | Selected |
|--------|-------------|----------|
| Match PaymentIntent pattern | id, object, status, usage. Hide client_secret entirely | ✓ |
| Show more fields | Also show payment_method_types or customer | |

**User's choice:** Match PaymentIntent pattern

---

### Plan Structure

| Option | Description | Selected |
|--------|-------------|----------|
| A: One per resource | 05-01 SetupIntent, 05-02 PaymentMethod | ✓ |
| B: Single combined plan | One plan for both resources | |
| C: Three plans | Struct+CRUD per resource, then shared tests | |

**User's choice:** A: One per resource (Recommended)

---

## Round 2: Additional Design Decisions

### PaymentMethod Type Handling

| Option | Description | Selected |
|--------|-------------|----------|
| A: Keep Stripe's shape | Struct has card, us_bank_account, etc. as plain maps. Nil when not active | ✓ |
| B: Only active type data | Single type_data field | |
| C: Stripe shape + accessor | Standard shape plus type_details/1 convenience | |

**User's choice:** A: Keep Stripe's shape (Recommended)

---

### Stream Convenience Functions

| Option | Description | Selected |
|--------|-------------|----------|
| A: Params map + validate | stream!(client, params) with ArgumentError if customer missing | ✓ |
| B: Positional customer_id | stream!(client, customer_id, params) | |

**User's choice:** A: Params map + validate (Recommended)

---

### SetupIntent verify_microdeposits

| Option | Description | Selected |
|--------|-------------|----------|
| A: Include in Phase 5 | Same action verb pattern. Completes SI API | ✓ |
| B: Defer | Strict scope — only SINT-01..06 | |
| C: Include as bonus | Add but don't map to requirement | |

**User's choice:** A: Include in Phase 5 (Recommended)

---

## Round 3: Infrastructure Decisions

### Shared Helper Extraction

| Option | Description | Selected |
|--------|-------------|----------|
| A: Keep copy-pasting | Each module self-contained | |
| B: Helper module | LatticeStripe.Resource with from_map_fn arg. @moduledoc false | ✓ |
| C: use macro | __using__ injection. Rejected in Phase 4 D-01 | |

**User's choice:** B: Helper module (Recommended)

---

### SetupIntent.confirm Params

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern as PI confirm | confirm(client, id, params, opts). No special handling | ✓ |
| Validate payment_method | ArgumentError if payment_method missing | |

**User's choice:** Same pattern (Recommended)

---

### PaymentMethod.create Scope

| Option | Description | Selected |
|--------|-------------|----------|
| A: Pure pass-through | Same create(client, params). Stripe validates type + nested params | ✓ |
| B: Validate type param | ArgumentError if "type" missing | |
| C: Type-specific functions | create_card/2, create_bank_account/2, etc. | |

**User's choice:** A: Pure pass-through (Recommended)

---

## Round 4: Refactoring & Completeness

### Resource Helper Refactor Scope

| Option | Description | Selected |
|--------|-------------|----------|
| A: In 05-01 | Extract + refactor existing + build SetupIntent in one plan | ✓ |
| B: Separate 05-00 | Clean separation but extra execution round | |
| C: In 05-02 | Copy-paste first, then extract in PM plan | |

**User's choice:** A: In 05-01 (Recommended)

---

### PaymentMethod Delete Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| A: Don't include, moduledoc note | Same as PaymentIntent. No function. Doc says use detach | ✓ |
| C: Raise with helpful message | def delete always raises pointing to detach | |

**User's choice:** A: Don't include (Recommended)

---

### SetupIntent Status Atom Mapping

| Option | Description | Selected |
|--------|-------------|----------|
| A: Keep as strings | Match Phase 4. EXPD-05 deferred for all-resources sweep | ✓ |
| B: Convert to atoms now | Start EXPD-05 but breaks consistency | |
| C: Known-atom allowlist | Safe but mixed types | |

**User's choice:** A: Keep as strings (Recommended)

---

## Round 5: Search & Fields

### SetupIntent Search API / PaymentIntent Search Gap

| Option | Description | Selected |
|--------|-------------|----------|
| A: Add PI search in 05-01 | We're refactoring PI.ex anyway. Fill the gap | ✓ |
| B: Defer PI search | Strict Phase 5 scope | |

**User's choice:** A: Add PI search (Recommended)
**Notes:** Research confirmed SetupIntents have no search endpoint. PaymentIntents do but it was missed in Phase 4.

---

### PaymentMethod Struct Field Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| A: Common types only | card, us_bank_account, sepa_debit, link on struct. Rest in extra | |
| B: All type fields | All ~45 type-specific fields on struct. Most nil. Consistent access | ✓ |
| C: No type fields | All types via extra map | |

**User's choice:** B: All type fields (Recommended)
**Notes:** Nil struct fields have zero runtime cost in Elixir. Consistent access pattern matches Phase 1 D-12.

---

### Local Validation Pattern Details

| Option | Description | Selected |
|--------|-------------|----------|
| A: Inline in PM | 4 lines in list + stream. Simple but duplicated | |
| B: Private helper in PM | DRY within module but not reusable | |
| C: In Resource module | Resource.require_param!/3. Reusable, we're creating the module anyway | ✓ |

**User's choice:** C: In Resource module (Recommended)

---

## Round 6: Testing & Struct Details

### Testing Strategy — Shared Test Helpers

| Option | Description | Selected |
|--------|-------------|----------|
| A: Keep per-file | Status quo copy-paste | |
| B: Extract shared helpers | test/support/test_helpers.ex for common helpers | ✓ |

**User's choice:** B: Extract shared helpers (Recommended)

---

### SetupIntent cancellation_reason

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same as PI | Struct field. Known Stripe field per Phase 1 D-12 | ✓ |
| Discuss further | | |

**User's choice:** Yes, same as PaymentIntent

---

### Type Registry

| Option | Description | Selected |
|--------|-------------|----------|
| A: Still defer | No consumer in Phase 5. Build in Phase 7 | ✓ |
| B: Create now | ~15 line module ready for Phase 7 | |

**User's choice:** A: Still defer (Recommended)

---

## Round 7: Edge Cases

### SetupIntent latest_attempt Field

| Option | Description | Selected |
|--------|-------------|----------|
| Same as PI.latest_charge | Raw value (string ID or plain map). D-06 applies | ✓ |
| Discuss further | | |

**User's choice:** Same as latest_charge (Recommended)

---

### PM After Detach Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Default is fine | from_map handles customer: nil. Test details Claude's discretion | ✓ |
| Explicit test required | Mandate test asserting customer is nil | |

**User's choice:** Default is fine (Recommended)

---

### Resource Module @moduledoc Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Follow pattern, Claude's discretion | Same structure. PM docs note required customer + no-delete | ✓ |
| Specific doc sections | User describes wanted sections | |

**User's choice:** Follow pattern, Claude's discretion (Recommended)

---

## Claude's Discretion

- Internal from_map/1 implementation details for both structs
- Exact struct field lists (follow Stripe API reference)
- @moduledoc and @doc content, examples, formatting
- Test fixture data shapes
- Optional/nilable field handling
- Whether to verify customer==nil in detach tests
- Helper function organization within modules
- Task ordering within plans

## Deferred Ideas

- Type registry — Phase 7
- Typed expansion (EXPD-02) — future phase
- Status atom conversion (EXPD-05) — all-resources-at-once
- Shared resource macro/DSL — not needed
- Nested resource helpers (Customer.list_payment_methods) — use top-level PM.list with customer param
