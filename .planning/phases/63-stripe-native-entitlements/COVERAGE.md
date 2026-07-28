# API Coverage — Stripe Entitlements

> Full coverage by default. Opt-outs are explicit, reasoned decisions.
>
> Scope: the `/v1/entitlements/*` surface as enumerated in Stripe's `spec3.sdk.json`
> (`info.version = 2026-06-24.dahlia`, parsed 2026-07-28 — see `63-RESEARCH.md` § Standard Stack →
> Wire Surface). Exactly four entitlement paths exist; there are no others.

| capability | decision | reason |
|---|---|---|
| `active_entitlements.list` — `GET /v1/entitlements/active_entitlements` | INTEGRATE | |
| `active_entitlements.list` — required `customer` filter | INTEGRATE | |
| `active_entitlements.list` — `limit` / `starting_after` / `ending_before` | INTEGRATE | |
| `active_entitlements.list` — auto-pagination (`stream!/3`) | INTEGRATE | |
| `active_entitlements.list` — `expand` (e.g. `data.feature`) | INTEGRATE | |
| `active_entitlements.retrieve` — `GET /v1/entitlements/active_entitlements/{id}` | INTEGRATE | |
| `active_entitlement.feature` — expandable decode to a typed feature | INTEGRATE | |
| `active_entitlement.lookup_key` — typed struct field | INTEGRATE | |
| `features.create` — `POST /v1/entitlements/features` | INTEGRATE | |
| `features.retrieve` — `GET /v1/entitlements/features/{id}` | INTEGRATE | |
| `features.update` — `POST /v1/entitlements/features/{id}` | INTEGRATE | |
| `features.list` — `GET /v1/entitlements/features` | INTEGRATE | |
| `features.list` — auto-pagination (`stream!/3`) | INTEGRATE | |
| `features.list` — `archived` filter | INTEGRATE | |
| `features.list` — `lookup_key` filter | INTEGRATE | |
| `active_entitlement_summary` — typed deserialization (`from_map/1`) | INTEGRATE | |
| `active_entitlement_summary.entitlements` — typed nested list + cursor state | INTEGRATE | |
| `entitlements.active_entitlement_summary.updated` — canonical re-fetch helper | INTEGRATE | |
| `features.delete` | OPT-OUT | No such endpoint. Spec lists `/v1/entitlements/features` and `/{id}` as `[get, post]`; `DELETE` 404s against stripe-mock v0.199.0 (F-06). Locked by `refute function_exported?(Feature, :delete, 2)`. |
| `features.archive` / `features.unarchive` as explicit verbs | OPT-OUT | Stripe ships no `/archive` endpoint; archiving is `update/4` with `active: false`. Explicit verbs mirror explicit endpoints; `update` takes the wire field (D-08). See the `## Archiving` moduledoc. |
| `retrieve_by_lookup_key` convenience verb on `Feature` | OPT-OUT | No Stripe endpoint backs it; it would have to invent 0-result and >1-result semantics Stripe does not define. The `%{"lookup_key" => ...}` list filter is a documented moduledoc recipe instead (D-12). |
| `active_entitlement_summary` via HTTP retrieval | OPT-OUT | No path serves it — the object carries no `x-resourceId` in the spec and is webhook-only by construction (F-03). Shipped as decode-only. |
| `GET /v1/customer/{cus}/entitlements` (the inlined summary `url`) | OPT-OUT | Not among the four spec paths; callability not established (F-05). `stream_entitlements!/3` re-fetches against `/v1/entitlements/active_entitlements`; the nested `url` is rewritten to it (D-03/D-04). |
| per-request `entitled?(customer, feature)` gate helper | OPT-OUT | Not a Stripe endpoint. An authz check that makes a network call fails **open** under partition. Ships the reconciler plus a local fail-closed gate recipe instead, documented in three surfaces (D-19). |
| `ObjectTypes` registry rows for `entitlements.*` wire objects | OPT-OUT | Phase 65 owns `lib/lattice_stripe/object_types.ex` (OBJ-01). Phase 63 types at the resource layer via `Stream.map(&from_map/1)`, so it has no code dependency on the registry (F-09). |
| public `LatticeStripe.Testing.Fixtures` for entitlement objects | OPT-OUT | Phase 65 (OBJ-02) promotes them by move + module rename. Phase 63 ships private `LatticeStripe.Test.Fixtures.Entitlements` with the exact function names Phase 65 will consume (D-27, correction C-01). |
| `product_feature` attach / list / delete (`/v1/products/{id}/features`) | OPT-OUT | Phase 66 (PROD-01). Not an `/v1/entitlements/*` path; `Product.Feature` is the attachment object, `Entitlements.Feature` is the definition (D-15). |
| `mix lattice_stripe.check_drift` enrolment for `entitlements.*` | OPT-OUT | Drift enrolment derives from `ObjectTypes.object_map()`, which Phase 65 owns. The drift job files an issue rather than blocking CI, and already exits 1 for unrelated reasons — not a Phase 63 gate. |
