# Phase 56: Release Truth & Getting Started - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the release-status prose drift in `guides/getting-started.md` so first-run adopters on HexDocs see **`1.7.x`** as the current published line — aligned with the already-correct `~> 1.7` install pin and README release block. Extend `docs_truth_test.exs` with grep locks on release-status prose (TRUTH-02), not just install pins.

**In scope:** `guides/getting-started.md` prose fix; `docs_truth_test.exs` release-truth helpers and assertions; harmonize README release test with same SSOT helpers.

**Out of scope:** payments.md API fixes (Phase 57); CI paths-ignore (deferred); milestone bullets or v1.x stop signal in getting-started; git dependency callout; new Mix doc-generation tasks; JTBD-MAP refresh (Phase 58).

</domain>

<decisions>
## Implementation Decisions

### Release-status prose wording (Area 1)

- **D-01:** Replace stale lines 20–21 with a **minimal README-style blockquote one-liner** — no milestone bullets, no v1.x scope essay in getting-started.
- **D-02:** Exact shape mirrors README tone:

  ```markdown
  > **Release status:** **`1.7.x`** ships as the current published line on Hex (capstone release **1.7.0**).
  ```

- **D-03:** Install snippet stays `{:lattice_stripe, "~> 1.7"}` unchanged. Prose immediately follows the install code block, before "Then fetch your dependencies."
- **D-04:** Reject full README blockquote duplication (milestone 1.4–1.7 bullets) — HexDocs landing guide stays task-focused (install → Finch → first call). Milestone narrative remains README/CHANGELOG only.

### docs_truth lock strategy (Area 2)

- **D-05:** **Positive assert + refute stale** (Option A) — extend Phase 54 SSOT, do not lock verbatim full sentences (reject Option C).
- **D-06:** Add module helper `current_release_line/0` alongside `expected_install_snippet/0`:

  ```elixir
  defp current_release_line do
    [major, minor | _] = String.split(LatticeStripe.MixProject.project()[:version], ".")
    "#{major}.#{minor}.x"
  end
  ```

- **D-07:** Positive asserts on `guides/getting-started.md`: derived `current_release_line()` present **and** semantic anchor (`"current published"` or `"published line"` or `"published Hex"`).
- **D-08:** Refute `@stale_release_status_claims` list (exact stale *claims*, not bare version numbers):

  ```elixir
  @stale_release_status_claims [
    "1.3.x` line is the current published",
    "1.3.x line is the current published"
  ]
  ```

  Extend list on future capstone bumps (same ritual as `@stale_install_pins`).

- **D-09:** Refactor existing `"readme release block and hexdocs clusters reflect v1.7 surface"` test to use `current_release_line/0` and `@stale_release_status_claims` — one SSOT for both README and getting-started release truth.
- **D-10:** Reject refute-only (Option B) — insufficient for TRUTH-02; paraphrased stale claims would pass.

### Git dependency callout (Area 3)

- **D-11:** **Remove the git dependency paragraph entirely** — delete lines 20–21 git-dep framing; do not soften (Option A) or keep verbatim with version fix (Option C).
- **D-12:** Rationale: post-REL-04 Hex 1.7.0 capstone makes "unreleased work from `main`" obsolete in adopter onboarding; contradicts README maintenance-mode posture; peer Elixir Hex libs (Phoenix, Ecto, Oban, Req, Finch) and official Stripe SDKs do not steer integrators to git installs in getting-started.
- **D-13:** If contributors need git-dep guidance later, it belongs in CONTRIBUTING — not the zero-to-first-`PaymentIntent` path.
- **D-14:** docs_truth refute: `refute guide =~ "unreleased work from \`main\`"` in getting-started release test — prevents regression of pre-capstone Hex-lag narrative.

### Test organization (Area 4)

- **D-15:** Add `describe "guides/getting-started.md"` with **two tests**:
  1. `"release-status prose matches current Hex surface"` (TRUTH-02 — new)
  2. `"branches from first success into high-leverage guides"` (migrate existing cross-link test from top-level)
- **D-16:** Add `describe "release truth"` for cross-surface SSOT: getting-started prose test may live under getting-started describe; README release assertions move into or share helpers under release-truth grouping. Minimal Phase 56: prose test under `guides/getting-started.md` describe; refactor README test to use shared helpers at module level.
- **D-17:** Reject extending cross-link test with prose asserts (Option A) — mixes routing contract with release-truth contract; failure signal misleads fixers.
- **D-18:** Phase 57 VERIFY-04 adds parallel `describe "guides/payments.md"` for canonical API example locks — do not extend tax-guide monolith pattern.

### Claude's Discretion

- Exact wording inside blockquote if editorial polish needed — must preserve `current_release_line()` token and semantic published anchor.
- Whether README release test moves into `describe "release truth"` or stays top-level with shared helpers only.
- Custom assert messages for clearer CI failure output (e.g., `"release-status prose drifted from mix.exs version"`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` § Phase 56 — success criteria, TRUTH-01/02
- `.planning/REQUIREMENTS.md` § Release Truth — TRUTH-01, TRUTH-02 acceptance
- `.planning/PROJECT.md` — v1.8 goal, docs_truth prose gap assessment
- `.planning/STATE.md` — docs_truth must cover release-status prose
- `.planning/JTBD-MAP.md` — getting-started lines 20–21 drift documented
- `.planning/threads/v1-8-next-milestone-assessment.md` — bug class analysis, SSOT lesson
- `.planning/config.json` — `docs_truth_prose_surfaces: ["guides/getting-started.md"]`

### Prior release-truth work
- `.planning/milestones/v1.7-ROADMAP.md` § Phase 54 — SSOT install contract, REL-01..04
- `.planning/milestones/v1.7-MILESTONE-AUDIT.md` — getting-started prose drift finding
- `.planning/milestones/v1.4-phases/43-public-truth-baseline/43-01-SUMMARY.md` — original getting-started release-status pattern (historical; superseded by 1.7 capstone)

### Implementation surfaces
- `guides/getting-started.md` — lines 20–21 bug; HexDocs `main` page
- `README.md` line 8 — canonical release-status blockquote to mirror (one-liner only)
- `test/lattice_stripe/docs_truth_test.exs` — SSOT install helpers, README refute at line 136, getting-started cross-link test at line 139
- `mix.exs` — `@version` SSOT for install and prose derivation

### Ecosystem research (prompts)
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — Hex docs hygiene, README-only docs anti-pattern, copy-pasteable guides
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — CI/docs regression posture

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `expected_install_snippet/0` — Phase 54 SSOT pattern; extend with `current_release_line/0` for prose
- `@stale_install_pins` / `@install_surfaces` — stale-list ritual to mirror for `@stale_release_status_claims`
- `test "readme release block and hexdocs clusters reflect v1.7 surface"` — partial lock; hardcodes `1.7`; refactor to SSOT helpers
- README blockquote at line 8 — tone/template for getting-started one-liner

### Established Patterns
- **Positive + refute grep locks** — Charge moduledoc, thin-events guide, operator guides, tax guide
- **Content vs cross-link split** — thin-events and operator guides use separate tests; getting-started should follow via describe grouping
- **Install SSOT from mix.exs** — version bumps fail tests until all surfaces align

### Integration Points
- `guides/getting-started.md` is ExDoc `main` (`mix.exs` docs `main: "getting-started"`)
- Phase 57 adds `describe "guides/payments.md"` in same test file — keep structure scalable
- Verification command: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`

</code_context>

<specifics>
## Specific Ideas

### Research synthesis (all four areas — user requested one-shot coherent recommendations)

**Coherent package:** Minimal blockquote + SSOT positive/refute locks + remove git-dep + describe-per-guide test structure. All four decisions reinforce "Hex 1.7.0 is the adopter truth; getting-started confirms trust then moves to first success."

| Area | Decision | Why it coheres |
|------|----------|----------------|
| Prose | README one-liner blockquote | Matches README; Req/Finch/Swoosh/Stripe SDKs keep install sections task-focused |
| Lock | SSOT derive + positive + refute | Extends Phase 54; closes install-pin-passed/prose-lied bug class; templates Phase 57 VERIFY-04 |
| Git dep | Remove | REL-04 retired Hex-lag narrative; README has no git mention; least surprise for production adopters |
| Tests | `describe "guides/getting-started.md"` | Scales to Phase 57 payments describe; clear CI failure names |

### Cross-ecosystem lessons applied
- **Do right:** Stripe SDKs use package manager first; version policy in CHANGELOG/support sections; Elixir Hex libs assume Hex in getting-started
- **Footguns avoided:** Split-brain install vs prose (this bug); duplicating README milestone bullets; refute-only locks; git-dep in production onboarding; unrelated asserts in one test

### Example target state (`guides/getting-started.md` Installation section)

```markdown
```elixir
defp deps do
  [
    {:lattice_stripe, "~> 1.7"},
    {:finch, "~> 0.21"}
  ]
end
```

> **Release status:** **`1.7.x`** ships as the current published line on Hex (capstone release **1.7.0**).

Then fetch your dependencies:
```

</specifics>

<deferred>
## Deferred Ideas

- **CI paths-ignore fix (CI-01)** — guide-only PRs should run docs_truth; awaiting explicit approval per STATE.md; not v1.8 scope
- **Contributor git-dep documentation** — if needed, add to CONTRIBUTING, not getting-started
- **Cheatsheet release-status prose** — no drift found; cheatsheet has install pin only
- **Mix task for doc sync from @version** — overkill for two sentences; test-time SSOT sufficient
- **Full README release block in getting-started** — deferred permanently; wrong surface for milestone archaeology

</deferred>

---

*Phase: 56-release-truth-getting-started*
*Context gathered: 2026-05-27*
