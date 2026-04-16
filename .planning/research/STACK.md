# Technology Stack

**Project:** LatticeStripe (Elixir Stripe SDK)
**Researched:** 2026-03-31 (v1.0); updated 2026-04-13 (v1.1 addendum); updated 2026-04-16 (v1.2 addendum)
**Overall Confidence:** HIGH

---

## v1.2 Addendum — Production Hardening & DX Features

> This section was added at the start of the v1.2 milestone. It answers stack questions for the nine new
> feature areas. The existing v1.1 addendum and original v1.0 stack content follow unchanged below.

### Verdict: Two optional new dependencies, zero hard new dependencies

The v1.0/v1.1 `deps/0` block ships unchanged to users. Two optional additions:
`:fuse` for circuit breaking (optional, user-declared), `opentelemetry_api` as a dev-only
guide dep (not a runtime dep for LatticeStripe itself). All other v1.2 features are
pure-Elixir patterns, CI tooling additions, or `.livemd` notebook files with no new Hex deps.

---

### Feature-by-Feature Stack Analysis

#### 1. Expand Deserialization (EXPD-02/03/05)

**No new dependencies.** The existing `from_map/1` + `@known_fields` + `extra` pattern in
every resource module is the right mechanism. Expanding typed structs is a pure-Elixir dispatch
problem: inspect the value at an expanded field key — if it's a map with an `"object"` key,
route to the matching `from_map/1` implementation; if it's a string ID, leave as-is.

Implementation path: add a `LatticeStripe.Deserializer` internal module (hidden with
`@moduledoc false`) that maps `"object"` string values to module names. The dot-path support
for `expand: ["data.customer"]` is string splitting + recursive descent — no library needed.

Status field atomization audit (EXPD-05) is similarly pure-Elixir: add `status_atom/1`
helpers to each resource struct, following the existing `Account.Capability` pattern.

**Confidence: HIGH** — pattern verified in v1.0/v1.1 codebase.

#### 2. Circuit Breaker Pattern

**Recommended: `:fuse ~> 2.5` as an OPTIONAL dependency (not required, user-declared).**

`:fuse` (v2.5.0 on Hex.pm, April 2026) is the canonical Erlang circuit breaker library. It is
an OTP application — a supervised GenServer process tree — with a minimal five-function API:
`ask/2`, `install/2`, `melt/1`, `reset/1`, `run/3`. It integrates cleanly with Elixir via
direct Erlang interop.

LatticeStripe should NOT add `:fuse` as a hard runtime dependency because:
1. Most users do not need circuit breaking at the SDK level — they handle it at the
   application or infrastructure layer (e.g., load balancer circuit breaking, Kubernetes
   readiness probes).
2. `:fuse` starts OTP processes that would appear in every LatticeStripe user's supervision
   tree without their knowledge.
3. It creates an application coupling (`:fuse` must be in `:extra_applications` or started
   before LatticeStripe).

**Recommended approach:** Ship a `LatticeStripe.RetryStrategy.CircuitBreaker` module that
is documented as requiring the user to add `{:fuse, "~> 2.5"}` to their own `deps/0`. The
module wraps the `RetryStrategy` behaviour with fuse semantics. Document clearly in the
performance guide.

**Alternatives considered:**
- `breaker` (hex.pm/packages/breaker) — less maintained, fewer downloads than fuse.
- Custom GenServer state machine — re-inventing the wheel, fuse is battle-tested.
- `req_fuse` (v0.3.2) — wraps fuse for Req, not applicable (LatticeStripe doesn't use Req),
  and licensed CC-BY-NC-ND which is non-commercial only.
- Application-level only (leave to users entirely) — valid, but documenting the integration
  pattern saves every user from reinventing it.

**Confidence: HIGH** — fuse v2.5.0 confirmed on hex.pm, OTP 26+ compatible.

#### 3. Rate-Limit Header Tracking

**No new dependencies.** Stripe returns `RateLimit-Limit`, `RateLimit-Remaining`, and
`RateLimit-Reset` headers on every response. The existing `Response` struct and telemetry
pipeline already capture response headers. Extension is: parse these headers in
`LatticeStripe.Client` after every successful response, attach them to the telemetry
`[:lattice_stripe, :request, :stop]` event metadata, and optionally expose them on
`LatticeStripe.Response.t()` as a `rate_limit` field.

Pure-Elixir string parsing — `Integer.parse/1` on header values. No library needed.

**Confidence: HIGH.**

#### 4. OpenTelemetry Integration

**No new runtime dependency for LatticeStripe itself.**

The correct integration path: LatticeStripe already emits `[:lattice_stripe, :request, :*]`
telemetry events. Users attach an OpenTelemetry handler to those events using
`opentelemetry_telemetry` (the bridge library, v1.1.2, maintained by the OTel org).

LatticeStripe's role is to write a guide (`guides/opentelemetry.md`) showing:
1. Add `{:opentelemetry_api, "~> 1.5"}` and `{:opentelemetry_telemetry, "~> 1.1"}` to the
   user's `deps/0`.
2. Attach telemetry handlers that create OTel spans from LatticeStripe events.
3. Example instrumentation code.

Do NOT add `opentelemetry_api` to LatticeStripe's own `mix.exs`. Adding an OTel dep would
force every LatticeStripe user to carry the OTel stack even if they are not using it.
LatticeStripe's telemetry events are the correct abstraction boundary.

**For the guide itself:** Add `opentelemetry_api ~> 1.5` and `opentelemetry_telemetry ~> 1.1`
only as `only: :dev` deps in LatticeStripe's `mix.exs` so the guide examples can be
validated in CI. Do not declare them as `:optional` — they are not a user-facing optional
feature of the SDK, they are guide examples that happen to need the lib to compile.

| Package | Version | Role |
|---------|---------|------|
| `opentelemetry_api` | ~> 1.5 | User's dep — OTel API (traces/metrics/logs) |
| `opentelemetry_telemetry` | ~> 1.1 | User's dep — bridge from `:telemetry` events to OTel spans |
| `opentelemetry` | ~> 1.5 | User's dep — OTel SDK (needed at runtime; `opentelemetry_api` is API-only) |

LatticeStripe only needs `opentelemetry_api ~> 1.5` in `only: :dev` for guide doctests.

**Confidence: HIGH** — opentelemetry_api v1.5.0 confirmed on hex.pm (October 2025),
opentelemetry_telemetry v1.1.2 confirmed on hex.pm.

#### 5. LiveBook Notebook

**No new Hex dependency.** LiveBook notebooks are `.livemd` files — plain Markdown with Elixir
code cells. Ship a `notebooks/stripe_explorer.livemd` file in the repo. Users run it with
their locally installed Livebook (v0.19.6, hex.pm/packages/livebook).

The notebook installs LatticeStripe from Hex inside Livebook's Mix environment using the
standard `Mix.install` pattern:

```elixir
Mix.install([{:lattice_stripe, "~> 1.2"}])
```

No `kino` dependency needed for a basic exploration notebook. Kino (v0.19.0) is useful for
interactive widgets (input fields for API keys, data tables for response inspection) — add
`{:kino, "~> 0.19"}` inside the `Mix.install` in the notebook itself if wanted. This is
a user-side dependency inside the `.livemd`, not a Hex dep of LatticeStripe.

The `.livemd` file is committed to the repo under `notebooks/` and linked from the README
with a "Run in Livebook" badge. No changes to `mix.exs` whatsoever.

**Confidence: HIGH** — Livebook v0.19.6 confirmed on hex.pm (March 2026), kino v0.19.0 confirmed.

#### 6. Stripe API Changelog / Drift Detection in CI

**No new Hex dependency.** This is a CI tooling addition using existing tools.

**Recommended approach:** Add a GitHub Actions workflow (`drift-check.yml`) on a weekly cron
schedule that:
1. Downloads the latest `stripe/openapi` spec (`/latest/spec3.json` from
   `raw.githubusercontent.com/stripe/openapi`) — the repo has 2,236+ releases, updated with
   every Stripe API version.
2. Runs a mix task (`mix lattice_stripe.drift_check`) that compares known resource fields
   against the spec and reports new/removed fields.
3. Opens a GitHub issue (via `gh issue create`) if drift is detected.

The mix task is pure Elixir + Jason (already a dep) for JSON parsing. No additional library.

**Alternative: `oasdiff` GitHub Action** — `oasdiff/oasdiff-action` detects breaking changes
between two OpenAPI specs. Useful if the goal is strict breaking-change alerting, but
overkill for field drift detection since Stripe's API is additive (breaking changes extremely
rare). The mix task approach gives more control over what counts as "drift worth alerting."

**Confidence: MEDIUM** — approach validated by `stripe/openapi` repo structure (verified
April 2026, updated daily, raw file access confirmed). Mix task implementation is standard
Elixir + Jason.

#### 7. `meter_event_stream` Endpoint (v2 API)

**No new dependencies.** Finch's existing `stream/5` function handles this.

**Key finding:** The `/v2/billing/meter_event_stream` endpoint is NOT a streaming protocol
(not SSE, not HTTP/2 push). It is a standard HTTPS POST that accepts batches of up to 100
meter events per request at high concurrency. The "stream" in the name refers to the
high-throughput usage pattern, not a wire protocol. Authentication uses a short-lived session
token (15-minute expiry) obtained from `POST /v2/billing/meter_event_session`.

The URL is `https://meter-events.stripe.com/v2/billing/meter_event_stream` — a different
hostname from `api.stripe.com`. This means LatticeStripe needs a second Finch pool or
accepts the existing Finch instance can open connections to a second host (Finch handles
multi-host automatically per pool configuration).

Implementation: `LatticeStripe.Billing.MeterEventStream` module with:
- `create_session/2` — POST to `/v2/billing/meter_event_session`, returns token + expiry
- `send_events/3` — POST to `/v2/billing/meter_event_stream` with Bearer token auth
- Token renewal handled by caller (no GenServer process in LatticeStripe — caller manages
  token lifecycle per the SDK's "processes only when needed" philosophy)

`Finch.stream/5` is not needed here — this is request/response, not streaming. Standard
`Finch.request/3` suffices.

**Confidence: HIGH** — endpoint protocol confirmed via Stripe API reference (standard POST,
session token auth, `meter-events.stripe.com` hostname). Finch multi-host support confirmed.

#### 8. Changeset-Style Param Builders

**No new dependencies.** This is a pure-Elixir DSL pattern.

The ecosystem search found no purpose-built "builder" library for this use case. The right
approach is a hand-rolled `LatticeStripe.Params` module (or per-resource builder modules)
using Elixir's pipe operator as the composition mechanism:

```elixir
LatticeStripe.Params.SubscriptionSchedule.new()
|> LatticeStripe.Params.SubscriptionSchedule.add_phase(items: [...], iterations: 3)
|> LatticeStripe.Params.SubscriptionSchedule.set_end_behavior(:release)
|> LatticeStripe.Params.SubscriptionSchedule.build()
```

Each builder function returns a map that is passed directly to the resource CRUDL functions.
NimbleOptions (already a dep) validates the final built map before sending to Stripe.

Ecto.Changeset would add Ecto as a dependency — rejected. Ecto is a database library. No database.

**Confidence: HIGH** — pattern is idiomatic Elixir, no library needed.

#### 9. Connection Warm-Up / Pool Pre-Establishment

**No new dependencies.** Finch (already a dep) handles this natively.

Finch's `Finch.stream/5` and `Finch.request/3` lazily establish connections. Pool
pre-establishment is done by sending a real request at application startup. The recommended
pattern is an `Application.start/2` callback or a simple `Task.start/1` in the user's
supervision tree that calls a lightweight endpoint (e.g., `LatticeStripe.Health.ping/1` —
a new zero-cost public function that hits `GET /v1/account` with a short timeout).

Finch 0.21 does not expose an explicit "pre-connect" API — connection establishment is
triggered by the first request. A warm-up helper is a thin wrapper around the existing
transport, not a new capability.

**Confidence: HIGH** — confirmed via Finch documentation (lazy connection model, no explicit
warm-up API).

---

### mix.exs Changes for v1.2

**Runtime deps block: unchanged.** Do not add any new entries to the shipped dependencies.

**Optional dev additions** (only if OpenTelemetry guide examples require compilation in CI):

```elixir
# Add only: :dev entries — NOT optional runtime deps
{:opentelemetry_api, "~> 1.5", only: :dev, runtime: false},
```

**What NOT to add:**
- `{:fuse, "~> 2.5"}` — document as user-declared optional; do not add to LatticeStripe deps
- `{:opentelemetry_api, "~> 1.5"}` as a runtime dep — breaks lean-library philosophy
- `{:kino, "~> 0.19"}` — lives inside `.livemd` Mix.install block, not mix.exs
- Any changeset/builder library — pure-Elixir pattern, no dep needed

---

### Version Verification Summary (April 2026)

| Package | Confirmed Version | Source |
|---------|------------------|--------|
| `:fuse` | 2.5.0 | hex.pm/packages/fuse |
| `opentelemetry_api` | 1.5.0 | hex.pm/packages/opentelemetry_api |
| `opentelemetry_telemetry` | 1.1.2 | hex.pm/packages/opentelemetry_telemetry |
| `livebook` | 0.19.6 | hex.pm/packages/livebook |
| `kino` | 0.19.0 | hex.pm/packages/kino |

---

## v1.1 Addendum — Billing.Meter, Billing.MeterEvent + MeterEventAdjustment, BillingPortal.Session

> This section was added at the start of the v1.1 milestone. It answers the specific
> stack questions for the three new resource modules. The original v1.0 stack content
> follows unchanged below.

### Verdict: No new dependencies required for v1.1

`mix.exs` is complete as-is. Every infrastructure need for the three new modules is
already met by the v1.0 stack.

### Stripe API Version Compatibility (2026-03-25.dahlia)

Verified directly by parsing `stripe/openapi` `spec3.json` (raw JSON, not a web page).
All four endpoint families are present with no beta, restricted, or preview flags:

| Endpoint | OpenAPI path | HTTP methods | Beta/restricted |
|----------|--------------|-------------|-----------------|
| Billing.Meter list/create | `/v1/billing/meters` | GET, POST | none |
| Billing.Meter retrieve/update | `/v1/billing/meters/{id}` | GET, POST | none |
| Billing.Meter deactivate | `/v1/billing/meters/{id}/deactivate` | POST | none |
| Billing.Meter reactivate | `/v1/billing/meters/{id}/reactivate` | POST | none |
| Billing.MeterEvent create | `/v1/billing/meter_events` | POST | none |
| Billing.MeterEventAdjustment create | `/v1/billing/meter_event_adjustments` | POST | none |
| BillingPortal.Session create | `/v1/billing_portal/sessions` | POST | none |

`x-stripeVersion`, `x-stability`, `x-restricted`, and `x-beta` fields are all absent on
every path. **No `stripe_version` bump required.** `2026-03-25.dahlia` is fully compatible.

Background: Stripe deprecated legacy usage-records (`UsageRecord`) in `2025-03-31.basil`.
`Billing.Meter` + `MeterEvent` are now the canonical, non-deprecated metered billing
primitives in every API version from `2025-03-31.basil` onward. `2026-03-25.dahlia` is
well past that boundary. (HIGH confidence — confirmed from Stripe OpenAPI spec + changelog)

### stripe-mock Docker Coverage

**All four v1 endpoint families are covered by `stripe/stripe-mock:latest`.**

stripe-mock is auto-generated from the same `stripe/openapi` spec3.json that was
verified above. Because all paths are present without beta/restricted flags, they are
in the mock. No custom fixtures or overrides needed.

One important behavioral constraint (applies equally to all v1.0 integration tests):
stripe-mock is stateless. It validates request shapes and returns fixture responses.
Cross-request state (e.g., deactivating a meter then querying its status) is not
simulated. Integration tests should assert on response shape and HTTP 200/201 codes,
not multi-step state transitions.

**Endpoint outside v1.1 scope (for clarity):** The high-throughput streaming variant
lives at `/v2/billing/meter-event-stream` (v2 API, different auth model using ephemeral
15-minute session tokens). This is NOT what `Billing.MeterEvent.create/3` uses. v1.1
uses the standard `/v1/billing/meter_events` endpoint with the normal `Stripe-Key`
header — same as every other v1.0 resource. The v2 streaming path is deferred to v1.2+
per locked decision D3.

### No New Dependencies

| Infrastructure need | Already satisfied by |
|--------------------|----------------------|
| HTTP requests to Stripe | Finch `~> 0.21` |
| JSON encode/decode | Jason `~> 1.4` |
| Struct hydration (`from_map/1` pattern) | no dep — pure Elixir pattern |
| Idempotency key threading (`identifier:` opt) | existing client plumbing |
| `stripe_account:` header (Connect compat) | existing client plumbing |
| Telemetry events | `:telemetry ~> 1.0` |
| Option validation for `create/3` opts | NimbleOptions `~> 1.0` |
| Unit test mocking | Mox `~> 1.2` |
| Integration tests | stripe-mock Docker |

### mix.exs: No Changes to deps/0

Do not touch `deps/0`. The current block is correct for v1.1.

### mix.exs: groups_for_modules requires two additions

This is a docs-config change, not a dependency change. It belongs in Phase 20-06
and Phase 21-04 respectively. Recommended approach (mirrors the `Checkout` group
pattern — separate namespace, separate group):

```elixir
# Add after the existing Billing group:
"Billing Metering": [
  LatticeStripe.Billing.Meter,
  LatticeStripe.Billing.Meter.DefaultAggregation,
  LatticeStripe.Billing.Meter.CustomerMapping,
  LatticeStripe.Billing.Meter.ValueSettings,
  LatticeStripe.Billing.Meter.StatusTransitions,
  LatticeStripe.Billing.MeterEvent,
  LatticeStripe.Billing.MeterEventAdjustment
],
"Customer Portal": [
  LatticeStripe.BillingPortal.Session,
  LatticeStripe.BillingPortal.Session.FlowData
],
```

Rationale for separate groups over appending to "Billing": `Billing.Meter*` is a
distinct sub-namespace with its own guide; `BillingPortal` mirrors `Checkout` in
structure (create-only session, namespace-based). New groups keep the HexDocs sidebar
navigable as the module count grows.

Also add new guide paths to `extras:` in the docs config:
- `"guides/metering.md"` (Phase 20-06)
- `"guides/customer-portal.md"` (Phase 21-04)

### Optional: StreamData for property testing

Not required for v1.1. Mentioned because `MeterEvent.create/3` is the hot path in
Accrue and idempotency correctness matters.

[StreamData](https://hex.pm/packages/stream_data) `~> 1.1` is the Elixir ecosystem
standard for property-based tests (ExUnit-integrated, `use ExUnitProperties`).

Why NOT to add it in v1.1:
1. stripe-mock is stateless — server-side `identifier` deduplication cannot be exercised
   against it. The real idempotency guarantee lives in Stripe's infrastructure.
2. `identifier:` in `MeterEvent.create/3` is a passthrough string opt — encoding path
   is identical to every other string opt already tested in v1.0.
3. Adds CI overhead for a minor release with limited return.

If property tests are added in a future milestone, the right targets are broader:
`FormEncoder` with arbitrary nested maps, pagination cursor parsing, timestamp
boundary values across all resources. Add StreamData then, not now.

---

## Platform Target

| Requirement | Value | Rationale |
|-------------|-------|-----------|
| Elixir | >= 1.15 | ~2.5 year coverage; 1.15 introduced compile-time improvements and better warnings. Covers OTP 24-26 minimum. PROJECT.md specifies 1.15+. |
| Erlang/OTP | >= 26 | Aligns with Elixir 1.15 upper bound and 1.19 lower bound. OTP 26 is mature and widely deployed. |
| Elixir upper tested | 1.19.x | Current stable (1.19.5). Test CI matrix against 1.15 through 1.19. |
| OTP upper tested | 28 | Latest stable supported by Elixir 1.19. |

**Confidence: HIGH** -- Verified against official Elixir compatibility table at hexdocs.pm/elixir/compatibility-and-deprecations.html.

## Recommended Stack

### Core Runtime Dependencies

These ship to users. Minimize aggressively.

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Finch | ~> 0.21 | Default HTTP transport | Mint-based, built-in connection pooling, async-friendly, the modern Elixir HTTP primitive. Used by Req, Swoosh, and most production Elixir apps. Lighter than Req for an SDK (no redirect/retry/decompression overhead -- LatticeStripe owns those behaviors). | HIGH |
| Jason | ~> 1.4 | JSON encoding/decoding | Undisputed Elixir ecosystem standard. Blazing fast pure-Elixir implementation. Every Phoenix app already has it. | HIGH |
| :telemetry | ~> 1.0 | Instrumentation events | Erlang ecosystem standard for metrics/tracing. Emitting telemetry events lets users plug in any monitoring stack (Prometheus, DataDog, OpenTelemetry) without LatticeStripe knowing about it. | HIGH |
| Plug | ~> 1.16 | Webhook endpoint plug | Only needed for the webhook verification Plug. Use `plug` not `plug_cowboy` -- LatticeStripe provides a Plug, users bring their own server. Broad version range because Plug's core API is stable. | HIGH |
| Plug Crypto | ~> 2.0 | HMAC signature verification | Provides `Plug.Crypto.secure_compare/2` for timing-safe comparison in webhook signature verification. Pulled in transitively by Plug but worth noting explicitly. | HIGH |

### Optional Runtime Dependencies

| Technology | Version | Purpose | When Needed | Confidence |
|------------|---------|---------|-------------|------------|
| NimbleOptions | ~> 1.0 | Option schema validation | For validating client config and per-request options with clear error messages. Dashbit-maintained, tiny, used by Finch/Broadway/etc. Declare as optional dep -- recommended but not required. | MEDIUM |

**NimbleOptions rationale:** Provides schema-based validation with auto-generated docs for options. Alternative is hand-rolled validation with Keyword/Map checks -- works fine but NimbleOptions gives better error messages for free. Recommend including it as a hard dependency given its tiny footprint and ecosystem ubiquity.

### Dev/Test Dependencies

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| ExUnit | (stdlib) | Test framework | Ships with Elixir. No external test framework needed. | HIGH |
| Mox | ~> 1.2 | Behaviour-based test mocks | Dashbit-maintained, idiomatic Elixir pattern for mocking behaviours (Transport, RetryStrategy). Concurrent-safe with `async: true`. | HIGH |
| ExDoc | ~> 0.34 | Documentation generation | Official Elixir documentation tool. Generates beautiful HTML docs for HexDocs. Version floor of 0.34 covers through current 0.40.x. | HIGH |
| Credo | ~> 1.7 | Static analysis / linting | Code consistency tool. Not Dialyzer -- lighter, faster, focuses on style and common mistakes. PROJECT.md explicitly excludes Dialyzer. | HIGH |
| MixAudit | ~> 2.1 | Security vulnerability scanning | Scans deps for known CVEs. Cheap insurance for CI. | MEDIUM |
| stripe-mock | latest (Docker) | Integration test server | Official Stripe mock HTTP server powered by OpenAPI spec. Run in CI via Docker (`stripe/stripe-mock:latest`). Not a Hex dep -- a test infrastructure service. | HIGH |

### CI/CD Tooling (Not Hex Dependencies)

| Tool | Purpose | Why |
|------|---------|-----|
| GitHub Actions | CI/CD | Free for open source, excellent Elixir ecosystem support, matrix builds. |
| stripe-mock Docker image | Integration testing | `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`. Official, auto-updated from Stripe OpenAPI spec. |
| Release Please | Automated releases | Conventional Commits to automated changelog + version bump + GitHub Release. |
| Hex.pm publishing | Package distribution | `mix hex.publish` in CI on release tag. |

## mix.exs Dependencies Block

```elixir
defp deps do
  [
    # Runtime
    {:finch, "~> 0.21"},
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.0"},
    {:plug, "~> 1.16"},
    {:plug_crypto, "~> 2.0"},
    {:nimble_options, "~> 1.0"},

    # Dev/Test
    {:mox, "~> 1.2", only: :test},
    {:ex_doc, "~> 0.34", only: :dev, runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
  ]
end
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| HTTP Client | Finch | **Req** | Req is built on Finch and adds retry, redirect, decompression. But LatticeStripe needs to own retry logic (Stripe-Should-Retry header, idempotency semantics). Req's batteries would conflict with SDK-specific behavior. Finch gives the right level of control. |
| HTTP Client | Finch | **HTTPoison/Hackney** | Legacy. Hackney has known memory issues under load. Finch (Mint-based) is the modern replacement endorsed by the community. |
| HTTP Client | Finch | **Tesla** | Tesla is a middleware HTTP client -- good pattern for general apps but overkill for an SDK that controls its own pipeline. Adds unnecessary abstraction layer. |
| JSON | Jason | **Poison** | Slower, less maintained. Jason is the uncontested standard since ~2019. |
| JSON | Jason | **JSON (stdlib)** | Elixir 1.18+ includes a JSON module in stdlib. Too new to target as minimum -- we support 1.15+. Jason remains the right choice until the stdlib JSON module is available across all supported versions. Could offer as a configurable codec via behaviour in future. |
| Mocking | Mox | **Mimic** | Mimic patches modules at runtime (like RSpec mocks). Mox enforces behaviour contracts -- aligns with LatticeStripe's architecture of Transport/RetryStrategy behaviours. |
| Linting | Credo | **Dialyzer/Dialyxir** | Explicitly excluded per PROJECT.md. Dialyzer is slow, produces confusing false positives, and typespecs are documentation-only in this project. |
| Docs | ExDoc | (no real alternative) | ExDoc is the official, only serious option for Elixir documentation. |
| Options validation | NimbleOptions | **Hand-rolled** | NimbleOptions is 200 lines of code, battle-tested, and gives auto-generated docs. Not worth hand-rolling. |

## Architecture-Relevant Stack Decisions

### Transport Behaviour (NOT a dependency choice)

LatticeStripe defines a `LatticeStripe.Transport` behaviour. Finch is the default adapter. Users can implement the behaviour to use Req, Tesla, HTTPoison, or anything else. This means:

- Finch is a **default** dependency, not a hard coupling
- The behaviour contract is: `request(method, url, headers, body, opts) :: {:ok, response} | {:error, reason}`
- Tests mock the Transport behaviour via Mox

### JSON Codec Behaviour (future-proofing)

Define a `LatticeStripe.JSON` behaviour with `encode/1` and `decode/1`. Default implementation wraps Jason. When Elixir stdlib JSON matures across the ecosystem, users can swap without LatticeStripe changes.

### Why NOT Req for an SDK

This deserves emphasis. Req is excellent for application-level HTTP but wrong for an SDK because:

1. **Retry ownership**: Stripe has specific retry semantics (Stripe-Should-Retry header, idempotency key replay). Req's built-in retry would fight with SDK retry logic.
2. **Error mapping**: LatticeStripe needs to parse Stripe error responses into structured types. Req's error handling is generic.
3. **Connection pooling**: Finch lets LatticeStripe configure a dedicated pool for `api.stripe.com` with SDK-appropriate settings (size, timeouts).
4. **Dependency weight**: Req brings in Finch anyway, plus ~15 additional deps. An SDK should be lean.

## Elixir CI Test Matrix

```yaml
# Recommended GitHub Actions matrix
strategy:
  matrix:
    include:
      - elixir: "1.15"
        otp: "26"
      - elixir: "1.17"
        otp: "27"
      - elixir: "1.19"
        otp: "28"
```

Three combinations covering the floor, middle, and ceiling of supported versions. More than three adds CI time without proportional value.

## What NOT to Use

| Technology | Why Not |
|------------|---------|
| **Dialyzer/Dialyxir** | Explicitly excluded. Slow, janky DX, false positives. Typespecs are for documentation. |
| **HTTPoison** | Legacy Hackney wrapper. Memory issues. Community has moved to Finch/Req. |
| **Poison** | Superseded by Jason years ago. No reason to use it. |
| **Tesla** | Middleware abstraction unnecessary for an SDK that owns its entire request pipeline. |
| **Req** | Too high-level. Retry/error/redirect logic conflicts with SDK-specific Stripe semantics. |
| **ExVCR / Bypass** | ExVCR records real HTTP and replays cassettes -- brittle, hard to maintain. Bypass is a local HTTP server -- stripe-mock is better because it validates against Stripe's actual OpenAPI spec. Use Mox for unit tests, stripe-mock for integration tests. |
| **Ecto** | No database. This is an HTTP client library. |
| **GenServer for state** | Per PROJECT.md philosophy: "processes only when truly needed." Client config is a struct passed explicitly, not process state. Finch handles connection pool processes. |
| **`/v2/billing/meter-event-stream`** | v2 high-throughput streaming endpoint — different auth model (ephemeral 15-minute session tokens), different semantics. Deferred to v1.2+ per locked decision D3. v1.1 uses `/v1/billing/meter_events` with standard `Stripe-Key` auth. |
| **`req_fuse`** | Circuit breaker wrapper for Req — wrong HTTP client. Also CC-BY-NC-ND licensed (non-commercial only). |
| **`breaker`** | Less maintained Elixir circuit breaker alternative to `:fuse`. Fewer downloads, less community validation. |

## Sources

- [Finch on Hex.pm](https://hex.pm/packages/finch) -- v0.21.0 confirmed
- [Finch Documentation](https://hexdocs.pm/finch/Finch.html) -- pool configuration, stream/5 function, HTTP/2 streaming support confirmed
- [Jason on Hex.pm](https://hex.pm/packages/jason) -- v1.4.4 confirmed
- [Telemetry on Hex.pm](https://hex.pm/packages/telemetry) -- v1.4.1 confirmed
- [Plug on Hex.pm](https://hex.pm/packages/plug) -- v1.19.1 confirmed
- [Plug.Crypto Documentation](https://hexdocs.pm/plug_crypto/) -- v2.1.1, HMAC verification
- [NimbleOptions on Hex.pm](https://hex.pm/packages/nimble_options) -- v1.1.1 confirmed
- [Mox on GitHub](https://github.com/dashbitco/mox) -- v1.2.0 confirmed
- [ExDoc on Hex.pm](https://hex.pm/packages/ex_doc) -- v0.40.1 confirmed
- [Credo on Hex.pm](https://hex.pm/packages/credo) -- v1.7.17 confirmed
- [MixAudit on Hex.pm](https://hex.pm/packages/mix_audit) -- v2.1.5 confirmed
- [stripe-mock on GitHub](https://github.com/stripe/stripe-mock) -- Docker image available; auto-generated from Stripe OpenAPI spec
- [stripe/openapi spec3.json](https://github.com/stripe/openapi) -- direct JSON parse confirmed all four v1.1 endpoint paths present, no beta/restricted flags (verified 2026-04-13); 2,236+ releases, updated April 16 2026
- [Stripe Billing Meters API Reference](https://docs.stripe.com/api/billing/meter) -- endpoint shape, fields, deactivate/reactivate verbs confirmed
- [Stripe Meter Events API Reference](https://docs.stripe.com/api/billing/meter-event) -- POST /v1/billing/meter_events confirmed
- [Stripe Customer Portal Sessions API Reference](https://docs.stripe.com/api/customer_portal/sessions) -- create-only confirmed
- [Stripe Changelog: deprecate legacy usage-based billing](https://docs.stripe.com/changelog/basil/2025-03-31/deprecate-legacy-usage-based-billing) -- meters canonical post-2025-03-31.basil; 2026-03-25.dahlia is stable territory
- [Stripe v2 Meter Event Stream API Reference](https://docs.stripe.com/api/v2/billing-meter-stream) -- confirmed standard HTTPS POST (not SSE/HTTP/2 push), session token auth, meter-events.stripe.com hostname
- [Stripe v2 Meter Event Stream changelog](https://docs.stripe.com/changelog/acacia/2024-09-30/usage-based-billing-v2-meter-events-api) -- high-throughput up to 10k events/sec, 100 events per request, 15-minute session tokens
- [fuse on Hex.pm](https://hex.pm/packages/fuse) -- v2.5.0 confirmed, Erlang circuit breaker, OTP application
- [opentelemetry_api on Hex.pm](https://hex.pm/packages/opentelemetry_api) -- v1.5.0 confirmed (October 2025)
- [opentelemetry_telemetry on Hex.pm](https://hex.pm/packages/opentelemetry_telemetry) -- v1.1.2 confirmed, telemetry-to-OTel bridge
- [Livebook on Hex.pm](https://hex.pm/packages/livebook) -- v0.19.6 confirmed (March 2026)
- [kino on Hex.pm](https://hex.pm/packages/kino) -- v0.19.0 confirmed, Livebook interactive widgets
- [req_fuse on Hex.pm](https://hex.pm/packages/req_fuse) -- v0.3.2, CC-BY-NC-ND (non-commercial), Req-only integration, rejected
- [oasdiff GitHub Action](https://github.com/oasdiff/oasdiff-action) -- OpenAPI breaking change detection, alternative to custom mix task
- [Elixir Compatibility Table](https://hexdocs.pm/elixir/compatibility-and-deprecations.html) -- version matrix verified
- [Req on Hex.pm](https://hex.pm/packages/req) -- v0.5.17, confirmed Finch-based
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) -- official best practices
- [Elixir v1.19 Release](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/) -- current stable series
