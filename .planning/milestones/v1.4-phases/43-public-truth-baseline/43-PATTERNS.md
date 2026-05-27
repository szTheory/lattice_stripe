# Phase 43: Public Truth Baseline - Pattern Map

## File Classification

| File | Role | Why it matters |
|------|------|----------------|
| `README.md` | repo landing page | First public package/install truth many adopters see |
| `guides/getting-started.md` | HexDocs main page | First-run onboarding page; currently stale on `~> 1.2` |
| `guides/cheatsheet.cheatmd` | compact public quick-reference | High-visibility install snippet and first-use examples |
| `CHANGELOG.md` | release truth ledger | Published `1.3.0` anchor and shipped-surface narrative |
| `mix.exs` | docs metadata source | Defines published version and ExDoc extras/main page |
| `test/lattice_stripe/docs_truth_test.exs` | regression guard | Current lightweight docs-truth safety net |

## Pattern Assignments

### `test/lattice_stripe/docs_truth_test.exs`

- Pattern: file-content assertions with `File.read!/1`
- Pattern: metadata assertions through `LatticeStripe.MixProject.project/0`
- Reuse for:
  - install snippet alignment
  - onboarding-surface alignment
  - ExDoc reachability of primary public docs surfaces

### `README.md` / `guides/getting-started.md` / `guides/cheatsheet.cheatmd`

- Pattern: copy-paste installation snippet truth
- Pattern: first-run quickstart alignment
- Reuse for:
  - a single canonical `{:lattice_stripe, "~> 1.3"}` package line
  - consistent public wording around the shipped `1.3.x` surface

### `CHANGELOG.md`

- Pattern: release-truth anchor rather than tutorial surface
- Reuse for:
  - ensuring public docs claims point back to an actual shipped release
  - avoiding future wording that implies `1.3.x` is unreleased

### `mix.exs`

- Pattern: ExDoc main/extras define public entry points
- Reuse for:
  - guarding that the docs surfaces covered by plan 01 remain actually published

## Recommended Planning Split

### Plan 01

- Primary files: `README.md`, `CHANGELOG.md`, `guides/getting-started.md`, `guides/cheatsheet.cheatmd`
- Optional supporting file: `mix.exs`
- Goal: reconcile public truth without changing execution or adding features

### Plan 02

- Primary files: `test/lattice_stripe/docs_truth_test.exs`
- Supporting files: `mix.exs`, the public docs files read by the test
- Goal: encode the public-truth contract so onboarding drift fails fast

## Risks

- Overfitting tests to large wording blocks instead of stable truth snippets
- Mixing Phase 43 truth checks with broader Phase 44 discovery/navigation requirements
- Letting docs tests assert transient prose rather than durable install/version/package facts

---
*Phase: 43-public-truth-baseline*
