# Phase 19: Cross-cutting Polish & v1.0 Release - Research

**Researched:** 2026-04-13
**Domain:** Hex publishing, ExDoc configuration, Release Please 0.x→1.0 promotion, guide editorial pass, README automation
**Confidence:** HIGH — all decisions pre-locked in CONTEXT.md with 26 decisions backed by four advisor files; research confirms codebase state matches assumptions and fills in actionable implementation details

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Cleanup Scope**
- D-01: API-boundary-only cleanup rule. INCLUDE iff observable from a user's call site (public name/arity, return shape, error type, `@doc`/`@spec`/`@typedoc`, telemetry event name, NimbleOptions schema key). DEFER everything else.
- D-02: No backlog drain. Prior-phase `<deferred>` blocks roll forward into v1.1 backlog note in STATE.md. Ground truth: `grep -E 'TODO|FIXME|XXX|HACK' lib/` returns zero hits at commit `3ceb913`.
- D-03: Update stale Phase 14 VERIFICATION.md in passing — not blocking.

**Public API Surface Audit**
- D-04: Flip Phase 10 D-03. Mark non-extension-point helpers `@moduledoc false`: `LatticeStripe.FormEncoder`, `LatticeStripe.Request`, `LatticeStripe.Resource`, `LatticeStripe.Transport.Finch`, `LatticeStripe.Json.Jason`, `LatticeStripe.RetryStrategy.Default`, `LatticeStripe.Webhook.CacheBodyReader`, `LatticeStripe.Billing.Guards`.
- D-05: Keep three extension-point behaviours VISIBLE in "Internals" group: `LatticeStripe.Transport`, `LatticeStripe.Json`, `LatticeStripe.RetryStrategy`.
- D-06: No rename sweep, no speculative `@deprecated` markers.
- D-07: Publish `guides/api_stability.md` (~100 lines, new 14th guide). Semver contract: patch = bug fixes, minor = additive, major = breaking. Private modules excluded from semver contract.
- D-08: Update Phase 11 D-16 to post-1.0 semantics (breaking = major, feature = minor, fix = patch). Document in api_stability.md and CHANGELOG.

**Release Mechanics**
- D-09: Drive 0.x → 1.0.0 via `release-please-config.json`. Add `"release-as": "1.0.0"` to the `"."` package block.
- D-10: Do NOT use the `Release-As:` commit footer. Broken under squash-merge workflows (release-please-action #952). Phase 11 D-35 mandates squash merge.
- D-11: No pre-1.0 CI re-run, no manual Hex override. Phase 11 automation fires normally — Release Please PR → merge → GitHub release → `mix hex.publish --yes` → HexDocs published.

**CHANGELOG**
- D-12: Curated Highlights section for v1.0.0. Push one `docs(changelog): add v1.0 highlights` commit to the release-please PR branch BEFORE merge.
- D-13: Phase 11 D-19's "no manual curation" scopes to GitHub Release page bodies only, not CHANGELOG.md.
- D-14: Highlights content: 4-sentence narrative of 0.2→1.0 arc — Foundation / Billing / Connect / Stability commitment. ~300 words. No per-phase bullets in narrative.

**Docs Refresh Scope**
- D-15: Hybrid scoped editorial pass. Re-verify code samples in 4 Phase-10 guides (payments, checkout, webhooks, error-handling) against stripe-mock. Add "See also" footers. 10-item checklist (see CONTEXT.md for full list).
- D-16: Split existing 577-line `connect.md` into three files: `connect.md` (~150 lines, conceptual overview), `connect-accounts.md` (~250 lines), `connect-money-movement.md` (~280 lines).
- D-17: Final `:extras` order: getting-started → client-configuration → payments → checkout → invoices → subscriptions → connect → connect-accounts → connect-money-movement → webhooks → error-handling → testing → telemetry → api-stability → extending-lattice-stripe → cheatsheet.cheatmd → CHANGELOG.md (17 entries total).
- D-18: Do NOT merge invoices.md + subscriptions.md. Do NOT add billing-overview.md.

**ExDoc Module Groups**
- D-19: Nine-group ExDoc layout: Client & Configuration / Payments / Checkout / Billing / Connect / Webhooks / Telemetry / Testing / Internals. Full module mapping in CONTEXT.md.
- D-20: Backfill six modules currently missing from mix.exs groups: `LoginLink`, `InvoiceItem.Period`, `Webhook.Handler`, `Webhook.SignatureVerificationError`, `Testing.TestClock`, `Testing.TestClock.Owner`, `Testing.TestClock.Error`.

**README Quickstart**
- D-21: Keep Phase 10 D-18 PaymentIntent hero UNCHANGED.
- D-22: Restructure README feature bullets into grouped Payments / Billing / Connect / Platform sub-sections.
- D-23: Add short "What's new in v1.0" callout block below the badges.

**Automated 60-second Quickstart Test**
- D-24: Add `test/readme_test.exs` — `@tag :integration` test that regex-extracts fenced `elixir` blocks from the README Quick Start section and `Code.eval_string/1`s them against stripe-mock. ~40 LOC.
- D-25: Do NOT use `ExUnit.DocTest.doctest_file/1`. Forces `iex>` prompts that hurt copy-paste DX.
- D-26: Test runs only in the integration job. Default `mix test` stays stripe-mock-free (Phase 9 D-01 preserved).

### Claude's Discretion
- Exact wording/length of the Highlights narrative (~300 words per D-14)
- Exact regex/parse strategy for `test/readme_test.exs`
- Wording of `api_stability.md` guide (D-07)
- Exact ordering/wording of "See also" footers on each guide
- Commit-splitting strategy inside Phase 19 plans
- Whether `Webhook.Handler` is exposed as a public behaviour — verify during audit; drop from Webhooks group if not
- Whether to update Phase 14 VERIFICATION.md in-phase or leave as a note (D-03)

### Deferred Ideas (OUT OF SCOPE)
- Deprecation cycle for 2.0
- Full guide rewrite with uniform template
- `billing-overview.md` meta-guide
- Merging invoices.md + subscriptions.md
- Tabbed or multi-tier README quickstart
- `ExUnit.DocTest.doctest_file/1` for README
- Internal refactors / typespec gap fill / test coverage expansion
- Draining prior-phase `<deferred>` blocks
- CODEOWNERS, stale bot, Discussions
</user_constraints>

---

## Summary

Phase 19 is a polish and release phase, not a feature phase. The 26 locked decisions in CONTEXT.md provide surgical precision: every implementation action is a concrete file edit, not an open architectural question. The advisor research files contain copy-pasteable code snippets for all four work areas. Research confirms that the codebase state matches advisor assumptions (verified below in Current Codebase Reality).

**Primary recommendation:** Execute four sequential plans — (1) API audit + `@moduledoc false` flip + mix.exs module group overhaul, (2) guide editorial pass + connect.md split + api_stability.md, (3) README restructure + readme_test.exs, (4) release-please config + CHANGELOG highlights + release cut. All four plans are independent enough to plan in parallel but must execute in dependency order for the release plan.

---

## Project Constraints (from CLAUDE.md)

| Directive | Value |
|-----------|-------|
| Language | Elixir 1.15+, OTP 26+ |
| No Dialyzer | Typespecs for documentation only |
| HTTP | Finch as default; Transport behaviour for swapping |
| JSON | Jason (ecosystem standard) |
| Testing | ExUnit + Mox + stripe-mock (Docker); no ExVCR/Bypass |
| ExDoc | ~> 0.34 |
| Lint | Credo (`--strict`), MixAudit |
| No GenServer for state | Config is a plain struct |
| GSD workflow | Use `/gsd:execute-phase` for all file changes |

---

## Standard Stack

No new dependencies in Phase 19. All existing deps are in use and locked.

### Core (already installed)
| Library | Version | Purpose |
|---------|---------|---------|
| ex_doc | ~> 0.34 (current: 0.40.x) | ExDoc documentation generation |
| release-please-action | v4 | GitHub Actions release automation |
| stripe-mock | Docker `stripe/stripe-mock:latest` | Integration test server |

[VERIFIED: mix.exs — no new deps required for Phase 19]

### ExDoc version reality check

ExDoc ~> 0.34 is declared in mix.exs. The `groups_for_modules` syntax used throughout is stable since ExDoc 0.28+. The nine-group layout (D-19) uses the same list-of-module-atom syntax as the current eight-group config. No API changes needed. [VERIFIED: mix.exs `deps` block]

---

## Architecture Patterns

### Plan Decomposition (from CONTEXT.md Specifics section)

The phase naturally decomposes into four plans in this order:

```
Plan 1: API audit + @moduledoc false flip + mix.exs module groups
Plan 2: Guide editorial pass + connect.md split + api_stability.md
Plan 3: README restructure + readme_test.exs
Plan 4: Release-please config + CHANGELOG highlights + release cut
```

Plans 1-3 can be drafted in parallel; Plan 4 depends on all three shipping cleanly.

### Pattern: `@moduledoc false` for Non-Extension-Point Internals

**What:** Replace real `@moduledoc """..."""` with `@moduledoc false` on modules that are implementation details, not user API. Function-level `@doc` annotations can remain (for maintainers and stacktrace context).

**When to use:** Any module in the Internals group that is NOT a user-implemented behaviour (i.e., not `Transport`, `Json`, `RetryStrategy`).

**Example:**
```elixir
# Before (Phase 10 D-03 — visible internals OK for 0.x)
defmodule LatticeStripe.FormEncoder do
  @moduledoc """
  Encodes nested Elixir maps into Stripe's URL-encoded form format.
  ...
  """

# After (Phase 19 D-04 — hide at 1.0)
defmodule LatticeStripe.FormEncoder do
  @moduledoc false
  # Function-level @doc annotations remain for maintainer context.
```

[CITED: hexdocs.pm/elixir/writing-documentation.html — `@moduledoc false` convention for internals]

### Pattern: ExDoc nine-group `groups_for_modules`

The new mix.exs `groups_for_modules` block replaces the current eight-group block. The key changes from current state:

1. Rename "Core" → "Client & Configuration"
2. Move `Charge` from Payments → Connect
3. Remove `Billing.Guards` from Billing → move to Internals (with `@moduledoc false`)
4. Add six missing modules to their groups (D-20)
5. Split "Telemetry & Testing" → separate "Telemetry" and "Testing" groups
6. Add `Webhook.Handler`, `Webhook.SignatureVerificationError` to Webhooks group
7. Move `Testing.TestClock`, `Testing.TestClock.Owner`, `Testing.TestClock.Error` into Testing group

[VERIFIED: mix.exs lines 43-128 — current state confirmed against advisor drift inventory]

### Pattern: Release Please 0.x → 1.0.0 Promotion

```json
// release-please-config.json — add release-as to packages."." block
{
  "release-type": "elixir",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": false,
  "changelog-sections": [
    {"type": "feat",  "section": "Features"},
    {"type": "fix",   "section": "Bug Fixes"},
    {"type": "perf",  "section": "Performance Improvements"},
    {"type": "deps",  "section": "Dependencies"},
    {"type": "chore", "section": "Miscellaneous", "hidden": true}
  ],
  "packages": {
    ".": {
      "release-as": "1.0.0"
    }
  }
}
```

After the 1.0.0 release PR merges and Hex publishes, a follow-up PR removes `"release-as"` and flips `"bump-minor-pre-major"` to `false`.

[CITED: github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md]
[CITED: 19-ADVISOR-release-changelog.md — Option A mechanics, squash-merge safety]

### Pattern: README Quickstart Test (D-24)

```elixir
# test/readme_test.exs  (~40 LOC)
defmodule LatticeStripe.ReadmeTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :readme

  @readme Path.join(__DIR__, "../README.md") |> Path.expand()

  setup_all do
    # stripe-mock already running on :12111 per Phase 9 D-02
    start_supervised!({Finch, name: ReadmeTest.Finch})
    :ok
  end

  test "README Quick Start blocks execute against stripe-mock" do
    # Extract only the Quick Start section to avoid extracting unintended blocks
    readme = File.read!(@readme)
    quick_start_section = extract_quick_start_section(readme)
    blocks = extract_elixir_blocks(quick_start_section)

    script =
      blocks
      |> Enum.join("\n")
      |> String.replace(~s("sk_test_..."), ~s("sk_test_readme"))
      |> String.replace("MyApp.Finch", "ReadmeTest.Finch")
      |> inject_base_url()

    {_result, _binding} = Code.eval_string(script, [])
    # If Code.eval_string raises, the test fails — that is the assertion
  end

  defp extract_quick_start_section(md) do
    case Regex.run(~r/## Quick Start\n(.*?)(?=\n## |\z)/s, md, capture: :all_but_first) do
      [section] -> section
      nil -> raise "## Quick Start section not found in README"
    end
  end

  defp extract_elixir_blocks(md) do
    ~r/```elixir\n(.*?)```/s
    |> Regex.scan(md, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  defp inject_base_url(script) do
    String.replace(
      script,
      "LatticeStripe.Client.new!(",
      ~s|LatticeStripe.Client.new!(base_url: "http://localhost:12111", |
    )
  end
end
```

[CITED: 19-ADVISOR-readme-test.md — Option B sketch, Phase 9 D-01 compatibility]

### Pattern: CHANGELOG Highlights (D-12, D-14)

The highlights block must be pushed to the release-please PR branch BEFORE merge, BELOW the `## [1.0.0]` heading line (never edit the heading itself — release-please may match on it). Structure:

```markdown
## [1.0.0](...) (2026-04-XX)

### Highlights

LatticeStripe 1.0 marks our commitment to API stability...

**What's in the box:**
- **Payments.** ...
- **Billing.** ...
- **Connect.** ...
- **Webhooks.** ...
- **Operational glue.** ...

**Upgrading from 0.2.x.** No breaking changes...

**Supported versions.** Elixir 1.15+ on OTP 26+...

### Features
* (release-please auto-generated — do not touch)
```

[CITED: 19-ADVISOR-release-changelog.md — Option 2, D-18/D-19 compatibility analysis]

### Anti-Patterns to Avoid

- **Using `Release-As:` commit footer:** Broken under squash-merge workflows (release-please-action issue #952, still open April 2026). Use config `release-as` key instead.
- **Using `doctest_file "README.md"`:** Forces `iex>` prompt syntax in README hero, creating copy-paste footgun for users. Use custom fence-parsing test instead (D-25).
- **Adding speculative `@deprecated` markers:** No concrete deprecations exist; phantom deprecations are noise. Defer to post-1.0 when real warts surface (D-06).
- **Editing the `## [1.0.0]` CHANGELOG heading line:** Release-please matches on it for idempotency checks. Add highlights below it, not by replacing it.
- **Removing `@doc` from hidden modules:** `@moduledoc false` hides the module from ExDoc navigation but function `@doc` annotations remain useful in stacktraces and for maintainers. Keep them.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| 0.x → 1.0.0 version promotion | Manual manifest edit, commit footer tricks | `"release-as": "1.0.0"` in release-please-config.json packages block |
| README code verification | Custom mix task, doctest_file | `Code.eval_string/1` inside `@tag :integration` ExUnit test |
| CHANGELOG curation | Separate UPGRADING.md, separate guide | Add `### Highlights` block to the release PR branch before merge |
| Module visibility | Custom documentation hiding | Elixir standard `@moduledoc false` attribute |

---

## Current Codebase Reality

**CRITICAL for planner — actual state verified 2026-04-13:**

### mix.exs `groups_for_modules` drift from D-19 target

| Item | Current State | D-19 Target | Action |
|------|---------------|-------------|--------|
| Group name "Core" | Exists | Rename → "Client & Configuration" | Edit mix.exs |
| `LatticeStripe.Charge` | In Payments group | Move to Connect group | Edit mix.exs |
| `LatticeStripe.Billing.Guards` | In Billing group (with `@moduledoc """`) | Move to Internals + `@moduledoc false` | Edit mix.exs + guards.ex |
| `LatticeStripe.LoginLink` | **ALREADY in Connect group** | Stays in Connect | No action needed |
| `LatticeStripe.InvoiceItem.Period` | **ALREADY in Billing group** | Stays in Billing | No action needed |
| `LatticeStripe.Webhook.Handler` | NOT in any group | Add to Webhooks group | Edit mix.exs (verify public behaviour first) |
| `LatticeStripe.Webhook.SignatureVerificationError` | NOT in any group | Add to Webhooks group | Edit mix.exs |
| `LatticeStripe.Testing.TestClock` | NOT in any group | Add to Testing group | Edit mix.exs |
| `LatticeStripe.Testing.TestClock.Owner` | NOT in any group (has `@moduledoc false`) | Add to Testing group | Edit mix.exs + owner.ex (remove `@moduledoc false`, add real doc) |
| `LatticeStripe.Testing.TestClock.Error` | NOT in any group | Add to Testing group | Edit mix.exs |
| "Telemetry & Testing" combined group | Exists | Split into "Telemetry" + "Testing" | Edit mix.exs |
| `LatticeStripe.RetryStrategy.Default` | In Internals | Stays in Internals | No action (but add `@moduledoc false`) — **note: defined inside `retry_strategy.ex`, not a separate file** |

[VERIFIED: mix.exs lines 43-128, lib/ tree scan 2026-04-13]

**Important finding:** `LatticeStripe.RetryStrategy.Default` is defined INSIDE `lib/lattice_stripe/retry_strategy.ex` (line 38: `defmodule LatticeStripe.RetryStrategy.Default do`), not in a separate file. The `@moduledoc false` must be added to the inner module definition, not a non-existent separate file.

**Important finding:** `LatticeStripe.Testing.TestClock.Owner` currently has `@moduledoc false` (the only module in `lib/` with this attribute). It will need its `@moduledoc false` replaced with a real `@moduledoc` since it's being added to the public Testing group.

**Important finding:** CONTEXT.md D-20 says "Backfill six missing modules" but actual mix.exs already includes `LoginLink` and `InvoiceItem.Period`. The actual missing modules are four, not six: `Webhook.Handler`, `Webhook.SignatureVerificationError`, `Testing.TestClock`, `Testing.TestClock.Owner`, `Testing.TestClock.Error` (that's five). The advisor's count was based on an earlier snapshot. The planner should use the verified current state above.

### `@moduledoc false` candidates — current state

All modules targeted by D-04 currently have real `@moduledoc """..."""` (verified by grep scan):
- `LatticeStripe.FormEncoder` — has `@moduledoc """`
- `LatticeStripe.Request` — has `@moduledoc """`
- `LatticeStripe.Resource` — has `@moduledoc """`
- `LatticeStripe.Transport.Finch` — has `@moduledoc """`
- `LatticeStripe.Json.Jason` — has `@moduledoc """`
- `LatticeStripe.RetryStrategy.Default` — needs verification (defined inside retry_strategy.ex)
- `LatticeStripe.Webhook.CacheBodyReader` — has `@moduledoc """` (nested inside plug.ex as `defmodule`)
- `LatticeStripe.Billing.Guards` — has `@moduledoc """`

All need `@moduledoc false` applied. [VERIFIED: Grep scan of lib/ tree]

### Guides on disk vs D-17 target

Current guides (13 files):
```
guides/getting-started.md
guides/client-configuration.md
guides/payments.md
guides/checkout.md
guides/invoices.md
guides/subscriptions.md
guides/connect.md           <- 577 lines, must split into 3 files (D-16)
guides/webhooks.md
guides/error-handling.md
guides/testing.md
guides/telemetry.md
guides/extending-lattice-stripe.md
guides/cheatsheet.cheatmd
```

After Phase 19 (16 guide files + CHANGELOG):
```
guides/connect.md           <- ~150 lines (new conceptual overview, REPLACES current)
guides/connect-accounts.md  <- ~250 lines (NEW, split from current connect.md)
guides/connect-money-movement.md <- ~280 lines (NEW, split from current connect.md)
guides/api_stability.md     <- ~100 lines (NEW, D-07)
```

[VERIFIED: `ls guides/` 2026-04-13; connect.md section structure via `grep "^## " guides/connect.md`]

### connect.md current section structure

```
## Acting on behalf of a connected account  (line 12)
## Creating a connected account             (line 62)
## Onboarding URL flow                      (line 86)
## Login Links                              (line 132)
## Handling capabilities                    (line 158)
## Rejecting an account                     (line 192)
## Webhook handoff                          (line 214)
## Money Movement                           (line 234)
```

Split target per D-16:
- New `connect.md` (~150 lines): conceptual overview — Standard/Express/Custom, charge patterns, money-flow diagram, capability model. Does NOT directly lift sections from current connect.md (current file lacks this framing).
- `connect-accounts.md` (~250 lines): "Acting on behalf", "Creating a connected account", "Onboarding URL flow", "Login Links", "Handling capabilities", "Rejecting an account", "Webhook handoff".
- `connect-money-movement.md` (~280 lines): "Money Movement" section + new destination charges + fee reconciliation content.

[VERIFIED: `head -50 guides/connect.md` + `grep "^## " guides/connect.md`]

### release-please-config.json current state

```json
{
  "release-type": "elixir",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": false,
  "changelog-sections": [...],
  "packages": {
    ".": {}    // <- Empty object; needs "release-as": "1.0.0" added
  }
}
```

`.release-please-manifest.json` current: `{ ".": "0.2.0" }`

[VERIFIED: cat release-please-config.json + cat .release-please-manifest.json 2026-04-13]

### README current state

README already has a QuickStart section with three fenced `elixir` blocks:
1. `deps do` block (mix.exs)
2. `children = [{Finch...}]` supervision tree block
3. `client = LatticeStripe.Client.new!...` PaymentIntent block

The readme_test.exs should extract blocks from the `## Quick Start` section. The `deps do` block is not executable against stripe-mock — the extractor regex must handle this gracefully (either skip non-runnable blocks or extract only the section after "Then create a client"). Claude's discretion on exact regex.

[VERIFIED: `head -80 README.md` 2026-04-13]

### `test/readme_test.exs` — does not exist yet

`ls test/*.exs` confirms only `test/lattice_stripe_test.exs` and `test/test_helper.exs` exist. The `test/integration/` directory exists with 26 integration test files. `readme_test.exs` is a net-new file.

[VERIFIED: `ls test/*.exs` 2026-04-13]

---

## Common Pitfalls

### Pitfall 1: `Release-As:` Footer in Squash-Merge Repos
**What goes wrong:** Pushing an empty commit with `Release-As: 1.0.0` footer, then finding release-please ignores it or creates 0.3.0 anyway.
**Why it happens:** GitHub squash-merge adds `---` separator and Co-authored-by trailers, which break release-please's footer parser. Open bug as of April 2026 (release-please-action #952).
**How to avoid:** Use `"release-as": "1.0.0"` in `release-please-config.json` packages block (D-09).
**Warning signs:** Release PR opens with version 0.3.0 instead of 1.0.0.

[CITED: github.com/googleapis/release-please-action/issues/952]

### Pitfall 2: Editing the CHANGELOG Heading Line
**What goes wrong:** Editing the `## [1.0.0](https://...)` heading in CHANGELOG.md causes release-please to fail to detect the existing entry on subsequent runs.
**Why it happens:** Release-please uses the heading line pattern for idempotency checking.
**How to avoid:** Add the `### Highlights` block as the first subsection BELOW the heading, not by modifying the heading itself.

[CITED: 19-ADVISOR-release-changelog.md — automation risk assessment]

### Pitfall 3: Leaving `"release-as"` in Config After Release
**What goes wrong:** After 1.0.0 ships, leaving `"release-as": "1.0.0"` in config means release-please keeps proposing 1.0.0 instead of incrementing to 1.0.1, 1.1.0, etc.
**Why it happens:** The key is permanent until removed.
**How to avoid:** Plan 4 must include a follow-up PR (or step) to remove `release-as` and flip `bump-minor-pre-major` to `false`.

### Pitfall 4: `Testing.TestClock.Owner` has `@moduledoc false` — Must Flip
**What goes wrong:** Adding `LatticeStripe.Testing.TestClock.Owner` to the Testing ExDoc group while it retains `@moduledoc false` makes it appear in the sidebar but show no documentation.
**Why it happens:** `@moduledoc false` suppresses all ExDoc output even when the module is listed in a group.
**How to avoid:** Add a real `@moduledoc` to `Testing.TestClock.Owner` as part of Plan 1's docs pass.

[VERIFIED: Only module in lib/ with `@moduledoc false` is `Testing.TestClock.Owner` at `lib/lattice_stripe/testing/test_clock/owner.ex:2`]

### Pitfall 5: README Quickstart Test Extracting the `deps do` Block
**What goes wrong:** `readme_test.exs` extracts all fenced elixir blocks from the Quick Start section including the `deps do` block, which is not valid Elixir outside a `mix.exs` context.
**Why it happens:** Regex capturing all fenced blocks indiscriminately.
**How to avoid:** Either (a) use a section-delimiting regex that starts capture after "Then create a client:" text, or (b) use `Code.eval_string` per-block and skip blocks that fail with a `CompileError` (not a runtime error — `deps` has an undefined `deps` function). Claude's discretion on implementation.

### Pitfall 6: `Webhook.CacheBodyReader` — Nested Module Definition
**What goes wrong:** Trying to find `lib/lattice_stripe/webhook/cache_body_reader.ex` and discovering it's inside `webhook/plug.ex` as a nested module, not a separate file.
**Why it happens:** It was implemented as a submodule for co-location with its plug.
**How to avoid:** The `@moduledoc false` must be added to the `defmodule LatticeStripe.Webhook.CacheBodyReader do` block inside `webhook/plug.ex`, or `webhook/cache_body_reader.ex` if it exists as a separate file. Verify location before editing.

[VERIFIED: `ls lib/lattice_stripe/webhook/` shows `cache_body_reader.ex` IS a separate file, so this concern is resolved — it exists at `lib/lattice_stripe/webhook/cache_body_reader.ex`]

---

## Code Examples

### release-please-config.json after D-09 change
```json
{
  "release-type": "elixir",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": false,
  "changelog-sections": [
    {"type": "feat",  "section": "Features"},
    {"type": "fix",   "section": "Bug Fixes"},
    {"type": "perf",  "section": "Performance Improvements"},
    {"type": "deps",  "section": "Dependencies"},
    {"type": "chore", "section": "Miscellaneous", "hidden": true}
  ],
  "packages": {
    ".": {
      "release-as": "1.0.0"
    }
  }
}
```

### mix.exs groups_for_modules after D-19 (complete target block)
```elixir
groups_for_modules: [
  "Client & Configuration": [
    LatticeStripe,
    LatticeStripe.Client,
    LatticeStripe.Config,
    LatticeStripe.Error,
    LatticeStripe.Response,
    LatticeStripe.List
  ],
  Payments: [
    LatticeStripe.PaymentIntent,
    LatticeStripe.Customer,
    LatticeStripe.PaymentMethod,
    LatticeStripe.SetupIntent,
    LatticeStripe.Refund
    # Charge moved to Connect (D-19)
  ],
  Checkout: [
    LatticeStripe.Checkout.Session,
    LatticeStripe.Checkout.LineItem
  ],
  Billing: [
    LatticeStripe.Invoice,
    LatticeStripe.Invoice.LineItem,
    LatticeStripe.Invoice.StatusTransitions,
    LatticeStripe.Invoice.AutomaticTax,
    LatticeStripe.InvoiceItem,
    LatticeStripe.InvoiceItem.Period,
    LatticeStripe.Subscription,
    LatticeStripe.Subscription.CancellationDetails,
    LatticeStripe.Subscription.PauseCollection,
    LatticeStripe.Subscription.TrialSettings,
    LatticeStripe.SubscriptionItem,
    LatticeStripe.SubscriptionSchedule,
    LatticeStripe.SubscriptionSchedule.Phase,
    LatticeStripe.SubscriptionSchedule.CurrentPhase,
    LatticeStripe.SubscriptionSchedule.PhaseItem,
    LatticeStripe.SubscriptionSchedule.AddInvoiceItem
    # Billing.Guards moved to Internals + @moduledoc false (D-04, D-19)
  ],
  Connect: [
    LatticeStripe.Account,
    LatticeStripe.Account.BusinessProfile,
    LatticeStripe.Account.Capability,
    LatticeStripe.Account.Company,
    LatticeStripe.Account.Individual,
    LatticeStripe.Account.Requirements,
    LatticeStripe.Account.Settings,
    LatticeStripe.Account.TosAcceptance,
    LatticeStripe.AccountLink,
    LatticeStripe.LoginLink,
    LatticeStripe.BankAccount,
    LatticeStripe.Card,
    LatticeStripe.ExternalAccount,
    LatticeStripe.ExternalAccount.Unknown,
    LatticeStripe.Transfer,
    LatticeStripe.TransferReversal,
    LatticeStripe.Payout,
    LatticeStripe.Payout.TraceId,
    LatticeStripe.Balance,
    LatticeStripe.Balance.Amount,
    LatticeStripe.Balance.SourceTypes,
    LatticeStripe.BalanceTransaction,
    LatticeStripe.BalanceTransaction.FeeDetail,
    LatticeStripe.Charge  # moved from Payments (D-19)
  ],
  Webhooks: [
    LatticeStripe.Webhook,
    LatticeStripe.Webhook.Plug,
    LatticeStripe.Webhook.Handler,              # added (D-20) — verify public behaviour
    LatticeStripe.Webhook.SignatureVerificationError, # added (D-20)
    LatticeStripe.Event
  ],
  Telemetry: [             # split from "Telemetry & Testing" (D-19)
    LatticeStripe.Telemetry
  ],
  Testing: [               # split from "Telemetry & Testing" (D-19)
    LatticeStripe.Testing,
    LatticeStripe.Testing.TestClock,           # added (D-20)
    LatticeStripe.Testing.TestClock.Owner,     # added (D-20) — remove @moduledoc false
    LatticeStripe.Testing.TestClock.Error      # added (D-20)
  ],
  Internals: [
    LatticeStripe.Transport,
    LatticeStripe.Transport.Finch,
    LatticeStripe.Json,
    LatticeStripe.Json.Jason,
    LatticeStripe.RetryStrategy,
    LatticeStripe.RetryStrategy.Default,
    LatticeStripe.FormEncoder,
    LatticeStripe.Request,
    LatticeStripe.Resource,
    LatticeStripe.Billing.Guards               # moved from Billing (D-19)
  ]
]
```

### api_stability.md guide outline (D-07)

```markdown
# API Stability

> LatticeStripe 1.0.0 commits to API stability under standard semantic versioning.

## What is public API

Modules documented in HexDocs (those without `@moduledoc false`) are public API.
The semver contract applies to:
- Public module names and aliases
- Public function signatures (name, arity, parameter types)
- Public struct field names (addition of fields is non-breaking; removal is breaking)
- Error reason atoms in `LatticeStripe.Error`
- Telemetry event names and metadata keys in `LatticeStripe.Telemetry`
- NimbleOptions schema keys in `LatticeStripe.Config`

## What is NOT public API

Modules with `@moduledoc false` are internal implementation details.
They may change in any patch release without notice:
- `LatticeStripe.FormEncoder`
- `LatticeStripe.Request`
- `LatticeStripe.Resource`
- `LatticeStripe.Transport.Finch`
- `LatticeStripe.Json.Jason`
- `LatticeStripe.RetryStrategy.Default`
- `LatticeStripe.Webhook.CacheBodyReader`
- `LatticeStripe.Billing.Guards`

## Extension points (public behaviours)

These three behaviours ARE public API — they are designed for user implementation:
- `LatticeStripe.Transport` — swap HTTP client
- `LatticeStripe.Json` — swap JSON codec
- `LatticeStripe.RetryStrategy` — customize retry logic

## Versioning policy

After v1.0.0:
- **Patch** (1.0.x): bug fixes, documentation corrections, internal refactors
- **Minor** (1.x.0): additive features — new resource modules, new function arities, new options
- **Major** (x.0.0): breaking changes to public API — removed functions, changed signatures, error type changes
```

---

## State of the Art

| Old Approach | Current Approach | Impact for Phase 19 |
|---|---|---|
| Phase 10 D-03: internal modules visible in "Internals" ExDoc group (correct for 0.x) | Phase 19 D-04: flip to `@moduledoc false` for non-behaviour internals (correct for 1.0) | Apply `@moduledoc false` to 8 modules |
| Phase 11 D-16: pre-1.0 semver (breaking = minor bump) | Phase 19 D-08: post-1.0 semver (breaking = major bump) | Document in api_stability.md + CHANGELOG highlights |
| Release Please with `"packages": {".": {}}` (standard bump rules) | Add `"release-as": "1.0.0"` to force 1.0.0, then remove after ship | Config change + follow-up cleanup PR |
| Single combined `connect.md` (577 lines, Phase 17/18) | Three-file split: overview + accounts + money-movement (D-16) | Create 2 new files, rewrite connect.md as overview |

---

## Validation Architecture

Test framework: ExUnit (stdlib). nyquist_validation is enabled (config.json).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) |
| Config file | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration])` |
| Quick run command | `mix test` |
| Full suite command | `mix test --include integration` |
| Integration stripe-mock | `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` |
| CI command | `mix ci` (format + compile + credo + test + docs) |

### Phase Requirements → Test Map

Phase 19 has no new requirement IDs (cross-cutting phase). Testing targets are:

| Behavior | Test Type | Automated Command | File Exists? |
|----------|-----------|-------------------|-------------|
| README quickstart runs against stripe-mock | integration | `mix test --include integration test/readme_test.exs` | ❌ Wave 0 (new file) |
| ExDoc builds without warnings | smoke | `mix docs --warnings-as-errors` | ✅ (part of `mix ci`) |
| All modules in groups compile cleanly | smoke | `mix compile --warnings-as-errors` | ✅ (part of `mix ci`) |
| `@moduledoc false` modules hidden from ExDoc sidebar | manual | Build docs + verify no internal modules in sidebar | Manual verification |

### Wave 0 Gaps
- [ ] `test/readme_test.exs` — covers D-24/D-26 README quickstart validation
  - Framework install: already present (ExUnit, Finch, stripe-mock infra)
  - No conftest.py equivalent needed (Elixir uses `test/support/`)

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | stripe-mock integration tests | ✓ | 29.3.1 | — (blocking for integration tests) |
| Elixir/Mix | All compilation + docs | ✓ | 1.19.5 / OTP 28 | — |
| stripe-mock Docker image | readme_test.exs, integration tests | ✓ (Docker available) | latest | — |
| release-please-action v4 | GitHub Actions release | ✓ (already installed in CI) | v4 | — |

**No missing dependencies.** All required tooling is present. [VERIFIED: `which docker && docker --version`, `mix --version`]

---

## Security Domain

Phase 19 is documentation, release configuration, and test file changes only. No new HTTP endpoints, no new cryptographic operations, no new user-facing APIs, no new input validation surfaces.

ASVS categories: Not applicable. Phase 19 adds no new attack surface.

The only security-adjacent action is making internal modules (`@moduledoc false`) less discoverable — this reduces Hyrum's-law liability, not a security concern.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `LatticeStripe.Webhook.Handler` is a public behaviour (not just an internal dispatch helper) — planner must verify before adding to Webhooks group | Current Codebase Reality | If it's not a public behaviour, drop from Webhooks group per Claude's Discretion clause |
| A2 | The `## Quick Start` section header in README.md will remain stable enough for the regex extractor to find it | Code Examples (readme_test.exs) | If README section header changes, regex breaks; low risk since we control the README |
| A3 | stripe-mock's latest Docker image continues to support the 2026-03-25.dahlia API version pinned in Config | Validation Architecture | If stripe-mock drops this version, integration tests fail; unlikely within this phase window |

---

## Open Questions

1. **Is `Webhook.Handler` a public behaviour or an internal dispatch helper?**
   - What we know: It exists at `lib/lattice_stripe/webhook/handler.ex` with a real `@moduledoc """` (verified). CONTEXT.md D-05 lists it for the Webhooks group.
   - What's unclear: Whether it has user-implementable callbacks (making it a genuine extension point) or only internal callbacks.
   - Recommendation: Planner should read first 20 lines of `webhook/handler.ex` during Plan 1. If it's a `@behaviour` with `@callback` definitions intended for user implementation, include in Webhooks group. If not, drop per Claude's Discretion.

2. **deps block in README — should readme_test.exs skip it?**
   - What we know: README Quick Start has a `deps do ... end` block that is not executable via `Code.eval_string` outside `mix.exs`.
   - What's unclear: Whether to skip it via regex (extract only from "Then create a client" onward) or handle via per-block eval with rescue.
   - Recommendation: Scope extraction to blocks after the "Then create a client" marker in README. Claude's discretion on exact regex.

---

## Sources

### Primary (HIGH confidence)
- `mix.exs` — verified current state of groups_for_modules, deps, extras
- `release-please-config.json` — verified `"packages": {".": {}}` state
- `.release-please-manifest.json` — verified `"0.2.0"` current version
- `guides/connect.md` — verified 577 lines, section structure
- `lib/` tree scan — verified all `@moduledoc` states
- `test/` tree scan — verified readme_test.exs does not exist

### Secondary (MEDIUM confidence — from advisor files, themselves HIGH-source)
- `19-ADVISOR-release-changelog.md` — Release Please 0.x→1.0 mechanics, CHANGELOG curation pattern
- `19-ADVISOR-cleanup-api.md` — `@moduledoc false` precedent (Elixir official docs, Phoenix/Ecto/Broadway)
- `19-ADVISOR-docs-exdoc.md` — ExDoc nine-group layout, connect.md split rationale
- `19-ADVISOR-readme-test.md` — readme_test.exs sketch, doctest_file rejection rationale

### External (CITED)
- [release-please manifest-releaser.md](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) — `release-as` config key
- [release-please-action issue #952](https://github.com/googleapis/release-please-action/issues/952) — squash-merge trap
- [Elixir writing-documentation guide](https://hexdocs.pm/elixir/writing-documentation.html) — `@moduledoc false` convention
- [Elixir library-guidelines](https://hexdocs.pm/elixir/library-guidelines.html) — pre-1.0 guarantees, semver

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all existing deps verified in mix.exs
- Release mechanics: HIGH — Release Please config verified against current file; squash-merge trap well-documented
- Module group changes: HIGH — verified current mix.exs state against D-19 target; drift inventory confirmed
- Guide editorial pass: HIGH — connect.md section structure verified; split target well-defined
- readme_test.exs: HIGH — sketch from advisor file; Phase 9 integration infrastructure confirmed present

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (ExDoc and release-please are stable; Stripe API version pinned)
