---
phase: 75-typed-contract-updates
verified: 2026-09-24T12:50:06Z
status: passed
score: 4/4 roadmap truths verified
covered_files:
  - .planning/REQUIREMENTS.md
  - .planning/phases/75-typed-contract-updates/75-01-PLAN.md
  - .planning/phases/75-typed-contract-updates/75-01-SUMMARY.md
  - .planning/phases/75-typed-contract-updates/75-02-PLAN.md
  - .planning/phases/75-typed-contract-updates/75-02-SUMMARY.md
  - CHANGELOG.md
  - guides/invoices.md
  - lib/lattice_stripe.ex
  - lib/lattice_stripe/invoice.ex
  - lib/lattice_stripe/refund.ex
  - priv/api/current.txt
  - test/lattice_stripe/invoice_test.exs
  - test/lattice_stripe/refund_test.exs
  - test/lattice_stripe/typed_contract_docs_test.exs
covered_digest: "v1:sha256:072bc3218ab0f6549817b943c0e0def4b3966f6f14915463c5e19399191b9543"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 75: Typed Contract Updates Verification Report

**Phase Goal:** Adopters can use the selected high-value fields as typed data without losing unknown-field access or changing existing public behavior.
**Verified:** 2026-09-24T12:50:06Z
**Status:** passed
**Re-verification:** No — the prior report had no `gaps:` section; this refresh adds evidence for the previously human-routed criterion.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Selected fields decode from stable-version fixtures into documented typed values. | ✓ VERIFIED | `Invoice.from_map/1` assigns the optional integer `amount_paid_off_stripe`; `Refund.from_map/1` assigns `customer`, `customer_account`, and `payment_method`, using `ObjectTypes.maybe_deserialize/1` for expandable fields. Named schema-derived tests cover retrieval at the explicit minimum API versions and typed values: `invoice_test.exs#retrieve/3 retrieves off-Stripe payment amount with the explicitly selected API version`; `refund_test.exs#retrieves schema-derived attribution fields at their minimum API version`. The tests name the pinned OpenAPI commit and property paths. |
| 2 | Regression coverage proves unknown response fields remain available through `extra`. | ✓ VERIFIED | Both resource decoders use `Map.split(map, @known_fields)` and assign the remainder to `extra`. The new retrieval assertions retain `future_reconciliation_key` / `future_refund_key`, and existing unknown-field tests remain in each focused test file. |
| 3 | Compatibility checks show existing public behavior is preserved and intended additions are reviewed against package SemVer policy. | ✓ VERIFIED | `priv/api/current.txt` contains the added Invoice and Refund fields; the summaries report reviewed diffs with additions only (3,464 entries after Invoice, 3,467 after Refund). The Invoice retrieval test retains `amount_paid: 300`; Refund retrieval asserts the existing `charge`, `payment_intent`, and `status`, with separate tests for null/omitted, ID/expanded/deleted-customer forms and Inspect redaction. The default is still `2026-03-25.dahlia` in `lib/lattice_stripe.ex`. Supplied final `mix ci` evidence: 2,461 tests, 0 failures, 1 skipped; API lock, version prose, and docs checks passed. |
| 4 | Adopter documentation identifies the relevant Stripe API-version contract and selected fields. | ✓ VERIFIED | `test/lattice_stripe/typed_contract_docs_test.exs#Invoice and Refund docs state their version and response-scope contracts` passes. It reads the public module docs, Invoice guide, and changelog, and asserts both minima, response scopes, webhook caveats, selected fields, and unchanged default. |

**Score:** 4/4 truths verified.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/lattice_stripe/invoice.ex` | Optional typed invoice field and decoder | ✓ VERIFIED | `@known_fields`, struct, `@type t`, and `from_map/1` include `amount_paid_off_stripe: integer() | nil`; unknown map entries flow to `extra`. |
| `test/lattice_stripe/invoice_test.exs` | Schema-derived retrieval and decoder regressions | ✓ VERIFIED | Asserts integer field, unchanged `amount_paid`, unknown-key retention, omitted/null decoding, and explicit Stripe-Version request header. |
| `lib/lattice_stripe/refund.ex` | Optional attribution fields and decoder | ✓ VERIFIED | Struct/typespec/decoder include the three fields; known expandable fields are deserialized and the map remainder is kept in `extra`. |
| `test/lattice_stripe/refund_test.exs` | Retrieval, nullable, expandable, and compatibility coverage | ✓ VERIFIED | Covers request version, all selected fields, unknown-key retention, existing values, null/omitted, expanded objects, deleted-customer raw map, and Inspect redaction. |
| `guides/invoices.md` | Invoice reconciliation guidance | ✓ VERIFIED | Gives amount units, API request response scope, `2026-05-27.dahlia` opt-in, and unchanged default; the named docs contract test asserts these statements. |
| `CHANGELOG.md` | Unreleased adopter-facing contract | ✓ VERIFIED | Describes selected fields, version minima, Refund response scope, webhook caveat, and unchanged default; the named docs contract test asserts these statements. |
| `test/lattice_stripe/typed_contract_docs_test.exs` | Executable public prose contract | ✓ VERIFIED | Focused named test passes and checks the module docs, guide, and changelog for the version, response-scope, webhook, and default-version claims. |
| `priv/api/current.txt` | Reviewed additive API snapshot | ✓ VERIFIED | Summary records only four added field entries across the two plans, no removals or changed entries; lock check passed in supplied `mix ci` evidence. |
| `lib/lattice_stripe.ex` | Existing package API version default | ✓ VERIFIED | `@stripe_api_version` remains `2026-03-25.dahlia`. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `Invoice.retrieve/3` transport response | `Invoice.from_map/1` | Existing resource response decoding | ✓ WIRED | Named retrieval test returns the decoded Invoice, verifies GET and requested Stripe-Version, then checks the typed amount and `extra`. |
| Invoice `@known_fields` | `Invoice.extra` | `Map.split/2` in `from_map/1` | ✓ WIRED | Selected key is decoded into the typed field; unrelated key remains in the map assigned to `extra`. |
| `Refund.retrieve/3` transport response | `Refund.from_map/1` | Existing resource response decoding | ✓ WIRED | Named retrieval test checks the explicit minimum version, selected fields, unknown key, and existing refund fields. |
| Refund `@known_fields` | `Refund.extra` | `Map.split/2` in `from_map/1` | ✓ WIRED | Only selected known keys are promoted; unrelated response keys flow to `extra`. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| `Invoice.retrieve/3` | Invoice response map | Mocked transport response passed through production retrieval/decoder path | Yes; test supplies the same response shape that the transport decoder consumes, with provenance labeled schema-derived | ✓ FLOWING |
| `Refund.retrieve/3` | Refund response map | Mocked transport response passed through production retrieval/decoder path | Yes; named test exercises response-to-struct path, with schema-derived provenance | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Public docs state selected-field minima, response scopes, webhook caveats, and unchanged default | `mix test test/lattice_stripe/typed_contract_docs_test.exs` | 1 test, 0 failures | ✓ PASS |

The supplied post-merge `mix ci` result is recorded as evidence: 2,462 tests, 0 failures, 1 skipped; API lock, version prose, and docs checks passed. The skipped test identity was not provided, so this report does not claim that the skip is unrelated to these requirements.

## Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|---|---|---:|---:|---:|---|---|
| `test/lattice_stripe/invoice_test.exs` | DRIFT-02, DRIFT-03 | Yes | 0 observed | No | Behavioral/value | PASS |
| `test/lattice_stripe/refund_test.exs` | DRIFT-02, DRIFT-03 | Yes | 0 observed | No | Behavioral/value | PASS |
| `test/lattice_stripe/typed_contract_docs_test.exs` | DRIFT-04 | Yes | 0 | No | Exact text assertions | PASS; named test run passed |

No disabled requirement-linked tests, circular expected-value generation, or insufficient assertions were identified in these tests.

## Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probe was identified for this typed resource-contract phase.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DRIFT-02 | 75-01, 75-02 | Adopters access selected stable Stripe fields through typed resource fields while unknown fields remain in `extra`. | ✓ SATISFIED | Invoice and Refund decoder/retrieval assertions prove typed values and unknown-key retention. |
| DRIFT-03 | 75-01, 75-02 | Focused tests and compatibility checks preserve existing behavior. | ✓ SATISFIED | Focused tests cover existing values and edge forms; API snapshot checks passed as part of supplied CI evidence and summaries document additive-only review. |
| DRIFT-04 | 75-01, 75-02 | API version and promoted-field contract are documented; default changes only when justified. | ✓ SATISFIED | The new named docs contract test asserts both minima, response scopes, webhook caveats, and unchanged default across public docs; the test passes. |

No additional requirements mapped to Phase 75 were found beyond DRIFT-02, DRIFT-03, and DRIFT-04.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No implementation stubs, unreferenced debt markers, or disabled requirement-linked tests found in the scanned Invoice and Refund artifacts. | — | No blocker identified. |

## Human Verification Required

None. The previously human-routed prose claims now have a named passing executable assertion.

## Gaps Summary

All four roadmap truths and requirements DRIFT-02, DRIFT-03, and DRIFT-04 are verified. The new docs contract test closes the evidence gap for the public version and response-scope claims. No blocker or human verification item remains.

---

_Verified: 2026-09-24T12:50:06Z_  
_Verifier: the agent (gsd-verifier)_
