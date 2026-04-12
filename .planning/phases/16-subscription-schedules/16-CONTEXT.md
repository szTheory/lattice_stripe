# Phase 16: Subscription Schedules - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Milestone:** v2.0-billing (Phase 15 D3)

<domain>
## Phase Boundary

Developers can create, retrieve, update, cancel, release, and list Stripe Subscription Schedules through `LatticeStripe.SubscriptionSchedule`, with a coherent typed-struct model for phases and phase items, an extended proration safety guard covering per-phase `proration_behavior`, and the same Phase 14/15 conventions (flat namespace, nested typed structs, reuse over duplication, PII-safe Inspect, no `Jason.Encoder`).

Requirement: **BILL-03** (Subscription Schedules extension of the Billing track).

**In scope:**
- `LatticeStripe.SubscriptionSchedule` resource module: `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` + bang variants
- Action verbs: `cancel/4`, `release/4` + bang variants
- 4 new nested typed structs under `LatticeStripe.SubscriptionSchedule.*` (Phase, CurrentPhase, PhaseItem, AddInvoiceItem)
- Reuse of `LatticeStripe.Invoice.AutomaticTax` for `phases[].automatic_tax`
- Extension of `LatticeStripe.Billing.Guards.has_proration_behavior?/1` to walk `phases[].proration_behavior`
- Wire `check_proration_required/2` into `SubscriptionSchedule.update/4` (only — create has no `proration_behavior` field)
- stripe-mock integration tests
- Extension of `guides/subscriptions.md` with a Schedules section + ExDoc Billing module group wiring

**Out of scope:**
- `search` endpoint — Stripe does not expose one for `subscription_schedule`
- Customer Portal (BILL-05)
- Coupons / PromoCodes resource wiring (BILL-06) — deferred
- Usage Records / Meters (BILL-07) — deprecated path
- Connect (phases 17/18)
- Client-side validation of create modes (`from_subscription` vs `customer+phases`) — let Stripe's 400 flow through `%LatticeStripe.Error{}`
- Client-side state pre-validation on `cancel` / `release` — TOCTOU; Phase 15 D5 "no fake ergonomics"

</domain>

<decisions>
## Implementation Decisions (Locked — D1-D5)

### D1 — Nested typed struct depth & reuse

Promote **exactly 5 nested fields** on `%SubscriptionSchedule{}` to typed structs (mirrors Phase 15's "5 promoted fields" budget):

1. **`phases`** → `[%LatticeStripe.SubscriptionSchedule.Phase{}]`
2. **`default_settings`** → **reuses** `%LatticeStripe.SubscriptionSchedule.Phase{}` (same struct)
3. **`current_phase`** → `%LatticeStripe.SubscriptionSchedule.CurrentPhase{}` (small: `start_date`, `end_date`)
4. **`phases[].items`** → `[%LatticeStripe.SubscriptionSchedule.PhaseItem{}]` — **NEW struct, not `SubscriptionItem`**
5. **`phases[].add_invoice_items`** → `[%LatticeStripe.SubscriptionSchedule.AddInvoiceItem{}]`
6. **`phases[].automatic_tax`** → **reused** as `%LatticeStripe.Invoice.AutomaticTax{}` (Phase 15 D4 precedent)

**Why `Phase` is reused for `default_settings`:** Stripe's API docs describe `default_settings` as phase-shaped minus `start_date`/`end_date`/`iterations`. Reusing one struct is justified; document the nil-trailing-fields asymmetry explicitly in `SubscriptionSchedule.Phase`'s `@moduledoc`.

**Why `PhaseItem` is NOT `SubscriptionItem`:** The shapes genuinely diverge. Phase items have NO `id`, NO `subscription`, NO `current_period_*`, NO `created`; they DO have `price_data` and `trial` which live items don't. They are **templates** that Stripe materializes into real `SubscriptionItem`s when the phase activates. Cramming both into `%SubscriptionItem{}` would create a half-nil struct and invite `nil.id` bugs in user code that assumed an item came from a live subscription. Stripe-go reached the same conclusion (`SubscriptionSchedulePhaseItem` is distinct from `SubscriptionItem`). Stripity_stripe's "everything is a map" stance is an auto-generation artifact, not a deliberate design.

**Leave as plain maps (in `extra`):** `invoice_settings`, `transfer_data`, `billing_thresholds`, `discounts`, `metadata`, `pending_update`, `application_fee_percent`, `default_tax_rates`, `trial_continuation`, `prebilling`. These are rarely-traversed config blobs; keeping them in `extra` absorbs future Stripe field additions without breaking changes.

**Pattern (inherited from Phase 14/15):**
- `@known_fields` + `extra` for every new struct
- Custom PII-safe `Inspect` on the top-level `%SubscriptionSchedule{}` (hide `customer` details, mirror `Invoice` Inspect)
- No `Jason.Encoder` derivation on any new struct

### D2 — Action verb signatures: `cancel/4` and `release/4`

```elixir
cancel(client, id, params \\ %{}, opts \\ [])
cancel!(client, id, params \\ %{}, opts \\ [])

release(client, id, params \\ %{}, opts \\ [])
release!(client, id, params \\ %{}, opts \\ [])
```

Arity-4 pass-through mirrors `LatticeStripe.Subscription.cancel/4` exactly (Phase 15 D5). Both stripity_stripe and Striped use the identical shape. Params map carries Stripe fields (`invoice_now`, `prorate` for cancel; `preserve_cancel_date` for release); `opts` keyword list carries LatticeStripe request options (`idempotency_key`, `api_version`, transport opts). This semantic boundary between wire params and request behavior is load-bearing — do not collapse into one keyword list.

**No client-side state pre-validation:** TOCTOU on schedule status makes any client-side guard a lie. Let Stripe's 4xx bubble through `%LatticeStripe.Error{}` (Phase 2 convention).

**Destructive semantics of `release`:** Document in module-level `@moduledoc` and in `release/4`'s `@doc` with a direct contrast against `cancel/4`:

> `release/4` detaches the schedule from its subscription. The subscription remains active and billable but is no longer governed by phases. This is irreversible. Contrast with `cancel/4`, which terminates both the schedule AND the underlying subscription.

No generic `stop/4` or `end/4` aliases. Function names match Stripe endpoint actions exactly (Phase 15 D5).

### D3 — Creation ergonomics: single `create/3` pass-through

```elixir
create(client, params \\ %{}, opts \\ [])
create!(client, params \\ %{}, opts \\ [])
```

**No** `create_from_subscription/3` helper. **No** client-side validation of the two mutually-exclusive param sets (`from_subscription` vs `customer+phases`). Every reference SDK — stripity_stripe v3, stripe-ruby, stripe-node, stripe-go, stripe-java, stripe-python — uses a single pass-through for SubscriptionSchedule create. Splitting modes for exactly one resource creates permanent inconsistency debt ("why does SubscriptionSchedule have `create_from_X` but Subscription doesn't?").

**DX for "which mode did I need?":** solved in `@doc` via two clearly-labeled examples and a `## Creation modes` section of the module `@moduledoc`. Stripe's 400 ("You may only specify one of these parameters: from_subscription, phases") surfaces verbatim through `%Error{}`, making the failure mode self-correcting on first attempt.

### D4 — Proration guard: extend to `phases[].proration_behavior` only

**Critical finding:** Stripe's `POST /v1/subscription_schedules/:id` accepts `proration_behavior` at **exactly two paths**:
1. Top-level `params["proration_behavior"]`
2. Per-phase `params["phases"][i]["proration_behavior"]`

**Stripe does NOT accept `proration_behavior` at `phases[].items[]`.** Verified against [Stripe Update a schedule reference](https://docs.stripe.com/api/subscription_schedules/update). This collapses the guard depth question to a binary.

**Implementation:**

Add `phases_has?/1` private helper in `LatticeStripe.Billing.Guards` mirroring the existing `items_has?/1` byte-for-byte (defensive against nil, non-list, non-map elements). Wire it into `has_proration_behavior?/1` as a new `or` branch:

```elixir
def has_proration_behavior?(params) do
  top_level_has?(params) or
    subscription_details_has?(params) or
    items_has?(params) or
    phases_has?(params)                  # NEW
end
```

**Wire into:**
- `SubscriptionSchedule.update/4` via `check_proration_required/2`

**Do NOT wire into:**
- `SubscriptionSchedule.create/3` — Stripe does not accept `proration_behavior` on create (schedules prorate based on `start_date` mode, not an explicit field)
- `SubscriptionSchedule.cancel/4` — `prorate` is a different concept (whether the cancellation generates a proration invoice), not `proration_behavior`; do not conflate
- `SubscriptionSchedule.release/4` — no proration concept

**Unit tests (4 cases):** top-level present, phase-level present, neither, malformed `phases` (non-list / non-map elements).

### D5 — Plan file structure: 3 plans, action-aligned

Mirrors Phase 15's proven 3-plan rhythm:

- **16-01-PLAN.md** — `SubscriptionSchedule` struct + 4 new nested typed structs (`Phase`, `CurrentPhase`, `PhaseItem`, `AddInvoiceItem`) + CRUD (`create`, `retrieve`, `update`, `list`, `stream!`) + bang variants + custom PII-safe `Inspect` + unit tests
- **16-02-PLAN.md** — Action verbs (`cancel/4`, `release/4`) + bang variants + `Billing.Guards.phases_has?/1` extension + `check_proration_required/2` wiring into `update/4` + unit tests (guard + action verbs)
- **16-03-PLAN.md** — stripe-mock integration tests (create from scratch, create from subscription, update, cancel, release, list) + `guides/subscriptions.md` Schedules section + `mix.exs` ExDoc Billing module group extension

**Why this split is cohesive:** 16-01 owns "a schedule exists and can be read/mutated." 16-02 owns "schedule mutations are safe" — cancel, release, and the guard extension share a single review concern (mutation safety). 16-03 owns "real Stripe accepts our shapes and humans can read about it." Each plan fits within Phase 15's proven ~500-600 LOC ceiling.

### Claude's Discretion

- Exact `@known_fields` list on each new struct (follow `lib/lattice_stripe/invoice/line_item.ex` template)
- Test organization within each `*_test.exs` (follow `test/lattice_stripe/subscription_test.exs` style)
- `guides/subscriptions.md` Schedules section placement and heading depth
- Fixture JSON shape for `test/support/fixtures/subscription_schedule.ex` (follow `test/support/fixtures/customer.ex` template)
- Whether to split `16-01` further if task count exceeds ~8 tasks (acceptable escape hatch)
- Whether `update/4` accepts a convenience atom-keyed `phases:` param or requires string-keyed `"phases"` (follow existing resource convention — string keys pass through, atom keys normalized by `form_encoder`)
- Exact `@moduledoc` wording for the `Phase` struct explaining its dual usage (phases[] vs default_settings)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 15 precedents (closest template — same size & complexity)
- `lib/lattice_stripe/subscription.ex` — action verbs, lifecycle helpers, PII-safe Inspect, nested struct promotion pattern
- `lib/lattice_stripe/subscription_item.ex` — flat-namespace resource with required param on list
- `lib/lattice_stripe/subscription/pause_collection.ex` — small typed nested struct template
- `lib/lattice_stripe/subscription/cancellation_details.ex` — small typed nested struct template
- `lib/lattice_stripe/subscription/trial_settings.ex` — typed nested struct with further nesting (`end_behavior`)
- `.planning/phases/15-subscriptions-subscription-items/15-CONTEXT.md` — locked D1-D5 patterns this phase inherits
- `.planning/phases/15-subscriptions-subscription-items/15-01-PLAN.md` — plan-sizing reference (569-line ceiling)
- `.planning/phases/15-subscriptions-subscription-items/15-03-PLAN.md` — stripe-mock integration + guide wiring template

### Phase 14 precedents
- `lib/lattice_stripe/invoice.ex` — larger resource precedent; Inspect pattern
- `lib/lattice_stripe/invoice/automatic_tax.ex` — **reused as** `SubscriptionSchedule.Phase.automatic_tax`
- `lib/lattice_stripe/invoice/line_item.ex` — larger nested struct with `@known_fields` + `extra` and custom Inspect; template for `PhaseItem`
- `lib/lattice_stripe/invoice/status_transitions.ex` — small nested struct template

### Reusable helpers (call — do not duplicate)
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3`
- `lib/lattice_stripe/client.ex` — `request/2`, `request!/2`, `require_explicit_proration` field
- `lib/lattice_stripe/billing/guards.ex` — `check_proration_required/2`, existing `top_level_has?/1`, `subscription_details_has?/1`, `items_has?/1` (template for new `phases_has?/1`)
- `lib/lattice_stripe/list.ex` — `stream!/2` and `from_json/3`
- `lib/lattice_stripe/form_encoder.ex` — nested-param encoding (critical — verify `phases[][items][]` and `phases[][add_invoice_items][]` array encoding in tests)
- `lib/lattice_stripe/telemetry.ex` — general request events only; no schedule-specific events

### Test infrastructure
- `test/support/test_helpers.ex` — `test_client/1`, `ok_response/1`, `list_json/2`, `test_integration_client/0`
- `test/support/fixtures/subscription.ex` — fixture module template (closest match)
- `test/support/fixtures/customer.ex` — baseline fixture template
- `test/integration/subscription_integration_test.exs` — stripe-mock integration skeleton
- `test/lattice_stripe/billing/guards_test.exs` — guard test template (extend with `phases[]` cases)

### External specs
- [Stripe — Subscription Schedule object](https://docs.stripe.com/api/subscription_schedules/object)
- [Stripe — Create a schedule](https://docs.stripe.com/api/subscription_schedules/create)
- [Stripe — Update a schedule](https://docs.stripe.com/api/subscription_schedules/update) — canonical source for `proration_behavior` valid paths
- [Stripe — Cancel a schedule](https://docs.stripe.com/api/subscription_schedules/cancel)
- [Stripe — Release a schedule](https://docs.stripe.com/api/subscription_schedules/release)
- [Stripe — Prorations guide](https://docs.stripe.com/billing/subscriptions/prorations)

### Project conventions
- `CLAUDE.md` — project instructions and stack decisions
- `.planning/STATE.md` — current position, milestone framing (v2.0-billing)
- `.planning/REQUIREMENTS.md` — BILL-03 definition
- `.planning/PROJECT.md` — core value, non-negotiables

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LatticeStripe.Invoice.AutomaticTax`**: reused as `SubscriptionSchedule.Phase.automatic_tax` — no duplication
- **`LatticeStripe.Billing.Guards.check_proration_required/2`**: wire into `update/4` after adding `phases_has?/1` branch
- **`LatticeStripe.Resource` helpers**: all unwrap/bang/require_param helpers work unchanged for this resource
- **`LatticeStripe.List.stream!/2`**: works unchanged for `list` → `stream!`
- **`LatticeStripe.FormEncoder`**: already handles nested arrays-of-maps; no changes expected (verify in integration tests)

### Established Patterns
- **5-promoted-fields budget** (Phase 15): SubscriptionSchedule follows the same rhythm — Phase, CurrentPhase, PhaseItem, AddInvoiceItem, reused AutomaticTax = 5 typed things
- **`@known_fields` + `extra`**: every new struct uses this for future-proofing against Stripe field additions
- **Custom PII-safe `Inspect`**: top-level resources only (matches Subscription, Invoice); nested structs use default derived Inspect
- **Arity-4 action verbs**: `(client, id, params, opts)` universal pattern
- **Single `create/3` pass-through**: universal pattern; no per-resource special constructors
- **No `Jason.Encoder` derivation**: on any struct in the SDK
- **Telemetry piggyback**: no resource-specific events; general `[:lattice_stripe, :request, *]` only

### Integration Points
- `mix.exs` — ExDoc `groups_for_modules` Billing group needs `SubscriptionSchedule` + nested types added
- `guides/subscriptions.md` — existing guide gets a new `## Subscription Schedules` section
- `lib/lattice_stripe/billing/guards.ex` — one new private helper + one `or` branch in `has_proration_behavior?/1`
- `test/lattice_stripe/billing/guards_test.exs` — 4 new test cases
- `test/support/fixtures/` — new `subscription_schedule.ex` fixture module

</code_context>

<specifics>
## Specific Ideas from Research

- **Phase struct dual usage:** `SubscriptionSchedule.Phase` is used for BOTH `schedule.phases[]` AND `schedule.default_settings`. On `default_settings` instances, `start_date`, `end_date`, and `iterations` will be `nil`. Document this explicitly in the struct's `@moduledoc` — this is a Stripe-side modeling asymmetry, not a LatticeStripe defect.

- **PhaseItem ≠ SubscriptionItem:** Document in `PhaseItem`'s `@moduledoc` that a phase item is a **template** that Stripe materializes into a real `%SubscriptionItem{}` when the phase activates. Link both `@moduledoc`s to each other with a `See also:` note.

- **`release/4` destructiveness:** The `@doc` for `release/4` must contrast it with `cancel/4` in prose: "Detaches the schedule from its subscription; the subscription continues billing but is no longer phase-governed. Irreversible. Contrast with `cancel/4` which terminates both."

- **Two creation modes in `@moduledoc`:** Add a `## Creation modes` section with two code examples — one for `from_subscription` mode, one for `customer + phases` mode — and explicitly note that mixing them raises a Stripe 400 that surfaces as `%LatticeStripe.Error{type: :invalid_request_error}`.

- **Proration guard finding:** Add a source-code comment in `Billing.Guards.phases_has?/1` noting that Stripe only accepts `proration_behavior` at top-level and `phases[].proration_behavior` — not at `phases[].items[]` — and cite the Stripe API reference URL. Future maintainers tempted to add deeper walking will see the comment.

- **No search endpoint:** Add a brief note in `SubscriptionSchedule.@moduledoc` that Stripe does not expose a `search` endpoint for schedules (unlike Subscription), so the module has no `search/3` or `search_stream!/3`. Prevents "why is this missing?" questions.

- **PII safety:** Custom `Inspect` on `%SubscriptionSchedule{}` must hide `customer` details and anything payment-related in `default_settings.default_payment_method` / `phases[].default_payment_method`. Mirror `Subscription` Inspect.

- **Form encoder sanity check:** The deepest param path will be something like `phases[0][items][0][price_data][currency]`. Phase 16 integration tests should exercise this explicitly — stripity_stripe had historical bugs in this area.

</specifics>

<deferred>
## Deferred Ideas

- **Subscription Schedule `search`** — Stripe does not expose this endpoint. If Stripe adds it in the future, add to a follow-up phase.
- **Coupons / Promotion Codes / Discounts resource wiring** (BILL-06) — restored to codebase via Phase 15 D1, still awaits its own resource phase
- **Customer Portal Sessions** (BILL-05) — future phase
- **Usage Records / Meters / Meter Events** (BILL-07) — deprecated path at Stripe; deferred entirely
- **Connect + schedules** (phases 17/18) — platform-schedules interactions out of scope for Billing track
- **Convenience `create_from_subscription/3` helper** — rejected in D3 to preserve SDK-wide single-create consistency; revisit only if adopted SDK-wide
- **Client-side create-mode validation** — rejected in D3 as Ecto-shaped solution to an HTTP SDK problem; Stripe's 400 is already actionable
- **Client-side `cancel`/`release` state pre-validation** — rejected in D2 (TOCTOU, Phase 15 D5)
- **Deep typed structs for `invoice_settings`, `transfer_data`, `billing_thresholds`** — rejected in D1 as promotion creep; leave in `extra`
- **Subscription-specific or schedule-specific telemetry events** — Phase 15 decision, applies here too; webhook layer owns state transitions

</deferred>

---

*Phase: 16-subscription-schedules*
*Context gathered: 2026-04-12 — 4 parallel advisor agents researched all 5 gray areas; user locked recommendations one-shot*
