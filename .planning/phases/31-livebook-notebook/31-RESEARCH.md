# Phase 31: LiveBook Notebook - Research

**Researched:** 2026-04-16
**Domain:** LiveBook `.livemd` format, Kino interactive widgets, SDK documentation notebooks
**Confidence:** HIGH

## Summary

Phase 31 delivers a single interactive LiveBook notebook (`notebooks/stripe_explorer.livemd`) that lets developers explore the complete LatticeStripe v1.2 API surface interactively. The notebook is a standalone file — no changes to `mix.exs`, no test files, no new modules. It uses `Mix.install/2` with `path: "."` for local use and `{:kino, "~> 0.14"}` for interactive widgets.

The implementation is primarily a content authoring task, not a coding task. The key technical decisions are: correct `Mix.install/2` form for a local `path:` dependency with Finch startup in the notebook itself, Kino widget selection per section (Input for config, DataTable for list results, Tree for nested structs), and faithful coverage of the nine ExDoc groups in order. The notebook does not interact with an OTP application — Finch is started directly with `Finch.start_link/1` inside the notebook's setup cell.

Stripe-mock is the primary backend (`http://localhost:12111`), configured via a pre-filled `Kino.Input.text` field. The notebook requires no changes to the existing codebase; the `notebooks/` directory is new.

**Primary recommendation:** Author the notebook as a guided workshop with alternating Markdown prose and executable code cells. Use `Finch.start_link(name: StripeExplorer.Finch)` in the setup section, build a `Client` struct from `Kino.Input` values, then demonstrate each resource group's golden path sequentially.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Single notebook file `notebooks/stripe_explorer.livemd` — not multiple notebooks.
- **D-02:** Sections follow the ExDoc nine-group order: Client & Configuration → Payments → Billing → Connect → Webhooks.
- **D-03:** stripe-mock is the primary backend. Setup section documents `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`. A note documents how to switch to a real test API key.
- **D-04:** Use `Kino.Input.text/2` for the API key field with a stripe-mock default value pre-filled (`sk_test_...`). Base URL input defaults to `http://localhost:12111`.
- **D-05:** Include `kino` in `Mix.install/2`. Use `Kino.Input.text/2` for config inputs, `Kino.DataTable.new/2` for list/search results, `Kino.Tree.new/1` for deeply nested struct responses.
- **D-06:** Response display uses raw struct output for simple returns and `Kino.Tree` for deeply nested structs (BillingPortal.Configuration, expanded objects).
- **D-07:** Each section demonstrates golden path per resource: create → retrieve → list (where applicable) + one advanced flow per resource's key capability.
- **D-08:** v1.2 features get dedicated highlight sections: expand deserialization, `Batch.run/3`, changeset-style param builders for SubscriptionSchedule, `MeterEventStream` session lifecycle.
- **D-09:** `Mix.install/2` pins `lattice_stripe` via `path: "."` for local development. Commented alternative for hex release. Include `{:kino, "~> 0.14"}`.

### Claude's Discretion
- Prose tone and density between sections — informative but concise, matching existing guide style
- Exact Kino widget choices for each section (DataTable vs Tree vs raw output) based on what displays best
- Whether to include a "cleanup" section at the end that deletes test resources created during exploration
- Section ordering within each group (e.g., PaymentIntent before SetupIntent within Payments)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-05 | Developer can explore the SDK interactively via a `notebooks/stripe_explorer.livemd` LiveBook notebook | Verified: Kino 0.19.0 provides Input.text, DataTable.new, Tree.new; Mix.install with `path: "."` is the correct local-dev form; stripe-mock runs on localhost:12111 as confirmed by integration test infrastructure |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Notebook file | Static/Documentation | — | A `.livemd` file served by LiveBook runtime, not part of the OTP app |
| HTTP transport | Browser / LiveBook runtime | — | Finch started directly in the notebook setup cell, not supervised by any app |
| Stripe API calls | Notebook code cells | LatticeStripe SDK (lib/) | Notebook calls SDK functions; SDK owns request/response logic |
| Interactive inputs | LiveBook / Kino | — | Kino.Input fields are rendered by LiveBook UI |
| Data display | LiveBook / Kino | — | Kino.DataTable and Kino.Tree render in LiveBook UI |
| stripe-mock backend | External service (Docker) | — | Launched by developer before running notebook |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| kino | ~> 0.14 (latest: 0.19.0) | Interactive widgets (Input, DataTable, Tree) | Official LiveBook companion library; D-09 specifies `~> 0.14` constraint |
| lattice_stripe | `path: "."` or `~> 1.2` | SDK under exploration | The subject of the notebook |
| finch | ~> 0.21 | HTTP connection pool (started in notebook) | Required by lattice_stripe transport |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jason | ~> 1.4 | JSON codec (transitive) | Pulled in by lattice_stripe |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Kino.Tree.new/1` | `IO.inspect/2` or raw struct | Tree gives collapsible nested view; better for deep structs like BillingPortal.Configuration |
| `Kino.DataTable.new/2` | Plain list display | DataTable adds sorting and pagination for list results |
| `path: "."` | `{:lattice_stripe, "~> 1.2"}` | path: works for local development during authoring; hex version is what end-users of the published notebook will use |

**Installation (Mix.install block for the notebook):**
```elixir
Mix.install([
  {:lattice_stripe, path: "."},
  # Alternatively, for released version:
  # {:lattice_stripe, "~> 1.2"},
  {:kino, "~> 0.14"},
  {:finch, "~> 0.21"}
])
```

**Version verification:**
- kino: `0.19.0` — published 2026-03-03 [VERIFIED: hex.pm API]
- kino `~> 0.14` constraint covers 0.14.x through 0.19.x [VERIFIED: SemVer ~> rule]
- The kino README itself shows `{:kino, "~> 0.19.0"}` for current install [VERIFIED: github.com/livebook-dev/kino README]

**Note on `~> 0.14` vs `~> 0.19.0`:** D-09 specifies `~> 0.14`, which covers the full 0.x minor series including 0.19. This is intentionally permissive. The planner may choose to use `~> 0.14` (as per D-09) or tighten to `~> 0.19` — both are valid. The `~> 0.14` form is what D-09 locks.

## Architecture Patterns

### System Architecture Diagram

```
Developer opens stripe_explorer.livemd in LiveBook
          │
          ▼
[Setup Cell] Mix.install → loads lattice_stripe + kino + finch
          │
          ▼
[Setup Cell] Finch.start_link(name: StripeExplorer.Finch)
          │
          ▼
[Config Section]
  Kino.Input.text("API Key", default: "sk_test_...")  ──────────────┐
  Kino.Input.text("Base URL", default: "http://localhost:12111")     │
          │                                                           │
          ▼                                                           │
  client = Client.new!(api_key: ..., base_url: ..., finch: ...)      │
                                                                      │
          │                                                           │
          ▼                                                           ▼
[Resource Sections]                                          stripe-mock (Docker)
  PaymentIntent.create → display struct                      or real Stripe test API
  PaymentIntent.retrieve → display struct
  PaymentIntent.list → Kino.DataTable.new(results.data)
  PaymentIntent.confirm → advanced flow
          │
  [Repeat per section: Billing, Connect, Portal, Webhooks]
          │
          ▼
[v1.2 Highlights Section]
  Batch.run/3 → concurrent fan-out demo
  Expand deserialization → %Customer{} vs string ID
  SubscriptionSchedule builder → SSBuilder pipe chain
  MeterEventStream → create_session + send_events
```

### Recommended Project Structure
```
notebooks/
└── stripe_explorer.livemd   # Single notebook (new directory, new file)
```

No other directories or files are needed. No changes to `lib/`, `test/`, or `mix.exs`.

### Pattern 1: Mix.install with local path dependency
**What:** Start the notebook with a `Mix.install/2` block that loads the local SDK and Kino.
**When to use:** Always — first cell of the notebook.
**Example:**
```elixir
# Source: livebook-dev/livebook docs, Mix.install path usage
Mix.install([
  {:lattice_stripe, path: "."},
  # For released hex version, comment out above and uncomment:
  # {:lattice_stripe, "~> 1.2"},
  {:kino, "~> 0.14"},
  {:finch, "~> 0.21"}
])
```

### Pattern 2: Finch startup in notebook (no OTP application)
**What:** Start Finch manually since the notebook runs outside any OTP application.
**When to use:** In the setup section, after Mix.install.
**Example:**
```elixir
# Source: guides/getting-started.md "Non-OTP scripts" note
{:ok, _} = Finch.start_link(name: StripeExplorer.Finch)
```

### Pattern 3: Kino.Input for configuration
**What:** Render text inputs and read their values synchronously in a later cell.
**When to use:** Setup section for API key and base URL.
**Example:**
```elixir
# Source: hexdocs.pm/kino/Kino.Input.html [VERIFIED]
api_key_input = Kino.Input.text("Stripe API Key", default: "sk_test_123")
base_url_input = Kino.Input.text("Base URL", default: "http://localhost:12111")
```
```elixir
# In the NEXT cell — Kino.Input.read/1 reads the current value synchronously
api_key = Kino.Input.read(api_key_input)
base_url = Kino.Input.read(base_url_input)

client = LatticeStripe.Client.new!(
  api_key: api_key,
  base_url: base_url,
  finch: StripeExplorer.Finch
)
```

**Critical:** The `Kino.Input` widget must be rendered in one cell, and `Kino.Input.read/1` called in the NEXT cell. Reading in the same cell as rendering returns the default value before the user can change it. [VERIFIED: hexdocs.pm/kino Kino.Input.html — `read/1` is "synchronous"]

### Pattern 4: Kino.DataTable for list results
**What:** Display a list of Stripe structs as a sortable, paginated table.
**When to use:** After `.list/2` calls that return `%LatticeStripe.List{data: [...]}`.
**Example:**
```elixir
# Source: hexdocs.pm/kino/Kino.DataTable.html [VERIFIED]
{:ok, result} = LatticeStripe.PaymentIntent.list(client, %{"limit" => "5"})
Kino.DataTable.new(result.data, name: "Payment Intents")
```

### Pattern 5: Kino.Tree for nested structs
**What:** Display a deeply-nested struct with collapsible nodes.
**When to use:** After retrieving resources with nested sub-structs (BillingPortal.Configuration, expanded objects).
**Example:**
```elixir
# Source: hexdocs.pm/kino/Kino.Tree.html [VERIFIED]
{:ok, config} = LatticeStripe.BillingPortal.Configuration.retrieve(client, "bpc_123")
Kino.Tree.new(config)
```

### Pattern 6: Batch.run/3 demonstration
**What:** Show concurrent fan-out pattern with error isolation.
**When to use:** v1.2 highlights section.
**Example:**
```elixir
# Source: lib/lattice_stripe/batch.ex [VERIFIED from codebase]
{:ok, [customer_result, sub_result, invoice_result]} =
  LatticeStripe.Batch.run(client, [
    {LatticeStripe.Customer, :retrieve, [customer.id]},
    {LatticeStripe.Subscription, :list, [%{"customer" => customer.id}]},
    {LatticeStripe.Invoice, :list, [%{"customer" => customer.id}]}
  ])
```

### Pattern 7: MeterEventStream session lifecycle
**What:** Two-step session-token API for high-throughput meter events.
**When to use:** Billing Metering → v2 stream section.
**Example:**
```elixir
# Source: lib/lattice_stripe/billing/meter_event_stream.ex [VERIFIED from codebase]
{:ok, session} = LatticeStripe.Billing.MeterEventStream.create_session(client)

events = [
  %{"event_name" => "api_call", "payload" => %{"stripe_customer_id" => customer.id, "value" => "1"}}
]

{:ok, %{}} = LatticeStripe.Billing.MeterEventStream.send_events(client, session, events)
```

**Note:** stripe-mock may not support the v2 `meter-events.stripe.com` endpoint — the `MeterEventStream` module calls a different host (`meter-events.stripe.com`) with a session token. The notebook should include a comment explaining this limitation and suggesting users run this section against a real Stripe test key. [ASSUMED — requires verification when implementing]

### Pattern 8: SubscriptionSchedule builder
**What:** Demonstrate the fluent builder API for complex nested params.
**When to use:** Billing → Subscription Schedules section.
**Example:**
```elixir
# Source: lib/lattice_stripe/builders/subscription_schedule.ex [VERIFIED from codebase]
alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder

params =
  SSBuilder.new()
  |> SSBuilder.customer(customer.id)
  |> SSBuilder.start_date(:now)
  |> SSBuilder.end_behavior(:release)
  |> SSBuilder.add_phase(
       SSBuilder.phase_new()
       |> SSBuilder.phase_items([%{"price" => price.id, "quantity" => 1}])
       |> SSBuilder.phase_iterations(3)
       |> SSBuilder.phase_build()
     )
  |> SSBuilder.build()

{:ok, schedule} = LatticeStripe.SubscriptionSchedule.create(client, params)
```

### Anti-Patterns to Avoid
- **Reading Kino.Input in the same cell it's rendered:** `Kino.Input.read/1` in the same cell as `Kino.Input.text/2` returns the default value immediately, before the user can change it. Always split into two cells.
- **Global client as module attribute:** In a notebook, the client must be built from the Kino.Input values in a code cell, not a module attribute (module attributes evaluate at compile time, before user inputs are read).
- **Starting Finch without a unique name:** If the notebook is re-run, `Finch.start_link/1` will fail because the named process already exists. Wrap in a guard or use `{:ok, _} = ...` with a match that tolerates `{:error, {:already_started, _}}`.
- **Hardcoding stripe-mock IDs:** stripe-mock generates fresh IDs on every create call. Never hardcode IDs from one section's output into a later section; instead carry them via variables.
- **Logging session.url or auth tokens:** `BillingPortal.Session.url` and `MeterEventStream.Session.authentication_token` are bearer credentials. Prose should warn not to log or store them.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interactive configuration UI | Custom input parsing | `Kino.Input.text/2` + `Kino.Input.read/1` | Purpose-built, renders in LiveBook UI |
| Tabular list display | Manual string formatting | `Kino.DataTable.new/2` | Sortable, paginated, handles structs via Table.Reader protocol |
| Nested struct inspection | `IO.inspect/2` with pretty: true | `Kino.Tree.new/1` | Collapsible tree view, far more usable for 4-level nesting |
| JSON rendering | Custom formatter | Raw struct display (simpler resources) | Structs print readably in LiveBook already |

**Key insight:** LiveBook's kernel renders Elixir structs legibly by default. Use Kino only where interactivity or structure adds clear value.

## Runtime State Inventory

> This is a greenfield addition (new directory, new file). No rename or refactor. Skipping this section.

## Environment Availability Audit

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| LiveBook | Running the notebook | Unknown — developer's machine | — | Install via `mix escript.install hex livebook` or `brew install livebook` |
| Docker | stripe-mock backend | Unknown — developer's machine | — | Use real Stripe test key (documented in notebook) |
| stripe-mock (Docker image) | API calls in notebook | Unknown — must be started | — | Real test API key |
| Finch | HTTP transport | Pulled in via Mix.install | 0.21.x | — |
| kino | Interactive widgets | Pulled in via Mix.install | 0.19.0 | — |

**Missing dependencies with no fallback:**
- LiveBook itself — the notebook is useless without it. The notebook's README-style prose section should include the install command.

**Missing dependencies with fallback:**
- Docker / stripe-mock — notebook documents the real test key alternative.

## Common Pitfalls

### Pitfall 1: Finch already started on notebook re-run
**What goes wrong:** Executing the setup cell a second time raises `{:error, {:already_started, #PID<...>}}` because `StripeExplorer.Finch` is already registered.
**Why it happens:** `Finch.start_link/1` registers a named process; re-running the cell attempts to re-register the same name.
**How to avoid:** Pattern match to tolerate the already-started case:
```elixir
case Finch.start_link(name: StripeExplorer.Finch) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end
```
**Warning signs:** `** (MatchError) no match of right hand side value: {:error, {:already_started, ...}}` on second run.

### Pitfall 2: MeterEventStream incompatible with stripe-mock
**What goes wrong:** `MeterEventStream.create_session/1` targets `api.stripe.com/v2/billing/meter_event_session`; `send_events/3` targets `meter-events.stripe.com`. stripe-mock may not serve the v2 endpoint.
**Why it happens:** stripe-mock is powered by Stripe's OpenAPI v1 spec; v2 endpoints may not be included.
**How to avoid:** Include a prose note in the MeterEventStream section explaining this limitation and instructing users to either skip this section or substitute a real test API key. Demonstrate the function signatures and session expiry check regardless.
**Warning signs:** `{:error, %LatticeStripe.Error{type: :api_error}}` or a 404 from stripe-mock on the session create call. [ASSUMED — needs verification during implementation]

### Pitfall 3: Kino.Input read/render in same cell
**What goes wrong:** `Kino.Input.read(input)` called in the same cell as `Kino.Input.text(...)` returns the default value immediately, not the user-entered value.
**Why it happens:** Cell evaluation is synchronous; the user has no opportunity to type before `read/1` executes.
**How to avoid:** Always put the `Kino.Input.text/2` call in one cell (to render the widget), and `Kino.Input.read/1` + `Client.new!` in the next cell.
**Warning signs:** `Client.new!` always uses the stripe-mock default even after the user edited the input field.

### Pitfall 4: Resource IDs not carried across sections
**What goes wrong:** A later section (e.g., BillingPortal.Session) tries to use `customer.id` from an earlier section, but the variable isn't in scope if sections are run out of order.
**Why it happens:** Each LiveBook section can be run independently; variables from earlier sections may not be bound.
**How to avoid:** At the start of each section that depends on a prior resource, include a note: "Run the Customer section first, or substitute any `cus_...` ID here." Alternatively, re-create minimal dependencies at the top of each self-contained section.
**Warning signs:** `** (CompileError) undefined variable "customer"`.

### Pitfall 5: stripe-mock generates deterministic but not real IDs
**What goes wrong:** stripe-mock returns IDs like `pi_xxxxxxxxxxxxx` that look real but aren't recognized by the real Stripe API.
**Why it happens:** stripe-mock is a test server that generates fake-but-valid-looking IDs.
**How to avoid:** The notebook prose should note this explicitly for the Connect section, where `stripe_account:` IDs from stripe-mock won't be recognized by real Connect APIs.

## Code Examples

### Complete Setup Section
```elixir
# Source: guides/getting-started.md + Kino docs [VERIFIED from codebase + hexdocs]

# Cell 1: Install
Mix.install([
  {:lattice_stripe, path: "."},
  # Alternatively, for the released hex version:
  # {:lattice_stripe, "~> 1.2"},
  {:kino, "~> 0.14"},
  {:finch, "~> 0.21"}
])

# Cell 2: Start Finch (tolerates re-run)
case Finch.start_link(name: StripeExplorer.Finch) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

# Cell 3: Configuration inputs (renders widgets)
api_key_input = Kino.Input.text("Stripe API Key", default: "sk_test_123")
base_url_input = Kino.Input.text("Base URL", default: "http://localhost:12111")

# Cell 4: Build client (reads widget values)
api_key = Kino.Input.read(api_key_input)
base_url = Kino.Input.read(base_url_input)

client = LatticeStripe.Client.new!(
  api_key: api_key,
  base_url: base_url,
  finch: StripeExplorer.Finch
)
```

### PaymentIntent Golden Path
```elixir
# Source: test/integration/payment_intent_integration_test.exs [VERIFIED from codebase]

# Create
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => "2000",
  "currency" => "usd"
})

# Retrieve
{:ok, retrieved} = LatticeStripe.PaymentIntent.retrieve(client, intent.id)

# List (display with DataTable)
{:ok, list} = LatticeStripe.PaymentIntent.list(client, %{"limit" => "5"})
Kino.DataTable.new(list.data, name: "Recent PaymentIntents")

# Advanced: Confirm
{:ok, confirmed} = LatticeStripe.PaymentIntent.confirm(client, intent.id, %{
  "payment_method" => "pm_card_visa"
})
```

### Subscription Golden Path
```elixir
# Source: guides/subscriptions.md + test fixtures [VERIFIED from codebase]

# Prerequisites: customer + price from earlier sections
{:ok, sub} = LatticeStripe.Subscription.create(client, %{
  "customer" => customer.id,
  "items" => [%{"price" => price.id, "quantity" => 1}]
})

# Retrieve
{:ok, retrieved_sub} = LatticeStripe.Subscription.retrieve(client, sub.id)

# List
{:ok, sub_list} = LatticeStripe.Subscription.list(client, %{"customer" => customer.id})
Kino.DataTable.new(sub_list.data, name: "Subscriptions")

# Advanced: cancel at period end
{:ok, cancelled_sub} = LatticeStripe.Subscription.cancel(client, sub.id, %{
  "cancellation_details" => %{"comment" => "Exploring the SDK"}
})
```

### BillingPortal Session (uses Kino.Tree for nested struct)
```elixir
# Source: guides/customer-portal.md [VERIFIED from codebase]

{:ok, portal_session} = LatticeStripe.BillingPortal.Session.create(client, %{
  "customer" => customer.id,
  "return_url" => "https://example.com/account"
})

# Use Kino.Tree for nested flow_data
Kino.Tree.new(portal_session)
```

### Batch.run/3 v1.2 Highlight
```elixir
# Source: lib/lattice_stripe/batch.ex [VERIFIED from codebase]

{:ok, results} =
  LatticeStripe.Batch.run(client, [
    {LatticeStripe.Customer, :retrieve, [customer.id]},
    {LatticeStripe.Subscription, :list, [%{"customer" => customer.id}]},
    {LatticeStripe.Invoice, :list, [%{"customer" => customer.id}]}
  ])

[customer_result, subscriptions_result, invoices_result] = results

# Each result is independently {:ok, _} or {:error, _}
for {label, result} <- Enum.zip(["Customer", "Subscriptions", "Invoices"], results) do
  case result do
    {:ok, data} -> IO.puts("#{label}: ok")
    {:error, err} -> IO.puts("#{label}: error — #{err.message}")
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static ExDoc guides only | Interactive LiveBook notebook | Phase 31 (now) | Developers can execute code alongside reading |
| `IO.inspect/2` for output | `Kino.Tree.new/1` for nested, `Kino.DataTable.new/2` for lists | Phase 31 | Richer output display |

**Deprecated/outdated:**
- kino `~> 0.13` or earlier: avoid — 0.14 introduced significant API stability. Current is 0.19.0. [VERIFIED: hex.pm]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | stripe-mock may not support the v2 `meter-events.stripe.com` endpoint used by `MeterEventStream` | Pitfall 2, Pattern 7 | Low — notebook can document the limitation and provide fallback prose |
| A2 | `Kino.DataTable.new/2` accepts a list of LatticeStripe structs via the `Table.Reader` protocol | Pattern 4 | Medium — if structs don't implement Table.Reader, use `Enum.map/2` to convert to plain maps first |

**If Table.Reader fallback needed:**
```elixir
# If Kino.DataTable.new(result.data) fails, convert structs to maps:
rows = Enum.map(result.data, &Map.from_struct/1)
Kino.DataTable.new(rows, name: "Payment Intents")
```

## Open Questions

1. **Does `Kino.DataTable.new/2` work with LatticeStripe structs directly?**
   - What we know: `Kino.DataTable` accepts any data implementing `Table.Reader.t()`. Elixir structs implement the `Enumerable` protocol but may not implement `Table.Reader`.
   - What's unclear: Whether `Table.Reader` is auto-derived for structs, or whether we need to convert to plain maps.
   - Recommendation: Try `Kino.DataTable.new(result.data)` first; if it fails, add `Enum.map(result.data, &Map.from_struct/1)` as a one-liner preprocessing step. Document whichever works.

2. **Does stripe-mock support v2 billing endpoints for MeterEventStream?**
   - What we know: stripe-mock is powered by Stripe's OpenAPI spec. The v2 spec may or may not be included.
   - What's unclear: Whether `/v2/billing/meter_event_session` is served by `localhost:12111`.
   - Recommendation: Test during implementation. If not supported, add a clear prose note in the MeterEventStream section and skip the `send_events` cell (show it as commented-out code instead).

3. **Should the notebook include a cleanup section?**
   - What we know: Claude's Discretion allows adding a cleanup section.
   - What's unclear: Whether stripe-mock resources persist across restarts (likely not — in-memory).
   - Recommendation: Omit explicit cleanup. stripe-mock doesn't persist state; real test mode resources don't incur charges. A brief prose note ("these are test resources — stripe-mock resets on restart; test-mode resources on real Stripe are safe to leave") is sufficient.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test --include integration` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-05 | `notebooks/stripe_explorer.livemd` exists and contains required sections | Manual verification | `ls notebooks/stripe_explorer.livemd` | ❌ Wave 0 |
| DX-05 | `Mix.install/2` block includes `kino` and `lattice_stripe` | File content check | `grep -q "kino" notebooks/stripe_explorer.livemd` | ❌ Wave 0 |
| DX-05 | All five required topics covered | Manual review | Read notebook sections | ❌ Wave 0 |

**Note:** A LiveBook notebook is not a test suite. There are no ExUnit tests to write for this phase. Validation is:
1. File exists at `notebooks/stripe_explorer.livemd`
2. `Mix.install/2` block is present and correct
3. All five required sections exist: client configuration, payment intent lifecycle, subscription creation, meter event reporting, portal session creation
4. Notebook can be opened in LiveBook and cells execute successfully against stripe-mock

### Sampling Rate
- **Per task commit:** `ls notebooks/stripe_explorer.livemd && head -50 notebooks/stripe_explorer.livemd`
- **Per wave merge:** Manual notebook execution against stripe-mock
- **Phase gate:** Full manual walkthrough before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `notebooks/` directory — needs creation (it does not exist)
- [ ] No ExUnit test file needed — validation is manual + file existence

*(No test infrastructure gaps — this phase requires no new ExUnit tests)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Notebook uses test API keys only |
| V3 Session Management | No | Notebook is stateless |
| V4 Access Control | No | Developer tool, not user-facing |
| V5 Input Validation | Partial | SDK validates params; notebook uses hardcoded/user-typed test values |
| V6 Cryptography | No | No crypto in notebook itself |

### Known Threat Patterns for LiveBook Notebooks

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hardcoded API keys in notebook | Information Disclosure | Use `sk_test_...` keys only; never commit live keys; notebook uses Kino.Input so keys aren't in source |
| BillingPortal.Session URL logged | Information Disclosure | Prose warning: "Do not log or cache session.url — it is a single-use bearer credential" |
| MeterEventStream auth token logged | Information Disclosure | Prose warning: "The authentication_token is masked in LatticeStripe's Inspect output for this reason" |

**Key security note:** The notebook should use `sk_test_...` Stripe API keys exclusively. The `Kino.Input.text/2` approach (rather than hardcoded strings) means the key is not stored in the `.livemd` file itself — users type it at runtime. This is the correct pattern.

## Sources

### Primary (HIGH confidence)
- `/websites/hexdocs_pm_kino` (Context7) — Kino.Input, Kino.DataTable, Kino.Tree function signatures
- `hexdocs.pm/kino/Kino.Input.html` [VERIFIED via WebFetch] — `text/2` options (`:default`, `:debounce`), `read/1` synchronous behavior
- `hexdocs.pm/kino/Kino.DataTable.html` [VERIFIED via WebFetch] — `new/2` args, data format, `:keys`/`:name` options
- `hexdocs.pm/kino/Kino.Tree.html` [VERIFIED via WebFetch] — `new/1` accepts any Elixir term
- `hex.pm/api/packages/kino` [VERIFIED via Bash] — version 0.19.0, published 2026-03-03
- `github.com/livebook-dev/kino` README [VERIFIED via Bash] — `Mix.install` form `{:kino, "~> 0.19.0"}`
- `lib/lattice_stripe/batch.ex` [VERIFIED from codebase] — `Batch.run/3` signature and error isolation
- `lib/lattice_stripe/billing/meter_event_stream.ex` [VERIFIED from codebase] — `create_session/1`, `send_events/3`, v2 host
- `lib/lattice_stripe/builders/subscription_schedule.ex` [VERIFIED from codebase] — SSBuilder pipe chain
- `lib/lattice_stripe/client.ex` [VERIFIED from codebase] — `Client.new!/1` fields including `base_url:`, `finch:`
- `test/support/test_helpers.ex` [VERIFIED from codebase] — `test_integration_client` pattern with `base_url: "http://localhost:12111"`
- `test/integration/payment_intent_integration_test.exs` [VERIFIED from codebase] — create/retrieve/confirm param shapes
- `guides/getting-started.md` [VERIFIED from codebase] — Finch start_link in non-OTP scripts note
- `guides/metering.md` [VERIFIED from codebase] — `Billing.Meter.create/3` param shape
- `guides/customer-portal.md` [VERIFIED from codebase] — `BillingPortal.Session.create/3` param shape

### Secondary (MEDIUM confidence)
- `livebook-dev/livebook` docs (Context7) — `Mix.install/2` with `path:` and `config_path:` options

### Tertiary (LOW confidence)
- A1: stripe-mock v2 endpoint support — unverified, flagged as ASSUMED
- A2: `Kino.DataTable` Table.Reader protocol support for LatticeStripe structs — unverified, flagged as ASSUMED

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Kino version verified on hex.pm; API verified on hexdocs
- Architecture: HIGH — `Mix.install` + Finch pattern verified from guides/getting-started.md; stripe-mock port from integration tests
- Pitfalls: HIGH — Kino read/render pitfall from official docs; Finch re-run pitfall from Elixir OTP behavior; ID-scoping pitfall from LiveBook execution model
- MeterEventStream stripe-mock compatibility: LOW (ASSUMED)

**Research date:** 2026-04-16
**Valid until:** 2026-07-16 (Kino stable; LiveBook format stable)
