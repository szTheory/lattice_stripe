# Phase 10: Documentation & Guides - Research

**Researched:** 2026-04-03
**Domain:** Elixir ExDoc configuration, @moduledoc/@doc authoring, guide writing for Hex packages
**Confidence:** HIGH

## Summary

Phase 10 covers the entire documentation layer for LatticeStripe v1. The codebase is
functionally complete (phases 1-9 done), so this phase is pure documentation work: ExDoc
configuration, @moduledoc/@doc authoring across ~23 modules, nine guide files plus one
cheatsheet, and a README rewrite.

The codebase is in better shape than a blank slate. Every module already has @moduledoc.
PaymentIntent (19 @doc), Customer (15 @doc), SetupIntent (16 @doc), Checkout.Session (16
@doc), and PaymentMethod (14 @doc) are close to target quality. The weakest spots are the
internal-pattern modules: Request (0 @doc), Resource (@moduledoc false, 0 @doc), Transport
and Transport.Finch (0 @doc), Json.Jason (0 @doc), Webhook.Plug (0 @doc),
Webhook.CacheBodyReader (0 @doc), and RetryStrategy (0 @doc functions). These need the
most work.

The mix.exs docs config is minimal today (main + extras: README only). It needs expansion
for groups_for_modules, groups_for_extras, extras with all guides, logo, and source_ref.

**Primary recommendation:** Work in two parallel tracks — (1) ExDoc configuration and file
scaffolding (guides dir + files + mix.exs config), and (2) @doc authoring module-by-module,
starting with modules that have 0 @doc and working toward full coverage.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**ExDoc Organization**
- D-01: Domain-based module grouping: Core (LatticeStripe, Client, Config, Error, Response, List), Payments (PaymentIntent, Customer, PaymentMethod, SetupIntent, Refund), Checkout (Session, LineItem), Webhooks (Webhook, Webhook.Plug, Event), Telemetry & Testing (Telemetry, Testing), Internals (Transport, Transport.Finch, JSON, JSON.Jason, RetryStrategy, FormEncoder, Request, Resource)
- D-02: Guides listed before modules in sidebar, ordered by integration journey: Getting Started, Client Configuration, Payments, Checkout, Webhooks, Error Handling, Testing, Telemetry, Extending LatticeStripe
- D-03: Internal modules (behaviours + helpers) shown in an "Internals" group, not hidden with @moduledoc false
- D-04: Include a cheatsheet extra (.cheatmd) with common operations quick-reference
- D-05: Logo branding in ExDoc sidebar header
- D-06: Source links to GitHub enabled (source_url + source_ref in mix.exs docs config)
- D-07: CHANGELOG.md included as ExDoc extra
- D-08: Single Webhooks guide covering signature verification, Plug setup, event handling, and Phoenix integration (not split into separate pages)
- D-09: Add "Extending LatticeStripe" guide showing how to implement custom Transport, JSON codec, and RetryStrategy behaviours (9th guide, beyond the 8 in DOCS-05)

**Guide Depth & Tone**
- D-10: Tutorial walkthrough style — step-by-step with full code examples for real scenarios
- D-11: Medium length per guide (~200-400 lines), covering 3-5 complete scenarios with explanation
- D-12: Professional-friendly tone — clear, direct, slightly warm. Uses "you" and "your app". Like Stripe's own docs.
- D-13: Each guide ends with a "Common Pitfalls" / "Gotchas" section for that topic
- D-14: Use Stripe test keys (sk_test_...) in code examples, not placeholder strings
- D-15: Testing guide includes Mox mocking pattern showing users how to mock the Transport behaviour in their own apps
- D-16: Link to Stripe's documentation for deeper context where helpful
- D-17: No doctests in guides — plain code blocks only

**README Quickstart**
- D-18: Hero code example is PaymentIntent.create (~10 lines showing client setup + payment creation)
- D-19: Focused README (~100-150 lines): badges, one-liner description, quickstart, feature bullet list, link to HexDocs, license
- D-20: Quickstart includes Finch child spec setup (3-line supervision tree snippet)
- D-21: Brief Contributing section with link to CONTRIBUTING.md
- D-22: Standard badge set: Hex version, CI status, HexDocs link, License (MIT)
- D-23: Compatibility section listing Elixir >= 1.15, OTP >= 26, and pinned Stripe API version

**Code Comments & @doc**
- D-24: Every public function gets full @doc: one-line summary, params description, return type, at least one code example, error cases where relevant
- D-25: Inline code comments on Stripe-specific logic only; standard Elixir patterns don't get comments
- D-26: Each resource @moduledoc includes a link to the corresponding Stripe API reference page
- D-27: @doc examples show both happy path ({:ok, result}) and key error patterns ({:error, reason}) with pattern matching
- D-28: @typedoc added to key public structs (Error, Response, List, and each resource struct)
- D-29: Bang variants get brief one-liner @doc referencing the non-bang version

### Claude's Discretion
- Landing page: Claude decides between LatticeStripe module or a dedicated Overview guide page
- No specific Elixir library style reference to emulate — Claude picks the best approach for a production payment SDK

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-01 | Every public module has @moduledoc with purpose and usage examples | Audit shows all modules have @moduledoc; most need examples and Stripe API reference links |
| DOCS-02 | Every public function has @doc with arguments, return types, examples, and error cases | Audit shows ~10 modules have 0 @doc; high-traffic modules (PaymentIntent, Customer) are 80%+ done |
| DOCS-03 | ExDoc generates grouped, navigable documentation published to HexDocs | ExDoc 0.40.1 installed; mix.exs needs groups_for_modules, groups_for_extras, extras, logo, source_ref |
| DOCS-04 | README provides <60 second quickstart from install to first API call | README.md is placeholder text today; needs complete rewrite per D-18 through D-23 |
| DOCS-05 | Guides cover: Getting Started, Client Configuration, Payments, Checkout, Webhooks, Error Handling, Testing, Telemetry | guides/ directory does not exist; 9 .md files + 1 .cheatmd need creation |
| DOCS-06 | Non-obvious code has short, readable comments with example input/output data shapes | Stripe-specific logic identified: retry header parsing, form-encoding, webhook HMAC signing |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExDoc | ~> 0.34 (installed: 0.40.1) | HTML documentation generation | Official Elixir documentation tool; generates HexDocs-compatible output |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mix docs | (stdlib alias) | Builds documentation via ExDoc | `mix docs` or `mix docs --warnings-as-errors` |

### Installation
Already installed. ExDoc is in mix.exs dev/test deps.

## Architecture Patterns

### Recommended File Structure
```
guides/
├── getting-started.md
├── client-configuration.md
├── payments.md
├── checkout.md
├── webhooks.md
├── error-handling.md
├── testing.md
├── telemetry.md
├── extending-lattice-stripe.md
└── cheatsheet.cheatmd

README.md         (complete rewrite)
CHANGELOG.md      (already exists or create)
assets/
└── logo.png      (if logo branding desired per D-05)
```

### ExDoc Configuration Pattern (mix.exs)

The current docs config:
```elixir
docs: [
  main: "LatticeStripe",
  extras: ["README.md"]
]
```

Target docs config:
```elixir
@source_url "https://github.com/lattice-stripe/lattice_stripe"

docs: [
  main: "getting-started",   # or "LatticeStripe" — Claude's discretion
  source_url: @source_url,
  source_ref: "v#{@version}",
  logo: "assets/logo.png",   # only if logo asset exists
  extras: [
    "guides/getting-started.md",
    "guides/client-configuration.md",
    "guides/payments.md",
    "guides/checkout.md",
    "guides/webhooks.md",
    "guides/error-handling.md",
    "guides/testing.md",
    "guides/telemetry.md",
    "guides/extending-lattice-stripe.md",
    "guides/cheatsheet.cheatmd",
    "CHANGELOG.md"
  ],
  groups_for_extras: [
    "Guides": Path.wildcard("guides/*.{md,cheatmd}"),
    "Changelog": ["CHANGELOG.md"]
  ],
  groups_for_modules: [
    "Core": [
      LatticeStripe,
      LatticeStripe.Client,
      LatticeStripe.Config,
      LatticeStripe.Error,
      LatticeStripe.Response,
      LatticeStripe.List
    ],
    "Payments": [
      LatticeStripe.PaymentIntent,
      LatticeStripe.Customer,
      LatticeStripe.PaymentMethod,
      LatticeStripe.SetupIntent,
      LatticeStripe.Refund
    ],
    "Checkout": [
      LatticeStripe.Checkout.Session,
      LatticeStripe.Checkout.LineItem
    ],
    "Webhooks": [
      LatticeStripe.Webhook,
      LatticeStripe.Webhook.Plug,
      LatticeStripe.Event
    ],
    "Telemetry & Testing": [
      LatticeStripe.Telemetry,
      LatticeStripe.Testing
    ],
    "Internals": [
      LatticeStripe.Transport,
      LatticeStripe.Transport.Finch,
      LatticeStripe.Json,
      LatticeStripe.Json.Jason,
      LatticeStripe.RetryStrategy,
      LatticeStripe.RetryStrategy.Default,
      LatticeStripe.FormEncoder,
      LatticeStripe.Request,
      LatticeStripe.Resource
    ]
  ]
]
```

**Important:** `source_ref: "v#{@version}"` uses a compiled module attribute, so `@source_url`
must be defined at the top of the `defmodule LatticeStripe.MixProject` block (already done).

### @doc Pattern for Resource Functions

The high-quality bar (from PaymentIntent, Customer) looks like:

```elixir
@doc """
Creates a new Customer in Stripe.

## Parameters

- `client` - A `%LatticeStripe.Client{}` struct
- `params` - Map of customer attributes (see Stripe API docs)
- `opts` - Per-request options: `idempotency_key`, `stripe_account`, `timeout`, `expand`

## Returns

`{:ok, %LatticeStripe.Customer{}}` on success, `{:error, %LatticeStripe.Error{}}` on failure.

## Examples

    {:ok, customer} = LatticeStripe.Customer.create(client, %{
      "email" => "jenny@example.com",
      "name" => "Jenny Rosen"
    })

    # With error handling
    case LatticeStripe.Customer.create(client, %{"email" => "jenny@example.com"}) do
      {:ok, customer} -> customer.id
      {:error, %LatticeStripe.Error{type: :card_error}} -> handle_card_error()
      {:error, %LatticeStripe.Error{} = err} -> handle_error(err)
    end
"""
```

### @typedoc Pattern for Public Structs

```elixir
@typedoc """
A Stripe Customer object.

Fields map directly to the [Stripe Customer API](https://docs.stripe.com/api/customers/object).
"""
@type t :: %__MODULE__{
  id: String.t() | nil,
  email: String.t() | nil,
  ...
}
```

### Bang @doc Pattern (D-29)

```elixir
@doc """
Same as `create/3` but raises `LatticeStripe.Error` on failure.

See `create/3` for parameter documentation.

## Example

    customer = LatticeStripe.Customer.create!(client, %{"email" => "jenny@example.com"})
"""
```

### .cheatmd Format

ExDoc 0.34+ renders `.cheatmd` files as cheatsheets. Syntax:

```markdown
# LatticeStripe Cheatsheet

## Section Name
{: .col-2}

### Left Column Heading

```elixir
# code example
```

### Right Column Heading

- Bullet point
- Another point
```

Key layout attributes (placed on line after `##` heading):
- `{: .col-2}` — two column layout (most common)
- `{: .col-3}` — three column layout
- No attribute — single column

### Guide File Structure Pattern

Each guide should follow this structure:
1. `# Guide Title` (H1 — becomes the sidebar nav label)
2. Brief intro paragraph (what this guide covers, 2-3 sentences)
3. Multiple `## Section` headings with full code examples
4. Final `## Common Pitfalls` section (D-13)

### @moduledoc Enhancement Pattern

For resource modules, add Stripe API reference link per D-26:

```elixir
@moduledoc """
Operations on Stripe Customer objects.

Customers let you save payment methods, track payment history, and manage subscriptions
across multiple payments.

See the [Stripe Customers API](https://docs.stripe.com/api/customers) for the full object
reference and available parameters.

## Usage

    client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)

    {:ok, customer} = LatticeStripe.Customer.create(client, %{
      "email" => "jenny@example.com"
    })
"""
```

### Anti-Patterns to Avoid

- **Doctests in guides (D-17):** Don't use `iex>` syntax in guide files — examples need
  a running Stripe API or stripe-mock. Plain code blocks only in guides.
- **Using @moduledoc false for internal modules (D-03):** Internal modules go in the
  "Internals" group, not hidden. Resource, FormEncoder, Transport.Finch, Json.Jason all
  need real @moduledoc content explaining their contract.
- **Placeholder secrets in examples:** Always use `sk_test_...` or `whsec_test_...`
  format (D-14), not `"YOUR_API_KEY"` or `"<api_key>"`.
- **main pointing to a module on the landing page:** With guides listed first, `main:
  "getting-started"` creates a better first impression than `main: "LatticeStripe"`. The
  module docstring is the wrong landing page for a complex SDK.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Module grouping | Custom sidebar HTML | `groups_for_modules` in ExDoc config | ExDoc has native module grouping |
| Guide navigation | Custom nav code | `groups_for_extras` in ExDoc config | ExDoc native; guides auto-link in sidebar |
| Cheatsheet layout | Custom CSS/HTML | `.cheatmd` extension + `{: .col-2}` | ExDoc 0.34+ renders cheatsheets natively |
| Source links | Custom link builder | `source_url` + `source_ref` in docs config | ExDoc infers GitHub source links automatically |

**Key insight:** ExDoc 0.40.1 handles essentially all the structural concerns. The planner
should not create tasks to build custom navigation, styling, or link generation.

## @doc Coverage Audit

Current state per module (public API functions needing @doc):

| Module | Public Fns | @doc Count | Gap | Priority |
|--------|-----------|-----------|-----|----------|
| LatticeStripe.Request | 0 (struct only) | 0 | struct @typedoc needed | LOW |
| LatticeStripe.Resource | internal (@moduledoc false) | 0 | needs @moduledoc + @doc per D-03 | HIGH |
| LatticeStripe.Transport | behaviour, 0 public fns | 0 | @moduledoc OK, @typedoc for types | LOW |
| LatticeStripe.Transport.Finch | 1 (request/1) | 0 | needs @doc | MEDIUM |
| LatticeStripe.Json | behaviour, 2 callbacks | 2 | callbacks have @doc — DONE | LOW |
| LatticeStripe.Json.Jason | 4 (callbacks impls) | 0 | brief @doc per function | LOW |
| LatticeStripe.RetryStrategy | behaviour, 0 public | 0 | @moduledoc OK | LOW |
| LatticeStripe.RetryStrategy.Default | 1 (retry?/2) | 0 | needs @doc | MEDIUM |
| LatticeStripe.FormEncoder | 1 public (encode/1) | 1 | has 1 @doc — check completeness | LOW |
| LatticeStripe.Config | 3 public fns | 3 | has 3 @doc — check completeness | LOW |
| LatticeStripe.Client | 4+ public fns | 4 | has 4 @doc — likely needs expand/new/request docs | MEDIUM |
| LatticeStripe.Error | 1 public fn | 1 | has 1 @doc — add @typedoc per D-28 | MEDIUM |
| LatticeStripe.Response | 1 public fn | 1 | has 1 @doc — add @typedoc | LOW |
| LatticeStripe.List | 3 public fns | 3 | has 3 @doc — add @typedoc | LOW |
| LatticeStripe.Event | 6 public fns | 6 | good coverage — add @typedoc | LOW |
| LatticeStripe.Webhook | 5 public fns | 5 | good coverage | LOW |
| LatticeStripe.Webhook.Plug | Plug init/call | 0 visible | has @doc on init/call but needs @typedoc | LOW |
| LatticeStripe.Webhook.CacheBodyReader | 1 (read_body/3) | 0 | needs @doc | MEDIUM |
| LatticeStripe.Webhook.Handler | behaviour callback | 1 | check completeness | LOW |
| LatticeStripe.Telemetry | 5 public fns | 5 | has 5 @doc — comprehensive @moduledoc already | LOW |
| LatticeStripe.Testing | 2 public fns | 2 | has 2 @doc | LOW |
| LatticeStripe.PaymentIntent | 19 fns | 19 | add @typedoc, add Stripe API link | LOW |
| LatticeStripe.Customer | 15 fns | 15 | add @typedoc, add Stripe API link | LOW |
| LatticeStripe.SetupIntent | 16 fns | 16 | add @typedoc, add Stripe API link | LOW |
| LatticeStripe.PaymentMethod | 14 fns | 14 | add @typedoc, add Stripe API link | LOW |
| LatticeStripe.Refund | 12 fns | 12 | add @typedoc, add Stripe API link | LOW |
| LatticeStripe.Checkout.Session | 16 fns | 16 | add @typedoc, add Stripe API link | LOW |
| LatticeStripe.Checkout.LineItem | struct only | 1 | add @typedoc | LOW |

**Summary:** Most @doc work is LOW priority polish. The HIGH priority gaps are modules with
0 @doc that the user will encounter: Resource (internal but per D-03 must document),
Transport.Finch, RetryStrategy.Default, Webhook.CacheBodyReader.

## Common Pitfalls

### Pitfall 1: mix.exs `source_ref` pointing to "main" instead of version tag
**What goes wrong:** Source links in generated docs always point to `main` branch. Users
reading v0.1.0 docs click source links that show different code (post-release changes).
**Why it happens:** Default `source_ref` is "main". Missing explicit version pin.
**How to avoid:** Set `source_ref: "v#{@version}"` — uses the `@version` module attribute.
**Warning signs:** Source link URLs contain `/blob/main/` instead of `/blob/v0.1.0/`.

### Pitfall 2: guides/ directory not added to ExDoc extras with correct path
**What goes wrong:** `mix docs` completes silently but guides don't appear in the sidebar.
**Why it happens:** ExDoc only processes files explicitly listed in `:extras`. Glob patterns
in `groups_for_extras` do NOT serve as the extras list — they only group what's in `:extras`.
**How to avoid:** List every guide file individually in `:extras`. Then use
`Path.wildcard("guides/*.{md,cheatmd}")` in `groups_for_extras` to group them.
**Warning signs:** `mix docs` completes but sidebar shows no guides section.

### Pitfall 3: Resource module has @moduledoc false — conflicts with D-03
**What goes wrong:** `@moduledoc false` hides the module from ExDoc entirely. Per D-03,
internal modules should be in the "Internals" group, not hidden.
**Why it happens:** Resource was marked false during development to suppress docs noise.
**How to avoid:** Change to `@moduledoc """..."""` with a real explanation of the module's
purpose (shared helpers for resource modules) and add to "Internals" group.
**Warning signs:** Resource module doesn't appear in generated docs at all.

### Pitfall 4: .cheatmd layout attributes on wrong line
**What goes wrong:** Two-column layout doesn't render — content appears as single column.
**Why it happens:** The `{: .col-2}` attribute must appear on the line AFTER the `##`
section heading, not after text or code blocks.
**How to avoid:** Place `{: .col-2}` immediately after the `## Section Name` line.
**Warning signs:** Cheatsheet renders as single column despite using `col-2` syntax.

### Pitfall 5: Logo path doesn't exist — mix docs --warnings-as-errors fails
**What goes wrong:** CI gate `mix docs --warnings-as-errors` fails because the logo file
is missing.
**Why it happens:** D-05 requires logo branding but the asset doesn't exist yet.
**How to avoid:** Either create the asset before configuring logo in mix.exs, or defer
`logo:` config until the asset is ready. Don't add a logo path that doesn't exist.
**Warning signs:** ExDoc warns about missing logo file; CI fails.

### Pitfall 6: Webhook.Plug wrapped in `if Code.ensure_loaded?(Plug)` — affects ExDoc
**What goes wrong:** If Plug is not available in the docs build environment, the module
won't be compiled and ExDoc won't document it.
**Why it happens:** Webhook.Plug uses conditional compilation to make Plug optional.
**How to avoid:** Ensure Plug is available during `mix docs` (it is, as a dep in mix.exs).
The `optional: true` flag on Plug as a dep means it needs to be present in the deps list
but isn't forced on users. ExDoc runs in dev env where Plug is available.
**Warning signs:** Webhook.Plug module missing from generated docs.

## Code Examples

### mix.exs docs() function (verified pattern)

```elixir
# Source: ExDoc 0.40.1 official configuration
@version "0.1.0"
@source_url "https://github.com/lattice-stripe/lattice_stripe"

docs: [
  main: "getting-started",
  source_url: @source_url,
  source_ref: "v#{@version}",
  extras: [
    "guides/getting-started.md",
    "guides/client-configuration.md",
    "guides/payments.md",
    "guides/checkout.md",
    "guides/webhooks.md",
    "guides/error-handling.md",
    "guides/testing.md",
    "guides/telemetry.md",
    "guides/extending-lattice-stripe.md",
    "guides/cheatsheet.cheatmd",
    "CHANGELOG.md"
  ],
  groups_for_extras: [
    "Guides": Path.wildcard("guides/*.{md,cheatmd}"),
    "Changelog": ["CHANGELOG.md"]
  ],
  groups_for_modules: [
    "Core": [...],
    "Payments": [...],
    ...
  ]
]
```

### .cheatmd basic structure (verified pattern)

```markdown
# LatticeStripe Cheatsheet

## Setup
{: .col-2}

### Add dependency

```elixir
{:lattice_stripe, "~> 0.1"}
```

### Create client

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch
)
```
```

### @typedoc for a resource struct (D-28 pattern)

```elixir
@typedoc """
A Stripe Customer object.

See [Stripe Customers API](https://docs.stripe.com/api/customers/object) for field definitions.
"""
@type t :: %__MODULE__{
  id: String.t() | nil,
  email: String.t() | nil,
  ...
}
```

### Guide Common Pitfalls section template (D-13)

```markdown
## Common Pitfalls

### Amount is in smallest currency unit

Stripe amounts are in cents (USD) or the smallest unit for other currencies.
`2000` means $20.00 USD, not $2,000. See [Stripe's zero-decimal currencies](https://docs.stripe.com/currencies#zero-decimal)
for currencies that don't use subdivisions.

### PaymentIntent requires Finch in supervision tree

...
```

## Guide Content Map

What each guide needs to cover (for planner task scoping):

| Guide | Core Scenarios | Stripe API Links |
|-------|----------------|-----------------|
| getting-started.md | Install, supervision tree, create client, first PaymentIntent | docs.stripe.com/api |
| client-configuration.md | All Client.new! options, per-request overrides, Connect usage | docs.stripe.com/connect |
| payments.md | Create customer → create PaymentIntent → confirm → handle errors → refund | docs.stripe.com/payments |
| checkout.md | Create session (payment/subscription/setup modes), redirect flow, session expiry | docs.stripe.com/checkout |
| webhooks.md | Plug setup (Option A + B), signature verification, Phoenix integration, secret rotation | docs.stripe.com/webhooks |
| error-handling.md | Pattern matching on Error types, all error types, retry behavior | docs.stripe.com/error-codes |
| testing.md | Mox Transport mock in user apps, LatticeStripe.Testing helpers, stripe-mock setup | docs.stripe.com/testing |
| telemetry.md | attach_default_logger, custom telemetry handler, all events + metadata | hexdocs.pm/telemetry |
| extending-lattice-stripe.md | Custom Transport impl, custom Json codec impl, custom RetryStrategy impl | — |
| cheatsheet.cheatmd | Quick reference: client setup, charge, checkout, webhook verify, error match | — |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| groups_for_modules as list of modules | Now supports regex and string matching | ExDoc 0.34+ | Simpler for large module groups |
| @moduledoc false to hide internals | groups_for_modules "Internals" group | ExDoc 0.30+ | D-03 is achievable without hiding |
| Separate extras syntax in old ExDoc | Keyword-pair extras for title override | ExDoc 0.34+ | `"path": [title: "Custom"]` format works |

## Environment Availability

Step 2.6: SKIPPED — Phase 10 is purely documentation work (file authoring + mix.exs config). No new external service dependencies beyond what's already installed. ExDoc 0.40.1 confirmed in mix.lock.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | test/test_helper.exs |
| Quick run command | `mix docs --warnings-as-errors` |
| Full suite command | `mix ci` (includes docs build) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-01 | All public modules have @moduledoc | mix docs build | `mix docs --warnings-as-errors` | ✅ (CI alias) |
| DOCS-02 | All public functions have @doc | mix docs build | `mix docs --warnings-as-errors` | ✅ (CI alias) |
| DOCS-03 | ExDoc generates grouped navigable docs | mix docs build + manual review | `mix docs && open doc/index.html` | ✅ |
| DOCS-04 | README quickstart is <60s | Manual review | manual | N/A |
| DOCS-05 | All 9 guides exist with full content | mix docs build | `mix docs --warnings-as-errors` | ❌ Wave 0 |
| DOCS-06 | Non-obvious code has comments | Code review | `mix credo --strict` (partial) | ✅ |

### Sampling Rate
- **Per task commit:** `mix docs --warnings-as-errors`
- **Per wave merge:** `mix ci`
- **Phase gate:** Full `mix ci` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `guides/` directory — all 9 .md + 1 .cheatmd files need to exist before mix docs can validate them
- [ ] `CHANGELOG.md` — must exist before being listed in extras

## Sources

### Primary (HIGH confidence)
- ExDoc 0.40.1 hex package + mix.lock verification — version confirmed
- ExDoc.generate/4 hexdocs — groups_for_modules, groups_for_extras, extras, source_ref, logo syntax
- Codebase audit (direct file reads) — @doc coverage counts, module list, mix.exs current config

### Secondary (MEDIUM confidence)
- ExDoc GitHub README — basic configuration patterns
- ExDoc cheatsheet.html — .cheatmd format and layout attributes

### Tertiary (LOW confidence)
None — all critical claims verified against official sources or codebase directly.

## Metadata

**Confidence breakdown:**
- ExDoc configuration: HIGH — verified against ExDoc 0.40.1 docs and installed version
- @doc coverage audit: HIGH — direct file reads of all 23+ modules
- Guide content scope: HIGH — derived from CONTEXT.md locked decisions
- .cheatmd format: MEDIUM — verified from ExDoc docs, limited examples found

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (ExDoc API is stable; 30-day window is conservative)
