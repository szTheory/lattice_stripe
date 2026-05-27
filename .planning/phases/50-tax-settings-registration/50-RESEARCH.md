# Phase 50: Tax Settings & Registration — Research

**Researched:** 2026-05-27  
**Confidence:** HIGH (Stripe API endpoints verified; codebase singleton + CRUDL precedents confirmed)

## RESEARCH COMPLETE

## Executive Summary

Phase 50 adds the **first singleton resource** (`Tax.Settings`) and a standard **CRUDL resource** (`Tax.Registration`) under `lib/lattice_stripe/tax/`. Phase 49 (`Tax.Calculation`, `Tax.Transaction`) is already landed — this phase registers two more ObjectTypes entries and closes CONF-01..04. No chained integration test (unlike Phase 49 calc→txn): configuration resources have no wire ID handoff.

**Highest risk:** Pitfall #7 — implementing Settings as CRUD with a fake ID in the path. Prevention is `balance_test.exs`-style **module surface** negative exports plus URL assertions without trailing ID segments.

## API Surface (Verified)

### Tax.Settings (singleton)

| Verb | Method | Path | Arity |
|------|--------|------|-------|
| `retrieve/2` | GET | `/v1/tax/settings` | `(client, opts \\ [])` |
| `retrieve!/2` | GET | `/v1/tax/settings` | same |
| `update/3` | POST | `/v1/tax/settings` | `(client, params, opts \\ [])` |
| `update!/3` | POST | `/v1/tax/settings` | same |

**No** `list`, `create`, `delete`, or ID-parameter variants.

**Wire object:** `tax.settings` — **no `id` field** on the Stripe object.

**Top-level `@known_fields` (plan-time):** `object`, `defaults`, `head_office`, `livemode`, `status`, `status_details`

**Connect:** Pass `stripe_account: "acct_..."` in `opts` on retrieve and update (Balance precedent; Tax settings are Connect-relevant).

**Nested typing (D-02):**
- `Tax.Settings.Defaults` — atomize `tax_behavior` (`:exclusive`, `:inclusive`, `:inferred_by_currency`); pass through `tax_code`, `provider` strings
- `Tax.Settings.HeadOffice` — `address` stays **map()**
- `Tax.Settings.StatusDetails` — thin module; `active` / `pending` remain maps inside
- `status` top-level — atomize `:active`, `:pending`

**Update semantics:** Params cannot be unset once set (document in moduledoc).

### Tax.Registration (CRUDL)

| Verb | Method | Path |
|------|--------|------|
| `create/3` | POST | `/v1/tax/registrations` |
| `retrieve/3` | GET | `/v1/tax/registrations/:id` |
| `update/4` | POST | `/v1/tax/registrations/:id` |
| `list/3` | GET | `/v1/tax/registrations` |
| `stream!/3` | GET (paginated) | `/v1/tax/registrations` |

**No** `delete` in ROADMAP SC — omit unless Stripe docs add it (current API: create, update, retrieve, list only).

**Wire object:** `tax.registration`

**Top-level `@known_fields`:** `id`, `object`, `active_from`, `country`, `country_options`, `created`, `expires_at`, `livemode`, `status`

**`country_options`:** raw **map** at decode time (Account.Settings depth-cap analog — do not generate per-country modules).

**`status`:** atomize known strings; pass through unknown.

**Create body shape:** nested `country_options` uses **lowercase ISO** keys matching `"country"` field, e.g.:

```elixir
%{
  "country" => "US",
  "country_options" => %{
    "us" => %{"type" => "state_sales_tax", "state" => "CA"}
  }
}
```

Anti-pattern: putting jurisdiction `type` at top level instead of under `country_options[cc]`.

## Codebase Patterns to Copy

| Pattern | Source | Apply to |
|---------|--------|----------|
| Singleton `retrieve/2` only (no id) | `Balance` | Settings.retrieve |
| Singleton + `update/3` POST same path | *(new — Meter has verbs but not singleton)* | Settings.update |
| Module surface negative exports | `balance_test.exs` | `settings_test.exs` |
| CRUDL + `stream!/3` | `CreditNote` | Registration |
| `update/4` with id | `CreditNote` | Registration.update |
| Map subtree depth cap | `Account.Settings` | Registration.country_options |
| Bounded nested structs | Phase 49 `Tax.Calculation` | Settings.Defaults etc. |
| ObjectTypes co-delivery | Phase 49 | both entries in same plan as module |
| Mox per-verb tests | `credit_note_test.exs` | split test files |
| Fixture `Map.merge` | `test/support/fixtures/credit_note.ex` | tax_settings, tax_registration |

## ObjectTypes

```elixir
"tax.settings" => LatticeStripe.Tax.Settings,
"tax.registration" => LatticeStripe.Tax.Registration,
```

Two new cases in `object_types_test.exs` (minimal wire maps with `"object"` key).

## Moduledoc Grep Targets (Phase 51 DX-05 prep)

| Module | Required substrings |
|--------|---------------------|
| `Tax.Settings` | `singleton`, `tax_code`, Calculation fallback, `stripe_account` |
| `Tax.Registration` | `tax authorities`, `country_options`, `LatticeStripe.Tax.Settings`, `LatticeStripe.Tax.Calculation`, `Invoice.AutomaticTax`, `out of SDK scope`, `stream!` |

## Validation Architecture

Nyquist validation applies. Automated verification uses ExUnit + Mox:

| Layer | Command | When |
|-------|---------|------|
| Quick (settings) | `mix test test/lattice_stripe/tax/settings_test.exs --no-start` | After Settings plan tasks |
| Quick (registration) | `mix test test/lattice_stripe/tax/registration_test.exs --no-start` | After Registration plan tasks |
| ObjectTypes | `mix test test/lattice_stripe/object_types_test.exs --no-start` | After each ObjectTypes task |
| Full tax suite | `mix test test/lattice_stripe/tax/ --no-start` | End of wave 2 |
| Compile gate | `mix compile --warnings-as-errors` | Every plan |

**Estimated runtime:** ~15–25s for full `test/lattice_stripe/tax/`.

**Manual-only:** None required — stripe-mock smoke explicitly deferred (CONTEXT).

## Plan Split Recommendation

| Plan | Wave | Delivers | Requirements |
|------|------|----------|----------------|
| 50-01 | 1 | `Tax.Settings` + nested modules + `tax.settings` ObjectTypes + fixtures + settings tests | CONF-01, CONF-02 |
| 50-02 | 2 | `Tax.Registration` CRUDL + `stream!/3` + full moduledocs + `tax.registration` ObjectTypes + fixtures + registration tests | CONF-03, CONF-04 |

## Sources

- [Tax Settings API](https://docs.stripe.com/api/tax/settings)
- [Tax Registrations API](https://docs.stripe.com/api/tax/registrations)
- [Registering for tax](https://docs.stripe.com/tax/registering)
- `.planning/phases/50-tax-settings-registration/50-CONTEXT.md` (D-01–D-04)
- `.planning/research/PITFALLS.md` (Pitfall #7)
- `lib/lattice_stripe/balance.ex`, `lib/lattice_stripe/credit_note.ex`
