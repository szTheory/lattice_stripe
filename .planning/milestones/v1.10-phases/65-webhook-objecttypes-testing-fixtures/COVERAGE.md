# API Coverage — Stripe webhook object-type catalog + public testing-fixture surface

> Full coverage by default. Opt-outs are explicit, reasoned decisions.
>
> Scope: the two surfaces Phase 65 owns — (a) rows in `lib/lattice_stripe/object_types.ex`
> `@object_map`, the wire-`"object"`-string → module dispatch registry, and (b) the public
> `LatticeStripe.Testing.Fixtures.*` surface that ships in the Hex tarball (`mix.exs:325`
> `files: ["lib", ...]`).
>
> Phase 65 adds **no** Stripe verb, request, endpoint, or dependency. The "capabilities"
> enumerated below are registry rows and published fixture modules, not HTTP operations.
>
> Measured at plan time: `@object_map` holds **48** rows; all four OBJ-01 keys currently return
> `:error` from `fetch_module/1`. Post-phase count is **52**.
> (65-RESEARCH.md says 47 → 51; the measured count is 48 → 52. See 65-06 housekeeping.)

## OBJ-01 — webhook object-type registry rows

| capability | decision | reason |
|---|---|---|
| `entitlements.active_entitlement` → `Entitlements.ActiveEntitlement` | INTEGRATE | |
| `entitlements.active_entitlement_summary` → `Entitlements.ActiveEntitlementSummary` (no `:id`) | INTEGRATE | |
| `billing.meter_event` → `Billing.MeterEvent` | INTEGRATE | |
| `billing.meter_event_summary` → `Billing.MeterEventSummary` | INTEGRATE | |
| `fetch_module/1` resolution for all four (gates `Webhook.fetch_related_object/3`) | INTEGRATE | |
| `billing.meter_error_report` registry row | OPT-OUT | Structurally unregistrable. `maybe_deserialize/1` dispatches on `%{"object" => _}` (`object_types.ex:73`); this payload is v2 thin-event `data` and carries **no** `"object"` key, so the row would be a dead key a future contributor assumes works (Phase 64 F-13 / D-14, one-way). Decoded explicitly via `Billing.MeterErrorReport.from_event/1`. Absence already locked by `object_types_test.exs:217-227`. |
| `map_size(object_map()) == 52` count assertion | OPT-OUT | Brittle against Phase 66's `product.feature` row. 65-RESEARCH.md § Pitfall 7 explicitly recommends against it. Key-level `fetch_module/1` assertions cover the same ground without the false failure. |
| `@known_fields` on `meter_event.ex` for the Drift tool | OPT-OUT | Q3, reversible. `from_map/1` does not consume `@known_fields`; a decorative attribute is a worse trap than the drift noise. Drift runs in its own scheduled workflow (`drift.yml`), never in PR-gating `ci.yml`. `/gsd-quick` follow-up if the noise becomes annoying. |
| Auto-registration by scanning modules for `from_map/1` | OPT-OUT | Would auto-register `MeterErrorReport` — resurrecting exactly the dead key D-14 forbids. Explicit rows are the mitigation, not an inconvenience. |

## OBJ-02 — entitlement + meter public fixtures

| capability | decision | reason |
|---|---|---|
| `Testing.Fixtures.Entitlements.active_entitlement_json/1` | INTEGRATE | |
| `Testing.Fixtures.Entitlements.active_entitlement_summary_json/1` (no-`id` summary) | INTEGRATE | |
| `Testing.Fixtures.Entitlements.feature_json/1` | INTEGRATE | |
| `Testing.Fixtures.Entitlements.active_entitlement_list_json/2` | INTEGRATE | |
| `Testing.active_entitlement/1` typed wrapper | INTEGRATE | |
| `Testing.active_entitlement_summary/1` typed wrapper | INTEGRATE | |
| meter-event fixture + `Testing.meter_event/1` wrapper | INTEGRATE | |
| meter-event-summary fixture + `Testing.meter_event_summary/1` wrapper | INTEGRATE | |
| meter-error-report fixture (public) | INTEGRATE | OBJ-02 says "meter objects"; its 25-line verbatim-from-Stripe provenance comment is worth publishing. |
| `Testing.meter_error_report/1` typed wrapper | INTEGRATE | **Reversed post-verification (UAT checkpoint 2).** The original opt-out rationale was factually wrong: it asserted OBJ-02 was satisfied "for every fixture that has a `from_map/1` to wrap", but `LatticeStripe.Billing.MeterErrorReport.from_map/1` exists at `meter_error_report.ex:220` and decodes the promoted fixture into a populated struct. The surviving half of the argument — that `:meter` can only be filled by `from_event/1`, because the meter id lives in the event envelope and never in `data` (F-13/D-14) — is real, and is now carried in the wrapper's own `@doc` and asserted by `testing_test.exs`, which is a stronger guarantee than omitting the wrapper. Completeness is enforced by `test/lattice_stripe/testing/wrapper_completeness_test.exs`, which machine-checks each opt-out *reason*: a `:no_from_map` claim now runs `refute function_exported?/3` and would have failed this row on the day it was written. |
| `Meter`, `MeterEventAdjustment`, `MeterEventStreamSession` fixtures | OPT-OUT | Q1 resolved as `flat-three` and now locked mechanically: `priv/api/current.txt` records the exact public surface, so promoting these three later is a visible, reviewed diff rather than a silent expansion. OBJ-02 names neither; they stay private in `test/support/fixtures/`. |
| `Testing.Fixtures.Entitlements.Feature` typed wrapper (`Testing.feature/1`) | INTEGRATE | **Reversed post-verification (UAT checkpoint 2).** Added rather than deferred: `Entitlements.Feature.from_map/1` exists at `feature.ex:288`, and `entitlements.feature` is deliberately absent from `@object_map`, so this wrapper is the only typed decode path the public surface offers for the object. The addition is additive and non-breaking, and it removes a scope-reading question that would otherwise have needed a human to adjudicate. |

## OBJ-03 — core-billing public fixtures

| capability | decision | reason |
|---|---|---|
| `Testing.Fixtures.Customer.customer_json/1` + `Testing.customer/1` | INTEGRATE | |
| `Testing.Fixtures.Subscription.subscription_json/1` (+ `with_items/paused/canceled`) + `Testing.subscription/1` | INTEGRATE | |
| `Testing.Fixtures.PaymentIntent.payment_intent_json/1` + `Testing.payment_intent/1` | INTEGRATE | |
| `Testing.Fixtures.Invoice.invoice_json/1` + `Testing.invoice/1` | INTEGRATE | Newly authored — no invoice fixture module exists anywhere in the repo. Body lifted verbatim from `invoice_test.exs:16-61`. |
| Duplicating rather than moving the three existing private core-billing fixtures | OPT-OUT | Pending Q2 checkpoint (65-03). The `Dispute` duplication is already an unlocked drift hazard (two byte-identical files, no lock); `TaxId` is the move precedent. Five caller lines is cheaper than a permanent drift surface. |
| `invoice_json_for_telemetry/1` (`telemetry_test.exs:780`) promotion | OPT-OUT | A deliberately reduced shape for telemetry assertions, not a canonical wire fixture. Publishing two competing invoice fixtures would make the canonical one ambiguous. |
| Fixtures for billing objects beyond the four OBJ-03 names | OPT-OUT | OBJ-03 enumerates exactly subscription, invoice, customer, payment_intent. Broader resource-family breadth is barred by the v1.x stop signal in STATE.md. |

## Not an external-API integration

Phase 65 issues no new HTTP request and defines no new endpoint. It does, as a documented and
accepted side effect, flip `Webhook.fetch_related_object/3` from `{:error, {:unknown_object_type,
t}}` to "issue `GET related_object.url`" for the four newly-registered types — `@object_map` has
two consumers and the phase brief describes only one (65-RESEARCH.md § Pitfall 1, Phase 47 D-05).
That behavior change is intentional; see threat `T-65-04` in each plan's `<threat_model>`.

**Now test-locked (UAT checkpoint 3).** A paired characterization test in
`test/lattice_stripe/webhook/fetch_test.exs` pins both halves: a registered-but-non-retrievable
type issues exactly one doomed GET, and an unregistered type still short-circuits with zero HTTP.
The pair makes it a characterization of the registry's dual role rather than a fact about one
object type. A triage invariant in `test/lattice_stripe/object_types_test.exs` partitions all 52
`@object_map` keys, so a future row must state its retrievability explicitly instead of silently
flipping fetch behaviour.

Adding an `{:error, {:not_retrievable, _}}` branch stays deferred (deferred-items.md item 2), on
semver grounds rather than effort: widening a documented return union breaks adopters whose `case`
is exhaustive over the three published variants, and Elixir does not warn on a non-exhaustive
`case`. The characterization test makes implementing it later a loud, deliberate change.
