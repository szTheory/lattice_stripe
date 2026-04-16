# Phase 30: Stripe API Drift Detection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 30-stripe-api-drift-detection
**Areas discussed:** OpenAPI spec sourcing, Drift report format, CI notification mechanism, Field matching strategy
**Mode:** --auto (all decisions auto-selected)

---

## OpenAPI Spec Sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Fetch from Stripe's public GitHub repo | Download `spec3.json` from `stripe/openapi` at runtime — always current | ✓ |
| Vendor a snapshot in repo | Check in a copy of the spec — offline, but stale by default | |
| Fetch from Stripe docs CDN | Use Stripe's public API docs URL — less stable than GitHub | |

**User's choice:** [auto] Fetch from Stripe's public GitHub repo (recommended default)
**Notes:** Always up-to-date, no vendored file to maintain. `stripe/openapi` is the canonical source.

---

## Drift Report Format

| Option | Description | Selected |
|--------|-------------|----------|
| Structured list grouped by module | Module-grouped output with `+` prefix for new fields, exit code 1 on drift | ✓ |
| JSON output | Machine-readable JSON for programmatic consumption | |
| Table format | Tabular display with columns for module, field, type | |

**User's choice:** [auto] Structured list grouped by module (recommended default)
**Notes:** Easy to scan, CI-friendly exit codes, human-readable in issue bodies.

---

## CI Notification Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Open a GitHub issue | Create/update issue with drift details, deduplicate by checking for existing open issue | ✓ |
| Open a draft PR | Create a draft PR with placeholder changes | |
| Check annotation only | Annotate the workflow run, no issue/PR | |

**User's choice:** [auto] Open a GitHub issue (recommended default)
**Notes:** Lower friction than PRs, searchable, closeable. Duplicate-prevention keeps tracker clean.

---

## Field Matching Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Top-level properties via ObjectTypes registry | Compare top-level OpenAPI properties per object type using existing registry mapping | ✓ |
| Full nested property tree | Recursively compare all nested properties | |
| Pattern-based module discovery | Scan `lib/` for modules with `@known_fields` instead of using registry | |

**User's choice:** [auto] Top-level properties via ObjectTypes registry (recommended default)
**Notes:** Matches existing `@known_fields` pattern. Nested structs checked independently via their own modules.

---

## Claude's Discretion

- Internal module structure (single module vs. separate parser/reporter)
- HTTP client for spec download (dev-only dep consideration)
- GitHub Actions workflow syntax and caching
- Whether drift report includes field types or just names
- Test strategy (fixture spec snippets vs. live spec)

## Deferred Ideas

None — discussion stayed within phase scope.
