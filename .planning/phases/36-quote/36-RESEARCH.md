# Phase 36: Quote - Research

**Researched:** 2026-05-25
**Domain:** Stripe Quote lifecycle coverage in an Elixir SDK
**Confidence:** HIGH

## Summary

Phase 36 should ship as a two-plan resource phase:

1. Lock the Quote parser contracts, selective nested structs, object registration, Invoice back-reference handling, ExDoc grouping, and reusable fixtures.
2. Add the public Quote API surface: CRUDL, explicit lifecycle verbs, both line-item endpoint families, and binary PDF download with focused unit and integration coverage.

The phase is materially more complex than Mandate/SetupAttempt or CreditNote because it combines three distinct concerns:

- a broad top-level resource with several expandable references
- two different line-item endpoint families with different semantics
- one binary endpoint (`/v1/quotes/:id/pdf`) that must bypass the normal JSON decode path

The existing codebase already contains the critical infrastructure and analogs:

- `Client.download/3` exists and is explicitly documented as the path used by `Quote.pdf/3`
- `Checkout.Session.list_line_items/4` and `CreditNote.list_line_items/4` are direct subresource templates
- `Invoice.finalize/4` is the closest finalize-with-params action-verb pattern
- `Dispute.close/3` is the closest thin irreversible-action precedent for `accept/3` and `cancel/3`
- `ObjectTypes.maybe_deserialize/1` plus `is_map/1` guards are the established expandable-field pattern

## Locked Design Outcomes

### Public surface

- Ship `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`
- Ship explicit lifecycle verbs:
  - `finalize/4`
  - `accept/3`
  - `cancel/3`
- Ship both line-item endpoint families:
  - `list_line_items/4`, `list_line_items!/4`, `stream_line_items!/4`
  - `list_computed_upfront_line_items/4`, `list_computed_upfront_line_items!/4`, `stream_computed_upfront_line_items!/4`
- Ship binary PDF access:
  - `pdf/3` returns `{:ok, binary()} | {:error, Error.t()}`
  - `pdf!/3` returns binary or raises

### Typing depth

- Use selective typing, not a generated deep object tree
- Add dedicated:
  - `LatticeStripe.Quote.LineItem`
  - `LatticeStripe.Quote.Computed`
  - `LatticeStripe.Quote.StatusTransitions`
- Keep broad fast-moving branches raw in Phase 36:
  - `subscription_data`
  - `invoice_settings`
  - `from_quote`
- Keep `automatic_tax` raw unless execution finds a directly reusable bounded pattern that is already established elsewhere in the repo

### Expandable-field handling

These fields must use the normal `is_map/1` guard + `ObjectTypes.maybe_deserialize/1` pattern:

- `customer`
- `invoice`
- `subscription`
- `subscription_schedule`

`Invoice.from_map/1` must also stop treating `quote` as string-only when expanded.

## Endpoint Inventory

Required Stripe endpoints for this phase:

- `POST /v1/quotes`
- `GET /v1/quotes/:id`
- `POST /v1/quotes/:id`
- `GET /v1/quotes`
- `POST /v1/quotes/:id/finalize`
- `POST /v1/quotes/:id/accept`
- `POST /v1/quotes/:id/cancel`
- `GET /v1/quotes/:id/pdf`
- `GET /v1/quotes/:id/line_items`
- `GET /v1/quotes/:id/computed_upfront_line_items`

## Key Risks And Required Countermeasures

### 1. PDF endpoint is binary, not JSON

Risk:
- Reusing the normal request pipeline would try to decode the PDF body as JSON.

Required handling:
- `Quote.pdf/3` must call `Client.download/3`
- Public Quote API must unwrap `%Response{data: binary}` into raw binary before returning it
- `@doc` must state that `draft` and `canceled` quotes may 404 because Stripe only generates PDFs for shareable/finalized states

### 2. Quote has two different line-item surfaces

Risk:
- Implementing only `/line_items` hides upfront-only computed charges and creates an incorrect SDK surface.

Required handling:
- Treat both endpoints as first-class API surface in the same plan
- Reuse the same `Quote.LineItem` struct for both endpoint families
- Docs must distinguish:
  - embedded partial snapshots
  - paginated quoted-input line items
  - paginated computed upfront line items

### 3. Accept response contains expandable downstream objects

Risk:
- `invoice`, `subscription`, and `subscription_schedule` can be either string IDs or expanded objects.

Required handling:
- `Quote.from_map/1` must use `is_map/1` guards before `ObjectTypes.maybe_deserialize/1`
- tests must lock both string and expanded-map cases

## Recommended Plan Split

### Plan 01

Scope:
- `Quote`, `Quote.LineItem`, `Quote.Computed`, `Quote.StatusTransitions` parser contracts
- object registry updates
- Invoice expanded quote back-reference fix
- Billing ExDoc grouping
- reusable Quote fixtures

Why first:
- Plan 02 depends on stable `from_map/1` contracts for all public APIs and tests
- This matches the same parser-first sequencing used in Phase 34 and Phase 35

### Plan 02

Scope:
- Quote CRUDL
- lifecycle verbs
- both line-item endpoint families
- binary PDF surface
- moduledoc and `@doc` lifecycle guidance
- unit tests and targeted integration route sanity

Why second:
- It keeps the request-surface work focused and lets the tests rely on already-settled struct contracts

## Verification Strategy

- Unit tests should be the primary safety net for request shapes, bang helpers, binary PDF unwrapping, enum atomization, and expandable-field behavior.
- Integration coverage should stay narrow and route-focused:
  - retrieve/list/create/finalize when `stripe-mock` supports them cleanly
  - at least one line-item endpoint
- Existing `Client.download/3` tests already cover transport-level binary handling; Quote unit tests only need to verify the resource-layer contract that unwraps binary from `%Response{}`.

## Recommended Analogs

| Quote concern | Primary analog | Why |
|---------------|----------------|-----|
| CRUDL shell | `lib/lattice_stripe/credit_note.ex` | Modern resource layout with typed parsing and subresource helpers |
| finalize with params | `lib/lattice_stripe/invoice.ex` | Same action-verb shape and raw params passthrough |
| thin irreversible verbs | `lib/lattice_stripe/dispute.ex` | Explicit lifecycle docs for terminal operations |
| line-item endpoints | `lib/lattice_stripe/checkout/session.ex` | Clean list/stream helper pattern |
| binary download | `lib/lattice_stripe/client.ex` + `test/lattice_stripe/client_test.exs` | Existing download contract already in place |
| parser-first phase split | Phase 34 / Phase 35 plans | Matches current repo planning style |

## Execution Recommendation

Default recommendation:

- Keep `automatic_tax` raw in Phase 36
- do not add a separate Quote guide
- do not add predictive helpers
- keep all public APIs Stripe-shaped and explicit

That produces the smallest correct surface that still satisfies all five success criteria without importing Accrue-owned workflow logic.
