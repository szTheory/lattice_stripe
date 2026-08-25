---
phase: 66
slug: product-feature-attachment
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-25
validated: 2026-08-25
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox Transport mock |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/product/feature_test.exs test/lattice_stripe/product/feature_stream_test.exs test/lattice_stripe/product_test.exs test/lattice_stripe/object_types_test.exs test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | Quick run < 30 seconds; full suite measured during execution |

---

## Sampling Rate

- **After every task commit:** Run the narrowest affected test file plus `MIX_ENV=prod mix compile`.
- **After every plan wave:** Run the quick command, `mix test`, and `mix docs`; record total tests and warning differential.
- **Before `$gsd-verify-work`:** Full suite must be green; total tests must be at least 2,332; `mix docs` must exit 0 with no more than 38 warnings and no new warning naming `LatticeStripe.Product.Feature` or the Phase 66 guides.
- **Max feedback latency:** 30 seconds for task-local checks; full-suite/docs checks occur at wave boundaries.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 66-01-01 | 01 | 1 | PROD-01 | T-66-03, T-66-04 | Create validates the Product and required attachment definition before transport, uses the scoped collection path, and preserves future response fields. | unit/Mox tracer | `mix test test/lattice_stripe/product/feature_test.exs --only tracer && MIX_ENV=prod mix compile` | ✅ file + case | ✅ pass — 1 tracer test; production compile exit 0 (66-01) |
| 66-01-02 | 01 | 1 | PROD-01 | T-66-03, T-66-04 | Retrieve/list/delete preserve explicit `prod_`/`prodft_` identity, reject a `feat_` delete target, and retain unknown response fields. | unit/Mox + surface regression | `mix test test/lattice_stripe/product/feature_test.exs && mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict` | ✅ file + case | ✅ pass — 16 focused tests; format, strict compile, and Credo green (66-01) |
| 66-02-01 | 02 | 2 | PROD-01 | T-66-01, T-66-02, T-66-04 | Complete enumeration preserves Product/Connect scope, filters, cursor identity, order, laziness, and loud later-page failure. | unit/Mox pagination | `mix test test/lattice_stripe/product/feature_stream_test.exs && git diff --quiet lib/lattice_stripe/list.ex && mix format --check-formatted` | ✅ file + case | ✅ pass — 4 pagination tests; List untouched; format green (66-02) |
| 66-03-01 | 03 | 2 | PROD-01, PROD-02 | T-66-02 | Legacy/current Product marketing fields remain raw, independent, and separate from authorization-bearing attachments. | unit regression | `mix test test/lattice_stripe/product_test.exs && git diff --quiet lib/lattice_stripe/product.ex` | ✅ file + case | ✅ pass — raw independent legacy/current map regression; runtime decoding unchanged (66-03) |
| 66-03-02 | 03 | 2 | PROD-01, PROD-02 | T-66-04 | Exact `product_feature` dispatch types the attachment and rejects the dotted typo without a brittle registry-size lock. | unit dispatch regression | `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/product_test.exs && mix compile --warnings-as-errors && mix format --check-formatted` | ✅ file + case | ✅ pass — exact-key typed dispatch and dotted-typo rejection; strict compile and format green (66-03) |
| 66-04-01 | 04 | 3 | PROD-01, PROD-02 | T-66-02, T-66-03 | HexDocs distinguishes marketing data, `feat_` definitions, and `prodft_` attachments while preserving the local authorization boundary. | production compile/ExDoc | `MIX_ENV=prod mix compile && mix docs` | ✅ file + case | ✅ pass — production compile and ExDoc green (66-04; rechecked at close) |
| 66-04-02 | 04 | 3 | PROD-01, PROD-02 | T-66-04 | The generated API lock admits only the accepted Product.Feature module, struct/type, canonical verbs, arities, and decoder. | API surface regression | `mix lattice_stripe.api_surface && mix lattice_stripe.api_surface --check && mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/product/feature_test.exs` | ✅ file + case | ✅ pass — 3,457-entry snapshot check and focused lock tests green (66-04; rechecked at close) |
| 66-05-01 | 05 | 4 | PROD-01, PROD-02 | T-66-02, T-66-03, T-66-04 | Guides lock complete catalog enumeration, explicit attachment identity, webhook reconciliation, and local fail-closed authorization without public-surface drift. | docs/API regression | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/product/feature_test.exs test/lattice_stripe/product_test.exs && mix docs` | ✅ file + case | ✅ pass — 95 focused tests; docs exit 0; 0 Phase-66 warning-name matches (66-05) |
| 66-05-02 | 05 | 4 | PROD-01, PROD-02 | T-66-02, T-66-03, T-66-04 | The phase-close differential gate measures every task, the inherited test floor, the warning ceiling, and the absence of Phase 66 warning names before validation flags change. | full-suite differential gate | Plan 05 Task 2 `<verify><automated>` exact failure-propagating command | ✅ existing | ✅ pass — 2,418 tests, 0 failures, 1 skipped; 0 docs warnings; production compile and API check green (66-05) |

Threat references:

- **T-66-01:** Cross-product or cross-tenant reads caused by losing Product scope or Connect headers on later pages.
- **T-66-02:** A partial list or marketing copy is mistaken for complete authorization truth.
- **T-66-03:** A `feat_...` definition ID is mistaken for the deletable `prodft_...` attachment ID.
- **T-66-04:** Future Stripe response fields are silently dropped or an incorrect object key bypasses typed dispatch.

---

## Wave 0 Requirements

- [x] `test/lattice_stripe/product/feature_test.exs` — PROD-01 resource, decoder, validation, options, tuple/bang, delete-shape, and public-surface proof.
- [x] `test/lattice_stripe/product/feature_stream_test.exs` — PROD-01 multi-page cursor, scope/options, order/type, early termination, and later-page failure proof.
- [x] Extend `test/lattice_stripe/product_test.exs` — PROD-02 raw and independent legacy/current marketing-field regression.
- [x] Extend `test/lattice_stripe/object_types_test.exs` — exact `product_feature` registry and typo-rejection proof.
- [x] Extend `test/lattice_stripe/docs_truth_test.exs` and `priv/api/current.txt` — semantic guide and public-surface locks.

The ExUnit/Mox infrastructure already exists; Wave 0 creates only Phase 66 test files and fixtures.

---

## Differential Gate Evidence

| Measurement | Required | Observed |
|-------------|----------|----------|
| `mix test` exit and parsed total | exit 0 and at least 2,332 tests | exit 0 — **2,418 tests, 0 failures, 1 skipped** (214 excluded) |
| `mix docs` exit and parsed warning count | exit 0 and no more than 38 warnings | exit 0 — **0 warnings** |
| Phase 66 docs-output name scan | zero matches for `LatticeStripe.Product.Feature`, `guides/entitlements.md`, and `guides/user-flows-and-jtbd.md` | **0 matches** — the close-gate grep did not match any forbidden name |

Plan 05 Task 2 captured every measurement above before setting `status: validated`,
`nyquist_compliant: true`, and `wave_0_complete: true`. The two inherited flakes
(`client_test.exs:912` and `batch_test.exs:72`) did not fire, so no rerun was needed.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Stripe-mock remains an additional CI lane when its supported API version exposes Product Feature attachments; it is not the sole proof of Phase 66 behavior.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s for task-local checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated from captured close-gate evidence: 2,418 passing tests,
0 ExDoc warnings, zero forbidden Phase 66 warning-name matches, strict format/compile/Credo,
production compile, and API surface check all passed. All nine task rows are reconciled.
