# Phase 19: Cross-cutting Polish & v1.0 Release - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Source:** Advisor-researcher one-shot (4 parallel agents, see `19-ADVISOR-*.md`)

<domain>
## Phase Boundary

LatticeStripe ships v1.0.0 to Hex. Scope: (1) a scoped editorial pass over existing guides to harmonize them across Billing + Connect, (2) a one-pass public API surface audit to lock the stability contract, (3) driving Release Please from 0.x to 1.0.0, (4) an automated 60-second quickstart test that machine-enforces README correctness. Polish is bounded at the API boundary — no cleanup of internal TODOs, refactors, or non-observable items. Treat v1.0 as a surface-stability commitment, not a code-quality commitment.

**Not in scope:** new features, new resource modules, rewriting guides, draining the full prior-phase backlog, deprecation cycles for 2.0.
</domain>

<decisions>
## Implementation Decisions

### Cleanup Scope (from Advisor Q1)

- **D-01:** API-boundary-only cleanup rule. INCLUDE an item iff it is observable from a user's call site — a public name/arity, a return shape, an error type, a `@doc` / `@spec` / `@typedoc`, a telemetry event name, or a NimbleOptions schema key. DEFER everything else (internal TODOs, refactors, test coverage holes, typespec gaps on private functions, prior-phase VERIFICATION warnings that don't cross the API boundary).
- **D-02:** No backlog drain. Prior-phase `<deferred>` blocks and any open non-boundary items roll forward into a v1.1 backlog note in STATE.md — they do not gate v1.0. Ground truth check confirms `grep -E 'TODO|FIXME|XXX|HACK' lib/` returns zero hits, so the cleanup surface lives in planning artifacts, not rotting code.
- **D-03:** WR-01 exception aside. The stale Phase 14 VERIFICATION.md is already noted in memory (fixed in commit 0628bbd) — update that VERIFICATION.md in passing but do not treat it as blocking.

### Public API Surface Audit (from Advisor Q2)

- **D-04:** Flip Phase 10 D-03. At 1.0, mark non-extension-point helpers `@moduledoc false`. Specific modules to hide: `LatticeStripe.FormEncoder`, `LatticeStripe.Request`, `LatticeStripe.Resource`, `LatticeStripe.Transport.Finch`, `LatticeStripe.Json.Jason`, `LatticeStripe.RetryStrategy.Default`, `LatticeStripe.Webhook.CacheBodyReader`, `LatticeStripe.Billing.Guards`. Rationale: visible internals were the right call for 0.x learning; at 1.0 they become a Hyrum's-law liability.
- **D-05:** Keep the three extension-point behaviours VISIBLE in an "Internals" group: `LatticeStripe.Transport`, `LatticeStripe.Json`, `LatticeStripe.RetryStrategy`. These are user extension points — hiding them would break the "bring your own HTTP client" DX story the library is built on.
- **D-06:** No rename sweep. No speculative deprecations for 2.0. No `@deprecated` markers unless they already exist. Keep the surface exactly as it is except for D-04's visibility flip.
- **D-07:** Publish `guides/api_stability.md` (new 14th guide — conceptual, ~100 lines) modeled on Stripe's own SDK versioning page. Semver contract after 1.0: patch = bug fixes, minor = additive features, major = breaking public API. Private modules (`@moduledoc false`) are explicitly excluded from the semver contract.
- **D-08:** Update Phase 11 D-16 to post-1.0 semantics (breaking = major bump, feature = minor bump, fix = patch bump). This is a governance decision, not a code change — document it in the new stability guide and in CHANGELOG.

### Release Mechanics (from Advisor Q1 on release)

- **D-09:** Drive 0.x → 1.0.0 via `release-please-config.json`. Add `"release-as": "1.0.0"` to the `"."` package block. This is the official manifest-releaser mechanism. After v1.0.0 ships, a follow-up PR removes `release-as` and flips `"bump-minor-pre-major": false` so ordinary semver resumes.
- **D-10:** Do NOT use the `Release-As:` commit footer. It is broken under squash-merge workflows (release-please-action #952), and Phase 11 D-35 mandates squash merge. This is a live trap to avoid.
- **D-11:** No pre-1.0 CI re-run, no manual Hex override. Phase 11 automation (D-13..D-15) fires normally — Release Please PR → merge → GitHub release → `mix hex.publish --yes` → HexDocs published.

### CHANGELOG for v1.0.0 (from Advisor Q2 on CHANGELOG)

- **D-12:** Curated Highlights section for v1.0.0 only. Push one `docs(changelog): add v1.0 highlights` commit to the release-please PR branch **before merge** that prepends a ~300-word `### Highlights` section above the auto-generated Features / Bug Fixes bullets. Release Please never rewrites existing version sections, so this is automation-safe.
- **D-13:** Phase 11 D-19's "no manual curation" rule scopes to GitHub Release page bodies only, not CHANGELOG.md. The curated highlights live in CHANGELOG.md (which ships on HexDocs as an extra, Phase 10 D-07).
- **D-14:** Highlights content: 4-sentence narrative of the 0.2 → 1.0 arc — Foundation (Phase 1-11) / Billing (14-16) / Connect (17-18) / Stability commitment. No per-phase bullets in the narrative — auto-generated sections handle those. Pattern matches Req, Oban, Phoenix, stripe-node major-version CHANGELOGs; Ecto is the bullets-only outlier.

### Docs Refresh Scope (from Advisor Q1 on docs)

- **D-15:** Hybrid scoped editorial pass (Advisor Option D). Do NOT rewrite guides. Concrete checklist:
  1. Re-verify code samples in the four Phase-10 guides that overlap Billing/Connect (`payments.md`, `checkout.md`, `webhooks.md`, `error-handling.md`) against stripe-mock.
  2. Add a "See also" footer block to every guide pointing forward/backward in the integration journey.
  3. `payments.md` intro paragraph: "for recurring billing see Subscriptions; for marketplace/platform charges see Connect."
  4. `checkout.md`: verify subscription-mode example matches `subscriptions.md`; cross-link.
  5. `webhooks.md`: add `account.updated`, `account.application.authorized`, `invoice.*`, `customer.subscription.*` to the event-handling examples list (one line each, not full handlers).
  6. `error-handling.md`: add `invoice_payment_failed` and Connect `account_invalid` error patterns.
  7. `cheatsheet.cheatmd`: add rows for "Create a subscription", "Verify a webhook for a Connect account", "Create a transfer", "Create an onboarding link".
  8. `getting-started.md`: one-line "next steps" mentioning Subscriptions + Connect (60-second hero stays PaymentIntent-only per D-18 Phase 10).
  9. Re-order `mix.exs` `:extras` list into the final integration-journey order (D-17 below).
  10. Do NOT touch prose in `invoices.md`, `subscriptions.md`, or `connect.md` sources — they are fresh and post-Billing/Connect-aware.
- **D-16:** Split existing 577-line `connect.md` into three files:
  - `connect.md` (~150 lines, conceptual) — Standard vs Express vs Custom, charge patterns (direct/destination/separate), money-flow diagram, capability model. This is where new users land.
  - `connect-accounts.md` (~250 lines) — lifted from first half of current `connect.md` plus `Stripe-Account` header coverage.
  - `connect-money-movement.md` (~280 lines) — lifted from second half of current `connect.md` plus destination charges and fee reconciliation.
  Rationale: matches Phase 17/18 split, matches Stripe's own API reference split, keeps each under the Phase 10 D-11 400-line ceiling.
- **D-17:** Final `:extras` order in `mix.exs` (14 guides + cheatsheet + CHANGELOG):
  1. getting-started
  2. client-configuration
  3. payments
  4. checkout
  5. invoices
  6. subscriptions
  7. connect (overview)
  8. connect-accounts
  9. connect-money-movement
  10. webhooks
  11. error-handling
  12. testing
  13. telemetry
  14. api-stability *(new, per D-07)*
  15. extending-lattice-stripe
  16. cheatsheet.cheatmd
  17. CHANGELOG.md
- **D-18:** Do NOT merge `invoices.md` + `subscriptions.md`. Do NOT add `billing-overview.md`. Billing is less conceptually surprising than Connect — no conceptual intro needed.

### ExDoc Module Groups (from Advisor Q3 on docs)

- **D-19:** Nine-group ExDoc layout (not the literal six from the roadmap — that reading forces framing modules into domain buckets). Full mapping:
  - **Client & Configuration:** `LatticeStripe`, `Client`, `Config`, `Error`, `Response`, `List`
  - **Payments:** `PaymentIntent`, `Customer`, `PaymentMethod`, `SetupIntent`, `Refund`
  - **Checkout:** `Checkout.Session`, `Checkout.LineItem`
  - **Billing:** `Invoice`, `Invoice.LineItem`, `Invoice.StatusTransitions`, `Invoice.AutomaticTax`, `InvoiceItem`, `InvoiceItem.Period` *(was missing)*, `Subscription`, `Subscription.CancellationDetails`, `Subscription.PauseCollection`, `Subscription.TrialSettings`, `SubscriptionItem`, `SubscriptionSchedule`, `SubscriptionSchedule.Phase`, `SubscriptionSchedule.CurrentPhase`, `SubscriptionSchedule.PhaseItem`, `SubscriptionSchedule.AddInvoiceItem`
  - **Connect:** `Account` + nested (`BusinessProfile`, `Capability`, `Company`, `Individual`, `Requirements`, `Settings`, `TosAcceptance`), `AccountLink`, `LoginLink` *(was missing)*, `BankAccount`, `Card`, `ExternalAccount`, `ExternalAccount.Unknown`, `Transfer`, `TransferReversal`, `Payout`, `Payout.TraceId`, `Balance`, `Balance.Amount`, `Balance.SourceTypes`, `BalanceTransaction`, `BalanceTransaction.FeeDetail`, `Charge` *(moved from Payments — retrieve-only fee reconciliation helper, Phase 18 18-02 intent)*
  - **Webhooks:** `Webhook`, `Webhook.Plug`, `Webhook.Handler` *(was missing)*, `Webhook.SignatureVerificationError` *(was missing)*, `Event`
  - **Telemetry:** `Telemetry` *(split from "Telemetry & Testing")*
  - **Testing:** `Testing`, `Testing.TestClock`, `Testing.TestClock.Owner`, `Testing.TestClock.Error` *(all four were missing)*
  - **Internals:** `Transport`, `Transport.Finch`, `Json`, `Json.Jason`, `RetryStrategy`, `RetryStrategy.Default`, `FormEncoder`, `Request`, `Resource`, `Billing.Guards` *(moved from Billing)*
- **D-20:** Backfill the six modules currently missing from `mix.exs` groups: `LoginLink`, `InvoiceItem.Period`, `Webhook.Handler`, `Webhook.SignatureVerificationError`, `Testing.TestClock`, `Testing.TestClock.Owner`, `Testing.TestClock.Error`.

### README Quickstart (from Advisor Q1 on README)

- **D-21:** Keep Phase 10 D-18 PaymentIntent hero UNCHANGED. Ecosystem survey (Finch, Req, Ecto, Phoenix, Broadway, Oban, Swoosh, Bandit, stripe-node, stripe-python, stripe-ruby) showed 100% single-domain heroes. No tabs, no multi-tier teasers.
- **D-22:** Restructure README feature bullets into grouped Payments / Billing / Connect / Platform sub-sections so v1.0's full scope is visible in the first screenful without inventing untested teaser code. Each sub-section = 3-5 bullets + one link to the relevant guide.
- **D-23:** Add a short "What's new in v1.0" callout block below the badges pointing to CHANGELOG highlights — one sentence, one link.

### Automated 60-second Quickstart Test (from Advisor Q2 on README)

- **D-24:** Add `test/readme_test.exs` — a custom `@tag :integration` test that regex-extracts fenced `elixir` blocks from the README Quick Start section and `Code.eval_string/1`s them against stripe-mock. Reuses Phase 9 stripe-mock container and Phase 11 CI integration-test job. Target ~40 LOC.
- **D-25:** Do NOT use `ExUnit.DocTest.doctest_file/1`. It forces `iex>` prompts in the README hero, which hurts copy-paste DX and conflicts with Phase 9 D-01 (default `mix test` must not require stripe-mock).
- **D-26:** Test runs only in the integration job, so default `mix test` stays stripe-mock-free. This is the machine-enforcement mechanism for Phase 19 success criterion #3 ("README quickstart still passes the 60-second test").

### Claude's Discretion

- Exact wording/length of the Highlights narrative in the v1.0.0 CHANGELOG entry (bounded by ~300 words per D-14)
- Exact regex / parse strategy for the README extractor in `test/readme_test.exs`
- Wording of the `api_stability.md` guide (D-07)
- Exact ordering/wording of the "See also" footers on each guide (D-15 step 2)
- Commit-splitting strategy inside Phase 19's plans (e.g., should doc pass be one commit per guide or one batched commit)
- Whether `Webhook.Handler` is exposed as a public behaviour — verify during audit; drop from Webhooks group if not
- Whether to update Phase 14 VERIFICATION.md in-phase or leave it as a note (D-03)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Advisor Research (this phase)
- `.planning/phases/19-cross-cutting-polish-release/19-ADVISOR-cleanup-api.md` — Cleanup scope + API audit research, precedent from Broadway/Req/Ecto/Phoenix 1.0 cuts
- `.planning/phases/19-cross-cutting-polish-release/19-ADVISOR-release-changelog.md` — Release Please 0.x→1.0.0 mechanics, squash-merge trap, CHANGELOG highlights pattern
- `.planning/phases/19-cross-cutting-polish-release/19-ADVISOR-docs-exdoc.md` — Full 9-group ExDoc mapping, mix.exs drift inventory, guide-split rationale
- `.planning/phases/19-cross-cutting-polish-release/19-ADVISOR-readme-test.md` — README hero ecosystem survey, 60-second test extractor sketch

### Project & Requirements
- `.planning/PROJECT.md` — core value, design philosophy, constraints
- `.planning/REQUIREMENTS.md` — requirement IDs (cross-cutting phase, no new IDs)
- `.planning/ROADMAP.md` §Phase 19 — goal, success criteria, dependency on Phase 18
- `CLAUDE.md` — technology stack, CI matrix, what-not-to-use list

### Prior Phase Context (decisions this phase depends on or overrides)
- `.planning/phases/10-documentation-guides/10-CONTEXT.md` — D-01 (module groups baseline — now superseded by D-19 here), D-03 (internals visibility — now partially overridden by D-04), D-07 (CHANGELOG as ExDoc extra), D-11 (guide length target), D-18..D-23 (README locked)
- `.planning/phases/11-ci-cd-release/11-CONTEXT.md` — D-13..D-15 (Release Please automation), D-16 (pre-1.0 version rule — expires at v1.0 per D-08 here), D-18..D-19 (CHANGELOG/release-notes automation), D-35 (squash merge — informs D-10 here)
- `.planning/phases/09-testing-infrastructure/09-CONTEXT.md` — D-01 (integration tag), D-02 (stripe-mock ports) — both consumed by D-24 here

### Existing Code
- `mix.exs` — current `docs` config, `@version`, `:extras` list, `groups_for_modules` (needs D-17, D-19, D-20 changes)
- `README.md` — current README (Phase 10) — needs D-22, D-23
- `CHANGELOG.md` — existing unreleased entries — needs D-14 Highlights prepended during release-please PR
- `release-please-config.json` — needs `"release-as": "1.0.0"` per D-09
- `lib/lattice_stripe/` — target for D-04 `@moduledoc false` flip
- `guides/` — 13 existing extras + `connect.md` split (D-16) + new `api_stability.md` (D-07)

### External Docs
- https://github.com/googleapis/release-please — `release-as` manifest key (D-09)
- https://github.com/googleapis/release-please-action/issues/952 — squash-merge trap (D-10)
- https://docs.stripe.com/sdks — Stripe SDK versioning page (template for D-07 api_stability guide)
- https://docs.stripe.com/api — canonical Connect domain split (informs D-16 connect.md split)

</canonical_refs>

<specifics>
## Specific Ideas

- The four advisor files contain copy-pasteable snippets (release-please config delta, README skeleton, ExDoc groups block, readme_test.exs sketch). The planner should read them verbatim rather than re-derive.
- Cleanup ground truth: `grep -E 'TODO|FIXME|XXX|HACK' lib/` returns zero hits at commit `3ceb913`. The cleanup surface is entirely in planning artifacts and mix.exs drift, not in source code.
- mix.exs drift inventory: 6 modules missing from groups, 1 mis-grouped (`Charge` in Payments → Connect), 1 over-exposed (`Billing.Guards` → Internals + `@moduledoc false`).
- Phase 11 D-16's pre-1.0 version rule actively conflicts with a clean v1.0 cut — the override in D-08 must be explicit in the plan and the new `api_stability.md` guide.
- Precedent worth citing in the v1.0.0 Highlights: Req, Oban, Phoenix, stripe-node all write narrative highlights at major versions; Ecto is the outlier with bullets only.
- Plan-splitting hint: this phase naturally decomposes into (1) API audit + `@moduledoc false` flip + mix.exs drift fix, (2) guide editorial pass + connect.md split + api_stability.md, (3) README restructure + readme_test.exs, (4) release-please config + 1.0.0 CHANGELOG highlights + release cut. Likely 4 plans.

</specifics>

<deferred>
## Deferred Ideas

- **Deprecation cycle for 2.0:** no speculative `@deprecated` markers (D-06). When a 2.0 is needed, open a new milestone.
- **Full guide rewrite with uniform template:** rejected (D-15). Cost > benefit at 1.0.
- **`billing-overview.md` meta-guide:** rejected (D-18). Billing concepts are self-explanatory.
- **Merging invoices.md + subscriptions.md:** rejected (D-18). Separate deep-dives are clearer.
- **Tabbed or multi-tier README quickstart (Options B/C from advisor):** rejected (D-21). Zero ecosystem precedent.
- **`ExUnit.DocTest.doctest_file/1` for README:** rejected (D-25). Forces `iex>` prompts that hurt copy-paste.
- **Internal refactors / typespec gap fill / test coverage expansion:** out of scope per D-01. Rolls to v1.1 backlog.
- **Draining prior-phase `<deferred>` blocks:** out of scope per D-02. Rolls to v1.1 backlog.
- **CODEOWNERS, stale bot, Discussions:** explicitly out per Phase 11 D-43..D-44. Unchanged.

</deferred>

---

*Phase: 19-cross-cutting-polish-release*
*Context gathered: 2026-04-13 via four parallel advisor-researcher agents*
