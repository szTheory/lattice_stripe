Here’s the Stripe mental model I wish every engineer got on day one.

Stripe is not really “a payments API.” It is a money workflow API. You create objects that represent what you want to happen, Stripe moves them through real-world payment and billing steps, and then it tells you what actually happened through updated objects and webhooks. The core pattern is: create intent → customer acts or payment system responds → Stripe updates state → your app reacts. That pattern shows up in one-time payments, saved payment methods, subscriptions, invoices, and platform payouts.  ￼

The reason Stripe can feel confusing at first is that the ecosystem mixes three layers at once:
	1.	Money objects like PaymentIntent, Invoice, Subscription, Refund.
	2.	Business objects like Customer, Product, Price.
	3.	Async truth via Event and webhook delivery.  ￼

Once you separate those layers, Stripe becomes much easier to reason about.

⸻

The 30-second mental model

Think of Stripe as five connected systems:
	•	Catalog — what you sell: Product, Price.  ￼
	•	Customers — who is buying: Customer, PaymentMethod.  ￼
	•	Payment engine — take money now or save a way to take money later: PaymentIntent, SetupIntent.  ￼
	•	Billing engine — recurring charges and invoices: Subscription, Invoice, Invoice Item, Customer Portal.  ￼
	•	Event stream — what actually happened: Event, webhooks.  ￼

If you build a SaaS app, you will live mostly in these nouns:

Customer, PaymentMethod, PaymentIntent, SetupIntent, Product, Price, Subscription, Invoice, Checkout Session, Event, Refund.  ￼

⸻

The core Stripe idea: “intent first, result later”

Modern Stripe does not want you to think “charge card.” It wants you to think:
	•	“I intend to collect this payment” → PaymentIntent
	•	“I intend to save this payment method for later” → SetupIntent  ￼

That’s a better fit for reality, because real payments are not always instant. A payment can need extra authentication, fail, stay processing for a while, or require follow-up from the customer. Stripe models that as a state machine, not as a single yes/no request.  ￼

So the first big Stripe insight is:

Don’t think “make payment.” Think “start payment workflow.”

That one idea explains a lot.

⸻

The main nouns, in plain English

Customer

A person or company you bill. This is where you hang saved payment methods, billing details, and subscription relationships. A lot of Stripe gets simpler once you create a customer early and consistently.  ￼

PaymentMethod

A reusable way to pay: card, bank account, and so on. It’s the saved instrument, not the payment itself. You usually use it with a PaymentIntent or SetupIntent.  ￼

PaymentIntent

A payment attempt in progress. It tracks the lifecycle of collecting money for one order or one checkout session. Stripe recommends one PaymentIntent per order or customer session.  ￼

SetupIntent

A “save payment details now, charge later” workflow. It looks like a payment flow, but it does not create a charge.  ￼

Charge

The actual charge record created by a successful card payment flow. In modern integrations, you usually work through PaymentIntent; the Charge still matters, but it is no longer the main entry point.  ￼

Refund

Money going back to the customer after a payment. Operationally important, conceptually simple. It hangs off the payment/charge world.  ￼

Product

What you sell. Example: “Pro plan,” “Team plan,” “Consulting hour.”  ￼

Price

How much and how often you charge for a product. Example: $29/month, $290/year, or a one-time $199. Products define the thing; prices define the commercial terms.  ￼

Subscription

An ongoing agreement to bill a customer on a schedule. It sits on top of products, prices, invoices, and payment collection.  ￼

Invoice

A bill. In Stripe Billing, subscriptions generate invoices, and invoices often generate PaymentIntents when payment is due.  ￼

Checkout Session

A hosted Stripe checkout flow. It can represent a one-time payment, subscription signup, or setup flow. Think of it as Stripe hosting the UI and much of the orchestration.  ￼

Event

A record that something happened in Stripe, like payment_intent.succeeded or invoice.paid. Events are what Stripe sends to your webhook endpoint.  ￼

⸻

The main verbs

These are the verbs you do over and over in Stripe:
	•	Create — start a workflow or create a business object.
	•	Confirm — tell Stripe to actually attempt the payment or setup.
	•	Attach — link a payment method to a customer.
	•	Capture — finalize an authorized payment if using manual capture.
	•	Cancel — stop a workflow.
	•	Finalize — turn a draft invoice into a real one.
	•	Pay — collect payment for an invoice.
	•	Refund — send money back.
	•	Expand — ask Stripe to include related objects inline in a response.
	•	Listen — receive webhooks when state changes.  ￼

A nice Stripe integration mostly comes down to understanding when to use those verbs, and on which object.

⸻

The main events you will actually care about in a SaaS app

For a typical SaaS app, these event families matter most:
	•	payment_intent.*
	•	checkout.session.*
	•	invoice.*
	•	customer.subscription.*
	•	sometimes charge.* and refund.*  ￼

You do not need to memorize every event type. You do want to know this rule:

Your app should usually treat webhooks as the source of truth for important state changes.

That’s especially true for successful payments, subscription activation, failed renewals, refunds, and anything asynchronous. Stripe explicitly recommends webhooks for payment events that happen outside the immediate request flow.  ￼

⸻

The four main flows every SaaS engineer should understand

Flow 1: take a one-time payment

This is the modern custom-payments flow.

Your app
  -> create PaymentIntent
  -> collect payment details
  -> confirm PaymentIntent
  -> Stripe may require extra customer action
  -> PaymentIntent succeeds or fails
  -> webhook confirms final outcome

A PaymentIntent tracks the lifecycle of the payment from creation through checkout, including extra authentication if needed. Stripe recommends creating one per order or session.  ￼

What to remember:
	•	PaymentIntent is the workflow object
	•	the final money movement becomes a Charge
	•	success is often best handled through payment_intent.succeeded
	•	failure can be immediate or asynchronous depending on method and flow  ￼

The intuitive way to think about it:

A PaymentIntent is your order’s payment brain.

It knows the amount, currency, customer, allowed payment methods, and where the payment is in its journey.

Why Stripe chose this model

Because payments are messy in the real world. Some succeed instantly, some need extra authentication, some take time, some fail after initial optimism. PaymentIntent keeps all of that inside one durable object.  ￼

⸻

Flow 2: save a payment method for later

This is the “put a card on file” flow.

Your app
  -> create SetupIntent
  -> collect payment details
  -> confirm SetupIntent
  -> Stripe may require authentication
  -> payment method is now reusable later

A SetupIntent is similar to a payment flow, but it creates no charge. Its purpose is to safely prepare a payment method for future payments.  ￼

When this matters in SaaS:
	•	free trial now, charge later
	•	add/update billing method in account settings
	•	prepare an off-session billing method before the first invoice
	•	save a card during signup without charging immediately  ￼

The intuition:

A SetupIntent is a payment rehearsal with no money movement.

⸻

Flow 3: start a subscription

This is the flow most SaaS apps care about most.

Product + Price
   ↓
Subscription created for Customer
   ↓
Stripe creates Invoice
   ↓
Stripe creates PaymentIntent for that invoice when payment is due
   ↓
customer pays successfully
   ↓
subscription becomes active
   ↓
future billing cycles repeat through invoices

Stripe’s docs are very clear here: when you create a subscription, Stripe automatically creates an invoice, and when payment is due Stripe generates a PaymentIntent for that invoice. During the first payment window, the subscription can be incomplete while payment is still being resolved.  ￼

This is the second big Stripe insight:

Subscriptions are not direct charges. Subscriptions generate invoices, and invoices are what get paid.

That one sentence clears up a huge amount of confusion.

The subscription stack, in order
	•	Product = what plan exists
	•	Price = what it costs and how often
	•	Customer = who is subscribing
	•	Subscription = the recurring agreement
	•	Invoice = the bill for a cycle
	•	PaymentIntent = how a given invoice gets paid  ￼

For SaaS, that stack is the heart of the billing model.

The events you usually care about
	•	customer.subscription.created
	•	customer.subscription.updated
	•	invoice.paid
	•	invoice.payment_failed
	•	trial-ending and status-change events  ￼

A helpful mental shortcut:

Subscription = agreement. Invoice = bill. PaymentIntent = attempt to collect the bill.

⸻

Flow 4: let Stripe host the payment page with Checkout

If you want less UI work and fewer payment-edge-case headaches, Stripe Checkout is the hosted route.

Your app
  -> create Checkout Session
  -> redirect customer to Stripe-hosted page
  -> Stripe collects payment / setup / subscription signup
  -> customer returns to your app
  -> webhook confirms completion

A Checkout Session represents the customer’s session while they pay for one-time purchases or subscriptions through Checkout or Payment Links. Stripe recommends a new session each time the customer attempts to pay.  ￼

Checkout can run in different modes, including one-time payment, subscription, and setup-for-later.  ￼

The intuition:

Checkout is Stripe saying, “We’ll host the tricky page and orchestrate the flow for you.”

For many SaaS teams, especially early on, this is the fastest path to production.

⸻

The object relationships that matter most

Here is the compact map:

Customer
  ├─ has PaymentMethods
  ├─ has Subscriptions
  ├─ receives Invoices
  └─ can pay via PaymentIntents

Product
  └─ has Prices

Subscription
  ├─ belongs to Customer
  ├─ points to Price(s)
  └─ generates Invoices

Invoice
  └─ may generate a PaymentIntent

PaymentIntent
  └─ may produce a Charge

Stripe
  └─ emits Events about all of the above

That diagram is the Stripe ecosystem, at least for a SaaS app.

⸻

The happy-path recipe for a SaaS app

If I were explaining Stripe to a SaaS engineer in one practical sequence, I’d say:

Option A: easiest path

Use:
	•	Customer
	•	Product
	•	Price
	•	Checkout Session
	•	webhooks for checkout.session.completed, invoice.paid, invoice.payment_failed, customer.subscription.*  ￼

This gets you:
	•	signup
	•	payment collection
	•	recurring billing
	•	subscription renewals
	•	event-driven state changes

with less custom payment UI.

Option B: more custom control

Use:
	•	Customer
	•	PaymentMethod
	•	PaymentIntent
	•	SetupIntent
	•	Subscription
	•	Invoice
	•	webhooks  ￼

This gives you more control, but more responsibility.

⸻

The biggest conceptual traps, explained simply

Trap 1: thinking Stripe is synchronous

It often isn’t.

You make an API call, but the final truth may arrive later through a webhook. Payment flows, subscription renewals, disputes, and many billing events are asynchronous by design.  ￼

Trap 2: thinking a subscription directly charges a card

Not quite.

A subscription creates invoices. Invoices are what get paid. Payment collection for those invoices is tracked by PaymentIntents.  ￼

Trap 3: mixing up “save payment method” with “take payment”

SetupIntent saves for later. PaymentIntent collects now.  ￼

Trap 4: treating the immediate API response as final truth

For important business state, prefer the webhook-confirmed outcome. Stripe explicitly documents webhook handling for payment events and subscription lifecycle changes.  ￼

Trap 5: not creating a Customer early enough

You can do some flows without one, but SaaS apps almost always end up wanting a durable customer record for saved methods, subscriptions, invoices, and admin operations. That’s where the ecosystem naturally converges.  ￼

⸻

Webhooks: the “real world happened” channel

Stripe sends webhook events to your HTTPS endpoint when things happen in your account. The payload is JSON and includes an Event object.  ￼

This matters because many Stripe workflows finish outside the request that started them:
	•	customer finishes hosted checkout
	•	bank-based payment settles later
	•	subscription renews overnight
	•	invoice payment fails
	•	refund completes
	•	dispute opens  ￼

The right mindset for webhooks

Think of them as durable notifications that your local app state should catch up to reality.

The important safety rule

Signature verification must use the raw request body. If middleware changes the body before verification, it can fail. Stripe calls this out explicitly.  ￼

The calm, boring webhook pattern
	1.	verify signature
	2.	parse event
	3.	record event ID for idempotency
	4.	update your app state
	5.	return 2xx quickly  ￼

That pattern will save you pain.

⸻

Products and Prices: Stripe’s catalog language

A lot of SaaS confusion disappears once you internalize this:
	•	Product = the thing
	•	Price = the terms  ￼

Examples:
	•	Product: “Pro plan”
	•	Price: $29/month
	•	Price: $290/year
	•	Product: “SMS credits”
	•	Price: $10 one-time
	•	Product: “Support retainer”
	•	Price: custom recurring amount or invoice-driven amount depending on setup  ￼

This model is elegant because the same catalog can feed Checkout, invoices, quotes, subscriptions, and more.  ￼

⸻

Expand: why Stripe responses sometimes look oddly shallow

Stripe often returns IDs for related objects instead of full nested objects. That keeps responses smaller and more stable. If you want the full related object inline, you use expand.  ￼

Example idea:
	•	response gives you customer: "cus_123"
	•	with expand, response can include the whole customer object instead  ￼

The intuition:

By default Stripe gives you references. expand asks for details.

That’s an important part of the API’s domain language.

⸻

API v1 and v2: why you may hear about both

Stripe now has two API namespaces:
	•	/v1 contains most of the existing API
	•	/v2 contains endpoints using newer design patterns  ￼

Two practical differences matter:

In v1, expand is common

That’s the classic linked-object expansion model.  ￼

In v2, include can matter

Some response properties come back as null by default in v2 unless you explicitly ask for them with include. Stripe says this depends on the endpoint, not just the object type.  ￼

The intuition:

expand means “replace this reference with the full object.”
include means “please populate these omitted fields.”

That distinction is worth remembering.

⸻

Idempotency: how Stripe helps you avoid double actions

Stripe supports idempotency so you can safely retry create/update-style requests without accidentally doing the same mutation twice. For API v1, this is used on POST requests; API v2 extends idempotent behavior to POST and DELETE. Stripe recommends using idempotency keys on writes, especially when a network failure makes the outcome uncertain.  ￼

This matters in human terms because of one common fear:

“What if my server timed out after creating the payment, and I accidentally create it again?”

Idempotency is Stripe’s answer to that.

For a SaaS app, it is especially important when creating:
	•	customers
	•	payment intents
	•	setup intents
	•	subscriptions
	•	refunds  ￼

⸻

Invoicing: the missing mental model for SaaS engineers

Many engineers understand payments but not invoices. Stripe Billing makes more sense once you see the invoice as the center of the recurring-money universe.

An invoice is the itemized bill. It can be created manually or generated from subscriptions. Stripe can send it to the customer or automatically charge a saved payment method. Subscription invoices are finalized and collected as part of the billing cycle flow.  ￼

A helpful way to remember it:

Subscriptions decide that money is owed. Invoices express exactly what is owed. PaymentIntents try to collect it.

That is the recurring billing triangle.

⸻

What Connect is, in one clear paragraph

If regular Stripe is “my business takes money,” then Connect is “my platform helps other businesses take money.” It’s Stripe’s platform/multi-account layer. When making API calls on behalf of connected accounts, Stripe supports account scoping through headers like Stripe-Account, and newer patterns use Stripe-Context, which Stripe says supersedes Stripe-Account for related-account context.  ￼

For a normal SaaS app, you can mostly ignore Connect.

For a marketplace, creator platform, vertical SaaS with sub-merchants, or platform that routes money to other businesses, Connect becomes central.

⸻

The Stripe release/versioning story, in plain English

Stripe’s versioning matters because response shapes and behavior can evolve over time. Stripe now says monthly releases are backward-compatible, while named releases introduce breaking changes. Webhook endpoints can also have their own API version behavior, and Stripe documents a careful upgrade path for webhook versioning.  ￼

The calm takeaway:

Stripe is stable, but version-aware.

If you are building a library, versioning deserves first-class design attention. If you are just building an app, it deserves respect, not fear.

⸻

The domain language reference

Here is the short glossary I’d keep in my head.

Nouns
	•	Customer — who you bill.
	•	PaymentMethod — how they can pay.
	•	PaymentIntent — a payment workflow happening now.  ￼
	•	SetupIntent — a save-for-later workflow.  ￼
	•	Charge — the actual successful charge record.  ￼
	•	Refund — money returned.  ￼
	•	Product — what you sell.  ￼
	•	Price — how much / how often.  ￼
	•	Subscription — recurring agreement.  ￼
	•	Invoice — bill owed.  ￼
	•	Checkout Session — hosted checkout workflow.  ￼
	•	Event — record that something happened.  ￼

Verbs
	•	create — begin it
	•	confirm — attempt it
	•	attach — link it
	•	capture — finalize the money movement
	•	finalize — lock the invoice
	•	pay — collect the invoice
	•	refund — reverse the money
	•	expand — inline related objects
	•	listen — react to webhooks  ￼

Events
	•	payment succeeded
	•	payment failed
	•	checkout completed
	•	invoice paid
	•	invoice payment failed
	•	subscription changed  ￼

⸻

The “if you remember only seven things” list
	1.	A PaymentIntent is the main modern payment workflow object. Stripe recommends one per order or session.  ￼
	2.	A SetupIntent saves payment details for later without charging now.  ￼
	3.	A subscription does not directly charge a card; it creates invoices, and invoices trigger payment collection.  ￼
	4.	Products are what you sell; Prices are the commercial terms.  ￼
	5.	Checkout is Stripe-hosted orchestration and is often the easiest SaaS starting point.  ￼
	6.	Webhooks are essential because many important Stripe outcomes are asynchronous.  ￼
	7.	Idempotency protects you from accidental duplicate writes when retries happen.  ￼

⸻

The best intuitive starting architecture for a SaaS app

If you want the cleanest Stripe mental model for a SaaS product, this is it:

App user signs up
   ↓
Create Customer
   ↓
Choose Product + Price
   ↓
Use Checkout Session for subscription
   ↓
Listen to webhook events
   ↓
Grant or revoke app access based on subscription/invoice state

That architecture lines up well with Stripe’s own billing and checkout model, and it keeps your app logic tied to durable billing state instead of optimistic frontend outcomes.  ￼

⸻

Final calm summary

Stripe feels big because it covers a lot of business reality. But for a SaaS app, the ecosystem becomes very readable once you see it as:
	•	Customer — who
	•	Product / Price — what and how much
	•	PaymentIntent / SetupIntent — take money now or prepare to take it later
	•	Subscription / Invoice — recurring billing
	•	Checkout Session — hosted orchestration
	•	Event / webhook — what actually happened  ￼

Once those six ideas click, Stripe stops feeling like a jungle and starts feeling like a clean, consistent language.

I can turn this into a second companion piece next: “Stripe for SaaS, by example” with 6 end-to-end flows and concrete object-by-object walkthroughs.