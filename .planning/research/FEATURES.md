# Feature Landscape

**Domain:** Elixir Stripe SDK (API client library)
**Researched:** 2026-03-31
**Overall confidence:** HIGH (based on extensive project research documents, official Stripe SDK analysis, and Elixir ecosystem review)

## Table Stakes

Features users expect from any serious Stripe SDK. Missing any of these means developers stick with stripity_stripe or consider switching languages.

### Foundation Layer (Tier 0)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| HTTP transport with pluggable adapter | Every SDK needs a reliable HTTP layer; Elixir devs expect behaviour-based extensibility | Medium | Transport behaviour with Finch default. Must handle form-encoded v1 requests. |
| Client configuration struct | Official SDKs all use instance-based StripeClient pattern (2024+). Multi-tenant Elixir apps require per-client config. | Low | API key, base URL, timeouts, retries, API version, telemetry toggle. |
| Per-request option overrides | Every official SDK supports this. Essential for Connect (stripe_account), idempotency, and version overrides. | Low | idempotency_key, stripe_account, api_key, stripe_version, expand, timeout. |
| Structured error model | All official SDKs implement same error hierarchy. Pattern matching is Elixir's strength -- errors must be matchable. | Medium | CardError, InvalidRequestError, AuthenticationError, RateLimitError, APIError, IdempotencyError, etc. Each carries type, code, message, param, request_id. |
| Automatic retries with exponential backoff | Official SDKs do this by default since 2023+. Stripe-Should-Retry header support is expected. | Medium | Respect Stripe-Should-Retry, configurable max retries, jittered backoff. |
| Idempotency key support | Stripe explicitly recommends idempotency on all mutations. SDKs auto-generate keys on retry. | Low | Auto-generation on retry, manual override, replay detection. |
| `{:ok, result} \| {:error, reason}` returns | Elixir convention. Any library not following this pattern is dead on arrival. | Low | Bang variants (create!/2) layered on top. |
| Cursor-based list pagination | Every official SDK provides this. Manual page fetching is baseline. | Low | starting_after, ending_before, limit parameters. Return List struct with has_more. |
| Auto-pagination via Streams | Official SDKs all provide auto_paging_each or async iterators. Stream.resource/3 is the Elixir pattern. Community explicitly complained about stripity_stripe lacking this. | Medium | Lazy enumerable composable with Stream/Enum. This is a top community pain point. |
| Webhook signature verification | The #1 community pain point in Elixir. Developers skip verification when it is hard. Must handle raw body correctly. | Medium | construct_event/3 function. Must document the Phoenix raw body problem explicitly. |
| Raw response access | Official SDKs expose request_id, status, headers. Essential for debugging and support tickets. | Low | Available on response structs or via option. |
| API version pinning | Stripe releases monthly versions. SDK must pin and allow override. | Low | Pin per library release, override per-client and per-request. |

### Resource Coverage (Tier 1 -- Payments)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| PaymentIntents CRUD + lifecycle | The center of modern Stripe. Create, retrieve, update, confirm, capture, cancel, list. | Medium | State-machine-heavy. Must support confirm-on-create, manual capture, off-session. |
| SetupIntents CRUD + lifecycle | Save-for-later is the second most common payment flow. | Low | create, retrieve, update, confirm, cancel, list. |
| PaymentMethods CRUD + attach/detach | Backbone of subscriptions and off-session billing. | Low | create, retrieve, update, list, attach, detach. Customer-scoped listing. |
| Customers CRUD + search | Foundational across all Stripe use cases. | Low | create, retrieve, update, delete, list, search. |
| Refunds CRUD | Operationally critical for admin/support tooling. | Low | create, retrieve, update, list. Partial refunds. |

### Resource Coverage (Tier 2 -- Checkout)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Checkout Sessions | Many devs judge the library by how easy Checkout is. Major integration path. | Medium | create, retrieve, list, expire. Payment/subscription/setup modes. Line items, customer prefill. |

### Webhook Handling

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Event parsing | Must deserialize webhook payloads into typed structs. | Low | v1 snapshot events. Type field for dispatch. |
| Phoenix Plug for webhooks | Elixir devs use Phoenix. A drop-in Plug that handles raw body extraction is expected. | Medium | Must run before Plug.Parsers or handle raw body caching. This is the #1 Elixir Stripe pain point. |
| Tolerance window configuration | Prevent replay attacks with configurable timestamp tolerance. | Low | Default 300 seconds, configurable. |

### Developer Experience

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| ExDoc documentation with guides | Elixir devs expect excellent HexDocs. Grouped modules, examples, guides. | Medium | Quickstart guide, per-resource examples, error handling guide. |
| Typespecs on all public functions | Convention in Elixir ecosystem even without Dialyzer enforcement. | Low | @spec on every public function. @type for all structs. |
| Comprehensive test suite | Open source credibility. Integration tests primary, unit tests for pure logic. | High | stripe-mock, Stripe CLI, Mox for behaviour injection. |
| README with <60 second quickstart | First impression. Copy-paste to working code. | Low | Install, configure, make first API call. |

## Differentiators

Features that set LatticeStripe apart from stripity_stripe and emerging competitors. Not expected, but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Search pagination support | stripity_stripe lacks this entirely. Page-based pagination for /search endpoints with eventual consistency caveats documented. | Low | Different pagination model from list endpoints (page, next_page). |
| Telemetry events for request lifecycle | Elixir ecosystem standard (Phoenix, Ecto, Finch all emit telemetry). No existing Stripe lib does this well. | Medium | [:lattice_stripe, :request, :start\|:stop\|:exception] with duration, method, path, status, request_id. Also [:lattice_stripe, :webhook, :*]. |
| Expand support as first-class concept | stripity_stripe supports expand but not ergonomically. Handling id-vs-expanded-object unions cleanly is a real differentiator. | High | Union types for expandable fields. Nested expansion. List expansions (data.*). |
| Pattern-matchable domain types | Elixir's pattern matching is a superpower. Rich structs with atom-based status/type fields enable elegant case/with clauses. | Medium | Status atoms (:succeeded, :requires_action), currency atoms, type enums. stripe-kit (Swift) proves this approach works beautifully. |
| Retry strategy as pluggable behaviour | Most SDKs hard-code retry logic. A behaviour allows custom backoff, circuit breaking, or retry budgets. | Low | Default exponential backoff. Users can implement custom RetryStrategy behaviour. |
| JSON codec as pluggable behaviour | Most apps use Jason, but some use Poison or other encoders. | Low | Jason default, behaviour for override. Minimal effort, high flexibility signal. |
| Test helpers and utilities | No Elixir Stripe library provides good testing support. Req.Test enables plug-based concurrent test stubs. | Medium | Test fixture helpers, mock webhook event construction, example factory functions. |
| Stripe-Account header as first-class | Connect support baked into the request path from day one, not bolted on. Every request function accepts stripe_account option. | Low | Community explicitly complained about poor Connect support in stripity_stripe. |
| Detailed error context for debugging | Beyond just type/code -- include request_id, HTTP status, full error body, suggestion text when available. | Low | Inspect-friendly error structs. Actionable error messages. |
| Up-to-date API version (2026-03-25.dahlia) | stripity_stripe targets Stripe API 2019-12-03 -- a 6+ year gap. Being current is a major selling point. | Low | Just building new means being current. Competitors are years behind. |
| Idempotency conflict detection | Parse 409 responses specifically. Surface idempotency key reuse conflicts as a distinct error type. | Low | IdempotencyError with original request_id and conflicting key info. |

## Anti-Features

Features to deliberately NOT build. Each exclusion is intentional.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Code generation from OpenAPI spec (v1) | PROJECT.md explicitly scopes v1 as handwritten. Codegen adds complexity, generates un-idiomatic code, and Stripe's custom OpenAPI extensions (x-expandableFields, x-expansionResources) break standard generators. Handwritten code enables polish and ergonomics over breadth. | Hand-craft Tier 0/1/2 resources. Consider codegen as a future milestone for breadth. |
| Dialyzer/Dialyxir support | PROJECT.md decision: "feels janky." Typespecs serve as documentation, not enforcement. | Write comprehensive typespecs for documentation. Pattern matching + tagged tuples provide runtime safety. |
| Higher-level billing abstractions | A "Pay gem" / "Laravel Cashier" style layer (Ecto schemas, subscription lifecycle management, billable traits) is a separate project with different change cadence and dependencies. | Build the API client first. Higher-level billing layer is a future separate package. |
| Global module-level configuration | Official SDKs moved away from this (2024+). Global config creates problems for multi-tenant apps, test isolation, and concurrent usage. | Instance-based client struct pattern. Application config as fallback only. |
| Ecto dependency | An API client library should not force Ecto on users. Not everyone uses Ecto. | Pure data structs. Ecto integration belongs in a separate billing-layer package. |
| Phoenix dependency (except webhook Plug) | API client should work outside Phoenix. Webhook Plug is the one justified Phoenix touch point. | Optional Plug dependency for webhook handling only. Core library is framework-agnostic. |
| v2 API namespace support | v2 is still evolving. v1 snapshot events cover the vast majority of use cases. Thin events and v2 semantics are a future milestone. | Focus on v1 completely. Document v2 as future scope. |
| Legacy Charges/Tokens/Sources as primary API | Stripe explicitly recommends PaymentIntents. Building around legacy APIs sends the wrong signal. | Support Charges for read/retrieve only if needed. PaymentIntents are the primary path. |
| Full API surface breadth | 30+ product categories with hundreds of resources. Covering everything in v1 means shallow quality everywhere. | Deep polish on Foundation + Payments + Checkout + Webhooks. Billing, Connect, Tax, Identity, etc. are future milestones. |
| Mobile/frontend SDK | Backend-only. Stripe.js handles the frontend. | Document how to use with Stripe.js and Phoenix LiveView in guides. |
| Automatic webhook event routing/dispatch | A pub/sub event routing system (like Pay gem's ActiveSupport::Notifications pattern) belongs in a higher-level layer, not the API client. | Provide construct_event/3 and a simple Phoenix Plug. Users implement their own dispatch. |
| Billing test clocks | Specialized testing feature for subscriptions. Out of scope until Billing milestone. | Future milestone alongside subscription support. |

## Feature Dependencies

```
Transport Behaviour -----> HTTP Client (Finch adapter)
       |
       v
Client Configuration ----> Per-request Options
       |
       v
Request Building --------> Error Model (response parsing)
       |                        |
       v                        v
Retry Logic <-----------> Idempotency Key Handling
       |
       v
Pagination (List) -------> Auto-pagination (Streams)
       |
       v
Resource Modules --------> PaymentIntents, SetupIntents, PaymentMethods, Customers, Refunds
       |
       v
Checkout Sessions -------> (depends on all resource modules being pattern-established)
       |
       v
Webhook Verification ----> Event Parsing --> Phoenix Plug
       |
       v
Telemetry Events -------> (cross-cutting, can be added at any layer)
       |
       v
Expand Support ----------> (cross-cutting, affects all resource modules)
```

**Critical path:** Transport -> Client -> Errors -> Retries -> Pagination -> First Resource (Customers) -> Remaining Resources -> Webhooks

**Parallel work after foundation:**
- Telemetry can be woven in alongside resource modules
- ExDoc/guides can be written alongside implementation
- Test infrastructure builds incrementally with each resource

## MVP Recommendation

**Prioritize (ship with v0.1.0):**

1. **Foundation layer complete** -- Transport, client config, per-request options, error model, retries, idempotency, pagination, auto-pagination Streams. This is the layer that makes everything "just work" and is the hardest to change later.

2. **Customers CRUD + search** -- Simplest resource, establishes the pattern for all other resources. Every Stripe integration touches Customers.

3. **PaymentIntents full lifecycle** -- The center of modern Stripe. Create, confirm, capture, cancel, list. This is what developers evaluate first.

4. **SetupIntents + PaymentMethods** -- Completes the payment flow story. Save-for-later is the second most common use case.

5. **Refunds** -- Operationally critical, low complexity, rounds out the payment story.

6. **Checkout Sessions** -- Many developers judge the whole library by how easy Checkout is. High-leverage polish target.

7. **Webhook signature verification + Phoenix Plug** -- The #1 Elixir community pain point. Solving this well is an immediate differentiator.

8. **Telemetry events** -- Low effort, high signal. Establishes production-readiness credibility.

**Defer to future milestones:**

- **Billing (subscriptions, invoices, products, prices):** Large surface area, complex lifecycle. Second milestone.
- **Connect (accounts, transfers, payouts):** Major surface, different user persona. Third milestone.
- **Tax, Identity, Treasury, Issuing, Terminal:** Specialist domains. Coverage milestones.
- **v2 API support (thin events, include, JSON encoding):** API is still evolving. Wait for stability.
- **Code generation from OpenAPI:** Consider after v1 handwritten library proves the architecture.
- **Higher-level billing layer (Ecto schemas, subscription management):** Separate package, separate project.

## Competitive Analysis Summary

| Feature | stripity_stripe | pin_stripe | tiger_stripe | LatticeStripe (target) |
|---------|----------------|------------|--------------|----------------------|
| API version | 2019-12-03 | Current | Current | 2026-03-25.dahlia |
| Last release | May 2024 | Dec 2025 | Feb 2026 | New |
| Auto-pagination | No | No | Unknown | Yes (Streams) |
| Search pagination | No | No | Unknown | Yes |
| Telemetry | No | No | Unknown | Yes |
| Webhook Plug | Buggy (#855) | Yes (Spark DSL) | Unknown | Yes (solves raw body) |
| Error types | Basic | Basic | Unknown | Full hierarchy, pattern-matchable |
| Retries | No | No | Unknown | Yes (exponential backoff, Stripe-Should-Retry) |
| Idempotency | Manual only | No | Unknown | Auto-generate + manual override |
| Connect support | Poor | Unknown | Unknown | First-class (stripe_account on every request) |
| Expand support | Basic | Basic | Unknown | First-class (union types) |
| Transport | Hackney | Req | Unknown | Pluggable behaviour (Finch default) |
| Test helpers | No | No | Unknown | Yes (Req.Test based) |
| Typed structs | Codegen | Minimal | Codegen | Handcrafted, pattern-matchable |

## Sources

- Project research: `/prompts/stripe-lib-priority-user-flows-deep-research.md` -- Tier priority analysis
- Project research: `/prompts/stripe-sdk-api-surface-area-deep-research.md` -- Complete API surface mapping
- Project research: `/prompts/The definitive Stripe library gap in Elixir - a master research document.md` -- Ecosystem gap analysis, community pain points, prior art
- [Stripe Auto-pagination docs](https://docs.stripe.com/api/pagination/auto?lang=ruby)
- [stripe-ruby GitHub](https://github.com/stripe/stripe-ruby)
- [stripe-node GitHub](https://github.com/stripe/stripe-node)
- [Stripe Advanced Error Handling](https://docs.stripe.com/error-low-level)
- [Stripe Idempotent Requests](https://docs.stripe.com/api/idempotent_requests)
- [stripity-stripe GitHub](https://github.com/beam-community/stripity-stripe)
- [PinStripe Hex Preview](https://preview.hex.pm/preview/pin_stripe/show/README.md)
- [SDKs with Req: Stripe - Dashbit Blog](https://dashbit.co/blog/sdks-with-req-stripe)
- [Stripe SDKs Documentation](https://docs.stripe.com/sdks)
- [Stripe Server-side SDK Introduction](https://docs.stripe.com/sdks/server-side)
