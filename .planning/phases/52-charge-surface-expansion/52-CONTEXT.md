# Phase 52: Charge Surface Expansion - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Expand `LatticeStripe.Charge` from retrieve-only to full support/reconciliation surface: `list/3`, `list!/3`, `stream!/3`, `search/3`, `search!/3`, `search_stream!/3`, `update/4`, `update!/4`, `capture/4`, and `capture!/4` — preserving existing `retrieve/3`, `retrieve!/3`, and `from_map/1`.

**Explicitly out of scope:** `create/3` and `cancel/3` (PI-first design; Phase 18 D-06 preserved). No new canonical guide, no `guides/charges.md`, no README/JTBD discovery work (Phase 53 is operator guides only).

</domain>

<decisions>
## Implementation Decisions

### PI-first moduledoc narrative (D-01)
- **D-01:** Rewrite `@moduledoc` using the **PaymentIntent-first result-record** pattern — not "retrieve-only by design."
- **Opening:** Charge is the **result record** of a payment attempt; PaymentIntent confirmation creates the Charge; new integrations start with `LatticeStripe.PaymentIntent`.
- **Section order:** opening paragraph → `## When to use this module` (Connect reconciliation, support/audit list+search, post-hoc metadata) → `## When not to use this module` (accept payment → PI; capture PI charge → `PaymentIntent.capture/4`; cancel → `PaymentIntent.cancel/4`; refund → `Refund.create/3`) → `## Usage` (retrieve w/ expand, list/stream, search, update, capture) → `## Connect platform fee reconciliation` (keep existing content) → `## SDK surface (intentionally omitted)` (no `create`/`cancel`; D-06 reframed as **no payment initiation**, not read-only) → `## Security and Inspect` → `## Stripe API Reference`.
- **Remove stale phrases:** "retrieve-only access," "Only three public functions exist," "Charges are never directly manipulated through this SDK," leading negative inventory of absent functions.
- **Per-function `@doc` on `capture/4`:** Include Stripe's PI redirect — do not use `Charge.capture/4` for PaymentIntent-initiated charges; use `PaymentIntent.capture/4`.

### Canonical sibling template (D-02)
- **D-02:** **`PaymentIntent` is the mechanical template** for list/search/stream/update/capture implementation — identical arity, `Resource.unwrap_*` wiring, and bang grouping; swap paths to `/v1/charges`.
- **Hybrid touches only:**
  - From **Refund:** document `update/4` field constraints — metadata **and** description (CHRG-03); do not copy Refund's "metadata only" wording.
  - From **existing Charge:** keep pre-network `ArgumentError` on empty retrieve id; keep PII-safe `Inspect`.
  - **Do not use Dispute as template** — lacks search; domain helpers (`update_evidence/4`, `close/3`) don't transfer.
- **Search signature:** `search(client, query, opts)` with bare query string — matches PaymentIntent/Customer, not Invoice's params-map overload.
- **Add aliases:** `List`, `Response` to `charge.ex` (currently missing).
- **Do not add:** nested refund helpers on Charge, third pagination API, `create`/`cancel` for SDK parity.

### D-06 test contract evolution (D-03)
- **D-03:** **Delete entirely** the `describe "module surface (D-06 retrieve-only)"` block and its eight negative-only export tests.
- **Replace with** TaxId-style dual contract in `charge_test.exs`:
  - `"module surface"` test 1: **positive** assert full expanded export matrix (retrieve, list, list!, stream!, search, search!, search_stream!, update, update!, capture, capture!, from_map).
  - `"module surface"` test 2: **negative** refute `create`/`cancel` only (all common arities) — PI-first D-06 guard.
- **Mox wire truth:** Add one `describe` per new operation in `test/lattice_stripe/charge/` (roadmap criterion 6) — method/path/body assertions via MockTransport; mirror `payment_intent_test.exs` / `dispute_test.exs` patterns.
- **Keep unchanged:** existing retrieve, retrieve!, from_map, and Inspect describes (may relocate under `test/lattice_stripe/charge/` for directory cohesion).
- **Four-surface triangulation (CHRG-05):** moduledoc + code + Mox tests + `docs_truth_test.exs` grep block — **no** separate Tax-style `adoption_contract_test.exs` (Charge has no canonical guide trilogy; Dispute expansion did not get one either).
- **`docs_truth_test.exs`:** New test locking expanded surface names, PI-first rationale, Connect reconciliation anchor, and **refuting** stale retrieve-only language.

### Testing helper & integration depth (D-04)
- **D-04:** **Defer `LatticeStripe.Testing.charge/1`** for Phase 52 — internal `LatticeStripe.Test.Fixtures.Charge` suffices; no documented adopter workflow in `guides/testing.md`; avoid public API creep per elixir-opensource-libs best practices.
- **Primary proof:** Mox-at-Transport under `test/lattice_stripe/charge/` (required).
- **Stripe-mock integration (recommended polish):** Extend `test/integration/charge_integration_test.exs` with shape-first smokes for `list/3`, `search/3`, `update/4`, and `capture/4` — same "routing + typed decode" stance as `dispute_integration_test.exs`; do not duplicate Mox wire assertions or test lifecycle semantics stripe-mock cannot model.
- **Do not add:** `guides/charges.md`, README/JTBD Charge routes, ExDoc new canonical guide, deep stripe-mock lifecycle tests.

### Claude's Discretion
- Exact Mox test file layout under `test/lattice_stripe/charge/` (single file vs split by verb).
- Whether to relocate existing `charge_test.exs` contents into the charge/ subdirectory or keep top-level file and add charge/* for new ops only.
- Exact docs-truth grep anchor strings (implementation detail).
- Search moduledoc note on eventual consistency and India availability (copy PaymentIntent search caveat wording).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` — Phase 52 goal, success criteria, CHRG-01..05
- `.planning/REQUIREMENTS.md` — CHRG requirements; out-of-scope table (no create/cancel)
- `.planning/threads/v1-7-next-milestone-assessment.md` — Charge gap analysis, PaymentIntent pattern recommendation

### Domain & API surface research
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Charge as read/legacy compatibility; PI-first migration story
- `prompts/stripe-explanation-domain-language-deep-research.md` — Charge vs PaymentIntent mental model
- `prompts/payments_domain_field_guide.md` — Charge object semantics, search support, Connect charge types, capture/refund flows
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — {:ok,_}|{:error,_}, bang convention, minimal stable public API

### Prior decisions
- Phase 18 D-06 (referenced in `lib/lattice_stripe/charge.ex` @moduledoc) — reframed: no payment initiation, not retrieve-only
- `.planning/JTBD-MAP.md` — Gap 1: Charge audit/reconciliation wedge

### Implementation templates (code)
- `lib/lattice_stripe/payment_intent.ex` — list/search/stream/capture/update mechanical template
- `lib/lattice_stripe/dispute.ex` — list/stream! pattern; support-workflow moduledoc tone reference
- `lib/lattice_stripe/refund.ex` — update field constraint documentation style
- `lib/lattice_stripe/charge.ex` — existing retrieve, from_map, Inspect, Connect reconciliation examples
- `test/lattice_stripe/charge_test.exs` — D-06 contract to replace
- `test/lattice_stripe/tax/adoption_contract_test.exs` — surface guard pattern reference (export asserts only; do not copy guide UAT sections)
- `test/lattice_stripe/docs_truth_test.exs` — docs-truth grep pattern (Tax moduledoc lock precedent)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/lattice_stripe/charge.ex` — full `from_map/1`, PII Inspect, Connect fee-reconciliation `@moduledoc` example
- `test/support/fixtures/charge.ex` — `basic/0`, `with_balance_transaction_expanded/0`, `with_pii/0` for Mox responses
- `Resource.unwrap_singular/2`, `Resource.unwrap_list/2`, `List.stream!/2` — shared pagination/search infrastructure
- `PaymentIntent` list/search/capture implementations — copy paths, swap `/v1/charges`

### Established Patterns
- Explicit verbs with `{:ok, result} | {:error, %Error{}}` + bang variants via `Resource.unwrap_bang!/1`
- Search: bare query string arg, `GET /v1/{resource}/search`, `%{"query" => query}` params
- Capture: `POST /v1/{resource}/:id/capture`, optional params map, returns singular struct
- Partial-surface resources use positive export asserts + negative forbidden-op refutes (TaxId pattern)
- docs-truth grep blocks lock moduledoc surface declarations against drift

### Integration Points
- `ObjectTypes` — Charge already registered; no registry changes expected
- `Dispute.charge`, `Refund.charge`, `PaymentIntent.latest_charge` — expanded Charge surface improves expand/deserialize workflows already tested
- Phase 53 operator guides may reference Charge reconciliation — surface must land first (ROADMAP dependency)

</code_context>

<specifics>
## Specific Ideas

- Reframe D-06 once in `## SDK surface (intentionally omitted)` — not in the opening paragraph.
- Official SDK lesson (stripe-node): `charges.capture` docstring warns against capturing PI-initiated charges — replicate at `Charge.capture/4` call site.
- stripity_stripe frames "intent based" as modern default — LatticeStripe should match that posture while omitting deprecated `create`.
- Four-surface triangulation satisfies CHRG-05 without a Tax-style adoption trilogy — Dispute-scale wire expansion, not Tax-family closure.

</specifics>

<deferred>
## Deferred Ideas

- **`LatticeStripe.Testing.charge/1`** — add when a `guides/testing.md` section documents Charge webhook/fixture workflows (no adopter pull in Phase 52).
- **`guides/charges.md` canonical guide** — belongs in a future adoption phase if evaluators need a discovery ladder entry; not v1.7 scope.
- **Charge `create`/`cancel`** — permanently out of scope per REQUIREMENTS; PI owns payment initiation.
- **Tax-style `adoption_contract_test.exs`** — defer unless a canonical Charge guide ships in a later phase.

</deferred>

---

*Phase: 52-charge-surface-expansion*
*Context gathered: 2026-05-27*
