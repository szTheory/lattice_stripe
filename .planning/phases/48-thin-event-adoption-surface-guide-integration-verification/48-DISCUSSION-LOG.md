# Phase 48 Discussion Log

**Date:** 2026-05-27
**Phase:** 48 — Thin-Event Adoption Surface — Guide & Integration Verification

## Prior context loaded

- `.planning/PROJECT.md`, `.planning/ROADMAP.md` (Phase 48 entry), `.planning/REQUIREMENTS.md` (GUIDE-03, VERIFY-03)
- `.planning/STATE.md` — current focus Phase 48, milestone v1.5
- `.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/` — full CONTEXT, VERIFICATION (with WR-04 deferred to Phase 48), REVIEW, 5 SUMMARYs
- `.planning/milestones/v1.4-phases/44-guide-discovery-support-truth/44-CONTEXT.md` — Phase 44 D-01..D-18 (docs architecture, layered ExDoc groups, surface-first + task-first routing, inline truth)
- `.planning/milestones/v1.4-phases/45-flagship-recipes-i/45-CONTEXT.md` — Phase 45 D-01..D-27 (workflow-playbook scale, one-recommended-path, library-scoped, tone discipline)
- `.planning/threads/thin-event-webhook-evaluation.md` — locked v1.5 surface, rate-limit + idempotency directives
- `.planning/threads/v1-5-next-milestone-assessment.md` §Wedge A — canonical docs scope
- `test/lattice_stripe/docs_truth_test.exs` (186 lines, 8 tests) — existing docs-truth surface
- `test/lattice_stripe/webhook/fetch_test.exs` (378 lines) — Mox-at-Transport template
- `test/integration/stripe_explorer_notebook_integration_test.exs` + `test/support/stripe_explorer_harness.ex:157-165` — `meter_event_stream_boundary` pattern; stripe-mock `/v2/` boundary signal
- `guides/webhooks.md` (216 lines) — canonical webhook trust rail (sibling structure)
- `guides/checkout-signup-and-portal.md` + `metering-runtime-and-reconciliation.md` etc. — Flagship Recipe scale reference points
- `mix.exs:54-96` `groups_for_extras` — Operations & DX is the locked group target
- `README.md` (current "Choose Your Route" + "What's already in the box" structure)
- `guides/user-flows-and-jtbd.md` (7-Job JTBD ladder)
- `prompts/` corpus (elixir/phoenix/stripe-sdk best practices, surface area research, domain language)

## Anti-pattern check

No `.continue-here.md` found in phase directory. No blocking anti-patterns surfaced.

## Gray areas presented

| Area | Selected? |
|---|---|
| Guide shape, depth & ExDoc placement | Yes |
| Integration test strategy | Yes |
| Docs-truth regression scope | Yes |
| Discovery wiring (README + JTBD) | Yes |

Explicitly auto-folded (not a gray area, pre-decided by Phase 47 VERIFICATION's `deferred` block):
- WR-04 Plug `@moduledoc` `tolerance: 0` mention + grep test — folded into Area 3 docs-truth scope per D-03 sub-decision 3E.

## Area 1 — Guide shape, depth & ExDoc placement

**Options presented (with full ecosystem research + tradeoffs):**
- **A.** Flagship workflow playbook (~200–240 lines, Flagship Recipes group, sibling to checkout-signup-and-portal.md)
- **B.** Canonical surface guide (~200–230 lines, Canonical Guides group, sibling to subscriptions.md/metering.md)
- **C.** Short canonical Operations & DX sibling (~140–180 lines, Operations & DX group, sibling to webhooks.md) — **Recommended**

**User selection:** C (Recommended).

**Captured as D-01.**

Reasoning anchored to:
- Phase 44 D-06 webhook elevation + family coherence (avoid two webhook guides fighting for the same evaluator attention)
- Phase 47 D-08 lock (`Webhook.Plug` snapshot mode unchanged; adopters wire their own Phoenix controller — thin guide just teaches the diff)
- Phase 45 D-04 library-scoped + primitive-first posture (avoid workflow-playbook drift into Accrue territory)
- Cross-SDK consistency (stripe-node, stripe-go, stripe-ruby all document thin events as a sibling story, not a separate workflow playbook)
- Length calibration matching Operations & DX siblings (webhooks.md is 216 lines)

## Area 2 — Integration test strategy

**Options presented (with full ecosystem research + tradeoffs):**
- **S1.** Mox-based roundtrip suite at `test/lattice_stripe/webhook/thin_event_test.exs` (async, Mox at Transport, no new deps) — **Initial recommendation**
- **S2.** Bypass-based full-HTTP roundtrip (adds `{:bypass, "~> 2.1", only: :test}`; conflicts with CLAUDE.md "What NOT to Use")
- **S3.** stripe-mock `/v2/` boundary documentation test (mirrors `meter_event_stream_boundary` pattern in `test/integration/`)
- **S4.** Hybrid Mox roundtrip + stripe-mock boundary doc
- **S5.** Hybrid Bypass + stripe-mock boundary doc

**User feedback:** Requested deep ecosystem research via subagents before committing — best practices, cross-language Stripe SDK precedent, Elixir OSS HTTP client patterns, DX dimension, anti-patterns/footguns, CLAUDE.md prior weight.

**Subagent research executed.** Key findings:
- CLAUDE.md "What NOT to Use" explicitly excludes Bypass (S2/S5 violate locked prior)
- Every mature Stripe SDK (stripe-node nock, stripe-go httptest fixtures, stripe-java MockWebServer, stripe-python monkey-patch, stripe-ruby webmock+fixtures) tests thin-event helpers at the client-fetch boundary with fixtures — none use a real HTTP server
- stripe-ruby's `vcr` cassette era is the public cautionary tale they migrated away from
- Stripity Stripe (Bypass-based) is the in-ecosystem case study CLAUDE.md is reacting against
- The existing `test/lattice_stripe/billing/meter_event_stream_integration_test.exs` (`@moduletag :skip`) is dead code / anti-pattern in this repo, NOT a template — sharpens S3/S4 against
- REQUIREMENTS.md VERIFY-03 namespace signal `test/lattice_stripe/webhook*` is decisive (not `test/integration/`)
- Phase 47 already paid for the Mox infrastructure; cross-helper roundtrip is the natural extension

**Revised recommendation:** S1 (Mox-only roundtrip suite, NO boundary doc file). Document stripe-mock `/v2/` gap as one prose line inside `guides/webhooks-thin-events.md` per D-01.

**User selection:** S1 (Mox-only roundtrip, no boundary doc) — Recommended.

**Captured as D-02.**

## Area 3 — Docs-truth regression scope

**Sub-decisions presented:**
- **3A.** New guide content locks (function names, error atoms, rate-limit phrases, `event.id`/`event.context` anchors, canonical truth phrase, `/v2/events`, verification-vs-payload-shape phrase) — Recommended: lock all
- **3B.** Install-version handling — three options:
  - B1. Bundle full `~> 1.3 → ~> 1.5` refresh into Phase 48
  - **B2.** New guide flips to `~> 1.5`, others stay `~> 1.3` (canary effect) — **Recommended**
  - B3. New guide install line stays unversioned
- **3C.** Extend ExDoc placement test to lock `webhooks-thin-events.md` in Operations & DX group — Recommended
- **3D.** Cross-link graph locks (3 forward + 1 reverse) — Recommended
- **3E.** Fold Phase 47 WR-04 Plug `@moduledoc` extension + grep test into this phase — Recommended

**User selection:** All recommended (3A + 3B-B2 + 3C + 3D + 3E).

**Captured as D-03.**

Rationale for B2 (canary install line):
- Phase 44 D-10 honesty-rule preserved (until 1.5.0 is on Hex, claiming `~> 1.5` everywhere violates "explicit inline honesty at the point of use")
- New guide is 1.5-only content, so its `~> 1.5` snippet is honest about this guide's scope
- Avoids coupling Phase 48 to v1.5 release sequencing
- Natural canary: once shipped, the v1.5 release task fails CI on existing docs-truth assertions until they're flipped — enforces lockstep release without coupling that flip to Phase 48

## Area 4 — Discovery wiring (README + JTBD)

**Options presented (with full ecosystem research + tradeoffs):**
- **S1.** Tail callout in webhooks.md only, no README/JTBD changes
- **S2.** Sub-bullet under existing hardening-ops route + extend webhooks.md closing section + JTBD Job 7 `Read next` — **Recommended**
- **S3.** New JTBD Job 8 "Modernize to thin-event webhooks" (peer rank)
- **S4.** Pair-with + "What's new in v1.5" README "Release status" flip (couples to release prep)

**User selection:** S2 (Recommended).

**Captured as D-04.**

Reasoning anchored to:
- Phase 44 D-08 scope discipline (JTBD stays a compact bridge, not a peer-rank cookbook)
- Thin events are a hardening / runtime-truth concern, not a new job — same job as snapshot webhooks at the adopter-mental-model level
- Phase 44 D-06 webhook elevation preserved (webhooks.md stays canonical; thin-events is v2 branch)
- Avoids the v1.5 "Release status" block flip from D-03 sub-decision 3B canary handling (Phase 48 doesn't touch the v1.3-locked Release status block)
- Discoverability is good-enough via the README hardening-ops route + JTBD Job 7 `Read next` cluster; reverse link from `webhooks.md` is the highest-ROI discovery hook

## Scope creep redirected

None observed in this session. User stayed focused on Phase 48 boundaries throughout. Phase 45-style workflow-playbook scope tempting but explicitly evaluated and rejected for thin-events in Area 1 — captured as a real architectural decision, not creep.

## Deferred ideas captured

See `48-CONTEXT.md` `<deferred>` section. Summary of new deferrals from this discussion:
- Install-line refresh from `~> 1.3` → `~> 1.5` across non-Phase-48 guides (defer to v1.5 release prep)
- README "Release status" block flip (defer to v1.5 release prep)
- `Webhook.Handler` thin-event callback parallel (Phase 47 D-08 deferral preserved)
- Thin-event-aware `Webhook.Plug` dispatch mode (Phase 47 D-08 deferral preserved)
- WR-02, WR-03, WR-05 helper-API hardening (Phase 47 REVIEW deferrals preserved; not Phase 48 docs+tests scope)
- Bypass-based real-HTTP integration tier (D-02 explicit rejection; reconsider only if Finch-pipeline regression evidence emerges)
- `@moduletag :integration` stripe-mock `/v2/` boundary-doc file (D-02 explicit rejection)
- JTBD Job 8 "Modernize to thin-event webhooks" (D-04 explicit rejection — revisit only with adopter-pull evidence)
- Live event tail LiveBook (v1.7 polish candidate per v1-5-next-milestone-assessment thread)

## Claude's Discretion (left to planner/researcher)

- Exact `webhooks-thin-events.md` section ordering, headings, prose framing within D-01 content scope and D-03 phrase locks
- Exact wording of the README "What's already in the box" Webhooks bullet expansion (must surface `thin-event` and `/v2/events`)
- The exact idempotency-table sketch shape in the guide (Ecto schema sketch? bare map dedup? ETS?) — Phoenix-friendly + library-scoped
- Fixture reuse strategy in `thin_event_test.exs` (reuse Phase 47 `test/support/fixtures/event_notification.ex` wherever possible; new fixtures only if a roundtrip case requires)
- Grouping strategy for new docs-truth assertions (one new `describe` vs distributed across existing tests)
- Exact `:tolerance` line wording in `Webhook.Plug` `@moduledoc` extension (47-REVIEW.md:144-148 has a suggested shape; planner may refine)

---

*Phase 48 — context gathering complete. Ready for /gsd:plan-phase 48.*
