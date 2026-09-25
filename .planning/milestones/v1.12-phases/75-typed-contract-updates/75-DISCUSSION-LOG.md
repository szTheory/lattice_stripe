# Phase 75: Typed Contract Updates - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-23
**Phase:** 75-typed-contract-updates
**Areas discussed:** Field eligibility, adopter-facing typed contract, proof and documentation

---

## Field eligibility

| Option | Description | Selected |
|--------|-------------|----------|
| Reopen candidates behind both evidence gates | Establish exact drift inventory membership and immutable GA schema identity/path before selection. | ✓ |
| Promote from changelog descriptions or mutable schema | Faster, but would leave Phase 74's documented provenance and membership gaps unresolved. | |
| Change the default API pin or add broad versioned models | Could expose newer shapes but creates a separate cross-cutting compatibility obligation. | |

**User's choice:** Accepted the complete research recommendation set.
**Notes:** If no candidate passes both evidence gates, do not invent a selection or begin field implementation. Keep `2026-03-25.dahlia`; any pin change requires the separate D-10 review.

---

## Adopter-facing typed contract

| Option | Description | Selected |
|--------|-------------|----------|
| Add qualified optional fields to existing structs | Follow current decoders and typespecs; preserve `extra`, open values, and expandable ID/object shapes; document minimum API version. | ✓ |
| Leave new fields in `extra` | Low commitment, but less discoverable and less ergonomic for adopters. | |
| Add strict nested or per-version response schemas | Stronger apparent constraints, with higher maintenance and forward-compatibility risks. | |

**User's choice:** Accepted the complete research recommendation set.
**Notes:** No Ecto schema, closed enum, new modeling dependency, or version-specific resource family for this bounded response-decoding change.

---

## Proof and documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Focused decoder tests and provenance-labeled fixtures | Cover only qualified wire shapes and preserve unknown fields; update public docs and changelog with version/surface caveats. | ✓ |
| Broad API-version matrix | Useful for a wider compatibility project, disproportionate for a few optional response fields. | |
| Provider or Phoenix integration proof | Reserve for changes that cross request, webhook, or host-app boundaries. | |

**User's choice:** Accepted the complete research recommendation set.
**Notes:** This headless library phase has no visual UI scope; its UX surface is the API and HexDocs. No broad integration claim should be inferred from decoder tests.

---

## the agent's Discretion

- Select only the coherent, adopter-valued candidate cluster that passes Phase 74 evidence gates.
- Follow established decoder/test patterns and prove only schema-supported shapes.
- Replan if evidence reveals request, webhook, or broader compatibility consequences.

## Deferred Ideas

- Default API pin migration pending the full compatibility review.
- Broad API-versioned response models.

