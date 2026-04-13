---
phase: 19-cross-cutting-polish-release
fixed: 2026-04-13T00:00:00Z
fix_scope: critical_warning
review_path: 19-REVIEW.md
status: fixes_applied
target_branch: release-please--branches--main
findings_total: 3
findings_fixed: 3
findings_skipped: 8
iterations: 1
---

# Phase 19 — Code Review Fix Report

Applied fixes for all Critical + Warning findings from `19-REVIEW.md`. Default scope (no
`--all` flag), so the 8 Info-level findings remain open.

Fixes were committed to the **release-please PR branch** (`release-please--branches--main`),
**not** to `main`, because all three warnings affect files that ship with the v1.0.0 Hex
package (CHANGELOG, cheatsheet, webhooks guide). Landing them on the PR branch ensures
v1.0.0 ships clean rather than requiring a post-release patch.

## Fixes applied

| ID | Severity | Commit | What changed |
|---|---|---|---|
| WR-01 | warning | `428a791` | Removed stale `## [Unreleased]` stanza from `CHANGELOG.md` (12-line "Initial release of LatticeStripe" placeholder left over from pre-v0.1.0 scaffolding). |
| WR-02 | warning | `ce8ac2f` | `guides/cheatsheet.cheatmd:152` — corrected dead error pattern `:auth_error` → `:authentication_error` (the actual atom in `LatticeStripe.Error.error_type/0`). |
| WR-03 | warning | `09736ac` | `guides/webhooks.md:378` — aligned prose with the example: now mentions `LatticeStripe.Webhook.generate_test_signature/3` (used by the example) and notes `LatticeStripe.Testing.generate_webhook_payload/3` as the payload-builder companion. |

## Verification

- `mix ci` on PR branch after fixes: ✓ format, compile -Werror, credo --strict, **1386 tests / 0 failures**, docs -Werror
- `git push origin release-please--branches--main`: ✓ `321cb95..09736ac`
- GitHub Actions CI re-run triggered automatically on the new push (5 required checks)

## Skipped (Info-level — not in default fix scope)

These remain open on the PR branch unless the user runs `/gsd-code-review-fix 19 --all`
or fixes them manually before merge:

| ID | Why it might still matter |
|---|---|
| IN-01 | Orphan public modules `Price`, `Product`, `Coupon`, `PromotionCode` not in any `groups_for_modules` — will land in ExDoc default bucket instead of a named group. Cosmetic only. |
| IN-02 | `Internals` ExDoc group is effectively empty because every module in it has `@moduledoc false`. Cosmetic. |
| IN-03 | `Webhook.CacheBodyReader` is `@moduledoc false` but users are told to reference it by FQN in endpoint config. Doc/code mismatch. |
| IN-04 | README / getting-started / cheatsheet still pin `~> 0.1`–`~> 0.2` in deps blocks — should bump to `~> 1.0`. **User-visible at HexDocs**. |
| IN-05 | `test/readme_test.exs` `Code.eval_string/1` has no eval timeout (reliability hedge, not security). |
| IN-07 | `Billing.Guards.has_proration_behavior?` accepts `items[].proration_behavior` on Schedule updates where Stripe API does not. |
| IN-08 | CHANGELOG Highlights uses relative markdown path `guides/api_stability.md` that HexDocs may not resolve. |

**Recommended:** at minimum, fix **IN-04** (dep version bump) before merging PR #7 — it's
a copy-paste hazard for early adopters. The other Info items are deferrable.

## Next steps

1. Watch GitHub CI on PR #7 (`gh pr checks 7 --watch`) to confirm the 3 new fix commits stay green
2. Optionally fix IN-04 manually (3 files, ~3 lines each)
3. `gh pr merge 7 --squash --subject "chore: release 1.0.0"`
4. Watch `Release` workflow → tag `v1.0.0` → `Publish to Hex.pm`
5. Open the post-release cleanup PR (remove `release-as`, restore semver cadence) per the runbook
