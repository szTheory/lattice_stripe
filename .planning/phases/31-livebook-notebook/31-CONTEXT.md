# Phase 31: LiveBook Notebook - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a single interactive LiveBook notebook (`notebooks/stripe_explorer.livemd`) that lets developers explore the complete LatticeStripe v1.2 API surface — from client configuration through payments, billing, metering, connect, and portal flows — without reading documentation linearly. The notebook is a developer onboarding and exploration tool, not a test suite or documentation replacement.

</domain>

<decisions>
## Implementation Decisions

### Notebook Structure
- **D-01:** Single notebook file `notebooks/stripe_explorer.livemd` — not multiple notebooks. DX-05 names one file, and a single progressive notebook provides the best guided exploration experience.
- **D-02:** Sections follow the ExDoc nine-group order: Client & Configuration → Payments → Billing → Connect → Webhooks. This matches the existing documentation hierarchy developers will encounter on HexDocs.

### Stripe Connectivity
- **D-03:** stripe-mock is the primary backend. The setup section documents how to start stripe-mock via Docker (`docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`) and pre-fills the base URL. A note documents how to switch to a real test API key for those who prefer it.
- **D-04:** Use `Kino.Input.text/2` for the API key field with a stripe-mock default value pre-filled (e.g., `sk_test_...`). The base URL input defaults to `http://localhost:12111`. This makes the notebook zero-config for stripe-mock users while remaining configurable.

### Interactive Elements (Kino)
- **D-05:** Include `kino` in `Mix.install/2` for interactive widgets. Use `Kino.Input.text/2` for configuration inputs, `Kino.DataTable.new/2` for list/search results display, and `Kino.Tree.new/1` for inspecting nested struct responses.
- **D-06:** Response display uses raw struct output for simple returns and `Kino.Tree` for deeply nested structs (e.g., expanded objects, BillingPortal.Configuration). This shows developers the real SDK return types.

### Exercise Coverage
- **D-07:** Each section demonstrates the golden path per resource: create → retrieve → list (where applicable), plus one advanced flow that highlights the resource's key capability (e.g., confirm for PaymentIntent, cancel+resume for Subscription, deactivate/reactivate for Meter).
- **D-08:** v1.2 features get dedicated highlight sections: expand deserialization (showing `%Customer{}` vs string ID), `Batch.run/3` for concurrent requests, changeset-style param builders for SubscriptionSchedule, and `MeterEventStream` session lifecycle.

### Mix.install Configuration
- **D-09:** `Mix.install/2` block pins `lattice_stripe` via `path: "."` for local development with a commented alternative for the released hex version (`{:lattice_stripe, "~> 1.2"}`). Include `{:kino, "~> 0.14"}` for interactive widgets.

### Claude's Discretion
- Prose tone and density between sections — informative but concise, matching existing guide style
- Exact Kino widget choices for each section (DataTable vs Tree vs raw output) based on what displays best
- Whether to include a "cleanup" section at the end that deletes test resources created during exploration
- Section ordering within each group (e.g., PaymentIntent before SetupIntent within Payments)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### SDK Structure
- `mix.exs` — Module groups, dependency list, ExDoc configuration (nine-group layout)
- `lib/lattice_stripe.ex` — Top-level module with `warm_up/1` and delegation functions

### Guides (content model for prose sections)
- `guides/getting-started.md` — Quickstart pattern to mirror in notebook intro
- `guides/client-configuration.md` — Client setup patterns
- `guides/payments.md` — PaymentIntent lifecycle
- `guides/subscriptions.md` — Subscription lifecycle
- `guides/metering.md` — Meter + MeterEvent + MeterEventAdjustment patterns
- `guides/customer-portal.md` — BillingPortal.Session creation
- `guides/connect.md` — Connect overview
- `guides/performance.md` — Batch, warm-up, timeout patterns

### Key Modules to Exercise
- `lib/lattice_stripe/client.ex` — Client.new!/1 configuration
- `lib/lattice_stripe/batch.ex` — Batch.run/3 concurrent helper
- `lib/lattice_stripe/billing/meter_event_stream.ex` — v2 session-token API
- `lib/lattice_stripe/builders/` — Changeset-style param builders

### Testing Infrastructure (stripe-mock patterns)
- `test/support/` — Fixture patterns and stripe-mock connection setup

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/getting-started.md` — Contains the quickstart code pattern (Client.new!, create PaymentIntent) that the notebook intro section should mirror
- `test/support/fixtures/` — Fixture maps showing valid param shapes for each resource, useful as notebook exercise templates
- `test/integration/` — Integration test patterns show exactly which stripe-mock endpoints work and what params they accept

### Established Patterns
- All resources follow `Module.create/3`, `Module.retrieve/3`, `Module.list/2` convention
- `{:ok, %Struct{}} | {:error, %Error{}}` return pattern everywhere
- stripe-mock listens on port 12111 (HTTP) and 12112 (HTTPS)
- `Client.new!/1` accepts `api_key:`, `base_url:`, and other opts

### Integration Points
- `notebooks/` directory does not exist yet — needs creation
- No changes to `mix.exs` needed (LiveBook notebook is standalone, not a project dependency)
- ExDoc `extras:` list in `mix.exs` could optionally reference the notebook but this is not required

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for LiveBook notebook design. The notebook should feel like a guided workshop: setup → explore → experiment.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 31-livebook-notebook*
*Context gathered: 2026-04-16*
