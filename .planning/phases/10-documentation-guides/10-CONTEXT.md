# Phase 10: Documentation & Guides - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Make every public API documented and developers productive within 60 seconds of install. Covers: ExDoc configuration, @moduledoc/@doc on all public modules and functions, 9 guide pages, README rewrite, cheatsheet, and inline code comments on Stripe-specific logic.

</domain>

<decisions>
## Implementation Decisions

### ExDoc Organization
- **D-01:** Domain-based module grouping: Core (LatticeStripe, Client, Config, Error, Response, List), Payments (PaymentIntent, Customer, PaymentMethod, SetupIntent, Refund), Checkout (Session, LineItem), Webhooks (Webhook, Webhook.Plug, Event), Telemetry & Testing (Telemetry, Testing), Internals (Transport, Transport.Finch, JSON, JSON.Jason, RetryStrategy, FormEncoder, Request, Resource)
- **D-02:** Guides listed before modules in sidebar, ordered by integration journey: Getting Started, Client Configuration, Payments, Checkout, Webhooks, Error Handling, Testing, Telemetry, Extending LatticeStripe
- **D-03:** Internal modules (behaviours + helpers) shown in an "Internals" group, not hidden with @moduledoc false
- **D-04:** Include a cheatsheet extra (.cheatmd) with common operations quick-reference
- **D-05:** Logo branding in ExDoc sidebar header
- **D-06:** Source links to GitHub enabled (source_url + source_ref in mix.exs docs config)
- **D-07:** CHANGELOG.md included as ExDoc extra
- **D-08:** Single Webhooks guide covering signature verification, Plug setup, event handling, and Phoenix integration (not split into separate pages)
- **D-09:** Add "Extending LatticeStripe" guide showing how to implement custom Transport, JSON codec, and RetryStrategy behaviours (9th guide, beyond the 8 in DOCS-05)

### Guide Depth & Tone
- **D-10:** Tutorial walkthrough style — step-by-step with full code examples for real scenarios (e.g., Payments guide walks through create customer, create PaymentIntent, confirm, handle errors)
- **D-11:** Medium length per guide (~200-400 lines), covering 3-5 complete scenarios with explanation
- **D-12:** Professional-friendly tone — clear, direct, slightly warm. Uses "you" and "your app". Like Stripe's own docs.
- **D-13:** Each guide ends with a "Common Pitfalls" / "Gotchas" section for that topic
- **D-14:** Use Stripe test keys (sk_test_...) in code examples, not placeholder strings
- **D-15:** Testing guide includes Mox mocking pattern showing users how to mock the Transport behaviour in their own apps
- **D-16:** Link to Stripe's documentation for deeper context where helpful (e.g., "See Stripe's PaymentIntent guide for the full lifecycle")
- **D-17:** No doctests in guides — plain code blocks only (guide examples need Stripe API/stripe-mock)

### README Quickstart
- **D-18:** Hero code example is PaymentIntent.create (~10 lines showing client setup + payment creation)
- **D-19:** Focused README (~100-150 lines): badges, one-liner description, quickstart, feature bullet list, link to HexDocs, license
- **D-20:** Quickstart includes Finch child spec setup (3-line supervision tree snippet) since most users are setting up for the first time
- **D-21:** Brief Contributing section with link to CONTRIBUTING.md
- **D-22:** Standard badge set: Hex version, CI status, HexDocs link, License (MIT)
- **D-23:** Compatibility section listing Elixir >= 1.15, OTP >= 26, and pinned Stripe API version

### Code Comments & @doc
- **D-24:** Every public function gets full @doc: one-line summary, params description, return type, at least one code example, error cases where relevant
- **D-25:** Inline code comments on Stripe-specific logic only (retry header parsing, form-encoding nested params, webhook signature timing, etc.). Standard Elixir patterns don't get comments.
- **D-26:** Each resource @moduledoc includes a link to the corresponding Stripe API reference page
- **D-27:** @doc examples show both happy path ({:ok, result}) and key error patterns ({:error, reason}) with pattern matching
- **D-28:** @typedoc added to key public structs (Error, Response, List, and each resource struct)
- **D-29:** Bang variants get brief one-liner @doc referencing the non-bang version ("Same as `create/2` but raises on error. See `create/2` for details.") with a minimal example

### Claude's Discretion
- Landing page: Claude decides between LatticeStripe module or a dedicated Overview guide page (likely Overview guide given Stripe's complexity, for better editorial orientation)
- No specific Elixir library style reference to emulate — Claude picks the best approach for a production payment SDK

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Requirements
- `.planning/REQUIREMENTS.md` — DOCS-01 through DOCS-06 define the documentation requirements

### Existing Documentation Patterns
- `lib/lattice_stripe/client.ex` — Already has comprehensive @moduledoc with Quick Start, Multiple Clients, Per-Request Overrides examples (reference for doc quality bar)
- `lib/lattice_stripe/payment_intent.ex` — Rich @moduledoc with usage examples, security notes, 19 @doc annotations (closest to target quality)
- `lib/lattice_stripe/customer.ex` — 15 @doc annotations, good existing coverage

### ExDoc Configuration
- `mix.exs` — Current docs config (lines 19-22), package config, @source_url. Needs expansion for groups, extras, logo, source_ref.

### Stripe API Reference (external)
- https://docs.stripe.com/api — Canonical Stripe API docs to link from @moduledoc on each resource module

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- 20+ modules already have @moduledoc — most need enhancement, not creation from scratch
- PaymentIntent (19 @doc), Customer (15 @doc) are already close to target quality
- Client module has a comprehensive @moduledoc that can serve as the template for other modules
- mix.exs already has @source_url and basic docs config to build on

### Established Patterns
- Resource modules follow a consistent pattern: @moduledoc with usage examples, CRUD functions with @doc
- ExDoc is already a dev dependency
- Jason is the JSON codec (relevant for doc examples)
- Finch is the default transport (relevant for quickstart examples)

### Integration Points
- `mix.exs` docs config — needs groups, extras, logo, source_ref additions
- `guides/` directory — needs to be created (9 .md files + 1 .cheatmd)
- `README.md` — complete rewrite from placeholder to production README
- Every `lib/lattice_stripe/*.ex` file — @doc audit and enhancement

</code_context>

<specifics>
## Specific Ideas

- Quickstart should show Finch child spec → Client.new! → PaymentIntent.create in one continuous flow
- Cheatsheet should cover: create client, charge a card, create subscription checkout, verify webhook, handle errors
- Integration journey guide order mirrors the natural developer path: setup → charge → checkout → webhooks → handle errors → test → observe → extend
- Code comment style should include example input/output shapes (per PROJECT.md design philosophy)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-documentation-guides*
*Context gathered: 2026-04-03*
