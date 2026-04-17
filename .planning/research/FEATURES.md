# Feature Research

**Domain:** Production Elixir SDK for Stripe API (LatticeStripe v1.3 — Production Coverage & Adoption Polish)
**Researched:** 2026-04-16
**Confidence:** HIGH (all API operations and fields verified against official Stripe API reference docs)

---

## Context: v1.3 Scope

This research covers 6 new Stripe resource families and 1 DX polish phase for v1.3.
LatticeStripe v1.2 is live with 31 phases complete, 85 plans executed, 108 source files,
21K LOC Elixir, 1783 tests / 0 failures. The downstream consumer (Accrue) is building on v1.1+.

v1.3 goal: Production SaaS developers never need to drop to raw HTTP for common workflows.
Onboarding friction minimized.

**New resource families:** Dispute, CreditNote, Mandate, SetupAttempt, File/FileLink, Quote
**DX polish:** Phoenix webhook recipe, test fixture builders, recipes guide

---

## Per-Resource Family Analysis

### 1. Dispute

**What it is:** A record of a customer challenging a charge with their card issuer.
Merchants submit evidence to defend against chargebacks.

**Stripe API operations:**
- `GET /v1/disputes/:id` — retrieve
- `POST /v1/disputes/:id` — update (submit evidence, set `submit: true` to send to bank)
- `GET /v1/disputes` — list
- `POST /v1/disputes/:id/close` — close (concede the dispute)

**No CREATE** — disputes are created by Stripe/card networks, not by merchants.
**No DELETE** — disputes are permanent records.

**Key fields:**
- `id`, `amount`, `currency`, `charge` (expandable), `payment_intent` (expandable)
- `status` — enum: `warning_needs_response`, `warning_under_review`, `warning_closed`, `needs_response`, `under_review`, `won`, `lost`
- `reason` — enum: `bank_cannot_process`, `check_returned`, `credit_not_processed`, `customer_initiated`, `debit_not_authorized`, `duplicate`, `fraudulent`, `general`, `incorrect_account_details`, `insufficient_funds`, `product_not_received`, `product_unacceptable`, `subscription_canceled`, `unrecognized`
- `balance_transactions` — array of BalanceTransaction objects showing fund movements
- `is_charge_refundable` — boolean
- `metadata`

**Nested `evidence` object (27 fields):**

File upload fields (each accepts a File object ID):
- `cancellation_policy`, `customer_communication`, `customer_signature`
- `duplicate_charge_documentation`, `receipt`, `refund_policy`
- `service_documentation`, `shipping_documentation`, `uncategorized_file`

Text fields (each up to 20,000 chars, combined limit 150,000):
- `access_activity_log`, `billing_address`, `cancellation_policy_disclosure`
- `cancellation_rebuttal`, `customer_email_address`, `customer_name`
- `customer_purchase_ip`, `duplicate_charge_explanation`, `duplicate_charge_id`
- `product_description`, `refund_policy_disclosure`, `refund_refusal_explanation`
- `service_date`, `shipping_address`, `shipping_carrier`
- `shipping_date`, `shipping_tracking_number`, `uncategorized_text`

**Nested `evidence_details` object:**
- `due_by` — deadline timestamp for evidence submission
- `has_evidence` — boolean
- `past_due` — boolean
- `submission_count` — integer

**Nested `payment_method_details` object:**
- Varies by payment type: card (network reason code, case type), PayPal, Klarna, Amazon Pay

**Enhanced evidence for Visa CE 3.0:**
- `enhanced_evidence` nested object with additional structured data

**Action verbs:**
- `update` (with `submit: true`) — submit evidence to card network (irreversible; one shot)
- `update` (with `submit: false`) — stage evidence without submitting
- `close` — concede the dispute (stops evidence submission)

**Key constraint:** Evidence submission is one-shot — Stripe immediately forwards to the issuing
bank. A second submission is possible but uncommon. Model this with an explicit `submit_evidence/3`
verb rather than embedding in `update`.

**Dependencies on existing resources:** Charge, BalanceTransaction, File (for evidence uploads),
PaymentIntent (expandable reference).

---

### 2. CreditNote

**What it is:** A document that adjusts (reduces) a finalized Invoice's amount. Used for partial
refunds, corrections, and goodwill credits.

**Stripe API operations:**
- `POST /v1/credit_notes` — create
- `GET /v1/credit_notes/:id` — retrieve
- `POST /v1/credit_notes/:id` — update (memo and metadata only; post-issuance)
- `GET /v1/credit_notes` — list
- `POST /v1/credit_notes/:id/void` — void (reverses credit; only on open invoices)
- `GET /v1/credit_notes/preview` — preview (before creation; dry-run)
- `GET /v1/credit_notes/preview/lines` — preview line items
- `GET /v1/credit_notes/:id/lines` — retrieve line items

**Key fields:**
- `id`, `number` (customer-facing, on PDF), `created`, `voided_at`
- `amount`, `subtotal`, `total` (all in cents)
- `amount_shipping`, `discount_amount`, `out_of_band_amount`
- `pre_payment_amount`, `post_payment_amount`
- `status` — `issued` | `void`
- `type` — `pre_payment` (on open invoice) | `post_payment` (on paid invoice) | `mixed`
- `reason` — optional: `duplicate` | `fraudulent` | `order_change` | `product_unsatisfactory`
- `customer`, `invoice` (expandable), `refunds` (array), `pdf` (URL), `memo`

**Nested `lines` object:** paginated list of `CreditNoteLineItem`
- `amount`, `description`, `quantity`, `unit_amount`
- `type` — `invoice_line_item` | `custom_line_item`
- `invoice_line_item` (ID reference, when type is invoice_line_item)
- `tax_rates`, `tax_amounts`

**Create params for paid invoices:**
- `refund_amount` — refund to customer's payment method
- `credit_amount` — credit to customer balance (applied to future invoices)
- `out_of_band_amount` — credit outside Stripe (cash/check)
- All three can be combined; remaining amount after refund+credit becomes out_of_band

**Action verbs:**
- `void` — reverse the credit note (only works on open invoices)
- `preview` — dry-run before creating

**Dependencies on existing resources:** Invoice (required), Customer (expandable),
InvoiceLineItem (referenced in line items), Refund (referenced in `refunds` array).

---

### 3. Mandate

**What it is:** A record of customer authorization to debit their payment method. Created
automatically when SetupIntents or PaymentIntents create payment method authorizations.

**Stripe API operations:**
- `GET /v1/mandates/:id` — retrieve (only operation)

**No CREATE, UPDATE, DELETE, or LIST.** Mandates are created automatically by Stripe during
payment method setup flows. Developers read them to verify authorization state.

**Key fields:**
- `id`, `livemode`
- `status` — `active` | `inactive` | `pending`
- `type` — `single_use` | `multi_use`
- `payment_method` (expandable)

**Nested `customer_acceptance` object:**
- `accepted_at` (timestamp)
- `type` — `online` | `offline`
- `online` — `{ ip_address, user_agent }` (for audit trails, compliance)
- `offline` — `{ contact_email }` (for paper mandates)

**Nested `payment_method_details` object (varies by payment type):**
- SEPA Debit: `{ reference, url, network_status }`
- ACH / US Bank: `{ collection_method }`
- Bacs Debit: `{ network_status, reference, revocation_reason, url }`
- PayPal: `{ billing_agreement_id, payer_id }`
- Also: Amazon Pay, Klarna, Payto, Pix, UPI

**Nested `single_use` object** (when type is single_use):
- `amount`, `currency`

**Nested `multi_use` object** (when type is multi_use):
- (empty — presence means mandate is reusable)

**Action verbs:** None. Read-only resource.

**Dependencies on existing resources:** PaymentMethod (expandable).
SetupIntent and PaymentIntent create mandates during confirmation.

---

### 4. SetupAttempt

**What it is:** One attempted confirmation of a SetupIntent, capturing the specific details of
that attempt (success or failure). A single SetupIntent can have multiple SetupAttempts if
previous attempts failed.

**Stripe API operations:**
- `GET /v1/setup_attempts` — list (filter by `setup_intent`)

**No CREATE, RETRIEVE (by ID), UPDATE, or DELETE.** SetupAttempts are created automatically
by Stripe when a SetupIntent is confirmed. You list them by `setup_intent` to get history.

**Key fields:**
- `id`, `created`, `livemode`
- `setup_intent` (expandable)
- `customer` (expandable)
- `payment_method` (expandable)
- `application` (expandable)
- `on_behalf_of` (expandable)
- `attach_to_self` (boolean)
- `flow_directions` — `["inbound"]` | `["outbound"]` | `["inbound", "outbound"]`
- `usage` — `off_session` | `on_session`

**Nested `setup_error` object** (present only on failed attempts):
- `code`, `message`, `doc_url`
- `decline_code`
- `param`
- `payment_method` (the PM that failed)
- `type` — `api_error` | `card_error` | `idempotency_error` | `invalid_request_error`

**Nested `payment_method_details` object** (confirmation-specific info, varies by type):
- Card: `{ brand, checks, exp_month, exp_year, fingerprint, funding, last4, three_d_secure { ... } }`
- Bank: `{ bank_code, bank_name, bic, iban_last4 }`
- Digital wallets: Apple Pay, Google Pay
- Regional: iDEAL, Bancontact, SEPA Debit
- BNPL: Klarna, Affirm

**Action verbs:** None. Read-only resource (list only).

**Key use case:** Diagnosing why a SetupIntent failed. List attempts for a setup_intent,
inspect the most recent `setup_error` to understand the failure reason and whether to retry.

**Dependencies on existing resources:** SetupIntent (required filter param), Customer, PaymentMethod.

---

### 5. File and FileLink

**What they are:** File — a document uploaded to Stripe's servers (multipart upload).
FileLink — a shareable URL to access a File without authentication.

#### File

**Stripe API operations:**
- `POST https://files.stripe.com/v1/files` — create (NOTE: different hostname from api.stripe.com)
- `GET /v1/files/:id` — retrieve
- `GET /v1/files` — list

**No UPDATE or DELETE.** Files are immutable once uploaded.

**Upload mechanics:**
- Content-Type: `multipart/form-data` (not JSON)
- Upload endpoint: `https://files.stripe.com/v1/files` (files subdomain)
- Requires `purpose` parameter (see below)
- Size limits vary by purpose

**Key fields:**
- `id`, `created`, `expires_at` (nullable), `filename`
- `size` (bytes), `title` (nullable), `type` (csv | pdf | jpg | png)
- `url` (authenticated download — requires API key)
- `purpose` enum — see below
- `links` (embedded list of FileLinks, expandable)

**`purpose` enum values (20 total):**
- `dispute_evidence` — primary use case for this SDK
- `identity_document` — KYC document uploads
- `identity_document_downloadable` — Stripe Identity output
- `customer_signature`
- `account_requirement` — Connect account verification docs
- `additional_verification` — Connect custom account docs
- `business_icon`, `business_logo`
- `pci_document`
- `platform_terms_of_service`
- `finance_report_run`, `financial_account_statement`
- `issuing_regulatory_reporting`
- `selfie`
- `sigma_scheduled_query`
- `tax_document_user_upload`
- `terminal_android_apk`, `terminal_reader_splashscreen`
- `terminal_wifi_certificate`, `terminal_wifi_private_key`

**Action verbs:** None (create/retrieve/list only).

**SDK implementation note:** File upload requires multipart/form-data encoding, NOT the standard
`application/x-www-form-urlencoded` that all other LatticeStripe requests use. Requires a
separate codepath in the Transport layer or a dedicated upload function that sets the correct
Content-Type and sends binary data. Also requires the `files.stripe.com` base URL, not
`api.stripe.com`.

#### FileLink

**Stripe API operations:**
- `POST /v1/file_links` — create
- `GET /v1/file_links/:id` — retrieve
- `POST /v1/file_links/:id` — update (expire_at, metadata only)
- `GET /v1/file_links` — list

**Key fields:**
- `id`, `created`, `livemode`
- `file` (expandable, the parent File)
- `url` — public, unauthenticated download URL
- `expires_at` (nullable) — if set, link expires at this timestamp
- `expired` (boolean)
- `metadata`

**Action verbs:** None (CRUDL). Update can set expiry or mark as expired.

**Dependencies on existing resources:** File (required to create a FileLink).
Dispute Evidence (File IDs are submitted as dispute evidence fields).

---

### 6. Quote

**What it is:** A proposal that models prices for a customer. Accepted quotes automatically
generate an Invoice, Subscription, or SubscriptionSchedule. The proposal-to-subscription workflow.

**Stripe API operations:**
- `POST /v1/quotes` — create
- `GET /v1/quotes/:id` — retrieve
- `POST /v1/quotes/:id` — update
- `GET /v1/quotes` — list
- `POST /v1/quotes/:id/finalize` — finalize (draft → open; assigns quote number, ready to send)
- `POST /v1/quotes/:id/accept` — accept (open → accepted; generates Invoice/Subscription)
- `POST /v1/quotes/:id/cancel` — cancel (draft|open → canceled; terminal)
- `GET /v1/quotes/:id/pdf` — download PDF
- `GET /v1/quotes/:id/line_items` — list line items
- `GET /v1/quotes/:id/computed_upfront_line_items` — list upfront computed line items

**Lifecycle states (status field):**
- `draft` → `open` (via finalize) → `accepted` | `canceled`
- `draft` → `canceled`
- Expired quotes auto-cancel when `expires_at` is reached

**Key fields:**
- `id`, `number` (assigned at finalize), `created`, `expires_at`
- `status` — `draft` | `open` | `accepted` | `canceled`
- `customer` (expandable), `customer_account`
- `currency`
- `amount_subtotal`, `amount_total`
- `description`, `header`, `footer` (PDF display text)
- `collection_method` — `charge_automatically` | `send_invoice`
- `invoice` (expandable; set after accept if one-time items)
- `subscription` (expandable; set after accept if recurring)
- `subscription_schedule` (expandable; set after accept if future-dated recurring)
- `on_behalf_of` (Connect)
- `metadata`

**Nested `computed` object:**
- `upfront` — `{ amount_subtotal, amount_total, line_items, total_details }`
- `recurring` — `{ amount_subtotal, amount_total, interval, interval_count, line_items, total_details }`

**Nested `subscription_data` object:**
- `billing_cycle_anchor`, `billing_cycle_anchor_config`
- `description`, `effective_date`, `trial_period_days`
- `metadata`, `prebilling`

**Nested `invoice_settings` object:**
- `days_until_due`, `issuer`

**Nested `from_quote` object** (for cloned quotes):
- `is_revision` (boolean), `quote` (parent quote ID)

**Nested `automatic_tax` object:**
- `enabled` (boolean), `liability`, `status`

**Nested `status_transitions` object:**
- `accepted_at`, `canceled_at`, `finalized_at`

**Also:** `discounts`, `default_tax_rates`, `transfer_data`

**What accepting a Quote generates:**
- One-time items only → draft `Invoice` (with `auto_advance: false`, caller must finalize)
- Recurring items, immediate start → `Subscription` (first invoice auto-generated as draft)
- Recurring items, future start → `SubscriptionSchedule`

**Action verbs (explicit, irreversible):**
- `finalize` — draft → open; assigns number; can be emailed to customer
- `accept` — customer agreed; generates downstream objects (Invoice/Subscription/Schedule)
- `cancel` — customer declined or quote no longer valid; terminal state

**Dependencies on existing resources:** Customer (required to finalize), Invoice (created on
accept), Subscription (created on accept), SubscriptionSchedule (created on accept with future
date), Product/Price (used in line items).

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume a production-grade Stripe SDK provides. Missing these forces raw HTTP.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Dispute retrieve + list | Chargeback handling is a production necessity for any merchant. `retrieve` and `list` are baseline CRUD. | LOW | Standard Resource pattern. Status enum, reason enum → `status_atom/1`, `reason_atom/1` helpers. BalanceTransaction list nested in response. |
| Dispute evidence update | Submitting evidence is THE core dispute workflow. Without `update` (with `evidence:` and `submit: true`), the module is useless for its primary purpose. | MEDIUM | Evidence has 27 fields (9 File IDs + 18 text). Nested `evidence` struct with all fields. The `submit: true` semantics must be visible — explicit `submit_evidence/3` verb is idiomatic vs hiding it in a generic `update`. |
| Dispute close | Concede a dispute programmatically. Needed in automated dispute pipelines. | LOW | Simple action verb. `close/2` or `close/3`. |
| CreditNote CRUDL | Invoice credits are table stakes for any billing system. SaaS teams issue credits for: overcharges, refunds, proration errors, goodwill. Stripe Billing users need this immediately. | MEDIUM | Status (`issued`/`void`), type (`pre_payment`/`post_payment`/`mixed`), reason, line items list endpoint. Three separate refund amount fields on create. |
| CreditNote void | Reversing a credit note is a required billing operation (e.g., issued a credit by mistake). | LOW | Action verb. `void/2` or `void/3`. Only works on open invoices. |
| CreditNote preview | Before creating a credit note, preview the result without committing. Standard billing DX. | LOW | `preview/3` returning a CreditNote struct. Also `preview_lines/3` for line item preview. |
| Mandate retrieve | Mandates are created automatically — retrieve is the only operation needed. Required for compliance (verify customer authorized the recurring debit), support workflows, and debugging failed debits. | LOW | Read-only. Nested `customer_acceptance` (online/offline), `payment_method_details` (varies by PM type), `single_use`/`multi_use`. Status atom helper. |
| SetupAttempt list | Without list, developers cannot diagnose why a SetupIntent failed. The only operation. Filter by `setup_intent` is the primary access pattern. | LOW | List-only resource. Nested `setup_error` and `payment_method_details`. `status_atom/1` on outer object. Decode `setup_error` into same `%Error{}` struct shape for consistency. |
| File retrieve + list | Read file metadata, list uploaded files. Required to reference files in dispute evidence and Connect verification flows. | LOW | Standard pattern. Purpose enum handling. Linked FileLinks embedded. |
| File create (upload) | Upload documents for dispute evidence, identity verification, business logos. Core file management. | HIGH | Non-standard: multipart/form-data, `files.stripe.com` base URL. Requires dedicated upload function separate from standard API path. Binary data handling. |
| FileLink CRUDL | Create shareable URLs for files (no auth needed to download). Required for sharing dispute evidence with issuers, or documents with customers/partners. | LOW | Standard pattern. Expiry management. `expired` boolean. |
| Quote CRUDL | The proposal-to-subscription workflow is a full SaaS sales pattern. Create, read, update quotes as drafts, then finalize and share with customers. | MEDIUM | Complex nested structs: `computed`, `subscription_data`, `invoice_settings`, `from_quote`, `status_transitions`. Line items list endpoint. PDF download. |
| Quote finalize | Assigns a number and makes the quote shareable. Required step before sending to customer. | LOW | Action verb. `finalize/2` or `finalize/3`. |
| Quote accept | The customer agreed — generate downstream billing objects. Core of the Quote lifecycle. | LOW | Action verb. `accept/2` or `accept/3`. Returns Quote with `invoice`, `subscription`, or `subscription_schedule` populated. |
| Quote cancel | Customer rejected or quote expired. Explicit cancellation. | LOW | Action verb. `cancel/2` or `cancel/3`. Terminal state. |

### Differentiators (Competitive Advantage)

Features that set LatticeStripe apart from stripity_stripe and generic HTTP wrappers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Explicit `submit_evidence/3` verb for disputes | Hiding evidence submission inside a generic `update` call obscures the irreversible nature of evidence submission. An explicit verb makes the "one-shot" semantics obvious and discoverable in docs. No other Elixir SDK does this. | LOW | `submit_evidence(client, id, evidence_params)` calls `POST /v1/disputes/:id` with `evidence: params, submit: true`. Separate `stage_evidence/3` for staging without submitting. Both return `{:ok, %Dispute{}}`. |
| Typed `Dispute.Evidence` struct | Dispute evidence has 27 named fields. A typed struct (vs raw map) makes the field names discoverable via editor autocomplete and ExDoc. Idiomatic LatticeStripe. | MEDIUM | `%Dispute.Evidence{}` struct with all 27 fields, and `%Dispute.EvidenceDetails{}` for tracking. Decode from API response. Encode back when updating. |
| `Dispute.PaymentMethodDetails` polymorphic struct | Disputes behave differently by payment method (card vs PayPal vs Klarna). Typed dispatch improves pattern matching. | MEDIUM | Same pattern as existing `ExternalAccount` polymorphic dispatcher. `Card`, `PayPal`, `Klarna`, `Unknown` variants. |
| CreditNote line items stream | Auto-paginate credit note line items via `stream!/3`. SaaS invoices can have many line items. Consistent with existing `stream!/2` on other list endpoints. | LOW | Already have `stream!/2` pattern on other resources. Add `stream_lines!/3` for credit note line items endpoint. |
| Mandate `status_atom/1` + `type_atom/1` | Idiomatic Elixir for finite enumerations. Status (`active`/`inactive`/`pending`) and type (`single_use`/`multi_use`) are natural atoms. | LOW | Consistent with existing `status_atom/1` pattern across all v1.2 resources. |
| SetupAttempt `setup_error` decoded as `%LatticeStripe.Error{}` | When SetupAttempt has a `setup_error`, it has the same structure as a top-level API error. Decoding it into the same `%Error{}` struct allows callers to use identical error handling code for both immediate errors and historical attempt inspection. | MEDIUM | Reuse existing `Error.from_map/1` for the `setup_error` nested object. Add `error_type/1` convenience function returning the error type atom. |
| File multipart upload with progress telemetry | Large file uploads (dispute evidence PDFs) benefit from upload progress visibility. LatticeStripe already emits telemetry events — adding byte count to the upload stop event gives users visibility into upload performance. | MEDIUM | Add `bytes_uploaded` to `[:lattice_stripe, :file, :upload, :stop]` telemetry event. Requires tracking content-length. |
| Quote `what_will_be_created/1` introspection | Before accepting a quote, tell the caller whether it will produce an Invoice, a Subscription, or a SubscriptionSchedule. Eliminates the need for callers to inspect line items and dates to predict downstream behavior. | LOW | Pure computation on the quote struct. Check `computed.recurring` presence and `subscription_data.effective_date` vs now. Returns `:invoice | :subscription | :subscription_schedule`. |
| Phoenix webhook recipe guide | Stripe + Phoenix webhook setup is the #1 integration search for Elixir developers. The raw-body problem (Phoenix's body parser consumes the raw body before `Webhook.Plug` can verify it) is a common gotcha. A complete, copy-paste-ready guide eliminates the single largest onboarding friction point. | LOW | Documentation only. Guide covers: raw body preservation via `Plug.Parsers` custom `body_reader`, router config, `LatticeStripe.Webhook.Plug` mounting, `Webhook.Handler` behaviour implementation, event type pattern matching, idempotency via `event.id` + Ecto. |
| Test fixture builders for new resources | The existing `LatticeStripe.Testing` module provides fixture builders for Payment, Billing, Connect resources. Adding builders for Dispute, CreditNote, File, Quote lets library users write clean integration tests for their code that calls LatticeStripe. | MEDIUM | Same pattern as existing fixtures in `test/support/fixtures/`. Add `dispute_fixture/1`, `credit_note_fixture/1`, `file_fixture/1`, `quote_fixture/1`. Export from `LatticeStripe.Testing`. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Auto-retry dispute evidence submission | "The bank rejected my evidence — retry automatically" | Evidence submission to card networks is explicitly one-shot and irreversible. Stripe documents this prominently. Auto-retry would silently re-submit to the issuing bank, potentially triggering fraud flags or confusing reviewers. | Surface `submission_count` from `evidence_details`. Provide `stage_evidence/3` for drafting before committing. Make `submit_evidence/3` visually distinct from `update`. |
| File streaming / chunked upload | Large file uploads should stream chunks | Stripe's file upload API does not support chunked/streaming uploads — it requires the full file in a single multipart request. Max size is per-purpose (dispute evidence: under 4.5MB combined across all files for a single dispute). | Document size limits clearly. For dispute evidence, multiple files per evidence field are not supported — one file per field. Verify size before upload. |
| Automatic FileLink creation on file upload | "Just give me a URL immediately" | FileLinks have optional expiry and are a separate authorization concept from the file itself. Auto-creating a FileLink on every upload would create orphaned permanent links with no expiry — a security anti-pattern for compliance documents. | Require explicit `FileLink.create/3`. Document the pattern: upload file → get file_id → create link with appropriate expiry. |
| Quote auto-finalize on create | "Just finalize when I create" | Draft state exists to allow iterative edits (line items, customer, pricing). Auto-finalizing skips the draft review stage and makes the quote number-assigned immediately, confusing teams with approval workflows. | Keep create → finalize as explicit two-step. The draft state IS the value — it's where edits happen. |
| Mandate creation API | "I want to create a mandate directly" | Mandates are created by Stripe during payment authorization flows (SetupIntent confirmation, PaymentIntent confirmation with `setup_future_usage`). Direct creation bypasses the authorization verification that makes mandates legally enforceable. | Use SetupIntent to create payment method authorizations, which generate mandates as a side effect. Link SetupAttempt list to diagnose if the mandate wasn't created. |
| Sync dispute polling | "Poll the dispute until it's resolved" | Dispute resolution takes days to weeks. Polling wastes API requests and rate limit budget. | Emit Stripe webhooks (`charge.dispute.updated`, `charge.dispute.won`, `charge.dispute.lost`). Handle via existing `LatticeStripe.Webhook.Plug`. |

---

## Feature Dependencies

```
Dispute
    └──requires──> File (for evidence file IDs — upload first, reference ID in evidence)
    └──expandable──> Charge (already shipped v1.0)
    └──expandable──> PaymentIntent (already shipped v1.0)
    └──expandable──> BalanceTransaction (already shipped v1.0)
    └──independent_of──> CreditNote, Mandate, Quote

CreditNote
    └──requires──> Invoice (already shipped v1.0 — invoice ID is mandatory create param)
    └──references──> InvoiceLineItem (for line item type on create)
    └──references──> Refund (populated in refunds array post-create)
    └──independent_of──> Dispute, Mandate, Quote

Mandate
    └──expandable──> PaymentMethod (already shipped v1.0)
    └──created_by──> SetupIntent confirmation (side effect, not a dep)
    └──created_by──> PaymentIntent confirmation (side effect, not a dep)
    └──independent_of──> Dispute, CreditNote, Quote, File

SetupAttempt
    └──requires──> SetupIntent (already shipped v1.0 — setup_intent is mandatory list filter)
    └──expandable──> Customer (already shipped v1.0)
    └──expandable──> PaymentMethod (already shipped v1.0)
    └──independent_of──> Dispute, CreditNote, Quote, File, Mandate

File
    └──independent_of──> all other new resources (foundational upload primitive)
    └──referenced_by──> Dispute (evidence file IDs)
    └──referenced_by──> Account (identity_document purposes — Connect flow, already shipped)

FileLink
    └──requires──> File (file ID mandatory on create)
    └──independent_of──> Dispute, CreditNote, Mandate, SetupAttempt, Quote

Quote
    └──requires──> Customer (must exist to finalize)
    └──generates──> Invoice (on accept with one-time items)
    └──generates──> Subscription (on accept with recurring, immediate)
    └──generates──> SubscriptionSchedule (on accept with recurring, future date)
    └──uses──> Product/Price (in line items)
    └──all_dependencies_already_shipped_in_v1.0_or_v1.1

DX Polish (Phoenix webhook recipe, test fixtures, recipes guide)
    └──depends_on──> All 6 resource families complete (fixture builders need the structs)
    └──enhances──> Webhook.Plug + Webhook.Handler (already shipped v1.0)
    └──references──> All major resource families
```

### Dependency Notes

- **File before Dispute evidence:** Merchants upload files first (`File.create/3`), then reference
  the returned `file.id` in `Dispute.submit_evidence/3`. File must be implemented before
  Dispute evidence submission is exercisable end-to-end. However, Dispute retrieve/list/close
  can ship independently of File.

- **CreditNote is self-contained:** Depends only on Invoice (v1.0), which is stable. No new
  resource dependencies. Can be implemented in any order relative to other v1.3 families.

- **Mandate and SetupAttempt are read-only:** Both are list/retrieve only. No write operations,
  no upstream dependencies on new v1.3 resources. Lowest complexity of the 6 families.
  Natural candidates for a single combined phase.

- **Quote depends on existing resources only:** All Quote dependencies (Customer, Invoice,
  Subscription, SubscriptionSchedule, Product, Price) are already in v1.0/v1.1. Quote is
  self-contained from a dependency standpoint but has the most complex nested struct surface.

- **DX polish ships last:** Fixture builders reference structs from all 6 new families.
  Phoenix webhook recipe can document all resource event types. Recipes guide needs complete
  surface to write meaningful examples.

---

## MVP Definition

### Phase 1 — File/FileLink (foundational)

File and FileLink are the most cross-cutting new primitives. File uploads unblock full dispute
evidence workflows.

- [x] `File.create/3` (multipart upload, files.stripe.com)
- [x] `File.retrieve/3` + `File.list/3`
- [x] `FileLink.create/3`, `retrieve/3`, `update/3`, `list/3`
- [x] Typed `%File{}` and `%FileLink{}` structs
- [x] Upload telemetry event

### Phase 2 — Dispute

Chargeback handling is the most urgent production need. Requires File (Phase 1) for evidence.

- [x] `Dispute.retrieve/3` + `Dispute.list/3`
- [x] `Dispute.submit_evidence/3` (with `submit: true`)
- [x] `Dispute.stage_evidence/3` (with `submit: false`)
- [x] `Dispute.close/3`
- [x] Typed `%Dispute{}`, `%Dispute.Evidence{}`, `%Dispute.EvidenceDetails{}` structs
- [x] `status_atom/1` + `reason_atom/1` helpers

### Phase 3 — CreditNote

Invoice credits are required for any production billing system.

- [x] `CreditNote.create/3`, `retrieve/3`, `update/3`, `list/3`, `list_lines/3`
- [x] `CreditNote.void/3`
- [x] `CreditNote.preview/3` + `CreditNote.preview_lines/3`
- [x] Typed `%CreditNote{}` + `%CreditNote.LineItem{}` structs
- [x] `stream_lines!/3` auto-pagination
- [x] `status_atom/1` + `type_atom/1` helpers

### Phase 4 — Mandate + SetupAttempt

Read-only diagnostic resources. Low complexity, high production value for debugging.

- [x] `Mandate.retrieve/3`
- [x] `SetupAttempt.list/3`
- [x] Typed `%Mandate{}`, `%Mandate.CustomerAcceptance{}`, `%Mandate.PaymentMethodDetails{}` structs
- [x] Typed `%SetupAttempt{}`, `%SetupAttempt.SetupError{}` structs
- [x] `Mandate.status_atom/1` + `type_atom/1`
- [x] `SetupAttempt.setup_error` decoded as `%LatticeStripe.Error{}`

### Phase 5 — Quote

SaaS proposal-to-subscription workflow. Most complex struct surface.

- [x] `Quote.create/3`, `retrieve/3`, `update/3`, `list/3`
- [x] `Quote.finalize/3`, `accept/3`, `cancel/3`
- [x] `Quote.pdf/3` (PDF download)
- [x] `Quote.list_line_items/3` + `Quote.list_upfront_line_items/3`
- [x] Typed `%Quote{}` with all nested structs
- [x] `status_atom/1` + `what_will_be_created/1` helpers

### Phase 6 — DX Polish

Ships after all resource families are complete.

- [x] Phoenix webhook recipe guide (`guides/phoenix-webhooks.md`)
- [x] Test fixture builders for all 6 new families (added to `LatticeStripe.Testing`)
- [x] Recipes guide (`guides/recipes.md`) — common patterns across resource families

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Dispute retrieve + list | HIGH | LOW | P1 |
| Dispute evidence submission | HIGH | MEDIUM | P1 |
| CreditNote CRUDL + void | HIGH | MEDIUM | P1 |
| File create (upload) | HIGH | HIGH | P1 |
| FileLink CRUDL | HIGH | LOW | P1 |
| Quote full lifecycle | HIGH | HIGH | P1 |
| Mandate retrieve | MEDIUM | LOW | P1 |
| SetupAttempt list | MEDIUM | LOW | P1 |
| CreditNote preview | MEDIUM | LOW | P2 |
| Dispute close | MEDIUM | LOW | P2 |
| Quote PDF download | MEDIUM | LOW | P2 |
| Typed Evidence struct | MEDIUM | MEDIUM | P2 |
| Phoenix webhook recipe | HIGH | LOW | P2 |
| Test fixture builders | MEDIUM | MEDIUM | P2 |
| CreditNote stream_lines! | LOW | LOW | P3 |
| Quote what_will_be_created/1 | LOW | LOW | P3 |
| File upload telemetry | LOW | LOW | P3 |
| SetupAttempt setup_error as Error{} | MEDIUM | LOW | P3 |
| Recipes guide | MEDIUM | LOW | P3 |

**Priority key:**
- P1: Must have for v1.3 to claim "production coverage" — ships in core phases
- P2: Should have — increases production confidence and DX — ships in same phases
- P3: Nice to have — completes the story — can ship in DX phase or later

---

## Competitor Feature Analysis

| Feature | stripity_stripe (legacy) | stripe-ruby (official) | LatticeStripe v1.3 plan |
|---------|--------------------------|------------------------|-------------------------|
| Dispute evidence submission | YES — generic `update` only | YES — generic `update` | YES + explicit `submit_evidence/3` verb; idiomatic |
| CreditNote void | YES | YES | YES + `type_atom/1` + line item streaming |
| Mandate retrieve | YES | YES | YES + typed payment_method_details by PM type |
| SetupAttempt list | YES | YES | YES + setup_error decoded as %Error{} |
| File multipart upload | YES | YES | YES + telemetry; NOTE: different transport path |
| Quote lifecycle | PARTIAL | YES | YES + `what_will_be_created/1` helper |
| Typed nested structs | PARTIAL (inconsistent) | YES (auto-generated) | YES (fully typed, handwritten) |
| Phoenix webhook guide | NO | N/A | YES (Elixir-specific differentiator) |
| Test fixture builders | NO | YES (built-in fixtures) | YES via LatticeStripe.Testing |
| status_atom helpers | NO | NO | YES (consistent with v1.2 pattern) |

---

## Implementation Notes Per Feature

### File Upload — Transport Layer Challenge

All existing LatticeStripe requests use `application/x-www-form-urlencoded` to `api.stripe.com`.
File uploads require `multipart/form-data` to `https://files.stripe.com/v1/files`.

Two options:
1. **Dedicated upload function in Transport** — add `upload/4` alongside `request/5`. Finch
   supports multipart via `:multipart` body type. Pass binary file data + purpose. Use
   `files.stripe.com` base URL.
2. **Configurable base URL per request** — allow per-request base URL override and content-type
   override. More general but adds complexity to the public API.

**Recommendation:** Option 1 — dedicated `Transport.upload/4` callback added to the `Transport`
behaviour. Finch implementation wraps binary in multipart form. Clean separation from standard
JSON API requests. The `File` module calls `transport.upload/4` instead of `transport.request/5`.

### Dispute Evidence — Struct Design

Evidence has 27 named fields. Three options:
1. Raw map (current approach for unknown fields)
2. `%Dispute.Evidence{}` typed struct with all 27 fields
3. Nested keyword lists

**Recommendation:** Option 2 — typed struct. The evidence fields are a fixed, documented schema.
A typed struct makes all 27 fields discoverable in editor autocomplete and ExDoc. The struct
decodes from API responses and encodes back when calling `update/3`. Uses the existing
`from_map/1` + `@known_fields` + `extra` pattern.

### Quote — Line Items vs Computed

Quotes have two related concepts:
- `line_items` (input: what was quoted)
- `computed.upfront.line_items` and `computed.recurring.line_items` (output: what Stripe computed)

The `GET /v1/quotes/:id/line_items` endpoint returns input line items (paginated).
The `GET /v1/quotes/:id/computed_upfront_line_items` returns computed upfront line items.

Both need `list_line_items/3` and `list_upfront_line_items/3` functions with `stream!/2` variants.

### SetupAttempt — List-Only Access Pattern

SetupAttempts have no `retrieve/:id` endpoint — only `list`. This is unusual in the Stripe API.
The typical usage pattern:

```elixir
# Get all attempts for a SetupIntent to diagnose failures
{:ok, page} = SetupAttempt.list(client, %{setup_intent: "seti_..."})
# Most recent attempt is first
latest = List.first(page.data)
# Inspect setup_error if status is not succeeded
```

The module should not expose a `retrieve/3` function (there is no such endpoint). This matches
the Mandate pattern (retrieve-only) — both are asymmetric from the standard CRUDL pattern but
for opposite reasons.

### DX Polish — Phoenix Webhook Recipe

The raw body problem is the #1 Phoenix + Stripe webhook gotcha. Pattern:

```elixir
# In endpoint.ex — preserve raw body for webhook verification
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []},
  json_decoder: Phoenix.json_library()

# In router.ex
scope "/webhooks" do
  pipe_through :api
  post "/stripe", MyAppWeb.StripeWebhookController, :handle
end
```

The guide must show the `CacheBodyReader` module (if LatticeStripe should ship one) or reference
how to implement it. This is a documentation artifact plus potentially a small helper module.

---

## Sources

- [Stripe Disputes API Reference](https://docs.stripe.com/api/disputes) — operations confirmed
- [Stripe Dispute Update API](https://docs.stripe.com/api/disputes/update) — all 27 evidence fields confirmed
- [Stripe Disputes Responding Guide](https://docs.stripe.com/disputes/api) — submit semantics, one-shot nature
- [Stripe Credit Notes API Reference](https://docs.stripe.com/api/credit_notes) — operations confirmed
- [Stripe Credit Note Object](https://docs.stripe.com/api/credit_notes/object) — all fields confirmed
- [Stripe Programmatic Credit Notes Guide](https://docs.stripe.com/invoicing/integration/programmatic-credit-notes) — refund_amount/credit_amount/out_of_band_amount semantics
- [Stripe Mandates API Reference](https://docs.stripe.com/api/mandates) — retrieve-only confirmed
- [Stripe Mandate Object](https://docs.stripe.com/api/mandates/object) — nested objects confirmed
- [Stripe Setup Attempts API Reference](https://docs.stripe.com/api/setup_attempts) — list-only confirmed
- [Stripe SetupAttempt Object](https://docs.stripe.com/api/setup_attempts/object) — nested objects confirmed
- [Stripe Files API Reference](https://docs.stripe.com/api/files) — operations confirmed
- [Stripe File Object](https://docs.stripe.com/api/files/object) — all 20 purpose enum values confirmed
- [Stripe File Upload Guide](https://docs.stripe.com/file-upload) — multipart/form-data, files.stripe.com URL confirmed
- [Stripe FileLinks API Reference](https://docs.stripe.com/api/file_links) — CRUDL confirmed
- [Stripe Quotes API Reference](https://docs.stripe.com/api/quotes) — all operations confirmed
- [Stripe Quote Object](https://docs.stripe.com/api/quotes/object) — all nested objects confirmed
- [Stripe Quotes Overview Guide](https://docs.stripe.com/quotes/overview) — lifecycle states and downstream object generation confirmed
- [Phoenix Webhook Pattern](https://connerfritz.com/blog/stripe-webhooks-in-phoenix-with-elixir-pattern-matching/) — raw body problem confirmed

---

*Feature research for: LatticeStripe v1.3 — Production Coverage & Adoption Polish*
*Researched: 2026-04-16*
