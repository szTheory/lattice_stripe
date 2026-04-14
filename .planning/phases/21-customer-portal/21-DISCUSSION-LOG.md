# Phase 21: Customer Portal - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 21-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 21-customer-portal
**Areas discussed:** A. Flow-type validation, B. FlowData struct shape, C. Session Inspect allowlist, E. Guide scope/length
**Discussion mode:** Research-driven. Four parallel `gsd-advisor-researcher` agents produced comparison tables with Elixir/Phoenix/Ecto/Plug idiom analysis, stripity_stripe/stripe-node/ruby/python lessons, and one-shot committed recommendations per area. User requested "best practices, coherent/consistent... one-shot a perfect recommendation for each" — research-backed recommendations were locked.

---

## A. Flow-type validation architecture

| Option | Description | Selected |
|--------|-------------|----------|
| 1. New `BillingPortal.Guards` module + pattern-match function heads (GUARD-03 idiom) | One happy-path clause per flow type, one missing-field clause per type, binary catchall for unknown types, final catchall for malformed flow_data. ~50 LOC. | ✓ |
| 2. Same module but `cond` dispatch (GUARD-01 idiom) | Compact single-function body with branch conditions. Tighter symmetry with GUARD-01. | |
| 3. Extend existing `LatticeStripe.Billing.Guards` | Zero new files; add `check_portal_flow_data!/1` to the existing Billing.Guards module. | |
| 4. Inline private functions in `BillingPortal.Session` | Validator sits next to its caller; no new module. | |
| 5. Data-driven `@required_fields` dispatch map | Compile-time schema walked at runtime via `Map.fetch` + `get_in`. | |

**User's choice:** Lock Option 1 — confirmed via AskUserQuestion.
**Notes:** Rationale captured in 21-CONTEXT.md D-01. Key winning arguments: (1) GUARD-03 pattern-match idiom is the closer semantic match to "nested required sub-object + closed enum dispatch"; (2) Phase 20 D-01 "guards alongside resource namespace" rules out Option 3 (namespace false friend — `billing` ≠ `billing_portal`); (3) binary catchall makes Success Criterion #3 structurally impossible to violate; (4) stripity_stripe / stripe-node / stripe-ruby / stripe-python all skip client-side validation entirely, which is the exact gap LatticeStripe is filling and differentiates this SDK.

---

## B. FlowData nested-struct shape

| Option | Description | Selected |
|--------|-------------|----------|
| 1. Flat FlowData + raw maps for branches | 1 module, `subscription_cancel: map()` etc. String-key bracket access for sub-fields. | |
| 2. Flat FlowData + 4 nested sub-structs per branch (5 modules total) | `FlowData` + `AfterCompletion` + `SubscriptionCancel` + `SubscriptionUpdate` + `SubscriptionUpdateConfirm`. Pure atom dot-access. Matches Phase 20 Meter idiom. | ✓ |
| 3. Polymorphic union (4 per-type structs, no parent) | `Session.flow` is typed `SubscriptionCancel.t() \| SubscriptionUpdate.t() \| ...`. Forces exhaustive `case` at every call site. | |
| 4. Fully flat, raw maps everywhere | No sub-structs at all; mirrors stripity_stripe. | |
| 5. Parametric `:branch_data` opaque map | Synthetic field derived at decode time; not on the wire. | |

**User's choice:** "you decide whatever would be best practices, coherent/consistent.... one-shot a perfect recommendation" — delegated to the locked research recommendation.
**Notes:** Locked Option 2 per research recommendation. Rationale captured in 21-CONTEXT.md D-02. Key winning arguments: (1) matches Phase 20 Meter footprint exactly (4 nested sub-structs + parent); (2) Checkout.Session's flat `map()` treatment of `shipping_options`/`payment_method_options` is pre-Phase-17 legacy debt, not a precedent to repeat; (3) Stripe's wire format keeps each branch in its own named key, so polymorphism does not block Option 2 — `nil` indicates inactive branches cleanly; (4) DX win: `session.flow.subscription_cancel.subscription` pure atom dot-access versus string-key brackets under Options 1/4; (5) forward compat handled by `flow.extra` catching unknown `type` strings and new sub-fields. Shallow leaves (retention, items, discounts, redirect, hosted_confirmation) deliberately stay as raw maps — matches Checkout.Session `line_items` precedent and caps module count at 5.

---

## C. Session Inspect allowlist

| Option | Description | Selected |
|--------|-------------|----------|
| A. Minimal (Customer-style): `id`, `object`, `livemode` only | Strongest defensive posture; debuggability is a non-goal. | |
| B. Structural (Checkout.Session-style): `id`, `object`, `livemode`, `customer`, `configuration`, `on_behalf_of`, `created`, `return_url`, `locale` | Hide `:url` (auth token) and `:flow` (nested struct bloat). Matches Checkout.Session shape. | ✓ |
| C. Verbose: everything except `:url` and `:flow` | Widest debug surface; no precedent in the SDK. | |

**User's choice:** Delegated to research recommendation via the one-shot "you decide" directive.
**Notes:** Locked Option B per research recommendation. Rationale in 21-CONTEXT.md D-03. Critical precedent uncovered during research: `Checkout.Session`'s `:url` field is **already hidden** in its existing `defimpl Inspect` (lines 658-684), making "Stripe session URLs are uniformly masked in LatticeStripe" a de facto SDK invariant. Phase 21 is making it explicit and documenting it for the higher-sensitivity portal variant. Threat model: Logger→APM, crash dumps→Sentry, telemetry handlers→S3, pair-programming screen shares — all vectors where a 5-minute TTL is long enough to hijack the portal session. `:flow` is hidden for different reasons (Inspect one-liner hygiene + `after_completion.redirect` echo risk), not credential-level sensitivity.

---

## E. Guide scope/length for `guides/customer-portal.md`

| Envelope | Line target | H2 count | Selected |
|----------|-------------|----------|----------|
| TIGHT | ~150 | 6 | |
| MODERATE | ~240 | 7 | ✓ |
| METERING-MATCH | ~500 | 11 | |

**User's choice:** Delegated to research recommendation.
**Notes:** Locked MODERATE per research recommendation. Rationale in 21-CONTEXT.md D-04. Structural reference: `guides/checkout.md` is the twin (274 lines, 11 H2s for a single-resource create-centric API with a string discriminator). Portal has a wider-but-shallower discriminator (`flow_data.type` × 4 values) and fewer surrounding operations (no expire/list/list_line_items), arguing for *slightly less* than checkout.md — 240 lines, 7 H2s. Metering's 620 lines earned by 3 resources + hot path + 2-layer idempotency + GUARD trap + webhook error flow, none of which BillingPortal has. Phase 21 D-02 `:url` masking teaching is promoted to its own H2 §"Security and session lifetime" because it is a behavior users cannot discover from the moduledoc alone. DOCS-02's "Accrue-style usage example" requirement satisfied by a 5-line wrapper module shown above the Phoenix controller example in §"End-to-end Phoenix example". Plan slot: bundle with resource-landing plan (21-03 per v1.1 brief) as default; split only if 21-03 is already heavy.

## Claude's Discretion

Two gray areas were deliberately not discussed because they are trivial:

- **D. Plan breakdown (3 vs 4 plans)** — deferred to gsd-plan-phase. Start from the v1.1 brief's 4-plan sketch and collapse or expand based on resource-plan weight after research.
- **F. `configuration` param type** — accept `binary()` (Stripe `bpc_*` ID) as the documented type; no pre-flight guard (Stripe's 400 is clear enough if a map is passed). Documented in moduledoc that portal configuration is managed via Stripe dashboard in v1.1 per locked v1.1 D4.

## Deferred Ideas

See 21-CONTEXT.md `<deferred>` section — 8 items captured:

1. `BillingPortal.Configuration` CRUDL (v1.1 D4)
2. `FlowData.Retention` sub-module
3. `FlowData.AfterCompletion.Redirect` / `.HostedConfirmation` sub-modules
4. Typed sub-modules for `SubscriptionUpdateConfirm.items[]` / `.discounts[]`
5. Encoding FlowData back to the wire (v1.1 is decode-only)
6. Telemetry / observability guide section
7. FAQ section in the guide
8. Connect platform deep-dive guide section
