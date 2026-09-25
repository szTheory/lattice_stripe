# Phase 77: Adopter Edge Profiles and CI - Research

**Researched:** 2026-09-24  
**Domain:** Test-only Phoenix host integration for an Elixir Stripe SDK  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Keep one shared Phoenix host app and make B2B, usage, and Connect scenarios independently selectable as test profiles (for example, focused ExUnit files or tags). Do not create one application per profile.
- **D-02:** Give each profile a small, distinct SDK contract: typed invoice or reconciliation behavior for B2B, usage-summary pagination or streaming, and per-request Connect tenant context including account-header behavior. Confirm exact operations against existing SDK capabilities during research/planning.
- **D-03:** Cover shared error, idempotency, and webhook-verification boundaries where they are meaningful to the selected flows. Prefer executable assertions at the host/SDK seam and use synthetic fixtures; do not implement billing policy, persistent event processing, or application-owned orchestration.
- **D-04:** Add one dedicated adopter CI job using the repository's existing primary Elixir 1.19 / OTP 28 toolchain. It should resolve the nested adopter lockfile and run the complete adopter suite without secrets, live services, or production data. Preserve a single obvious local command.

### the agent's Discretion
- Select exact SDK calls and response fixtures after checking the supported typed surfaces and existing test seams.
- Choose ExUnit organization and whether profile selection uses tags, files, or both, provided the complete suite has one deterministic command.
- Keep the CI job proportional to the existing workflow; do not expand the package's Elixir/OTP matrix or redesign unrelated CI jobs.
- Add or adjust adopter instructions only as needed to explain the profiles and their local invocation.

### Deferred Ideas (OUT OF SCOPE)
- Separate adopter applications, full industry-specific billing workflows, production deployment, live Stripe credentials, real adopter data, and persistence are outside the phase boundary.
- Additional profiles or Stripe resource families remain pull-driven and require a distinct adopter job and maintenance case.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADOPT-03 | The adopter can opt into B2B invoicing, usage reconciliation, and Connect tenant-context profiles that exercise distinct SDK contracts without implementing application billing policy. | Source-supported choices: `Invoice.retrieve/3` with typed `amount_paid_off_stripe`, `MeterEventSummary.stream!/4` for cursor pagination, and `Balance.retrieve/2` with per-request `stripe_account:`. [VERIFIED: .planning/REQUIREMENTS.md:20; quote: `**ADOPT-03**`] |
| ADOPT-04 | The adopter proof covers meaningful integration boundaries, including error handling, pagination or streaming, idempotency, and webhook verification, where relevant to the selected flows. | Reuse the typed structured `Error` return, meter summary pagination and meter event dual idempotency, plus the existing raw-byte webhook route/signature tests. [VERIFIED: .planning/REQUIREMENTS.md:21; quote: `**ADOPT-04**`] |
| ADOPT-05 | CI can run the adopter proof deterministically without live Stripe credentials or production adopter data. | Run all nested-app tests with its checked-in `mix.lock`, Mox transport, synthetic config, and the existing 1.19/28 CI toolchain. [VERIFIED: .planning/REQUIREMENTS.md:22; quote: `**ADOPT-05**`] |
</phase_requirements>

## Summary

The phase can meet its profile requirements entirely through existing SDK surface and the nested host app. Keep the app at `test_apps/phoenix_adopter` as a checked-out path dependency and add three independently runnable ExUnit files around `Invoice.retrieve/3`, `MeterEventSummary.stream!/4` (plus `MeterEvent.create/3` for idempotency), and `Balance.retrieve/2`. The source definitions and existing SDK tests prove these are supported calls; no new package or resource module is indicated. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-24`; `lib/lattice_stripe/invoice.ex:344-348`; `lib/lattice_stripe/billing/meter_event_summary.ex:207-243,281-322`; `lib/lattice_stripe/billing/meter_event.ex:73-90`; `lib/lattice_stripe/balance.ex:77-89`]

**Primary recommendation:** Add focused profile test files that call the public APIs through the existing Mox `LatticeStripe.Transport` mock, assert request and typed-result contracts, and rely on the existing core-flow webhook coverage. Make CI enter the nested project, resolve with `mix deps.get --check-locked`, and run its complete suite once on Elixir 1.19 / OTP 28. [VERIFIED: `test_apps/phoenix_adopter/test/test_helper.exs:1-3`; `.github/workflows/ci.yml:46-49,191-199`; `test_apps/phoenix_adopter/README.md:5-15`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Invoice retrieval and usage reporting / summary reads | API / Backend | — | The Phoenix host calls the SDK; `LatticeStripe.Invoice`, `Billing.MeterEvent`, and `Billing.MeterEventSummary` build Stripe-shaped requests and decode typed responses. [VERIFIED: `lib/lattice_stripe/invoice.ex:290-349`; `lib/lattice_stripe/billing/meter_event.ex:73-90`; `lib/lattice_stripe/billing/meter_event_summary.ex:207-243`] |
| Connect tenant context | API / Backend | — | Account context is a per-request SDK option serialized into the Stripe account header before transport dispatch. [VERIFIED: `lib/lattice_stripe/client/request_builder.ex:8-25,153-188`] |
| Host endpoint and webhook receipt | Frontend Server (SSR) | API / Backend | The Phoenix endpoint owns its route and plugs; the webhook plug verifies the signed request and invokes the host handler. [VERIFIED: `test_apps/phoenix_adopter/lib/phoenix_adopter.ex:55-88`] |
| Deterministic contract proof | API / Backend | Frontend Server (SSR) | ConnTest drives the host endpoint while Mox replaces only outbound Stripe transport. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs:1-10,38-88`; CITED: [Phoenix.ConnTest 1.8](https://phoenix.hexdocs.pm/1.8.4/Phoenix.ConnTest.html)] |
| Adopter suite CI gate | API / Backend | — | CI runs the nested Mix test suite after setting the documented Elixir/OTP pair. [VERIFIED: `.github/workflows/ci.yml:46-49,153-199`] |

## Standard Stack

No new dependency is recommended. Keep the already locked host app stack and existing SDK transport seam. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-24`; `test_apps/phoenix_adopter/mix.lock:1-19`]

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / OTP | 1.19 / 28 in CI | Compile and run adopter tests | This is the existing primary CI toolchain and the locked phase choice. [VERIFIED: `.github/workflows/ci.yml:46-49`; quote: `elixir-version: '1.19'`, `otp-version: '28'`] |
| Phoenix | 1.8.14 locked | Existing host endpoint and ConnTest harness | Already a test-host dependency, not an SDK runtime dependency. [VERIFIED: test_apps/phoenix_adopter/mix.lock:11; quote: "phoenix": {:hex, :phoenix, "1.8.14"; test_apps/phoenix_adopter/mix.exs:18-24; quote: {:phoenix, "~> 1.8.0"}] |
| Plug | 1.20.3 locked | Endpoint connection and webhook plumbing | Existing host dependency; webhook plug must see original body bytes before parsers. [VERIFIED: test_apps/phoenix_adopter/mix.lock:14; quote: "plug": {:hex, :plug, "1.20.3"; test_apps/phoenix_adopter/lib/phoenix_adopter.ex:73-88] |
| ExUnit | Bundled with Elixir | Test organization and assertions | The adopter's existing test files are ExUnit cases. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs:1-2`] |
| Mox | 1.3.2 locked | Mock LatticeStripe.Transport for synthetic HTTP responses | The host already defines its transport mock in test helper and uses expectations in the core flow. [VERIFIED: test_apps/phoenix_adopter/mix.lock:7; quote: "mox": {:hex, :mox, "1.3.2"; test_apps/phoenix_adopter/test/test_helper.exs:1-3; quote: Mox.defmock(PhoenixAdopter.MockTransport, for: LatticeStripe.Transport)] |
| LatticeStripe | checked-out path dependency | SDK under test | The app consumes the repository source via its relative path and separate lock. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-24`; quote: `{:lattice_stripe, path: "../../"}`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated profile test files (recommended) | ExUnit tags | Tags require a convention and selector flags; file paths give each focused profile a direct local invocation while ordinary `mix test` still runs everything. This is a planning recommendation, not a repository fact. [ASSUMED] |
| Mox transport expectations | Live Stripe or `stripe-mock` | Mox makes exact multi-page response shapes and request headers deterministic. `stripe-mock` is already reserved for protocol smoke tests and does not supply stateful pagination behavior. [VERIFIED: `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs:5-9`; `.github/workflows/ci.yml:235-276`] |

No installation command is needed for the phase; do not add external packages. The current host dependency declarations and pinned versions are the ones to preserve unless a demonstrated compile gap appears. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-24`; `test_apps/phoenix_adopter/mix.lock:1-19`]

## Architecture Patterns

### System Architecture Diagram

```text
Phoenix.ConnTest request ──> PhoenixAdopter.Endpoint / profile test
                                  │
                                  ├──> LatticeStripe public API + explicit Client
                                  │        │
                                  │        └──> Mox transport expectation
                                  │                 └──> synthetic HTTP response
                                  │        <── typed SDK object / Error
                                  │
                                  └── signed raw webhook bytes
                                           └──> Webhook.Plug verifies
                                                    └──> typed host event handler

GitHub Actions (Elixir 1.19 / OTP 28)
  └── nested adopter `mix deps.get --check-locked`
       └── nested adopter `mix test --warnings-as-errors`
```

The outbound adapter boundary is the `LatticeStripe.Transport` behavior, and webhook verification is an inbound raw-body boundary; those are separate directions and should remain separately asserted. [VERIFIED: `lib/lattice_stripe/transport.ex:1-50`; `test_apps/phoenix_adopter/lib/phoenix_adopter.ex:70-88`; `test_apps/phoenix_adopter/test/core_flow_test.exs:38-101`]

### Recommended Project Structure

Keep all work in the existing host app, e.g. add focused files under `test_apps/phoenix_adopter/test/` for B2B invoice, usage reconciliation, and Connect context. These suggested names are illustrative, not existing paths. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs`; ASSUMED]

### Pattern 1: Typed off-Stripe invoice reconciliation

**What:** Read an Invoice through the public request path with an explicit `stripe_version` option and assert the typed `amount_paid_off_stripe` value alongside the ordinary invoice amount. The field is documented for API request responses beginning at `2026-05-27.dahlia`, while the client default remains `2026-03-25.dahlia`; do not make a webhook-field claim. [VERIFIED: `lib/lattice_stripe/invoice.ex:56-62,193-210,344-349`; `guides/invoices.md:12-29`]

**When to use:** The minimal B2B invoice reconciliation contract that proves an adopter can read the supported off-Stripe paid amount without introducing invoice lifecycle policy. [VERIFIED: `guides/invoices.md:12-19`]

**Example:**

```elixir
{:ok, %LatticeStripe.Invoice{amount_paid_off_stripe: amount}} =
  LatticeStripe.Invoice.retrieve(client, "in_...", stripe_version: "2026-05-27.dahlia")
```

The guide quotes `{:ok, invoice} = LatticeStripe.Invoice.retrieve(client, "in_..." )`, `off_stripe_amount = invoice.amount_paid_off_stripe`, and `api_version: "2026-05-27.dahlia"`; the source signature is `def retrieve(%Client{} = client, id, opts \\\\ []) when is_binary(id)`. [VERIFIED: `guides/invoices.md:21-29`; `lib/lattice_stripe/invoice.ex:344-349`]

### Pattern 2: Usage stream with a real cursor boundary

**What:** Call `MeterEventSummary.stream!/4` with one customer and an aligned bucketed window; have the mock return two pages and assert all results are typed and the second request carries the last ID from page one. The source requires `customer`, `start_time`, and `end_time`, aligns hour/day windows to UTC boundaries, and the list defaults to a potentially incomplete page of ten. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:183-205,253-321`; `guides/metering.md:571-584,586-607`]

**When to use:** Proving reconciliation consumers can traverse all returned buckets instead of summing only the first page. Keep the association to the queried customer outside the summary object because the typed object has no customer field; do not claim summaries are real-time, since the guide states they are eventually consistent. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:13-29,324-355`; `guides/metering.md:611-625`]

**Example:**

```elixir
summaries =
  client
  |> LatticeStripe.Billing.MeterEventSummary.stream!("mtr_123", params)
  |> Enum.to_list()
```

The source docs explicitly show `MeterEventSummary.stream!(meter.id, %{... "value_grouping_window" => "hour"})` followed by enumeration; use the existing summary pagination tests as the cursor test analog. [VERIFIED: `guides/metering.md:571-584`; `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs:90-145`]

### Pattern 3: Explicit dual idempotency at the write seam

**What:** If the usage profile includes a write, call `MeterEvent.create/3` with stable body `identifier` and explicit HTTP `idempotency_key:` and assert both encoded body and `idempotency-key` header at the mock transport. These two keys cover different duplicate boundaries; a successful return means accepted for processing, not applied to a customer. [VERIFIED: `lib/lattice_stripe/billing/meter_event.ex:22-71,73-90`; `lib/lattice_stripe/client.ex:161-170`; `lib/lattice_stripe/client/request_builder.ex:153-188`]

**When to use:** Only enough to prove the currently supported usage event request contract; do not build a usage queue, retry orchestration, or persistence. The invoice profile can also assert an explicit idempotency header on a POST if that is a better shared error test, but do not duplicate unrelated flows. [VERIFIED: `lib/lattice_stripe/invoice.ex:292-325`; ASSUMED]

**Example:**

```elixir
LatticeStripe.Billing.MeterEvent.create(client, %{
  "event_name" => "api_call",
  "payload" => %{"stripe_customer_id" => customer_id, "value" => "1"},
  "identifier" => event_identifier
}, idempotency_key: request_key)
```

The SDK's documented parameter names are exactly `"event_name"`, `"payload"`, `"identifier"`, and `idempotency_key:`. [VERIFIED: `lib/lattice_stripe/billing/meter_event.ex:27-53,65-71`]

### Pattern 4: Request-scoped Connect account routing

**What:** Use a single explicit platform client, issue two calls with different per-request `stripe_account:` values, and assert each outgoing request carries only its corresponding `stripe-account` header. Per-request opts override client-level configuration and `nil` explicitly suppresses the client-level value. [VERIFIED: `lib/lattice_stripe/client/request_builder.ex:8-25,153-188`; `test/lattice_stripe/client_stripe_account_header_test.exs:35-93`]

**When to use:** Proving tenant routing on the actual SDK request builder/transport seam. `Balance.retrieve/2` is a minimal typed connected-account read (`GET /v1/balance`) with documented account routing; it avoids introducing Connect account creation/onboarding behavior. [VERIFIED: `lib/lattice_stripe/balance.ex:5-8,77-89`; `guides/connect-money-movement.md:60-69`]

**Example:**

```elixir
LatticeStripe.Balance.retrieve(client, stripe_account: "acct_connected_customer_a")
LatticeStripe.Balance.retrieve(client, stripe_account: "acct_connected_customer_b")
```

The public guide already shows these distinct account values in per-request calls and states that the per-request value takes precedence. [VERIFIED: `guides/connect-accounts.md:31-53`]

Verbatim anchors are `stripe_account: "acct_connected_customer_a"`, `stripe_account: "acct_connected_customer_b"`, and `{"stripe-account", account}`. A nil account omits the header: `defp maybe_add_stripe_account(headers, nil), do: headers`. [VERIFIED: `guides/connect-accounts.md:41-49`; `lib/lattice_stripe/client/request_builder.ex:185-188`]

### Shared error boundary

Use one synthetic HTTP 400 response on a selected profile call and assert the structured error tuple at the host/SDK seam. The already tested shape is {:error, %Error{type: :invalid_request_error, status: 400}}; Error.error_type includes :invalid_request_error, and the focused client test feeds a 400 response through its transport. [VERIFIED: lib/lattice_stripe/error.ex:64-75; test/lattice_stripe/client/response_decoding_test.exs:27-35]

This keeps error behavior in the SDK contract: Invoice.retrieve/3 documents {:ok, %Invoice{}} on success and {:error, %LatticeStripe.Error{}} on failure. [VERIFIED: lib/lattice_stripe/invoice.ex:328-349]

### Anti-Patterns to Avoid

- **Do not construct a second Phoenix app per profile:** that violates the locked single-app boundary and multiplies lockfiles, CI setup, and drift. [VERIFIED: `77-CONTEXT.md`, D-01]
- **Do not use live credentials or Stripe services in this job:** existing host config uses synthetic credentials, and the phase explicitly requires no secrets or live services. [VERIFIED: `test_apps/phoenix_adopter/config/config.exs:8-10`; `77-CONTEXT.md`, D-04]
- **Do not parse or re-encode webhook JSON before verification:** the existing endpoint mounts the webhook plug before `Plug.Parsers`; signature verification depends on original request bytes. [VERIFIED: `test_apps/phoenix_adopter/lib/phoenix_adopter.ex:73-88`; `guides/webhooks.md:31-53`]
- **Do not treat meter event acceptance or summary values as settled billing truth:** event validation is asynchronous, and summaries are eventually consistent and lack a freshness field. [VERIFIED: `lib/lattice_stripe/billing/meter_event.ex:54-63`; `guides/metering.md:621-625`]
- **Do not assert only the first page for a usage series:** the summary stream follows `has_more`; the existing transport pagination suite already documents why Mox is the useful boundary. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:253-279`; `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs:5-9`]
- **Do not run `mix test` from the package root as the adopter gate:** that executes the SDK project, not the nested host Mix project. [VERIFIED: `test_apps/phoenix_adopter/README.md:5-10`; `test_apps/phoenix_adopter/mix.exs:1-11`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stripe request/response test seam | A fake HTTP server, mutable global client, or hand-coded response decoder | Existing explicit Client plus Mox-backed `LatticeStripe.Transport` | It leaves request construction and response decoding in the SDK path while the host controls deterministic fixture responses. [VERIFIED: `test_apps/phoenix_adopter/test/test_helper.exs:1-3`; `test_apps/phoenix_adopter/test/core_flow_test.exs:38-65`] |
| Cursor pagination | A custom page loop in adopter code | `MeterEventSummary.stream!/4` and `LatticeStripe.List` | The SDK already owns cursor derivation and forwards relevant page options; source tests cover multi-page behavior. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:314-321`; `lib/lattice_stripe/list.ex:164-190,249-272`; `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs:90-145`] |
| Webhook signatures | Host-specific HMAC implementation or hard-coded signature | `LatticeStripe.Webhook.generate_test_signature/3` and existing endpoint plug | The current core app exercises signed and tampered synthetic raw bodies through the handler boundary. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs:75-101`; `lib/lattice_stripe/webhook.ex:559-584`] |
| Account routing | Separate client per tenant or manual header construction | Per-request `stripe_account:` option | The SDK request builder resolves per-request scope and constructs the header in one place. [VERIFIED: `lib/lattice_stripe/client/request_builder.ex:8-25,153-188`] |

**Key insight:** These profiles should prove package contracts at the seam the host uses; Phoenix remains host-only and application billing policy, data storage, and long-running reconciliation are explicitly outside the phase. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-24`; `77-CONTEXT.md` domain and D-03]

## Common Pitfalls

### Pitfall 1: Requesting the typed off-Stripe amount on the default API version

**What goes wrong:** A fixture with `amount_paid_off_stripe` would suggest that the field is available by default.  
**Why it happens:** The typed field is version-gated to API request responses from `2026-05-27.dahlia`; the SDK's default is `2026-03-25.dahlia`.  
**How to avoid:** Set `stripe_version: "2026-05-27.dahlia"` for the targeted request and assert the request header plus typed integer field.  
**Warning signs:** The test fixture asserts the field but never inspects the `stripe-version` header, or moves the default API version. [VERIFIED: `lib/lattice_stripe/invoice.ex:56-62,193-210`; `lib/lattice_stripe/client/request_builder.ex:9-25,153-167`; `guides/invoices.md:14-19`]

### Pitfall 2: Valid but incomplete usage pagination

**What goes wrong:** The profile reports a total from only the first ten bucket rows, which can look plausible but be incomplete.  
**Why it happens:** List defaults to `limit` 10 and returns one page; `has_more` must be followed to get the whole series.  
**How to avoid:** Use `stream!/4` and make the second fixture page require the cursor from page one; preserve the original customer and window filters.  
**Warning signs:** The test only uses `list/4`, has one mocked transport call, or asserts the first result without checking `has_more`. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:203-205,253-321`; `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs:90-145`]

### Pitfall 3: Losing tenant attribution in the mock

**What goes wrong:** Two sequential tenant requests accidentally reuse or omit the Stripe account header.  
**Why it happens:** Client-level account context is a fallback; per-request options win and a `nil` request override omits the header.  
**How to avoid:** Reuse one client, make sequential expectations, assert both the selected and excluded header values for each request.  
**Warning signs:** Only checking that a `stripe-account` header exists, or using different client instances that cannot prove request-scoped override behavior. [VERIFIED: `lib/lattice_stripe/client/request_builder.ex:8-25,153-188`; `test/lattice_stripe/client_stripe_account_header_test.exs:47-93`]

### Pitfall 4: Treating body and transport idempotency as one key

**What goes wrong:** Retries are safe at the HTTP layer while duplicated business events still have different body identifiers, or the reverse.  
**Why it happens:** MeterEvent `identifier` and HTTP `idempotency_key:` operate at separate layers.  
**How to avoid:** When proving a usage write, supply and assert both values; don't implement the actual durable retry mechanism in this app. [VERIFIED: `lib/lattice_stripe/billing/meter_event.ex:41-52`; `guides/metering-runtime-and-reconciliation.md:66-75`]

### Pitfall 5: New nested dependency with stale host lock

**What goes wrong:** CI resolves dependencies differently from local runs or silently updates the nested host dependency set.  
**Why it happens:** The adopter is a separate Mix project with its own lockfile; the package project's dependency graph is not the host application's lock.  
**How to avoid:** Run dependency resolution with `--check-locked` from the nested project after any dependency change and commit an intentional nested lock diff. Keep the current lock unless a real need arises. [VERIFIED: `test_apps/phoenix_adopter/README.md:5-13`; `test_apps/phoenix_adopter/mix.lock:1-19`; CITED: [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html), [Mix.Project lockfile option](https://hexdocs.pm/mix/Mix.Project.html)]

## Code Examples

The profile calls below are supported public operations; request assertions belong in the host mock callback, and response assertions should match the typed module. [VERIFIED: `lib/lattice_stripe/invoice.ex:311-349`; `lib/lattice_stripe/billing/meter_event_summary.ex:207-243,281-322`; `lib/lattice_stripe/billing/meter_event.ex:73-90`; `lib/lattice_stripe/balance.ex:85-89`]

```elixir
# Typed B2B reconciliation field (API version is material to this field).
{:ok, %LatticeStripe.Invoice{amount_paid_off_stripe: amount}} =
  LatticeStripe.Invoice.retrieve(client, "in_...", stripe_version: "2026-05-27.dahlia")

# Usage series: assert the Mox expectation for page two and then enumerate all results.
summaries =
  client
  |> LatticeStripe.Billing.MeterEventSummary.stream!("mtr_123", params)
  |> Enum.to_list()

# Connect: vary per-request context on the same platform client and inspect each request.
LatticeStripe.Balance.retrieve(client, stripe_account: "acct_connected_customer_a")
LatticeStripe.Balance.retrieve(client, stripe_account: "acct_connected_customer_b")
```

The invoice field and version examples are in `guides/invoices.md:14-29`; `MeterEventSummary.stream!/4` is shown in `guides/metering.md:571-584`; and account values with per-request scope are shown in `guides/connect-accounts.md:31-49`. [VERIFIED: cited guide lines]

## State of the Art

| Older / unsafe assumption | Current approach | Evidence | Impact |
|---------------------------|------------------|----------|--------|
| Treat an invoice as a single Stripe-collected paid amount | Read typed `Invoice.amount_paid_off_stripe` when the client opts into `2026-05-27.dahlia` | [VERIFIED: `lib/lattice_stripe/invoice.ex:56-62,193-210`; `guides/invoices.md:14-19`] | The test profile must pin the request API version and must not claim webhook payload parity. |
| Use a page result as the full usage series | Use `MeterEventSummary.stream!/4` to follow `has_more` | [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:253-279`; `guides/metering.md:571-607`] | The synthetic contract should prove the cursor continuation, not just decode one result. |
| Put each Connect tenant into client/global state | Pass per-request `stripe_account:` on the shared platform client | [VERIFIED: `guides/connect-accounts.md:31-53`; `lib/lattice_stripe/client/request_builder.ex:8-25`] | A two-request expectation demonstrates no tenant header bleed. |

## Environment Availability

This phase needs the Elixir toolchain and package resolution but no Stripe service or credential. The current workspace reports Elixir 1.19.5 and OTP 28; CI pins Elixir 1.19 / OTP 28. Docker is installed locally but not required for this adopter gate. [VERIFIED: local `elixir --version` probe; `.github/workflows/ci.yml:46-49`; local `command -v docker` probe]

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / OTP | Compile and run host suite | ✓ | 1.19.5 / 28 locally; CI uses 1.19 / 28 | Use the CI-pinned pair |
| Mix / Hex dependency resolution | Fresh checkout and nested lock resolution | ✓ Mix present; Hex fetch not separately probed | Mix 1.19.5 | CI resolves from Hex with `mix deps.get --check-locked` |
| Stripe credentials/service | None; Mox transport returns fixtures | Not required | — | Synthetic transport fixture |
| Docker / stripe-mock | Not required for this job | ✓ Docker CLI present; service not needed | Not recorded | Omit |

**Missing dependencies with no fallback:** None identified for local planning.  
**Missing dependencies with fallback:** No live Stripe service/credential is needed; the Mox transport is the planned fallback and normal path. [VERIFIED: `test_apps/phoenix_adopter/test/test_helper.exs:1-3`; `test_apps/phoenix_adopter/config/config.exs:8-10`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit, bundled with Elixir; nested test dependency Mox 1.3.2 |
| Config file | `test_apps/phoenix_adopter/test/test_helper.exs` |
| Quick run command | `cd test_apps/phoenix_adopter && mix test` (documented local command) |
| Full suite command | `cd test_apps/phoenix_adopter && mix deps.get --check-locked && mix test --warnings-as-errors` |

The README currently documents `cd test_apps/phoenix_adopter`, `mix deps.get`, then `mix test`; root CI already uses `mix deps.get --check-locked` and `--warnings-as-errors` in focused gates, so the proposed stricter full suite is consistent with repository practice. [VERIFIED: `test_apps/phoenix_adopter/README.md:5-10`; `.github/workflows/ci.yml:67-71,197-199`]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADOPT-03 | Each profile proves its distinct typed invoice, summary stream, or request-account contract | Host/SDK contract | `cd test_apps/phoenix_adopter && mix test` | ❌ add profile tests |
| ADOPT-04 | Structured error; all summary pages; body and HTTP idempotency keys; existing valid/tampered raw-byte webhook behavior | Host/SDK contract | `cd test_apps/phoenix_adopter && mix test` | ⚠️ webhook coverage exists; add selected edge assertions |
| ADOPT-05 | Complete synthetic suite resolves against nested lock and runs on the selected toolchain | CI | `cd test_apps/phoenix_adopter && mix deps.get --check-locked && mix test --warnings-as-errors` | ❌ add dedicated workflow job |

Useful narrow commands after the files are added are `mix test test/<profile-file>.exs`; keep the single complete command as the CI gate. The narrow file names are planning placeholders until the planner chooses the final file layout. [ASSUMED]

### Sampling Rate

- **Per task commit:** run the focused adopter test file changed in that task from `test_apps/phoenix_adopter`. [ASSUMED]
- **Per wave merge:** run the full nested `mix test --warnings-as-errors` suite. [CITED: `.github/workflows/ci.yml:197-199`]
- **Phase gate:** resolve nested dependencies with `mix deps.get --check-locked`, then run the full adopter suite on Elixir 1.19 / OTP 28. [VERIFIED: `.github/workflows/ci.yml:46-49,191-199`] 

### Wave 0 Gaps

- [ ] Add focused B2B invoice, usage, and Connect test files; no new test framework setup is needed. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test_apps/phoenix_adopter/test/test_helper.exs:1-3`]
- [ ] Add a dedicated workflow job that resolves the nested lock and runs all adopter tests. [VERIFIED: `.github/workflows/ci.yml:153-199` shows package tests and focused adoption checks; `77-CONTEXT.md`, D-04]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement: false`. The proposed security proof is tenant isolation at the request-builder header seam, no credential environment fallback, and raw-body webhook signature verification. [VERIFIED: `.planning/config.json:1-60`; `test_apps/phoenix_adopter/config/config.exs:8-10`; `lib/lattice_stripe/client/request_builder.ex:8-25`; `test_apps/phoenix_adopter/test/core_flow_test.exs:75-101`]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Validation and Business Logic | Yes | Validate required summary filters/window alignment before transport; avoid adding business policy. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:188-205,211-243`; CITED: [OWASP ASVS 5.0 taxonomy](https://cornucopia.owasp.org/taxonomy/asvs-5.0)] |
| V4 API and Web Service | Yes | Assert the exact request path, account header, request body, structured errors, and typed response at the transport boundary. [VERIFIED: `lib/lattice_stripe/client/request_builder.ex:8-35,153-188`; CITED: [OWASP ASVS 5.0 taxonomy](https://cornucopia.owasp.org/taxonomy/asvs-5.0)] |
| V6 Authentication | No user authentication; Yes API credential routing | Use only the synthetic test key already configured in the host; do not read secrets from CI environment. [VERIFIED: `test_apps/phoenix_adopter/config/config.exs:8-10`; CITED: [OWASP ASVS 5.0 taxonomy](https://cornucopia.owasp.org/taxonomy/asvs-5.0)] |
| V7 Session Management | No | The headless test endpoint has no browser session contract. [CITED: [OWASP ASVS 5.0 taxonomy](https://cornucopia.owasp.org/taxonomy/asvs-5.0)] |
| V8 Authorization | Yes | Treat Stripe account routing as tenant authority; assert a request-scoped account header for each request. [VERIFIED: `test/lattice_stripe/client_stripe_account_header_test.exs:47-93`; CITED: [OWASP ASVS 5.0 taxonomy](https://cornucopia.owasp.org/taxonomy/asvs-5.0)] |
| V11 Cryptography | Yes | Use the SDK webhook signer/verifier over original bytes; do not hand-roll HMAC. [VERIFIED: `lib/lattice_stripe/webhook.ex:520-584`; `test_apps/phoenix_adopter/test/core_flow_test.exs:75-101`; CITED: [OWASP ASVS 5.0 taxonomy](https://cornucopia.owasp.org/taxonomy/asvs-5.0)] |

### Known Threat Patterns for the Phoenix / Elixir SDK seam

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale or omitted Connect account context causes cross-tenant reads/writes | Elevation of privilege / information disclosure | Reuse one client in test; assert different tenant header values at transport for sequential requests. [VERIFIED: `lib/lattice_stripe/client/request_builder.ex:8-25,153-188`] |
| Modified webhook body reuses a prior signature | Tampering / spoofing | Verify raw request bytes; assert tampering is rejected before handler dispatch. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs:75-101`] |
| Unlimited usage stream accumulates all buckets | Denial of service | Bound consumption with `Stream.take/2` when full enumeration is not required; use complete enumeration only for the intentionally small synthetic fixture. [VERIFIED: `lib/lattice_stripe/billing/meter_event_summary.ex:270-279`; `guides/metering.md:604-607`] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Use separate ExUnit files for profile selection and `mix test` as the all-profiles command. | Architecture Patterns / Validation | Low: profile selection can instead use tags without changing the one-app/one-command requirements. |

## Resolved Decisions

1. **B2B uses `Invoice.retrieve/3` with a request-scoped `stripe_version: "2026-05-27.dahlia"`.** This is the smallest distinct B2B contract: the guide explicitly reads `amount_paid_off_stripe` from a retrieved invoice, and the SDK exposes per-request options on `retrieve/3`. Invoice writes are unnecessary for this typed reconciliation proof; idempotency is covered on the usage event write. [VERIFIED: `guides/invoices.md:14-29`; `lib/lattice_stripe/invoice.ex:328-349`; `lib/lattice_stripe/client/request_builder.ex:8-25`; `lib/lattice_stripe/billing/meter_event.ex:41-52`]

2. **The usage profile reuses the existing two-page `MeterEventSummary` fixture shape and asserts cursor continuation.** Adapt the existing response helper and assertions: page one returns two summary items and `has_more: true`; page two must receive `starting_after` equal to page one's final item ID; enumeration must include all items exactly once. This tests the consumer-visible pagination contract without rebuilding the SDK's cursor algorithm. [VERIFIED: `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs:50-61,90-145`; `lib/lattice_stripe/billing/meter_event_summary.ex:253-321`]

## Sources

### Primary (HIGH confidence)

- `.planning/phases/77-adopter-edge-profiles-and-ci/77-CONTEXT.md` — locked boundaries, three profile requirements, CI pair, and exclusions.
- `.planning/REQUIREMENTS.md` — ADOPT-03 through ADOPT-05 wording and traceability.
- `lib/lattice_stripe/invoice.ex`, `billing/meter_event.ex`, `billing/meter_event_summary.ex`, `balance.ex`, `client/request_builder.ex`, `client.ex`, and `error.ex` — callable surface, version gate, structured errors, idempotency, pagination, and account header behavior.
- `test_apps/phoenix_adopter/**`, `.github/workflows/ci.yml`, and focused package tests — existing host, fixture seam, lockfile, CI toolchain, and reusable assertions.
- `guides/invoices.md`, `guides/metering.md`, `guides/connect-accounts.md`, `guides/connect-money-movement.md`, `guides/webhooks.md`, `guides/testing.md` — documented adopter semantics and known constraints.

### Secondary (MEDIUM confidence)

- [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html) and [Mix.Project](https://hexdocs.pm/mix/Mix.Project.html) — official path dependency and project lockfile documentation.
- [Phoenix.ConnTest 1.8.4](https://phoenix.hexdocs.pm/1.8.4/Phoenix.ConnTest.html) — official endpoint test guidance for the existing host approach.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — checked nested `mix.exs`, `mix.lock`, and the existing CI toolchain. [VERIFIED: cited files]
- Architecture: HIGH — existing host path, client, transport, webhook setup, and resource source define the seams. [VERIFIED: cited files]
- Pitfalls: HIGH — package docs and focused SDK tests explicitly cover version gates, raw webhook bytes, pagination, and idempotency. [VERIFIED: cited files]

**Research date:** 2026-09-24  
**Valid until:** 2026-10-24 (stable test harness; recheck lockfile and CI workflow before execution)
