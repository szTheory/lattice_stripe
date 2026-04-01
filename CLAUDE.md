<!-- GSD:project-start source:PROJECT.md -->
## Project

**LatticeStripe**

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe aims to be the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

### Constraints

- **Language**: Elixir 1.15+, OTP 26+
- **License**: MIT
- **No Dialyzer**: Typespecs for documentation only, not enforced
- **HTTP**: Transport behaviour with Finch as default adapter (library doesn't hard-depend on one client)
- **JSON**: Jason (Elixir ecosystem standard)
- **Stripe API**: Pin to current stable version, support per-request override
- **Dependencies**: Minimal — only what's truly needed (Finch, Jason, Telemetry, Plug for webhook)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Platform Target
| Requirement | Value | Rationale |
|-------------|-------|-----------|
| Elixir | >= 1.15 | ~2.5 year coverage; 1.15 introduced compile-time improvements and better warnings. Covers OTP 24-26 minimum. PROJECT.md specifies 1.15+. |
| Erlang/OTP | >= 26 | Aligns with Elixir 1.15 upper bound and 1.19 lower bound. OTP 26 is mature and widely deployed. |
| Elixir upper tested | 1.19.x | Current stable (1.19.5). Test CI matrix against 1.15 through 1.19. |
| OTP upper tested | 28 | Latest stable supported by Elixir 1.19. |
## Recommended Stack
### Core Runtime Dependencies
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
- Finch is a **default** dependency, not a hard coupling
- The behaviour contract is: `request(method, url, headers, body, opts) :: {:ok, response} | {:error, reason}`
- Tests mock the Transport behaviour via Mox
### JSON Codec Behaviour (future-proofing)
### Why NOT Req for an SDK
## Elixir CI Test Matrix
# Recommended GitHub Actions matrix
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
## Sources
- [Finch on Hex.pm](https://hex.pm/packages/finch) -- v0.21.0 confirmed
- [Finch Documentation](https://hexdocs.pm/finch/Finch.html) -- pool configuration details
- [Jason on Hex.pm](https://hex.pm/packages/jason) -- v1.4.4 confirmed
- [Telemetry on Hex.pm](https://hex.pm/packages/telemetry) -- v1.4.1 confirmed
- [Plug on Hex.pm](https://hex.pm/packages/plug) -- v1.19.1 confirmed
- [Plug.Crypto Documentation](https://hexdocs.pm/plug_crypto/) -- v2.1.1, HMAC verification
- [NimbleOptions on Hex.pm](https://hex.pm/packages/nimble_options) -- v1.1.1 confirmed
- [Mox on GitHub](https://github.com/dashbitco/mox) -- v1.2.0 confirmed
- [ExDoc on Hex.pm](https://hex.pm/packages/ex_doc) -- v0.40.1 confirmed
- [Credo on Hex.pm](https://hex.pm/packages/credo) -- v1.7.17 confirmed
- [MixAudit on Hex.pm](https://hex.pm/packages/mix_audit) -- v2.1.5 confirmed
- [stripe-mock on GitHub](https://github.com/stripe/stripe-mock) -- Docker image available
- [Elixir Compatibility Table](https://hexdocs.pm/elixir/compatibility-and-deprecations.html) -- version matrix verified
- [Req on Hex.pm](https://hex.pm/packages/req) -- v0.5.17, confirmed Finch-based
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) -- official best practices
- [Elixir v1.19 Release](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/) -- current stable series
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
