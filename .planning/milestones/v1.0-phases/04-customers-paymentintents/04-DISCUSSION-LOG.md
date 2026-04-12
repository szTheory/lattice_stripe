# Phase 4: Customers & PaymentIntents - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 04-customers-paymentintents
**Areas discussed:** Resource Module Pattern, Typed Struct Design, Delete Response Handling, Search API Ergonomics
**Mode:** Auto (all recommended defaults selected)

---

## Resource Module Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-written with shared helpers | Explicit modules, extract helpers when duplication is obvious | ✓ |
| Macro-based DSL | `use LatticeStripe.Resource` with declarative config | |
| Shared base module | `defdelegate` pattern with common functions in base | |

**User's choice:** [auto] Hand-written with shared helpers (recommended default)
**Notes:** Establishes copyable pattern before abstracting. Matches Elixir ecosystem norms.

---

## Typed Struct Design

| Option | Description | Selected |
|--------|-------------|----------|
| Plain defstruct + from_map/1 | Simple constructor, mirror Stripe fields, extra catch-all | ✓ |
| Ecto-like schema | typed_struct or similar DSL for field definitions | |
| Map-only (no structs) | Return plain maps like Phase 1-3 | |

**User's choice:** [auto] Plain defstruct + from_map/1 (recommended default)
**Notes:** Top-level only, expanded objects stay as plain maps per Phase 3 D-28.

---

## Delete Response Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Same struct with deleted flag | %Customer{deleted: true} — single type | ✓ |
| Separate DeletedCustomer struct | Distinct type for deleted state | |
| Return :ok atom | Just confirm deletion succeeded | |

**User's choice:** [auto] Same struct with deleted flag (recommended default)
**Notes:** Matches Stripe JSON shape and Ruby/Python/Node pattern.

---

## Search API Ergonomics

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse List + search_stream! sugar | search/3 returns %List{}, search_stream!/3 wraps List.stream! | ✓ |
| Separate SearchResult type | Distinct type for search results | |
| Raw response only | Return %Response{} without convenience functions | |

**User's choice:** [auto] Reuse List + search_stream! sugar (recommended default)
**Notes:** Leverages Phase 3 infrastructure. List already handles search_result object type.

---

## Claude's Discretion

- Internal from_map/1 implementation, exact struct fields, helper organization, test fixtures, @doc content

## Deferred Ideas

- Deep typed deserialization for nested objects
- Type registry for object-to-module mapping
- Shared resource macro/DSL (evaluate after Phases 5-6)
- Nested resource helpers (e.g., Customer.list_payment_methods)
