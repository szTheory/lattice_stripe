# Phase 59: Checkout Guide & README Truth - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix copy-paste bugs in `guides/checkout.md` and `README.md` and add `docs_truth_test.exs` regression locks so stale patterns fail CI. Doc-only milestone — no Hex bump, no CI workflow changes (CI-01 is Phase 60), no new API breadth.

**In scope:** CHECKOUT-01..03, README-01..02, VERIFY-05.

**Out of scope:** JTBD-MAP upgrade (Phase 60), CI `paths-ignore` fix (Phase 60), payments.md output-comment wire-string polish, new recipes or API modules.

</domain>

<decisions>
## Implementation Decisions

### Status callout scope
- **D-01:** One callout covers **both** atomized Session enums — `payment_status` (`:paid`, `:unpaid`, `:no_payment_required`) and `status` (`:open`, `:complete`, `:expired`).
- **D-02:** Callout explains the struct-vs-wire split: atoms on `%LatticeStripe.Checkout.Session{}`; wire strings in Stripe API reference, Dashboard, list filters, and webhook raw maps (`event.data["object"]`).
- **D-03:** Include a brief fulfillment note: `status == :complete` does not imply paid — check `payment_status` before fulfilling (especially async payment methods).
- **D-04:** Do **not** add wire→atom mapping tables — follow `guides/payments.md` shape (blockquote + wire-string reference lists below).

### Callout placement and example fixes
- **D-05:** Place the status-values callout **immediately before** the stream pipeline code block under `### Auto-Pagination with Streams` (within `## Listing Sessions`) — the first status **comparison** in the guide, mirroring Phase 57 payments.md placement logic.
- **D-06:** Fix line 206 filter: `s.payment_status == :paid` (not `"paid"`). Strengthen example with fulfillment-safe filter: `s.payment_status == :paid and s.status == :complete`.
- **D-07:** Optional one-liner at end of "Retrieving Sessions" cross-linking to Auto-Pagination with Streams for status comparisons — do not duplicate the full callout at retrieve.
- **D-08:** Leave `# Status: expired` output comments unchanged (wire-string output comments deferred per REQUIREMENTS polish tier).

### README error taxonomy
- **D-09:** Replace README L111 stale atoms (`:auth_error`, `:server_error`) with canonical `:authentication_error` and `:api_error`.
- **D-10:** Keep teaser shape ("4 examples + and more") — do **not** enumerate all seven error types in README.
- **D-11:** Add inline link to canonical guide. Exact target line:

  ```markdown
  - Structured, pattern-matchable errors: `:card_error`, `:authentication_error`, `:rate_limit_error`, `:api_error`, and more — [Guide: Error Handling](guides/error-handling.md)
  ```

### docs_truth regression locks
- **D-12:** Mirror Phase 57 payments pattern — dedicated `describe "guides/checkout.md"` block, separate from cross-link graph tests.
- **D-13:** Add `@stale_checkout_api_patterns` module attribute (minimum: `~s/payment_status == "paid"/`) with positive assert on `payment_status == :paid` and refute loop.
- **D-14:** Second checkout test (or folded asserts) locks callout presence: `"Status values:"`, `%Session{}`, `:paid`.
- **D-15:** Dedicated `describe "README.md"` test `"error taxonomy matches Error module atoms"` — assert `:authentication_error`, `:api_error`, `:card_error`; refute `:auth_error`, `:server_error` via `@stale_readme_error_atoms`.
- **D-16:** Do **not** consolidate checkout + README + payments into one describe — preserve per-surface failure signals for Phase 60 CI-01 enforceability.

### Claude's Discretion
- Exact callout prose wording and wire-string bullet formatting (must satisfy D-01..D-04 intent).
- Whether retrieve-section cross-link (D-07) ships in same PR or is omitted if redundant.
- Optional expansion of `@stale_checkout_api_patterns` to `"unpaid"` string compare if present in examples.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 59 success criteria (CHECKOUT-01..03, README-01..02, VERIFY-05)
- `.planning/REQUIREMENTS.md` — v1.9 requirement definitions and traceability

### Canonical guide precedent (Phase 57)
- `guides/payments.md` §Status values callout (lines 110–118) — template for checkout callout shape
- `guides/payments.md` §Auto-Pagination with Streams (line 199) — atom filter example pattern
- `test/lattice_stripe/docs_truth_test.exs` — `describe "guides/payments.md"` and `@stale_payments_api_patterns` (VERIFY-04 precedent)

### Source of truth for fixes
- `guides/checkout.md` — line 206 bug (`"paid"` string filter); retrieve section (lines 164–172)
- `README.md` — line 111 error taxonomy drift
- `lib/lattice_stripe/checkout/session.ex` — `atomize_status/1`, `atomize_payment_status/1` (lines 683–696)
- `lib/lattice_stripe/error.ex` — canonical seven `type` atoms in moduledoc/typespec

### Error taxonomy SSOT
- `guides/error-handling.md` — full error type table (README delegates here)
- `guides/getting-started.md` — first-run error examples (already correct; do not regress)

### Assessment and vision
- `.planning/threads/v1-9-next-milestone-assessment.md` — repo-truth findings motivating this phase
- `.planning/PROJECT.md` — core value: copy-paste correct, unsurprising, Elixir-idiomatic
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — Checkout Tier 2 DX priority
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — README vs guide responsibility split
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md` — typed error model as day-one SDK priority

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `atomize_payment_status/1` and `atomize_status/1` in `lib/lattice_stripe/checkout/session.ex` — define the atom set the guide must document.
- `describe "guides/payments.md"` in `docs_truth_test.exs` — copy structure for checkout describe block.
- `@stale_payments_api_patterns` — pattern for stale-pattern module attributes + refute loop.

### Established Patterns
- Phase 57 playbook: fix canonical example → add callout at first comparison site → grep-lock in docs_truth.
- Cross-link tests (`flagship guides are published and cross-linked`) assert routing only — body semantics belong in per-guide describes.
- Webhook handler examples in checkout.md correctly use wire strings from `event.data["object"]` — callout must scope atoms to `%Session{}` struct contexts.

### Integration Points
- `guides/checkout.md` stream filter example (line 206) — primary bug fix target.
- `README.md` Features §Payments bullet (line 111) — error taxonomy fix target.
- `test/lattice_stripe/docs_truth_test.exs` — new describe blocks plug in alongside existing payments describe.

</code_context>

<specifics>
## Specific Ideas

- "Checkout should feel boringly reliable" — Tier 2 surface per priority user-flows research; stream filter is the highest-risk copy-paste vector for reconciliation adopters.
- Fulfillment-safe stream example should filter `:paid` **and** `:complete` — teaches that event name / lifecycle complete ≠ payment succeeded.
- README fix follows official SDK pattern: marketing teaser + deep guide, not full enumeration (Finch/Req/Ecto README norms).
- stripity_stripe uses different error naming — README must not validate abbreviated atoms that never match `%LatticeStripe.Error{}`.

</specifics>

<deferred>
## Deferred Ideas

- payments.md / checkout.md `# Status:` output comments using wire strings — REQUIREMENTS polish tier, non-blocking.
- JTBD-MAP hosted checkout upgrade to Strong — Phase 60 (JTBD-01) after checkout locks land.
- CI `paths-ignore` narrowing — Phase 60 (CI-01), requires explicit workflow approval.
- Optional `@stale_checkout_api_patterns` expansion beyond `"paid"` — only if examples introduce additional string compares.

</deferred>

---

*Phase: 59-checkout-guide-readme-truth*
*Context gathered: 2026-05-27*
