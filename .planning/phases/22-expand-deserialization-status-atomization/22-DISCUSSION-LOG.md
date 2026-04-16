# Phase 22: Expand Deserialization & Status Atomization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 22-expand-deserialization-status-atomization
**Areas discussed:** Expand dispatch design, Type safety & compat, Atomization strategy, Dot-path expand

---

## Expand Dispatch Design

| Option | Description | Selected |
|--------|-------------|----------|
| A: Central ObjectTypes registry | Single module mapping "object" → module; mirrors stripe-ruby/python | ✓ |
| B: Per-module @object_name + naming convention | Co-locates identity; zero registry maintenance | |
| C: Recursive field walk in Resource helpers | Automatic; works for nested expansions | |

**User's choice:** A — Central ObjectTypes registry
**Notes:** User requested deep research across stripe-ruby, stripe-python, stripe-go, Elixir ecosystem patterns. Research confirmed all major SDKs converge on central registry. Naming convention rejected due to dot-notation namespace complexity.

---

## Type Safety & Backward Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| A: Always auto-deserialize | is_map guard in from_map/1; union type specs | ✓ |
| B: Opt-in deserialize_expanded: flag | Fully backward-compatible; flag threading | |
| C: Separate accessor function | Zero behavior change; leaks deserialization to caller | |

**User's choice:** A — Always auto-deserialize
**Notes:** Research showed all official Stripe SDKs auto-deserialize. The change is map() → struct (not string → struct), so it's strictly additive. CHANGELOG migration note required. Audit Accrue before release.

---

## Atomization Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A: Auto-atomize in from_map/1 | Private atomize_status; DX default; matches Invoice precedent | ✓ |
| B: Public status_atom/1 only | Predictable String.t(); extra call needed | |
| C: Both auto + public | Covers webhook raw-string case; doubled surface | |
| D: Separate Status module | Enum module pattern; premature for current scope | |

**User's choice:** A — Auto-atomize in from_map/1
**Notes:** Resolves existing codebase inconsistency (Invoice auto-atomizes, Capability/Meter don't). Sweep includes non-status enum fields (billing_reason, collection_method, etc.). Capability and Meter public status_atom/1 to be deprecated.

---

## Dot-Path Expand

| Option | Description | Selected |
|--------|-------------|----------|
| A: Pass-through only | Zero new code; expanded fields as raw maps | |
| B: Response-driven object detection | is_map + "object" key dispatch; no parsing needed | ✓ |
| C: Client-side dot-path parsing | Explicit; context threading through List/pagination | |

**User's choice:** B — Response-driven object detection
**Notes:** Works automatically because D-01 (ObjectTypes registry) + D-02 (is_map guard) already handle detection. No dot-path parsing needed. Pagination already preserves expand params in List._params.

---

## Claude's Discretion

- Module sweep order and batching strategy
- Exact set of non-status enum fields to atomize
- Whether Expand.maybe_deserialize/1 is public or private
- Test structure for ObjectTypes registry

## Deferred Ideas

None — discussion stayed within phase scope.
