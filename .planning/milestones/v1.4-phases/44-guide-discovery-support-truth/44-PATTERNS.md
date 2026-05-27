# Phase 44: Guide Discovery & Support Truth - Pattern Map

## File Classification

| File | Role | Why it matters |
|------|------|----------------|
| `README.md` | repo landing page | First impression and highest-visibility route-by-intent surface |
| `guides/getting-started.md` | HexDocs main page | First-success onboarding page; must branch clearly after the initial API call |
| `guides/user-flows-and-jtbd.md` | evaluator routing layer | Best existing task-first orientation page; should route into canonical guides |
| `guides/recipes.md` | compact bridge layer | Good job-to-primitive bridge that must stay library-scoped |
| `guides/subscriptions.md` | canonical recurring-billing guide | One of the most important adopter destinations |
| `guides/customer-portal.md` | canonical self-serve billing guide | Natural follow-through guide after subscriptions and failed-payment recovery |
| `guides/metering.md` | canonical usage-billing guide | High-value runtime surface the milestone wants surfaced earlier |
| `guides/connect.md` | canonical Connect landing guide | Primary platform/marketplace destination from evaluator routing |
| `guides/connect-accounts.md` | deeper Connect lifecycle guide | Important for account onboarding and connected-account setup follow-through |
| `guides/connect-money-movement.md` | deeper Connect funds-flow guide | Important for payout / transfer / reconciliation follow-through |
| `guides/webhooks.md` | canonical async truth guide | The central “webhooks confirm reality” trust rail |
| `guides/testing.md` | testing and proof guide | Trust rail for fixture surface and application-level confidence |
| `guides/error-handling.md` | support-facing ops guide | Trust rail for runtime failure posture and troubleshooting |
| `mix.exs` | ExDoc publication and grouping source | Controls which docs are visible and how layered navigation appears |
| `test/lattice_stripe/docs_truth_test.exs` | regression guard | Best place to lock guide discovery and support-truth routing into CI |

## Pattern Assignments

### `README.md`

- Pattern: route-by-intent first impression
- Pattern: compact “start here / next if you care about X” ladders
- Reuse for:
  - surfacing subscriptions, portal, webhooks, metering, Connect, testing, and troubleshooting
  - sending evaluators to `guides/user-flows-and-jtbd.md` and `guides/getting-started.md` without making either redundant

### `guides/getting-started.md`

- Pattern: first-success path followed by deliberate branching
- Pattern: short next-step menus keyed to common SaaS jobs
- Reuse for:
  - branching first-run users into recurring billing, customer portal, webhooks, metering, Connect, testing, and error handling
  - preserving the “one successful call” starter experience

### `guides/user-flows-and-jtbd.md`

- Pattern: task-first routing layer
- Pattern: runtime-truth framing with “accepted now vs true later”
- Reuse for:
  - mapping jobs to canonical guides
  - linking serious evaluators into the right guide cluster without becoming a second docs hierarchy

### `guides/recipes.md`

- Pattern: compact bridge from jobs to primitives
- Pattern: read-next lists after webhook confirmation points
- Reuse for:
  - routing from compact recipes into canonical guides and trust rails
  - preserving library scope

### Canonical guides (`subscriptions`, `customer-portal`, `metering`, `connect*`, `webhooks`, `testing`, `error-handling`)

- Pattern: inline support-truth note at the operational boundary
- Pattern: “See also” / “Read next” adjacency into the next truthful guide
- Reuse for:
  - connecting setup, runtime, and troubleshooting paths
  - keeping high-stakes caveats visible where users act

### `mix.exs`

- Pattern: layered docs publication
- Reuse for:
  - separating “Start Here”, canonical surface guides, and operations/DX guidance in ExDoc groups
  - keeping `main: "getting-started"` intact while making the broader guide graph easier to scan

### `test/lattice_stripe/docs_truth_test.exs`

- Pattern: lightweight file-content assertions
- Pattern: docs metadata assertions through `LatticeStripe.MixProject.project/0`
- Reuse for:
  - protecting discovery-route anchors on README / Getting Started / JTBD / recipes
  - protecting ExDoc grouping roles without snapshotting whole prose blocks

## Recommended Planning Split

### Plan 01

- Primary files: `README.md`, `guides/getting-started.md`, `guides/user-flows-and-jtbd.md`, `guides/recipes.md`, `mix.exs`
- Goal: make the main entry points and ExDoc hierarchy clearly route to already-shipped high-leverage surfaces

### Plan 02

- Primary files: `guides/webhooks.md`, `guides/testing.md`, `guides/error-handling.md`, `guides/subscriptions.md`, `guides/customer-portal.md`, `guides/metering.md`, `guides/connect.md`, `guides/connect-accounts.md`, `guides/connect-money-movement.md`, `test/lattice_stripe/docs_truth_test.exs`
- Optional file: a small secondary support-truth/orientation guide if execution proves it adds value without becoming the sole caveat location
- Goal: make navigation honest inside the guide graph itself and prevent discovery/support-truth drift

## Risks

- Over-designing ExDoc grouping and forcing a larger docs rewrite than the phase needs
- Treating recipes or JTBD as a competing canonical map
- Adding a centralized support-truth page that becomes the only place caveats live
- Writing tests that assert exact paragraph prose instead of durable route anchors and docs metadata

---
*Phase: 44-guide-discovery-support-truth*
