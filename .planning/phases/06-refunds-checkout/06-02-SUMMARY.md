---
phase: "06-refunds-checkout"
plan: "02"
subsystem: "checkout"
tags: ["checkout", "session", "line-items", "stripe-api", "resource"]
dependency_graph:
  requires:
    - "06-01"
    - "lib/lattice_stripe/resource.ex"
    - "lib/lattice_stripe/list.ex"
    - "lib/lattice_stripe/client.ex"
  provides:
    - "lib/lattice_stripe/checkout/session.ex"
    - "lib/lattice_stripe/checkout/line_item.ex"
  affects:
    - "test suite (427 tests total)"
tech_stack:
  added: []
  patterns:
    - "Nested-namespace module pattern (LatticeStripe.Checkout.Session)"
    - "Pre-network param validation via Resource.require_param!"
    - "Nested endpoint stream (stream_line_items!/4 via line_items sub-path)"
    - "Search stream pattern (search_stream!/3 for paginated search results)"
key_files:
  created:
    - "lib/lattice_stripe/checkout/session.ex"
    - "lib/lattice_stripe/checkout/line_item.ex"
    - "test/lattice_stripe/checkout/session_test.exs"
    - "test/support/fixtures/checkout_session.ex"
    - "test/support/fixtures/checkout_line_item.ex"
  modified: []
decisions:
  - "Checkout.Session has no update or delete functions — Stripe API constraint; expire/4 is the cancellation mechanism"
  - "mode param validated pre-network via Resource.require_param! — ArgumentError raised before any HTTP call"
  - "client_secret and PII fields (customer_email, customer_details, shipping_details) hidden from Inspect output"
  - "LineItem accessed only via list_line_items/4 and stream_line_items!/4 — no independent CRUD"
metrics:
  duration_minutes: 12
  completed_date: "2026-04-03"
  tasks_completed: 1
  files_created: 5
  files_modified: 0
  tests_added: 44
  tests_total: 427
---

# Phase 06 Plan 02: Checkout.Session and LineItem Summary

**One-liner:** Checkout.Session resource with create (3 modes + mode validation), retrieve, list, expire, search, stream, nested line_items endpoint, and typed LineItem struct with Inspect.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create LineItem struct and Checkout.Session resource module | 99dbadd | lib/lattice_stripe/checkout/line_item.ex, lib/lattice_stripe/checkout/session.ex, test/lattice_stripe/checkout/session_test.exs, test/support/fixtures/checkout_session.ex, test/support/fixtures/checkout_line_item.ex |

## What Was Built

### Checkout.Session (`lib/lattice_stripe/checkout/session.ex`)

The most complex resource in the SDK to date. Establishes the nested-namespace module pattern (`LatticeStripe.Checkout.Session`) for future sub-namespaced resources.

**Public API:**
- `create/3` — POST /v1/checkout/sessions, validates `mode` param pre-network
- `retrieve/3` — GET /v1/checkout/sessions/:id
- `list/3` — GET /v1/checkout/sessions
- `expire/4` — POST /v1/checkout/sessions/:id/expire
- `search/3` — GET /v1/checkout/sessions/search
- `stream!/3` — cursor-based auto-pagination stream
- `search_stream!/3` — search-based auto-pagination stream
- `list_line_items/4` — GET /v1/checkout/sessions/:id/line_items, returns typed `%LineItem{}`
- `stream_line_items!/4` — stream line items with auto-pagination
- Bang variants for all functions above
- `from_map/1` — decodes Stripe API response with unknown fields in `extra`
- No `update` or `delete` (Stripe API constraint)

**Inspect output:** Shows `id`, `object`, `mode`, `status`, `payment_status`, `amount_total`, `currency`. Hides `client_secret`, `customer_email`, `customer_details`, `shipping_details`.

### Checkout.LineItem (`lib/lattice_stripe/checkout/line_item.ex`)

Typed struct for line items returned by `list_line_items` and `stream_line_items!`.

**Fields:** `id`, `object`, `amount_discount`, `amount_subtotal`, `amount_tax`, `amount_total`, `currency`, `description`, `price`, `quantity`, `extra`

**Inspect output:** Shows `id`, `object`, `description`, `quantity`, `amount_total`.

### Fixtures

- `test/support/fixtures/checkout_session.ex` — 4 fixture helpers: payment, subscription, setup, and expired modes
- `test/support/fixtures/checkout_line_item.ex` — `line_item_json/1` with realistic T-Shirt item data

## Decisions Made

1. **No update or delete on Checkout.Session** — Stripe API constraint. `expire/4` is the only session state mutation available via API.
2. **mode param validated pre-network** — `Resource.require_param!(params, "mode", ...)` raises `ArgumentError` before any HTTP call. Consistent with Refund's `payment_intent` validation pattern.
3. **client_secret hidden from Inspect** — Used in embedded Checkout mode; treated as a sensitive credential, excluded from all inspect output.
4. **LineItem is read-only** — No `create`, `retrieve`, `update`, or `delete`. Accessed only through session sub-endpoints.
5. **search_stream!/3 added** — Plan specified search stream; implemented consistently with Customer.search_stream!/3 pattern.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all functions are fully wired. Line items are returned as typed `%LineItem{}` structs from the Stripe API response.

## Verification Results

- `mix test test/lattice_stripe/checkout/session_test.exs` — 44 tests, 0 failures
- `mix test` — 427 tests, 0 failures
- `mix compile --warnings-as-errors` — no warnings
- `def create` exists in session.ex
- `def expire` exists in session.ex
- `def list_line_items` exists in session.ex
- `def update` does NOT exist in session.ex
- `def delete` does NOT exist in session.ex
- `LineItem.from_map` exists in session.ex

## Self-Check: PASSED
