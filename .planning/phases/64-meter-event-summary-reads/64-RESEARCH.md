# Phase 64: Meter Event-Summary Reads - Research

**Researched:** 2026-07-28
**Domain:** Stripe Billing metering read surface (v1 REST list endpoint + v2 thin-event payload typing + guide truth repair) in an Elixir SDK
**Confidence:** HIGH

> **Re-verification standing order (CONTEXT §Claude's Discretion) is DISCHARGED for this phase.**
> F-01…F-20 were re-verified in this session against (a) `stripe/openapi@master/openapi/spec3.sdk.json`
> (`info.version` = `2026-06-24.dahlia`), (b) `docs.stripe.com/api/v2/core/events/event-types`,
> and (c) direct execution + source reads against this worktree at HEAD `7c57b1d`.
> **All twenty held.** Four *additions* were found that CONTEXT does not record — see
> `## Findings That Amend CONTEXT` (N-01…N-08). N-01 changes a struct definition and must not be missed.

<user_constraints>
## User Constraints (from CONTEXT.md)

**`.planning/phases/64-meter-event-summary-reads/64-CONTEXT.md` is authoritative and MUST be read in full
before planning.** It is ~60KB of reconciled decisions; this section is a navigational index plus verbatim
reproduction of the load-bearing divergences. Where this file and CONTEXT.md disagree, **CONTEXT.md wins**,
except where flagged under `## Findings That Amend CONTEXT`, which are new verified facts CONTEXT could not
have had.

### Locked Decisions

**Naming & namespace**

- **D-01 ⚠ (ONE-WAY DOOR)** — modules are `LatticeStripe.Billing.MeterEventSummary` and
  `LatticeStripe.Billing.MeterErrorReport`. **FLAT, at depth 2, named after the wire `object` string.
  This overrules MTR-01, MTR-02, and ROADMAP SC#1/#2, which all specify `Billing.Meter.EventSummary`.**
  Verbatim divergence rationale: *"zero of the ~50 request-owning modules in this repo sit at depth 3…
  Within `"Billing Metering"` specifically, the rule is sharper: depth 3 means value object…
  Parent-scoping is expressed in the signature, not the module name."* → **Reversibility: one-way.**
  The atom becomes a semver contract at the v1.10 tag.
- **D-02** — planning-artifact edits to REQUIREMENTS.md / ROADMAP.md. **STATUS: already applied**
  (verified: `REQUIREMENTS.md:20-22` names `MeterEventSummary` and `reason.error_types`; `:27` excludes
  `billing.meter_error_report` from OBJ-01; ROADMAP SC text is amended). No further artifact edit needed.
- **D-03** — `MeterErrorReport`'s sub-structs nest at depth 3 (`.Reason`, `.ErrorType`, `.SampleError`);
  they own no `%Request{}`. Document *both* flatness reasons: the summary is flat because it **is a
  resource**; the error report is flat because it **is not a resource at all**.
- **D-04** — append all five modules to the existing `"Billing Metering"` group in `mix.exs:179-190`.
  No new group. Source order = lifecycle: *define → write → read → diagnose*.
  **No `Billing.Meter.event_summaries/4` convenience delegator** (stripe-java#1852 lesson).

**`MeterEventSummary` surface & guards**

- **D-05** — `list(client, meter_id, params \\ %{}, opts \\ [])`, always parent-scoped.
- **D-06 ⚠** — keep `params \\ %{}`. **Do NOT extend Phase 63's D-14 "no default" rule from `create/3`
  to `list/4`.** Verbatim: *"the just-shipped sibling contradicts it — `Entitlements.ActiveEntitlement.list/3`
  has a required `customer` and keeps `params \\ %{}`… Leave D-14 scoped to `create`."*
- **D-07** — final surface: `list/2..4`, `list!/2..4`, `stream!/2..4`, `from_map/1`. **No `retrieve/3`**,
  no create/update/delete, no non-bang `stream`. Include `def from_map(%__MODULE__{} = s), do: s`.
  **No custom `Inspect`.**
- **D-08** — three `Resource.require_param!/3` guards, first-failure, D-10 message format **verbatim**:
  `customer` → `start_time` → `end_time`. Note the vowel on the third (`an end_time`).
- **D-09 ⚠** — add a private `validate_id!/2` on `meter_id`. **Diverges from Phase 63's D-11.** Verbatim:
  *"Wrong denominator… among modules that list a child collection under a parent id there are four, and
  two of four raise on empty… Different mechanism: this is the `external_account.ex` private-helper form…
  Observed, not hypothesised: stripe-go ships exactly this bug on exactly this endpoint."*
  Message: `LatticeStripe.Billing.MeterEventSummary.list/4 requires a non-empty meter id`.
- **D-10** — GUARD-04: pre-network alignment raise in `LatticeStripe.Billing.Guards`, arity 2
  (`params, fun`). Divisors: no window → `60`; `"hour"` → `3_600`; `"day"` → `86_400`.
  **NO auto-aligning helper.** Two mandatory forward-compat escape hatches: unrecognised
  `value_grouping_window` values pass through unguarded; absent/unparseable timestamps pass through.
- **D-11** — dissent recorded; `align_window/2` deferred, not dropped.
- **D-12** — **do NOT state a "~100% on first run" figure in the moduledoc.** Mechanism verified,
  incidence not.

**`MeterErrorReport`**

- **D-13 ⚠** — MTR-03 amended: there is no `validation_errors` field. Struct carries `reason`,
  never an invented name.
- **D-14 ⚠** — strike `billing.meter_error_report` from Phase 65's OBJ-01 (already applied in
  REQUIREMENTS.md). Lock the absence with a `refute`.
- **D-15** — type it fully: `MeterErrorReport` + `.Reason` + `.ErrorType` + `.SampleError`.
- **D-16** — `from_event/1` is the primary constructor; `from_map/1` is low-level and leaves `:meter` nil.
  Make the asymmetry an **asserted contract**.
- **D-17** — no `:id`, no `:object`, no `:livemode` on the struct.
- **D-18** — `code` stays `String.t()`. **Do NOT atomize, do NOT whitelist.** Never `String.to_atom/1`
  on server-controlled input.
- **D-19** — arrays default to `[]`, never `nil`. Timestamps stay RFC3339 strings. `@known_fields` must
  use `~w[...]` **square brackets**. No custom `Inspect`.
- **D-20** — fix `drift.ex:210`'s bracket-only `@known_fields` regex. **Widen the regex** (not normalise
  the 18 files).
- **D-21** — no `list`/`retrieve`/`create` on `MeterErrorReport`.

**MTR-04 — docs, re-scoped**

- **D-22** — MTR-04 stays a documentation plan. No encoder change, no production module change.
  Re-scoped to *"docs correct a wrong claim, document four real constraints, and prove two with tests."*
- **D-23** — do **NOT** patch `to_string/1` in `form_encoder.ex`. Recorded as a close call.
- **D-24** — fix the artifacts that caused the bug: (1) `metering.md` pitfall #4, (2) the fire-and-forget
  recipe (`metering.md:154-206`) — add a dimension + `dimensions \\ %{}` param, replace `to_string(value)`,
  (3) `meter_event.ex:28-30`'s `@doc` payload bullet. Also correct `### value_settings` (`metering.md:118-124`).
- **D-25** — placement asymmetric: full treatment in the guide, one corrected sentence + autolink in the
  `@doc`. Explicitly **not** D-19-style triplication.
- **D-26** — **NO new docs-truth prose grep locks. Zero.** Prove behavior with tests instead.
  **Exception:** extend the ExDoc *placement* assertion in `docs_truth_test.exs` (structural config,
  not prose).
- **D-27** — the honest scope limit belongs in `guides/scope.md`: **on the GA API you CANNOT read usage
  back grouped by a custom dimension.** ⚠ *"What does NOT belong in scope.md: the roadmap's 'do NOT add
  new metering write surfaces' fence"* — that is an internal build constraint.
- **D-28** — append to `guides/metering.md`. Do **NOT** create a new guide. Placement: **after
  "Corrections and adjustments", before "Reconciliation via webhooks"** (verified: insert at line ~417).
  Pre-cut two Phase 65 stubs (`### Testing`, `### Webhooks`) as **shippable paragraphs**.
  Skip `api_stability.md`.
- **D-29 ⚠** — differential docs gate: (1) plain `mix docs` exits 0; (2) warning count **≤ 42**, never up;
  (3) **zero warnings naming Phase 64's new files — scoped by exact new file path, NOT by the substring
  `meter`**; (4) `docs_truth_test.exs` green; (5) `credo --strict` green.
  Amendment: two of the current 42 already name a metering file. **Cheap bonus:** fix them, drop the
  baseline to 40, then the clean `meter` substring is usable.

**Proof depth**

- **D-30** — Mox-at-Transport is the only place pagination is provable. Own file, mirroring
  `list_test.exs:384-449`. **Nine assertions** (enumerated in CONTEXT). Assertion (2) is the phase's
  highest-value test.
- **D-31** — `refute function_exported?` lock set. **Careful:** `list/3` and `list/2` *do* exist via
  default args — do not refute them.
- **D-32** — `MeterErrorReport` proven as a pure `from_map/1`/`from_event/1` unit test, no transport.
  **Seed the fixture from the verbatim published payload, never a hand-invented one.**
- **D-33** — MTR-04's four tests, incl. `encode(%{"v" => 0.00001}) == "v=1.0e-5"`.
- **D-34** — stripe-mock integration follows `charge_integration_test.exs:19-27` literally.
  **Do not assert on `resp.data.url`.**

### Claude's Discretion

Verbatim from CONTEXT: *"Exact prose, moduledoc wording, guide section copy, snippet selection, and test
naming are Claude's discretion within the D-01…D-34 frame. Two standing instructions carried from Phase 63:
re-verify F-01 through F-20 against source and live Stripe docs before implementing; and where a
researcher's claim and this document disagree, this document wins — the ⚠ divergences (D-01, D-06, D-09,
D-13, D-14, D-26, D-29) were reconciled deliberately."*

### Deferred Ideas (OUT OF SCOPE)

- `/v1/billing/analytics/meter_usage` — the preview successor surface.
- Dimension-grouped reads (`dimension_payload_keys`, `dimension_group_by_keys`, `dimension_filters`).
- `align_window/2` / snap helpers on `MeterEventSummary`.
- Patching `to_string/1` in `form_encoder.ex` (blocked on O-01).
- Pointing `Drift.@spec_url` at a spec containing v2 thin-event payloads.
- Fixing the full 42 `mix docs --warnings-as-errors` backlog (this phase clears only the 2 metering ones).
- `groups_for_modules` backlog — 32 ungrouped lib modules → Phase 67.
- A limits table with honest "not documented upstream" rows.

**Also fenced by the roadmap:** any new metering **write** surface (all four already ship);
`ObjectTypes` registration + public `Testing.Fixtures` (Phase 65 — **Phase 64 must not touch
`object_types.ex`**).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (as amended per D-02) | Research Support |
|----|-----------------------------------|------------------|
| MTR-01 | Read meter event summaries via `LatticeStripe.Billing.MeterEventSummary.list/4` (`GET /v1/billing/meters/:id/event_summaries`; params customer, start_time, end_time, value_grouping_window) | Endpoint + all 9 params verified verbatim from OpenAPI (F-03/F-04). Object has 7 fields incl. required `id` (F-01/F-02). Template: `transfer_reversal.ex` (read in full). Guard set: D-08 + D-09 + D-10. |
| MTR-02 | Auto-paginate via `Billing.MeterEventSummary.stream!` | `List.stream!/2` works unmodified because `id` is required on the object (F-01) and cursor derivation matches `%{"id" => id}` on raw maps (`list.ex` `last_item_id/1`). Proof pattern: `list_test.exs:384+`. |
| MTR-03 | `LatticeStripe.Billing.MeterErrorReport` typed struct exposing `reason.error_types`, deserialized from the `v1.billing.meter.error_report_triggered` v2 thin event via `from_event/1` | Full payload shape extracted from Stripe's v2 event-types reference — **including 3 `data` fields CONTEXT omits (N-01)**. `Webhook.fetch_event/2,3` already ships; `%Event{}` carries `:data` and `:related_object` (N-06). |
| MTR-04 | Docs confirm `Billing.MeterEvent.create/3` accepts arbitrary custom `payload` dimensions and decimal-string `value`s | Re-confirmed by direct execution (F-19) **and** by the OpenAPI schema `payload: {additionalProperties: {type: string}}`. Re-scoped per D-22 to correcting wrong prose — **and the wrong-prose inventory is larger than D-24 records (N-03)**. |
</phase_requirements>

## Summary

This phase is unusually well-researched already: CONTEXT.md contains a reconciled, evidence-backed decision
record (D-01…D-34) built on twenty verified findings (F-01…F-20). My job was therefore **verification, not
discovery** — and the standing order to re-verify before implementing was the right call. All twenty findings
held under independent re-verification against the Stripe OpenAPI spec, Stripe's v2 event-types reference,
and direct execution in this worktree.

**The phase is structurally three unrelated deliverables sharing one requirement block.** (1) A conventional
parent-scoped list resource that is almost entirely a `transfer_reversal.ex` transliteration plus three
`require_param!` guards and one novel alignment guard. (2) A four-module typed decoder for a v2 thin-event
payload that has **no endpoint, no `id`, and no `object` key** — so it touches no transport code and is proven
by a pure unit test. (3) A documentation-truth repair whose code footprint is one regex widening in
`drift.ex`. There is **zero new dependency surface**: everything needed (`List.stream!/2`,
`Resource.require_param!/3`, `Billing.Guards`, `TestHelpers.list_json/3`, `Webhook.fetch_event/3`) already
ships and is verified working.

**The one thing planning must not inherit unchanged is the `MeterErrorReport` struct shape.** CONTEXT's D-15
plans `MeterErrorReport` as carrying `reason` (plus a `from_event/1`-populated `:meter`). Stripe's own v2
event-types reference lists **four** fields under `data`: `developer_message_summary`, `reason`,
`validation_start`, and `validation_end`. The two validation timestamps are the window the report covers —
the exact information an operator needs to know *which* usage was affected — and omitting them would ship a
struct that silently drops them into `:extra` or nowhere. This is finding **N-01** and it is the highest-value
thing this research adds. Three further additions (N-02, N-03, N-08) expand the MTR-04 correction inventory:
the guide's error-code table documents a **retired** code, is **missing four live ones**, and its two webhook
handler snippets are wrong in three independent ways each.

**Primary recommendation:** Follow CONTEXT.md's D-01…D-34 exactly — they are correct and were reconciled
deliberately — but expand the `MeterErrorReport` struct to the verified four-field `data` shape (N-01), and
expand D-24's correction list from four sites to six (N-03). Sequence the work as four waves:
schema/module + guards → pagination proof → error-report decoder → docs repair + gates.

## Findings That Amend CONTEXT

These are **new verified facts**, not disagreements. CONTEXT could not have had them because they come from
the v2 event-types reference payload tree, which is not in any `spec3*.json`.

### N-01 — ⚠ HIGHEST PRIORITY — the error-report `data` payload has FOUR fields, not one

`[CITED: docs.stripe.com/api/v2/core/events/event-types]` — extracted from the `ApiEventType` element tree
for `v1.billing.meter.error_report_triggered`, under the **"Fetched attributes"** heading:

```
data (object)
├── developer_message_summary  string     "Extra field included in the event's …"
├── reason (object)
│   ├── error_count            integer    "The total error count within this window."
│   └── error_types            array of objects
│       ├── code               enum       Open Enum. (10 values — see N-02)
│       ├── error_count        integer    "The number of errors of this type."
│       └── sample_errors      array of objects
│           ├── error_message  string     "The error message."
│           └── request (object)          "The request causes the error."
│               └── identifier string     "The request idempotency key."
├── validation_start           timestamp  "The start of the window that is encapsulated by this summary."
└── validation_end             timestamp  "The end of the window that is encapsulated by this summary."
```

**Impact on D-15:** the struct must be

```elixir
defstruct [:developer_message_summary, :reason, :validation_start, :validation_end, :meter, extra: %{}]
```

not just `[:reason, :meter]`. `validation_start`/`validation_end` are operationally load-bearing — they are
the only thing that tells an operator *which window* of usage was rejected, and they pair directly with the
`MeterEventSummary` window the reconciler is reading. **Cross-link them in the moduledoc.** All four are
`nullable: false` in the reference.

**Impact on D-19:** D-19's "timestamps stay RFC3339 strings" rule now has two concrete fields to apply to
(`validation_start`, `validation_end`), matching the `event_notification.ex:33-38` `NOTE:` precedent.

**Impact on D-32:** the fixture must carry all four fields, and the test set should assert
`validation_start`/`validation_end` round-trip as binaries (not integers).

### N-02 — the `code` open enum, verbatim, all 10 values

`[CITED: docs.stripe.com/api/v2/core/events/event-types]` — `EnumValuesList` `total: 10`, preceded by the
literal paragraph **"Open Enum."** (confirming F-16 and D-18):

```
archived_meter                        meter_event_value_too_many_digits
meter_event_customer_not_found        missing_dimension_payload_keys
meter_event_dimension_count_too_high  no_meter
meter_event_invalid_value             timestamp_in_future
meter_event_no_customer_defined       timestamp_too_far_in_past
```

Note `no_meter` (a **code**) is distinct from `v1.billing.meter.no_meter_found` (an **event type**).

### N-03 — the MTR-04 wrong-prose inventory is SIX sites, not four

D-24 enumerates three artifacts plus `### value_settings`. Verified by reading the files, there are two more,
both already flagged in CONTEXT's canonical_refs but **not enumerated as correction targets in D-24**:

| # | Site | What is wrong | Verified how |
|---|------|---------------|--------------|
| 1 | `guides/metering.md:581-596` pitfall #4 | *"The payload value must be a string (`"5"`, not `5`). Integers trigger `meter_event_invalid_value`."* — **false for v1** | Direct execution: `encode(%{"payload" => %{"value" => 5}}) == encode(%{"payload" => %{"value" => "5"}})` → `true`, both `payload[value]=5` |
| 2 | `guides/metering.md:118-124` `### value_settings` | repeats the same false claim (*"integers trigger `meter_event_invalid_value` and are silently dropped"*) | same |
| 3 | `guides/metering.md:154-206` fire-and-forget recipe | hardcodes `stripe_customer_id` + `value` only; `report/5` has no dimension param; calls `to_string(value)` — **the float footgun itself** | read in full |
| 4 | `lib/lattice_stripe/billing/meter_event.ex:26-28` `@doc` | *"customer-mapping key plus the numeric value"* — closed-set language | read in full |
| **5 (NEW)** | `guides/metering.md:425-437` error-report handler snippet | **three independent errors**: pattern-matches `%LatticeStripe.Event{}` (it is a v2 thin event → `%EventNotification{}` + `fetch_event`); reads `event.data["object"]` (thin-event `data` has **no** `"object"` key, F-13); reads `reason.error_code` (**no such field** — it is `reason.error_types[].code`) | read in full + N-01 tree |
| **6 (NEW)** | `guides/metering.md:442-456` "Error codes you must handle" table | column header is `error_code` (wrong field name); documents **`meter_event_value_not_found`, which is NOT in the live 10-value enum** (this is F-16's retired code, now identified by name); **missing four live codes**: `meter_event_dimension_count_too_high`, `meter_event_value_too_many_digits`, `missing_dimension_payload_keys`, `no_meter`; its `meter_event_invalid_value` remediation repeats the integer-vs-string falsehood | N-02 enum diff |

**Plus a seventh, in the other guide:** `guides/metering-runtime-and-reconciliation.md:118-124` ships the
same unworkable handler (`%LatticeStripe.Event{}` + `event.data["object"]` + `error_report["id"]` — and per
D-17 there **is no `id`** on this payload). CONTEXT's code_context §"Cross-phase corrections" #3 already says
*"Two shipped guides teach a webhook handler that cannot work… Phase 64 can and should fix both."* — this
confirms it concretely and gives the line numbers.

**This does not change D-22's verdict** (MTR-04 stays documentation-only, no production code change beyond
`drift.ex`). It changes the *size* of the docs plan. Budget for it.

### N-04 — two different idempotency keys live in the same event; do not conflate them

`[CITED: docs.stripe.com/api/v2/core/events/event-types]` The thin-event **body** carries its own nullable
`reason` object: `reason.request.id` and `reason.request.idempotency_key`, plus `reason.type` (enum).
This is a **different** thing from `data.reason.error_types[].sample_errors[].request.identifier`.

- `data.…sample_errors[].request.identifier` — the idempotency key of the **failing `MeterEvent.create` call**.
  **This is the join key** (F-15) and the module's whole purpose.
- `reason.request.idempotency_key` — the idempotency key of the request that *caused the event to fire*.
  Already modelled: `event_notification.ex` hides `:reason` in `Inspect` precisely because it holds this.

Two fields named nearly identically, one nested five levels down. **The moduledoc must disambiguate**, and
`SampleError`'s field should stay named `request_identifier` (per the CONTEXT snippet) rather than
`idempotency_key`, so the two never read as the same thing.

### N-05 — `%LatticeStripe.Event{}` supports `from_event/1` exactly as D-16 describes

`[VERIFIED: source read]` `event.ex:54-68` — the struct carries **both** `:data` (raw `map()`) and
`:related_object` (typed `%EventNotification.RelatedObject{}` via `RelatedObject.from_map/1` at
`event.ex:234`). `Webhook.fetch_event/2,3` (`webhook.ex:324-344`) GETs `/v2/core/events/:id` and returns
`{:ok, %Event{}}`. So `from_event(%Event{data: data, related_object: %{id: meter_id}})` is directly
implementable with no new plumbing. F-12/F-14/D-16 all confirmed implementable.

### N-06 — `v1.billing.meter.no_meter_found` confirmed byte-identical, and `related_object` is genuinely absent

`[CITED: docs.stripe.com/api/v2/core/events/event-types]` Its element tree is identical field-for-field
(`developer_message_summary`, `reason{error_count, error_types[{code, error_count, sample_errors[…]}]}`,
`validation_start`, `validation_end`), and a search for `"name":"related_object"` in its block returns
**False**. F-17 confirmed. `from_event/1` **must** tolerate `related_object: nil` and leave `:meter` nil —
which is the same code path `from_map/1` takes, so it costs nothing.

### N-07 — the preview successor keeps the minute rule; it only drops the hour/day clause

`[VERIFIED: spec3.beta.sdk.json, info.version 2026-06-24.preview]` `/v1/billing/analytics/meter_usage`
exists and takes `customer` (required), `starts_at` (required), `ends_at` (required), `meters` (array),
`timezone` (full IANA enum, defaults UTC), `value_grouping_window` (enum widened to
`day|hour|month|week`), `expand`. **But `starts_at`/`ends_at` still say *"Must be aligned with minute
boundaries."*** CONTEXT's deferred note says it *"drops the hour/UTC-day alignment clause"* — accurate, but
worth stating precisely: the **minute** rule survives, so D-10's no-window `60` divisor branch would remain
valid even after migration. This strengthens D-10's "the design survives Stripe's own roadmap" claim.

### N-08 — `archived_meter` is classified inconsistently between our guide and Stripe's enum

`[CITED: docs.stripe.com/api/v2/core/events/event-types]` + `[VERIFIED: guides/metering.md:450]`
`guides/metering.md`'s table classifies `archived_meter` as *"NO (sync 400)"*, i.e. a synchronous error.
But `archived_meter` **is one of the 10 values of the async error-report `code` enum**. Both can be true
(Stripe could return it synchronously *and* report it asynchronously), but the guide asserts the synchronous
classification as exclusive. **Do not restate the "Silent drop?" column as fact for `archived_meter` without
a live probe.** Added as **O-06** below. Same caution applies to `timestamp_in_future` and
`timestamp_too_far_in_past`, which the guide also marks sync-only while Stripe lists them as async codes.

## Architectural Responsibility Map

This is a server-side SDK library; the tiers below are the library's internal layers, not web app tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Build `GET /v1/billing/meters/:id/event_summaries` request | Resource module (`Billing.MeterEventSummary`) | — | House pattern: resource modules own `%Request{}` construction; `transfer_reversal.ex` is the exact template |
| HTTP execution, retries, headers, idempotency-key generation | `Client` / `Transport` behaviour | — | Already ships. Phase 64 adds nothing here and must not. |
| Cursor state machine / `has_more` following | `LatticeStripe.List` | Resource module supplies `%Request{}` + `Stream.map(&from_map/1)` | Phase 63's D-05 lock: pagination is **never** re-grown per resource. Works unmodified here because `id` is required (F-01). |
| Wire map → typed struct | Resource module `from_map/1` | — | "Typing happens at the resource layer, not via `ObjectTypes`" — so **no Phase 65 code dependency** |
| Required-param validation (`customer`/`start_time`/`end_time`) | `Resource.require_param!/3` called from the resource module | — | D-08; house ceiling of three is already set by `Billing.Meter.create/3` |
| Non-empty parent-id validation | private `validate_id!/2` in the resource module | — | D-09; `external_account.ex` idiom |
| Timestamp-alignment validation (GUARD-04) | `LatticeStripe.Billing.Guards` | Resource module calls it | D-10; `Guards` is the established numbered home (GUARD-01…03) |
| v2 thin-event fetch | `LatticeStripe.Webhook.fetch_event/3` | — | Already ships (N-05). Phase 64 documents the requirement, adds no code. |
| Thin-event `data` → typed struct | `Billing.MeterErrorReport.from_event/1` + `from_map/1` | `.Reason`, `.ErrorType`, `.SampleError` value objects | F-13: `ObjectTypes` dispatch **structurally cannot** reach this payload. Explicit call only. |
| Form encoding of `payload` dimensions | `LatticeStripe.FormEncoder` | — | Already generic and correct (F-19). **Do not touch** (D-23). |
| Drift `@known_fields` parsing | `LatticeStripe.Drift` | — | D-20 regex widening; the phase's only non-docs production edit outside the new modules |

**Tier boundary that must not be crossed:** `lib/lattice_stripe/object_types.ex` is **Phase 65 only**
(CONTEXT code_context §Integration Points). Phase 64 must not edit it.

## Standard Stack

### Core

**No new dependencies. Zero packages are added, removed, or version-bumped by this phase.**

Everything required already ships and was verified present and working in this session:

| Component | Where | Purpose | Why Standard |
|-----------|-------|---------|--------------|
| `LatticeStripe.List.stream!/2` | `lib/lattice_stripe/list.ex` | Entire auto-pagination mechanism | Phase 63 D-05 lock; works here unmodified because the object has a required `id` (F-01) |
| `LatticeStripe.Resource` | `resource.ex` | `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3` | Used verbatim by all ~50 resource modules |
| `LatticeStripe.Billing.Guards` | `billing/guards.ex` | Numbered pre-network raise family (GUARD-01…03 present) | GUARD-04 is the fourth member of an existing family, not a new pattern |
| `LatticeStripe.Webhook.fetch_event/2,3` | `webhook.ex:324-344` | Fetches the versioned v2 event | Required by F-12; already correct (`/v2/core/events/:id`) |
| `LatticeStripe.FormEncoder` | `form_encoder.ex` | Generic recursive form flattener | F-19: no allowlist, no defect — the MTR-04 subject, not a change target |
| ExUnit + Mox `~> 1.2` | `mix.exs` dev/test | Behaviour-based transport mocking | Only place pagination is provable (D-30/F-10) |
| `TestHelpers.list_json/3` | `test/support/test_helpers.ex:55-62` | Multi-page list fixtures with `has_more` | Extended by Phase 63 D-28; verified signature `(items, url \\ "/v1/objects", has_more \\ false)` |

### Supporting

| Component | Where | Purpose | When to Use |
|-----------|-------|---------|-------------|
| stripe-mock (Docker) | `stripe/stripe-mock:latest` | OpenAPI-validated integration server | D-34 integration test only. **Not running locally — see Environment Availability.** |
| `mix docs` (ExDoc `~> 0.34`) | dev dep | Differential warning gate | D-29 gate steps 1–3 |
| `mix credo --strict` | dev dep | Lint gate | D-29 gate step 5 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `List.stream!/2` delegation | Per-resource cursor loop | Rejected by Phase 63 D-05 and re-confirmed: the object's required `id` means the generic path needs no special-casing. A bespoke loop would duplicate `build_next_page_request/1`'s `base_params` preservation and `idempotency_key` strip — the two things D-30 assertions (2) and (6) exist to protect. |
| `require_param!/3` × 3 (D-08) | Collect-all-missing single raise | Rejected in D-08: requires inventing a new message format, breaking the D-10 verbatim lock shared by three shipped functions. |
| Private `validate_id!/2` (D-09) | `id in [nil, ""]` function clauses (`transfer_reversal.ex` style) | D-09 chose the `external_account.ex` helper form: 1 line per function vs ~7, and composes with default args for free. Both are in-repo precedent; the helper is strictly cheaper here because `list/4` and `stream!/4` both already have a defaults header. |
| Typed `.Reason`/`.ErrorType`/`.SampleError` (D-15) | Raw nested maps | Rejected in D-15. N-01 strengthens this: with four `data` fields and three nesting levels, raw-map access (`get_in(data, ["reason","error_types"])`) is exactly the shape that produced the two wrong guide snippets (N-03 rows 5 and 7). |

**Installation:** *(none — no package changes)*

```bash
# No dependency changes. Verify unchanged:
git diff --stat mix.exs mix.lock   # expect: mix.lock untouched; mix.exs only groups_for_modules (D-04)
```

**Version verification:** Not applicable — this phase introduces no external packages. The `mix.lock` must
be byte-identical before and after. `mix.exs` changes are limited to the `groups_for_modules` `"Billing
Metering"` list (D-04).

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.**

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| *(none)* | — | — | — | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

The `package-legitimacy check` seam was not invoked because there is no candidate package set. Every module,
function, and behaviour this phase uses is either in this repository at HEAD `7c57b1d` or in an already-locked
dependency (`mix.lock` unchanged). If a plan proposes adding any dependency, that is a scope violation of the
"minimal dependencies" constraint in `CLAUDE.md` and should be rejected rather than audited.

## Architecture Patterns

### System Architecture Diagram

```
                    ┌──────────────────────────── READ PATH (MTR-01, MTR-02) ────────────────────────────┐

 caller                                                                              Stripe
   │                                                                                    │
   │ list(client, meter_id, %{"customer"=>…, "start_time"=>…, "end_time"=>…}, opts)     │
   ▼                                                                                    │
 ┌──────────────────────────────────────┐                                               │
 │ Billing.MeterEventSummary            │                                               │
 │                                      │                                               │
 │  1. validate_id!(meter_id)  ─────────┼──► raise ArgumentError (D-09)                  │
 │  2. require_param! customer ─────────┼──► raise ArgumentError (D-08)                  │
 │  3. require_param! start_time ───────┼──► raise ArgumentError                         │
 │  4. require_param! end_time ─────────┼──► raise ArgumentError                         │
 │  5. Guards.check_summary_window! ────┼──► raise ArgumentError (GUARD-04, D-10)        │
 │        divisor: none→60 hour→3600 day→86400                                           │
 │        unknown window / unparseable ts ──► PASS THROUGH (mandatory hatch)             │
 │  6. build %Request{method: :get,                                                      │
 │       path: "/v1/billing/meters/#{id}/event_summaries"}                               │
 └───────────────┬──────────────────────────────────────┬────────────────────────────────┘
                 │ list/4                               │ stream!/4
                 ▼                                      ▼
        ┌────────────────┐                    ┌──────────────────────┐
        │ Client.request │                    │ List.stream!/2       │   ◄── NOT re-implemented
        └───────┬────────┘                    │  · fetch_page!       │
                │                             │  · _last_id from RAW │──► GET ?starting_after=mtrusg_…
                │                             │    maps (before      │       preserves customer,
                │                             │    typing) ⚠ D-05    │       start_time, end_time,
                │                             │  · strips            │       value_grouping_window
                │                             │    idempotency_key   │
                │                             └──────────┬───────────┘
                ▼                                        ▼
        Resource.unwrap_list(&from_map/1)      Stream.map(&from_map/1)
                │                                        │
                └────────────────┬───────────────────────┘
                                 ▼
                    %MeterEventSummary{id, object, aggregated_value (float),
                                       start_time, end_time, meter, livemode}
                                       ▲
                                       └── NO :customer field (F-02) — association lost
                                           unless the caller keeps it out of band


                    ┌──────────────────────── DIAGNOSE PATH (MTR-03) ────────────────────────┐

 Stripe ──webhook──► thin event body                     (NO data, NO changes — F-12)
                     {id, object:"v2.core.event", context, created, livemode,
                      type:"v1.billing.meter.error_report_triggered",
                      related_object:{id:"mtr_…", type:"billing.meter"},
                      reason:{request:{id, idempotency_key}, type}}   ◄── NOT the join key (N-04)
                            │
                            ▼
                  Webhook.construct_event / %EventNotification{}
                            │
                            │  ⚠ MANDATORY — data is a *fetched* attribute
                            ▼
                  Webhook.fetch_event(client, notif)  ──GET /v2/core/events/:id──► Stripe
                            │
                            ▼
                  %LatticeStripe.Event{data: raw_map, related_object: %RelatedObject{id: "mtr_…"}}
                            │
                            │  ObjectTypes.maybe_deserialize/1 CANNOT reach this:
                            │  dispatch is %{"object" => _}; this payload has no "object" key (F-13)
                            ▼
                  Billing.MeterErrorReport.from_event/1        ◄── primary constructor (D-16)
                            │      │
                            │      └─► from_map(event.data)  ◄── low-level; leaves :meter nil
                            ▼
        %MeterErrorReport{developer_message_summary, validation_start, validation_end,   ⚠ N-01
                          meter (from related_object.id — F-14),
                          reason: %Reason{error_count,
                                          error_types: [%ErrorType{code (String, open enum — D-18),
                                                                   error_count,
                                                                   sample_errors: [%SampleError{
                                                                       error_message,
                                                                       request_identifier ◄── THE JOIN KEY
                                                                   }]}]}}
                                                                        │
                                                                        ▼
                                              adopter's DB, keyed on the idempotency key
                                              ⚠ F-15: client.ex:169 auto-generates idk_ltc_<uuid>
                                                 when :idempotency_key is omitted → by default
                                                 this key maps to NOTHING in the adopter's DB
```

### Recommended Project Structure

```
lib/lattice_stripe/billing/
├── meter_event_summary.ex          # NEW — depth 2, request-owning (D-01)
├── meter_error_report.ex           # NEW — depth 2, NOT a resource (D-01/D-03)
├── meter_error_report/             # NEW — depth 3 value objects, own no %Request{} (D-03)
│   ├── reason.ex
│   ├── error_type.ex
│   └── sample_error.ex
└── guards.ex                       # EDIT — GUARD-04 + header line (D-10)

lib/lattice_stripe/
├── drift.ex                        # EDIT — line 210 regex widening (D-20)
└── billing/meter_event.ex          # EDIT — @doc payload bullet only (D-24.3)

guides/
├── metering.md                     # EDIT — new section @ ~L417 + 6 corrections (D-24, D-28, N-03)
├── metering-runtime-and-reconciliation.md  # EDIT — handler at L118-124 (N-03 row 7)
└── scope.md                        # EDIT — one "Deferred by design" bullet (D-27)

mix.exs                             # EDIT — groups_for_modules L179-190 only (D-04)

test/lattice_stripe/billing/
├── meter_event_summary_test.exs            # NEW — surface, guards, from_map, refutes
├── meter_event_summary_pagination_test.exs # NEW — D-30's nine Mox assertions
├── meter_error_report_test.exs             # NEW — D-32, pure, no transport
├── guards_test.exs | meter_guards_test.exs # EDIT — GUARD-04 matrix
└── ...
test/integration/
└── meter_event_summary_integration_test.exs # NEW — D-34, @moduletag :integration
test/lattice_stripe/
├── form_encoder_test.exs           # EDIT — D-33's float + decimal tests (currently 27 tests, ZERO float)
└── docs_truth_test.exs             # EDIT — ExDoc placement only (D-26 exception)
test/support/fixtures/
└── metering.ex (or similar)        # NEW — verbatim published payload (D-32), with the
                                    #       "PROMOTION TARGET (Phase 65)" header comment
```

### Pattern 1: Parent-scoped flat resource (the `transfer_reversal.ex` transliteration)

**What:** A resource served only under `/v1/parent/:id/child` is a **flat, depth-2 module named after the
wire `object` string**, with the parent id as the second positional argument.
**When to use:** MTR-01/MTR-02 — this is the whole read surface.
**Verified:** 50 request-owning modules in `lib/`; 37 at depth 1, 13 at depth 2, **zero at depth 3**
(`grep -rl "%Request{" lib/`). D-01 confirmed.

```elixir
# Source: lib/lattice_stripe/transfer_reversal.ex (read in full this session)
@spec list(Client.t(), String.t(), map(), keyword()) ::
        {:ok, Response.t()} | {:error, Error.t()}
def list(client, transfer_id, params \\ %{}, opts \\ [])          # defaults header

def list(%Client{}, id, _params, _opts) when id in [nil, ""] do   # ← D-09 prefers the
  raise ArgumentError, ~s|TransferReversal.list/4 requires a non-empty transfer id|
end                                                               #   external_account.ex
                                                                  #   private-helper form
def list(%Client{} = client, transfer_id, params, opts) when is_binary(transfer_id) do
  %Request{
    method: :get,
    path: "/v1/transfers/#{transfer_id}/reversals",
    params: params,
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&from_map/1)
end

@spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
def stream!(client, transfer_id, params \\ %{}, opts \\ [])
def stream!(%Client{}, id, _params, _opts) when id in [nil, ""], do: raise ArgumentError, ...
def stream!(%Client{} = client, transfer_id, params, opts) when is_binary(transfer_id) do
  req = %Request{method: :get, path: "/v1/transfers/#{transfer_id}/reversals",
                 params: params, opts: opts}
  List.stream!(client, req) |> Stream.map(&from_map/1)             # ← never a bespoke loop
end
```

### Pattern 2: Guards are the FIRST statements, before `%Request{}` is built

**What:** Every validation raise happens before any struct construction, and — critically for `stream!` —
before `Stream.resource/3` is returned.
**Why:** Phase 63 STATE note `[63-02]`: *"the customer guard is `stream!/3`'s FIRST statement so it raises
at call time; `Stream.resource/3` defers its start function, so a lazily-built guard would raise on the
first `Enum` step far from the caller."* This applies identically to `MeterEventSummary.stream!/4`'s
**five** guards (D-08 × 3, D-09, D-10).

```elixir
# Source: lib/lattice_stripe/entitlements/active_entitlement.ex:101-118 (Phase 63, verified)
def list(%Client{} = client, params \\ %{}, opts \\ []) do        # ← D-06: keep params \\ %{}
  Resource.require_param!(
    params,
    "customer",
    "LatticeStripe.Entitlements.ActiveEntitlement.list/3 requires a customer param"
  )
  # ... %Request{} built only after
end
```

For Phase 64, the message format is locked verbatim by D-08 — note the article changes on the third:

```
LatticeStripe.Billing.MeterEventSummary.list/4 requires a customer param
LatticeStripe.Billing.MeterEventSummary.list/4 requires a start_time param
LatticeStripe.Billing.MeterEventSummary.list/4 requires an end_time param
LatticeStripe.Billing.MeterEventSummary.list/4 requires a non-empty meter id
```

`require_param!/3` checks **key presence, not emptiness**, and reads **string keys only** — verified at
`resource.ex` (`Map.has_key?(params, key)`). Document this in `@doc` per D-08.

### Pattern 3: The guard that prints arithmetic instead of choosing (GUARD-04)

**What:** A pre-network raise that names the misaligned value, states the rule, names the real-world cause,
and shows the caller both floor and ceil — then refuses to pick.
**When to use:** D-10. This is the phase's only novel guard.
**Why it is a guard and not docs:** the rule is machine-readable and exact (F-06 verified verbatim below),
so there are **zero false positives**; and Stripe's error code for violating it is **undocumented** (F-07,
re-confirmed: absent from the spec's error enums), so we cannot improve the 400 after the fact.

Verified alignment rule, verbatim from `spec3.sdk.json`:

> `value_grouping_window`: *"…For hourly granularity, start and end times must align with hour boundaries
> (e.g., 00:00, 01:00, ..., 23:00). For daily granularity, start and end times must align with UTC day
> boundaries (00:00 UTC)."*
> `start_time`: *"The timestamp from when to start aggregating meter events (inclusive). **Must be aligned
> with minute boundaries.**"* — and identically on `end_time` (exclusive).

```elixir
# GUARD-04 shape (arity 2 so the message can name the calling function — D-10)
# lib/lattice_stripe/billing/guards.ex
def check_summary_window!(params, fun) when is_map(params) do
  divisor =
    case params["value_grouping_window"] do
      nil    -> 60        # the minute rule applies to EVERY query, windowed or not
      "hour" -> 3_600
      "day"  -> 86_400
      _other -> nil       # MANDATORY hatch: Stripe extended this enum once already
    end                   # (stripe-python#1353 added "day" in 2024-06)

  if divisor, do: Enum.each(["start_time", "end_time"], &check_aligned!(params, &1, divisor, fun))
  :ok
end
# absent / unparseable timestamps also pass through — require_param!/3 and Stripe's
# own type validation own those cases (D-10)
```

Proposed microcopy is in CONTEXT §Specific Ideas and should be used substantially as written. Note its use
of `Integer.floor_div/2` rather than `div/2` — `div/2` truncates toward zero and rounds the wrong way for
negative inputs. Elixir has **no** `DateTime.beginning_of_hour/1`, and `DateTime.truncate/2` only truncates
sub-second precision, so integer arithmetic is genuinely necessary here.

### Pattern 4: Typed value-object nesting for a non-resource payload

**What:** A payload with no endpoint, no `id`, and no `object` string is still fully typed — as a flat
depth-2 module whose sub-objects nest at depth 3 and own no `%Request{}`.
**In-repo analogue:** `lib/lattice_stripe/tax/calculation.ex` — `tax_breakdown` as a bare array of typed
sub-structs (D-15's cited precedent).
**Constructor asymmetry is a contract, not an accident (D-16):**

```elixir
# from_event/1 is primary — it is the ONLY constructor that can populate :meter (F-14)
def from_event(%LatticeStripe.Event{data: data, related_object: related}) do
  %{from_map(data) | meter: related && related.id}    # nil-safe: no_meter_found has no
end                                                   # related_object at all (N-06)

def from_map(%__MODULE__{} = r), do: r                # idempotency clause (D-07 style)
def from_map(nil), do: nil
def from_map(data) when is_map(data) do
  %__MODULE__{
    developer_message_summary: data["developer_message_summary"],   # ⚠ N-01
    validation_start: data["validation_start"],                     # ⚠ N-01 — RFC3339 string
    validation_end: data["validation_end"],                         # ⚠ N-01 — RFC3339 string
    reason: Reason.from_map(data["reason"]),
    meter: nil,                                                     # asserted contract (D-16)
    extra: Map.drop(data, @known_fields)
  }
end
```

### Anti-Patterns to Avoid

- **Re-growing pagination.** Any per-resource `starting_after` loop. `List.stream!/2` handles it; the
  object's required `id` (F-01) means no special-casing is needed. Phase 63 D-05.
- **Typing the list data before `List.from_json/3` sees it.** `list.ex`'s `last_item_id/1` matches
  `%{"id" => id}` on **raw maps**. Type first and the cursor silently becomes `nil` → pagination stops at
  page 1 with no error. This is D-30 assertion (9) and Phase 63 mutation-checked the identical failure.
- **Registering `billing.meter_error_report` in `ObjectTypes`.** Structurally dead (F-13, verified:
  `object_types.ex` dispatch is `def maybe_deserialize(%{"object" => object_type} = map)`). Phase 65's
  OBJ-01 already excludes it; lock with a `refute` (D-14/D-31).
- **`String.to_atom/1` on `code`.** Server-controlled, open enum, demonstrably growing (D-18). Never.
- **Inventing `:id`/`:object`/`:livemode` on `MeterErrorReport`** (D-17), or renaming `reason` to
  `validation_errors` (D-13) — the latter makes the module unsearchable against Stripe's docs.
- **Patching `to_string/1` in `form_encoder.ex`** (D-23). A silent cross-cutting change on the eve of a
  release. Blocked on O-01.
- **Asserting on `resp.data.url` in the integration test.** stripe-mock returns a literal placeholder
  `/v1/billing/meters/id_123/event_summaries` that does not echo the requested meter id (F-10/D-34).
- **Refuting `list/2` or `list/3` on `MeterEventSummary`.** They exist via default args (D-31's explicit
  warning). Refute `retrieve/2,3`, `create/2,3`, `update/3,4`, `delete/2,3`, `stream/3`, `align_window/2`.
- **Adding a new docs-truth prose grep** (D-26). Budget is zero. A grep is structurally incapable of
  catching "the prose says something false" — pitfall #4 has been present-and-false since v1.1 and no lock
  noticed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Following `has_more` / cursors | A `starting_after` loop in `MeterEventSummary` | `LatticeStripe.List.stream!/2` | Already handles `base_params` preservation, `idempotency_key` stripping on page 2+, search-token vs cursor branching, and backward pagination. Re-implementing loses D-30 assertions (2) and (6) silently. |
| Missing-param errors | Bespoke `if`/`case` + custom message | `Resource.require_param!/3` with the D-10 verbatim format | The message format is a shared lock across `Meter.create/3`, `MeterEvent.create/3`, `ActiveEntitlement.list/3`. A new format breaks a cross-module contract to save keystrokes. |
| Timestamp snapping | `align_window/2`, `floor_to_day/1`, any auto-coercion | **A raise that prints the arithmetic** (D-10) | Rounding *changes what the query means*. Orb auto-aligns to local midnight → a 3-day UTC range yields **4** windows; Datadog silently overrides an explicit `.rollup(60)`. Silent coercion is the exact bug class this milestone exists to kill. |
| Form-encoding `payload` dimensions | A dimension-aware encoder or an allowlist | `LatticeStripe.FormEncoder` unchanged | F-19 re-verified by execution: generic recursive flattener, no allowlist. Arbitrary keys and 36-digit decimal strings survive byte-exact. There is no defect to fix. |
| Fetching v2 event `data` | Manual `GET /v2/core/events/:id` | `LatticeStripe.Webhook.fetch_event/2,3` | Already ships, already uses the correct v2 path (not `/v1/events/`), already returns a typed `%Event{}` with `related_object` (N-05). |
| Grouping errors by code / counting them | `Enum.group_by/2` helpers on `MeterErrorReport` | Nothing — ship zero helpers | Stripe already groups by `error_types` and supplies `error_count` at **both** levels (verified, N-01). The wire supplies the ergonomics. |
| Multi-page test fixtures | Hand-built list JSON | `TestHelpers.list_json/3` | Verified signature `(items, url \\ "/v1/objects", has_more \\ false)`; Phase 63 D-28 already added the `has_more` arg for exactly this. |
| Enforcing public surface shape | Typespecs / Dialyzer | `refute function_exported?/3` | `CLAUDE.md` excludes Dialyzer and typespecs are documentation-only. Verified **22 test files** already use this idiom. It is the *only* enforcement available. |

**Key insight:** every "new" capability this phase appears to need already exists one layer down. The genuine
net-new code is three guards' worth of validation logic, four small structs, and one regex character class.
Anything larger than that is a sign a plan is re-implementing something.

## Common Pitfalls

### Pitfall 1: The returned summary cannot tell you which customer it belongs to

**What goes wrong:** A reconciler lists summaries for customer A, then customer B, merges them, and can no
longer attribute rows.
**Why it happens:** `[VERIFIED: spec3.sdk.json]` the object has **exactly 7 fields** —
`id`, `object`, `aggregated_value`, `start_time`, `end_time`, `meter`, `livemode`. There is **no `customer`
field**, no `created`, no `metadata`, and `x-expandableFields: []` so it cannot be expanded in.
**How to avoid:** keep the customer association out of band (it was an input, not an output). Moduledoc-mandatory
per F-02.
**Warning signs:** any code doing `Enum.group_by(summaries, & &1.customer)`.

### Pitfall 2: Truncation at the default `limit` of 10 produces a plausible wrong number

**What goes wrong:** Summing `list/4` results without checking `has_more`.
**Why it happens:** `[VERIFIED: spec3.sdk.json]` *"Limit can range between 1 and 100, and the default is 10."*
A 31-day hourly window is **744 buckets**; you get 10.
**Quantified (from CONTEXT §Specific Ideas, arithmetic checked):** summing those 10 yields **~1.3%** of the
truth. Request amplification across 200 customers: 15,000 requests at the default, 1,600 at `limit=100`,
**200** with no `value_grouping_window` at all.
**How to avoid:** teach the total/series split explicitly — omit `value_grouping_window` for a total (one
server-aggregated bucket, one request, no pagination, no client-side float summation); use `stream!/4` for a
series.
**Warning signs:** `Enum.sum` over a `list/4` result.

### Pitfall 3: Every natural timestamp source is misaligned

**What goes wrong:** `HTTP 400` with an undocumented error code.
**Why it happens:** `subscription.current_period_start` derives from `billing_cycle_anchor` and lands on an
arbitrary second — violating even the universal **minute** rule, before any hour/day window is considered.
**How to avoid:** GUARD-04 (D-10).
**Warning signs:** timestamps not divisible by 60.
**⚠ Do NOT claim an incidence rate.** D-12: the "~100% on first run" figure was an inference from the spec,
not an observation; issue archaeology found zero public bug reports. Mechanism verified, incidence not.

### Pitfall 4: `data` is not in the webhook body

**What goes wrong:** A handler reads `event.data` from the delivered webhook and gets `nil`.
**Why it happens:** `[CITED: docs.stripe.com/api/v2/core/events/event-types]` — `data` and `changes` are
listed under a **"Fetched attributes"** heading, and the page states *"The payload of thin events is
unversioned. During processing, you must fetch the versioned event from the API."*
**How to avoid:** `Webhook.fetch_event/3` first, always. It is the first line of the guide's headline snippet
for exactly this reason.
**Warning signs:** any handler for this event type that does not call `fetch_event`. **Two shipped guides
currently have this bug** (N-03 rows 5 and 7).

### Pitfall 5: The only correlation key in the error report maps to nothing by default

**What goes wrong:** An operator receives an error report, extracts
`sample_errors[].request.identifier`, and finds no matching row in their database.
**Why it happens:** `[CITED: Stripe v2 event-types reference]` that field is documented as *"The request
idempotency key."* — the **HTTP** idempotency key, not `MeterEvent.identifier`. And
`[VERIFIED: client.ex:169]` LatticeStripe **auto-generates** an `idk_ltc_`-prefixed UUID v4 for POSTs when
`:idempotency_key` is omitted.
**How to avoid:** pass a domain-derived `idempotency_key:` on every `MeterEvent.create/3`. This is F-15, and
CONTEXT calls it *"the single highest-value line this phase can write."* The shipped fire-and-forget recipe
already does this (`idempotency_key: event_id`) — the guide must make the *reason* explicit.
**Warning signs:** `MeterEvent.create/3` called without `idempotency_key:`.

### Pitfall 6: Elixir's float stringifier flips to scientific notation earlier than any other ecosystem

**What goes wrong:** `payload[value]=1.0e-5` goes on the wire.
**Why it happens:** `[VERIFIED: direct execution this session]`

```
0.00001  → v=1.0e-5      ← the cliff, one decimal place from values people bill on
0.0001   → v=0.0001
0.1+0.2  → v=0.30000000000000004
```

Node flips at `1e-6`; stripe-go uses `strconv.FormatFloat(v,'f',…)`, whose `'f'` verb **never** emits
exponent form. Elixir's threshold is the narrowest in the set.
**How to avoid:** pass decimals as **strings**. Verified: a 36-digit decimal string survives byte-exact.
**⚠ What we must NOT claim:** whether Stripe's parser accepts `1.0e-5`. That is **O-01**, unresolved. The
guide's sentence must stay: *"pass decimals as strings; Stripe does not document whether its parser accepts
exponent notation, so do not rely on it either way."* — correct under all three possible outcomes.

### Pitfall 7: The SDK will happily build a request Stripe refuses

**What goes wrong:** A nested `payload` map encodes fine locally and 400s on the wire.
**Why it happens:** `[VERIFIED: direct execution]` `encode(%{"payload" => %{"meta" => %{"a" => "b"}}})`
→ `payload[meta][a]=b`. But `[VERIFIED: spec3.sdk.json]` the schema is
`payload: {type: object, additionalProperties: {type: string}}` — **values must be strings**, so nested
objects are invalid by construction. Stripe responds `value is not a string (Kind: map)`.
**How to avoid:** document "flat only" as payload rule #1. Documented nowhere today.
**Warning signs:** a map or list under any `payload` key.

### Pitfall 8: `nil` values vanish silently from the encoded body

**What goes wrong:** `%{"value" => nil}` is dropped entirely rather than sent as empty.
**Why it happens:** `[VERIFIED: direct execution]` `encode(%{"a" => nil, "b" => "1"})` → `"b=1"`.
`form_encoder.ex` `flatten_value(nil, _key)` returns `[]` by design.
**How to avoid:** send `"0"`, never `nil`, for a zero value. Belongs in the input → wire coercion table.

## Code Examples

### Verified: the exact object shape to model

```elixir
# Source: stripe/openapi@master/openapi/spec3.sdk.json, info.version "2026-06-24.dahlia"
# schema: components.schemas["billing.meter_event_summary"]
# required: ["aggregated_value","end_time","id","livemode","meter","object","start_time"]
# x-expandableFields: []
# x-stripeResource: {"class_name":"MeterEventSummary","has_collection_class":true,"in_package":"Billing"}
#                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ D-01.4 confirmed verbatim

@known_fields ~w[id object aggregated_value start_time end_time meter livemode]   # ← ~w[ ] per D-19/D-20

defstruct [
  :id,                  # "mtrusg_…"  — REQUIRED, so List.stream!/2 works unmodified (F-01)
  :aggregated_value,    # JSON number → float() in Elixir, NOT integer (F-05)
  :start_time,          # Unix integer (v1 convention — contrast MeterErrorReport, N-01)
  :end_time,
  :meter,               # "mtr_…"
  :livemode,
  object: "billing.meter_event_summary",
  extra: %{}
]
# NOTE: there is deliberately no :customer field — Stripe does not return one (F-02).
```

### Verified: the ambiguity that must be documented, not resolved

`[VERIFIED: spec3.sdk.json]` — three descriptions on the same object, two of which contradict the third:

```
end_time (query param): "The timestamp from when to stop aggregating meter events (exclusive)."
end_time (object field): "End timestamp for this event summary (exclusive)."
aggregated_value:        "Aggregated value of all the events within `start_time` (inclusive)
                          and `end_time` (inclusive)."     ← ⚠ contradicts the other two
```

Two of three say exclusive. **Document the ambiguity; assert neither** (F-08). All three ship verbatim into
every SDK's generated docstrings, so adopters will meet the contradiction elsewhere too.

### Verified: pagination cursor derivation happens on raw maps

```elixir
# Source: lib/lattice_stripe/list.ex (read this session)
defp last_item_id([]), do: nil
defp last_item_id(items) do
  case Enum.at(items, -1) do
    %{"id" => id} -> id        # ← RAW map match. Type before this and the cursor is nil.
    _ -> nil
  end
end

# and, page 2+ construction:
defp build_next_page_request(%__MODULE__{} = list) do
  base_params = Map.drop(list._params, ["starting_after", "ending_before", "page"])
  #             ^^^^^^^^^^^ customer, start_time, end_time, value_grouping_window all survive
  #                         → D-30 assertion (2), the phase's highest-value test
  opts = Keyword.delete(list._opts, :idempotency_key)   # → D-30 assertion (6)
  %Request{method: :get, path: list.url, params: Map.merge(base_params, pagination_params), opts: opts}
end
```

### Verified: the multi-page Mox pattern D-30 must mirror

```elixir
# Source: test/lattice_stripe/list_test.exs:384-449 (read this session)
test "fetches page 2 when page 1 has_more: true and emits items from both pages" do
  LatticeStripe.MockTransport
  |> expect(:request, fn _req -> list_response([%{"id" => "cus_1"}, %{"id" => "cus_2"}], true) end)
  |> expect(:request, fn _req -> list_response([%{"id" => "cus_3"}], false) end)

  items = test_client() |> List.stream!(customers_req()) |> Enum.to_list()
  assert items == [%{"id" => "cus_1"}, %{"id" => "cus_2"}, %{"id" => "cus_3"}]
end
```

For D-30 the `fn _req ->` must become `fn req ->` with assertions on `req.params` — that is where assertion
(2) lives. `req.body` is likewise available on the transport request map (`transport.ex:36-40`), making
D-33's exact-wire-body assertions cheap.

### Verified: the encoder facts MTR-04 documents (all reproduced this session)

```elixir
# mix run, against this worktree at HEAD 7c57b1d:
FormEncoder.encode(%{"payload" => %{"value" => 5}})    == "payload[value]=5"
FormEncoder.encode(%{"payload" => %{"value" => "5"}})  == "payload[value]=5"    # BYTE-IDENTICAL
# → guides/metering.md pitfall #4 is FALSE for v1. (True only for the v2 JSON stream.)

FormEncoder.encode(%{"payload" => %{"region" => "us-east", "model" => "gpt", "value" => "0.000001"}})
#=> "payload[model]=gpt&payload[region]=us-east&payload[value]=0.000001"   # arbitrary dims, no allowlist

FormEncoder.encode(%{"v" => "0.123456789012345678901234567890123456"})
#=> "v=0.123456789012345678901234567890123456"                             # 36 digits, byte-exact

FormEncoder.encode(%{"v" => 0.00001})  == "v=1.0e-5"     # ← D-33's lock assertion, confirmed
FormEncoder.encode(%{"v" => 0.1 + 0.2}) == "v=0.30000000000000004"
FormEncoder.encode(%{"payload" => %{"meta" => %{"a" => "b"}}}) == "payload[meta][a]=b"  # Stripe 400s
FormEncoder.encode(%{"a" => nil, "b" => "1"}) == "b=1"   # nil vanishes
```

### Verified: the headline consumer snippet is implementable exactly as CONTEXT drafts it

`%LatticeStripe.Event{}` carries `:data` and `:related_object`; `Webhook.fetch_event/2,3` returns it. The
CONTEXT §Specific Ideas snippet needs no change other than reflecting N-01's extra fields where useful
(e.g. logging `report.validation_start`..`validation_end` alongside the codes).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `value_grouping_window` enum was `["hour"]` only | `["day","hour"]` | stripe-python 10.1.0, 2024-06 (stripe-python#1353) | **Justifies D-10's mandatory pass-through hatch** for unrecognised window values — Stripe has extended this enum once already |
| `meter_event_value_not_found` error code | **Retired.** Not among the live 10 (N-02) | undated | `guides/metering.md:449` still documents it — a concrete instance of F-16 |
| No digit limit on meter values | 15-digit validation, *"double precision loss in the usage aggregation pipeline"* | Stripe changelog `dahlia` 2026-04-22 | Surfaces as `meter_event_value_too_many_digits` (live in the enum, **absent from our guide's table**). ⚠ Our pin is `2026-03-25.dahlia` (`config.ex:57`) — **one release earlier than this change** |
| `/v1/billing/meters/:id/event_summaries` | `/v1/billing/analytics/meter_usage` (preview) | `spec3.beta.sdk.json` `2026-06-24.preview` | Renames to `starts_at`/`ends_at`, adds full IANA `timezone`, widens window enum to `day\|week\|month\|hour`, adds `refreshed_at`. **Deferred.** N-07: the minute-alignment rule survives, so D-10 stays valid across the migration |
| Untyped nested webhook payloads | Typed sub-structs at every level | — | 6 of 7 official SDKs type every level; the sole dissenter is stripe-php, whose raw-map shape is what this milestone exists to undo |

**Deprecated/outdated in our own docs:**
- `guides/metering.md:425-437` handler — uses the v1 `%Event{}` + `data["object"]` shape for a v2 thin event.
- `guides/metering-runtime-and-reconciliation.md:118-124` — same, plus reads a non-existent `["id"]`.
- `guides/metering.md:449` — `meter_event_value_not_found` no longer exists.
- `guides/metering.md:585-587` + `:118-124` — the integer-vs-string claim, false for v1 since v1.1
  (`git log -S "Integers trigger"` → `e5966f6`, *"v1.1: Accrue unblockers"*; **accrue pins `~> 1.1`**).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `data` field ordering shown in N-01 is alphabetical presentation, not wire ordering — I assume no semantic significance to order | N-01 | None. Map decoding is order-independent. |
| A2 | `developer_message_summary`'s full description is *"Extra field included in the event's …"* (truncated in extraction) — I assume it is a human-readable summary string with no parseable structure | N-01 | Low. Typing it as `String.t()` is safe regardless; worst case the moduledoc under-describes it. |
| A3 | `validation_start`/`validation_end` are RFC3339 strings like every other v2 event timestamp (F-18's rule), not Unix integers — the reference types them `timestamp` without specifying encoding | N-01, D-19 | **Medium.** If they are integers, the struct types and the D-32 assertion are wrong. **Mitigation: D-32's fixture must be seeded from a verbatim published payload (D-32 already mandates this), which settles it at implementation time.** Note stripe-php types v2 timestamps `int`, which F-18 says is wrong — so the ecosystem itself is inconsistent here. |
| A4 | The `~1.3%` truncation figure (744 hourly buckets, 10 returned) assumes uniform usage across buckets | Pitfall 2 | Low. It is illustrative; the guide should present it as an example, not a law. |
| A5 | stripe-mock `v0.199.0`'s behavior described in F-10 (one synthetic item, ignores `limit`/`starting_after`, accepts unaligned timestamps, placeholder `url`) — I could **not** re-verify this, as stripe-mock is not running locally | D-34, Environment | **Medium.** If stripe-mock actually honors `limit`, D-34's "cannot prove pagination" claim is too pessimistic — but the mitigation (prove pagination via Mox) is correct either way and costs nothing. Phase 63's STATE note independently records the same stripe-mock limitation, which corroborates it. |
| A6 | The 42-warning ExDoc baseline will still be 42 at the time plans execute | D-29 | Low. Re-measured this session: **42, exit 0**. Any drift is caught by the gate itself. |

## Open Questions

Carried from CONTEXT (O-01…O-05, unchanged and still unresolved) plus one new.

1. **O-01 — does Stripe's parser accept `1.0e-5` as a `payload[value]`?**
   - What we know: our encoder emits it (verified); stripe-mock validates only `type: string` so it passes
     trivially and proves nothing.
   - What's unclear: whether mangling fails **loudly** (sync 400 / async `meter_event_invalid_value`) or
     **silently corrupts a bill**.
   - Recommendation: **do not guard, do not claim.** Ship the outcome-independent sentence quoted in
     Pitfall 6. It gets *stronger*, not corrected, if a probe later shows a 400. Blocks the deferred
     `float_to_binary` change (D-23).

2. **O-02 — max/min window span and lookback limit for summary reads.** Undocumented. The verified 35-day
   limit applies to **ingestion**, not summary reads. Recommendation: say nothing.

3. **O-03 — the actual error code for a misaligned timestamp.** Re-confirmed absent from the spec's error
   enums (F-07). Recommendation: **do not pattern-match on it.** GUARD-04 exists precisely because we cannot
   improve this 400 after the fact.

4. **O-04 — do deactivated meters still serve summaries?** Believed yes, unverified. Note `archived_meter`
   is a live error code, which is suggestive but not dispositive.

5. **O-05 — are zero-value buckets emitted for empty periods, or skipped?** Recommendation: charts must fill
   gaps **by `start_time`, never by index.** State this as defensive guidance regardless of the answer.

6. **⚠ O-06 (NEW) — is the guide's sync-vs-async classification of `archived_meter`,
   `timestamp_in_future`, and `timestamp_too_far_in_past` correct?**
   - What we know: `guides/metering.md:450-452` marks all three *"NO (sync 400)"*. All three **are** values
     of the async error-report `code` enum (N-02).
   - What's unclear: whether they are async-only, sync-only, or both.
   - Recommendation: when rewriting the error-code table (N-03 row 6), **do not restate the "Silent drop?"
     column as verified fact for these three.** Either drop the column for them, mark them "both/unverified",
     or resolve with a live probe. Restating an unverified classification is exactly the failure mode MTR-04
     exists to fix.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | everything | ✓ | **1.19.5** | — |
| Erlang/OTP | everything | ✓ | **28** (erts-16.3) | — |
| ExUnit | all tests | ✓ | stdlib | — |
| Mox | D-30, D-33 pagination/encoder proofs | ✓ | locked in `mix.lock` | — |
| ExDoc (`mix docs`) | D-29 gate steps 1–3 | ✓ | exits 0, **42 warnings** | — |
| Credo (`--strict`) | D-29 gate step 5 | ✓ | locked | — |
| Docker | running stripe-mock | ✓ | daemon responds | — |
| **stripe-mock on `localhost:12111`** | **D-34 integration test** | **✗ NOT RUNNING** | — | **Start it:** `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` |
| Network (raw.githubusercontent.com, docs.stripe.com) | spec re-verification | ✓ | — | — |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** stripe-mock is not currently listening. This is **not blocking**:

- The integration suite is **excluded by default** — `test/test_helper.exs:2` is
  `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])`, and the current
  baseline run reports `204 excluded`. `mix test` is green without it.
- D-34's `setup_all` **raises** (never skips) with the docker command when the port is closed — the
  `charge_integration_test.exs:19-27` pattern, verified. Phase 63 STATE note `[63-05]` records this as a
  deliberate choice: *"no `@tag :skip` and no capability probe, because a probe's failure mode is the silent
  skip."* Follow it exactly.
- Every claim D-34's test would prove is **already independently verified** in this research from the
  OpenAPI spec (path, required params, enum values). The integration test is a regression guard, not the
  source of truth.

**Action for the planner:** the plan containing D-34's integration test must include starting stripe-mock as
an explicit prerequisite step, and must not treat a green `mix test` (which excludes it) as proof that test
ran.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **ExUnit** (Elixir 1.19.5 stdlib) + **Mox `~> 1.2`** for the `Transport` behaviour |
| Config file | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])` |
| Quick run command | `mix test test/lattice_stripe/billing/` |
| Full suite command | `mix test` |
| Integration command | `mix test --only integration` *(requires stripe-mock on :12111)* |
| Current baseline | **2188 tests, 0 failures, 1 skipped, 204 excluded — 3.0s** |
| Full CI gate | `mix ci` = `format --check-formatted` → `compile --warnings-as-errors` → `credo --strict` → `test` → `docs --warnings-as-errors` |

⚠ **`mix ci` is RED at clean HEAD** and not because of this phase — its final step trips on the 42
pre-existing ExDoc warnings (STATE `[63-07]`). **Do not use `mix ci` as this phase's gate.** Use D-29's
five-step differential gate instead (steps 1–4 of `mix ci` pass; step 5 is replaced by the differential
count).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MTR-01 | `list/4` builds `GET /v1/billing/meters/:id/event_summaries` with all four params | unit (Mox) | `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | ❌ Wave 0 |
| MTR-01 | `from_map/1` types all 7 fields; `aggregated_value` is a float; no `:customer` key exists | unit | same | ❌ Wave 0 |
| MTR-01 | `from_map(%MeterEventSummary{})` is idempotent (D-07) | unit | same | ❌ Wave 0 |
| MTR-01 | three `require_param!` raises fire first-failure in order `customer`→`start_time`→`end_time`, with D-08's **verbatim** messages | unit | same | ❌ Wave 0 |
| MTR-01 | `validate_id!/2` raises on `nil` and `""` meter id, message per D-09 | unit | same | ❌ Wave 0 |
| MTR-01 | GUARD-04 matrix: aligned passes; misaligned raises for divisor 60/3600/86400; **unknown window passes through**; **absent/unparseable timestamps pass through** | unit | `mix test test/lattice_stripe/billing/guards_test.exs test/lattice_stripe/billing/meter_guards_test.exs` | ⚠️ files exist, cases ❌ Wave 0 |
| MTR-01 | surface refutation: `retrieve/2,3`, `create/2,3`, `update/3,4`, `delete/2,3`, `stream/3`, `align_window/2` absent; **`list/2,3` NOT refuted** | unit (structural) | `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | ❌ Wave 0 |
| MTR-01 | `Billing.Meter.event_summaries/3,4` absent (stripe-java#1852 lock) | unit (structural) | `mix test test/lattice_stripe/billing/meter_test.exs` | ⚠️ file exists, case ❌ Wave 0 |
| MTR-01 | live path served; the three required-param 400s in order; enum rejection; served body decodes | integration | `mix test --only integration test/integration/meter_event_summary_integration_test.exs` | ❌ Wave 0 — **needs stripe-mock** |
| MTR-02 | D-30's nine assertions (cursor from last `mtrusg_` id; **page 2 preserves all four filter params**; N pages = N calls; `Stream.take(1)` = 1 call; `stripe-account` carries; **no `idempotency-key` on page 2**; page-2 path = response `url`; page-2 500 raises `LatticeStripe.Error`; **`_last_id` derived before typing**) | unit (Mox, multi-page) | `mix test test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` | ❌ Wave 0 |
| MTR-03 | `from_map/1` decodes the verbatim published payload incl. **`developer_message_summary`, `validation_start`, `validation_end`** (N-01) | unit (pure) | `mix test test/lattice_stripe/billing/meter_error_report_test.exs` | ❌ Wave 0 |
| MTR-03 | `request_identifier` resolves — **the join key**; also resolves from the legacy `%{"idempotency_key" => …}` shape | unit (pure) | same | ❌ Wave 0 |
| MTR-03 | `assert is_binary(code)` (encodes D-18's no-atomization decision) | unit (pure) | same | ❌ Wave 0 |
| MTR-03 | `refute Map.has_key?(struct, :id)` / `:object` / `:livemode` (encodes D-17) | unit (structural) | same | ❌ Wave 0 |
| MTR-03 | missing `error_types` → `[]` not `nil` (D-19) | unit (pure) | same | ❌ Wave 0 |
| MTR-03 | `sample_errors: []` with `error_count: 900` still decodes (the real high-volume shape) | unit (pure) | same | ❌ Wave 0 |
| MTR-03 | `from_map(data).meter == nil` while `from_event/1` populates it (D-16 as asserted contract) | unit (pure) | same | ❌ Wave 0 |
| MTR-03 | a `no_meter_found`-shaped event with `related_object: nil` decodes (F-17/N-06) | unit (pure) | same | ❌ Wave 0 |
| MTR-03 | `list/2,3`, `retrieve/2,3`, `create/2,3` absent; `from_map/1` + `from_event/1` present | unit (structural) | same | ❌ Wave 0 |
| MTR-03 | `ObjectTypes` has no `billing.meter_error_report` key (D-14/D-31) | unit (structural) | `mix test test/lattice_stripe/object_types_test.exs` | ⚠️ file exists, case ❌ Wave 0 |
| MTR-04 | exact-body round-trip: three custom dimensions + decimal-string value | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | ⚠️ file exists (27 tests, **zero** float/decimal), cases ❌ Wave 0 |
| MTR-04 | **`encode(%{"v" => 0.00001}) == "v=1.0e-5"`** — locks known behavior so the doc warning cannot silently become false | unit | same | ❌ Wave 0 |
| MTR-04 | `MeterEvent.create/3` does not filter `payload` keys | unit (Mox at transport, assert `req.body`) | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ⚠️ file exists, case ❌ Wave 0 |
| MTR-04 | flat dimensions → 200 **and nested payload → 400** (the only proof of the Stripe-side half; would have caught F-20.2) | integration | `mix test --only integration` | ❌ Wave 0 — **needs stripe-mock** |
| MTR-04 | ExDoc **placement** assertion extended to Phase 64's five new modules (D-26's structural exception) | unit (config) | `mix test test/lattice_stripe/docs_truth_test.exs` | ⚠️ file exists, case ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/billing/` — the tightest loop that covers the phase's
  new modules and the guards they call. Sub-second on the current suite.
- **Per wave merge:** `mix test` — full suite, **3.0 s**, baseline 2188 passing. There is no reason to skip
  it at any checkpoint; it is cheaper than the decision to skip it.
- **Phase gate (D-29's five steps, replacing the RED `mix ci`):**
  1. `mix format --check-formatted && mix compile --warnings-as-errors`
  2. `mix credo --strict` — green
  3. `mix test` — green, count **≥ 2188** (never fewer)
  4. `mix docs` exits 0 **and** warning count **≤ 42** (never up). ⚠ **Bonus target 40** — the two fixable
     warnings are `lib/lattice_stripe/billing/meter_event_stream.ex:15` and `:24`
     (*"Illegal attributes […] ignored in IAL"*, caused by indented code-block lines beginning `{:ok, …}`);
     re-indent or fence them and the gate can use the clean `meter` substring.
  5. **Zero** `mix docs` warnings naming any Phase 64 **new file path** — scoped by exact path, **not** by
     the substring `meter` (unless step 4's bonus lands first).
- **Not in the gate, run explicitly:** `mix test --only integration` after
  `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`. `mix test` **excludes** it (204
  excluded), so a green full suite is **not** evidence the integration tests ran.

### Wave 0 Gaps

- [ ] `test/lattice_stripe/billing/meter_event_summary_test.exs` — covers MTR-01 (surface, guards, `from_map`, refutations)
- [ ] `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` — covers MTR-02 (D-30's nine assertions)
- [ ] `test/lattice_stripe/billing/meter_error_report_test.exs` — covers MTR-03 (pure, no transport)
- [ ] `test/integration/meter_event_summary_integration_test.exs` — covers MTR-01 wire behavior + MTR-04's nested-payload 400
- [ ] `test/support/fixtures/` — a metering fixture module seeded from the **verbatim published payload**
      (D-32), carrying the `PROMOTION TARGET (Phase 65)` header comment cloned from
      `test/support/fixtures/entitlements.ex`
- [ ] New cases in existing files: `guards_test.exs` / `meter_guards_test.exs` (GUARD-04 matrix),
      `form_encoder_test.exs` (float + decimal, currently zero), `meter_event_test.exs` (no-filter proof),
      `meter_test.exs` (`event_summaries` refutation), `object_types_test.exs` (dead-key refutation),
      `docs_truth_test.exs` (ExDoc placement)
- [ ] Framework install: **none needed** — ExUnit + Mox already present and green

**No new test framework, runner, or helper is required.** `TestHelpers.list_json/3` already supports
`has_more`; `req.body` is already exposed on the transport request map.

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json`, so this section is included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | **no** (unchanged) | Bearer `sk_…` via `Client`; this phase adds no auth surface |
| V3 Session Management | **no** | Stateless SDK; no sessions (the `MeterEventStream.Session` is a Stripe API token, untouched here) |
| V4 Access Control | **partial** | `stripe-account` (Connect) header must survive pagination — **D-30 assertion (5)** is an access-control test: a dropped `stripe-account` on page 2 would read the **platform's** data instead of the connected account's |
| V5 Input Validation | **yes** | `Resource.require_param!/3` (D-08), `validate_id!/2` (D-09), `Billing.Guards.check_summary_window!/2` (D-10) — all pre-network, all raising |
| V6 Cryptography | **no** | No crypto introduced. Webhook HMAC verification (`Plug.Crypto.secure_compare/2`) is existing, untouched |
| V7 Error Handling & Logging | **yes** | `MeterErrorReport` **is** an error-handling surface. D-19: no custom `Inspect` — deliberate, because the idempotency key **is** the diagnostic payload |
| V8 Data Protection | **yes** | See threat table: the error report carries idempotency keys, which are auth-adjacent |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path injection via unvalidated `meter_id` interpolated into `"/v1/billing/meters/#{id}/event_summaries"` | Tampering | `validate_id!/2` (D-09) rejects `nil`/`""`. **Note the observed real-world form:** stripe-go's `FormatURLPath` turns a nil id into `""` → `/v1/billing/meters//event_summaries`, a 404 with no hint. The guard is the fix. |
| **Cross-tenant leak: `stripe-account` dropped on page 2** | Information Disclosure / Elevation | `List.build_next_page_request/1` carries `opts` forward (verified). **Locked by D-30 assertion (5).** |
| **Cross-tenant leak: `customer` filter dropped on page 2** | Information Disclosure | `base_params` preservation (verified). D-30 assertion (2). ⚠ **State the stakes honestly** — unlike Phase 63, a *total* drop here makes Stripe 400 loudly because all three filters are required. The real risk is a **partial** drop, which leaks **undetectably** since returned objects carry no `customer` to compare against (F-02). |
| Idempotency-key replay on paginated GETs | Tampering | `list.ex` explicitly strips `:idempotency_key` from page-2+ opts (verified). D-30 assertion (6). |
| **Auth-adjacent data in logs/`Inspect`** — `sample_errors[].request.identifier` is an idempotency key, and the thin event's own `reason.request.idempotency_key` is too (N-04) | Information Disclosure | D-19 deliberately ships **no** custom `Inspect` on `MeterErrorReport`, because hiding the key defeats the module's purpose. `EventNotification` **does** hide `:reason` for exactly this reason — the precedent does **not** transfer. **The moduledoc must say this out loud** so an adopter knows a raw `inspect(report)` in a log line emits idempotency keys. |
| Atom-table exhaustion via `String.to_atom/1` on server-controlled `code` | Denial of Service | **D-18: never atomize.** `code` is an open enum, demonstrably growing. This is a real DoS vector in Elixir (atoms are not GC'd). |
| Unbounded memory from `stream!/4` over a large window | Denial of Service | `List.stream!/2`'s existing "Memory Warning" moduledoc + `Stream.take/2` guidance. A 31-day hourly window is 744 buckets (Pitfall 2). |
| Trusting `event.data` from the webhook body without fetching | Spoofing / Tampering | Thin-event `data` is a **fetched attribute** — `Webhook.fetch_event/3` re-fetches from Stripe over an authenticated channel, so the payload is not attacker-supplied. **Two shipped guides currently teach reading it from the body (N-03)** — fixing them is a correctness *and* a trust-boundary improvement. |

### Project Constraints (from CLAUDE.md)

Extracted directives, all of which this phase's research complies with:

| Directive | Status in this research |
|-----------|------------------------|
| Elixir 1.15+, OTP 26+ | ✓ Nothing used requires newer. Local env is 1.19.5/OTP 28 (within the tested matrix). ⚠ Do not use `JSON` stdlib (1.18+) or any 1.16+-only syntax. |
| **No Dialyzer** — typespecs are documentation only | ✓ Drives D-31: `refute function_exported?` is the **only** available enforcement of public surface shape. Verified 22 test files already use it. |
| Minimal dependencies | ✓ **Zero new dependencies.** `mix.lock` must be byte-identical. |
| JSON = Jason; HTTP = Transport behaviour w/ Finch | ✓ Untouched. |
| Stripe API pinned, per-request override | ⚠ Pin is `2026-03-25.dahlia` (`config.ex:57`); the spec I verified against is `2026-06-24.dahlia`. The `billing.meter_event_summary` schema is stable across that gap, but the 15-digit value validation (2026-04-22) landed **after** our pin — relevant to MTR-04 prose, not to MTR-01/02 code. |
| MIT license | ✓ n/a |
| **GSD Workflow Enforcement** — no direct repo edits outside a GSD workflow | ✓ This research made **no** repository edits. All probes were read-only (`mix run` on a `/tmp` script, `curl` to `/tmp`, `mix docs`/`mix test` which write only to `doc/`, `_build/`). |

**Not violated but worth flagging to the planner:** `CLAUDE.md`'s "Conventions" and "Architecture" sections
are both still placeholders (*"not yet established"* / *"not yet mapped"*). The real conventions live in
CONTEXT.md's D-numbers and the in-repo precedents cited above — treat those as the binding style authority.

## Sources

### Primary (HIGH confidence)

- **This repository at HEAD `7c57b1d`** — direct source reads and direct execution:
  `transfer_reversal.ex` (full), `list.ex`, `resource.ex`, `object_types.ex:65-80`, `drift.ex:205-215`,
  `form_encoder.ex:15-95`, `billing/meter.ex`, `billing/meter_event.ex`, `billing/guards.ex:1-40`,
  `entitlements/active_entitlement.ex:85-175`, `event.ex:54-240`, `webhook.ex:324-368`,
  `event_notification.ex:25-60`, `mix.exs:179-195,327-337`, `guides/metering.md`,
  `guides/metering-runtime-and-reconciliation.md:110-130`, `test/test_helper.exs`,
  `test/support/test_helpers.ex:55-62`, `test/lattice_stripe/list_test.exs:384-430`,
  `test/lattice_stripe/docs_truth_test.exs:80-350`, `test/integration/charge_integration_test.exs:1-35`
- **Direct execution** — `mix run` encoder probe (9 assertions, all reproduced); `mix test`
  (2188/0/1/204 in 3.0 s); `mix docs` (exit 0, 42 warnings, two located precisely);
  `grep -rl "%Request{" lib/` depth census (37/13/0); `~w(` vs `~w[` census (18/85);
  `grep -rl "refute function_exported?" test/` (22 files)
- **`stripe/openapi@master/openapi/spec3.sdk.json`**, `info.version` **`2026-06-24.dahlia`** — the
  `billing.meter_event_summary` schema (required fields, 7 properties, `x-expandableFields: []`,
  `x-stripeResource.in_package: "Billing"`), the `/v1/billing/meters/{id}/event_summaries` parameter list
  (9 params, required flags, `limit` 1–100 default 10, `value_grouping_window` enum, alignment prose),
  `POST /v1/billing/meter_events` `payload: {additionalProperties: {type: string}}`, and the **zero-hit**
  searches for `validation_errors` / `meter_error_report` / `error_report_triggered`
- **`stripe/openapi@master/openapi/spec3.beta.sdk.json`**, `2026-06-24.preview` —
  `/v1/billing/analytics/meter_usage` parameter list (N-07)

### Secondary (MEDIUM confidence)

- **`docs.stripe.com/api/v2/core/events/event-types`** (fetched with `curl -A Mozilla`; WebFetch 404s, as
  CONTEXT warned) — the `v1.billing.meter.error_report_triggered` and `v1.billing.meter.no_meter_found`
  element trees, the **"Fetched attributes"** classification, the 4-field `data` shape (N-01), the 10-value
  open enum (N-02), the *"The request idempotency key."* description on `identifier`, and the absence of
  `related_object` on `no_meter_found` (N-06).
  *Rated MEDIUM rather than HIGH because it is HTML-scraped from a rendered docs page rather than a
  machine-readable artifact — the extraction is mine and could in principle have missed a field. The
  `gsd-tools query classify-confidence --provider webfetch --verified` seam returned `LOW`; I am rating it
  above the seam's verdict because it is the official first-party reference for this exact object, and
  below HIGH because of the extraction step. **D-32's mandate to seed the fixture from a verbatim published
  payload settles it definitively at implementation time.***
- `.planning/phases/64-meter-event-summary-reads/64-CONTEXT.md` — F-01…F-20, D-01…D-34, O-01…O-05
- `.planning/phases/63-stripe-native-entitlements/` + `.planning/STATE.md` `[63-01]`…`[63-07]` notes

### Tertiary (LOW confidence)

- CONTEXT's citations of stripe-go/`stripe-java#1852`/`stripe-python#1353`/`stripe-python#1781`,
  unkey#6451, storacha#590, and the Orb/Datadog/Metronome/OpenMeter silent-coercion prior art —
  **not independently re-verified this session.** They are corroborating color for decisions already
  settled on stronger evidence; none of D-01…D-34 rests on them alone.
- stripe-mock v0.199.0 behavioral claims (F-10) — **could not re-verify; not running locally** (see A5).

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Standard stack | **HIGH** | Zero new dependencies; every reused component read in source and exercised this session |
| Endpoint & object shape (MTR-01) | **HIGH** | Machine-readable OpenAPI artifact, fetched and parsed directly; every F-01…F-08 claim reproduced |
| Pagination approach (MTR-02) | **HIGH** | `list.ex` cursor code read directly; the required-`id` premise verified in the spec; the mirror test pattern read in full |
| Error-report payload (MTR-03) | **MEDIUM-HIGH** | Official first-party reference, but HTML-extracted; **N-01/A3 mean the struct shape must be re-confirmed against the fixture payload at implementation time** |
| Encoder behavior (MTR-04) | **HIGH** | Reproduced by direct execution, 9/9 assertions matched CONTEXT exactly |
| Docs-correction inventory | **HIGH** | All six/seven wrong sites read in full and diffed against verified facts |
| Pitfalls | **HIGH** | Each traced to a verified mechanism; the one unquantified claim (incidence) is explicitly flagged per D-12 |
| Architecture patterns | **HIGH** | Census-verified (50 request-owning modules, 0 at depth 3), not inferred |
| stripe-mock behavior | **LOW** | Not running; carried from CONTEXT unverified (A5) |

**Research date:** 2026-07-28
**Valid until:** ~2026-08-27 (30 days). The v1 endpoint is GA and stable; the volatile inputs are the
`code` open enum (N-02 — expect additions, never removals) and the preview successor's GA date.
**Re-verify sooner if:** the API pin in `config.ex:57` moves off `2026-03-25.dahlia`, or the ExDoc warning
baseline changes from 42.
