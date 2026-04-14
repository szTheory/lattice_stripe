---
phase: 20-billing-metering
plan: "06"
subsystem: docs
tags: [documentation, exdoc, guides, metering]
dependency_graph:
  requires: [20-03, 20-04, 20-05]
  provides: [DOCS-01, DOCS-03, DOCS-04]
  affects: [mix.exs, guides/]
tech_stack:
  added: []
  patterns: [exdoc-extras, groups_for_modules, reciprocal-crosslinks]
key_files:
  created:
    - guides/metering.md
  modified:
    - mix.exs
    - guides/subscriptions.md
    - guides/webhooks.md
    - guides/telemetry.md
    - guides/error-handling.md
    - guides/testing.md
decisions:
  - "620-line guide at ceiling; dunning example retained in full (telemetry handler and timestamp section trimmed to compensate)"
  - "Billing Metering ExDoc group placed after Billing, before Connect per D-05 discretion"
  - "Crosslink in subscriptions.md added at end of PII section (no explicit metered-price section exists)"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-14"
  tasks_completed: 3
  files_changed: 7
---

# Phase 20 Plan 06: Metering Guide and ExDoc Registration Summary

Shipped `guides/metering.md` (620 lines, 9 H2 sections) covering the full
Stripe metering lifecycle — AccrueLike.UsageReporter fire-and-forget pattern,
two-layer idempotency contract, 7-row error code table, and dunning correction
worked example — registered in mix.exs Billing Metering ExDoc group, with
reciprocal crosslinks in all 5 sibling guides.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Author guides/metering.md | 8ae2d3e | guides/metering.md (620 lines) |
| 2 | Register Billing Metering ExDoc group | 7dd4abc | mix.exs |
| 3 | Reciprocal crosslinks + credo sweep | 86db73e | 5 sibling guides |

## Deliverables

### DOCS-01 — guides/metering.md

- **620 lines**, 9 H2 sections covering the full Phase 20 metering story
- `AccrueLike.UsageReporter` fire-and-forget module with supervised task,
  telemetry span, and transient/permanent error classification
- **Two-layer idempotency** section: `identifier` (body, business-layer, 24h
  dedup) vs `idempotency_key:` (HTTP header, transport-layer) with comparison
  table and "set BOTH" rule
- **35-day backdating / 5-minute future** window in timestamp semantics
- **Nightly batch flush anti-pattern** in `> **Warning:**` blockquote with
  corrected inline pattern
- **7-row error code table** with `archived_meter` (sync 400, data PERMANENTLY
  LOST), `meter_event_customer_not_found`, `timestamp_too_far_in_past`, and all
  async silent-drop codes
- **Dunning worked example** showing exact `%{"cancel" => %{"identifier" => ...}}`
  nested shape (GUARD-03 enforced)
- `IO.inspect(event, structs: false)` and `event.payload` escape hatches with
  "NEVER log raw payload" warning (T-20-doc-02 mitigated)
- `## See also` section linking all 5 sibling guides

### DOCS-03 — mix.exs ExDoc registration

- `"guides/metering.md"` added to `extras:` list (after invoices.md)
- `"Billing Metering"` group added to `groups_for_modules` (after Billing,
  before Connect) with all 8 Phase 20 modules:
  - `LatticeStripe.Billing.Meter`
  - `LatticeStripe.Billing.Meter.DefaultAggregation`
  - `LatticeStripe.Billing.Meter.CustomerMapping`
  - `LatticeStripe.Billing.Meter.ValueSettings`
  - `LatticeStripe.Billing.Meter.StatusTransitions`
  - `LatticeStripe.Billing.MeterEvent`
  - `LatticeStripe.Billing.MeterEventAdjustment`
  - `LatticeStripe.Billing.MeterEventAdjustment.Cancel`
- `mix docs` builds clean (pre-existing `@moduledoc false` warning on
  `Guards.check_meter_value_settings!/1` is not new)

### DOCS-04 — Reciprocal crosslinks

| Guide | Location | Link |
|-------|----------|------|
| subscriptions.md | End of PII section | `metering.md#reporting-usage-the-hot-path` |
| webhooks.md | Additional event types bullet list | `metering.md#reconciliation-via-webhooks` |
| telemetry.md | Custom Telemetry Handlers intro | `metering.md#observability` |
| error-handling.md | See also section | `metering.md#reconciliation-via-webhooks` |
| testing.md | End of file | `metering.md#what-not-to-do-nightly-batch-flush` |

### Credo sweep

`mix credo --strict` on all Phase 20 billing source files: **0 issues**.

## Deviations from Plan

None — plan executed exactly as written. One minor note: the plan referenced
12 H2 sections but D-05 outline has 9 substantive H2 sections (intro is prose,
not a heading; "See also" is section 9 not section 12). The guide contains all
required content from D-05; the section count discrepancy is in the plan
reference numbering, not the content.

## Threat Model Verification

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-20-doc-01 | Examples match Plan 20-03/04/05 function signatures | MITIGATED |
| T-20-doc-02 | "NEVER log raw MeterEvent.payload" warning + escape hatch documented | MITIGATED |
| T-20-doc-03 | Dunning example uses exact `%{"cancel" => %{"identifier" => ...}}` shape | MITIGATED |

## Known Stubs

None. All code examples use real function signatures from shipped Phase 20 modules.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. This
plan is documentation-only.

## Self-Check

### Files exist

- guides/metering.md: EXISTS (620 lines)
- mix.exs: MODIFIED (Billing Metering group + extras entry)
- 5 sibling guides: ALL MODIFIED (metering.md link in each)

### Commits exist

- 8ae2d3e: `docs(20-06): author guides/metering.md per D-05 outline`
- 7dd4abc: `feat(20-06): register Billing Metering ExDoc group and extras in mix.exs`
- 86db73e: `docs(20-06): reciprocal crosslinks to metering.md in 5 sibling guides`

## Self-Check: PASSED
