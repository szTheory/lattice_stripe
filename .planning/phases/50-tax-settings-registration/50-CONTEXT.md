# Phase 50: Tax Settings & Registration - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship account-level Stripe Tax configuration: `Tax.Settings` (singleton retrieve/update on `/v1/tax/settings`) and `Tax.Registration` (CRUDL on `/v1/tax/registrations`). Register `tax.settings` and `tax.registration` in ObjectTypes. Moduledocs cover operational traps (authority disclaimer, `country_options` nesting, pagination). Unit tests prove singleton path/arity (Pitfall #7) and Registration wire contracts.

**In scope:** CONF-01..04; `lib/lattice_stripe/tax/settings.ex`, nested Settings modules, `registration.ex`, ObjectTypes entries, fixtures, `settings_test.exs`, `registration_test.exs`, two ObjectTypes dispatch tests.

**Out of scope (Phase 51):** TaxId, Testing fixtures (DX-02), `guides/tax.md` (DX-04), docs-truth grep blocks (DX-05), five-type expand integration proof (DX-01), chained settings→registration→calculation integration spec, request param builders, Tax Code lookup (TAX-01 / v1.7+).

</domain>

<decisions>
## Implementation Decisions

### Settings singleton API shape (D-01)
- **D-01:** **Balance singleton arity + Meter-style update/bangs** — `retrieve/2`, `retrieve!/2`, `update/3`, `update!/3` only; fixed paths `GET` and `POST` `/v1/tax/settings`; **no ID parameter** in function signatures or URL paths.
- **Struct:** `%Tax.Settings{}` with **no `:id` field** — Stripe `tax.settings` wire object has no `id`; unknown future keys land in `extra` via `@known_fields`.
- **Connect:** Document and test `stripe_account:` opt on both retrieve and update (same semantics as `Balance.retrieve/2`; Stripe Tax settings are Connect-relevant).
- **Absence as interface:** Export `module surface` tests mirroring `balance_test.exs` — refute `list`, `create`, `delete`, `retrieve/3`, `update/4`; assert `%Settings{}` has no `:id`; refute `function_exported?(Settings, :retrieve, 3)`.
- **No `SingletonResource` behaviour/macro** — only two singletons exist (`Balance`, `Settings`); defer abstraction until a third singleton appears.
- **Cross-SDK alignment:** Matches stripe-node `stripe.tax.settings.retrieve/update`, stripe-ruby `SingletonAPIResource`, stripe-go package-level Get/Update — **reject** CRUD-shaped `retrieve(client, id, opts)` (Pitfall #7).

### Nested struct typing (D-02)
- **D-02:** **Extend Phase 49 D-01 pragmatic partial typing** — type resource boundaries and stable configuration reads; keep polymorphic jurisdiction blobs as maps.
- **`Tax.Settings`:** Top-level struct; nested modules `Tax.Settings.Defaults`, `Tax.Settings.HeadOffice`, `Tax.Settings.StatusDetails` (thin — `active`/`pending` stay maps inside).
- **`head_office.address`:** **map()** — no shared Address module (Phase 49 / Checkout precedent).
- **`defaults`:** Atomize closed `tax_behavior` (`:exclusive`, `:inclusive`, `:inferred_by_currency`); pass through `tax_code`, `provider` strings.
- **`status`:** Atomize `:active`, `:pending`; unknown strings pass through.
- **`Tax.Registration`:** Top-level struct with scalars (`id`, `country`, `active_from`, `created`, `expires_at`, `livemode`, `status` atomized); **`country_options` stays a raw map** — do not generate per-country modules or a 100-key polymorphic struct (contrast: `Dispute.PaymentMethodDetails` is for few branches; `Account.Settings` is the analog for deep map subtrees).
- **Requests:** Raw string-key maps for `update/3` and `create/3` — no param builders in Phase 50 (Phase 49 precedent; prompts allow builders later).
- **Reject:** OpenAPI/codegen depth (stripe-ruby `CountryOptions` per country), maps-only Settings (loses `settings.defaults.tax_code` ergonomics), `CountryOptions` wrapper struct with ISO keys as fields.

### Moduledoc & operational guidance (D-03)
- **D-03:** **Phase 49 D-03 contract** — structured relationship paragraph, operational traps at ExDoc discovery, encyclopedic jurisdiction matrix deferred to Phase 51 `guides/tax.md`.
- **`Tax.Settings` moduledoc sections:** purpose → singleton surface (no ID; `retrieve/2` + `update/3` only) → **defaults → Calculation** (`tax_code` / `tax_behavior` fallback when line items omit them) → AutomaticTax fence → Connect `stripe_account:` note → usage examples → API link → Phase 51 guide placeholder.
- **`Tax.Registration` moduledoc sections (order):** purpose → **does not register with tax authorities** (ROADMAP SC#6, required) → relationship (`Settings`, `Calculation`, not `Invoice.AutomaticTax`; filing out of SDK scope) → **`country_options`** (required; lowercase ISO key must match `"country"`; US + one non-US example; anti-pattern: top-level `type`) → usage (`create/3`, `list/3`) → **pagination** (`list/3` = one page; use `stream!/3` for many jurisdictions; `List` not `Enumerable`) → API link → guide placeholder.
- **Ship `Registration.stream!/3`** when `list/3` ships (CreditNote precedent) so pagination moduledoc is honest.
- **Phase 51 docs-truth prep (no grep blocks yet):** Registration moduledoc must contain grepable: `tax authorities`, `country_options`, `LatticeStripe.Tax.Settings`, `LatticeStripe.Tax.Calculation`, `Invoice.AutomaticTax`, `out of SDK scope`, pagination/stream language. Settings: `singleton`, `tax_code`, Calculation fallback language.
- **Stripe update semantics:** Settings moduledoc notes params cannot be unset once set; `status` / `active` configuration path.

### Test proof strategy (D-04)
- **D-04:** **Unit-only Mox-at-Transport** — no chained settings→registration workflow file; ROADMAP has no integration SC for Phase 50 (unlike Phase 49 calc→txn chain where ID handoff is a real wire contract).
- **Files:** `test/lattice_stripe/tax/settings_test.exs` (~10–12 tests), `test/lattice_stripe/tax/registration_test.exs` (~8–10 tests), `test/support/fixtures/tax_settings.ex`, `test/support/fixtures/tax_registration.ex`; extend `object_types_test.exs` with two dispatch cases.
- **Settings load-bearing tests:** URL ends with `/v1/tax/settings` with **no** trailing ID segment; `module surface` negative exports; `%Settings{}` has no `:id`; optional Connect header on retrieve/update.
- **Registration tests:** CreditNote-shaped per-verb path/body asserts; `create/3` body includes nested `country_options[us][...]` (or one jurisdiction); list returns `%List{}`; `stream!/3` if exported.
- **Optional future:** stripe-mock shape smoke — not Phase 50 gate; will not catch Pitfall #7 if mock is permissive.

### Claude's Discretion
- Exact `@known_fields` after Stripe doc verification at plan time (e.g. Registration fields beyond confirmed set).
- Whether `StatusDetails` is a separate module vs inline on Settings (prefer separate thin module).
- Registration `update/3` vs `update/4` arity naming — follow CreditNote (`update/4` with id).
- Unit test file split vs single `tax_settings_registration_test.exs` — prefer split per D-04.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & pitfalls
- `.planning/PROJECT.md` — v1.6 Tax milestone, Accrue boundary, explicit verbs
- `.planning/REQUIREMENTS.md` — CONF-01..04
- `.planning/ROADMAP.md` — Phase 50 success criteria (#1–6)
- `.planning/research/PITFALLS.md` — Pitfall #7 (singleton path), integration table (`country_options`, Settings default `tax_code`), performance (registration list pagination)
- `.planning/research/ARCHITECTURE.md` — Pattern 3 singleton, Pattern 1 CRUDL, configuration flow diagram
- `.planning/research/SUMMARY.md` — Phase 50 flags (singleton path, Registration CRUDL precedent)

### Prior phase decisions
- `.planning/phases/49-tax-calculation-transaction-core/49-CONTEXT.md` — D-01 typing, D-03 moduledoc, D-04 testing split, ObjectTypes incremental registration

### Codebase patterns
- `lib/lattice_stripe/balance.ex` — singleton retrieve-only precedent, Connect warning, module surface moduledoc
- `lib/lattice_stripe/credit_note.ex` — CRUDL + `stream!/3` + moduledoc tone
- `lib/lattice_stripe/account/settings.ex` — outer-only / map subtrees depth cap (D-01 analog for `country_options`)
- `lib/lattice_stripe/tax/calculation.ex` — Tax namespace, AutomaticTax cross-ref, guide deferral
- `lib/lattice_stripe/object_types.ex` — add `tax.settings`, `tax.registration`
- `test/lattice_stripe/balance_test.exs` — singleton module surface tests
- `test/lattice_stripe/tax/calculation_transaction_test.exs` — when **not** to chain (contrast)

### Prompts (vision / DX)
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — handwritten ergonomics over codegen; Tax as major family; `extra` escape hatch
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — lifecycle-first; transport before wrappers
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — `{:ok,_}` + bang, explicit client, excellent moduledocs

### External Stripe docs
- [Tax Settings API](https://docs.stripe.com/api/tax/settings) — singleton GET/POST
- [Tax Registrations API](https://docs.stripe.com/api/tax/registrations) — CRUDL, `country_options`
- [Registering for tax](https://docs.stripe.com/tax/registering) — authority vs API distinction (guide deferral source)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Resource` — unwrap_singular, unwrap_bang!, require_param!
- `LatticeStripe.Request` + `FormEncoder` — POST param encoding
- `LatticeStripe.List` — `list/3` + `List.stream!/2` for Registration pagination
- `LatticeStripe.Balance` — singleton retrieve pattern, Connect opts, module surface tests
- `LatticeStripe.CreditNote` — CRUDL verbs, `stream!/3`, test layout
- Phase 49 `lib/lattice_stripe/tax/*` — namespace, nested struct mechanics, moduledoc voice

### Established Patterns
- Tax modules under `lib/lattice_stripe/tax/`
- ObjectTypes: add entries co-located with module delivery (49-CONTEXT D-04 stagger continues)
- Mox-at-Transport unit tests, `async: true`, no `@moduletag :integration` except stripe-mock TCP
- Bounded typing: `@known_fields` + `extra`; volatile → maps

### Integration Points
- `object_types.ex` — two new entries
- `Tax.Calculation` moduledoc may cross-link Settings default `tax_code` (optional one-line; full flow in Phase 51 guide)
- No changes to `Invoice.AutomaticTax`

</code_context>

<specifics>
## Specific Ideas

- **Cross-SDK:** Official SDKs type Tax deeply via OpenAPI — LatticeStripe wins on bounded handwritten ergonomics, not parity with stripe-ruby `CountryOptions` kwargs.
- **stripity_stripe footgun:** Stale/missing Tax surfaces and global-config magic — LatticeStripe explicit `Client` + current paths.
- **Pitfall #7 is the phase's highest-risk bug:** Settings implemented as CRUD with fake ID — module surface tests are the structural prevention, not a chain test.
- **Configuration resources are orthogonal:** Settings/Registration enhance Calculation but do not share a stateful ID handoff like calc→txn — chain test would be theater on Mox.
- **Adopter mental model:** `Registration.create` ≠ legal registration with authorities — moduledoc must say so in the first operational section.

</specifics>

<deferred>
## Deferred Ideas

- Chained Mox workflow: settings retrieve → registration create → calculation (no wire coupling; Phase 51 guide narrative only)
- Per-country `CountryOptions` structs — codegen depth, rejected
- `SingletonResource` behaviour — until third singleton
- Request param builders for nested `country_options` — Phase 50+ raw maps
- stripe-mock Tax settings/registration smoke — optional, not gate
- Full jurisdiction matrix in moduledoc — Phase 51 `guides/tax.md`
- Docs-truth grep blocks — Phase 51 (DX-05)

</deferred>

---

*Phase: 50-tax-settings-registration*
*Context gathered: 2026-05-27*
