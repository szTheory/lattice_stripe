# Phase 77: Adopter Edge Profiles and CI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-24  
**Phase:** 77-adopter-edge-profiles-and-ci  
**Areas discussed:** Profile shape and opt-in behavior, Distinct contract coverage, CI gate and determinism

---

## Profile shape and opt-in behavior

| Option | Description | Selected |
|--------|-------------|----------|
| One shared host app with independently selectable profile tests | Reuse the Phase 76 Phoenix app and isolate scenarios in tests/tags. | ✓ |
| Separate host app per profile | Create an app for B2B, usage, and Connect independently. | |

**Auto selection:** Recommended default selected (`--auto`). Keep the existing one-app boundary and use independently selectable test scenarios.

---

## Distinct contract coverage

| Option | Description | Selected |
|--------|-------------|----------|
| One distinct SDK contract per profile plus shared boundary cases | Select a small contract per profile and share relevant error/idempotency/webhook checks. | ✓ |
| Broad end-to-end business workflows for each profile | Build fuller application workflows for each adopter context. | |

**Auto selection:** Recommended default selected (`--auto`). Exact SDK operations remain subject to source-backed research.

---

## CI gate and determinism

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated single-toolchain adopter job | Run the nested complete suite once on Elixir 1.19 / OTP 28. | ✓ |
| Run adopter in the full SDK version matrix | Expand host-app compatibility coverage across every package matrix entry. | |

**Auto selection:** Recommended default selected (`--auto`). Preserve the existing package matrix and focus the adopter gate on the primary toolchain.

---

## the agent's Discretion

- Exact supported resource calls, fixtures, test tags/files, and README wording are to be determined from existing SDK contracts during planning.

## Deferred Ideas

- Separate applications and full application-owned billing/business policies were not included; they exceed the phase's contract-test boundary.
