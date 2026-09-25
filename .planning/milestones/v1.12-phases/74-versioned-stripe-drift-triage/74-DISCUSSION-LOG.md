# Phase 74: Versioned Stripe Drift Triage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-23
**Phase:** 74-Versioned Stripe Drift Triage
**Areas discussed:** Reliable Stripe evidence, Candidate prioritization, Actionable triage and API pin

**Mode:** User selected all areas and requested a one-shot research-backed recommendation that reconciles project prompts, Elixir conventions, Stripe SDK prior art, adopter JTBD, architecture, compatibility, operational concerns, and developer experience. Three `gsd-advisor-researcher` subagents researched one area each. There is no separate UI/brandbook for this headless SDK; API shape, decoding, errors, examples, and HexDocs are the applicable user-experience surfaces.

---

## Reliable Stripe evidence

| Option | Description | Selected |
|--------|-------------|----------|
| Promote from OpenAPI `master` diff | Fast, broad, and automatable discovery, but does not prove stable status or pinned-version applicability | |
| Require stable, versioned Stripe source corroboration | Changelog/reference plus GA OpenAPI provenance supports reproducible applicability and type decisions | ✓ |
| Require runtime probe as primary evidence | Demonstrates one observed behavior but cannot establish GA stability and may be account/mock-specific | |

**User's choice:** 1 — accept the synthesized recommendation set.
**Notes:** The drift checker remains discovery only. Candidates need stable, versioned Stripe documentation and GA OpenAPI corroboration. Record version applicability and classify current stable, later stable, preview-only, or unconfirmed/schema noise. Probes corroborate but do not establish stability. Official Stripe OpenAPI documentation distinguishes GA `/latest` and preview `/preview`; official typed SDK guidance also cautions that API-version overrides may diverge from generated types.

## Candidate prioritization

| Option | Description | Selected |
|--------|-------------|----------|
| Rank by drift count or recency | Objective and easy to automate, but weakly connected to adopter value | |
| Rank by adopter JTBD and operational consequence | Prioritizes useful flow outcomes and meaningful failure consequences | ✓ |
| Require stable source and type/decode coherence | Essential eligibility gate, but not a complete value-ranking method | |

**User's choice:** 1 — accept the synthesized recommendation set.
**Notes:** First apply evidence and decode-safety gates. Then prioritize adopter job, operational consequence, and coherent additions. Apply extra weight to money, tax, fulfillment, webhook, Connect context, and reconciliation. Avoid numeric scoring and per-resource quotas; keep reasons reviewable and the SDK boundary at Stripe-shaped primitives.

## Actionable triage and API pin

| Option | Description | Selected |
|--------|-------------|----------|
| Concise Markdown triage document | Human-reviewable and adequate for the bounded decision set | ✓ |
| Structured ledger plus generated report and validator | Machine-checkable and reusable, but introduces tooling/schema maintenance | |
| GitHub issue per candidate | Familiar workflow, but fragments decisions and creates inventory noise | |

**User's choice:** 1 — accept the synthesized recommendation set.
**Notes:** Selected and deferred candidates carry resource/field, stable source and API version/status, current-pin applicability, adopter job, rationale, type/decode implications, and disposition; deferrals state why and what reopens them. Keep the default pin at `2026-03-25.dahlia`. A possible pin change needs a separate compatibility review across changelog, request and response behavior, webhook versions, adopter proof, and SemVer; date freshness or one fixture is not enough.

## Research synthesis and project-specific checks

- Compared official Stripe sources (versioning docs, GA/preview OpenAPI separation, and Stripe Node/Ruby SDK policies) with Elixir typespec, Ecto enum, and project library conventions.
- Reviewed `prompts/README.md`, the current payments field guide, and applicable historical Stripe SDK / Elixir OSS research prompts. Historical prompt content is background, not authority over current source/docs.
- Confirmed the codebase is a headless package, not a Phoenix app or Ecto persistence layer. The consumer UX is typed resource access, forward-compatible decoding, focused errors, and discoverable HexDocs.
- Applied the existing `extra` preservation rule and project SemVer boundary. Do not expose raw OpenAPI internals as a new public abstraction.
- Research agents agreed on versioned source qualification and adopter-first ranking. The synthesis deliberately kept the Phase 74 artifact human-readable rather than adding a structured generator/validator for this bounded triage.

## The agent's Discretion

- Exact Markdown layout and concise evidence wording.
- The candidate shortlist and coherent field grouping after current source review, within the stable-source, adopter-value, and compatibility constraints.
- Flag unresolved sources as unconfirmed/deferred rather than promoting them.

## Deferred Ideas

- Changing the default Stripe API version — revisit only with separate compatibility evidence.
- Building a recurring machine-validated candidate ledger/report — defer unless this review demonstrates the Markdown artifact is insufficient.
- Promoting preview-only or schema-only changes — revisit when stable versioned evidence exists.
