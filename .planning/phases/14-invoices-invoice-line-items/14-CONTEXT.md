# Phase 14: Invoices & Invoice Line Items - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 14 delivers the full Stripe **Invoice lifecycle** as idiomatic Elixir resources: Invoice CRUD + action verbs (finalize/void/pay/send/mark_uncollectible), `upcoming/3` and `create_preview/3` proration preview, auto-advance race mitigation via telemetry, Invoice Line Items as a typed child resource, and InvoiceItem as a standalone CRUD resource.

**In scope:**
- `LatticeStripe.Invoice` — create, retrieve, update, delete, list, stream, search + action verbs (finalize, void, pay, send_invoice, mark_uncollectible) + upcoming/3 + create_preview/3
- `LatticeStripe.Invoice.LineItem` — typed struct for read-only line items on an invoice, accessed via `Invoice.list_line_items/4` and `Invoice.stream_line_items!/3`
- `LatticeStripe.Invoice.StatusTransitions` — typed nested struct (finalized_at, marked_uncollectible_at, paid_at, voided_at)
- `LatticeStripe.Invoice.AutomaticTax` — typed nested struct (enabled, status, liability as map)
- `LatticeStripe.InvoiceItem` — standalone CRUD resource (create, retrieve, update, delete, list, stream) at `/v1/invoiceitems`
- `LatticeStripe.InvoiceItem.Period` — typed nested struct (start, end)
- `LatticeStripe.Billing.Guards` — shared proration guard module (`check_proration_required/2`)
- `require_explicit_proration` option on Client struct (default `false`, forward-wired for Phase 15)
- Auto-advance telemetry: `[:lattice_stripe, :invoice, :auto_advance_defaulted]` event + `attach_default_logger/1` extension
- `guides/invoices.md` — comprehensive workflow guide (~400 lines)

**Out of scope:**
- Subscriptions / SubscriptionItems (Phase 15)
- SubscriptionSchedules (Phase 16)
- Connect transfer_data typing (Phase 17)
- TaxRate resource (future phase)
- Shared `LatticeStripe.Address` struct (future cross-cutting phase)

</domain>

<decisions>
## Implementation Decisions

### Action Verb Surface

- **D-14a:** Mixed naming — bare verbs where safe, suffixed only for `send` (Kernel.send collision). Functions: `finalize/4`, `void/4`, `pay/4`, `send_invoice/4`, `mark_uncollectible/4`. All follow uniform arity `(client, id, params \\ %{}, opts \\ [])`. Both tuple and bang variants.

  **Why:** Elixir module context (`Invoice.finalize`) removes ambiguity — no need for `finalize_invoice` suffix like official SDKs use (they lack module namespacing). `send_invoice` is the exception because `def send(client, id, params \\ %{}, opts \\ [])` generates an arity-2 clause that conflicts with `Kernel.send/2`. All 4 official Stripe SDKs also use `send_invoice`. Uniform arity matches existing `PaymentIntent.confirm/capture/cancel` pattern.

- **D-14a (precedent):** `mark_uncollectible/4` matches the Stripe API path and all official SDKs verbatim. No shortening.

### Upcoming Invoice Preview

- **D-14b:** Ship BOTH `upcoming/3` (legacy `GET /v1/invoices/upcoming`) and `create_preview/3` (new `POST /v1/invoices/create_preview`). Both return `{:ok, %Invoice{id: nil}}` — same struct, nil id. Also ship `upcoming_lines/3` and `create_preview_lines/3` for paginating line items on preview invoices.

  **Why:** Stripe is deprecating `upcoming` in favor of `create_preview` as of API version `2025-03-31.basil`. Shipping both future-proofs the SDK — users on older API versions use `upcoming/3`, users on newer versions use `create_preview/3`. Same return type for both.

- **D-14b (signature):** `upcoming(client, params, opts \\ [])` — params is a map with `customer`, `subscription`, `subscription_items` keys. Matches `create/3` and `list/3` patterns. No convenience wrappers for proration preview — raw params map is sufficient, matching all official SDKs.

- **D-14b (lines):** The `lines` field on Invoice struct is `%LatticeStripe.List{data: [%Invoice.LineItem{}, ...]}` — preserves `has_more` and pagination metadata. Stripe paginates at 10 items by default so `has_more: true` is common. `from_map/1` parses via `List.from_json/1` + `Enum.map(&Invoice.LineItem.from_map/1)`.

### Auto-Advance Telemetry

- **D-14c:** Pre-request telemetry event `[:lattice_stripe, :invoice, :auto_advance_defaulted]`. Fires in `Invoice.create/3` when params map does NOT contain `"auto_advance"` key. Inspects params before the HTTP call.

  **Why:** The auto-advance footgun is a code-level mistake (forgetting to pass the param), not a runtime anomaly. Pre-request inspection catches it at the decision point, before wasting an HTTP round-trip.

- **D-14c (event shape):** `measurements: %{system_time: System.system_time()}`, `metadata: %{resource: "invoice", operation: "create", auto_advance: :defaulted}`. Consistent with existing request event metadata keys.

- **D-14c (logger):** Extend `attach_default_logger/1` to also handle this event. Emits `Logger.warning("Invoice created without explicit auto_advance — Stripe will auto-finalize in ~1 hour. Set auto_advance: false for draft invoices.")`. Users who call `attach_default_logger/1` (recommended in quickstart) get the warning automatically.

- **D-14c (docs):** Layered documentation:
  1. `Invoice.@moduledoc` — brief "Common workflow" section with canonical `create → add items → finalize → pay` sequence
  2. `Invoice.create/3` `@doc` — admonition about `auto_advance` default behavior
  3. `guides/invoices.md` — full walkthrough with code examples, auto-advance explainer, collection method comparison

- **D-14c (opt-out):** No opt-out mechanism initially. Telemetry is inherently opt-in (no handler = no effect). Add suppression config only if users request it.

### Invoice Line Items

- **D-14d:** `LatticeStripe.Invoice.LineItem` — nested under Invoice, data-struct-only module. Mirrors `Checkout.LineItem` precedent exactly.

- **D-14d (access):** `Invoice.list_line_items/4` and `Invoice.stream_line_items!/3` on the parent module. Matches `Checkout.Session.list_line_items/4` pattern. The `LineItem` module is a data struct, not an API surface.

### InvoiceItem (Standalone CRUD)

- **D-14e:** `LatticeStripe.InvoiceItem` — flat namespace (standalone CRUD resource at `/v1/invoiceitems`). Operations: create, retrieve, update, delete, list, stream. No search (D-05 callout: endpoint doesn't exist).

- **D-14e (disambiguation):** `@moduledoc` includes explicit "InvoiceItem vs Invoice Line Item" section: InvoiceItems are standalone CRUD for adding charges to draft invoices; Invoice Line Items are read-only rendered rows on finalized invoices.

- **D-14e (typing):** Only `InvoiceItem.Period` (2-field: `start`, `end`) gets a typed sub-struct. All other nested objects (`pricing`, `parent`, `proration_details`, `tax_rates`) stay as `map()`.

- **D-14e (draft constraint):** Per-function `@doc` notes on create/update/delete: "Only applicable to draft invoices. Stripe returns an error for finalized invoices." Brief mention in moduledoc overview. No client-side state validation.

### Invoice Struct Field Typing

- **D-14f:** Strategic typing per D-01. Two nested objects get typed structs:
  - `Invoice.StatusTransitions` — flat 4-timestamp object (`finalized_at`, `marked_uncollectible_at`, `paid_at`, `voided_at`). High pattern-match value for lifecycle tracking.
  - `Invoice.AutomaticTax` — `enabled` flag + `status` field (critical for tax error handling: `failed`, `requires_location_inputs`). `liability` sub-field stays as `map()`.

  Everything else stays `map()`: `payment_settings` (deeply nested), `rendering`, `custom_fields`, `from_invoice`, `issuer`, `subscription_details`, `threshold_reason`, `total_discount_amounts`, `total_tax_amounts`, `customer_address`, `customer_shipping`, `shipping_details`, `shipping_cost`, `transfer_data` (Phase 17), `default_tax_rates` (future TaxRate resource), `last_finalization_error`.

  `discount`/`discounts` use existing `LatticeStripe.Discount` from Phase 12.

### Invoice Status Atomization

- **D-14g:** All 4 top-level enum fields whitelist-atomized per D-03:
  - `status` — `:draft | :open | :paid | :void | :uncollectible | String.t()`
  - `collection_method` — `:charge_automatically | :send_invoice | String.t()`
  - `billing_reason` — `:subscription_cycle | :subscription_create | :subscription_update | :subscription_threshold | :subscription | :manual | :upcoming | String.t()`
  - `customer_tax_exempt` — `:none | :exempt | :reverse | String.t()`

- **D-14g (no predicates):** No `Invoice.paid?/1`, `Invoice.draft?/1` etc. Pattern matching on atoms is idiomatic Elixir. Neither Ecto, Oban, nor Phoenix provide predicate helpers. Existing LatticeStripe modules have zero predicates.

- **D-14g (collection_method :send_invoice):** No naming collision with `send_invoice/4` function — field values and module functions are completely separate namespaces in Elixir.

### Proration Guard

- **D-14h:** Add `require_explicit_proration: false` to Client struct + Config NimbleOptions schema in Phase 14. Default `false` = zero behavior change for existing code.

- **D-14h (guard module):** Create `LatticeStripe.Billing.Guards` with `check_proration_required(client, params)` returning `:ok | {:error, %Error{type: :proration_required}}`. Phase 15 reuses the same function for Subscription/SubscriptionItem mutations — zero refactoring.

- **D-14h (scope):** Guard `upcoming/3` and `create_preview/3` only — these are the proration preview endpoints. Other Invoice mutations (create, update, finalize, pay) don't accept `proration_behavior` as a meaningful parameter. Phase 15 guards Subscription-side mutations.

- **D-14h (pre-request):** Checks `Map.has_key?(params, "proration_behavior")` before HTTP call. Stripe silently applies its default when the param is omitted — pre-request inspection is the only viable approach.

- **D-14h (error message):** Actionable message listing valid values: `"proration_behavior is required when require_explicit_proration is enabled. Valid values: \"create_prorations\", \"always_invoice\", \"none\""`. Matches NimbleOptions/Ecto pattern.

### Lifecycle Documentation

- **D-14i:** ASCII state transition table in `Invoice.@moduledoc`:
  ```
  draft → (finalize) → open → (pay) → paid
                          ↓
                        (void) → void
                          ↓
                   (mark_uncollectible) → uncollectible
  ```
  Per-function `@doc` notes for state preconditions (e.g., "Only callable on open invoices").

- **D-14i (delete):** `Invoice.delete/3` exists — `DELETE /v1/invoices/:id` is a real endpoint (works on draft invoices only). D-05 applies only to genuinely absent endpoints. `@doc` notes draft-only constraint.

- **D-14i (no client-side validation):** SDK does not validate lifecycle state pre-request. Stripe is the authority — struct status may be stale. Consistent with PaymentIntent pattern.

- **D-14i (InvoiceItem cross-reference):** InvoiceItem `@moduledoc` notes: "InvoiceItems can only be added to invoices in draft status. Once finalized, line items are locked."

### Invoice Search

- **D-14j:** `Invoice.search/3` follows established D-04/D-10 pattern. Searchable fields documented in `@doc`: `created`, `currency`, `customer`, `last_finalization_error_code`, `last_finalization_error_type`, `metadata`, `number`, `receipt_number`, `status`, `subscription`, `total`.

- **D-14j (eventual consistency):** D-10 callout verbatim.

- **D-14j (upcoming note):** One-line note: "Upcoming invoices (previews) are not searchable because they are not yet persisted objects."

### Telemetry for Action Verbs

- **D-14k:** No dedicated per-verb telemetry events. Existing `[:lattice_stripe, :request, :start | :stop]` with `:resource` and `:operation` metadata is sufficient. Users filter via `%{operation: :finalize}`.

  **Why:** Matches Ecto (one `:query` event), Oban (one `:job` event), Phoenix (one `:router_dispatch`). PaymentIntent already has confirm/capture/cancel without per-verb events. Adding per-verb events sets an unsustainable precedent.

### Guide: guides/invoices.md

- **D-14l:** Comprehensive workflow guide (~400 lines) with sections:
  1. Introduction + link to Stripe docs
  2. The Invoice Workflow (canonical create → add items → finalize → pay)
  3. Collection Methods (charge_automatically vs send_invoice)
  4. Auto-Advance Behavior (1-hour window, telemetry, why `false` gives control)
  5. Working with Invoice Items (relationship, 250-item limit, price vs price_data)
  6. Draft Invoice Management (update, delete, void, mark_uncollectible)
  7. Proration Preview (upcoming/3 and create_preview/3 workflow with examples)
  8. Subscription-Generated Invoices (automatic invoice creation, billing_reason)
  9. Testing Invoices with Test Clocks (advancing through days_until_due)
  10. Common Pitfalls (auto-advance surprise, missing items, send_invoice without days_until_due)

### Claude's Discretion

- Exact module path for nested structs (e.g., `lib/lattice_stripe/invoice/line_item.ex` vs `lib/lattice_stripe/invoice/status_transitions.ex`) — planner decides based on file-size conventions
- Whether `Invoice.AutomaticTax` `liability` sub-field stays flat `map()` or gets a trivial 2-field struct — planner's call
- Internal structure of `LatticeStripe.Billing.Guards` (module name could be `Billing.Validation` or `Billing.Guards`)
- Exact wording of lifecycle state table in moduledoc (ASCII art vs markdown table)
- Whether `upcoming_lines/3` and `create_preview_lines/3` are separate functions or share implementation via a private helper
- InvoiceItem `@known_fields` exact list — planner verifies against Stripe API docs
- Guide section ordering and exact code example depth

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 14 requirements
- `.planning/REQUIREMENTS.md` — BILL-04, BILL-04b, BILL-04c, BILL-10 requirement definitions
- `.planning/ROADMAP.md` §"Phase 14: Invoices & Invoice Line Items" — success criteria 1-5

### Phase 12-13 inherited decisions
- `.planning/phases/12-billing-catalog/12-CONTEXT.md` — D-01 (strategic typing), D-03 (atomization), D-05 (forbidden ops), D-07 (custom IDs), D-09 (FormEncoder battery), D-10 (search callout)
- `.planning/phases/13-billing-test-clocks/13-CONTEXT.md` — D-13a (namespace convention), D-13c (Error struct), D-13i (real_stripe test tier)

### v1 resource template (match this pattern)
- `lib/lattice_stripe/customer.ex` — canonical v1 resource template (struct, `@known_fields`, `from_map/1`, CRUD signatures)
- `lib/lattice_stripe/payment_intent.ex` — action verb pattern (confirm/capture/cancel at lines 295-365), search pattern
- `lib/lattice_stripe/checkout/session.ex` — `list_line_items/4`, `stream_line_items!/4` child resource access pattern
- `lib/lattice_stripe/checkout/line_item.ex` — child resource data struct precedent (LineItem under parent namespace)
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2` shared helpers
- `lib/lattice_stripe/form_encoder.ex` — form encoder (used by all CRUD)
- `lib/lattice_stripe/client.ex` — `Client` struct + `Client.request/2` entry point + Config schema
- `lib/lattice_stripe/error.ex` — `%Error{}` struct (add `:proration_required` type)
- `lib/lattice_stripe/list.ex` — List struct with `from_json/3`, pagination wrapper
- `lib/lattice_stripe/telemetry.ex` — telemetry module + `attach_default_logger/1`
- `lib/lattice_stripe/coupon.ex` — D-05 "Operations not supported" moduledoc pattern

### Existing guides (match tone and depth)
- `guides/payments.md` — PaymentIntent workflow guide (~250 lines, established format)
- `guides/checkout.md` — Checkout Session guide (established format)
- `guides/telemetry.md` — telemetry event documentation

### Stripe API references (external)
- https://docs.stripe.com/api/invoices — Invoice object, fields, endpoints
- https://docs.stripe.com/api/invoices/finalize — finalize_invoice endpoint
- https://docs.stripe.com/api/invoices/void — void endpoint
- https://docs.stripe.com/api/invoices/pay — pay endpoint
- https://docs.stripe.com/api/invoices/send — send_invoice endpoint
- https://docs.stripe.com/api/invoices/mark_uncollectible — mark_uncollectible endpoint
- https://docs.stripe.com/api/invoices/upcoming — upcoming (legacy GET)
- https://docs.stripe.com/api/invoices/create_preview — create_preview (new POST)
- https://docs.stripe.com/api/invoices/upcoming/lines — upcoming lines pagination
- https://docs.stripe.com/api/invoice-line-item/object — InvoiceLineItem object
- https://docs.stripe.com/api/invoiceitems — InvoiceItem standalone CRUD
- https://docs.stripe.com/api/invoices/search — search endpoint + query fields
- https://docs.stripe.com/search#data-freshness — eventual consistency reference (D-10)
- https://docs.stripe.com/invoicing/integration/workflow-transitions — Invoice lifecycle states

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LatticeStripe.Resource.unwrap_singular/2` and `unwrap_list/2`** — Phase 14 CRUD routes through these exactly like Customer/PaymentIntent
- **`LatticeStripe.FormEncoder.encode/1`** — handles all Phase 14 needs (including InvoiceItem params)
- **`LatticeStripe.Request` / `Client.request/2`** — unchanged; Phase 14 resources build `%Request{}` structs following v1 pattern
- **`LatticeStripe.Error`** — reused for proration guard errors (add `:proration_required` type)
- **`LatticeStripe.List`** — list response wrapper with `from_json/3` for Invoice.lines field parsing
- **`LatticeStripe.Discount`** — already typed from Phase 12, used on Invoice.discount/discounts fields
- **`LatticeStripe.Telemetry`** — `attach_default_logger/1` extended with auto-advance handler

### Established Patterns
- **Action verb pattern:** `PaymentIntent.confirm/capture/cancel` — `POST /v1/{resource}/{id}/{verb}`, uniform `(client, id, params \\ %{}, opts \\ [])`, both tuple + bang. Invoice verbs follow identically.
- **Child resource pattern:** `Checkout.Session.list_line_items/4` + `Checkout.LineItem` data struct. Invoice.list_line_items follows identically.
- **Search pattern:** `Customer.search/3` with searchable fields in `@doc` + D-10 callout. Invoice.search follows identically.
- **Atomization pattern:** Private `atomize_*` helpers with whitelist + `String.t()` catch-all. Invoice atomizes 4 fields following Phase 12 Price/Coupon precedent.
- **D-05 moduledoc pattern:** Coupon's "Operations not supported by the Stripe API" section. InvoiceItem follows for absent search.
- **String-keyed params throughout** — all resources accept `%{"field" => "value"}`. Phase 14 matches.
- **`{:ok, t()} | {:error, Error.t()}` everywhere** — no bang variants on CRUD. `stream!/2` is the only bang on list operations.

### Integration Points
- **`lib/lattice_stripe/client.ex`** — add `require_explicit_proration: false` to Client defstruct + Config NimbleOptions schema
- **`lib/lattice_stripe/error.ex`** — add `:proration_required` to type values
- **`lib/lattice_stripe/telemetry.ex`** — extend `attach_default_logger/1` to handle `[:lattice_stripe, :invoice, :auto_advance_defaulted]`
- **`mix.exs` extras config** — add `"guides/invoices.md"` to ExDoc extras list
- **New files expected:**
  - `lib/lattice_stripe/invoice.ex` + `test/lattice_stripe/invoice_test.exs`
  - `lib/lattice_stripe/invoice/line_item.ex` + test
  - `lib/lattice_stripe/invoice/status_transitions.ex` + test
  - `lib/lattice_stripe/invoice/automatic_tax.ex` + test
  - `lib/lattice_stripe/invoice_item.ex` + `test/lattice_stripe/invoice_item_test.exs`
  - `lib/lattice_stripe/invoice_item/period.ex` + test
  - `lib/lattice_stripe/billing/guards.ex` + test
  - `guides/invoices.md`
  - stripe-mock integration tests for Invoice and InvoiceItem
  - `test/real_stripe/` tests for Invoice lifecycle (optional, follows Phase 13 pattern)

</code_context>

<specifics>
## Specific Ideas

- **"Principle of least surprise"** drove the mixed verb naming (D-14a): `Invoice.finalize` reads naturally in Elixir, `Invoice.send_invoice` avoids the `Kernel.send` collision — bare verbs where safe, suffixed only where necessary.
- **"Forward-wired from Phase 15"** (roadmap SC-5) drove the decision to add `require_explicit_proration` to the Client struct in Phase 14, not defer. The guard is testable end-to-end in Phase 14.
- **Stripe API version migration** (`upcoming` → `create_preview`) drove the decision to ship both endpoints. LatticeStripe supports users on different Stripe API versions.
- **`%Invoice{id: nil}` for upcoming** matches all official Stripe SDKs (Ruby, Node, Python, Go, Java). No separate type — same struct, nil id, documented in `@doc`.
- **Auto-advance telemetry is advisory, not blocking** — the SDK creates the invoice regardless. The telemetry event + Logger warning is opt-in guidance, not a gate.
- **InvoiceItem vs Invoice.LineItem distinction** is the #1 confusion in the Stripe ecosystem. Explicit disambiguation in both modules' `@moduledoc` is the SDK's leverage point.

</specifics>

<deferred>
## Deferred Ideas

- **Shared `LatticeStripe.Address` struct** — `customer_address`, `customer_shipping`, `shipping_details` on Invoice (and `address`, `shipping` on Customer) all share an address shape. Defer to a future cross-cutting phase rather than typing piecemeal per resource.
- **`Invoice.TransferData` typed struct** — defer to Phase 17 (Connect). Simple 2-field object (`amount`, `destination`).
- **`Invoice.ShippingCost` typed struct** — borderline; defer unless shipping invoices become a focus.
- **TaxRate resource** — `default_tax_rates` on Invoice stays `list(map())` until TaxRate gets its own module in a future phase.
- **Status predicate helpers** (`Invoice.paid?/1`, `Invoice.draft?/1`) — rejected for now. Pattern matching on atoms is idiomatic. Add only if users request.
- **Per-verb telemetry events** — rejected. Existing request events with metadata filtering are sufficient. Add only if users need in-process hooks distinct from HTTP observability.
- **Client-side lifecycle state validation** — rejected. Stripe is the authority. Struct status may be stale. Document constraints, don't enforce them.
- **Proration convenience wrapper** (`Invoice.preview_proration/5`) — rejected. Raw params map matches all official SDKs. `@doc` examples provide discoverability.
- **Auto-advance suppression config** (`suppress_auto_advance_warning: true`) — deferred. Telemetry is opt-in. Add only if users request.

### Reviewed Todos (not folded)

None — `gsd-tools todo match-phase 14` returned zero matches.

</deferred>

---

*Phase: 14-invoices-invoice-line-items*
*Context gathered: 2026-04-12*
*Research: 12 parallel gsd-advisor-researchers across 3 rounds (action verbs, upcoming shape, auto-advance telemetry, line items, struct typing, atomization, proration guard, forbidden ops, search, InvoiceItem CRUD, verb telemetry, guide scope)*
