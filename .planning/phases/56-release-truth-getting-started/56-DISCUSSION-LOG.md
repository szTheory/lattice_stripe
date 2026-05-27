# Phase 56: Release Truth & Getting Started - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 56-Release Truth & Getting Started
**Areas discussed:** All four (user selected discuss-all with subagent research)

---

## Area 1: Release-status prose wording

| Option | Description | Selected |
|--------|-------------|----------|
| A — Minimal README one-liner blockquote | 2–3 sentences; mirrors README tone; no milestone bullets | ✓ |
| B — Full README blockquote + 1.4–1.7 bullets | Complete release narrative on HexDocs landing | |
| C — Dynamic prose from mix.exs at edit time | Mix generator or ExDoc templating | |

**User's choice:** Auto-resolved via research synthesis (discuss-all + one-shot recommendations)
**Notes:** Subagent research + prompts/elixir-opensource-libs confirmed Hex getting-started guides should be task-focused. Option A + test-time SSOT derivation (partial C) is the sweet spot. Reject B — duplicates README, violates docs ladder roles.

---

## Area 2: docs_truth lock strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A — Positive assert + refute stale | Derive major.minor.x from mix.exs; semantic anchors; stale claim list | ✓ |
| B — Refute-only | Block known stale string only | |
| C — Full SSOT verbatim prose | Lock exact sentence from helper | |

**User's choice:** Auto-resolved via research synthesis
**Notes:** Option A extends Phase 54 install SSOT. Reject C (brittle on editorial reword). Reject B alone (paraphrased lies pass). Sets template for Phase 57 VERIFY-04 positive/refute pattern on payments.md API examples.

---

## Area 3: Git dependency callout

| Option | Description | Selected |
|--------|-------------|----------|
| A — Keep but soften for maintenance mode | Rare co-tester valve with softened wording | |
| B — Remove entirely | Hex-only onboarding; git dep obsolete post-REL-04 | ✓ |
| C — Keep verbatim (version fix only) | Change 1.3.x → 1.7.x only | |

**User's choice:** Auto-resolved via research synthesis
**Notes:** Tension with Area 1 subagent example (kept git dep) resolved in favor of B for project coherence — REL-04 capstone, README maintenance mode, peer Elixir/Stripe SDK patterns. Blockquote alone sufficient after install snippet.

---

## Area 4: Test organization

| Option | Description | Selected |
|--------|-------------|----------|
| A — Extend existing cross-link test | Add prose asserts to "getting started branches…" | |
| B — New describe "guides/getting-started.md" | Migrate cross-link test + add prose test (2 tests) | ✓ |
| C — New top-level test only | Minimal diff; defer describe refactor | |

**User's choice:** Auto-resolved via research synthesis
**Notes:** Enhanced Option B — two tests in describe block. Reject A (misleading CI failure signal). Phase 57 adds `describe "guides/payments.md"` using same pattern.

---

## Claude's Discretion

- Exact blockquote editorial polish within SSOT constraints
- README test placement vs shared-helper-only refactor
- Custom assert messages for CI clarity

## Deferred Ideas

- CI paths-ignore (CI-01) — not v1.8 scope
- CONTRIBUTING git-dep docs — only if maintainers request later
- Mix doc-sync task — overkill for Phase 56
