# Phase 50: Tax Settings & Registration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 50-tax-settings-registration
**Areas discussed:** All four (user requested full research + one-shot recommendations)

---

## Settings singleton API shape

| Option | Description | Selected |
|--------|-------------|----------|
| Balance-extended singleton | `retrieve/2`, `update/3`, bangs, no ID in path/struct | ✓ |
| Balance read-only only | retrieve only | |
| CRUD with optional/fake ID | `retrieve(client, id, opts)` | |
| SingletonResource behaviour | macro for DRY | |

**User's choice:** Auto-resolved via parallel research (user: "don't make me think")
**Notes:** Pitfall #7 prevention via module surface tests; Connect `stripe_account:` on both verbs.

---

## Nested struct typing

| Option | Description | Selected |
|--------|-------------|----------|
| Pragmatic partial (Phase 49 D-01) | Settings: Defaults/HeadOffice/StatusDetails; Registration: `country_options` map | ✓ |
| Full codegen depth | per-country modules | |
| Maps-only | minimal typing | |
| Polymorphic CountryOptions struct | 100 ISO keys | |

**User's choice:** Auto-resolved — extend D-01
**Notes:** `Account.Settings` is analog for map-heavy subtrees; reject stripe-ruby CountryOptions depth.

---

## Registration moduledoc & operational guidance

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 49 D-03 structured moduledoc | authorities disclaimer, country_options assertive, pagination, relationship paragraph | ✓ |
| Encyclopedic jurisdiction matrix in moduledoc | | |
| Minimal one-liner moduledocs | | |

**User's choice:** Auto-resolved
**Notes:** Ship `stream!/3` with list; grepable strings for Phase 51 docs-truth.

---

## Phase 50 test proof

| Option | Description | Selected |
|--------|-------------|----------|
| Unit-only per verb + Settings module surface | settings_test + registration_test + fixtures | ✓ |
| Chained Mox workflow | settings → registration → list | |
| Hybrid (unit + chain) | | |
| stripe-mock integration | optional smoke | |

**User's choice:** Auto-resolved
**Notes:** Phase 49 chain is exception for calc→txn ID handoff; no ROADMAP integration SC for Phase 50.

---

## Claude's Discretion

- Exact Registration `@known_fields` after API verification
- StatusDetails as separate module vs inline
- Optional stripe-mock smoke

## Deferred Ideas

- SingletonResource abstraction until third singleton
- Request param builders for country_options
- settings→registration→calculation chain integration test
