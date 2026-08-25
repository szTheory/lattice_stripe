# Phase 63: Stripe-Native Entitlements - Context

**Gathered:** 2026-07-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the **greenfield `LatticeStripe.Entitlements.*` namespace** (verified absent: `grep -ril entitlement lib` → 0 hits) as three public modules plus one canonical guide:

- `LatticeStripe.Entitlements.ActiveEntitlement` — `list/3`, `stream!/3`, `retrieve/3` over `GET /v1/entitlements/active_entitlements` (ENT-01/02/03)
- `LatticeStripe.Entitlements.Feature` — create/retrieve/update/list (+ `stream!/3`) over `/v1/entitlements/features` (ENT-04)
- `LatticeStripe.Entitlements.ActiveEntitlementSummary` — typed deserialization of the webhook-only summary object that has **no top-level `id`** (ENT-05)
- `guides/entitlements.md` — canonical guide, spine-only, with pre-cut stubs for Phases 65/66

**This phase delivers the pull/pagination shape. It does not deliver a gate.** The reconciler is the job; the auth path is not.

**Out of scope (fenced):** any per-request `entitled?/2` helper; `Product.Feature` attachment (Phase 66); `ObjectTypes` registration + public `Testing.Fixtures` (Phase 65); meter reads (Phase 64); the 32-module `groups_for_modules` backlog (route to Phase 67).

</domain>

<decisions>
## Implementation Decisions

All four gray areas were researched by dedicated subagents (codebase evidence + live Stripe API/OpenAPI verification + cross-ecosystem lessons + `prompts/` commissioned research), then reconciled. **Three reconciliations diverge from an individual researcher's recommendation and are marked ⚠ — the divergence rationale is load-bearing and must not be silently "corrected" back during planning.**

### Verified facts that reframe the phase

These were confirmed against live Stripe docs, Stripe's `spec3.sdk.json` OpenAPI spec, and a locally-run `stripe/stripe-mock:latest` (v0.199.0). They are **evidence, not assumption** — but re-verify before implementing, per this project's own "verify shipped surface against `lib/` source" decision.

- **F-01 — ENT-05's premise as written is false.** Nothing in the SDK drops id-less objects. `Client.build_decoded_response/6` and `ObjectTypes.maybe_deserialize/1` key only off the wire `"object"` string; `List.first_item_id/1`/`last_item_id/1` already return `nil` gracefully. **"Make deserialization id-tolerant" is a no-op task.** ENT-05's real content is *ship the typed module*; the actual drop-to-raw-map risk is an unregistered `"object"` key, which is Phase 65's registry row.
- **F-02 — the summary has no `id` even as an optional property.** Spec `required: ["customer", "entitlements", "livemode", "object"]`. The struct must have **no `:id` field at all**.
- **F-03 — the summary is webhook-only.** Exactly four entitlement paths exist in the spec; none serves a summary. `active_entitlement_summary` is unreachable via HTTP by construction. Not a gap to apologize for.
- **F-04 — `customer` is REQUIRED on `GET /v1/entitlements/active_entitlements`,** and `limit` defaults to **10** (max 100).
- **F-05 — the inlined summary `url` is not the canonical list path.** Stripe's webhook payload carries `"url": "/v1/customer/{cus_id}/entitlements"` (singular `customer`, path-scoped) while the documented list endpoint is `/v1/entitlements/active_entitlements`. Stripe's own docs *instruct* using the inlined url, so it is probably an undocumented alias — **its callability is NOT established.** Recorded honestly: we route around it because the canonical path is documented and provably correct, not because the alias is proven broken.
- **F-06 — there is no DELETE for features.** Spec: `/v1/entitlements/features` = `[get, post]`, `/{id}` = `[get, post]`. ENT-04's create/retrieve/update/list is the *complete* surface; nothing is deferred.
- **F-07 — `active` (object field) vs `archived` (list filter) is a two-words-one-concept split, and `list/3` silently omits archived features by default.** A drift-detection reconciler that doesn't pass `%{"archived" => true}` will report archived features as **deleted**. Invisible from any function signature.
- **F-08 — stripe-mock v0.199.0 serves all six verbs this phase ships** (verified by running it and curling each). But it returns **one synthetic item per list and ignores `limit`/`starting_after`** — so it **cannot** prove pagination.
- **F-09 — `stream!` types via resource-level `Stream.map(&from_map/1)`, not `ObjectTypes` dispatch** (`charge.ex:341`). **Phase 63 has no code dependency on Phase 65.**
- **F-10 — this silent-truncation bug class is industry-wide.** Shipped in stripe-node #630, stripe-php #1422, stripe-java #451, and — as literally accrue's bug — stripe/sync-engine-fork #118 and supabase/stripe-sync-engine #280.

### Summary shape & truncation follow-through (ENT-05, and the phase's load-bearing ergonomics)

- **D-01 — Phase 63 ships the full `ActiveEntitlementSummary` module; Phase 65 keeps only the `object_types.ex` registry row + public fixtures.** This matches the declared dependency direction (65 depends on 63), makes SC#5 provable by a direct `from_map/1` unit test, and keeps entitlement *domain* knowledge in the phase where it's reviewed alongside `ActiveEntitlement`. Per F-01, the alternative ("63 only makes it id-tolerant") would ship a no-op and fail its own success criterion.
- **D-02 — the summary's `entitlements` field is a typed `%LatticeStripe.List{}` whose `data` is `[%ActiveEntitlement{}]`.** Follows the dominant in-repo precedent (Tax.Calculation, Tax.Transaction, Quote, Quote.Computed, CreditNote all type nested list data; only `Invoice.lines` leaves it raw). Raw `[map()]` is rejected outright: it has the **worst reversibility** (`[map()]` → `%List{}` is breaking for anyone pattern-matching) and would repeat the exact `Product.features` mistake that Phase 66 exists to undo. — **Reversibility:** costly — the field's `%List{}`-ness is a published semver contract once v1.10 tags; its internal `_params`/`_opts`/`_last_id` values are documented non-contract (`list.ex:81-82`) and stay free.
- **D-03 ⚠ — the blessed reconciler path is a FULL CANONICAL RE-FETCH keyed on `summary.customer`, not a cursor-resume from the inline page.** `ActiveEntitlementSummary.stream_entitlements!(client, summary, opts \\ [])` delegates to `ActiveEntitlement.stream!(client, %{"customer" => summary.customer, "limit" => "100"}, opts)` and ignores the inline page entirely.

  **⚠ Divergence + rationale (do not revert):** the summary-shape researcher recommended resuming from the inline page via `starting_after=<last inline id>` against a rewritten canonical url. Rejected — that produces a **hybrid snapshot**: head-of-list from a webhook fired at T₀, tail from a fresh query at T₁, stitched by a cursor whose ordering assumption spans both. Accrue's stated goal is to move its reducer *from* monotonic-snapshot *to* refetch-canonical; a hybrid is a third thing that is harder to reason about than either. Full re-fetch is one call, one point-in-time, and strictly simpler to explain. The ergonomics are identical (`|> Enum.to_list()`); only the correctness story improves.
- **D-04 — populate the nested list's cursor state correctly anyway, as defensive insurance.** Set `url` to the canonical `/v1/entitlements/active_entitlements` (F-05), `_params: %{"customer" => customer}`, and derive `_last_id` **from the raw maps before typing**. Rationale: without this, `List.stream(summary.entitlements, client)` — which any consumer may reach for — either silently stops at 10 or (with `_last_id: nil` and `has_more: true`) re-requests page 1 forever. ~5 lines to make *both* paths correct instead of one correct and one quietly wrong.
- **D-05 — ORDER IS LOAD-BEARING and must be locked by a test.** `List.from_json/3` derives `_last_id` by matching `%{"id" => id}` on raw string-keyed maps (`list.ex:283-295`). It must see **raw** maps; type `data` only after. The in-repo idiom `%{List.from_json(list, ...) | data: Enum.map(data, &ActiveEntitlement.from_map/1)}` gets this right *by call order alone* — a future refactor that reorders it reintroduces silent truncation with **zero test failures** unless explicitly asserted. Ship an assertion on `_last_id` being non-nil.
- **D-06 — `ActiveEntitlement` owns the canonical path as a single module attribute** (`@list_path "/v1/entitlements/active_entitlements"`), shared by `list/3`, `stream!/3`, and the summary's url rewrite, so they physically cannot diverge.
- **D-07 — add an idempotency clause `def from_map(%__MODULE__{} = e), do: e`** so a stream whose head is already typed and whose tail is raw cannot produce a heterogeneous result.

### `Entitlements.Feature` verb surface (ENT-04)

- **D-08 ⚠ — `update/4` only. NO `archive/3`, NO `unarchive/3`.**

  **⚠ This overturns the framing in the gray-area presentation,** which suggested archiving might earn an explicit verb under the project's "explicit verbs over magical updates" decision. The evidence says the doctrine is narrower than that, and it is stated verbatim in `Subscription.pause_collection/5`'s own `@doc`: *"Stripe has no dedicated pause endpoint — this helper is a thin wrapper around `update/4`. We expose it under the exact field name (`pause_collection`) rather than a generic `pause/4` so IDE autocomplete and Stripe docs align."* So the rule is **explicit verbs mirror explicit Stripe endpoints; when wrapping `update`, name the function after the exact wire field.** `Billing.Meter.deactivate/3` exists because Stripe shipped `/deactivate`. Stripe shipped no archive endpoint (F-06). Field-name-faithful would force `set_active/4`, which nobody wants — that is the tell.

  Three independent lines converge: (1) the doctrine above; (2) **`Price` and `Product` have the identical `active: false` archive mechanic and neither ships an archive verb** — adding one for `Feature` makes three sibling resources incoherent; (3) all five official Stripe SDKs expose exactly create/retrieve/update/list. Semver seals it: adding `archive/3` later is a minor bump; removing a wrong `unarchive/3` — for behavior stripe-ruby's own docstring calls *"permanently deactivate"* — is a major one. — **Reversibility:** reversible — adding the verb later costs a minor bump; this decision deliberately buys optionality rather than spending it.
- **D-09 — the F-07 landmines are moduledoc-mandatory.** The `## Archiving` section must state (a) the `active` field vs `archived` filter vocabulary split, and (b) that `list/3` omits archived features by default, so a reconciler diffing against a local catalog must pass `%{"archived" => true}` or report false deletions. This teaches more than a verb would, because neither fact is visible from a function name.
- **D-10 — guard required params pre-network with `Resource.require_param!/3`.** `Feature.create/3` guards `name` and `lookup_key`. **Extend the same guard to `ActiveEntitlement.list/3` and `stream!/3` for `customer`** — required per F-04, and it makes the cross-tenant leak guard (D-22) meaningful. Message format copied verbatim from `Billing.Meter.create/3`: `"LatticeStripe.<Module>.<fun>/<arity> requires a <key> param"`. Note in `@doc` that the guard checks presence, not emptiness.
- **D-11 — keep `when is_binary(id)`; do NOT add `id in [nil, ""]` ArgumentError clauses.** That pattern appears in only **5 of 55** top-level modules — a minority, not a convention. Adopting it in a flagship new module would make it look like the house rule it isn't.
- **D-12 — `lookup_key`: moduledoc recipe, no helper function.** Exact internal precedent: `Price` carries `lookup_key` as a struct field and documents it as a `list/3` filter with zero helpers. A `retrieve_by_lookup_key/3` would invent a verb with no Stripe endpoint and invent 0-result/>1-result semantics Stripe doesn't define. Document three things: the `%{"lookup_key" => ...}` filter, that it returns a **list not a singleton**, and that **`lookup_key` is immutable after create** (Stripe silently ignores it on update) — that third point is the actual unlock, because it's what makes it safe to key host config on.
- **D-13 — `Feature` gets `stream!/3`.** Beyond ENT-04's literal text, but least-surprise rather than scope creep: it would otherwise be the only list-bearing module in 60+ without it, and shipping the two entitlements modules with *different* pagination affordances is the one genuinely surprising outcome available. The drift-detection JTBD (accrue's catalog is 100% duplicated host config) needs full enumeration, and `limit` defaults to 10.
- **D-14 — final surface:** `create/3`, `create!/3`, `retrieve/3`, `retrieve!/3`, `update/4`, `update!/4`, `list/3`, `list!/3`, `stream!/3`, `from_map/1`. `create/3` takes `params` **without** a `\\ %{}` default (matching `Billing.Meter.create/3`) — a defaulted empty map could only ever raise. **No custom `Inspect` impl** — `charge.ex` has one solely to redact PII; a Feature holds none (`name` is explicitly not customer-displayable). Derive the default.
- **D-15 — lock the `Entitlements.Feature` vs `Product.Feature` distinction in both moduledocs now,** reusing the shape of `Tax.Transaction`'s existing *"Relationship to other tax surfaces"* section. `Entitlements.Feature` is the **definition** (`entitlements.feature`, `feat_…`); `Product.Feature` is the **attachment** (`product_feature`, `prodft_…`) and carries the full definition under its `entitlement_feature` field. `ActiveEntitlement.feature` must decode to `Feature.t() | String.t() | nil` via the standard expandable idiom (`charge.ex:514-518`), which is why `Feature` must land in the same wave as `ActiveEntitlement`, not after it.

### Namespace, ExDoc placement, and the guide

- **D-16 — `lib/lattice_stripe/entitlements/{active_entitlement,feature,active_entitlement_summary}.ex` with NO parent `entitlements.ex`.** The repo's rule is derivable, not arbitrary: a parent `.ex` exists **iff the parent is itself a real Stripe resource or a module with functions**. Dirs with no parent: `billing/`, `billing_portal/`, `checkout/`, `tax/`, `builders/`, `test_helpers/`. There is no `/v1/entitlements` endpoint, so a parent module would be a doc-only fiction and a permanently undeletable public symbol. Keep the redundant-looking `Entitlements.ActiveEntitlement` — "active entitlement" is Stripe's term of art and every official SDK does it; shortening breaks the wire↔module mental map Phase 65 depends on. — **Reversibility:** one-way — module names are the semver contract once v1.10 tags; renaming post-release is a breaking change. This is the phase's only one-way door.
- **D-17 — new `Entitlements:` group in `mix.exs` `groups_for_modules`, inserted between `"Billing Metering"` and `Connect:`.** `"Billing Metering"` already establishes the motif that a Billing sub-product earns a sibling group rather than a fold-in. Folding into `"Billing"` (already **22 modules**) is precisely the failure mode Phase 62's D-04 named and rejected. Phase 66 appends `Product.Feature` to this same group with a one-line diff — **`Product.Feature` belongs in `Entitlements`, not `Billing`**, so the two halves of one concept sit adjacent in the sidebar; that is the highest-value discoverability win in the milestone and it defuses the exact "two things called Feature" confusion. Zero restructure across 63/64/66. — **Reversibility:** reversible — sidebar only, one commit.
- **D-18 — ship `guides/entitlements.md` in Phase 63, spine-only (~200-260 lines), with three pre-cut stub sections** (Webhooks → filled by Phase 65; Testing → filled by Phase 65; Attaching features to products → filled by Phase 66). This dissolves the write-thrice objection: the skeleton *reserves* the space, so later phases append rather than rewrite. Precedent is direct — v1.6 shipped `guides/tax.md` in the same milestone as the Tax modules, and `metering.md` demonstrably grew by appending. Filename flat kebab-case (`entitlements.md`), title `# Entitlements`. Registered in **both** `extras:` and `groups_for_extras: "Canonical Guides"` (a file in a group but absent from `extras:` is silently dropped), placed between `customer-portal.md` and `metering.md` — the reader's chain is *what they bought → how they self-manage → **what they can access** → what they consumed → what they owe*. **No new `groups_for_extras` group** and **no 5th Flagship Recipe** — neither affordance is earned by a single-family guide.
- **D-19 — the "no `entitled?` — gate locally, fail closed" rationale ships in ALL THREE surfaces,** because the three reader entry points are different and one location will not hold:
  1. **`ActiveEntitlement` `@moduledoc`** — a warning admonition. This is where a contributor who greps `entitled?` or Hex-searches "entitled" actually *lands*; it is the highest-probability interception point for the "let me just add the helper" PR.
  2. **`guides/entitlements.md` → `## Scope boundary`** — the full argument **plus the working replacement** (reconciler → local store → gate locally → fail closed on staleness). Refusal-without-alternative is what gets "fixed."
  3. **`guides/scope.md`** — 2-3 lines. This is the canonical "what this library deliberately does NOT do" page and is *already* docs-truth-locked; a decision that isn't here is not locked project-wide. — **Reversibility:** one-way by intent — the permanence is the point.

### Proof depth

- **D-20 — full triangulation: Mox + stripe-mock integration + docs-truth. No capability probe, no `@tag :skip`.** F-08 settles it empirically — all six verbs work against stripe-mock today, so there is no capability question, and a probe's failure mode is a *silent skip*, i.e. the fake-green this project has explicitly recorded values against. Follow `charge_integration_test.exs:19-27` literally: `setup_all` opens a TCP connection to `localhost:12111` and **raises with the docker command** if absent.
- **D-21 — `stream!` (ENT-02) is proven in Mox, in its own file, with 8 named assertions.** stripe-mock cannot prove pagination (F-08); the Mox-at-Transport multi-page pattern in `test/lattice_stripe/list_test.exs:384-449` is the only place pagination is genuinely proven in this repo, and it is the direct analogue of how stripe-node/ruby/python/go test auto-pagination (hand-authored multi-page fixtures, not against stripe-mock). Assertions: (1) page-2 `starting_after` = last id of page 1; (2) **`customer=` still present on page 2**; (3) exactly N transport calls for N pages (`verify_on_exit!`); (4) items from all pages emitted in order as typed structs; (5) `Stream.take(1)` on a 2-page stream makes exactly 1 call; (6) `stripe-account` header carries to page 2; (7) **no `idempotency-key` on page 2** (the explicit strip at `list.ex:267`); (8) `assert_raise LatticeStripe.Error` when page 2 returns 500.
- **D-22 — assertion (2) is the single highest-value test in the phase.** If `base_params` preservation (`list.ex:246`) regresses, the reconciler silently streams **the entire account's entitlements instead of one customer's** — a cross-tenant data leak. It is entitlements-specific and not covered by the existing `list_test.exs`. Name the test `"page 2 preserves the customer filter"`, not something generic.
- **D-23 — locks: prefer structural over grep.** The repo has a well-established absent-verb idiom: `refute function_exported?` appears in **19 test files** (verified — `tax_id_test.exs:29-32`, `balance_test.exs:139-143`, `transfer_test.exs:204-208`, `testing_test.exs:256-260`, `charge_test.exs`, `price_test.exs`, `product_test.exs`, `coupon_test.exs`, `payout_test.exs`, `tax/settings_test.exs`, and 9 more). This is a house convention, not a niche trick. A grep for `"entitled?"` is defeatable by renaming; `refute function_exported?` is defeated only by actually adding the function — which is the thing being forbidden. **With typespecs documentation-only and no Dialyzer, `refute function_exported?` is the only enforcement of surface shape in this project**, which raises these from nice-to-have to mandatory.
  - **L1** — `refute function_exported?(ActiveEntitlement, :entitled?, 2/3/4)`, plus `refute :create/:update/:delete` (read-only resource).
  - **L2** — `assert function_exported?` for Feature's four verbs + `refute function_exported?(Feature, :delete, 2/3)` (F-06: no DELETE exists; lock the *complete* surface against a future 404-producing `delete/3`).
  - **L3** — docs-truth grep on the *prose* fence: moduledoc `=~ "gate"`, `=~ "fail closed"`, `=~ "stream!/3"`; summary moduledoc `=~ "no top-level"`. L1 locks the code; L3 locks the explanation.
- **D-24 ⚠ — the moduledoc MUST mention `entitled?` by name; do NOT add `refute source =~ "entitled?"`.**

  **⚠ Reconciles a direct contradiction between two researchers.** The namespace researcher wants `assert moduledoc =~ "entitled?"` so a contributor grepping the string lands on the explanation (D-19.1). The proof researcher proposed `refute source =~ "entitled?"` to prove absence. The refute would **forbid the very documentation the fence depends on**. Resolution: absence is proven structurally by L1 (`refute function_exported?`); the *string* must be present in prose for discoverability. Assert presence, never refute it.
- **D-25 — do NOT lock generic pagination prose** ("auto-follows `has_more`"). The D-21 stream test is the real structural proof; a grep for that sentence is noise and erodes the mechanism. Three locks, no more.
- **D-26 — ENT-05 is proven as a pure `from_map/1` unit test, no transport** (F-03 — there is no endpoint). Assert: returns `%ActiveEntitlementSummary{}` not raw map/nil; `customer`/`livemode`/`object` populate; **`refute Map.has_key?(struct, :id)`** (encodes the design decision per F-02, not just current behavior); nested `data` → `[%ActiveEntitlement{}]` with `has_more` preserved. Plus one negative: `data: []` with `has_more: true` still deserializes — empty-but-truncated is a real Stripe state and the exact "paid but no feature" shape.
- **D-27 — fixtures: private now, promote-by-move in Phase 65.** `test/support/fixtures/entitlements.ex` (`@moduledoc false`), functions named exactly as Phase 65 will need them: `active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2`. Header comment: `# PROMOTION TARGET (Phase 65 / OBJ-02): git mv to lib/lattice_stripe/testing/fixtures/entitlements.ex verbatim. Do not re-author.` **And append one line to Phase 65's Build constraints in `.planning/ROADMAP.md`** — the comment alone will not survive; the ROADMAP edit is the real deliverable.
- **D-28 — extend `TestHelpers.list_json/2` to `list_json(items, url, has_more \\ false)`.** It currently hardcodes `has_more: false`, which makes multi-page tests impossible. Backward compatible; every future streaming resource benefits.
- **D-29 — the docs gate is DIFFERENTIAL.** `mix docs --warnings-as-errors` is still **RED at 43 warnings** (re-verified); enforced CI is plain `mix docs` (`ci.yml:254`). Unlike Phase 62, this phase **touches `lib/`**, so sloppy autolinks would *add* to the pile. Gate: (1) plain `mix docs` exits 0; (2) zero *new* warnings vs clean-HEAD baseline **and** zero warnings matching `entitlements`; (3) `docs_truth_test.exs` green; (4) `credo --strict` green. Use ExDoc autolinks and relative `.md#anchor` links — never hardcoded hexdocs URLs.

### Claude's Discretion

Exact prose, moduledoc wording, guide section copy, snippet selection, and test naming are Claude's discretion within the D-01…D-29 frame. Two standing instructions: **re-verify F-01 through F-10 against source and live Stripe docs before implementing** (this project's own recorded decision is that planning artifacts can be coherent and still miss code truth — the v1.5 `tolerance: 0` bug was found by source verification, not by a green suite); and where a researcher's claim and this document disagree, **this document wins** — the ⚠ divergences (D-03, D-08, D-24) were reconciled deliberately.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase source & requirements
- `.planning/ROADMAP.md` §"Phase 63" — goal, 5 success criteria, build constraints (charge.ex template; `List.stream!`; no gate helper; ExDoc registration mandatory).
- `.planning/REQUIREMENTS.md` — ENT-01..ENT-05, and the "Out of Scope" row explaining *why* the gate helper is refused.
- `.planning/seeds/SEED-005-stripe-native-entitlements.md` §1.1 (the ask + accrue's four scars), §1.2 (Product↔Feature, Phase 66), §6 (FROZEN stability contracts).
- `.planning/research/accrue-gap-brief-2026-07-27.txt` — the verified gap brief behind the whole milestone.

### The template to follow
- `lib/lattice_stripe/charge.ex` — the full-resource template. `@known_fields` (L104), `defstruct [..., object:, extra: %{}]` (L116), expandable-field idiom (L514-518), `stream!/3` (L338-342), `from_map/1` (L499-576), custom `Inspect` (L588+, PII-only — **not** needed here per D-14).
- `lib/lattice_stripe/list.ex` — **read in full.** `from_json/3` cursor derivation (L283-295, the D-05 ordering hazard), `stream!/2` (L154), `stream/2` (L180), `build_next_page_request/1` (L245-275, incl. `base_params` preservation at L246 and the `idempotency_key` strip at L267), and the deliberate non-`Enumerable` stance (L20-24).
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3` (L117).
- `lib/lattice_stripe/billing/meter.ex` — closest sibling for `create/3` required-param guards and message format; also the `deactivate/3` endpoint-mirroring precedent (D-08).
- `lib/lattice_stripe/tax/calculation.ex` (L193) + `lib/lattice_stripe/tax/transaction.ex` (L219) — the typed-nested-`%List{}` idiom and the "Relationship to other surfaces" moduledoc section (D-15).
- `lib/lattice_stripe/price.ex` (L171) — the `lookup_key`-as-list-filter precedent (D-12) and the archive-without-a-verb precedent (D-08).
- `lib/lattice_stripe/product.ex` — second archive-without-a-verb precedent; also the raw `[map()]` `features` field (L67/100/408) Phase 66 exists to fix.
- `lib/lattice_stripe/subscription.ex` — `pause_collection/5` and its `@doc`, which states the house verb doctrine verbatim (D-08).
- `lib/lattice_stripe/object_types.ex` — the registry Phase 65 adds to; `maybe_deserialize/1` (L69-80).

### Registration & docs
- `mix.exs` — the `docs/0` block: `extras:` (L23), `groups_for_extras:` (L60), `groups_for_modules:` (L109). Both guide registrations and the new `Entitlements:` group land here.
- `guides/tax.md` — the closest precedent: a canonical guide shipped with a new resource family. Mirror its `## Scope boundary` structure (D-19.2).
- `guides/scope.md` — the canonical deferred-scope contract; already docs-truth-locked. The permanent fence home (D-19.3).
- `guides/metering.md`, `guides/subscriptions.md`, `guides/customer-portal.md` — sidebar neighbours and cross-link targets.
- `guides/api_stability.md` — what the semver contract commits to (relevant to D-08 and D-16).

### Test surfaces
- `test/lattice_stripe/list_test.exs` L384-449, L451-511, L626-696 — the Mox-at-Transport multi-page pattern D-21 must mirror.
- `test/integration/charge_integration_test.exs` L19-27 — the `setup_all` raise-if-mock-absent pattern (D-20).
- `test/lattice_stripe/docs_truth_test.exs` — the lock mechanism; L447-520 is the tax-guide lock template to clone; L341 is the `scope.md` lock to extend.
- `test/lattice_stripe/tax_id_test.exs` L29-32 (+ `balance_test.exs` L139-143, `transfer_test.exs` L204-208, `testing_test.exs` L256-260) — the `refute function_exported?` absent-verb idiom (D-23).
- `test/support/test_helpers.ex` — `list_json/2`, to be extended per D-28.
- `.github/workflows/ci.yml` L185-217 (docs_truth job), L254 (plain `mix docs`), L265 (required gates incl. `integration`).

### Prior-phase context
- `.planning/phases/62-1-1-1-7-what-landed-migration-guide/62-CONTEXT.md` — D-04 there resolved ExDoc placement/filename reasoning and the differential-docs-gate posture; D-17/D-18/D-29 stay coherent with it.
- `.planning/phases/61-default-finch-pool-optional-application/61-CONTEXT.md` — the default Finch pool now means examples need no `finch:` argument.

### Commissioned research (`prompts/`)
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — HexDocs `extras`/`groups_for_*` conventions (~L359-378).
- `prompts/elixir-best-practices-deep-research.md` — idiomatic surface + testing.
- `prompts/stripe-explanation-domain-language-deep-research.md` — domain nouns/verbs for naming and moduledoc voice.
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — JTBD framing for the guide spine.
- `prompts/stripe-sdk-api-surface-area-deep-research.md`, `prompts/payments_domain_field_guide.md`.

### External (verified during discussion)
- Stripe: [List all active entitlements](https://docs.stripe.com/api/entitlements/active-entitlement/list) — F-04 (`customer` required, `limit` default 10).
- Stripe: [Entitlements](https://docs.stripe.com/billing/entitlements) — F-05 (the inlined `entitlements.url`), ≤10 inline + `has_more`.
- Prior art on this exact bug class (F-10): [stripe/sync-engine-fork#118](https://github.com/stripe/sync-engine-fork/issues/118), [supabase/stripe-sync-engine#280](https://github.com/supabase/stripe-sync-engine/issues/280), [stripe-node#630](https://github.com/stripe/stripe-node/issues/630), [stripe-php#1422](https://github.com/stripe/stripe-php/issues/1422), [stripe-java#451](https://github.com/stripe/stripe-java/issues/451).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LatticeStripe.List.stream!/2` and `stream/2`** — the entire pagination mechanism already exists. This phase supplies state it was designed to consume; it must **not** grow a new pagination mechanism (recorded project decision: "Reuse existing dispatch tables for new resource families instead of growing new ones").
- **`Resource.unwrap_singular/unwrap_list/unwrap_bang!/require_param!`** — all four are used verbatim.
- **The typed-nested-`%List{}` idiom** — `%{List.from_json(list, params, opts) | data: Enum.map(data, &Mod.from_map/1)}`, proven in 5 modules.
- **`Mix.Tasks.LatticeStripe.CheckDrift`** — enrolls anything in `ObjectTypes.object_map()` and diffs `@known_fields` against Stripe's OpenAPI spec. A typed module with `@known_fields` gets **free spec-drift surveillance** once Phase 65 registers it; raw `[map()]` gets none. An argument for D-02 the roadmap does not state.
- **`refute function_exported?` absent-verb locks** — 19 existing precedent files (verified). With no Dialyzer and typespecs documentation-only, this is the *only* enforcement of public surface shape in the project.

### Established Patterns
- **Verb doctrine:** explicit verbs mirror explicit Stripe endpoints; wrappers over `update` take the exact wire field name (D-08).
- **Namespace rule:** a parent `.ex` exists iff the parent is a real Stripe resource or has functions (D-16).
- **Bang twins** for every non-bang function via `Resource.unwrap_bang!/1`; `stream!` has no non-bang twin.
- **Typing happens at the resource layer** (`Stream.map(&from_map/1)`), not via `ObjectTypes` — hence F-09, no Phase 65 dependency.
- **Custom `Inspect` only to redact PII** — not a default.
- **docs-truth is `File.read!` + `=~` over guides *and source files*,** run as its own required CI job.

### Integration Points
- `mix.exs` `docs/0` — one new `groups_for_modules` group + two guide registrations.
- `lib/lattice_stripe/object_types.ex` — **Phase 65 only.** Phase 63 must not touch it.
- `test/support/test_helpers.ex` — `list_json/3` extension (D-28).
- `.planning/ROADMAP.md` — Phase 65 build-constraint line for promote-by-move (D-27); optionally record Phase 66's hard code dependency on Phase 63 (below).

### Roadmap gap found during discussion
`Product.Feature.from_map/1` (Phase 66) must call `Entitlements.Feature.from_map/1` to decode its `entitlement_feature` field. That is a **hard code dependency from Phase 66 back to Phase 63**, stronger than ROADMAP.md's current loose phrasing ("entitlement `Feature` objects are what product features reference"). Worth tightening when Phase 66 is planned.

</code_context>

<specifics>
## Specific Ideas

- The reconciler snippet is the guide's headline example and should read exactly this cleanly — one call, no `has_more` branch, consumer never learns Stripe inlines ten:
  ```elixir
  summary = ObjectTypes.maybe_deserialize(event.data["object"])

  entitlements =
    client
    |> Entitlements.ActiveEntitlementSummary.stream_entitlements!(summary)
    |> Enum.to_list()

  MyApp.Billing.reconcile(summary.customer, entitlements)
  ```
- The success measure for this phase is external and concrete: **accrue can delete its `truncated` DB column and its `[:accrue, :ops, :entitlement_summary_truncated]` telemetry event, and move its entitlement reducer from monotonic-snapshot to refetch-canonical.** If the shipped surface doesn't let it do that, the phase missed.
- Guide section order (the reader's chain): Scope boundary → Mental model (Feature → Product attachment → purchase → ActiveEntitlement, ASCII diagram in `tax.md` style) → Reading a customer's entitlements (`list/3`, `stream!/3`, `retrieve/3`) → The reconciler pattern → The `active_entitlement_summary` → Managing features (verb **table**, cheap to extend) → `lookup_key` as your system identifier → [stub] Attaching to products → [stub] Testing → [stub] Webhooks → Error handling → See also.
- Use a **verb table** rather than prose in "Managing features" so Phase 66 and any future verb append one row.
- Proposed `ArgumentError` microcopy: `** (ArgumentError) LatticeStripe.Entitlements.Feature.create/3 requires a lookup_key param`.

</specifics>

<deferred>
## Deferred Ideas

- **`groups_for_modules` backlog — 32 ungrouped lib modules** falling into ExDoc's default bucket, including the entire `Tax.*` family (14 modules), `Product`, `Price.*`, `Coupon.*`, `PromotionCode`, `File`, `FileLink`, `ObjectTypes`, `Drift`, `Webhook.CacheBodyReader`, `TestHelpers.TestClock`. v1.6 shipped a 350-line `tax.md` but skipped module grouping entirely. → **Phase 67 (Milestone Doc Close)**, as two added tuples (`Tax:` and `Catalog:`). Explicitly NOT Phase 63 — scope fence. D-17 is deliberately independent of this landing.
- **Promoting `guides/entitlements.md` to a 5th Flagship Recipe** — the flagship set is 4 curated multi-resource journeys; a single-family guide dilutes it. Revisit only on adopter pull.
- **`Oban`-style `guides/upgrading/` subdirectory** — carried forward unresolved from Phase 62; still not triggered.
- **Fixing `mix docs --warnings-as-errors` (43 warnings)** — pre-existing, not this phase's debt. D-29's differential gate is the interim posture.
- **`retrieve_by_lookup_key/3` on `Feature`** — rejected in D-12, but recorded: if adopter pull shows the 3-line `list/3` recipe is a real friction point, it is an additive minor-bump addition later.

</deferred>

---

*Phase: 63-stripe-native-entitlements*
*Context gathered: 2026-07-28*
