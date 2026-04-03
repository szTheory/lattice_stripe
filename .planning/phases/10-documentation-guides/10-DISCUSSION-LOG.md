# Phase 10: Documentation & Guides - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 10-documentation-guides
**Areas discussed:** ExDoc organization, Guide depth & tone, README quickstart, Code comments bar

---

## ExDoc Organization

### Module Grouping

| Option | Description | Selected |
|--------|-------------|----------|
| By domain | Groups like Core, Payments, Checkout, Webhooks, Internals. Mirrors how developers think about Stripe. | ✓ |
| Flat alphabetical | No grouping — just alphabetical list of all modules. | |
| Two-tier (Public / Internal) | Just 'Public API' and 'Internals'. | |

**User's choice:** By domain
**Notes:** None

### Guide Sidebar Position

| Option | Description | Selected |
|--------|-------------|----------|
| Before modules | Guides listed first in sidebar. Standard pattern for Elixir libs. | ✓ |
| After modules | API reference first, guides below. | |
| You decide | Claude picks. | |

**User's choice:** Before modules
**Notes:** None

### Internal Modules Visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Show in Internals group | Visible but clearly marked as internal. Useful for advanced users implementing custom transports. | ✓ |
| Hide with @moduledoc false | Cleaner sidebar but hides extensibility story. | |
| Split: show behaviours, hide helpers | Behaviours visible, helpers hidden. | |

**User's choice:** Show in Internals group
**Notes:** None

### Landing Page

| Option | Description | Selected |
|--------|-------------|----------|
| LatticeStripe module | mix.exs already has main: "LatticeStripe". Common pattern. | |
| Overview guide page | Separate overview.md as entry point. More editorial control. | |
| README as landing | Set main: "readme". Keeps HexDocs and GitHub in sync. | |

**User's choice:** Free text — fine with either LatticeStripe module or Overview guide. Stripe is complex enough that summary intro might help DX. Deferred to Claude's discretion, noting it can be changed later.
**Notes:** User acknowledged this is easily changeable.

### Cheatsheet

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include cheatsheet | ExDoc has native .cheatmd support. Quick-reference card. | ✓ |
| No cheatsheet | Guides cover it. | |
| You decide | Claude decides. | |

**User's choice:** Yes, include cheatsheet
**Notes:** None

### Branding

| Option | Description | Selected |
|--------|-------------|----------|
| Logo only | Small LatticeStripe logo in sidebar header. | ✓ |
| No branding | Plain ExDoc defaults. | |
| You decide | Claude decides. | |

**User's choice:** Logo only
**Notes:** None

### Source Links

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, source links | Every function links back to GitHub source. Already have @source_url. | ✓ |
| No source links | Keep docs self-contained. | |
| You decide | Claude decides. | |

**User's choice:** Yes, source links
**Notes:** None

### Style Reference

| Option | Description | Selected |
|--------|-------------|----------|
| Oban | Comprehensive guides, grouped modules, professional landing page. | |
| Phoenix | Extensive guides with progressive disclosure. | |
| Req | Clean, focused, single-module-centric. | |
| No specific reference | Claude picks best approach. | ✓ |

**User's choice:** No specific reference
**Notes:** None

### Webhook Docs Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single Webhooks guide | One guide covering signature verification, Plug setup, event handling, Phoenix integration. | ✓ |
| Separate Plug guide | Webhooks guide for concepts, separate guide for Phoenix integration. | |
| You decide | Claude decides. | |

**User's choice:** Single Webhooks guide
**Notes:** None

### Changelog

| Option | Description | Selected |
|--------|-------------|----------|
| CHANGELOG.md in extras | Include in ExDoc. Standard practice. | ✓ |
| GitHub releases only | Keep docs focused on usage. | |
| You decide | Claude decides. | |

**User's choice:** CHANGELOG.md in extras
**Notes:** None

### Extending Guide

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add Extending guide | Guide showing how to implement custom Transport, JSON codec, RetryStrategy. | ✓ |
| No, moduledocs are enough | Callback specs in @moduledoc suffice. | |
| You decide | Claude decides. | |

**User's choice:** Yes, add Extending guide
**Notes:** This makes 9 guides total (8 from DOCS-05 + Extending)

### Guide Sidebar Order

| Option | Description | Selected |
|--------|-------------|----------|
| Integration journey | Follows natural developer path: setup → charge → checkout → webhooks → errors → test → observe → extend. | ✓ |
| Alphabetical | Simpler to maintain. | |
| You decide | Claude picks. | |

**User's choice:** Integration journey
**Notes:** None

---

## Guide Depth & Tone

### Guide Style

| Option | Description | Selected |
|--------|-------------|----------|
| Tutorial walkthrough | Step-by-step with full code examples for real scenarios. | ✓ |
| Reference with examples | Shorter, annotated API reference with code snippets. | |
| Mixed | Getting Started tutorial-style, domain guides reference-style, operational guides tutorial-style. | |

**User's choice:** Tutorial walkthrough
**Notes:** None

### Guide Length

| Option | Description | Selected |
|--------|-------------|----------|
| Medium (~200-400 lines) | 3-5 complete scenarios with explanation. | ✓ |
| Short (~100-150 lines) | Minimal explanation, mostly code. | |
| Comprehensive (~500+ lines) | Every scenario and edge case. | |

**User's choice:** Medium
**Notes:** None

### Pitfalls Sections

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, per guide | Each guide ends with common mistakes section. | ✓ |
| One dedicated Pitfalls guide | All gotchas in one place. | |
| No pitfalls sections | Keep guides positive. | |
| You decide | Claude decides. | |

**User's choice:** Yes, per guide
**Notes:** None

### Tone

| Option | Description | Selected |
|--------|-------------|----------|
| Professional-friendly | Clear, direct, slightly warm. Like Stripe's own docs. | ✓ |
| Formal/technical | Neutral, academic. | |
| Casual/conversational | Very informal, uses humor. | |

**User's choice:** Professional-friendly
**Notes:** None

### API Keys in Examples

| Option | Description | Selected |
|--------|-------------|----------|
| Stripe test keys | Use sk_test_... format. Copy-paste friendly. | ✓ |
| Placeholder strings | Use "your-api-key-here" or env var approach. | |
| Both | Env var in Getting Started, sk_test_... elsewhere. | |

**User's choice:** Stripe test keys
**Notes:** None

### Testing Guide Mox

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, show Mox mocking | Show how to define mock transport, set up expectations, test user code. | ✓ |
| Just reference Testing module | Point to LatticeStripe.Testing moduledoc. | |
| You decide | Claude decides. | |

**User's choice:** Yes, show Mox mocking
**Notes:** None

### Stripe Doc Links

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, link to Stripe docs | Include links to Stripe documentation for deeper context. | ✓ |
| Self-contained guides | Don't link out. Explain concepts inline. | |
| You decide | Claude decides per guide. | |

**User's choice:** Yes, link to Stripe docs
**Notes:** None

### Doctests

| Option | Description | Selected |
|--------|-------------|----------|
| No doctests in guides | Guide examples need Stripe API. Plain code blocks only. | ✓ |
| Doctests where possible | Use for pure functions, plain blocks for API calls. | |
| You decide | Claude decides. | |

**User's choice:** No doctests in guides
**Notes:** None

---

## README Quickstart

### Hero Example

| Option | Description | Selected |
|--------|-------------|----------|
| PaymentIntent.create | Most common Stripe operation. ~10 lines. | ✓ |
| Customer.create | Simpler conceptually but less exciting. | |
| Checkout.Session.create | More realistic for SaaS but more verbose. | |

**User's choice:** PaymentIntent.create
**Notes:** None

### README Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Focused (~100-150 lines) | Badges, quickstart, feature list, docs link. | ✓ |
| Comprehensive (~300-400 lines) | Condensed versions of each guide topic. | |
| Minimal (<50 lines) | Description, install, quickstart, docs link. | |

**User's choice:** Focused
**Notes:** None

### Finch Setup

| Option | Description | Selected |
|--------|-------------|----------|
| Show Finch setup | Include 3-line child spec. Most users setting up first time. | ✓ |
| Skip Finch setup | Assume user has Finch. Link to docs. | |
| You decide | Claude decides. | |

**User's choice:** Show Finch setup
**Notes:** None

### Contributing Section

| Option | Description | Selected |
|--------|-------------|----------|
| Brief section + link | 2-3 lines pointing to CONTRIBUTING.md. | ✓ |
| No contributing section | Skip for v1. | |
| You decide | Claude decides. | |

**User's choice:** Brief section + link
**Notes:** None

### Badges

| Option | Description | Selected |
|--------|-------------|----------|
| Standard set | Hex version, CI status, HexDocs link, License. | ✓ |
| Minimal | Just Hex version and License. | |
| No badges | Clean look. | |
| You decide | Claude picks. | |

**User's choice:** Standard set
**Notes:** None

### Compatibility Info

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both | Elixir/OTP versions and Stripe API version. | ✓ |
| Just Elixir/OTP | Language versions only, Stripe details in docs. | |
| No, link to docs | Compatibility in Getting Started guide. | |
| You decide | Claude decides. | |

**User's choice:** Yes, both
**Notes:** None

---

## Code Comments Bar

### @doc Completeness

| Option | Description | Selected |
|--------|-------------|----------|
| Every public function | Full @doc: summary, params, return type, example, errors. | ✓ |
| Summary + example only | One-line summary and one code example per function. | |
| Audit existing, fill gaps | Don't rewrite good docs, only fill where missing. | |

**User's choice:** Every public function
**Notes:** None

### Comment Threshold

| Option | Description | Selected |
|--------|-------------|----------|
| Stripe-specific logic only | Comment where code does something because of Stripe's API quirks. | ✓ |
| Any non-obvious logic | Comment anything a new contributor might not understand. | |
| Minimal comments | Trust code to be self-documenting. | |

**User's choice:** Stripe-specific logic only
**Notes:** None

### Stripe API Links in @moduledoc

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, link to Stripe docs | Each resource @moduledoc includes link to corresponding Stripe API reference. | ✓ |
| No external links | Keep moduledocs self-contained. | |
| You decide | Claude decides per module. | |

**User's choice:** Yes, link to Stripe docs
**Notes:** None

### Error Examples in @doc

| Option | Description | Selected |
|--------|-------------|----------|
| Happy path + key errors | Show {:ok, result} and 1-2 common {:error, reason} patterns. | ✓ |
| Happy path only | Just {:ok, result}. Error handling in guide. | |
| You decide | Claude decides per function. | |

**User's choice:** Happy path + key errors
**Notes:** None

### @typedoc

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, for key structs | Add to Error, Response, List, and each resource struct. | ✓ |
| No @typedoc | @moduledoc already describes structs. | |
| You decide | Claude decides. | |

**User's choice:** Yes, for key structs
**Notes:** None

### Bang Variant Docs

| Option | Description | Selected |
|--------|-------------|----------|
| Brief one-liner | "Same as create/2 but raises on error. See create/2 for details." with minimal example. | ✓ |
| Full duplicate docs | Same full @doc as non-bang version. | |
| No @doc on bangs | Skip entirely. | |
| You decide | Claude picks. | |

**User's choice:** Brief one-liner
**Notes:** None

---

## Claude's Discretion

- Landing page choice (LatticeStripe module vs Overview guide)
- No specific Elixir library style reference chosen — Claude picks best approach

## Deferred Ideas

None — discussion stayed within phase scope
