# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.4 — Adoption Closure

**Shipped:** 2026-05-27
**Phases:** 4 (43-46) | **Plans:** 8 | **Tasks:** 18

### What Was Built

- **Public truth alignment** — README, CHANGELOG, Getting Started, cheatsheet, mix.exs, HexDocs extras all agree on the shipped `1.3.x` package line; stale `~> 1.2` snippet found and removed.
- **Docs-truth regression coverage** — `test/lattice_stripe/docs_truth_test.exs` grew from README-only checks to 7 tests covering ExDoc metadata, install snippets, route anchors, layered group metadata, and per-flagship-guide content.
- **Discovery ladder** — README route-by-intent → JTBD/recipes routing → canonical guides → flagship recipes, with layered ExDoc groups (`Start Here`, `Canonical Guides`, `Operations & DX`, `Flagship Recipes`).
- **Four flagship recipe guides** — `checkout-signup-and-portal`, `metering-runtime-and-reconciliation`, `connect-platform-flow`, `quote-to-billing-operator`, each published and regression-tested for publication + cross-link presence.
- **Support-truth follow-through** — `See also` / `Read next` links across nine canonical guides linking webhooks ↔ testing ↔ error-handling ↔ subscriptions ↔ portal ↔ metering ↔ connect cluster.
- **Planning truth reconciled** — PROJECT/ROADMAP/REQUIREMENTS/STATE all reflect close-ready posture; Phase 41.1 preserved explicitly as `pending-external-verification`.

### What Worked

- **Docs-truth tests as regression surface.** Phase 43 found `guides/getting-started.md` still on `~> 1.2` even while older narrower README assertions stayed green. Treating docs assertions as first-class CI coverage caught real adopter-facing drift.
- **Webhook-confirmed truth framing in flagship guides.** Distinguishing "accepted by API now" from "confirmed by webhook later" gave the metering and quote guides honest async-billing posture without overclaiming synchronous authority.
- **Layered ExDoc grouping over flat extras list.** Role-based groups (Start Here / Canonical / Operations / Flagship) surfaced the right guide for the right reader rather than burying high-leverage surfaces in a flat alphabetized list.
- **Preserving the Phase 41.1 boundary explicitly through close.** Not flattening an accepted external-proof gap into a false full-close kept the milestone honest and the v1.5 wedge candidates clear-eyed.

### What Was Inefficient

- **Three of four phases shipped without writing VERIFICATION.md.** Only Phase 44 produced the standard artifact during execution; 43, 45, 46 relied on SUMMARY + passing docs-truth tests + (for 46) a UAT. The v1.4 milestone audit had to backfill the verification artifacts post-hoc — bookkeeping debt that should have been resolved phase-by-phase.
- **REQUIREMENTS.md traceability lagged completion.** GUIDE-01, GUIDE-02, VERIFY-02, RECIPE-01, RECIPE-02 stayed `[ ] Pending` in the traceability table even after SUMMARYs marked them complete and docs-truth tests covered them. Status drift between SUMMARY frontmatter and traceability rows is easy to miss.
- **Dirty-worktree execution suppressed per-task commits.** Every phase noted "no task commits because the working tree already contained unrelated modifications." This is fine for docs-only work but means the v1.4 commit history under-represents the actual phase boundaries; everything bundled into `54270e2 feat: publish flagship guides and docs truth updates`.
- **`46-UAT.md` test 1 included `LoginLink` as a required anchor.** The Connect flagship guide doesn't use `LoginLink`, but `rg -c` aggregated total matches across all patterns, so the assertion passed without that pattern ever matching. An inaccurate UAT expectation that snuck through because the aggregation hid the per-pattern result.

### Patterns Established

- **Docs-truth assertions as first-class regression.** `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` should be part of every docs-touching phase's verification command set, not a one-off check.
- **Flagship recipe template:** new flagship guide → published in `mix.exs` Flagship Recipes group → linked from `recipes.md` + `user-flows-and-jtbd.md` → cross-linked from relevant canonical guides → asserted in `docs_truth_test.exs`. Apply to any future workflow guide.
- **Webhook-confirmed truth language in async-billing docs.** "Accepted for processing" / "became true once the webhook arrived" — not "the API returned success so the subscription is provisioned." Use in any docs touching meter events, quotes, subscriptions, or webhook-confirmed lifecycles.
- **Layered ExDoc grouping over flat extras.** Future docs phases should add new guides to the right role-based group (`Start Here` / `Canonical Guides` / `Operations & DX` / `Flagship Recipes`) and update `docs_truth_test.exs` to assert the membership.

### Key Lessons

1. **Documentation milestones need verification discipline too.** Treating v1.4 as "just docs" let three of four phases skip VERIFICATION.md. Docs-only phases still benefit from the standard verification artifact — even if the evidence is `rg`/`mix test` rather than runtime probes.
2. **REQUIREMENTS.md traceability is a separate update step from SUMMARY frontmatter.** Plan execution updates SUMMARY but not the traceability table; the milestone audit caught the drift. Future phases should flip the traceability row in the same commit that marks `requirements-completed` in the SUMMARY.
3. **`rg -c` aggregates across patterns and can mask missing anchors.** UAT and verification commands should split per-pattern assertions or use `rg -l` plus per-pattern grep when checking that *each* required anchor is present.
4. **Audit close-out can be lightweight when the work is sound.** v1.4 audit reported `gaps_found` but the gaps were all bookkeeping (missing VERIFICATION.md, stale checkboxes, non-uniform UAT). One ~500-line cleanup commit closed the audit without re-running phase chains. Pattern: backfill artifacts inline when the underlying work is verified.

### Cost Observations

- **Sessions:** Single session for milestone execution and close (this turn-set).
- **Phase model mix:** Sonnet for integration-checker; main session Opus 4.7 1M.
- **Notable:** v1.4 shipped in 5 commits over ~2 days. Smallest milestone by commit count to date, reflecting its scope as docs-and-truth rather than new SDK code.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 14 | 47 | Initial SDK breadth: transport, retry, pagination, Payments, Checkout, Billing, Connect, webhooks, docs, CI/CD |
| v1.1 | 2 | (small) | Accrue-unblocker mini-milestone: Meter, MeterEvent, BillingPortal.Session |
| v1.2 | 10 | 24 | Production hardening + DX: Configuration CRUDL, per-op timeouts, circuit breaker, OpenTelemetry, drift detection, LiveBook |
| v1.3 | 12 | 26 | Coverage breadth: File/FileLink, Disputes, CreditNote, Mandate, SetupAttempt, Quote + DX follow-through. Phase 41.1 follow-through accepted as `pending-external-verification` |
| v1.4 | 4 | 8 | Adoption Closure: docs/truth/discovery, four flagship recipes, planning-truth reconciliation. First non-code milestone — verification artifact discipline lagged because of it |

### Top Lessons (Verified Across Milestones)

1. **Preserve accepted gaps honestly rather than flattening them.** v1.3 accepted Phase 41.1 explicitly; v1.4 carried that forward in the audit and milestone close. Both refused to claim full close when an external-proof boundary remained.
2. **Docs and tests both need to assert truth.** v1.4 found that a green narrow `docs_truth_test` had been hiding `~> 1.2` drift in `getting-started.md`. The fix was broader assertion coverage, not abandoning the test — the same pattern applies to API drift detection added in v1.2.
3. **Recipes should stitch shipped primitives, not become app workflows.** Both v1.3 (Phoenix webhook recipe, fixture builders) and v1.4 (four flagship guides) held the line against drifting into billing-engine abstractions or Accrue territory. Library-scoped guidance keeps the SDK boundary clear.
4. **Behaviour-based extensibility plus integration-first proof scales.** Carrying `Transport`/`RetryStrategy`/`Json` behaviours through five milestones, plus integration tests as the default evidence form, kept the SDK from accumulating mock/prod divergence.
