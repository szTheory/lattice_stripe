# Phase 59: Checkout Guide & README Truth — Research

**Researched:** 2026-05-27
**Phase:** 59-checkout-guide-readme-truth
**Status:** Complete

## Summary

Phase 59 is a doc-only truth pass: fix one copy-paste bug in `guides/checkout.md`, add a status-values callout mirroring Phase 57 `guides/payments.md`, fix README error taxonomy drift, and extend `docs_truth_test.exs` with per-surface grep locks. No API, CI workflow, or Hex changes in this phase.

## Current State (Repo Truth)

### checkout.md bug (line 206)

```elixir
|> Stream.filter(fn s -> s.payment_status == "paid" end)
```

`%LatticeStripe.Checkout.Session{}` atomizes `payment_status` via `atomize_payment_status/1` in `lib/lattice_stripe/checkout/session.ex` (lines 693–696): `:paid`, `:unpaid`, `:no_payment_required`. String compare always fails at runtime.

### payments.md precedent (Phase 57)

- Callout at lines 110–118 before status machine bullets — explains struct atoms vs wire strings.
- Stream filter at line 199 uses `intent.status == :succeeded` (atoms).
- `docs_truth_test.exs` `describe "guides/payments.md"` with `@stale_payments_api_patterns` refute loop.

### README drift (line 111)

Current: `:auth_error`, `:server_error` — never emitted by `LatticeStripe.Error`.
Canonical (error.ex moduledoc line 18): `:authentication_error`, `:api_error` among seven types.

### docs_truth_test.exs gap

No `describe "guides/checkout.md"` or `describe "README.md"` error taxonomy block. VERIFY-05 requires checkout content locks alongside existing payments locks.

## Recommended Approach

### Wave structure (2 plans)

| Plan | Wave | Scope | Requirements |
|------|------|-------|--------------|
| 59-01 | 1 | checkout.md callout + stream filter fix | CHECKOUT-01, CHECKOUT-02 |
| 59-02 | 2 | README error taxonomy + docs_truth locks | README-01, README-02, CHECKOUT-03, VERIFY-05 |

Plan 02 depends on 01 so checkout guide content is final before grep locks are written.

### checkout.md callout (mirror payments.md)

Place **immediately before** the Auto-Pagination stream block under `### Auto-Pagination with Streams` (first status comparison site per D-05).

Shape (from D-01..D-04):

```markdown
> **Status values:** LatticeStripe atomizes known Checkout Session `status` and `payment_status` on `%LatticeStripe.Checkout.Session{}` (e.g. `:paid`, `:complete`, `:open`). Stripe's API reference, Dashboard, list filters, and webhook raw maps (`event.data["object"]`) use the wire string names below.

Session lifecycle status:
- `open` → customer can still complete checkout
- `complete` → checkout finished (does not imply payment succeeded — check `payment_status`)
- `expired` → session timed out or was explicitly expired

Payment status:
- `paid` → payment succeeded
- `unpaid` → payment not yet completed
- `no_payment_required` → free or setup-only checkout

Before fulfilling orders, verify both `status == :complete` and `payment_status == :paid` — especially for async payment methods.
```

Stream filter fix (D-06):

```elixir
|> Stream.filter(fn s -> s.payment_status == :paid and s.status == :complete end)
```

Optional retrieve cross-link (D-07): one-liner at end of Retrieving Sessions pointing to Auto-Pagination section — executor discretion.

Leave `# Status: expired` output comments unchanged (D-08).

### README fix (D-09..D-11)

Replace line 111 with:

```markdown
- Structured, pattern-matchable errors: `:card_error`, `:authentication_error`, `:rate_limit_error`, `:api_error`, and more — [Guide: Error Handling](guides/error-handling.md)
```

### docs_truth locks (D-12..D-16)

Add after existing `describe "guides/payments.md"` block:

```elixir
@stale_checkout_api_patterns [
  ~s/payment_status == "paid"/
]

@stale_readme_error_atoms [
  ":auth_error",
  ":server_error"
]
```

Two new describe blocks — separate failure signals for Phase 60 CI-01:

1. `describe "guides/checkout.md"` — assert `:paid`, callout markers (`Status values:`, `%Session{}`); refute stale patterns.
2. `describe "README.md"` test `"error taxonomy matches Error module atoms"` — assert canonical atoms; refute stale via `@stale_readme_error_atoms`.

## Validation Architecture

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds (docs_truth only) |

Per-task verification: run `mix test test/lattice_stripe/docs_truth_test.exs` after docs_truth changes; grep assertions for doc content changes.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Callout duplicates webhook wire-string examples | Scope callout to `%Session{}` struct contexts; webhook handler examples stay on `event.data["object"]` strings |
| Over-broad stale pattern catches legitimate wire docs | `@stale_checkout_api_patterns` targets comparison expressions only (`payment_status == "paid"`), not callout wire-string bullet lists |
| Consolidated describe loses per-surface CI signal | Keep separate describes per D-16 |

## Sources Consulted

- `.planning/phases/59-checkout-guide-readme-truth/59-CONTEXT.md` — locked decisions D-01..D-16
- `guides/payments.md` lines 110–118, 199 — callout + atom filter precedent
- `guides/checkout.md` lines 164–208 — bug site + placement anchor
- `test/lattice_stripe/docs_truth_test.exs` — payments describe pattern
- `lib/lattice_stripe/checkout/session.ex` lines 683–696 — atom sets
- `lib/lattice_stripe/error.ex` lines 18–19 — canonical type atoms

---

## RESEARCH COMPLETE
