---
phase: 22
slug: expand-deserialization-status-atomization
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/object_types_test.exs` |
| **Full suite command** | `mix test` |
| **Integration suite** | `mix test --include integration` (requires stripe-mock on port 12111) |
| **Estimated runtime** | ~15 seconds (unit), ~45 seconds (full + integration) |

---

## Sampling Rate

- **After every task commit:** Run `mix test <module_test_file>` for the touched module
- **After every plan wave:** Run `mix test` (full unit suite)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | EXPD-01 | — | N/A | unit | `mix test test/lattice_stripe/object_types_test.exs` | ❌ W0 | ⬜ pending |
| 22-01-02 | 01 | 1 | EXPD-01 | T-22-01 | Private atomize_* whitelist (no String.to_atom) | unit | `mix test test/lattice_stripe/object_types_test.exs` | ❌ W0 | ⬜ pending |
| 22-02-01 | 02 | 2 | EXPD-03 | T-22-01 | Private atomize_* whitelist | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ✅ | ⬜ pending |
| 22-02-02 | 02 | 2 | EXPD-01 | — | N/A | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ✅ | ⬜ pending |
| 22-03-01 | 03 | 2 | EXPD-03 | T-22-01 | Private atomize_* whitelist | unit | `mix test test/lattice_stripe/<module>_test.exs` | ✅ | ⬜ pending |
| 22-04-01 | 04 | 3 | EXPD-04 | — | N/A | static | Review typespec changes | n/a | ⬜ pending |
| 22-04-02 | 04 | 3 | EXPD-04 | — | N/A | static | grep CHANGELOG.md for migration note | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/object_types_test.exs` — ObjectTypes.maybe_deserialize/1 unit tests (nil, string ID, known dispatch, unknown fallthrough)

*Existing test infrastructure covers all module test files — atomizer tests added during each wave.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CHANGELOG migration note clarity | EXPD-04 | Human-readable prose check | Read CHANGELOG entry; confirm it explains expand behavior change and pattern-match migration |
| Typespec union types | EXPD-04 | Static review (no Dialyzer) | Grep `@type t()` in touched modules; confirm expandable fields use `Module.t() \| String.t() \| nil` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
