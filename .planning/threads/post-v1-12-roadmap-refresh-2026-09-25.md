# Post-v1.12 Roadmap Refresh

**Updated:** 2026-09-25

**Status:** Assessment complete; reactive maintenance; no milestone started

## Decision

LatticeStripe is near-done for its intended mainstream Stripe SDK scope. Keep it in reactive
maintenance and open another feature milestone only when concrete adopter, Stripe API,
security, reliability, or CI-cost evidence justifies the ongoing implementation and proof
cost. The roadmap horizons are candidates, not commitments.

The prior next-milestone assessment ranked API Contract Freshness and Adopter Proof highest.
That work shipped in v1.12: versioned Stripe drift triage, selected Invoice and Refund typed
fields, and one synthetic Phoenix adopter covering common SaaS, B2B invoicing, usage, Connect,
and webhook contracts. Package 2.3.0 was verified on Hex, GitHub Releases, and HexDocs;
`main` is synchronized and clean. Thus the leading previously identified wedge is closed.

## Near / Mid / Long Horizon

- **Near:** Reactive maintenance: confirmed defects, security needs, and stable Stripe changes
  affecting supported high-value resources. Keep package/docs/release truth aligned and CI
  green. Do not reopen work from raw drift counts or acknowledged edge debt alone.
- **Mid:** Evidence-triggered confidence work: a named adopter-blocking contract, material
  reliability/privacy issue, or recurring CI cost. Select property tests only for a named
  high-risk pure invariant; extend the shared Phoenix adopter only for a distinct reusable
  contract or recurring failure mode.
- **Long:** Specialist Stripe families only for a named adopter job, stable contract, clear
  SDK/application boundary, and maintainable proof. Industry policy and admin/operator UI
  remain in adopting products, including Accrue, not in this headless SDK.

## Done-Enough Assessment

The project is near the point of diminishing returns for planned feature work. Its mainstream
payments, billing, Connect, tax, metering, entitlement, webhook, testing, and operator-guidance
surface is established, and v1.12 addressed the concrete freshness/adopter-proof gap. The
earlier estimate of 94–96% was a qualitative judgment before v1.12 shipped; do not turn that
estimate into a progress metric. The practical stop signal is that no evidence-backed gap
currently warrants a new milestone. Continue maintenance and reopen scope when a trigger fires.

The v1.12 audit has no requirement or integration blockers. It records two optional adopter
edge assertions and three Nyquist artifact status gaps as bounded debt. Its disposition says
not to create cleanup work absent adopter evidence or a concrete failure.

## Provenance

Assessment grounded in `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`,
`.planning/REQUIREMENTS.md`, `.planning/MILESTONES.md`, `.planning/JTBD-MAP.md`, the v1.12
assessment and audit/integration records, README and scope/operator guides, CI configuration,
Phoenix adopter tests, and shipped v1.12 release evidence. The repository was on clean,
synchronized `main` at `ebb16cb6` when refreshed. The v1.12 audit and prior assessment are
historical evidence; perform fresh checks before any future release or milestone decision.

No personal data or secret values are recorded here.
