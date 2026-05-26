# v1.4 Adoption Closure

Updated: 2026-05-26

## Why this thread exists

The repo is materially stronger than its public adopter story. The next milestone should
default to adoption closure before another major resource family: make the shipped `1.3.x`
surface obvious, trustworthy, and easier to evaluate for serious Phoenix SaaS teams.

## Repo-truth findings to preserve

- Planning docs treat v1.3 as shipped on 2026-05-25, but the earlier claim that
  `HEAD` matched the `v1.3` tag is now stale in the current repo state and should
  not be reused as a trust anchor without re-checking git truth.
- The shipped surface already includes File/FileLink, Dispute, CreditNote, Mandate,
  SetupAttempt, Quote, recipes, and the Phoenix webhook quickstart.
- The library now looks closer to **strong / near-done** than to "still building foundation":
  the core Payments, Billing, Checkout, Webhooks, Connect, metering, testing-helper, and
  operator-diagnostic stories are all real in repo truth, with broad unit + integration proof.
- Public truth drift existed at assessment time:
  - `guides/getting-started.md` still tells adopters to install `{:lattice_stripe, "~> 1.2"}`
    even though README and CHANGELOG frame the current published line as `1.3.x`
  - docs-truth regression coverage currently checks README + recipes registration, but does
    not cover `guides/getting-started.md` or the cheatsheet, so high-visibility drift can
    slip without failing the targeted DX proof
  - `CHANGELOG.md` now claims the Getting Started drift was fixed, so the public truth
    story is internally inconsistent until docs and proof are reconciled
- `JTBD-MAP.md` was stale enough to still call several v1.3 families "planned/not shipped".
- Targeted repo checks on 2026-05-26 confirmed the drift posture rather than merely
  repeating archived planning claims:
  - `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/webhook_test.exs`
    passed, confirming the current docs-truth net is still too narrow to catch the
    stale Getting Started install snippet
  - `mix test test/integration/quote_integration_test.exs --only integration` passed,
    reaffirming that Quote routing and the bounded downstream proof remain real while
    the separate Phase `41.1` external follow-through gap stays narrow and honest
  - there is still no shipped `Tax`, `Identity`, `Treasury`, `Issuing`, or `Terminal`
    resource family in `lib/`, so those remain future breadth candidates rather than
    under-documented existing surfaces

## Default v1.4 shape

Treat this as the recommended next milestone unless new adopter evidence overrides it:

1. Refresh release/package/version truth across README, changelog, install snippets, and docs checks.
2. Tighten guide discovery for already-shipped high-leverage surfaces.
3. Add 3-4 flagship recipes/operator guidance slices for already-shipped SaaS flows without
   drifting into Accrue-style orchestration.
4. Update planning truth so milestone selection starts from the real shipped baseline.
5. Keep Phase `41.1` as a narrow follow-through item unless it can be closed opportunistically.

## Done-Enough Bar For v1.4

The milestone is only "done enough" when all of these are true:

- package/version/install truth agrees across README, CHANGELOG, Getting Started,
  cheatsheet, and HexDocs extras
- docs-truth checks fail on first-run onboarding drift, not just README drift
- guide discovery makes already-shipped high-leverage surfaces easy to find
- flagship recipes exist for the most important already-shipped SaaS stories:
  Checkout signup plus portal follow-through, metering runtime plus reconciliation,
  Connect platform flow, and quote-to-billing operator follow-through
- planning truth preserves the explicit `41.1` external-proof boundary instead of
  flattening it into a false full-close story

## Assessment posture

- Working done estimate: roughly **85%** complete for the intended SDK scope.
- Remaining delta type: **important adopter-facing wedges**, not foundational missing surface.
- Primary risk: under-selling or under-explaining what is already shipped.
- Secondary risk: reopening breadth-first work before public truth and support-truth are coherent.
- Current band still looks like **80-89% strong, meaningful wedges remain** rather than
  "near-done/diminishing returns now" because the adopter story still has a first-run
  trust gap and flagship recipe/operator guidance is not yet complete.

## Explicit non-goals

- Do not turn LatticeStripe into a billing engine or app workflow package.
- Do not let a docs milestone become a broad rewrite of every guide.
- Do not let recipe work turn into entitlement logic, dunning policy, or operator UX.
- Do not make Phase `41.1` the entire milestone headline.

## What comes after adoption closure

- Leading code wedge: thin-event webhook support
- Next breadth candidate after that: Tax
- Specialist families like Identity, Financial Connections, Terminal, Issuing, or Treasury
  only if real adopter pull appears

## Graduation candidates

- "When the SDK is already broad and verified, prefer adoption closure before new breadth"
  looks like a reusable cross-project milestone-selection rule.
- "Targeted docs-truth tests are not enough if they miss the first-run install path" looks
  like a reusable DX verification lesson for future library milestones.
- "Flagship recipes should stitch shipped primitives together without turning the SDK
  into an app workflow product" looks like a reusable OSS scope discipline rule.
- "Assessment conclusions should be re-checked against representative source, tests, and
  guides before activating the next milestone" looks like a reusable milestone-start rule.
