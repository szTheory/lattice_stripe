# Phase 20: Billing Metering - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Milestone:** v1.1 (Accrue unblockers — first phase)
**Commit anchor:** e7e883f

<domain>
## Phase Boundary

Ship `LatticeStripe.Billing.Meter` (CRUDL + `deactivate`/`reactivate` lifecycle verbs), `LatticeStripe.Billing.MeterEvent` (create-only hot-path usage reporting), and `LatticeStripe.Billing.MeterEventAdjustment` (create-only dunning correction) — unblocking Accrue BILL-11. Includes four nested `Meter.*` typed structs, a pre-flight `value_settings` trap guard, integration tests, and the new `guides/metering.md` + ExDoc "Billing Metering" group.

**Requirements:** METER-01..METER-09, EVENT-01..EVENT-05, GUARD-01, GUARD-02, GUARD-03, TEST-01, TEST-03, TEST-05 (metering portion), DOCS-01, DOCS-03 (Billing Metering group), DOCS-04.

**In scope:**
- `LatticeStripe.Billing.Meter` resource — `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`, `deactivate/3`, `reactivate/3` + all bang variants
- 4 nested typed structs under `LatticeStripe.Billing.Meter.*`: `DefaultAggregation`, `CustomerMapping`, `ValueSettings`, `StatusTransitions` (see D-03)
- `%Meter{}.status` atom decoding via `status_atom/1` helper mirroring `Account.Capability` (METER-09)
- `LatticeStripe.Billing.MeterEvent` resource — `create/3` + `create!/3` only; minimal struct; allowlist `Inspect` masking `:payload` (D-02)
- `LatticeStripe.Billing.MeterEventAdjustment` resource — `create/3` + `create!/3` only; full typed struct (not raw map) for symmetry (D-04)
- `LatticeStripe.Billing.Guards.check_meter_value_settings!/1` pre-flight guard (D-01)
- `test/support/fixtures/metering.ex` — `Meter`, `MeterEvent`, `MeterEventAdjustment` fixtures
- stripe-mock integration tests covering full lifecycle: create → retrieve → update → list → deactivate → reactivate + event report + adjustment
- `guides/metering.md` — 580 lines ± 40, 12 H2 sections, full `UsageReporter` hot-path example, 2-layer idempotency explainer, dunning-correction worked example, 7-row error code table, GUARD-01 escape hatch (D-05)
- `mix.exs`: new `"Billing Metering"` group in `groups_for_modules` (7 modules), `guides/metering.md` added to `extras`
- Cross-links from `subscriptions.md`, `webhooks.md`, `telemetry.md`, `error-handling.md`, `testing.md` (reciprocal)

**Out of scope (locked deferrals):**
- `/v2/billing/meter_event_stream` high-throughput variant (v1.1 D3)
- `BillingPortal.Configuration` CRUDL (v1.1 D4 — belongs to Phase 21)
- `Meter` delete / search (Stripe API does not expose)
- `MeterEvent` retrieve / list (Stripe API does not expose — events are write-only)
- `Billing.Meter.EventSummary` aggregate queries (separate API family — v1.2+)
- Release-cut phase analogous to Phase 19 (release-please zero-touch per v1.1-accrue-context.md)
- `customer_mapping` presence guard (see D-07 — flagged for future consideration, not implemented in Phase 20)
- Formula input normalization (atom → string) — D-06 rejects; strings only on the wire

</domain>

<decisions>
## Implementation Decisions (Locked — D-01..D-07)

### D-01 — GUARD-01 scope, severity, and location

**Helper:** `LatticeStripe.Billing.Guards.check_meter_value_settings!/1` (new), called from `Meter.create/3` after the `Resource.require_param!/3` checks.

**Behavior:**
1. **Hard `ArgumentError`** when `default_aggregation.formula` is `"sum"` or `"last"` AND `value_settings` is passed as a map whose `event_payload_key` is missing, nil, or empty-string. This is the genuinely broken shape — Stripe returns HTTP 200 and silently drops every event's value contribution.
2. **Silent pass** when `value_settings` is omitted entirely. Stripe defaults `event_payload_key` to `"value"` — this is a legal and common shape per [Stripe API docs](https://docs.stripe.com/api/billing/meter/create). The REQUIREMENT text's literal reading ("raise when value_settings absent") is over-strict relative to Stripe's documented default; this decision **amends ROADMAP success criterion 2** to raise on present-but-malformed rather than on absence.
3. **`Logger.warning/1`** (not `IO.warn/2`) when `default_aggregation.formula` is `"count"` AND `value_settings` is passed — Stripe silently ignores value_settings for count meters; a soft warning nudges devs without rejecting legal calls.
4. **String keys only.** Atom-keyed params (`%{default_aggregation: %{formula: :sum}}`) bypass the guard because the guard reads string keys (matching Stripe's wire format). This is correct — if a dev passes atoms, the HTTP layer will miss the known fields and Stripe's 400 will surface the real problem. No dual-representation footgun. (Also see D-06.)

**Elixir implementation sketch** (drop into `lib/lattice_stripe/billing/guards.ex`):

```elixir
require Logger

@doc """
Pre-flight guard for `LatticeStripe.Billing.Meter.create/3`. Raises when
`value_settings` is present-but-malformed for sum/last formulas; warns on
count + value_settings (ignored field). Accepts omitted value_settings
silently — Stripe defaults `event_payload_key` to `"value"`.
"""
@spec check_meter_value_settings!(map()) :: :ok
def check_meter_value_settings!(params) when is_map(params) do
  formula = get_in(params, ["default_aggregation", "formula"])
  value_settings = Map.get(params, "value_settings")

  cond do
    formula in ["sum", "last"] and is_map(value_settings) and
        not valid_event_payload_key?(value_settings) ->
      raise ArgumentError,
            "LatticeStripe.Billing.Meter.create/3: default_aggregation.formula " <>
              "is #{inspect(formula)} but value_settings.event_payload_key is " <>
              "missing or empty. Stripe would accept this and silently drop " <>
              "every MeterEvent's value. Either omit value_settings entirely " <>
              "(defaults to \"value\") or pass " <>
              "%{\"event_payload_key\" => \"<your_key>\"}."

    formula == "count" and not is_nil(value_settings) ->
      Logger.warning(
        "LatticeStripe.Billing.Meter.create/3: value_settings is ignored " <>
          "when default_aggregation.formula is \"count\". Stripe will drop " <>
          "this field silently."
      )
      :ok

    true ->
      :ok
  end
end

def check_meter_value_settings!(_non_map), do: :ok

defp valid_event_payload_key?(%{"event_payload_key" => key})
     when is_binary(key) and byte_size(key) > 0,
     do: true

defp valid_event_payload_key?(_), do: false
```

**`Meter.create/3` call site:**

```elixir
def create(%Client{} = client, params, opts \\ []) when is_map(params) do
  Resource.require_param!(params, "display_name",
    "LatticeStripe.Billing.Meter.create/3 requires a display_name param")
  Resource.require_param!(params, "event_name",
    "LatticeStripe.Billing.Meter.create/3 requires an event_name param")
  Resource.require_param!(params, "default_aggregation",
    "LatticeStripe.Billing.Meter.create/3 requires a default_aggregation param")

  :ok = Billing.Guards.check_meter_value_settings!(params)

  Resource.request(client, :post, "/v1/billing/meters", params, opts, __MODULE__)
end
```

**Test matrix (8 cases, Plan 20-03):**
1. `formula: "sum"`, no `value_settings` → `:ok`
2. `formula: "sum"`, `value_settings: %{"event_payload_key" => "tokens"}` → `:ok`
3. `formula: "sum"`, `value_settings: %{}` → raises `ArgumentError`
4. `formula: "sum"`, `value_settings: %{"event_payload_key" => ""}` → raises `ArgumentError`
5. `formula: "last"`, `value_settings: %{"event_payload_key" => nil}` → raises `ArgumentError`
6. `formula: "count"`, `value_settings: %{"event_payload_key" => "x"}` → logs warning, `:ok` (use `ExUnit.CaptureLog`)
7. `formula: "count"`, no `value_settings` → `:ok` silent
8. Atom-keyed `%{default_aggregation: %{formula: :sum}}` → `:ok` silent (guard no-ops; HTTP layer handles)

**Rationale:** Option C (hybrid hard-raise on broken shape + soft warn on ignored field + accept legal omission) is the only choice that honors three non-negotiable constraints simultaneously: (a) Stripe's documented wire semantics (omitted `value_settings` defaults to `"value"` and is legal), (b) "no fake ergonomics" (Phase 15 D5 — don't reject what Stripe accepts), (c) the REQUIREMENT's actual intent (prevent silent-zero, which only fires when value_settings is present-but-broken). stripe-node/ruby/python, stripity_stripe, and the Ecto/Plug/Finch idiom all agree: raise on programmer errors, pass through legal-but-suspicious calls, don't client-side-validate what Stripe would cleanly reject. The `Billing.Guards` namespace matches the Phase 14 `check_proration_required/2` precedent.

**Rejected:**
- **Strict ArgumentError on absence** (literal ROADMAP reading) — rejects valid Stripe input, breaks parity with every other Stripe SDK, forces escape-hatch docs.
- **`IO.warn/2`** — stacktrace noise in test output, not overridable, wrong idiom for runtime configuration hints.
- **NimbleOptions schema for entire create params** — validates keyword lists well, nested string-keyed maps poorly; contradicts "minimal deps"; already rejected in Phase 19 D-16.
- **Function-head atom guard on `:sum|:count|:last`** — Phase 17 D-04c already ruled this pattern fits positional closed enums only, not nested map params.

---

### D-02 — MeterEvent Inspect masking: allowlist pattern, hide `:payload`

**Extend the existing LatticeStripe allowlist Inspect pattern** to `%LatticeStripe.Billing.MeterEvent{}`. Canonical references: `lib/lattice_stripe/customer.ex:467+` and `lib/lattice_stripe/checkout/session.ex`.

**Render shape:**
```
#LatticeStripe.Billing.MeterEvent<event_name: "api_calls", identifier: "req_abc", timestamp: 1712345678, created: 1712345679, livemode: false>
```

`:payload` is hidden. Any field outside the allowlist is hidden (including `:extra` if present). This matches Customer (id/object/livemode/deleted) and Checkout.Session precedent exactly.

**Why mask `:payload`:**
- Contains the customer-mapping key value (e.g. `stripe_customer_id: "cus_..."`) — commercially sensitive on the usage-reporting hot path
- Appears in Logger error output, crash dumps, telemetry handler inspections
- Consistency with the LatticeStripe commitment: "decoded Stripe resources hide their sensitive surface by default"
- Phase 21 will apply the same pattern to `BillingPortal.Session.url`, completing the pattern across v1.1

**Implementation sketch** (drop into `lib/lattice_stripe/billing/meter_event.ex`, Plan 20-04):

```elixir
defimpl Inspect, for: LatticeStripe.Billing.MeterEvent do
  import Inspect.Algebra

  def inspect(event, opts) do
    # Allowlist structural fields only. `:payload` is hidden because it
    # carries the customer-mapping key and metered value, both commercially
    # sensitive when surfaced in Logger output, crash dumps, or telemetry.
    # Consistent with LatticeStripe.Customer and Checkout.Session.
    #
    # To see the payload during debugging:
    #     IO.inspect(event, structs: false)
    #     # or
    #     event.payload
    fields = [
      event_name: event.event_name,
      identifier: event.identifier,
      timestamp: event.timestamp,
      created: event.created,
      livemode: event.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Billing.MeterEvent<" | pairs] ++ [">"])
  end
end
```

**Test coverage:** 2 tests in `test/lattice_stripe/billing/meter_event_test.exs` — one asserting `inspect(ev) =~ "#LatticeStripe.Billing.MeterEvent<"`; one asserting `refute inspect(ev) =~ "stripe_customer_id"`.

**Rationale:** Option A (allowlist, hide entire payload) wins decisively. The existing LatticeStripe pattern is allowlist-based, not field-level substitution, so per-key masking (Option B) would be a net-new pattern with ongoing drift risk as Stripe adds customer-mapping keys. Option C (don't mask, rely on Plug/Ecto-style) loses to internal consistency: LatticeStripe has publicly committed to masking decoded-struct sensitive surfaces (Phase 17 D-01), and downstream Accrue authors will expect `MeterEvent` to behave like `Customer`. Option D (compile-env switch) is a library-hygiene violation — Inspect impls should not branch on host Mix.env. Guardian/Phoenix.Token (masked by default) is the closer spectrum end than Plug.Conn.body_params (unmasked); LatticeStripe sits on the Guardian side.

**Coherence:** D-01 ensures any `%MeterEvent{}` reaching `Inspect` has a populated payload (the value_settings guard ensures meters are well-formed before events flow), so masking is never vacuous. The debugging escape hatch is documented in `guides/metering.md` (D-05) under "Observability → Debugging with Inspect."

**Rejected:**
- **Per-key masking of customer-mapping value** — drift risk; inconsistent with allowlist pattern elsewhere; `%Customer{}.id` is already visible unmasked, so inconsistent threat model.
- **Don't mask (Plug/Ecto style)** — breaks the internal "every decoded struct hides its sensitive surface" story.
- **Compile-time env switch** — library hygiene violation.

---

### D-03 — Nested typed struct budget for `%Meter{}` (4 modules)

**4 distinct nested struct modules**, well under Phase 17's amended "5 distinct modules" budget:

| # | Field on `%Meter{}` | Module | Notes |
|---|---|---|---|
| 1 | `default_aggregation` | `LatticeStripe.Billing.Meter.DefaultAggregation` | Single field: `formula` (string). Simple value struct — no `:extra`. |
| 2 | `customer_mapping` | `LatticeStripe.Billing.Meter.CustomerMapping` | Fields: `event_payload_key`, `type`. Follows `@known_fields + :extra` (Stripe may add mapping types). |
| 3 | `value_settings` | `LatticeStripe.Billing.Meter.ValueSettings` | Single field: `event_payload_key`. Simple value struct — no `:extra`. |
| 4 | `status_transitions` | `LatticeStripe.Billing.Meter.StatusTransitions` | Field: `deactivated_at` (timestamp). Follows `@known_fields + :extra` (Stripe may add future transitions). |

**On `%Meter{}` itself:**
- `status` is a top-level field on the parent struct (NOT a nested struct). Decoded to atom via `status_atom/1` helper mirroring `Account.Capability.status_atom/1` (Phase 17 D-02).
- `@known_statuses` = `["active", "inactive"]`. Unknown values fall through to `:unknown`.
- Parent struct uses `@known_fields + :extra` (F-001).

**No `Jason.Encoder` on any struct** (established v1.0 convention).
**No PII `Inspect` masking on nested structs** (Meter configuration is non-sensitive — the hot-path masking in D-02 covers only `MeterEvent.payload`).

**Rationale:** Research confirmed these are the only 4 nested objects in the Stripe Meter response. No reuse opportunity (unlike Phase 16 `Subscription.Schedule.Phase` or Phase 17 `Account.Requirements`). DefaultAggregation and ValueSettings are 1-field value structs that could be collapsed to plain maps, but giving them typed structs provides `@typedoc` anchor points for formula semantics (which the guide references heavily per D-05) and matches the broader "nested promoted fields get typed structs" pattern.

---

### D-04 — `MeterEventAdjustment` gets a full typed struct (not raw map)

**`%LatticeStripe.Billing.MeterEventAdjustment{}` is a full resource struct** with `from_map/1`, `@known_fields`, `:extra`, and a return type of `{:ok, %MeterEventAdjustment{}} | {:error, %Error{}}` — mirroring `MeterEvent` and every other create-only resource in the SDK.

**Fields (per [Stripe docs](https://docs.stripe.com/api/billing/meter-event-adjustment/object)):** `id`, `object`, `event_name`, `status`, `cancel`, `livemode` plus `extra` for forward compat. `cancel` is decoded as a minimal nested typed struct `LatticeStripe.Billing.MeterEventAdjustment.Cancel` (single field: `identifier`) so `from_map/1` round-trip tests can assert the exact `cancel.identifier` shape (ROADMAP success criterion 4).

**Unit test (Plan 20-04):** A `from_map/1` round-trip must assert that the `cancel: %{"identifier" => "req_abc"}` shape decodes to `%Cancel{identifier: "req_abc"}` — not `identifier: "req_abc"` at the top level, not `id: "req_abc"`. This prevents the EVENT-04 / Pitfall-4 regression (developers writing `%{"identifier" => ...}` at the top level and getting a Stripe 400).

**Rationale:** Returning `{:ok, map()}` for exactly one endpoint while every other LatticeStripe create returns `{:ok, struct}` is an inconsistency tax higher than the ~40 LOC cost of the struct. Guide code examples (D-05's dunning correction worked example) will pattern-match `%MeterEventAdjustment{}` cleanly. Symmetry with MeterEvent is free insurance.

---

### D-05 — `guides/metering.md` depth and structure

**Target: 580 lines ± 40.** Anchored to `guides/invoices.md` (556 lines) and slightly exceeds `subscriptions.md` (407) because metering has more async failure modes than any other v1.0/v1.1 resource.

**Section outline (12 H2 sections):**

1. **Intro** (2 paragraphs) — what metering is, what this guide covers
2. **Mental model** — Meter = schema / MeterEvent = fire-and-forget fact / Subscription with metered price = billing glue. ASCII diagram. Crosslink OUT to `subscriptions.md` for metered prices.
3. **Defining a meter** (H3s: Aggregation formulas, customer_mapping, value_settings, Lifecycle verbs)
   - Formula section: 1 paragraph per formula (`sum`, `count`, `last`) with when-to-use and one concrete example each. Explicit callout that `:sum`/`:last` REQUIRE a well-formed `value_settings.event_payload_key`.
4. **Reporting usage (the hot path)** — ⬅ anchor of the guide
   - H3: "The fire-and-forget idiom" — full `AccrueLike.UsageReporter` module (~40 lines) using `Task.Supervisor.start_child`, telemetry spans, error-type classification (retry transient / drop permanent)
   - H3: "Two-layer idempotency" — `identifier` (body, business-level) vs `idempotency_key:` (transport, HTTP). Side-by-side code block + explanatory table + the "set both" rule with its rationale
   - H3: "Timestamp semantics" — 35-day past / 5-min future window, clock skew
   - H3: "What NOT to do: nightly batch flush" — explicit wrong-way code block in a `> **Warning:**` box, then the right way immediately below (see Snippet C in DISCUSSION-LOG.md)
5. **Corrections and adjustments** (H3s: MeterEventAdjustment.create/3, Dunning-style over-report flow)
   - Dunning example: ~45 lines end-to-end — detect over-report via metadata lookup → call `MeterEventAdjustment.create/3` with exact `cancel.identifier` shape → log telemetry
6. **Reconciliation via webhooks** (H3s: The error-report webhook, Error codes you must handle, Remediation patterns)
   - 7-row error code table (see Snippet D in DISCUSSION-LOG.md):

     | `error_code` | When | Silent drop? | Remediation |
     |---|---|---|---|
     | `meter_event_customer_not_found` | customer deleted | YES (async) | Sweep job |
     | `meter_event_no_customer_defined` | payload missing mapping key | YES (async) | Fix reporter |
     | `meter_event_invalid_value` | value not numeric | YES (async) | Fix reporter |
     | `meter_event_value_not_found` | sum/last but no value | YES (async) | Fix payload (likely GUARD-01 bypass) |
     | `archived_meter` | meter deactivated | NO (sync 400) | Alert — data PERMANENTLY LOST |
     | `timestamp_too_far_in_past` | >35 days | NO (sync 400) | Drop batch flush |
     | `timestamp_in_future` | >5 min future | NO (sync 400) | Fix clock skew |

7. **Observability** (H3s: Telemetry for the hot path, Debugging with Inspect)
   - Debugging section documents the D-02 masking and shows `IO.inspect(event, structs: false)` + `event.payload` escape hatches. Explicit guidance: NEVER log raw `MeterEvent.payload` because it contains `stripe_customer_id`.
8. **Guards and escape hatches** — D-01 framing: why `check_meter_value_settings!/1` hard-raises + the `LatticeStripe.Client.request/4` one-line bypass. Framed as "only for porting from another SDK — production code should fix the meter, not the call."
9. **Common pitfalls** — 7 bullets mirroring research `PITFALLS.md`, each 2-3 lines with crosslink
10. **See also** — `subscriptions.md`, `webhooks.md`, `telemetry.md`, `error-handling.md`, `testing.md`

**Style conventions (carry from v1.0 guides):**
- `> **Warning:**` blockquote for destructive/irreversible/silent-data-loss content
- `> **Note:**` blockquote for easy-to-miss facts
- Code blocks always specify `elixir` fencing
- H2 `## See also` section at bottom
- Inline `` `code` `` for function names and atoms
- Cross-references by path: `[subscriptions.md](subscriptions.md#metered-prices)`

**Reciprocal crosslinks (DOCS-04, executed in Plan 20-06):**
- `subscriptions.md` — inline link in metered-price section pointing to metering.md
- `webhooks.md` — in event handler section, link to "Reconciliation via webhooks"
- `telemetry.md` — in custom handlers section, link to "Observability"
- `getting-started.md` — add `metering.md` to the guide index list
- `cheatsheet.cheatmd` — add a metering cheat row if existing table structure allows

**Hard stops:** if draft exceeds 700 lines, cut the dunning example to reference-only. If draft is under 450 lines, the error-code table or formula section is too shallow.

**Rationale:** The metering guide is the single differentiator over stripity_stripe (which has no metering coverage at all) and the primary touchpoint for Accrue authors learning the two-layer idempotency contract. Undersizing it means every downstream consumer reinvents the retry classifier and rediscovers `cancel.identifier` the hard way. 580 lines matches the `invoices.md` anchor and sits at the top of the existing guide distribution — defensible given metering has uniquely more async footguns than any other resource.

---

### D-06 — Formula input surface: strings only (no atom normalization on write)

`Meter.create/3` accepts **strings only** on the wire: `%{"default_aggregation" => %{"formula" => "sum"}}`. Atom-keyed params and atom values are not normalized. Read-side decoding to atoms (METER-09, `status_atom/1` helper on parent `%Meter{}`) is unaffected.

**Rationale:**
- Phase 17 D-04c already ruled that positional atom-guard patterns (Phase 15 `pause_collection`, Phase 17 `Account.reject`) don't fit multi-field creates with nested params
- Stripe's wire format is strings; single-representation discipline avoids the "which form does the guard read?" footgun
- Matches every other `create/3` in LatticeStripe
- If a dev passes `%{default_aggregation: %{formula: :sum}}` (atom keys), the guard silently no-ops (reads string keys), and Stripe's HTTP layer returns a clear 400 on the malformed request — which is the correct surfacing path

---

### D-07 — `customer_mapping` presence guard: deferred

**Not implemented in Phase 20.** The REQUIREMENT scopes GUARD-01 tightly to `value_settings`; expanding to also guard `customer_mapping` presence would conflate two failure modes in one decision. `customer_mapping` has no documented Stripe default (unlike `value_settings` which defaults to `"value"`), so a future guard would plausibly be stricter (hard raise on absence for any formula).

**Action:** Track as a candidate follow-up. If user demand or downstream Accrue feedback surfaces the silent-drop trap in practice, add `Billing.Guards.check_meter_customer_mapping!/1` as a post-ship patch. Guide-level warning in D-05's "Defining a meter → customer_mapping" section documents the trap in the meantime.

---

### Claude's Discretion

The following fall under planner/executor judgment:

- Exact field order in each nested struct (follow Stripe API doc order)
- Exact `@moduledoc` wording and examples (follow Phase 14/15/16/17 conventions)
- Exact message wording in `ArgumentError` / `Logger.warning` (as drafted above is a baseline)
- Test fixture shapes (follow `test/support/fixtures/` conventions)
- stripe-mock integration test coverage depth (mirror Phase 17/18 pattern)
- Whether `Meter.update/4` pre-validates `status` mutation attempts (recommend NO per "no fake ergonomics" — `deactivate`/`reactivate` are the authorized path)
- ExDoc group ordering in `mix.exs` (place "Billing Metering" after "Billing", before "Connect")
- Whether `MeterEventAdjustment.Cancel` nested struct deserves its own test module or shares `meter_event_adjustment_test.exs`
- `@typedoc` depth on `DefaultAggregation` formula enum (recommend: enumerate the 3 values with one-paragraph semantics each — the guide D-05 heavily references this)
- Whether integration tests split into 1 file or 3 files (recommend 3 files per research: `meter_integration_test.exs`, `meter_event_integration_test.exs`, `meter_event_adjustment_integration_test.exs`)
- Whether the hot-path `UsageReporter` example module appears as a `moduledoc` `iex>` block or only in `guides/metering.md` (recommend: guide only; moduledoc points to guide)

</decisions>

<plan_structure>
## Phase 20 Plan Wave Structure (6 plans, 5 waves, sequential)

```
Wave 0 (bootstrap):      20-01
                           │
Wave 1 (nested structs): 20-02
                           │
Wave 2 (Meter resource): 20-03                     ← holds GUARD-01 (D-01)
                           │  (sequential, NOT parallel)
Wave 3 (events):         20-04                     ← holds Inspect masking (D-02) + Adjustment struct (D-04)
                           │
Wave 4 (integration):    20-05
                           │
Wave 5 (docs):           20-06                     ← holds guide depth (D-05)
```

**Sequential, not parallel.** 20-03 and 20-04 both depend only on 20-02, but executing sequentially avoids fixture-file collisions on `test/support/fixtures/metering.ex` and keeps commit logs clean. Parallelism savings (~20 min) are not worth the coordination cost.

| Plan | Title | Deliverables | LOC src | LOC test | LOC doc |
|---|---|---|---|---|---|
| **20-01** | Wave 0 bootstrap | `test/support/fixtures/metering.ex` (Meter.basic/1, Meter.list_response/1, Meter.deactivated/1, MeterEvent.basic/1, MeterEventAdjustment.basic/1); stripe-mock probe script covering 3 endpoint families + deactivate/reactivate verbs; record gaps in `20-VALIDATION.md` | 0 | ~180 | ~30 |
| **20-02** | Nested structs (`Meter.*`) | 4 sub-modules (DefaultAggregation, CustomerMapping, ValueSettings, StatusTransitions) per D-03; F-001 `@known_fields + :extra` on CustomerMapping and StatusTransitions only; unit tests for round-trip + extra capture | ~160 | ~180 | 0 |
| **20-03** | `Billing.Meter` resource | CRUDL + `deactivate/3` + `reactivate/3` + bang variants + `from_map/1` + `stream!/3`; `status_atom/1` helper; **GUARD-01 (D-01)**; ~40 Mox unit tests including the 8-case guard matrix | ~280 | ~380 | 0 |
| **20-04** | `MeterEvent` + `MeterEventAdjustment` | Two resource modules (create-only each); two minimal structs with `from_map/1`; `MeterEventAdjustment.Cancel` nested struct (D-04); **Inspect masking on MeterEvent (D-02)**; `idempotency_key:` + `stripe_account:` opts; two-layer idempotency moduledoc | ~220 | ~240 | 0 |
| **20-05** | Integration tests | 3 files: `meter_integration_test.exs` (create → retrieve → update → list → deactivate → reactivate), `meter_event_integration_test.exs` (create + idempotency replay note), `meter_event_adjustment_integration_test.exs` (create with exact `cancel.identifier` shape); ~15 tests; stripe-mock limitation comments for dedup windows | 0 | ~300 | 0 |
| **20-06** | Guide + ExDoc | `guides/metering.md` per D-05 (580 ± 40 lines, 12 H2 sections); `mix.exs`: "Billing Metering" group in `groups_for_modules`, `guides/metering.md` in `extras`; reciprocal crosslinks in 5 sibling guides | 0 | 0 | ~330 |

**Totals:** 6 plans, ~660 LOC src, ~1280 LOC test, ~360 LOC doc — ~60% of Phase 17's size, consistent with reduced nested-struct surface (4 vs 7) and no PII redaction work.

**Sanity check:** No plan is below ~200 LOC (avoiding trivial-plan anti-pattern) and no plan exceeds ~700 LOC (avoiding bloated-plan anti-pattern). 20-03 is the largest, as in Phase 17; stays well under the 17-03 ceiling.

</plan_structure>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Project-level decisions and state
- `.planning/v1.1-accrue-context.md` — authoritative v1.1 brief; locked decisions D1-D5; Accrue minimum API surfaces for Meter/MeterEvent/MeterEventAdjustment/BillingPortal.Session
- `.planning/PROJECT.md` — vision, principles, non-negotiables
- `.planning/REQUIREMENTS.md` §"Billing Metering" — METER-01..09, EVENT-01..05, GUARD-01..03, TEST-01/03/05, DOCS-01/03/04
- `.planning/STATE.md` — current milestone position; v1.1 D1-D5 in decisions log
- `.planning/ROADMAP.md` Phase 20 entry — goal, depends-on, success criteria (note: this CONTEXT amends success criterion 2 per D-01)

### Research outputs (v1.1 milestone)
- `.planning/research/SUMMARY.md` — 6-plan wave structure, namespacing decisions, zero-new-deps verdict
- `.planning/research/FEATURES.md` — full feature categorization for Meter/MeterEvent/MeterEventAdjustment
- `.planning/research/ARCHITECTURE.md` — namespacing (`Billing.Meter` flat; `MeterEventAdjustment` sibling of `MeterEvent` not nested), nested struct patterns, file manifest
- `.planning/research/PITFALLS.md` — all 7 metering pitfalls with phase assignments and exact error codes
- `.planning/research/STACK.md` — zero-new-deps addendum; `mix.exs` docs-config changes only

### Prior phase contexts that establish patterns Phase 20 must follow
- `.planning/phases/14-invoices-invoice-line-items/14-CONTEXT.md` — `LatticeStripe.Billing.Guards` namespace pattern; nested struct cutoff heuristic
- `.planning/phases/15-subscriptions-subscription-items/15-CONTEXT.md` — D4 flat namespace, D5 `pause_collection` atom-guard precedent, D5 "no fake ergonomics" principle, webhook-handoff callout
- `.planning/phases/15-subscriptions-subscription-items/15-REVIEW-FIX.md` — F-001 `@known_fields + :extra` split pattern
- `.planning/phases/16-subscription-schedules/16-CONTEXT.md` — 5-field nested struct budget (later amended)
- `.planning/phases/17-connect-accounts-links/17-CONTEXT.md` — D-01 budget counts distinct modules (not parent fields), D-02 `Account.Capability.status_atom/1` helper pattern, D-04c positional-atom-guard doesn't fit nested creates
- `.planning/phases/17-connect-accounts-links/17-01-wave0-bootstrap-SUMMARY.md` through `17-06-guide-and-exdoc-SUMMARY.md` — 6-plan wave structure reference

### Codebase files Phase 20 code must be coherent with
- `lib/lattice_stripe/billing/guards.ex` — existing module; `check_proration_required/2` pattern; Phase 20 adds `check_meter_value_settings!/1`
- `lib/lattice_stripe/resource.ex` — `require_param!/3`, `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `request/6` — use these, do not reimplement
- `lib/lattice_stripe/client.ex:52-95,176-196,388-427` — Client struct, per-request `stripe_account:`/`idempotency_key:` opts threading (already wired — zero Client changes)
- `lib/lattice_stripe/customer.ex:36-55,462-467+` — canonical `@known_fields + :extra` + `defimpl Inspect` allowlist pattern
- `lib/lattice_stripe/checkout/session.ex` — second allowlist-Inspect reference (masks `:url`)
- `lib/lattice_stripe/account.ex` + `lib/lattice_stripe/account/capability.ex` — `status_atom/1` helper pattern for D-03
- `lib/lattice_stripe/subscription.ex` + `lib/lattice_stripe/subscription_schedule/` — most recent multi-nested-struct resource precedents
- `test/support/fixtures/` — fixture module conventions (Phase 06); `test/support/fixtures/account.ex` is the closest structural reference
- `test/integration/` — stripe-mock integration test setup; Phase 17/18 tests are closest pattern match

### Stripe API references (web)
- https://docs.stripe.com/api/billing/meter — Meter resource full reference
- https://docs.stripe.com/api/billing/meter/create — create endpoint, `default_aggregation.formula` enum, `value_settings` semantics, `"value"` default
- https://docs.stripe.com/api/billing/meter/object — object fields, `status` values, `status_transitions` shape
- https://docs.stripe.com/api/billing/meter-event — MeterEvent create endpoint, 24-hour `identifier` dedup, 100-char max
- https://docs.stripe.com/api/billing/meter-event-adjustment — MeterEventAdjustment, `cancel.identifier` exact shape
- https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api — timestamp 35-day window, async validation, error codes
- https://docs.stripe.com/billing/subscriptions/usage-based/meters/configure — formula semantics, `value_settings` default
- https://docs.stripe.com/error-codes — exhaustive error code reference for the table in D-05
- https://docs.stripe.com/changelog/basil/2025-03-31/billing-meter-webhooks — `v1.billing.meter.error_report_triggered` webhook

### Cross-SDK comparison references
- https://github.com/beam-community/stripity-stripe — closest Elixir precedent (no metering coverage — Phase 20 ships first)
- https://github.com/stripe/stripe-node — TypeScript reference for Meter typing
- https://github.com/stripe/stripe-python — Python reference for `record_usage`
- https://laravel.com/docs/cashier-stripe/metered-billing — Cashier's `reportUsage()` ergonomic target (Accrue analogue)

</canonical_refs>

<code_context>
## Existing Code Insights (from scout)

### Reusable Assets (use, don't duplicate)
- **`LatticeStripe.Billing.Guards`** (`lib/lattice_stripe/billing/guards.ex`) — existing module with `check_proration_required/2`. Phase 20 ADDS `check_meter_value_settings!/1` to the same module per D-01. Confirmed during scout: billing/ directory contains only `guards.ex` currently — the new Meter/MeterEvent/MeterEventAdjustment files will join it.
- **`LatticeStripe.Resource`** — `require_param!/3`, `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `request/6`. All 7 Meter operations + 2 create-only resources MUST use these helpers.
- **Client `idempotency_key:` and `stripe_account:` opts threading** — per-request opts override already wired end-to-end (`client.ex:176-196,388-427`). **Phase 20 requires zero changes to Client or `build_headers`.** Both `MeterEvent.create/3` and `MeterEventAdjustment.create/3` inherit this plumbing automatically.
- **`@known_fields + :extra` pattern** — canonical in `lib/lattice_stripe/customer.ex:36-55`. Use verbatim for `Meter`, `CustomerMapping`, `StatusTransitions`, `MeterEvent`, `MeterEventAdjustment`.
- **Allowlist `defimpl Inspect` pattern** — canonical in `customer.ex:467+` and `checkout/session.ex`. Use for `MeterEvent` per D-02. No masking needed on `Meter` (config-time, non-sensitive) or `MeterEventAdjustment` (metadata-only).
- **`status_atom/1` helper pattern** — canonical in `lib/lattice_stripe/account/capability.ex`. Copy the exact shape for `Meter.status_atom/1` with `@known_statuses = ["active", "inactive"]`.
- **`LatticeStripe.List` + `stream!/3`** — `list/3` and `stream!/3` pattern from Customer/PaymentIntent. Meter supports both (Stripe has `/v1/billing/meters` list endpoint). Events and Adjustments do NOT.
- **Fixtures** — `test/support/fixtures/` has ~20 modules. Phase 20 adds one: `test/support/fixtures/metering.ex` covering all three resources (Phase 14 precedent for bundled fixture modules).

### Established Patterns
- **Flat namespace for top-level resources**, namespaced sub-modules for nested structs (`LatticeStripe.Billing.Meter.DefaultAggregation` at `lib/lattice_stripe/billing/meter/default_aggregation.ex`) — Phase 14/15/16/17 convention.
- **Bang variants** for every public fallible function — Phase 4 onwards.
- **`Jason.Encoder` NOT derived** on any resource struct — decoded from Stripe, never encoded to Stripe.
- **Pre-network `require_param!`** for endpoint-required params — `Meter.create/3` pre-validates `display_name`, `event_name`, `default_aggregation` before `check_meter_value_settings!/1` runs.
- **Webhook-handoff callout** in every resource guide — `guides/metering.md` restates the "drive application state from webhook events" rule from Phase 15 D5 in the context of `meter.error_report_triggered`.
- **No telemetry added per-resource** — CRUD piggybacks on the general `[:lattice_stripe, :request, *]` events from `Client.request/2` (Phase 08 D-05 `parse_resource_and_operation/2` auto-derives paths).

### Integration Points
- `mix.exs` — ExDoc `groups_for_modules:` add `"Billing Metering"` group containing `LatticeStripe.Billing.Meter`, `MeterEvent`, `MeterEventAdjustment`, and all `Meter.*` + `MeterEventAdjustment.Cancel` nested modules. Place after `"Billing"` and before `"Connect"`.
- `mix.exs` — ExDoc `extras:` add `guides/metering.md` to the extras list in the "Guides" section.
- `test/test_helper.exs` — integration test runner already configured for stripe-mock; no changes.
- `lib/lattice_stripe/telemetry.ex` — no changes; path parsing auto-derives from URL.

### Creative Options Enabled
- Because `Billing.Guards` already exists, D-01's new `check_meter_value_settings!/1` is a single-file addition — no new namespace, no new module ceremony. Path of least resistance.
- The already-wired per-request `idempotency_key:` + `stripe_account:` opts mean `MeterEvent.create/3` is ~20 lines of Elixir (params + Resource.request + from_map + bang variant) — vast majority of Plan 20-04 is moduledoc + guide prose.
- `LatticeStripe.Account.Capability.status_atom/1` is the exact template for `Meter.status_atom/1` — the v1.0 atom-decoding discipline is already in place, Phase 20 inherits it by reference.

</code_context>

<specifics>
## Specific Ideas from Discussion

- **D-01 amends ROADMAP success criterion 2.** The literal text ("raises ArgumentError when value_settings is absent from params") is over-strict relative to Stripe's documented `"value"` default. The guard raises on present-but-malformed `value_settings`, not on omission. This amendment is deliberate and research-grounded; do not re-introduce the strict reading during planning/execution.
- **`Logger.warning/1` not `IO.warn/2`** for the count + value_settings case. `IO.warn` emits a stacktrace and floods test output; `Logger.warning/1` is overridable via Logger config and idiomatic for runtime configuration hints in libraries.
- **String keys only on the wire.** D-06 rejects atom normalization on write. The guard in D-01 reads string keys only; atom-keyed params bypass the guard silently and Stripe's HTTP layer surfaces the real error. This is the correct single-representation discipline (Phase 17 D-04c precedent).
- **`MeterEventAdjustment` gets a full struct** (D-04). Symmetry with `MeterEvent` is free insurance; the ~40 LOC cost is trivial compared to the inconsistency tax of returning `{:ok, map()}` from exactly one endpoint. `MeterEventAdjustment.Cancel` is a minimal nested struct with one field (`identifier`) to anchor round-trip tests for the exact `cancel.identifier` shape (ROADMAP success criterion 4 / Pitfall 4 prevention).
- **Allowlist `Inspect` pattern (D-02)** is extended, not invented. Existing LatticeStripe uses allowlist (Customer, Checkout.Session), not field-level substitution. MeterEvent's `Inspect` mirrors this exactly — no per-key masking logic.
- **`MeterEvent.Inspect` debugging escape hatches** (`IO.inspect(event, structs: false)` and `event.payload`) are documented in `guides/metering.md` under "Observability → Debugging with Inspect" (D-05) — users need a non-paternalistic path to see their own data during debugging.
- **Hot-path recipe is a module, not a snippet** (D-05). The full `AccrueLike.UsageReporter` module (~40 lines, with Task.Supervisor + telemetry + error classification) is copy-paste gold for Accrue and downstream consumers. A 20-line function example would force every consumer to reinvent the retry classifier.
- **Dunning-correction worked example** (~45 lines, not 100) lives in `guides/metering.md` §"Corrections and adjustments". One example, showing the exact `cancel.identifier` nested shape. Not two; not expanded with full webhook reconcile.
- **Batch-flush anti-pattern section** is mandatory in D-05 — it's the single highest-value callout in the guide because PITFALL #6 (35-day window) is the #1 way production consumers lose data silently.
- **No release phase.** Post-1.0 `release-please-config.json` (`bump-minor-pre-major: false`, no `release-as`) makes 1.0 → 1.1 zero-touch. The last `feat:` commit of Phase 21 auto-triggers release. Do NOT add a release-cut plan to Phase 20.
- **Status log entry:** after Phase 20 commits, STATE.md should record "Phase 20 CONTEXT locked at commit e7e883f with 7 decisions D-01..D-07; amends ROADMAP success criterion 2."

</specifics>

<deferred>
## Deferred Ideas

- **D-07: `customer_mapping` presence guard** — not implemented in Phase 20. REQUIREMENT scopes GUARD-01 tightly to `value_settings`; `customer_mapping` has a different failure model (no Stripe default) and warrants its own decision. Track as a post-ship candidate; guide-level warning in D-05 documents the trap meanwhile.
- **Formula input atom normalization** — rejected in D-06. If downstream Accrue feedback shows users strongly prefer atom values in write-side params, revisit as a uniform policy decision across all create/3 signatures in the SDK (not a Phase-20-local one).
- **MeterEventAdjustment webhook reconcile worked example** — D-05's dunning example stops at `MeterEventAdjustment.create/3` + telemetry, not the webhook echo. If users ask for the full round-trip, extend guide post-ship.
- **Hot-path `UsageReporter` as a moduledoc `iex>` doctest** — Claude's discretion leaves this guide-only. If `mix docs` renders the code block nicely enough, users will find it; moduledoc brevity is a higher priority.
- **Meter EventSummary aggregate queries** — separate Stripe API family, deferred to v1.2+ per research SUMMARY.md.
- **`/v2/billing/meter_event_stream` high-throughput variant** — v1.1 D3 locked deferral. Different auth model (15-min session token), different semantics. Separate work.
- **Property-based tests for MeterEvent idempotency** — `StreamData` dep would need to be added. Deferred alongside broader property test coverage for FormEncoder / pagination cursors (v1.2+ scope).
- **Parallelization of Plan 20-03 and 20-04** — technically valid (both depend only on 20-02) but sequential execution keeps commit logs clean and avoids fixture-file collisions. Revisit if wall-clock time becomes a pain point.

### Reviewed Todos (not folded)

No pending todos matched Phase 20 (confirmed via `gsd-tools todo match-phase 20`).

</deferred>

---

*Phase: 20-billing-metering*
*Context gathered: 2026-04-14*
*Research: 4 parallel gsd-advisor-researcher agents covered Gray Areas A (GUARD-01), B (Inspect masking), C (plan structure), D (guide depth)*
*Amends: ROADMAP Phase 20 success criterion 2 (via D-01) — raise on present-but-malformed value_settings, not on omission*
