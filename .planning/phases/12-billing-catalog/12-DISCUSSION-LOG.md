# Phase 12: Billing Catalog - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `12-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 12-billing-catalog
**Areas discussed:** Nested struct typing, PromotionCode.search path, Forbidden ops discipline, FormEncoder battery scope, Custom IDs (bonus)

---

## Initial gray area selection

| Option | Description | Selected |
|--------|-------------|----------|
| Nested struct typing | How deep do typed nested structs go on Price/Coupon/Product? | ✓ |
| PromotionCode.search path | How do we verify whether search/2 ships? | ✓ |
| Forbidden ops discipline | Price.delete and Coupon.update — don't define vs define+raise vs typed error | ✓ |
| FormEncoder battery scope | Minimal vs exhaustive vs property-based | ✓ |

**User's choice:** All four areas selected.

---

## Nested struct typing

### Q1: How deep should typed nested structs go?

| Option | Description | Selected |
|--------|-------------|----------|
| Strategic typing (Tier 2) | Type Price.Recurring, Price.Tier, Coupon.AppliesTo. Leave transform_quantity, custom_unit_amount, package_dimensions as map(). Rule: "nested = struct if downstream pattern-matches on it." | ✓ |
| All typed (stripe-go style) | Type every nested across all four resources (~15-20 modules). Matches 4/5 official Stripe SDKs. Higher boilerplate. | |
| All raw maps (v1 parity) | Keep every nested as map() with string keys, exactly like Customer.address/discount/shipping. String keys leak into every call site. | |

**Research consulted:** Parallel agent compared stripe-ruby, stripe-node, stripe-python, stripe-go, stripity_stripe. 4-of-5 official SDKs fully type every nested. stripity_stripe (unmaintained) uses `term | nil`. Price.recurring is the highest-read nested in every Stripe SDK.

**User's choice:** Strategic typing (Tier 2).
**Notes:** Milestone-wide rule locked: "nested = struct if downstream phases pattern-match on it."

### Q2: Backfill Customer.discount as typed %Discount{} once Coupon exists?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, backfill in Phase 12 | Small v1 polish. ~20 LOC, natural while the context is loaded. | ✓ |
| No, leave Customer alone | Don't touch v1 resources. Keep Phase 12 scope minimal. | |
| Defer decision to planner | Claude's discretion. | |

**User's choice:** Yes, backfill in Phase 12.

### Q3: How should we handle enum-like string fields?

| Option | Description | Selected |
|--------|-------------|----------|
| Whitelist atomize, unknown→string | Known enums convert to atoms; unknown values pass through as raw string. Forward-compatible. | ✓ |
| Whitelist atomize, unknown raises | Known whitelist, unknown raises ArgumentError. SDK breaks if Stripe silently adds a new value. | |
| Atomize interval only | Only Price.Recurring.interval gets atomized. Smallest scope, least consistent. | |
| No atomization anywhere | Walk back the atom decision. Keep all enum fields as strings. | |

**User's choice:** Whitelist atomize, unknown→string.
**Notes:** `String.to_atom/1` is a DoS risk; `String.to_existing_atom/1` crashes on unknown. Whitelist with catch-all is the only safe forward-compatible pattern.

### Q4: Scope of whitelist atomization?

| Option | Description | Selected |
|--------|-------------|----------|
| Every well-known enum | Price.type, billing_scheme, tax_behavior, Recurring.interval/usage_type/aggregate_usage, Product.type, Coupon.duration, Tier.up_to. | ✓ |
| Only pattern-matched enums | Only interval, duration, type. Skip billing_scheme, tax_behavior, aggregate_usage. | |
| Defer to planner | Planner enumerates exact fields. | |

**User's choice:** Every well-known enum.

---

## PromotionCode.search path

**Research consulted:** Parallel agent checked Stripe OpenAPI spec (`spec3.sdk.json`). Definitive: only 7 resources have `/search` endpoints — charges, customers, invoices, payment_intents, prices, products, subscriptions. PromotionCode and Coupon are absent. stripe-ruby `promotion_code.rb` does not include `APIOperations::Search`; stripe-node typings have zero "search" references.

**Conclusion reached in analysis (not asked as a decision):**
- Product.search ✓ ship
- Price.search ✓ ship
- Coupon.search ✗ do not ship (endpoint does not exist)
- PromotionCode.search ✗ do not ship (endpoint does not exist)

### Q1: How should we surface that Coupon.search and PromotionCode.search don't exist?

| Option | Description | Selected |
|--------|-------------|----------|
| Omit entirely | Don't define the function. UndefinedFunctionError if called. Consistent with ROADMAP's "missing functions, not runtime errors." | ✓ |
| Define + raise with helpful message | Stub function that raises with list/2 hint. More discoverable but inconsistent with ecosystem. | |
| Omit + @moduledoc discoverability note | Omit AND add "Finding promotion codes" section. Best of both. | |

**User's choice:** Omit entirely.
**Notes:** Matches the forbidden-ops decision (Area 3). Discoverability ultimately lives in the `@moduledoc` callout section per D-05, so the "omit + moduledoc" effect is achieved even with "omit entirely" because D-05 adds the moduledoc section anyway.

### Q2: Update REQUIREMENTS.md BILL-06b to reflect verified-absent?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, update REQUIREMENTS.md now | Change BILL-06b from "conditional on verification" to "verified-absent, list/2 with filters is discovery path." | ✓ |
| Capture in CONTEXT.md only | Leave REQUIREMENTS.md as historical record. | |

**User's choice:** Yes, update now.
**Action taken:** `.planning/REQUIREMENTS.md` BILL-06b line updated in this session.

---

## Forbidden ops discipline

### Q1: How should Price.delete, Coupon.update, and future forbidden ops be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Omit + @moduledoc callout | Don't define. Add "## Operations not supported by the Stripe API" section in @moduledoc with workaround. Matches all 5 official SDKs. | ✓ |
| Omit only, no @moduledoc section | Just omit. UndefinedFunctionError. Consumers wonder why. | |
| Define + raise ArgumentError | Stub that raises. Diverges from every Stripe SDK. Wrong mental model. | |
| Define + return typed :not_supported error | Actively harmful — invites recovery code for non-recoverable errors. | |

**User's choice:** Omit + @moduledoc callout.
**Notes:** Sets milestone-wide template for Phase 14 (Invoice finalization constraints) and Phase 15 (Subscription terminal-state constraints).

---

## FormEncoder battery scope

### Q1: What scope should the battery cover?

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: exhaustive + StreamData | Enumerated catalog (~30 tests covering all known Stripe shapes through Phase 19) + StreamData property tests for structural invariants. Adds stream_data as dev-only dep. | ✓ |
| Exhaustive enumerated only | ~30-50 explicit test cases. No property-based layer. No new deps. | |
| Minimal (roadmap text only) | ~5-10 tests covering just the called-out triple-nested case. | |
| Property-based only | Generators-only, no enumerated catalog. Misses semantic bugs. | |

**User's choice:** Hybrid: exhaustive + StreamData.

### Q2: Latent issues the battery uncovers — which should Phase 12 fix vs defer? (multiSelect)

| Option | Description | Selected |
|--------|-------------|----------|
| Scientific notation on floats | 0.00001 → "1.0e-5" currently. Stripe rejects. Fix with :erlang.float_to_binary/2. | ✓ |
| Atom values round-trip | Ensure :month encodes identically to "month". Test, fix if broken. | ✓ |
| Metadata special chars (hyphen, slash, space) | Verify URL encoding for metadata keys with special chars. | ✓ |
| Empty-string clear vs nil omit contract | Lock current behavior. Already correct, add explicit test. | ✓ |

**User's choice:** All four. Phase 12 fixes/tests all four latent issues.

---

## Custom IDs (bonus gray area)

### Q0: Explore this gray area before writing CONTEXT.md?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, discuss custom IDs | Quick research + decision on how LatticeStripe exposes user-provided IDs. | ✓ |
| No, ready for CONTEXT.md | Pass-through concern, let the planner handle it. | |

**User's choice:** Yes, discuss.

### Q1: How should LatticeStripe expose custom IDs for Coupon and PromotionCode?

| Option | Description | Selected |
|--------|-------------|----------|
| Pass-through + @doc examples | No helper functions. Consumers pass id/code in params map. @doc blocks carry explicit examples and call out Coupon.id vs PromotionCode.code vs server id distinction. Matches all 5 official Stripe SDKs. | ✓ |
| Dedicated helper functions | create_with_id/3, create_with_code/4. Doubles public API, diverges from ecosystem. | |
| Pass-through with no special docs | Minimum surface. Leaves the confusion to bite consumers. | |

**User's choice:** Pass-through + @doc examples.
**Notes:** The critical point is that Coupon.id (user-assignable) vs PromotionCode.id (always server-generated) vs PromotionCode.code (customer-facing identifier) is the #1 common confusion. The SDK's leverage point is documentation, not function signatures.

---

## Claude's Discretion

The following were explicitly marked as planner/executor discretion in CONTEXT.md:

- Exact module path for `Discount` (`lib/lattice_stripe/discount.ex` is the obvious choice)
- Whether typed nested structs live in separate files or inline in parent module
- Whether eventual-consistency doc block lives as `@search_consistency_doc` module attribute or is duplicated verbatim
- Exact wording and placement of `## Operations not supported by the Stripe API` sections
- Name and structure of `atomize_*` helper functions (per-module free functions vs shared helper)
- StreamData generator depth/breadth limits (CI budget)
- Whether atom-value round-trip test lives in FormEncoder battery or resource integration tests

## Deferred Ideas

See `12-CONTEXT.md` `<deferred>` section. Summary:
- Typing remaining nested shapes (transform_quantity, custom_unit_amount, etc.)
- Backfilling typed nesteds on other v1 resources beyond Customer.discount
- Client-side Stripe ID format validation
- OpenAPI codegen
- Billing Meters (BILL-07)
- BillingPortal (BILL-05)
- StreamData round-trip via reference decoder
- Coupon.search / PromotionCode.search if Stripe ever adds them
