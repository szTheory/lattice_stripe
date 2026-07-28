# Phase 64: Meter Event-Summary Reads - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-28
**Phase:** 64-meter-event-summary-reads
**Areas discussed:** Module name & namespace; MeterErrorReport depth; `list/4` guards & landmines; MTR-04 scope & proof

**Mode:** The user selected all four gray areas and requested deep subagent research on each — pros/cons/tradeoffs with worked examples, Elixir/Hex ecosystem idiom, lessons from comparable libraries in any language (what they got right, what footguns they shipped), DX and consumer-perspective API design, JTBD who/what/where/when/why, the `prompts/` commissioned research, and a coherent one-shot set of recommendations rather than a survey. Four `general-purpose` researchers ran in parallel; one spawned a cross-ecosystem sub-researcher of its own. Results were reconciled by the orchestrator, with divergences marked ⚠ in CONTEXT.md.

---

## Module name & namespace

| Option | Description | Selected |
|--------|-------------|----------|
| Nested `Billing.Meter.EventSummary` | As literally specified in REQUIREMENTS MTR-01/02 and ROADMAP SC#1/#2 | |
| **Flat `Billing.MeterEventSummary`** | Depth 2, named after the wire `"object"` string, matching the flat siblings and both parent-scoped precedents | ✓ |
| Hybrid (nested module name, depth-2 file) | Module says depth 3, file says depth 2 | |

**Outcome:** Flat — **overrules the written requirement** (CONTEXT D-01).

**Notes:** Three independent researchers converged, two of them unprompted while investigating other areas. Decisive evidence: zero of ~50 request-owning modules in `lib/` sit at depth 3 (verified directly by the orchestrator); within `"Billing Metering"` specifically, every depth-3 name is a non-request-owning value object and every request-owning module is depth 2, so nesting would actively mislead; both existing parent-scoped child resources (`TransferReversal`, `ExternalAccount`) are flat and wire-named; Stripe's own codegen directive says `{class_name: "MeterEventSummary", in_package: "Billing"}` and all six official SDKs plus `stripity_stripe` implement it; the wire↔module transform Phase 65 depends on is 43/43 outside the `LineItem` family; and ROADMAP already contradicted itself (its build constraint pointed at two flat templates while its success criterion said nested).

Counter-argument recorded and rejected: the requirement says nested, in writing. But nothing has shipped, module names are a one-way door, and amending costs four text edits versus a major version bump. Amendments applied to REQUIREMENTS.md and ROADMAP.md in this commit.

Also settled here: no `Billing.Meter.event_summaries/4` delegator (stripe-java#1852 — Stripe's docs advertised exactly that method; it never existed, and Stripe's reply was *"the docs is wrong"*).

---

## MeterErrorReport depth

| Option | Description | Selected |
|--------|-------------|----------|
| **Fully typed — 4 modules** | `MeterErrorReport` + `.Reason` + `.ErrorType` + `.SampleError`, ~90 LOC | ✓ |
| Partially typed | Type `ErrorType`, leave `sample_errors` as `[map()]` | |
| Raw maps | `reason :: map()`, one module | |
| 5th module for `request` | As all six typed SDKs do | |

**Outcome:** Fully typed, four modules (CONTEXT D-15).

**Notes:** The research overturned the requirement's premise before answering the question. Verified: there is **no `billing.meter_error_report` object and no `validation_errors` field anywhere** — zero hits across four Stripe spec files, the npm tarball, and stripe-go. It is a **v2 thin event whose `data` is a fetched attribute**, not present in the webhook body; all seven official SDKs encode this structurally by omitting `data` from their notification classes. MTR-03 was amended accordingly.

Typing rationale: 6 of 7 official SDKs give every nesting level a dedicated named type; the sole dissenter is stripe-php, which is exactly the raw-map shape this milestone exists to undo. Phase 63's D-02 reversibility asymmetry applies (raw→typed and typed→raw are both breaking, so choose the branch with the additive future). One argument was withdrawn honestly: the "free CheckDrift surveillance" case does **not** apply, because `Drift.@spec_url` points at a spec file that doesn't contain this schema and enrolment requires an `object` property this payload lacks.

The 5th `request` module was considered and rejected for Elixir specifically: `LatticeStripe.Request` is aliased in nearly every resource module, so the name collision is a real readability cost. Its one required field is hoisted as a typed `request_identifier` scalar with the verbatim wire object retained alongside.

Rejected on evidence: atomizing or whitelisting `code`. It is an Open Enum; plaid-python's closed enum with `_check_type=True` fails deserialization on new server values, and `stripity_stripe`'s closed atom union has gone stale at 14 atoms vs ~250 live codes.

---

## `list/4` guards & landmines

| Option | Description | Selected |
|--------|-------------|----------|
| **`list(client, meter_id, params \\ %{}, opts \\ [])` + 3 `require_param!` + `validate_id!` + GUARD-04 raise** | Pre-network validation of everything machine-checkable | ✓ |
| Moduledoc only, no guards | Follow a literal reading of Phase 63's D-09/D-11 | |
| Auto-aligning `align_window/2` helper | Round timestamps for the caller | |
| Positional required args | `list(client, meter_id, customer, start, end, opts)` | |

**Outcome:** Guards, no helper (CONTEXT D-05 … D-12).

**Notes:** The phase's make-or-break unknown resolved favourably — `billing.meter_event_summary` carries a required top-level `id` (`mtrusg_`), so `List.stream!`'s cursor derivation works unmodified and MTR-02 is implementable as specified.

Two divergences from Phase 63 were taken deliberately. **D-06** keeps `params \\ %{}` rather than extending D-14's no-default rule, because the just-shipped `ActiveEntitlement.list/3` has a required `customer` and keeps the default — diverging would make two consecutive phases inconsistent. **D-09** adds a private `validate_id!/2` despite D-11 rejecting nil/empty-id clauses; the re-verified 5-of-55 count is correct, but among *parent-scoped child-collection* modules it is 2 of 4, D-11's stated concern (a minority pattern masquerading as a house rule in a flagship module) doesn't apply to a leaf module that already raises three times pre-network, the mechanism proposed is a different and lighter one D-11 never considered, and stripe-go ships exactly this bug on exactly this endpoint (a nil id becomes `""` → `/v1/billing/meters//event_summaries`).

The auto-aligning helper was rejected on domain grounds with strong external corroboration: rounding changes what the query *means* (floor includes pre-period usage, ceil drops usage — a business decision). Orb auto-aligns to customer-local midnight so a 3-day UTC range silently yields 4 windows, and its `/events/volume` auto-widens so totals over-count; Datadog silently overrides an explicit `.rollup(60)`. Stripe alone hard-rejects. A raise that prints the arithmetic is the maximally-visible form of the same help at zero semver cost. Recorded as a deferred additive minor bump.

A researcher's own claim was corrected rather than inherited: the assertion that the alignment landmine bites "~100% on first run" is an inference from the spec, not an observation — issue archaeology found zero public reports for this endpoint (StackOverflow/Reddit were unreachable, so that angle is unchecked rather than negative).

---

## MTR-04 scope & proof

| Option | Description | Selected |
|--------|-------------|----------|
| Docs-only, as written | "Docs confirm arbitrary payload dimensions and decimal-string values" | |
| **Docs corrections + 4 proof tests** | Fix wrong shipped prose; prove the behavior structurally | ✓ |
| Docs + patch `to_string/1` in the encoder | Stop float→scientific-notation at source | |
| Add a docs-truth grep lock | Per the Phase 63 lock mechanism | |

**Outcome:** Re-scoped to corrections + tests; no encoder change; **zero** new grep locks (CONTEXT D-22 … D-29).

**Notes:** The encoder was cleared — verified by direct execution that arbitrary payload dimensions and decimal strings round-trip byte-exact, with no whitelist anywhere in the path. So MTR-04 stays a docs plan.

But "docs confirm X" turned out to be the wrong framing, because **three things a reader will infer are false and one is already shipped as prose**: `guides/metering.md` pitfall #4 claims integers trigger `meter_event_invalid_value`, when integer and string values produce byte-identical bodies on v1 (the string rule is v2-JSON-only); nested payload maps are rejected by Stripe with a synchronous 400 while our encoder builds them happily; and Elixir floats flip to scientific notation at `0.00001` — the narrowest threshold in the ecosystem, and the guide's own headline recipe calls `to_string(value)`. That pitfall text is v1.1-vintage and **accrue pins `~> 1.1`**, which closes the causal loop on why it drops the host payload.

Patching `to_string/1` was rejected as a silent cross-cutting change on the eve of a release, but recorded as a genuinely close call — stripe-go deliberately uses a formatter that never emits exponent notation, so LatticeStripe would be the only SDK shipping this hazard.

The grep lock was rejected on the mechanism's own terms: the failure mode here is "the prose says something false", and a grep asserts presence, not truth — pitfall #4 has been present-and-false since v1.1 with no lock noticing. Phase 63 spent D-25's three-lock budget; Phase 64 spends zero and proves the behavior with tests instead. Phase 63's D-19 (three surfaces for a fence) was examined and found not to transfer — it governs prohibitions, not affordances — yet duplication was adopted anyway for a different reason: the `@doc` itself is one of the miscommunicating artifacts.

Largest scope finding: **the phase's JTBD as briefed is not fully deliverable.** Dimension-grouped reads are preview-gated by Stripe (verified four ways). Dimensions are write-only on the GA API. That goes in `guides/scope.md` as an honest limitation — and, per D-27, the roadmap's internal "no new write surfaces" fence explicitly does *not*, because publishing it would misrepresent a completed surface as a gap.

---

## Claude's Discretion

The user asked for a one-shot coherent recommendation set rather than incremental choices, so all four areas were resolved by the orchestrator from the research. Exact prose, moduledoc wording, guide section copy, snippet selection, and test naming remain discretionary within the D-01…D-34 frame.

Two open items were deliberately *not* resolved and are recorded for a live test-mode probe rather than guessed (CONTEXT O-01…O-05) — most importantly whether Stripe's parser accepts `1.0e-5` as a payload value, which decides whether float mangling fails loudly or silently corrupts a bill. stripe-mock cannot answer it (it validates `type: string` only). The interim guide wording was chosen to be correct under every outcome.

## Deferred Ideas

- `/v1/billing/analytics/meter_usage` — Stripe's preview successor (adds IANA `timezone`, `refreshed_at`, `week`/`month` windows; drops the alignment clause)
- Dimension-grouped reads, once out of preview — the largest gap between what ships and what the JTBD wanted
- `align_window/2` snap helpers — additive minor bump on adopter pull; any future version must make snapping visible in the return value
- Patching `to_string/1` to `float_to_binary(v, decimals: N)` — blocked on O-01
- Pointing `Drift.@spec_url` at `latest/openapi.spec3.sdk.json` with a non-`object`-keyed enrolment path, to give v2 thin events drift coverage
- Fixing the remaining `mix docs --warnings-as-errors` backlog (42 → this phase opportunistically clears the 2 metering-file warnings)
- The `groups_for_modules` backlog (32 ungrouped modules) → Phase 67
- A limits table with honest "not documented upstream" rows — not one of eleven surveyed platforms documents max payload bytes/keys/key length
</content>
