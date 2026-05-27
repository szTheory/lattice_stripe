# Phase 56: Release Truth & Getting Started — Research

**Researched:** 2026-05-27
**Phase:** 56-release-truth-getting-started
**Requirements:** TRUTH-01, TRUTH-02

## Summary

Phase 56 closes a split-brain adopter-trust bug: install pins across public surfaces already derive from `mix.exs` via Phase 54 SSOT (`expected_install_snippet/0`), but `guides/getting-started.md` lines 20–21 still claim **`1.3.x`** is the current published Hex line and steer adopters toward git dependencies. README line 8 already carries the correct **`1.7.x`** blockquote. The fix is narrow — replace stale prose with a README-style one-liner, remove the obsolete git-dep paragraph, and extend `docs_truth_test.exs` with SSOT-derived positive/refute locks mirroring the install-pin ritual.

## Current State

### Bug surface (`guides/getting-started.md`)

```markdown
The `1.3.x` line is the current published Hex surface. If you specifically need
unreleased work from `main`, use a git dependency instead of the published release.
```

Install snippet is already correct: `{:lattice_stripe, "~> 1.7"}`.

### Canonical truth sources

| Source | Current value | Role |
|--------|---------------|------|
| `mix.exs` `@version` | `1.7.0` (or current) | SSOT for install + prose derivation |
| `README.md` line 8 | `1.7.x` blockquote | Tone/template for getting-started one-liner |
| `docs_truth_test.exs` | Install SSOT only | Locks pins, not release-status prose |

### Existing test gaps

- `"readme release block and hexdocs clusters reflect v1.7 surface"` hardcodes `"1.7"` and one stale refute string — not SSOT-derived.
- `"getting started branches from first success..."` mixes cross-link routing with a stale-pin refute (`~> 1.2`) — no release-status prose lock.
- No `@stale_release_status_claims` list analogous to `@stale_install_pins`.

## Recommended Approach

### 1. Prose fix (TRUTH-01)

Replace lines 20–21 with:

```markdown
> **Release status:** **`1.7.x`** ships as the current published line on Hex (capstone release **1.7.0**).
```

- Place immediately after the install code block, before "Then fetch your dependencies."
- Do **not** duplicate README milestone bullets (D-04).
- Remove git dependency paragraph entirely (D-11–D-13).

### 2. Test SSOT extension (TRUTH-02)

Add alongside existing install helpers:

```elixir
@stale_release_status_claims [
  "1.3.x` line is the current published",
  "1.3.x line is the current published"
]

defp current_release_line do
  [major, minor | _] = String.split(LatticeStripe.MixProject.project()[:version], ".")
  "#{major}.#{minor}.x"
end
```

Positive asserts on getting-started:
- Contains `current_release_line()` output
- Contains semantic anchor: `"current published"` OR `"published line"` OR `"published Hex"`

Refute asserts:
- Each string in `@stale_release_status_claims`
- `refute guide =~ "unreleased work from \`main\`"`

### 3. Test organization

Add `describe "guides/getting-started.md"` with:
1. `"release-status prose matches current Hex surface"` — TRUTH-02
2. `"branches from first success into high-leverage guides"` — migrate existing cross-link test

Refactor README release test to use `current_release_line/0` and `@stale_release_status_claims` (D-09). Optional `describe "release truth"` grouping — minimal path: shared module-level helpers only.

### 4. Verification command

```bash
mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors
```

## Patterns to Follow

From `docs_truth_test.exs`:
- **Positive + refute grep locks** — tax guide, webhooks-thin-events, operator guides
- **Install SSOT from mix.exs** — Phase 54 `expected_install_snippet/0`
- **Content vs cross-link split** — separate describe blocks per guide contract

From Phase 43 (historical): getting-started release-status prose was added then superseded by 1.7 capstone without prose update — this phase completes that reconciliation.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Hardcoding `1.7.0` in blockquote goes stale on patch bump | Use capstone version from mix.exs in test positive assert; prose can name current capstone explicitly per README |
| Refute-only locks miss paraphrased stale claims | Positive assert on derived `current_release_line()` (D-10) |
| Mixing prose + routing in one test | Separate describe blocks (D-17) |
| Future capstone bump forgets stale list | Document ritual: extend `@stale_release_status_claims` like `@stale_install_pins` |

## Plan Structure Recommendation

Two plans, two waves:

| Plan | Wave | Delivers |
|------|------|----------|
| 56-01 | 1 | SSOT helpers, describe reorg, new/failing prose tests, README test refactor |
| 56-02 | 2 | getting-started.md prose fix (makes tests green) |

Plan 01 intentionally leaves prose tests red until Plan 02 — standard red-green for docs_truth.

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config | `mix.exs` `test_paths: ["test"]` |
| Quick run | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| Full suite | `mix test --warnings-as-errors` |
| Estimated runtime | ~2–5 seconds (docs_truth only) |

### Per-requirement verification

| REQ-ID | Automated command | Pass condition |
|--------|-------------------|----------------|
| TRUTH-01 | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | getting-started contains derived release line; no stale 1.3.x claim |
| TRUTH-02 | same | new describe test passes; README test uses SSOT helpers |

### Wave 0

Not required — ExUnit infrastructure exists; no new test files needed.

## RESEARCH COMPLETE
