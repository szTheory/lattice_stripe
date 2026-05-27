# v1.8 Next-Milestone Assessment

Updated: 2026-05-27 (refreshed with parallel repo-truth pass)

## Why this thread exists

After v1.7 Polish & Operator shipped and archived (2026-05-27), a fresh adopter-first assessment was run before defining the next milestone to (a) re-check how close LatticeStripe is to "done enough" for its intended v1.x SDK scope, (b) confirm the single highest-leverage next milestone, and (c) retain research so `/gsd-new-milestone` starts informed.

This thread captures durable findings, the v1.8 recommendation, and planning-truth corrections discovered by repo inspection (not milestone names alone).

## Done estimate

**~92–94%** (band: 90–95% near-done / diminishing returns soon)

| Rubric dimension | Score | Notes |
|---|---|---|
| Core JTBD coverage | ~95% | 152 lib modules, 48 ObjectTypes, 38 integration test files, 157 test files total |
| Breadth vs category expectations | ~90% | Mainstream SaaS flows covered; specialist families correctly deferred |
| Docs / onboarding / install | ~86% | 33 guides, 4 flagship recipes; getting-started prose drift; **payments.md API example bugs** (fresh find) |
| Operator / diagnostic posture | ~90% | production-checklist + event-debugging shipped; Charge update/capture not in operator doc route |
| Proof / CI honesty | ~91% | Mox-at-Transport chains, stripe-mock, docs-truth; **CI paths-ignore skips docs_truth on guide-only PRs**; untracked tax proof files |

## Repo-truth findings (verified by lib/ scan, not planning docs alone)

### Shipped surface (post-v1.7)

- ~179 `.ex` files / ~41 HTTP resource modules under `lib/lattice_stripe/`, 48 ObjectTypes entries, 38 integration test files.
- Full Charge surface: `list`, `search`, `update`, `capture` in `lib/lattice_stripe/charge.ex` (not retrieve-only).
- Tax core, thin-event webhooks, operator guides, Hex 1.7.0 install truth on seven `@install_surfaces`.
- v1.x stop signal published in README, `guides/scope.md`, PROJECT.md, CHANGELOG.

### Remaining gaps (verified)

**Doc-routing polish only — not foundational code:**

1. **`guides/getting-started.md` lines 20–21** — prose claims `1.3.x` is current published Hex surface while install snippet says `~> 1.7`. Not locked by `docs_truth_test.exs` (README refute only).
2. **JTBD-MAP was stale** — still listed Charge as retrieve-only and operator guides as missing despite v1.7 shipping both. Refreshed in this assessment pass.
3. **Charge doc routing** — `guides/payments.md` does not route list/search/update/capture; operator guides document list/search only (v1.7 audit CHRG-03/04/05).
4. **Cosmetic planning drift** — MILESTONES.md v1.7 header and RETROSPECTIVE historical bullets reference pre-publish state.
5. **`guides/payments.md` canonical guide bugs** (fresh repo-truth pass) — copy-paste errors not previously tracked as REQ gaps:
   - L89–101: `confirmed.status` matched against strings (`"succeeded"`, `"requires_action"`) but SDK atomizes statuses (`:succeeded`, `:requires_action`)
   - L197: stream filter uses `"succeeded"` instead of `:succeeded`
   - L208–213: `PaymentIntent.search/3` documented as `search(client, map)` but actual API is `search(client, query_string, opts \\ [])`
6. **CI honesty gap** — `.github/workflows/ci.yml` `paths-ignore` on `**.md` and `guides/**` means `docs_truth_test.exs` does not run on guide-only PRs.
7. **Untracked proof files** — `test/integration/tax_id_integration_test.exs` and `test/lattice_stripe/tax/adoption_contract_test.exs` exist locally but are untracked; CI may reference adoption contract gates.

**Not a gap (documented by design):**

- `ObjectTypes.fetch_module/1` returns `:error` for `v2.core.*` types — `fetch_related_object/3` fail-fast per Phase 47 D-05; documented in thin-events and event-debugging guides.

### NOT shipped (correctly deferred)

- Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, Reporting.
- Tax narrow follow-ups TAX-01 (tax_codes), TAX-02 (transaction list) — adopter pull only.

## Wedge analysis

### Wedge A — v1.8 Adopter Truth & Doc Routing Polish (SELECTED)

**Why:** Closes v1.7 audit tech debt; prevents re-deriving already-shipped gaps from stale JTBD-MAP; fixes last adopter-facing onboard prose lie.

**Done enough:**

- getting-started prose matches 1.7.0 + docs_truth lock on release-status prose
- JTBD-MAP reflects post-v1.7 reality (this pass)
- Charge reconciliation routed in payments guide + operator guides mention update/capture
- `guides/payments.md` API examples corrected (status atoms, search arity)
- MILESTONES.md / RETROSPECTIVE cosmetic fixes
- docs_truth extended for release-status prose + canonical guide API examples

**Overbuilding line:** No new code modules, no new Stripe families, no new flagship recipes.

**Scope:** ~2–3 phases, ~1 day.

### Wedge B — Maintenance-only (honest alternative)

Bugfixes + Stripe API drift only; getting-started + JTBD-MAP as `/gsd-quick` tasks. Risk: unstructured doc debt persists.

### Wedge C — Specialist Stripe families

Only on documented adopter pull (Accrue or external). Violates v1.x stop signal without pull.

### Wedge D — Tax narrow (TAX-01/02)

Low adopter pull; defer.

### Wedge E — Narrative docs for under-documented shipped surfaces

Product/Price, BillingPortal config, disputes deep playbooks — diminishing returns.

## Recommended ordering

1. **v1.8 — Adopter Truth & Doc Routing Polish** ← SELECTED
2. **Maintenance mode** — bugfixes, Stripe API drift, adopter-driven narrow additions
3. **Specialist families** — only on adopter pull (likely v2.0 or scoped v1.x point release)
4. **Tax narrow / long-tail narrative docs** — adopter pull or opportunistic only

## Why v1.8 is the right pick (post-v1.7)

- Library is declared done for v1.x scope at Hex 1.7.0 — no code breadth wedge remains.
- JTBD-MAP lag caused false "Charge retrieve-only" and "operator guides missing" signals — proven failure mode for milestone planning.
- getting-started prose is the one remaining adopter-facing install/onboard inconsistency.
- v1.7 audit tech debt is non-blocking but cheap to close (~1 day).

## Graduation candidates

- **Refresh JTBD-MAP at every milestone close, not just milestone start** — v1.7 shipped but map still described pre-v1.7 gaps until this assessment.
- **docs_truth must cover release-status prose, not just install pins** — getting-started install snippet correct while prose lied about 1.3.x.
- **docs_truth must cover canonical guide API examples, not just install pins and cross-links** — payments.md status/search bugs survived because body content is unlocked.
- **CI must run docs_truth when guides change** — paths-ignore on `guides/**` bypasses unit CI on the highest-risk edit surface.
- **Post-stop-signal milestones should be doc-routing polish, not API breadth** — unless adopter pull documents otherwise.
- **Verify untracked proof files at milestone assessment** — adoption contract / integration tests may exist locally but not be on branch.

## Decision fork (for `/gsd-new-milestone`)

Choose one when starting the next milestone:

1. **v1.8 Adopter Truth Polish** — structured milestone (~2–3 phases) — recommended
2. **Maintenance-only** — quick tasks for getting-started + doc routing only
3. **Specialist breadth** — only with named adopter pull

## Files consulted

- `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/MILESTONES.md`, `.planning/JTBD-MAP.md`
- `.planning/threads/v1-7-next-milestone-assessment.md`, `.planning/milestones/v1.7-MILESTONE-AUDIT.md`
- `lib/lattice_stripe/charge.ex`, `lib/lattice_stripe/object_types.ex`, `lib/lattice_stripe/webhook.ex`, `lib/lattice_stripe/payment_intent.ex`
- `README.md`, `mix.exs`, `guides/getting-started.md`, `guides/payments.md`, `guides/scope.md`, `guides/production-checklist.md`, `guides/event-debugging.md`
- `test/lattice_stripe/docs_truth_test.exs`, integration test inventory, `.github/workflows/ci.yml`
- `prompts/stripe-lib-priority-user-flows-deep-research.md` (vision alignment)
