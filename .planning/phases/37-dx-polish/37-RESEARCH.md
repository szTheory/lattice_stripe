# Phase 37: DX Polish - Research

**Researched:** 2026-05-25
**Domain:** Developer-experience polish for webhook setup, testing fixtures, recipes, and docs/package truth
**Confidence:** HIGH

## Summary

Phase 37 should ship as a three-plan polish phase:

1. Expose a public fixture-builder surface under `LatticeStripe.Testing.Fixtures.*`, keeping raw Stripe-shaped maps canonical and layering typed/event helpers on top through `LatticeStripe.Testing`.
2. Rewrite the public docs flow around one canonical Phoenix webhook quickstart, a compact recipes guide, and testing guidance that makes the fixture surface discoverable.
3. Sweep the public package/docs truth so `README.md`, `CHANGELOG.md`, `mix.exs`, guide indexes, and version references reflect the actual v1.3-capable branch state.

This split matches the actual risk boundaries in the repo:

- the code-facing risk is fixture API shape and discoverability
- the guide-facing risk is presenting too many webhook paths and hiding the library’s recommended operating model
- the trust risk is stale version/install/docs metadata that undermines the rest of the polish work

## Primary Findings

### 1. The repo already has the raw fixture material Phase 37 needs

The required v1.3 families already have realistic internal fixture modules in `test/support/fixtures/`:

- `File`
- `FileLink`
- `Dispute`
- `CreditNote`
- `Mandate`
- `SetupAttempt`
- `Quote`

Those modules are good canonical sources of Stripe-shaped raw payloads, but they are not part of the public package surface and their naming is inconsistent (`basic/1`, `with_links/1`, `quote_json/1`, etc.). Phase 37 should not invent a second canonical data source. It should promote and normalize those shapes into a public surface.

### 2. `LatticeStripe.Testing` already provides the right layering direction

The existing public testing module already exposes:

- `generate_webhook_event/3`
- `generate_webhook_payload/3`

That is the right abstraction boundary for Phase 37:

- fixture modules produce raw Stripe-shaped maps
- `LatticeStripe.Testing` turns those maps into signed payloads, `%Event{}` structs, and typed resource structs where useful

The phase should keep separate functions for separate shapes. The context’s rejection of `as: :map | :struct` polymorphism is correct for this repo.

### 3. Current webhook docs teach two paths too early

`guides/webhooks.md` currently presents both:

- mount-before-`Plug.Parsers`
- `CacheBodyReader` + router `forward`

The content is technically correct, but the top-level presentation is too even-handed for a public quickstart. The repo already has a simpler recommended path: mount `LatticeStripe.Webhook.Plug` in `endpoint.ex` before `Plug.Parsers`, gate it with `at:`, and hand off to a handler module. That should become the canonical path in the guide.

The advanced `forward` + `CacheBodyReader` route should stay documented, but as a secondary path with a clear “use this when you need Plug.Parsers first” explanation.

### 4. The public trust story is visibly stale

Current public package/docs truth has obvious drift:

- `mix.exs` still sets `@version "1.1.0"`
- `README.md` still says “What’s new in v1.1”
- install snippets still point at `~> 1.1`
- the docs extras list does not yet include `guides/recipes.md`

Phase 37 must treat this as first-class scope, not cleanup if time remains. A polished webhook guide or fixture API will not offset obvious version drift at the main entrypoints.

### 5. Recipes should be narrow bridges, not a second handbook

The repo already has:

- `guides/user-flows-and-jtbd.md` for conceptual framing
- focused topical guides like `guides/webhooks.md`, `guides/testing.md`, `guides/customer-portal.md`, and `guides/credit_notes.md`

So `guides/recipes.md` should be a compact bridge between “what job am I solving?” and “which detailed guides do I need next?”. The three locked recipes are sufficient:

- dispute handling / evidence workflow
- credit issuance / invoice adjustment workflow
- quote-to-invoice workflow

Anything broader pushes the library toward a product playbook instead of an SDK guide.

## External Guidance Check

Primary-source check against upstream docs supports the phase decisions:

- Stripe’s webhook docs say signature verification requires the raw request body and recommend verifying the `Stripe-Signature` header with the endpoint secret.
- Stripe’s webhook signature troubleshooting docs reinforce that the three required inputs are request body, signature header, and endpoint secret; wrong or transformed body content breaks verification.
- Plug’s `Plug.Parsers` docs explicitly document `:body_reader` as the extension point for reading the raw body before parsing discards it.
- ExDoc’s docs support `extras` plus `groups_for_extras`, which is the correct path for adding and grouping `guides/recipes.md`.
- Hex’s publish docs confirm package metadata and docs publication are driven from `mix.exs`, reinforcing that `version`, docs extras, and package truth must stay aligned.

## Locked Design Outcomes

### Public fixture surface

- Add public resource-specific fixture builders under `LatticeStripe.Testing.Fixtures.*`
- Canonical return shape is raw map
- Add explicit wrapper helpers for:
  - signed webhook payloads
  - `%LatticeStripe.Event{}`
  - decoded typed resource structs where useful
- Do not add option-driven shape switching

### Webhook guide posture

- One canonical quickstart: `endpoint.ex` before `Plug.Parsers`
- Default examples use runtime secret resolution
- Teach the raw-body invariant early and explicitly
- Teach “app flows start work, webhooks confirm reality”
- Keep `CacheBodyReader` + `forward` as advanced fallback, not co-primary setup

### Recipes guide posture

- New `guides/recipes.md`
- Three workflows only
- Library-scoped examples only
- Deep-link out to topic guides instead of re-explaining everything inline

### Consistency sweep boundary

- Sweep `guides/`
- Sweep `README.md`
- Sweep `CHANGELOG.md`
- Sweep `mix.exs` docs/version truth
- No release automation, tagging, or publish workflow changes

## Recommended Plan Split

### Plan 01

Scope:

- public fixture-builder modules under `lib/lattice_stripe/testing/fixtures/`
- `LatticeStripe.Testing` helper expansion for typed/event/webhook wrappers
- focused unit coverage for the new public testing surface

Why first:

- it establishes the public DX API that both docs guides and recipes should teach
- it lets later docs reference real stable helper names instead of placeholders

### Plan 02

Scope:

- rewrite `guides/webhooks.md` around one canonical Phoenix quickstart
- update `guides/testing.md` to teach the new fixture surface
- add `guides/recipes.md`

Why second:

- docs should teach the actual public helper names and modules shipped by Plan 01
- keeping guide authoring separate avoids mixing public API design with long-form docs editing

### Plan 03

Scope:

- `README.md`, `CHANGELOG.md`, `mix.exs`, guide indexes, cross-links, and visible version references
- lightweight drift checks or docs-focused tests where appropriate

Why third:

- it is the public trust sweep once the surface and guides are settled
- it prevents late plan churn from forcing repeated README/changelog edits

## Verification Strategy

- Unit tests are the primary safety net for the new public testing helpers and wrapper functions.
- Docs verification should be a mix of:
  - `mix test` for any docs-truth tests added in this phase
  - `mix docs --warnings-as-errors` after the guide/index sweep
  - targeted grep/file-existence checks for new extras and cross-links
- Manual review still matters for:
  - “is there one obvious webhook path?”
  - “can a new Phoenix user copy-paste this?”
  - “do the recipes stay library-scoped?”

## Recommended Analogs

| Phase 37 concern | Primary analog | Why |
|------------------|----------------|-----|
| Public helper layering | `lib/lattice_stripe/testing.ex` | Existing public testing boundary already ships in `lib/` |
| Canonical Phoenix example tone | `guides/customer-portal.md` | Strong application-facing guide with focused end-to-end framing |
| Internal fixture sources | `test/support/fixtures/*.ex` | Existing realistic Stripe-shaped payload builders |
| ExDoc guide registration | `mix.exs` `extras` / `groups_for_extras` | Existing public docs structure |
| Public truth sweep | `README.md` + `CHANGELOG.md` + `mix.exs` | Highest-visibility adoption surfaces |

## Execution Recommendation

Default recommendation:

- keep raw fixture maps canonical
- keep typed/event/payload conversions explicit and layered
- teach one webhook path first
- add only one compact recipes guide
- treat version/docs truth as required scope, not cleanup

That is the smallest coherent Phase 37 that satisfies all four DX requirements without sliding into release-operations work or Accrue-style workflow abstraction.
