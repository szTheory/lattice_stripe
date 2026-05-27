# Pitfalls Research

**Domain:** Adding Stripe Tax resource family to LatticeStripe SDK
**Researched:** 2026-05-27
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Scope Bleed into Filing Orchestration

**What goes wrong:**
SDK grows tax filing workflows, multi-jurisdiction strategy helpers, or returns automation — becoming a mini-Accrue.

**Why it happens:**
Tax is inherently complex; developers conflate "tax API coverage" with "tax compliance product."

**How to avoid:**
Hard scope boundary in PROJECT.md and discuss-phase: Calculation + Transaction + Settings + Registration + TaxId primitives only. No filing, no returns, no threshold monitoring.

**Warning signs:**
Requirements mention "file returns," "monitor thresholds," or "registration wizard."

**Phase to address:**
Phase 49 discuss-phase scope negotiation.

---

### Pitfall 2: Calculation Expiry Not Documented

**What goes wrong:**
Adopters store calculation IDs indefinitely and fail when calling `create_from_calculation` on expired calculations (90-day window).

**Why it happens:**
Calculation feels like a persistent resource but is ephemeral in Stripe's model.

**How to avoid:**
Moduledoc on `Tax.Calculation` must state 90-day expiry. Integration spec should demonstrate prompt calculation → transaction flow.

**Warning signs:**
Tests use hardcoded calculation IDs without create step; moduledoc omits expiry.

**Phase to address:**
Phase 49 (Calculation + Transaction implementation).

---

### Pitfall 3: Transaction Reference Uniqueness Violations

**What goes wrong:**
Adopters reuse `reference` values across transactions, causing Stripe 400 errors that look like SDK bugs.

**Why it happens:**
`reference` is a custom order ID — developers assume it's scoped per customer or per day.

**How to avoid:**
Moduledoc on `create_from_calculation/3` and `create_reversal/3` must state global uniqueness requirement. Include realistic reference example (`"order_#{order_id}"`).

**Warning signs:**
Test fixtures use static reference strings like `"test_ref"`.

**Phase to address:**
Phase 49 (Transaction verbs).

---

### Pitfall 4: Conflating AutomaticTax with Tax API

**What goes wrong:**
Developers use `Invoice.AutomaticTax` struct helpers expecting standalone Tax API behavior, or implement Tax API modules that try to bridge into Invoice automatic tax fields.

**Why it happens:**
Both involve "tax" naming; `Invoice.AutomaticTax` already exists in codebase.

**How to avoid:**
Keep modules separate. Cross-reference in moduledocs only. Do not extend `Invoice.AutomaticTax` for Tax API coverage.

**Warning signs:**
Requirements mention "unify tax modules" or shared tax builder abstraction.

**Phase to address:**
Phase 49 architecture decision in discuss-phase.

---

### Pitfall 5: TaxId Dual-Path Confusion

**What goes wrong:**
SDK implements only customer-nested OR only top-level TaxId paths, breaking adopters who need the other path. Or two separate modules create API confusion.

**Why it happens:**
Stripe exposes both `/v1/tax_ids` and `/v1/customers/:id/tax_ids` with identical object shape.

**How to avoid:**
Single `LatticeStripe.TaxId` module with arity-based path routing (customer_id as optional first param after client). Document both paths in moduledoc.

**Warning signs:**
Only one path implemented; or duplicate `Customer.TaxId` + `TaxId` modules.

**Phase to address:**
Phase 50 or 51 (TaxId implementation — discuss-phase decides phase assignment).

---

### Pitfall 6: Missing ObjectTypes Registry Entries

**What goes wrong:**
Tax resources deserialize as raw maps when expanded; webhook `fetch_related_object` fails on tax event types.

**Why it happens:**
ObjectTypes update is easy to forget when adding new resource families.

**How to avoid:**
Add all 5 entries (`tax.calculation`, `tax.transaction`, `tax.settings`, `tax.registration`, `tax_id`) in same PR as struct modules. Test expand deserialization.

**Warning signs:**
`from_map/1` works but `ObjectTypes.maybe_deserialize/1` returns raw map for tax objects.

**Phase to address:**
Each phase that adds resources — verify registry in phase verification.

---

### Pitfall 7: Singleton Settings Path Mistake

**What goes wrong:**
Settings module uses `/v1/tax/settings/:id` pattern (standard CRUD) instead of singleton `/v1/tax/settings`.

**Why it happens:**
First singleton resource in codebase; no existing pattern to copy.

**How to avoid:**
Explicitly design Settings as singleton (no ID param). Review against Stripe docs before implementation.

**Warning signs:**
`Settings.retrieve(client, id, opts)` arity; path includes ID segment.

**Phase to address:**
Phase 50 (Settings + Registration).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip TaxId dual-path | Faster ship | Breaks B2B VAT flows for half of adopters | Never |
| Raw map returns for nested line items | Skip LineItem struct | Breaks pattern-matchable returns contract | Never |
| Defer integration spec to v1.7 | Save time now | Tax family ships without proof of calc→txn flow | Never for v1.6 |
| Skip Testing fixtures | Less code | Harder adopter test setup | Never — fixtures are table stakes since v1.3 |
| Defer guide to v1.7 | Focus on code | Tax is complex enough to need a recipe | Acceptable if code+tests ship in v1.6 |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Tax Calculation | Missing `customer_details.address` | Require address fields for accurate tax; document in moduledoc |
| Tax Calculation | Omitting `tax_code` on line items | Falls back to Settings default; document both paths |
| Tax Transaction | Calling create_from_calculation without `reference` | `reference` is required; use Resource.require_param! |
| Tax Registration | Flat country param without `country_options` | Nest jurisdiction-specific options per Stripe docs |
| TaxId | Wrong type format for country | Stripe validates format; document type enum in moduledoc |
| Expand line_items | Forgetting pagination on list_line_items | Use existing List module for paginated endpoint |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Calculation-per-item in loop | Rate limit / cost spike | Batch line items in single calculation | >10 calculations per transaction |
| Storing calculations instead of transactions | Expired calculation errors | Create transaction promptly after calculation | After 90 days |
| Registration list without pagination | Memory spike on large accounts | Use List.stream/3 | >100 registrations |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging full calculation params | PII in logs (addresses) | Telemetry already redacts; don't add Tax-specific logging |
| Client-side tax calculation | Tax evasion liability | Document: always use Stripe Calculation API for authoritative rates |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No moduledoc examples | Adopters read Stripe docs instead | Include realistic Elixir param maps in moduledocs |
| Missing calc→txn flow docs | Adopters don't know standalone Tax flow | Integration spec + optional guide |
| Unclear Accrue boundary | Adopters expect filing in SDK | State scope in PROJECT.md and guide intro |

## "Looks Done But Isn't" Checklist

- [ ] **Tax.Calculation:** Often missing `list_line_items/3` — verify paginated endpoint exists
- [ ] **Tax.Transaction:** Often missing `create_reversal/3` — verify both verb endpoints
- [ ] **Tax.Settings:** Often implemented as CRUD with ID — verify singleton path
- [ ] **Tax.Registration:** Often missing `update/3` — verify POST update endpoint
- [ ] **TaxId:** Often missing one path variant — verify both top-level and customer-nested
- [ ] **ObjectTypes:** Often missing tax entries — verify all 5 deserialize via expand
- [ ] **Integration spec:** Often unit-only — verify chained calc→txn Mox spec exists

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Scope bleed | HIGH | Descope filing helpers; move to Accrue backlog |
| Missing dual-path TaxId | MEDIUM | Add second path in follow-up PR |
| ObjectTypes gap | LOW | Add entries + expand test |
| Singleton Settings wrong | LOW | Fix path in Settings module |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Scope bleed | Phase 49 discuss | Requirements review excludes filing |
| Calculation expiry | Phase 49 | Moduledoc + integration spec timing |
| Reference uniqueness | Phase 49 | Moduledoc + dynamic reference in tests |
| AutomaticTax conflation | Phase 49 discuss | No Invoice.AutomaticTax changes |
| TaxId dual-path | Phase 50/51 | Tests for both URL paths |
| ObjectTypes gap | All phases | Expand deserialization test |
| Singleton Settings | Phase 50 | Path inspection + retrieve/update test |

## Sources

- [Stripe Standalone Tax API guide](https://docs.stripe.com/tax/standalone-tax-api)
- [Stripe Tax Calculations API](https://docs.stripe.com/api/tax/calculations)
- [Stripe Tax Transactions API](https://docs.stripe.com/api/tax/transactions)
- LatticeStripe v1.5 post-mortem patterns (tolerance:0 four-surface triangulation)
- PROJECT.md scope boundaries (Accrue downstream)

---
*Pitfalls research for: LatticeStripe v1.6 Tax*
*Researched: 2026-05-27*
