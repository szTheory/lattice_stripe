---
phase: 63-stripe-native-entitlements
verified: 2026-07-28T16:21:13Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps: []
deferred:

  - truth: "entitlements.* object-type registry rows in lib/lattice_stripe/object_types.ex (automatic webhook deserialization)"
    addressed_in: "Phase 65"
    evidence: "Phase 65 goal: 'Five entitlement/meter object types deserialize; public fixtures (Wave 2)'. Phase 63 confirmed to have ZERO runtime dependency on the missing rows."

  - truth: "Public LatticeStripe.Testing.Fixtures.Entitlements"
    addressed_in: "Phase 65"
    evidence: "ROADMAP Phase 65 build constraint records the move-plus-rename promotion contract for test/support/fixtures/entitlements.ex"

  - truth: "product_feature attachment surface (LatticeStripe.Product.Feature)"
    addressed_in: "Phase 66"
    evidence: "Phase 66: 'Product ↔ Feature Attachment — Attach/list/delete product features + typed Product.features (Wave 3)'"

  - truth: "mix ci green (docs --warnings-as-errors on 42 pre-existing warnings)"
    addressed_in: "Phase 62 / Phase 67"
    evidence: "Phase 62 Success Criterion 3: 'mix ci passes (docs --warnings-as-errors, credo --strict)'. Phase 63 contributes zero of the 42 warnings (verified by attribution below)."
human_verification:

  - test: "Run ActiveEntitlement.stream!/3 against LIVE Stripe (not stripe-mock) for a customer with >10 active entitlements; confirm the returned count equals the dashboard count."
    expected: "Every entitlement is returned across multiple pages, with the customer filter preserved on page 2+."
    why_human: "Declared `verification: backstop` in 63-05-PLAN.md — non-inferable. stripe-mock ignores `limit`/`starting_after` and returns one synthetic item per list, so live-Stripe cursor honoring is structurally unprovable in CI. The SDK-side cursor construction IS proven (Mox multi-page, 10 assertions); what is unproven is Stripe's server-side response to the requests this SDK builds."

  - test: "Decide whether `guides/entitlements.md:11` should read 'v1.10' (the internal milestone label) or '1.8.0' (the Hex release this ships in)."
    expected: "The published HexDocs guide names a version an adopter can actually pin to."
    why_human: "Editorial/release-naming decision. mix.exs @version is 1.7.13; ROADMAP milestone v1.10 is explicitly labelled '(Hex 1.8.0)'. Precedent guides/tax.md says 'v1.6' where milestone and Hex version coincided; here they diverge, so the label is ambiguous rather than plainly wrong. No docs_truth lock covers it."
---

# Phase 63: Stripe-Native Entitlements Verification Report

**Phase Goal:** Developers can pull and auto-paginate a customer's active entitlements and manage entitlement features.
**Verified:** 2026-07-28T16:21:13Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `ActiveEntitlement.list/3` returns a customer's active entitlements from `GET /v1/entitlements/active_entitlements` (customer filter) | ✓ VERIFIED | `active_entitlement.ex:140-150` builds `%Request{method: :get, path: "/v1/entitlements/active_entitlements"}` → `Client.request/2` → `Resource.unwrap_list(&from_map/1)`. Behavioral: `active_entitlement_test.exs:17` asserts method, URL and `customer=cus_123` on the outgoing Mox request and decodes `[%ActiveEntitlement{id: "ent_123"}]`. Live: integration test asserts `list.url == "/v1/entitlements/active_entitlements"` against stripe-mock v0.199.0 (ran green here). |
| 2 | `ActiveEntitlement.stream!/3` auto-follows `has_more`/cursor across pages | ✓ VERIFIED | `active_entitlement.ex:180-195` delegates to `LatticeStripe.List.stream!/2` + `Stream.map(&from_map/1)`. Behavioral (all executed green): page-2 `starting_after=ent_b` from the LAST id of page 1; **page 2 preserves `customer=cus_123`** (cross-tenant leak guard); N pages = exactly N transport calls; `Stream.take(1)` fetches only page 1; empty page → `[]` in one call; wire order stable across the seam; `stripe-account` header carried to page 2; idempotency-key stripped on page 2; **500 on page 2 raises rather than truncating**. |
| 3 | `ActiveEntitlement.retrieve/3` returns a single typed active entitlement by id | ✓ VERIFIED | `active_entitlement.ex:114-118`, path composed as `@list_path <> "/#{id}"`. Behavioral: `active_entitlement_test.exs:80` (Mox, asserts `/{id}` route + typed struct), `:94` (bang returns bare struct), `:103` (bang raises on error payload). Live: integration `retrieve/3` test green against stripe-mock. |
| 4 | `Entitlements.Feature` supports create/retrieve/update/list over `/v1/entitlements/features` | ✓ VERIFIED | `feature.ex` ships all four plus bang twins plus `stream!/3` and `from_map/1` (10 functions). Behavioral: 29 tests in `feature_test.exs` incl. POST route + typed decode, stable idempotency-key across two identical creates, pre-network `lookup_key`/`name` guards consuming zero Mox expectations, `archived` filter passthrough, single-match `lookup_key` still returns a `%List{}`, `archived` filter carried onto every streamed page. Live: 5 integration tests green. |
| 5 | An `active_entitlement_summary` payload with **no top-level `id`** deserializes without being dropped | ✓ VERIFIED | `active_entitlement_summary.ex` — `defstruct` has no `:id`, `@known_fields ~w(object customer entitlements livemode)`. Behavioral: `refute Map.has_key?(%ActiveEntitlementSummary{}, :id)`; typed nested `%List{}` of `%ActiveEntitlement{}`; `has_more` preserved; **`_last_id` derived from RAW maps before typing** (the silent-truncation lock); url rewritten to the canonical path; `_params` carries the customer filter; empty-but-truncated page still decodes. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

All five are behavior-dependent (state transitions / cursor + ordering invariants). Each is backed by an executed test, not by symbol presence. Full suite run three times here (default seed, 917342, 5): **2188 tests, 0 failures, 1 skipped (204 excluded)** every time.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|--------------|----------|
| 1 | `entitlements.*` rows in `object_types.ex` | Phase 65 | Phase 65 goal + build constraints. Verified independent: see Data-Flow Trace. |
| 2 | Public `LatticeStripe.Testing.Fixtures.Entitlements` | Phase 65 | ROADMAP:138 records the move-plus-rename contract and the four function names to carry over |
| 3 | `product_feature` attachment surface | Phase 66 | Phase 66 goal; guide + moduledocs both say so explicitly |
| 4 | `mix ci` green | Phase 62 / 67 | Phase 62 SC 3; Phase 63 contributes 0 of the 42 warnings |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/lattice_stripe/entitlements/active_entitlement.ex` | ENT-01/02/03 read surface | ✓ VERIFIED | 235 lines. `list/3`, `list!/3`, `retrieve/3`, `retrieve!/3`, `stream!/3`, `from_map/1`, `list_path/0`. No write verbs, no `entitled?`. |
| `lib/lattice_stripe/entitlements/feature.ex` | ENT-04 complete verb surface | ✓ VERIFIED | 308 lines, 10 functions. `Feature.list_path/0` correctly absent (removed as dead in 63-03); zero references remain anywhere in `lib/` or `test/`. |
| `lib/lattice_stripe/entitlements/active_entitlement_summary.ex` | ENT-05 webhook decode | ✓ VERIFIED | 170 lines. `from_map/1` + `stream_entitlements!/3` only. No `:id` field, with a source comment forbidding its addition. |
| `test/support/fixtures/entitlements.ex` | Private wire fixtures | ✓ VERIFIED | `LatticeStripe.Test.Fixtures.Entitlements`; consumed by all four unit suites. |
| `test/lattice_stripe/entitlements/*.exs` | Unit + pagination + surface locks | ✓ VERIFIED | 4 files, 1076 lines. All `async: true`, all green. |
| `test/integration/entitlements_integration_test.exs` | stripe-mock routing proof | ✓ VERIFIED | 109 lines, 7 tests, `@moduletag :integration`. Executed here against a live `stripe/stripe-mock:latest` container: **7 tests, 0 failures**. `setup_all` raises with the exact docker command when nothing listens on 12111 — no `@tag :skip`, no capability probe (verified by reading `setup_all`). |
| `guides/entitlements.md` | Canonical guide, 294 lines | ⚠️ VERIFIED WITH ONE INACCURACY | Every documented function exists at the documented arity (see Docs-Truth Audit). One version-label inaccuracy at line 11 — routed to human. |
| `mix.exs` | ExDoc registration | ✓ VERIFIED | `guides/entitlements.md` in `extras:` (L48) **and** in `groups_for_extras` "Canonical Guides" (L83), positioned between `customer-portal.md` and `metering.md` as planned. `groups_for_modules` `Entitlements:` (L191-195) holds all three modules, adjacent to Billing Metering. |
| `test/lattice_stripe/docs_truth_test.exs` | L3 prose locks | ✓ VERIFIED | New top-level test at L524-574 + `entitled?`/`entitlements.md` anchors added to the scope.md lock at L347-350. |
| `.planning/.../docs-warning-baseline.txt` | Clean-HEAD warning count | ⚠️ WEAK ARTIFACT | Contains the single token `42` — a count, not the warning text. See INFO-2. |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `active_entitlement.ex` | `feature.ex` | `Feature.from_map/1` called DIRECTLY on an expanded `feature` map (L225-229), never through `ObjectTypes` | ✓ WIRED |
| `active_entitlement.ex` | `list.ex` | `LatticeStripe.List.stream!(client, req)` (L194) — cursor state machine not re-grown | ✓ WIRED |
| `active_entitlement.ex` | `resource.ex` | `Resource.require_param!/3` (L141, L183) + `unwrap_list/2` (L149) + `unwrap_singular/2` (L117) | ✓ WIRED |
| `feature.ex` | `resource.ex` | `require_param!` ×2 (L138, L144), `unwrap_singular`, `unwrap_list`, `unwrap_bang!` | ✓ WIRED |
| `feature.ex` | `list.ex` | `LatticeStripe.List.stream!` (L275) | ✓ WIRED |
| `active_entitlement_summary.ex` | `list.ex` | `List.from_json/3` on the RAW map FIRST (L161-166), typing in the struct-update | ✓ WIRED |
| `active_entitlement_summary.ex` | `active_entitlement.ex` | `ActiveEntitlement.list_path()` (L165) + `ActiveEntitlement.stream!/3` (L116) | ✓ WIRED — this is also the sole consumer that keeps `list_path/0` from being dead |
| `mix.exs` | `guides/entitlements.md` | Both halves of the registration present | ✓ WIRED |
| `guides/entitlements.md` | `active_entitlement_summary.ex` | Reconciler example calls `stream_entitlements!/3` | ✓ WIRED |

### Data-Flow Trace (Level 4) — Phase 65 independence

| Concern | Trace | Result |
|---------|-------|--------|
| Does anything in Phase 63 need the missing `object_types.ex` entitlement rows at runtime? | `grep -rn "ObjectTypes"` over `lib/lattice_stripe/entitlements/`, `guides/entitlements.md`, and all entitlements tests → **2 hits, both inside a source comment** (`active_entitlement.ex:222-223`) explaining why routing through `ObjectTypes` was deliberately avoided. Zero call sites. | ✓ INDEPENDENT |
| Does the registry already carry entitlement rows (Phase 65 work leaking early)? | `grep -i entitlement lib/lattice_stripe/object_types.ex` → **zero hits**. | ✓ CLEAN DEFERRAL |
| Is the guide's reconciler example executable TODAY without the registry? | `Event.from_map/1:231` stores `data: map["data"]` **raw** (no deserialization pass), so `event.data["object"]` is a raw string-keyed map, which is exactly what `ActiveEntitlementSummary.from_map/1`'s `is_map/1` clause consumes. | ✓ RUNS TODAY |
| No `ObjectTypes.maybe_deserialize/1` snippet survived into the guide? | Confirmed absent from `guides/entitlements.md`. The guide's Webhooks + Testing sections instead say to decode "explicitly with `ActiveEntitlementSummary.from_map/1`" and that fixtures/registry entries land later. | ✓ TRUTHFUL |

### Structural Lock Audit — real coverage, not theater

The stated risk is that `function_exported?/3` returns `false` for an **unloaded** module, which would make every `refute` vacuously true.

| Check | Method | Result |
|-------|--------|--------|
| Is `function_exported?/3` load-sensitive here? | `MIX_ENV=test mix run -e 'function_exported?(Feature, :create, 3)'` → `false` before `Code.ensure_loaded`, `true` after. | Yes — the hazard is real in principle |
| Are the modules loaded when the lock tests run? | Ran the lock test **in isolation** (`mix test feature_test.exs:356`, 28 other tests excluded) → `1 test, 0 failures`. The `assert function_exported?` half passes with nothing else in the file executing, so the module IS loaded. Same for `active_entitlement_summary_test.exs:143`. | ✓ NON-VACUOUS |
| Do the locks cover every exported arity of a defaulted-arg function? | `Feature`: `archive/2,3`, `unarchive/2,3`, `set_active/3,4`, `delete/2,3`, `retrieve_by_lookup_key/2,3`, `stream/1,2,3` — a `def archive(client, id, opts \\ [])` exports 2 AND 3; both refuted. `ActiveEntitlement`: `entitled?/2,3,4`, `create/2,3`, `update/3,4`, `delete/2,3`, `stream/1,2,3`. `Summary`: `retrieve/2,3`, `retrieve!/2,3`, `stream_entitlements/2,3`. | ✓ WOULD CATCH A REGRESSION |
| Gap in the lock set | Bang twins of refuted verbs are NOT refuted (`ActiveEntitlement.create!`, `Feature.delete!`, `Feature.archive!`). | ℹ️ INFO-3 — a contributor adding only `delete!/3` slips past. Low likelihood (bang twins are never added without their non-bang sibling in this codebase) but the lock set is not airtight. |
| Positive locks (present-surface) | 63-03's must_haves claim exactly ten `Feature` functions; the assert block enumerates 10 names across 19 arities and the module exports exactly those. `list_path/0` is deliberately NOT among them, matching the 63-03 removal. | ✓ CONSISTENT |

### Docs-Truth Audit — `guides/entitlements.md`

Every function the guide names, checked against source at the documented arity:

| Guide reference | Source | Status |
|-----------------|--------|--------|
| `ActiveEntitlement.list/3`, `list!/3`, `retrieve/3`, `retrieve!/3`, `stream!/3` | `active_entitlement.ex` | ✓ all exist |
| `resp.data.data` on a list result | `Resource.unwrap_list/2:63-66` returns `%Response{data: %List{data: typed}}` | ✓ correct field path |
| `ActiveEntitlementSummary.from_map/1`, `stream_entitlements!/3` | `active_entitlement_summary.ex` | ✓ both exist |
| `Feature.create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` + bang twins (verb table L187-196) | `feature.ex` | ✓ all 9 exist at stated arity |
| `Feature.update(client, feature.id, %{"active" => false})` archive snippet | `feature.ex:204` | ✓ executable |
| `LatticeStripe.Client.request/2` (escape hatch) | `client.ex:189` | ✓ exists |
| `%LatticeStripe.Event{}` / `event.data["object"]` | `event.ex:102` `data: map() \| nil`, stored raw | ✓ executable |
| `LatticeStripe.Webhook.Handler` | `lib/lattice_stripe/webhook/handler.ex` | ✓ exists |
| `ObjectTypes.maybe_deserialize/1` (the prior draft's user-breaking snippet) | — | ✓ ABSENT — nothing similar survived |
| Relative links: scope, testing, webhooks, error-handling, customer-portal, metering, subscriptions | `guides/*.md` | ✓ all 7 files exist; `mix docs` emits zero warnings for any of them |
| **L11: "Code examples reflect function signatures shipped in v1.10."** | `mix.exs @version "1.7.13"`; ROADMAP milestone `v1.10 — ... (Hex 1.8.0)` | ⚠️ **INACCURATE** — see WARNING-1 |

Forward-looking stub sections (Attaching features to products, Testing, Webhooks) are honestly hedged — "not yet part of the typed surface", "not yet exported", "when the registry entries land" — and match the actual Phase 65/66 deferrals. No stub over-promises.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full unit suite (seed default) | `mix test` | 2188 tests, 0 failures, 1 skipped (204 excluded) | ✓ PASS |
| Full unit suite (seed 917342) | `mix test --seed 917342` | 2188 tests, 0 failures | ✓ PASS |
| Full unit suite (seed 5) | `mix test --seed 5` | 2188 tests, 0 failures | ✓ PASS |
| Integration vs. live stripe-mock | `docker run stripe/stripe-mock:latest` + `mix test --only integration test/integration/entitlements_integration_test.exs` | **7 tests, 0 failures** | ✓ PASS |
| Surface lock non-vacuity | `mix test feature_test.exs:356` (isolated) | 1 test, 0 failures | ✓ PASS |
| `function_exported?` load semantics | `MIX_ENV=test mix run -e '...'` | `false` → `true` after `ensure_loaded` | ✓ PASS (hazard characterized) |
| Formatting | `mix format --check-formatted` | exit 0 | ✓ PASS |
| Compile | `mix compile --warnings-as-errors` | exit 0 | ✓ PASS |
| Credo | `mix credo --strict` | 2225 mods/funs, found no issues | ✓ PASS |
| Docs build | `mix docs` | 42 warnings, exit 0 | ✓ PASS |
| Docs gate | `mix docs --warnings-as-errors` | **exit 1** | ✗ FAIL — pre-existing, see WARNING-2 |

Docker was available; stripe-mock was started, the integration suite was run, and the container was stopped. The suite was NOT assumed to pass.

### `mix ci` Attribution — the "predates Phase 63" claim, verified

The claim was checked rather than accepted. Evidence:

1. `mix ci` = `format --check-formatted` → `compile --warnings-as-errors` → `credo --strict` → `test` → `docs --warnings-as-errors` (`mix.exs:327-337`). The first four all pass (run individually above). Only the fifth fails.
2. `mix docs` emits **42** warnings. `grep -i entitlement` over the full output → **zero hits**. Not one warning names any entitlements module, the guide, or any Phase 63 file.
3. The 42 warnings (21 distinct, doubled across the HTML and EPUB passes) name only: `../README.md`, `../notebooks/stripe_explorer.livemd`, `File.create/3`, seven hidden `LatticeStripe.Tax.*` / `TaxId.*` types, hidden `LatticeStripe.ObjectTypes` (+ `fetch_module/1`), hidden `BillingPortal.Guards.check_flow_data!/1`, and private `Webhook.check_tolerance/2`.
4. Cross-referenced against the file footprint of every Phase 63 commit (`git log --name-only`): the phase touched `guides/entitlements.md`, `guides/scope.md`, the three entitlements modules, `mix.exs`, and five test files. **No warned-about file intersects that set.**
5. 63-07-SUMMARY discloses this honestly rather than claiming green: *"`mix ci` ... fails only at its final `docs --warnings-as-errors` step, on 42 pre-existing warnings, none of which name an entitlements file."* Independently confirmed.

**Verdict: the claim holds.** Phase 63 contributes 0 of the 42. (Residual limitation: a true pre-phase baseline would require checking out a pre-Phase-63 commit and re-running `mix docs`, which the read-only/no-branch-switch constraint forbids. Attribution by file footprint is the strongest available substitute and is unambiguous here.)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ENT-01 | 63-01, 63-05, 63-06, 63-07 | List a customer's active entitlements via `ActiveEntitlement.list/3` | ✓ SATISFIED | SC1 above. Mandatory pre-network `customer` guard (`Resource.require_param!/3`) proven to raise with **zero** Mox expectations consumed. Prohibition (no `entitled?` gate) held: absent, structurally refuted at 3 arities, and the name kept greppable in prose with a working fail-closed replacement. |
| ENT-02 | 63-02, 63-06 | Auto-paginate via `stream!/3` following `has_more`/cursor | ✓ SATISFIED | SC2 above. The reconciler-critical piece. The named cross-tenant guard ("page 2 preserves the customer filter") exists verbatim and passes. Prohibition (never silently partial) held: a 500 on page 2 raises. |
| ENT-03 | 63-02, 63-05 | Retrieve a single active entitlement by id | ✓ SATISFIED | SC3 above. Unit + integration. |
| ENT-04 | 63-03, 63-05, 63-06, 63-07 | Create/retrieve/update/list entitlement features | ✓ SATISFIED | SC4 above. All four verbs + bangs + `stream!/3`. Archiving-is-`update/4` and no-`retrieve_by_lookup_key` are documented decisions with structural locks, matching the requirement text (which asks for exactly create/retrieve/update/list). |
| ENT-05 | 63-04, 63-06, 63-07 | `active_entitlement_summary` (no top-level `id`) deserializes without being dropped | ✓ SATISFIED | SC5 above. The `_last_id`-before-typing ordering lock is the highest-value assertion here and is mutation-checked in 63-04's coverage record. |

No orphaned requirements: REQUIREMENTS.md maps exactly ENT-01…ENT-05 to Phase 63, and every one is claimed by at least one plan and verified above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | `TODO`/`FIXME`/`XXX`/`TBD`/`HACK`/`PLACEHOLDER`/"not yet implemented"/"coming soon" across all three modules, the guide, all four unit suites, the integration suite, and the fixtures | — | **Zero hits.** No debt markers. |
| `active_entitlement.ex` | 100 | `@doc false def list_path` | ℹ️ INFO | Not dead — sole consumer is `active_entitlement_summary.ex:165`. Verified by repo-wide grep. `Feature.list_path/0` was correctly removed in 63-03 and has zero remaining references. |
| `active_entitlement_summary.ex` | 152, 169 | `parse_entitlements(other, _customer), do: other` passthrough | ℹ️ INFO | Deliberate forward-compat fallthrough for a non-list envelope, not a stub — the `%{"object" => "list"}` clause above it does the real work and is the one under test. |

No blocker anti-patterns. No hollow props, no empty-return stubs, no console-log-only handlers, no hardcoded empty data reaching render.

### Findings

**WARNING-1 — `guides/entitlements.md:11` names a version that will never exist on Hex.**
The line reads *"Code examples reflect function signatures shipped in v1.10."* `mix.exs` `@version` is `1.7.13`, and the ROADMAP milestone is explicitly *"v1.10 — Accrue Surface Closure **(Hex 1.8.0)**"*. The internal milestone counter and the Hex version have diverged, so an adopter reading the published HexDocs guide and searching hex.pm for `v1.10` finds nothing; the guide ships in `1.8.0`. The precedent (`guides/tax.md:10`, "shipped in v1.6") was written when milestone and Hex version coincided. This is a doc-truth defect in precisely the category this phase invested in locking, and **no `docs_truth_test` assertion covers the version string**. Routed to human as an editorial decision rather than filed as a gap, because "v1.10" is defensible as a milestone label.

**WARNING-2 — `mix ci` is RED at phase close (carry-forward, not caused here).**
Verified: format/compile/credo/test all pass; `mix docs --warnings-as-errors` exits 1 on 42 pre-existing warnings, **zero** attributable to Phase 63 (see attribution section). Phase 63's own Success Criteria do not include `mix ci`, so this is not a Phase 63 gap — but Phase 62's SC 3 *does* require `mix ci` to pass, so the debt is real and now belongs to Phase 62/67. Flagging so it is not silently inherited.

**INFO-2 — the docs-warning baseline is a bare count.**
`docs-warning-baseline.txt` contains the single token `42`. A count-only baseline cannot detect a swap (one warning fixed, one introduced, count unchanged). It happened to be sufficient here only because I independently attributed all 42 by content and file footprint. A future phase reusing this differential gate should record warning *text*, not a number.

**INFO-3 — surface locks omit bang twins of refuted verbs.**
`Feature.delete!`, `ActiveEntitlement.create!`/`update!`/`delete!` are not refuted. The non-bang refutations are arity-complete and would catch the realistic regression; a bang-only addition would slip through. Cheap to close if the family is extended.

**INFO-4 — one unreproduced full-suite flake is on record and did not recur.**
63-04-SUMMARY discloses a single `2187 tests, 1 failure` run that exited before printing a failure block and did not reproduce across eight subsequent runs. It did not recur in any of my three runs either. Recorded, not dismissed.

### Overstated-Claim Audit

Every executor claim in the task briefing was checked. All held:

- Module surfaces are exactly as described (including `list_path/0` present on `ActiveEntitlement`, absent on `Feature`).
- "7 tests, run green against live stripe-mock v0.199.0" — reproduced independently: 7/7 green against `stripe/stripe-mock:latest`.
- "294 lines" guide + ExDoc registration — exact.
- "`mix docs` → 42 warnings ... 0 attributable to entitlements" — reproduced and independently attributed.
- "`mix ci` RED only at the docs step" — reproduced, and the SUMMARY discloses it rather than claiming green.
- 63-03's claim of "29 tests" in `feature_test.exs` — counted: exactly 29.
- 63-05-SUMMARY even records a *correction* to its own orchestrator briefing (which wrongly described `archive`/`unarchive`/`retrieve_by_lookup_key` as shipped) rather than following the wrong briefing. That is the opposite of an overstated claim.

**No SUMMARY claim was found to overstate what the code does.** The single inaccuracy found (WARNING-1) is in the shipped guide, not in a SUMMARY, and no SUMMARY asserts it is correct.

### Gaps Summary

None. All five ROADMAP Success Criteria and all five requirements (ENT-01…ENT-05) are satisfied by code that exists, is substantive, is wired, carries real data, and is proven by executed tests rather than by symbol presence. The phase is also self-consistent with its deferrals: it has zero runtime dependency on the Phase 65 `object_types.ex` rows, and the guide sections that reference future work are honestly hedged.

Status is `human_needed` rather than `passed` for two items only: (1) the `verification: backstop` truth from 63-05 — live-Stripe multi-page cursor honoring, which is non-inferable and structurally unprovable against stripe-mock; and (2) an editorial decision on the `v1.10` version label in the guide.

---

## UAT Resolution (2026-07-28)

`status` moved `human_needed` → `passed` after `/gsd-verify-work 63`. Both items
that held it at `human_needed` were resolved:

1. **Live-Stripe multi-page cursor honoring (63-05 backstop).** Accepted as risk A1.
   stripe-mock returns one synthetic item per list and ignores both page size and
   cursor, so this is structurally unprovable at that leg; the proof stands at the Mox
   layer (`active_entitlement_stream_test.exs`, 63-02), and no live Stripe key exists
   in this environment. Recorded in `63-UAT.md` test 3.
2. **The `v1.10` guide version label.** Resolved editorially in commit 578f7b8
   ("correct guide version claim to the Hex release and lock its shape").

`63-UAT.md` records 63/63 — 56 deliverables deterministically covered by passing
tests, 7 human-judgment checkpoints approved by the maintainer.

### Re-verification after coverage-block repair

The seven `*-SUMMARY.md` files were subsequently edited to repair schema defects in
their `coverage:` blocks (an illegal `status: deferred` in 63-03 D10 and 63-05 D7;
a missing required `rationale` on all seven `human_judgment: true` entries). Those
edits touched coverage **metadata only** — no claim about the code changed.

Re-verified after the repair, all green:
- `mix test` — 2188 tests, 0 failures, 1 skipped
- `mix test --only integration` against stripe-mock v0.199.0 — 192 tests, 0 failures
- entitlements integration suite — 7 tests, 0 failures
- `check api-coverage.verify-pre` — passed (28 capabilities, 18 INTEGRATE, 10 OPT-OUT)
- `uat classify-coverage` over all seven summaries — 0 errors, and the classification
  is unchanged in shape (56 auto-passed, the same 7 human checkpoints), now reporting
  `reason: human_judgment` instead of `reason: validation_failed`

---

_Verified: 2026-07-28T16:21:13Z_
_Verifier: Claude (gsd-verifier)_
_UAT resolved + re-verified: 2026-07-28 (gsd-verify-work)_
