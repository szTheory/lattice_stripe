# Phase 49: Tax Calculation & Transaction Core - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the standalone Stripe Tax API core flow: calculate tax (`Tax.Calculation`), record it as a transaction (`Tax.Transaction.create_from_calculation/3`), and reverse when needed (`Tax.Transaction.create_reversal/3`). Includes typed structs with pragmatic nested decoding, explicit verb functions, ObjectTypes entries for both resource types, assertive moduledocs for operational traps and AutomaticTax scope fencing, and a Mox-at-Transport integration spec proving the calc→txn→reversal chain.

**In scope:** CALC-01..03, TXN-01..04, DX-03; `lib/lattice_stripe/tax/calculation.ex`, `transaction.ex`, nested LineItem and first-order nested struct modules, ObjectTypes registration for `tax.calculation` and `tax.transaction`, unit tests per verb, one chained integration test file.

**Out of scope (Phases 50–51):** Tax.Settings, Tax.Registration, TaxId, `LatticeStripe.Testing` fixtures (DX-02), `guides/tax.md` (DX-04), docs-truth grep extension (DX-05), full five-type expand proof (DX-01), optional stripe-mock smoke test.

</domain>

<decisions>
## Implementation Decisions

### Nested struct typing depth (D-01)
- **D-01:** **Pragmatic partial typing (Option B)** — type workflow-critical boundaries; keep volatile/expand-only subtrees as maps with `extra` at every level.
- **Type these:**
  - Top-level `%Tax.Calculation{}` and `%Tax.Transaction{}` — all documented scalar fields (`amount_total`, `tax_amount_exclusive`, `tax_amount_inclusive`, `currency`, `expires_at`, `tax_date`, `livemode`, `reference`, etc.).
  - Paginated line items — separate flat modules `%Tax.Calculation.LineItem{}` and `%Tax.Transaction.LineItem{}` (distinct Stripe object types; do not unify unless shapes are provably identical at plan time).
  - First-order nested modules on Calculation/Transaction: `CustomerDetails` (flat fields; **`address` stays a map** — no shared Address module exists; matches Checkout.Session precedent), `ShippingCost`, `ShipFromDetails` (small flat structs), and a shared `Tax.TaxBreakdown` module if Calculation/Transaction breakdown shapes match (elements: `amount`, `inclusive`, `taxability_reason`, `taxable_amount`; **`tax_rate_details` stays a map** — mirrors `Invoice.AutomaticTax.liability` precedent).
- **Keep as maps/lists:**
  - `customer_details.tax_ids` — array of small objects, rarely pattern-matched.
  - `tax_rate_details` innards — document in typespecs/moduledoc, do not sub-struct.
  - Line-item `tax_breakdown` — expand-only, includes variable-depth `jurisdiction` trees; leave as `list() | nil` on LineItem (Quote `pricing` footgun avoidance).
  - Expandable `product` on line items — decode via `ObjectTypes.maybe_deserialize/1` when expanded.
- **Mechanics:** `@known_fields` + `Map.split/2` → `extra` at every nested level; embedded `line_items` decode as `%List{data: [%LineItem{}]}` via `List.from_json/1` (Quote/CreditNote pattern); atomize closed enums (`tax_behavior` → `:exclusive | :inclusive`); pass through unknown `taxability_reason` strings.
- **Request params:** Accept raw string-key maps for `create/3` — no request builders in Phase 49 (prompts research: Tax params are deeply nested; encoding is caller responsibility).
- **Rationale:** Satisfies ROADMAP SC#1 (typed nested line items when expanded) without codegen-depth maintenance burden. Matches Quote.Computed bounded boundary, CreditNote line items, Dispute polymorphic shells, Meter one-level nesting. Official stripe-ruby/node/go type everything because OpenAPI codegen is free; LatticeStripe is handwritten and intentionally bounded.

### Integration spec breadth (D-02)
- **D-02:** **Chain + reversal (Option B)** — one load-bearing Mox-at-Transport chained test proving the canonical adopter workflow; full verb/error coverage lives in companion unit files.
- **Integration file:** `test/lattice_stripe/tax/calculation_transaction_test.exs` — `async: true`, `setup :verify_on_exit!`, **no** `@moduletag :integration` (Phase 48 D-02: `:integration` tag = stripe-mock TCP probe only).
- **Single chained test** `"canonical standalone tax flow"` with ordered `expect/3`:
  1. `POST /v1/tax/calculations` → return fixture with known `id`
  2. `POST /v1/tax/transactions/create_from_calculation` → assert body contains calc `id` + dynamically generated `reference`
  3. `GET /v1/tax/transactions/:id` → return txn fixture
  4. `POST /v1/tax/transactions/create_reversal` → assert `original_transaction` + unique reversal `reference`
- **Dynamic IDs/references (PITFALLS #2, #3):** Never hardcode `taxcalc_*` IDs; always create calculation first. Use `"order_#{System.unique_integer([:positive])}"` for every transaction/reversal `reference`.
- **Unit files (separate):** `calculation_test.exs` and `transaction_test.exs` — per-verb isolation (retrieve, list_line_items, bang variants, path/body assertions), error paths (mock 400 `resource_expired` for calc, `reference_already_exists` for txn), guard/no-HTTP paths. Follow `credit_note_test.exs` split, not integration duplication.
- **Optional future:** `test/integration/tax_integration_test.exs` stripe-mock smoke (shape-only, stateless) — not Phase 49 requirement; stripe-mock cannot chain calc→txn because it is stateless (meter_integration_test.exs precedent).
- **Rationale:** DX-03/ROADMAP SC#7 require calc→txn chain; TXN-02 reversal is core to canonical flow (ARCHITECTURE.md calculate→record→reverse); Phase 48 locked Mox-at-Transport when stripe-mock cannot model behavior; Option C duplicates unit tests without adding integration-first proof value.

### Moduledoc scope boundary (D-03)
- **D-03:** **Structured relationship paragraph (Option A refined)** — not a full Accrue out-of-scope bullet list in moduledocs; fence AutomaticTax and operational traps at ExDoc discovery; defer filing/caching/wizard table to Phase 51 `guides/tax.md`.
- **`Tax.Calculation` moduledoc sections:**
  1. One-line purpose — standalone `/v1/tax/calculations` API for custom payment flows.
  2. **Lifecycle** — create → retrieve / list_line_items → (within ~90 days) hand off to Transaction; calculations are ephemeral; cite `expires_at`.
  3. **Relationship to other tax surfaces** (required paragraph) — explicitly NOT `LatticeStripe.Invoice.AutomaticTax` (nested settings struct on Invoice/Subscription/Quote for built-in automatic tax on Billing objects); for Checkout/Invoicing/Subscription flows, enable automatic tax on those resources instead; LatticeStripe exposes Stripe-shaped primitives only — filing, returns, and threshold monitoring are out of SDK scope.
  4. **Usage** — realistic `create/3` example with `customer_details`, `line_items`, `currency`.
  5. Stripe API reference link.
  6. Placeholder guide pointer: *"A canonical tax guide ships in v1.6 Phase 51."* (update cross-link when `guides/tax.md` lands).
- **`Tax.Transaction` moduledoc sections:**
  1. One-line purpose — record and reverse tax via standalone Tax Transactions API.
  2. **Lifecycle** — create_from_calculation (live calc ID + globally unique reference) → retrieve / list_line_items; create_reversal for refunds/corrections.
  3. **Operational constraints** (PITFALLS #2, #3 — required, not deferred) — calculations expire ~90 days; `reference` must be globally unique across all tax transactions (example: `"order_#{order_id}"`).
  4. **Relationship to other tax surfaces** — same AutomaticTax cross-ref paragraph (trimmed); recording in custom flows happens here, not via `automatic_tax` fields.
  5. Usage examples for `create_from_calculation/3` and `create_reversal/3`.
  6. Stripe API reference link.
- **Voice:** Match Quote ("stops at Stripe resource boundary"), Meter (lifecycle + guide deferral), Mandate/CreditNote (one-sentence negative fences). More explicit than generated stripe-ruby/node Tax moduledocs (Pitfall #4 is real — `Invoice.AutomaticTax` already ships) but less encyclopedic than duplicating REQUIREMENTS.md out-of-scope table.
- **Phase 49 docs-truth prep (no grep blocks yet — DX-05 is Phase 51):** Moduledocs must contain grepable strings: `90` + day/expiry language in Calculation; `reference` + unique/globally in Transaction; `Invoice.AutomaticTax` cross-link in both.

### ObjectTypes registration timing (D-04)
- **D-04:** **Register both in Phase 49 (Option A)** — co-locate with struct module delivery, same commit/plan.
- **Entries:**
  ```elixir
  "tax.calculation" => LatticeStripe.Tax.Calculation,
  "tax.transaction" => LatticeStripe.Tax.Transaction,
  ```
- **Also add:** Two cases to `test/lattice_stripe/object_types_test.exs` (follow existing dispatch tests).
- **Do NOT add:** Phase 49 expand integration test — five-type expand proof remains Phase 51 DX-01 scope.
- **Rationale:** ROADMAP already assigns ObjectTypes to Phase 50 (settings/registration) incrementally; deferring calc/txn to Phase 51 contradicts that staggered model. Partial registration (Calculation only) leaves expand cross-references as raw maps inside typed parents — silent type erosion. Two map entries cost ~4 lines; Pitfall #6 risk if deferred. Phase 47 built the gate (`fetch_module/1`); Phase 49 populates it for Tax core pair same as `billing.meter` precedent. Direct API calls work without ObjectTypes, but expand paths and future webhook completeness benefit immediately.

### Claude's Discretion
- Exact `@known_fields` lists after Stripe doc verification during plan-phase (nested param shapes flagged in research SUMMARY).
- Whether `Tax.TaxBreakdown` is shared or duplicated across Calculation/Transaction (decide at implementation if shapes match).
- Unit test file organization (single `tax_test.exs` vs split `calculation_test.exs` + `transaction_test.exs`) — prefer split per CreditNote precedent unless planner finds strong reason to merge.
- Optional stripe-mock smoke test file — include only if plan capacity allows; not required for Phase 49 close.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & pitfalls
- `.planning/PROJECT.md` — v1.6 Tax milestone goal, Accrue boundary, design philosophy (explicit verbs, least surprise)
- `.planning/REQUIREMENTS.md` — CALC-*, TXN-*, DX-03 traceability; Out of Scope table (filing, AutomaticTax bridging, rate caching)
- `.planning/ROADMAP.md` — Phase 49 success criteria (#1–7)
- `.planning/research/PITFALLS.md` — Pitfalls #1–4 (scope bleed, 90-day expiry, reference uniqueness, AutomaticTax conflation)
- `.planning/research/ARCHITECTURE.md` — Tax namespace layout, canonical calc→txn→reverse flow, anti-patterns
- `.planning/research/SUMMARY.md` — Phase 49 nested param research flag

### Established codebase patterns
- `lib/lattice_stripe/quote.ex` — bounded nested typing (`Computed`), `list_line_items/4`, lifecycle moduledoc
- `lib/lattice_stripe/credit_note.ex` — flat LineItem struct, paginated line items, verb functions
- `lib/lattice_stripe/billing/meter.ex` — namespace grouping, verb functions, lifecycle moduledoc + guide deferral
- `lib/lattice_stripe/invoice/automatic_tax.ex` — existing AutomaticTax struct (do NOT extend; cross-ref only)
- `lib/lattice_stripe/object_types.ex` — dispatch table; Phase 47 `fetch_module/1` gate

### Integration test precedents
- `.planning/milestones/v1.5-phases/48-thin-event-adoption-surface-guide-integration-verification/48-CONTEXT.md` — D-02 Mox-at-Transport strategy, namespace under `test/lattice_stripe/`, no `@moduletag :integration`
- `test/lattice_stripe/webhook/thin_event_test.exs` — chained Mox roundtrip pattern
- `test/lattice_stripe/billing/meter_integration_test.exs` — stripe-mock smoke anti-pattern for stateful chains (reference only)

### Prompts research (vision alignment)
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Tax as major family; escape hatches for unknown fields; handwritten ergonomics over codegen depth
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — lifecycle-first SDK design; transport foundation before product wrappers
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — explicit APIs, `{:ok, _}` + bang variants, stable return types, excellent moduledocs

### External Stripe docs (verify during plan-phase)
- [Stripe Standalone Tax API](https://docs.stripe.com/tax/standalone-tax-api) — canonical adopter flow
- [Stripe Tax API Reference](https://docs.stripe.com/api/tax) — Calculation/Transaction object shapes and verb paths

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Resource` — unwrap_singular/bang!, standard create/retrieve patterns
- `LatticeStripe.List` — paginated list decoding for `list_line_items/4`
- `LatticeStripe.Request` + `FormEncoder` — POST param encoding (string-key maps)
- `LatticeStripe.ObjectTypes.maybe_deserialize/1` — expandable nested objects on line items
- `LatticeStripe.Invoice.AutomaticTax` — existing tax-named struct; cross-reference target only

### Established Patterns
- **Namespace:** `LatticeStripe.Tax.*` under `lib/lattice_stripe/tax/` (matches `Billing.Meter` under `billing/`)
- **Verbs:** Explicit functions for non-CRUD paths (`create_from_calculation/3`, `create_reversal/3`) — matches Quote finalize/accept, Meter deactivate/reactivate
- **Line items:** Separate paginated endpoint + nested LineItem module — Quote, CreditNote, Checkout.Session precedent
- **Bounded typing:** `@known_fields` + `extra` maps; deep subtrees intentionally left as maps when volatile (Quote.Computed, AutomaticTax.liability)
- **Testing split:** Mox chained workflow test + per-verb unit tests; stripe-mock for stateless shape smoke only

### Integration Points
- `lib/lattice_stripe/object_types.ex` — add 2 entries when Tax modules ship
- No changes to `Invoice.AutomaticTax`, `Invoice`, `Subscription`, or `Quote` modules beyond potential moduledoc cross-links from Tax modules
- Phase 51 will add Testing fixtures, guide, docs-truth — Phase 49 modules should not anticipate those APIs

</code_context>

<specifics>
## Specific Ideas

- Cross-SDK lesson: official stripe-ruby/node/go type Tax deeply because OpenAPI codegen is free; LatticeStripe wins on **bounded handwritten ergonomics** — type what adopters pattern-match in the calc→txn flow, map the rest.
- Cross-SDK lesson: all mature Stripe SDKs prove Tax at HTTP boundary with fixtures (nock/httptest/MockWebServer), not stateful tax servers — Mox-at-Transport is the idiomatic LatticeStripe expression of that pattern.
- stripity_stripe ecosystem footgun: legacy libs often under-type or over-magic; LatticeStripe's `@known_fields` + `extra` contract is the forward-compat escape hatch prompts research mandates.
- Accrue downstream consumer already exists — Phase 49 must stay primitive-first so Accrue owns filing orchestration without SDK scope creep.

</specifics>

<deferred>
## Deferred Ideas

- Full Accrue out-of-scope bullet list in moduledocs — Phase 51 `guides/tax.md` (DX-04)
- Docs-truth grep blocks for Tax moduledocs — Phase 51 (DX-05)
- Five-type ObjectTypes expand proof — Phase 51 (DX-01)
- `LatticeStripe.Testing` Tax fixtures — Phase 51 (DX-02)
- Optional stripe-mock Tax smoke test — nice-to-have, not Phase 49 gate
- Tax Code lookup resource (`TAX-01`) — v1.7+
- Request-side param builder helpers for deeply nested Tax create params — out of scope; raw maps only

</deferred>

---

*Phase: 49-tax-calculation-transaction-core*
*Context gathered: 2026-05-27*
