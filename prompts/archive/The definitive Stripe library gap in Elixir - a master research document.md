# The definitive Stripe library gap in Elixir: a master research document

**The Elixir ecosystem lacks a production-grade, actively maintained Stripe library — and the gap is widening.** The incumbent `stripity_stripe` has not shipped a release since May 2024, trails the Stripe API by multiple major versions, and accumulates unresolved issues while the Stripe API expands into usage-based billing, v2 endpoints, and new product categories. Several experimental replacements have emerged (PinStripe, tiger_stripe) but none has reached stability. This document maps the complete opportunity space for building the canonical Stripe solution for Elixir/Phoenix — covering the current ecosystem, developer pain points, prior art from Ruby/PHP/Swift, the full Stripe API surface, architecture decisions, and a prioritized feature roadmap.

---

## 1. The Elixir Stripe ecosystem is fractured and stagnant

### stripity_stripe: dominant but drifting

The only widely used Elixir Stripe library remains `stripity_stripe` (beam-community/stripity-stripe), with **5.6 million all-time Hex.pm downloads** and ~233k monthly downloads as of March 2026. Its current version is **v3.2.0**, last released **May 9, 2024** — nearly two years without a new release. The library targets **Stripe API version 2019-12-03** (per external tutorials), while Stripe's current API version is **`2026-03-25.dahlia`** — a gap of over six years. The v3 line was auto-generated from Stripe's OpenAPI spec, which was a significant architectural improvement over v2's hand-crafted modules, but the codegen has not been re-run against recent specs.

GitHub activity shows only **4 open issues** as of late 2025 — not a sign of health, but of low triage activity. Issues #879 (can't get subscription for invoice), #878 (deleted customers missing `deleted` key), #877 (compiler warnings with newer Elixir), and #831 (outdated API version table) remain unresolved. The library's `Stripe.WebhookPlug` has known issues (#855: 400 errors in development), and type definitions cause Dialyzer failures (#823, #568). An ElixirForum thread titled "Is Stripity Stripe maintained?" captures the community's concern directly.

- **Hex.pm**: https://hex.pm/packages/stripity_stripe
- **GitHub**: https://github.com/beam-community/stripity-stripe
- **Stars**: ~1,100 | **Forks**: ~372 | **License**: BSD-3-Clause

### Emerging alternatives remain experimental

**PinStripe** (formerly TinyElixirStripe) appeared in December 2025, directly inspired by Wojtek Mach's Dashbit blog post "SDKs with Req: Stripe." It uses **Req** as its HTTP client, features a **Spark-powered webhook handler DSL**, automatic signature verification, and Igniter-powered code generators. With 1,314 recent downloads on Hex.pm and 33 likes on its ElixirForum announcement, it has the most community interest of any new library. However, the author admits: *"let's be honest, no one is using this yet."* It's published as `pin_stripe` v0.3.4.

**tiger_stripe** appeared in February 2026, claiming "complete Stripe SDK for Elixir with 1:1 parity to the official Ruby SDK — V1+V2 API coverage (190 services, 307 resources, 523 typed params)." With only 308 total downloads, it's too new to evaluate but represents the most ambitious scope claim. Published as `tiger_stripe` v0.1.10.

**paper_tiger** (v1.0.2, January 2026) is not a client library but a **stateful mock Stripe server for testing** — addressing a major pain point. It has 3,403 total downloads, relatively strong early adoption for a testing tool.

**Bling** (ozziexsh/bling, v0.5.0) is the closest thing to a Laravel Cashier or Pay gem equivalent in Elixir, providing Ecto-integrated subscription management for Phoenix. However, it depends on `stripity_stripe ~> 2.17` (the older v2 line), has only **130 GitHub stars** and 598 recent Hex downloads, and is pre-1.0. Its companion **Bankroll** provides prebuilt subscription management UI. Bling covers subscription creation, cancellation, resumption, plan swapping, trials, and webhook handling — but lacks metered billing and one-off charges.

### The abandoned graveyard

All other Elixir Stripe packages are effectively dead: `stripe_elixir` (v0.8.0, 9 years old), `stripy` (v2.1.0, 8 years old), `extripe`, `stripex`, `stripi`, `stripe_post`, `s76_stripe` — none maintained. Two earlier OpenAPI-generated attempts, `striped` (v0.5.0) and `exoapi_stripe` (v0.1.4), are both 3+ years old with under 1,000 total downloads.

| Package | Version | Recent Downloads | Status |
|---|---|---|---|
| `stripity_stripe` | v3.2.0 | 233,619/month | Stagnant (no release since May 2024) |
| `pin_stripe` | v0.3.4 | 1,314 | Experimental (Dec 2025) |
| `tiger_stripe` | v0.1.10 | 308 | Very new (Feb 2026) |
| `paper_tiger` | v1.0.2 | 3,403 | Testing tool only |
| `bling` | v0.5.0 | 598 | Pre-1.0, depends on stripity v2 |
| All others | Various | <500 | Abandoned |

---

## 2. What Elixir developers are specifically asking for

Community complaints cluster around **seven core pain points**, drawn from ElixirForum threads, GitHub issues, and Reddit discussions. Understanding these precisely defines what the new library must solve on day one.

### Webhook signature verification: "dev happiness rock bottom"

The single most technically frustrating issue. Phoenix's `Plug.Parsers` consumes the raw request body, but Stripe's webhook signature verification requires it. Developer @outlog on ElixirForum described implementing webhook verification as their *"first (and only!) 'bad' experience in Elixir world... something you assume is gonna be fast to do — but gets you into quite the rabbit hole."* Multiple ElixirDaze attendees reported the same problem. Developer @Crowdhailer noted their team *"copied and pasted the plug parsers into our codebase and added a line to put the raw body in conn.assigns[:raw_body]"* — an extreme workaround. The fear is developers skip verification entirely: *"worst case is if people implement these webhooks without verifying, because it's quite steep to understand what's going on."*

### No subscription lifecycle management layer

Developer @nehero (Bling creator): *"When I was working with Laravel every day we made extensive use of the Laravel Cashier package. I had been missing it while working on Elixir products."* Developer @artem (June 2024): *"I failed to figure any standard libraries and advices on how to handle it in Elixir. Just integrating stripe payments with a library is relatively easy... but what do you do on the Phoenix side then? What do you use for defining payment plans, tracking credit expirations... promo code discounts, etc?"* The community's advice is resignation: *"Instead of searching for a universal library, I'd recommend building out a client that interacts with the endpoints you care about."*

### Stripe Connect is poorly supported

Developer @MatijaL (July 2024): *"I'm building a platform which uses Stripe Connect for payments. There is stripity_stripe package available for Stripe but Stripe made big changes to their API and stripity_stripe doesn't support them yet."* Multiple users struggled with the `Stripe-Account` header for connected accounts. The original 2.0 RFC acknowledged that *"both teams were/are implementing on top of Stripe's Connect functionality and found the existing version's endpoint modules to be generally lacking best practice support for the Stripe-Account header."*

### Testing infrastructure is inadequate

PaperTiger's creator documented the problem: Stripe's official `stripe-mock` is stateless (can't create then fetch), the webhook sandbox is limited to 5 endpoints, shared test mode causes CI collisions, and there's no time control for subscription testing. Developer @lawik: *"Probably 6-7 years back I worked on a client project that had stripity stripe and they were rawdogging everything and had very little in terms of tests."*

### Additional specific pain points

- **Inaccurate type specs**: Dialyzer conflicts on subscription updates (#823), missing optional keys on checkout sessions (#568), deleted customers lacking `deleted` key (#878), nested object relationships broken (#879)
- **No auto-pagination**: Official Stripe SDKs all provide `auto_paging_each`/`autoPagingEach`; stripity_stripe requires manual cursor management
- **API version lag**: StakNine tutorial warns users *"may experience failed charges in regions with very recent regulatory changes, such as India"*
- **LiveView + Stripe Elements integration** is poorly documented and requires careful phx-hook management
- **Metered/usage-based billing** unsupported in Bling; no library covers the new Billing Meters API
- **Some developers consider switching languages**: *"I still half wonder if I wouldn't be better off implementing this in Go or PHP since those are officially supported SDKs"*

---

## 3. Prior art: the Pay gem sets the standard for billing libraries

The Ruby **Pay gem** (pay-rails/pay, v11.4.3, December 2025) represents the gold standard for framework-integrated billing. With **~2,200 GitHub stars**, 154 total releases, and support for 6 payment processors (Stripe, Braintree, Paddle Billing, Paddle Classic, Lemon Squeezy, FakeProcessor), it demonstrates what a mature billing layer looks like.

### Database schema: six tables

Pay's schema cleanly separates billing concerns from application models via polymorphic associations:

**`pay_customers`** stores the processor-customer mapping: `owner_type`/`owner_id` (polymorphic to User/Team/Account), `processor` ("stripe"/"braintree"), `processor_id` (Stripe Customer ID), `default` flag, `data` (JSONB), `stripe_account` (Connect), `object` (full Stripe response JSON), and `deleted_at` (soft delete).

**`pay_subscriptions`** tracks the full subscription lifecycle: `customer_id` (FK), `name` ("default"), `processor_id`, `processor_plan`, `quantity`, `status` (active/trialing/past_due/canceled/incomplete/paused), `trial_ends_at`, `ends_at`, `current_period_start/end`, `metered` (boolean), `pause_behavior`/`pause_starts_at`/`pause_resumes_at`, `application_fee_percent`, `metadata` (JSONB), `subscription_items` (JSONB array), and `object` (full API response).

**`pay_charges`** records individual payments: `customer_id`, `subscription_id` (nullable FK), `processor_id`, `amount` (cents), `currency`, `amount_refunded`, `amount_captured`, `statement_descriptor`, `payment_method_type`, `brand`/`last4`/`exp_month`/`exp_year`, `line_items` (JSONB), and `object`.

**`pay_webhooks`** stores raw events: `event_type` and `data` (JSONB).

**`pay_merchants`** (Connect): polymorphic owner, processor info for marketplace sellers.

**`pay_payment_methods`**: `customer_id`, `processor_id`, `default`, `payment_method_type`, `data`.

### Webhook processing architecture

Pay's webhook system is architecturally elegant:
1. Webhook received → signature verified by provider-specific controller
2. Event stored in `pay_webhooks` table (audit trail)
3. `Pay::Webhooks::ProcessJob` enqueued via ActiveJob (async processing)
4. Job dispatches via pub/sub pattern (`ActiveSupport::Notifications`)
5. **20 built-in Stripe handlers** fire, then custom handlers

Custom handlers register via: `Pay::Webhooks.delegator.subscribe "stripe.charge.succeeded", MyHandler.new`. Built-in handlers are unsubscribable. This pub/sub architecture means multiple handlers can react to the same event independently.

### Key design patterns worth emulating

- **Lazy customer creation**: Stripe Customer only created on first actual use (charge, subscribe)
- **STI for provider polymorphism**: `Pay::Stripe::Customer < Pay::Customer < ApplicationRecord`
- **Idempotent sync methods**: `Pay::Stripe::Charge.sync(charge_id)` uses `find_or_initialize_by(processor_id)` — prevents duplicates
- **`object` column pattern**: Stores full Stripe API response JSON alongside parsed fields — future-proofs against schema changes
- **Background webhook processing**: Never blocks the HTTP response; enqueues for async handling
- **FakeProcessor**: Built-in test/trial processor — enables card-less trials and testing without real API calls

### Known limitations

Pay is backend-only (no UI components), depends heavily on webhooks for Checkout-created records (confusing for newcomers), has limited invoice management, and has experienced breaking changes between major versions. Duplicate webhook events can cause double-receipt emails unless handlers are strictly idempotent.

---

## 4. Official Stripe SDKs define the API contract

### The StripeClient pattern (all SDKs, 2024+)

All official SDKs have converged on an instance-based **StripeClient** pattern, moving away from global static/module-level configuration. This is the modern API:

```ruby
# Ruby v13+
client = Stripe::StripeClient.new("sk_test_...")
customer = client.v1.customers.retrieve("cus_123")

# Node v21+
const stripe = new Stripe("sk_test_...", { apiVersion: "2026-03-25.dahlia" })
const customer = await stripe.customers.retrieve("cus_123")
```

Per-request overrides for Connect (`stripe_account`), idempotency keys, and API version are passed as options alongside parameters. This pattern is **critical for multi-tenant Elixir applications** where different requests may use different Stripe accounts.

### Auto-pagination: three approaches across SDKs

**Ruby**: `Stripe::ListObject#auto_paging_each` yields items across pages. **Node**: Three variants — `for await...of` (async iteration), `autoPagingEach(callback)`, and `autoPagingToArray({limit: N})`. **Python**: Async iteration support via `pip install stripe[async]`. All use Stripe's cursor-based pagination (`starting_after`/`ending_before`).

### Error hierarchy

All SDKs implement the same error tree under `StripeError`: **CardError** (payment failures), **InvalidRequestError** (wrong parameters), **AuthenticationError** (bad API key), **APIConnectionError** (network issues), **APIError** (Stripe-side), **RateLimitError**, **IdempotencyError**, **PermissionError**, **SignatureVerificationError**. Each error carries `type`, `code`, `message`, `param`, and `request_id`.

### Code generation from OpenAPI

All official SDKs are **partially auto-generated** from Stripe's OpenAPI spec (`stripe/openapi`, 3,479 commits, **2,196 releases** — updated almost daily). The codegen is a **custom closed-source JavaScript program** using JSX-style templates — not openapi-generator. The architecture is two-layered: the **outer layer** (models, resources, type definitions) is generated; the **inner layer** (HTTP infrastructure, utilities, error handling) is hand-maintained. The OpenAPI spec uses custom extensions (`x-expandableFields`, `x-expansionResources`, `x-resourceId`) that standard generators don't understand.

### Release cadence

Official SDKs release **multiple times per month**, tracking each OpenAPI spec update. Breaking API versions (Acacia → Basil → Clover → Dahlia, roughly semiannual) trigger new SDK major versions. The current API version is **`2026-03-25.dahlia`**. Between major versions, monthly backward-compatible updates ship under the same plant name.

---

## 5. Patterns from other billing ecosystems

### Laravel Cashier: the "beloved" standard

Laravel Cashier's appeal comes from its **zero-boilerplate, Eloquent-native API**: `$user->newSubscription('default', 'price_monthly')->trialDays(5)->create($paymentMethod)`. The `Billable` trait injects all billing methods directly onto the User model. Subscription status checks are one-liners: `$user->subscribed()`, `$user->subscription('default')->onGracePeriod()`, `$user->onTrial()`. A middleware `Subscribed::class` gates routes. An artisan command `cashier:webhook` auto-registers the webhook endpoint in Stripe. The library pins to a specific Stripe API version per major release (v16 pins to `2025-06-30.basil`).

### stripe-kit (Swift/Vapor): type safety as architecture

The Vapor community's `stripe-kit` (147 stars, v26.1.0, actively maintained 8+ years) demonstrates what thorough type safety looks like. Every Stripe object is a Swift struct with enum-based values (`.succeeded`, `.usd`). Three property wrappers handle expandable fields: `@Expandable` (single), `@DynamicExpandable` (polymorphic), `@ExpandableCollection` (arrays). Webhook events use typed payloads enabling exhaustive `switch` statements — this maps perfectly to Elixir's pattern matching. The coverage extends to virtually all Stripe APIs including Issuing, Terminal, and Identity.

### Lemon Squeezy: functional-first API design

The `@lemonsqueezy/lemonsqueezy.js` SDK uses a functional approach closest to Elixir's idiom: standalone exported functions (`getSubscription(id)`) rather than class methods, with a consistent `{data, error}` return pattern. Setup is via a global `lemonSqueezySetup({apiKey, onError})`. Functions are tree-shakeable (600B–1KB each). This maps directly to Elixir modules with `{:ok, data} | {:error, reason}` returns.

### Chargebee: enterprise resilience patterns

Chargebee's SDKs include built-in **exponential backoff**, rate limit handling (429 responses), configurable retry status codes, custom HTTP client injection, and detailed error types (`payment`, `invalid_request`, `operation_failed` with `api_error_code`). Its subscription object is extremely rich: `billing_period`/`billing_period_unit`, `current_term_start/end`, `remaining_billing_cycles`, `contract_term`, `mrr`, `exchange_rate`, `has_scheduled_changes`. This level of subscription state tracking is what enterprise users expect.

---

## 6. Stripe's complete API surface area: what must be covered

Stripe's API spans **30+ product categories** with hundreds of individual resources. The current version (`2026-03-25.dahlia`) includes significant new additions from 2024–2026 that no existing Elixir library covers. Here is the complete surface area, organized by priority tier for a billing-focused library.

### Tier 1 — Must-have (core billing + payments)

- **Payment Intents**: create, confirm, capture, cancel, search — the modern payment flow
- **Setup Intents**: save payment methods for future use
- **Payment Methods**: CRUD, attach/detach — replaces legacy Tokens/Sources
- **Customers**: CRUD, search, balance operations
- **Charges**: retrieve, list, capture, search (many operations moved to PaymentIntents)
- **Subscriptions**: create, update, cancel, resume, search, list
- **Subscription Items**: CRUD for multi-line subscriptions
- **Products & Prices**: CRUD, search — the modern catalog (replaces Plans)
- **Invoices**: CRUD, finalize, pay, void, mark uncollectible, send, upcoming preview
- **Invoice Items**: add/remove line items
- **Checkout Sessions**: create, retrieve, list, expire — hosted payment pages
- **Billing Portal**: sessions (create), configuration (CRUD) — customer self-service
- **Webhooks**: endpoint CRUD, signature verification, event retrieval
- **Coupons & Promotion Codes**: CRUD
- **Refunds**: create, retrieve, update, cancel
- **Disputes**: retrieve, update, close
- **Balance & Balance Transactions**: read
- **Events**: list, retrieve

### Tier 2 — Should-have (complete billing + Connect)

- **Subscription Schedules**: complex plan migration scenarios
- **Billing Meters** (new 2024): usage-based billing — replaces legacy Usage Records
- **Meter Events v2**: high-throughput usage reporting
- **Billing Alerts**: threshold notifications
- **Credit Grants & Credit Balance Transactions** (new Oct 2024): prepaid credits
- **Credit Notes**: issue refunds/credits against invoices
- **Tax IDs, Tax Rates, Tax Calculations, Tax Registrations, Tax Settings**: Stripe Tax
- **Quotes**: create and send price quotes
- **Connect Accounts**: CRUD, capabilities, persons, external accounts
- **Account Links & Account Sessions**: onboarding flows
- **Transfers, Transfer Reversals**: platform payments
- **Application Fees & Refunds**: marketplace fee management
- **Payouts**: trigger and manage payouts
- **Top-ups**: add funds to Stripe balance
- **Test Clocks**: subscription testing with time manipulation
- **Entitlements** (new 2024–2025): feature access gating
- **Payment Links**: no-code payment pages
- **Customer Sessions**: embedded components

### Tier 3 — Nice-to-have (specialized products)

- **Issuing**: cards, cardholders, authorizations, transactions
- **Terminal**: readers, locations, connection tokens
- **Identity**: verification sessions, verification reports
- **Treasury**: financial accounts, transactions, outbound/inbound transfers
- **Financial Connections**: bank account linking
- **Radar**: value lists, early fraud warnings, reviews
- **Climate**: carbon removal orders
- **Sigma & Reporting**: scheduled queries, report runs
- **Forwarding**: vault and forward card details
- **Capital**: financing offers
- **Payment Records** (new 2025): cross-processor payment tracking

### Critical new features existing libraries miss entirely

**Billing Meters** (2024): The new primitive for usage-based billing. Basil (2025-03-31) *requires* meters for metered prices, replacing the legacy Usage Records API. **Meter Events v2** supports 10K events per stream. **Credit Grants** (October 2024) enable prepaid credit balances. **Billing Alerts** trigger on usage/spend thresholds. **Adaptive Pricing** auto-converts prices to 150+ local currencies with a 4.7% conversion increase. **Event Destinations v2** supports cloud targets (EventBridge, Azure Event Grid). **Entitlements** provide server-side feature gating tied to subscriptions. **Payment Records** track payments across Stripe and external processors. None of these are available in any current Elixir library.

---

## 7. The critical webhook event taxonomy

A billing library must handle **~50 core webhook events** to cover the full subscription and payment lifecycle. These are organized by criticality — based on what breaks if missed.

### Events that cause revenue loss or access control failures if missed

| Event | What breaks if missed |
|---|---|
| `customer.subscription.deleted` | Users retain access after subscription ends |
| `invoice.finalization_failed` | Subscriptions stay active but no payment collected — free access indefinitely |
| `invoice.payment_failed` | No dunning/retry, silent payment failures accumulate |
| `checkout.session.completed` | Orders never fulfilled after Checkout payment |
| `customer.subscription.created` | No local record of new subscriptions |
| `customer.subscription.updated` | Plan changes, status transitions not tracked |
| `charge.dispute.created` | Disputes go unresponded within tight windows |
| `invoice.paid` | Access not granted/renewed after successful payment |
| `payment_intent.succeeded` | One-time payments not fulfilled |

### Events that degrade user experience if missed

`customer.subscription.trial_will_end` (3-day warning), `invoice.upcoming` (only chance to add usage charges), `invoice.payment_action_required` (SCA authentication needed), `payment_method.automatically_updated` (stale cached card details), `checkout.session.async_payment_succeeded/failed` (delayed payment methods like bank transfers), `charge.refunded`, `customer.updated/deleted`.

### Commonly mishandled patterns

**Out-of-order delivery**: Stripe does NOT guarantee event ordering. A subscription creation may fire `customer.subscription.created`, `invoice.created`, `charge.succeeded`, and `invoice.paid` in any order. Handlers must be order-independent. **Duplicate delivery**: Stripe may send the same event multiple times; handlers must be idempotent (store processed event IDs). **`invoice.created` timing**: For automatic-collection subscriptions, Stripe waits **1 hour** after a successful 200 response before attempting payment — and if the webhook endpoint fails, Stripe delays finalization for ALL account invoices for up to 72 hours. **`checkout.session.completed` ≠ payment confirmed**: For async payment methods (bank transfers, SEPA), the session completes before payment confirms; must wait for `checkout.session.async_payment_succeeded`.

---

## 8. Architecture decisions to make upfront

### HTTP client: Req on Finch

**Req** (v0.5.17, 11.3M+ Hex downloads) is the clear choice. José Valim and Dashbit explicitly recommend it. Andrea Leopardi (Mint co-maintainer) says "don't use HTTPoison." Req's composable step pipeline maps perfectly to Stripe's needs: authentication steps, idempotency key injection, retry logic, response decoding, and telemetry — all implemented as request/response steps. Critically, **Req.Test provides plug-based concurrent test stubs** that exercise the full HTTP path, solving the testing problem without external mock servers.

```elixir
# Conceptual Stripe client built on Req
Req.new(base_url: "https://api.stripe.com/v1")
|> Req.Request.prepend_request_steps(stripe_auth: &add_bearer_token/1)
|> Req.Request.append_request_steps(idempotency: &inject_idempotency_key/1)
|> Req.Request.append_response_steps(stripe_decode: &decode_to_struct/1)
```

### Response types: generated typed structs

The Elixir community strongly favors typed structs. Every Stripe resource should be a `defstruct` with `@type t()` typespecs for Dialyzer support. Expandable fields should use union types (`String.t() | Stripe.Customer.t()`) to represent both the ID-only and expanded states. stripe-kit's approach — typed enums for all status/currency values — translates naturally to Elixir atoms.

### Error handling: tagged tuples with structured errors

```elixir
{:ok, %Stripe.Charge{}} = Stripe.Charges.create(params)
{:error, %Stripe.ApiError{type: :card_error, code: "card_declined"}} = Stripe.Charges.create(bad_params)
%Stripe.Charge{} = Stripe.Charges.create!(params)  # bang variant raises
```

The `Stripe.ApiError` struct should carry: `type` (atom matching Stripe's hierarchy: `:card_error`, `:invalid_request_error`, `:authentication_error`, `:api_connection_error`, `:api_error`, `:rate_limit_error`, `:idempotency_error`), `code`, `message`, `param`, `http_status`, and `request_id`.

### Pagination: Stream.resource for auto-pagination

```elixir
# Single page
{:ok, %Stripe.List{data: customers, has_more: true}} = Stripe.Customers.list(limit: 100)

# Auto-paginating stream — the killer feature
Stripe.Customers.stream()
|> Stream.filter(& &1.delinquent)
|> Enum.take(10)
```

`Stream.resource/3` is the established Elixir pattern (used by ExTwilio and others). It produces a lazy enumerable that fetches pages on demand, composable with all `Stream`/`Enum` functions.

### Configuration: per-request with application config fallback

Following Elixir library guidelines (avoid `Application.get_env` as primary configuration), the library should support a client struct pattern for multi-tenancy:

```elixir
# Simple: application config fallback
Stripe.Charges.create(%{amount: 2500, currency: "usd"})

# Multi-tenant: explicit client
client = Stripe.client(api_key: "sk_test_...", stripe_account: "acct_...")
Stripe.Charges.create(client, %{amount: 2500, currency: "usd"})

# Per-request overrides
Stripe.Charges.create(%{amount: 2500}, api_key: "sk_...", idempotency_key: "abc123")
```

### Telemetry: :telemetry.span for all operations

Emit `[:stripe, :request, :start]`, `[:stripe, :request, :stop]`, and `[:stripe, :request, :exception]` events with measurements (duration, system_time) and metadata (method, path, status, stripe_request_id, resource, operation). Add `[:stripe, :webhook, :start|:stop|:exception]` for webhook processing. This follows the Phoenix/Ecto/Finch standard.

### Webhook handling: Plug + function, both provided

Provide `Stripe.Webhook.construct_event(raw_body, signature, secret)` as the low-level function, plus `Stripe.WebhookPlug` for drop-in Phoenix integration. The Plug must run **before** `Plug.Parsers` in the endpoint pipeline to access the raw body. Document the raw-body problem explicitly — this is the #1 pain point.

### Code generation: aj-foster's open-api-generator

**aj-foster/open-api-generator** (148+ stars) is the leading Elixir OpenAPI code generator, proven with the `oapi_github` package. Its philosophy — "ergonomics of hand-crafted client with API coverage of generated code" — is exactly right. It supports schema renaming/merging, configurable output, plugin-based customization, and test helper generation. No one has yet used it for Stripe's OpenAPI spec — **this is the key opportunity**. The generated outer layer (structs, operation functions) can be combined with a hand-crafted inner layer (Req client, error handling, webhook verification, pagination).

The tradeoff: Stripe's OpenAPI spec uses custom extensions (`x-expandableFields`, `x-expansionResources`) that aj-foster's generator doesn't natively understand. A custom plugin will be needed to handle expandable fields correctly. The spec is also enormous (hundreds of resources), so configuration to control output scope will be essential.

---

## 9. One library or two? The architecture of the whole project

### Recommended: two packages, built sequentially

The Ruby and PHP ecosystems both split this into two layers — and for good reason. The low-level API client and the high-level billing layer serve different users with different needs and different change cadences.

**Package 1: `stripe` — the API client** (build first)
- Generated from Stripe's OpenAPI spec via aj-foster's generator
- Typed structs for all resources, operation functions for all endpoints
- Req-based HTTP client with per-request configuration
- Stream-based auto-pagination
- Webhook signature verification (`Stripe.Webhook.construct_event/3`)
- Structured error types mirroring Stripe's hierarchy
- Telemetry integration
- No Ecto or Phoenix dependency
- **Goal**: Replace stripity_stripe as the canonical Stripe API client

**Package 2: `stripe_billing` or `stripe_phoenix` — the billing layer** (build second)
- Ecto schemas: `stripe_customers`, `stripe_subscriptions`, `stripe_charges`, `stripe_webhooks`, `stripe_payment_methods` (following Pay's schema design)
- `use Stripe.Billable` macro for Ecto schemas (like Pay's `pay_customer`)
- Subscription lifecycle: create, cancel, resume, swap, pause, trial management
- Webhook processing: Phoenix Plug with pub/sub event routing, background job dispatch (Oban integration)
- Checkout Session and Billing Portal helpers
- Pipeline-based subscription builder: `user |> Stripe.new_subscription("default", "price_xxx") |> Stripe.Subscription.trial_days(14) |> Stripe.Subscription.create()`
- Testing helpers: mock webhooks, factory functions, Stripe Test Clock support
- **Goal**: Replace Bling as the canonical Elixir billing layer

### Why two packages

The API client changes when Stripe's API changes (frequently). The billing layer changes when billing patterns evolve (slowly). Different users need different things — an API client user building a custom marketplace integration doesn't want Ecto as a dependency. A SaaS builder wants the billing layer but shouldn't need to understand Stripe's raw API. The `Pay` gem (Ruby) and `Cashier` (Laravel) both exist as separate packages from their language's Stripe API client. This is a proven architecture.

---

## 10. Prioritized feature roadmap

### Phase 1: API client foundation (Tier 1 coverage)

Build the core `stripe` package covering Tier 1 APIs (Payment Intents, Customers, Subscriptions, Products/Prices, Invoices, Checkout Sessions, Billing Portal, Webhooks, Refunds, Disputes). This alone — if well-typed, well-tested, and actively maintained — would be enough to replace stripity_stripe for most users. Target: full Stripe API version `2026-03-25.dahlia` compatibility.

- OpenAPI-generated structs and operations for all Tier 1 resources
- Req-based client with retry, idempotency, telemetry
- Stream-based auto-pagination
- Webhook signature verification
- Comprehensive error types
- Per-request config for Connect/multi-tenancy
- Req.Test-based testing support
- Hex.pm publication and documentation

### Phase 2: Complete API coverage + billing layer

Expand to Tier 2 APIs (Billing Meters, Credit Grants, Connect, Tax, Subscription Schedules, Entitlements). Begin building the billing layer package with Ecto schemas, subscription lifecycle management, and webhook processing.

### Phase 3: Ecosystem completeness

Tier 3 APIs (Issuing, Terminal, Identity, Treasury). Phoenix-specific integrations (LiveView billing components, subscription middleware). Oban-based webhook job processing. Test Clock support. Documentation at Laravel Cashier quality level.

---

## 11. Complete prior art reference list

### Elixir Stripe Libraries
| Name | URL | Hex | Status |
|---|---|---|---|
| stripity_stripe | https://github.com/beam-community/stripity-stripe | https://hex.pm/packages/stripity_stripe | Stagnant (v3.2.0, May 2024) |
| PinStripe | https://github.com/eileennoonan83/pin_stripe | https://hex.pm/packages/pin_stripe | Experimental (v0.3.4) |
| tiger_stripe | — | https://hex.pm/packages/tiger_stripe | Very new (v0.1.10) |
| paper_tiger | — | https://hex.pm/packages/paper_tiger | Mock server (v1.0.2) |
| Bling | https://github.com/ozziexsh/bling | https://hex.pm/packages/bling | Pre-1.0 (v0.5.0) |
| Bankroll | https://github.com/ozziexsh/bankroll | — | Bling UI companion |
| striped | — | https://hex.pm/packages/striped | Abandoned (v0.5.0) |
| exoapi_stripe | — | https://hex.pm/packages/exoapi_stripe | Abandoned (v0.1.4) |

### Key Documentation & Blog Posts
| Resource | URL |
|---|---|
| Dashbit "SDKs with Req: Stripe" | https://dashbit.co/blog/sdks-with-req-stripe |
| Stripe API Reference | https://stripe.com/docs/api |
| Stripe OpenAPI Spec | https://github.com/stripe/openapi |
| aj-foster OpenAPI Generator | https://github.com/aj-foster/open-api-generator |
| PinStripe ElixirForum Thread | https://elixirforum.com/t/tinyelixirstripe-a-stripe-small-development-kit-for-elixir/73714 |
| "Is Stripity Stripe Maintained?" | https://elixirforum.com/t/is-stripity-stripe-maintained/73673 |

### Other Language Libraries
| Name | URL | Language |
|---|---|---|
| Pay gem | https://github.com/pay-rails/pay | Ruby |
| stripe-ruby | https://github.com/stripe/stripe-ruby | Ruby (official) |
| stripe-node | https://github.com/stripe/stripe-node | Node.js (official) |
| stripe-python | https://github.com/stripe/stripe-python | Python (official) |
| stripe-java | https://github.com/stripe/stripe-java | Java (official) |
| Laravel Cashier | https://github.com/laravel/cashier-stripe | PHP |
| stripe-kit | https://github.com/vapor-community/stripe-kit | Swift/Vapor |

### Elixir Infrastructure Libraries
| Name | URL | Purpose |
|---|---|---|
| Req | https://github.com/wojtekmach/req | HTTP client (recommended) |
| Finch | https://github.com/sneako/finch | HTTP client (underlying) |
| :telemetry | https://github.com/beam-telemetry/telemetry | Instrumentation |
| aj-foster/open-api-generator | https://github.com/aj-foster/open-api-generator | OpenAPI codegen |
| Oban | https://github.com/sorentwo/oban | Background jobs |
| Bypass | https://github.com/PSPDFKit-labs/bypass | Test HTTP server |

---

## Conclusion: the opportunity is clear and the timing is right

The Elixir Stripe ecosystem sits at an inflection point. The incumbent library is effectively unmaintained, community frustration is vocal and specific, and no experimental replacement has reached production quality. Meanwhile, Stripe's API has expanded dramatically — Billing Meters, Credit Grants, Entitlements, v2 APIs, Adaptive Pricing — creating a widening feature gap that grows with each Stripe release.

The new library should be **OpenAPI-generated** (using aj-foster's generator against Stripe's spec) for coverage, **Req-based** for modern HTTP handling and testability, and **split into two packages** (API client + billing layer) for clean separation of concerns. The API client alone — with proper typing, auto-pagination, webhook verification, and current API version support — would immediately serve the ~233k monthly downloads that currently depend on stripity_stripe. The billing layer, modeled on Pay's database schema and Laravel Cashier's developer experience but adapted for Elixir's pipe-based, pattern-matching idiom, would fill the gap that Bling has only partially addressed.

Three decisions will determine whether this library becomes canonical: **maintaining parity with Stripe's release cadence** (the failure mode of every predecessor), **providing first-class webhook handling that solves the raw-body problem out of the box**, and **shipping with testing utilities that make Stripe integration tests as easy as writing any other Elixir test**. Every previous Elixir Stripe library failed on the first point. The new library's OpenAPI-generated architecture — where re-running codegen against a new spec version produces an updated release — is the only viable path to keeping pace with Stripe's near-daily spec updates.