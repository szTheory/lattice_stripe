# Phase 55: Milestone Closure & v1.x Stop Signal - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 55-milestone-closure-v1-x-stop-signal
**Areas discussed:** Phase 41.1 retirement, Stop-signal wording, Deferred scope disclosure, Planning sweep scope, Milestone-complete gate

---

## Phase 41.1 retirement

| Option | Description | Selected |
|--------|-------------|----------|
| A — Planning-only flip | Update ROADMAP/STATE/MILESTONES/PROJECT/REQUIREMENTS only | Partial (necessary, not sufficient) |
| B — Restore 41.1 dir + VERIFICATION.md | Git restore + retirement append | ✓ |
| C — Update public quote guide | Add stripe-mock / phase language to guide | |
| D — Preserve sandbox script | Keep `scripts/verify_quote_follow_through.exs` | ✓ |

**User's choice:** Hybrid **B + A + D**, skip **C** (user: "okay i follow ur recs")

**Notes:** Subagent research confirmed 41.1 directory was deleted without milestone archive copy; CLOSE-01 requires directory artifacts. Public guide already satisfies RECIPE-04 without phase IDs. Status vocabulary: `accepted-external-verification` only.

---

## Stop-signal wording and placement

| Option | Description | Selected |
|--------|-------------|----------|
| A — README blockquote extension | Extend existing release-status block | ✓ |
| B — New README Project status section | Separate section | |
| C — Planning-only | PROJECT/MILESTONES only | |
| D — CHANGELOG only | 1.7.0 note carries narrative | |

**User's choice:** **A** + PROJECT.md `## v1.x Status`; CHANGELOG one-liner; public voice "feature-complete for intended scope" + "maintenance and adoption-driven"

**Notes:** Phase 54 explicitly deferred stop signal to Phase 55. Never claim "complete Stripe SDK." Link JTBD + api_stability guides.

---

## Deferred scope disclosure

| Option | Description | Selected |
|--------|-------------|----------|
| A — README short list only | ~8 lines in README | ✓ (part of E) |
| B — Link JTBD-MAP only | Planning artifact link | |
| C — REQUIREMENTS only | Planning depth | ✓ (part of E) |
| D — New guides/scope.md | Canonical public contract | ✓ |
| E — README + REQUIREMENTS hybrid | Public + planning depth | ✓ |

**User's choice:** **E + D** — `guides/scope.md` + README `## v1.x scope`; no JTBD-MAP link from README

**Notes:** Two grouped lists (specialist families vs Tax narrow follow-ups). Tax core v1.6 must not read as incomplete.

---

## Planning-artifact sweep scope

| Option | Description | Selected |
|--------|-------------|----------|
| A — Active four files only | PROJECT/ROADMAP/REQUIREMENTS/STATE | |
| B — Active + MILESTONES footnotes | Living log repairs | ✓ (subset of D) |
| C — Full archive grep sweep | Rewrite all milestones/ | |
| D — Active + v1.7 archive slice | Touch active; freeze v1.0–v1.6 archives | ✓ |

**User's choice:** **D** — Phase 46 D-25 immutability for archived ROADMAPs

---

## Milestone-complete gate

| Option | Description | Selected |
|--------|-------------|----------|
| A — 55 = docs only; complete-milestone separate | Documentary close only | |
| B — 55 marks reqs [x] + close_ready STATE | Close-ready preflight | ✓ |
| C — 55 embeds complete-milestone archive | Single combined phase | |

**User's choice:** **B** — sequence: execute 55 → audit-milestone v1.7 → complete-milestone v1.7; skip new git tag

**Notes:** REL-04 must be verified before [x] on REL-* requirements. Phase 54 prerequisite.

---

## Claude's Discretion

Listed in CONTEXT.md — verifier restore source, scope guide ExDoc group, optional thread superseded header, verification doc numbering.

## Deferred Ideas

- `/gsd-complete-milestone` execution inside Phase 55 plans
- Full archive rewrite for grep cleanliness
- Sandbox re-run as release gate
- Public "Phase 41.1" naming in README/guides
