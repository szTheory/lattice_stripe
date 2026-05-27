# Phase 51: TaxId, Testing & Adoption Surface - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the v1.6 Tax family adoption surface: dual-path `LatticeStripe.TaxId`, public `LatticeStripe.Testing` fixtures for Calculation/Transaction/TaxId, canonical `guides/tax.md`, five-type ObjectTypes expand proof (including `tax_id`), and docs-truth regression locking Tax moduledocs and guide content.

**In scope:** TAXID-01..04, DX-01, DX-02, DX-04, DX-05; `lib/lattice_stripe/tax_id.ex`, nested `TaxId.Verification` and `TaxId.Owner`, ObjectTypes `tax_id` entry, `lib/lattice_stripe/testing/fixtures/tax_*.ex`, promotion of calc/txn wire fixtures from test/support, `guides/tax.md`, extensions to `docs_truth_test.exs`, `tax_object_types_expand_test.exs`, discovery wiring (README, JTBD, payments cross-link), Tax moduledoc guide link replacement.

**Out of scope:** Tax Code lookup (TAX-01 / v1.7+); request param builders; public Settings/Registration Testing fixtures (DX-02 lists Calc/Txn/TaxId only); `Customer.tax_ids` expand typing or `CustomerDetails.tax_ids` struct promotion (Phase 49 D-01 stands); chained settings→registration→calculation Mox integration spec (guide narrative only); Event `data` typed as Tax objects; stripe-mock Tax smoke (optional, not gate).

</domain>

<decisions>
## Implementation Decisions

### TaxId dual-path API shape (D-01)
- **D-01:** **Single top-level `LatticeStripe.TaxId` with positional parent routing** — extra `customer_id` as second argument after `client` selects customer-nested Stripe paths; otherwise top-level paths. Matches locked STATE.md decision and `LoginLink` path-scoped parent precedent (more explicit than stripe-go `Customer` param, avoids stripe-node duplication and stripity_stripe customer-only footgun).
- **Arity matrix:**
  - Top-level: `create/3`, `retrieve/3`, `list/3` (`params \\ %{}`), `delete/3`, `stream!/3` (+ bang variants).
  - Customer-nested: `create/4`, `retrieve/4`, `list/4`, `delete/4`, `stream!/4` (+ bang variants).
- **No `update/*` or `search/*`** — Stripe TaxId is CRUDL minus update (Coupon precedent).
- **Nested `create`:** Omit `"customer"` from params body — Stripe infers from URL path.
- **Bang variants mirror non-bang arity exactly** (`create!/4` nested, not collapsed opts).
- **Moduledoc:** Open with dual-path URL table; document both paths before usage examples.
- **Tests:** `describe "module surface"` negative exports (refute `update/*`, `search/*`, wrong arities); per-path Mox tests asserting `/v1/tax_ids` vs `/v1/customers/:id/tax_ids`; register `"tax_id" => LatticeStripe.TaxId` in `object_types.ex` co-located with module delivery.

### `guides/tax.md` shape & discovery (D-02)
- **D-02:** **`guides/tax.md` is a Canonical Guide (~280–350 lines)** — resource-family reference + canonical workflow, not Operations & DX (webhooks/testing tier) and not Flagship Recipe (Accrue-scale orchestration).
- **ExDoc:** Add to `mix.exs` `extras` and **`Canonical Guides`** group (near `metering.md` / `payments.md`).
- **Section spine (order flexible at plan time):**
  1. Scope boundary — SDK primitives only; filing/returns/threshold monitoring out of scope (name Accrue if PROJECT.md does).
  2. **Choose your path** — `Invoice.AutomaticTax` / Checkout / Subscription / Quote vs standalone `Tax.Calculation` API (Pitfall #4).
  3. Mental model — configure (Settings/Registration) → ephemeral Calculation → durable Transaction → optional reversal; ~90-day expiry.
  4. Configure once — Settings defaults → Calculation fallback; Registration does not register with tax authorities; US + one non-US `country_options` example; link Stripe for full jurisdiction list.
  5. **Primary spine** — calculate → record → reverse with Elixir examples aligned to `calculation_transaction_test.exs` (dynamic `reference`, unique reference footgun).
  6. TaxId — dual-path summary + one example.
  7. Testing — `LatticeStripe.Testing` fixtures; link `guides/testing.md`.
  8. See also — payments, checkout, invoices, subscriptions, error-handling, Stripe custom-tax URL.
- **Discovery (Phase 48 D-04 pattern):** README new “Choose Your Route” entry for custom-payment tax; README Features/Tax bullet; `user-flows-and-jtbd.md` Start Here route + Job 1 (or billing job) `Read next` — **no new JTBD Job 8**; `recipes.md` compact bridge; `payments.md` closing reverse-link; one-line automatic_tax pointers in `invoices.md` / `subscriptions.md`; replace Phase 51 placeholder in all five Tax moduledocs with `guides/tax.md` link.
- **Skip 3B install canary** unless `tax.md` alone ships `~> 1.6` while README/getting-started stay on `~> 1.3`.

### Testing fixture API (D-03)
- **D-03:** **Two-layer v1.3 pattern with `tax_` prefix** — wire maps canonical; typed wrappers thin `from_map/1`.
- **Public modules:**
  - `LatticeStripe.Testing.Fixtures.TaxCalculation` — `tax_calculation_json/1`, `tax_calculation_line_item_json/1`
  - `LatticeStripe.Testing.Fixtures.TaxTransaction` — `tax_transaction_json/1`, `tax_transaction_line_item_json/1`
  - `LatticeStripe.Testing.Fixtures.TaxId` — `tax_id_json/1`
- **Public wrappers on `LatticeStripe.Testing`:** `tax_calculation/1`, `tax_transaction/1`, `tax_id/1`
- **Migration:** Lift `test/support/fixtures/tax_calculation.ex` and `tax_transaction.ex` into `lib/.../testing/fixtures/`; update lib tests to import public modules; delete support copies.
- **Keep internal-only:** `test/support/fixtures/tax_settings.ex`, `tax_registration.ex` — not DX-02 scope.
- **Reject:** bare `calculation/1` / `transaction/1` (collision); nested `Fixtures.Tax.*` namespace (new pattern); public Settings/Registration fixtures.
- **Docs:** Extend `guides/testing.md` with Tax subsection (Mox + fixture example in calc→txn chain).
- **Hex `mix.exs`:** Add new fixture modules to Testing group.

### Docs-truth grep scope (D-04)
- **D-04:** **Centralize all Tax docs-truth in `test/lattice_stripe/docs_truth_test.exs`** (Phase 48 contract); **remove** Phase 49 partial `"moduledoc grep targets"` from `transaction_test.exs` when migrating.
- **3C — ExDoc:** Assert `guides/tax.md` in `extras` and `Canonical Guides` group.
- **3A — Guide content locks:** `Calculation.create`, `create_from_calculation`, `create_reversal`; `Invoice.AutomaticTax`; `out of SDK scope`; `90` + `expires_at`/`days`; `reference` + (`globally` | `unique`); optional `country_options`, `Tax.Settings`, `Tax.Registration`, filing/Accrue phrase if guide names boundary.
- **3D — Cross-link graph:** Forward from `tax.md` to `testing.md`, `error-handling.md`, `payments.md`; reverse from JTBD + all five Tax `@moduledoc`s; optional `recipes.md`.
- **3E — Moduledoc source greps (semantic anchors, ~6–8 per module):**
  - **Calculation:** `90` + (`days` | `expires_at`); `Invoice.AutomaticTax`; `out of SDK scope`; `LatticeStripe.Tax.Transaction`; `guides/tax.md`
  - **Transaction:** `reference` + (`globally` | `unique`); `create_from_calculation`; `create_reversal`; `Invoice.AutomaticTax`; `LatticeStripe.Tax.Calculation`; `guides/tax.md`
  - **Settings:** `singleton`; `tax_code`; `LatticeStripe.Tax.Calculation`; `Invoice.AutomaticTax`; `stripe_account`; `guides/tax.md`
  - **Registration:** `tax authorities`; `country_options`; `LatticeStripe.Tax.Settings`; `LatticeStripe.Tax.Calculation`; `Invoice.AutomaticTax`; `out of SDK scope`; `stream!`
  - **TaxId:** `/v1/tax_ids` and `customers` (or equivalent dual-path prose); `Invoice.AutomaticTax`; `guides/tax.md`
- **Do not grep** forever: “A canonical tax guide ships in v1.6 Phase 51” placeholder — replace with guide link first, then grep link.

### ObjectTypes expand proof (D-05)
- **D-05:** **Hybrid test layout** — minimal dispatch stays in `object_types_test.exs`; expand-through-parent in new `test/lattice_stripe/tax_object_types_expand_test.exs`.
- **Registry:** Add `"tax_id" => LatticeStripe.TaxId` with TaxId module delivery.
- **`object_types_test.exs` additions:** `tax_id` dispatch test; `fetch_module/1` resolves all five: `tax.calculation`, `tax.transaction`, `tax.settings`, `tax.registration`, `tax_id`.
- **`tax_object_types_expand_test.exs` required scenarios:**
  1. `Tax.Calculation.from_map/1` — expanded `customer` → `%Customer{}`
  2. `Tax.Calculation` line item — expanded `product` via `ObjectTypes`
  3. `Tax.Transaction.from_map/1` — expanded `customer` → `%Customer{}`
  4. Root `ObjectTypes.maybe_deserialize/1` on `tax_id` map → `%TaxId{}`
- **Out of DX-01 narrow scope:** `Event.data` typing; `customer_details.tax_ids` on Calculation (Phase 49 D-01 raw list); Settings/Registration parent expand (dispatch + fetch_module sufficient).
- **Optional (Claude discretion):** `Webhook.fetch_related_object/3` for `tax_id`; `Customer.tax_ids` list expand — only if Customer module gains `tax_ids` field (defer by default).

### TaxId struct typing (D-06)
- **D-06:** **First-class `%TaxId{}` with two small nested modules** — extend Phase 49 D-01 pragmatic partial typing; do not deepen `CustomerDetails.tax_ids`.
- **Top-level `@known_fields`:** `id`, `object`, `country`, `created`, `customer`, `customer_account`, `deleted`, `livemode`, `owner`, `type`, `value`, `verification`
- **`TaxId.Verification`:** `status`, `verified_address`, `verified_name` — atomize `status` (`:pending`, `:verified`, `:unverified`, `:unavailable`).
- **`TaxId.Owner`:** `account`, `application`, `customer`, `customer_account`, `type` — atomize `type` (`:account`, `:application`, `:customer`, `:self`); `account`/`customer`/`application` through `ObjectTypes.maybe_deserialize/1` when expanded map.
- **`type` (TaxId):** **String pass-through** — do not atomize 100+ Stripe enum values.
- **`value`:** String; **Inspect redact** (PII — follow `Account.Company` precedent).
- **Moduledoc:** Link to Stripe for country/type formats; 1–2 examples (`eu_vat` + `DE`); no inline country matrix (deferred encyclopedic content lives in guide).
- **`CustomerDetails.tax_ids`:** Unchanged `list()` of maps on `%Tax.CustomerDetails{}`.

### Claude's Discretion
- Exact `@known_fields` after Stripe doc verification at plan time.
- Guide section ordering within D-02 outline; exact JTBD job number for tax route.
- Whether to add optional `fetch_related_object` Mox test for `tax_id` thin events.
- `tax_id_json/1` default fixture shape details (EU VAT baseline).
- Reversal fixture helper name (`tax_transaction_json` with `type: reversal` vs dedicated helper).
- `groups_for_modules` Tax sidebar group in ExDoc (optional; separate from guide extras group).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & requirements
- `.planning/PROJECT.md` — v1.6 Tax milestone, Accrue boundary, explicit client-first APIs, docs-truth as regression
- `.planning/REQUIREMENTS.md` — TAXID-01..04, DX-01, DX-02, DX-04, DX-05
- `.planning/ROADMAP.md` — Phase 51 success criteria (#1–6)
- `.planning/research/PITFALLS.md` — Pitfall #5 (TaxId dual-path), #6 (ObjectTypes gap)
- `.planning/research/ARCHITECTURE.md` — Pattern 4 dual-path, Tax namespace layout, `tax_id.ex` top-level placement
- `.planning/research/SUMMARY.md` — Phase 51 flags, TaxId discuss-phase resolution
- `.planning/research/FEATURES.md` — TaxId CRUDL, Testing fixtures, guide scope

### Prior phase decisions
- `.planning/phases/49-tax-calculation-transaction-core/49-CONTEXT.md` — D-01 typing, D-03 moduledoc, D-04 ObjectTypes stagger, Mox integration precedent
- `.planning/phases/50-tax-settings-registration/50-CONTEXT.md` — D-03 moduledoc prep strings, D-04 unit-only tests, singleton precedent contrast

### Codebase patterns
- `lib/lattice_stripe/login_link.ex` — path-scoped parent ID as second positional arg after client
- `lib/lattice_stripe/credit_note.ex` — CRUDL + `stream!/3`, no update where Stripe omits it
- `lib/lattice_stripe/balance.ex` — singleton module surface negative tests
- `lib/lattice_stripe/testing.ex` + `lib/lattice_stripe/testing/fixtures/credit_note.ex` — two-layer fixture pattern
- `lib/lattice_stripe/object_types.ex` — dispatch table; four Tax types already registered
- `test/lattice_stripe/object_types_test.exs` — per-type dispatch tests
- `test/lattice_stripe/docs_truth_test.exs` — Phase 48 docs-truth contract (3A–3E)
- `test/lattice_stripe/tax/calculation_transaction_test.exs` — canonical flow for guide alignment
- `guides/metering.md` — Canonical Guide depth reference (upper bound)
- `.planning/milestones/v1.5-phases/48-thin-event-adoption-surface-guide-integration-verification/48-CONTEXT.md` — D-01 guide tier, D-03 docs-truth, D-04 discovery wiring

### Prompts (vision / DX)
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — handwritten bounded typing vs OpenAPI codegen depth
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — lifecycle-first SDK design
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — explicit APIs, `{:ok,_}` + bang, tuple errors, excellent moduledocs

### External Stripe docs
- [Stripe Tax IDs API](https://docs.stripe.com/api/tax_ids) — dual paths, object shape, no update
- [Stripe Customer tax IDs](https://docs.stripe.com/billing/taxes/tax-ids) — type/country formats (link target, not inline matrix)
- [Stripe Standalone Tax API](https://docs.stripe.com/tax/standalone-tax-api) — canonical adopter flow for guide spine
- [Stripe Tax custom payment flows](https://docs.stripe.com/tax/custom) — depth reference for guide link-outs

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Resource` — unwrap_singular/bang!, standard CRUD patterns
- `LatticeStripe.List` — `list/3` + `stream!/3` for TaxId list pagination
- `LatticeStripe.ObjectTypes.maybe_deserialize/1` — expand on TaxId owner/customer fields
- `test/support/fixtures/tax_calculation.ex`, `tax_transaction.ex` — promote to public Testing fixtures
- `test/support/fixtures/tax_settings.ex`, `tax_registration.ex` — remain internal for lib unit tests
- Phase 49 moduledoc grep strings — migrate to `docs_truth_test.exs`

### Established Patterns
- Tax modules under `lib/lattice_stripe/tax/`; top-level `tax_id.ex` for object type `tax_id`
- ObjectTypes entries co-located with module delivery (Phases 49–50 stagger)
- Mox-at-Transport unit tests; expand proof on resource `from_map/1` (credit_note, invoice precedent)
- Docs-truth as first-class CI contract, not editorial cleanup
- Guide tier: Canonical Guides for domain workflows; Operations & DX for trust/ops rails

### Integration Points
- `object_types.ex` — add `tax_id` entry
- `mix.exs` — `guides/tax.md` in extras + Canonical Guides; Testing group modules
- `lib/lattice_stripe/testing.ex` — three new typed wrappers
- All Tax moduledocs — replace Phase 51 placeholder with guide link
- `docs_truth_test.exs` — Tax guide + moduledoc blocks
- README, `user-flows-and-jtbd.md`, `payments.md`, `guides/testing.md` — discovery updates

</code_context>

<specifics>
## Specific Ideas

- **Cross-SDK:** stripe-go unifies TaxId paths via params; LatticeStripe wins on **explicit arity = URL shape** (LoginLink precedent) — more discoverable in ExDoc and `@spec`.
- **stripity_stripe footgun:** customer-only TaxId routing breaks top-level `/v1/tax_ids` — Phase 51 must implement both paths with tests (Pitfall #5 never shortcut).
- **stripe-ruby/node:** thin Tax moduledocs + Stripe.com depth — LatticeStripe guide is the missing spine, not moduledoc encyclopedia.
- **Prompts alignment:** wire map canonical in tests; bounded handwritten structs; lifecycle-first guide; docs-truth locks decisions against drift.
- **Adopter mental model:** Guide opens with automatic_tax vs standalone decision — prevents Pitfall #4 before adopters read Calculation moduledoc.
- **B2B VAT:** TaxId `verification.status` is workflow-critical — justify `TaxId.Verification` submodule vs flat map.

</specifics>

<deferred>
## Deferred Ideas

- `Customer.tax_ids` expand list decoding through ObjectTypes — webhook-heavy B2B; defer unless explicit requirement emerges
- `Webhook.fetch_related_object/3` Mox test for `tax_id` — optional in Phase 51
- Request param builders for Tax create params — out of scope (Phases 49–50 precedent)
- Tax Code lookup resource (`TAX-01`) — v1.7+
- Chained settings → registration → calculation Mox integration file — guide narrative only (Phase 50 D-04: no wire coupling)
- Public `Testing` fixtures for Settings/Registration — DX-02 excludes; revisit only if guide adds heavy configure-once test recipes
- stripe-mock Tax smoke test — optional, not gate
- 3B install canary `~> 1.6` in `tax.md` only — only if staggered Hex release
- `Event.from_map/1` typed Tax `data` — out of SDK event design

</deferred>

---

*Phase: 51-taxid-testing-adoption-surface*
*Context gathered: 2026-05-27*
