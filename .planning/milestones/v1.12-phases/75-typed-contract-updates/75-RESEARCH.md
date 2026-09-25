# Phase 75: Typed Contract Updates - Research

**Researched:** 2026-09-24
**Domain:** Versioned Stripe response contracts, hand-written Elixir resource decoding, public API compatibility
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Field eligibility and API-version contract
- **D-01:** Reopen Phase 74 candidates individually. A field is eligible only after exact inventory membership and its exact path in an immutable GA OpenAPI snapshot are established, with the stable source, minimum API version, and fixture provenance recorded. Select only eligible fields that solve a clear, costly adopter job; if none qualify, leave the implementation unstarted rather than promoting on changelog prose, a candidate count, or mutable schema evidence.
- **D-02:** Keep the default API version at `2026-03-25.dahlia`. A later-version field must name its minimum Stripe API version and the response/event surfaces where it is available, as supported by evidence. A default API pin change remains a separate compatibility decision requiring the Phase 74 D-10 review.

### Typed response shape
- **D-03:** Add qualified fields additively to the existing resource structs and `@type t` definitions, following each resource's established `@known_fields` and `from_map/1` decoder pattern. Do not introduce strict response schemas, per-API-version resource modules, Ecto schemas, or a new modeling dependency for this bounded response-decoding work.
- **D-04:** Preserve the unknown-key `extra` contract. Represent absent/nullable fields consistently with the verified schema and existing decoder conventions, normally as `nil`. For fields confirmed expandable, retain the established ID-string, expanded-resource, or `nil` union. Keep enum-like Stripe values open to new strings; do not introduce closed enums without an upstream stability guarantee.

### Proof and adopter documentation
- **D-05:** For each selected field, add focused decoder coverage for evidence-supported cases: ordinary value, omission/null behavior, ID/expanded form when applicable, unknown enum-like values when applicable, and retention of unrelated unknown response keys in `extra`. Assert only behavior the SDK actually promises; these are decoder checks, not claims about live Stripe behavior.
- **D-06:** Record fixture provenance accurately (captured or schema-derived), including API version and immutable GA snapshot identity/path. Update the field's public type/module documentation and changelog with its adopter meaning, minimum API version, and proven endpoint/event availability. Update a canonical guide only when it materially helps an adopter complete the relevant job.
- **D-07:** Keep proof proportional to the change: focused tests and compatibility review are the default. A broad API-version matrix or Phoenix/Plug/provider integration proof is warranted only if the selected change actually crosses those boundaries. This is a headless library change; its UX surface is the API and HexDocs, not a visual UI.

### the agent's Discretion
- After the evidence gate passes, choose the eligible field cluster by adopter consequence and coherence, with priority for reconciliation, money movement, and other costly operational work as established in Phase 74.
- Follow the closest existing resource decoder, fixture, and test pattern; use only field-specific shape cases supported by the immutable schema evidence.
- If evidence reveals request semantics, webhook behavior, or a compatibility impact beyond additive response decoding, surface that boundary for replanning instead of implying this phase proves it.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 75 scope. Default API pin migration and broad multi-version response models remain separate compatibility work, not shortcuts for selecting fields.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DRIFT-02 | Adopters can access selected high-value, stable Stripe fields through typed resource fields while unmodeled response fields remain available through the existing `extra` behavior. | Only after D-01 yields an eligible field: extend the existing struct/typespec/decoder seam and preserve unknown keys in `extra`. No candidate currently passes the gate, so implementation is not yet plan-ready. |
| DRIFT-03 | Maintainers can verify promoted field decoding and compatibility through focused tests without removing or changing existing public behavior. | Existing resource tests exercise `from_map/1`, unknown-field retention, and expanded references; the API surface lock protects public struct changes. A selected field needs focused cases from its verified schema. No selected field currently exists. |
| DRIFT-04 | Adopters can find the supported API-version and promoted-field contract documented; the default API version changes only when compatibility evidence justifies it. | Keep the pinned version and document a field's evidence-backed minimum version and response/event surface. Stripe recommends testing version upgrades; a default-pin migration is outside this phase absent the separate D-10 review. |
</phase_requirements>

## Summary

Phase 75 is **not implementation-ready on the current evidence**. Phase 74 selected no fields, its inventory was partial, and this session's retry of `mix lattice_stripe.check_drift` exits before task execution: Mix 1.19.5 cannot open the PubSub TCP socket (`:eperm`). Searches of repository/planning sources found the count-only 104-addition note and the five deferred leads, but no dated exact-path inventory. Therefore no candidate has demonstrated the first mandatory eligibility gate (exact inventory membership); the exact immutable GA OpenAPI snapshot and paths are also still absent. Do not select or type any lead based only on its changelog, raw count, or the mutable `latest`/`master` spec URL. [VERIFIED: `.planning/phases/74-versioned-stripe-drift-triage/74-TRIAGE.md:8-11,18-25`; `.planning/phases/74-versioned-stripe-drift-triage/74-01-SUMMARY.md:44-49`; command output recorded during this research]

**Primary recommendation:** Return an inconclusive/blocked planning outcome for field implementation. Do not create implementation tasks or claim DRIFT-02/03/04 complete. Resume only when a successful exact-path inventory (or dated exact-path artifact) is available and a candidate can be traced to an immutable GA snapshot identity plus exact schema path, minimum API version, availability surface, and fixture provenance. If no lead passes after that evidence recovery, preserve the context's explicit no-field stop condition.

This is a headless Hex library change. The consumer-facing experience is a stable Elixir struct/type, tolerant decoding, module docs, changelog, and HexDocs. Existing hand-written resource decoders already split known keys from `extra`; the project stability guide calls an optional struct field additive but treats type/value representation as a compatibility contract. Stripe's OpenAPI repository distinguishes GA `/latest/` from `/preview/`, and Stripe advises testing an API-version upgrade before committing. Those ecosystem facts support the locked design, but they cannot make an unevidenced field eligible. [CITED: https://github.com/stripe/openapi/blob/master/README.md; https://docs.stripe.com/api/versioning; VERIFIED: `guides/api_stability.md:14-24,37-40,69-78`]

## Evidence Gate Result

| Gate | Result in this research | Planning consequence |
|---|---|---|
| Exact inventory membership | Not demonstrated. Phase 74 recorded partial/non-exhaustive coverage. Current retry failed before the task ran with `:eperm`; repository searches surfaced planning leads but no dated full-path listing. | No candidate can proceed to selection. Do not treat a resource-family mention or reported count as membership. |
| Immutable GA schema snapshot and exact path | Not demonstrated. Stripe documents `/latest/` as latest GA, but it is a mutable pointer; Phase 74 says its JSON contents and immutable identity/path were unavailable. | Even if inventory is recovered, qualify each exact property path against a commit/ref-identified GA file and record a content hash. A mutable URL or preview spec is insufficient. |
| Stable source, minimum version, response/event surfaces | Phase 74 lists later-stable changelog leads, but D-01 still requires all gates and accurate response/event scope. | Preserve as leads only. Do not add fields, claim event support, or change the default pin. |
| Existing decoder seam | Verified in source: Invoice and Refund have `@known_fields`, structs/typespecs, `from_map/1`, and `extra`; tests cover unknown-key retention. | Reuse this seam if/when evidence qualifies a field. |

The current API pin is verified in source as `@stripe_api_version "2026-03-25.dahlia"` (`lib/lattice_stripe.ex:57`); keep it unchanged. The exact five lead strings, quoted verbatim from the Phase 74 ledger, are: `Invoice.amount_paid_off_stripe`; `Refund.customer`, `Refund.customer_account`, and `Refund.payment_method`; `Dispute.payment_method_details.card.network`; `InvoiceItem.frozen_fields`; and Invoice/Subscription `payment_settings.payment_method_types` (Billie). [VERIFIED: `.planning/phases/75-typed-contract-updates/75-CONTEXT.md:99`; `.planning/phases/74-versioned-stripe-drift-triage/74-TRIAGE.md:20-24`; `lib/lattice_stripe.ex:57`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Qualify Stripe field/version/schema evidence | API / Backend | Repository documentation | Stripe API release sources define availability; planning records source identity and paths before code changes. |
| Decode qualified resource response fields | API / Backend | — | Existing resource `from_map/1` functions own typed response shaping and unknown-field preservation. |
| Expose the contract to adopters | Library API / HexDocs | Changelog | The package has no browser UI. Struct shape, typespecs, moduledocs, guides, and release notes are the relevant UX. |
| Prove decoding and public compatibility | Test / CI | Maintainer review | Focused ExUnit cases exercise concrete payload shapes; the API surface lock detects public struct/type changes. |

## Standard Stack

### Core

| Library / Source | Version | Purpose | Why Standard |
|---|---|---|---|
| Existing Elixir resource modules | Repository version | Stripe response struct, typespec, and decoder | This hand-written SDK already uses this boundary; D-03 explicitly locks it. |
| `Map.split/2` with each resource's `@known_fields` | Elixir standard library | Separate recognized keys from `extra` | It is the established tolerant-decoding pattern in the current resource code. |
| ExUnit | Repository's existing test setup | Focused decoder and compatibility checks | Existing resource tests already assert decoder behavior and unknown-key retention. |
| Stripe public GA OpenAPI JSON and dated changelog/API reference | Immutable commit/ref plus exact path required | Establish schema and API-version provenance | Stripe identifies `/latest/` as GA and `/preview/` as preview; the planner must pin the actual snapshot identity rather than cite the mutable alias alone. [CITED: https://github.com/stripe/openapi/blob/master/README.md] |

No dependency installation is indicated. Do not add Ecto or another modeling dependency: Ecto's own guidance describes schemas/changesets as data mapping and casting/validation tools, while the SDK's locked contract is direct tolerant response decoding into Stripe-shaped resource structs. [CITED: https://hexdocs.pm/ecto/data-mapping-and-validation.html]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Existing resource struct and decoder | Raw `extra` only | Raw maps preserve access but do not give adopters first-class discoverability or the selected field's documented type. Keep `extra` as a forward-compatible escape hatch. |
| Existing resource struct and decoder | Ecto schemas/changesets | Adds validation/casting and a persistence-oriented dependency/concept to an SDK response boundary; explicitly out of scope in D-03. |
| One pinned default resource type | Per-API-version resource modules | Makes consumers track version-specific types and expands public maintenance surface; explicitly out of scope in D-03. |
| Open upstream string values | Closed enum | Closed sets can make future Stripe values unusable; D-04 forbids this without an upstream stability guarantee. |

## Architecture Patterns

### System Architecture Diagram

```text
dated Stripe source ───────┐
exact drift inventory ─────┼─> evidence gate ──(pass only)──> GA schema path/version fixture
immutable GA snapshot ─────┘                                      │
                                                                  v
                                                existing resource from_map/1 decoder
                                                                  │
                                           ┌──────────────────────┴─────────────────────┐
                                           v                                            v
                               typed optional struct field                   unrelated keys -> extra
                                           │
                                           v
                            typespec + docs + changelog + focused proof
```

### Recommended Project Structure

No new production module or dependency is recommended. For each future eligible property, touch only its existing resource module, nearest resource test/fixture, and relevant module docs/changelog. Record the provenance in the fixture or adjacent test documentation as required by D-06. Do not start those edits until both evidence gates pass.

### Pattern 1: Tolerant additive resource decoding

**What:** Extend the existing known-field/struct/typespec/decoder mapping together. Keep unknown response keys in `extra`; do not change behavior for current keys. Check omission and explicit `null` against the schema and current conventions, and represent only evidence-supported shapes.

**When to use:** Only after D-01 eligibility is established.

**Example (shape only; no candidate field is selected):**

```elixir
@known_fields ~w[id object amount_paid]

defstruct [:id, :amount_paid, extra: %{}]

@type t :: %__MODULE__{id: String.t() | nil, amount_paid: integer() | nil}

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{id: known["id"], amount_paid: known["amount_paid"], extra: extra}
end
```

This is a structural illustration using an existing Invoice field, not a claim that it is a newly eligible Phase 75 candidate. The source says verbatim: `@known_fields ~w[` / `id object account_country account_name account_tax_ids amount_due amount_paid` (`lib/lattice_stripe/invoice.ex:75-77`); `:id` (`lib/lattice_stripe/invoice.ex:96`) and `id: String.t() | nil` (`lib/lattice_stripe/invoice.ex:188-190`); `amount_paid: integer() | nil` (`lib/lattice_stripe/invoice.ex:194-196`); and `amount_paid: known["amount_paid"]` (`lib/lattice_stripe/invoice.ex:933-936`).

### Pattern 2: Public docs and tests state exactly what is promised

**What:** Explain adopter meaning, minimum API version, and only the response/event surfaces proven by sources. Use schema-derived synthetic fixtures when captured payload provenance is unavailable, and label them as such. Test decoding, not Stripe's live behavior. Typespecs are documentation/tooling, not runtime validation. [CITED: https://hexdocs.pm/elixir/typespecs.html]

**When to use:** Once a specific field passes evidence gates.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Stripe wire-shape proof | Inferred schema, handwritten assertion, or changelog-only field | Exact property in immutable public GA OpenAPI snapshot plus field/version provenance | Mutable or preview schema and changelog prose alone do not meet the locked evidence gate. |
| Forward-compatible decoding | Custom unknown-field registry or closed response validator | Existing per-resource `@known_fields`, `from_map/1`, and `extra` seam | Preserves current behavior and makes fields discoverable only when deliberately promoted. |
| Version compatibility confidence | Broad matrix by default or changing the default pin to access a field | Focused schema-shaped decoder cases and compatibility review; separate pin decision under D-10 | Proportional proof avoids implying that a response fixture establishes request or webhook compatibility. |

**Key insight:** The critical work is evidence qualification, not code volume. Implementing a plausible but unproven field creates public API maintenance obligations without proving the SDK should promise that shape.

## Common Pitfalls

### Pitfall 1: Promoting a lead because it looks useful
**What goes wrong:** A changelog candidate or resource-level drift count gets added to a public struct without proof it belongs to the inventory or exact GA schema.
**Why it happens:** Candidate discovery is mistaken for qualification.
**How to avoid:** Require exact inventory membership and immutable snapshot identity/path before selecting any field (D-01).
**Warning signs:** Candidate count, mutable `master`/`latest` URL, or changelog alone appears as the only evidence.

### Pitfall 2: Treating the package pin as the whole webhook contract
**What goes wrong:** Docs imply that a field is available in event payloads because it exists on a later-version API resource.
**Why it happens:** Retrieval responses and versioned webhook snapshots are conflated; thin events have different payload semantics.
**How to avoid:** State only endpoint/event surfaces proved by candidate evidence. Stripe's versioning guide says webhook events use the endpoint/account API version unless configured; resource support alone proves no event surface. [CITED: https://docs.stripe.com/api/versioning]

### Pitfall 3: Letting a typespec imply runtime validation
**What goes wrong:** A type declaration is treated as proof that decoder output is cast or validated.
**Why it happens:** Typespecs describe expectations but are not enforced by the Elixir runtime.
**How to avoid:** Keep runtime decoding behavior explicit and cover it with ExUnit; document the typespec as a contract/tooling aid. [CITED: https://hexdocs.pm/elixir/typespecs.html]

### Pitfall 4: Silently broadening the public compatibility surface
**What goes wrong:** An optional field is added without refreshing the public API lock or without reviewing its value representation.
**Why it happens:** Additive field changes are assumed to be invisible to public API tooling.
**How to avoid:** Review the API surface lock and `guides/api_stability.md`; optional fields are additive, while later type/value representation changes are breaking under the existing contract. [VERIFIED: `guides/api_stability.md:14-24,69-78`]

### Pitfall 5: Retrying a blocked drift task as if it produced an empty inventory
**What goes wrong:** A startup failure is interpreted as zero candidates or evidence that a lead is absent.
**Why it happens:** Command failure and successful empty output are conflated.
**How to avoid:** Record the exact `:eperm` socket failure and leave inventory membership unknown. Recover in an environment where Mix can start; do not infer a result.

## Code Examples

The local Invoice decoder establishes the pattern: `Map.split(map, @known_fields)` produces `known` and `extra`, then the struct is built from recognized keys (`lib/lattice_stripe/invoice.ex:925-930`). Existing tests assert unknown Invoice keys survive under `extra` (`test/lattice_stripe/invoice_test.exs:189-198`), and Refund tests assert a two-key unknown map is retained (`test/lattice_stripe/refund_test.exs:372-385`). These are precedent examples, not proof for any Phase 75 candidate.

Typespecs should describe the public field type and any confirmed union; they do not cast API values at runtime. For Stripe SDK precedent, Stripe documents that `stripe-node` v12+ aligns request API version to SDK release so TypeScript types match; explicit overrides can make those types inaccurate, and webhook versions are set separately. Apply the general lesson (keep version claims explicit), not the Node-specific mechanism. [CITED: https://docs.stripe.com/api/versioning; https://github.com/stripe/stripe-node#typescript-and-the-stripe-versioning-policy]

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| Treat latest OpenAPI/master diffs as API contract truth | Stripe OpenAPI distinguishes public GA `/latest/` from preview; lock an immutable source identity and exact path for evidence | Current mutable aliases are discovery sources; snapshot identity is needed for repeatable field qualification. [CITED: https://github.com/stripe/openapi/blob/master/README.md] |
| Treat generated SDK types as independent of API version | Stripe SDK guidance aligns some SDK versions to specific Stripe API versions and warns overrides can make types inaccurate | Document the minimum field version and keep default pin changes separate from additive field decoding. [CITED: https://docs.stripe.com/api/versioning] |

**Deprecated/outdated:** None introduced by this phase. Do not add a schema-generation or versioned-resource framework for this bounded change.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | A usable exact-path inventory may become available by rerunning drift tooling outside the current sandbox or locating a dated artifact. | Evidence Gate Result | If no inventory can be recovered, this phase remains blocked and needs an explicit re-scope or later evidence refresh. |
| A2 | After a qualified field is selected, the existing resource test file will remain the most coherent place for its focused decoder cases. | Validation Architecture | A repository-specific fixture convention may be more appropriate; planner should inspect the nearest existing tests before assigning files. |

## Open Questions

1. **Can exact inventory membership be recovered?** Current `mix lattice_stripe.check_drift` exits before execution with `:eperm` in `Mix.Sync.PubSub.subscribe/1`; the recorded 104 additions are count-only. Recommendation: stop field implementation planning until a successful output or dated exact-path artifact is available.
2. **Which immutable GA snapshot paths correspond to any lead?** Current Phase 74 record has no commit/ref, hash, or JSON paths. Recommendation: after inventory recovery, verify only intersecting candidates against a pinned public GA snapshot and record exact paths and content identity.
3. **Which response/event surfaces are supported?** This is candidate-specific and cannot be inferred from object presence. Recommendation: state only the surfaces backed by versioned Stripe evidence.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (existing repository suite) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/<resource>_test.exs` after a field is eligible |
| Full suite command | `mix ci` (includes tests, API surface, docs, formatting, compile, Credo) |

No tests were run for this research task. The Mix drift command itself was attempted and failed before the task ran with `:eperm`; therefore it produced no inventory to test against.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| DRIFT-02 | Eligible response field decodes as documented while unrelated response keys remain in `extra`. | Focused unit | `mix test test/lattice_stripe/<resource>_test.exs` | Resource tests exist; selected-field case does not, and no resource can be named until selection. |
| DRIFT-03 | Omission/null, ordinary values, confirmed expandable forms/open values, plus public API compatibility remain correct. | Focused unit + API surface | `mix test test/lattice_stripe/<resource>_test.exs` and `mix test test/lattice_stripe/api_surface_lock_test.exs` | General tests/lock exist; candidate-specific cases do not. |
| DRIFT-04 | API pin and public field-version documentation are accurate. | Docs/version checks + source review | `mix lattice_stripe.version_prose --check` and `mix ci` | Version check exists; exact docs content depends on an eligible field. |

### Wave 0 Gaps

- **Blocking evidence gap:** recover exact inventory membership; then pin and inspect the exact GA snapshot path for at least one candidate. This is not a test-framework setup gap.
- **Conditional implementation gaps:** selected-field fixture/test cases and docs cannot be designed before selection. Do not create placeholder tests for hypothetical fields.

## Security Domain

This phase adds no auth, session, access-control, cryptographic, or persistence behavior. Applicable ASVS concern is V5 Input Validation only at the response-decoding boundary: treat Stripe payloads as external input, preserve unknown keys without atomizing arbitrary values, and only claim types the decoder actually guarantees. No new validation layer is justified by the evidence or scope. Existing decoder values are passed through or explicitly decoded by the known resource mapper. [VERIFIED: `lib/lattice_stripe/invoice.ex:925-930`; `lib/lattice_stripe/dispute/payment_method_details.ex:27-33`]

## Sources

### Primary (HIGH confidence for repository facts)
- `.planning/phases/74-versioned-stripe-drift-triage/74-TRIAGE.md` — partial inventory, failed refresh, deferred candidates, missing immutable GA paths.
- `.planning/phases/74-versioned-stripe-drift-triage/74-01-SUMMARY.md` — recorded `:eperm` failure and explicit Phase 75 readiness caveat.
- `lib/lattice_stripe/drift.ex`, `lib/mix/tasks/lattice_stripe.check_drift.ex` — drift task source and behavior.
- `lib/lattice_stripe/invoice.ex`, `lib/lattice_stripe/refund.ex`, resource tests, `guides/api_stability.md` — decoder, `extra`, and public compatibility patterns.

### Secondary (MEDIUM confidence; official documentation pages)
- [Stripe OpenAPI repository README](https://github.com/stripe/openapi/blob/master/README.md) — GA `/latest/` versus `/preview/`, public versus SDK specs, expandable-field metadata.
- [Stripe API versioning](https://docs.stripe.com/api/versioning) — version upgrade testing and webhook version behavior.
- [Elixir typespecs](https://hexdocs.pm/elixir/typespecs.html) — typespec documentation/tooling semantics.
- [Ecto data mapping and validation](https://hexdocs.pm/ecto/data-mapping-and-validation.html) — schema/changeset scope and separation of mappings.
- [stripe-node versioning and TypeScript policy](https://github.com/stripe/stripe-node#typescript-and-the-stripe-versioning-policy) — cross-language version/type alignment example.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — local implementation and dependency boundary are directly inspected; official documentation confirms the language/library semantics.
- Architecture: HIGH — D-03/D-04 lock the existing seam, confirmed in source.
- Candidate evidence: LOW — exact inventory and immutable GA paths remain unavailable; this is the phase blocker.
- Pitfalls: MEDIUM — directly grounded in Phase 74 evidence limits, local compatibility policy, and official Stripe/Elixir docs.

**Research date:** 2026-09-24
**Valid until:** 2026-10-24 for stable architecture; candidate evidence must be refreshed when inventory/snapshot access changes.
