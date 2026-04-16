# Phase 29: Changeset-Style Param Builders - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 29-changeset-style-param-builders
**Areas discussed:** Builder API shape, Output format & validation, Module structure & naming, Scope boundary
**Mode:** --auto (all decisions auto-selected)

---

## Builder API Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Pipe-based changeset style | `new() \|> setter() \|> build()` chains, idiomatic Elixir | ✓ |
| Keyword-list-based | `build(customer: "cus_123", phases: [...])` | |
| Map merge helpers | Utility functions that merge into existing maps | |

**User's choice:** [auto] Pipe-based changeset style (recommended default)
**Notes:** Matches phase name "Changeset-Style", aligns with Ecto/Ash/Req ecosystem patterns.

---

## Output Format & Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Plain map, no validation | `build/1` returns `map()`, existing guards validate | ✓ |
| Tagged tuple with validation | `build/1` returns `{:ok, map} \| {:error, reason}` | |
| Validated struct | Builder returns a struct that validates on construction | |

**User's choice:** [auto] Plain map, no validation (recommended default)
**Notes:** Avoids duplicating guard logic. Builders are convenience, not contract boundaries.

---

## Module Structure & Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Flat — two top-level modules | `Builders.SubscriptionSchedule` + `Builders.BillingPortal` | ✓ |
| Mirror sub-struct hierarchy | Separate modules for Phase, PhaseItem, FlowData sub-types | |
| Single unified Builders module | One module with namespaced functions | |

**User's choice:** [auto] Flat — two top-level modules (recommended default)
**Notes:** Keeps builder layer thin. Sub-builders as nested functions or inner helpers, not separate module files.

---

## Scope Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| FlowData only | "BillingPortal flows" = FlowData params for session creation | ✓ |
| FlowData + Configuration | Also build Configuration feature params | |
| FlowData + Configuration + full portal | All BillingPortal param construction | |

**User's choice:** [auto] FlowData only (recommended default)
**Notes:** FlowData is the deeply nested, error-prone shape. Configuration params are simpler maps.

## Claude's Discretion

- Function naming style (e.g., `customer/2` vs `set_customer/2`)
- Internal builder representation (opaque struct vs map accumulator)
- Convenience constructors for common patterns
- Test strategy and fixture approach

## Deferred Ideas

None — discussion stayed within phase scope.
