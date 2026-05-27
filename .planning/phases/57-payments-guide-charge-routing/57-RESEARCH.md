# Phase 57: Payments Guide & Charge Routing — Research

**Researched:** 2026-05-27
**Phase:** 57-payments-guide-charge-routing
**Requirements:** GUIDE-01, GUIDE-02, GUIDE-03, ROUTE-01, ROUTE-02, VERIFY-04

## Summary

Phase 57 closes a copy-paste correctness gap in the canonical payments guide and routes adopters to shipped Charge reconciliation workflows. `guides/payments.md` currently has three executable bugs (string status `case`, string stream filter, wrong `search/2` arity/shape) and no Charge reconciliation section despite v1.7 shipping `Charge.list/search/update/capture`. Operator guides still say "no separate Charge guide in v1.7" and omit update/capture routing. Fix pattern mirrors Phase 56: docs_truth positive+refute locks first (red), guide prose second (green), operator spine bullets last.

## Current State

### Bug inventory (`guides/payments.md`)

| Location | Bug | SDK truth |
|----------|-----|-----------|
| L93–101 `confirm/3` case | `"succeeded"`, `"requires_action"` string arms | `PaymentIntent.atomize_status/1` → atoms on struct |
| L197 stream filter | `intent.status == "succeeded"` | Atom `:succeeded` on decoded struct |
| L208–213 search | `search/2` with `%{"query" => ...}` map | `search/3`: `search(client, query_string, opts \\ [])` |

Status machine bullets (L110–116) correctly use Stripe wire-string names — keep as glossary; add bridge note before them (D-06).

### Missing Charge routing

- No `## Charge reconciliation` section between Search and Refunds (natural beat after list/search flows).
- `lib/lattice_stripe/charge.ex` moduledoc has PI-first narrative + full list/search/update/capture examples ready to distill (~55 lines).
- `docs_truth_test.exs` has Charge moduledoc positive test (L293–308) but no `describe "guides/payments.md"`.
- Operator guides (`production-checklist.md` L163–176, `event-debugging.md` L207–219) route to moduledoc only; stale "no separate Charge guide in v1.7" copy.

### Canonical test template (Phase 56)

```elixir
describe "guides/getting-started.md" do
  test "release-status prose matches current Hex surface" do
    # positive + @stale_release_status_claims refute loop
  end
end
```

Extend with `describe "guides/payments.md"` — two tests, positive+refute for API patterns; structural asserts for Charge section (D-24–D-29).

## Recommended Approach

### 1. docs_truth locks (VERIFY-04) — Wave 1, red phase

Add module attribute and describe block:

```elixir
@stale_payments_api_patterns [
  "\"succeeded\" ->",
  "\"requires_action\" ->",
  "intent.status == \"succeeded\"",
  "Use `search/2`",
  "PaymentIntent.search(client, %{"
]

describe "guides/payments.md" do
  test "canonical API examples use atom statuses and search/3" do
    payments = File.read!("guides/payments.md")
    assert payments =~ ":succeeded ->"
    assert payments =~ ":requires_action ->"
    assert payments =~ "intent.status == :succeeded"
    assert payments =~ "search/3"
    assert payments =~ ~s|PaymentIntent.search(client, "|
    for pattern <- @stale_payments_api_patterns do
      refute payments =~ pattern, "stale API pattern #{inspect(pattern)} in payments.md"
    end
  end

  test "routes Charge reconciliation after PaymentIntent flows" do
    payments = File.read!("guides/payments.md")
    assert payments =~ "## Charge reconciliation"
    assert payments =~ "LatticeStripe.Charge.list"
    assert payments =~ "LatticeStripe.Charge.search"
    assert payments =~ "LatticeStripe.Charge.update"
    assert payments =~ "LatticeStripe.Charge.capture"
    assert payments =~ "list/3"
    assert payments =~ "search/3"
    # PI-first ordering: Creating section precedes Charge reconciliation
    creating_idx = :binary.match(payments, "## Creating a PaymentIntent") |> elem(0)
    charge_idx = :binary.match(payments, "## Charge reconciliation") |> elem(0)
    assert creating_idx < charge_idx
  end
end
```

Tests fail until Plan 02 updates `payments.md` — intentional red-green.

### 2. payments.md API fixes (GUIDE-01..03) — Wave 2

**confirm/3 case (GUIDE-01):**
```elixir
case confirmed.status do
  :succeeded -> IO.puts("Payment succeeded!")
  :requires_action -> IO.puts("3D Secure required — redirect to: ...")
  other -> IO.puts("Unexpected status: #{other}")
end
```

**Bridge note before status machine bullets (D-06):**
> **Status values:** LatticeStripe atomizes known PaymentIntent statuses on `%PaymentIntent{}` (e.g. `:succeeded`, `:requires_action`). Stripe's API reference, Dashboard, webhooks, and search queries use the wire string names below.

**stream!/2 filter (GUIDE-02):** `intent.status == :succeeded`

**search/3 (GUIDE-03):**
- Heading: `Use search/3 for full-text search...`
- Example:
```elixir
{:ok, resp} =
  LatticeStripe.PaymentIntent.search(client, "metadata['order_id']:'ord_456'")
```

### 3. Charge reconciliation section (ROUTE-01) — Wave 2

Insert after Search eventual-consistency note (after L220), before `## Refunding a Payment`.

Anchor: `## Charge reconciliation` (GitHub/ExDoc slug: `#charge-reconciliation`)

Content spine (~52–60 lines):
- PI-first framing: Charge = result record; PaymentIntent = initiation; no `Charge.create/3`
- Verb table: retrieve/list/stream/search/update/capture with when-to-use
- One copy-paste example each (distill from `charge.ex` moduledoc)
- Search eventual-consistency anti-pattern (mirror PI search note)
- `capture/4` labeled legacy direct charges; cross-link `PaymentIntent.capture/4`
- Connect fees: one link to `connect-money-movement.md`
- Cross-links: production-checklist, event-debugging

### 4. Operator guide spine updates (ROUTE-02) — Wave 3

Replace stale routing in both guides (D-19):
```markdown
Full workflows: [Payments — Charge reconciliation](payments.md#charge-reconciliation) and
`LatticeStripe.Charge` moduledoc.
```

**production-checklist.md** §Support and audit lookups — add verb bullets (no code fences):
- `Charge.retrieve/3` for known charge id
- `Charge.update/4` for metadata/description on settled charges
- `Charge.capture/4` for legacy direct uncaptured only; PI → `PaymentIntent.capture/4`

**event-debugging.md** §`charge.*` events — add:
- `Charge.update/4` for post-dispatch support context
- Anti-pattern: do not call `Charge.capture/4` from `charge.*` handlers for PI flows

Optional ROUTE-02 docs_truth (D-23): assert `update/4` and `capture/4` in operator guide tests + cross-link anchor.

## Patterns to Follow

From Phase 56:
- **Red-green docs_truth** — tests before prose
- **Describe-per-guide** — separate failure signals
- **Positive + refute grep** — closes install-pin-passed/body-lied bug class

From Phase 53 / tax.md:
- **Content vs routing split** — canonical snippets in payments.md; operator guides = bullets + links
- **PI-first everywhere** — moduledoc, connect-money-movement, operator guides

From `charge.ex`:
- Distill moduledoc examples; do not duplicate Connect fee walkthrough

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Atom bullets in status glossary confuse Stripe cross-ref | Keep wire strings in bullets; bridge note explains two-layer model (D-05, D-08) |
| Charge.capture in PI webhook handlers | Explicit anti-pattern in event-debugging (D-21) |
| Doc drift from duplicating snippets in 3 surfaces | SSOT in payments.md; operator guides link only (D-18) |
| Structural regex locks break on editorial refactor | Lock copy-paste Elixir patterns only, not prose (D-28) |
| Charge.search for real-time confirmation | Eventual-consistency note in Charge section (D-13) |

## Plan Structure Recommendation

Three plans, three waves (red-green + operator routing):

| Plan | Wave | Delivers | Requirements |
|------|------|----------|--------------|
| 57-01 | 1 | docs_truth `describe "guides/payments.md"` locks | VERIFY-04 |
| 57-02 | 2 | payments.md API fixes + Charge reconciliation section | GUIDE-01..03, ROUTE-01 |
| 57-03 | 3 | operator guide spine updates + optional docs_truth ROUTE-02 asserts | ROUTE-02 |

Plan 01 intentionally leaves payments describe tests red until Plan 02 — standard Phase 56 pattern.

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config | `mix.exs` `test_paths: ["test"]` |
| Quick run | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| Full suite | `mix test --warnings-as-errors` |
| Estimated runtime | ~2–5 seconds (docs_truth only) |

### Per-requirement verification

| REQ-ID | Automated command | Pass condition |
|--------|-------------------|----------------|
| GUIDE-01 | docs_truth + manual grep | `:succeeded ->` in confirm case; refute `"succeeded" ->` |
| GUIDE-02 | docs_truth | `intent.status == :succeeded` in stream example |
| GUIDE-03 | docs_truth | `search/3` + query-string shape; refute `search/2` / map form |
| ROUTE-01 | docs_truth test 2 | Charge section with list/search/update/capture after PI flows |
| ROUTE-02 | grep operator guides | update/capture bullets + cross-link to charge-reconciliation |
| VERIFY-04 | `mix test test/lattice_stripe/docs_truth_test.exs` | both payments describe tests pass |

### Wave 0

Not required — ExUnit infrastructure exists.

## RESEARCH COMPLETE
