# Phase 51 — Pattern Map

**Mapped:** 2026-05-27

## TaxId (`lib/lattice_stripe/tax_id.ex`)

| Role | Analog | Excerpt pattern |
|------|--------|-----------------|
| Dual-path routing | `lib/lattice_stripe/login_link.ex` | `create(client, account_id, params, opts)` — parent ID as 2nd positional arg |
| CRUDL minus update | `lib/lattice_stripe/coupon.ex` | No `update/*`; `delete/3` + `list/3` + `stream!/3` |
| PII Inspect redact | `lib/lattice_stripe/account/company.ex` | `defimpl Inspect` with `@redacted [:value]` |
| ObjectTypes co-delivery | `lib/lattice_stripe/tax/registration.ex` (Phase 50) | Register `"tax_id"` in same plan as module |
| Mox URL tests | `test/lattice_stripe/credit_note_test.exs` | Per-verb describe + path assertion |

## Testing fixtures

| Role | Analog | Excerpt pattern |
|------|--------|-----------------|
| Wire + wrapper | `lib/lattice_stripe/testing/fixtures/credit_note.ex` + `testing.ex` | `credit_note_json/1` + `def credit_note(raw), do: CreditNote.from_map(raw)` |
| Migration source | `test/support/fixtures/tax_calculation.ex` | Rename to `LatticeStripe.Testing.Fixtures.TaxCalculation` |

## Expand proof

| Role | Analog | Excerpt pattern |
|------|--------|-----------------|
| Expand-through-parent | Invoice/CreditNote expand tests | `from_map(%{"customer" => %{"object" => "customer", ...}})` → `%Customer{}` |

## Adoption surface

| Role | Analog | Excerpt pattern |
|------|--------|-----------------|
| Canonical guide | `guides/metering.md` | Section spine, Elixir examples, scope boundary |
| Discovery | Phase 48 thin-events guide | README + JTBD + recipes bridge |
| Docs-truth | `test/lattice_stripe/docs_truth_test.exs` | `File.read!` + `assert moduledoc =~` anchors |
