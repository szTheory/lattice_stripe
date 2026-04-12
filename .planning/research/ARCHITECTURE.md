# Architecture Research: v2.0 Billing + Connect Integration

**Project:** lattice_stripe
**Milestone:** v2.0 (Billing + Connect)
**Research mode:** Project — integration-fit for new resources against existing v1 architecture
**Researched:** 2026-04-11
**Overall confidence:** HIGH (all claims grounded in the actual v1 code on disk, file+line refs below)

---

## Executive Summary

The v1 foundation is **complete and load-bearing for v2**. Every new Billing and Connect resource can be built by copy-pasting the existing `PaymentIntent` / `Checkout.Session` template against a new path, with **zero** additions to `Client`, `Transport`, `Request`, `Response`, `Error`, `RetryStrategy`, or `Json`. The three "new modules" the v2 plan proposes — `LatticeStripe.Search`, `LatticeStripe.EventType`, `LatticeStripe.Billing.ProrationBehavior` — need scope adjustment:

1. **`LatticeStripe.Search` is already built.** `LatticeStripe.List.stream!/2` transparently handles both cursor (`starting_after`/`ending_before`) and search (`next_page`) pagination — see `lib/lattice_stripe/list.ex:245-275`. The plan's proposed sibling module would duplicate existing code. A thin `Search` facade (documentation + type alias) is fine, but the engine already exists.
2. **`LatticeStripe.EventType` should be a plain constants module** (string module attributes + accessor functions + category lists). Behaviour/macro alternatives add ceremony with no payoff — Stripe event strings are static data.
3. **`LatticeStripe.Billing.ProrationBehavior` is a new pattern** — no enum validator exists in v1 today. It's the first such module, so it sets the precedent. Recommend placing it at `LatticeStripe.Billing.ProrationBehavior` (domain-scoped, not in `Resource`).

The Connect `stripe_account` header plumbing is already proven and correct (`lib/lattice_stripe/client.ex:175, 422-424`) — every Connect-flavored resource gets this for free via per-request `opts`.

**Build order:** The plan's proposed Phase 12→19 sequence is nearly right. The one non-obvious move worth considering: **pull TestClocks forward to Phase 13** (which the plan already does). The rest of the Billing ordering follows the Stripe data graph (Product → Price → Invoice → Subscription → Schedule), and Connect is an independent branch that can run in parallel or after Billing depending on execution capacity.

---

## Existing Architecture (v1 — Load-Bearing, Do Not Touch)

| Component | File | Role for v2 |
|---|---|---|
| `LatticeStripe.Client` | `lib/lattice_stripe/client.ex` | Sole HTTP entry point. Handles api_key, api_version, `stripe_account`, idempotency key, retries, telemetry, expand. New resources call `Client.request(client, %Request{})` — nothing else. |
| `LatticeStripe.Request` | `lib/lattice_stripe/request.ex` | Pure data struct — method, path, params, opts. New resources build these. |
| `LatticeStripe.Response` | `lib/lattice_stripe/response.ex` | Wraps status/headers/request_id/data. Data is a map (singular) or `%List{}` (list/search). |
| `LatticeStripe.List` | `lib/lattice_stripe/list.ex` | Paginated envelope **plus** `stream!/2` state machine that auto-handles forward cursor, backward cursor, **and search `next_page` pagination** (see `list.ex:245-275`). |
| `LatticeStripe.Resource` | `lib/lattice_stripe/resource.ex` | Shared helpers: `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3`. Every v1 resource uses these. |
| `LatticeStripe.Error` | `lib/lattice_stripe/error.ex` | 10-field struct with pattern-matchable `:type`. New resources return it unchanged — zero new error types needed. |
| `LatticeStripe.Telemetry` | `lib/lattice_stripe/telemetry.ex` | Wraps every `Client.request/2` in a span. New resources get telemetry for free. |
| `LatticeStripe.Webhook` / `Webhook.Plug` | `lib/lattice_stripe/webhook.ex`, `lib/lattice_stripe/webhook/plug.ex` | Event verification. New Billing/Connect event types flow through unchanged — the webhook layer is event-type agnostic. |

**Design invariant (v1 → v2):** no new behaviours, no new transport concerns, no client struct additions. The foundation is frozen. v2 is pure resource-surface work plus three small cross-cutting helpers.

---

## 1. Resource Module Shape — Confirmed Fit for Billing

### v1 template (from `payment_intent.ex`)

Every v1 resource follows this exact shape:

```
defmodule LatticeStripe.Xxx do
  @known_fields ~w[id object ...]    # for Map.drop extra
  defstruct [...fields..., object: "xxx", extra: %{}]
  @type t :: %__MODULE__{...}

  # CRUD (each ~4 lines of pipe)
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/xxx", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end
  # retrieve / update / delete / list / stream! / search / search_stream!

  # Bang variants layered on top via Resource.unwrap_bang!
  def create!(...), do: create(...) |> Resource.unwrap_bang!()

  def from_map(map), do: %__MODULE__{...fields from map..., extra: Map.drop(map, @known_fields)}
end

defimpl Inspect, for: LatticeStripe.Xxx do
  # Hide PII and sensitive fields
end
```

### Does Subscription need to deviate?

**No.** Subscription has more CRUD surface (create/retrieve/update/cancel/list/search + pause/resume lifecycle actions), but so does `PaymentIntent` (create/retrieve/update/confirm/capture/cancel/list/search — see `payment_intent.ex:214-549`). The template scales to 6-8 action verbs without strain. Subscription adds:

- `pause/3` → `POST /v1/subscriptions/:id` with `pause_collection` param (not a sub-path)
- `resume/3` → `POST /v1/subscriptions/:id/resume` (sub-path, identical shape to `capture/4`)
- `cancel/3` → `DELETE /v1/subscriptions/:id` with query/body params — this is the **one** v2 wrinkle: the cancel action uses `DELETE` with a body, not `POST`. Inspect `payment_intent.ex:357` (`cancel/4` is POST to `/cancel` sub-path) — Subscription diverges here. Worth a comment in the resource file, but no shared helper needed.

### Invoice `upcoming/2` — special path shape

`GET /v1/invoices/upcoming` is not a singular-by-id retrieve — there is no upcoming invoice ID. It's a "compute the hypothetical next invoice for this customer/subscription" query. Use a plain `retrieve/2`-style function, but take params instead of an id:

```elixir
def upcoming(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :get, path: "/v1/invoices/upcoming", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

No new helper needed. Template fits.

### PII hiding for Billing

Subscription: hide nothing structural, but the `default_payment_method`, `default_source`, and `latest_invoice.payment_intent.client_secret` sub-fields are sensitive — since these are nested maps in `extra`/typed fields, the top-level Inspect can still show `id/status/customer/items` as in `payment_intent.ex:620-644`.

Invoice: `customer_email`, `customer_name`, `customer_address`, `customer_shipping`, `account_name` are PII → hide in Inspect.

Coupon/PromotionCode/Product/Price/Subscription Schedule: no PII → standard Inspect is fine.

Connect Account: **heavy PII** — business_profile, company, individual (SSN/DOB), tos_acceptance (IP address), external_accounts. Must define a restrictive custom Inspect showing only `id/object/type/charges_enabled/payouts_enabled/details_submitted`.

AccountLink, LoginLink: `url` field is a short-lived credential — hide in Inspect (or show only prefix). Similar rationale to `client_secret` hiding on PaymentIntent.

### Verdict — Resource shape

**The v1 template works unchanged for every v2 resource.** No new `Resource` helpers are needed. Every Billing+Connect resource is a 300-600 line module that follows the exact same skeleton.

---

## 2. Nested Resources — How v1 Handles Children

### v1 pattern (InvoiceLineItem analog: `Checkout.LineItem`)

`lib/lattice_stripe/checkout/line_item.ex` is a read-only struct module with:

- `defstruct` + `@type t` + `from_map/1`
- No CRUD functions of its own — parent (`Checkout.Session`) exposes `list_line_items/4` and `stream_line_items!/4` that build the `/v1/checkout/sessions/:id/line_items` request and unwrap into `%LineItem{}` via `Resource.unwrap_list(&LineItem.from_map/1)` (see `session.ex:479-519`).

### Recommendation for Billing nested resources

**Follow the exact same pattern.**

| Child | Module path | Parent exposes |
|---|---|---|
| InvoiceLineItem | `lib/lattice_stripe/invoice/line_item.ex` → `LatticeStripe.Invoice.LineItem` | `Invoice.list_lines/4`, `Invoice.stream_lines!/4`, `Invoice.list_upcoming_lines/4` |
| SubscriptionItem | `lib/lattice_stripe/subscription/item.ex` → `LatticeStripe.Subscription.Item` | `Subscription.list_items/4`, `Subscription.stream_items!/4`, plus `create_item/4`, `update_item/5`, `delete_item/4` because `/v1/subscription_items` is writable (unlike Invoice lines which are read-only) |
| BillingPortal.Session (Tier 3) | `lib/lattice_stripe/billing_portal/session.ex` → `LatticeStripe.BillingPortal.Session` | Top-level module (not nested under BillingPortal.Configuration) — matches the way Checkout.Session is top-level under the Checkout namespace |

### Why nested, not top-level?

Two reasons, both backed by v1 precedent:

1. **Namespace mirrors Stripe's URL structure.** Checkout.Session → `/v1/checkout/sessions`; Invoice.LineItem is logically child of Invoice. Users discovering the module via ExDoc's "Billing" group will find `Invoice` and expect `Invoice.LineItem` next to it.
2. **List/stream helpers belong on the parent.** Users naturally write `Invoice.list_lines(client, invoice_id)` not `InvoiceLineItem.list(client, invoice_id)` — the Checkout.Session precedent confirms this ergonomics choice.

**SubscriptionItem is the one exception where full CRUD lives on the child:** Stripe's API treats `/v1/subscription_items` as a first-class collection (you create items on existing subscriptions via `POST /v1/subscription_items`), so `Subscription.Item` needs create/retrieve/update/delete/list in addition to the parent-helper `list_items`. Both exist: the parent helper calls the nested list with the scoped `subscription` param pre-filled.

---

## 3. Connect Header Plumbing — Already End-to-End

Tracing `stripe_account` through v1:

1. **Client struct** — `stripe_account` is a top-level field with default `nil` (`client.ex:52-64`).
2. **Per-request override** — `Client.request/2` at line 175 extracts `effective_stripe_account = Keyword.get(req.opts, :stripe_account, client.stripe_account)`, so per-request opts win, client falls back.
3. **Header emission** — `build_headers/5` at line 387 passes it to `maybe_add_stripe_account/2` at line 422, which prepends `{"stripe-account", stripe_account}` when non-nil.
4. **Retry loop** — headers are built once per transport request (before the retry loop), so retries re-use the same `stripe-account` header. Correct.
5. **Pagination** — `List.stream!` re-uses `_opts` when building next-page requests (`list.ex:266`), so `stripe_account` threads through auto-pagination too. The one cleanup: `list.ex:267` strips only `:idempotency_key` from opts — `:stripe_account` correctly persists.

**Verdict:** Connect plumbing is correct and already exercised in v1 (verified in the Checkout integration tests). Phase 17 (Account/AccountLink/LoginLink) and Phase 18 (Transfer/Payout/Balance/BalanceTransaction) add **zero** new transport work. Connect resources just:

- Use `Client.request/2` normally
- Pass `opts: [stripe_account: "acct_xxx"]` when called against a connected account (or rely on client-level `stripe_account`)
- That's it.

One v2 documentation gap worth flagging: the README/guides don't show a Connect usage example end-to-end. Phase 17 should include a dedicated `guides/connect.md` that shows all three patterns: (1) client-level `stripe_account`, (2) per-request `opts[:stripe_account]`, (3) direct-charge (no stripe_account — platform uses its own key with `transfer_data`).

---

## 4. Search Endpoint Architecture — Already Built, Don't Duplicate

### The plan's assumption (incorrect)

The plan says "`LatticeStripe.List.stream!` assumes cursor pagination (starting_after / ending_before). Stripe search endpoints use page / next_page." That was true in an early draft of v1, but **v1 as shipped handles both transparently**.

### What v1 actually does (`list.ex:245-275`)

```elixir
defp build_next_page_request(%__MODULE__{} = list) do
  base_params = Map.drop(list._params, ["starting_after", "ending_before", "page"])

  pagination_params =
    cond do
      # Search pagination (D-16): use page token from response
      list.object == "search_result" && list.next_page ->
        %{"page" => list.next_page}

      # Backward cursor pagination (D-06): use first item ID from original page
      Map.has_key?(list._params, "ending_before") && list._first_id != nil ->
        %{"ending_before" => list._first_id}

      # Forward cursor pagination: use last item ID from original page
      list._last_id != nil ->
        %{"starting_after" => list._last_id}
```

The `from_json/3` function at `list.ex:115-131` reads `decoded["object"]` — if Stripe returned `"search_result"`, the list struct records that and `build_next_page_request` picks the `page` branch. **This is already in production and tested in v1.** Every `search_stream!` on every v1 resource (Customer, PaymentIntent, Checkout.Session) works via this branch.

### How Stripe's own SDKs model this

- **stripe-ruby** (`Stripe::SearchResultObject`): subclass of `ListObject`. Separate class but same `auto_paging_each` method. Differences are polymorphic, not structural.
- **stripe-node** (`autoPagingEach` on `SearchResult` vs `ApiList`): single iterator shape, branch on `object` type internally.

Both model search as **a list variant, not a separate primitive**. v1 already does this correctly.

### Recommendation for v2

**Option A (recommended): Document, don't create a new module.**

- Add a `LatticeStripe.Search` module as a **thin facade** — zero runtime code. It is just a `@moduledoc` describing the search pagination difference and linking to `List.stream!/2`. This satisfies the plan's discoverability intent (users searching the docs for "Search" find something) without adding a redundant engine.
- Alternative: skip the module entirely and add a "Search pagination" section to `LatticeStripe.List` `@moduledoc`. Less discoverable, simpler.

**Option B (not recommended): Split `Search` into its own module with its own `stream!/3`.**

- Would require duplicating the state machine in `List.stream!/2`.
- Would split tests into two code paths.
- Would require users to know which module to import based on whether they're listing vs searching — exactly the ergonomics loss the v1 design avoids.

**Decision:** Go with Option A as a facade-only module. The plan's "add `LatticeStripe.Search.stream!/3`" line item should be rewritten to "add `LatticeStripe.Search` documentation module that points to existing `List.stream!/2`".

### Search struct type?

The plan asks "should it be a new struct type?" — **no**. v1 already distinguishes `%List{object: "list"}` vs `%List{object: "search_result"}` via the `object` field. A separate struct would break pattern-matching in user code that doesn't care about the difference (`%List{data: items}` works for both today).

---

## 5. EventType Catalog — Plain Constants Module

### What exists today

v1's `Webhook` module has **no event-type catalog.** Users pattern-match on raw strings:

```elixir
case event.type do
  "payment_intent.succeeded" -> ...
  "charge.refunded" -> ...
end
```

This is fine but stringly-typed. No constants, no discovery surface, no docs enumeration.

### Alternatives considered

#### Option A — Plain constants module (RECOMMENDED)

```elixir
defmodule LatticeStripe.EventType do
  @moduledoc "Catalog of Stripe webhook event types. ..."

  @payment_intent_succeeded "payment_intent.succeeded"
  @customer_subscription_created "customer.subscription.created"
  # ... exhaustive list

  def payment_intent_succeeded, do: @payment_intent_succeeded
  def customer_subscription_created, do: @customer_subscription_created

  @payments_events [
    @payment_intent_succeeded,
    # ...
  ]
  @billing_events [
    @customer_subscription_created,
    # ...
  ]
  @connect_events [...]

  def payments_events, do: @payments_events
  def billing_events, do: @billing_events
  def connect_events, do: @connect_events
  def all, do: @payments_events ++ @billing_events ++ @connect_events
end
```

**Pros:**
- Zero abstraction — it is literally a list of strings with names.
- Pattern-matchable: `t when t == LatticeStripe.EventType.payment_intent_succeeded() -> ...` (function calls in guards need `when` + `==`, not direct pattern match, but import fixes that).
- With `import LatticeStripe.EventType`, users write `case event.type do; t when t == customer_subscription_created() -> ...; end` — a bit verbose but works.
- Best alternative: use them to build `defp handle("customer.subscription.created", event), do: ...` dispatch — the EventType module is a documentation/fixture catalog rather than a runtime matcher. This is how Stripe's own ruby gem ships `Stripe::Event::Types` constants.
- Category lists (`billing_events/0`, `payments_events/0`) enable tests like `assert Enum.all?(observed, &(&1 in EventType.all()))`.
- Auto-verification via Phase 19 "milestone smoke test" — generate the catalog from the OpenAPI spec and diff against the hand-written constants.

**Cons:**
- Verbose. ~100 `@attribute + def` pairs. Unavoidable with this approach.
- Still string-based at runtime (not atoms) — but converting to atoms would be dangerous because Stripe adds new event types regularly and atom exhaustion is a real risk.

#### Option B — Behaviour

A `LatticeStripe.EventType` behaviour with `@callback handle(event_type :: String.t(), event :: Event.t())` — users `use` it and implement `handle/2`.

**Rejected:** This is a dispatcher, not a catalog. It forces all webhook handlers into one module (or forces multiple modules per category). Users with 3 webhook handlers and 5 event types shouldn't have to adopt a framework. The v1 philosophy ("processes only when truly needed" per `PROJECT.md`) extends to "abstractions only when truly needed".

#### Option C — Macro (`LatticeStripe.EventType.match/2`)

A macro that expands to `case event.type do; ...; end` with compile-time event-name validation.

**Rejected:** Macros are opaque at debug time. The 15% syntactic sugar isn't worth the "what does this expand to?" tax on library consumers. v1 deliberately avoids macros in favor of plain functions.

#### Option D — Plain string module attributes only (no accessor functions)

Just `@payment_intent_succeeded "payment_intent.succeeded"` — no `def`. Users can't access them from outside the module because module attributes are compile-time only.

**Rejected:** Defeats the purpose — the catalog must be callable at runtime for tests, dispatch, and fixtures.

### Decision

**Option A: plain constants module with `@attr + def` pairs per event + category list functions.** Matches Stripe's own ruby gem, ships with zero new abstractions, and gives downstream libraries (especially Accrue) a canonical catalog without forcing them into a dispatch pattern.

**Scope:** Exhaustive across all current Stripe event types — Payments, Billing, Connect, plus Identity/Dispute/Charge/Checkout that already emit events used by v1 webhooks. Phase 19 adds a test that diffs the constants against a scraped OpenAPI event list and fails CI if Stripe adds new types. This auto-pins the catalog to reality.

---

## 6. ProrationBehavior Validator — Where Does It Live?

### v1 has no enum validator precedent

Grep for `validate|enum|allowed_values` in `lib/lattice_stripe` yields only `Config` (NimbleOptions schema) and `Resource.require_param!` (presence check, no value validation). The v1 approach to enum-like params is: **let Stripe validate and return an `:invalid_request_error`**. That's fine for most enums (currency, capture_method, cancellation_reason) but wrong for `proration_behavior` because the whole point is to **fail before the network call** so the caller can't silently inherit Stripe's default.

This means v2 introduces a new pattern: the client-side enum validator. Where it lives sets precedent for any future `__Behavior` helper (e.g., `PaymentMethodType`, `CaptureMethod`).

### Options

#### Option A — `LatticeStripe.Billing.ProrationBehavior` (domain-scoped module)

```elixir
defmodule LatticeStripe.Billing.ProrationBehavior do
  @values ~w[create_prorations always_invoice none]
  def valid?(value), do: value in @values
  def validate!(value) do
    unless valid?(value) do
      raise ArgumentError, "proration_behavior must be one of #{inspect(@values)}, got: #{inspect(value)}"
    end
    :ok
  end
  def values, do: @values
end
```

Called from `Subscription.update/3`, `Subscription.cancel/3`, `SubscriptionSchedule.update/3`, `Invoice.upcoming/2`:

```elixir
def update(%Client{} = client, id, params, opts \\ []) do
  if client.require_explicit_proration or Map.has_key?(params, "proration_behavior") do
    LatticeStripe.Billing.ProrationBehavior.validate!(params["proration_behavior"])
  end
  # ... build request
end
```

**Pros:** Domain-scoped, discoverable via ExDoc "Billing" group, sets a clean precedent (`LatticeStripe.Billing.CollectionMethod`, `LatticeStripe.Payments.CaptureMethod`, etc. can follow). Doesn't pollute `Resource` with domain knowledge.

**Cons:** Tiny module (20 lines). Some reviewers will ask "why isn't this just a constant?".

#### Option B — Helper function in `LatticeStripe.Billing` (umbrella module)

A `LatticeStripe.Billing` module with `validate_proration_behavior!/1` as one of many utility functions.

**Rejected:** Creates a catch-all module that will grow unboundedly. v1's philosophy is one module per concept — `Resource` is the only cross-cutting helper and its scope is deliberately narrow (unwrap + require_param). A `Billing` umbrella breaks that discipline.

#### Option C — Function in `LatticeStripe.Resource`

Extend `Resource` with `require_enum_value!/3`.

**Rejected:** `Resource` is a primitive-helper module — it doesn't know about domain values. Adding an enum-value check is fine, but hard-coding proration_behavior values in `Resource` would be wrong. A generic `require_enum_value!(params, key, allowed_list, message)` is tempting but Option A's domain module is still clearer because it centralizes the *list* of valid values somewhere named after what they are.

A hybrid that works: generic `Resource.require_enum_value!/4` exists as a helper **and** `LatticeStripe.Billing.ProrationBehavior` uses it:

```elixir
def validate!(value, params \\ nil) do
  Resource.require_enum_value!(params || %{"proration_behavior" => value}, "proration_behavior", @values, "...")
end
```

Too clever. Pick one. Go with Option A as the clean path.

### Decision

**Option A: `LatticeStripe.Billing.ProrationBehavior` as a standalone module** at `lib/lattice_stripe/billing/proration_behavior.ex`. Functions: `values/0`, `valid?/1`, `validate!/1`. Used by Subscription / SubscriptionSchedule / Invoice (upcoming proration preview). This establishes a "domain enum module" pattern future phases can follow.

**Client flag:** Add `require_explicit_proration: false` to the `Client` struct (`client.ex:52`). When `true`, the Billing resources raise if `proration_behavior` is *missing from params* at call time (not just if it's invalid). This is the one small `Client` struct addition v2 needs — mentioned because it does modify v1 code, but it's additive and default-false.

---

## 7. TestClock Integration — New Test Support Layer

TestClock is Stripe-side infrastructure: POST `/v1/test_helpers/test_clocks` creates a simulated clock, `/v1/test_helpers/test_clocks/:id/advance` advances it, and any Customer / Subscription / Invoice created with `test_clock: "clock_xxx"` is tied to that clock's time instead of wall clock.

### What v1 has

Nothing. `test/support/` currently has `StripeMockCase`, `StripeMockHelper`, and `MoxHelper` (verified by elixirc_paths at `mix.exs:129`). No time-travel utilities.

### What v2 needs

1. **`LatticeStripe.BillingTestClock` (ships in `lib/`)** — plain resource module following the v1 template. CRUD + `advance/3` lifecycle action. Ships in the hex package so downstream users (including Accrue) can write their own integration tests against Stripe using test clocks.

2. **`LatticeStripe.Testing.TestClock` (ships in `lib/`, not `test/support/`)** — high-level helper similar to `LatticeStripe.Testing` (which already ships in `lib/` — see `testing.ex:1-46` where the moduledoc explicitly says "This module ships in `lib/` (not `test/support/`) so downstream users can import it without configuring custom `elixirc_paths`"). Offers:
   - `with_test_clock/3` — creates a clock, runs a block, deletes the clock on exit (bang-raising on cleanup failure since leftover clocks cost nothing but clutter a test account).
   - `advance_to/3` — advance a clock to a relative offset (`{:hours, 24}`, `{:days, 30}`) with assertion helpers.
   - `build_subscription/3` — shortcut that creates a Customer + Subscription bound to a test clock with sensible test defaults.

3. **`test/support/billing_case.ex` (internal only)** — an ExUnit `CaseTemplate` used by the lattice_stripe test suite itself for Phases 14-16 integration tests. Wraps `StripeMockCase` with `setup` that creates a fresh test clock per test and tears it down in `on_exit`. Do NOT ship this in `lib/` — it's scaffold for lattice_stripe's own tests, not downstream API.

### Precedent check

`LatticeStripe.Testing` already exists in `lib/` (not `test/support/`) and is grouped in the `"Telemetry & Testing"` ExDoc group (`mix.exs:65-68`). `LatticeStripe.Testing.TestClock` slots under the same umbrella. **This is the right place** — follows v1 precedent and doesn't require downstream users to add anything to their `elixirc_paths`.

### Phase 13 scope (TestClocks pulled forward)

The plan already pulls TestClocks to Phase 13 (before Invoices in Phase 14) so Phases 14-16 can use time-travel in their integration tests. **Confirmed correct.** The ordering is:

1. Phase 13: ship `LatticeStripe.BillingTestClock` + `LatticeStripe.Testing.TestClock` helpers + `test/support/billing_case.ex`.
2. Phases 14-16: use `BillingCase` + `with_test_clock/3` in every Invoice/Subscription/Schedule integration test that exercises time-dependent behavior (trial expiry, period rollover, past_due transition).

stripe-mock **does** support test clocks (it stubs the endpoints), so the full test-clock flow can run in CI against stripe-mock — no real Stripe calls needed for the default CI path.

---

## 8. ExDoc Module Grouping for v2

### Current v1 groups (`mix.exs:40-80`)

- **Core**: LatticeStripe, Client, Config, Error, Response, List
- **Payments**: PaymentIntent, Customer, PaymentMethod, SetupIntent, Refund
- **Checkout**: Checkout.Session, Checkout.LineItem
- **Webhooks**: Webhook, Webhook.Plug, Event
- **Telemetry & Testing**: Telemetry, Testing
- **Internals**: Transport, Transport.Finch, Json, Json.Jason, RetryStrategy, RetryStrategy.Default, FormEncoder, Request, Resource

### Proposed v2 groups (additive)

Keep all v1 groups **unchanged**. Add:

```elixir
Billing: [
  LatticeStripe.Product,
  LatticeStripe.Price,
  LatticeStripe.Coupon,
  LatticeStripe.PromotionCode,
  LatticeStripe.Invoice,
  LatticeStripe.Invoice.LineItem,
  LatticeStripe.Subscription,
  LatticeStripe.Subscription.Item,
  LatticeStripe.SubscriptionSchedule,
  LatticeStripe.BillingTestClock,
  LatticeStripe.Billing.ProrationBehavior
],
Connect: [
  LatticeStripe.Account,
  LatticeStripe.AccountLink,
  LatticeStripe.LoginLink,
  LatticeStripe.Transfer,
  LatticeStripe.Payout,
  LatticeStripe.Balance,
  LatticeStripe.BalanceTransaction
],
"Cross-Cutting": [
  LatticeStripe.EventType,
  LatticeStripe.Search  # thin facade module, see §4
],
"Telemetry & Testing": [
  LatticeStripe.Telemetry,
  LatticeStripe.Testing,
  LatticeStripe.Testing.TestClock   # new
]
```

**Notes:**
- `LatticeStripe.Billing.ProrationBehavior` lives in the Billing group alongside the resources that use it — users won't expect to find it in Internals.
- `BillingPortal.Session` / `BillingPortal.Configuration` (Tier 3, post-v0.3) will later land in a new `"Billing Portal"` group or folded into `Billing` — decide during Phase 12 of the Tier 3 milestone.
- `CreditNote`, `TaxRate`, `TaxId`, `Billing.Meter*`, `Quote` (Tiers 3-5) are post-v0.3 and out of this milestone's ExDoc concern.

### One subtlety: `LatticeStripe.Search` placement

Since Search is a thin facade (no runtime code, just docs pointing to `List.stream!/2`), an alternative placement is directly in **Core** next to `List`. Either works. Recommendation: put it in `"Cross-Cutting"` so users exploring "what's new in v2" see it; the @moduledoc can link prominently to `LatticeStripe.List`.

---

## 9. Phase Dependency Order

### Stripe data-model dependencies

Billing:
```
Product ────► Price ────► Subscription ────► Invoice ────► InvoiceLineItem
                                    │            │
                                    ▼            ▼
                               Subscription  Invoice.upcoming
                               Schedule      (depends on Subscription
                                              to preview proration)
Coupon ────► PromotionCode
```

Connect (independent sibling branch — depends only on `Client.stripe_account` plumbing):
```
Account ────► AccountLink
        ────► LoginLink
        ────► Transfer ────► Payout
              Balance, BalanceTransaction (account-scoped reads)
```

### Key observations

1. **Invoice is technically queryable without Subscription** (you can create and finalize manual invoices with no subscription), but Invoice's most important feature (`upcoming/2` proration preview) **requires a subscription to preview against**. So Invoice in pure form comes before Subscription, but Invoice's *full* feature surface isn't tested until Subscription lands.
2. **Subscription** requires Price (for line items), requires Invoice (for `latest_invoice` typed field), and is itself the parent of SubscriptionSchedule.
3. **SubscriptionSchedule** requires Subscription and Price but is otherwise standalone.
4. **TestClocks** are infrastructure — they must precede anything that benefits from time-travel tests. Pull forward to Phase 13 (before Invoices).
5. **Connect** has no ordering dependency on Billing. It's an independent branch that can ship in parallel.
6. **Cross-cutting helpers** (EventType, Search facade, ProrationBehavior) should ship **last** (Phase 19) so they can observe the actual event types and validation needs that emerged during Phases 12-18 rather than being guessed up front.

### Proposed build orders (three alternatives)

---

#### Order A — Plan's proposed order (RECOMMENDED)

| Phase | Work | Why here |
|---|---|---|
| 12 | Product, Price, Coupon, PromotionCode | Standalone, no dependencies. Fast wins, establish v2 template. |
| 13 | BillingTestClock + `Testing.TestClock` helper + `BillingCase` | Pull forward so Phases 14-16 can use time-travel. Stripe-mock supports test clocks. |
| 14 | Invoice + Invoice.LineItem + `upcoming/2` | Needs Price (for line items). Tests use test clocks for period simulation. |
| 15 | Subscription + Subscription.Item + lifecycle actions | Needs Price and Invoice. Uses test clocks for trial/past_due/cancel_at_period_end tests. |
| 16 | SubscriptionSchedule | Needs Subscription. Optional v0.3.0-rc1 release here to unblock downstream consumers. |
| 17 | Connect: Account, AccountLink, LoginLink | Proves `stripe_account` header flow against a fresh resource branch. |
| 18 | Connect: Transfer, Payout, Balance, BalanceTransaction | Builds on Phase 17's plumbing proof. |
| 19 | `EventType` catalog + `Search` facade module + `ProrationBehavior` validator + `require_explicit_proration` client flag + Billing guide + Connect guide + milestone smoke test | Cross-cutting helpers informed by actual usage in Phases 12-18. |

**Tradeoffs:**
- **Pro:** Strictly topological — each phase builds only on what's shipped. Testing layer arrives early enough to matter.
- **Pro:** Phase 16 is a clean release boundary for v0.3.0-rc1 (Billing done, Connect not yet).
- **Pro:** Phase 19's cross-cutting work benefits from having observed what Phases 12-18 actually needed.
- **Con:** Connect work is delayed until Phase 17 even though it has no Billing dependency — if two devs could parallelize, Connect could start earlier. But for a single-dev sequential workflow (which this project is), Order A is correct.

**Caveat on Phase 19 ordering:** `ProrationBehavior` is *used by* Phase 15 (Subscription) and Phase 16 (SubscriptionSchedule). If strictly deferred to Phase 19, Phases 15-16 would ship without the validator and then retroactively gain it. Better plan: ship `ProrationBehavior` as a sub-task of Phase 15 (when Subscription first needs it), and leave Phase 19 to handle `EventType`, `Search` facade, guides, and smoke test. This keeps Phase 15 self-contained while still deferring the purely cross-cutting helpers to the end.

---

#### Order B — Connect-First (build Connect before Billing)

| Phase | Work |
|---|---|
| 12 | Connect: Account, AccountLink, LoginLink |
| 13 | Connect: Transfer, Payout, Balance, BalanceTransaction |
| 14 | Product, Price, Coupon, PromotionCode |
| 15 | BillingTestClock + testing helpers |
| 16 | Invoice + Invoice.LineItem |
| 17 | Subscription + Subscription.Item |
| 18 | SubscriptionSchedule |
| 19 | Cross-cutting |

**Tradeoffs:**
- **Pro:** Proves the `stripe_account` header end-to-end immediately, catching any header-plumbing bugs before the bulk of the milestone lands.
- **Pro:** Connect is simpler (fewer cross-resource dependencies) — might be a faster warm-up to v2.
- **Con:** The downstream consumer (Accrue) wants Billing first — Order B blocks Accrue's Phase 2 for longer.
- **Con:** No early v0.3.0-rc1 release candidate — Billing lands at Phase 18, too late for a pre-release cut.
- **Con:** TestClocks delayed to Phase 15 — Phases 16-17 tests can't use time-travel until mid-milestone.

**Verdict:** Worse than Order A for this project specifically. The downstream-consumer argument is decisive.

---

#### Order C — Interleaved (Billing and Connect in parallel tracks)

| Phase | Billing track | Connect track |
|---|---|---|
| 12 | Product, Price, Coupon, PromoCode | — |
| 13 | BillingTestClock + helpers | Account, AccountLink, LoginLink |
| 14 | Invoice + LineItem | — |
| 15 | Subscription + Item | Transfer, Payout, Balance, BalanceTransaction |
| 16 | SubscriptionSchedule | — |
| 17 | — | — (absorbed into 13/15) |
| 18 | — | — |
| 19 | Cross-cutting + all guides + smoke test |

**Tradeoffs:**
- **Pro:** Two tracks maximize parallelism if there are two executors.
- **Pro:** Milestone finishes one phase earlier (18 vs 19 for main work).
- **Con:** Single-executor workflow — phases double in size, making review and rollback harder.
- **Con:** Breaks the one-phase-one-concern discipline v1 used religiously (each v1 phase had a single focused theme).
- **Con:** No natural v0.3.0-rc1 boundary.

**Verdict:** Only makes sense if this milestone has two concurrent executors. For the single-dev sequential workflow, Order A's discipline beats Order C's parallelism.

---

### Recommendation

**Adopt Order A (the plan's proposed order), with the Phase 15 caveat:** ship `ProrationBehavior` alongside Subscription in Phase 15 (not deferred to 19). It's topologically correct, matches v1's phase-discipline pattern, produces a clean v0.3.0-rc1 release boundary at Phase 16, and gives Phase 19 the benefit of hindsight for the remaining cross-cutting helpers (`EventType`, `Search` facade, guides, smoke test).

The one specific challenge to the plan: **the "`LatticeStripe.Search.stream!/3`" work item in Phase 19 should be rewritten as "`LatticeStripe.Search` facade module (documentation-only, pointing to `List.stream!/2`)"** — see §4. This is a scope reduction, not a scope change — it means Phase 19 has less code to write and can instead invest that time in the EventType catalog auto-verification test.

---

## 10. Summary of New vs Modified Components

### New modules (resource)

Billing:
- `LatticeStripe.Product`
- `LatticeStripe.Price`
- `LatticeStripe.Coupon`
- `LatticeStripe.PromotionCode`
- `LatticeStripe.Invoice` + `LatticeStripe.Invoice.LineItem`
- `LatticeStripe.Subscription` + `LatticeStripe.Subscription.Item`
- `LatticeStripe.SubscriptionSchedule`
- `LatticeStripe.BillingTestClock`

Connect:
- `LatticeStripe.Account`
- `LatticeStripe.AccountLink`
- `LatticeStripe.LoginLink`
- `LatticeStripe.Transfer`
- `LatticeStripe.Payout`
- `LatticeStripe.Balance`
- `LatticeStripe.BalanceTransaction`

### New modules (cross-cutting)

- `LatticeStripe.EventType` — constants + category list functions
- `LatticeStripe.Billing.ProrationBehavior` — enum validator
- `LatticeStripe.Search` — thin facade/docs pointing to `List.stream!/2`
- `LatticeStripe.Testing.TestClock` — high-level test helpers (ships in `lib/`)
- `test/support/billing_case.ex` — internal ExUnit case template (not shipped)

### Modified files

| File | Change | Scope |
|---|---|---|
| `lib/lattice_stripe/client.ex:52-64` | Add `require_explicit_proration: false` to `defstruct` | Additive, default false, no behavior change for existing code |
| `lib/lattice_stripe/config.ex` | Add `require_explicit_proration` to NimbleOptions schema (boolean, default false) | Additive |
| `mix.exs:40-80` | Add Billing, Connect, Cross-Cutting groups | Documentation-only, no runtime impact |
| `guides/*.md` | Add `billing.md`, `connect.md`, update `webhooks.md` with EventType example | New content |
| `CHANGELOG.md` | Phase-transition entries | Auto-handled by Release Please |

### Untouched (v1 load-bearing, frozen)

- `LatticeStripe.Transport` / `Transport.Finch`
- `LatticeStripe.Request`
- `LatticeStripe.Response`
- `LatticeStripe.Error` (no new error types — Stripe's existing `:type` values cover Billing/Connect)
- `LatticeStripe.RetryStrategy` / `RetryStrategy.Default`
- `LatticeStripe.Json` / `Json.Jason`
- `LatticeStripe.FormEncoder`
- `LatticeStripe.List` — **including search pagination, which already works**
- `LatticeStripe.Resource` — no new helpers needed
- `LatticeStripe.Webhook` / `Webhook.Plug` — event-type agnostic, no changes
- `LatticeStripe.Telemetry` — event shape is stable

---

## Quality Gate Checklist

- [x] Integration points identified with file + line refs (Client header plumbing `client.ex:175, 422-424`; Search already in List `list.ex:245-275`; Resource template `payment_intent.ex:214-549`; nested child pattern `session.ex:479-519` / `line_item.ex`)
- [x] New vs modified components made explicit (§10)
- [x] Build order with 2+ alternatives and tradeoffs (§9 — Orders A, B, C)
- [x] Confirms or challenges plan's Phase 12-19 structure (§9 — confirms Order A with Phase 15 caveat, §4 challenges the scope of the Search module)
- [x] No "build a new Transport" recommendations — v1 foundation confirmed untouchable (§10 Untouched table)
- [x] Connect header plumbing verified end-to-end (§3)
- [x] TestClock integration strategy defined (§7)
- [x] ExDoc grouping proposed, consistent with v1 pattern (§8)
- [x] EventType catalog shape decided with rejected alternatives documented (§5)
- [x] ProrationBehavior validator placement decided with precedent set for future enum modules (§6)

---

## Key Sources (all internal, HIGH confidence)

- `lib/lattice_stripe/client.ex` — Transport dispatch, header building, retry loop
- `lib/lattice_stripe/list.ex` — Pagination state machine (cursor + search)
- `lib/lattice_stripe/resource.ex` — Shared helper primitives
- `lib/lattice_stripe/payment_intent.ex` — Most complex v1 resource template
- `lib/lattice_stripe/checkout/session.ex` + `checkout/line_item.ex` — Namespaced + nested child pattern
- `lib/lattice_stripe/testing.ex` — Precedent for shipping test helpers in `lib/`
- `mix.exs` — ExDoc grouping scheme
- `.planning/PROJECT.md` — Design philosophy and v2 key decisions
- `.planning/MILESTONES.md` — v1 shipped state
- `~/Downloads/lattice_stripe_billing_gap.txt` — Downstream consumer (Accrue) constraints and Tier-1/2 scope

External references for Option A EventType decision and Search model:
- stripe-ruby `Stripe::Event::Types` constants module — same shape Option A recommends
- stripe-ruby `Stripe::SearchResultObject` / stripe-node `SearchResult` — list-subclass model, matches v1's `%List{object: "search_result"}` approach
