# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.8 — Adopter Truth & Doc Routing Polish

**Shipped:** 2026-05-27
**Phases:** 3 (56–58) | **Plans:** 10

### What Was Built

- getting-started 1.7.x release-status blockquote + docs_truth SSOT prose locks (Phase 56)
- payments.md copy-paste fixes + Charge reconciliation section + operator routing (Phase 57)
- JTBD-MAP full post-v1.8 refresh; MILESTONES/RETROSPECTIVE cosmetics; tax proof commit (Phase 58)

### What Worked

- **describe-per-guide docs_truth pattern** — Phase 56 getting-started describe → Phase 57 payments + operator describes; each guide contract isolated
- **JTBD refresh at milestone close** — PROJECT.md Key Decision validated; prevents v1.7-style stale map driving redundant milestones
- **Post-stop milestone = doc polish only** — no new modules; highest leverage after v1.x stop signal

### What Was Inefficient

- **Untracked proof files discovered at assessment** — `adoption_contract_test.exs` + `tax_id_integration_test.exs` existed locally while CI referenced adoption gate; commit deferred to Phase 58 PROOF-01
- **JTBD-MAP lagged two phases** — Gap 1 block contradicted shipped guides through Phase 57; reinforces close-time refresh ritual

### Key Lessons

1. Planning maps must refresh at **close**, not only milestone start
2. CI steps must reference **tracked** files — adoption contract on fresh clone breaks without PROOF-01
3. Doc-only post-stop milestones still need audit-before-archive (v1.7 pattern)

### Cost Observations

- Phases 56–57: 5 plans, single-day; Phase 58: 5 plans, planning + hygiene only
- Git range: `ff8dd13` → `{close_sha}` (fill at close)

---

## Milestone: v1.7 — Polish & Operator

**Shipped:** 2026-05-27
**Phases:** 4 (52–55) | **Plans:** 17

### What Was Built

- **Charge surface expansion** — `LatticeStripe.Charge` list/search/update/capture with PI-first moduledoc, Mox wire tests, stripe-mock integration smokes, and docs-truth four-surface triangulation.
- **Operator guides** — `guides/production-checklist.md` and `guides/event-debugging.md` wired into ExDoc Operations & DX, README hardening route, and JTBD operator route.
- **Release truth capstone** — `@version` 1.7.0, CHANGELOG v1.4–v1.7, lockstep `~> 1.7` install contract, SSOT docs-truth migration, Hex publish at 1.7.0.
- **v1.x stop signal** — Phase `41.1` retired as `accepted-external-verification`; library declared done for v1.x scope in README, `guides/scope.md`, PROJECT.md, CHANGELOG, and ExDoc.

### What Worked

- **Four-phase vertical slice with honest stop signal.** Charge (52) → operator guides (53) → release truth (54) → milestone closure (55) kept each phase independently shippable while building toward the v1.x capstone.
- **Hex publish as stop-milestone capstone.** Folding REL-04 into Phase 54–55 eliminated the adopter truth lag that plagued v1.5/v1.6 closes (code shipped but Hex lagged).
- **Phase 55 gap-closure plans.** Extra plans (55-05, 55-06) for REL-04 reconciliation and close_ready state prevented shipping a milestone with stale planning artifacts.

### What Was Inefficient

- **Partial close artifacts before REL-04 landed.** MILESTONES.md and RETROSPECTIVE.md were written with "pending REL-04" before Hex publish completed — required cleanup at final close.
- **Phase 54 missing VERIFICATION.md.** Release truth was verified via Phase 55 batch verification and live Hex checks, but the formal artifact gap persisted through audit.

### Patterns Established

- **SSOT install contract in docs_truth_test.** Migrated from per-version canaries to a single install contract enforced across seven public surfaces — reusable for future release milestones.
- **Operator guide trilogy:** resource surface → operator playbooks → release truth → stop signal — template for future polish milestones.

### Key Lessons

1. **Stop milestones need release truth as a hard gate.** v1.7's REL-04 requirement prevented the "code shipped, Hex lagging" pattern from repeating.
2. **Retire external-proof phases explicitly.** Phase 41.1 `accepted-external-verification` disposition closed an honest boundary without false completeness claims.
3. **Audit before complete-milestone.** Running `/gsd-audit-milestone` first surfaced doc-routing tech debt without blocking close.

### Cost Observations

- **Timeline:** Single-day milestone (2026-05-27).
- **Source diff:** 138 files, +7527/-538 lines.
- **Notable:** Fourth consecutive single-day milestone (v1.4–v1.7) — pre-locked scope and established execution patterns sustain velocity.

---

## Milestone: v1.6 — Tax

**Shipped:** 2026-05-27
**Phases:** 3 (49, 50, 51) | **Plans:** 9

### What Was Built

- **Tax Calculation & Transaction core** — `Tax.Calculation` and `Tax.Transaction` with nested structs, explicit verbs, moduledocs on 90-day expiry and `Invoice.AutomaticTax` boundary, and chained Mox-at-Transport integration spec (`calculation_transaction_test.exs`).
- **Tax Settings singleton + Registration CRUDL** — first singleton resource pattern (`Tax.Settings` on `/v1/tax/settings`) plus jurisdiction registration management with authority disclaimer moduledocs.
- **TaxId dual-path surface** — guard-disambiguated `LatticeStripe.TaxId` covering top-level and customer-nested Stripe paths, PII-redacted `Inspect`, `tax_id` ObjectTypes dispatch.
- **Adoption surface** — public Testing fixtures for all five Tax object types, `guides/tax.md` (351 lines), ExDoc + JTBD discovery wiring, docs-truth grep locks on Tax moduledocs and guide content.

### What Worked

- **Three-phase vertical slice decomposition.** Calculation/Transaction core (49) → Settings/Registration (50) → TaxId + adoption (51) kept each phase independently shippable while building toward a complete Tax family.
- **Singleton pattern landed cleanly in Phase 50.** `Tax.Settings` established the first singleton resource pattern without polluting the CRUDL conventions used elsewhere.
- **Guard-based arity routing for TaxId.** Single top-level module with dual-path routing avoided duplicating Customer-scoped vs top-level modules — decision locked in Phase 51 discuss.
- **Accrue fence in the canonical guide.** `guides/tax.md` documents SDK primitives only; filing orchestration stays downstream — scope discipline held through three phases.

### What Was Inefficient

- **Milestone audit ran after archive close.** `v1.6-MILESTONE-AUDIT.md` landed retroactively (passed, 20/20 requirements, 0 critical gaps). Close order should run `/gsd-audit-milestone` before `/gsd-complete-milestone` to keep MILESTONES.md and RETROSPECTIVE accurate on first commit.
- **`mix.exs` version still pinned at 1.3.0.** Tax code is merged and tested; Hex publish remains out-of-band — same posture as v1.5 close.

### Patterns Established

- **Singleton resources:** `Tax.Settings` pattern (`retrieve/2`, `update/3`, no ID param) is the template for future Stripe singletons.
- **Dual-path arity routing:** Guard-disambiguated function heads for resources with multiple Stripe URL shapes (TaxId top-level vs customer-nested).
- **Tax family adoption trilogy:** resource modules → Testing fixtures + ObjectTypes proof → canonical guide + docs-truth — reusable for future Stripe families.

### Key Lessons

1. **Largest remaining Stripe family shipped in one day.** v1.6 matched v1.5's single-day velocity (83 files, +6988 lines) because phases were pre-scoped in the milestone roadmap and discuss-phase locked TaxId placement early.
2. **Scope fence once in the guide, not in every moduledoc.** Accrue boundary is stated in `guides/tax.md`; moduledocs link to the guide rather than repeating the fence — keeps module docs focused on API semantics.
3. **Integration spec after resource modules, not during.** Phase 49 plan 03 chained Mox spec landed after Calculation + Transaction modules were stable — correct ordering for calc→txn proof.

### Cost Observations

- **Timeline:** Single-day milestone (2026-05-27).
- **Notable:** Third consecutive single-day milestone (v1.4, v1.5, v1.6) — adoption-closure and wedge milestones benefit from pre-locked scope and established execution patterns.

---

## Milestone: v1.5 — Thin-Event Webhooks

**Shipped:** 2026-05-27
**Phases:** 2 (47, 48) | **Plans:** 11

### What Was Built

- **Thin-event SDK surface** — `Webhook.parse_event_notification/4` (+ bang variant) verifies signatures and returns typed `EventNotification` structs exposing `id`, `type`, `created`, `context`, and a `related_object` reference, reusing the same error atoms as `construct_event/3`.
- **Typed fetch-after-verify helpers** — `Webhook.fetch_event/2,3` (`/v2/core/events/{id}`) and `Webhook.fetch_related_object/2,3` returning typed resources via the existing `ObjectTypes` registry — no new dispatch table introduced.
- **`Event.t()` extension + new structs** — net-new `EventNotification` and `EventNotification.RelatedObject` modules with custom `Inspect` impls (defensive against credential-shape leakage); `Event.related_object` field added; `ObjectTypes.fetch_module/1` typed-gate accessor.
- **`tolerance: 0` four-surface reconciliation (WEBFIX-01)** — docstring at `webhook.ex:84`, code clause at `:268-273`, `Webhook.Plug` NimbleOptions schema (`:pos_integer` → `:non_neg_integer`), tests, CHANGELOG entry, and docs-truth grep regression all reconciled in one plan. `tolerance: 0` now disables the staleness check as the docstring promised — matching stripe-node, stripe-go, and stripe-ruby behavior.
- **Canonical Phoenix guide** — `guides/webhooks-thin-events.md` (199 lines) teaching controller spine → verify → fetch-after-verify → idempotent dispatch keyed on `event.id`, with rate-limit guidance (<90/s under Stripe's 100 req/s ceiling), Connect/context-aware routing, and the verification-vs-payload-shape failure boundary. Wired into ExDoc `Operations & DX`, README hardening-ops route, `guides/webhooks.md` closing section, and JTBD Start Here Runtime route + Job 7 Read next.
- **`LatticeStripe.Testing` thin-event helpers** — `generate_thin_event_payload/3` (signed wire payload + matching `Stripe-Signature` header) and `event_notification/1` (typed builder); snapshot helpers backwards-compatible.
- **Integration coverage** — `test/lattice_stripe/webhook/thin_event_test.exs` (211 lines, 9 tests) chained Mox-at-Transport suite covering happy-path, fetch-after-verify roundtrip, malformed-payload boundary, and `tolerance: 0` reconciliation.
- **Docs-truth contract extended** — five new grep blocks (3A guide content, 3B `~> 1.5` install canary, 3C ExDoc placement, 3D cross-link graph, 3E Plug `@moduledoc` `tolerance: 0` testing-only). Docs-truth suite now 12 tests, 0 failures.

### What Worked

- **Verifying shipped surface against `lib/` source before milestone kickoff.** The v1.5 assessment found two real code-truth gaps that the v1.4 close had not surfaced: (a) the `tolerance: 0` docstring/code disagreement and (b) the unusually thin `Charge` surface. Planning artifacts alone would not have caught these — the rule "verify shipped surface against `lib/` source before every new milestone" earned its place in PROJECT.md Key Decisions.
- **Four-surface triangulation for the security-adjacent bug fix.** WEBFIX-01 reconciled `tolerance: 0` across docstring, code clause, Plug schema, and tests — plus CHANGELOG entry + docs-truth grep regression — rather than fixing one surface and leaving drift seams. This pattern is reusable for any future security-adjacent fix touching public docs + code + config schema.
- **Treating docstring/code drift as a code bug, not a docs-fix.** WEBFIX-01 chose to fix the code clause to match the docstring (and every canonical Stripe SDK) instead of the easier path of changing the docstring to match the code. Locked the decision against future "fix it to be stricter" drift via a docs-truth grep regression on the CHANGELOG entry.
- **Reusing the existing `ObjectTypes` dispatch table.** `Webhook.fetch_related_object/2,3` typed-dispatches through the registry already used elsewhere in the SDK. Resisting the "new dispatch table" temptation kept v1.5 surface narrow and made the fetcher immediately benefit from `ObjectTypes` typed deserialization.
- **Chained Mox-at-Transport integration suite for the new surface.** `thin_event_test.exs` runs parse → fetch → verify as one chained flow per test, with `verify_on_exit!` ensuring zero unexpected HTTP. Mirrors the integration-first proof posture validated across prior milestones.

### What Was Inefficient

- **Phase 48 VALIDATION.md left `nyquist_compliant: false` and `wave_0_complete: false`.** The per-task verify map carries a placeholder row (`48-XX-YY`) rather than per-task expansion. Tests are green (9 in `thin_event_test.exs` + 12 in `docs_truth_test.exs`, plus the full 2004-test suite), so this is administrative debt — but it broke milestone-level Nyquist parity (47 compliant, 48 partial). `/gsd:validate-phase 48` would close it.
- **`thin_event_test.exs` skipped two typed-error paths.** `{:error, :no_related_object}` and `{:error, {:unknown_object_type, type}}` are covered by Phase 47's `webhook/fetch_test.exs` unit tests but not exercised in the Phase 48 integration suite. Not a regression risk; the gap is integration-level redundancy missing.
- **Bang variants (`parse_event_notification!/4`, `fetch_event!/3`, `fetch_related_object!/3`) covered only by Phase 47 unit tests.** Not exercised in `thin_event_test.exs` or referenced in the canonical guide. Tagged-tuple style is taught exclusively in user-facing docs, which is fine — but the bang surface should have at least one integration-level test for symmetry.
- **`LatticeStripe.Testing.event_notification/1` exported but not referenced in the guide or `thin_event_test.exs`.** The 0-arity fixture import IS used (line 131 of `thin_event_test.exs`); the typed builder is reachable via that fixture path. Exported helper without canonical-guide demonstration is a docs gap that should be closed when the helper sees first downstream use.
- **WR-03 hard-coded `created` in snapshot `generate_webhook_payload/3`.** Testing-only inconsistency — the helper uses `System.system_time(:second)` instead of the `:timestamp` opt. Found in Phase 47 review, deferred as non-blocking. Small follow-up patch.

### Patterns Established

- **Four-surface triangulation for security-adjacent fixes.** When fixing a bug that touches behavior surfaced through docs + code + config + tests, reconcile *all four surfaces in the same plan* and add a docs-truth grep regression on the CHANGELOG entry. Documented as a Key Decision; applies directly to v1.7 `Charge` surface work (where `list/3`/`search/3`/`capture/4`/`update/4` need docstring + code + tests + CHANGELOG triangulation).
- **Source-truth check before milestone kickoff.** Grep `lib/` for the planned surface area before locking the milestone roadmap — planning artifacts can be coherent and still miss code-truth gaps. New rule in PROJECT.md Key Decisions.
- **Reuse existing dispatch tables instead of growing new ones.** `ObjectTypes` registry served the thin-event fetcher; resisting a new table kept v1.5 narrow and made the new surface inherit typed deserialization for free.
- **Verify-then-decode for new typed surfaces.** `parse_event_notification/4` follows the exact `construct_event/4` pattern (verify-then-decode, telemetry span reuse, public `{:ok, t()} | {:error, reason}` + bang variant). Pattern is the canonical shape for any future signed-payload entry point.

### Key Lessons

1. **Source-truth verification beats planning-doc coherence.** v1.5 caught two real gaps (`tolerance: 0` bug, thin `Charge` surface) that four prior milestones of planning review missed. The rule now codified: read `lib/` against the planned roadmap before locking the milestone.
2. **Fix the code, not the docstring, when public-API drift exists.** WEBFIX-01 chose the harder path (fix code clause) over the easier path (change docstring). Result: behavior now matches every canonical Stripe SDK and the more useful semantics. Lock the decision in CHANGELOG + docs-truth grep so it can't drift back.
3. **Single-day milestones are viable when the wedge is narrow and well-researched.** v1.5 shipped 2 phases / 11 plans / 21 source files / +2343 lines in ~6 hours on 2026-05-27. The dossier (`v1-5-next-milestone-assessment.md`, `thin-event-webhook-evaluation.md`) pre-locked the API shape and reference SDK before phase 47 kicked off — that pre-work compressed the execution loop dramatically.
4. **Audit-passed-with-tech-debt is a legitimate close posture.** v1.5 audit returned `passed` with 9 tech-debt items (WR-01..05, IN-01..04, Phase 48 VALIDATION placeholder). None are blockers; all are classified at audit time. Don't conflate "audit passed" with "no follow-up work" — explicitly carry tech debt forward.

### Cost Observations

- **Sessions:** Single session for milestone execution and close (this turn-set).
- **Phase model mix:** Sonnet for integration-checker; main session Opus 4.7 1M.
- **Notable:** v1.5 shipped in ~6 hours single-day — fastest milestone by wall-clock time to date. Heavy upfront research (the v1.5 assessment + thin-event evaluation dossier landed before milestone kickoff) compressed execution. Pre-locked API shape made the plan-phase loops faster.

---

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
| v1.5 | 2 | 11 | Thin-Event Webhooks: net-new `parse_event_notification`/`fetch_event`/`fetch_related_object` surface, `tolerance: 0` four-surface reconciliation (WEBFIX-01), canonical Phoenix guide, integration + docs-truth coverage. Fastest milestone by wall-clock (~6 hours single-day). Source-truth verification rule codified |
| v1.8 | 3 | 10 | Adopter truth & doc routing polish: describe-per-guide docs_truth, Charge reconciliation routing, planning-truth close at milestone end |

### Top Lessons (Verified Across Milestones)

1. **Preserve accepted gaps honestly rather than flattening them.** v1.3 accepted Phase 41.1 explicitly; v1.4 carried that forward in the audit and milestone close. Both refused to claim full close when an external-proof boundary remained.
2. **Docs and tests both need to assert truth.** v1.4 found that a green narrow `docs_truth_test` had been hiding `~> 1.2` drift in `getting-started.md`. The fix was broader assertion coverage, not abandoning the test — the same pattern applies to API drift detection added in v1.2.
3. **Recipes should stitch shipped primitives, not become app workflows.** Both v1.3 (Phoenix webhook recipe, fixture builders) and v1.4 (four flagship guides) held the line against drifting into billing-engine abstractions or Accrue territory. Library-scoped guidance keeps the SDK boundary clear.
4. **Behaviour-based extensibility plus integration-first proof scales.** Carrying `Transport`/`RetryStrategy`/`Json` behaviours through five milestones, plus integration tests as the default evidence form, kept the SDK from accumulating mock/prod divergence.
5. **Source-truth verification before milestone scope-lock.** v1.5 codified what prior milestones did informally — grep `lib/` against the planned roadmap before locking. Caught the `tolerance: 0` bug and thin `Charge` surface that planning-doc review had missed for four milestones.
6. **Reuse existing dispatch tables rather than growing new ones.** v1.5 `Webhook.fetch_related_object/2,3` typed-dispatched via the `ObjectTypes` registry already used elsewhere. Same pattern that kept v1.2 expand wiring narrow. Resisting "new table" temptation keeps the SDK surface coherent.
7. **Fold Hex release into stop milestone — out-of-band publish creates adopter truth lag.** v1.7 assessment (2026-05-27): `mix.exs` stayed at 1.3.0 through v1.5/v1.6 code milestones while README/getting-started locked `~> 1.3`. Install truth became the top adopter friction, not missing Stripe families. Stop milestones must include version bump, CHANGELOG, lockstep docs-truth flip, and Hex publish as capstone work.
