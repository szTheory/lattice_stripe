---
phase: "75"
slug: "typed-contract-updates"
status: planned
nyquist_compliant: false
wave_0_complete: true
created: "2026-09-24"
---

# Phase 75 — Validation Strategy

The 2026-09-24 refresh in `75-EVIDENCE.md` qualifies `Invoice.amount_paid_off_stripe` and the three selected Refund attribution fields. These tests prove SDK decoding from schema-derived synthetic responses, not captured live Stripe behavior.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | ExUnit (existing repository suite) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/invoice_test.exs` and `mix test test/lattice_stripe/refund_test.exs` |
| Full suite command | `mix ci` after implementation is eligible |
| Estimated runtime | Not measured during planning; no tests were run |

## Sampling Rate

- After each decoder/test task: run its focused resource test file.
- After the implementation wave: run the relevant compatibility checks and full suite.
- Before phase verification: require all planned automated checks to pass.
- Feedback latency: focused suites after their matching task; complete `mix ci` at the end of 75-02.

## Per-Task Verification Map

| Requirement | Planned executable proof |
|---|---|
| DRIFT-02 | Named `Invoice.retrieve/3` and `Refund.retrieve/3` tests exercise selected fields through MockTransport and assert an unrelated response key remains in `extra`. |
| DRIFT-03 | Focused `from_map/1` cases cover ordinary, omission/null, and supported ID/expanded forms; `mix lattice_stripe.api_surface --check` plus inspection of the additive lock diff protects the public contract. |
| DRIFT-04 | `mix lattice_stripe.version_prose --check` and `mix docs --warnings-as-errors` check the version/docs surface; `mix ci` runs the full repository gate. |

Every new payload is labeled schema-derived and cites Stripe OpenAPI commit `c8faccbde66b784ea916d3c28f5790d7a9c9aee2`, the exact JSON pointer, and minimum API version. The tests do not prove live endpoint/event behavior.

## Wave 0 Requirements

- [x] `75-EVIDENCE.md` records successful exact-path drift output for all four selected fields.
- [x] `75-EVIDENCE.md` records immutable GA OpenAPI commit, hashes, exact pointers, and dated version/surface sources.
- [x] Planned fixture provenance is schema-derived, with per-field pointers and version floors required by 75-01 and 75-02.

The prior `:eperm` attempt in research is superseded by the successful 2026-09-24 task run recorded in `75-EVIDENCE.md`. The drift command exits 1 when drift is found.

## Manual-Only Verifications

No field-specific human check is planned. The public API lock diff requires compatibility review before the updated snapshot is accepted. Any later live Stripe behavior claim would need separately scoped evidence.

## Validation Sign-Off

- [x] All planned implementation tasks have executable verification.
- [x] Wave 0 evidence gate is complete.
- [x] Sampling continuity is established by 75-01 and 75-02.
- [ ] `nyquist_compliant: true` set after eligible work has a real validation map.

**Approval:** evidence-qualified plan; execution checks pending
