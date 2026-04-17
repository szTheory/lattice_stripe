# Phase 33: Disputes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 33-disputes
**Areas discussed:** Evidence API split, Nested struct depth, Close verb semantics, Status atomization

---

## Evidence API Split

| Option | Description | Selected |
|--------|-------------|----------|
| Three-function split | `update/4` (raw), `update_evidence/4` (safe staging), `submit_evidence/3` (irreversible) with shared `do_update/4` | ✓ |
| Single update (official SDK style) | One `update/4` accepting evidence + metadata + submit — matches all official SDKs | |
| Two-function split | `update/4` for everything, `submit_evidence/3` for irreversible submit only | |

**User's choice:** Three-function split
**Notes:** Research showed every official SDK (ruby, python, go, node) uses a single update — leaving the #1 footgun (forgetting `submit: false` defaults to immediate submission). LatticeStripe's three-function split eliminates this. `update_evidence/4` accepts flat evidence map, strips stray `submit` keys. `submit_evidence/3` takes no evidence param, forcing two-step workflow. `update/4` remains available for power users.

---

## Nested Struct Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Type branching points only | Evidence + EvidenceDetails (locked) + PaymentMethodDetails struct; card/klarna/paypal as raw maps | ✓ |
| Type everything (stripe-go style) | Full struct hierarchy down to three_d_secure | |
| Minimal (locked reqs only) | Only Evidence + EvidenceDetails; PaymentMethodDetails as raw map | |

**User's choice:** Type branching points only
**Notes:** stripe-go types everything; stripity_stripe types nothing (negative feedback). LatticeStripe's existing threshold is "type what developers pattern-match on." PaymentMethodDetails.type is a branching point (card vs klarna routing). Card sub-object (~4 string fields) is not. BalanceTransaction and Charge reuse existing types.

---

## Close Verb Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| `close/3` with strong docs | Match all official SDKs + Stripe API name; `## Irreversibility` doc section | ✓ |
| `accept/3` | More semantically honest but zero discoverability across Stripe ecosystem | |
| `close/3` with runtime guard | Require `:i_understand` confirmation atom | |

**User's choice:** `close/3` with strong docs
**Notes:** Every official SDK uses `close`. Stripe docs title it "Close a dispute." `Account.reject/4` already established the `## Irreversibility` doc section pattern. No runtime guards — not idiomatic Elixir, inconsistent with `cancel`, `reject`, `deactivate`. `submit_evidence/3` gets same doc pattern with milder wording.

---

## Status Atomization

| Option | Description | Selected |
|--------|-------------|----------|
| Atomize status + reason at parse time | Private `atomize_status/1` and `atomize_reason/1` in `from_map/1`; string passthrough catch-all | ✓ |
| Atomize status only | Only status gets atoms; reason stays as string | |
| No atomization (strings only) | Match official SDK behavior — plain strings | |

**User's choice:** Atomize status + reason at parse time
**Notes:** Codebase already atomizes 13+ fields across resources (status, type, mode, interval, etc.). Dispute status (8 values) and reason (~14 values) are classic finite enums developers pattern-match on. No public `status_atom/1` functions — deprecated per Phase 22. Unknown values pass through as strings via catch-all (not error tuples).

## Claude's Discretion

- Internal `do_update/4` implementation, struct field ordering, test organization, ExDoc grouping, fixture helpers, custom Inspect if applicable

## Deferred Ideas

- `Builders.Dispute` evidence builder (explicitly out of scope per REQUIREMENTS.md)
- `PaymentMethodDetails.Card` typed struct (promote from raw map if demand appears)
- Deeper `three_d_secure` typing (informational leaf data)
