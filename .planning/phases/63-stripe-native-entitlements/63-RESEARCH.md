# Phase 63: Stripe-Native Entitlements - Research

**Researched:** 2026-07-28
**Domain:** Stripe Entitlements API surface + in-repo Elixir resource-module conventions
**Confidence:** HIGH

## Summary

This phase is unusually well-specified. `63-CONTEXT.md` already contains 29 locked decisions (D-01…D-29) and 10 asserted facts (F-01…F-10). CONTEXT's own standing instruction was to **re-verify F-01 through F-10 against source and live Stripe docs before implementing**. That verification is the primary work product of this research, and it is now complete: **all ten facts hold.** F-02, F-03, F-04, F-05, F-06, F-07, and F-08 were confirmed against Stripe's authoritative OpenAPI spec (`stripe/openapi` `spec3.sdk.json`, spec version `2026-06-24.dahlia`) and against a locally-run `stripe/stripe-mock:latest`. F-01 and F-09 were confirmed by reading `lib/lattice_stripe/client.ex`, `object_types.ex`, `list.ex`, and `charge.ex`. The planner should treat CONTEXT.md's decisions as binding and this document as the *evidence file* plus a small set of **corrections** where CONTEXT's incidental details drifted from code truth.

Four corrections matter enough to change plan tasks. (1) The private test-fixture namespace in this repo is `LatticeStripe.Test.Fixtures.*` under `test/support/fixtures/`, while the *public* one is `LatticeStripe.Testing.Fixtures.*` under `lib/lattice_stripe/testing/fixtures/` — so D-27's "git mv … verbatim" is a **move plus a module rename**, and the promotion header comment must say so or Phase 65 will hit a compile error. (2) The `mix docs --warnings-as-errors` baseline is **42** warnings, not 43, and — critically — the `mix ci` alias in `mix.exs` *includes* `docs --warnings-as-errors`, so **`mix ci` is RED at clean HEAD**. No plan task may use `mix ci` as a gate. (3) `entitlements.active_entitlement` carries a **`lookup_key`** field (required in the spec) that CONTEXT never enumerates — the struct is exactly five fields. (4) `product_feature.entitlement_feature` is a direct `$ref`, never a bare id string, which sharpens D-15's Phase-66 note.

The technical risk in this phase is not the API surface (it is tiny and fully mapped) but the **cursor-derivation ordering hazard** at `list.ex:283-295`, which is invisible from any signature and is the exact bug class that shipped in five official Stripe SDKs (F-10). D-05's ordering lock and D-21's eight-assertion Mox stream test are the load-bearing proof; everything else is mechanical template-following.

**Primary recommendation:** Follow CONTEXT.md's D-01…D-29 verbatim. Clone `lib/lattice_stripe/billing/meter.ex` (not `charge.ex`) as the structural template for both new resource modules — Meter is the closest sibling in size, namespace depth, required-param guarding, and `stream!/3` shape; use `charge.ex` only for the expandable-field idiom and `tax/calculation.ex:190-196` for the typed-nested-`%List{}` idiom.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Copied from `.planning/phases/63-stripe-native-entitlements/63-CONTEXT.md` `<decisions>`. **Where a researcher's claim and CONTEXT.md disagree, CONTEXT.md wins.** The three ⚠ items were deliberately reconciled and must not be "corrected" back.

**Verified facts that reframe the phase (F-01…F-10):**

- **F-01** — ENT-05's premise as written is false. Nothing in the SDK drops id-less objects. `Client.build_decoded_response/6` and `ObjectTypes.maybe_deserialize/1` key only off the wire `"object"` string; `List.first_item_id/1`/`last_item_id/1` already return `nil` gracefully. "Make deserialization id-tolerant" is a no-op task. ENT-05's real content is *ship the typed module*; the actual drop-to-raw-map risk is an unregistered `"object"` key, which is Phase 65's registry row.
- **F-02** — the summary has no `id` even as an optional property. Spec `required: ["customer", "entitlements", "livemode", "object"]`. The struct must have **no `:id` field at all**.
- **F-03** — the summary is webhook-only. Exactly four entitlement paths exist in the spec; none serves a summary. `active_entitlement_summary` is unreachable via HTTP by construction. Not a gap to apologize for.
- **F-04** — `customer` is REQUIRED on `GET /v1/entitlements/active_entitlements`, and `limit` defaults to **10** (max 100).
- **F-05** — the inlined summary `url` is not the canonical list path. Stripe's webhook payload carries `"url": "/v1/customer/{cus_id}/entitlements"` (singular `customer`, path-scoped) while the documented list endpoint is `/v1/entitlements/active_entitlements`. Stripe's own docs *instruct* using the inlined url, so it is probably an undocumented alias — its callability is NOT established. We route around it because the canonical path is documented and provably correct, not because the alias is proven broken.
- **F-06** — there is no DELETE for features. Spec: `/v1/entitlements/features` = `[get, post]`, `/{id}` = `[get, post]`. ENT-04's create/retrieve/update/list is the *complete* surface; nothing is deferred.
- **F-07** — `active` (object field) vs `archived` (list filter) is a two-words-one-concept split, and `list/3` silently omits archived features by default. A drift-detection reconciler that doesn't pass `%{"archived" => true}` will report archived features as **deleted**. Invisible from any function signature.
- **F-08** — stripe-mock v0.199.0 serves all six verbs this phase ships. But it returns **one synthetic item per list and ignores `limit`/`starting_after`** — so it **cannot** prove pagination.
- **F-09** — `stream!` types via resource-level `Stream.map(&from_map/1)`, not `ObjectTypes` dispatch (`charge.ex:341`). **Phase 63 has no code dependency on Phase 65.**
- **F-10** — this silent-truncation bug class is industry-wide. Shipped in stripe-node #630, stripe-php #1422, stripe-java #451, and — as literally accrue's bug — stripe/sync-engine-fork #118 and supabase/stripe-sync-engine #280.

**Summary shape & truncation follow-through (ENT-05):**

- **D-01** — Phase 63 ships the full `ActiveEntitlementSummary` module; Phase 65 keeps only the `object_types.ex` registry row + public fixtures.
- **D-02** — the summary's `entitlements` field is a typed `%LatticeStripe.List{}` whose `data` is `[%ActiveEntitlement{}]`. Raw `[map()]` is rejected outright. *Reversibility: costly — the field's `%List{}`-ness is a published semver contract once v1.10 tags; its internal `_params`/`_opts`/`_last_id` values are documented non-contract (`list.ex:81-82`) and stay free.*
- **D-03 ⚠** — the blessed reconciler path is a FULL CANONICAL RE-FETCH keyed on `summary.customer`, not a cursor-resume from the inline page. `ActiveEntitlementSummary.stream_entitlements!(client, summary, opts \\ [])` delegates to `ActiveEntitlement.stream!(client, %{"customer" => summary.customer, "limit" => "100"}, opts)` and ignores the inline page entirely. **⚠ Divergence + rationale (do not revert):** cursor-resume produces a hybrid snapshot (head from T₀ webhook, tail from T₁ query). Full re-fetch is one call, one point-in-time, strictly simpler to explain.
- **D-04** — populate the nested list's cursor state correctly anyway, as defensive insurance. Set `url` to the canonical `/v1/entitlements/active_entitlements` (F-05), `_params: %{"customer" => customer}`, and derive `_last_id` **from the raw maps before typing**.
- **D-05** — ORDER IS LOAD-BEARING and must be locked by a test. `List.from_json/3` derives `_last_id` by matching `%{"id" => id}` on raw string-keyed maps (`list.ex:283-295`). It must see **raw** maps; type `data` only after. Ship an assertion on `_last_id` being non-nil.
- **D-06** — `ActiveEntitlement` owns the canonical path as a single module attribute (`@list_path "/v1/entitlements/active_entitlements"`), shared by `list/3`, `stream!/3`, and the summary's url rewrite.
- **D-07** — add an idempotency clause `def from_map(%__MODULE__{} = e), do: e`.

**`Entitlements.Feature` verb surface (ENT-04):**

- **D-08 ⚠** — `update/4` only. NO `archive/3`, NO `unarchive/3`. **⚠ Overturns the gray-area framing.** The house rule is: explicit verbs mirror explicit Stripe endpoints; when wrapping `update`, name the function after the exact wire field. *Reversibility: reversible — adding the verb later costs a minor bump.*
- **D-09** — the F-07 landmines are moduledoc-mandatory. The `## Archiving` section must state (a) the `active` field vs `archived` filter vocabulary split, and (b) that `list/3` omits archived features by default.
- **D-10** — guard required params pre-network with `Resource.require_param!/3`. `Feature.create/3` guards `name` and `lookup_key`. **Extend the same guard to `ActiveEntitlement.list/3` and `stream!/3` for `customer`.** Message format copied verbatim from `Billing.Meter.create/3`. Note in `@doc` that the guard checks presence, not emptiness.
- **D-11** — keep `when is_binary(id)`; do NOT add `id in [nil, ""]` ArgumentError clauses.
- **D-12** — `lookup_key`: moduledoc recipe, no helper function. Document three things: the `%{"lookup_key" => ...}` filter, that it returns a **list not a singleton**, and that **`lookup_key` is immutable after create**.
- **D-13** — `Feature` gets `stream!/3`.
- **D-14** — final surface: `create/3`, `create!/3`, `retrieve/3`, `retrieve!/3`, `update/4`, `update!/4`, `list/3`, `list!/3`, `stream!/3`, `from_map/1`. `create/3` takes `params` **without** a `\\ %{}` default. **No custom `Inspect` impl.**
- **D-15** — lock the `Entitlements.Feature` vs `Product.Feature` distinction in both moduledocs now, reusing `Tax.Transaction`'s "Relationship to other tax surfaces" shape. `ActiveEntitlement.feature` must decode to `Feature.t() | String.t() | nil` via the standard expandable idiom (`charge.ex:514-518`) — which is why `Feature` must land in the same wave as `ActiveEntitlement`.

**Namespace, ExDoc placement, and the guide:**

- **D-16** — `lib/lattice_stripe/entitlements/{active_entitlement,feature,active_entitlement_summary}.ex` with NO parent `entitlements.ex`. *Reversibility: one-way — module names are the semver contract once v1.10 tags. This is the phase's only one-way door.*
- **D-17** — new `Entitlements:` group in `mix.exs` `groups_for_modules`, inserted between `"Billing Metering"` and `Connect:`. *Reversibility: reversible — sidebar only, one commit.*
- **D-18** — ship `guides/entitlements.md` in Phase 63, spine-only (~200-260 lines), with three pre-cut stub sections (Webhooks → Phase 65; Testing → Phase 65; Attaching features to products → Phase 66). Filename flat kebab-case, title `# Entitlements`. Registered in **both** `extras:` and `groups_for_extras: "Canonical Guides"`, placed between `customer-portal.md` and `metering.md`. **No new `groups_for_extras` group** and **no 5th Flagship Recipe.**
- **D-19** — the "no `entitled?` — gate locally, fail closed" rationale ships in ALL THREE surfaces: (1) `ActiveEntitlement` `@moduledoc` warning admonition; (2) `guides/entitlements.md` → `## Scope boundary` (full argument **plus the working replacement**); (3) `guides/scope.md` (2-3 lines). *Reversibility: one-way by intent — the permanence is the point.*

**Proof depth:**

- **D-20** — full triangulation: Mox + stripe-mock integration + docs-truth. No capability probe, no `@tag :skip`. Follow `charge_integration_test.exs:19-27` literally.
- **D-21** — `stream!` (ENT-02) is proven in Mox, in its own file, with 8 named assertions: (1) page-2 `starting_after` = last id of page 1; (2) **`customer=` still present on page 2**; (3) exactly N transport calls for N pages (`verify_on_exit!`); (4) items from all pages emitted in order as typed structs; (5) `Stream.take(1)` on a 2-page stream makes exactly 1 call; (6) `stripe-account` header carries to page 2; (7) **no `idempotency-key` on page 2**; (8) `assert_raise LatticeStripe.Error` when page 2 returns 500.
- **D-22** — assertion (2) is the single highest-value test in the phase (cross-tenant data leak if `base_params` preservation regresses). Name the test `"page 2 preserves the customer filter"`.
- **D-23** — locks: prefer structural over grep. **L1** `refute function_exported?(ActiveEntitlement, :entitled?, 2/3/4)` plus `refute :create/:update/:delete`. **L2** `assert function_exported?` for Feature's four verbs + `refute function_exported?(Feature, :delete, 2/3)`. **L3** docs-truth grep on the *prose* fence: moduledoc `=~ "gate"`, `=~ "fail closed"`, `=~ "stream!/3"`; summary moduledoc `=~ "no top-level"`.
- **D-24 ⚠** — the moduledoc MUST mention `entitled?` by name; do NOT add `refute source =~ "entitled?"`. Assert presence, never refute it.
- **D-25** — do NOT lock generic pagination prose. Three locks, no more.
- **D-26** — ENT-05 is proven as a pure `from_map/1` unit test, no transport. Assert: returns `%ActiveEntitlementSummary{}`; `customer`/`livemode`/`object` populate; **`refute Map.has_key?(struct, :id)`**; nested `data` → `[%ActiveEntitlement{}]` with `has_more` preserved. Plus one negative: `data: []` with `has_more: true` still deserializes.
- **D-27** — fixtures: private now, promote-by-move in Phase 65. `test/support/fixtures/entitlements.ex` (`@moduledoc false`), functions named exactly as Phase 65 will need them: `active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2`. Header comment marking the promotion target. **And append one line to Phase 65's Build constraints in `.planning/ROADMAP.md`.**
- **D-28** — extend `TestHelpers.list_json/2` to `list_json(items, url, has_more \\ false)`.
- **D-29** — the docs gate is DIFFERENTIAL. Gate: (1) plain `mix docs` exits 0; (2) zero *new* warnings vs clean-HEAD baseline **and** zero warnings matching `entitlements`; (3) `docs_truth_test.exs` green; (4) `credo --strict` green. Use ExDoc autolinks and relative `.md#anchor` links — never hardcoded hexdocs URLs.

### Claude's Discretion

Exact prose, moduledoc wording, guide section copy, snippet selection, and test naming are Claude's discretion within the D-01…D-29 frame. Two standing instructions: **re-verify F-01 through F-10 against source and live Stripe docs before implementing**; and where a researcher's claim and CONTEXT.md disagree, **CONTEXT.md wins** — the ⚠ divergences (D-03, D-08, D-24) were reconciled deliberately.

### Deferred Ideas (OUT OF SCOPE)

- **`groups_for_modules` backlog — 32 ungrouped lib modules** (incl. the entire `Tax.*` family, `Product`, `Price.*`, `Coupon.*`, `PromotionCode`, `File`, `FileLink`, `ObjectTypes`, `Drift`, `Webhook.CacheBodyReader`, `TestHelpers.TestClock`). → **Phase 67 (Milestone Doc Close)**. Explicitly NOT Phase 63.
- **Promoting `guides/entitlements.md` to a 5th Flagship Recipe** — revisit only on adopter pull.
- **`Oban`-style `guides/upgrading/` subdirectory** — carried forward unresolved from Phase 62; still not triggered.
- **Fixing `mix docs --warnings-as-errors`** — pre-existing, not this phase's debt. D-29's differential gate is the interim posture.
- **`retrieve_by_lookup_key/3` on `Feature`** — rejected in D-12; additive minor-bump addition later if adopter pull shows friction.
- Any per-request `entitled?/2` helper; `Product.Feature` attachment (Phase 66); `ObjectTypes` registration + public `Testing.Fixtures` (Phase 65); meter reads (Phase 64).

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENT-01 | List a customer's active entitlements via `LatticeStripe.Entitlements.ActiveEntitlement.list/3` (`GET /v1/entitlements/active_entitlements`, customer filter) | Endpoint + params confirmed from OpenAPI spec (`customer` REQUIRED, `limit` default 10 / max 100, `starting_after`/`ending_before`/`expand`). Template = `Billing.Meter.list/3` + `Resource.unwrap_list/2`. Guard via `Resource.require_param!/3` per D-10. See *Standard Stack* and *Code Examples*. |
| ENT-02 | Auto-paginate via `ActiveEntitlement.stream!/3` (follows `has_more`/cursor) | `LatticeStripe.List.stream!/2` already implements the entire mechanism (`list.ex:154-161`). Resource layer only wraps it with `Stream.map(&from_map/1)` (F-09 verified at `charge.ex:338-342`, `meter.ex:196-200`). The list `url` returned by the canonical endpoint is `/v1/entitlements/active_entitlements` (verified live), so next-page construction is correct with zero special-casing. See *Common Pitfalls #1* and *Validation Architecture*. |
| ENT-03 | Retrieve a single active entitlement via `ActiveEntitlement.retrieve/3` | `GET /v1/entitlements/active_entitlements/{id}` confirmed; only `expand` is accepted. Returns the object directly (not wrapped). Template = `Billing.Meter.retrieve/3` + `Resource.unwrap_singular/2`. |
| ENT-04 | Create/retrieve/update/list entitlement features via `LatticeStripe.Entitlements.Feature` | Spec-confirmed surface: `POST /v1/entitlements/features` (requires `lookup_key` + `name`), `GET /{id}`, `POST /{id}` (accepts only `active`/`name`/`metadata`/`expand`), `GET` list (filters `archived`, `lookup_key`). **No DELETE exists** (F-06 verified). D-13 adds `stream!/3`. See *Standard Stack → Wire Surface*. |
| ENT-05 | `active_entitlement_summary` payloads (no top-level `id`) deserialize correctly without being dropped | F-01 verified: nothing drops id-less objects today (`client.ex:768-783` keys off `"object"`; `list.ex:283-295` returns `nil` gracefully). F-02 verified: the spec has **no `id` property at all**. Real deliverable is the typed module (D-01) + `%List{}`-typed `entitlements` (D-02) + cursor-state rewrite (D-04). Proven by pure `from_map/1` unit test (D-26). |
</phase_requirements>

## Architectural Responsibility Map

This is a single-tier library (an HTTP SDK), so the tiers are internal layers rather than deployment tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP request construction | Resource module (`Entitlements.*`) | `LatticeStripe.Request` | Each resource owns its `%Request{}` literal; there is no shared "endpoint" abstraction and none should be introduced. |
| Transport / retry / telemetry | `LatticeStripe.Client` | `Transport.Finch` | Already complete. Phase 63 touches neither. |
| Cursor pagination state machine | `LatticeStripe.List` | — | `stream!/2` + `build_next_page_request/1` own all three pagination modes. **Do not grow a new mechanism** (recorded project decision). |
| Wire-map → struct typing | Resource module `from_map/1` | `ObjectTypes` (webhook dispatch only) | F-09: resource-level `Stream.map(&from_map/1)`. `ObjectTypes` is for webhook/expandable dispatch; Phase 65 owns its registry rows. |
| Required-param enforcement | Resource module | `Resource.require_param!/3` | Pre-network `ArgumentError` guard (D-10). |
| Response unwrapping | `Resource.unwrap_singular/unwrap_list/unwrap_bang!` | — | All four used verbatim; no new helper needed. |
| Docs / sidebar registration | `mix.exs` `docs/0` | `docs_truth_test.exs` | One `groups_for_modules` group + two guide registrations (D-17, D-18), locked by docs-truth. |
| Fixture data | `test/support/fixtures/entitlements.ex` (private) | `lib/lattice_stripe/testing/fixtures/` (Phase 65, public) | D-27 promote-by-move. See *Correction C-01* — namespaces differ. |

## Project Constraints (from CLAUDE.md)

| Directive | Impact on this phase |
|-----------|---------------------|
| Elixir 1.15+, OTP 26+ | No 1.18+/1.19-only syntax. Avoid stdlib `JSON` module; use Jason via `LatticeStripe.Json`. |
| **No Dialyzer** — typespecs are documentation-only | `@spec` is for ExDoc, not enforcement. This is *why* D-23's `refute function_exported?` locks are mandatory: they are the only enforcement of public surface shape. |
| Minimal dependencies | **Phase 63 adds zero dependencies.** Everything needed is already in `mix.exs`. |
| HTTP via Transport behaviour, Finch default | Unit tests mock `LatticeStripe.MockTransport` (`Mox.defmock` in `test/test_helper.exs:5`). |
| JSON via Jason | Fixtures are string-keyed maps matching Jason's default output — same as `~w[...]` sigil (no `a`) for `@known_fields`. |
| Pin to current stable Stripe API version, per-request override | Client default is `2026-03-25.dahlia` (SEED-005 §6 FROZEN). Spec verified this session is `2026-06-24.dahlia`; entitlement schemas are stable across the delta. |
| GSD workflow enforcement | Work must run through `/gsd-execute-phase`, not ad-hoc edits. |
| "Processes only when truly needed" | No GenServer, no supervision changes. Client config is a struct passed explicitly. |
| Credo (not Dialyzer) for static analysis | `mix credo --strict` must be green. Note `Credo.Check.Warning.StructFieldAmount` — the new structs are small (5 and 7 fields), so no `credo:disable-for-next-line` needed. |

## Standard Stack

### Core — already present, zero additions

| Library | Version (in `mix.lock` range) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `finch` | `~> 0.21` | Default HTTP transport | Already the default; Phase 61 made the pool automatic. `[VERIFIED: mix.exs:284]` |
| `jason` | `~> 1.4` | JSON codec | Already wired through `LatticeStripe.Json.Jason`. `[VERIFIED: mix.exs:285]` |
| `telemetry` | `~> 1.0` | Request instrumentation | Emitted by `Client.request/2`; entitlements inherit it for free. `[VERIFIED: mix.exs:286]` |
| `nimble_options` | `~> 1.0` | Client config validation | Not touched by this phase. `[VERIFIED: mix.exs:287]` |

### Dev/Test — already present

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `mox` | `~> 1.2` | Transport mocking | All unit tests. `LatticeStripe.MockTransport` is pre-defined. `[VERIFIED: mix.exs:292, test/test_helper.exs:5]` |
| `ex_doc` | `~> 0.34` | Docs generation | `mix docs` gate (D-29). `[VERIFIED: mix.exs:293]` |
| `credo` | `~> 1.7` | Static analysis | `mix credo --strict` gate. `[VERIFIED: mix.exs:294]` |
| `stripe/stripe-mock:latest` (Docker, not a Hex dep) | v0.199.0 verified this session | Integration tests | `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` `[VERIFIED: run locally 2026-07-28]` |

**Installation:** none. `mix deps.get` only.

### Wire Surface — verified against `stripe/openapi` `spec3.sdk.json`

`[VERIFIED: stripe/openapi spec3.sdk.json, info.version = "2026-06-24.dahlia", downloaded and parsed 2026-07-28]`

**Exactly four entitlement paths exist. There are no others.**

| Path | Verbs | Notes |
|------|-------|-------|
| `/v1/entitlements/active_entitlements` | `GET` | list |
| `/v1/entitlements/active_entitlements/{id}` | `GET` | retrieve |
| `/v1/entitlements/features` | `GET`, `POST` | list, create |
| `/v1/entitlements/features/{id}` | `GET`, `POST` | retrieve, update |

**`GET /v1/entitlements/active_entitlements` query params:**

| Param | Required | Type | Note |
|-------|----------|------|------|
| `customer` | **YES** | string | "The ID of the customer." Confirms F-04. |
| `limit` | no | integer | 1–100, **default 10**. Confirms F-04. |
| `starting_after` | no | string | forward cursor |
| `ending_before` | no | string | backward cursor |
| `expand` | no | array | e.g. `["data.feature"]` |

Response: standard list envelope `{object: "list", data: [entitlements.active_entitlement], has_more, url}` with all four fields `required`.

**`GET /v1/entitlements/active_entitlements/{id}`:** path `id` (required) + `expand` only. Returns the object directly (no envelope).

**`entitlements.active_entitlement` object — exactly 5 fields, all `required` in spec:**

| Field | Type | Note |
|-------|------|------|
| `id` | string | `ent_…` |
| `object` | string enum | `"entitlements.active_entitlement"` |
| `feature` | `anyOf [string, entitlements.feature]` | **Expandable** — use the `charge.ex:514-518` idiom (D-15) |
| `lookup_key` | string | up to 80 chars. **CONTEXT never enumerates this field — see Correction C-03** |
| `livemode` | boolean | |

**`entitlements.feature` object — exactly 7 fields, all `required` in spec:**

| Field | Type | Note |
|-------|------|------|
| `id` | string | `feat_…` |
| `object` | string enum | `"entitlements.feature"` |
| `active` | boolean | Spec description, verbatim: *"Inactive features cannot be attached to new products **and will not be returned from the features list endpoint**."* — this is F-07's silent-omission, straight from the spec |
| `lookup_key` | string | up to 80 chars |
| `name` | string | *"for your own purpose, not meant to be displayable to the customer"* — supports D-14's no-`Inspect`-redaction call |
| `metadata` | object | |
| `livemode` | boolean | |

**`entitlements.active_entitlement_summary` object — exactly 4 fields, all `required`, and there is NO `id` property at all:**

| Field | Type | Note |
|-------|------|------|
| `customer` | string | `cus_…` |
| `entitlements` | inline list object | title `EntitlementsResourceCustomerEntitlementList`; `required: [data, has_more, object, url]`, `object` enum `["list"]`, `data` items `$ref entitlements.active_entitlement`, `x-expandableFields: ["data"]` |
| `livemode` | boolean | |
| `object` | string enum | `"entitlements.active_entitlement_summary"` |

Also: `x-resourceId` is **absent** for the summary (present for the other two) — an independent structural confirmation of F-03 (it is not an addressable resource).

**Feature request bodies:**

| Operation | Required body | Optional body |
|-----------|--------------|---------------|
| `POST /v1/entitlements/features` | `lookup_key`, `name` | `metadata`, `expand` |
| `POST /v1/entitlements/features/{id}` | *(none)* | `active`, `name`, `metadata`, `expand` |

**`lookup_key` is absent from the update body schema entirely** — the spec itself proves D-12's immutability claim. `[VERIFIED: spec3.sdk.json paths./v1/entitlements/features/{id}.post.requestBody]`

**`GET /v1/entitlements/features` query params:** `archived` (boolean — *"filter results to only include features with the given archive status"*), `lookup_key`, `limit` (default 10, max 100), `starting_after`, `ending_before`, `expand`.

**Webhook events:** exactly one entitlement event type exists in the spec — `entitlements.active_entitlement_summary.updated`. `[VERIFIED: spec3.sdk.json]`

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Billing.Meter` as structural template | `charge.ex` | ROADMAP names `charge.ex`, and it is the canonical *full-resource* template. But Charge is 615 lines with a custom `Inspect`, `search/3`, `capture/4`, and 40+ fields. `meter.ex` (288 lines) is nested-namespace, has `require_param!` guards, a 5-line `stream!/3`, and no `Inspect` impl — a structurally closer match. **Use Meter for shape, Charge for the expandable-field idiom only.** |
| Typed `%List{}` for `summary.entitlements` (D-02) | raw `[map()]` | Rejected in D-02. Additional evidence found: `LatticeStripe.Drift.run/1` enrolls modules via `ObjectTypes.object_map()` and diffs `@known_fields` against the spec (`drift.ex:15-27`) — a typed module gets free spec-drift surveillance once Phase 65 registers it; a raw map gets none. |
| stripe-mock for pagination proof | Mox multi-page fixtures | stripe-mock **cannot** prove pagination (F-08, re-verified this session — see *Environment Availability*). Mox is the only option. |

## Architecture Patterns

### System Architecture Diagram

```
                     caller
                        │
     ┌──────────────────┼──────────────────────────────┐
     │                  │                              │
     ▼                  ▼                              ▼
 list/3            stream!/3                      retrieve/3
     │                  │                              │
     │  require_param!  │  require_param!              │ is_binary(id) guard
     │  ("customer")    │  ("customer")                │
     ▼                  ▼                              ▼
 %Request{             %Request{                  %Request{
  :get, @list_path}     :get, @list_path}          :get, @list_path <> "/#{id}"}
     │                  │                              │
     │                  ▼                              │
     │        LatticeStripe.List.stream!/2             │
     │            (Stream.resource)                    │
     │                  │                              │
     │        ┌─────────┴───────────┐                  │
     │        ▼                     ▼                  │
     │   fetch_page!          build_next_page_request  │
     │        │                     │                  │
     │        │       base_params (customer PRESERVED) │
     │        │       + starting_after = _last_id      │
     │        │       − idempotency_key (stripped)     │
     │        │                     │                  │
     │        └──────────┬──────────┘                  │
     ▼                   ▼                             ▼
      LatticeStripe.Client.request/2  ──▶ Transport ──▶ Stripe / stripe-mock
                         │
                         ▼
             build_decoded_response/6
            (object=="list" ? List.from_json : raw map)
                         │
     ┌───────────────────┼───────────────────┐
     ▼                   ▼                   ▼
 unwrap_list      Stream.map(&from_map/1)  unwrap_singular
 (&from_map/1)                             (&from_map/1)
     │                   │                   │
     └───────────────────┴───────────────────┘
                         │
                         ▼
              %Entitlements.ActiveEntitlement{}


   webhook path (no HTTP — F-03):

   event.data["object"]  ──▶ ObjectTypes.maybe_deserialize/1
                                    │  (Phase 65 adds the registry row;
                                    │   Phase 63 exposes from_map/1 directly)
                                    ▼
                       ActiveEntitlementSummary.from_map/1
                                    │
              ┌─────────────────────┼──────────────────────┐
              ▼                     ▼                      ▼
        customer            entitlements               livemode
      (string)         List.from_json(raw)  ← ORDER LOAD-BEARING (D-05)
                              │  derives _last_id from RAW maps
                              ▼
                       %{list | data: Enum.map(raw, &AE.from_map/1)}
                              │  + url rewritten to @list_path (D-04)
                              │  + _params: %{"customer" => customer}
                              ▼
                       %LatticeStripe.List{data: [%ActiveEntitlement{}]}

              ▼
   stream_entitlements!/3  ──▶ ActiveEntitlement.stream!(client,
                                 %{"customer" => summary.customer,
                                   "limit" => "100"}, opts)
                               (FULL RE-FETCH — inline page ignored, D-03)
```

### Recommended Project Structure

```
lib/lattice_stripe/entitlements/
├── active_entitlement.ex          # ENT-01/02/03 — list/3, stream!/3, retrieve/3, from_map/1
├── active_entitlement_summary.ex  # ENT-05 — from_map/1, stream_entitlements!/3
└── feature.ex                     # ENT-04 — create/retrieve/update/list/stream!/from_map
                                   # NO parent entitlements.ex (D-16)

guides/entitlements.md             # D-18 spine-only, ~200-260 lines

test/lattice_stripe/entitlements/
├── active_entitlement_test.exs        # Mox unit + L1 locks
├── active_entitlement_stream_test.exs # D-21 — own file, 8 named assertions
├── active_entitlement_summary_test.exs# D-26 — pure from_map/1, no transport
└── feature_test.exs                   # Mox unit + L2 locks

test/integration/
└── entitlements_integration_test.exs  # D-20 — all six verbs vs stripe-mock

test/support/fixtures/entitlements.ex  # D-27 — private, promotion-marked
```

### Pattern 1: Full resource module (the `meter.ex` shape)

**What:** A flat module: `@known_fields` sigil → `@type t` → `defstruct` (with `object:` default + `extra: %{}`) → banner-commented verb sections, each a non-bang + bang pair → `from_map/1` last.
**When to use:** Both `ActiveEntitlement` and `Feature`.

```elixir
# Source: lib/lattice_stripe/billing/meter.ex (verbatim structure)
defmodule LatticeStripe.Billing.Meter do
  @moduledoc """..."""

  alias LatticeStripe.{Client, Request, Resource}

  @known_fields ~w(id object display_name event_name status ...)

  @type t :: %__MODULE__{id: String.t() | nil, ..., extra: map()}

  defstruct [:id, :display_name, ..., object: "billing.meter", extra: %{}]

  # ---------------------------------------------------------------------------
  # CREATE
  # ---------------------------------------------------------------------------

  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(params, "display_name",
      "LatticeStripe.Billing.Meter.create/3 requires a display_name param")

    %Request{method: :post, path: "/v1/billing/meters", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  # ...

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    %__MODULE__{id: known["id"], object: known["object"] || "billing.meter", ..., extra: extra}
  end
end
```

Note the exact pipe idiom `%Request{...} |> then(&Client.request(client, &1)) |> Resource.unwrap_*`. Match it.

### Pattern 2: `stream!/3` at the resource layer (F-09)

```elixir
# Source: lib/lattice_stripe/billing/meter.ex:196-200 (identical at charge.ex:338-342)
@spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  req = %Request{method: :get, path: "/v1/billing/meters", params: params, opts: opts}
  LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

`stream!` has **no non-bang twin** anywhere in the repo. Do not add one.

### Pattern 3: Typed-nested-`%List{}` (D-02, D-05)

```elixir
# Source: lib/lattice_stripe/tax/calculation.ex:190-196
defp parse_line_items(nil), do: nil

defp parse_line_items(%{"object" => "list", "data" => data} = list) when is_list(data) do
  %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
end

defp parse_line_items(other), do: other
```

`List.from_json(list)` runs **first**, on the raw string-keyed map, so `_last_id` derivation at `list.ex:283-295` sees `%{"id" => ...}`. The `Enum.map` update happens after. **This ordering is the whole of D-05.** For the summary, extend the update map with the D-04 cursor-state fields:

```elixir
%{
  List.from_json(list, %{"customer" => customer}, [])
  | data: Enum.map(data, &ActiveEntitlement.from_map/1),
    url: @list_path
}
```

### Pattern 4: Expandable field decode (D-15)

```elixir
# Source: lib/lattice_stripe/charge.ex:514-518
customer:
  if(is_map(known["customer"]),
    do: ObjectTypes.maybe_deserialize(known["customer"]),
    else: known["customer"]
  ),
```

For `ActiveEntitlement.feature` this yields `Feature.t() | String.t() | nil` **only after Phase 65 registers `"entitlements.feature"` in `object_types.ex`**. Until then `maybe_deserialize/1` falls through to the raw map (`object_types.ex:76`). **Do not route through `ObjectTypes` for this field** — call `Feature.from_map/1` directly so ENT-01 is correct in Phase 63 without a Phase 65 dependency:

```elixir
feature: if(is_map(known["feature"]), do: Feature.from_map(known["feature"]), else: known["feature"]),
```

`tax/calculation.ex:187-188` (`parse_expandable/1`) shows the `ObjectTypes` variant; use the direct variant here and note why in a comment.

### Pattern 5: ExDoc warning admonition (D-19.1)

```elixir
# Source: lib/lattice_stripe/balance.ex:10 (17 uses across lib/ and guides/)
> #### Reconciliation loop antipattern {: .warning}
>
> ...
```

Supported classes in use: `{: .warning}`, `{: .info}`. Use `{: .warning}` for the `entitled?` fence.

### Pattern 6: "Relationship to other …" moduledoc section (D-15)

```markdown
## Relationship to other tax surfaces

This module is **not** `LatticeStripe.Invoice.AutomaticTax`. ...
```
`[VERIFIED: lib/lattice_stripe/tax/transaction.ex:20-26]` — clone this shape for `Entitlements.Feature` vs `Product.Feature`.

### Anti-Patterns to Avoid

- **Growing a new pagination mechanism.** `List.stream!/2` handles all three modes. Recorded project decision: "Reuse existing dispatch tables for new resource families instead of growing new ones."
- **Typing `data` before calling `List.from_json/3`.** Silent truncation, zero test failures. See *Common Pitfalls #1*.
- **Touching `lib/lattice_stripe/object_types.ex`.** Phase 65 owns it. Phase 63 must not add rows.
- **Adding a parent `lib/lattice_stripe/entitlements.ex`.** D-16. Verified rule: `billing/`, `billing_portal/`, `checkout/`, `tax/`, `builders/`, `test_helpers/` all have no parent `.ex`.
- **Adding a custom `Inspect` impl.** `charge.ex:588+` exists only to redact PII; `Feature.name` is spec-documented as *not customer-displayable*. Derive the default (D-14).
- **`id in [nil, ""]` ArgumentError clauses.** 5 of 55 top-level modules only — not a convention (D-11).
- **Using `mix ci` as a task gate.** See *Common Pitfalls #4* — it is RED at clean HEAD.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cursor pagination | A `while has_more` loop | `LatticeStripe.List.stream!/2` | Handles search-token, backward (`ending_before` + `_first_id`), and forward (`_last_id`) modes; preserves `base_params`; strips `idempotency_key` on page ≥2. `list.ex:245-275`. |
| Cursor id extraction | `List.last(data)["id"]` in the resource | `List.from_json/3` | Already derives `_first_id`/`_last_id` and returns `nil` gracefully on id-less items (`list.ex:283-295`). |
| `{:ok, _}` unwrapping | `case ... do` in each verb | `Resource.unwrap_singular/2`, `unwrap_list/2` | Uniform error pass-through; used by all 55 modules. |
| Bang variants | Hand-written `raise` | `Resource.unwrap_bang!/1` | One-liner delegation, established across the repo. |
| Required-param validation | `Map.fetch!` / custom raise | `Resource.require_param!/3` | Raises `ArgumentError` pre-network with a house-format message. `resource.ex:117-124`. |
| Test list envelopes | Hand-built maps per test | `TestHelpers.list_json/2` (extend to `/3` per D-28) | Currently hardcodes `has_more: false` (`test_helpers.ex:55-62`), which is exactly why D-28 exists. |
| Spec-drift detection | Manual field audits | `mix lattice_stripe.check_drift` | Auto-enrolls anything in `ObjectTypes.object_map()` (`drift.ex:15-27`). Free once Phase 65 registers the types. |

**Key insight:** Phase 63 writes almost no new mechanism. Every hard problem in this domain — pagination, cursor derivation, param threading, header propagation, error unwrapping — is already solved and unit-tested in `list.ex`, `resource.ex`, and `client.ex`. The phase's job is to *supply correctly-shaped state* to machinery that already works. The one place it must be careful is the order in which it supplies that state (D-05).

## Runtime State Inventory

Not applicable — this is a greenfield additive phase, not a rename/refactor/migration. No stored data, live service config, OS-registered state, secrets, or build artifacts carry an old name. **Verified:** `grep -ril entitlement lib` returns 0 hits; `ls lib/lattice_stripe/entitlements` does not exist.

## Common Pitfalls

### Pitfall 1: Cursor derivation ordering (the phase's real hazard)

**What goes wrong:** `List.from_json/3` derives `_last_id` by pattern-matching `%{"id" => id}` on `data` items (`list.ex:283-295`). Typed `%ActiveEntitlement{}` structs do **not** match a string-keyed map pattern, so `_last_id` becomes `nil`. With `has_more: true` and `_last_id: nil`, `build_next_page_request/1` falls to the `true -> %{}` branch (`list.ex:262-263`) and re-requests **page 1 forever**, or — if `has_more` is false — silently truncates at 10.
**Why it happens:** Nothing in any function signature reveals the ordering requirement. A "harmless" refactor that maps `data` first compiles, passes every existing test, and ships.
**How to avoid:** Always `List.from_json(raw_list, ...)` **first**, then update `data`. Ship the D-05 assertion: `assert summary.entitlements._last_id == "ent_last"` (non-nil, and equal to the last raw id).
**Warning signs:** `_last_id == nil` on a list whose `data` is non-empty; an infinite stream; exactly 10 items returned when more exist.
**Prior art:** This exact bug shipped in stripe-node #630, stripe-php #1422, stripe-java #451, stripe/sync-engine-fork #118, supabase/stripe-sync-engine #280 (F-10).

### Pitfall 2: The webhook summary's `url` is not a callable canonical path

**What goes wrong:** `List.stream/2` builds the next page from `list.url` (`list.ex:271`). Stripe's webhook payload sets `entitlements.url` to `/v1/customer/{cus_id}/entitlements` — singular `customer`, path-scoped — which is **not one of the four paths in the OpenAPI spec**. `[VERIFIED: docs.stripe.com/billing/entitlements?dashboard-or-api=api webhook example; cross-checked against spec3.sdk.json path list]`
**Why it happens:** Stripe's own docs instruct developers to use the inlined url, so it is plausibly an undocumented alias — but its callability is **not established**, and it is absent from the spec that stripe-mock is generated from (so it 404s locally).
**How to avoid:** D-04 — rewrite `url` to `@list_path` when building the nested `%List{}`. D-03 — the blessed path (`stream_entitlements!/3`) does a full canonical re-fetch and never touches the inline cursor at all.
**Warning signs:** A 404 on page 2 of `List.stream(summary.entitlements, client)`.

### Pitfall 3: `active` vs `archived` — the two-words-one-concept split (F-07)

**What goes wrong:** A reconciler diffing Stripe's feature catalog against a local config calls `Feature.list/3` with no params, gets only non-archived features, and reports every archived feature as **deleted**.
**Why it happens:** The object field is `active` (boolean); the list filter is `archived` (boolean, inverted sense). The spec states it plainly in the `active` field description: *"Inactive features … will not be returned from the features list endpoint."* `[VERIFIED: spec3.sdk.json components.schemas."entitlements.feature".properties.active.description]`
**How to avoid:** D-09 — a mandatory `## Archiving` moduledoc section naming both halves and prescribing `%{"archived" => true}` for catalog reconciliation. Nothing in a function signature can surface this.
**Warning signs:** Phantom deletions in a drift report.

### Pitfall 4: `mix ci` is RED at clean HEAD — do not use it as a gate

**What goes wrong:** A plan task that runs `mix ci` fails for reasons unrelated to the phase.
**Why it happens:** `mix.exs:320-330` defines `ci: ["format --check-formatted", "compile --warnings-as-errors", "credo --strict", "test", "docs --warnings-as-errors"]`. The last step currently exits **1** with **42** warnings. `[VERIFIED: run 2026-07-28 in this worktree]` Real CI (`.github/workflows/ci.yml:254`) runs plain `mix docs` (exit 0) and never invokes the `ci` alias.
**How to avoid:** Plan tasks must use the individual commands. See *Validation Architecture → Sampling Rate*.
**Warning signs:** A verification step failing on `Charge.capture/4`-style autolink warnings the phase never touched.

### Pitfall 5: `Feature.create/3` param defaults

**What goes wrong:** Writing `def create(client, params \\ %{}, opts \\ [])` makes an argument-less call compile and then raise `ArgumentError` at runtime for a missing `lookup_key`.
**Why it happens:** Copy-paste from `list/3`, which legitimately defaults.
**How to avoid:** D-14 — `create/3` takes `params` with **no default**, matching `Billing.Meter.create/3` (`meter.ex:92`).

### Pitfall 6: `stream!/3` and the required-`customer` guard

**What goes wrong:** `stream!/3` returns a lazy `Stream`; if the `require_param!` call is placed inside the stream construction it will not raise until the stream is consumed, producing a confusing stack trace far from the call site.
**Why it happens:** `Stream.resource/3` defers the `start_fun`.
**How to avoid:** Call `Resource.require_param!/3` in the function body **before** constructing `%Request{}` — as `Billing.Meter.create/3` does. Since `stream!/3`'s body is eager up to the `List.stream!/2` call, this is automatic if the guard is the first statement. Add a test asserting `assert_raise ArgumentError, fn -> ActiveEntitlement.stream!(client, %{}) end` (no `Enum.to_list`).

## Code Examples

### List a customer's active entitlements (ENT-01)

```elixir
# Pattern source: lib/lattice_stripe/billing/meter.ex:177-188
@list_path "/v1/entitlements/active_entitlements"

@spec list(Client.t(), map(), keyword()) ::
        {:ok, LatticeStripe.Response.t()} | {:error, LatticeStripe.Error.t()}
def list(%Client{} = client, params \\ %{}, opts \\ []) do
  Resource.require_param!(
    params,
    "customer",
    "LatticeStripe.Entitlements.ActiveEntitlement.list/3 requires a customer param"
  )

  %Request{method: :get, path: @list_path, params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&from_map/1)
end
```

### Auto-paginate (ENT-02)

```elixir
# Pattern source: lib/lattice_stripe/billing/meter.ex:196-200
@spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  Resource.require_param!(
    params,
    "customer",
    "LatticeStripe.Entitlements.ActiveEntitlement.stream!/3 requires a customer param"
  )

  req = %Request{method: :get, path: @list_path, params: params, opts: opts}
  LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

### Idempotent `from_map/1` (D-07)

```elixir
@spec from_map(map() | t() | nil) :: t() | nil
def from_map(nil), do: nil
def from_map(%__MODULE__{} = entitlement), do: entitlement

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)

  %__MODULE__{
    id: known["id"],
    object: known["object"] || "entitlements.active_entitlement",
    feature:
      if(is_map(known["feature"]),
        do: LatticeStripe.Entitlements.Feature.from_map(known["feature"]),
        else: known["feature"]
      ),
    lookup_key: known["lookup_key"],
    livemode: known["livemode"],
    extra: extra
  }
end
```

Clause order matters: `%__MODULE__{}` is a map, so the struct clause must precede `when is_map(map)`.

### Summary deserialization with correct cursor state (ENT-05, D-02/D-04/D-05)

```elixir
alias LatticeStripe.Entitlements.ActiveEntitlement

@known_fields ~w(object customer entitlements livemode)
# NOTE: no "id" — the Stripe object has no id property (F-02, spec-verified).

defstruct [:customer, :entitlements, :livemode,
           object: "entitlements.active_entitlement_summary", extra: %{}]

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  customer = known["customer"]

  %__MODULE__{
    object: known["object"] || "entitlements.active_entitlement_summary",
    customer: customer,
    entitlements: parse_entitlements(known["entitlements"], customer),
    livemode: known["livemode"],
    extra: extra
  }
end

defp parse_entitlements(nil, _customer), do: nil

defp parse_entitlements(%{"object" => "list", "data" => data} = list, customer)
     when is_list(data) do
  # ORDER IS LOAD-BEARING (D-05): List.from_json/3 derives _last_id by matching
  # %{"id" => id} on RAW string-keyed maps (list.ex:283-295). Type data only after.
  # D-04: rewrite url to the canonical path — the webhook payload's url
  # ("/v1/customer/{cus}/entitlements") is not one of the four spec paths.
  %{
    LatticeStripe.List.from_json(list, %{"customer" => customer}, [])
    | data: Enum.map(data, &ActiveEntitlement.from_map/1),
      url: ActiveEntitlement.list_path()
  }
end

defp parse_entitlements(other, _customer), do: other
```

`ActiveEntitlement` should expose the path via `@doc false def list_path, do: @list_path` so D-06's "physically cannot diverge" holds across modules.

### The blessed reconciler call (D-03)

```elixir
@spec stream_entitlements!(Client.t(), t(), keyword()) :: Enumerable.t()
def stream_entitlements!(%Client{} = client, %__MODULE__{customer: customer}, opts \\ [])
    when is_binary(customer) do
  ActiveEntitlement.stream!(client, %{"customer" => customer, "limit" => "100"}, opts)
end
```

### Mox multi-page test shape (D-21)

```elixir
# Pattern source: test/lattice_stripe/list_test.exs:384-449
test "page 2 preserves the customer filter" do
  LatticeStripe.MockTransport
  |> expect(:request, fn req ->
    assert req.url =~ "customer=cus_123"
    list_response([ae_json("ent_a"), ae_json("ent_b")], true)
  end)
  |> expect(:request, fn req ->
    # D-22: the single highest-value assertion in the phase.
    # If base_params preservation (list.ex:246) regresses, the reconciler
    # streams the ENTIRE ACCOUNT's entitlements instead of one customer's.
    assert req.url =~ "customer=cus_123"
    assert req.url =~ "starting_after=ent_b"
    list_response([ae_json("ent_c")], false)
  end)

  items =
    test_client()
    |> ActiveEntitlement.stream!(%{"customer" => "cus_123"})
    |> Enum.to_list()

  assert [%ActiveEntitlement{id: "ent_a"}, %ActiveEntitlement{id: "ent_b"},
          %ActiveEntitlement{id: "ent_c"}] = items
end
```

**Concrete detail the planner needs:** the Mox mock receives a plain map with keys `:method`, `:url`, `:headers`, `:body`, `:opts` (`lib/lattice_stripe/transport.ex:36-42`). GET params are encoded into `:url` as a query string (`client.ex:705`). So D-21's assertions (1), (2) are `req.url =~ "…"` string matches; assertions (6) and (7) are on `req.headers`, whose names are **lowercase**: `{"stripe-account", …}` (`client.ex:687`) and `{"idempotency-key", …}` (`client.ex:693`).

### Integration test setup (D-20)

```elixir
# Source: test/integration/charge_integration_test.exs:19-27 — copy literally
@moduletag :integration

setup_all do
  case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
      :ok

    {:error, _} ->
      raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
  end
end

setup do
  {:ok, client: test_integration_client()}
end
```

### `mix.exs` registrations (D-17, D-18)

```elixir
# extras: — insert after "guides/customer-portal.md", before "guides/metering.md"
"guides/entitlements.md",

# groups_for_extras: "Canonical Guides" — same relative position
"guides/entitlements.md",

# groups_for_modules: — insert between "Billing Metering" and Connect:
Entitlements: [
  LatticeStripe.Entitlements.ActiveEntitlement,
  LatticeStripe.Entitlements.ActiveEntitlementSummary,
  LatticeStripe.Entitlements.Feature
],
```

A guide listed in `groups_for_extras` but absent from `extras:` is **silently dropped** — both edits are required (D-18). `[VERIFIED: mix.exs:23-104; docs_truth_test.exs:450-455 asserts exactly this pair for tax.md]`

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Entitlement gating by re-reading subscriptions/prices | Stripe-native Entitlements API (`feature` → `product_feature` attachment → `active_entitlement`) | Stripe GA'd Entitlements in 2024 | The whole reason this phase exists. |
| Per-request `entitled?(customer, feature)` network gate | Reconciler → local store → local fail-closed gate | Project decision (SEED-005, REQUIREMENTS "Out of Scope") | Deliberately refused here (D-19). |
| Trusting the webhook summary's inline 10 entitlements as a complete snapshot | Full canonical re-fetch keyed on `summary.customer` | D-03, this phase | Removes accrue's `truncated` column and its truncation telemetry event. |
| `mix test` alone as surface-shape enforcement | `refute function_exported?` structural locks | Established across 19 test files (86 call sites) `[VERIFIED: grep 2026-07-28]` | With no Dialyzer and doc-only typespecs, this is the *only* enforcement of public API shape. |

**Deprecated/outdated:**
- `Billing.Meter.status_atom/1` carries `@deprecated` — an example of how the repo handles deprecation, not relevant to this phase.
- No entitlement API surface is deprecated. There is no DELETE for features and there never was (F-06).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Live `api.stripe.com` behaves identically to `spec3.sdk.json` for the four entitlement paths (all verification was against the spec + stripe-mock; no live-key call was made) | Standard Stack → Wire Surface | LOW. The spec is Stripe's own generation source and stripe-mock is built from it. A live-key smoke test is the only way to fully close this, and no live key is available in this environment. |
| A2 | The inlined `entitlements.url` (`/v1/customer/{cus}/entitlements`) is an undocumented alias rather than a documentation error | Common Pitfalls #2 | NONE for the plan — D-03/D-04 route around it either way. Recorded honestly per F-05. |
| A3 | Stripe will not add a `DELETE /v1/entitlements/features` before v1.10 tags | ENT-04 surface completeness | LOW. D-08's `refute function_exported?(Feature, :delete, …)` lock is a *shape* lock, not a Stripe-behavior claim; if Stripe adds one, that is a future minor bump. |
| A4 | `guides/entitlements.md` at ~200-260 lines is the right spine size | D-18 | NONE — pure discretion; `tax.md` is 350 lines, `customer-portal.md` is 362. |

## Open Questions

1. **D-27's "git mv … verbatim" is not literally possible.** See *Correction C-01*. The private fixture namespace is `LatticeStripe.Test.Fixtures.*`; the public one is `LatticeStripe.Testing.Fixtures.*`.
   - What we know: `test/support/fixtures/metering.ex` defines `LatticeStripe.Test.Fixtures.Metering`; `lib/lattice_stripe/testing/fixtures/tax_id.ex` defines `LatticeStripe.Testing.Fixtures.TaxId`. `[VERIFIED: read both files 2026-07-28]`
   - What's unclear: whether D-27 intended the module name to change on promotion (it must) and whether the flat `active_entitlement_json/1`-style function names should be preserved (the public fixtures use different naming — check `lib/lattice_stripe/testing/fixtures/tax_id.ex` conventions during planning).
   - Recommendation: keep D-27's **function names** exactly as specified (that is the load-bearing part for Phase 65), name the private module `LatticeStripe.Test.Fixtures.Entitlements`, and word the header comment as: `# PROMOTION TARGET (Phase 65 / OBJ-02): move to lib/lattice_stripe/testing/fixtures/entitlements.ex and rename the module to LatticeStripe.Testing.Fixtures.Entitlements. Function names and bodies transfer unchanged — do not re-author.`

2. **D-29's baseline number is stale.** CONTEXT says 43 warnings; the re-verified count is **42**. Recommendation: the plan should capture the baseline dynamically rather than hardcoding a number — e.g. `mix docs --warnings-as-errors 2>&1 | grep -c "warning:"` on clean HEAD vs. post-change, plus a hard `grep -ci entitle` == 0. That satisfies D-29 without a magic constant that drifts again.

3. **`mix lattice_stripe.check_drift` already exits 1 today** because entitlement schemas appear in `new_resources` (spec types not in `ObjectTypes.object_map()`). `[VERIFIED: drift.ex:15-45]` It runs in a **separate scheduled workflow** (`.github/workflows/drift.yml`), not in `ci.yml`, and files an issue rather than blocking. Phase 63 does not change this. Recommendation: no plan task should treat drift as a gate; optionally note in the phase's verification that the drift issue will still list `entitlements.*` until Phase 65 lands.

## Corrections to CONTEXT.md

These are the only places where re-verification found CONTEXT's incidental details diverging from code truth. **None of them touch a D-decision's substance** — CONTEXT.md still wins on every judgment call.

| # | CONTEXT says | Code truth | Action for planner |
|---|-------------|-----------|-------------------|
| **C-01** | D-27: "`git mv` to `lib/lattice_stripe/testing/fixtures/entitlements.ex` **verbatim**" | Private fixtures are `LatticeStripe.Test.Fixtures.*`; public are `LatticeStripe.Testing.Fixtures.*` | Reword the promotion comment (see Open Question 1). Keep D-27's function names. |
| **C-02** | D-29: "RED at **43** warnings" | **42** warnings; plain `mix docs` exits 0; `mix ci` alias exits 1 | Use a dynamic baseline. **Never use `mix ci` as a task gate.** |
| **C-03** | ENT-01/D-15 never enumerate `ActiveEntitlement`'s fields | Spec: exactly `id`, `object`, `feature`, `lookup_key`, `livemode` — **`lookup_key` is on the entitlement too**, not just the feature | `@known_fields ~w(id object feature lookup_key livemode)`. Document in the moduledoc that `ActiveEntitlement.lookup_key` mirrors the feature's — it is the field a local gate keys on without expanding `feature`. This strengthens D-12's story materially. |
| **C-04** | D-15: "`Product.Feature` … carries the full definition under its `entitlement_feature` field" | Correct, and stronger: `entitlement_feature` is a **direct `$ref`** to `entitlements.feature`, not an `anyOf [string, …]` — it is **never** a bare id string | Phase 66's `Product.Feature.from_map/1` can call `Feature.from_map/1` unconditionally. Worth one line in the D-15 moduledoc cross-reference. |
| **C-05** | ROADMAP build constraint: "follow `lib/lattice_stripe/charge.ex` full-resource template" | `charge.ex` is 615 lines with custom `Inspect`, `search/3`, 40+ fields | Follow `billing/meter.ex` for structure (nested namespace, `require_param!`, 5-line `stream!/3`, no `Inspect`); use `charge.ex` only for the expandable-field idiom (L514-518) and `tax/calculation.ex:190-196` for nested `%List{}`. This satisfies the constraint's *intent*. |
| **C-06** | F-05 wording implies uncertainty about the summary url | Now pinned exactly: `"/v1/customer/cus_ABC123customer/entitlements"`, max **10** inlined | Cite the exact string in the summary moduledoc so a future reader can verify. |
| **C-07** | (not stated) stripe-mock's behavior on a missing required param | Returns **HTTP 400** `invalid_request_error` — *"object property 'customer' is required"* | The D-10 client-side guard means the integration test never reaches this. Add one Mox-free unit assertion that `ActiveEntitlement.list(client, %{})` raises `ArgumentError` **without any transport call** (`verify_on_exit!` with zero `expect`s proves it). |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | everything | ✓ | project targets `~> 1.15`; CI matrix through 1.19 | — |
| `mix deps.get` deps | build | ✓ | resolved | — |
| Docker | stripe-mock integration tests (D-20) | ✓ | 29.5.2 | — |
| `stripe/stripe-mock:latest` | ENT-01/03/04 integration proof | ✓ | **v0.199.0**, pulled and run this session | — |
| Stripe live API key | live-behavior confirmation (A1) | ✗ | — | Spec + stripe-mock triangulation (accepted; this is the project's standing posture) |
| `stripe/openapi` `spec3.sdk.json` | wire-shape verification | ✓ | `info.version = 2026-06-24.dahlia`, 10.06 MB | Fetched on demand by `mix lattice_stripe.check_drift`; not vendored |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** live Stripe credentials → spec + stripe-mock (documented as the project's chosen approach).

### stripe-mock capability probe results (F-08 re-verification, 2026-07-28)

All six verbs exercised via `curl` against `localhost:12111`:

| Verb | Request | Result |
|------|---------|--------|
| ActiveEntitlement list | `GET /v1/entitlements/active_entitlements?customer=cus_123` | 200; `url: "/v1/entitlements/active_entitlements"`; **1 item**, `has_more: false` |
| ActiveEntitlement retrieve | `GET /v1/entitlements/active_entitlements/ent_123` | 200; echoes the requested id; `object: "entitlements.active_entitlement"` |
| Feature list | `GET /v1/entitlements/features` | 200; `url: "/v1/entitlements/features"`; 1 item |
| Feature create | `POST /v1/entitlements/features` (`name`, `lookup_key`) | 200; echoes both; `active: true` |
| Feature retrieve | `GET /v1/entitlements/features/feat_123` | 200 |
| Feature update | `POST /v1/entitlements/features/feat_123` (`name`) | 200 |
| Feature **delete** | `DELETE /v1/entitlements/features/feat_123` | **404** — confirms F-06 |
| Missing required param | `GET /v1/entitlements/active_entitlements` (no `customer`) | **400** `invalid_request_error` — confirms F-04 |
| `archived` / `lookup_key` filters | `GET /v1/entitlements/features?archived=true` / `?lookup_key=something` | 200 both — filters accepted |
| **Pagination** | `?customer=cus_123&limit=3` | **1 item, `has_more: false` — `limit` ignored. stripe-mock CANNOT prove pagination.** Confirms F-08. |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) + Mox `~> 1.2` |
| Config file | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])`; `Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)` |
| Test support path | `test/support` (compiled only in `:test` — `mix.exs:317`) |
| Quick run command | `mix test test/lattice_stripe/entitlements/` |
| Full suite command | `mix test` (baseline: **2114 tests, 0 failures, 1 skipped, 197 excluded** — verified 2026-07-28) |
| Integration command | `mix test --include integration` (requires stripe-mock on :12111) |

### Layers of Validation

| Layer | Mechanism | What it proves | What it cannot prove |
|-------|-----------|----------------|---------------------|
| **Unit — Mox at Transport** | `LatticeStripe.MockTransport` + `verify_on_exit!` | Request construction (method, path, query params, headers), pagination sequencing, call counts, laziness, error propagation, typed decoding | That Stripe actually accepts the request shape |
| **Unit — pure `from_map/1`** | No transport at all | Deserialization of payloads with no HTTP endpoint (the summary, F-03), field mapping, `extra` capture, the no-`id` invariant | Anything network-adjacent |
| **Integration — stripe-mock** | Docker `stripe/stripe-mock:latest` on :12111, `@moduletag :integration` | Real routing against Stripe's OpenAPI spec, real JSON decode, `%Response{}`/`%List{}` shape, that the six verbs exist | **Pagination** (F-08 — one item per list, `limit` ignored); real entitlement lifecycle semantics |
| **Docs-truth** | `File.read!` + `=~` over guides *and* `lib/` sources, own CI job (`ci.yml:185-217`) | That the prose fence exists and says the right words (D-19, D-23 L3) | That the prose is *correct* |
| **Structural locks** | `refute/assert function_exported?` | Public surface shape — the only enforcement available (no Dialyzer, doc-only typespecs) | Behavior |
| **Live Stripe** | *not available* | — | Everything above the mock; accepted risk A1 |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENT-01 | `list/3` GETs `/v1/entitlements/active_entitlements` with the customer filter and returns typed structs | unit (Mox) | `mix test test/lattice_stripe/entitlements/active_entitlement_test.exs` | ❌ Wave 0 |
| ENT-01 | `list/3` raises `ArgumentError` with no `customer`, **before** any transport call (C-07) | unit (Mox, zero expects) | same | ❌ Wave 0 |
| ENT-01 | `list/3` round-trips against stripe-mock | integration | `mix test --include integration test/integration/entitlements_integration_test.exs` | ❌ Wave 0 |
| ENT-02 | `stream!/3` follows `has_more`, 8 named assertions (D-21) | unit (Mox multi-page) | `mix test test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | ❌ Wave 0 |
| ENT-02 | **`"page 2 preserves the customer filter"`** (D-22 — cross-tenant leak guard) | unit (Mox) | same | ❌ Wave 0 |
| ENT-03 | `retrieve/3` GETs `/{id}` and returns a typed struct | unit + integration | both files above | ❌ Wave 0 |
| ENT-04 | `create/3` requires `lookup_key` + `name`; `retrieve/3`; `update/4`; `list/3`; `stream!/3` | unit (Mox) | `mix test test/lattice_stripe/entitlements/feature_test.exs` | ❌ Wave 0 |
| ENT-04 | All five Feature verbs against stripe-mock; **no DELETE** | integration + structural | `mix test --include integration …` + `refute function_exported?(Feature, :delete, 2)` / `3` | ❌ Wave 0 |
| ENT-05 | `from_map/1` returns `%ActiveEntitlementSummary{}`, not a raw map or `nil` | unit (pure) | `mix test test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` | ❌ Wave 0 |
| ENT-05 | `refute Map.has_key?(%ActiveEntitlementSummary{}, :id)` (F-02 design lock) | unit (pure) | same | ❌ Wave 0 |
| ENT-05 | nested `entitlements` → `%LatticeStripe.List{data: [%ActiveEntitlement{}]}` with `has_more` preserved | unit (pure) | same | ❌ Wave 0 |
| ENT-05 | **`_last_id` is non-nil after typing** (D-05 ordering lock) | unit (pure) | same | ❌ Wave 0 |
| ENT-05 | `url` rewritten to `/v1/entitlements/active_entitlements`; `_params == %{"customer" => …}` (D-04) | unit (pure) | same | ❌ Wave 0 |
| ENT-05 | negative: `data: []` with `has_more: true` still deserializes (D-26) | unit (pure) | same | ❌ Wave 0 |
| Fence | L1 `refute function_exported?(ActiveEntitlement, :entitled?, 2/3/4)` + `refute :create/:update/:delete` | structural | `mix test test/lattice_stripe/entitlements/active_entitlement_test.exs` | ❌ Wave 0 |
| Fence | L3 docs-truth prose locks (`"gate"`, `"fail closed"`, `"stream!/3"`, `"no top-level"`, `"entitled?"` **present** per D-24) | docs-truth | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ extend existing |
| Docs | `guides/entitlements.md` in **both** `extras:` and `groups_for_extras["Canonical Guides"]`; `Entitlements:` in `groups_for_modules` | docs-truth | same | ✅ extend existing |
| Helper | `TestHelpers.list_json/3` backward-compatible (D-28) | unit | `mix test` (existing callers are the regression) | ✅ extend existing |

### Sampling Rate

- **Per task commit:** `mix format --check-formatted && mix compile --warnings-as-errors && mix test test/lattice_stripe/entitlements/` (< 5 s)
- **Per wave merge:** `mix test` (full unit suite, ~2.5 s) + `mix credo --strict`
- **Phase gate (all four, per D-29 + C-02):**
  1. `mix test` — 0 failures (baseline 2114 tests)
  2. `mix test --include integration` — requires `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`
  3. `mix docs` — **exit 0** (plain, as CI does), plus differential check: warning count ≤ clean-HEAD baseline (42 at time of research — capture dynamically) **and** `mix docs --warnings-as-errors 2>&1 | grep -ci entitle` == `0`
  4. `mix credo --strict` — 0 issues
  5. `mix test test/lattice_stripe/docs_truth_test.exs` — green (it is its own required CI lane)

  **Do NOT run `mix ci`** — the alias includes `docs --warnings-as-errors`, which is RED at clean HEAD (C-02).

### Un-observable Without Live Stripe Credentials

These behaviors cannot be proven by any automated gate in this phase. They must be stated as known limits, not silently assumed:

- **Real pagination against Stripe.** stripe-mock returns one item and ignores `limit`/`starting_after` (F-08, re-verified). D-21's Mox test proves the SDK *constructs* correct page-2 requests; it cannot prove Stripe honors them. This is the same posture every official Stripe SDK takes (hand-authored multi-page fixtures, not a live mock).
- **Whether `/v1/customer/{cus}/entitlements` is actually callable** (F-05/A2). D-03/D-04 route around it, so this is unfalsifiable-but-irrelevant by design.
- **The `archived` filter's real semantics** — stripe-mock accepts the param (200) but its synthetic response does not vary. F-07's landmine is proven by the *spec description*, and mitigated by moduledoc (D-09), not by a test.
- **`lookup_key` immutability on update.** The spec proves it structurally (not an accepted update param); stripe-mock will not error on an extra param. Documentation-only (D-12).
- **Real `active_entitlement_summary` webhook delivery.** No endpoint serves it (F-03); the only proof is `from_map/1` against a hand-authored fixture matching Stripe's published payload (D-26).

### Wave 0 Gaps

- [ ] `test/support/fixtures/entitlements.ex` — `LatticeStripe.Test.Fixtures.Entitlements`, `@moduledoc false`, with `active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2` and the C-01-worded promotion header (D-27)
- [ ] `test/support/test_helpers.ex` — extend `list_json/2` → `list_json(items, url, has_more \\ false)` (D-28); verify all existing call sites still compile
- [ ] `test/lattice_stripe/entitlements/active_entitlement_test.exs` — ENT-01, ENT-03, L1 locks
- [ ] `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` — ENT-02, D-21's 8 assertions, D-22 named test
- [ ] `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` — ENT-05, D-26 assertions incl. the D-05 `_last_id` ordering lock
- [ ] `test/lattice_stripe/entitlements/feature_test.exs` — ENT-04, L2 locks
- [ ] `test/integration/entitlements_integration_test.exs` — D-20, six verbs, `setup_all` raise-if-absent
- [ ] `test/lattice_stripe/docs_truth_test.exs` — extend with the entitlements guide lock (clone L447-520 tax template) and extend the `guides/scope.md` lock at L341 (D-19.3)
- [ ] Framework install: **none** — ExUnit and Mox are already wired

## Security Domain

Phase 63 is a read/write HTTP client surface over an already-audited transport. No new auth, session, crypto, or storage code is introduced.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | API key handling is `Client`'s, unchanged |
| V3 Session Management | no | Stateless SDK |
| V4 Access Control | **yes** | **Tenant isolation via the `customer` filter.** D-22's `"page 2 preserves the customer filter"` test is an access-control regression guard, not merely a pagination test. If `list.ex:246`'s `base_params` preservation regresses, `stream!/3` returns **the entire account's** entitlements. Treat this as a security test. |
| V5 Input Validation | **yes** | `Resource.require_param!/3` for `customer`, `lookup_key`, `name` (D-10). Params reach the wire via `LatticeStripe.FormEncoder` / `URI.encode_query` — already hardened. |
| V6 Cryptography | no | None introduced. Webhook HMAC is `Webhook`'s, untouched. |
| V7 Error Handling & Logging | **yes** | Errors flow through `LatticeStripe.Error`. **No `Inspect` redaction is needed** — the spec documents `Feature.name` as *"not meant to be displayable to the customer"* (i.e. internal, not PII) and the entitlement objects carry only ids, a lookup key, and a boolean. This is the affirmative evidence behind D-14's "derive the default `Inspect`." |
| V8 Data Protection | **yes (advisory)** | The `entitled?` fence (D-19) is a security decision: a network call on an auth path fails **open** under network partition. The guide must ship the fail-closed local-gate replacement, not just the refusal. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant data exposure via dropped list filter on page ≥2 | Information Disclosure | D-22's named assertion; `List.build_next_page_request/1` preserves `base_params` (`list.ex:246`) |
| Idempotency-key replay across GET page fetches | Tampering | Already stripped at `list.ex:267`; D-21 assertion (7) locks it |
| Connect account leakage across pages | Information Disclosure | `stripe-account` header carries via `_opts`; D-21 assertion (6) locks it |
| Unbounded memory from an unlimited stream | Denial of Service | `List` moduledoc's Memory Warning; guide should show `Stream.take/2` alongside `Enum.to_list()` |
| Fail-open entitlement gate under partition | Elevation of Privilege | The entire D-19 fence — no `entitled?/2`; gate locally, fail closed |

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** Every dependency it uses (`finch`, `jason`, `telemetry`, `nimble_options`, `plug_crypto`, `plug`, `mox`, `ex_doc`, `credo`, `mix_audit`) is already declared in `mix.exs` and locked in `mix.lock`. `stripe/stripe-mock` is a Docker test service, not a Hex dependency, and is already used by 37 existing integration test files.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Sources

### Primary (HIGH confidence)

- `stripe/openapi` `openapi/spec3.sdk.json` — downloaded and parsed 2026-07-28; `info.version = "2026-06-24.dahlia"`; 10.06 MB. Source of every wire-shape claim: the four paths, all query/body params, all three object schemas, the `product_feature` schema, and the single webhook event type.
- `stripe/stripe-mock:latest` (v0.199.0) — run locally via Docker; all six verbs plus DELETE-404, missing-param-400, filters, and the `limit`-ignored pagination limitation exercised via `curl`.
- In-repo source, read directly this session: `lib/lattice_stripe/list.ex` (full), `lib/lattice_stripe/resource.ex` (full), `lib/lattice_stripe/billing/meter.ex` (full), `lib/lattice_stripe/object_types.ex` (full), `lib/lattice_stripe/charge.ex` (L95-125, L330-350, L495-530, L585-615), `lib/lattice_stripe/client.ex` (L687-710, L757-798), `lib/lattice_stripe/tax/calculation.ex` (L150-204), `lib/lattice_stripe/tax/transaction.ex` (L20-38), `lib/lattice_stripe/subscription.ex` (L314-338), `lib/lattice_stripe/price.ex`, `lib/lattice_stripe/product.ex`, `lib/lattice_stripe/drift.ex` (L15-45), `lib/lattice_stripe/transport.ex`, `mix.exs` (full `docs/0`, `deps/0`, `aliases/0`), `test/test_helper.exs`, `test/support/test_helpers.ex`, `test/support/fixtures/metering.ex`, `test/lattice_stripe/list_test.exs` (L1-40, L380-455), `test/lattice_stripe/docs_truth_test.exs` (L85-102, L335-350, L447-525), `test/lattice_stripe/tax_id_test.exs` (L25-40), `test/integration/charge_integration_test.exs` (L1-60), `.github/workflows/ci.yml` (L180-270), `.github/workflows/drift.yml`.
- Commands run this session: `mix test` (2114 tests, 0 failures), `mix docs` (exit 0), `mix docs --warnings-as-errors` (exit 1, 42 warnings, 0 matching "entitle"), `grep -rn "refute function_exported?" test` (86 sites / 19 files), `grep -ril entitlement lib` (0 hits).

### Secondary (MEDIUM confidence)

- [Stripe Entitlements guide (API variant)](https://docs.stripe.com/billing/entitlements.md?dashboard-or-api=api) — the `entitlements.active_entitlement_summary.updated` webhook payload example, the `"/v1/customer/{cus}/entitlements"` url string, and the max-10-inlined statement. Cross-checked against the spec's path list (the url is absent from it), which is what makes F-05's "callability not established" the honest reading.
- `.planning/phases/63-stripe-native-entitlements/63-CONTEXT.md` — the binding decision record; its external citations (stripe-node #630, stripe-php #1422, stripe-java #451, stripe/sync-engine-fork #118, supabase/stripe-sync-engine #280) were not independently re-fetched this session and carry forward at CONTEXT's stated confidence.

### Tertiary (LOW confidence)

- None. No claim in this document rests on WebSearch alone.

## Metadata

**Confidence breakdown:**

- Wire surface (paths, params, schemas): **HIGH** — read directly from Stripe's own OpenAPI generation source and independently exercised against stripe-mock.
- In-repo conventions (templates, idioms, test patterns, ExDoc mechanics): **HIGH** — every claim is a direct file read with line references; the two counted claims (19 `refute function_exported?` files; 42 docs warnings) were re-counted.
- Architecture / plan shape: **HIGH** — inherited from CONTEXT.md's 29 reconciled decisions; this research verified their factual premises rather than re-deciding them.
- Pitfalls: **HIGH** — Pitfall 1 is traced to specific lines (`list.ex:262-263`, `list.ex:283-295`); Pitfall 3 quotes the spec verbatim; Pitfall 4 was reproduced by running the commands.
- Live-Stripe behavior: **MEDIUM** (assumption A1) — no live key available; spec + mock triangulation is the project's standing posture.

**Research date:** 2026-07-28
**Valid until:** 2026-08-27 (30 days — the Stripe Entitlements surface is small and stable; re-check `spec3.sdk.json` if the phase slips past a Stripe API version bump)
