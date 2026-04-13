# Advisor Research — Docs Refresh + ExDoc Groups

**Phase:** 19 (Cross-cutting Polish & v1.0 Release)
**Gray area:** Docs Refresh Scope + ExDoc Module Groups
**Researched:** 2026-04-13

## Current State Snapshot

Before picking options, pin down what already exists (verified against `mix.exs`, `guides/`, and `lib/lattice_stripe/`):

**Guides on disk (13 extras, not 9):**
```
getting-started.md       217 lines
client-configuration.md  304 lines
payments.md              322 lines
checkout.md              266 lines
invoices.md              556 lines   <- added Phase 14
subscriptions.md         407 lines   <- added Phase 15/16
connect.md               577 lines   <- added Phase 17/18
webhooks.md              423 lines
error-handling.md        310 lines
testing.md               476 lines
telemetry.md             436 lines
extending-lattice-stripe.md 463 lines
cheatsheet.cheatmd       235 lines
```
Total ~4,992 lines. So the "9 guides" phrasing in the prompt is stale — Billing + Connect guides already exist as single top-level guides. Phase 19's job is *polishing what is there*, not greenfielding.

**ExDoc groups currently in `mix.exs` (8 groups):**
Core, Payments, Checkout, Billing, Connect, Webhooks, "Telemetry & Testing", Internals.

**Drift and gaps vs current lib tree:**
- `LatticeStripe.Charge` is mapped under Payments, but it was introduced in Phase 18 as a retrieve-only fee-reconciliation helper — conceptually Connect.
- `LatticeStripe.LoginLink` and `LatticeStripe.InvoiceItem.Period` have module files but aren't listed in any group.
- `LatticeStripe.Testing.TestClock` + `Testing.TestClock.Owner` + `Testing.TestClock.Error` exist under `lib/lattice_stripe/testing/test_clock/` but are not in any ExDoc group.
- `LatticeStripe.Webhook.Handler`, `Webhook.CacheBodyReader`, `Webhook.SignatureVerificationError` exist but aren't listed — Handler is public API, the other two are implementation details.
- `LatticeStripe.Billing.Guards` is exposed under Billing, but is a private guard-clause helper module (`@moduledoc false` candidate — belongs in Internals or hidden).
- `LatticeStripe.RetryStrategy.Default` is in Internals already.

**Roadmap Phase 19 target (success criterion #2):**
> Module groups in ExDoc config reflect final public surface
> (Payments / Billing / Connect / Webhooks / Testing / Telemetry)

That's six groups. Current config has eight. The delta implies: (a) drop "Core" into something else (or rename), (b) split "Telemetry & Testing" into two peer groups, (c) probably hide or fold "Internals". Also missing from the roadmap list: Checkout. Either Checkout folds into Payments or the list is incomplete.

---

## Q1: Guide Refresh Strategy

### Context
The 13 guides are in mixed states:
- **Pre-Billing/Connect (Phase 10, ~6 months old in project time):** getting-started, client-configuration, payments, checkout, webhooks, error-handling, testing, telemetry, extending. Written before Billing/Connect existed — examples don't cross-reference Invoice/Subscription/Account, cheatsheet has no subscription or connect row.
- **Post-Billing (Phase 14/15/16):** invoices, subscriptions — fresh and consistent with Phase 14-16 patterns but never harmonized with payments.md tone/structure.
- **Post-Connect (Phase 17/18):** connect.md (577 lines, large — it's absorbing both Connect Accounts and Money Movement).

Risks if we do too little: guides feel bolted-on; cross-links point only backward; `payments.md` never mentions "for recurring charges, see Subscriptions"; README/cheatsheet don't surface the new surface area; new users on v1.0 land on docs that look like a 0.2-era payments library.

Risks if we do too much: rewrite introduces regressions, breaks working code samples, invalidates external links from blog posts / search results that cite old section anchors, and consumes effort that should go into release cut.

### Options

**Option A — Full end-to-end rewrite for v1.0 consistency**
- *Pros:* Uniform voice/tone, one pass catches all Billing/Connect cross-references, chance to re-template every guide against a new "v1.0 guide skeleton" (intro / when-to-use / step-by-step / pitfalls / see-also).
- *Cons:* Highest effort, highest diff blast radius, highest regression risk on working code samples (Stripe API shapes shift subtly — a rewritten example that wasn't run against stripe-mock can ship broken). Throws away 6 months of incremental polish. Breaks deep-link anchors that may be cited.
- *Precedent:* Major framework rewrites (Phoenix 1.6 → 1.7 guides, Ecto 2 → 3 guides) did this — but those rewrites were forced by breaking API changes. LatticeStripe's API is additive from 0.2 → 1.0, so the forcing function is weaker.

**Option B — Diff-based updates only where Billing/Connect changed things**
- *Pros:* Smallest diff, lowest regression risk, preserves deep-link anchors. Respects the fact that `invoices.md`, `subscriptions.md`, `connect.md` are already post-Billing-and-Connect-aware. Forces author to make a decision per guide instead of blanket rewrites.
- *Cons:* Tone drift stays. Guides written in Phase 10 and guides written in Phase 14-18 keep slightly different voices. Cross-references may still feel one-directional.
- *Precedent:* How Twilio, Stripe's own docs, and AWS SDK docs typically evolve — continuous diff-based updates with an editorial pass on cross-links. AWS SDK v3 migration guides are diff-oriented, not rewrites of each service doc.

**Option C — Targeted section additions (append "Billing integration" / "Connect integration" sections at end of each guide)**
- *Pros:* Explicit, auditable, each guide gains a clearly-labeled v1.0 addendum. Very low regression risk.
- *Cons:* Creates "tacked-on" feel — the guide body still reads like 0.2-era, with a tail section that says "oh and by the way, there's also...". Violates the integration-journey ordering principle (D-02) because the interesting Billing/Connect content ends up at the bottom of the wrong guides.
- *Precedent:* This is what bad library docs often look like ("see also: v2 features"). Not recommended by any major SDK docs team.

**Option D — Hybrid: diff-based + one pass over 4 "hot" cross-reference points + uniform frontmatter**
- *Pros:* Bounded effort, highest DX win per minute of work. Identify the ~4 places where Phase 10 guides need to *acknowledge* Billing/Connect (e.g. payments.md mentions Subscriptions for recurring, checkout.md mentions subscription-mode, webhooks.md mentions Connect account.* events, error-handling.md includes Invoice/Subscription error patterns). Plus a pass to unify the "Common Pitfalls" section naming, add "See also" footers to every guide, refresh the cheatsheet with a Billing row and a Connect row, and re-order mix.exs extras into the final integration-journey sequence.
- *Cons:* Requires deliberate scoping — easy to balloon into Option A.
- *Precedent:* Stripe's own docs team does this between minor revisions — they call it an "editorial pass" rather than a rewrite.

### Recommendation (Q1): **Option D — Hybrid diff + editorial pass**

Do a scoped editorial pass with a crisp checklist:
1. Re-verify every code sample in the 4 Phase-10 guides that overlap Billing/Connect (payments, checkout, webhooks, error-handling) still compiles and runs against stripe-mock. Nothing else.
2. Add a "See also" footer block to every guide pointing forward/backward in the integration journey.
3. In payments.md: one paragraph in the intro saying "for recurring billing, see Subscriptions; for marketplace/platform charges, see Connect."
4. In checkout.md: verify the subscription-mode example still matches what Subscriptions guide recommends, and cross-link.
5. In webhooks.md: add `account.updated`, `account.application.authorized`, `invoice.*`, and `customer.subscription.*` to the event-handling examples list (text-only, one line each, not full handlers).
6. In error-handling.md: add the Billing-specific `invoice_payment_failed` pattern and the Connect `account_invalid` pattern.
7. In cheatsheet.cheatmd: add rows for "Create a subscription", "Verify a webhook for a Connect account", "Create a transfer", "Create an onboarding link".
8. In getting-started.md: the 60-second test stays payments-focused (D-18 is locked), but add a one-line "next steps" mentioning Subscriptions + Connect.
9. Re-order `mix.exs` `:extras` list into the final integration-journey order (see Q2).
10. Do NOT rewrite prose in invoices.md, subscriptions.md, connect.md — they are fresh.

This captures 90% of the DX win of Option A at 20% of the effort and almost none of the regression risk. The bar is "a new v1.0 reader never feels the seam between Phase 10 docs and Phase 14-18 docs."

---

## Q2: New Billing + Connect Guides

### Context
This question is partially moot — `invoices.md`, `subscriptions.md`, and `connect.md` already exist. The real questions are:

- **Q2a:** Is one combined `connect.md` (577 lines) the right shape, or should it split into `connect-accounts.md` + `connect-money-movement.md`?
- **Q2b:** Should `invoices.md` (556 lines) and `subscriptions.md` (407 lines) merge into a single `billing.md`, stay separate, or get a sibling `billing-overview.md` that cross-links?
- **Q2c:** Final ordering of the extras list in mix.exs?

### Options

**Option A — Status quo (13 extras, connect and billing each single-file)**
- *Pros:* No work. Extras list just gets reordered.
- *Cons:* `connect.md` at 577 lines is the single longest guide. It has to do a lot (Standard vs Express vs Custom, account lifecycle, account links, external accounts, transfers, payouts, destination charges, balance). HexDocs sidebar treats each extra as one flat entry — there's no nesting — so a 577-line guide has poor in-page discoverability even with a TOC.
- *Precedent:* Swoosh keeps one mailer adapter guide per adapter; Oban keeps multiple small "use case" guides; Phoenix has one `request_lifecycle.md` regardless of length. No consistent pattern in the ecosystem — depends on how much the concepts interlock.

**Option B — Split Connect into two guides: `connect-accounts.md` + `connect-money-movement.md`. Keep Billing as two guides (invoices + subscriptions).**
- *Pros:* Matches the phase split (17 = Accounts, 18 = Money Movement) which was made intentionally for reviewability. Matches Stripe's own API reference split (Connect → Accounts / Connect → Transfers / Connect → Payouts). Each guide stays ~300 lines, which matches D-11 (200-400 lines target). Readers who only need onboarding can stop after guide 1; readers who need payouts jump to guide 2.
- *Cons:* More files to maintain in sync. Marginal cross-link overhead. 14 total extras instead of 13.
- *Precedent:* stripe-node docs, stripe-python docs, and Stripe's official API reference all split Connect into sub-sections (Accounts, Account Links, Transfers, Payouts, Application Fees, Balance, External Accounts). stripe-java and stripe-go each use ServiceClasses grouped similarly. The single-file approach is the outlier.

**Option C — Add a `billing-overview.md` meta-guide that introduces the Billing journey, then invoices + subscriptions as deep dives.**
- *Pros:* Gives readers a conceptual map (one-off vs recurring, how invoices relate to subscriptions, proration, test clocks). Parallels Checkout's "there are three modes" intro.
- *Cons:* Risks being a fluff page. If invoices.md and subscriptions.md each have strong intros, an overview is redundant.
- *Precedent:* Phoenix has "Overview" style guides (Request Lifecycle) that are purely conceptual — they work because the content is genuinely cross-cutting. A billing-overview would have to earn its place.

**Option D — Add a `connect-overview.md` meta-guide, keep connect-accounts + connect-money-movement as deep dives.**
- *Pros:* Connect genuinely needs a conceptual intro — the three account types (Standard/Express/Custom), the charge patterns (direct/destination/separate), and the money-flow model are not obvious to newcomers. This is exactly where an overview earns its place.
- *Cons:* Extra file. More cross-links to maintain.
- *Precedent:* Stripe's own Connect docs have a "Connect overview" page before any API reference. AWS service docs universally have a "How it works" page before API reference.

### Final Guide List (Recommended — 14 extras, integration-journey order)

```
1.  getting-started.md              (install → first API call in 60s)
2.  client-configuration.md         (multi-client, per-request overrides, Stripe-Account header)
3.  payments.md                     (one-off PaymentIntents — core charging path)
4.  checkout.md                     (hosted Checkout — payment/subscription/setup modes)
5.  invoices.md                     (standalone invoicing — Phase 14)
6.  subscriptions.md                (recurring billing, schedules, proration — Phase 15/16)
7.  connect.md                      (Connect overview — conceptual intro — NEW, ~150 lines)
8.  connect-accounts.md             (Standard/Express/Custom onboarding, account links — split from current connect.md)
9.  connect-money-movement.md       (transfers, payouts, destination charges, balance, fees — split from current connect.md)
10. webhooks.md                     (signature verification, Plug, event handling)
11. error-handling.md               (all error types, retry semantics)
12. testing.md                      (Mox patterns, stripe-mock, TestClock helpers)
13. telemetry.md                    (event catalog, observability stack integration)
14. extending-lattice-stripe.md     (custom Transport/JSON/RetryStrategy)
+   cheatsheet.cheatmd              (quick-reference extra, pinned to end)
+   CHANGELOG.md                    (pinned to end, under Changelog group)
```

### Recommendation (Q2): **Option B + Option D (hybrid)**

Split current `connect.md` into three files: a thin `connect.md` overview (~150 lines, conceptual — Standard vs Express vs Custom, charge patterns, money-flow diagram, capability model), `connect-accounts.md` (~250 lines, lifted from the first half of current connect.md plus D-03 Stripe-Account header coverage), `connect-money-movement.md` (~280 lines, lifted from the second half of current connect.md plus destination charges + fee reconciliation).

Do NOT merge invoices.md + subscriptions.md, and do NOT add a `billing-overview.md`. Rationale: Billing is less conceptually surprising than Connect — developers know what an invoice and a subscription are. Connect is where a conceptual intro genuinely reduces the time-to-understanding.

Net change: 13 extras → 14 extras (split connect into 3, everything else stays). Matches Stripe's own docs structure, matches Phase 17/18 split, keeps each guide under the 400-line D-11 ceiling.

---

## Q3: Final ExDoc Module Groups

### Context

Target from roadmap: "Payments / Billing / Connect / Webhooks / Testing / Telemetry" (six groups).
Current config has eight groups.
Missing from the roadmap list: **Core** (LatticeStripe, Client, Config, Error, Response, List) and **Checkout** (Session, LineItem) and **Internals** (behaviours, helpers).

The roadmap list is almost certainly aspirational shorthand, not a literal instruction to delete Core/Checkout/Internals. A developer who pattern-matches on `%LatticeStripe.Error{}` or calls `LatticeStripe.Client.new!/1` needs those modules *findable*. The question is what to call the groups.

### Options

**Option A — Keep eight groups as-is, just fill in the drift.**
- *Pros:* Minimum churn. All current module-to-group mappings stay valid.
- *Cons:* Doesn't match the roadmap success criterion language. "Telemetry & Testing" as a combined group sells both short — Testing deserves its own header now that `LatticeStripe.Testing.TestClock` exists as a real public surface.

**Option B — Roadmap-literal: exactly six groups (Payments / Billing / Connect / Webhooks / Testing / Telemetry).**
- *Pros:* Matches roadmap wording.
- *Cons:* Where do LatticeStripe (top-level), Client, Config, Error, Response, List, Checkout.Session, Checkout.LineItem, Transport, Json, RetryStrategy, FormEncoder, Request, Resource go? Either they disappear (bad — they're public API) or they get forced into Payments (bad — they're not payments-specific). Literal interpretation breaks DX.

**Option C — Eight groups, refined: promote Checkout and split Telemetry from Testing, fold "Core" into a renamed "Client & Configuration" top, fix drift.**
- *Pros:* Matches the roadmap *spirit* (six domain groups: Payments/Billing/Connect/Checkout/Webhooks/Telemetry/Testing) plus a framing "Client & Configuration" group that mirrors how the getting-started and client-configuration guides open. Each group tells a reader where to look. Testing gets its own header, matching its new scope. Internals stays visible per D-03 (never `@moduledoc false` for behaviours — users who want to implement Transport need to see it).
- *Cons:* Nine groups instead of six. More sidebar noise. Some users will find Internals distracting.
- *Precedent:* Ecto uses ~6 conceptual groups (Repo / Schema / Query / Changeset / Migration / Adapters). Oban uses ~5 (Oban, Job, Testing, Notifiers, Plugins/Pro). Phoenix uses ~5. A payment SDK that spans 30+ modules across 6 Stripe domains plausibly needs 8-9 — the "right" number scales with public surface area.

**Option D — Five domain groups + one "Framework" group + hide Internals behind @moduledoc false on non-behaviour helpers.**
- *Pros:* Cleanest sidebar. Closest literal read of the roadmap.
- *Cons:* Violates D-03 (Phase 10 explicitly decided against hiding internals). Hiding FormEncoder + Request + Resource removes them from docs entirely, so when users hit an error like `LatticeStripe.FormEncoder.encode/1` in a stacktrace, HexDocs search returns nothing. Breaks observability. Also reverses a locked Phase 10 decision — would need to be raised as an ADR, not a quiet flip.
- *Precedent:* Most Elixir libraries DO mark helpers as `@moduledoc false`. But most Elixir libraries don't have a documented "bring your own Transport" extensibility story. LatticeStripe's behaviour-based design requires the behaviours to be documented.

### Recommendation (Q3): **Option C — nine groups, refined**

Below is the full final grouping with every module in the current `lib/lattice_stripe/` tree explicitly mapped. Delta markers: **[+]** added vs current, **[-]** removed vs current, **[>]** moved vs current.

```elixir
groups_for_modules: [
  # --- Framing: how to construct a client and handle results ---
  "Client & Configuration": [
    LatticeStripe,                      # top-level convenience module
    LatticeStripe.Client,
    LatticeStripe.Config,
    LatticeStripe.Error,
    LatticeStripe.Response,
    LatticeStripe.List
  ],

  # --- Domain: one-off payments ---
  Payments: [
    LatticeStripe.PaymentIntent,
    LatticeStripe.Customer,
    LatticeStripe.PaymentMethod,
    LatticeStripe.SetupIntent,
    LatticeStripe.Refund
    # [>] LatticeStripe.Charge moved to Connect (retrieve-only, fee reconciliation)
  ],

  # --- Domain: hosted Checkout ---
  Checkout: [
    LatticeStripe.Checkout.Session,
    LatticeStripe.Checkout.LineItem
  ],

  # --- Domain: Billing (Phase 14-16) ---
  Billing: [
    LatticeStripe.Invoice,
    LatticeStripe.Invoice.LineItem,
    LatticeStripe.Invoice.StatusTransitions,
    LatticeStripe.Invoice.AutomaticTax,
    LatticeStripe.InvoiceItem,
    LatticeStripe.InvoiceItem.Period,       # [+] was missing
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
    # [-] LatticeStripe.Billing.Guards -> mark @moduledoc false, move to Internals
    #     (it's a `defguard` helper, not a public resource module)
  ],

  # --- Domain: Connect (Phase 17-18) ---
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
    LatticeStripe.LoginLink,                 # [+] was missing
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
    LatticeStripe.Charge                     # [>] from Payments — retrieve-only,
                                             #     exists for fee reconciliation
                                             #     (Phase 18 18-02 plan intent)
  ],

  # --- Domain: Webhooks ---
  Webhooks: [
    LatticeStripe.Webhook,
    LatticeStripe.Webhook.Plug,
    LatticeStripe.Webhook.Handler,           # [+] was missing — public behaviour
    LatticeStripe.Webhook.SignatureVerificationError, # [+] public error type
    LatticeStripe.Event
    # LatticeStripe.Webhook.CacheBodyReader stays @moduledoc false — pure internal
  ],

  # --- Cross-cutting: Telemetry (separated from Testing) ---
  Telemetry: [                               # [>] split from "Telemetry & Testing"
    LatticeStripe.Telemetry
  ],

  # --- Cross-cutting: Testing helpers + TestClock ---
  Testing: [                                 # [>] split from "Telemetry & Testing"
    LatticeStripe.Testing,
    LatticeStripe.Testing.TestClock,         # [+] was missing
    LatticeStripe.Testing.TestClock.Owner,   # [+] was missing
    LatticeStripe.Testing.TestClock.Error    # [+] was missing
  ],

  # --- Extensibility behaviours + impls — visible per D-03 ---
  Internals: [
    LatticeStripe.Transport,                 # behaviour
    LatticeStripe.Transport.Finch,           # default impl
    LatticeStripe.Json,                      # behaviour
    LatticeStripe.Json.Jason,                # default impl
    LatticeStripe.RetryStrategy,             # behaviour
    LatticeStripe.RetryStrategy.Default,     # default impl
    LatticeStripe.FormEncoder,
    LatticeStripe.Request,
    LatticeStripe.Resource,
    LatticeStripe.Billing.Guards             # [>] moved from Billing; guard helper
  ]
]
```

**Module-level actions implied:**
1. `LatticeStripe.Webhook.CacheBodyReader` → confirm `@moduledoc false` (already is).
2. `LatticeStripe.Billing.Guards` → decide: either keep public with a refined @moduledoc and leave in Billing, OR mark `@moduledoc false` and move to Internals. Recommendation: Internals (it's a `defguard` helper that users don't call directly). Verify first that no guide documents it.
3. Every module now listed in a group but currently missing a @moduledoc (TestClock subs especially) gets one during the docs pass.
4. Confirm `LatticeStripe.Webhook.Handler` is a public behaviour — if not, drop it from Webhooks group.

**Why nine groups, not six:**
- Six groups (the literal roadmap reading) forces Core + Checkout + Internals into domain buckets where they don't belong. A developer looking for `Client.new!/1` under "Payments" is a failed information scent.
- Nine groups still scans cleanly: the sidebar has ~30 groups' worth of visual budget before fatigue sets in (see stripity_stripe, Oban Pro, Phoenix.LiveView which all exceed six).
- Each group answers one question: "how do I construct a client?" / "how do I charge a card?" / "how do I use hosted Checkout?" / "how do I bill recurring?" / "how do I run a marketplace?" / "how do I verify webhooks?" / "how do I observe requests?" / "how do I test my integration?" / "how do I extend the library?"

---

## Executive Recommendation

For Phase 19 docs polish, pursue a scoped editorial pass (Option D from Q1) rather than a rewrite — re-verify the four Phase-10 guides that overlap Billing/Connect against stripe-mock, add bidirectional "See also" footers, cross-link payments→subscriptions and checkout→subscriptions, extend webhooks/error-handling examples to cover Billing and Connect events, and refresh the cheatsheet with four new rows. Split the 577-line `connect.md` into a thin conceptual `connect.md` overview plus `connect-accounts.md` + `connect-money-movement.md` deep dives (matching Phase 17/18's own split and Stripe's own API reference structure), keep `invoices.md` and `subscriptions.md` separate, and land at 14 guide extras in integration-journey order. For ExDoc module groups, adopt a nine-group layout — Client & Configuration / Payments / Checkout / Billing / Connect / Webhooks / Telemetry / Testing / Internals — which honors the roadmap's six-domain intent while keeping the framing modules (Client, Config, Error) and extensibility behaviours (Transport, Json, RetryStrategy) findable per D-03; along the way, move `Charge` from Payments to Connect (it's a Phase 18 fee-reconciliation helper), move `Billing.Guards` from Billing to Internals as `@moduledoc false`, and backfill the six module mappings currently missing from `mix.exs` (`LoginLink`, `InvoiceItem.Period`, `Webhook.Handler`, `Webhook.SignatureVerificationError`, and the three `Testing.TestClock` modules).

## Sources
- [Ecto on HexDocs](https://hexdocs.pm/ecto/Ecto.html)
- [Phoenix on HexDocs](https://hexdocs.pm/phoenix/Phoenix.html)
- [Oban on HexDocs](https://hexdocs.pm/oban/Oban.html)
- [stripity_stripe on HexDocs](https://hexdocs.pm/stripity_stripe/readme.html)
- [Broadway on HexDocs](https://hexdocs.pm/broadway/Broadway.html)
- [Stripe API Reference](https://docs.stripe.com/api) — canonical domain taxonomy (Core Resources / Payment Methods / Products / Checkout / Billing / Connect / Fraud / Issuing / Terminal / Treasury / Tax / Reporting / Webhooks)
- [stripe-python on GitHub](https://github.com/stripe/stripe-python) — v8+ `StripeClient` resource-service organization, versioned namespaces
- [Stripe SDKs index](https://docs.stripe.com/sdks) — cross-SDK documentation conventions
