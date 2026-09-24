---
phase: "74"
slug: "versioned-stripe-drift-triage"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-23"
---

# Phase 74 — Validation Strategy

> This phase produces a human-reviewed evidence and selection record. Automated checks can catch document hygiene issues, but cannot establish Stripe release status, GA schema membership, or adopter value.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit exists in the repository; no runtime behavior is changed in this phase |
| **Config file** | `mix.exs` / `test/test_helper.exs` |
| **Quick run command** | `git diff --check` |
| **Full suite command** | Not applicable to a documentation-only evidence artifact |
| **Estimated runtime** | Under 1 second |

## Sampling Rate

- **After every task commit:** Run `git diff --check` to detect whitespace errors.
- **After every plan wave:** Review the entire triage record against D-01–D-11.
- **Before `$gsd-verify-work`:** Complete source-by-source human review of every selected and deferred row.
- **Max feedback latency:** Under 1 second for the automated hygiene check.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 74-01-01 | 01 | 1 | DRIFT-01 | — | Public-source provenance remains explicit; no credentials required | document hygiene | `git diff --check` | ✅ | ⬜ pending |
| 74-01-02 | 01 | 1 | DRIFT-01 | — | Preview or unconfirmed evidence is never described as promotable | human evidence review | Manual review per criteria below | ✅ | ⬜ pending |

## Wave 0 Requirements

Existing infrastructure covers the phase requirement. No code tests, fixtures, or test dependencies are required for this documentation-only phase.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Every candidate has a dated stable/versioned source, explicit API version/status, and exact GA OpenAPI corroboration or an explicit unconfirmed/deferred disposition | DRIFT-01 | No automated check can establish provenance or distinguish authoritative GA evidence from preview/schema noise without replacing the human review this phase exists to perform | Open each cited Stripe source; verify the exact resource path, API version and stable/preview designation. Compare selected candidates with the exact GA OpenAPI snapshot. If any check is unavailable or ambiguous, mark the candidate unconfirmed/deferred and state what evidence reopens it. |
| Selected and deferred rows state current-pin applicability, adopter job, semantic rationale, type/decode implications, and disposition; every deferral gives a reason and reopening evidence | DRIFT-01 | These are semantic and prioritization judgments | Review every row against D-05–D-09 and confirm open-enum/`extra` compatibility under D-11. |
| Default API pin remains `2026-03-25.dahlia`; no pin change is proposed without a separate compatibility review | DRIFT-01 | Compatibility assessment spans request semantics, response decoding, webhook versions, adopter flows, and SemVer | Confirm the triage record explicitly preserves the default pin and does not treat date freshness or one fixture as sufficient change evidence. |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 1s for automated hygiene check
- [ ] `nyquist_compliant: true` set in frontmatter after evidence review

**Approval:** pending human evidence review
