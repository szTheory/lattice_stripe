---
phase: 31-livebook-notebook
plan: "01"
subsystem: notebooks
tags: [livebook, notebook, dx, interactive, kino]
dependency_graph:
  requires:
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/payment_intent.ex
    - lib/lattice_stripe/billing/meter.ex
    - lib/lattice_stripe/billing/meter_event.ex
    - lib/lattice_stripe/billing/meter_event_stream.ex
    - lib/lattice_stripe/billing_portal/session.ex
    - lib/lattice_stripe/builders/subscription_schedule.ex
    - lib/lattice_stripe/batch.ex
  provides:
    - notebooks/stripe_explorer.livemd
  affects: []
tech_stack:
  added:
    - kino ~> 0.14 (Mix.install in notebook, not project dependency)
  patterns:
    - LiveBook .livemd alternating Markdown + elixir fenced code blocks
    - Kino.Input.text render-then-read pattern (two separate cells)
    - Finch.start_link with already_started guard for notebook re-run safety
    - Kino.DataTable.new with Map.from_struct/1 for list results
    - Kino.Tree.new for deeply nested structs
key_files:
  created:
    - notebooks/stripe_explorer.livemd
  modified: []
decisions:
  - "Used Map.from_struct/1 in all DataTable cells — safeguards against Kino Table.Reader protocol uncertainty for SDK structs (per RESEARCH.md A2)"
  - "Kino.Input widgets in one cell, Kino.Input.read + Client.new! in a separate cell — mandatory split to allow user to edit values before reading (per RESEARCH.md Pitfall 3)"
  - "Finch already_started guard in setup cell — allows notebook re-run without MatchError (per RESEARCH.md Pitfall 1)"
  - "Added Connect, Webhooks, and v1.2 Highlights sections beyond plan scope — all content follows D-02 nine-group ExDoc order and enriches the notebook as a guided workshop"
metrics:
  duration_minutes: 7
  completed_date: "2026-04-17"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 31 Plan 01: LiveBook Notebook — Setup + Payments + Billing Summary

**One-liner:** Interactive LiveBook notebook with 31 code cells covering the complete LatticeStripe v1.2 API surface — setup through Connect, Webhooks, and v1.2 DX highlights (Batch.run/3, expand deserialization, SSBuilder, MeterEventStream).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create stripe_explorer.livemd with Setup + Payments + Billing sections | 48e1085 | notebooks/stripe_explorer.livemd |

## What Was Built

Created `notebooks/stripe_explorer.livemd` — a single progressive LiveBook notebook for exploring the complete LatticeStripe SDK interactively.

**Structure (31 code cells across 6 sections):**

1. **Setup** — Mix.install (local path + commented hex version), Finch.start_link with already_started guard, Kino.Input widgets for API key + base URL, Client.new! from widget values.

2. **Payments** — Customer create (prerequisite), PaymentIntent create/retrieve/list/confirm, error handling example, SetupIntent create/retrieve, Refund create.

3. **Billing** — Product/Price prerequisites, Subscription create/list/cancel, SubscriptionSchedule via SSBuilder pipe chain, Billing.Meter create, MeterEvent.create fire-and-forget, MeterEventStream session lifecycle (v2 with stripe-mock caveat), BillingPortal.Session with Kino.Tree display.

4. **Connect** — Account create/retrieve, AccountLink create with Kino.Tree, Transfer create.

5. **Webhooks** — `construct_event/4` with test signature via `LatticeStripe.Testing.generate_test_signature/3`, event type dispatch example.

6. **v1.2 Highlights** — `Batch.run/3` concurrent fan-out demo, expand deserialization showing string ID vs `%Customer{}` struct comparison.

**Key technical decisions embedded in the notebook:**
- `Map.from_struct/1` wraps all DataTable inputs (safe fallback for Table.Reader protocol)
- Kino.Input render and read split into two cells (Pitfall 3 from RESEARCH.md)
- Finch already_started guard in setup (Pitfall 1 from RESEARCH.md)
- Security warnings for MeterEventStream auth token and BillingPortal.Session URL

## Deviations from Plan

### Extensions (beyond plan scope — within Claude's Discretion per CONTEXT.md)

**1. Added Connect section**
- **Rationale:** D-02 specifies nine-group ExDoc order including Connect; plan scope was Setup + Payments + Billing but Claude's Discretion allows extending the workshop
- **Content:** Account create/retrieve, AccountLink, Transfer
- **Files:** notebooks/stripe_explorer.livemd

**2. Added Webhooks section**
- **Rationale:** Completes the ExDoc nine-group order; webhook verification is a high-value exploration target for SDK developers
- **Content:** `construct_event/4` with test signature generation, event type dispatch pattern
- **Files:** notebooks/stripe_explorer.livemd

**3. Added v1.2 Highlights section**
- **Rationale:** D-08 specifies v1.2 features get dedicated highlight sections; plan listed them as in-scope for the Billing section but they read better in a dedicated highlights area
- **Content:** Batch.run/3 concurrent fan-out, expand deserialization comparison
- **Files:** notebooks/stripe_explorer.livemd

These extensions are all within scope of DX-05 (interactive SDK exploration notebook) and do not require any new code changes to the SDK itself.

## Known Stubs

None. All code cells use verified param shapes from integration tests. No placeholder content.

## Threat Flags

No new threat surface introduced. The notebook file is static documentation — no runtime code, no new endpoints, no new auth paths. Threat mitigations T-31-01 through T-31-03 are all implemented:

- **T-31-01** (API key in source): Mitigated — Kino.Input.text renders widget; key typed at runtime, not stored in .livemd source. Default is stripe-mock's `sk_test_123`.
- **T-31-02** (portal session URL logged): Mitigated — prose warning "Do not log or cache it" present in Portal Session section.
- **T-31-03** (MeterEventStream auth token): Mitigated — prose warning in MeterEventStream section; SDK Inspect masks automatically.

## Self-Check: PASSED

```
[ -f notebooks/stripe_explorer.livemd ] → FOUND
git log --oneline | grep 48e1085 → FOUND
grep -c '```elixir' notebooks/stripe_explorer.livemd → 31 (≥ 15 ✓)
```
