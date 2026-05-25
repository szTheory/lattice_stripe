# Phase 36: Quote - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 13
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/quote.ex` | service | request-response | `lib/lattice_stripe/credit_note.ex` | role-match |
| `lib/lattice_stripe/quote/line_item.ex` | model | transform | `lib/lattice_stripe/credit_note/line_item.ex` | role-match |
| `lib/lattice_stripe/quote/computed.ex` | model | transform | `lib/lattice_stripe/invoice/automatic_tax.ex` | role-match |
| `lib/lattice_stripe/quote/status_transitions.ex` | model | transform | `lib/lattice_stripe/invoice/status_transitions.ex` | exact |
| `lib/lattice_stripe/object_types.ex` | config | transform | `lib/lattice_stripe/object_types.ex` | exact |
| `lib/lattice_stripe/invoice.ex` | service | transform | `lib/lattice_stripe/invoice.ex` | exact |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `test/support/fixtures/quote.ex` | test | transform | `test/support/fixtures/credit_note.ex` | role-match |
| `test/lattice_stripe/object_types_test.exs` | test | transform | `test/lattice_stripe/object_types_test.exs` | exact |
| `test/lattice_stripe/quote_test.exs` | test | request-response | `test/lattice_stripe/credit_note_test.exs` | role-match |
| `test/integration/quote_integration_test.exs` | test | request-response | `test/integration/credit_note_integration_test.exs` | role-match |
| `lib/lattice_stripe/client.ex` | infrastructure | request-response | existing `download/3` implementation | exact |
| `test/lattice_stripe/client_test.exs` | infrastructure test | request-response | existing `download/3` coverage | exact |

## Pattern Assignments

### `lib/lattice_stripe/quote.ex`

**Primary analog:** `lib/lattice_stripe/credit_note.ex`  
**Supporting analogs:** `lib/lattice_stripe/invoice.ex`, `lib/lattice_stripe/dispute.ex`

- Copy the modern resource layout:
  - `@moduledoc`
  - alias block
  - `@known_fields`
  - `defstruct`
  - `@type t`
  - public API
  - `from_map/1`
  - private parse helpers
- Use `Invoice.finalize/4` as the exact shape for `Quote.finalize/4`.
- Use `Dispute.close/3` as the documentation posture for `accept/3` and `cancel/3`: explicit lifecycle consequence, thin body, no local validation.
- Keep broad nested branches raw; do not introduce deep subtrees beyond `Computed` and `StatusTransitions`.

### `lib/lattice_stripe/quote/line_item.ex`

**Primary analog:** `lib/lattice_stripe/credit_note/line_item.ex`  
**Supporting analog:** `lib/lattice_stripe/checkout/line_item.ex`

- Follow the repo’s normal nested-resource struct pattern:
  - string-key `@known_fields`
  - explicit field assignment
  - `from_map(nil), do: nil`
  - `extra` preservation
- Keep polymorphic tax/price/discount branches raw maps or lists.
- Support both embedded partial snapshots and paginated endpoint payloads with one forward-compatible struct.

### `lib/lattice_stripe/quote/computed.ex`

**Primary analog:** `lib/lattice_stripe/invoice/automatic_tax.ex`

- Keep this bounded and map-valued.
- Model only the stable high-signal branches (`upfront`, `recurring`, and similar top-level keys from the current Stripe payload); do not recursively model every nested amount or line item subtree.
- Preserve unknown keys in `extra`.

### `lib/lattice_stripe/quote/status_transitions.ex`

**Primary analog:** `lib/lattice_stripe/invoice/status_transitions.ex`

- Mirror the same tiny nested-struct shape:
  - explicit timestamp fields
  - `from_map/1`
  - `extra`

### `lib/lattice_stripe/object_types.ex` and `lib/lattice_stripe/invoice.ex`

**Analogs:** self

- Register:
  - `"quote" => LatticeStripe.Quote`
  - `"quote_line_item" => LatticeStripe.Quote.LineItem`
- Update `Invoice.from_map/1` so expanded `quote` values deserialize via the standard `is_map/1` guard pattern instead of staying raw maps or string-only.

### Line-item endpoint helpers

**Primary analogs:** `lib/lattice_stripe/checkout/session.ex`, `lib/lattice_stripe/credit_note.ex`

- Use one private helper for list endpoints and one for stream endpoints.
- Path variants should be the only difference between:
  - `/v1/quotes/:id/line_items`
  - `/v1/quotes/:id/computed_upfront_line_items`

### Binary PDF endpoint

**Primary analog:** `lib/lattice_stripe/client.ex` `download/3`

- Do not invent a second binary path.
- `Quote.pdf/3` should call `Client.download/3`, then unwrap `%Response{data: binary}` to `{:ok, binary}`.
- `Quote.pdf!/3` should delegate to `pdf/3` and raise `LatticeStripe.Error` on failure.

### Tests and fixtures

**Fixture analog:** `test/support/fixtures/credit_note.ex`  
**Unit-test analog:** `test/lattice_stripe/credit_note_test.exs`

- Use mergeable `quote_json/1` and `quote_line_item_json/1` helpers.
- Add a second helper for computed upfront line items if it improves test readability, but keep both shapes aligned with the same `Quote.LineItem` contract.
- Unit tests should explicitly cover:
  - CRUDL request paths
  - finalize/accept/cancel request paths
  - both line-item endpoint families
  - binary `pdf/3` contract
  - expanded `invoice` / `subscription` / `subscription_schedule`
  - expanded `Invoice.quote`

### Integration tests

**Primary analog:** `test/integration/credit_note_integration_test.exs`

- Keep route sanity narrow.
- Prefer create/retrieve/list/finalize plus one line-item route over trying to encode every lifecycle state transition in `stripe-mock`.
- If `stripe-mock` cannot prove a lifecycle nuance, unit tests remain the source of truth for request shape and resource-layer behavior.
