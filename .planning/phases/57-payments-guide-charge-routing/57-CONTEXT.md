# Phase 57: Payments Guide & Charge Routing - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix copy-paste bugs in `guides/payments.md` (PaymentIntent status atoms, stream filter, search/3 arity); add a PI-first Charge reconciliation section routing list/search/update/capture; extend operator guides with update/capture discovery; lock canonical guide API patterns in `docs_truth_test.exs` (GUIDE-01..03, ROUTE-01, ROUTE-02, VERIFY-04).

**In scope:** `guides/payments.md` API fixes + Charge reconciliation section; `guides/production-checklist.md` and `guides/event-debugging.md` Charge routing deltas; `describe "guides/payments.md"` in `docs_truth_test.exs`; optional operator-guide grep anchors for ROUTE-02.

**Out of scope:** JTBD-MAP refresh (Phase 58); `guides/checkout.md` status bugs; moduledoc string-status cleanup in `payment_intent.ex`; CI paths-ignore; new API breadth; separate `guides/charge.md`.

</domain>

<decisions>
## Implementation Decisions

### API example corrections (Area 1 — Option B)

- **D-01:** Fix three broken executable blocks only — do not rewrite the entire guide.
- **D-02:** `confirm/3` status `case` uses atom arms: `:succeeded`, `:requires_action`, with `other ->` fallback for unknown/future statuses.
- **D-03:** `stream!/2` filter uses `intent.status == :succeeded` (not string compare).
- **D-04:** Search section documents `search/3` with query-string shape:

  ```elixir
  {:ok, resp} =
    LatticeStripe.PaymentIntent.search(client, "metadata['order_id']:'ord_456'")
  ```

- **D-05:** Status machine bullet list (L110–116) **keeps Stripe wire-string names** in backticks — they serve as Stripe API glossary for Dashboard, webhooks JSON, and search query syntax.
- **D-06:** Insert one bridge note immediately before the status-machine bullets:

  > **Status values:** LatticeStripe atomizes known PaymentIntent statuses on `%PaymentIntent{}` (e.g. `:succeeded`, `:requires_action`). Stripe's API reference, Dashboard, webhooks, and search queries use the wire string names below.

- **D-07:** Reject Option A (fixes code but leaves bullet→case copy-paste trap without bridge). Reject Option C (atom bullets fight Stripe cross-reference docs; search/webhooks remain string-layer anyway).
- **D-08:** Two-layer model is explicit: **request params and search queries = wire strings**; **decoded struct fields = atoms**.

### Charge reconciliation section (Area 2 — Option B)

- **D-09:** Add `## Charge reconciliation` section **after** `## Listing and Searching` (after search eventual-consistency note), **before** `## Refunding a Payment`.
- **D-10:** Target **~52–60 lines** — distilled routing spine, not moduledoc wholesale paste.
- **D-11:** Opening frames PI-first contract: Charge = result record; PaymentIntent = initiation; no `Charge.create/3`.
- **D-12:** Include verb routing table + one concise copy-paste example each for: `retrieve/3` (with `expand: ["balance_transaction"]`), `list/3` + `stream!/3`, `search/3`, `update/4`, `capture/4`.
- **D-13:** `Charge.search/3` carries eventual-consistency anti-pattern (same class as PI search note) — do not use search to confirm a payment that just succeeded.
- **D-14:** `Charge.capture/4` labeled **legacy direct charges only**; cross-link to existing `PaymentIntent.capture/4` section for PI manual capture.
- **D-15:** Connect fee depth deferred — one link to `connect-money-movement.md`; do not duplicate fee walkthrough.
- **D-16:** Cross-link to operator guides: production-checklist for pre-launch audit; event-debugging for `charge.*` webhook diagnosis.
- **D-17:** Reject Option A (too thin for ROUTE-01/CHRG-05 triangulation). Reject Option C (See also only — fails success criterion #4).

### Operator guide extensions (Area 3 — Option C)

- **D-18:** Operator guides = **routing spines** (Phase 53 pattern); canonical copy-paste snippets live in `payments.md#charge-reconciliation` only — single SSOT.
- **D-19:** Replace stale "no separate Charge guide in v1.7" lines in both operator guides with:

  ```markdown
  Full workflows: [Payments — Charge reconciliation](payments.md#charge-reconciliation) and
  `LatticeStripe.Charge` moduledoc.
  ```

- **D-20:** `production-checklist.md` §Support and audit lookups — add verb bullets (no code fences):
  - `Charge.retrieve/3` for known charge id from Dashboard/support
  - `Charge.update/4` for metadata/description on settled charges (not payment state)
  - `Charge.capture/4` for legacy direct uncaptured charges only; PI manual capture → `PaymentIntent.capture/4` with cross-link
- **D-21:** `event-debugging.md` §`charge.*` events — add:
  - `Charge.update/4` for post-dispatch support context (ticket id in metadata); idempotency still keyed on `event.id`
  - Anti-pattern: do not call `Charge.capture/4` from `charge.*` handlers for PaymentIntent flows
- **D-22:** Do **not** add capture/update code blocks to operator guides — bullet + anti-pattern shape only (matches existing search anti-pattern pattern).
- **D-23:** Optional ROUTE-02 docs_truth: assert `update/4` and `capture/4` in operator guide tests; assert cross-link to Charge reconciliation section.

### docs_truth lock strategy (Area 4 — Option B)

- **D-24:** Add `describe "guides/payments.md"` with **two tests** — do not extend tax-guide monolith (Phase 56 D-18).
- **D-25:** Test 1: `"canonical API examples use atom statuses and search/3"` — positive asserts for `:succeeded ->`, `:requires_action ->`, `intent.status == :succeeded`, `search/3`, query-string `PaymentIntent.search(client, "` pattern.
- **D-26:** Module attribute `@stale_payments_api_patterns` with refute loop:

  ```elixir
  @stale_payments_api_patterns [
    "\"succeeded\" ->",
    "\"requires_action\" ->",
    "intent.status == \"succeeded\"",
    "Use `search/2`",
    "PaymentIntent.search(client, %{"
  ]
  ```

- **D-27:** Test 2: `"routes Charge reconciliation after PaymentIntent flows"` — assert section heading/reconcil anchor; `LatticeStripe.Charge.list/search/update/capture`; `list/3` and `search/3` arity strings; PI-first ordering (`## Creating a PaymentIntent` precedes Charge reconciliation section via `"## Charge reconciliation"` anchor).
- **D-28:** Do **not** lock prose status bullets, Stripe API param strings, webhook event names, or illustrative log comments — lock copy-paste Elixir patterns only.
- **D-29:** Reject Option A (positive-only allows stale+correct coexistence). Reject Option C (structural regex brittleness — Phase 56 rejected verbatim locks).
- **D-30:** ROUTE-02 operator guide locks remain separate from payments describe when added.

### Claude's Discretion

- Exact bridge-note wording and Charge section editorial polish — must preserve atom patterns and PI-first framing.
- Whether to split Test 1 into two tests if combined CI failures prove confusing.
- Optional `Charge` moduledoc one-liner pointing to payments guide section.
- Exact `@stale_payments_api_patterns` extension if additional stale shapes discovered during implementation.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` § Phase 57 — success criteria, GUIDE-01..03, ROUTE-01/02, VERIFY-04
- `.planning/REQUIREMENTS.md` § Doc Routing, Verification — acceptance criteria
- `.planning/PROJECT.md` — v1.8 goal, docs_truth canonical guide gap assessment
- `.planning/STATE.md` — docs_truth must cover canonical guide API examples
- `.planning/config.json` — `docs_truth_canonical_guides: ["guides/payments.md"]`
- `.planning/JTBD-MAP.md` — payments.md bug inventory, Charge reconciliation discovery gap
- `.planning/threads/v1-8-next-milestone-assessment.md` — bug class analysis, SSOT lesson

### Prior phase decisions
- `.planning/phases/56-release-truth-getting-started/56-CONTEXT.md` — D-05 positive+refute, D-18 describe-per-guide, VERIFY-04 template

### v1.7 Charge surface (shipped code)
- `.planning/milestones/v1.7-MILESTONE-AUDIT.md` — CHRG-03/04/05 discovery gaps
- `.planning/milestones/v1.7-REQUIREMENTS.md` — CHRG-01..05 complete
- `lib/lattice_stripe/charge.ex` — PI-first moduledoc, list/search/update/capture examples
- `lib/lattice_stripe/payment_intent.ex` — `atomize_status/1`, `search/3` signature

### Implementation surfaces
- `guides/payments.md` — L89–101, L197, L208–213 bugs; missing Charge section
- `guides/production-checklist.md` — L163–176 Charge section
- `guides/event-debugging.md` — L207–219 charge.* section
- `guides/connect-money-movement.md` — Charge.retrieve fee reconciliation deep dive
- `guides/tax.md` — canonical guide routing pattern (distill, don't clone monolith)
- `test/lattice_stripe/docs_truth_test.exs` — Phase 56 getting-started describe, Charge moduledoc test L293–308
- `test/lattice_stripe/payment_intent_test.exs` — status atomization contract

### Research & ecosystem guidance
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — examples as API contract, four doc layers
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — docs regression in CI
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — Tier 1 Payments polish, search read-after-write
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — status lifecycles, generated core + handwritten ergonomics

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PaymentIntent.atomize_status/1` — seven known statuses → atoms; unknown pass-through as string
- `Charge` moduledoc — full list/search/update/capture examples ready to distill (~6 snippets)
- `describe "guides/getting-started.md"` — Phase 56 template for describe-per-guide locks
- Charge moduledoc docs_truth test — positive surface asserts (list/search/update/capture)

### Established Patterns
- **Two-layer docs:** wire strings in API params/search queries; atoms on decoded structs
- **PI-first everywhere:** moduledoc, operator guides, connect-money-movement all frame Charge as result record
- **Content vs routing split:** canonical guide body locks in payments describe; operator guides = spine bullets + cross-links
- **Positive + refute grep locks** — closes install-pin-passed/body-lied bug class

### Integration Points
- Charge section sits between PI list/search and Refunds — natural "what's next" beat
- Operator guides link to `payments.md#charge-reconciliation` — replaces stale moduledoc-only routing
- VERIFY-04 describe scales `docs_truth_canonical_guides` pattern from config.json

</code_context>

<specifics>
## Specific Ideas

### Coherent four-area package (research synthesis — user requested one-shot recommendations)

| Area | Decision | Why it coheres |
|------|----------|----------------|
| API fixes | Option B — atoms in code, wire strings in prose + bridge note | Matches SDK v1.2 contract; teaches two-layer model; Stripe cross-reference friendly |
| Charge section | Option B — ~55-line section after Listing/Searching | Closes CHRG-05/ROUTE-01; tax-guide routing pattern distilled; PI-first preserved |
| Operator guides | Option C — verb bullets + cross-link, no duplicate snippets | Phase 53 spine pattern; DRY SSOT in payments.md; avoids PI-capture footgun in event-debugging |
| docs_truth | Option B — two tests, positive + refute | Extends Phase 56 SSOT; locks copy-paste patterns not prose; separate failure signals |

### Cross-ecosystem lessons applied

**Do right (Stripe SDKs, Elixir OSS, LatticeStripe v1.7):**
- Treat guide examples as API contract (`elixir-opensource-libs-best-practices`)
- Atoms for finite semantic states in Elixir pattern matching (EXPD-05, CHANGELOG v1.2)
- Structured routing tables in canonical guides (tax.md precedent)
- Operator runbooks = scannable bullets + links, not second API reference (Phase 53)
- docs_truth grep locks on canonical guide body, not just install pins (PROJECT.md assessment)

**Footguns avoided:**
- String status `case` that never matches (current bug — silent wrong branch)
- `Charge.capture/4` in PI webhook handlers (operator anti-pattern explicit)
- Duplicating moduledoc snippets in 3 surfaces (doc drift)
- `Charge.search/3` for real-time payment confirmation (eventual consistency)
- Structural regex locks on guide sections (editorial refactor breaks CI)
- Atom notation in Stripe API glossary bullets (fights Dashboard/webhook cross-reference)

### Example target: confirm/3 fix

```elixir
case confirmed.status do
  :succeeded -> IO.puts("Payment succeeded!")
  :requires_action -> IO.puts("3D Secure required — redirect to: ...")
  other -> IO.puts("Unexpected status: #{other}")
end
```

With bridge note before status-machine bullets explaining wire strings vs struct atoms.

</specifics>

<deferred>
## Deferred Ideas

- **`guides/checkout.md` status string bugs** — same class as payments.md; out of Phase 57 scope; consider v1.8.x patch or Phase 58+ if discovered in audit
- **`PaymentIntent.cancel/4` moduledoc string status** — internal inconsistency; separate cleanup
- **Contributor git-dep / CI paths-ignore** — deferred per STATE.md
- **Separate `guides/charge.md`** — v1.7 decision: no separate guide; moduledoc + payments routing sufficient
- **JTBD-MAP charge-reconciliation row refresh** — Phase 58 ROUTE-03

</deferred>

---

*Phase: 57-payments-guide-charge-routing*
*Context gathered: 2026-05-27*
