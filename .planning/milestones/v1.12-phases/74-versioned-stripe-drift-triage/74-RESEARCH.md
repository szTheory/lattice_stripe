# Phase 74: Versioned Stripe Drift Triage - Research

**Researched:** 2026-09-23
**Domain:** Stripe API versioning, versioned changelog/OpenAPI evidence, Elixir SDK resource triage
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Treat `mix lattice_stripe.check_drift` and its OpenAPI `master` comparison as candidate discovery, not proof that a field is stable or applicable to the SDK's default API version.
- **D-02:** A candidate considered for promotion must have a stable, versioned Stripe source (changelog or versioned API reference) and corroboration from a GA OpenAPI source. Record the exact source, API version, GA/preview status, and whether the field applies to the current pin or a later stable version.
- **D-03:** Classify findings as current stable, later stable, preview-only, or unconfirmed/schema noise. Preview-only and unconfirmed findings are not promoted. Later-stable fields may be selected only when their minimum API version is explicit and a versioned fixture can prove decoding; the default pin need not move to expose an opt-in newer contract.
- **D-04:** A test-mode/runtime probe is corroborating behavior evidence after source qualification; it cannot establish GA status or replace versioned source provenance.

### Candidate prioritization
- **D-05:** After the stable-source and type/decode safety gates, prioritize by the adopter job improved, operational consequence of missing the field, and whether related fields form a coherent resource-level addition.
- **D-06:** Apply extra weight to fields that can affect money movement, tax, fulfillment state, webhook interpretation/routing, Connect tenant context, or financial reconciliation. Keep LatticeStripe's boundary at Stripe-shaped primitives; application policy remains with the adopter.
- **D-07:** Do not rank by raw candidate count, recency, fixed numeric score, or a per-resource quota. Record the reason for each selected or deferred candidate so the ranking remains explainable without creating scoring ceremony.

### Triage record and API pin
- **D-08:** Use a concise, human-reviewable Markdown triage record as the phase's decision artifact; do not add a generator/validator or create one issue per field for this bounded review.
- **D-09:** For selected and deferred candidates, record resource and field path, stable source/API version and status, current-pin applicability, adopter job, semantic rationale, type/decode implications, and disposition. Every deferral records why it waits and what evidence would reopen it.
- **D-10:** Keep the default API version at `2026-03-25.dahlia` in this milestone. Consider a pin change only through a separate compatibility review covering the intervening Stripe changelog, request semantics, response decoding, webhook event/version behavior, supported adopter flows, and package SemVer impact. Date freshness or a single successful fixture is insufficient evidence.
- **D-11:** Any selected optional response field preserves the existing `extra` behavior for unknown response keys. Stripe enum-like values remain open where upstream can add values; do not turn a convenient current value list into a closed consumer contract without a Stripe stability guarantee.

### the agent's Discretion
- Exact Markdown layout, grouping of candidates into coherent field clusters, and concise wording of evidence summaries, provided every selected/deferred row carries D-09 evidence.
- The concrete shortlist, after inspecting current versioned Stripe sources and applying D-01–D-07; do not infer scope from the raw 104-field count.
- Whether a source ambiguity is recorded as `unconfirmed/schema noise` or deferred pending further source confirmation; do not promote it while unresolved.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within Phase 74 scope. Typed-field implementation belongs to Phase 75; API pin migration remains deferred pending compatibility evidence.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DRIFT-01 | Maintainers can trace candidate changes in already-supported Stripe resources to stable, versioned Stripe API sources and distinguish applicable changes from preview or OpenAPI-shape noise. | Stripe's dated changelog and versioned references provide minimum-version/status evidence; the GA-vs-preview OpenAPI source distinction is explicit. Existing drift inventory is a lead list only. The triage artifact needs exact GA-spec corroboration per candidate and explicit current-pin/later-stable/preview/unconfirmed labels. |
</phase_requirements>

## Summary

The existing drift command compares registered resource fields against `https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json`; it reports additions/removals but has no API-version qualification. Its dated assessment counted 104 candidate additions across 23 modules, but explicitly says these need manual version, relevance, and semantic triage. The present local run could not execute because Mix failed to open a TCP socket for its PubSub subscriber, so that dated inventory is the available lead list rather than a freshly reproduced count. [VERIFIED: `lib/lattice_stripe/drift.ex:11-18,50-61`; `.planning/threads/v1-12-next-milestone-assessment.md:97-110`]

Stripe publishes a dated changelog with separate `.dahlia` and `.preview` sections. Its official changelog page read during this research lists stable releases newer than the SDK's pin, including 2026-05-27, 2026-07-29, and 2026-08-26. Concrete later-stable research candidates among the already-modeled resources are `Invoice.amount_paid_off_stripe` (off-Stripe amount reconciliation), Refund customer/account/payment-method references (refund attribution and fewer follow-up reads), and `Dispute.payment_method_details.card.network` (payment-network context for dispute operations). These are **later-stable candidates**, not yet qualified for promotion: each must be checked against the exact GA OpenAPI snapshot, and the Phase 74 artifact must record that snapshot/version. [CITED: Stripe changelog entries below; current pin VERIFIED at `lib/lattice_stripe.ex:57,67`]

**Primary recommendation:** Produce a compact candidate/defer Markdown record. Treat the master drift list as discovery; qualify candidate paths using dated stable changelog/API references plus Stripe's GA `/latest` OpenAPI source, assign one of the four required statuses, and only recommend the later-stable candidates if that exact corroboration and type/decode review passes. Keep the package default pinned at `2026-03-25.dahlia`. The local web reader could identify Stripe's GA spec file and its 4.31 MB size but could not inspect its contents; direct network access from the shell was unavailable. Do not claim OpenAPI corroboration until the planner or phase executor checks the spec from an environment that can read it. [CITED: Stripe changelog; Stripe OpenAPI README and latest directory; local command output]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Classify Stripe response fields by API-version availability | API / Backend | — | These fields are present on Stripe API resources and API-versioned webhook snapshots, not client-side UI state. |
| Keep hand-written resource decoding tolerant | API / Backend | Database / Storage — | Resource `from_map/1` owns typed decoding; unknown response keys are retained in each resource's `extra` map. [VERIFIED: `lib/lattice_stripe/subscription.ex:447-500`] |
| Preserve a human-reviewable selection/defer record | Repository documentation | — | Phase 74 ends with a Markdown decision artifact; implementation and executable tooling are outside scope. [VERIFIED: `.planning/phases/74-versioned-stripe-drift-triage/74-CONTEXT.md`, D-08 and Deferred Ideas] |

## Standard Stack

### Core

| Library / Source | Version | Purpose | Why Standard |
|---|---|---|---|
| Stripe API changelog and versioned API reference | Exact date-release API versions (e.g. `2026-05-27.dahlia`) | Establish field/enum additions and the minimum API version | Stripe's own dated change entries link resource paths with explicit `api-version` query values. [CITED: Stripe changelog entries below] |
| Stripe OpenAPI repository `/latest/openapi.spec3.json` | Mutable latest GA snapshot; record commit/tag or downloaded snapshot identity at triage time | Corroborate that a field is in the public GA schema | The repository's `latest/README.md` describes these as latest GA OpenAPI specifications and distinguishes preview specs. [CITED: Stripe OpenAPI latest README] |
| Existing LatticeStripe hand-written resource module and synthetic fixtures | Current repository | Decide type/decode safety and preserve behavior | Resource `@known_fields`, struct, `from_map/1`, tests, and fixtures already define the extension seam. [VERIFIED: `lib/lattice_stripe/subscription.ex:68-78,447-500`] |

### Supporting

| Source / Tool | Purpose | When to Use |
|---|---|---|
| `mix lattice_stripe.check_drift` | Candidate discovery against current master spec | Use as an inventory lead, then independently qualify each candidate. |
| Stripe test-mode/runtime probe | Corroborate observed decode/response behavior | Only after stable version and GA schema evidence exist; never as proof of GA status. [CITED: Phase 74 D-04] |
| Versioned synthetic response fixtures | Pin expected response shape for a later-stable API contract | Required before selecting a later-stable field for Phase 75. [CITED: Phase 74 D-03] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Current `/master/openapi/spec3.json` drift result as proof | Dated Stripe changelog/versioned resource references plus GA `/latest/openapi.spec3.json` | Master catches candidates quickly but does not establish GA status or minimum version. The latter pair is the qualification evidence required by D-02. |
| Runtime test-mode observation alone | Versioned source + GA spec, with probe only as corroboration | Runtime behavior can show one account/configuration response; it cannot establish that a field is GA or available at the SDK's default API version. [CITED: Phase 74 D-04] |
| OpenAPI diff count or fixed score | Explainable per-candidate value/risk rationale | Avoids treating schema volume or arbitrary weights as adopter value. |

## Package Legitimacy Audit

Not applicable: Phase 74 adds no external package dependency.

## Architecture Patterns

### System Architecture Diagram

```text
Current drift/master output ── candidate names ──┐
                                                 ├─> version/status qualification ─> type/decode and adopter review
Dated Stripe changelog + versioned API refs ─────┤                                      │
                                                 │                                      v
Stripe GA OpenAPI snapshot ── schema corroboration┘                         Markdown select/defer record
                                                                                       │
                                                                                       v
                                                                    Phase 75 optional field implementation
```

### Recommended Project Structure

```text
.planning/phases/74-versioned-stripe-drift-triage/
└── 74-TRIAGE.md   # concise human-reviewed field decisions and evidence
```

The artifact filename is a recommended path, not an existing path contract. The phase context locks the content and format, not the filename.

### Pattern 1: Evidence-first candidate row

**What:** Keep each selected or deferred row self-contained: resource and nested field path; dated source and API version; stable/preview status; current pin or later stable applicability; GA OpenAPI corroboration (including snapshot identity); adopter job; semantic/type/decode implications; disposition; and, for deferrals, the evidence that would reopen it.

**When to use:** Every candidate included in Phase 74's bounded record.

**Example:**

```markdown
| Candidate | Status / minimum version | Pin applicability | Adopter job and consequence | Type/decode note | Disposition / reopen evidence |
|---|---|---|---|---|---|
| Invoice.amount_paid_off_stripe | Later stable / 2026-05-27.dahlia | Later than 2026-03-25.dahlia | Reconcile off-Stripe partial/full invoice payments | Integer minor-unit amount; optional field; retain `extra` behavior | Select only after exact GA OpenAPI corroboration and a versioned fixture |
```

**Evidence:** Stripe says `amount_paid_off_stripe` is an integer amount in invoice currency, dynamically computed from Payment Record data, and unavailable in event payloads; changelog links the API object version as `2026-05-27.dahlia`. This makes it a strong operational candidate but also a reminder to distinguish ordinary API-resource responses from event payloads. [CITED: https://docs.stripe.com/changelog/dahlia/2026-05-27/invoice-object-amount-paid-off-stripe-property]

### Pattern 2: Keep open upstream enums open

**What:** Use a string/open representation or a known-value convenience that preserves unrecognized upstream values; do not make the list of currently documented values exhaustive in a consumer contract.

**When to use:** New payment-method values, statuses, networks, and other Stripe enum-like values.

**Example:** Preserve raw response values for payment method type additions, including the stable `billie` addition in 2026-08-26.dahlia, rather than treating the contemporary list as closed. Existing `Subscription` status decoding returns unknown values unchanged: `defp atomize_status(other), do: other`. [VERIFIED: `lib/lattice_stripe/subscription.ex:504-514`; `billie` is CITED: Stripe changelog 2026-08-26 Billie entry]

### Anti-Patterns to Avoid

- **Promoting directly from master drift:** It lacks version/status semantics; qualify with dated stable sources and GA schema.
- **Conflating `/latest` and `/preview`:** Stripe documents separate specification directories; preview presence is not GA corroboration.
- **Treating changelog absence as evidence a field is absent:** If a candidate is not found in one evidence source, leave it unconfirmed until positively checked against versioned docs and GA schema.
- **Treating a runtime probe as release-state proof:** A probe does not prove GA availability or version floor.
- **Closing enums from one current snapshot:** Stripe adds new values; keep unknown upstream values representable.
- **Expanding scope to resource families, typed implementations, a generator, or API pin migration:** These belong elsewhere or are explicitly out of scope.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Candidate inventory | New generator/validator for this bounded review | Existing drift task as a lead list | The phase decision explicitly calls for concise human review and says not to add a generator/validator. |
| Stripe version semantics | A local inferred version algorithm | Stripe's dated changelog and versioned API reference | Stripe provides each change's explicit date version and stable/preview section. |
| API schema status | A custom interpretation of master | Stripe's public GA `/latest` spec, separately from `/preview` | The upstream repository defines those source boundaries. |
| Tolerant decoding | A second raw-field wrapper | Existing `extra` behavior in resource `from_map/1` | Unknown response keys already survive decoding. [VERIFIED: `lib/lattice_stripe/subscription.ex:449-450,500`] |

**Key insight:** The risk is provenance confusion, not the cost of computing a diff. Keep discovery, stable-version qualification, GA schema corroboration, runtime observation, and value selection as distinct evidence steps.

## Common Pitfalls

### Pitfall 1: Treating current API-reference defaults as the SDK pin

**What goes wrong:** A generated “current” docs view may show fields unavailable to requests using the package's pinned API version.
**Why it happens:** Stripe adds monthly versioned releases after the package pin.
**How to avoid:** Cite the resource view with explicit `api-version`; compare it with `2026-03-25.dahlia`; record current-pin vs later-stable applicability. [VERIFIED: `lib/lattice_stripe.ex:57,67`; CITED: Stripe changelog entries]
**Warning signs:** An unqualified API docs URL, a `master` diff, or a runtime response with no sent `Stripe-Version` noted.

### Pitfall 2: Mistaking preview changes for stable response fields

**What goes wrong:** A preview-only field or breaking behavior is recorded as a candidate for normal typed support.
**Why it happens:** Changelog pages interleave stable and preview sections for the same date/release family.
**How to avoid:** Record the section and exact version suffix. Example: 2026-08-26 stable and 2026-08-26.preview are separate changelog sections; the PaymentIntent/SetupIntent `payment_method_types` removal is listed as a preview breaking change, while the stable release also lists `billie` enum support. [CITED: https://docs.stripe.com/changelog]
**Warning signs:** Candidate citation lacks `.dahlia` / `.preview` status.

### Pitfall 3: Letting nested shape and operation scope disappear

**What goes wrong:** A nested field is named without its full resource path or a resource field is assumed to apply to event snapshots.
**Why it happens:** OpenAPI candidate output may flatten context; Stripe may explicitly scope a field to retrieval API responses.
**How to avoid:** Record complete field path and endpoint/resource scope. `amount_paid_off_stripe` is exposed on Invoice API requests and Stripe explicitly says it is not in event payloads. [CITED: amount-paid changelog]
**Warning signs:** Bare names such as `network` or `customer`, with no parent object path.

### Pitfall 4: Turning discovery breadth into planned breadth

**What goes wrong:** The raw 104-candidate inventory drives a resource quota or a sweeping implementation.
**Why it happens:** Counts look concrete but do not encode adopter value or operational consequence.
**How to avoid:** Use field-level adopter jobs and deferral reasons; prefer common/costly operational use cases. [VERIFIED: `.planning/threads/v1-12-next-milestone-assessment.md:97-126`; CITED: `.planning/JTBD-MAP.md` audience and domain lenses]
**Warning signs:** “N fields per resource,” recency ordering, or an unqualified percentage/count goal.

## Code Examples

Existing decoder pattern, quoted from `Subscription.from_map/1`:

```elixir
{known, extra} = Map.split(map, @known_fields)
```

The split is present at `lib/lattice_stripe/subscription.ex:449-450`, and the resource assigns `extra: extra` at line 500; unrecognized keys remain available after adding selected optional known fields. [VERIFIED: `lib/lattice_stripe/subscription.ex:449-450,500`]

**Do not copy:** `@stripe_api_version "2026-03-25.dahlia"` (current pin), confirmed at `lib/lattice_stripe.ex:57`. Phase 74 does not authorize changing it. [VERIFIED: `lib/lattice_stripe.ex:57`]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Compare against the current OpenAPI master and infer all additions are actionable | Treat the diff as discovery; qualify against dated stable changelog/API reference and GA OpenAPI | Phase 74 context, 2026-09-23 | Adds version applicability/status and separates preview/schema noise from candidates. [VERIFIED: `lib/lattice_stripe/drift.ex:11-18`; `74-CONTEXT.md` D-01–D-04] |
| Infer GA from the presence of a field in the broad current spec | Use the dedicated `/latest` GA spec and keep `/preview` distinct | Stripe repository's documented directory split | The public spec path and snapshot identity must be recorded. [CITED: Stripe OpenAPI latest README] |

**Deprecated/outdated:** Treating bare `master` comparisons as a versioned Stripe contract. The existing task remains useful for discovery, but not for promotion evidence.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The three candidate paths named here are represented in the existing raw 104-field drift lead list. The assessment names affected resource groups but not those exact field names, and the drift command could not run in this environment. | Summary and candidate examples | A recommendation could spend effort on candidates not in this phase's lead inventory; check the dated artifact/current successful drift output before including them in the final decision record. |
| A2 | The current mutable `/latest` OpenAPI snapshot contains each candidate described in the official dated changelog. The web reader could not inspect the 4.31 MB JSON file, and local shell networking was unavailable. | Summary / evidence gate | D-02 is unmet until a successful exact-spec lookup confirms each candidate; otherwise classify it unconfirmed/defer it. |

## Open Questions

1. **Which of the three later-stable candidates are present in the exact GA OpenAPI snapshot and in the 104-field lead list?**
   - What we know: Stripe's official dated entries identify the stable version and exact field path; all belong to existing domain families described as supported by the repository.
   - What's unclear: Exact GA `/latest` JSON field match and exact intersection with the assessment's drift list were not inspectable here.
   - Recommendation: At planning/execution, capture the exact versioned sources and GA snapshot commit/version, cross-check the lead list, and keep any unverified row out of the selected set.
2. **Does a future-stable candidate warrant decoding only on its typed resource at Phase 75?**
   - What we know: New response fields remain backward-tolerant through `extra`; `amount_paid_off_stripe` is not included in API v1 event payloads per Stripe.
   - What's unclear: Whether downstream adopter evidence favors these typed additions over other candidates in the inventory.
   - Recommendation: Apply D-05–D-07; state the human reason per row rather than setting a quota.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Stripe public web documentation | Versioned changelog and source research | ✓ | Current page read 2026-09-23 | — |
| Stripe OpenAPI exact GA spec access | Candidate qualification | Partial | `latest/openapi.spec3.json` identified; 4.31 MB page unavailable to reader | Use an environment that can download/inspect the official spec; until then keep candidates unconfirmed for promotion |
| Local `mix lattice_stripe.check_drift` | Refresh candidate inventory | ✗ | Mix 1.19.5; failed before task due `:eperm` opening PubSub TCP socket | Use the recorded 2026-09-23 inventory as discovery only; re-run where local socket permissions allow |

**Missing dependencies with no fallback:** None that block the research-to-plan handoff; exact candidate corroboration remains an explicit planning/execution gate.

**Missing dependencies with fallback:** Drift inventory has the dated assessment lead list; exact GA OpenAPI content requires another accessible environment/source.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (repository-wide; research phase does not modify code) |
| Config file | `mix.exs` / `test/test_helper.exs` |
| Quick run command | `mix test` (no phase-specific code behavior is introduced in Phase 74) |
| Full suite command | `mix ci` (repository's project CI task; not run during research) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| DRIFT-01 | Candidate records carry versioned source, explicit GA/preview/current-pin/later-stable classification, and explain schema noise/defer decisions | Human review of Markdown evidence; optional narrow docs-truth check only if consistent with existing workflow | No truthful automated command can establish Stripe's GA status or semantic adopter priority | Not applicable; phase is a decision artifact |

### Sampling Rate

- **Per task commit:** Review every candidate row for complete evidence and disposition.
- **Per wave merge:** N/A for code; review the whole triage record against D-01–D-11.
- **Phase gate:** Human review of sources and reasons; no automated test can replace the source qualification decision.

### Wave 0 Gaps

None — no implementation or test framework work is required by this phase. Do not add a generator or validator merely to automate this bounded review.

## Security Domain

Phase 74 changes no runtime authentication, sessions, access control, persistence, or cryptographic behavior. The relevant control is evidence integrity: cite only public Stripe sources, distinguish preview from GA, and do not use credentials for optional runtime probes. Do not introduce a live credential requirement for phase proof. [CITED: Phase 74 D-04 and scope]

The category numbering below follows ASVS 4.0.3 so V2–V6 retain the requested authentication/session/access-control/validation/cryptography meanings. ASVS 5.0 renumbered its chapters; do not mix identifiers across versions. [CITED: OWASP ASVS 4.0 sources]

| ASVS Category (4.0.3) | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | No authentication behavior is changed. |
| V3 Session Management | No | No session behavior is changed. |
| V4 Access Control | No | No authorization behavior is changed. |
| V5 Input Validation | No | No application input path is added or changed. |
| V6 Cryptography | No | No cryptographic implementation is added or changed. |

## Sources

### Primary (MEDIUM confidence from this lookup path)

- [Stripe API changelog](https://docs.stripe.com/changelog) — dated stable vs preview sections; 2026-08-26 stable and preview changes.
- [Stripe OpenAPI latest README](https://github.com/stripe/openapi/tree/master/latest) — says `latest` is the latest GA public API spec; contrasts `/preview`.
- [Stripe API versioning](https://docs.stripe.com/api/versioning) — major/monthly release versioning and testing before upgrade guidance.
- [Invoice amount paid off Stripe changelog](https://docs.stripe.com/changelog/dahlia/2026-05-27/invoice-object-amount-paid-off-stripe-property) — field meaning, response scope, and minimum version.
- [Refund details changelog](https://docs.stripe.com/changelog/dahlia/2026-07-29/adds-customer-and-payment-method-details-to-the-refunds-api) — exact field paths and minimum version.
- [Dispute card network changelog](https://docs.stripe.com/changelog/dahlia/2026-07-29/dispute-payment-method-details-card-network) — exact nested path and minimum version.
- [Invoice Item frozen fields changelog](https://docs.stripe.com/changelog/dahlia/2026-08-26/adds-frozen-fields-property-to-invoice-items) — exact field path, type/meaning, and minimum version.
- [Billie support changelog](https://docs.stripe.com/changelog/dahlia/2026-08-26/billie-support-for-invoices-and-subscriptions) — enum addition and limited `send_invoice` applicability.
- [OWASP ASVS 4.0.3 authentication chapter](https://github.com/OWASP/ASVS/blob/master/4.0/en/0x11-V2-Authentication.md) and [4.0.3 preface](https://github.com/OWASP/ASVS/blob/master/4.0/en/0x02-Preface.md) — version-scoped category mapping used for the ASVS applicability table.

### Repository sources (verified by reading this session)

- `.planning/phases/74-versioned-stripe-drift-triage/74-CONTEXT.md` — D-01 through D-11, scope, deferrals.
- `.planning/REQUIREMENTS.md` — DRIFT-01 and scope exclusions.
- `.planning/threads/v1-12-next-milestone-assessment.md` — dated drift counts and candidate categories.
- `lib/lattice_stripe/drift.ex` and `lib/mix/tasks/lattice_stripe.check_drift.ex` — master-source comparison and report semantics.
- `lib/lattice_stripe/subscription.ex` — established `@known_fields`, `from_map/1`, `extra`, and open fallback pattern.
- `lib/lattice_stripe.ex` — current API pin.
- `.planning/JTBD-MAP.md` — adopter segments, common/costly jobs, and SDK/application boundary.
- `.planning/config.json` — `workflow.nyquist_validation` is `true`; therefore validation architecture included.

## Metadata

**Confidence breakdown:**
- Standard sources: MEDIUM — official Stripe sources establish changelog/version and spec directory distinctions, but exact large GA JSON content was inaccessible in this session.
- Architecture: HIGH — existing source code directly shows the drift and tolerant-decoding patterns.
- Candidate priority: MEDIUM — Stripe docs establish concrete later-stable use cases; exact raw-list intersection and GA spec confirmation remain for the triage step.

**Research date:** 2026-09-23
**Valid until:** 2026-10-23 (recheck Stripe changelog and mutable GA OpenAPI snapshot before triage execution)
