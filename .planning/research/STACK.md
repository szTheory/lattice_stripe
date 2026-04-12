# Technology Stack — v2.0 Billing & Connect Milestone

**Project:** LatticeStripe (Elixir Stripe SDK)
**Milestone:** v2.0 Billing & Connect (target Hex release: `lattice_stripe` v0.3.0)
**Researched:** 2026-04-11
**Overall Confidence:** HIGH
**Bottom line:** No new runtime dependencies. No new test-infrastructure dependencies. v1 stack is sufficient for the entire v2 scope.

## Summary

The v2.0 milestone adds Billing (Products, Prices, Subscriptions, Invoices, SubscriptionSchedules, Coupons, PromotionCodes, InvoiceLineItems, BillingTestClocks) and Connect (Accounts, AccountLinks, LoginLinks, Transfers, Payouts, Balance, BalanceTransactions) resources on top of the v1 foundation. None of these require capabilities the v1 stack does not already provide:

- Every new resource is a handwritten module that composes `LatticeStripe.Resource`, `LatticeStripe.Request`, `LatticeStripe.FormEncoder`, and `LatticeStripe.List.stream!/2`.
- Connect's per-request scoping is already plumbed through `Stripe-Account` header support (client-level + per-request), validated in v1.
- Webhook event payloads for the new event families use the same snapshot-event envelope v1 already parses -- only new event *type strings* enter the catalog, not new verification or parsing logic.
- BillingTestClocks are a regular Stripe resource with `create`, `retrieve`, `advance`, `delete`, `list` verbs -- they ship as another resource module, not as test infrastructure.

The research question "do we need anything new" is answered **no** across all five investigation axes. The decisions below document that explicitly so future contributors don't waste effort re-litigating them.

## Recommendations

| Area | Decision | Change from v1? | Confidence |
|------|----------|-----------------|------------|
| HTTP transport | Keep Finch `~> 0.19` (also `~> 0.21` compatible) | No | HIGH |
| JSON codec | Keep Jason `~> 1.4` | No | HIGH |
| Telemetry | Keep `:telemetry ~> 1.0` | No | HIGH |
| Config validation | Keep NimbleOptions `~> 1.0` | No | HIGH |
| Webhook crypto | Keep Plug.Crypto `~> 2.0`, Plug `~> 1.16` (optional) | No | HIGH |
| Unit test mocks | Keep Mox `~> 1.2` | No | HIGH |
| Docs | Keep ExDoc `~> 0.34` | No | HIGH |
| Lint | Keep Credo `~> 1.7` | No | HIGH |
| Security scan | Keep MixAudit `~> 2.1` | No | HIGH |
| Integration test server | Keep `stripe/stripe-mock:latest` Docker image | No | HIGH |
| Stripe API version pin | Keep `2026-03-25.dahlia` | No | HIGH |
| Time-travel testing | Use real Stripe test mode via `BillingTestClock.advance/3` against `stripe-mock` best-effort; gated real-API integration for stateful flows | No new dep | HIGH |
| EventType catalog verification | Handwritten list + a tagged test that parses `stripe/openapi` `spec3.json` via Jason at test-time | No new dep | MEDIUM |

**mix.exs diff for v0.3.0: none required.** The version bump from `@version "0.2.0"` to `@version "0.3.0"` is the only edit mix.exs needs (modulo any future housekeeping unrelated to this milestone).

## Investigation Details

### 1. Does `2026-03-25.dahlia` need to change for Billing?

**No.** Dahlia is the current stable Stripe API version (flora-named release train, released 2026-03-25). It is the first version of the Dahlia cycle, so it contains the breaking changes for this cycle; subsequent Dahlia point releases (e.g., `2026-04-22.dahlia`, etc.) are additive only per Stripe's versioning policy. Dahlia's breaking changes are concentrated in Stripe.js / Elements / Checkout client-side surfaces -- not in server-side Billing resource shapes that LatticeStripe touches.

Notable Dahlia additions relevant to v2:
- New Trial Offers API (additive; can be modeled in a future resource module, not blocking).
- Configurable billing interval for pending invoice items in Checkout-based subscriptions (additive; flows through existing param passthrough).

Per-request `:stripe_version` override already exists (v1 Phase 3), so any consumer who needs a newer additive-Dahlia feature can opt in without a library bump. No stack change required.

**Sources:**
- [Stripe Dahlia changelog](https://docs.stripe.com/changelog/dahlia)
- [Stripe API versioning policy](https://docs.stripe.com/api/versioning)

### 2. Does stripe-mock fully support Billing & Connect endpoints?

**Schema coverage: yes. Stateful workflows: no -- and this is a known stripe-mock design constraint, not something a dependency swap can fix.**

stripe-mock is powered by the Stripe OpenAPI spec (`stripe/openapi`), so every Billing and Connect endpoint LatticeStripe plans to call in v2 has schema validation and fixture responses available. URL shape, HTTP method, query/body params, and response envelope structure will all be exercised.

The important limitation (already bitten in v1 -- see commit `e986f1b` "fix: skip invalid-id integration tests -- stripe-mock returns stubs for any ID"):

> stripe-mock is stateless. Data you send on a POST request will be validated, but it will be completely ignored beyond that. It will not be reflected on the response or on any future request.

That matters for v2 more than v1 because Billing flows are inherently stateful:
- `Subscription.update/3` with `proration_behavior` cannot be verified end-to-end -- stripe-mock won't produce a prorated upcoming invoice.
- `Invoice.upcoming/2` cannot be verified against real subscription state -- returns a fixture invoice.
- `BillingTestClock.advance/3` is a no-op in stripe-mock -- it validates the request shape and returns a fixture clock, but does not actually advance any subscription state.
- `Subscription.cancel/3` with `invoice_now: true` -- no real invoice gets generated.
- Connect `Transfer.create/2` / `Payout.create/2` will validate param shapes but cannot model balance movement.

**Testing strategy implications (no new dependencies, but important for Phase plans):**

| Test type | Tool | Coverage |
|-----------|------|----------|
| Unit tests via Mox | `mox ~> 1.2` | Request building, error normalization, param validation, pagination shapes -- 100% of pure logic |
| Integration smoke (stripe-mock) | existing Docker service | URL shape, method, required params, response parsing, pagination cursor handling, happy-path decoding |
| Stateful integration | **Real Stripe test mode**, gated behind env var | Subscription lifecycle, proration math, test clock advancement, webhook event ordering -- run in CI only when `STRIPE_TEST_API_KEY` secret is set, skipped by default |

The "real test-mode" test category is already permitted in v1 (CONTRIBUTING suggests tests in `test/integration/` gated behind env vars). v2 expands its usage but does not introduce it. No new dep.

**What stripe-mock WILL catch** (still valuable -- caught "several param-shape bugs that Mox unit tests missed" in v1 per PROJECT.md):
- Wrong URL path (e.g., `/v1/subscription_schedules` vs `/v1/subscription-schedules`)
- Missing required params
- Malformed nested bracket notation on complex params like `items[0][price]`
- Response decoding against OpenAPI-shaped fixtures
- Pagination envelope shape (`has_more`, `data`, `url`)

**What stripe-mock WILL NOT catch** (must be covered by real-API integration or skipped):
- Subscription status transitions (`incomplete` -> `active` -> `past_due` -> `canceled`)
- `upcoming` invoice proration math
- Test clock time advancement effects on subscriptions
- Connect balance/transfer state
- Multi-step workflows where the *second* request depends on *first* request's computed state

**Sources:**
- [stripe/stripe-mock README](https://github.com/stripe/stripe-mock) — explicit "stripe-mock is stateless" + "not planning to add statefulness" quotes
- [Stripe Test Clocks docs](https://docs.stripe.com/billing/testing/test-clocks) — advancement is a real-API feature with rate limits; not modeled in stripe-mock
- v1 commit `e986f1b` in-repo — confirmed v1 hit exactly this gap for invalid-id test mode

### 3. New test-infrastructure deps for time-travel testing?

**No.** `BillingTestClock.advance/3` is a normal POST endpoint that returns an updated TestClock object; it's not a test tool, it's a Stripe resource. The "time travel" happens server-side on Stripe's API -- LatticeStripe just calls the endpoint and polls/receives webhooks.

Alternative considered: **PropCheck / StreamData for property-based lifecycle testing**. Rejected -- subscription state machines are deterministic (no randomness to explore) and the real value is in *integration* shape, not property invariants. ExUnit + gated real-API tests cover the ground better.

Alternative considered: **Bureaucrat / ex_unit_html / Wallaby / Hound for end-to-end webhook flow visualization**. Rejected -- over-engineered for an SDK library; webhook events are verified by pattern-matching assertions in ExUnit.

**What the phase plans should codify** (not a dep change):
1. TestClocks pulled forward to Phase 13 (already planned per PROJECT.md key decisions).
2. Phase 14-16 integration tests that need stateful behavior use `@tag :stripe_api` and are skipped unless `STRIPE_TEST_API_KEY` env var is set.
3. CI pipeline adds a separate `integration-real` job that runs on-push to `main` and on tag builds, using a repo secret. Pull requests only run stripe-mock integration.
4. A small `test/support/test_clock_helper.ex` that wraps "create clock -> create customer on clock -> advance -> assert" with a configurable timeout (test clock advancement is async; status changes from `advancing` -> `ready`).

All of this is test-code, not dependencies.

**Sources:**
- [Stripe Test Clocks API reference](https://docs.stripe.com/api/test_clocks)
- [Stripe Test Clocks simulate-subscriptions](https://docs.stripe.com/billing/testing/test-clocks/simulate-subscriptions) — documents advancement rate limits ("advance by a few minutes between API requests")
- [stripity_stripe's Stripe.TestHelpers.TestClock](https://hexdocs.pm/stripity_stripe/Stripe.TestHelpers.TestClock.html) — prior-art Elixir SDK modeled test clocks as a regular resource module, no extra test deps

### 4. Auto-verify `LatticeStripe.EventType` catalog against OpenAPI spec?

**No new dep. Use a `@tag :openapi_verify` test that reads the spec at test time via Jason and diffs event types.**

The `stripe/openapi` repository publishes `openapi/spec3.json` at `https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json`. Event type enums are encoded in the spec as string enums under the `Event` schema. The verification approach:

1. **Vendor a pinned snapshot of the spec** into `test/fixtures/stripe_openapi_events.json` (a trimmed slice, not the full ~20 MB spec -- just the events enum list). Pinning avoids network-flaky tests.
2. **Write a refresher mix task** `mix lattice_stripe.refresh_openapi_events` (or a shell script in `scripts/`) that fetches the full spec, extracts the events enum via `Jason.decode!/1` (already in deps), and rewrites the fixture.
3. **Add an ExUnit test** tagged `:openapi_sync` that loads the fixture, diffs it against `LatticeStripe.EventType.all/0`, and fails with a helpful message when Stripe adds new event types (a maintenance reminder, not a blocking failure -- the tag lets it be skipped in normal CI and run weekly via a scheduled workflow).
4. **Optional: a scheduled GitHub Actions workflow** that runs the refresher + test and opens a PR when Stripe publishes new events.

**Why not OpenAPI client-gen tools** (`open_api_spex`, `oapi_generator`, `oasis`):
- `open_api_spex` is an OpenAPI-for-Phoenix server-side library -- opposite direction.
- No production-grade Elixir OpenAPI *client* code generator exists at the quality level LatticeStripe needs. Handwritten v1 modules exist exactly because codegen was rejected (ADVN-02, deferred).
- A full client-gen pipeline would leak into the architecture (generated modules, generation step in CI, regeneration discipline). Out of scope for v2; tracked as future consideration for a post-v2 milestone.

**Why not Context7 / runtime spec fetching**:
- Tests must be hermetic. Fetch-at-test-time creates flakes and requires network in CI.
- Spec version drift between CI runs causes spurious failures.

**The chosen approach is:** `Jason.decode!/1` + vendored fixture + mix task. Both Jason and Mix are already in the project. Zero new deps.

**Sources:**
- [stripe/openapi repository](https://github.com/stripe/openapi)
- [spec3.json raw URL](https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json)
- PROJECT.md v2 key decision row: "v2 LatticeStripe.EventType catalog is exhaustive (not Accrue-scoped) ... auto-verify against OpenAPI spec during Phase 19"

### 5. Finch pool tuning for higher-volume Billing integration tests?

**No config change needed for v2 integration tests, but document the knob.**

Finch connection pool sizing is a per-client configuration (`Finch.start_link(pools: %{"https://api.stripe.com" => [size: N, count: M]})`). The v1 default in `LatticeStripe.Transport.Finch` is sufficient for:

- Stripe-mock integration tests (local Docker, latency ~1 ms, single-threaded ExUnit).
- Real-API integration tests gated behind env var (typically run serially due to Stripe's per-key rate limits -- 100 req/s read, 100 req/s write in test mode, *lower* when a test clock is attached).

The specific concern raised in the milestone context -- "higher-volume test scenarios in Billing integration tests (subscription webhooks, invoice events)" -- is not actually a Finch pool problem. It's a Stripe rate-limit problem:

> If you make multiple updates to a subscription that has a test clock, Stripe might return a rate limit error. Since the subscription is frozen to the time of the test clock, all API requests count toward that time, which can trigger the rate limit. To avoid this, advance the simulated time of the clock by a few minutes before making additional API requests on the subscription.
> -- [Stripe Test Clocks docs](https://docs.stripe.com/billing/testing/test-clocks)

Adding more Finch connections will not help -- it will *hurt*, by allowing more concurrent requests to a single rate-limit bucket. The correct mitigation:

1. Run billing integration tests with `async: false`.
2. Rely on v1's existing `RetryStrategy` exponential backoff (already honors `Stripe-Should-Retry` and `Retry-After`).
3. Advance test clocks by non-zero intervals between state changes (per Stripe's own guidance).

**Action:** no pool change. Document the rate-limit-with-test-clock gotcha in `guides/testing.md` as part of Phase 19 docs work, and surface it in `.planning/research/PITFALLS.md` so it makes the v2 pitfall catalog.

**Sources:**
- [Stripe Test Clocks rate limits](https://docs.stripe.com/billing/testing/test-clocks) (search for "rate limit")
- [Finch pool docs](https://hexdocs.pm/finch/Finch.html#start_link/1)
- v1 `LatticeStripe.RetryStrategy.Default` (already in repo) handles `Stripe-Should-Retry: true` for 429s

## What NOT to Add

| Technology | Why NOT |
|------------|---------|
| **Req** | Already rejected in v1. v2 doesn't change the calculus. LatticeStripe owns its retry/idempotency/rate-limit pipeline; Req's batteries conflict. |
| **Tesla** | Middleware abstraction unnecessary; same v1 reasoning. |
| **HTTPoison / Hackney** | Legacy; v1 rejection stands. |
| **PropCheck / StreamData** | Subscription state machines are deterministic. Property testing adds flakes without catching real bugs for an HTTP SDK. |
| **Bypass** | stripe-mock is strictly better (OpenAPI-validated) for what Bypass would cover. Mox covers the rest. |
| **ExVCR** | Cassette-based replay is brittle. Real-API gated tests + stripe-mock handle both ends. |
| **open_api_spex** | It's a server-side library for documenting Phoenix APIs, not a client-gen tool. |
| **oapi_generator / oasis** | Client generation is explicitly out-of-scope (ADVN-02, deferred). v2 is still handwritten per PROJECT.md Key Decisions. |
| **Stripe Terminal SDK / Stripe CLI as a library** | Out of scope; Stripe CLI is a developer tool, not a library dep. Webhook testing uses `stripe listen` manually in `guides/testing.md`, not via a Hex package. |
| **Ecto / Postgrex** | Still no database. SDK has no persistence concerns. |
| **GenServer-wrapped client cache** | Still violates PROJECT.md "processes only when truly needed". Client is a struct passed explicitly. |
| **benchee** | Could be tempting for "benchmark subscription creation flow". Out of scope for v2 -- performance is not a stated milestone goal, and stripe-mock local latency dominates any meaningful benchmark anyway. Add later if a real user reports a perf issue. |
| **New test-matrix dimensions** (e.g., macOS runners, Windows runners) | v1 CI matrix (Elixir 1.15/1.17/1.19 × OTP 26/27/28 on ubuntu-latest) is adequate. The SDK has no platform-specific code paths. Adding runners costs CI minutes without catching real bugs. |
| **Dialyzer/Dialyxir** | Still excluded per PROJECT.md constraints. |

## Stays the Same (explicit v1-carryover list)

Every runtime and tooling choice from v1 carries forward to v2 unchanged:

```elixir
# mix.exs deps -- v0.3.0 is identical to v0.2.0 except for @version
defp deps do
  [
    {:finch, "~> 0.19"},
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.0"},
    {:nimble_options, "~> 1.0"},
    {:plug_crypto, "~> 2.0"},
    {:plug, "~> 1.16", optional: true},

    {:mox, "~> 1.2", only: :test},
    {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
  ]
end
```

Behaviours that stay load-bearing and are reused as-is:
- `LatticeStripe.Transport` (+ `LatticeStripe.Transport.Finch` default adapter)
- `LatticeStripe.Json` (+ `LatticeStripe.Json.Jason` default adapter)
- `LatticeStripe.RetryStrategy` (+ `LatticeStripe.RetryStrategy.Default`)
- `LatticeStripe.Resource` helper (extracted in v1, reused by every new v2 resource module)
- `LatticeStripe.Request` / `LatticeStripe.FormEncoder` (encoder already handles Stripe bracket notation for nested params like `items[0][price]`, which Billing and Connect rely on heavily)
- `LatticeStripe.List` / `List.stream!/2` (cursor pagination; works unchanged for all new list endpoints)
- `LatticeStripe.Response` (Access/Inspect protocols)

**One new public helper, no new deps:** `LatticeStripe.Search.stream!/3`. Stripe's search endpoints use `page` / `next_page` cursors instead of `starting_after`, and the existing `List.stream!/2` assumes cursor-style. v2 adds a second streamer for search that wraps `Stream.resource/3` differently. It is pure Elixir, composes the existing `Client.request/2`, and adds zero dependencies. This belongs in the architecture research, not the stack research, but calling it out here to preempt the "is this a new dep?" question.

## Integration Points with Existing Code

| New v2 capability | Existing module it plugs into | Change to existing module? |
|-------------------|-------------------------------|----------------------------|
| Billing resource modules (Product, Price, Subscription, Invoice, ...) | `LatticeStripe.Resource` (unwrap helper), `LatticeStripe.Client.request/2` | None -- additive only |
| Connect resource modules (Account, Transfer, Payout, ...) | Existing `Stripe-Account` header plumbing in `LatticeStripe.Config` + per-request opts | None -- header support already complete in v1 |
| `LatticeStripe.EventType` catalog | `LatticeStripe.Event`, `LatticeStripe.Webhook` | None -- EventType is a new sibling module, not a replacement |
| `LatticeStripe.Search.stream!/3` | `LatticeStripe.List` (sibling, not replacement) | None -- both helpers coexist |
| `LatticeStripe.Billing.ProrationBehavior` validator | Subscription/Invoice opts validation | None -- validator runs before `Client.request/2` |
| BillingTestClock resource | Normal resource module | None -- follows Customer pattern exactly |
| Proration discipline (`require_explicit_proration` flag) | `LatticeStripe.Config` (adds one boolean) | Additive config field |

All integration is additive. No breaking changes to v1 public API. v0.3.0 is a MINOR bump per SemVer (and Release Please will pick that up from Conventional Commits).

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| "No new runtime deps" | HIGH | Verified against the full Tier 1 + Tier 2 resource list from `lattice_stripe_billing_gap.txt`; every resource reduces to `Resource + Request + FormEncoder + List` primitives already in v1. |
| "stripe-mock coverage + limitations" | HIGH | Directly confirmed by stripe-mock README statelessness quote and v1's own commit `e986f1b` fixing exactly this class of issue. |
| "Dahlia API version is fine for v2" | HIGH | Verified against Stripe changelog; Dahlia breaking changes are client-side (Stripe.js/Elements), Billing server-side shapes are additive. |
| "No new test-infrastructure deps for test clocks" | HIGH | Test clocks are a normal Stripe resource; stripity_stripe's prior art confirms the modeling approach. |
| "EventType verification via vendored fixture + Jason" | MEDIUM | The approach is sound and zero-dep, but no existing Elixir SDK has implemented it in the form proposed. Risk is low (~150 LOC of test code) -- downgraded from HIGH only because it's slightly novel for this repo. |
| "Finch pool sizing unchanged" | HIGH | The stated concern was a misdiagnosis; root cause is Stripe rate limits with test clocks, not connection pool pressure. |

## Sources

- [Stripe Dahlia changelog](https://docs.stripe.com/changelog/dahlia) — confirms Dahlia breaking changes are client-side, Billing additions are additive
- [Stripe API versioning](https://docs.stripe.com/api/versioning) — flora release model, additive point releases
- [stripe/stripe-mock README](https://github.com/stripe/stripe-mock) — explicit statelessness, "not planning to add statefulness" quote
- [Stripe Test Clocks API reference](https://docs.stripe.com/api/test_clocks)
- [Stripe Test Clocks overview](https://docs.stripe.com/billing/testing/test-clocks) — advancement semantics, rate-limit-with-clock warning
- [Stripe Test Clocks simulate subscriptions](https://docs.stripe.com/billing/testing/test-clocks/simulate-subscriptions)
- [Testing Billing integrations](https://docs.stripe.com/billing/testing)
- [Testing subscriptions with Test Clocks and Workbench (stripe.dev blog)](https://stripe.dev/blog/testing-subscriptions-with-stripe-test-clocks-and-workbench)
- [stripe/openapi repository](https://github.com/stripe/openapi) — source of truth for EventType catalog verification
- [spec3.json raw URL](https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json)
- [stripity_stripe TestClock module](https://hexdocs.pm/stripity_stripe/Stripe.TestHelpers.TestClock.html) — prior art confirming test clocks model as a regular resource
- [Finch on Hex.pm](https://hex.pm/packages/finch) — pool configuration reference
- LatticeStripe repo: `mix.exs` (current v0.2.0 deps), commit `e986f1b` (v1 stripe-mock stateless workaround), PROJECT.md Key Decisions table (v2 design decisions already logged)
- `~/Downloads/lattice_stripe_billing_gap.txt` — Accrue-side v2 scope with Tier 1/2/3/4/5 resource breakdown
