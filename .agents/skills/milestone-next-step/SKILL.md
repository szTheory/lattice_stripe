---
name: milestone-next-step
description: Assesses this library at a new milestone boundary and preserves the highest-value planning truth. Use when choosing the single highest-leverage next milestone for this project.
---

<objective>
Run a repo-local, adopter-first milestone assessment for this library at a fresh milestone boundary.

Treat the library as a product for serious Phoenix/Elixir adopters, not as a phase counter or generic code-review target.

The output must answer:
- how close the library is to "done enough" for its intended scope
- which single next milestone has the highest leverage
- which few wedges should follow after that
- what planning truth should be preserved so the next milestone starts informed
</objective>

<quick_start>
When invoked:

1. Read planning truth first:
   - `.planning/PROJECT.md`
   - `.planning/ROADMAP.md`
   - `.planning/REQUIREMENTS.md`
   - `.planning/STATE.md`
   - `.planning/MILESTONES.md`
   - `.planning/JTBD-MAP.md`
   - relevant `.planning/milestones/*`
   - relevant `.planning/threads/*`

2. Read adopter-facing truth:
   - `README.md`
   - a small set of key guides
   - relevant `prompts/*` research

3. Read enough `lib/` and `test/` to separate shipped reality from planning/doc claims.

4. Rank the top remaining wedges, recommend one next milestone, update planning truth, then stop.
</quick_start>

<process>
Use these rules every time:

- Prefer repo-local truth over milestone names, summaries, or old assumptions.
- Separate:
  - already built but under-documented
  - genuinely missing code surface
  - narrow follow-through work
  - adjacent overbuilding
- Use an adopter lens:
  - install path
  - onboarding clarity
  - flagship JTBD coverage
  - operator/admin/diagnostic truth where relevant
  - proof honesty
- Respect scope boundaries:
  - LatticeStripe owns Stripe-shaped SDK coverage, primitives, verification helpers, and bounded recipes
  - app workflow orchestration, entitlement logic, dunning policy, and billing-engine behavior belong elsewhere
- Prefer parallel exploration when comparing candidate wedges.

Assessment flow:

1. Explain what the library appears to be and note any confidence caveats from planning/docs drift.
2. Summarize the current adopter story:
   - one-line job
   - what is clearly real today
   - who it already serves well
   - where it still feels rough or under-explained
3. Estimate done-% using product judgment, not phase counts.
   Use these bands:
   - `90-95%` near-done / diminishing returns soon
   - `80-89%` strong, meaningful wedges remain
   - `70-79%` credible and useful, important adopter gaps
   - `<70%` still missing foundational expectations
4. Research the serious candidate wedges and rank the top 3-5.
   For each candidate:
   - why it matters
   - why it is coherent with the repo's vision
   - the "done enough" bar
   - what would make it overbuilding
5. Pick the single highest-leverage next milestone and suggest the ordering after it.
6. Give a blunt maintainer takeaway.

Bookkeeping rules:

- Update `.planning/STATE.md` with the current position, key decisions, and blockers/concerns from this assessment.
- Update `.planning/PROJECT.md` only if milestone-selection decisions, non-goals, or near-done posture changed.
- Refresh relevant `.planning/threads/*` with genuinely new cross-session context.
- Add lessons only when there is a real existing home and the lesson is new.
- Do not invent feature code, do not start the milestone, and do not duplicate existing planning truth verbatim.

Shift-left rules:

- Prefer safe project-local defaults only.
- Good candidates:
  - research-enabled workflows
  - text-mode compatibility for this runtime
  - reusable project-local skill entrypoints
- Do not silently disable verification, plan-checking, or other quality gates.
</process>

<success_criteria>
This skill is complete when it:
- identifies the library's real shipped adopter story from source/tests/docs
- recommends one next milestone with clear ordering after it
- records only genuinely new planning truth in `.planning/`
- avoids scope bleed and breadth-first busywork
- stops after assessment, bookkeeping, and safe shift-left updates
</success_criteria>
