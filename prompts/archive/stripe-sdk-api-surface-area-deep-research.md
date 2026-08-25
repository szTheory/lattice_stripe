Here’s the map I’d feed an implementation LLM.

The big picture: Stripe is no longer “just charges and customers.” A serious Elixir SDK now has to span a unified REST API with both /v1 and /v2 namespaces, monthly API releases, twice-yearly breaking releases, event/webhook delivery in both snapshot and thin-event forms, and a huge surface area that ranges from payments and billing to Connect, Treasury, Identity, Financial Connections, Tax, Terminal, Issuing, and more. Stripe’s own OpenAPI repo now publishes specs for both v1 and v2 in /latest/, plus preview specs, while the legacy /openapi/ tree remains v1-only. Stripe’s SDK support policy also changed: new API versions ship monthly without breaking changes, with named major releases carrying the breaking changes.  ￼

Also, in Elixir land, the de facto existing library is stripity_stripe, and even its README explicitly frames the modern default as “intent based” payments, with token-based flows as legacy and not the way forward for new development. That is a strong signal for your prioritization and migration story.  ￼

1. Foundation jobs: what the SDK itself must do before any product-specific API wrappers
	1.	HTTP transport and request signing
Support authenticated requests to https://api.stripe.com, test vs live mode, form-encoded v1 requests, JSON/v2 semantics where needed, and per-request overrides for headers and auth context. Stripe’s API is REST, single-object-per-request, and uses headers heavily for auth, versioning, idempotency, Connect, and context.  ￼
	2.	Client configuration
You need a first-class client struct/config for:
	•	secret/restricted/org API keys
	•	base URL / host override
	•	timeouts
	•	proxy / custom adapter
	•	telemetry toggle
	•	retry policy
	•	API version override
	•	preview/beta version strings
	•	app/plugin identification
Stripe’s official SDKs expose these sorts of knobs directly, including timeout, retries, proxy agent, telemetry, API version, and app info.  ￼
	3.	Per-request options
Every request should accept overrides like:
	•	idempotency_key
	•	stripe_account
	•	stripe_context
	•	api_key
	•	stripe_version
	•	timeout
	•	max_network_retries
	•	expand
	•	include for v2
Stripe’s official libraries expose per-request request options for idempotency, Connect, retries, timeouts, and account-scoped requests; /v2 also introduces include-dependent response fields.  ￼
	4.	Typed error model
Model:
	•	auth errors
	•	permission errors
	•	card/payment failures
	•	validation errors
	•	rate limits
	•	conflicts/idempotency conflicts
	•	server errors
	•	external dependency failures
Stripe documents standard HTTP semantics including 400, 401, 402, 403, 409, 424, 429, and 5xx.  ￼
	5.	Retries and idempotency
This is one of the most important cross-cutting jobs. Your library should:
	•	auto-generate idempotency keys when retrying POSTs
	•	respect Stripe-Should-Retry
	•	support exponential backoff
	•	expose replay headers / request IDs
	•	document the “500 is indeterminate” gotcha
	•	distinguish v1 and v2 idempotency behavior
Stripe explicitly recommends idempotency on mutations, documents Stripe-Should-Retry, and notes that API v1 and v2 differ: v1 replays POSTs within about 24 hours, while v2 supports POST and DELETE and uses a 30-day replay window scoped more precisely.  ￼
	6.	Pagination + auto-pagination
Implement:
	•	cursor pagination for list endpoints (starting_after, ending_before, limit)
	•	search pagination (page, next_page) for search endpoints
	•	lazy streams / enumerables in Elixir
	•	manual and automatic pagination helpers
Stripe has separate list pagination and search pagination models, and official SDKs expose auto-pagination helpers.  ￼
	7.	Expandable objects and polymorphic fields
Stripe’s v1 response model relies heavily on expandable IDs; many fields are id | object. Your Elixir types and decoding story need to handle:
	•	raw ID only
	•	expanded object
	•	nested expansion
	•	expansion depth limits
	•	list expansions starting with data.*
This is a real pain point in strongly or semi-typed clients.  ￼
	8.	API v2 include support
Stripe v2 introduces include-dependent fields that default to null unless explicitly requested. This is a whole new response-shaping surface distinct from expand. Your library should treat include as first-class, not as an afterthought.  ￼
	9.	Observability and raw response access
Expose:
	•	request ID
	•	status code
	•	headers
	•	elapsed time
	•	emitted request/response events / telemetry hooks
Stripe’s official SDKs expose response metadata and request/response hooks.  ￼
	10.	Webhook verification utilities
First-class support for:
	•	raw body verification
	•	signature parsing
	•	tolerance windows
	•	test header generation
	•	snapshot vs thin-event handling
Stripe is explicit that webhook verification requires the exact raw request body, not parsed JSON.  ￼
	11.	Testing strategy
You want support/docs for:
	•	Stripe CLI local workflows
	•	webhook replay/testing
	•	stripe-mock
	•	fixtures
	•	sandbox/test mode
	•	billing test clocks
Stripe ships both Stripe CLI and stripe-mock, and Billing has test clocks as a major testing primitive.  ￼
	12.	Codegen pipeline
For breadth, you almost certainly want OpenAPI-assisted generation with handwritten layers for ergonomics. Stripe’s repo explicitly says the SDK spec variant contains annotations and deprecated/pre-release details meant for generating libraries.  ￼

⸻

2. Versioning / migration jobs: this is a top-level concern, not an appendix
	1.	Pinned Stripe API version support
Decide whether your SDK is:
	•	pinned to one Stripe API version per library release
	•	configurable per client / per request
	•	multi-version aware in generated types
Stripe’s official typed SDKs align with the API version current at the SDK release, and older/newer versions typically imply upgrading/downgrading SDK versions.  ￼
	2.	Legacy v1 + modern v2 coexistence
Support both namespaces cleanly:
	•	client.v1.*
	•	client.v2.*
	•	different request encodings and semantics
	•	different idempotency semantics
	•	expand vs include
	•	v1 snapshot events vs v2 thin events
Stripe’s public API and OpenAPI now straddle both namespaces.  ￼
	3.	Preview / beta support
Stripe’s preview features may require special version headers and can change faster than GA. Your library should have an escape hatch for preview headers and unknown params/fields. Official SDK docs explicitly discuss preview SDKs and feature-version header strings.  ￼
	4.	Legacy migration story
Support/document migration from:
	•	Charges/token flows → PaymentIntents/SetupIntents/PaymentMethods
	•	old usage records → new Meters/Meter Events
	•	snapshot events → thin events
	•	old Connect OAuth-heavy flows → newer onboarding/context patterns where appropriate
Stripe’s docs and ecosystem show these migration vectors plainly.  ￼

⸻

3. Core “jobs to be done” / product surfaces you’ll probably want to support

A. Payments core

This is the center of gravity.
	1.	Collect a one-time payment
Primary surface:
	•	PaymentIntents
	•	PaymentMethods
	•	Customers
	•	optional Charges for read/legacy compatibility
Stripe recommends one PaymentIntent per order/session. PaymentMethods are the canonical stored instrument abstraction. Charges still matter for read-side compatibility, reconciliation, refunds, disputes, and older integrations.  ￼
	2.	Save a payment method for later
Primary surface:
	•	SetupIntents
	•	PaymentMethods attach/detach/list
	•	Customers
	•	Mandates for debit/autopay scenarios
SetupIntents are the modern save-now-pay-later primitive.  ￼
	3.	Handle multi-step payment state machines
Your library should feel natural for:
	•	create / confirm / capture / cancel PaymentIntent
	•	incremental authorization
	•	microdeposit verification
	•	next-action flows
	•	off-session charges
Stripe’s PaymentIntent surface is big and very stateful.  ￼
	4.	Legacy payment compatibility
Even if you don’t optimize for it, you likely need at least read/operate compatibility for:
	•	Charges
	•	Tokens / Sources if still present in legacy integrations
	•	refunding old charges
	•	charge reconciliation
Existing Elixir usage and older Stripe users still have legacy surfaces hanging around.  ￼
	5.	Refunds and payment reversals
Core endpoints:
	•	Refunds
	•	charge/payment_intent association
	•	partial refunds
	•	multiple partial refunds
Refunds are a must-have first-tier surface.  ￼
	6.	Disputes / post-payment exceptions
Even if not day-one, plan for:
	•	disputes retrieval/list/update/submit evidence
	•	event handling around disputes
	•	balance impacts and reconciliation
Stripe’s event catalog and payments model make post-authorization resolution a core operational surface.  ￼
	7.	Checkout-hosted payment flows
Surface:
	•	Checkout Sessions
	•	session creation variants for payment/setup/subscription
	•	embedded/custom/hosted modes
	•	line items
	•	customer creation behavior
Checkout is a major integration path and deserves first-class ergonomic support.  ￼
	8.	Payment Links
This is adjacent to Checkout and worth supporting because it is operationally important and lower-effort if generated from OpenAPI.  ￼

B. Customer and payment-instrument management
	1.	Customer lifecycle
	•	create/update/retrieve/delete/search customers
	•	metadata
	•	saved payment methods
	•	billing/contact data
Customers are foundational across payments and billing.  ￼
	2.	Payment method vaulting
	•	create/retrieve/update/list payment methods
	•	attach/detach
	•	customer-scoped listing
	•	future-use optimization
This is the backbone of subscriptions and off-session billing.  ￼
	3.	Mandates / consent records
Especially important for bank debits and future usage.  ￼

C. Billing / subscriptions / invoicing

This is the second giant pillar.
	1.	Recurring subscriptions
	•	create/update/cancel/resume/pause/list/search subscriptions
	•	item-level changes
	•	payment behavior
	•	proration
	•	automatic tax hooks
	•	status transitions
Stripe’s subscription creation behavior is nuanced, especially around first invoice payment and payment_behavior.  ￼
	2.	Products and Prices
These are the commercial catalog model for Billing. Any serious SDK needs full support here because nearly everything recurring depends on them.  ￼
	3.	Subscription schedules
Important for future starts, phased upgrades/downgrades, backdating, and lifecycle orchestration.  ￼
	4.	Invoices
	•	create draft invoices
	•	finalize
	•	pay
	•	send
	•	list/retrieve/search as available
	•	invoice line items
	•	hosted invoice/payment flows
Invoices are generated one-off or periodically from subscriptions, and draft/finalize/pay/send is a distinct workflow.  ￼
	5.	Invoice items
A separate surface with its own lifecycle and gotchas around pre-billing vs attached-to-invoice behavior.  ￼
	6.	Discounting
	•	Coupons
	•	Promotion Codes
	•	Discounts on subscriptions / invoices / checkout / quotes
Coupons do not apply to plain one-off charges or PaymentIntents, which is an important modeling gotcha.  ￼
	7.	Customer portal
	•	portal configurations
	•	portal sessions
	•	deep-linked flows
This is a hosted billing-management surface many apps depend on.  ￼
	8.	Quotes and sales-flow billing surfaces
Quotes tend to matter in B2B and should be in the generated surface even if not part of the hand-tuned MVP. Coupons explicitly reference them too.  ￼
	9.	Credit notes / credits / customer balance
For finance-heavy Billing users, support:
	•	credit notes
	•	customer balance transactions
	•	credits / grants where applicable
Credit notes are core invoice adjustment primitives.  ￼
	10.	Usage-based billing
Modern usage billing now centers on:

	•	Meters
	•	Meter Events
	•	Meter Event Summaries
	•	catalog attachment to prices
	•	eventual consistency handling
	•	throughput/rate-limit guidance
Stripe’s newer metering model is an important migration target away from older usage-record styles.  ￼

	11.	Billing test clocks
This should at least be supported in API coverage because it materially changes how users test recurring logic.  ￼

D. Search / retrieval / reporting-friendly operations
	1.	Search endpoints
Stripe has search endpoints for some resources and they use a different pagination model from list endpoints. They are not guaranteed strongly consistent for read-after-write flows, and some regional limitations exist. Your library should make that obvious.  ￼
	2.	Metadata-heavy reconciliation
Metadata is a major integration primitive for correlating Stripe objects with app records and for surviving 500/reconciliation/webhook scenarios. It should have ergonomic helpers and strong documentation warnings about not storing sensitive data.  ￼

E. Connect / platforms / multi-account operations

This is a major top-tier surface.
	1.	Acting on behalf of connected accounts
Core support:
	•	Stripe-Account per request
	•	connected-account-scoped list/create/update/delete
	•	account links / onboarding
	•	account retrieval/update
This must be a first-class option in every request path, not bolted on later.  ￼
	2.	Connect account lifecycle
Support the account resources and onboarding primitives for Express/Custom/Standard-style platform flows.  ￼
	3.	Application fees / transfers / payouts
Marketplace/platform flows need:
	•	transfers
	•	payouts
	•	application fees
	•	balance transactions
	•	fee/refund/reversal reconciliation
Stripe explicitly distinguishes transfers from payouts after the historical split.  ￼
	4.	OAuth compatibility
Even if Stripe steers new integrations elsewhere, OAuth still matters for existing Connect users and migration support.  ￼
	5.	Org / context-aware access
Newer account models can require Stripe-Context; organization API keys require it, and org keys also require explicit Stripe-Version. This is an easy place for SDKs to fail in subtle ways.  ￼

F. Events / webhooks / async integration
	1.	Snapshot events
Traditional /v1 event payloads contain full object snapshots and include the event’s api_version. Event data remains frozen as rendered at creation time. That creates version-skew concerns when deserializing.  ￼
	2.	Thin events
Stripe’s newer event model delivers smaller, unversioned payloads and expects you to fetch the current event/object state. Your SDK should explicitly support this pattern and not assume webhook payloads are self-sufficient.  ￼
	3.	Webhook operational helpers
	•	signature verification
	•	raw body handling
	•	endpoint secret helpers
	•	parsing event type
	•	safe acknowledgment guidance
	•	local CLI workflows
Stripe recommends quick 2xx responses before long-running work.  ￼
	4.	Event-type coverage
Don’t just support “generic event.” Generate type constants/helpers for common payment, billing, dispute, Connect, Identity, Financial Connections, Treasury, Issuing, etc. Stripe’s event catalogs are large and evolving.  ￼

G. Payouts, balances, and money movement
	1.	Balance and balance transactions
These are key to finance and reconciliation tooling.  ￼
	2.	Payouts
Distinct from transfers; required for external disbursement workflows.  ￼
	3.	Transfers
Connect-centric inter-account fund movement.  ￼

H. Tax

Stripe Tax is important enough to be a major family, not a niche extra.
	1.	Tax calculations
Custom flow tax calculation is a standalone API family.  ￼
	2.	Tax registrations / transactions / settings
If you want credible breadth, cover the full generated tax family, not just calculations. The API reference groups these under Tax.  ￼
	3.	Billing/payment tax integration points
Automatic tax also appears on subscriptions and invoices, so your types must compose tax concerns into Billing resources.  ￼

I. Identity

Useful for marketplaces, fintech, and KYC-lite flows.
	1.	Verification sessions
	•	create/update/retrieve/list/cancel/redact
	•	client secret / hosted URL flow
	•	document + selfie configuration
	•	re-submission flow when requires_input
	•	sensitive-secret handling
Identity’s client secret is explicitly short-lived and security-sensitive.  ￼

J. Financial Connections

Useful for ACH, account linking, bank data, and ownership/balance/transaction reads.
	1.	Link bank accounts via sessions
	•	create session
	•	pass permissions
	•	launch with Stripe.js client secret
	•	retrieve accounts / balances / ownership / transactions depending on permission scope
The session API is permission-driven and app users often get tripped up on scope design.  ￼

K. Treasury

Big, specialized, but part of the real Stripe platform surface.
	1.	Financial accounts
Core Treasury primitive.  ￼
	2.	Treasury transactions / entries / money movement
If you claim full breadth, include the Treasury family in generated coverage even if ergonomics come later.  ￼

L. Issuing

If you want platform breadth, issuing is a major family.
	1.	Cards / authorizations / disputes / transactions
Also note webhook behavior for certain authorization flows can be latency-sensitive. Stripe explicitly calls out special webhook behavior around issuing_authorization.request.  ￼

M. Terminal

In-person payments.
	1.	Readers / locations / connection tokens / hardware-assisted collection
Even if your Elixir audience is smaller here, the API family matters for “complete Stripe SDK” positioning.  ￼

N. Entitlements / feature provisioning

Useful for SaaS app license provisioning tied to subscriptions. This is a newer-ish family worth generated support if you’re aiming broad platform coverage.  ￼

O. Capital / financing

Not every user needs it, but it appears in event catalogs and broader Stripe product coverage. Good candidate for generated-but-not-handcrafted support.  ￼

⸻

4. API-surface design jobs: how the Elixir API should feel
	1.	Namespace design
You’ll likely want something like:
	•	Stripe.V1.PaymentIntents
	•	Stripe.V1.Customers
	•	Stripe.V1.Subscriptions
	•	Stripe.V2.Core.Events
	•	Stripe.Webhooks
	•	Stripe.RequestOptions
	•	Stripe.Error
	•	Stripe.Stream
Reason: Stripe itself now has two namespaces with differing semantics.  ￼
	2.	Generated resource modules + handwritten ergonomics
Good pattern:
	•	generated modules for coverage
	•	handwritten facades for high-volume flows like PaymentIntents, Checkout, Customers, Billing, Webhooks
Stripe’s own scale basically forces this split.  ￼
	3.	Strict vs loose typing
In Elixir, use structs/typespecs where possible, but keep escape hatches for:
	•	unknown preview params
	•	undocumented-but-live fields
	•	version drift
	•	expanded/unexpanded unions
	•	v2 include fields defaulting to null
Official SDK docs explicitly acknowledge the need for “undocumented params/properties” escape hatches and preview handling.  ￼
	4.	Request builders for nested parameter trees
Stripe parameters get deeply nested, especially Checkout, subscriptions, Connect, Tax, Identity, Treasury. You want ergonomic encoding helpers rather than expecting users to handcraft deeply nested maps every time.  ￼
	5.	Search/list stream abstractions
Provide Enumerable/Stream wrappers over both list pagination and search pagination. They are different.  ￼
	6.	Event decoding abstraction
Model:
	•	snapshot event with typed data.object
	•	thin event with reference-only payload
	•	raw fallback event
This will save users a lot of pain.  ￼

⸻

5. Biggest gotchas your library should anticipate
	1.	Modern Stripe is state-machine heavy
PaymentIntents, SetupIntents, subscriptions, invoices, Identity sessions, and more have multi-status lifecycles. A naïve CRUD SDK feels wrong here.  ￼
	2.	Version skew is real
Webhook events may reflect the webhook endpoint’s API version or account default version; snapshot event payload data stays fixed at the version used when created.  ￼
	3.	expand and include are different beasts
Many users will mix them up. v1 mostly uses expand; v2 introduces include for values that are intentionally returned as null unless requested.  ￼
	4.	Search is not for strict read-after-write
Stripe says search can lag; during outages it can be much more delayed.  ￼
	5.	Retries are necessary but dangerous
Retrying after a 500 is not the same as “nothing happened”; Stripe explicitly says 500s can be indeterminate and later reconciled by webhooks.  ￼
	6.	Webhook verification fails if middleware mutates the body
In Phoenix/Plug terms, raw-body access needs to be solved cleanly and documented loudly.  ￼
	7.	Connect/organization context leaks everywhere
Stripe-Account, Stripe-Context, org keys, and per-request account targeting are not niche features anymore. They change how almost every request should be modeled.  ￼
	8.	Usage billing is mid-migration
Old mental models still exist in the wild, but Stripe’s newer meter/meter_event family is where the platform is going.  ￼

⸻

6. A realistic “main jobs to be done” enumeration for users of your Elixir SDK

This is the JTBD list I’d give an implementation LLM:
	1.	Make authenticated Stripe API calls with resilient retries, timeouts, request IDs, and per-request overrides.  ￼
	2.	Work against specific Stripe API versions, including preview versions, while surviving monthly and named breaking releases.  ￼
	3.	Support both /v1 and /v2 namespaces with correct request/response semantics.  ￼
	4.	Collect one-time payments using PaymentIntents and PaymentMethods.  ￼
	5.	Save payment credentials for later use with SetupIntents, PaymentMethods, Customers, and Mandates.  ￼
	6.	Maintain compatibility with legacy charge/token flows where customers still need them.  ￼
	7.	Run hosted payment experiences through Checkout Sessions and adjacent hosted flows.  ￼
	8.	Manage customers and their saved instruments.  ￼
	9.	Issue refunds and handle downstream payment exceptions like disputes.  ￼
	10.	Operate subscription businesses with Products, Prices, Subscriptions, Invoices, Invoice Items, Discounts, Portal Sessions, and Schedules.  ￼
	11.	Support usage-based billing with Meters and Meter Events.  ￼
	12.	Search and paginate Stripe data efficiently, with clear semantics around consistency.  ￼
	13.	Use metadata for reconciliation and local-ID correlation without storing sensitive data.  ￼
	14.	Build Connect/platform integrations that act on behalf of connected accounts and manage fund movement.  ￼
	15.	Process webhooks securely, including raw-body signature verification and thin-event follow-up fetches.  ￼
	16.	Handle tax calculation and tax-aware billing/payment flows.  ￼
	17.	Verify user identities with Identity verification sessions.  ￼
	18.	Link bank accounts and fetch permitted financial data with Financial Connections.  ￼
	19.	Support broader Stripe financial infrastructure families like Treasury, Issuing, Terminal, and related event types, at least through generated coverage.  ￼
	20.	Offer strong testing utilities via Stripe CLI, webhook test helpers, stripe-mock, and Billing test clocks.  ￼

⸻

7. If you want to build it systematically, here is the best implementation order

Tier 1: must-have foundation
	1.	client config + request options
	2.	auth/versioning/idempotency/retries/errors
	3.	list/search pagination
	4.	expand/include support
	5.	webhook verification + event parsing
	6.	raw request/response exposure  ￼

Tier 2: highest-value product APIs
	1.	Customers
	2.	PaymentMethods
	3.	PaymentIntents
	4.	SetupIntents
	5.	Refunds
	6.	Checkout Sessions
	7.	Charges read/legacy compatibility  ￼

Tier 3: billing
	1.	Products / Prices
	2.	Subscriptions
	3.	Invoices / Invoice Items
	4.	Coupons / Promotion Codes
	5.	Portal Sessions
	6.	Subscription Schedules
	7.	Meters / Meter Events / Test Clocks  ￼

Tier 4: platform + finance
	1.	Connect accounts/context
	2.	Transfers / Payouts / balance reconciliation
	3.	Tax
	4.	Identity
	5.	Financial Connections  ￼

Tier 5: breadth / completeness
	1.	Treasury
	2.	Issuing
	3.	Terminal
	4.	Entitlements / Capital / less-common families
	5.	generated long-tail resource coverage  ￼

⸻

8. My strong recommendation on architecture

Build this as a generated core + handwritten ergonomic shell:
	•	Generated core from Stripe’s spec3.sdk in /latest/ so you inherit both v1 and v2 coverage.  ￼
	•	Handwritten transport for Elixir-specific behavior: Finch/Hackney/Req/Tesla adapter strategy, retries, raw-body webhook support, and streaming pagination. Existing Elixir Stripe work already treats timeouts/retries/config as explicit concerns.  ￼
	•	Handwritten high-value resource APIs for Payments, Billing, Connect, and Webhooks.  ￼
	•	Version-aware compat layer that makes it easy to pin GA, opt into preview, and override per request.  ￼

If you want, I can turn this into a sharper “implementation blueprint” next: module tree, codegen strategy, type strategy, and milestone-by-milestone build plan for an Elixir SDK.