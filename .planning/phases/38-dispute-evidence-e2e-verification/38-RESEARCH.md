# Phase 38: Dispute Evidence E2E Verification - Research

**Researched:** 2026-05-25
**Domain:** Verification closure for File/FileLink and Dispute, with end-to-end dispute-evidence integration coverage under `stripe-mock`
**Confidence:** HIGH

## Summary

Phase 38 is a verification-closure phase, not a feature-build phase. The core File/FileLink and Dispute code already exists, unit coverage is already strong, and the milestone audit identifies two concrete gaps:

1. there is no closed `33-VERIFICATION.md`
2. there is no integration test that proves the cross-phase evidence workflow from `File.create/3` into `Dispute.update_evidence/4` and `Dispute.submit_evidence/3`

The smallest coherent split is two plans:

- Plan 01 adds the missing dispute integration coverage, centered on uploaded file evidence and submit flow
- Plan 02 closes the milestone evidence for Phase 32 and Phase 33 by refreshing `32-VERIFICATION.md`, creating `33-VERIFICATION.md`, and updating requirement traceability for FILE/DISP

## Primary Findings

### 1. The code gap is narrowly scoped to dispute integration

`test/integration/file_integration_test.exs` already covers:

- `File.create/3`
- `File.retrieve/3`
- `File.list/3`
- `FileLink.create/3`
- `FileLink.retrieve/3`
- `FileLink.update/4`
- `FileLink.list/3`

`test/lattice_stripe/dispute_test.exs` already covers the dispute API surface under Mox:

- `retrieve/3`
- `list/3`
- `stream!/3`
- `update/4`
- `update_evidence/4`
- `submit_evidence/3`
- `close/3`
- nested typed deserialization for `Evidence`, `EvidenceDetails`, and `PaymentMethodDetails`

So the missing runtime proof is not “does Dispute exist?” but “does the evidence flow work end-to-end against the wire contracts already implemented?”

### 2. The milestone audit is explicit about the evidence workflow it still lacks

`.planning/v1.3-v1.3-MILESTONE-AUDIT.md` calls out:

- partial Phase 32 verification because `32-VERIFICATION.md` is still `human_needed`
- missing `33-VERIFICATION.md`
- missing `File.create/3 -> Dispute.update_evidence/4` integration coverage
- missing `Dispute.submit_evidence/3` integration coverage

That means Phase 38 should optimize for directly satisfying the audit language instead of broadening scope into new features or planning-truth cleanup that belongs later in Phase 42.

### 3. `stripe-mock` realism is limited, but still sufficient for this phase

The repo’s existing integration tests already treat `stripe-mock` as a shape-and-routing verifier rather than a persistence-accurate backend. That same posture should apply here:

- uploaded file creation should return a real `%LatticeStripe.File{}`
- evidence staging should prove the SDK can pass a real uploaded file ID into dispute evidence fields
- evidence submission should prove the SDK can hit the submit path without malformed params
- retrieve/list/close/update metadata can be shape-only assertions on mock IDs

The tests should document that `stripe-mock` is stateless and may not model the true dispute lifecycle; the value is transport correctness plus response decoding.

### 4. Verification closure should reconcile prior phase evidence, not re-argue implementation

Phase 32 already has a strong verification file, but its frontmatter leaves the milestone workflow blocked with `status: human_needed`.
Phase 33 has summaries and passing unit tests but no verification report at all.

So the documentation work in Phase 38 should:

- preserve the existing verified truths from Phase 32
- add the new dispute-evidence integration evidence to the FILE requirements that depend on it
- create a proper Phase 33 verification report tied to `33-01` and `33-02` summaries plus the new integration run
- update `.planning/REQUIREMENTS.md` traceability rows for `FILE-01..05` and `DISP-01..07` so the audit has current status, not stale `Pending`

## Recommended Plan Split

### Plan 01

Scope:

- add `test/integration/dispute_integration_test.exs`
- cover `File.create/3 -> Dispute.update_evidence/4`
- cover `Dispute.submit_evidence/3`
- add enough dispute integration shape coverage to support closed verification for DISP requirements

Why first:

- it produces the missing runtime evidence the audit explicitly asks for
- the verification documents in Plan 02 should cite a concrete integration run, not speculate about intended coverage

### Plan 02

Scope:

- refresh `.planning/phases/32-file-filelink/32-VERIFICATION.md` into a closed verifier state
- create `.planning/phases/33-disputes/33-VERIFICATION.md`
- update `.planning/REQUIREMENTS.md` traceability rows for FILE/DISP

Why second:

- milestone-ready evidence depends on the integration artifacts created in Plan 01
- it keeps executable test work separate from audit reconciliation and planning docs

## Verification Strategy

- Targeted automated check for Plan 01: `mix test test/integration/dispute_integration_test.exs --include integration`
- Supporting regression check for Plan 01: `mix test test/lattice_stripe/dispute_test.exs test/integration/file_integration_test.exs --include integration`
- Plan 02 is primarily document verification, but it must be backed by concrete command output from the relevant unit/integration suites and by line-level artifact references
- Full phase close should still cite `mix test` or the most recent full-suite evidence if a fresh full run is not part of the plan execution

## Execution Recommendation

Keep the phase narrow:

- no new SDK features
- no reopening File/FileLink or Dispute API design
- no quote/mandate/credit-note spillover
- no planning-truth cleanup beyond FILE/DISP requirement traceability needed for milestone evidence

Success is a small new integration module plus closed verification artifacts that directly answer the milestone audit’s open findings.
