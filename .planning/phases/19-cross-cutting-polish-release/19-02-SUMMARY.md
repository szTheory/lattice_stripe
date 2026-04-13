---
phase: 19
plan: 02
subsystem: docs
tags: [docs, guides, connect-split, api-stability, editorial]
requires:
  - 19-01 merged (mix.exs groups_for_modules + @moduledoc false flip)
provides:
  - Three-file Connect guide split (overview / accounts / money-movement) per D-16
  - New guides/api_stability.md documenting D-07/D-08 semver contract
  - Final D-17 :extras ordering (17 entries) in mix.exs
  - Cross-linked Phase 10 guides with "See also" footers
  - Billing + Connect rows in cheatsheet.cheatmd
  - Phase 14 VERIFICATION.md WR-01 stale note resolved (D-03)
affects:
  - Downstream Plans 19-03 (README) and 19-04 (release-please 1.0) — both rely on the final guide layout being locked
tech-stack:
  added: []
  patterns:
    - "Hidden module references in docstrings must be plain text, not backticks (Phase 19 D-04 consequence)"
    - "One 'See also' footer per guide, linking to adjacent guides in the integration journey"
key-files:
  created:
    - guides/connect-accounts.md
    - guides/connect-money-movement.md
    - guides/api_stability.md
  modified:
    - guides/connect.md
    - guides/payments.md
    - guides/checkout.md
    - guides/webhooks.md
    - guides/error-handling.md
    - guides/getting-started.md
    - guides/cheatsheet.cheatmd
    - mix.exs
    - .planning/phases/14-invoices-invoice-line-items/14-VERIFICATION.md
decisions:
  - "Demoted '### N. X' subsection headings in connect-money-movement.md to '## X' since the new file is entirely about money movement (no H1 wrapper duplication)"
  - "api_stability.md lists Request as a retained-public exception (matches Phase 19 Plan 01 Rule 1 deviation)"
  - "Hidden module names in api_stability.md left as plain text, not backticks, to avoid ExDoc hidden-module warnings — same rule Phase 19 Plan 01 already applied"
  - "getting-started.md Next steps added as a new bottom section (not modifying the existing Next Steps section above Common Pitfalls) to avoid touching the 60-second hero per D-21"
metrics:
  completed: 2026-04-13
  duration: ~20 minutes
  tasks: 2/2
  files_modified: 9
  files_created: 3
---

# Phase 19 Plan 02: Guides Editorial Pass Summary

Completed the scoped editorial pass (D-15), split the 577-line `connect.md`
into three files per D-16, published the new `api_stability.md` guide
documenting the D-07/D-08 post-1.0 semver contract, reordered `mix.exs`
`:extras` into the final D-17 seventeen-entry layout, and added "See also"
cross-links plus Billing/Connect rows to close out the Phase 10 guide set
for the v1.0 cut.

## One-liner

Connect guide split into overview + accounts + money-movement, api_stability.md
published with explicit public/internal semver contract, Phase 10 guides
cross-linked via "See also" footers, and `mix docs --warnings-as-errors`
clean — a harmonization pass, not a prose rewrite.

## Tasks Completed

| Task | Name                                                                         | Commit  |
|------|------------------------------------------------------------------------------|---------|
| 1    | Split connect.md into three files and create api_stability.md                | 5f46ee6 |
| 2    | Editorial pass on Phase 10 guides + cheatsheet + mix.exs extras reorder      | bdd092c |

## What Was Built

### Task 1 — Connect split + api_stability.md (D-07, D-08, D-16)

- **`guides/connect.md`** rewritten as a 145-line conceptual overview:
  Standard/Express/Custom comparison table, three charge patterns with
  short inline code samples (direct / destination / separate charge-and-transfer),
  ASCII money-flow diagram, capabilities model paragraph with forward
  link to `connect-accounts.md#handling-capabilities`, and a
  "Where to go next" bullet block.
- **`guides/connect-accounts.md`** (232 lines) — extracted from the first
  half of the old `connect.md` (sections "Acting on behalf" through
  "Webhook handoff"), with a prepended deep-dive header and "See also"
  footer linking back to connect.md + connect-money-movement.md + webhooks.md.
- **`guides/connect-money-movement.md`** (352 lines) — extracted from the
  Money Movement section of the old `connect.md`, with subsection
  headings promoted from `### N. X` to `## X` (no parent H1 needed), a
  prepended deep-dive header, and a "See also" footer.
- **`guides/api_stability.md`** (new, 118 lines) — six-category
  "What is public API" list, explicit "What is NOT public API" list of
  the seven internals hidden by Phase 19 Plan 01 (plus the retained-public
  `Request` exception documented inline), three extension-point
  behaviours (Transport / Json / RetryStrategy), post-1.0 Patch/Minor/Major
  policy with an explicit paragraph noting the override of Phase 11 D-16,
  and a deprecation policy paragraph.

### Task 2 — Editorial pass + :extras reorder + Phase 14 note (D-15, D-17, D-03)

- **`mix.exs`** `:extras` reordered into the final D-17 sequence —
  17 entries ending with `CHANGELOG.md`. The three Connect files are
  contiguous (connect → connect-accounts → connect-money-movement), and
  `api_stability.md` slots between `telemetry.md` and
  `extending-lattice-stripe.md`.
- **`guides/payments.md`** — intro paragraph cross-links to Subscriptions
  and Connect; "See also" footer links to checkout, subscriptions,
  error-handling, webhooks.
- **`guides/checkout.md`** — subscription-mode section links to
  subscriptions.md for lifecycle management; "See also" footer links to
  payments, subscriptions, webhooks.
- **`guides/webhooks.md`** — new "Additional event types" subsection
  listing `account.updated`, `account.application.authorized`,
  `invoice.payment_succeeded` / `invoice.payment_failed`, and
  `customer.subscription.created` / `customer.subscription.deleted` as
  one-line bullets; "See also" footer links to error-handling,
  connect-accounts, subscriptions.
- **`guides/error-handling.md`** — two new subsections
  ("Invoice payment failures", "Connect account errors") with
  `account_invalid` code pattern; "See also" footer links to webhooks,
  invoices, connect.
- **`guides/getting-started.md`** — new bottom "Next steps" block
  linking to subscriptions and connect. The existing "Next Steps"
  section and the 60-second hero are untouched (D-21 respected).
- **`guides/cheatsheet.cheatmd`** — two new sections: **Billing** (Create
  a subscription, Verify a webhook for a Connect account) and
  **Connect** (Create a transfer, Create an onboarding link).
- **`.planning/phases/14-invoices-invoice-line-items/14-VERIFICATION.md`** —
  appended a single-line historical note pointing to commit 0628bbd
  where WR-01 was fixed (D-03).

## Verification

- `mix docs --warnings-as-errors` — PASSED (clean; zero warnings after
  the Rule 1 deviation for api_stability.md module names)
- `mix compile --warnings-as-errors` — PASSED
- Task 1 acceptance: all file-existence and `wc -l` / `grep` checks PASSED
  (connect.md 145 lines, connect-accounts.md 232, connect-money-movement.md
  352, api_stability.md 118; all within D-16 target ranges)
- Task 2 acceptance: all 16 `grep` + `mix` checks PASSED

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] api_stability.md hidden-module backtick warnings**
- **Found during:** Task 2 `mix docs --warnings-as-errors` run
- **Issue:** api_stability.md listed the seven `@moduledoc false`
  internals inside backticks. ExDoc treats backticked FQ module names
  as doc references and errors on hidden modules — the same rule that
  tripped Phase 19 Plan 01 during its docstring clean-up.
- **Fix:** Rewrote the "What is NOT public API" list as plain text
  (`LatticeStripe.FormEncoder` without backticks) and dropped
  `LatticeStripe.Request` from the list entirely since 19-01 retained
  `Request` as public API per its Rule 1 deviation. Added a short
  paragraph explaining the `Request` exception.
- **Files modified:** guides/api_stability.md
- **Commit:** bdd092c (rolled into the Task 2 commit since the fix was
  discovered during Task 2 verification)

## Self-Check

File existence:
- FOUND: guides/connect.md (modified)
- FOUND: guides/connect-accounts.md (created)
- FOUND: guides/connect-money-movement.md (created)
- FOUND: guides/api_stability.md (created)
- FOUND: mix.exs (modified with new :extras order)
- FOUND: guides/payments.md (See also)
- FOUND: guides/checkout.md (See also)
- FOUND: guides/webhooks.md (See also + events list)
- FOUND: guides/error-handling.md (See also + subsections)
- FOUND: guides/getting-started.md (Next steps)
- FOUND: guides/cheatsheet.cheatmd (Billing + Connect sections)
- FOUND: .planning/phases/14-invoices-invoice-line-items/14-VERIFICATION.md (Phase 19 note)

Commits:
- FOUND: 5f46ee6 (Task 1: Connect split + api_stability.md)
- FOUND: bdd092c (Task 2: editorial pass + mix.exs :extras)

## Self-Check: PASSED
