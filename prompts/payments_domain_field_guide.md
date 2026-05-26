# Payments domain — field guide

> The nouns, verbs, events, flows, state machines, and gotchas. Everything a software engineer needs to build confidently on top of Stripe — oriented around concepts, not docs pages.

**Legend:** `noun` = object/resource · `verb` = operation · `event` = webhook event name · ⚠️ = known gotcha

---

## Table of contents

1. [The mental model](#1-the-mental-model)
2. [The rails — who's who behind every payment](#2-the-rails)
3. [Nouns — the core objects](#3-nouns)
4. [Verbs — operations & actions](#4-verbs)
5. [State machines](#5-state-machines)
6. [Key flows](#6-key-flows)
7. [Subscriptions — in depth](#7-subscriptions)
8. [Billing models — Price types](#8-billing-models)
9. [Webhooks — the event system](#9-webhooks)
10. [Stripe Connect — marketplace & platform payments](#10-connect)
11. [3DS / SCA — authentication](#11-3ds--sca)
12. [Money encoding — never use floats](#12-money-encoding)
13. [API versioning](#13-api-versioning)
14. [Testing](#14-testing)
15. [Gotchas — the bites](#15-gotchas)

---

## 1. The mental model

A payment is not one thing — it's a pipeline of four distinct stages, each with its own timing and participants. Most bugs come from conflating these stages.

### Authorization → Capture → Clearing → Settlement

**Authorization** — the issuing bank (customer's bank) places a *hold* on the customer's funds. No money has moved. The merchant now has a promise. Holds typically expire in 7 days (some card types allow up to 31 days for hotels/rentals). This is why a hotel can charge you for the full stay before check-in — they authorized, didn't capture yet.
> In Stripe: create a `PaymentIntent` with `capture_method: manual`. Status becomes `requires_capture`.

**Capture** — the merchant actually collects the authorized funds. Can be less than authorized (partial capture — releases the remainder). Must capture within the auth window. `PaymentIntent` transitions to `succeeded`.
> In Stripe: call `capture` on the PaymentIntent.

**Clearing** — interbank reconciliation. Card networks (Visa, MC) act as post offices, tallying up who owes whom at end of day. Money doesn't move between individual accounts — it moves in net batches.
> Happens in background. Not directly visible via Stripe APIs.

**Settlement** — money actually lands in bank accounts. Typically T+1 to T+2 from capture. For Stripe: your Stripe Balance is credited, then you *payout* to your real bank account on a rolling schedule (default T+2 in US).
> In Stripe: watch for `balance.available` and `payout.paid` events.

> **Most of the time**, Stripe handles authorization and capture in a single step (`capture_method: automatic`, the default). You only split them when you need to hold funds and confirm the final amount later — hotels, rentals, pre-orders, fraud review queues.

### The two money pots

| Pot | What it is |
|---|---|
| **Stripe Balance** | Stripe's internal ledger. When a charge succeeds, funds land here after clearing. Not your bank account. Can hold multiple currencies. You use this as a source for payouts, refunds, and future charges. |
| **Your bank account** | Where payouts go. A `Payout` is the explicit transfer from your Stripe Balance to your external bank. Stripe creates these automatically on your payout schedule (daily, weekly, monthly) or you can trigger manually. |

---

## 2. The rails

When a customer pays with a card, at least five parties are involved. Understanding this network explains why disputes work the way they do, why refunds take days, and why Stripe charges what it charges.

| Role | Who | What they do |
|---|---|---|
| **Cardholder** | The customer | Has a card issued by a bank. The money starts here. |
| **Issuing bank** | Customer's bank (Chase, Citi, Barclays) | Issues the card. Holds the funds. Approves or declines the authorization. When a customer files a dispute, their issuing bank can forcibly reverse the payment (a chargeback). |
| **Card network** | Visa, Mastercard, Amex, Discover, UnionPay | The messaging infrastructure and rule-maker between banks. Sets interchange rates. Adjudicates disputes. Not typically visible via API but present in every transaction. Amex and Discover are also issuers — they do it all themselves. |
| **Acquiring bank** | Merchant's bank — Stripe acts as yours | Accepts card payments on behalf of the merchant, takes the settlement risk. This is why you sign up with Stripe instead of getting a merchant account at your own bank. |
| **Payment processor** | Technical operator — Stripe acts as yours | Sends auth requests to the card network, handles responses, manages batch settlement files. Historically separate businesses (e.g., First Data was a processor, Wells Fargo was the acquirer). |
| **Payment gateway** | The API layer — Stripe API | The interface you interact with. Stripe uniquely combines all four roles above into one product. |

> **Stripe = gateway + processor + acquirer, all in one.** When you call `PaymentIntents.create`, Stripe talks to the card network, which talks to the issuing bank — all synchronously within ~2 seconds.

---

## 3. Nouns

### Identity & payment methods

| Object | What it is |
|---|---|
| `Customer` | The central billing entity. Holds a billing email, shipping address, default payment method, tax IDs, balance, and discount. You don't *need* a Customer to take a one-off payment, but you need one for subscriptions, saved cards, invoices, and the Billing Portal. Think of it as your user's billing profile inside Stripe. |
| `PaymentMethod` | The modern representation of how someone pays. Can be a card, bank account, wallet (Apple Pay, Google Pay), or 20+ alternative methods (SEPA, ACH, iDEAL, Klarna, Afterpay, OXXO, Boleto, BACS, BECS, Konbini, etc.). Attaches to a Customer. Replaces the legacy `Source` and `Card` objects. Has a `fingerprint` field — same underlying card number = same fingerprint, even across different tokens/methods. |
| `PaymentIntent` | The modern payment orchestration object. Represents the intent to collect a specific amount, in a specific currency, from a specific customer. Has a full state machine. Created server-side, confirmed client-side (usually). Handles 3DS, SCA, redirects, and async payment methods automatically. Replaces `Charge` for new integrations. *One PaymentIntent can result in multiple Charges on retry.* |
| `SetupIntent` | Like a PaymentIntent, but the goal is to *save* a payment method without charging anything now. The bank authenticates the card (so future off-session charges won't require SCA). Use this for free trials, billing-info collection at signup, or any "save card for later" flow. |
| `Charge` | A single attempt to debit a card. Legacy object — still created under the hood for every payment, accessible via `payment_intent.latest_charge`. Contains raw outcome: `outcome.type` (authorized, manual_review, issuer_declined, blocked, invalid), decline codes, network response codes. Don't create Charges directly in new code. |
| `Source` | Deprecated predecessor to `PaymentMethod`. Still works but new integrations should use `PaymentMethod`. You'll see it in old codebases. |
| `Token` | One-time-use opaque representation of card data. Created client-side (Stripe.js) so raw card numbers never touch your server. Superseded by PaymentMethod. Can only be used once. |

### Catalog & pricing

| Object | What it is |
|---|---|
| `Product` | What you're selling. A thing — "Pro Plan", "Widget", "API Credits". Has a name, description, images, metadata. Not tied to a specific price or billing frequency. One Product can have many Prices. |
| `Price` | How you charge for a Product. Encodes: *amount*, *currency*, *billing scheme* (per_unit, tiered), *type* (one_time or recurring), and for recurring: *interval* (day/week/month/year), *interval_count*, *usage_type* (licensed vs metered). **Immutable after creation** — can't change amount or interval. Create a new Price and archive the old one. |
| `Plan` | Legacy name for a recurring Price. Still works, still visible in old code. `Price` is the superset — it handles both one-time and recurring. Mentally treat Plan = recurring Price. |
| `Coupon` | The discount definition: `percent_off` or `amount_off`, duration (once/forever/repeating), max_redemptions, expiry. Reusable across customers. Apply to a Customer (as a Discount) or directly to a Subscription/Invoice. |
| `PromotionCode` | A human-readable code (`SAVE20`) that maps to a Coupon. What you share publicly. Coupons are the underlying discount logic; PromotionCodes are the UI-facing codes. Multiple codes can map to the same Coupon. |
| `Discount` | When a Coupon is applied to a Customer or Subscription, a Discount object is created. Records when it was applied and when it expires. |
| `TaxRate` | Manual tax rate you define (e.g., 10% CA sales tax). Applied to invoice line items. Separate from Stripe Tax (which auto-calculates). Use manual TaxRates when you manage your own tax obligations. |

### Billing lifecycle

| Object | What it is |
|---|---|
| `Subscription` | A recurring billing contract between you and a Customer. Has a *status* (see state machine), *current_period_start/end*, *trial_end*, *cancel_at_period_end*, *billing_cycle_anchor*, and a list of SubscriptionItems. Automatically creates Invoices at the start of each billing period. |
| `SubscriptionItem` | A single Price on a Subscription. One subscription can have multiple items (e.g., base plan + per-seat addon + metered API usage). Each item has its own Price and quantity. This is the right model for multi-line-item subscriptions. |
| `SubscriptionSchedule` | A plan for a subscription's future. Define *phases* — "charge $X for 3 months, then $Y forever." Used for grandfathered pricing, annual discounts, multi-phase onboarding. Don't reach for this unless you need to pre-schedule billing changes. |
| `Invoice` | A request for payment with line items. States: `draft → open → paid/void/uncollectible`. Stripe auto-creates invoices for subscriptions. Can be created manually for one-off charges. The *upcoming invoice* is a preview before finalization. |
| `InvoiceItem` | A single line on an Invoice. Created automatically by Stripe for subscription items. Can be created manually to add charges to a Customer — they'll appear on the next Invoice. Use for one-off charges that should appear on the customer's next subscription invoice (e.g., overage fees). |
| `BillingMeter` | The modern usage-based billing primitive (introduced 2024). Define a named event (e.g., `api_request`) and aggregation method. Send events via the high-throughput v2 API. Tallied at billing period end. Replaces legacy Usage Records. |
| `UsageRecord` | Legacy metered billing: manually report usage for a SubscriptionItem. Still works, but new integrations should use BillingMeters. |

### Payments infrastructure

| Object | What it is |
|---|---|
| `CheckoutSession` | Stripe's hosted payment page. Create a session server-side (with line items, mode, success/cancel URLs), redirect the customer, Stripe handles the UI. Three modes: `payment`, `setup`, `subscription`. Expires after 24 hours. Handles 40+ payment methods, built-in 3DS. |
| `PaymentLink` | A permanent, shareable URL that opens a Checkout-like page. Never expires, not tied to a specific customer. Good for simple product pages, tip jars, donations. |
| `BillingPortal.Session` | Stripe's hosted customer self-service UI. Redirect your customer here — they can update payment methods, view invoices, change plans, cancel. Completely hosted, no UI code needed. |
| `BillingPortal.Configuration` | Controls what features are available in the portal: which plans customers can switch to, whether they can cancel, which business info is shown. Can have multiple configurations for different customer segments. |
| `Refund` | A partial or full return of a payment. Created against a Charge. Returns to the original payment method. Card refunds take 5–10 business days. Cannot refund more than the original charge. Once submitted, cannot be canceled. |
| `Dispute` | A chargeback — the customer went to their bank and contested the charge. Bank forcibly reverses the funds and adds a dispute fee (~$15). You have 7–21 days to submit evidence to fight it. Even winning costs time. |
| `Balance` | Stripe's internal ledger of your funds. Has `available` (ready to payout), `pending` (not yet cleared), and `reserved` (held for disputes). Per-currency. |
| `BalanceTransaction` | Every movement in your Stripe Balance (charges, refunds, payouts, fees, adjustments) is a BalanceTransaction. The complete financial audit trail. Each charge creates: one BalanceTransaction for the gross amount, one for the Stripe fee. Net = gross − fee. |
| `Payout` | Transfer from your Stripe Balance to your external bank account. Has status: `paid`, `pending`, `in_transit`, `failed`, `canceled`. Failed payouts need manual intervention. |
| `Event` | A record of something that happened on Stripe — immutable, timestamped, typed (e.g., `invoice.paid`). Has an `id` (begins `evt_`), a `type`, a `data.object` (the resource in its new state), and optionally `data.previous_attributes`. Retrievable via API for 30 days. |
| `WebhookEndpoint` | A registered URL that receives events. Can filter by event type. Has a signing secret for verification. Stripe retries delivery on failure with exponential backoff, up to 3 days. |

### Connect (marketplace)

| Object | What it is |
|---|---|
| `Account (connected)` | A Stripe account belonging to a user of your platform. Types: Express (Stripe-managed onboarding UI), Standard (full Stripe account via OAuth), Custom (you own the entire UX). |
| `AccountLink` | Temporary, single-use URL for onboarding a Custom or Express connected account. Send the user here for identity verification, bank setup, agreements. Expires in minutes. |
| `AccountSession` | Enables embedded Stripe components (like a dashboard) directly in your platform UI without redirects. |
| `ApplicationFee` | Your platform's cut of a charge on a connected account. Automatically created when you specify `application_fee_amount`. |
| `Transfer` | Push money from your platform's Stripe Balance to a connected account. Decoupled from any specific customer payment — use in "separate charges + transfers" pattern. |

---

## 4. Verbs

| Operation | What it does |
|---|---|
| `authorize` | Place a hold on funds without capturing. `capture_method: manual` on PaymentIntent. Expires in 7 days. Call `capture` later. |
| `capture` | Collect an authorized amount. Can capture less (partial capture). Must capture within the auth window. |
| `confirm` | Submit a PaymentIntent for processing. Attaches payment method, triggers authentication if needed, submits to card network. Usually done client-side via Stripe.js, but can be done server-side for saved payment methods. |
| `cancel` | Void a PaymentIntent before capture. No charge occurs. Also cancels a subscription immediately (vs. `cancel_at_period_end`). Terminal. |
| `refund` | Return money to customer. Full or partial. Against a Charge. 5–10 business days for cards. *You absorb the Stripe processing fee — it's not returned on refunds.* |
| `expand` | Request nested objects be included in a response. Pass `expand: ["customer", "latest_invoice.payment_intent"]`. On lists, use `expand: ["data.customer"]`. Reduces round-trips. |
| `attach / detach` | Associate or remove a PaymentMethod from a Customer. Unattached PaymentMethods expire. Attached ones persist for reuse. |
| `finalize` | Lock a draft Invoice for payment. After finalization, line items are frozen and a PaymentIntent is created. ⚠️ If you return a non-200 on `invoice.created`, Stripe delays finalization across your entire account. |
| `void` | Cancel an open Invoice permanently. No charge occurs. Irreversible. |
| `mark_uncollectible` | Write off an invoice as bad debt. Stays in the record, subscription goes to `unpaid` state. |
| `pay` (invoice) | Manually trigger payment on an open Invoice. Use this to retry a failed invoice outside the normal dunning schedule, or to charge a different payment method. |
| `transfer` | Move funds from your Stripe Balance to a connected account. Used in separate charges + transfers Connect pattern. |
| `list` | Cursor-based pagination: `starting_after`, `ending_before`, `limit` (1–100). |
| `search` | Lucene-like query language. Returns `next_page` cursor (different from list cursor). Only some resources support it: customers, charges, invoices, payment intents, prices, products, subscriptions, subscription items. |
| `retrieve upcoming` (invoice) | Preview the next Invoice for a customer without creating it. Test proration, confirm plan change effects. |
| `advance` (test clock) | Move a TestClock forward in time, triggering subscription renewals, trial expirations, dunning retries. |

---

## 5. State machines

### PaymentIntent states

```
requires_payment_method
    → requires_confirmation   (payment method attached)
    → requires_action         (3DS / bank auth needed — customer must act)
    → requires_capture        (only with capture_method: manual)
    → processing              (submitted to network, awaiting response)
    → succeeded               ✓ safe to fulfill
    → canceled                ✗ terminal, no charge
```

| State | Meaning |
|---|---|
| `requires_payment_method` | Created but no payment method yet. Customer needs to enter card details. |
| `requires_confirmation` | Payment method attached, waiting for `confirm()`. |
| `requires_action` | ⚠️ Authentication required — 3DS challenge, bank redirect, etc. Do NOT mark order complete here. |
| `requires_capture` | Only with `capture_method: manual`. Authorized, waiting for your explicit `capture` call. |
| `processing` | Submitted to network. Brief for cards, can be hours/days for bank transfers. |
| `succeeded` | Captured. Funds on their way to your Stripe Balance. `payment_intent.succeeded` fires. |
| `canceled` | Terminal. Voided before capture. No funds moved. |

### Subscription states

| State | Meaning |
|---|---|
| `trialing` | In free trial. No payment yet. Payment method may or may not be on file. On trial end: charges and transitions to `active` (if paid) or `incomplete` (if no/bad payment method). |
| `active` | Paid up. All invoices current. Normal operating state. ⚠️ Also the state when `cancel_at_period_end: true` — sub stays active until period actually ends. |
| `past_due` | Payment failed. In dunning — Stripe will retry. Customer typically still has access. |
| `incomplete` | Very first invoice failed on subscription creation. Customer has 23 hours to fix payment. After that → `incomplete_expired`. |
| `incomplete_expired` | Terminal. Initial payment never completed within 23 hours. Create a new subscription if customer returns. |
| `unpaid` | Dunning exhausted, your settings say don't cancel. Invoice still open, payment failed. Can manually retry. |
| `paused` | Payment collection paused via `pause_collection`. No invoices generated. |
| `canceled` | Terminal. Subscription is done. `customer.subscription.deleted` fires. Revoke access immediately. |

### Invoice states

```
draft  →  open  →  paid
              ↓
            void
              ↓
        uncollectible
```

| State | Meaning |
|---|---|
| `draft` | Editable, not yet sent. Add InvoiceItems here. |
| `open` | Finalized, PaymentIntent created, awaiting payment. |
| `paid` | Fully paid. |
| `void` | Manually canceled. Irreversible. |
| `uncollectible` | Written off as bad debt. |

---

## 6. Key flows

### One-time payment (modern, your own UI)

1. Server creates `PaymentIntent` (amount, currency, optional customer). Gets back a `client_secret`.
   > Never expose the full PaymentIntent to the client — only the `client_secret`.
2. Client uses `stripe.confirmPayment({clientSecret, elements})` — PaymentElement handles card UI, 3DS, redirects automatically.
3. Stripe confirms with issuing bank. If 3DS needed, customer authenticates. PaymentIntent transitions to `succeeded`.
4. Stripe sends `payment_intent.succeeded` webhook to your server.
   > Don't rely on the client redirect alone — it can be closed/blocked. The webhook is your source of truth.
5. Fulfill the order. Return 200 to Stripe.

### Checkout Session (Stripe-hosted UI)

1. Server creates `CheckoutSession` with line items, mode (`payment`/`subscription`), success and cancel URLs.
2. Redirect customer to `session.url`. Stripe renders the payment form, handles 40+ payment methods, 3DS.
3. Customer completes payment. Stripe redirects to your `success_url`.
4. Stripe sends `checkout.session.completed` webhook.
   > ⚠️ For card payments: `payment_status: paid` — safe to fulfill. For async methods (SEPA, ACH, bank transfer): `payment_status: unpaid` — wait for `checkout.session.async_payment_succeeded` before fulfilling.
5. Retrieve the full session (or expand on the webhook) and fulfill based on `payment_status`, not just the event name.

### Save card for later (SetupIntent)

1. Create a `Customer` first (or use existing).
2. Server creates `SetupIntent` with `customer` and `usage: off_session`. Gets back a `client_secret`.
3. Client uses `stripe.confirmSetup({clientSecret, elements})`. Customer enters card. May involve 3DS to pre-authorize future off-session charges.
4. Stripe attaches a new `PaymentMethod` to the Customer. Webhook: `setup_intent.succeeded`.
5. Store the `payment_method.id`. Use later for server-side charges via `PaymentIntents.create({customer, payment_method, confirm: true, off_session: true})`.

---

## 7. Subscriptions

### Subscription creation paths

**Direct API**: Create Customer → attach PaymentMethod → create Subscription. First invoice created and charged immediately. If payment fails → `incomplete`.

**Via Checkout Session**: Create `CheckoutSession` with `mode: subscription`. Stripe collects payment, creates Customer, creates Subscription, fires `checkout.session.completed`. Easiest path — Stripe handles everything.

### Key subscription fields

| Field | What it controls |
|---|---|
| `billing_cycle_anchor` | Timestamp defining when billing periods start/end. Default: subscription creation time. Override to bill everyone on the 1st of the month. |
| `cancel_at_period_end` | ⚠️ Setting to `true` does NOT cancel. Schedules cancellation at period end. Status stays `active`. Actual cancellation fires `customer.subscription.deleted` at period end. Don't revoke access until then. |
| `proration_behavior` | On plan change mid-cycle: `create_prorations` (default, adds credit/charge to next invoice), `always_invoice` (invoice immediately), `none` (apply change at next renewal only). |
| `trial_end` | When trial ends. Can be a timestamp or `"now"`. On trial end, Stripe charges immediately. `customer.subscription.trial_will_end` fires 3 days before. |
| `pause_collection` | Pause payment without canceling. `keep_as_draft`, `mark_uncollectible`, or `void` for how to handle invoices during pause. |
| `payment_behavior` | On creation: `default_incomplete` (recommended), `error_if_incomplete` (fails loudly), `allow_incomplete` (don't use), `pending_if_incomplete`. |

### The dunning flow

1. Invoice payment attempt fails. `invoice.payment_failed` fires. `customer.subscription.updated` fires with `status: past_due`.
2. Stripe Smart Retries schedules retries using ML. Typically 3–5 retries over 1–4 weeks. Configurable in Dashboard.
3. Each retry fires `invoice.payment_failed` again — use these for dunning emails.
4. Retries exhausted. Based on your settings: cancel the subscription → `customer.subscription.deleted` fires; or move to `unpaid`.
5. Customer updates payment method → manually call `pay()` on the open invoice.

---

## 8. Billing models

A Price's billing behavior is determined by several orthogonal settings.

| Model | How it works |
|---|---|
| **Flat rate** (`billing_scheme: per_unit`) | Simplest. `unit_amount × quantity`. Fixed price per unit. Used for most SaaS plans: $29/seat/month. |
| **Tiered (graduated)** | Price changes as quantity crosses thresholds. Each tier applies only to units in that range. Customer pays a blended rate. E.g., first 100 units at $0.10, next 400 at $0.08. |
| **Tiered (volume)** | The tier containing the final quantity applies to *all* units. 500 units at the 200–500 tier rate means all 500 are at that price — but 501 units may drop to a cheaper tier for all 501. |
| **Package** | Sell in fixed bundles. `transform_quantity.divide_by` rounds quantity down to bundle count. E.g., 2,300 API calls → 2 packs of 1,000. |
| **Licensed** (`usage_type: licensed`) | Billed based on quantity set at subscription time. Most common. Set `quantity` on SubscriptionItem. Prorates when quantity changes mid-period. |
| **Metered** (`usage_type: metered`) | Billed based on reported usage. Tallied at period end. Aggregate options: `sum`, `last_during_period` (good for seat counts), `last_ever`, `max`. ⚠️ Must report usage before invoice finalizes. |
| **BillingMeter (2024+)** | New metered primitive. Define event names and aggregation. Send events via v2 API. Supports deduplication via `identifier`. Allows historical event ingestion. Replaces Usage Records. |

> **Real-world example**: "per-seat + metered API calls" subscription. SubscriptionItem 1 = flat rate licensed Price ($20/seat/month). SubscriptionItem 2 = metered Price ($0.001/API call). One subscription, one invoice, two line items.

---

## 9. Webhooks

### How they work

Stripe POSTs an Event JSON payload to your registered URL. You must return 200 within 30 seconds. If not, Stripe retries with exponential backoff for up to 72 hours.

### ⚠️ The raw body problem

Stripe's signature verification (HMAC-SHA256) requires the exact raw request body bytes. Most web frameworks (Phoenix/Plug, Express, Rails) parse the body before your handler runs, destroying the raw bytes. **You must cache the raw body before the framework's body parser consumes it.** This is the #1 webhook implementation pain point in Elixir.

### Signature verification

Every webhook request has a `Stripe-Signature` header containing a timestamp and HMAC-SHA256 signature.

Algorithm: `HMAC_SHA256(signing_secret, "${timestamp}.${raw_body}")`

Always verify. Always check the timestamp (within ±5 minutes) to prevent replay attacks. Use the **webhook signing secret** — different from your API key, one per endpoint.

### What Stripe guarantees (and doesn't)

| Guaranteed | NOT guaranteed |
|---|---|
| At-least-once delivery | Ordering |
| Events retrievable via API for 30 days | Exactly-once delivery |
| Retry on failure (up to 72 hours) | Events won't arrive out of order |

**Your handlers must be idempotent.** Use `event.id` as an idempotency key. Store processed event IDs in a `processed_webhook_events` table and skip events you've already handled.

### Critical event taxonomy

Events that cause **revenue loss or access control failures** if missed:

| Event | What breaks if missed |
|---|---|
| `customer.subscription.deleted` | Users retain access after subscription ends |
| `invoice.finalization_failed` | ⚠️ Subscription active but no payment ever attempted — silent free access |
| `invoice.payment_failed` | No dunning, silent payment failures accumulate |
| `checkout.session.completed` | Orders not fulfilled after Checkout |
| `customer.subscription.created` | No local record of new subscriptions |
| `customer.subscription.updated` | Plan changes, status transitions not tracked locally |
| `invoice.paid` | Access not granted/renewed after successful payment |
| `payment_intent.succeeded` | One-time payments not fulfilled |
| `charge.dispute.created` | Disputes go unresponded within tight windows |

Events that **degrade UX** if missed:

| Event | What it's for |
|---|---|
| `customer.subscription.trial_will_end` | 3-day warning — prompt to add payment method |
| `invoice.upcoming` | ⚠️ Only fires for renewal invoices, NOT the first invoice. Use for billing reminders. |
| `invoice.payment_action_required` | SCA authentication needed — notify customer |
| `checkout.session.async_payment_succeeded` | Async payment (SEPA, ACH) finally succeeded — fulfill now |
| `checkout.session.async_payment_failed` | Async payment failed — notify customer |
| `payment_method.attached` / `detached` | Update your cached card display |
| `charge.refunded` | Update your records |
| `customer.updated` / `customer.deleted` | Keep your local customer records in sync |

---

## 10. Connect

Connect enables your platform to facilitate payments between third parties.

### Connected account types

| Type | Who hosts onboarding | Who handles compliance | When to use |
|---|---|---|---|
| **Express** | Stripe (with your branding) | Stripe handles KYC/AML | Most marketplaces. Fast to ship. |
| **Standard** | Stripe (Stripe branding) | Stripe handles everything | Simplest. User gets a full Stripe account. |
| **Custom** | You (build everything) | You are liable | Maximum control. Stripe invisible to user. |

### Charge types — the most important Connect decision

| Type | How it works | Who pays Stripe fees | Best for |
|---|---|---|---|
| **Destination charges** | Charge on your platform. Automatic transfer to connected account minus your application fee. | Platform | Managed marketplaces where you control the UX. You handle refunds. |
| **Direct charges** | Charge directly on the connected account (`Stripe-Account` header). You take an application fee. | Connected account | SaaS platforms where merchants need their own transaction view and dispute management. |
| **Separate charges + transfers** | Charge on platform, then manually Transfer to one or more connected accounts. | Platform | Splits across multiple parties, delayed payouts, most flexibility. |

### The `Stripe-Account` header

For direct charges and connected account operations, pass the connected account ID as the `Stripe-Account` request header. This scopes the API call to that account. **Your library must support per-request account specification — critical for multi-tenant platforms.**

### Connect webhooks

Come in two flavors:
- **Platform webhooks** — events on your platform account
- **Account webhooks** — events on connected accounts (must register separately, or filter by `event.account` field)

Listen for `account.updated` to track connected account onboarding completion and capability status changes.

---

## 11. 3DS / SCA

**Strong Customer Authentication (SCA)** is a European regulation requiring two-factor authentication for many card payments. **3D Secure (3DS)** is the card network protocol that implements it. Even outside Europe, 3DS is increasingly common globally.

### How it surfaces in the API

When a `PaymentIntent` requires authentication, it transitions to `requires_action` with an `action` object. Action type is typically `redirect_to_url` (full page redirect to bank's authentication page) or `use_stripe_sdk` (Stripe.js handles in an iframe challenge).

### On-session vs off-session

**On-session (customer present):** Stripe.js handles automatically via `PaymentElement`. Call `stripe.confirmPayment()` — Stripe manages the 3DS flow, redirect, and return. Check the final PaymentIntent status.

**Off-session (no customer present):** Subscription renewals, server-initiated charges. If 3DS is required and you can't show UI, the payment fails. **Mitigation:** use `SetupIntent` with `usage: off_session` when saving the card — this pre-authenticates for future off-session charges. Banks may still require re-auth for large amounts.

> **3DS v2** (newer) is much smoother — many authentications are invisible ("frictionless flow") using device fingerprinting and behavioral analysis. The challenge only appears when the bank deems necessary. 3DS v1 always shows a challenge page.

---

## 12. Money encoding

**Stripe always uses integers.** Amounts represent the smallest currency unit. This eliminates floating-point arithmetic errors.

### Currency tiers

| Tier | Examples | What `amount: 100` means |
|---|---|---|
| **Two-decimal (standard)** | USD, EUR, GBP, CAD, AUD | $1.00 (100 cents) |
| **Zero-decimal** ⚠️ | JPY, KRW, BIF, CLP, GNF, MGA, PYG, RWF, UGX, VND, VUV, XAF, XOF, XPF | ¥100 (100 yen) |
| **Three-decimal** | KWD, BHD, OMR | 0.100 KWD (100 fils) |

> **Never use floats for money.** `0.1 + 0.2` in IEEE 754 = `0.30000000000000004`. Always use integers in cents. In Elixir, store as `integer` or `bigint` in PostgreSQL. Use the `Money` library (`ex_money`) for currency-aware arithmetic if you need to display amounts.

---

## 13. API versioning

### How Stripe versions its API

Every Stripe account is pinned to an API version at account creation. All API calls use that version by default. You can upgrade your account version in the Dashboard. You can override the version **per-request** via the `Stripe-Version` header — useful for testing before upgrading.

### The "plant" naming scheme (breaking changes)

Since 2024, Stripe releases breaking-change versions under plant names:
- `2024-06-20.acacia`
- `2025-01-27.basil`
- `2025-06-30.clover`
- `2026-03-25.dahlia` (current as of this writing)

Between plant releases, backward-compatible changes use date-based versions. Official SDKs pin to a specific plant name per major version.

### Webhook versioning

Webhooks are delivered in your account's pinned API version, not the version you used to make the API call. To test webhooks in a new version, update your account version or set a specific version per webhook endpoint.

### v1 vs v2 API

| | v1 | v2 |
|---|---|---|
| Base path | `/v1/...` | `/v2/...` |
| Body encoding | Form-encoded | JSON |
| Event model | Full event payload | Thin events (pointers) — must fetch full event separately |
| Currently available for | Everything | Billing Meter events, Event Destinations |

**Your library must handle both v1 and v2 in the same client.**

---

## 14. Testing

| Tool | What it's for |
|---|---|
| **Test API keys** (`sk_test_...`) | All charges simulated. No real money. Test resources isolated from live. |
| **Test card numbers** | `4242424242424242` (Visa, always succeeds), `4000000000000002` (always declined), `4000002500003155` (3DS required), `4000000000000341` (attaches fine, charge fails), `4000000000009995` (insufficient funds), `4000008260000000` (UK Visa, SCA required). Any future expiry, any CVC. |
| **Test bank accounts** | ACH: routing `110000000`, account `000123456789` (success) / `000111111116` (fails). SEPA: `AT611904300234573201`. |
| **Test Clocks** | Create a `TestClock`, attach a Customer to it, advance time via API. Triggers subscription renewals, trial expirations, dunning retries. Essential for integration testing billing flows without waiting days. |
| **stripe-mock** | Stripe's official local mock server. Stateless — can't create then retrieve. Good for unit testing response parsing. Run via Docker. |
| **paper_tiger** | Elixir community's stateful mock Stripe server. Remembers state across requests. Simulates webhooks. |
| **Req.Test** | Req's built-in test stubs. Return canned responses without hitting any server. Best for unit tests of your integration code. |
| **Stripe CLI** | `stripe listen --forward-to localhost:4000/webhooks` forwards live test events locally. `stripe trigger invoice.paid` fires synthetic events. Best for manual development and debugging. |

---

## 15. Gotchas

### 1. `invoice.finalization_failed` = silent free access

If Stripe can't finalize an invoice (bad tax config, missing required field), the subscription stays `active` but no payment is ever attempted. The customer gets your service for free indefinitely. You must handle `invoice.finalization_failed` and take action — suspend access, notify your team, fix the config.

### 2. `checkout.session.completed` ≠ paid

For asynchronous payment methods (SEPA, ACH, bank transfer, Boleto, Konbini), the session completes immediately but `payment_status: "unpaid"`. Payment arrives hours or days later via `checkout.session.async_payment_succeeded`. **Always check `payment_status` before fulfilling, not just the event type.**

### 3. Webhooks are unordered and can duplicate

Stripe delivers at least once but does NOT guarantee ordering. `invoice.paid` can arrive before `invoice.created`. Handlers must be idempotent — store processed `event.id` values in a DB table and skip events you've already processed. Use `event.data.previous_attributes` for state transitions rather than assuming the previous state.

### 4. The `invoice.created` 1-hour finalization trap

When Stripe sends `invoice.created`, it waits up to 1 hour before auto-finalizing — to let you add InvoiceItems. If your webhook endpoint returns a non-200, Stripe delays finalization for **all invoices on your account**. An unhealthy webhook endpoint compounds into account-wide billing delays.

### 5. `cancel_at_period_end: true` keeps status `active`

Setting this does not cancel the subscription. `status` stays `active`. `canceled_at` and `cancel_at` are set. Access revocation should happen when `customer.subscription.deleted` fires at period end. Don't check `cancel_at_period_end` for access control — check `status` and listen for the deletion event.

### 6. Subscription `incomplete` on creation failure

If you create a subscription and the first payment fails, the subscription enters `incomplete` state (not an exception). It stays there for 23 hours. After 23 hours without successful payment, it transitions to `incomplete_expired` (terminal). The customer must update their payment method and you must re-attempt payment manually.

### 7. Zero-decimal currencies: amount is in base units

For JPY, KRW, and ~15 others: `amount: 500` means ¥500, not ¥5.00. There are no "cents" in Japanese Yen. If you multiply by 100 like you would for USD, you'll charge 100x too much. Always check the currency before constructing an amount.

### 8. `invoice.upcoming` does not fire before the first invoice

This event only fires for *renewal* invoices, not the initial subscription invoice. Don't rely on it for provisioning or first-invoice processing. For subscription creation, use `customer.subscription.created` and `invoice.paid`.

### 9. Metered billing: report usage before finalization

Usage reports must be submitted before the invoice is finalized. Finalization is automatic (~1 hour before period end for subscription invoices). Once finalized, the billing period is locked. Late usage reports go on the *next* period.

### 10. Two different default payment method fields on Customer

- `customer.default_source` — legacy field for Token/Source objects
- `customer.invoice_settings.default_payment_method` — modern field for PaymentMethod objects

Stripe uses the modern field for subscription invoices if present, falling back to the legacy field. Setting one doesn't set the other. When updating a customer's default for subscriptions, always update `invoice_settings.default_payment_method`.

### 11. Idempotency key reuse with different parameters

If you reuse an idempotency key with *different* parameters within 24 hours, Stripe returns a 400 `IdempotencyError`. Keys are strictly tied to their original parameter set. Generate keys deterministically (hash of the request parameters, or a stable request UUID tied to your own order ID).

### 12. Pagination during concurrent mutations

If you're paginating through a list and new resources are created/deleted between pages, items can appear twice or be skipped entirely. For critical exports or reports, use a timestamp-based filter or snapshot before paginating.

### 13. Expand on list responses needs `data.*` prefix

To expand a nested field on items in a list response, use `expand: ["data.customer"]`, not `expand: ["customer"]`. The `data.` prefix is required for list item expansion. Forgetting this is a common source of unexpanded `cus_...` strings when you expected a full Customer object.

### 14. Refunds don't return the Stripe processing fee

When you refund a charge, Stripe returns the payment to the customer. But the processing fee (2.9% + 30¢ in the US) is **not returned**. Full refunds cost you the Stripe fee. Factor this into your refund policy.

### 15. Stripe's 200 OK with error body

A few older Stripe endpoints return HTTP 200 even when there's an error — the error is in the response body under an `error` key. Your HTTP client won't automatically treat these as errors. Always parse the response body and check for the `error` field, not just the HTTP status code.

---

*End of field guide. Feed this as context into any LLM session for building the Stripe library — it covers all the domain concepts, object relationships, state machines, event sequences, and known traps.*
