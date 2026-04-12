# Phase 16: Subscription Schedules — Research

**Researched:** 2026-04-12
**Phase:** 16-subscription-schedules
**Requirement:** BILL-03 (Billing track extension)
**Status:** Ready for planning
**Confidence:** HIGH

<user_constraints>
## User Constraints (from 16-CONTEXT.md — D1–D5 LOCKED)

- **D1 — 5 promoted typed structs:** `Phase` (reused for `default_settings`), `CurrentPhase`, `PhaseItem` (NEW, NOT `SubscriptionItem`), `AddInvoiceItem`, reused `Invoice.AutomaticTax` for `phases[].automatic_tax`. Everything else stays in `extra` / plain maps (invoice_settings, transfer_data, billing_thresholds, discounts, metadata, pending_update, application_fee_percent, default_tax_rates, trial_continuation, prebilling).
- **D2 — Arity-4 action verbs:** `cancel(client, id, params \\ %{}, opts \\ [])` and `release(client, id, params \\ %{}, opts \\ [])` plus bang variants. **No client-side state pre-validation.** Stripe's 4xx surfaces as `%LatticeStripe.Error{}`.
- **D3 — Single `create/3` pass-through:** No `create_from_subscription/3`. No client-side validation of `from_subscription` vs `customer+phases`. Stripe's 400 is the documented failure mode.
- **D4 — Proration guard:** extend with `phases_has?/1` ONLY. Detects `phases[].proration_behavior`, NOT `phases[].items[].proration_behavior` (Stripe doesn't accept it there). Wired into `update/4` only — NOT create/cancel/release.
- **D5 — 3 plans:** 16-01 (struct + nested types + CRUD + Inspect + unit tests), 16-02 (action verbs + guard extension + wiring), 16-03 (integration tests + guide + ExDoc wiring).

**Deferred (out of scope):** Search endpoint (Stripe has none for schedules), Customer Portal, Coupons wiring, Meters, Connect, `create_from_subscription/3` helper, client-side create-mode validation, client-side cancel/release state validation.

**Claude's Discretion:** Exact `@known_fields` per struct, test organization, guide placement, fixture JSON shape, task-split-at-8 escape hatch, atom-vs-string-key convention in update (follow existing), `@moduledoc` wording for dual-use `Phase` struct.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BILL-03 | Subscription Schedules extension of Billing track | §Stripe API Shapes documents all 6 endpoints; §Billing.Guards Current Implementation confirms single-branch extension pattern; §Phase 15 Plan Template confirms the 3-plan rhythm fits; §Form Encoder confirms nested `phases[][items][]` encoding works without changes |
</phase_requirements>

## Summary

Phase 16 is implementation-ready. All 5 user decisions (D1–D5) are locked and the codebase already contains every template required to execute them:

1. **Stripe's SubscriptionSchedule API surface is small and stable** — 6 endpoints, no search, cancel/release are `POST /:id/{cancel,release}` (NOT `DELETE`).
2. **`LatticeStripe.FormEncoder` already handles arbitrary-depth nested params** (`phases[0][items][0][price_data][currency]`) — verified by existing `deeply nested (4+ levels)` test. No encoder changes required; Phase 16 integration tests just need to exercise the deepest path as a regression guard.
3. **`Billing.Guards` byte-for-byte pattern for `phases_has?/1`** — mirror `items_has?/1` exactly. Six lines of defensive code, three new `or` branches in `has_proration_behavior?/1`, four new unit tests. Trivial.
4. **Phase 15 template matches one-for-one** — `Subscription` + 3 nested structs + guard extension landed in `15-01-PLAN.md` as a single ~569-line plan with 3 tasks. Phase 16 has 4 nested structs + struct + CRUD — same shape, same ceiling.
5. **`stripe-mock` supports schedule endpoints** — it's OpenAPI-spec driven and covers every public Stripe endpoint. One known quirk: responses are hardcoded fixtures, not stateful, so integration tests must not assume the mock reflects posted params (matches Phase 15 precedent: tests assert shape, not semantics).

**Primary recommendation:** Ship the 3 plans exactly as D5 specifies. No structural changes, no novel research gaps.

## Stripe API Shapes

All canonical sources: [docs.stripe.com/api/subscription_schedules](https://docs.stripe.com/api/subscription_schedules/object).

### Endpoint Table

| Action | HTTP | Path | Notes |
|--------|------|------|-------|
| Create | POST | `/v1/subscription_schedules` | Mutually exclusive modes: `from_subscription` OR (`customer` + `phases`) |
| Retrieve | GET | `/v1/subscription_schedules/{id}` | — |
| Update | POST | `/v1/subscription_schedules/{id}` | Accepts `proration_behavior` at top-level AND `phases[].proration_behavior` |
| List | GET | `/v1/subscription_schedules` | Standard cursor pagination |
| Cancel | **POST** | `/v1/subscription_schedules/{id}/cancel` | **NOT DELETE** — differs from `Subscription.cancel` |
| Release | POST | `/v1/subscription_schedules/{id}/release` | Detaches schedule, leaves subscription active |

**CRITICAL wire-shape gotcha:** `Subscription.cancel` uses `DELETE /v1/subscriptions/:id`, but `SubscriptionSchedule.cancel` uses **`POST /v1/subscription_schedules/:id/cancel`**. Do not mechanically copy `Subscription.cancel`'s dispatch — it must be `:post` with a sub-path. Same applies to `release`.

### Top-Level `%SubscriptionSchedule{}` Fields (from object docs)

```
id object application billing_mode canceled_at completed_at created current_phase
customer customer_account default_settings end_behavior livemode metadata phases
released_at released_subscription status subscription test_clock
```

- `status` — one of: `not_started`, `active`, `completed`, `released`, `canceled`
- `end_behavior` — `"release"` or `"cancel"`
- `phases` — list of Phase objects
- `current_phase` — small `{start_date, end_date}` object or nil
- `default_settings` — phase-shaped object minus `start_date`/`end_date`/`iterations`

### Phase Object Fields

```
add_invoice_items application_fee_percent automatic_tax billing_cycle_anchor
billing_thresholds collection_method currency default_payment_method default_tax_rates
description discounts end_date invoice_settings items metadata on_behalf_of
proration_behavior start_date transfer_data trial_end
```

Additional fields that may appear (from Create API reference): `iterations`, `trial`, `trial_continuation`, `pause_collection`, `coupon`, `prebilling`.

**Note:** On `default_settings` usage, `start_date`, `end_date`, `iterations`, `trial`, and `trial_end` will be `nil`. Document this asymmetry in `@moduledoc`.

### PhaseItem (`phases[].items[]`) Fields

```
billing_thresholds discounts metadata price price_data quantity tax_rates trial_data
```

Note: `price_data` is an inline-creation nested object (includes `currency`, `product`, `unit_amount`, `recurring`, `tax_behavior`). Keep `price_data` as a plain map on `PhaseItem` — do not promote.

**Shape divergence from `SubscriptionItem` (rationale for NEW struct per D1):**
- PhaseItem has NO `id`, `subscription`, `current_period_*`, `created`
- PhaseItem HAS `price_data`, `trial_data`
- PhaseItem is a **template**, not a live item

### AddInvoiceItem (`phases[].add_invoice_items[]`) Fields

```
discounts metadata price price_data quantity tax_rates period
```

Smaller than PhaseItem. `period` is a `{start, end}` map and should stay plain.

### CurrentPhase Fields

```
start_date end_date
```

Two integer Unix timestamps. Trivial struct.

### Sample JSON Response (Retrieve)

```json
{
  "id": "sub_sched_1Abc",
  "object": "subscription_schedule",
  "application": null,
  "canceled_at": null,
  "completed_at": null,
  "created": 1700000000,
  "current_phase": {"start_date": 1700000000, "end_date": 1702678400},
  "customer": "cus_test",
  "default_settings": {
    "application_fee_percent": null,
    "automatic_tax": {"enabled": false, "liability": null},
    "billing_cycle_anchor": "automatic",
    "collection_method": "charge_automatically",
    "default_payment_method": null,
    "invoice_settings": {"days_until_due": null},
    "transfer_data": null
  },
  "end_behavior": "release",
  "livemode": false,
  "metadata": {},
  "phases": [
    {
      "add_invoice_items": [],
      "application_fee_percent": null,
      "automatic_tax": {"enabled": false, "liability": null},
      "billing_cycle_anchor": null,
      "collection_method": null,
      "currency": "usd",
      "default_payment_method": null,
      "default_tax_rates": [],
      "description": null,
      "discounts": [],
      "end_date": 1702678400,
      "invoice_settings": null,
      "items": [
        {
          "billing_thresholds": null,
          "discounts": [],
          "metadata": {},
          "price": "price_test123",
          "quantity": 1,
          "tax_rates": []
        }
      ],
      "metadata": {},
      "on_behalf_of": null,
      "proration_behavior": "create_prorations",
      "start_date": 1700000000,
      "transfer_data": null,
      "trial_end": null
    }
  ],
  "released_at": null,
  "released_subscription": null,
  "status": "active",
  "subscription": "sub_test",
  "test_clock": null
}
```

## Form Encoder Nested Arrays

### Current Behavior (verified against `lib/lattice_stripe/form_encoder.ex` + tests)

`LatticeStripe.FormEncoder.encode/1` already handles every shape Phase 16 will throw at it:

1. **Nested maps** → bracket notation: `%{metadata: %{plan: "pro"}}` → `metadata[plan]=pro`
2. **Array of maps** → indexed brackets: `%{items: [%{price: "p_1"}]}` → `items[0][price]=p_1`
3. **Arbitrary depth** → verified by existing test `deeply nested (4+ levels): produces correct bracket notation`: `%{a: %{b: %{c: %{d: "deep"}}}}` → `a[b][c][d]=deep`
4. **Array of maps with further nested map** → naturally handled by recursive `flatten/2` + `flatten_value/2`. No special case needed.

**The deepest Phase 16 path**, `params["phases"][0]["items"][0]["price_data"]["recurring"]["interval"]`, encodes as:

```
phases[0][items][0][price_data][recurring][interval]=month
```

This works today. The encoder's `flatten/2` recursively dispatches on `is_map` and `is_list` at every level — there is no hardcoded depth limit.

### Gaps / Test Targets (none structural — regression guard only)

**No encoder changes needed.** Phase 16 adds **one regression-guard test** in the form encoder test file (Plan 16-01 or 16-03's call) asserting the exact string for the deepest known Phase 16 shape:

```elixir
test "phases[].items[].price_data nested encoding (Phase 16 regression guard)" do
  params = %{
    "phases" => [
      %{
        "items" => [
          %{"price_data" => %{"currency" => "usd", "recurring" => %{"interval" => "month"}}}
        ],
        "proration_behavior" => "create_prorations"
      }
    ]
  }

  result = FormEncoder.encode(params)
  assert result =~ "phases[0][items][0][price_data][currency]=usd"
  assert result =~ "phases[0][items][0][price_data][recurring][interval]=month"
  assert result =~ "phases[0][proration_behavior]=create_prorations"
end
```

**Additionally, Plan 16-03's stripe-mock integration test is the final validation** — if any nested-array encoding is wrong, stripe-mock's OpenAPI-spec-driven validator returns a 400 and the test fails. This is Phase 15's T-15-05 mitigation pattern; re-use it verbatim.

**One subtle concern to mention in Plan 16-03 notes:** Elixir maps don't preserve insertion order, and `FormEncoder.encode/1` sorts keys alphabetically before emitting. This means `phases[0][items][0][price]` and `phases[0][items][0][price_data][currency]` land alphabetically — `price` before `price_data`. That's fine for Stripe (order doesn't matter in form params), but document that any assertion on exact wire-string order must account for sort order.

## stripe-mock Coverage

**`stripe/stripe-mock`** is auto-generated from Stripe's [OpenAPI spec](https://github.com/stripe/openapi) and supports **every public endpoint** that appears in the spec. `/v1/subscription_schedules` (all 6 endpoints) is in the spec → supported.

**Confidence:** HIGH for endpoint presence, MEDIUM for response fidelity.

### Known quirks (Phase 15 learned these — they apply here)

1. **Responses are hardcoded fixtures.** The mock does not execute Stripe's business logic. `POST /v1/subscription_schedules` returns a canned schedule object whose `id`, `status`, `phases` content may not reflect the params you sent. Phase 15's integration test comment captures this verbatim (`test/integration/subscription_integration_test.exs:78-80`): "stripe-mock returns a fresh randomly-generated resource on each call…it's stateless against our requests — it validates against the OpenAPI spec and returns a canned-but-randomized response."
2. **Pattern: assert shape, not semantics.** Integration tests should assert `%SubscriptionSchedule{}` struct with `is_binary(id)`, `is_list(phases)`, etc. — NOT that the returned `phases[0].items[0].price == "price_test"`.
3. **Server-side validation IS the form encoder regression guard.** stripe-mock rejects malformed form bodies (e.g., mis-nested `phases[items][]` without the `[0]` index) with a 400, so any test that returns `{:ok, %SubscriptionSchedule{}}` has proven the encoder round-trip worked. Phase 15's `test "form encoder encodes items[0][...] nested params correctly"` is the template.
4. **Idempotency key honored.** stripe-mock returns the same object for two calls with the same `Idempotency-Key` header. Phase 15 test pattern: `test "idempotency_key is forwarded"` — reuse verbatim.
5. **No state transitions.** Calling `cancel/4` on a mock-returned schedule id may return `{:ok, %SubscriptionSchedule{status: "active"}}` (fixture) instead of `"canceled"`. Do not assert on returned `status` — assert on the HTTP path hit and that the call succeeded.

### Required Setup (already in place from Phase 9/15)

- Docker: `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`
- Test helper: `LatticeStripe.TestHelpers.test_integration_client/1` — points at `http://localhost:12111`
- Tag: `@moduletag :integration`
- Guard: `setup_all` does a `:gen_tcp.connect(~c"localhost", 12_111, ...)` and raises if down (pattern: `test/integration/subscription_integration_test.exs:11-21`)

## Phase 15 Plan Template

**Source:** `.planning/phases/15-subscriptions-subscription-items/{15-01,15-02,15-03}-PLAN.md`.

| Plan | Wave | Tasks | Files Modified | LOC ceiling | Test file(s) |
|------|------|-------|----------------|-------------|--------------|
| 15-01 | 1 | 3 tasks: (1) 3 nested structs + tests, (2) `Billing.Guards` extension + tests, (3) `Subscription` resource + tests + fixture | 11 files | ~569 lines (plan), not code | `subscription_test.exs`, 3 nested struct tests, `billing/guards_test.exs`, `fixtures/subscription.ex` |
| 15-02 | 2 | 1 task: `SubscriptionItem` module + tests + fixture | 3 files | ~300 lines | `subscription_item_test.exs`, `fixtures/subscription_item.ex` |
| 15-03 | 3 | 4 tasks: (1) Subscription integration, (2) SubscriptionItem integration, (3) `guides/subscriptions.md`, (4) `mix.exs` ExDoc wiring | 4 files | ~340 lines | 2 integration test files, 1 guide, mix.exs |

### Plan 15-01 Task Shape (mirror for 16-01)

1. **Task 1** (`tdd: true`) — Create 3 (Phase 16: 4) nested typed struct modules, one `.ex` + one `*_test.exs` each. Each struct is ~45 lines with `@known_fields`, `defstruct`, `from_map/1`, `defimpl Inspect`. Test file covers `from_map/1` round-trip + Inspect output + `nil` handling.
2. **Task 2** (`tdd: true`) — Extend `Billing.Guards.has_proration_behavior?/1` with one new `or` branch + one new `defp phases_has?/1` helper. Tests: 4–5 new cases in `guards_test.exs` (phase present, phase absent, malformed, mixed).
3. **Task 3** (`tdd: true`) — Build top-level `Subscription` resource module with struct, CRUD + lifecycle fns, custom Inspect, unit tests via Mox, fixture module.

**For Phase 16:** Task 1 grows to 4 nested structs; Task 2 becomes `phases_has?/1` instead of `items_has?/1`; Task 3 is `SubscriptionSchedule` struct + CRUD only (no action verbs — those move to 16-02 per D5).

### Plan 15-02 Task Shape (mirror for 16-02)

**Phase 15:** Built `SubscriptionItem`. **Phase 16:** Wire action verbs + guard extension + `update/4` proration wiring.

- Suggested 1-task plan (matches 15-02's structure): Add `cancel/4`, `cancel!/4`, `release/4`, `release!/4` to `SubscriptionSchedule` + wire `check_proration_required/2` into `update/4` + add unit tests covering guard rejection on update, cancel/release pass-through, arity-4 signatures, bang variants, idempotency forwarding.

### Plan 15-03 Task Shape (mirror for 16-03)

**4 tasks:** (1) stripe-mock integration covering all 6 endpoints, (2) form-encoder regression test for `phases[][items][][price_data][...]`, (3) `guides/subscriptions.md` extended with Schedules section, (4) `mix.exs` ExDoc Billing module group extended to include SubscriptionSchedule + 4 nested types.

**Note:** Phase 15's guide is `guides/subscriptions.md`. Phase 16 extends the same file with a new `## Subscription Schedules` section — do NOT create a new guide file.

### Plan file ceiling discipline

Each plan stayed under ~600 lines of plan markdown. Phase 16 is modestly larger (4 nested structs vs 3; 2 action verbs vs bolt-on lifecycle) but still fits comfortably. No plan should need to split further; the D5 "escape hatch" (split 16-01 if task count > 8) is unlikely to trigger.

## Billing.Guards Current Implementation

**File:** `lib/lattice_stripe/billing/guards.ex` (verbatim, 56 lines):

```elixir
defmodule LatticeStripe.Billing.Guards do
  @moduledoc """
  Shared pre-request guards for Billing operations.
  Used by `Invoice.upcoming/3`, `Invoice.create_preview/3` (Phase 14),
  and `Subscription`/`SubscriptionItem` mutations (Phase 15).
  """
  alias LatticeStripe.{Client, Error}

  @spec check_proration_required(Client.t(), map()) :: :ok | {:error, Error.t()}
  def check_proration_required(%Client{require_explicit_proration: false}, _params), do: :ok

  def check_proration_required(%Client{require_explicit_proration: true}, params) do
    if has_proration_behavior?(params) do
      :ok
    else
      {:error,
       %Error{
         type: :proration_required,
         message:
           "proration_behavior is required when require_explicit_proration is enabled. Valid values: \"create_prorations\", \"always_invoice\", \"none\""
       }}
    end
  end

  defp has_proration_behavior?(params) do
    Map.has_key?(params, "proration_behavior") or
      (is_map(params["subscription_details"]) and
         Map.has_key?(params["subscription_details"], "proration_behavior")) or
      items_has?(params["items"])
  end

  defp items_has?(items) when is_list(items) do
    Enum.any?(items, fn
      item when is_map(item) -> Map.has_key?(item, "proration_behavior")
      _ -> false
    end)
  end

  defp items_has?(_), do: false
end
```

### Phase 16 Extension (`phases_has?/1` byte-for-byte proposal)

Replace `has_proration_behavior?/1` with:

```elixir
defp has_proration_behavior?(params) do
  Map.has_key?(params, "proration_behavior") or
    (is_map(params["subscription_details"]) and
       Map.has_key?(params["subscription_details"], "proration_behavior")) or
    items_has?(params["items"]) or
    phases_has?(params["phases"])
end

# Detects whether any element of a `phases[]` array carries a
# `"proration_behavior"` key at the phase level. Defensive against nil,
# non-list, and non-map list elements.
#
# NOTE: Stripe only accepts `proration_behavior` at top-level and at
# `phases[].proration_behavior` on POST /v1/subscription_schedules/:id —
# it does NOT accept it at `phases[].items[]`. Do not walk deeper.
# Source: https://docs.stripe.com/api/subscription_schedules/update
defp phases_has?(phases) when is_list(phases) do
  Enum.any?(phases, fn
    phase when is_map(phase) -> Map.has_key?(phase, "proration_behavior")
    _ -> false
  end)
end

defp phases_has?(_), do: false
```

This is **7 added lines** (plus the `or` continuation and the comment). Structurally identical to `items_has?/1` — same defensive guards, same `Enum.any?` pattern, same fallback clause.

### Unit Test Proposal (4 cases — Plan 16-02 Task)

Append to `test/lattice_stripe/billing/guards_test.exs` (mirrors existing `items[]` cases lines 79–124):

```elixir
test "phases[] with proration_behavior returns :ok" do
  client = test_client(require_explicit_proration: true)

  params = %{
    "phases" => [
      %{"items" => [%{"price" => "price_1"}], "proration_behavior" => "create_prorations"}
    ]
  }

  assert Guards.check_proration_required(client, params) == :ok
end

test "phases[] without proration_behavior returns error" do
  client = test_client(require_explicit_proration: true)
  params = %{"phases" => [%{"items" => [%{"price" => "price_1"}]}]}

  assert {:error, %Error{type: :proration_required}} =
           Guards.check_proration_required(client, params)
end

test "phases[] with non-map element does not crash" do
  client = test_client(require_explicit_proration: true)

  assert {:error, %Error{type: :proration_required}} =
           Guards.check_proration_required(client, %{"phases" => ["not_a_map"]})
end

test "phases[] with mixed elements — one has proration_behavior — returns :ok" do
  client = test_client(require_explicit_proration: true)

  params = %{
    "phases" => [
      %{"items" => [%{"price" => "p1"}]},
      %{"items" => [%{"price" => "p2"}], "proration_behavior" => "none"}
    ]
  }

  assert Guards.check_proration_required(client, params) == :ok
end
```

## Subscription Inspect Implementation (Mirror Template)

**File:** `lib/lattice_stripe/subscription.ex` lines 520–547 (verbatim):

```elixir
defimpl Inspect, for: LatticeStripe.Subscription do
  import Inspect.Algebra

  def inspect(sub, opts) do
    # Hide PII: customer, payment_settings, default_payment_method, latest_invoice.
    # Show only presence markers or safe structural fields.
    base = [
      id: sub.id,
      object: sub.object,
      status: sub.status,
      current_period_end: sub.current_period_end,
      livemode: sub.livemode,
      has_customer?: not is_nil(sub.customer),
      has_payment_settings?: not is_nil(sub.payment_settings),
      has_default_payment_method?: not is_nil(sub.default_payment_method),
      has_latest_invoice?: not is_nil(sub.latest_invoice)
    ]

    fields = if sub.extra == %{}, do: base, else: base ++ [extra: sub.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Subscription<" | pairs] ++ [">"])
  end
end
```

### Phase 16 `SubscriptionSchedule` Inspect (Mirror)

Hide: `customer`, `default_settings` (contains `default_payment_method`), and `subscription` (the generated subscription id; low PII risk but mirrors Subscription's pattern of not surfacing the linked entity). Surface: `id`, `object`, `status`, `end_behavior`, `livemode`, and `current_phase` (non-sensitive timestamps). Show presence booleans for `customer`, `subscription`, `default_settings`, `phases` (non-empty).

```elixir
defimpl Inspect, for: LatticeStripe.SubscriptionSchedule do
  import Inspect.Algebra

  def inspect(sched, opts) do
    base = [
      id: sched.id,
      object: sched.object,
      status: sched.status,
      end_behavior: sched.end_behavior,
      current_phase: sched.current_phase,
      livemode: sched.livemode,
      has_customer?: not is_nil(sched.customer),
      has_subscription?: not is_nil(sched.subscription),
      has_default_settings?: not is_nil(sched.default_settings),
      phase_count: if(is_list(sched.phases), do: length(sched.phases), else: 0)
    ]

    fields = if sched.extra == %{}, do: base, else: base ++ [extra: sched.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.SubscriptionSchedule<" | pairs] ++ [">"])
  end
end
```

**Assertions the test must include (mirror Phase 15):**
- `refute inspected =~ "cus_"` (customer id not surfaced)
- `refute inspected =~ "default_payment_method"` (hidden inside default_settings)
- `assert inspected =~ "has_customer?: true"` (presence marker shown)
- `assert inspected =~ "phase_count:"` (safe structural metadata shown)

The four new nested structs (`Phase`, `CurrentPhase`, `PhaseItem`, `AddInvoiceItem`) each need a `defimpl Inspect` following the `PauseCollection` / `LineItem` template (flat field list, show `extra` when non-empty, no masking needed — they're below the PII waterline). **Exception:** `Phase` may carry `default_payment_method` inline on `default_settings` usage — the top-level `SubscriptionSchedule` Inspect handles this by never calling `to_doc` on `default_settings` directly, but the nested `Phase` struct's own default inspect (if a user inspects a `%Phase{}` standalone) should mask `default_payment_method`. Add a `masked_default_payment_method` presence marker like `CancellationDetails` masks `comment`.

## Fixture Shape

**New file:** `test/support/fixtures/subscription_schedule.ex`

Template: `test/support/fixtures/subscription.ex` (3 helper fns: `basic/1`, `with_phases/1`, `canceled/1`). Fixture map must be valid input to `SubscriptionSchedule.from_map/1` and exercise every nested struct decoder.

```elixir
defmodule LatticeStripe.Test.Fixtures.SubscriptionSchedule do
  @moduledoc false

  @doc "Minimal active schedule with one phase and one item."
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "sub_sched_test1234567890",
        "object" => "subscription_schedule",
        "status" => "active",
        "customer" => "cus_test123",
        "subscription" => "sub_test1234567890",
        "end_behavior" => "release",
        "livemode" => false,
        "created" => 1_700_000_000,
        "canceled_at" => nil,
        "completed_at" => nil,
        "released_at" => nil,
        "released_subscription" => nil,
        "metadata" => %{},
        "test_clock" => nil,
        "current_phase" => %{
          "start_date" => 1_700_000_000,
          "end_date" => 1_702_678_400
        },
        "default_settings" => %{
          "application_fee_percent" => nil,
          "automatic_tax" => %{"enabled" => false, "liability" => nil, "status" => nil},
          "billing_cycle_anchor" => "automatic",
          "collection_method" => "charge_automatically",
          "default_payment_method" => nil,
          "invoice_settings" => %{"days_until_due" => nil},
          "transfer_data" => nil
        },
        "phases" => [basic_phase()]
      },
      overrides
    )
  end

  defp basic_phase do
    %{
      "start_date" => 1_700_000_000,
      "end_date" => 1_702_678_400,
      "currency" => "usd",
      "proration_behavior" => "create_prorations",
      "automatic_tax" => %{"enabled" => false, "liability" => nil, "status" => nil},
      "items" => [
        %{
          "price" => "price_test123",
          "quantity" => 1,
          "billing_thresholds" => nil,
          "discounts" => [],
          "metadata" => %{},
          "tax_rates" => []
        }
      ],
      "add_invoice_items" => [
        %{
          "price" => "price_setup_fee",
          "quantity" => 1,
          "discounts" => [],
          "metadata" => %{},
          "tax_rates" => []
        }
      ],
      "metadata" => %{}
    }
  end

  @doc "Schedule with two phases — regression guard for `phases_has?/1`."
  def with_two_phases(overrides \\ %{})

  @doc "Canceled schedule."
  def canceled(overrides \\ %{})

  @doc "Released schedule (subscription detached, schedule released)."
  def released(overrides \\ %{})
end
```

## @known_fields Proposals (Enumerated Per Struct)

### `LatticeStripe.SubscriptionSchedule` (top-level)

```elixir
@known_fields ~w[
  id object application billing_mode canceled_at completed_at created current_phase
  customer customer_account default_settings end_behavior livemode metadata phases
  released_at released_subscription status subscription test_clock
]
```

### `LatticeStripe.SubscriptionSchedule.Phase` (reused for `default_settings`)

```elixir
@known_fields ~w[
  add_invoice_items application_fee_percent automatic_tax billing_cycle_anchor
  billing_thresholds collection_method currency default_payment_method default_tax_rates
  description discounts end_date invoice_settings items iterations metadata on_behalf_of
  pause_collection prebilling proration_behavior start_date transfer_data trial_continuation
  trial_end
]
```

**Note on dual usage:** On `default_settings` decode, `start_date`, `end_date`, `iterations`, `trial_end`, `trial_continuation` will be `nil`. Document in `@moduledoc`:

> This struct is used for both `schedule.phases[]` entries AND `schedule.default_settings`. When populated from `default_settings`, the timeline fields (`start_date`, `end_date`, `iterations`, `trial_end`, `trial_continuation`) will be `nil` — these fields only apply to concrete phases. This asymmetry reflects Stripe's API shape, not a LatticeStripe modeling defect.

### `LatticeStripe.SubscriptionSchedule.CurrentPhase`

```elixir
@known_fields ~w[start_date end_date]
```

Two fields. ~20-line module.

### `LatticeStripe.SubscriptionSchedule.PhaseItem` (NEW — not SubscriptionItem)

```elixir
@known_fields ~w[
  billing_thresholds discounts metadata plan price price_data quantity tax_rates trial_data
]
```

**Intentionally absent:** `id`, `object`, `subscription`, `created`, `current_period_*` — these are all in `SubscriptionItem` but not in PhaseItem (template vs. live item). Document in `@moduledoc` per the 16-CONTEXT.md §Specifics guidance.

### `LatticeStripe.SubscriptionSchedule.AddInvoiceItem`

```elixir
@known_fields ~w[discounts metadata period price price_data quantity tax_rates]
```

## Validation Architecture

**Config check:** This project has no explicit `workflow.nyquist_validation: false` override — section is included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) + Mox 1.2 |
| Config file | `test/test_helper.exs`, `mix.exs` (`test_paths`, `elixirc_paths(:test)`) |
| Quick run command | `mix test test/lattice_stripe/subscription_schedule_test.exs --trace` |
| Full suite command | `mix test --exclude integration` (unit) / `mix test --include integration` (+ stripe-mock) |
| Integration entry | `test/integration/subscription_schedule_integration_test.exs` — `@moduletag :integration` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BILL-03 | SubscriptionSchedule struct round-trips through `from_map/1` with nested typed structs decoded | unit | `mix test test/lattice_stripe/subscription_schedule_test.exs -x` | ❌ Wave 0 |
| BILL-03 | `create/3` dispatches `POST /v1/subscription_schedules` and returns `{:ok, %SubscriptionSchedule{}}` | unit (Mox) | `mix test test/lattice_stripe/subscription_schedule_test.exs:<line>` | ❌ Wave 0 |
| BILL-03 | `retrieve/3` dispatches `GET /v1/subscription_schedules/:id` | unit (Mox) | same | ❌ Wave 0 |
| BILL-03 | `update/4` dispatches `POST /v1/subscription_schedules/:id` + runs proration guard | unit (Mox) | same | ❌ Wave 0 |
| BILL-03 | `list/3` + `stream!/3` dispatch `GET /v1/subscription_schedules` + auto-paginate | unit (Mox) | same | ❌ Wave 0 |
| BILL-03 | `cancel/4` dispatches **POST** `/v1/subscription_schedules/:id/cancel` (NOT DELETE) | unit (Mox) | same | ❌ Wave 0 |
| BILL-03 | `release/4` dispatches POST `/v1/subscription_schedules/:id/release` | unit (Mox) | same | ❌ Wave 0 |
| BILL-03 | `Billing.Guards.phases_has?/1` detects `phases[].proration_behavior` and tolerates malformed inputs | unit | `mix test test/lattice_stripe/billing/guards_test.exs -x` | ✅ (extend) |
| BILL-03 | `Billing.Guards` wired into `SubscriptionSchedule.update/4` only | unit (Mox + strict client) | `mix test test/lattice_stripe/subscription_schedule_test.exs -x` | ❌ Wave 0 |
| BILL-03 | Custom Inspect hides `customer` + `default_payment_method`; shows presence markers | unit | same | ❌ Wave 0 |
| BILL-03 | 4 nested typed structs (`Phase`, `CurrentPhase`, `PhaseItem`, `AddInvoiceItem`) round-trip via `from_map/1` | unit | `mix test test/lattice_stripe/subscription_schedule/` | ❌ Wave 0 |
| BILL-03 | Every mutation (`create`, `update`, `cancel`, `release`) forwards `opts[:idempotency_key]` to `%Request{}.opts` | unit (Mox) | same | ❌ Wave 0 |
| BILL-03 | End-to-end round-trip against stripe-mock: create → retrieve → update → cancel; create → retrieve → release | integration | `mix test --include integration test/integration/subscription_schedule_integration_test.exs` | ❌ Wave 0 |
| BILL-03 | `list/3` + `stream!/3` return paginated results against stripe-mock | integration | same | ❌ Wave 0 |
| BILL-03 | `phases[0][items][0][price_data][...]` encodes correctly (form-encoder regression guard) | integration (via stripe-mock 200/400 validation) AND unit (FormEncoder regex) | `mix test test/lattice_stripe/form_encoder_test.exs -x` | ✅ (extend) |
| BILL-03 | `update/4` with strict client + `phases[].proration_behavior` missing returns `{:error, :proration_required}` without hitting transport | unit (Mox) + integration (strict client) | same | ❌ Wave 0 |
| BILL-03 | `ExDoc` Billing group includes `SubscriptionSchedule` + 4 nested types; `mix docs` exits 0 | manual | `mix docs` | ✅ (mix.exs exists) |
| BILL-03 | `guides/subscriptions.md` extended with `## Subscription Schedules` section | manual + grep | `grep -q "Subscription Schedules" guides/subscriptions.md` | ✅ (file exists) |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/subscription_schedule_test.exs test/lattice_stripe/subscription_schedule/ test/lattice_stripe/billing/guards_test.exs --trace`
- **Per wave merge:** `mix test --exclude integration && mix credo --strict && mix format --check-formatted`
- **Phase gate (before `/gsd-verify-work`):** `mix test --include integration && mix docs`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/subscription_schedule_test.exs` — unit tests for top-level resource (covers BILL-03 CRUD + action verbs + Inspect + idempotency)
- [ ] `test/lattice_stripe/subscription_schedule/phase_test.exs` — `Phase` struct unit tests (round-trip + dual-usage nil fields)
- [ ] `test/lattice_stripe/subscription_schedule/current_phase_test.exs`
- [ ] `test/lattice_stripe/subscription_schedule/phase_item_test.exs`
- [ ] `test/lattice_stripe/subscription_schedule/add_invoice_item_test.exs`
- [ ] `test/support/fixtures/subscription_schedule.ex` — new fixture module
- [ ] `test/integration/subscription_schedule_integration_test.exs` — stripe-mock round-trip for all 6 endpoints
- [ ] `test/lattice_stripe/billing/guards_test.exs` — EXTEND with 4 new `phases[]` cases (file exists)
- [ ] `test/lattice_stripe/form_encoder_test.exs` — EXTEND with one `phases[][items][][price_data]` regression test (file exists)

Framework is already installed — ExUnit + Mox are on every wave of the project. No framework install needed.

## Security Domain

**Config check:** No explicit `security_enforcement: false` — section is included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | `Bearer sk_*` header set by `Client` (Phase 1) — no new code |
| V3 Session Management | no | Stateless HTTP — no sessions |
| V4 Access Control | yes | Authorization is Stripe's responsibility; LatticeStripe passes the caller's API key — no new logic |
| V5 Input Validation | yes | `Resource.require_param!/3` for required fields (none on SubscriptionSchedule — all pass-through); `form_encoder` escapes nested bracket notation safely; `@known_fields` + `extra` absorbs unknown Stripe fields without crashing |
| V6 Cryptography | no | No crypto in this phase — signatures are Phase 7 webhook concern |
| V7 Error Handling | yes | All errors surface via `%LatticeStripe.Error{}` — Phase 2 pattern; no new error types |
| V8 Data Protection | yes | Custom Inspect masks `customer`, `default_payment_method`, PII paths on SubscriptionSchedule (mirror Subscription) |
| V9 Communication | yes | HTTPS via Finch transport (Phase 1) — no new config |
| V12 Files | no | — |
| V13 API | yes | Every mutation forwards `opts[:idempotency_key]` to Stripe's Idempotency-Key header (STRIDE: Tampering / Replay) |

### Known Threat Patterns for Phase 16

| Threat ID | STRIDE | Component | Standard Mitigation |
|-----------|--------|-----------|---------------------|
| T-16-01 | Information Disclosure | `%SubscriptionSchedule{}` Inspect | Custom Inspect masks `customer`, `default_payment_method`; tests assert `refute inspected =~ "cus_"` |
| T-16-02 | Tampering / Replay | `create/3`, `update/4`, `cancel/4`, `release/4` | Mox tests assert `opts[:idempotency_key]` is forwarded to `%Request{}.opts` on every mutation |
| T-16-03 | Elevation of Privilege (unintended proration) | `update/4` + `Billing.Guards.phases_has?/1` | Guard wired into `update/4`; unit test covers strict client rejection for `phases[]` without `proration_behavior` |
| T-16-04 | Tampering (form encoding) | `form_encoder.ex` deepest path | Regression unit test + stripe-mock 200 serves as server-side validation |
| T-16-05 | Information Disclosure (nested Phase struct) | `%Phase{}` default Inspect (when inspected standalone) | Mask `default_payment_method` as presence-only in nested struct's Inspect impl |

**No new ASVS categories become relevant for this phase** — Phase 16 is a pure data-plane extension of Phases 14/15. Same trust boundaries, same mitigations, same test patterns.

## Open Questions for Planner (RESOLVED)

All D1–D5 decisions are locked. The planner's only real degrees of freedom are listed in 16-CONTEXT.md §Claude's Discretion and repeated here, each with its resolution:

1. **Exact `@moduledoc` wording for `Phase` struct's dual usage** — the nil-trailing-fields asymmetry. Proposed text is in the §@known_fields Proposals section above; planner may refine.
   **RESOLVED:** 16-01-PLAN.md Task 1 embeds the full `@moduledoc` verbatim in the Phase code template (see §action block for `lib/lattice_stripe/subscription_schedule/phase.ex`). Deferred further refinement to executor per 16-CONTEXT §Claude's Discretion.
2. **Whether Plan 16-01 splits at 4 nested structs + struct + CRUD = 3 tasks, or splits Task 1 into Task 1a (2 structs) + Task 1b (2 structs).** Phase 15 kept 3 nested structs as a single Task 1 in 15-01 — recommend mirroring: one task, 4 nested structs + tests in a batch.
   **RESOLVED:** 16-01-PLAN.md uses 2 tasks total — Task 1 batches all 4 nested structs + tests; Task 2 builds the top-level resource + CRUD + fixture. Mirrors Phase 15 15-01 rhythm.
3. **`guides/subscriptions.md` section placement** — where inside the existing guide to add `## Subscription Schedules`. Proposed: immediately after `## Proration`, before `## SubscriptionItem operations`, so schedule docs benefit from the proration context already established.
   **RESOLVED:** 16-03-PLAN.md owns guide updates; placement deferred to executor per 16-CONTEXT §Claude's Discretion (proposed ordering noted in 16-03 Task read_first context).
4. **Whether `SubscriptionSchedule.update/4` accepts atom-keyed `phases:` or requires string-keyed `"phases"`.** Follow existing resource convention: accept both (atom keys normalize through `FormEncoder.encode/1` which calls `to_string/1` on keys), but document string-keyed as canonical in examples.
   **RESOLVED:** 16-01-PLAN.md Task 2 inherits the pass-through pattern from `lib/lattice_stripe/subscription.ex` (via read_first + interfaces block). Both atom- and string-keyed params normalize through `FormEncoder.encode/1` — no special-casing in `update/4`. String-keyed is canonical in `@moduledoc` examples.
5. **One genuine open call for the planner:** Phase 16 `SubscriptionSchedule` struct has 19 top-level fields. Phase 15's `Subscription` had 46 and used a `# credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount` comment above `defstruct`. Phase 16's count is below the Credo default threshold (~32), so no disable comment should be needed — planner should verify via first compile.
   **RESOLVED:** 16-01-PLAN.md Task 2 action block explicitly states "Field count is 19 (below Credo's ~32 default threshold — no `credo:disable-for-next-line` needed per 16-RESEARCH.md §Open Questions item 5)." If `mix credo --strict` flags this at execution time, executor adds the disable comment inline — not a planner concern.

No LOW-confidence findings. No research blockers. No gaps requiring additional investigation before planning begins.

## Sources

### Primary (HIGH confidence)
- [Stripe — Subscription Schedule object](https://docs.stripe.com/api/subscription_schedules/object) — verified all top-level + phase + phase-item + add-invoice-item + current-phase field names
- [Stripe — Create a schedule](https://docs.stripe.com/api/subscription_schedules/create) — endpoint + mutually-exclusive param sets
- [Stripe — Update a schedule](https://docs.stripe.com/api/subscription_schedules/update) — canonical source for `proration_behavior` valid paths (top-level + `phases[]`, NOT `phases[].items[]`)
- [Stripe — Cancel a schedule](https://docs.stripe.com/api/subscription_schedules/cancel) — confirms `POST /v1/subscription_schedules/:id/cancel`
- [Stripe — Release a schedule](https://docs.stripe.com/api/subscription_schedules/release) — confirms `POST /v1/subscription_schedules/:id/release`
- Codebase-local: `lib/lattice_stripe/subscription.ex`, `lib/lattice_stripe/subscription_item.ex`, `lib/lattice_stripe/billing/guards.ex`, `lib/lattice_stripe/form_encoder.ex`, `test/lattice_stripe/form_encoder_test.exs`, `test/lattice_stripe/billing/guards_test.exs`, `test/integration/subscription_integration_test.exs`, `test/support/fixtures/subscription.ex`, `.planning/phases/15-subscriptions-subscription-items/{15-01,15-02,15-03}-PLAN.md` — all verified by Read tool

### Secondary (MEDIUM confidence)
- [stripe-mock README on GitHub](https://github.com/stripe/stripe-mock) — confirms OpenAPI-spec-driven; cross-referenced with Phase 15's integration test comment block for quirk inventory

### Tertiary (LOW confidence)
- None. All Phase 16 claims are either cited or verified locally.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | None | — | All content in this research is either [VERIFIED: codebase Read] or [CITED: docs.stripe.com]. No `[ASSUMED]` claims. |

## Metadata

**Confidence breakdown:**
- Stripe API shapes: HIGH — verified against docs.stripe.com object + update reference
- Form encoder behavior: HIGH — verified against `lib/lattice_stripe/form_encoder.ex` + existing tests
- Billing.Guards extension: HIGH — byte-for-byte mirror of existing `items_has?/1`
- Phase 15 plan template: HIGH — files read verbatim
- stripe-mock coverage: MEDIUM — README confirms OpenAPI-driven but no explicit list of covered endpoints; Phase 15's successful integration tests for all Subscription endpoints provide strong inductive evidence
- Fixture / @known_fields / Inspect: HIGH — templates exist in the codebase, direct mirror

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (Stripe API is stable; 30-day window)

## RESEARCH COMPLETE
