---
phase: 21-customer-portal
plan: "04"
subsystem: billing_portal
tags: [integration-test, guide, exdoc, portal, docs, cross-links]
dependency_graph:
  requires:
    - 21-03
  provides:
    - test/integration/billing_portal_session_integration_test.exs
    - guides/customer-portal.md
  affects:
    - mix.exs
    - guides/subscriptions.md
    - guides/webhooks.md
tech_stack:
  added: []
  patterns:
    - "Integration test mirrors checkout_session_integration_test.exs pattern (setup creates Customer, tests use returned id)"
    - "MODERATE-envelope guide: 280 lines, 7 H2, per D-04 locked outline"
    - "ExDoc groups_for_modules Customer Portal group with 6 modules (Session + FlowData + 4 sub-structs)"
    - "Reciprocal See also cross-links in existing guides using ExDoc .tip admonition"
key_files:
  created:
    - test/integration/billing_portal_session_integration_test.exs
    - guides/customer-portal.md
  modified:
    - mix.exs
    - guides/subscriptions.md
    - guides/webhooks.md
decisions:
  - "BillingPortal.Guards excluded from Customer Portal ExDoc group — @moduledoc false, pre-existing Internals placement per RESEARCH Pitfall 5"
  - "mix docs --warnings-as-errors has pre-existing failures in meter.ex and BillingPortal.Guards/Billing.Guards refs from session.ex; all pre-exist before plan 21-04 changes — logged as deferred"
  - "Guide uses plain text reference to BillingPortal.Guards (not backtick module ref) to avoid adding new doc warning"
  - "Integration test setup creates Customer via LatticeStripe.Customer.create/3 — mirrors checkout integration test pattern exactly"
metrics:
  duration: ~10 minutes
  completed: 2026-04-14T21:09:44Z
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 3
---

# Phase 21 Plan 04: Integration Test, Guide, and ExDoc Registration Summary

**One-liner:** Portal integration tests proving Session.create/3 round-trip against stripe-mock, MODERATE-envelope customer-portal.md guide (280 lines, 7 H2, security Inspect masking teaching), and ExDoc Customer Portal group registering 6 modules — closing PORTAL-01, TEST-05, DOCS-02, DOCS-03.

---

## What Was Built

### Task 1 — Integration tests against stripe-mock (`11c80f7`)

`test/integration/billing_portal_session_integration_test.exs` — replaced the `@tag :skip` Wave 0 skeleton with 5 real `:integration`-tagged tests:

1. `create/3 with customer returns {:ok, %Session{url: url}} with non-empty url` — happy path, asserts `url =~ ~r{^https://}` — closes PORTAL-01 + TEST-05 (portal portion)
2. `create/3 populates all 11 PORTAL-05 response fields from stripe-mock` — asserts `id =~ ~r/^bps_/`, `object == "billing_portal.session"`, integer `created`, boolean `livemode`, all struct keys present
3. `create/3 decodes flow echo into %FlowData{}` — passes `flow_data` with `subscription_cancel` type, asserts `%FlowData{} = session.flow`
4. `create/3 with stripe_account: opt threads header through` — PORTAL-06 integration; stripe-mock accepts `acct_test`
5. `create!/3 bang variant returns unwrapped %Session{}` — bang path happy path

`setup` block creates a real `Customer` via `LatticeStripe.Customer.create/3` (mirrors `checkout_session_integration_test.exs` pattern). Documents intentional non-coverage at top of file: PORTAL-04 guard matrix stays in unit tests (stripe-mock doesn't enforce sub-field validation per RESEARCH Finding 1).

### Task 2 — `guides/customer-portal.md` (`fb04baa`)

280-line MODERATE-envelope guide with exactly 7 H2 sections per D-04 locked outline:

1. **What the Customer Portal is** — intro with 4 flow type summary
2. **Quickstart** — minimal `Session.create/3` call with params reference table
3. **Deep-link flows** — all 4 H3 subsections with code examples; cross-links to subscriptions.md §Lifecycle ops and §Proration
4. **End-to-end Phoenix example** — `portal_url/2` wrapper + `BillingController.portal/2` with redirect and error handling (Accrue-style, closes DOCS-02)
5. **Security and session lifetime** — Inspect masking demonstration (before/after `IO.inspect(session)` output showing `url` absent), `structs: false` escape hatch, security rules (mitigates T-21-11/T-21-12/T-21-13)
6. **Common pitfalls** — D-01 guard messages, no-cache rule, webhooks-not-return-URL teaching
7. **See also** — cross-links to Session moduledoc, subscriptions.md, webhooks.md, checkout.md

All code samples use string-keyed params per Phase 20 D-06.

### Task 3 — `mix.exs` ExDoc registration + reciprocal cross-links (`2a2f6ad`)

**mix.exs:**
- Added `"guides/customer-portal.md"` to `extras` list (alphabetical, between `connect-money-movement.md` and `webhooks.md`)
- Added `"Customer Portal"` group to `groups_for_modules` with 6 modules: `Session`, `FlowData`, `FlowData.AfterCompletion`, `FlowData.SubscriptionCancel`, `FlowData.SubscriptionUpdate`, `FlowData.SubscriptionUpdateConfirm`
- `BillingPortal.Guards` excluded — `@moduledoc false`, belongs in Internals per RESEARCH Pitfall 5

**guides/subscriptions.md:**
- §Lifecycle operations: added `.tip` admonition with link to `customer-portal.html#canceling-a-subscription`
- §Proration: added `.tip` admonition with link to `customer-portal.html#updating-a-subscription`

**guides/webhooks.md:**
- §See also: added cross-link to `customer-portal.html#security-and-session-lifetime` explaining portal flows dispatch via webhooks not return-URL payloads

---

## Requirements Closed

| Requirement | Description | Closed By |
|-------------|-------------|-----------|
| PORTAL-01 | `Session.create/3` integration proof against stripe-mock | Task 1 integration test |
| TEST-05 (portal) | Full portal flow test against stripe-mock | Task 1, 5 tests green |
| DOCS-02 | `guides/customer-portal.md` with Accrue-style Phoenix example | Task 2 |
| DOCS-03 | ExDoc Customer Portal group with 6 modules | Task 3 |

---

## Deviations from Plan

### Pre-existing issue (out of scope — logged, not fixed)

**`mix docs --warnings-as-errors` fails with pre-existing warnings in `meter.ex` and hidden-module refs from `session.ex` moduledoc.**

- **Found during:** Task 2 verification
- **Issue:** `mix docs --warnings-as-errors` exits non-zero due to: (1) a `Billing.Guards.check_meter_value_settings!/1` hidden-function ref in `meter.ex:83`, and (2) `BillingPortal.Guards` hidden-module refs in `session.ex` moduledoc. All 4 warnings exist before any Plan 21-04 file is added (confirmed via `git stash` test).
- **Disposition:** Pre-existing, out-of-scope per deviation rules. No new warnings introduced by this plan.
- **Logged in:** `deferred-items.md` (see below)

No other deviations — plan executed as written.

---

## Known Stubs

None. All integration tests use real stripe-mock round-trips. Guide prose is complete. ExDoc group is fully wired.

---

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: Information Disclosure (T-21-11 MITIGATED) | `guides/customer-portal.md` | §Security demonstrates `IO.inspect(session)` output with `url` absent — teaches masking behavior users cannot discover from moduledoc alone. Phoenix example uses `redirect(conn, external: session.url)` directly without intermediate log line. |
| threat_flag: Information Disclosure (T-21-12 MITIGATED) | `guides/customer-portal.md` | §Security and §Common pitfalls both explicitly require HTTPS `return_url`; pitfall bullet names the guard rejection and phishing risk. |
| threat_flag: Spoofing (T-21-13 MITIGATED) | `guides/customer-portal.md` | §Security: "portal redirect is NOT authentication — use webhooks for state-change confirmation"; `BillingController.return/2` example comments reinforce; webhooks.md cross-link closes the loop. |

---

## Self-Check: PASSED

Files verified:
- `test/integration/billing_portal_session_integration_test.exs` — FOUND (5 tests, 0 failures)
- `guides/customer-portal.md` — FOUND (280 lines, 7 H2 sections)
- `mix.exs` — FOUND (contains "Customer Portal", "customer-portal.md")
- `guides/subscriptions.md` — FOUND (contains "customer-portal")
- `guides/webhooks.md` — FOUND (contains "customer-portal")

Commits verified:
- `11c80f7` — integration tests
- `fb04baa` — guide
- `2a2f6ad` — mix.exs + cross-links
