---
phase: 70
slug: client-core-test-architecture
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-25
---

# Phase 70 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit + API snapshot |
| Quick run | `mix test test/lattice_stripe/client --warnings-as-errors` |
| Full suite | `mix ci` |

## Requirement Map

| Requirement | Automated evidence | Status |
|-------------|--------------------|--------|
| ARCH-01 | 85 façade characterization tests exercise builder → executor → decoder delegation | covered behavior; structure source-reviewed |
| ARCH-02 | five behavior-named client suites run independently and in full CI | covered behavior; navigation manually reviewed |
| ARCH-03 | helper behavior, docs-truth, and warning-free ExDoc | covered behavior; prose/path review manual |
| ARCH-04 | API lock test and `mix lattice_stripe.api_surface --check` | covered |

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Result |
|----------|-------------|------------|--------|
| Private module cohesion and behavior-led test navigation | ARCH-01, ARCH-02 | Cohesion and findability are design judgments, not stable syntax contracts. | passed integration audit |
| Testing-helper paths and microcopy read naturally | ARCH-03 | Reader ergonomics exceeds compile/link correctness. | passed documentation audit |

## Validation Sign-Off

- [x] Public behavior and API freeze are fully automated.
- [x] Design-quality boundaries are explicitly human-reviewed.

**Approval:** validated 2026-08-25 (partial Nyquist; design review retained)
