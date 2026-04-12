---
phase: 12
slug: billing-catalog
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-11
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) + StreamData ~> 1.1 (property tests) + Mox (behaviour mocks) |
| **Config file** | `test/test_helper.exs` (no changes expected); `mix.exs` (add `{:stream_data, "~> 1.1", only: :test}`) |
| **Quick run command** | `mix test --exclude integration` |
| **Full suite command** | `mix test` (requires `stripe-mock` running on `localhost:12111`) |
| **Estimated runtime** | ~30s quick, ~90s full (with stripe-mock integration) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --exclude integration <changed_test_file>` (≤10s)
- **After every plan wave:** Run `mix test --exclude integration` (full unit + property suite)
- **Before `/gsd-verify-work`:** `mix test` (unit + property + integration) must be green
- **Max feedback latency:** 10 seconds per-task, 90 seconds per-wave

---

## Per-Task Verification Map

> Populated by planner. Every task with code output MUST have either (a) an `<automated>` verify command or (b) a Wave 0 dependency that establishes the test file/fixture it will be verified against.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-XX-XX | TBD | 0 | BILL-01/02/06/06b | — | N/A | unit | `mix test test/lattice_stripe/<file>_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `mix.exs` — add `{:stream_data, "~> 1.1", only: :test}` dep; run `mix deps.get`
- [ ] `test/lattice_stripe/discount_test.exs` — unit stubs (struct + from_map/1)
- [ ] `test/lattice_stripe/product_test.exs` — unit stubs (CRUD + search + from_map/1)
- [ ] `test/lattice_stripe/price_test.exs` — unit stubs (CRUD + search + Recurring/Tier + atomization)
- [ ] `test/lattice_stripe/coupon_test.exs` — unit stubs (CRUD no-update no-search + AppliesTo)
- [ ] `test/lattice_stripe/promotion_code_test.exs` — unit stubs (CRUD no-search + list filters)
- [ ] `test/lattice_stripe/form_encoder_test.exs` — extend existing file with new `describe` blocks for battery (D-09a/b/c/d/e/f)
- [ ] `test/integration/product_integration_test.exs` — stripe-mock scaffold
- [ ] `test/integration/price_integration_test.exs` — stripe-mock scaffold (incl. triple-nested `price_data`)
- [ ] `test/integration/coupon_integration_test.exs` — stripe-mock scaffold
- [ ] `test/integration/promotion_code_integration_test.exs` — stripe-mock scaffold

---

## Validation Dimensions (per 12-RESEARCH.md § Validation Architecture)

| Dimension | Coverage | Owning Test Files |
|-----------|----------|-------------------|
| **Unit — struct + from_map/1** | Each resource decodes stripe-mock fixture into struct; nil fields omitted; atomization whitelist hits all documented enum values AND passes unknown string through | `*_test.exs` per resource |
| **Unit — CRUD signature surface** | Every listed function exists with correct arity; forbidden ops absent (`Code.ensure_loaded?/1` + `function_exported?/3` assertions for Price.delete/4, Coupon.update/4, Coupon.search/3, PromotionCode.search/3 == false) | `*_test.exs` per resource |
| **Unit — FormEncoder battery (D-09a)** | 14 enumerated shapes with golden wire-format strings | `form_encoder_test.exs` |
| **Property — FormEncoder invariants (D-09b)** | nil never emitted, determinism, URL-decodable, no key collisions | `form_encoder_test.exs` (StreamData) |
| **Unit — float scientific-notation fix (D-09f)** | `0.00001`, `1.0e-20`, `12.5`, `0.0`, negative floats all produce non-scientific output | `form_encoder_test.exs` |
| **Unit — atom round-trip (D-09e)** | `%{interval: :month}` and `%{interval: "month"}` encode identically | `form_encoder_test.exs` |
| **Unit — empty-string clear semantics (D-09d)** | `nil` omits; `""` emits `key=` | `form_encoder_test.exs` |
| **Unit — metadata special chars (D-09c)** | hyphen / slash / space in keys URL-encode correctly, brackets not double-encoded | `form_encoder_test.exs` |
| **Contract — struct field inventory** | `@known_fields` matches research-enumerated Stripe field list per resource | `*_test.exs` per resource |
| **Contract — eventual-consistency doc (D-10)** | `Product.search/2` and `Price.search/2` `@doc` both contain the shared callout string | `*_test.exs` — grep-style assertion on `Code.fetch_docs/1` |
| **Contract — forbidden-ops @moduledoc (D-05)** | Every module with forbidden ops has `## Operations not supported by the Stripe API` section | `*_test.exs` — `Code.fetch_docs/1` assertion |
| **Integration — stripe-mock round-trip** | Create/retrieve/update/list/stream for each resource hits stripe-mock and decodes cleanly | `test/integration/*_integration_test.exs` |
| **Regression — Customer.discount backfill (D-02)** | `Customer.from_map/1` with a fixture containing `discount` returns `%Discount{}`, not a `map()` | `customer_test.exs` |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Eventual-consistency wording identical across all search `@doc`s | ROADMAP success #4 | ExUnit can assert presence but wording review is semantic | Reviewer greps `Product` + `Price` module docs, confirms string matches D-10 block verbatim |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (test stubs + `stream_data` dep)
- [ ] No watch-mode flags (`mix test` is one-shot)
- [ ] Feedback latency < 90s full suite
- [ ] `nyquist_compliant: true` set in frontmatter (after planner populates verification map)

**Approval:** pending
