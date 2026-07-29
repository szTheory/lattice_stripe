---
name: lattice-verification-policy
description: Verification policy for LatticeStripe — what may be proven by an automated check versus what genuinely needs a human. Use when classifying deliverables in a SUMMARY coverage block, when deciding whether a phase needs human verification, or when planning must-have truths.
---

<objective>
LatticeStripe is a headless Elixir Hex library. Most of the generic "a human must look at
this" categories do not apply to it, and the ones that do apply are a short, closed list.

This skill exists so verification is *narrowed by evidence*, never softened. It has one
governing rule, and everything else follows from it:

**The way to eliminate a human verification item is to write the test. Never to reclassify
the deliverable.**

If a deliverable cannot be proven by a named, passing, executable check, it stays
`human_judgment: true`. That is not a failure of this policy — it is the policy working.
</objective>

<repo_shape>
Facts about this repository that determine which verification categories are live:

- **No UI.** No components, no screens, no CSS, no browser. Visual-appearance and
  visual-regression checks are structurally inapplicable.
- **No user flow.** Adopters call functions from their own application code. There is no
  click-path, no navigation, no session. "Complete the user flow" has no referent here.
- **No real-time behaviour.** No sockets, no LiveView, no presence, no streaming UI. The
  library is request/response over HTTP plus a webhook verification Plug.
- **No performance-feel surface.** There is nothing a human perceives as fast or slow.
  Performance claims here are throughput and allocation, which are measured, not felt.
- **One external service: Stripe.** It is reached exclusively through the
  `LatticeStripe.Transport` behaviour, which is Mox-mocked in unit tests
  (`test/test_helper.exs`) and exercised for real against the official `stripe-mock`
  OpenAPI server in the `integration` CI lane. "Needs a human to check the external
  integration" is already covered by those two seams.

Four of the six generic "always needs human" categories are therefore inapplicable *by
construction*, not by assertion. State the reason above rather than simply skipping them.
</repo_shape>

<still_needs_a_human>
This is a CLOSED list. If a verification item does not fall into one of these, it must be
converted into a test rather than escalated to a person.

1. **A one-way public-API decision not already covered by the API surface lock.** Module
   and function names become semver-covered at the next Hex tag. The lock
   (`priv/api/current.txt`) turns "do you accept this API?" into a reviewable PR diff, so
   most of this category is already mechanical — but a genuinely novel naming or shape
   decision, made for the first time, is a human call.

2. **A claim about Stripe's wire format with no provenance.** "Stripe returns X here" needs
   either a verbatim-quoted payload from Stripe's published docs with a source comment, or
   a passing `stripe-mock` integration test. An unsourced wire-shape claim is exactly the
   kind of thing that ships wrong and is never caught.

3. **Code and a recorded decision disagreeing.** If the implementation contradicts a
   decision in `.planning/`, a `COVERAGE.md` rationale, or a guide, a human resolves which
   one is wrong. Do not silently make the document match the code.
</still_needs_a_human>

<standing_locks>
These checks already exist and are green. A verifier may CITE them as evidence instead of
re-deriving the underlying claim by hand:

| Lock | What it makes impossible |
|---|---|
| `test/lattice_stripe/api_surface_lock_test.exs` + `priv/api/current.txt` | A public module, function, arity, struct field, type, callback or protocol impl changing without a visible diff. Catches `@doc false` privatization and deleted default args. |
| `test/lattice_stripe/docs_truth_test.exs` (totality guard) | A public module landing in no ExDoc group, or a group naming a module that does not exist. |
| `test/lattice_stripe/testing/wrapper_completeness_test.exs` | A public fixture object type shipping with no typed-wrapper decision, and an opt-out reason that is factually false. |
| `test/lattice_stripe/object_types_test.exs` (triage invariant) | A new `@object_map` row silently flipping `Webhook.fetch_related_object/3` from fail-fast to a doomed GET. |
| `test/lattice_stripe/docs_truth_test.exs` (prose locks) | Guides drifting from the shipped surface. |
| `mix lattice_stripe.check_drift` (scheduled) | The Stripe OpenAPI spec moving away from the registry. |

When one of these covers a deliverable, the coverage entry should reference the specific
test name and set `human_judgment: false`. That is a *stronger* claim than a human eyeball,
because it re-runs on every commit.
</standing_locks>

<authoring_coverage_blocks>
For every deliverable in a `*-SUMMARY.md` `coverage:` block:

1. Find or write the executable check that proves it. Prefer an existing standing lock.
2. Record it as a `verification` entry with a real `ref` — a test file plus the test name,
   or a command with its observed result. `ref` values are read by humans later; make them
   locatable.
3. Only then set `human_judgment: false`.

A deliverable with no `verification` entries, or with any entry not `status: pass`, cannot
auto-pass — that is enforced mechanically in `gsd-tools`, not by good intentions. Do not
attempt to work around it. If you find yourself wanting to, the honest move is to write the
missing test.

**Anti-pattern to avoid, with a real example.** Phase 65 shipped a `COVERAGE.md` opt-out
claiming OBJ-02 was satisfied "for every fixture that has a `from_map/1` to wrap." Both
functions it implied were missing actually existed. Nothing checked the rationale, so the
false claim shipped and a real gap stayed invisible. The fix was not a better review — it
was `wrapper_completeness_test.exs`, which now asserts the opt-out *reason* itself. Prefer
an invariant that makes the bad state unrepresentable over a prose justification nobody can
verify.
</authoring_coverage_blocks>

<planning_truths>
When writing `must_haves.truths` for a phase plan, each truth should name the behavioural
test that will prove it. A truth asserting runtime behaviour with no test exercising it is
recorded as behaviour-unverified and routes to a human — correctly. Naming the test up
front is what keeps that from happening at the end of the phase, when it is most expensive.

Avoid `verification: backstop` where explicit evidence can be supplied; a backstop truth
abstains and escalates.
</planning_truths>
