# Phase 64: Meter Event-Summary Reads - Context

**Gathered:** 2026-07-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the **metering read surface**. LatticeStripe ships all four meter WRITE surfaces and zero reads; accrue can push usage and never read totals back.

- `LatticeStripe.Billing.MeterEventSummary` — `list/4`, `list!/4`, `stream!/4`, `from_map/1` over `GET /v1/billing/meters/:id/event_summaries` (MTR-01, MTR-02)
- `LatticeStripe.Billing.MeterErrorReport` + three nested value objects — the typed `data` payload of the `v1.billing.meter.error_report_triggered` v2 thin event (MTR-03)
- `guides/metering.md` — a new **"Reading usage back"** section, a new **"The payload contract"** section, and **three corrections to already-shipped prose that is factually wrong** (MTR-04)

**Out of scope (fenced):** any new metering write surface (all four already ship; roadmap fence); `ObjectTypes` registration + public `Testing.Fixtures` (Phase 65); dimension-grouped reads (preview-gated by Stripe — see D-27); the `groups_for_modules` backlog (Phase 67).

**⚠ This phase's brief contained three false premises.** They were caught by verification against Stripe's OpenAPI spec, a locally-run stripe-mock v0.199.0, and direct execution against this repo at HEAD `578f7b8`. See F-01, F-02, F-11. Two written requirements and two roadmap success criteria are amended as a result (D-01, D-13).

</domain>

<decisions>
## Implementation Decisions

Four gray areas were researched by dedicated subagents (repo source reads + live Stripe API/OpenAPI verification + stripe-mock probes + all seven official Stripe SDKs + adjacent metering platforms + the `prompts/` commissioned research), then reconciled here.

**Three reconciliations diverge from a researcher's recommendation or from a Phase 63 decision and are marked ⚠ — the divergence rationale is load-bearing and must not be silently "corrected" back during planning.**

### Verified facts that reframe the phase

Each is marked **VERIFIED** (with the source that settles it) or **ASSUMED**. Per this project's standing rule, **re-verify F-01…F-20 against source and live Stripe docs before implementing** — planning artifacts can be coherent and still miss code truth (the v1.5 `tolerance: 0` bug was found by source verification, not by a green suite).

**The event-summary object**

- **F-01 — VERIFIED — the object HAS a required top-level `id` (`mtrusg_`), so MTR-02 is implementable exactly as written.** Schema `required: ["aggregated_value","end_time","id","livemode","meter","object","start_time"]`; stripe-mock returns `"id": "mtrusg_123"`. `List.stream!/2` derives its cursor by matching `%{"id" => id}` on raw maps (`list.ex:283-295`) — works unmodified. **No divergence from Phase 63's D-05 is needed.** (This was the phase's make-or-break unknown.)
- **F-02 — VERIFIED — the object has exactly 7 fields and NO `customer` field.** `id`, `object`, `aggregated_value`, `start_time`, `end_time`, `meter`, `livemode`. No `created`, no `metadata`. `x-expandableFields: []`. **You filter *by* customer but the returned struct never says which customer it belongs to** — a reconciler holding a list of summaries has lost the association unless it keeps it out of band. Genuinely surprising; moduledoc-mandatory.
- **F-03 — VERIFIED — `customer`, `start_time`, `end_time` are ALL required query params.** Confirmed twice: `required: true` in the spec, and reproduced against stripe-mock, which 400s in sequence (`'customer' is required` → `'start_time' is required` → `'end_time' is required`). `limit` range 1–100, **default 10**. `value_grouping_window` enum is exactly `["day","hour"]`.
- **F-04 — VERIFIED — exactly one path exists: `GET /v1/billing/meters/{id}/event_summaries`.** There is no top-level `/v1/billing/meter_event_summaries` and no `GET /{summary_id}`. **Dual-mode (`tax_id.ex` style) is structurally impossible, and there is no `retrieve/3` to ship.**
- **F-05 — VERIFIED — `aggregated_value` is a JSON `number` (float), not an integer.** stripe-go types it `float64`. Note the asymmetry: reads return a float, writes take a decimal *string* (F-15). Cross-link the two moduledocs.
- **F-06 — VERIFIED — the alignment rule, verbatim from the spec.** *"For hourly granularity, start and end times must align with hour boundaries… For daily granularity, start and end times must align with **UTC day boundaries (00:00 UTC)**."* Separately, and applying to **every** query including the no-window case, both timestamps are *"Must be aligned with **minute** boundaries."* Timezone is pinned to UTC — not account, not customer.
- **F-07 — VERIFIED — Stripe's own error code for a misaligned timestamp is UNDOCUMENTED.** Not in the API errors reference, not in any SDK, not in any issue. **This is the strongest argument for a client-side guard: we cannot improve the 400 after the fact, only prevent it.**
- **F-08 — VERIFIED — the spec contradicts itself on the window's end.** The `end_time` query param and the `end_time` object field both say *(exclusive)*; `aggregated_value`'s own description on the same object says *"within `start_time` (inclusive) and `end_time` (**inclusive**)"*. Two of three say exclusive. All three ship verbatim into every SDK's generated docstrings. **Document the ambiguity; assert neither.**
- **F-09 — VERIFIED — eventual consistency, unbounded and unmeasurable.** Spec: *"meter event summaries provide an eventually consistent view of the reported usage."* There is **no freshness field** on the v1 object and **no published SLA** — a caller cannot tell how stale a summary is. Stripe's preview successor adds `refreshed_at`, which is Stripe conceding the gap.
- **F-10 — VERIFIED — stripe-mock v0.199.0 serves this path and validates required/enum constraints, but returns one synthetic item, ignores `limit`/`starting_after`, accepts unaligned timestamps, and returns a literal placeholder `url` (`/v1/billing/meters/id_123/event_summaries`) that does not echo the requested meter id.** It cannot prove pagination or alignment. **Do not assert on `resp.data.url` in the integration test.**

**The error report**

- **F-11 — VERIFIED — there is no `billing.meter_error_report` object and no `validation_errors` field. Anywhere.** Zero hits across `spec3.json`, `spec3.sdk.json`, `spec3.beta.sdk.json`, `spec3.private_preview.sdk.json`, the published `stripe` npm tarball, and `stripe-go`. **MTR-03's literal text is unsatisfiable.** The real arrays are `data.reason.error_types[]` → `sample_errors[]`.
- **F-12 — VERIFIED — it is a v2 thin event, and `data` is a *fetched* attribute.** Stripe's event-types reference classifies `data` and `changes` as "Fetched Attributes"; the webhook body carries only `id/object/context/created/livemode/type/related_object/reason`. **All seven official SDKs encode this structurally — their `…EventNotification` classes have no `data` member at all.** You must call `Webhook.fetch_event/3`.
- **F-13 — VERIFIED — `ObjectTypes.maybe_deserialize/1` structurally cannot handle it.** Dispatch is `def maybe_deserialize(%{"object" => object_type} = map)` (`object_types.ex:73`, read directly). The `data` payload has **no `"object"` key**, so it falls through to the raw-map clause. **Phase 65's OBJ-01 row for `billing.meter_error_report` is a dead key by construction** — see D-14. This is Phase 63's F-01 all over again.
- **F-14 — VERIFIED — the meter id is NOT in `data`.** It lives in `event.related_object.id`. A struct built only from `data` cannot answer *"which meter is broken?"* — the first question an operator asks.
- **F-15 — VERIFIED — `sample_errors[].request.identifier` is the HTTP idempotency key, not `MeterEvent.identifier`.** Spec description: *"The request idempotency key."* And `client.ex:169` auto-generates an `idk_ltc_`-prefixed UUID v4 for POSTs when `:idempotency_key` is omitted — **so by default the only correlation key in the error report maps to nothing in the adopter's database.** This is the single highest-value line this phase can write.
- **F-16 — VERIFIED — `code` is an Open Enum** (`x-stripeEnum: {kind: "open"}`) with 10 current values. Stripe has already retired one code that `guides/metering.md` still documents.
- **F-17 — VERIFIED — a sibling event shares the payload byte-for-byte.** `v1.billing.meter.no_meter_found` has an identical `data` shape; its only difference is that `related_object` is absent. One struct decodes both.
- **F-18 — VERIFIED — timestamps are RFC3339 strings, not Unix integers** — unlike every other v1 object in this library. Direct in-repo precedent for documenting this asymmetry: `event_notification.ex:33-38`. (Note stripe-php types them `int`, which is wrong; do not copy.)

**The encoder (MTR-04)**

- **F-19 — VERIFIED by direct execution at HEAD — the encoder round-trips arbitrary custom `payload` dimensions and decimal strings byte-exact. There is NO defect and NO whitelist.** Path inspected end to end: `meter_event.ex:67-83` (two presence checks, `params` passed untouched) → `client.ex:699-703` → `form_encoder.ex:19-92`, a generic recursive flattener with no allowlist. `"0.001"`, `"0.000001"`, and a 36-digit decimal all survive verbatim. **MTR-04 does NOT become a code task.**
- **F-20 — VERIFIED by direct execution — but three things a reader will infer are FALSE, and one is already shipped as prose.**
  1. **`guides/metering.md` pitfall #4 is wrong for v1.** It says *"The payload value must be a string (`"5"`, not `5`). Integers trigger `meter_event_invalid_value`."* Verified: `payload[value] => 5` and `=> "5"` produce **byte-identical** bodies (`a == b` → `true`). The string rule is real but applies **only to the v2 JSON stream** (`meter_event_stream.ex:186`). This text is v1.1-vintage (`git log -S "Integers trigger"` → `e5966f6`, *"v1.1: Accrue unblockers"*) — **accrue pins `~> 1.1` and read this exact sentence.**
  2. **Nested maps/lists in `payload` are rejected with a synchronous 400** — `value is not a string (Kind: map)`. Our encoder happily produces `payload[meta][a]=b`, so **the SDK lets you build a request Stripe refuses.** Documented nowhere today.
  3. **Elixir floats are mangled, and Elixir's threshold is the narrowest in the ecosystem.** `to_string/1` flips to scientific notation at **`1.0e-5`** (Node: `1e-6`; and stripe-go uses `strconv.FormatFloat(v,'f',…)`, whose `'f'` verb never emits exponent form). `0.1 + 0.2` → `0.30000000000000004`. **`0.00001` is a plausible per-token cost — this is not a corner case, and `guides/metering.md`'s own headline recipe calls `to_string(value)`.**

### Naming & namespace — ⚠ overrules two written requirements

- **D-01 ⚠ — the modules are `LatticeStripe.Billing.MeterEventSummary` and `LatticeStripe.Billing.MeterErrorReport`. FLAT, at depth 2, named after the wire `object` string. This overrules MTR-01, MTR-02, and ROADMAP SC#1/#2, which all specify `Billing.Meter.EventSummary`.**

  **⚠ Divergence rationale (do not revert).** Three independent researchers converged on this from different evidence, two of them unprompted:

  1. **Verified by me directly: zero of the ~50 request-owning modules in this repo sit at depth 3.** All 12 nested subdirectories contain only `from_map/1` value objects. `Billing.Meter.EventSummary` would be the **first depth-3 module in the repo to own a `%Request{}`**.
  2. **Within `"Billing Metering"` specifically, the rule is sharper: depth 3 *means* value object.** Every depth-3 name in that group (`Meter.ValueSettings`, `MeterEventAdjustment.Cancel`, `MeterEventStream.Session`) is a non-request-owning decoder; every request-owning module (`Meter`, `MeterEvent`, `MeterEventAdjustment`, `MeterEventStream`) is depth 2. Nesting would actively mislead.
  3. **Both existing parent-scoped child resources are flat and wire-named.** `TransferReversal` serves `/v1/transfers/:id/reversals` — URL segment `reversals`, wire object `transfer_reversal`, module named after the **wire object** — and already ships the exact `list/4` + `stream!/4` shape MTR-01 asks for. `ExternalAccount` (`/v1/accounts/:id/external_accounts`) is the second. **Parent-scoping is expressed in the signature, not the module name.**
  4. **Stripe's own machine-readable codegen directive says `{class_name: "MeterEventSummary", in_package: "Billing"}`** — not `in_package: "Billing.Meter"`. All six official SDKs and the Elixir peer `stripity_stripe` implement it as `Billing::MeterEventSummary`.
  5. **The ObjectTypes rule Phase 65 will apply is already 43/43** on the mechanical transform *dot = module boundary, underscore = CamelCase* (`billing_portal.session` → `BillingPortal.Session`; `test_helpers.test_clock` → `TestHelpers.TestClock`). The only exceptions are the six `*line_item` rows, which exist because bare `LineItem` is ambiguous across six types — a problem `MeterEventSummary` does not have.
  6. **Phase 63's D-16 argues *for* this, not against.** D-16 kept the redundant-looking `Entitlements.ActiveEntitlement` precisely to preserve *"the wire↔module mental map Phase 65 depends on."* The wire string here is `meter_event_summary`, not `meter.event_summary`.
  7. **ROADMAP already contradicts itself.** Its Phase 64 build constraint says to follow `tax_id.ex` + `transfer_reversal.ex` (both flat) while SC#1 says nested.

  **Stated fairly, the case against:** MTR-01/02 and SC#1/#2 say nested, in writing. But nothing has shipped, module names are a **one-way door**, and the cost of amending is four text edits versus a major version bump. → **Reversibility:** one-way — the atom `Elixir.LatticeStripe.Billing.MeterEventSummary` becomes a semver contract at the v1.10 tag. A `defdelegate` shim is possible but permanently doubles the public surface and appears twice in every HexDocs search. **This is the phase's only one-way door.**

- **D-02 — the required planning-artifact edits, made as part of this phase's context commit** (Phase 63's D-27 precedent: the comment alone will not survive; the artifact edit is the real deliverable):
  - `.planning/REQUIREMENTS.md:20-21` — MTR-01/MTR-02 → `LatticeStripe.Billing.MeterEventSummary`
  - `.planning/REQUIREMENTS.md:22` — MTR-03 → `reason.error_types` (F-11)
  - `.planning/ROADMAP.md:118-120` — SC#1/#2/#3 likewise
  - `.planning/ROADMAP.md` Phase 65 OBJ-01 — strike `billing.meter_error_report` (D-14)

  Without these, a planner will faithfully implement the wrong name and the one-way door closes on the wrong side.

- **D-03 — `MeterErrorReport`'s sub-structs nest at depth 3, and that reinforces the rule rather than muddying it.** `Billing.MeterErrorReport.{Reason, ErrorType, SampleError}` own no `%Request{}` — they are exactly the shape of `MeterEventAdjustment.Cancel` and `MeterEventStream.Session`. `MeterErrorReport` itself is flat for a *different* reason than `MeterEventSummary`: the summary is flat because it **is a resource**; the error report is flat because it **is not a resource at all** — no endpoint, no `id`, no `object` string. Document both reasons; they are the same rule applied twice.

- **D-04 — append all five modules to the existing `"Billing Metering"` group in `mix.exs:179-190`. No new group.** Unlike Phase 63's `Entitlements:` (a new Billing sub-product, D-17), these extend a family that already has its own group of ten. Fifteen is comfortably under the 22 that made `Billing:` a problem. Source order follows the family's lifecycle — *define → write → read → diagnose*. → **Reversibility:** reversible — sidebar only, one commit.

  **No `Billing.Meter.event_summaries/4` convenience delegator.** stripe-java#1852 is Stripe's own docs advertising exactly that method; it didn't exist, and Stripe's reply was *"the docs is wrong."* Coherent with the existing "no `Transfer.reverse/4` delegator" precedent. Locked structurally (D-31).

### `MeterEventSummary` surface & guards

- **D-05 — signature: `list(client, meter_id, params \\ %{}, opts \\ [])`, always parent-scoped.** Matches all four in-repo parent-scoped precedents, matches the ROADMAP's literal `list/4`, and matches **5 of 6** official SDKs (only stripe-go puts the id in a params struct). Rejected: dual-mode (F-04 makes it impossible); positional required args (`start_time`/`end_time` are adjacent same-typed integers — silently swappable, and every future optional param becomes a new arity forever).

- **D-06 ⚠ — keep `params \\ %{}`. Do NOT extend Phase 63's D-14 "no default" rule from `create/3` to `list/4`.**

  **⚠ Divergence from a plausible reading of D-14.** D-14 said a defaulted empty map "could only ever raise." But **the just-shipped sibling contradicts it**: `Entitlements.ActiveEntitlement.list/3` (`active_entitlement.ex:101`) has a required `customer` and keeps `params \\ %{}`. Dropping the default here would make two consecutive phases' list functions differ for no reader-visible gain, and would cost the uniform `list/2..4` shape every other module has. **Leave D-14 scoped to `create`.**

- **D-07 — final surface:** `list/2..4`, `list!/2..4`, `stream!/2..4`, `from_map/1`. **No `retrieve/3`** (F-04 — no `GET /{summary_id}`), no create/update/delete (GET only), no non-bang `stream` (house rule). Include the D-07-style idempotency clause `def from_map(%__MODULE__{} = s), do: s`. **No custom `Inspect`** — coherent with Phase 63's D-14 (PII-only); this object carries none and has no `customer` field at all (F-02).

- **D-08 — three `Resource.require_param!/3` guards, first-failure, D-10 message format verbatim.** `customer` → `start_time` → `end_time`. Three is already the house ceiling (`Billing.Meter.create/3` has exactly three). Exact strings, note the vowel on the third, matching `Meter.create/3`'s existing `"requires an event_name param"`:

  ```
  LatticeStripe.Billing.MeterEventSummary.list/4 requires a customer param
  LatticeStripe.Billing.MeterEventSummary.list/4 requires a start_time param
  LatticeStripe.Billing.MeterEventSummary.list/4 requires an end_time param
  ```
  (and the `stream!/4` equivalents). Rejected collect-all-missing: it requires inventing a **new** message format, breaking the D-10 verbatim lock shared by `Meter.create/3`, `MeterEvent.create/3`, and `ActiveEntitlement.list/3`, to save ≤2 keystrokes. Note in `@doc` that `require_param!/3` checks **key presence, not emptiness**, and reads **string keys only**.

  **Worth knowing:** **not one of the six official SDKs validates any of this client-side** — stripe-ruby's list-params initializer actively defaults `customer`/`start_time`/`end_time` to `nil`. This guard makes LatticeStripe the only SDK in any language that catches it before the wire. → **Reversibility:** cheapest at birth — adding later breaks anyone catching the 400; removing later is non-breaking.

- **D-09 ⚠ — add a private `validate_id!/2` on `meter_id`. This diverges from Phase 63's D-11.**

  **⚠ Divergence rationale (do not revert).** D-11 rejected `id in [nil, ""]` clauses as "5 of 55 top-level modules — a minority, not a convention." **I re-verified the 5-of-55 count and it is correct.** Diverge anyway, on four grounds:
  1. **Wrong denominator.** Among modules that list a *child collection under a parent id* — MTR-01's exact structural class — there are four, and **two of four raise on empty** (`external_account.ex:272-276` via a private `validate_id!/2`; `transfer_reversal.ex` via clauses). A coin flip, not a rejected minority.
  2. **D-11's stated reason doesn't apply.** Its concern was a minority pattern masquerading as a house rule *in a flagship new module*. This is a leaf module in an established family — and it is **already** a function that raises `ArgumentError` three times pre-network (D-08). The id check is the fourth member of a set that exists regardless. It is coherence, not novelty.
  3. **Different mechanism.** D-11 rejected extra *clauses*; this is the `external_account.ex` private-helper form — 1 line per function instead of ~7, composes with default args for free, and D-11 did not consider it.
  4. **Observed, not hypothesised.** stripe-go ships exactly this bug on exactly this endpoint: `FormatURLPath(..., stripe.StringValue(listParams.ID))` turns a nil id into `""`, producing `/v1/billing/meters//event_summaries` and a 404 with no hint the id was missing.

  Exact message, carrying the arity so all four `ArgumentError`s from `list/4` share one grammar: `LatticeStripe.Billing.MeterEventSummary.list/4 requires a non-empty meter id`.

- **D-10 — GUARD-04: a pre-network alignment raise in `LatticeStripe.Billing.Guards`, plus a moduledoc section. NO auto-aligning helper.**

  `guards.ex` already opens with a numbered GUARD-01…GUARD-03 discoverability block; add the GUARD-04 line. Arity 2 (`params, fun`) because it is called from two functions and the message must name the right one. Divisors: no window → `60`; `"hour"` → `3_600`; `"day"` → `86_400`.

  **Two escape hatches are mandatory, both forward-compat:** unrecognised `value_grouping_window` values **pass through unguarded** (Stripe already extended this enum once, adding `"day"` in stripe-python 10.1.0, 2024-06), and absent/unparseable timestamps pass through (`require_param!` and Stripe's own type validation own those).

  **Why a guard and not docs alone:** the rule is machine-readable and exact (F-06) so there are zero false positives; Stripe's error contract is undocumented (F-07) so we cannot improve the 400 after the fact; the natural input source is always wrong (`subscription.current_period_start` derives from `billing_cycle_anchor` and lands on an arbitrary second, violating even the minute rule); and there is direct in-repo precedent in `Guards.check_meter_value_settings!/1`.

  **Why no auto-aligning helper — rejected on domain grounds, corroborated externally.** Rounding *changes what the query means*: floor the start and you include pre-period usage; ceil it and you drop usage. That is a business decision. **Orb** auto-aligns to the customer's local midnight, so a 3-day UTC range silently yields **4** windows, and its `/events/volume` auto-widens to the containing hour so totals **over-count**. **Datadog** silently overrides an explicit `.rollup(60)`. Silent coercion is exactly the silently-wrong-number bug class this milestone exists to kill. The raise prints the arithmetic instead, which is the maximally-visible form of the same help at zero semver cost.

  → **Reversibility:** cheapest at birth, and **the design survives Stripe's own roadmap** — removing the guard later is non-breaking, and Stripe's preview successor drops the hour/day clause entirely (D-33).

- **D-11 — a dissent, recorded honestly.** The cross-ecosystem researcher recommended shipping snap helpers, while simultaneously establishing that *"any snapping must be explicit and visible in the return value, never silent."* Reconciled in favour of the guard; `align_window/2` is recorded as a deferred additive minor bump rather than dropped.

- **D-12 — correction to an earlier research claim, carried forward so it is not re-inherited as fact.** The guards researcher initially wrote that the alignment landmine bites *"~100% on first run."* That is an **inference** from the spec, **not an observation** — issue archaeology found zero public bug reports for this endpoint in any SDK tracker (most likely because adoption is low; StackOverflow and Reddit were unreachable to the tooling, so that angle is *unchecked*, not negative). **The mechanism is verified; the incidence is not. Do not state a 100% figure in the moduledoc.**

### `MeterErrorReport` — typed, four modules

- **D-13 ⚠ — MTR-03 is amended: there is no `validation_errors` field, and this is not a `%LatticeStripe.Event{}` on the v1 path.** Per the house doctrine (Phase 63's D-08: *name after the exact wire field*), the struct carries `reason`, never an invented `validation_errors`. **Silently renaming a wire field into the struct is the worst outcome available here** — it makes the module unsearchable against Stripe's docs.

- **D-14 ⚠ — strike `billing.meter_error_report` from Phase 65's OBJ-01.** F-13: `maybe_deserialize/1` dispatches on `%{"object" => _}`, and this payload has no `"object"` key, so the registry row is **unimplementable and would be a dead key** a future contributor assumes works. `MeterErrorReport.from_map/1` must be called **explicitly** from the webhook handler. The other four OBJ-01 keys are fine. Lock it with a `refute` (D-31).

- **D-15 — type it fully: `MeterErrorReport` + `.Reason` + `.ErrorType` + `.SampleError`.** ~90 lines across four files whose every field is `required` in the spec, i.e. near-zero churn. Grounds: Phase 63's D-02 reversibility asymmetry (raw → typed is breaking either way, so choose the branch with the additive future); **6 of 7 official SDKs give every level a dedicated named type** — the sole dissenter is stripe-php, which is exactly the raw-map shape this milestone exists to undo; the direct in-repo precedent `Tax.Calculation.tax_breakdown`; and the consumer snippet, which only reads well because of it.

  **Note one argument that evaporated:** the "free CheckDrift surveillance" case does **not** apply here. `Drift.@spec_url` points at `spec3.json`, which does not contain this schema at all, and `accumulate_resource_schema/2` only enrols schemas having `properties.object.enum`. Neither condition is met. Two of five arguments for typing are gone; the remaining three carry.

- **D-16 — `from_event/1` is the primary constructor; `from_map/1` is the low-level one.** `from_map/1` must exist (repo idiom, fixtures, tests) but leaves `:meter` nil, because the meter id is in `related_object`, not `data` (F-14) — and *which meter is broken* is the first on-call question. Make the asymmetry an **asserted contract**, not an accident (D-30).

- **D-17 — no `:id`, no `:object`, no `:livemode` on the struct.** This is event `data`, not an addressable resource. Coherent with Phase 63's F-02/D-26 (`ActiveEntitlementSummary` deliberately has no `:id`). Inventing any of the three would fake a field Stripe never sends.

- **D-18 — `code` stays `String.t()`. Do NOT atomize and do NOT whitelist.** Stripe marks it `kind: "open"`; stripe-go/java/dotnet keep it a string. Evidence against closing it: plaid-python's closed enum with `_check_type=True` **fails deserialization** on a new server value, and `stripity_stripe`'s closed `card_error_code` atom union has gone stale (14 atoms vs ~250 live codes). **Never `String.to_atom/1` on server-controlled input.** A whitelist-with-passthrough would produce a mixed `atom() | String.t()` type on a value set that demonstrably grows — Stripe has already retired a code this repo still documents.

- **D-19 — arrays default to `[]`, never `nil`** (Shopify/Twilio precedent; no Stripe SDK does this, and every one of them forces consumers to nil-guard). **Timestamps stay RFC3339 strings** — direct precedent at `event_notification.ex:33-38`. **`@known_fields` must use `~w[...]` square brackets** (see D-20). **No custom `Inspect`** — D-14 is PII-only, and the nearest counter-precedent (`EventNotification` hiding `:reason`) does not transfer, because here the idempotency key **is** the diagnostic payload and hiding it defeats the module's purpose.

- **D-20 — a real pre-existing bug found in passing; fix it in this phase.** `drift.ex:210` is `~r/@known_fields\s+~w\[([^\]]+)\]/s` — **square brackets only**. Verified: **18 files use `~w(` and 85 use `~w[`**; the 18 parse to an empty MapSet and produce a spurious *"every field is an addition"* drift entry. Includes `billing/meter.ex:43`. Two options — widen the regex, or normalise the 18 files. **Widening the regex is the fix** (it removes a whole class of silent miscount); normalising is cosmetic and would recur. Cheap, and this phase is the one that discovered it.

- **D-21 — no `list/retrieve/create`.** F-11/F-12: no endpoint serves this. Phase 63's F-03/D-26 again — *"not a gap to apologize for."*

### MTR-04 — docs, re-scoped

- **D-22 — VERDICT: MTR-04 stays a documentation plan. No encoder change, no production module change.** F-19 settles it: no defect, no whitelist. **But it is re-scoped from *"docs confirm X"* to *"docs correct a wrong claim, document four real constraints, and prove two of them with tests."*** Plan-count impact: unchanged, plus ~4 tests that fit inside existing files.

- **D-23 — do NOT patch `to_string/1` in `form_encoder.ex`.** Special-casing floats would be a silent cross-cutting behavior change across the whole library on the eve of a release, to guard against an input Stripe's own type system says shouldn't exist (`map[string]string`). **Recorded as a close call, honestly:** stripe-go deliberately uses `strconv.FormatFloat(v,'f',…)` and no reference SDK ships this hazard — LatticeStripe would be the only one, purely because Elixir's default stringifier is the most aggressive in the set. A reviewer could reasonably choose `float_to_binary(v, decimals: 12)` instead. **If they do, it must be a documented, tested behavior change — never a silent one.**

- **D-24 — fix the artifact that caused the bug, not just the docs around it.** accrue's own gap brief says it drops the host payload *"partly because the contract is unclear."* Three shipped artifacts taught that:
  1. **`guides/metering.md` pitfall #4** — factually wrong for v1 (F-20.1). **Rewrite** to name floats as the hazard and integers as safe-on-v1, with the v2-stream exception.
  2. **The "fire-and-forget" recipe (`metering.md:154-206`)** — hardcodes exactly `stripe_customer_id` + `value` with a `report/5` signature that has no dimension parameter. Accrue mirrored it precisely. **Add a dimension to the payload and a `dimensions \\ %{}` parameter**, and replace its `to_string(value)` call (which *is* the float footgun) with a pointer to the decimal rule.
  3. **`meter_event.ex:28-30`'s `@doc`** — *"customer-mapping key plus the numeric value"* is closed-set language. **Amend the `payload` bullet.**

  Also correct `### value_settings` (`metering.md:118-124`), which repeats the same wrong claim.

- **D-25 — placement: both surfaces, asymmetric — the full treatment in the guide, one corrected sentence plus an autolink in the `@doc`.**

  **On Phase 63's D-19:** D-19 argued three reader entry points are needed because *"one location will not hold."* That was about a **fence** (a prohibition), where a missed fence means doing the forbidden thing, so redundancy is load-bearing. MTR-04 is an **affordance**, so **D-19's reasoning does not transfer on its own terms.** It earns duplication anyway for a stronger reason: **the miscommunicating artifact is the `@doc` itself** (D-24.3), so fixing only the guide leaves the cause in place. **This is targeted repair of specific misleading text — explicitly not D-19-style triplication.**

- **D-26 — NO new docs-truth grep lock. Zero.** Prove it with tests instead.

  Phase 63's D-25 budgeted "three locks, no more" for prose greps; **Phase 63 spent that budget, Phase 64 should spend zero.** The failure mode here is *"the prose says something false"* — and a grep is **structurally incapable** of catching that: pitfall #4 has been present-and-false since v1.1 and no lock noticed. Per D-23 ("structural over grep"), an encoding test asserts the **behavior the prose describes**. Note the asymmetry with Phase 63 that justifies diverging: D-19.1's entitlements lock guarded an **absence**, which is ungreppable structurally except via `refute function_exported?`, hence its paired prose lock. MTR-04's claim is a **behavior**, and behaviors are what tests are for.

  **Exception — structural config, not prose:** extend the existing ExDoc placement assertion in `docs_truth_test.exs` to cover Phase 64's new modules (a file in a group but absent from `extras:` is silently dropped). That is the entitlements precedent and is not a prose grep.

- **D-27 — the honest scope limit, and it belongs in `guides/scope.md`: on the GA API you CANNOT read usage back grouped by a custom dimension.** Verified four ways: the summary object has no `dimensions` field; `group_by=region` → 400 *"additional properties are not allowed"*; `dimension_payload_keys` on meter create → 400; and the canonical meters/configure docs page mentions dimensions nowhere. Dimension grouping exists **only in preview** (`spec3.private_preview.sdk.json` plus a separate Meter Usage Analytics API).

  **So the phase JTBD as briefed — *"read totals back per dimension"* — is not deliverable on the GA API.** Dimensions are **write-only today**: Stripe stores them, you cannot group by them. Workarounds are one meter per dimension value, or your own store. **This is the rule that saves a Phase-64 adopter a wasted week, and no other SDK's docs state it.**

  **⚠ What does NOT belong in scope.md:** the roadmap's *"do NOT add new metering write surfaces"* fence. That is an internal **build constraint** — all four writes already ship, nothing is deferred, and publishing it would misrepresent a completed surface as a limitation.

- **D-28 — guide structure: append to `guides/metering.md`. Do NOT create a new guide.**

  **Phase 63's D-18 is not analogous.** Entitlements was a brand-new family with no existing guide. Metering already has **two** docs — `metering.md` (808 lines, Canonical Guides) and `metering-runtime-and-reconciliation.md` (181 lines, Flagship Recipes) — and a third fragments an already-split domain for a two-module read surface. D-18's own cited precedent cuts this way: *"`metering.md` demonstrably grew by appending."*

  **Placement: "Reading usage back" goes after "Corrections and adjustments", before "Reconciliation via webhooks."** The guide's arc is write-path (define → report → correct) → **verify-path** (read back → reconcile) → operate → scale. Reading-back must come **first** of the two, because it raises the question (*"my summary shows less than I reported"*) that the error-report section answers.

  **Pre-cut two Phase 65 stubs** in the D-18 idiom — `### Testing` and `### Webhooks` under "Reading usage back", each a **shippable paragraph** stating today's state and what lands later (exactly like `entitlements.md:250-268`, which are real prose, not placeholders). Phase 65 then appends rather than restructures.

  **Skip `api_stability.md`** — new modules are purely additive; existing rules cover them.

- **D-29 — the docs gate, differential, with one amendment to D-29 as inherited.** Measured at HEAD: `mix docs` exits 0 with **42 warnings** (Phase 63 recorded 43; commit `e0f6dda` removed one). Gate: (1) plain `mix docs` exits 0; (2) count **≤ 42**, never up; (3) **zero warnings naming Phase 64's *new* files — scoped by exact new file path, NOT by the substring `meter`**; (4) `docs_truth_test.exs` green; (5) `credo --strict` green.

  **⚠ Amendment, and why it matters:** Phase 63's *"zero warnings matching `entitlements`"* was safe only because that substring started at zero. **Two of the current 42 already name a metering file** (`meter_event_stream.ex:15` and `:24` — *"Illegal attributes … ignored in IAL"*, from indented code-block lines beginning `{:ok, …}`). Copying D-29 verbatim would fail on day one. **Cheap bonus:** those two are fixable in ~2 minutes by re-indenting or fencing, dropping the baseline to **40** and letting the gate use the clean `meter` substring after all. Same file family; fold it in.

### Proof depth

- **D-30 — Mox-at-Transport is the only place pagination is provable** (F-10). Own file, mirroring `list_test.exs:384-449`; `TestHelpers.list_json/3` already accepts `has_more` from Phase 63's D-28. Nine assertions: (1) page-2 `starting_after` = last `mtrusg_` id of page 1; (2) **page 2 preserves `customer`, `start_time`, `end_time` and `value_grouping_window`**; (3) N pages = exactly N transport calls; (4) `Stream.take(1)` on a 2-page stream makes exactly 1 call; (5) `stripe-account` carries to page 2; (6) **no `idempotency-key` on page 2** (the explicit strip at `list.ex:267`); (7) page-2 path is the response `url`; (8) page-2 500 raises `LatticeStripe.Error`; (9) **`_last_id` is derived before typing** — the D-05 ordering lock, asserting a `mtrusg_`-prefixed binary, not `nil`.

  **Assertion (2) is the phase's highest-value test — but state its stakes honestly, because they differ from Phase 63's D-22.** There, dropping `customer` on page 2 leaked the whole account's entitlements silently. Here, because all three filters are *required*, a **total** drop makes Stripe 400 loudly. The real risks are narrower and worse-behaved: a **partial** drop leaks **undetectably**, since the returned objects carry no `customer` to compare against (F-02); and `value_grouping_window` is *optional*, so losing it silently flips page 2 from per-day buckets to whole-range aggregation, producing a series with one absurd outlier.

- **D-31 — `refute function_exported?` lock set** (Phase 63's D-23: with no Dialyzer and typespecs documentation-only, this is the **only** enforcement of public surface shape in this project). On `MeterEventSummary`: refute `retrieve/2,3`, `create/2,3`, `update/3,4`, `delete/2,3`, `stream/3`, and `align_window/2` (records the D-10 rejection structurally). On `Billing.Meter`: refute `event_summaries/3,4` (the stripe-java#1852 lesson). On `MeterErrorReport`: refute `list/2,3`, `retrieve/2,3`, `create/2,3`; assert `from_map/1` and `from_event/1`. **Careful:** `list/3` and `list/2` *do* exist via default args — do not refute them.

- **D-32 — `MeterErrorReport` is proven as a pure `from_map/1`/`from_event/1` unit test, no transport** (F-11/F-12 — there is no endpoint). **Seed the fixture from the verbatim published payload, never a hand-invented one** — accrue hand-built a fixture with `"object" => "billing.meter.error_report"`, `reason.error_code`, and a top-level `identifier`, none of which exist, and that is a live demonstration of the cost. Key assertions: `request_identifier` resolves (**the join key — the single most important one**), and also resolves from the legacy `%{"idempotency_key" => …}` shape; `assert is_binary(code)` (encodes the no-atomization decision, not just current behavior); `refute Map.has_key?(struct, :id)`/`:object`/`:livemode` (encodes D-17 as design); missing `error_types` → `[]` not `nil`; `sample_errors: []` with `error_count: 900` still decodes (the real high-volume shape); `from_map(data).meter == nil` while `from_event/1` populates it (D-16 as contract); a `no_meter_found`-shaped event with `related_object: nil` decodes (F-17).

- **D-33 — MTR-04's four tests** (`req.body` is available on the transport request map, so all are cheap): an exact-body round-trip with three custom dimensions and a decimal-string value; **a float-hazard guard asserting `encode(%{"v" => 0.00001}) == "v=1.0e-5"`** — locking known behavior so the doc warning can never silently become false; a Mox-at-Transport check that `MeterEvent.create/3` doesn't filter; and a stripe-mock check that flat dimensions → 200 **and nested payload → 400** (the only proof of the Stripe-side half, and it would have caught F-20.2). Note `form_encoder_test.exs` has **27** tests today with **zero** float and **zero** decimal-string coverage. (Corrected from 26 during plan review: re-measured at HEAD as 27, which is the number the plans and RESEARCH.md already carried. 64-02's post-condition threshold of ≥ 34 is anchored to 27 and must not be adjusted downward on the strength of the earlier figure.)

- **D-34 — stripe-mock integration follows `charge_integration_test.exs:19-27` literally** (`setup_all` TCP-probes `localhost:12111`, raises with the docker command if absent). It **can** prove: the path is served, each of the three required-param 400s in order, the enum rejection, and that a served body decodes. It **cannot** prove pagination, alignment, eventual consistency, zero-bucket behavior, or deactivated-meter reads. **Do not assert on `resp.data.url`** (F-10) — assert against the spec's own regex `^/v1/billing/meters/[^/]+/event_summaries` or skip.

### Open items — require a live test-mode probe, do not guess

These cannot be settled from published sources or stripe-mock. **Do not guard on them and do not claim them in docs.**

- **O-01 — does Stripe's parser accept `1.0e-5` as a `payload[value]`?** stripe-mock validates only `type: string`, so it passes trivially and proves nothing. The answer decides whether float mangling fails **loudly** (sync 400 / async `meter_event_invalid_value`) or **silently corrupts a bill**. Probe: create a `sum` meter, POST `payload[value]=1.0e-5` for a real test customer, then — because validation is asynchronous — either wait on the error-report webhook or poll `event_summaries` for that window. Three distinguishable outcomes; the worst is 200 + a summary reflecting nothing or a wrong number. **Until then the guide says only "pass decimals as strings; Stripe does not document whether its parser accepts exponent notation, so do not rely on it either way"** — correct under all three outcomes, and it gets *stronger*, not corrected, if the probe later shows a 400.
- **O-02** — max/min window span and any lookback limit (**undocumented**; the verified 35-day limit applies to *ingestion*, not summary reads).
- **O-03** — the actual error code Stripe returns for a misaligned timestamp (F-07). **Do not pattern-match on it.**
- **O-04** — whether deactivated meters still serve summaries (believed yes, unverified).
- **O-05** — whether zero-value buckets are emitted for empty periods or skipped. Charts must fill gaps by `start_time`, never by index.

### Claude's Discretion

Exact prose, moduledoc wording, guide section copy, snippet selection, and test naming are Claude's discretion within the D-01…D-34 frame. Two standing instructions carried from Phase 63: **re-verify F-01 through F-20 against source and live Stripe docs before implementing**; and where a researcher's claim and this document disagree, **this document wins** — the ⚠ divergences (D-01, D-06, D-09, D-13, D-14, D-26, D-29) were reconciled deliberately.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase source & requirements
- `.planning/ROADMAP.md` §"Phase 64" — goal, 4 success criteria, build constraints. **SC#1/#2/#3 are amended per D-02.**
- `.planning/REQUIREMENTS.md` — MTR-01…MTR-04. **MTR-01/02/03 are amended per D-02.**
- `.planning/seeds/SEED-005-stripe-native-entitlements.md` §2.1 (the meter-read ask + the "do NOT build more metering writes" fence), §2.2 (ObjectTypes/fixtures, Phase 65), §6 (FROZEN stability contracts).
- `.planning/research/accrue-gap-brief-2026-07-27.txt` — the verified gap brief; **L238-244 is the causal evidence for D-24** (accrue drops the payload "partly because the contract is unclear").

### The templates to follow
- `lib/lattice_stripe/transfer_reversal.ex` — **the primary template.** Parent-scoped, flat, wire-named, already ships `list/4` + `stream!/4` with a leading parent id.
- `lib/lattice_stripe/external_account.ex` L272-276 — the private `validate_id!/2` idiom (D-09).
- `lib/lattice_stripe/tax_id.ex` — the *other* parent-scoped precedent; note its dual-mode is **not** applicable here (F-04).
- `lib/lattice_stripe/list.ex` — **read in full.** `from_json/3` cursor derivation (L283-295, the D-05 ordering hazard), `stream!/2` (L154), `build_next_page_request/1` (L245-275, incl. `base_params` preservation at L246 and the `idempotency_key` strip at L267).
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3` (L117).
- `lib/lattice_stripe/billing/meter.ex` — sibling; `create/3`'s three required-param guards and the exact D-10 message format (L99-109); `@known_fields ~w(` at L43 (the D-20 bug).
- `lib/lattice_stripe/billing/guards.ex` — GUARD-01…GUARD-03 numbered header block (L3-13); GUARD-04 lands here (D-10).
- `lib/lattice_stripe/billing/meter_event.ex` — `create/3` (L67-83); the `@doc` `payload` bullet at L28-30 that D-24.3 amends.
- `lib/lattice_stripe/billing/meter_event_stream.ex` L38-48, L186 — the v1-form vs v2-JSON encoding split that makes pitfall #4 v2-only; **L15/L24 carry 2 of the 42 docs warnings** (D-29).
- `lib/lattice_stripe/form_encoder.ex` L19-92 — the generic flattener; `to_string/1` at L71 is the float hazard; `encode_key/1` L77-85 is the bracket quirk.
- `lib/lattice_stripe/client.ex` L169 (the `idk_ltc_` auto-generated idempotency key — **F-15's punchline**), L699-703 (`build_url_and_body/4`), L718-727 (`merge_expand/2`).
- `lib/lattice_stripe/event_notification.ex` L33-38 — the RFC3339-vs-Unix asymmetry `NOTE:` to mirror (D-19).
- `lib/lattice_stripe/object_types.ex` L69-80 — `maybe_deserialize/1`; **the `%{"object" => _}` dispatch that makes D-14 necessary.**
- `lib/lattice_stripe/drift.ex` L210 — the bracket-only `@known_fields` regex (D-20).
- `lib/lattice_stripe/tax/calculation.ex` — `tax_breakdown` as a bare array of typed sub-structs; the exact analogue of `error_types` (D-15).
- `lib/lattice_stripe/entitlements/active_entitlement.ex` L101 — `list/3` keeps `params \\ %{}` despite a required `customer` (D-06).

### Registration & docs
- `mix.exs` L179-190 — the `"Billing Metering"` `groups_for_modules` block (D-04).
- `guides/metering.md` — 808 lines. **L118-124** (`value_settings`, repeats the wrong claim), **L154-206** (the fire-and-forget recipe that caused the bug), **L418-478** (webhook reconciliation + the wrong error-code table), **L581-596** (Common pitfalls; #4 is wrong), L611+ (v2 stream).
- `guides/metering-runtime-and-reconciliation.md` L118 — also teaches the unworkable handler shape (F-12).
- `guides/scope.md` — the canonical deferred-scope page, already docs-truth-locked (`docs_truth_test.exs:341`). The D-27 dimension-read bullet lands here.
- `guides/entitlements.md` L250-268 — the pre-cut-stub idiom to clone (D-28); L292 links here, and the back-link is missing.
- `guides/api_stability.md` — reviewed; **no edit needed** (D-28).

### Test surfaces
- `test/lattice_stripe/list_test.exs` L384-449 — the Mox-at-Transport multi-page pattern D-30 must mirror.
- `test/integration/charge_integration_test.exs` L19-27 — the `setup_all` raise-if-mock-absent pattern (D-34).
- `test/lattice_stripe/docs_truth_test.exs` — L89 (ExDoc placement assertions, D-26's exception), L341 (`scope.md` lock to extend), L888/L900 (relative-`.md` and no-backtick-URL rules; **note `README.md` at L288 is locked to the opposite convention**).
- `test/lattice_stripe/form_encoder_test.exs` — 27 tests, **zero** float/decimal coverage (D-33).
- `test/lattice_stripe/billing/guards_test.exs`, `meter_guards_test.exs` — where GUARD-04's matrix lands.
- `test/support/test_helpers.ex` — `list_json/3` (extended in Phase 63's D-28).
- `test/support/fixtures/entitlements.ex` — the D-27 "PROMOTION TARGET (Phase 65)" header comment to clone for a meter fixture.

### Prior-phase context
- `.planning/phases/63-stripe-native-entitlements/63-CONTEXT.md` — **D-02** (typed nesting), **D-05** (cursor ordering), **D-07** (idempotency clause), **D-08** (verb doctrine), **D-10** (guard message format), **D-11** (the id-clause rejection this phase diverges from), **D-14** (create/3 no-default; PII-only Inspect), **D-16** (the namespace rule), **D-18** (guide stubs), **D-19** (three-entry-point fences), **D-20/D-21/D-22** (proof depth), **D-23** (structural over grep), **D-25** (three locks max), **D-28** (`list_json/3`), **D-29** (differential docs gate).
- `.planning/phases/62-1-1-1-7-what-landed-migration-guide/62-CONTEXT.md` — D-04, ExDoc placement + differential-docs posture.

### External (verified during discussion)
- Stripe OpenAPI — [`spec3.sdk.json`](https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.sdk.json) (`info.version 2026-06-24.dahlia`): the `billing.meter_event_summary` schema (F-01…F-06), the `x-stripeResource` codegen directive (D-01.4), and the `payload` `additionalProperties: {type: string}` (F-19).
- Stripe: [Meter event summary](https://docs.stripe.com/api/billing/meter-event_summary) · [v2 core event types](https://docs.stripe.com/api/v2/core/events/event-types) (F-12, F-16 — fetch with `curl -A Mozilla`; WebFetch 404s) · [Record usage with the API](https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api) (F-20, dimension cardinality) · [Meter usage analytics](https://docs.stripe.com/billing/subscriptions/usage-based/analytics) (D-27, preview).
- Stripe changelog: [15-digit value validation, 2026-04-22](https://docs.stripe.com/changelog/dahlia/2026-04-22/billing-meter-event-values-validation) — *"double precision loss in the usage aggregation pipeline."* **Note our pin is `2026-03-25.dahlia` (`config.ex:57`), one release earlier.**
- [stripe-python#1781](https://github.com/stripe/stripe-python/issues/1781) — a Stripe maintainer: *"the doc is just out of date"*, and *"don't build anything until I confirm."* The proof that "docs confirm X" was unsafe.
- [stripe-java#1852](https://github.com/stripe/stripe-java/issues/1852) — Stripe's docs advertising a `Meter.getEventSummaries()` that never existed; *"the docs is wrong."* → no delegator (D-04).
- [stripe-python#1353](https://github.com/stripe/stripe-python/pull/1353) — `"day"` added to the enum post-launch, 2024-06 → the D-10 pass-through hatch.
- stripe-go `billing/metereventsummary/client.go` — the `FormatURLPath` nil-id → `//` bug (D-09.4).
- Adopters who used the endpoint built reconciliation rather than trusting it: [unkey#6451](https://github.com/unkeyed/unkey/pull/6451) (0.1% drift tolerance vs ClickHouse), [storacha#590](https://github.com/storacha/project-tracking/issues/590) (parity check only).
- Silent-coercion prior art (D-10): [Orb ingest/usage](https://docs.withorb.com/quickstart/ingest), Datadog `/api/v1/query` rollup, [Metronome](https://docs.metronome.com/guides/events/send-usage-events), [OpenMeter](https://openmeter.io/docs/getting-started/meters/overview).

### Commissioned research (`prompts/`)
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — HexDocs `extras`/`groups_for_*` conventions (~L359-378), moduledoc craft.
- `prompts/elixir-best-practices-deep-research.md` — struct design, optional args, raise-vs-tuple.
- `prompts/stripe-explanation-domain-language-deep-research.md` — domain nouns/verbs and moduledoc voice.
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — JTBD framing for the guide spine.
- `prompts/payments_domain_field_guide.md` — usage-window and billing-period semantics.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LatticeStripe.List.stream!/2`** — the entire pagination mechanism already exists and works here unmodified (F-01). This phase must **not** grow a new one.
- **`Resource.require_param!/3` + `unwrap_list/2` + `unwrap_bang!/1`** — used verbatim.
- **`Billing.Guards`** — an established, numbered home for pre-network raises; GUARD-04 is the fourth member of an existing family, not a new pattern.
- **`TestHelpers.list_json/3`** — Phase 63's D-28 extension already supports the multi-page fixtures D-30 needs.
- **`refute function_exported?`** — 19 precedent files; the only enforcement of public surface shape in this project.
- **`req.body` on the transport request map** (`transport.ex:36-40`) — makes exact-wire-body assertions cheap (D-33).

### Established Patterns
- **Depth rule, extended by this phase:** a parent `.ex` exists iff the parent is a real Stripe resource or has functions (Phase 63's D-16). **Conversely — and this is the half Phase 64 adds — modules nested beneath a resource module are value objects only; they never own a `%Request{}`.** Verified: ~50 request-owning modules, all at depth ≤ 2, zero exceptions.
- **Wire↔module transform:** dot = module boundary, underscore = CamelCase. 43/43 outside the `LineItem` family.
- **Parent-scoping is expressed in the signature, not the module name** (`TransferReversal`, `ExternalAccount`).
- **Verb doctrine:** explicit verbs mirror explicit Stripe endpoints; wrappers over `update` take the exact wire field name.
- **Typing happens at the resource layer** (`Stream.map(&from_map/1)`), not via `ObjectTypes` — so **Phase 64 has no code dependency on Phase 65**.
- **docs-truth is `File.read!` + `=~` over guides *and* source files**, run as its own required CI job.

### Integration Points
- `mix.exs` `groups_for_modules` — five modules appended to `"Billing Metering"` (D-04).
- `lib/lattice_stripe/billing/guards.ex` — GUARD-04 plus its header line (D-10).
- `lib/lattice_stripe/drift.ex:210` — the regex widening (D-20).
- `guides/metering.md` — one new section, one new subsection, two pre-cut stubs, and **four corrections** (D-24, D-28).
- `guides/scope.md` — one "Deferred by design" bullet (D-27).
- `lib/lattice_stripe/object_types.ex` — **Phase 65 only. Phase 64 must not touch it.**
- `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md` — the D-02 amendments.

### Cross-phase corrections this research forces
1. **Phase 65's OBJ-01 must drop `billing.meter_error_report`** — structurally impossible (F-13). The other four keys are fine.
2. **MTR-03's `validation_errors` does not exist** — amend to `reason.error_types` (F-11).
3. **Two shipped guides teach a webhook handler that cannot work** (F-12) — neither is docs-truth-locked today, so Phase 64 can and should fix both.

</code_context>

<specifics>
## Specific Ideas

- **The reconciler/error-handler snippet is the guide's headline example.** Note it opens with `fetch_event` — that step is not optional and is the thing every adopter gets wrong:
  ```elixir
  def handle_notification(%EventNotification{type: "v1.billing.meter.error_report_triggered"} = notif, client) do
    # `data` is a fetched attribute — the webhook body does not contain it.
    {:ok, event} = Webhook.fetch_event(client, notif)
    report = MeterErrorReport.from_event(event)

    for %ErrorType{code: code, sample_errors: samples} <- report.reason.error_types,
        %SampleError{request_identifier: key, error_message: msg} <- samples do
      MyApp.Billing.MeterEvents.mark_failed_by_idempotency_key(key, code, msg)
    end
  end
  ```
  **Ship zero helper functions.** Stripe already groups by `error_types` and supplies `error_count` at both levels — the wire supplies the ergonomics, so `Enum.group_by/2` and a count helper would both be redundant.
- **The admin-screen snippet should teach the total/series split explicitly**, because the default is a trap:
  ```elixir
  # For a TOTAL: omit value_grouping_window -> one server-aggregated bucket,
  # one request, no pagination, no client-side float summation.
  {:ok, %{data: %{data: [summary]}}} =
    MeterEventSummary.list(client, meter.id, %{
      "customer" => sub.customer, "start_time" => aligned_start, "end_time" => aligned_end
    })
  ```
- **Use an input → wire coercion table** in "The payload contract" (the OpenMeter idiom) — it states the arbitrary-keys, decimal-string, float-hazard, nesting-rejection and nil-vanishing facts at once, and is far clearer than five prose rules. Rule 2's example must be **`0.00001`**, not `0.0000001` — the real cliff is one decimal place from values people bill on.
- **The four payload rules, ordered by what they cost you:** flat-only → decimals-as-strings → cardinality → dimensions-are-write-only. **Rule 4 is the one that saves an adopter a wasted week.**
- **Quantify the truncation footgun rather than describing it.** A 31-day hourly window is **744 buckets**; `list/4` returns 10. Summing without checking `has_more` yields a plausible number that is **1.3%** of the truth. Request amplification across 200 customers: 15,000 requests at the default, 1,600 at `limit=100`, **200** with no window.
- **Proposed guard microcopy** — print the arithmetic, name the real-world cause, and refuse to choose:
  ```
  LatticeStripe.Billing.MeterEventSummary.list/4: start_time 1753621037 is not aligned
  to a UTC day boundary (00:00 UTC). Stripe requires day-aligned timestamps when
  value_grouping_window is "day", and rejects unaligned values with HTTP 400.

  Subscription current_period_start/current_period_end derive from billing_cycle_anchor
  and are almost never aligned. Align them yourself — this library will not choose floor
  vs. ceil for you, because that choice changes which usage the window includes:

      start_time = Integer.floor_div(start_time, 86400) * 86400      # floor
      end_time   = -Integer.floor_div(-end_time,  86400) * 86400     # ceil
  ```
  `Integer.floor_div/2` rather than `div/2` — `div/2` truncates toward zero and rounds the wrong way for negative inputs. Elixir has **no** `DateTime.beginning_of_hour/1`, and `DateTime.truncate/2` only truncates sub-second precision, so this is integer arithmetic by necessity.
- **The success measure for this phase is external and concrete:** accrue can build its SEED-004 M3 "Usage / meters" admin room and a customer-facing "usage this period" display, and can stop dropping the host `:payload`. If the shipped surface doesn't let it do that, the phase missed.
- **Name the freshness caveat in UX terms, not API terms:** label the figure with the time it was fetched; never present it as live; never use it as a billing source of truth (Stripe bills from the meter, not from these summaries).

</specifics>

<deferred>
## Deferred Ideas

- **`/v1/billing/analytics/meter_usage` — the successor surface.** In `spec3.beta.sdk.json` (`2025-09-30.preview`), in no SDK. Renames to `starts_at`/`ends_at`, adds a full IANA `timezone` param, widens the window enum to `day|week|month|hour`, adds **`refreshed_at`**, and **drops the hour/UTC-day alignment clause**. It fixes footguns #1 and #3 at the API level. Revisit when it reaches GA — and note that D-10's guard is non-breaking to remove, so the design already survives this.
- **Dimension-grouped reads** (`dimension_payload_keys`, `dimension_group_by_keys`, `dimension_filters`, and a `dimensions` map on the summary) — preview-gated (D-27). This is the largest single gap between what Phase 64 ships and what the JTBD wanted. Revisit on GA or adopter pull.
- **`align_window/2` / snap helpers on `MeterEventSummary`** — rejected in D-10/D-11, recorded honestly: an additive minor bump later if adopter pull shows the two-line arithmetic is real friction. Any future version must make the snapping **visible in the return value**, never silent.
- **Patching `to_string/1` in `form_encoder.ex` to `float_to_binary(v, decimals: N)`** — rejected in D-23 as a silent cross-cutting change on the eve of a release, but it is the one call in this phase a reviewer could reasonably flip. Blocked on O-01.
- **Pointing `Drift.@spec_url` at `latest/openapi.spec3.sdk.json` plus a non-`object`-keyed enrolment path** — would give v2 thin-event payloads drift coverage they have none of today. A separate, larger change; out of scope here.
- **Fixing `mix docs --warnings-as-errors` (42 warnings)** — pre-existing, not this phase's debt. D-29's differential gate is the interim posture. (This phase does opportunistically clear the 2 metering-file warnings.)
- **`groups_for_modules` backlog — 32 ungrouped lib modules**, including `Billing.Guards` (already grouped elsewhere at `mix.exs:260` — leave it). → Phase 67.
- **A limits table with honest "not documented upstream" rows** (max payload bytes, max key count, max key length). **Not one of the eleven libraries and platforms surveyed documents these** — publishing the gap honestly would make our guide better than the state of the art. Cheap, but it is polish, not Phase 64 scope.

</deferred>

---

*Phase: 64-meter-event-summary-reads*
*Context gathered: 2026-07-28*
</content>
</invoke>
