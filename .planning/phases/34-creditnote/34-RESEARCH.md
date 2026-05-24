# Phase 34: CreditNote - Research

**Researched:** 2026-05-24 [VERIFIED: local env]  
**Domain:** Stripe Credit Notes in an Elixir SDK (`LatticeStripe`) [VERIFIED: .planning/ROADMAP.md]  
**Confidence:** HIGH [VERIFIED: codebase grep][CITED: https://docs.stripe.com/api/credit_notes/create?lang=node][CITED: https://docs.stripe.com/api/credit_notes/list]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `CreditNote.preview/3` as the canonical preview API, not `create_preview/3`. Stripe names the endpoint as preview, the roadmap/requirements already lock `preview/3`, and adding an Invoice-style `create_preview` alias would introduce avoidable surface inconsistency. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-02:** Use `CreditNote.list_preview_line_items/3` as the canonical preview-lines API. Do not name it `preview_lines/3` or `create_preview_lines/3`; the longer name is more explicit and aligns with the existing `list_line_items/4` family. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-03:** Issued-note line items follow the existing nested-list pattern already used by `Invoice` and `Checkout.Session`: `list_line_items/4`, `list_line_items!/4`, and `stream_line_items!/4`. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-04:** Add `list_preview_line_items!/3` and `stream_preview_line_items!/3` as DX-oriented symmetry helpers even though only non-bang list access is required by the roadmap. The endpoint is paginated, the implementation cost is low, and this keeps preview-line handling coherent with the rest of the library. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-05:** `create/3` and `preview/3` both accept raw params maps and pass them through to Stripe. Do not add builders, one-off helper DSLs, or client-side enum wrappers in this phase. Credit note params are complex and evolving; the library should remain Stripe-shaped and unsurprising. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-06:** `update/4` remains a raw pass-through update entry point even though Stripe currently documents only `memo` and `metadata`. Document the narrow practical use, but do not artificially reject unknown keys client-side; Stripe drift should fail at Stripe, not inside LatticeStripe. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-07:** `void/3` is an explicit verb with signature `void(client, id, opts \\ [])`. No params map. It sends an empty `POST /v1/credit_notes/:id/void`, matching the Stripe API and the pattern established by `Dispute.close/3`. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-08:** `void/3` docs must include a dedicated `## Irreversibility` section and must clearly state the invoice-state constraint: credit notes can be created only for finalized invoices, and voiding is valid only when the credit note is attached to an open invoice. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-09:** Model one top-level `%LatticeStripe.CreditNote{}` struct plus one nested `%LatticeStripe.CreditNote.LineItem{}` struct. This is the right depth for v1.3: it captures the important developer-facing objects without exploding the API surface. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-10:** Leave aggregate or highly nested billing detail fields as raw maps/lists for now: `refunds`, `discount_amounts`, `pretax_credit_amounts`, `total_taxes`, `shipping_cost`, and nested tax-rate payloads do not get dedicated structs in this phase. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-11:** Embedded `lines` on the credit note deserialize into `%LatticeStripe.List{data: [%CreditNote.LineItem{}, ...]}` using the same nested-list pattern used by `Invoice.lines`. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-12:** Register both `"credit_note"` and `"credit_note_line_item"` in `LatticeStripe.ObjectTypes`. Top-level expandable references like `customer`, `invoice`, and `customer_balance_transaction` should use `ObjectTypes.maybe_deserialize/1` where the target type already exists. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-13:** Atomize top-level `CreditNote.status` (`issued`, `void`), `CreditNote.reason` (`duplicate`, `fraudulent`, `order_change`, `product_unsatisfactory`), and `CreditNote.type` (`pre_payment`, `post_payment`, `mixed`) at parse time with string pass-through for unknown future values. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-14:** Keep `CreditNote.LineItem.type` as a string, not an atom. This matches the existing `Invoice.LineItem` convention and avoids introducing a second line-item enum style in the same library. The developer still gets a typed struct and can branch on `"invoice_line_item"` vs `"custom_line_item"` explicitly. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-15:** Unit tests must cover both credit-note line-item subtypes: `"invoice_line_item"` and `"custom_line_item"`. This is a known footgun in Stripe’s API and should not be left to integration coverage alone. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-16:** Integration fixtures for `CreditNote.create/3` must finalize the invoice first. Add a dedicated fixture/helper for “creditable invoice” setup instead of repeating finalize logic inline across tests. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-17:** Void integration coverage must use a credit note attached to an open invoice, not a paid invoice. Tests should encode this operational precondition directly so the docs and code stay aligned. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **D-18:** Module and guide examples must emphasize the two important create/preview shapes users are most likely to get wrong:
  1. crediting an existing invoice line item
  2. creating a custom credit line item [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

### Claude's Discretion

- Exact `@known_fields` coverage breadth and field ordering within `%CreditNote{}` and `%CreditNote.LineItem{}` [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- Whether `%CreditNote{}` gets a custom `Inspect` implementation; default inspect is acceptable unless a concrete readability or secret-leak issue appears [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- Internal helper extraction boundaries for line parsing and enum atomization [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- Exact test helper naming in `test/support/fixtures/credit_note.ex` [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- ExDoc grouping placement within Billing, as long as it remains consistent with existing invoice/subscription organization [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)

None. `34-CONTEXT.md` has no deferred-ideas section. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CRDN-01 | Developer can create, retrieve, update, list credit notes with auto-pagination via `stream!/3` [VERIFIED: .planning/REQUIREMENTS.md] | Endpoint inventory, resource module shape, and list/stream patterns below map directly to `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`. [CITED: https://docs.stripe.com/api/credit_notes/create?lang=node][CITED: https://docs.stripe.com/api/credit_notes/list][VERIFIED: codebase grep] |
| CRDN-02 | Developer can void a credit note via explicit `CreditNote.void/3` verb [VERIFIED: .planning/REQUIREMENTS.md] | Explicit empty-body `POST /v1/credit_notes/:id/void`, irreversibility docs, and open-invoice warning are covered below. [CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| CRDN-03 | Developer can preview a credit note before creating via `CreditNote.preview/3` [VERIFIED: .planning/REQUIREMENTS.md] | `GET /v1/credit_notes/preview` params, signature, and return-shape guidance are covered below. [CITED: https://docs.stripe.com/api/credit_notes/preview?api-version=2025-06-30.preview][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| CRDN-04 | Developer can list and stream credit note line items via `CreditNote.list_line_items/4` and `stream_line_items!/4` [VERIFIED: .planning/REQUIREMENTS.md] | Nested-list endpoint pattern, parser target, and streaming shape are covered below. [CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl][VERIFIED: codebase grep] |
| CRDN-05 | Developer can list preview line items via `CreditNote.list_preview_line_items/3` [VERIFIED: .planning/REQUIREMENTS.md] | Preview line-item endpoint, pagination params, and symmetry helpers are covered below. [CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| CRDN-06 | Credit note line items deserialize into typed `CreditNote.LineItem` struct [VERIFIED: .planning/REQUIREMENTS.md] | Struct depth, ObjectTypes registration, `from_map/1`, and subtype coverage strategy are covered below. [CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 34 is a conventional `LatticeStripe` resource phase, not a transport phase: the repo already has the JSON request pipeline, list wrapper, pagination stream helper, and nested expandable registry needed to ship `CreditNote` without adding dependencies or infrastructure. The implementation should mirror `Invoice` for preview and line-item patterns and mirror `Dispute` for explicit irreversible verbs and narrow docs around a dangerous operation. [VERIFIED: codebase grep][VERIFIED: mix.exs]

The highest-value planning focus is not “how to talk to Stripe,” but “how to model just enough of Stripe without overshooting the phase.” The locked decisions already resolve the hard tradeoffs: raw params in, single top-level `%CreditNote{}` plus `%CreditNote.LineItem{}`, string pass-through for future enum drift, and no builder DSL or deep billing sub-struct tree. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

The biggest verification nuance is test realism. Stripe’s documentation says credit notes are created against finalized invoices and voided only on notes attached to open invoices, but a direct `stripe-mock` probe in this session accepted draft-invoice creation and returned obviously synthetic credit-note payloads; it only enforced that `void` be sent as an empty form-encoded POST. Plan integration tests accordingly: use stripe-mock for route/shape sanity, and use unit tests plus docs to enforce the real lifecycle semantics. [CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB][VERIFIED: local stripe-mock probe]

**Primary recommendation:** Plan this as one resource module, one nested line-item module, one fixture helper module, one unit test module, one integration test module, and one small docs/ExDoc sweep, all reusing the existing `Invoice` and `Dispute` patterns. [VERIFIED: codebase grep]

## Project Constraints (from CLAUDE.md)

- Project language floor is Elixir `~> 1.15`, with OTP 26+ as the documented runtime target. [VERIFIED: CLAUDE.md][VERIFIED: mix.exs]
- Typespecs are for documentation; Dialyzer is explicitly out of scope. [VERIFIED: CLAUDE.md]
- HTTP stays on the transport behaviour pattern with Finch as the default adapter; resource phases should not bypass `Client.request/2` unless transport requirements force it. CreditNote does not require such an escape hatch. [VERIFIED: CLAUDE.md][VERIFIED: codebase grep]
- JSON remains Jason-based, and dependencies should stay minimal. CreditNote needs no new Hex dependency. [VERIFIED: CLAUDE.md][VERIFIED: mix.exs]
- Public API should remain low-magic and Stripe-shaped. That aligns with the locked “raw params, no builders” decision for this phase. [VERIFIED: CLAUDE.md][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- ExDoc module grouping is centrally managed in `mix.exs`; new public modules must be placed consistently there. [VERIFIED: mix.exs]
- Research/write artifacts live under the GSD workflow, and this phase is currently the active planning target after Phase 33 completed. [VERIFIED: CLAUDE.md][VERIFIED: .planning/STATE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Credit note CRUDL (`create/retrieve/update/list/stream`) | API / Backend | Stripe API | The Elixir resource module owns function signatures, request construction, and response parsing; Stripe owns business validation and persistence. [CITED: https://docs.stripe.com/api/credit_notes/create?lang=node][CITED: https://docs.stripe.com/api/credit_notes/list][VERIFIED: codebase grep] |
| Credit note preview and preview-line listing | API / Backend | Stripe API | The repo should expose ergonomic wrappers, but the preview computation itself is a Stripe-side dry-run. [CITED: https://docs.stripe.com/api/credit_notes/preview?api-version=2025-06-30.preview][CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl] |
| Issued-note line item listing and streaming | API / Backend | Stripe API | `List.stream!/2` and `Resource.unwrap_list/2` already own client-side pagination behavior; Stripe provides the paginated endpoint. [VERIFIED: codebase grep][CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl] |
| Typed deserialization and enum handling | API / Backend | — | `from_map/1`, `%List{}`, and `ObjectTypes.maybe_deserialize/1` are pure SDK responsibilities. [VERIFIED: codebase grep] |
| Expandable-object resolution for `customer`, `invoice`, and similar refs | API / Backend | Stripe API | Stripe decides which fields can be expanded; the SDK decides whether expanded maps are deserialized via `ObjectTypes`. [CITED: https://docs.stripe.com/api/credit_notes/object][VERIFIED: codebase grep] |
| Lifecycle warnings and irreversibility docs | API / Backend | Stripe docs | The module docs must teach Stripe’s invoice-state constraints because the API surface alone does not make them obvious. [CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| `LatticeStripe.Client`, `Request`, `Resource`, `List` | existing repo stack | HTTP request construction, unwrap helpers, pagination streaming | CreditNote is a normal JSON Stripe resource and fits the existing resource pipeline with no new transport work. [VERIFIED: codebase grep] |
| `LatticeStripe.ObjectTypes` | existing repo stack | Expandable-object dispatch and nested object registration | CreditNote needs only two new registrations: `"credit_note"` and `"credit_note_line_item"`. [VERIFIED: lib/lattice_stripe/object_types.ex][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| Elixir / Mix | Mix 1.19.5 on OTP 28 in this environment | Local planning/test execution environment | The repo target remains Elixir `~> 1.15`, and the current environment is sufficient for planning and test execution. [VERIFIED: mix.exs][VERIFIED: local env] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `Mox` | `~> 1.2` in repo deps | Unit-test request-shape assertions and parser coverage | Use for every public CreditNote function and enum/expandable/forward-compat parser case. [VERIFIED: mix.exs][VERIFIED: codebase grep] |
| `stripe-mock` Docker image | `latest` in project docs; locally pulled during this research | Integration-route smoke tests against Stripe OpenAPI behavior | Use for endpoint wiring, success paths, and body-shape checks; do not trust it to enforce all invoice-state semantics for CreditNote. [VERIFIED: guides/testing.md][VERIFIED: local stripe-mock probe] |
| ExDoc | `~> 0.34` in repo deps | Public docs grouping and guide publishing | Use when adding `CreditNote` docs/examples and updating Billing group membership. [VERIFIED: mix.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw param pass-through | Builder DSL or changeset-like validator | Rejected by locked decision D-05; it would add maintenance burden and local policy drift on a fast-changing Stripe surface. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| One nested line-item struct | Deep struct tree for refunds/taxes/shipping | Rejected by locked decisions D-09 and D-10; phase scope is typed developer-facing essentials, not full billing graph modeling. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| `preview/3` naming | `create_preview/3` alias for Invoice symmetry | Rejected by locked decision D-01 to keep Stripe’s naming and avoid extra surface area. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |

**Installation:** No new dependencies are required for this phase. [VERIFIED: mix.exs][VERIFIED: codebase grep]

**Version verification:** Repo dependency constraints already include `finch ~> 0.21`, `jason ~> 1.4`, `mox ~> 1.2`, and `ex_doc ~> 0.34`; CreditNote introduces no new package to verify. [VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Caller
  |
  v
LatticeStripe.CreditNote
  |-- create/3 ------------> POST /v1/credit_notes --------------------\
  |-- retrieve/3 ----------> GET  /v1/credit_notes/:id                  |
  |-- update/4 ------------> POST /v1/credit_notes/:id                  |
  |-- list/3 + stream!/3 --> GET  /v1/credit_notes                      |
  |-- preview/3 -----------> GET  /v1/credit_notes/preview              |--> Stripe API
  |-- void/3 --------------> POST /v1/credit_notes/:id/void             |
  |-- list_line_items/4 ---> GET  /v1/credit_notes/:id/lines            |
  \-- list_preview_line_items/3 -> GET /v1/credit_notes/preview/lines --/
          |
          v
     Client.request/2
          |
          v
    Resource.unwrap_* / List.stream!
          |
          +--> singular response -> CreditNote.from_map/1
          \--> list response ----> CreditNote.LineItem.from_map/1
                                       |
                                       v
                          embedded `lines` => %LatticeStripe.List{data: [%CreditNote.LineItem{}, ...]}
```

The planner should keep request transport, response unwrap, and object parsing in the normal resource pipeline; there is no transport exception here. [VERIFIED: codebase grep]

### Recommended Project Structure

```text
lib/
├── lattice_stripe/credit_note.ex              # public resource module
└── lattice_stripe/credit_note/line_item.ex    # nested typed line-item struct

test/
├── lattice_stripe/credit_note_test.exs        # unit tests via Mox
├── integration/credit_note_integration_test.exs
└── support/fixtures/credit_note.ex            # fixture maps and invoice setup helper
```

If docs are included in-phase, add `guides/credit_notes.md` and wire it into `mix.exs` `extras`; both modules belong in the existing Billing ExDoc group. [VERIFIED: mix.exs][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

### Pattern 1: Resource Module Mirrors `Invoice` and `Dispute`

**What:** Implement CreditNote as a normal resource module with CRUDL, preview, explicit irreversible verb, list-item endpoints, bang variants, and `from_map/1`. [VERIFIED: codebase grep][CITED: https://docs.stripe.com/api/credit_notes/create?lang=node]

**When to use:** For every Stripe resource in this repo that is JSON-shaped, paginated, and does not require transport specialization. [VERIFIED: codebase grep]

**Exact endpoint inventory:**

| Function | HTTP | Path | Return parser |
|----------|------|------|---------------|
| `create/3` | `POST` | `/v1/credit_notes` | `Resource.unwrap_singular(&from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/create?lang=node] |
| `retrieve/3` | `GET` | `/v1/credit_notes/:id` | `Resource.unwrap_singular(&from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/retrieve?lang=go] |
| `update/4` | `POST` | `/v1/credit_notes/:id` | `Resource.unwrap_singular(&from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/update?lang=php] |
| `list/3` | `GET` | `/v1/credit_notes` | `Resource.unwrap_list(&from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/list] |
| `stream!/3` | `GET` | `/v1/credit_notes` | `List.stream!/2 |> Stream.map(&from_map/1)` [VERIFIED: codebase grep][CITED: https://docs.stripe.com/api/credit_notes/list] |
| `preview/3` | `GET` | `/v1/credit_notes/preview` | `Resource.unwrap_singular(&from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/preview?api-version=2025-06-30.preview] |
| `void/3` | `POST` | `/v1/credit_notes/:id/void` | `Resource.unwrap_singular(&from_map/1)` [CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB] |
| `list_line_items/4` | `GET` | `/v1/credit_notes/:id/lines` | `Resource.unwrap_list(&CreditNote.LineItem.from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl] |
| `stream_line_items!/4` | `GET` | `/v1/credit_notes/:id/lines` | `List.stream!/2 |> Stream.map(&CreditNote.LineItem.from_map/1)` [VERIFIED: codebase grep][CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl] |
| `list_preview_line_items/3` | `GET` | `/v1/credit_notes/preview/lines` | `Resource.unwrap_list(&CreditNote.LineItem.from_map/1)` [CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl] |
| `stream_preview_line_items!/3` | `GET` | `/v1/credit_notes/preview/lines` | `List.stream!/2 |> Stream.map(&CreditNote.LineItem.from_map/1)` [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md][VERIFIED: codebase grep] |

**Example:**

```elixir
# Source: local Invoice/Dispute resource patterns + Stripe Credit Note endpoints
@spec void(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def void(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/credit_notes/#{id}/void", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

This is the same empty-param explicit-verb pattern already used by `Dispute.close/3`. [VERIFIED: lib/lattice_stripe/dispute.ex]

### Pattern 2: Minimal Typed Struct Depth, Maximum Forward Compatibility

**What:** Give `CreditNote` and `CreditNote.LineItem` typed structs with `@known_fields` and `extra`, but leave aggregate billing branches as raw maps/lists. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**When to use:** When Stripe responses are wide and partially polymorphic, but the phase only needs the top-level object plus the developer-visible nested subtype. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Required top-level fields to prioritize:**

- `id`, `object`, `amount`, `amount_shipping`, `created`, `currency`, `customer`, `customer_balance_transaction`, `effective_at`, `invoice`, `lines`, `livemode`, `memo`, `metadata`, `number`, `out_of_band_amount`, `pdf`, `pre_payment_amount`, `post_payment_amount`, `reason`, `refunds`, `shipping_cost`, `status`, `subtotal`, `subtotal_excluding_tax`, `total`, `total_excluding_tax`, `total_taxes`, `type`, `voided_at`, and `extra`. [CITED: https://docs.stripe.com/api/credit_notes/object][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Required line-item fields to prioritize:**

- `id`, `object`, `amount`, `description`, `discount_amount`, `discount_amounts`, `invoice_line_item`, `livemode`, `pretax_credit_amounts`, `quantity`, `tax_rates`, `taxes`, `type`, `unit_amount`, `unit_amount_decimal`, and `extra`. [CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl][VERIFIED: local stripe-mock probe]

**Example:**

```elixir
# Source: Stripe Credit Note line-item object + local Invoice.LineItem pattern
def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)

  %__MODULE__{
    id: known["id"],
    object: known["object"] || "credit_note_line_item",
    amount: known["amount"],
    description: known["description"],
    invoice_line_item: known["invoice_line_item"],
    quantity: known["quantity"],
    tax_rates: known["tax_rates"],
    taxes: known["taxes"],
    type: known["type"],
    unit_amount: known["unit_amount"],
    unit_amount_decimal: known["unit_amount_decimal"],
    extra: extra
  }
end
```

### Pattern 3: Atomize Only Stable Top-Level Enums

**What:** Atomize `CreditNote.status`, `CreditNote.reason`, and `CreditNote.type` with string pass-through for unknown future values; keep `CreditNote.LineItem.type` as a string. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**When to use:** When the repo already atomizes stable top-level Stripe enums but leaves subtype strings intact where local code benefits from explicit string branching. [VERIFIED: lib/lattice_stripe/invoice/line_item.ex][VERIFIED: lib/lattice_stripe/dispute.ex]

**Known enum sets from Stripe docs:**

- `status`: `issued`, `void`. [CITED: https://docs.stripe.com/api/credit_notes/object]
- `reason`: `duplicate`, `fraudulent`, `order_change`, `product_unsatisfactory`. [CITED: https://docs.stripe.com/api/credit_notes/create?lang=node]
- `type`: `pre_payment`, `post_payment`, `mixed`. [CITED: https://docs.stripe.com/api/credit_notes/object]
- `line_item.type`: `invoice_line_item`, `custom_line_item`. Keep as string. [CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

### Pattern 4: Embedded Lists Deserialize the Same Way as `Invoice.lines`

**What:** `CreditNote.from_map/1` should parse embedded `lines` into `%LatticeStripe.List{data: [%CreditNote.LineItem{}, ...]}` rather than leaving it as a raw map or untyped list. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**When to use:** When Stripe returns the first page of a child collection embedded in a parent resource and also exposes a full child-list endpoint. [CITED: https://docs.stripe.com/api/credit_notes/object][VERIFIED: lib/lattice_stripe/invoice.ex]

**Anti-Patterns to Avoid**

- **Builder creep:** Do not add builders or validation DSLs for CreditNote params in this phase. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **Deep-struct explosion:** Do not introduce structs for refund rows, tax rows, or shipping-cost shapes yet. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **Atomizing line-item subtype strings:** Keep line-item `type` as a string to match existing `Invoice.LineItem` conventions. [VERIFIED: lib/lattice_stripe/invoice/line_item.ex][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **Client-side rejection of unknown update params:** Let Stripe reject unsupported keys on `update/4`. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- **Assuming stripe-mock proves invoice-state semantics:** It does not for CreditNote. [VERIFIED: local stripe-mock probe]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Credit note param DSL | Custom builder/validator layer | Raw params map pass-through | Stripe’s parameter surface is large and evolving, and D-05 explicitly locks the low-magic approach. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| Pagination for line items | Manual cursor loop in CreditNote | Existing `List.stream!/2` pipeline | The repo already has the canonical auto-pagination abstraction used by `Invoice` and `Checkout.Session`. [VERIFIED: codebase grep] |
| Expandable-object switch logic | Per-field ad hoc case statements | `ObjectTypes.maybe_deserialize/1` | That is the repo-standard path for expanded refs. [VERIFIED: lib/lattice_stripe/object_types.ex][VERIFIED: codebase grep] |
| Full refund/tax sub-graph modeling | Many nested structs now | Raw maps/lists plus `extra` | D-10 keeps the phase narrow while preserving forward compatibility. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| CreditNote-specific docs grouping | One-off custom ExDoc group | Existing Billing module group | Billing is already the public docs home for invoice-adjacent resources. [VERIFIED: mix.exs] |

**Key insight:** This phase should add breadth, not infrastructure. Every time planning starts to invent new abstractions, it is probably moving against both the repo’s architecture and the locked discuss-phase decisions. [VERIFIED: CLAUDE.md][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Treating `stripe-mock` as a Source of Truth for Invoice-State Semantics

**What goes wrong:** Integration tests pass even when they violate the documented “finalized invoice” precondition for credit-note creation. [VERIFIED: local stripe-mock probe][CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB]

**Why it happens:** `stripe-mock` accepted draft-invoice credit-note creation in this session and returned synthetic payloads with unrealistic field values. [VERIFIED: local stripe-mock probe]

**How to avoid:** Encode real lifecycle constraints in module docs, fixture naming, and unit-test expectations; use stripe-mock only for route/shape coverage here. [VERIFIED: local stripe-mock probe][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Warning signs:** A passing integration test creates a draft invoice and immediately issues a credit note. [VERIFIED: local stripe-mock probe]

### Pitfall 2: Sending `void/3` Without an Empty Form Body

**What goes wrong:** `POST /v1/credit_notes/:id/void` can fail in stripe-mock if the request omits a form-encoded body entirely. [VERIFIED: local stripe-mock probe]

**Why it happens:** Stripe’s API has no business params for `void`, but the HTTP client still needs to send the request in the same `application/x-www-form-urlencoded` style as other POSTs. [VERIFIED: local stripe-mock probe][VERIFIED: codebase grep]

**How to avoid:** Follow the `Dispute.close/3` pattern: explicit verb, `params: %{}`, and route through the normal `Client.request/2` form encoding path. [VERIFIED: lib/lattice_stripe/dispute.ex]

**Warning signs:** Raw transport tests show an empty `Content-Type` or missing body on the `void` route. [VERIFIED: local stripe-mock probe]

### Pitfall 3: Missing the Two Line-Item Creation Subtypes

**What goes wrong:** Developers mix `invoice_line_item` and `custom_line_item` fields and hit Stripe validation errors. [CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl][CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB]

**Why it happens:** Stripe’s line-item model is conditional on `lines[n][type]`, and the two shapes are incompatible. [CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl]

**How to avoid:** Keep `create/3` and `preview/3` raw, but make unit tests and docs show both minimal valid shapes. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Warning signs:** Only one subtype appears in tests or examples. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

### Pitfall 4: Leaving Embedded `lines` Untyped

**What goes wrong:** `CreditNote.from_map/1` can return raw maps inside `lines.data`, which breaks parity with `Invoice` and forces callers to branch on raw JSON. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md][VERIFIED: lib/lattice_stripe/invoice.ex]

**Why it happens:** It is easy to implement top-level `list_line_items/4` and forget that the parent object also carries a first page of line items. [CITED: https://docs.stripe.com/api/credit_notes/object]

**How to avoid:** Parse embedded `lines` through the same list parser used for the child endpoint. [VERIFIED: lib/lattice_stripe/invoice.ex][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Warning signs:** Unit tests only cover the standalone `/lines` endpoints. [VERIFIED: codebase grep]

### Pitfall 5: Over-modeling Billing Aggregates Too Early

**What goes wrong:** Planning balloons into many nested structs for refunds, taxes, and shipping details that the current phase does not require. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Why it happens:** Credit Note responses are wide, and stripe-mock returns many populated branches even on trivial requests. [VERIFIED: local stripe-mock probe]

**How to avoid:** Keep the contract narrow: `CreditNote` and `CreditNote.LineItem` only, with `extra` preserving unknown data. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

**Warning signs:** Planner work items mention more than two new public struct modules. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]

## Code Examples

Verified patterns from official sources and existing local modules:

### `void/3` Should Match the Existing Irreversible-Verb Pattern

```elixir
# Source: local Dispute.close/3 + Stripe void endpoint
@spec void(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def void(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/credit_notes/#{id}/void", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

Source basis: `Dispute.close/3` in the repo and `POST /v1/credit_notes/:id/void` in Stripe’s docs. [VERIFIED: lib/lattice_stripe/dispute.ex][CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB]

### Preview Example: Existing Invoice Line Item

```elixir
# Source: locked phase examples + Stripe programmatic credit-note docs
CreditNote.preview(client, %{
  "invoice" => "in_123",
  "lines" => [
    %{
      "type" => "invoice_line_item",
      "invoice_line_item" => "il_123",
      "quantity" => 1
    }
  ]
})
```

Source basis: locked phase examples and Stripe’s documented quantity-based invoice-line-item credit flow. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md][CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB]

### Create Example: Custom Credit Line Item

```elixir
# Source: locked phase examples + Stripe custom_line_item docs
CreditNote.create(client, %{
  "invoice" => "in_123",
  "lines" => [
    %{
      "type" => "custom_line_item",
      "description" => "Goodwill credit",
      "quantity" => 1,
      "unit_amount" => 500
    }
  ],
  "memo" => "Applied after support review"
})
```

Source basis: locked phase examples and Stripe’s `custom_line_item` rules. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md][CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB][CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Alias-heavy preview naming (`create_preview`, `preview_lines`) | Stripe-shaped `preview/3` and explicit `list_preview_line_items/3` | Locked for Phase 34 on 2026-05-24 in discuss-phase context | The planner should not schedule naming aliases or compatibility shims. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| Deeper sub-struct modeling for every nested billing branch | Two-module public model (`CreditNote` + `CreditNote.LineItem`) | Locked for Phase 34 on 2026-05-24 | Keeps scope aligned with v1.3 breadth goals and reduces future API churn. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| Assuming integration harnesses prove lifecycle semantics | Separate “Stripe docs truth” from “stripe-mock behavior” | Verified in this session | Planner should require docs/unit coverage for finalized/open semantics instead of trusting integration alone. [VERIFIED: local stripe-mock probe][CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB] |

**Deprecated/outdated:**

- `preview_lines/3` and `create_preview_lines/3` naming for this phase are out of scope under the locked decisions. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- A plain-map `lines.data` representation is below the repo’s current typing standard for invoice-adjacent resources. [VERIFIED: lib/lattice_stripe/invoice.ex]

## Assumptions Log

All claims in this research were verified locally or cited from official Stripe documentation. No user confirmation is needed before planning. [VERIFIED: codebase grep][CITED: https://docs.stripe.com/api/credit_notes/create?lang=node]

## Open Questions

1. **Should docs land in Phase 34 or wait for Phase 37’s guide sweep?**
   - What we know: `mix.exs` already publishes guides through `extras`, and D-18 requires module and guide examples for the two common create/preview shapes. [VERIFIED: mix.exs][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
   - What's unclear: Whether the planner wants a new `guides/credit_notes.md` now or a narrower moduledoc-only scope with the dedicated guide deferred to Phase 37. [ASSUMED]
   - Recommendation: Keep at least moduledoc examples in Phase 34, and add a small guide now if it fits without displacing test work. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` / Elixir | Unit tests, integration tests, docs generation | ✓ | Mix 1.19.5 / OTP 28 in this environment | — [VERIFIED: local env] |
| Docker | `stripe-mock` integration tests | ✓ | Docker 29.4.1 | Skip integration tests if unavailable, but that would leave a phase gap. [VERIFIED: local env] |
| `stripe-mock` image | CreditNote integration route checks | ✓ | `stripe/stripe-mock:latest` pulled successfully during this session | None inside the repo; without it, only unit tests run. [VERIFIED: local stripe-mock probe] |
| Node / npm | Existing repo tooling and optional docs lookup fallback | ✓ | Node 22.14.0 / npm 11.1.0 | Not needed for CreditNote implementation itself. [VERIFIED: local env] |

**Missing dependencies with no fallback:** None. [VERIFIED: local env]

**Missing dependencies with fallback:** None. [VERIFIED: local env]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox for unit tests and `stripe-mock` for integration. [VERIFIED: mix.exs][VERIFIED: guides/testing.md] |
| Config file | none; test support is wired through `elixirc_paths(:test)` in `mix.exs`. [VERIFIED: mix.exs] |
| Quick run command | `mix test test/lattice_stripe/credit_note_test.exs` [ASSUMED] |
| Full suite command | `mix ci` [VERIFIED: mix.exs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CRDN-01 | CRUDL + `stream!/3` for CreditNote | unit + integration | `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` | ❌ Wave 0 [VERIFIED: codebase grep] |
| CRDN-02 | explicit `void/3` verb with empty-body POST | unit + integration | `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` | ❌ Wave 0 [VERIFIED: codebase grep] |
| CRDN-03 | preview via `preview/3` | unit + integration | `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` | ❌ Wave 0 [VERIFIED: codebase grep] |
| CRDN-04 | issued-note line-item list and stream | unit + integration | `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` | ❌ Wave 0 [VERIFIED: codebase grep] |
| CRDN-05 | preview-line listing (plus locked symmetry helpers) | unit + integration | `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` | ❌ Wave 0 [VERIFIED: codebase grep] |
| CRDN-06 | typed `%CreditNote.LineItem{}` deserialization | unit | `mix test test/lattice_stripe/credit_note_test.exs` | ❌ Wave 0 [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/credit_note_test.exs` [ASSUMED]
- **Per wave merge:** `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` [ASSUMED]
- **Phase gate:** `mix ci` [VERIFIED: mix.exs]

### Wave 0 Gaps

- [ ] `test/lattice_stripe/credit_note_test.exs` — public API, parser, enum pass-through, embedded `lines`, expandables, bang variants. [VERIFIED: codebase grep]
- [ ] `test/integration/credit_note_integration_test.exs` — route sanity for create/retrieve/update/list/preview/void/line-items/preview-line-items. [VERIFIED: codebase grep]
- [ ] `test/support/fixtures/credit_note.ex` — fixture maps for top-level note and both line-item subtypes, plus a finalized-invoice helper. [VERIFIED: codebase grep][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md]
- [ ] `test/lattice_stripe/object_types_test.exs` additions — `"credit_note"` and `"credit_note_line_item"` dispatch coverage. [VERIFIED: lib/lattice_stripe/object_types.ex][VERIFIED: test/lattice_stripe/object_types_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | The SDK passes Stripe API keys through existing `Client` configuration; Phase 34 adds no auth flow. [VERIFIED: CLAUDE.md][VERIFIED: codebase grep] |
| V3 Session Management | no | This library phase has no session concept. [VERIFIED: codebase grep] |
| V4 Access Control | no | This is an SDK wrapper over Stripe endpoints, not an application authorization layer. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Keep local validation minimal and rely on Stripe plus typed parsing; only shape the explicit `void/3` signature. [VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md][VERIFIED: codebase grep] |
| V6 Cryptography | no | CreditNote adds no cryptographic behavior. [VERIFIED: codebase grep] |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Logging or exposing irreversible action without warning | Repudiation | Dedicated `## Irreversibility` docs on `void/3`, mirroring `Dispute.close/3` style. [VERIFIED: lib/lattice_stripe/dispute.ex][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |
| Silent loss of future Stripe fields | Tampering | Preserve unknown keys in `extra` on both structs. [VERIFIED: lib/lattice_stripe/invoice/line_item.ex][VERIFIED: lib/lattice_stripe/dispute.ex] |
| Mis-deserializing expanded references as raw maps | Tampering | Route expanded top-level refs through `ObjectTypes.maybe_deserialize/1`. [VERIFIED: lib/lattice_stripe/object_types.ex][VERIFIED: .planning/phases/34-creditnote/34-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- [Stripe Credit Note create API](https://docs.stripe.com/api/credit_notes/create?lang=node) - create endpoint, top-level field inventory, update section, enum values. [CITED: https://docs.stripe.com/api/credit_notes/create?lang=node]
- [Stripe Credit Note object](https://docs.stripe.com/api/credit_notes/object) - top-level object shape and embedded `lines`. [CITED: https://docs.stripe.com/api/credit_notes/object]
- [Stripe Credit Note line item object](https://docs.stripe.com/api/credit_notes/line_item?lang=curl) - line-item field inventory and subtype enum values. [CITED: https://docs.stripe.com/api/credit_notes/line_item?lang=curl]
- [Stripe Credit Note list API](https://docs.stripe.com/api/credit_notes/list) - list filters and pagination. [CITED: https://docs.stripe.com/api/credit_notes/list]
- [Stripe Credit Note preview-lines API](https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl) - preview-lines params and conditional line-item shapes. [CITED: https://docs.stripe.com/api/credit_notes/preview_lines?lang=curl]
- [Stripe programmatic credit notes guide](https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB) - finalized/open invoice semantics, custom-line-item guidance, and void rule. [CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB]
- Local codebase: `lib/lattice_stripe/invoice.ex`, `lib/lattice_stripe/invoice/line_item.ex`, `lib/lattice_stripe/dispute.ex`, `lib/lattice_stripe/object_types.ex`, `mix.exs`, and existing tests/fixtures. [VERIFIED: codebase grep]
- Local `stripe-mock` probe run on 2026-05-24 against Docker `stripe/stripe-mock:latest`. [VERIFIED: local stripe-mock probe]

### Secondary (MEDIUM confidence)

- [Stripe dashboard credit notes guide](https://docs.stripe.com/invoicing/dashboard/credit-notes) - operational explanations for open vs paid invoice credits and voiding. [CITED: https://docs.stripe.com/invoicing/dashboard/credit-notes]

### Tertiary (LOW confidence)

None. [VERIFIED: research session]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - no new dependencies, and the phase fits the existing repo pipeline directly. [VERIFIED: mix.exs][VERIFIED: codebase grep]
- Architecture: HIGH - local `Invoice` and `Dispute` analogs map cleanly to the required CreditNote surface. [VERIFIED: codebase grep]
- Pitfalls: HIGH - Stripe’s official lifecycle docs were cross-checked against a local `stripe-mock` probe, which exposed exactly where integration confidence is weaker. [CITED: https://docs.stripe.com/invoicing/integration/programmatic-credit-notes?locale=en-GB][VERIFIED: local stripe-mock probe]

**Research date:** 2026-05-24 [VERIFIED: local env]  
**Valid until:** 2026-06-23 for repo-pattern guidance; re-check Stripe docs sooner if Stripe changes credit-note params or lifecycle text. [CITED: https://docs.stripe.com/api/credit_notes/create?lang=node]
