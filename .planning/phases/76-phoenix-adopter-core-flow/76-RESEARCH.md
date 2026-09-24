# Phase 76: Phoenix Adopter Core Flow — Research

**Researched:** 2026-09-24  
**Domain:** Elixir library adopter harness; Phoenix/Plug request boundary; Stripe Checkout subscription and webhook contracts  
**Confidence:** HIGH for the in-repository API and official framework patterns; MEDIUM for exact host dependency versions and architecture recommendations.

## User Constraints

No phase `CONTEXT.md` exists. These scope and outcome constraints are copied from the roadmap and requirements:

### Locked Decisions

> “**Goal:** Maintainers can verify that a host Phoenix application configures and uses LatticeStripe as a dependency across a common SaaS flow.” [VERIFIED: `.planning/ROADMAP.md:83-87`]
>
> “1. A test-only Phoenix app imports the checked-out LatticeStripe package as a path dependency and starts with its documented host configuration and supervision.  
> 2. A synthetic Checkout or subscription flow exercises typed Stripe responses and webhook handling from the host app boundary.  
> 3. The core adopter flow runs without live Stripe credentials or production data.” [VERIFIED: `.planning/ROADMAP.md:88-92`]
>
> “**ADOPT-01**: Maintainers can run one test-only Phoenix application that imports the checked-out LatticeStripe package as a dependency and verifies host configuration and supervision.  
> **ADOPT-02**: An adopter test can exercise a common Checkout or subscription flow through typed responses and webhook handling using synthetic data and no live Stripe credentials.” [VERIFIED: `.planning/REQUIREMENTS.md:16-20`]

### The Agent’s Discretion

- Choose the smallest Phoenix host-app shape and test boundary that proves both requirements.
- Choose fixture and transport-double patterns that remain deterministic and represent public adopter usage.
- Choose whether persistence, database tooling, a listening HTTP server, or UI components add value to this proof.

### Deferred Ideas (OUT OF SCOPE)

- B2B invoicing, usage reconciliation, Connect tenant-context profiles, broader error/pagination/idempotency profiles, and CI integration are assigned to Phase 77, not this phase. [VERIFIED: `.planning/ROADMAP.md:96-110`; `.planning/REQUIREMENTS.md:20-22`]
- Published Hex-install proof and release work are Phase 78. A path dependency does not prove the published tarball. [VERIFIED: `.planning/ROADMAP.md:112-128`]
- Business billing policy, production data, live credentials, and a billing engine remain out of scope. [VERIFIED: `.planning/REQUIREMENTS.md:68-77`]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADOPT-01 | “Maintainers can run one test-only Phoenix application that imports the checked-out LatticeStripe package as a dependency and verifies host configuration and supervision.” [VERIFIED: `.planning/REQUIREMENTS.md:18`] | Mix path dependency, isolated host Mix project, Phoenix endpoint and app supervision, in-process Phoenix.ConnTest proof. |
| ADOPT-02 | “An adopter test can exercise a common Checkout or subscription flow through typed responses and webhook handling using synthetic data and no live Stripe credentials.” [VERIFIED: `.planning/REQUIREMENTS.md:19`] | Host invokes public Checkout API through a mock transport, asserts typed response, then posts a signed synthetic webhook through the real endpoint and `LatticeStripe.Webhook.Plug`. |

## Summary

Build one standalone, test-only Phoenix host app in a clearly non-package directory (recommended: `test_apps/phoenix_adopter`). Make its `mix.exs` use a path dependency to the repository root, so Mix compiles the checked-out package as an adopter would consume it. Do not add Phoenix, Ecto, or adopter code to LatticeStripe’s runtime dependency surface. The package currently keeps its published file allow-list to `lib`, `priv/api`, project metadata, README, changelog, and license, which excludes a root-level `test_apps` harness. [VERIFIED: `mix.exs:192-224`]

The most representative small flow is subscription-mode Checkout creation followed by a synthetic `checkout.session.completed` webhook. Use the host’s test transport double to return a Stripe-shaped JSON response and assert that the public SDK call yields `%LatticeStripe.Checkout.Session{}`. Then generate a signed payload with the existing public test helper and send it through Phoenix.ConnTest to the endpoint-mounted LatticeStripe webhook plug; assert the host handler receives a typed event and the endpoint acknowledges it. This crosses the dependency, client/decoder, endpoint, signature verification, parsing, handler, and supervision boundaries without a Stripe call or persistence layer. The repository already documents this API path and helper. [VERIFIED: `guides/checkout.md:88-111`; `guides/testing.md:29-57,331-378`]

**Primary recommendation:** use Phoenix.ConnTest against an in-process, supervised Endpoint; use an explicit test-only LatticeStripe.Transport double and public signed-webhook helper; keep the host app stateless and omit Ecto/Repo, live server sockets, real Stripe credentials, browser UI, and business billing policy.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Checked-out package consumption | Mix / host application | LatticeStripe package | A path dependency proves the source package compiles and resolves from a separate Mix project. |
| Checkout request/typed response | Host application / LatticeStripe client boundary | Test transport | Host calls the public API; fake transport supplies a wire response while the package still encodes, decodes, and constructs the typed struct. |
| Webhook request and signature | Phoenix Endpoint + Plug | LatticeStripe webhook parser/handler contract | Phoenix owns routing/supervision; LatticeStripe owns Stripe signature verification and event decoding. |
| Billing persistence / subscription policy | — | — | No persistent state or product policy is required by ADOPT-01/02; omit Repo/Ecto. |
| Browser presentation | — | — | This is a maintainer proof harness, not a user-facing application. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | Follow repository support; current environment is Elixir/Mix 1.19.5. Package declares `elixir: "~> 1.15"`. | Independent host project and dependency resolution. | Mix path dependencies are the native mechanism for compiling a checked-out local library as a dependency. Path dependencies recompile when source changes. [CITED: [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html)] |
| LatticeStripe | Path to checked-out repository root | Package under test. | It ensures this proof is against the actual checkout, not a second published version. [CITED: [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html)] |
| Phoenix | Use current supported Phoenix 1.8 line; official docs consulted at 1.8.14. | Host Endpoint/Router and ConnTest integration. | Endpoint is Phoenix’s supervised request boundary; ConnTest directly dispatches into it. [CITED: [Phoenix 1.8.14 API](https://phoenix.hexdocs.pm/api-reference.html), [Phoenix testing](https://phoenix.hexdocs.pm/testing.html)] |
| Plug | Resolved from Phoenix and the optional package integration; repository requirement is `~> 1.16`. | Endpoint parser and webhook request pipeline. | Plug’s `body_reader` hook exists specifically to preserve raw bytes before parser transformation. [CITED: [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html)] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Mox | Use the repository-compatible `~> 1.2` requirement in the host’s test environment (current root lock resolves 1.2.0). | Behavior-based transport mock and per-test request expectation. | Recommended for explicit request assertions and isolated concurrent tests. Add it directly to the host app: the package’s own `only: :test` dependency is not a consumer dependency. [VERIFIED: `mix.exs:202-209`; `mix.lock:22`; CITED: [Mox docs](https://mox.hexdocs.pm/Mox.html)] |
| Jason | Inherited from the package/Phoenix dependency graph; root package declares `~> 1.4`. | Encode synthetic Stripe response and webhook JSON. | Use the same decoder expected by the endpoint. [VERIFIED: `mix.exs:194-200`; CITED: [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html)] |
| LatticeStripe.Testing | Public package API | Build a Stripe-signed synthetic webhook payload/header pair. | Use instead of hand-rolling the event JSON/HMAC. [VERIFIED: `guides/testing.md:29-57,133-148`; `lib/lattice_stripe/testing.ex:327-350`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Separate path-dependency host project | Add Phoenix directly to the SDK’s existing test environment | Simpler command surface, but it blurs consumer and package-test dependencies and does not prove the independent host Mix configuration. |
| In-process Phoenix.ConnTest | Start Cowboy and issue localhost HTTP requests | Exercises TCP/adapter wiring too, but adds ports, process cleanup, and timing failure modes that do not improve this phase’s host configuration/webhook Plug proof. Reserve socket-level behavior for a later, evidence-backed need. |
| Synthetic fake transport response | stripe-mock HTTP server | Adds external process/installation and HTTP coverage, but official stripe-mock documentation explicitly says its responses are static and its state is stateless; it cannot model Checkout→subscription lifecycle. Use it only for route/request sanity, not lifecycle proof. [CITED: [stripe-mock](https://github.com/stripe/stripe-mock)] |
| Public fixture builders owned by host app | Import package-private `test/support` fixtures | Sharing fixtures is convenient but couples an adopter harness to private source paths. Keep the host’s minimum wire payload local and small; public package helpers are the supported boundary. |
| No database | Ecto Repo with SQL Sandbox | A Repo could demonstrate persistence integration, but this phase has no storage requirement. It introduces DB service setup, sandbox ownership/concurrency concerns, and app billing semantics, obscuring package adoption. Ecto recommends explicit sandbox ownership; add only when a later requirement exercises persistence. [CITED: [Ecto testing](https://ecto.hexdocs.pm/3.13.2/testing-with-ecto.html)] |

### Installation / host dependency shape

Use a separate Mix project under a root-level test-only directory. In its `deps/0`, declare the repository as a path dependency and Phoenix as a host test app dependency; add Mox only under the host’s test environment. Commit the host’s lockfile for repeatable dependency resolution. The exact directory and dependency tuple are implementation choices (see Assumptions Log); relative paths must be resolved from the host project directory. Mix documents the path form as `{:foobar, path: "path/to/foobar"}` and notes local path dependencies recompile as they change. [CITED: [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html)]

Do not add Ecto/Postgrex, LiveView, assets, or a production HTTP adapter unless the selected Phoenix project setup genuinely requires an adapter to compile/start its endpoint. Prefer `server: false` in test configuration and ConnTest dispatch; no external socket is needed for the request flow.

## Package Legitimacy Audit

The configured package-legitimacy seam accepts only npm, PyPI, and crates. A direct Hex invocation returned: `Error: Usage: gsd-tools package-legitimacy check --ecosystem <npm|pypi|crates> <pkg1> ...`. Therefore the automated legitimacy verdict cannot be produced for Phoenix or Mox in this environment. Sources below are official HexDocs/package documentation; this is not a substitute for an automated Hex provenance audit. [CITED: [Phoenix API docs](https://phoenix.hexdocs.pm/api-reference.html), [Mox docs](https://mox.hexdocs.pm/Mox.html)]

| Package | Registry | Version evidence | Source | Verdict / disposition |
|---------|----------|------------------|--------|-----------------------|
| Phoenix | Hex | Official Phoenix documentation is for 1.8.14. | Phoenix HexDocs | Automated legitimacy gate unsupported for Hex; use as the required host framework, lock dependency resolution. |
| Mox | Hex | Root project currently locks 1.2.0; current official docs are v1.3.2. | Mox HexDocs | Automated legitimacy gate unsupported for Hex; optional host-only testing dependency. |

**Packages removed due to SLOP verdict:** none.  
**Packages flagged as suspicious SUS:** none.  
**Package risk note:** Keep all new dependencies confined to this test app and its lockfile, not the published package dependency list.

## Architecture Patterns

### System Architecture Diagram

```text
ExUnit test
  ├─ calls host checkout function
  │    └─ LatticeStripe Checkout.Session.create
  │         └─ host Mox transport ── synthetic Stripe-shaped JSON
  │              └─ LatticeStripe decoder ── typed Checkout.Session
  └─ sends signed synthetic Event with Phoenix.ConnTest
       └─ supervised Phoenix Endpoint → LatticeStripe.Webhook.Plug
            ├─ verify exact raw bytes + signature
            ├─ decode Event
            └─ host handler → observable test assertion / 2xx response
```

The transport mock isolates only outbound Stripe HTTP. Keep the endpoint and webhook plug real. That split lets the test prove host wiring and package behavior without pretending to simulate Stripe’s remote state machine. This matches the repository’s testing pyramid and Stripe’s own `stripe-mock` limitation statement. [VERIFIED: `guides/testing.md:8-25`; CITED: [stripe-mock](https://github.com/stripe/stripe-mock)]

### Recommended Project Structure

```text
test_apps/
└── phoenix_adopter/
    ├── mix.exs             # independent host deps; path dep points to repository root
    ├── mix.lock             # app-local lock for its Phoenix/test dependencies
    ├── config/              # test endpoint/application configuration only
    ├── lib/                  # minimal Application, Endpoint, Router, Checkout flow, handler
    └── test/                 # one end-to-end adopter test and local synthetic response data
```

`test_apps/phoenix_adopter` is a recommendation, not an existing repository path. A root-level directory avoids letting the root Mix test discovery treat the nested host app’s `*_test.exs` files as ordinary package tests; confirm the chosen invocation explicitly runs the host project. Keep host fixtures minimal and local so they cannot accidentally depend on private package test support. The current Hex package allow-list excludes this harness from publication. [VERIFIED: `mix.exs:213-224`]

### Pattern 1: Path dependency as consumer proof

**What:** A dedicated host Mix project compiles LatticeStripe through a relative `path:` dependency and calls only public package modules.  
**When to use:** Proving source checkout compatibility before the later published-release check.  
**Tradeoff:** It validates source dependency compilation and API usage, but not Hex packaging, release metadata, or installability. Phase 78 must prove the published package separately.  
**Source:** [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html).

### Pattern 2: End-to-end request without a listening server

**What:** Configure `Phoenix.ConnTest`’s endpoint and use `post/3` to exercise the actual endpoint/router in-process.  
**When to use:** Host route, Plug pipeline, handler response, and supervision checks where socket/adapter behavior is not in scope.  
**Tradeoff:** Avoids port conflicts and external server lifecycle; does not prove TCP adapter behavior. Phoenix.ConnTest dispatches requests directly to the endpoint. [CITED: [Phoenix testing](https://phoenix.hexdocs.pm/testing.html), [Phoenix.ConnTest](https://phoenix.hexdocs.pm/1.8.2/Phoenix.ConnTest.html)]

### Pattern 3: Host-owned outbound transport mock, real inbound webhook

**What:** Mock only `LatticeStripe.Transport.request/1`; allow LatticeStripe to encode the request and decode the returned JSON. Use `LatticeStripe.Testing.generate_webhook_payload/3`, then pass the raw payload and signature header through the endpoint’s actual webhook plug.  
**When to use:** Proving the two sides of the HTTP integration boundary while remaining offline.  
**Tradeoff:** Tests contract plumbing and decoding, not Stripe account behavior, webhook delivery retries, or a payment lifecycle. [VERIFIED: `lib/lattice_stripe/transport.ex:21-50`; `lib/lattice_stripe/testing.ex:327-350`; `guides/testing.md:331-378`]

### Anti-Patterns to Avoid

- **Do not invoke the default Finch transport.** Even with a fake test key, it would reach an external service if the flow is accidentally executed; inject a transport double and make unexpected outbound calls fail.
- **Do not parse/re-encode before signature verification.** Stripe’s signature covers exact raw request bytes; Plug documents `body_reader` for raw-body preservation. Prefer the already documented package webhook plug before `Plug.Parsers`. [CITED: [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html); VERIFIED: `guides/webhooks.md:15-53`]
- **Do not assert success from a browser redirect.** The redirect is UX; Stripe’s event is the confirmation path. [VERIFIED: `guides/checkout.md:45-47,109-111`]
- **Do not create a bespoke fake Stripe service or add stateful Checkout/subscription simulation.** It adds a second implementation of provider behavior and false confidence; a focused fixture proves the package boundary.
- **Do not make a test-only host into an app template.** No auth, HTML, billing database, job processing, retries, or customer-facing UX is required.

## Don’t Hand-Roll

| Problem | Don’t Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stripe webhook signature generation | Custom HMAC implementation or fixed signature string | `LatticeStripe.Testing.generate_webhook_payload/3` | Exercises the package’s actual signature format and avoids crypto/header mistakes. [VERIFIED: `lib/lattice_stripe/testing.ex:327-350`] |
| Webhook request verification and event decode | Custom host Plug that duplicates SDK verification | `LatticeStripe.Webhook.Plug` and host handler behavior | Proves consumer configuration of the supported integration. [VERIFIED: `guides/webhooks.md:31-53,70-103`] |
| Stripe HTTP response construction | Mock endpoint server plus mutable remote state | Host-side test transport expectation returning one response fixture | Preserves the real package request/decoder path while avoiding external infrastructure. [VERIFIED: `guides/testing.md:113-193`] |
| Phoenix request harness | Raw Cowboy listener and handcrafted HTTP client | `Phoenix.ConnTest` | Direct endpoint dispatch keeps the proof fast and isolates TCP as an unneeded variable. [CITED: [Phoenix ConnTest](https://phoenix.hexdocs.pm/1.8.2/Phoenix.ConnTest.html)] |
| Persistence and transactional cleanup | Ecto Repo + test database + Sandbox | No persistence for this phase | Requirements do not ask to prove an app storage boundary; avoid incidental DB/service setup. [VERIFIED: `.planning/REQUIREMENTS.md:18-22`; CITED: [Ecto testing](https://ecto.hexdocs.pm/3.13.2/testing-with-ecto.html)] |

**Key insight:** This harness should be a narrow contract probe. Each fake fixture should be simple enough that maintainers can see exactly what SDK behavior it exercises; Stripe’s own mock-server documentation warns that a mock with static, stateless responses cannot stand in for provider lifecycle behavior. [CITED: [stripe-mock](https://github.com/stripe/stripe-mock)]

## Common Pitfalls

### Pitfall 1: Testing the SDK from its own Mix project

**What goes wrong:** Phoenix can compile as a test dependency but the harness never proves a downstream host project can resolve and start LatticeStripe.  
**Why:** Package tests and host-app dependencies have different dependency environments.  
**How to avoid:** Keep a separate Mix project with a path dependency and its own lockfile; invoke tests from that project directory. Mix recompiles path dependencies when they change. [CITED: [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html)]  
**Warning signs:** Phoenix is added to root `mix.exs`; test references root `test/support` modules; no host dependency lock exists.

### Pitfall 2: Webhook signature fails after parsing

**What goes wrong:** A valid fixture signature fails because the handler receives parsed or re-encoded JSON rather than the raw body.  
**Why:** HMAC verification is byte-sensitive; JSON whitespace/key-order transformations change signed bytes. Plug’s body parser consumes the body unless a custom body reader preserves it. [CITED: [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html), [Stripe signature troubleshooting](https://support.stripe.com/questions/webhooks-what-to-do-when-the-http-status-code-starts-with-a-four-%284xx%29-or-five-%285xx%29?locale=en-GB)]  
**How to avoid:** Mount LatticeStripe’s documented webhook Plug before `Plug.Parsers` and send the helper-produced raw binary unchanged. [VERIFIED: `guides/webhooks.md:31-53,203-206`]  
**Warning signs:** Calling `read_body/1` after parser execution or signing `Jason.encode!(conn.body_params)`.

### Pitfall 3: Confusing Checkout response with billing truth

**What goes wrong:** A host test marks a subscription active solely because Checkout Session creation returned successfully or a success URL was reached.  
**Why:** Checkout creation and asynchronous payment/subscription outcomes are separate events; Stripe event snapshots are versioned at event creation. [CITED: [Stripe Events](https://docs.stripe.com/api/events/object?api-version=2025-06-30.basil), [Stripe Checkout Sessions](https://docs.stripe.com/api/checkout/sessions?how=)]  
**How to avoid:** In this proof, assert the returned typed Session, then separately assert the signed `checkout.session.completed` event reaches the host handler. Do not claim this simulates payment collection or the full subscription lifecycle. [VERIFIED: `guides/checkout.md:88-111`]

### Pitfall 4: Mox calls occur in a different process

**What goes wrong:** A private expectation is unavailable to the request process and the test fails as “unexpected call.”  
**Why:** Mox expectations are process-owned by default. [CITED: [Mox multi-process collaboration](https://mox.hexdocs.pm/Mox.html)]  
**How to avoid:** Keep `ConnTest`’s outbound request synchronous in the test process for this core flow; if a later harness intentionally spawns a client task, use Mox’s explicit allowance mechanism and wait for the assertion signal. Do not switch globally to Mox global mode to hide ownership errors.

### Pitfall 5: Test credentials leak into network paths or artifacts

**What goes wrong:** A fake key accidentally reaches Finch, a live `whsec_` value is copied into fixtures, or sensitive payload data appears in test output.  
**How to avoid:** Use unmistakably synthetic test-only keys/secrets, inject the mock transport, ensure there is no production env fallback, assert `livemode` remains false in the event, and never log raw request bodies. Stripe’s Event contract has an explicit `livemode` field; synthetic fixtures should exercise test-mode shape. [CITED: [Stripe Event object](https://docs.stripe.com/api/events/object?api-version=2025-06-30.basil); VERIFIED: `guides/webhooks.md:188-192`]

## Code Examples

The public surface already documents the Checkout creation and webhook payload conventions. These snippets are an architectural outline; proposed host module names and paths are illustrative assumptions, not existing repository APIs.

```elixir
# Host flow: call the public API; the host test transport returns JSON.
{:ok, session} =
  LatticeStripe.Checkout.Session.create(client, %{
    "mode" => "subscription",
    "success_url" => success_url,
    "line_items" => line_items
  })

assert %LatticeStripe.Checkout.Session{} = session

# Then use the public helper and send the unchanged raw payload through Phoenix.ConnTest.
{payload, signature} =
  LatticeStripe.Testing.generate_webhook_payload(
    "checkout.session.completed",
    synthetic_session_event,
    secret: test_webhook_secret,
    id: test_event_id
  )

conn = post(conn, webhook_path, payload, [{"stripe-signature", signature}])
assert conn.status == 200
```

`mode: "subscription"`, `success_url`, and `line_items` are the documented create contract. [VERIFIED: `lib/lattice_stripe/checkout/session.ex:35-40,88-107`] The webhook helper accepts `secret` and optional `id`; its signature timestamp defaults to the current time while its event `created` value is also generated at runtime. Set a stable event ID if useful, but do not assert the generated timestamp or serialize the full event as a fixed snapshot. [VERIFIED: `lib/lattice_stripe/testing.ex:327-350`] The event name is documented as the post-Checkout subscription provision event. [VERIFIED: `guides/checkout.md:109-111`] The host variable names/route above are proposed placeholders `[ASSUMED]`; a handler returning `:ok` receives the documented 200 response. [VERIFIED: `lib/lattice_stripe/webhook/plug.ex:78-87`]

The outbound mock should assert a POST to the Checkout Sessions endpoint and return a minimal valid Checkout Session response JSON. Use `LatticeStripe.Transport`’s documented request/response map contract rather than bypassing the client decoder. [VERIFIED: `lib/lattice_stripe/transport.ex:21-50`]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Unit-test only the client/resource modules | Add a dependency-consuming host app at an actual Phoenix Endpoint boundary | Current phase goal | Reveals dependency, supervision, parser order, and plug integration failures that isolated SDK unit tests cannot expose. [INFERENCE from `.planning/ROADMAP.md:83-92` and Phoenix Endpoint docs] |
| Treat a mock server as lifecycle simulation | Use narrow synthetic fixture tests for deterministic contract and provider test mode only for genuine remote behavior | stripe-mock documents current scope/limits | Avoids false confidence from a static, stateless server. [CITED: [stripe-mock limitations](https://github.com/stripe/stripe-mock)] |
| Webhook examples that parse before verifying | Preserve exact body bytes and verify before parsed-body handling | Plug’s documented body-reader hook | Avoids signature failures and keeps retention explicitly scoped. [CITED: [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html)] |

**Deprecated/outdated:** Do not copy archived sample recommendations that rely on `Plug.Parsers` body-reader plumbing when the current canonical package guide recommends mounting `LatticeStripe.Webhook.Plug` before the parser. The parser/body-reader path remains supported as an advanced alternative. [VERIFIED: `guides/webhooks.md:31-53,152-191`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit; Phoenix.ConnTest for endpoint requests; Mox or a host-owned behavior implementation for outbound HTTP. |
| Config file | New host app `mix.exs`, endpoint configuration, and test helper. |
| Quick run command | `cd test_apps/phoenix_adopter && mix test` (proposed path; adjust if implementation selects another root-level test-app directory). |
| Full suite command | Same host project test command for Phase 76; root `mix ci` remains the SDK suite and Phase 77 decides CI aggregation. |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADOPT-01 | Path dependency resolves; host config and OTP supervision start; Endpoint can receive ConnTest requests. | compile + application/endpoint integration | `mix test` from adopter project | ❌ New host app/test |
| ADOPT-02 | Checkout create traverses public client/decoder into a typed Session, then a signed synthetic webhook reaches host handler through the endpoint. | integration | `mix test` from adopter project | ❌ New host app/test |

### Sampling Rate

- **Per task commit:** Run the affected host test file while developing, then the host app’s full `mix test` before merge.
- **Phase gate:** Host suite green and root `mix ci` green; no live credentials or internet should be required by the host flow.

### Wave 0 Gaps

- [ ] Create the independent Phoenix host project, config, application supervision, endpoint/router, test transport and webhook handler.
- [ ] Create a small host-owned synthetic Checkout Session response and `checkout.session.completed` payload fixture.
- [ ] Add an app-local lockfile and direct test dependency entries for framework/test tooling.

## Security Domain

No auth/session/UI security surface is part of this phase. Applicable checks are input validation and cryptographic verification at the inbound webhook edge.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No user login/authentication flow exists. |
| V3 Session Management | No | No browser session or cookies are required. |
| V4 Access Control | No | No multi-user or tenant policy is implemented. |
| V5 Input Validation | Yes | Let LatticeStripe webhook decode/validation reject malformed events; test raw body preservation and signed helper payload. Keep synthetic payload minimal. |
| V6 Cryptography | Yes | Delegate Stripe signature generation/verification to LatticeStripe’s public test/webhook APIs; never hand-roll HMAC or disable timestamp/signature checks. |
| V10 Malicious Code | Yes | Pin host dependencies in its own lockfile; test transport must prevent requests escaping to network. |
| V14 Data Protection | Yes | Synthetic-only identifiers; do not persist/log full raw webhook bodies. |

### Known Threat Patterns for Phoenix/Plug Stripe Webhooks

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Parsed or normalized body before signature check | Tampering / spoofing | Verify the exact request bytes; mount the package plug before parsers. |
| Reusing a production webhook secret or Stripe credential in test fixtures | Information disclosure | Use synthetic strings; ensure no production environment fallback exists. |
| Accidental live HTTP transport use | Denial of service / unintended external side effects | Inject the transport double and fail on unexpected requests; no real API credentials or live endpoint. |
| Unbounded request-body retention in parser config | Information disclosure / resource exhaustion | Use the package’s scoped webhook path; keep Plug limits and avoid raw body logs. Plug documents a default maximum body length and supports explicit limits. [CITED: [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html)] |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Host Mix project | ✓ | 1.19.5 | — |
| PostgreSQL | None; no Repo is recommended | ✓ (`pg_isready` accepts connections) | Not queried | Do not use it in this phase. |
| Stripe CLI | None; synthetic helper replaces local Stripe forwarding | ✓ | Not queried | No fallback needed. |
| Docker | None | ✓ | Not queried | No fallback needed. |
| Hex dependency fetch | Phoenix host project | Not probed during research | — | Resolve dependencies when executing; no known need for custom external services. |

## Project Constraints (from AGENTS.md)

No `AGENTS.md` exists at the repository root. Existing project evidence to preserve: package runtime dependencies are explicit and Plug is optional; Mox is currently test-only; the published package file list excludes test harnesses. [VERIFIED: `mix.exs:192-224`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The host app should live at `test_apps/phoenix_adopter` and its relative path dependency should target the repository root. | Structure / Stack | Mix root test discovery or task ergonomics may be different than anticipated; adjust path/command while retaining project separation. |
| A2 | Phoenix 1.8 is the best host baseline for this project’s current adopter proof. | Standard Stack | A newer or older supported Phoenix line may be the actual maintainer target; maintain a host lockfile and confirm against the repo’s intended compatibility policy. |
| A3 | A Mox expectation can be consumed synchronously during ConnTest’s direct endpoint dispatch in this flow. | Pitfalls / Code Examples | If application code starts a process, add explicit Mox allowance/signaling or use a deterministic host transport fake. |
| A4 | An event handler can expose receipt to the test without a database, e.g. by returning an observable response or synchronous test message. | Architecture | If handler contract requires durable work, add only a small test-owned sink, not an Ecto billing model. |
| A5 | No `plug_cowboy` adapter is needed when the Endpoint is started with server disabled and only used by ConnTest. | Stack | If the chosen generated endpoint requires an adapter dependency to compile/start, include the host-only adapter but keep it from binding a port. |
| A6 | Elixir 1.19.5 environment availability represents the local planning machine only. | Environment | Does not establish CI/consumer support; Phase 77/78 must verify target CI matrix. |

## Open Questions

1. **What command should developers use to run the host harness?** Recommended `cd` into the independent test app and run `mix test`; wire it into root CI only in Phase 77.
2. **Should the synthetic fixture be a JSON file or an inline minimal map?** Prefer inline or a small host-owned fixture module unless the payload is long enough that a JSON fixture materially improves reviewability.
3. **Should the host test assert its Endpoint process is alive explicitly?** Yes, if the standard test startup reliably starts the host application. Otherwise make a focused application-start assertion and keep the request test’s endpoint process lifecycle standard.

## Sources

### Primary (HIGH confidence for documented behaviors)

- [Mix dependencies](https://hexdocs.pm/mix/Mix.Tasks.Deps.html) — path dependency syntax and recompilation behavior.
- [Phoenix 1.8.14 API reference](https://phoenix.hexdocs.pm/api-reference.html), [Phoenix testing](https://phoenix.hexdocs.pm/testing.html), [Phoenix.ConnTest 1.8.2](https://phoenix.hexdocs.pm/1.8.2/Phoenix.ConnTest.html) — endpoint/ConnTest roles and direct dispatch.
- [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html) — raw body reader, parsing, and request-size behavior.
- [Ecto testing](https://ecto.hexdocs.pm/3.13.2/testing-with-ecto.html) — sandbox setup and ownership semantics.
- [Mox](https://mox.hexdocs.pm/Mox.html) — behavior mocks, expectations, verification, and process ownership.
- [Stripe Event object](https://docs.stripe.com/api/events/object?api-version=2025-06-30.basil), [Checkout Sessions](https://docs.stripe.com/api/checkout/sessions?how=), [Stripe signature troubleshooting](https://support.stripe.com/questions/webhooks-what-to-do-when-the-http-status-code-starts-with-a-four-%284xx%29-or-five-%285xx%29?locale=en-GB) — event snapshot version/mode and raw-body signature constraints.
- Repository: `mix.exs`, `mix.lock`, `lib/lattice_stripe/application.ex`, `lib/lattice_stripe/transport.ex`, `lib/lattice_stripe/testing.ex`, `guides/checkout.md`, `guides/testing.md`, `guides/webhooks.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`.

### Successful examples and failure evidence

- [Stripe’s stripe-mock](https://github.com/stripe/stripe-mock) — successful SDK request-shape smoke testing; the maintainers document static responses and stateless behavior as limitations, supporting a narrow role rather than lifecycle simulation.
- [stripe-ruby-mock](https://github.com/stripe/stripe-ruby-mock) — fixture-based, overrideable event examples and no-network testing; its README also warns it does not cover all API endpoints, a reminder that test doubles must not be treated as full provider validation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH for Mix/Phoenix/Plug/Mox documented behavior; MEDIUM for the proposed exact Phoenix host version.
- Architecture: HIGH for existing package API and phase requirements; MEDIUM for the recommended directory and app shape.
- Pitfalls: HIGH for raw-body/signature issues and mock limitations; MEDIUM for process ownership behavior pending the implemented harness.

**Research date:** 2026-09-24  
**Valid until:** 2026-10-24 for stable framework patterns; re-check version recommendations before adding dependencies.
