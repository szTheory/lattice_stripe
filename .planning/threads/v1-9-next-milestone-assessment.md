# v1.9 Next-Milestone Assessment

Updated: 2026-05-27 (post-v1.8 repo-truth pass)

## Why this thread exists

After v1.8 Adopter Truth & Doc Routing Polish shipped and archived (2026-05-27), a fresh adopter-first assessment was run before defining the next milestone to (a) re-check how close LatticeStripe is to "done enough" for its intended v1.x SDK scope, (b) confirm the single highest-leverage next milestone, and (c) retain research so `/gsd-new-milestone` starts informed.

This thread captures durable findings, the v1.9 recommendation, and planning-truth corrections discovered by repo inspection (not milestone names alone).

## Done estimate

**~92–94%** (band: 90–95% near-done / diminishing returns soon)

| Rubric dimension | Score | Notes |
|---|---|---|
| Core JTBD coverage | ~95% | 179 lib modules, 48 ObjectTypes, ~35+ HTTP resource modules, 40 integration test files |
| Breadth vs category expectations | ~90% | Mainstream SaaS flows covered; specialist families correctly deferred |
| Docs / onboarding / install | ~87% | `~> 1.7` lockstep on 7 surfaces; getting-started fixed v1.8; **checkout.md + README errors remain** |
| Operator / diagnostic posture | ~91% | production-checklist + event-debugging + Charge routing (v1.7/v1.8) |
| Proof / CI honesty | ~89% | docs_truth on payments/getting-started; **CI paths-ignore skips docs-only PRs** |

## Repo-truth findings (verified by lib/ + guides scan, not planning docs alone)

### Shipped surface (post-v1.8)

- ~179 `.ex` files under `lib/lattice_stripe/`, 48 ObjectTypes entries, 40 integration-named test files.
- Full mainstream SaaS coverage: Payments, Billing, Connect, Tax core, thin-event webhooks, Charge reconciliation, operator guides.
- Hex **1.7.0** published; v1.8 was doc-only (no Hex bump — correct).
- v1.x stop signal published in README, `guides/scope.md`, PROJECT.md, CHANGELOG.

### Remaining gaps (verified)

**Important-but-narrow — doc/CI honesty, not foundational code:**

1. **`guides/checkout.md` line 206** — `Stream.filter(fn s -> s.payment_status == "paid" end)` compares wire string; SDK atomizes to `:paid` (same class as pre-v1.8 `payments.md` bug). No status-values callout like payments.md lines 110–118.
2. **`README.md` line 111** — lists `:auth_error` and `:server_error`; actual types are `:authentication_error` and `:api_error` per `lib/lattice_stripe/error.ex`.
3. **CI-01** — `.github/workflows/ci.yml` `paths-ignore` on `**.md` and `guides/**` skips entire CI including `docs_truth_test.exs` on guide-only PRs.
4. **docs_truth coverage gap** — checkout.md and README error taxonomy not locked; payments-only canonical guide lock left checkout exposed.
5. **JTBD-MAP overstated** — Hosted checkout rated "Strong" narrative while checkout.md has live copy-paste bug.
6. **Admin debt (non-blocking)** — `54-VERIFICATION.md` still missing from v1.7 Phase 54.

**Polish (lower priority):**

- payments.md output comments still use wire strings (`# Status: requires_payment_method`) despite atom pattern-match code being locked.
- Link format drift (`.md` vs `.html`) in getting-started Read next.

**Not a gap (documented by design):**

- Specialist families (Identity, Treasury, Issuing, Terminal, FC, Climate, Sigma, Reporting) absent by design.
- Tax calc→txn chain proven via Mox transport tests (not stripe-mock integration) — acceptable.
- `v2.core.*` ObjectTypes fail-fast per Phase 47 D-05.

### NOT shipped (correctly deferred)

- Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, Reporting.
- Tax narrow TAX-01 (tax_codes), TAX-02 (transaction list) — adopter pull only.

## Wedge analysis

### Wedge A — v1.9 CI & Doc Honesty (SELECTED)

**Why:** Same bug class as pre-v1.8 payments.md; CI-01 undermines docs_truth narrative; adopters copy-paste broken checkout code today.

**Done enough:**

- checkout.md atom status filters + status-values callout (mirror Phase 57 payments pattern)
- README error taxonomy fixed (`:authentication_error`, `:api_error`)
- docs_truth describe blocks for checkout.md + README error grep
- CI runs docs_truth on guide changes (CI-01 — requires explicit workflow approval)
- JTBD-MAP hosted checkout downgraded to Partial until locked
- Optional: backfill `54-VERIFICATION.md`

**Overbuilding line:** No new Stripe families, no new recipes, no Hex bump.

**Scope:** ~2 phases, ~1 day.

### Wedge B — Maintenance-only (honest alternative)

Bugfixes + Stripe API drift only; checkout/README as `/gsd-quick` tasks. Risk: unstructured doc debt persists; CI-01 stays open.

### Wedge C — Gap 2 narrative docs

Product/Price, BillingPortal config, disputes/files deep playbooks — diminishing returns unless adopter pull.

### Wedge D — Tax narrow (TAX-01/02)

Low adopter pull; defer.

### Wedge E — Specialist Stripe families

Only on documented adopter pull. Violates v1.x stop signal without pull.

## Recommended ordering

1. **v1.9 — CI & Doc Honesty** ← SELECTED
2. **Maintenance mode** — bugfixes, Stripe API drift, adopter-driven narrow additions
3. **Gap 2 narrative docs** — adopter pull or opportunistic only
4. **Specialist families / Tax narrow** — adopter pull only

## Why v1.9 is the right pick (post-v1.8)

- Library is declared done for v1.x scope at Hex 1.7.0 — no API breadth wedge remains.
- checkout.md `"paid"` filter is the same class of bug that embarrassed payments.md before Phase 57.
- README error taxonomy misleads adopters pattern-matching on wrong atoms.
- CI-01 means docs_truth locks are theater on guide-only PRs.
- v1.8 closed payments/getting-started but left checkout + README + CI untouched (explicitly deferred in v1.8 audit).

## Graduation candidates

- **docs_truth canonical guides list must include checkout.md** — payments-only lock left checkout exposed.
- **README high-visibility claims need grep locks** — error taxonomy drift survived because README body not in docs_truth.
- **JTBD narrative ratings require executable example audit** — "Strong" must mean copy-paste works, not just guide exists.
- **Extend docs_truth when fixing one canonical guide** — audit sibling guides in same flow (payments fixed → checkout missed).

## Decision fork (for `/gsd-new-milestone`)

Choose one when starting the next milestone:

1. **v1.9 CI & Doc Honesty** — structured milestone (~2 phases) — recommended
2. **Maintenance-only** — quick tasks for checkout + README only
3. **Mostly stop** — no structured milestone until adopter pull

## Files consulted

- `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/MILESTONES.md`, `.planning/JTBD-MAP.md`
- `.planning/threads/v1-8-next-milestone-assessment.md`, `.planning/milestones/v1.8-MILESTONE-AUDIT.md`
- `lib/lattice_stripe/error.ex`, `lib/lattice_stripe/checkout/session.ex`, `lib/lattice_stripe/object_types.ex`
- `README.md`, `mix.exs`, `guides/getting-started.md`, `guides/payments.md`, `guides/checkout.md`, `guides/scope.md`
- `test/lattice_stripe/docs_truth_test.exs`, `.github/workflows/ci.yml`
- `prompts/stripe-lib-priority-user-flows-deep-research.md` (vision alignment)
