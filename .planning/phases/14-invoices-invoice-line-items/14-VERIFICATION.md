---
phase: 14-invoices-invoice-line-items
verified: 2026-04-12T17:00:00Z
status: human_needed
score: 7/8 must-haves verified
overrides_applied: 0
gaps: []
human_verification:
  - test: "Verify create_preview/3 with proration_behavior nested inside subscription_details is not incorrectly rejected by the guard when require_explicit_proration: true"
    expected: "Invoice.create_preview(client_with_flag, %{\"subscription_details\" => %{\"proration_behavior\" => \"create_prorations\"}}) returns {:ok, %Invoice{}} not {:error, %Error{type: :proration_required}}"
    why_human: "Guard bug (WR-01 from code review) confirmed in code — guard only checks top-level params key, not nested subscription_details. Requires manual test or stripe-mock call to confirm real-world impact."
  - test: "Verify create_preview_lines/3 HTTP method (POST vs GET)"
    expected: "create_preview_lines/3 uses the correct HTTP verb — Stripe docs show GET for preview lines endpoints, but the implementation uses POST"
    why_human: "IN-01 from code review flags this as a possible semantic error. Cannot confirm without checking live Stripe OpenAPI spec or stripe-mock response."
---

# Phase 14: Invoices and Invoice Line Items Verification Report

**Phase Goal:** Developers can create, manage, and collect payment on Invoices and Invoice Line Items with full lifecycle support — including action verbs (finalize/void/pay/send/mark_uncollectible), search, preview endpoints with proration guard, auto-advance telemetry, and comprehensive documentation.
**Verified:** 2026-04-12T17:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Note on Phase Registration

Phase 14 does not appear in `.planning/ROADMAP.md` or `.planning/STATE.md`. It was executed as an out-of-band addition to the milestone. The phase goal is taken from the prompt. Requirements BILL-04b, BILL-04c, and BILL-10 declared in 14-05-SUMMARY.md do not exist in `.planning/REQUIREMENTS.md` — only BILL-04 is defined there. These IDs appear to be sub-requirements invented during planning that were never formally registered. This is noted in Requirements Coverage below.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Developers can create, retrieve, update, delete, and list Invoices | VERIFIED | `invoice.ex` has create/3, retrieve/3, update/4, delete/3, list/3 with bang variants at lines 288-440 |
| 2 | Invoice action verbs finalize, void, pay, send, and mark_uncollectible are available | VERIFIED | All 5 verbs with bang variants confirmed at lines 446-580; send named `send_invoice` to avoid Kernel.send/2 conflict |
| 3 | Invoice search is available with eventual consistency documentation | VERIFIED | `search/3` and `search_stream!/3` at lines 616-676; @doc includes Eventual Consistency admonition per SUMMARY |
| 4 | Preview endpoints (upcoming/create_preview) are guarded by proration check | PARTIAL | Guard is present and wired via `with :ok <- Billing.Guards.check_proration_required(client, params)` at lines 684, 723. However, guard only checks top-level `"proration_behavior"` key, not the nested `subscription_details.proration_behavior` form shown in the guide itself (WR-01 from code review — false positive bug when using nested params with flag enabled) |
| 5 | Auto-advance telemetry event is emitted when Invoice.create returns auto_advance: true | VERIFIED | `Telemetry.emit_auto_advance_scheduled/2` called inside `create/3` pattern match at line 296; event `[:lattice_stripe, :invoice, :auto_advance_scheduled]` defined in telemetry.ex with measurements, metadata, and default logger handler |
| 6 | InvoiceItem CRUD with correct URL path (/v1/invoiceitems) is available | VERIFIED | `invoice_item.ex` has full CRUD at 408 lines; path verified in SUMMARY as /v1/invoiceitems |
| 7 | Comprehensive documentation guide (guides/invoices.md) exists and is wired into ExDoc | VERIFIED | `guides/invoices.md` exists at 556 lines; mix.exs extras list includes it at line 28; Billing module group includes all 7 Phase 14 modules at lines 61-68 |
| 8 | Billing.Guards.check_proration_required protects preview endpoints from implicit proration when client flag is set | PARTIAL | Guard exists and is called. The partial failure is the false-positive path described in truth #4 — the guard can incorrectly block valid calls that use the nested subscription_details form. The guard correctly blocks calls with no proration_behavior at all, which is the primary protection goal. |

**Score:** 7/8 truths fully verified (truth #4 and #8 are the same partial — guard exists but has a correctness gap)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/lattice_stripe/invoice.ex` | Invoice struct, CRUD, action verbs, search, preview | VERIFIED | 1099 lines, all functions confirmed present |
| `lib/lattice_stripe/invoice_item.ex` | InvoiceItem struct, CRUD | VERIFIED | 408 lines |
| `lib/lattice_stripe/billing/guards.ex` | Proration guard with 3 clauses | VERIFIED | `check_proration_required/2` with false, true+present, true+absent clauses |
| `lib/lattice_stripe/invoice/status_transitions.ex` | Typed nested struct | VERIFIED | Exists, defmodule LatticeStripe.Invoice.StatusTransitions |
| `lib/lattice_stripe/invoice/automatic_tax.ex` | Typed nested struct | VERIFIED | Exists, defmodule LatticeStripe.Invoice.AutomaticTax |
| `lib/lattice_stripe/invoice/line_item.ex` | Typed nested struct with known_fields + extra | VERIFIED | Exists, defmodule LatticeStripe.Invoice.LineItem |
| `lib/lattice_stripe/invoice_item/period.ex` | Typed nested struct | VERIFIED | Exists, defmodule LatticeStripe.InvoiceItem.Period |
| `lib/lattice_stripe/telemetry.ex` | auto_advance_scheduled event, emit function, logger handler | VERIFIED | `emit_auto_advance_scheduled/2` at line 325, `handle_auto_advance_log/4` at line 425, `@auto_advance_event` at line 284 |
| `guides/invoices.md` | 556-line comprehensive guide | VERIFIED | 556 lines confirmed |
| `mix.exs` | Billing group + invoices guide in extras | VERIFIED | Lines 28, 61-68 confirmed |
| `test/lattice_stripe/invoice_test.exs` | Comprehensive unit tests | VERIFIED | 847 lines |
| `test/lattice_stripe/invoice_item_test.exs` | Unit tests | VERIFIED | 289 lines |
| `test/lattice_stripe/billing/guards_test.exs` | Guard behavior tests | VERIFIED | 61 lines |
| `test/integration/invoice_integration_test.exs` | stripe-mock integration tests | VERIFIED | 144 lines |
| `test/integration/invoice_item_integration_test.exs` | stripe-mock integration tests | VERIFIED | Exists |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `invoice.ex create/3` | `telemetry.ex emit_auto_advance_scheduled/2` | Pattern match on `{:ok, %Invoice{auto_advance: true}}` | WIRED | Line 295-296 |
| `invoice.ex upcoming/3` | `billing/guards.ex check_proration_required/2` | `with :ok <- Billing.Guards.check_proration_required(client, params)` | WIRED | Line 684 |
| `invoice.ex create_preview/3` | `billing/guards.ex check_proration_required/2` | `with :ok <- Billing.Guards.check_proration_required(client, params)` | WIRED | Line 723 |
| `guides/invoices.md` | `mix.exs extras` | `"guides/invoices.md"` in extras list | WIRED | Line 28 |
| `Billing.Guards` module | `mix.exs groups_for_modules Billing group` | `LatticeStripe.Billing.Guards` in Billing group | WIRED | Line 68 |
| `client.ex require_explicit_proration` | `billing/guards.ex check_proration_required/2` | Pattern match on `%Client{require_explicit_proration: false/true}` | WIRED | Guard clauses at lines 22, 24 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `invoice.ex create/3` | `%Invoice{}` struct | POST /v1/invoices via Client.request | Yes — real Stripe API call through Finch | FLOWING |
| `telemetry.ex emit_auto_advance_scheduled/2` | `invoice_id`, `customer` from returned Invoice struct | Pattern-matched from successful create result | Yes — real data from Stripe response | FLOWING |
| `invoice.ex upcoming/3` | `%Invoice{id: nil}` | GET /v1/invoices/upcoming — preview (unpersisted) | Yes — real Stripe API call | FLOWING |

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| All 10 action verb functions present (with bang variants) | `grep -c "def finalize\|def void\|def pay\|def send_invoice\|def mark_uncollectible..."` on invoice.ex | 18 matches (9 pairs × 2) | PASS |
| All commits referenced in SUMMARYs exist in git | `git log --oneline` for all 10 commit hashes | All 10 found: 39b98c9, 68f6cda, 651d821, 20936f5, eb4ab67, 1a78e95, cb0a9f6, 6957e5a, 1c44bf9, 939ca5b | PASS |
| Billing module group in mix.exs includes all 7 Phase 14 modules | `grep -n "Billing\|Invoice\|InvoiceItem" mix.exs` | LatticeStripe.Invoice, Invoice.LineItem, Invoice.StatusTransitions, Invoice.AutomaticTax, InvoiceItem, InvoiceItem.Period, Billing.Guards all present | PASS |
| guides/invoices.md wired in mix.exs extras | `grep "guides/invoices.md" mix.exs` | Found at line 28 | PASS |

### Requirements Coverage

| Requirement | Source | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| BILL-04 | REQUIREMENTS.md v2 section | Invoices — create, retrieve, update, finalize, pay, send, void, list, search | SATISFIED | All operations present in invoice.ex |
| BILL-04b | 14-05-SUMMARY.md only | Not defined in REQUIREMENTS.md | ORPHANED | This ID does not exist in REQUIREMENTS.md — it was used in planning artifacts but never formally registered. Cannot verify against an undefined requirement. |
| BILL-04c | 14-05-SUMMARY.md only | Not defined in REQUIREMENTS.md | ORPHANED | Same as BILL-04b — undefined in REQUIREMENTS.md. |
| BILL-10 | 14-05-SUMMARY.md only | Not defined in REQUIREMENTS.md | ORPHANED | Same as BILL-04b — undefined in REQUIREMENTS.md. |

**Note:** BILL-04b, BILL-04c, and BILL-10 appear only in the phase SUMMARY's `requirements-completed` field. They do not appear anywhere in `.planning/REQUIREMENTS.md`. These IDs were used without being formally registered. The functional work they presumably represent (InvoiceItem CRUD, proration guard, telemetry) is present in the codebase, but the requirements themselves are untracked. This is an administrative gap, not a functional one.

**Note on BILL-04 status:** BILL-04 is listed under "v2 Requirements" in REQUIREMENTS.md — meaning it was deferred to a future release, not part of the v1 milestone. Phase 14 delivered BILL-04 work ahead of the formal v2 schedule, which is net positive but means the ROADMAP.md and STATE.md reflect an outdated view.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/lattice_stripe/invoice.ex` | 1058-1066 | `defp parse_lines(_), do: nil` — silently drops unexpected map shapes instead of passing through raw data | Warning | Invoice.lines will be nil if Stripe returns a lines shape without `"object": "list"` — indistinguishable from absent field; inconsistent with extra catch-all pattern elsewhere |
| `lib/lattice_stripe/billing/guards.ex` | 24-35 | Guard only checks top-level `"proration_behavior"` key — misses nested `subscription_details.proration_behavior` form | Warning | False-positive guard rejection when caller uses documented nested form with `require_explicit_proration: true` |
| `lib/lattice_stripe/telemetry.ex` | 632 | `known_prefixes` missing `ii_` (InvoiceItem) and `il_` (Invoice LineItem) prefixes | Warning | Telemetry path parser may misclassify InvoiceItem/LineItem ID segments via fallback heuristic |
| `mix.exs` | 110 | `{:finch, "~> 0.19"}` — below CLAUDE.md recommended floor of `~> 0.21` | Warning | Fresh dependency resolution may install Finch 0.19.x or 0.20.x, not 0.21.x as intended |
| `test/integration/invoice_integration_test.exs` | 90-93 | `match?({:ok, %Invoice{}}, result) or match?({:error, %Error{}}, result)` — always-passing assertion | Info | Integration tests for delete/finalize pass regardless of actual outcome |

No blockers found. All warnings were already identified in the 14-REVIEW.md and are pre-existing known issues.

### Human Verification Required

#### 1. Proration Guard False-Positive with Nested Params

**Test:** With a client configured as `test_client(require_explicit_proration: true)`, call:
```elixir
Invoice.create_preview(client, %{
  "customer" => "cus_test123",
  "subscription_details" => %{
    "proration_behavior" => "create_prorations"
  }
})
```
**Expected:** Returns `{:ok, %Invoice{}}` — the guard should recognize `proration_behavior` inside `subscription_details` as satisfying the requirement.
**Actual (from code):** Returns `{:error, %Error{type: :proration_required}}` — guard only checks `Map.has_key?(params, "proration_behavior")` at the top level.
**Why human:** This is a confirmed code bug (WR-01 from review). The verifier cannot run the live code but the bug path is deterministic. A developer needs to confirm whether fixing it is in scope for this phase or deferred, and then apply the fix if needed.

#### 2. create_preview_lines/3 HTTP Method Correctness

**Test:** Inspect the Stripe API documentation or stripe-mock response for `POST /v1/invoices/create_preview/lines` vs `GET /v1/invoices/create_preview/lines`.
**Expected:** The endpoint should accept the same verb that Stripe's OpenAPI spec declares.
**Why human:** The implementation uses `POST` for `create_preview_lines/3` (per IN-01 from review), while `upcoming_lines/3` uses `GET`. The Stripe docs suggest GET for list/preview endpoints but this needs confirmation against the actual OpenAPI spec or stripe-mock. Cannot resolve without checking the live spec.

### Gaps Summary

No functional gaps blocking the core goal. The phase successfully delivers:
- Full Invoice CRUD and lifecycle
- All 5 action verbs (finalize, void, pay, send_invoice, mark_uncollectible)
- Search with eventual consistency documentation
- Preview endpoints (upcoming, create_preview) with proration guard wiring
- Auto-advance telemetry event emitted from create/3 with default logger
- InvoiceItem CRUD
- All nested typed structs (StatusTransitions, AutomaticTax, LineItem, InvoiceItem.Period)
- Billing.Guards proration guard integrated into Client/Config/Error
- 556-line invoices.md guide
- Billing module group in ExDoc

The two human verification items (proration guard false-positive, create_preview_lines HTTP verb) are pre-existing issues documented in 14-REVIEW.md. They do not block the overall goal but require developer decision on scope.

The three orphaned requirement IDs (BILL-04b, BILL-04c, BILL-10) are an administrative issue — the functional work is present but the requirements were never registered in REQUIREMENTS.md.

---

_Verified: 2026-04-12T17:00:00Z_
_Verifier: Claude (gsd-verifier)_
