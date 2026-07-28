# Phase 63: Stripe-Native Entitlements - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-28
**Phase:** 63-stripe-native-entitlements
**Areas discussed:** Summary shape & truncation, Feature verb surface, Namespace/ExDoc/guide, Proof depth

**Mode:** All four areas selected. User delegated the decisions to Claude — *"think deeply one-shot a perfect set of recommendations so i dont have to think, all recommendations are coherent/cohesive with each other"* — with an explicit instruction to research each area via subagents through breadth-and-depth lenses (idiomatic Elixir/ecosystem practice, cross-language SDK lessons incl. what they got right and their footguns, DX/consumer-API-as-UX, JTBD who/what/where/when/why, domain language, architecture, and the `prompts/` commissioned research). No brandbook exists — correct for a headless SDK, so the design-pillar lenses were applied to API surface, discoverability, and least-surprise rather than visual design.

Four `gsd-advisor-researcher` subagents ran in parallel, one per area, each instructed to flag cross-area conflicts. Claude reconciled the four reports; three reconciliations diverge from an individual researcher's recommendation and are marked ⚠ below.

---

## Summary shape & truncation follow-through (ENT-05)

### 1a — module ownership seam (Phase 63 vs 65)

| Option | Description | Selected |
|--------|-------------|----------|
| Full `ActiveEntitlementSummary` module in 63; 65 keeps registry row + fixtures | Matches declared dep direction (65 depends on 63); SC#5 provable by direct `from_map/1` unit test | ✓ |
| 63 only makes deserialization "id-tolerant"; module deferred to 65 | Nominally smaller phase | |

**Rationale:** the second option's premise is false. Verified that nothing in the SDK drops id-less objects — `Client.build_decoded_response/6` and `ObjectTypes.maybe_deserialize/1` key only off the wire `"object"` string, and `List.first_item_id/1` already returns `nil` gracefully. Phase 63 would have shipped a no-op and failed its own success criterion.

### 1b — what the inlined `entitlements` field becomes

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Typed `%List{}` + rewritten resumable cursor state | Resume from the inline page via `starting_after=<last inline id>` | partial ⚠ |
| (b) Typed `%List{}`, cursor nil + documented re-fetch recipe | Wire-faithful; no URL-rewrite commitment | |
| (c) Raw `[map()]` | Smallest diff | |

**Claude's reconciliation ⚠:** typed `%List{}` adopted (against (c), which has the worst reversibility and would repeat the `Product.features` mistake Phase 66 exists to undo). But the researcher's cursor-**resume** was rejected in favour of a **full canonical re-fetch** keyed on `summary.customer`. Resume stitches a webhook snapshot from T₀ to a fresh query at T₁ across a cursor whose ordering assumption spans both — a hybrid snapshot. Accrue's stated goal is to move *from* monotonic-snapshot *to* refetch-canonical; a hybrid is a third thing, harder to reason about than either. Ergonomics are identical; only the correctness story improves. Cursor state is still populated (D-04) as defensive insurance so `List.stream/2` cannot silently truncate for anyone who reaches for it.

**Notes:** the researcher's claim that the inlined `url` (`/v1/customer/{id}/entitlements`) is non-callable was **independently checked and softened** — Stripe's own docs instruct using that field, so it is probably an undocumented alias and its callability is *not* established. Recorded honestly in CONTEXT.md F-05: we route around it because the canonical path is documented and provably correct, not because the alias is proven broken. Also independently verified: `customer` is required on the list endpoint and `limit` defaults to 10.

---

## `Entitlements.Feature` verb surface (ENT-04)

| Option | Description | Selected |
|--------|-------------|----------|
| `update/4` only + moduledoc "Archiving" section | Matches Price/Product and all 5 official Stripe SDKs | ✓ |
| `archive/3` + `unarchive/3` | Discoverable domain verbs | |
| `archive/3` only | Sidesteps the reversibility claim | |

**Claude's reconciliation ⚠:** this **overturns the framing in Claude's own gray-area presentation**, which suggested archiving might earn a verb under the project's "explicit verbs over magical updates" decision. Evidence says the doctrine is narrower and is stated verbatim in `Subscription.pause_collection/5`'s `@doc`: explicit verbs mirror explicit Stripe *endpoints*; when wrapping `update`, name the function after the exact wire field. `Billing.Meter.deactivate/3` exists because Stripe shipped `/deactivate`. Stripe shipped no archive endpoint (verified against the OpenAPI spec: no DELETE, `[get, post]` only). Field-name-faithful would force `set_active/4` — the tell that the wrapper is wrong. Decisive corroboration: **Price and Product have the identical `active: false` mechanic and neither ships an archive verb.**

**Notes:** two landmines surfaced that hit accrue's drift-detection job directly and are now moduledoc-mandatory — Stripe uses `active` (object field) vs `archived` (list filter) for one concept, and `list/3` silently omits archived features by default, so a naive reconciler reports archived features as *deleted*.

### Sub-decisions

| Sub-question | Selected |
|---|---|
| Required-param enforcement | `Resource.require_param!/3` on `Feature.create/3` (`name`, `lookup_key`) — matching `Billing.Meter.create/3`'s message format. **Extended by Claude** to `ActiveEntitlement.list/3` + `stream!/3` for `customer` (required per Stripe; also makes the cross-tenant leak guard meaningful) |
| `id in [nil, ""]` ArgumentError guards | Rejected — only 5 of 55 modules do this; a minority pattern, not the convention |
| `lookup_key` affordance | Moduledoc recipe only, no `retrieve_by_lookup_key/3` — mirrors `Price` exactly |
| `stream!/3` on Feature | Included, though beyond ENT-04's literal text — it would otherwise be the only list-bearing module in 60+ without it |
| Custom `Inspect` | Omitted — `charge.ex` has one solely to redact PII; a Feature holds none |

---

## Namespace, ExDoc placement, and the guide

| Sub-question | Options | Selected |
|---|---|---|
| **3a** Layout | No parent `entitlements.ex` / parent facade module / flat files | **No parent module** ✓ |
| **3b** ExDoc group | New `Entitlements:` group / fold into `Billing` / fold into `Billing Metering` / rename to a conjunction | **New group** ✓ |
| **3c** Guide | Ship `guides/entitlements.md` in 63 / defer to 67 / moduledoc-only + append to an existing guide | **Ship in 63, spine-only** ✓ |

**Notes:** the layout rule was *derived from evidence* rather than chosen — a parent `.ex` exists iff the parent is itself a real Stripe resource or has functions (`billing/`, `tax/`, `checkout/`, `billing_portal/` have none; `invoice/`, `quote/`, `webhook/` do). There is no `/v1/entitlements` endpoint. Flagged as the phase's only **one-way door**: module names are the semver contract once v1.10 tags.

Folding into `"Billing"` (already 22 modules) was rejected as precisely the failure mode Phase 62's D-04 named — *"buries it in a 14-item group, worst discoverability."* `Product.Feature` was pre-assigned to the same `Entitlements` group in Phase 66 so the two things called "Feature" sit adjacent.

The write-thrice objection to shipping the guide now was dissolved by reserving three pre-cut stub sections (Webhooks, Testing, Product attachment) that Phases 65/66 *fill* rather than rewrite.

**The `entitled?` fence** ships in all three surfaces, each with a distinct job: the `ActiveEntitlement` moduledoc (where a contributor grepping the string actually lands), the guide's `## Scope boundary` (which carries the *replacement* pattern — refusal-without-alternative is what gets "fixed"), and `guides/scope.md` (already docs-truth-locked; a decision not there is not locked project-wide).

**Deferred out:** 32 ungrouped lib modules including the entire `Tax.*` family — real debt found during this discussion, routed to Phase 67 rather than fixed here.

---

## Proof depth

| Option | Description | Selected |
|--------|-------------|----------|
| Full triangulation: Mox + stripe-mock integration + docs-truth | Charge (v1.7) precedent | ✓ |
| Capability probe / runtime skip | Defensive if the mock regresses | |
| `@tag :skip` with documented trigger | Honest about a gap | |
| No integration test | Cheapest | |

**Decided empirically, not by argument.** The researcher ran `stripe/stripe-mock:latest` (v0.199.0) locally and curled every endpoint: **all six verbs this phase ships return 200.** There is no capability question, so a probe was rejected — its failure mode is a *silent skip*, i.e. exactly the fake-green this project has recorded values against (it retired a phase as `accepted-external-verification` rather than fake a close).

Two honest gaps, to be written into the integration test's `@moduledoc` rather than papered over: stripe-mock returns one synthetic item per list and ignores `limit`/`starting_after`, so **it cannot prove pagination** (proven in Mox instead); and `active_entitlement_summary` has **no HTTP endpoint at all** in Stripe's spec, so it is proven by a pure `from_map/1` unit test.

**Claude's reconciliation ⚠ — a direct contradiction between two researchers.** The namespace researcher wanted `assert moduledoc =~ "entitled?"` so a contributor grepping the string lands on the explanation. The proof researcher proposed `refute source =~ "entitled?"` to prove absence. The refute would have forbidden the very documentation the fence depends on. Resolved: absence is proven **structurally** via `refute function_exported?` (an established four-precedent idiom in this repo, and — with typespecs documentation-only and no Dialyzer — the *only* enforcement of surface shape available); the string must be **present** in prose for discoverability. Assert presence, never refute it.

**Notes:** the highest-value test in the phase is `"page 2 preserves the customer filter"` — if `base_params` preservation regresses, the reconciler silently streams the entire account's entitlements instead of one customer's, a cross-tenant data leak not covered by the existing `list_test.exs`. Locks were deliberately capped at three; generic pagination prose was explicitly *not* locked, on the grounds that a noise lock erodes the mechanism.

---

## Claude's Discretion

The user delegated all four areas wholesale. Everything above is Claude's judgement, research-backed and reconciled for internal coherence. Remaining discretion at plan time: exact prose, moduledoc wording, guide section copy, snippet selection, and test naming — within the D-01…D-29 frame.

Two standing instructions recorded in CONTEXT.md: re-verify the ten F-facts against source and live Stripe docs before implementing (this project's own recorded lesson is that coherent planning artifacts can still miss code truth); and where a researcher's claim and CONTEXT.md disagree, CONTEXT.md wins — the ⚠ divergences were reconciled deliberately.

## Deferred Ideas

- 32 ungrouped lib modules in `groups_for_modules` (incl. all 14 `Tax.*`) → Phase 67
- Promoting `guides/entitlements.md` to a 5th Flagship Recipe → only on adopter pull
- Oban-style `guides/upgrading/` subdirectory → carried from Phase 62, still not triggered
- Fixing the 43 pre-existing `mix docs --warnings-as-errors` warnings → not this phase's debt
- `retrieve_by_lookup_key/3` on `Feature` → rejected now, additive later if friction is real

## Scope-adjacent findings (not deferred — recorded for the roadmap)

- **Phase 66 has a hard code dependency on Phase 63** that ROADMAP.md currently phrases loosely: `Product.Feature.from_map/1` must call `Entitlements.Feature.from_map/1` to decode its `entitlement_feature` field.
- **Phase 65 needs a build-constraint line** instructing promote-by-move for the entitlements fixtures, so it moves Phase 63's file rather than authoring a second one.
