---
phase: 66
slug: product-feature-attachment
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
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
| 66-01-01 | 01 | 1 | PROD-01 | T-66-01, T-66-03 | Parent and attachment IDs are validated before transport; exact scoped paths are used. | unit/Mox | `mix test test/lattice_stripe/product/feature_test.exs` | ❌ W0 | ⬜ pending |
| 66-01-02 | 01 | 1 | PROD-01 | T-66-02 | Complete enumeration preserves scope/options and raises instead of returning a partial catalog. | unit/Mox | `mix test test/lattice_stripe/product/feature_stream_test.exs` | ❌ W0 | ⬜ pending |
| 66-02-01 | 02 | 2 | PROD-01 | T-66-04 | Exact `product_feature` dispatch retains unknown fields and rejects the typo key. | unit | `mix test test/lattice_stripe/object_types_test.exs` | ✅ extend | ⬜ pending |
| 66-02-02 | 02 | 2 | PROD-02 | T-66-02 | Marketing data remains separate from authorization-bearing attachments. | unit | `mix test test/lattice_stripe/product_test.exs` | ✅ extend | ⬜ pending |
| 66-03-01 | 03 | 2 | PROD-01, PROD-02 | T-66-02, T-66-03 | Docs preserve the reconciliation/fail-closed boundary and identifier distinction. | docs/API regression | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs` | ✅ extend | ⬜ pending |

Threat references:

- **T-66-01:** Cross-product or cross-tenant reads caused by losing Product scope or Connect headers on later pages.
- **T-66-02:** A partial list or marketing copy is mistaken for complete authorization truth.
- **T-66-03:** A `feat_...` definition ID is mistaken for the deletable `prodft_...` attachment ID.
- **T-66-04:** Future Stripe response fields are silently dropped or an incorrect object key bypasses typed dispatch.

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/product/feature_test.exs` — PROD-01 resource, decoder, validation, options, tuple/bang, delete-shape, and public-surface proof.
- [ ] `test/lattice_stripe/product/feature_stream_test.exs` — PROD-01 multi-page cursor, scope/options, order/type, early termination, and later-page failure proof.
- [ ] Extend `test/lattice_stripe/product_test.exs` — PROD-02 raw and independent legacy/current marketing-field regression.
- [ ] Extend `test/lattice_stripe/object_types_test.exs` — exact `product_feature` registry and typo-rejection proof.
- [ ] Extend `test/lattice_stripe/docs_truth_test.exs` and `priv/api/current.txt` — semantic guide and public-surface locks.

The ExUnit/Mox infrastructure already exists; Wave 0 creates only Phase 66 test files and fixtures.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Stripe-mock remains an additional CI lane when its supported API version exposes Product Feature attachments; it is not the sole proof of Phase 66 behavior.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for task-local checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
