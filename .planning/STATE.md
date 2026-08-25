---
gsd_state_version: 1.0
milestone: v1.10
milestone_name: Accrue Surface Closure (Hex 1.8.0)
current_phase: 67
current_phase_name: DX Hardening & Milestone Doc Close
status: complete
stopped_at: Completed 67-05-PLAN.md
last_updated: "2026-08-25T18:41:24.666Z"
last_activity: 2026-08-25
last_activity_desc: Phase 67 complete; v1.10 milestone audit found bounded tech debt and no blockers
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 37
  completed_plans: 37
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (reopened 2026-07-27 — v1.10 "Accrue Surface Closure" under adopter-pull gate, SEED-005)

**Core value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.
**Current focus:** Review bounded v1.10 audit debt, then complete the milestone

## Current Position

Phase: 67 — DX Hardening & Milestone Doc Close
Plan: 5 of 5 complete
Status: Milestone audited — `tech_debt`, no blockers
Last activity: 2026-08-25 — Phase 67 verified; fresh v1.10 audit completed

**Milestone-close carry-forward:**

- Phase 67's fresh full `mix ci` passed 2,440 tests with 0 failures; strict ExDoc is at zero warnings and the public API lock contains 3,463 entries.
- The current post-Phase-67 audit is `.planning/v1.10-POST-PHASE-67-MILESTONE-AUDIT.md`: `tech_debt`, 19/19 requirements, 7/7 phases, 19/19 integrations, 6/6 flows, no blockers.
- Phases 61 and 63 retain `status: draft` Nyquist artifacts. Run `$gsd-validate-phase 61` and `$gsd-validate-phase 63` if current-form Nyquist reconciliation is desired before archival.
- Stripe-mock cannot prove live Stripe pagination for a customer with more than ten active entitlements. SDK-owned cursor, tenant-filter, laziness, and failure semantics are mechanically covered; the earlier maintainer checkpoint accepted this external-confidence boundary.
- Two known low-frequency tests remain explicitly outside Phase 67: client retry telemetry and Batch error isolation. Both are documented in `.planning/phases/64-meter-event-summary-reads/deferred-items.md`; the current full suite is green.

## Performance Metrics

**Velocity (v1.9):**

- Total phases: 2 (59–60)
- Total plans completed: 6
- Timeline: single-day (2026-05-27)

**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 63 P01 | 5min | 2 tasks | 6 files |
| Phase 63 P02 | 3min | 2 tasks | 3 files |
| Phase 63 P03 | 3min | 3 tasks | 2 files |
| Phase 63 P04 | 4min | 2 tasks | 2 files |
| Phase 63 P05 | 8min | 2 tasks | 2 files |
| Phase 63 P06 | 6min | 2 tasks | 3 files |
| Phase 63 P07 | 12min | 2 tasks | 3 files |
| Phase 64 P04 | 21min | 3 tasks | 8 files |
| Phase 65 P01 | 5min | 2 tasks | 12 files |
| Phase 65 P02 | 7min | 2 tasks | 15 files |
| Phase 65 P04 | 4min | 2 tasks | 2 files |
| Phase 65 P03 | 6min | 2 tasks | 14 files |
| Phase 65 P05 | 4min | 1 tasks | 7 files |
| Phase 65 P06 | 12min | 2 tasks | 7 files |
| Phase 66-product-feature-attachment P01 | 5min | 2 tasks | 2 files |
| Phase 66-product-feature-attachment P02 | 4min | 1 tasks | 1 files |
| Phase 66-product-feature-attachment P03 | 3min | 2 tasks | 3 files |
| Phase 66-product-feature-attachment P04 | 3min | 2 tasks | 4 files |
| Phase 66 P05 | 4min | 2 tasks | 4 files |
| Phase 67 P01 | 5min | 3 tasks | 6 files |
| Phase 67 P02 | 3min | 2 tasks | 2 files |
| Phase 67-dx-hardening-milestone-doc-close P04 | 6min | 2 tasks | 3 files |
| Phase 67-dx-hardening-milestone-doc-close P03 | 3min | 3 tasks | 6 files |
| Phase 67 P05 | 5min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

- **v1.10 reopens the build track** — adopter-pull gate fired (Accrue's verified blocking need for Stripe-native Entitlements); scope narrow + additive → Hex minor bump 1.8.0. Numbering diverges: GSD milestone v1.10, Hex tag 1.8.0 (v1.8/v1.9 were doc-only).
- **Wave 0 first** — default Finch pool (live footgun, DX-01) + "1.1 → 1.7 what landed" migration guide (DOC-01) are near-zero-code, de-risk, and unblock the most downstream accrue work.
- **Entitlements: pull/pagination shape only** — NO per-request `entitled?` gate helper (actively harmful for accrue's fail-closed local gate).
- **No new metering writes** — accrue uses exactly one (`MeterEvent.create/3`); all four write surfaces already ship. Only reads (EventSummary) are missing.
- **SEED-005 §6 stability contracts FROZEN** — nil `stripe_account` omits header; per-request opts override per-client; api_version default `2026-03-25.dahlia`; `Client.new!/1` takes a keyword list.
- **Lower-priority DX deferred to SEED-006** — brief §3.2, 3.5–3.9, 3.11 are real but non-blocking; not in this milestone.
- **v1.x stop signal otherwise holds** — no broad resource-family breadth (Identity, Treasury, Issuing, Terminal, etc.) in this reopen.
- [Phase ?]: Phase 61 default Finch pool: LatticeStripe.Application starts LatticeStripe.Finch at boot; :finch defaults to it (was required); opt-out via config :lattice_stripe, start_default_finch: false
- **[63-01]** D-16 (one-way): no parent lib/lattice_stripe/entitlements.ex — LatticeStripe.Entitlements.ActiveEntitlement is the published semver name once v1.10 tags; renaming after release is breaking
- **[63-01]** D-06: ActiveEntitlement owns the canonical /v1/entitlements/active_entitlements path as one @list_path + list_path/0 accessor; 63-02 stream!/3 and 63-04's summary url rewrite read it rather than re-declaring it
- **[63-01]** T-63-04 mitigated structurally: refute function_exported?(:entitled?, 2/3/4) forbids the gate helper (a rename cannot defeat it); the moduledoc keeps the name entitled? PRESENT in prose (D-24) and ships the fail-closed local-gate replacement
- **[63-01]** Feature.ex ships decode-only; its alias LatticeStripe.{Client, Request, Resource} was omitted (unused-alias vs --warnings-as-errors) and 63-03 MUST add it with the verb surface — an in-source NOTE marks the spot
- **[63-01]** Clean-HEAD ExDoc warning baseline = 42, recorded for the 63-07 differential docs gate; mix ci stays un-run this phase because its docs --warnings-as-errors step is RED at clean HEAD (C-02)
- **[63-02]** stream!/3 delegates the entire cursor state machine to LatticeStripe.List.stream!/2 — no per-resource pagination is ever re-grown; the resource module only supplies a %Request{} and maps from_map/1
- **[63-02]** D-10/Pitfall 6: the customer guard is stream!/3's FIRST statement so it raises at call time; Stream.resource/3 defers its start function, so a lazily-built guard would raise on the first Enum step far from the caller
- **[63-02]** T-63-02 mutation-checked: zeroing base_params in List.build_next_page_request/1 fails exactly 'page 2 preserves the customer filter' and nothing else — that test is proven load-bearing, not merely green, and must keep its specific name
- **[63-02]** stream!/3 ships with NO non-bang twin, refuted structurally at arities 1/2/3 (two defaulted args means arity-3-only refutation would leak a def stream/2)
- [Phase ?]: **[63-03]** 63-01 carry-forward discharged: alias LatticeStripe.{Client, Request, Resource} added to feature.ex and the NOTE deleted; the vestigial @doc false list_path/0 accessor REMOVED (five verbs read @list_path now) while ActiveEntitlement.list_path/0 stays because 63-04's summary url rewrite consumes it
- [Phase ?]: **[63-03]** D-08 held: no archive/3, no unarchive/3, no set_active/4, no delete at any arity — archiving is update/4 with active: false, and every one of those names is refuted structurally at every exported arity
- [Phase ?]: **[63-03]** T-63-08 is documentation-only by necessity: the active-field vs archived-filter split and its false-deletion consequence live in an {: .warning} moduledoc admonition because no function signature can carry the fact and stripe-mock does not vary by filter
- [Phase ?]: **[63-03]** D-12 held: no retrieve_by_lookup_key/3 — a single-match lookup_key filter is asserted to return a %List{} of one, and lookup_key's post-create immutability (absent from the update body schema) is documented as the reason it is safe to key host config on
- [Phase ?]: **[63-04]** D-05 mutation-checked: typing the nested data before List.from_json/3 in parse_entitlements/2 fails exactly '_last_id is derived from the raw maps before typing' — call order is the whole mitigation and the test that proves it must keep its name
- [Phase ?]: **[63-04]** F-02 held: %ActiveEntitlementSummary{} has NO :id field (the Stripe object has no id property and no x-resourceId); the omission carries a source comment so it is not 'fixed' later
- [Phase ?]: **[63-04]** D-03 held: stream_entitlements!/3 is a FULL canonical re-fetch at limit=100 keyed on summary.customer — never a cursor-resume from the inline page, which would stitch two points in time into one hybrid snapshot
- [Phase ?]: **[63-04]** D-04 held: the nested list's url is rewritten to /v1/entitlements/active_entitlements and _params is populated with the customer filter, so List.stream/2 over summary.entitlements is callable and tenant-scoped rather than 404-ing on the webhook's /v1/customer/{cus}/entitlements path
- [Phase ?]: 63-05: integration setup_all RAISES with the docker command when stripe-mock is absent — no @tag :skip and no capability probe, because a probe's failure mode is the silent skip (T-63-15/D-20)
- [Phase ?]: 63-05: pagination deliberately NOT asserted against stripe-mock — it ignores page size and cursor and returns one synthetic item per list; the proof stays in 63-02's Mox multi-page suite
- [Phase ?]: 63-05: no raw-DELETE test — the absent delete verb is an SDK-shape fact already locked in feature_test.exs, not a Stripe-behavior fact to re-probe
- [Phase ?]: 63-06: guides/entitlements.md ships the entitled? refusal WITH the four-step fail-closed local-gate replacement in the same section (D-19.2); a refusal without an alternative is what the next contributor deletes
- [Phase ?]: 63-06: the guide's reconciler example uses ActiveEntitlementSummary.from_map/1, not ObjectTypes.maybe_deserialize/1 as CONTEXT.md's snippet shows — the registry row is Phase 65, so maybe_deserialize/1 returns a raw map today and the snippet would raise
- [Phase ?]: 63-06: new Entitlements: groups_for_modules group between Billing Metering and Connect (D-17); Phase 66 appends Product.Feature here with a one-line diff
- [Phase ?]: 63-07: D-24 held — entitled? is asserted PRESENT in three docs-truth places (guide, ActiveEntitlement source, scope.md) and refuted nowhere; the new test contains zero `refute`, because refuting the name would forbid the documentation the fence depends on
- [Phase ?]: 63-07: gate 3 failed at 48 vs baseline 42 and was answered by fixing the autolinks, never by raising the baseline — the three `Resource.require_param!/3` prose sites from 63-01/63-03 were reworded to document the guard without naming a @moduledoc false helper; phase ends at 42 = baseline, surface count 0
- [Phase ?]: 63-07: mix ci is still RED, but now entirely on 42 pre-existing warnings (Tax.* nested types, File.create/3, ../README.md, ObjectTypes) — steps 1-4 pass and zero warnings name an entitlements file; clearing them is Phase 67-shaped work
- [Phase ?]: 64-04: v2 validation timestamps confirmed RFC3339 strings against the live Stripe reference (RESEARCH A3 settled) — MeterErrorReport types validation_start/end as String.t()
- [Phase ?]: 64-04: MeterErrorReport.from_event/1 raises a directive ArgumentError on a data-less event rather than a bare BadMapError — the delivered-webhook-body trap
- [Phase ?]: 64-04: ExDoc references to @moduledoc-false modules (LatticeStripe.ObjectTypes) must be plain prose, not backticked autolinks — they add warnings past the 42 baseline
- [Phase ?]: [65-01] The test/support/ -> lib/ fixture promotion is proven: git mv + module rename Test.Fixtures->Testing.Fixtures + real @moduledoc + one @spec per builder + mix.exs groups_for_modules[:Testing] + guide bullet + caller alias retargets, ALL in one commit, gated by MIX_ENV=prod mix compile (exit 0). 65-02/65-03/65-05 repeat this recipe.
- [Phase ?]: [65-01] active_entitlement_list_json/2 stays in-module — LatticeStripe.TestHelpers.list_json/3 lives in test/support/ and is unreachable from lib/; calling it compiles in :test and fails MIX_ENV=prod mix compile (RESEARCH Pitfall 3)
- [Phase ?]: [65-01] @object_map is now 49 rows (was 48); "entitlements.active_entitlement" appended at the family-grouped tail, NOT alphabetically — the map is only roughly alphabetical through "transfer_reversal" and mix format never reorders map keys. 65-04 takes it to 52.
- [Phase ?]: [65-01] Fully-qualified nested calls in tests trip mix credo --strict Design.AliasUsage — alias the promoted fixture at the top of the test module (the MeterErrorReportFixture convention); expansion plans should alias from the start
- [Phase ?]: [65-01] ExDoc warning count held at the 38 baseline with 0 matching entitlement|meter|testing|fixture — the differential docs gate stays usable for the rest of Phase 65
- [Phase ?]: [65-02] Q1 = flat-three: promote exactly three meter fixtures to public FLAT depth-3 names — LatticeStripe.Testing.Fixtures.MeterEvent / .MeterEventSummary / .MeterErrorReport. One-way door; semver-covered at Hex 1.8.0. 65-04 writes dispatch tests against these exact names.
- [Phase ?]: [65-02] Meter, MeterEventAdjustment and MeterEventStreamSession stay PRIVATE in test/support/fixtures/metering.ex — no requirement names them, so semver surface grows only where OBJ-01/OBJ-02 require. No Testing.Fixtures.Metering namespace exists; zero depth-4 public fixture names.
- [Phase ?]: [65-02] The Phase-64 in-source nested-promotion header on metering.ex was SUPERSEDED and replaced with a note recording flat-three, not deleted silently.
- [Phase ?]: [65-02] Promoted fixtures need 'as: <Object>Fixture' aliases in callers: the flat name collides with the LatticeStripe.Billing struct alias already in the same test module.
- [Phase ?]: Registered exactly three registry rows; billing.meter_error_report stays out — its v2 thin-event payload has no "object" key so the row would be a dead key (Phase 64 F-13/D-14)
- [Phase ?]: No map_size count assertion on @object_map — brittle against Phase 66's product.feature row; per-key fetch_module/1 assertions cover it instead
- [Phase ?]: Open question Q3 resolved NO: meter_event.ex gets no @known_fields, since from_map/1 never consults it and a decorative attribute would read as load-bearing
- [Phase ?]: **[65-03]** Q2 = `move-and-rename` (operator decision, one-way door): the three private core-billing fixtures (customer, payment_intent, subscription) are MOVED into lib/lattice_stripe/testing/fixtures/ — no private twin remains, so drift is structurally impossible and no drift lock is needed; `Subscription.basic/1` is renamed to `subscription_json/1` on promotion, joining the dominant `<object>_json` convention (11 of 14 public fixture modules, ~30 functions) rather than the 3 meter modules' `basic/1`, which are artifacts of 65-02's verbatim-movement rule. Follow-up for a later phase (NOT this one): the three meter `basic/1` builders are now the public-surface outliers and are worth aligning before the Hex 1.8.0 tag.
- [Phase ?]: **[65-03]** Q2 rename cost measured at 31 edits, not the 4 the plan implies — one `alias ..., as: Fixtures` line fronting 28 `Fixtures.basic(` call sites in subscription_test.exs, plus 3 internal composition call sites at subscription.ex :54/:71/:86 (the plan says :85; that line is the `def canceled` head). Also: the 65-02 `as: <Object>Fixture` caller-alias lesson is CONDITIONAL — it applies only when a caller aliases the fixture by its bare last segment; a caller already using a generic or `as:`-renamed alias needs no rewrite.
- [Phase ?]: [65-05] Invoice fixture caller uses import, not 'alias as: InvoiceFixture' — imports cannot collide with the LatticeStripe.Invoice alias, so all ~40 call sites stayed byte-identical
- [Phase ?]: [65-05] Verbatim lift verified by diffing the extracted body against the pre-delete source, not by a passing suite alone — catches drift in fields no assertion covers
- [Phase ?]: [65-06] Corrected ROADMAP Phase 65 prose from FIVE to FOUR entitlement/meter object types — Phase 64 D-14 proved billing.meter_error_report structurally unregistrable; OBJ-01, Success Criterion 1 and the object_types_test refute all already said four
- [Phase ?]: [65-06] The stale 'v1.3 resource families' claim was REPLACED with a scope description in both fixtures.ex and guides/testing.md, not bumped to a newer version — a version-pinned moduledoc claim is the recurring staleness trap that caused this correction
- [Phase ?]: [65-06] 65-RESEARCH.md Pitfall 7's count-assertion parenthetical was corrected (51 -> 52), not deleted — deleting it would strand both 65-04's deliberate decline of the map_size assertion and COVERAGE.md's OPT-OUT record
- [Phase ?]: [65-06] The three meter basic/1 builders were NOT renamed here (15 of 18 public fixture modules use <object>_json; exactly these 3 use basic). Recorded in .planning/phases/65-.../deferred-items.md as cheap before the Hex 1.8.0 tag and a breaking change after it
- [Phase ?]: [65-06] Phase 65 closed and validated: 65-VALIDATION.md status: validated, nyquist_compliant: true, 19/19 rows green. Gate numbers Phase 66 gates against: mix test 2332, mix docs 38 warnings, 0/0/0/0 substring matches, map_size(object_map()) 52
- [Phase ?]: [66-01] Product.Feature is the typed product_feature/prodft_ attachment; its canonical surface is scoped create/retrieve/list/stream!/delete with no aliases or delete-by-feat convenience.
- [Phase ?]: [66-02] Product.Feature.stream!/4 page-two coverage decodes exact query values and preserves raw prodft_ cursor, Product/Connect scope, caller filters, laziness, and loud failure semantics through List.stream!/2.
- [Phase ?]: [66-03] D-09/D-10/D-26 held: Product.features and Product.marketing_features remain independent raw maps in 1.x; typed attachments are Product.Feature only.
- [Phase ?]: [66-03] D-11/D-27 held: ObjectTypes registers exact product_feature, rejects product.feature byte-for-byte, and adds no map-size lock.
- [Phase ?]: [66-04] Product.Feature is placed under Entitlements by an exact ExDoc matcher; Product remains under Billing.
- [Phase ?]: [66-04] Product features and marketing_features remain raw marketing maps; Product.Feature list/4 and stream!/4 are authoritative attachment reads.
- [Phase ?]: [66-04] API lock admits only the accepted Product.Feature module, type, fields, canonical verbs, default arities, and decoder.
- [Phase ?]: [66-05] Catalog reads use Product.Feature.list/4 or stream!/4; Product marketing fields remain display copy.
- [Phase ?]: [66-05] Entitlement authorization remains local and fail-closed from a complete persisted webhook-reconciled snapshot; no entitled? helper ships.
- [Phase ?]: [67-01] Error response evidence preserves ordered duplicate headers and strict uncapped decimal Retry-After; scheduling remains adopter-owned.
- [Phase ?]: [67-02] CacheBodyReader appends every Plug :more/:ok chunk under the fixed raw_body key while preserving native tuples and error passthrough.
- [Phase ?]: Keep the complete Charge creation policy in exactly two canonical consumer-facing regions: the Charge moduledoc and the payments guide's Charge reconciliation section.
- [Phase ?]: Describe the absent Charge API as its function name plus arity so ExDoc stays warning-free while the rendered guidance remains explicit.
- [Phase ?]: Confirmed the pre-approved conditional CacheBodyReader.read_body/2 contract; no storage, key, availability, or return-shape alternative was reopened.
- [Phase ?]: CacheBodyReader is public only with Plug; endpoint ordering remains canonical and parser-level retention stays a narrow non-multipart alternative.
- [Phase ?]: Phase 67 uses zero-warning ExDoc plus full CI as the documentation closure gate; no differential baseline.
- [Phase ?]: Phase 67 D-18 audits use the oldest 67 task commit parent as the immutable scope base; D-17 remains post-verification orchestration.

### Blockers/Concerns

- **Requirement count**: REQUIREMENTS.md header says "17 v1 requirements" but the enumerated list contains **19 distinct IDs** (ENT×5, MTR×4, OBJ×3, PROD×2, DX×3, DOC×2). All 19 are mapped to phases (100% coverage). The "17" is a stale count in the source header, not a coverage gap.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 20260528-i13p | Issue #13 drift patches — Balance, BalanceTransaction, BillingPortal.Session | 2026-05-28 | 79f6baf | [20260528-issue-13-drift-patches](./quick/20260528-issue-13-drift-patches/) |
| 20260528-jnc | JTBD narrative close — Adopter-owned depth + Mandates reading order | 2026-05-28 | a49a0f7 | [20260528-jtbd-narrative-close](./quick/20260528-jtbd-narrative-close/) |
| 20260528-dts | Doc-truth Connect + Webhook sibling clusters | 2026-05-28 | a49a0f7 | [20260528-docs-truth-sibling-clusters](./quick/20260528-docs-truth-sibling-clusters/) |
| 20260528-car | Capstone assessment refresh — STATE/PROJECT/v1-10 thread | 2026-05-28 | 775c8c5 | [20260528-capstone-assessment-refresh](./quick/20260528-capstone-assessment-refresh/) |
| 260528-i13 | Issue #13 drift triage — categorized report + maintenance tracker | 2026-05-28 | 8fc5e4b | [260528-issue-13-drift-triage](./quick/260528-issue-13-drift-triage/) |
| 260528-rgw | Release gate polls for ci-gate before Hex publish | 2026-05-28 | 3934bef | [260528-release-gate-ci-wait](./quick/260528-release-gate-ci-wait/) |
| 260527-tkc | Wedge A doc defect hotfixes (payments fence, portal truth, JTBD gaps) | 2026-05-28 | e24e9a3 | [260527-tkc-doc-defect-hotfixes-wedge-a-payments-md-](./quick/260527-tkc-doc-defect-hotfixes-wedge-a-payments-md/) |
| 260527-tm1 | Wedge B disputes/files evidence narrative in recipes.md | 2026-05-28 | b5a78dc | [260527-tm1-wedge-b-disputes-files-evidence-narrativ](./quick/260527-tm1-wedge-b-disputes-files-evidence-narrativ/) |
| 260527-tp8 | Gap 2 Product/Price catalog + mandate/SetupAttempt narratives | 2026-05-28 | 4c636f4 | [260527-tp8-gap-2-narrative-product-price-catalog-st](./quick/260527-tp8-gap-2-narrative-product-price-catalog-st/) |
| 260527-tqf | PLAN-01 backfill 54-VERIFICATION.md | 2026-05-28 | 69c0134 | [260527-tqf-plan-01-backfill-54-verification-md-from](./quick/260527-tqf-plan-01-backfill-54-verification-md-from/) |
| 260729-h47 | Fix 9 ExDoc reference warnings; CI quality lane now runs docs --warnings-as-errors | 2026-07-29 | 90298e8 | [260729-h47-fix-exdoc-warnings](./quick/260729-h47-fix-exdoc-warnings/) |
| 260729-h48 | Ship the phase-62 1.1→1.7 upgrading guide found orphaned during git cleanup | 2026-07-29 | 3b475c2 | [260729-h48-ship-upgrading-guide](./quick/260729-h48-ship-upgrading-guide/) |
| Phase 61 P01 | 5min | 2 tasks | 7 files |
| Phase 61 P02 | 10m | 2 tasks | 3 files |

## Session Continuity

**Last session:** 2026-08-25T18:13:49.455Z
**Stopped at:** Completed 67-05-PLAN.md
**Resume file:** None

Seed: `.planning/seeds/SEED-005-stripe-native-entitlements.md`
Gap brief: `.planning/research/accrue-gap-brief-2026-07-27.txt`
Assessment thread: `.planning/threads/v1-10-next-milestone-assessment.md`
Deferred DX: `.planning/seeds/SEED-006-accrue-dx-ergonomics.md`

## Operator Next Steps

**Default:** Phase 64 is planned (10 plans, 6 waves, checker PASSED). Execute it. Phase 63 is verified and closed (63/63 UAT, 2026-07-28).

| Trigger | Action |
|---------|--------|
| Ready to execute Phase 64 | `/gsd-execute-phase 64` — wave 1 opens with a **blocking `checkpoint:decision`** (D-01 module naming, the phase's only one-way door). Start stripe-mock before wave 4: `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` |
| Phase 63 verification | Done 2026-07-28 — `63-UAT.md` records 63/63 (56 auto-covered, 7 human-approved); `63-VERIFICATION.md` status `passed`. Accepted risk A1: multi-page pagination proven at the Mox layer only (stripe-mock ignores the cursor; no live key here) |
| Phase 64 gate reminder | Do **not** use `mix ci` as Phase 64's gate — it is RED at clean HEAD. Use D-29's five-step differential gate in `64-VALIDATION.md` |
| `mix ci` still red | Expected, and not Phase 63's doing. Steps 1–4 pass; `docs --warnings-as-errors` trips on 42 pre-existing warnings (Tax.* / TaxId.* nested types, `File.create/3`, `../README.md`, `../notebooks/stripe_explorer.livemd`, hidden `ObjectTypes` / `BillingPortal.Guards` / `Webhook.check_tolerance`). Zero name an entitlements file. Clearing them is Phase 67-shaped |
| Bug / wrong Stripe behavior | `/gsd-quick` or `/gsd-debug` → fix + test |

**Do not:** broad resource-family breadth; new metering writes; a per-request `entitled?` gate helper; break SEED-005 §6 stability contracts.
