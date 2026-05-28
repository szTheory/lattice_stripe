# v1.10 Next-Milestone Assessment

Updated: 2026-05-27 (post-v1.9 repo-truth pass)

## Why this thread exists

After v1.9 CI & Doc Honesty shipped and archived (2026-05-27), a fresh adopter-first assessment was run at the new milestone boundary to (a) re-check how close LatticeStripe is to "done enough" for its intended v1.x SDK scope, (b) pick the single highest-leverage next milestone (if any), and (c) retain research so `/gsd-new-milestone` starts informed.

This thread captures durable findings, the recommendation, and planning-truth corrections discovered by parallel repo inspection of `lib/`, `test/`, `guides/`, and `.planning/` — not milestone names alone.

## Done estimate

**~94–96%** (band: 90–95% near-done / diminishing returns soon)

| Rubric dimension | Score | Notes |
|---|---|---|
| Core JTBD coverage | ~95% | ~155 `.ex` files, 48 ObjectTypes, ~44 HTTP resource modules, 40 integration test files |
| Breadth vs category expectations | ~92% | Mainstream SaaS flows covered; specialist families correctly deferred |
| Docs / onboarding / install | ~90% | v1.9 fixed checkout/README/CI-01; **3 concrete doc defects remain** (see below) |
| Operator / diagnostic posture | ~93% | production-checklist + event-debugging + Charge routing (v1.7/v1.8) |
| Proof / CI honesty | ~92% | 26 docs_truth locks in default CI; CI-01 paths-ignore narrowed (Phase 60) |

## Repo-truth findings (verified by lib/ + guides scan, not planning docs alone)

### Shipped surface (post-v1.9)

- ~155 `.ex` files under `lib/`, 48 ObjectTypes entries, mainstream SaaS coverage complete.
- Payments, Billing, Connect, Tax, Checkout, webhooks (snapshot + thin-event parse/fetch), Charge reconciliation, operator guides.
- Hex **1.7.0** published; v1.8–v1.9 were doc-only (no Hex bump — correct).
- v1.x stop signal published in README, `guides/scope.md`, PROJECT.md, CHANGELOG.
- Accrue already consumes downstream.

### Remaining gaps (verified)

**Important-but-narrow — doc defects (not foundational code):**

1. **`guides/payments.md:212-220`** — unclosed Elixir fence; blockquote for Search API note trapped inside code block (copy-paste/render failure).
2. **`guides/customer-portal.md:44`** — stale "Portal configuration is managed via the Stripe Dashboard in v1.1" contradicts shipped `LatticeStripe.BillingPortal.Configuration` CRUD in `lib/lattice_stripe/billing_portal/configuration.ex`.
3. **`guides/user-flows-and-jtbd.md:415-423`** — "Still missing" list partially false post-v1.4 (flagship recipes, dispute/credit-note/quote stubs exist in `guides/recipes.md` and ExDoc Flagship Recipes).

**Gap 2 — narrative thinness (polish, not blocking):**

- Disputes/files: code + recipe stub; no upload → `File.create` → `Dispute.update_evidence` → `submit_evidence` spine.
- Product/Price catalog strategy: snippets only in `guides/subscriptions.md`.
- BillingPortal.Configuration: SDK shipped; guide understates programmatic config.
- Mandate / SetupAttempt: modules exist; no narrative guide.
- README ops bullets (`README.md:128-130`) not in docs reading-order ladder.

**By design (not gaps):**

- v2 thin-event `fetch_related_object/3` returns `{:unknown_object_type, "v2.core.account"}` — Phase 47 D-05 fail-fast; documented in `guides/webhooks-thin-events.md` and `guides/event-debugging.md`.
- TAX-01 (tax_codes), TAX-02 (transaction list) — adopter pull only since v1.6.
- Specialist families (Identity, Treasury, Issuing, Terminal, etc.) — v1.x stop signal.

**Planning hygiene (non-blocking):**

- `54-VERIFICATION.md` still missing (PLAN-01 third carry).

### NOT shipped (correctly deferred)

- Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, Reporting.
- v2.core typed resource modules without adopter pull.
- TaxCode surface without adopter pull.

## Wedge analysis

### Wedge A — Doc defect hotfixes (HIGHEST leverage if acting)

**Why:** Copy-paste failures undermine v1.9 trust wins; payments.md fence is worse than thin narrative.

**Done enough:** Fix fences/claims; docs_truth locks for portal config + payments search section structure.

**Overbuilding line:** Full Gap 2 rewrite in one pass.

**Scope:** ~0.5 day; `/gsd-quick` or Phase 61.

### Wedge B — Gap 2: Disputes + files evidence narrative

**Why:** `prompts/stripe-lib-priority-user-flows-deep-research.md` ranks disputes/evidence high for payments-heavy SaaS; README advertises ops surfaces but docs ladder doesn't route there.

**Done enough:** One guide or expanded recipe with File → Dispute evidence chain; ExDoc/JTBD routing; docs_truth lock.

**Overbuilding line:** Full dispute management product.

**Scope:** ~1 phase, doc-only.

### Wedge C — Maintenance-only (DEFAULT)

**Why:** v1.9 closed last milestone-grade honesty wedge; PROJECT.md and JTBD-MAP declare maintenance.

**Done enough:** `/gsd-quick` for defects; Stripe API drift; adopter-pull code only.

**Overbuilding line:** Structured milestone for every doc nit.

### Wedge D — PLAN-01 hygiene

**Why:** `54-VERIFICATION.md` third carry — bookkeeping only.

**Done enough:** Backfill from Phase 54/55 evidence.

### Wedge E — v2 typed dispatch / Tax narrow / specialist families (LOW)

Only with documented adopter demand. Violates v1.x stop signal without pull.

## Recommended ordering

1. **Maintenance mode** ← DEFAULT
2. **Optional v1.10 — Doc Defects & Disputes Narrative** (~2 doc-only phases) — if structured closure desired
3. **Remaining Gap 2** — Product/Price, BillingPortal deep guide, mandate diagnostics (opportunistic)
4. **PLAN-01** — when convenient
5. **TAX-01/02 or specialist families** — adopter pull only

## Why maintenance is the right default (post-v1.9)

- Library declared done for v1.x scope at Hex 1.7.0; no API breadth wedge remains.
- v1.9 closed checkout/README/CI-01 — the last milestone-grade honesty wedge.
- Remaining work is defects + narrative polish, not missing primitives.
- Risk of overbuilding narratives while Accrue already ships on top.

## Optional structured milestone: v1.10

If user wants one milestone (not maintenance-only):

- **Name:** Doc Defects & Disputes Narrative
- **Phase 1:** Hotfix defects (payments fence, portal claim, user-flows stale section) + docs_truth locks
- **Phase 2:** Disputes/files evidence narrative + ExDoc/JTBD routing
- **No Hex bump** (doc-only, like v1.8/v1.9)

## Graduation candidates

1. **Sibling-guide audit on fix** — fixing one canonical guide should grep sibling guides in same flow (payments fixed → checkout missed in v1.8).
2. **Markdown fence integrity** — docs_truth should detect unclosed ``` in canonical guides.
3. **Adopter JTBD doc sync at milestone close** — `user-flows-and-jtbd.md` "Still missing" must refresh when flagship recipes ship.
4. **README feature bullets ↔ docs ladder routing** — ops surfaces advertised but not in reading order.

## Decision fork (for `/gsd-new-milestone`)

Choose one when starting the next milestone:

1. **Maintenance-only** — `/gsd-quick` for doc defects; no structured milestone — **recommended**
2. **v1.10 Doc Defects & Disputes Narrative** — structured ~2 phases, doc-only
3. **Mostly stop** — respond to issues/PRs only

## MILESTONE NEXT-STEP pass (2026-05-27)

Parallel wedge research confirmed:

- **Wedge A (doc defects):** All three defects real; ~2–3h docs-only; leverage **7/10**. `docs_truth` would **not** catch fence or portal/JTBD inventory drift today.
- **Wedge B (disputes narrative):** `Dispute` + `File` fully shipped (`update_evidence`, `submit_evidence`, `File.create` in integration test); recipe omits `File.create` spine; leverage **7/10** as doc-only phase, ranks below Wedge A for trust.
- **README ops bullets** (Files/Disputes/Mandates) advertised but not in JTBD reading order — routing gap, not missing code.

## Graduation candidates (for future phases / docs_truth)

1. **Markdown fence integrity** — detect unclosed ``` in canonical guides (would have caught payments.md).
2. **Sibling-guide audit on fix** — payments fix in v1.8; checkout missed until v1.9.
3. **Portal Configuration truth lock** — `customer-portal.md` must mention `BillingPortal.Configuration` when claiming how config is managed.
4. **JTBD gap-inventory sync** — denylist stale "still missing" bullets when `recipes.md` / flagship guides ship; require `recipes.md` in Start Here reading order.
5. **README feature bullets ↔ docs ladder** — ops surfaces in README Features should appear in JTBD reading order.

## Files consulted

- `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/MILESTONES.md`, `.planning/JTBD-MAP.md`
- `.planning/threads/v1-9-next-milestone-assessment.md`, `.planning/milestones/v1.9-MILESTONE-AUDIT.md`
- `lib/lattice_stripe/error.ex`, `lib/lattice_stripe/webhook.ex`, `lib/lattice_stripe/billing_portal/configuration.ex`, `lib/lattice_stripe/dispute.ex`, `lib/lattice_stripe/file.ex`
- `README.md`, `mix.exs`, `guides/payments.md`, `guides/checkout.md`, `guides/customer-portal.md`, `guides/user-flows-and-jtbd.md`, `guides/recipes.md`
- `test/lattice_stripe/docs_truth_test.exs`, `test/integration/dispute_integration_test.exs`, `test/integration/file_integration_test.exs`
- `.github/workflows/ci.yml`
- `prompts/stripe-lib-priority-user-flows-deep-research.md`
