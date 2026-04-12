# Phase 13: Billing Test Clocks — Context

**Gathered:** 2026-04-12
**Status:** Ready for research & planning

<domain>
## Phase Boundary

Ship the Stripe Billing Test Clock SDK resource plus a user-facing ExUnit test helper library so LatticeStripe users can deterministically time-travel billing fixtures in their own test suites — unblocking subscription/invoice lifecycle coverage in Phases 14–19.

**In scope:**
1. `LatticeStripe.TestHelpers.TestClock` — SDK resource: create/retrieve/list/stream/delete/advance + `advance_and_wait/3` (differentiating helper, no other Stripe SDK ships it).
2. `LatticeStripe.Testing.TestClock` — user-facing ExUnit helper library (compile-time client binding, setup callback, auto-cleanup, customer linkage wrapper).
3. `mix lattice_stripe.test_clock.cleanup` — backstop Mix task for leaked clocks.
4. `LatticeStripe.Testing.RealStripeCase` — internal (`test/support/`) CaseTemplate establishing the `:real_stripe` test tier pattern for phases 14–19.
5. The first `@moduletag :real_stripe` test in the repo — a clock-advancement round-trip against live Stripe test mode, gated by `STRIPE_TEST_SECRET_KEY`.

**Out of scope:** Customer/Subscription/Invoice fixture factories (users layer ExMachina or plain functions on top); webhook-based clock advancement notifications; anything Connect-related.

**Requirements:** BILL-08, BILL-08b, BILL-08c, TEST-09, TEST-10.

</domain>

<decisions>
## Implementation Decisions

*Four parallel advisor researchers investigated ecosystem precedents (Oban.Testing, Ecto.Sandbox, Mox, ExMachina, Req, NimbleOptions, ExAws waiters, stripity_stripe, Stripe official SDKs) and idiomatic Elixir patterns before these were locked.*

### Module naming & namespace

- **D-13a — SDK resource: `LatticeStripe.TestHelpers.TestClock`.** Not `BillingTestClock`, not `LatticeStripe.TestClock`, not `LatticeStripe.Billing.TestClock`. Matches Stripe API path (`/v1/test_helpers/test_clocks`) and every official Stripe SDK. Introduces the **first nested sub-product namespace** in LatticeStripe.
- **D-13a (precedent):** Core billing resources (Customer, Product, Price, Coupon, Subscription, Invoice) stay **flat** under `LatticeStripe.*`. Stripe sub-product families (`TestHelpers`, `Connect`, `Issuing`, `Terminal`, `BillingPortal`, `Radar`, `Treasury`, `Identity`) **nest**. This rule is written into `.planning/CONVENTIONS.md` (D-13a-convention, new file this phase) so Phase 17 Connect doesn't re-litigate it.
- **D-13a (Phase 17 lock-in):** Connect resources will be `LatticeStripe.Connect.Account`, `LatticeStripe.Connect.AccountLink`, `LatticeStripe.Connect.Transfer`, etc. — NOT `LatticeStripe.ConnectAccount`.
- **D-13a (test helper module):** User-facing helper lives at `LatticeStripe.Testing.TestClock` — mirrors `Oban.Testing`, `Phoenix.ChannelTest`. The `Testing` namespace is distinct from `TestHelpers` — `TestHelpers` = SDK resources that wrap `/test_helpers/*` API, `Testing` = user-facing ExUnit ergonomics. Both names intentional and parallel.

### `advance_and_wait/3` — polling strategy

- **D-13b — Exponential backoff with full jitter.** Start `500ms`, multiplier `1.5`, cap `5_000ms`. Full jitter per step via `:rand.uniform(delay)` (AWS-style). Matches Req/Finch/ExAws-waiters/GCP long-running-op conventions.
- **D-13b — First poll happens with zero delay.** Catches stripe-mock's instant case and simple-fixture "already ready" cases without paying 500ms latency per test. Critical for test suite speed.
- **D-13b — Default timeout `60_000ms` (60s).** 2× the documented worst case for complex live fixtures, well under any CI step budget. Configurable via `opts[:timeout]`. Also accept `:initial_interval`, `:max_interval`, `:multiplier` for advanced users (un-prominent docs).
- **D-13b — Monotonic deadline.** Use `System.monotonic_time(:millisecond)` for deadline check, not `System.system_time/1` — NTP adjustments during long test runs would otherwise cause premature timeouts.
- **D-13b — 500ms floor is non-negotiable.** Stripe docs explicitly warn about rate limits on tight polling against test-clocked subscriptions; never drop below 500ms even if user configures lower.

### `advance_and_wait/3` — error shape & API surface

- **D-13c — Return shape: `{:error, %LatticeStripe.Error{}}` struct, not bare atom.** Overrides BILL-08b's literal `{:error, :timeout}` wording. Rationale: bare atoms throw away the clock's last-known status, which is exactly what a user needs to debug "why didn't my clock advance." Struct errors implementing `Exception` are the modern Elixir consensus (Ecto.Changeset, Mint.TransportError, NimbleOptions.ValidationError, Req exceptions).
- **D-13c — `%LatticeStripe.Error{}` must implement `Exception` behaviour.** Field schema: `type :: atom()`, `message :: String.t()`, `details :: map()`. For test clocks: `type: :test_clock_timeout` or `type: :test_clock_failed`, `details: %{clock_id:, last_status:, elapsed_ms:}`. Implementing `Exception` means the same value works for tuple returns AND bang variants via `raise/1`. Check if `LatticeStripe.Error` already exists in the codebase; if not, this phase introduces it (used by subsequent phases too).
- **D-13c — Ship BOTH `advance_and_wait/3` and `advance_and_wait!/3`.** Bang variant raises the same `%Error{}`. Convention: in test code (the only caller), users overwhelmingly want the bang variant — a failed test clock should fail the test loudly. Tuple variant exists for test-orchestration code that catches and retries.
- **D-13c — `internal_failure` is terminal, no retry.** First poll that returns `status: "internal_failure"` immediately returns `{:error, %Error{type: :test_clock_failed}}`. Different `type` from timeout so users pattern-match cleanly.
- **D-13c — BILL-08b update:** Requirements doc text will be amended to match (`{:error, %LatticeStripe.Error{type: :test_clock_timeout, ...}}`) — literal `{:error, :timeout}` was a pre-design stub.
- **D-13c — Telemetry:** `[:lattice_stripe, :test_clock, :advance_and_wait, :start | :stop]` with `%{status:, attempts:, duration:}`. Matches Phase 12 telemetry conventions.

### `Testing.TestClock` — helper library public API

- **D-13d — Oban.Testing `use` pattern with compile-time client binding.** Users write `use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient` **inside their own CaseTemplate** (typically `MyApp.StripeCase`). This is the idiomatic Elixir pattern for parameterized test helpers (Oban.Testing, ExMachina.Ecto).
- **D-13d — Does NOT force being a CaseTemplate itself.** Composes inside the user's `StripeCase` via nested `use`. Users keep control of their own case template inheritance.
- **D-13d — Validates `:client` option at compile time.** Missing or non-module = helpful `CompileError`. Never defer to runtime resolution.
- **D-13d — Per-call client override.** Every helper function accepts `client:` opt that wins over the compile-time binding. Multi-account tests supported.
- **D-13d — Imported helper surface (exactly this, not more):**
  - `test_clock/1` — create clock, register for cleanup. `opts` includes `:frozen_time`, `:name`, `:metadata`.
  - `advance/2` — advances clock and waits for `:ready`. `unit_opts` like `[days: 30]`, `[months: 1]`, `[to: ~U[...]]`. Wraps `TestHelpers.TestClock.advance_and_wait!/3`.
  - `freeze/1` — waits for current clock state to reach `:ready` (no advancement). Rarely needed; useful after out-of-band clock ops.
  - `create_customer/3` — wraps `LatticeStripe.Customer.create/2`, auto-injects `test_clock: clock.id` into params.
  - `with_test_clock/1` — ExUnit setup callback, returns `%{test_clock: clock}` in context.
- **D-13d — Usage example (the happy path):**
  ```elixir
  defmodule MyApp.StripeCase do
    use ExUnit.CaseTemplate
    using do
      quote do
        use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient
      end
    end
  end

  defmodule MyApp.BillingTest do
    use MyApp.StripeCase, async: true
    setup :with_test_clock

    test "sub renews after 30 days", %{test_clock: clock} do
      customer = create_customer(clock, email: "a@b.c")
      {:ok, sub} = MyApp.Billing.subscribe(customer, "price_monthly")
      advance(clock, days: 30)
      assert {:ok, %{status: "active"}} = MyApp.Billing.get_subscription(sub.id)
    end
  end
  ```

### `Testing.TestClock` — scope discipline

- **D-13e — Narrow like Ecto.Sandbox, NOT broad like ExMachina.** Helper owns: clock lifecycle, clock advancement, ONE customer wrapper (`create_customer/3` — closes the linkage footgun described in D-13h).
- **D-13e — Does NOT own:** Subscription factories, Invoice factories, Price factories, Product factories. Users layer ExMachina or plain functions on top using `test_clock` and `client` as primitives.
- **D-13e — Rationale:** ExMachina's broad fixture approach ages badly (factories drift from prod shape, god-factory proliferation). Ecto.Sandbox's narrow approach has aged beautifully across 8+ years. For a library tracking 30+ Stripe resources whose shapes evolve, narrow wins.

### `Testing.TestClock` — cleanup mechanism

- **D-13f — Primary: ExUnit `Owner` pattern via `start_owner!` + `on_exit`.** Mirrors `Ecto.Adapters.SQL.Sandbox.start_owner!/2` exactly. A lightweight per-test `GenServer` owner tracks created clocks; `on_exit` callback calls `DELETE /v1/test_helpers/test_clocks/:id` on each (Stripe cascades to attached customers and subs).
- **D-13f — Owner is NOT `start_supervised!/1`.** `on_exit` runs in an ExUnit-supervised process and executes even when the test pid crashes or raises. `start_supervised!` children die with the test process and miss cleanup. Ecto.Sandbox's choice here is deliberate and correct.
- **D-13f — Backstop: `mix lattice_stripe.test_clock.cleanup`.** `--dry-run`, `--older-than 1h` (default), `--client` (module name or Application env key). Reads Stripe account, lists test clocks, filters by metadata marker (D-13g), deletes matching. Detects stripe-mock via client transport config and no-ops.
- **D-13f — Why both:** `on_exit` handles 99% locally (test pass, raise, assertion fail — all covered). It does NOT run on SIGKILL, BEAM segfault, or CI job timeout. That gap + Stripe's 100-clock-per-account hard limit = broken CI for everyone on the account. Mix task backstops exactly those cases.
- **D-13f — Shared deletion core:** both paths call a common `LatticeStripe.TestHelpers.TestClock.cleanup_tagged/2` function; no duplicated deletion logic.

### Clock tagging marker

- **D-13g — Metadata key `"lattice_stripe_test_clock"`, value `"v1"`.** Merged into user-supplied metadata at clock creation via `test_clock/1`. Never touches the clock `name` (user-visible in Stripe Dashboard, users have legitimate naming needs).
- **D-13g — Public stable API.** Stored as `@cleanup_marker {"lattice_stripe_test_clock", "v1"}` module attribute in `LatticeStripe.Testing.TestClock`. Documented in `@moduledoc`. Changing the key or value is a breaking change.
- **D-13g — Versioning rationale:** `"v1"` beats `"1"` because it signals "schema version, not count." Future `"v2"` (different cleanup semantics) bumps the *creation* marker only. The Mix task must always delete BOTH `"v1"` and `"v2"` tagged clocks to support users running mixed SDK versions in CI.
- **D-13g — Metadata limit guard:** Stripe allows max 50 metadata keys per object. If user's supplied metadata + our marker would exceed 50, raise a clear error (`Testing.TestClockError` or similar) rather than silently dropping the marker.

### Customer ↔ Clock linkage

- **D-13h — `create_customer/3` wrapper auto-injects `test_clock: clock.id`.** Forgetting `test_clock:` on Customer creation is a silent correctness bug — customer runs on real time, clock advances have no effect, test passes for wrong reasons. Closing this footgun at the wrapper level eliminates the category.
- **D-13h — Process-dict scope (`with_clock(fn -> ... end)`) rejected.** Implicit context fights `async: true`, un-Elixir, breaks under nested describes with different clocks.
- **D-13h — Users who bypass the wrapper** (calling `LatticeStripe.Customer.create/2` directly) are on their own. Document this explicitly in the `Testing.TestClock` moduledoc.

### `:real_stripe` test tier

- **D-13i — New orthogonal tag `:real_stripe`.** NOT nested under `:integration`. They are independent axes: `:integration` = "hits Docker stripe-mock," `:real_stripe` = "hits live Stripe test mode." Running both: `mix test --include integration --include real_stripe`.
- **D-13i — `ExUnit.configure(exclude: [:integration, :real_stripe])` in `test/test_helper.exs`.** Default `mix test` runs neither.
- **D-13i — Directory: `test/real_stripe/*_test.exs`.** Physical separation signals cost to PR reviewers, enables `mix test test/real_stripe/` one-liner for maintainers, and keeps stripe-mock integration tests (`test/integration/`) unmixed. Added to `test_paths` in `mix.exs`.
- **D-13i — CaseTemplate: `LatticeStripe.Testing.RealStripeCase` in `test/support/real_stripe_case.ex`.** Internal-only (not shipped in `lib/`, not in Hex docs). Every `test/real_stripe/*_test.exs` file does `use LatticeStripe.Testing.RealStripeCase`.
- **D-13i — CaseTemplate applies:**
  - `@moduletag :real_stripe`
  - `@moduletag timeout: 120_000` (2min per test — real network is slow)
  - `async: false` implicit — real_stripe tests share rate-limit budget; never run in parallel
- **D-13i — `setup_all` behavior:**
  - No `STRIPE_TEST_SECRET_KEY` + no `CI` env var → `{:skip, "STRIPE_TEST_SECRET_KEY not set; skipping real Stripe tests"}` (friendly for contributors)
  - No `STRIPE_TEST_SECRET_KEY` + `CI=true` → `flunk(...)` (loud failure in CI — secret rotation must be noticed)
  - Key starts with `sk_live_` → `flunk("Refusing to run :real_stripe tests against a LIVE key. Use sk_test_*.")` — **non-negotiable safety guard**
  - Key starts with `sk_test_` → construct `LatticeStripe.Client` and inject into context as `client`
  - Anything else → `flunk("STRIPE_TEST_SECRET_KEY must start with sk_test_")`
- **D-13i — Per-test idempotency prefix:** `LatticeStripe.Client.new(api_key: key, idempotency_key_prefix: "lattice-test-#{System.system_time(:millisecond)}-")`. Avoids replay collisions across CI re-runs.
- **D-13i — Phase 13's canonical first test:** `test/real_stripe/test_clock_real_stripe_test.exs` — create a clock, advance it 30 days, assert status ready, assert metadata marker present, delete. This is the template phases 14–19 will follow.

### Secret handling

- **D-13j — Environment variable only: `STRIPE_TEST_SECRET_KEY`.** No Mix config indirection (risk of accidental commit via `config/test.exs`). No `dotenv` dep (belongs in maintainer's shell, not a library's deps). Document `direnv` + `.envrc` in `CONTRIBUTING.md` (Phase 13 adds this section).
- **D-13j — `.envrc` added to `.gitignore`** (if not already).
- **D-13j — CI path:** GitHub Actions repo secret → job env var. No other mechanism.

### Claude's Discretion

The following are deliberately left to the planner / executor during implementation — they are local implementation details that don't affect the public API shape:

- Exact internal module layout of the `Owner` GenServer (one module vs inlined into `Testing.TestClock`).
- Whether `cleanup_tagged/2` lives on `TestHelpers.TestClock` or a separate `TestHelpers.TestClock.Cleanup` submodule.
- Whether `advance/2`'s `unit_opts` parser supports DateTime shift directly or routes through `Timex`/`Date.shift` — caller cares only that `days: 30` and `to: ~U[...]` both work.
- Exact wording of `Testing.TestClockError` messages (just keep them actionable).
- Whether the Mix task reports progress via `Mix.shell().info/1` or `IO.puts/1` — either is fine.
- Property-test coverage for metadata merging (nice to have, not load-bearing).

### Research amendments (post-codebase-audit)

*Following the gsd-phase-researcher codebase audit, the decisions below are updated. These supersede the original claims where they conflict. See `13-RESEARCH.md` for full evidence.*

- **A-13a (amends D-13a — nested namespace claim):** Phase 13 is NOT the first nested namespace. `LatticeStripe.Checkout.Session` and `LatticeStripe.Checkout.LineItem` already exist (`lib/lattice_stripe/checkout/*.ex`). `CONVENTIONS.md` (new file, still a Phase 13 deliverable) will document Checkout as the **existing precedent** and Phase 13's `TestHelpers.TestClock` + `Testing.TestClock` as the second and third nested namespaces, respectively. Phase 17 Connect still follows the same rule.
- **A-13c (amends D-13c — Error struct field schema):** `LatticeStripe.Error` already exists at `lib/lattice_stripe/error.ex` and already implements `Exception`. Its field schema is `type | code | message | status | request_id | param | decline_code | charge | doc_url | raw_body`. **Do NOT add a `:details` field.** Instead: add `:test_clock_timeout` and `:test_clock_failed` to the `:type` whitelist, and stash clock context (`%{clock_id:, last_status:, elapsed_ms:}`) in the existing `:raw_body` field (which is a free-form map). No schema change; zero risk to Phase 12 consumers. BILL-08b amendment text becomes `{:error, %LatticeStripe.Error{type: :test_clock_timeout, raw_body: %{clock_id: _, last_status: :advancing, elapsed_ms: _}}}`.
- **A-13d (amends D-13d — advance/2 unit_opts):** Project minimum is Elixir 1.15, which does **not** include `Date.shift/2` (added in 1.17). Supporting `[months: 1]` / `[years: 1]` would require a dep on `Timex` or a hand-rolled month-arithmetic helper — neither is worth it in v1. **v1 `advance/2` supports: `:seconds`, `:minutes`, `:hours`, `:days`, `:to` (absolute DateTime).** `:months` / `:years` raise a clear error pointing users to `:to` (`advance(clock, to: DateTime.add(clock.frozen_time, 30, :day) ...)`). Revisit when project minimum bumps to 1.17+. The happy-path example in D-13d should use `advance(clock, days: 30)`, not `months: 1`.
- **A-13b (amends D-13b — jitter vs floor inconsistency):** "Full jitter" and "500ms floor" can produce values below 500ms (e.g., `:rand.uniform(700)` can yield 200ms). Resolution: `sleep_ms = max(500, :rand.uniform(delay))`. Floor wins; jitter operates on `[500, delay]`. First poll still has zero delay (the floor applies only to subsequent polls).
- **A-13g (amends D-13g — metadata support probe):** The Stripe Test Clock API's support for `metadata` on create is not documented explicitly in the OpenAPI schema excerpts the researcher could audit. **Plan 02 must include a probe task that verifies it** (one `curl` or one live API call). If metadata is unsupported, fall back to: Testing.TestClock Owner tracks clock ids in process state + Mix task cleans by age (`--older-than`) instead of by marker. This is a materially worse UX (Mix task can't distinguish LatticeStripe clocks from user-created ones) but functional.
- **A-13i (amends D-13i — test_paths):** Default `mix.exs` `test_paths` is already `["test"]` which covers `test/real_stripe/`. **No `mix.exs` change needed** for test path registration. Only the `ExUnit.configure(exclude: [..., :real_stripe])` line in `test/test_helper.exs` needs updating.
- **A-13support (new micro-task in Plan 01):** `test/support/test_helpers.ex` already defines `LatticeStripe.TestHelpers` (test-only, `@moduledoc false`). This **collides in intent** with the new public `LatticeStripe.TestHelpers.TestClock` namespace. Plan 01 renames the existing test-only module to `LatticeStripe.TestSupport` and updates ~10 test-file aliases. Elixir allows `LatticeStripe.TestHelpers.TestClock` to exist without a parent `LatticeStripe.TestHelpers` module, so the submodule compiles fine either way — but keeping two meanings of `TestHelpers` under one namespace invites confusion. The rename is cheap and clarifying.
- **A-13client (new micro-task in Plan 01):** `Client.new/1` does not currently support `:idempotency_key_prefix`. Plan 01 adds it: extend `Config` NimbleOptions schema, add to `Client` defstruct, thread through `resolve_idempotency_key/2` in the request pipeline. Default `nil` (backward-compatible). Unblocks D-13i's per-test idempotency prefix.

</decisions>

<specifics>
## Specific Ideas

- **"No other Stripe SDK ships `advance_and_wait`."** This is a genuine DX differentiator, not a port — be decisive about the shape rather than copying a reference implementation that doesn't exist.
- **"Unsurprising"** is LatticeStripe's core value prop. The customer-linkage wrapper (D-13h) is a direct expression of that: silent correctness bugs are not acceptable, even if the fix costs one extra function.
- **"Elixir devs feel at home immediately."** Every pattern chosen here has a direct ecosystem analog (Oban.Testing for `use`-with-client, Ecto.Sandbox for `Owner` cleanup, NimbleOptions/Mint for struct errors, ExAws waiters for backoff polling). A reader who knows Ecto + Oban should recognize the shape on sight.
- **Worked happy-path example** (from D-13d above) is the canonical reference for what "good" looks like. If an implementation decision would make that example longer or uglier, reconsider the decision.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 13 requirements
- `.planning/REQUIREMENTS.md` — BILL-08 / BILL-08b / BILL-08c / TEST-09 / TEST-10 row definitions (note: BILL-08b text will be amended per D-13c to use `%LatticeStripe.Error{}` struct)
- `.planning/ROADMAP.md` §"Phase 13: Billing Test Clocks" — success criteria 1–4 (first real_stripe test is SC-4)

### Phase 12 inherited decisions (apply unchanged to Phase 13)
- `.planning/phases/12-billing-catalog/12-CONTEXT.md` — decisions D-01 through D-11 inherit. Specifically:
  - **D-03 (atomization):** TestClock `status` field atomized whitelist `:ready | :advancing | :internal_failure | String.t()` for forward compat
  - **D-08 (standalone module):** TestClock is its own module, not inlined into another resource
  - **from_map/from_list + `extra: %{}` catch-all:** every new struct in this phase uses the Phase 12 pattern
  - **D-07 (custom IDs via params map):** no helper arg for custom clock IDs; users pass via `params.id` if they want them
- `.planning/phases/12-billing-catalog/12-RESEARCH.md` — research format precedent for Phase 13 researcher to follow

### Stripe API documentation
- https://docs.stripe.com/api/test_clocks — resource schema, fields, operations
- https://docs.stripe.com/api/test_clocks/advance — advance endpoint, validation rules (max "two intervals" from shortest sub)
- https://docs.stripe.com/api/test_clocks/delete — cascading delete semantics (auto-deletes customers, cancels subs attached to the clock)
- https://docs.stripe.com/billing/testing/test-clocks/api-advanced-usage — polling guidance, rate-limit warning
- https://docs.stripe.com/billing/testing/test-clocks — 100-clock-per-account limit, webhook event names

### Elixir ecosystem precedents (inform patterns used here)
- https://hexdocs.pm/oban/Oban.Testing.html — `use ... , client: MyClient` pattern source (D-13d)
- https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html — `start_owner!/2` + `on_exit` cleanup pattern source (D-13f)
- https://hexdocs.pm/ex_unit/ExUnit.CaseTemplate.html — CaseTemplate reference (D-13d, D-13i)
- https://hexdocs.pm/nimble_options/NimbleOptions.ValidationError.html — struct-error-implementing-Exception reference (D-13c)

### New files this phase introduces (not yet in repo)
- `.planning/CONVENTIONS.md` — codifies the "core flat, sub-product nested" rule from D-13a so Phase 17 Connect doesn't re-litigate. **Creating this file is a Phase 13 deliverable.** Contents: one-paragraph rule + examples + Phase 17 implications.
- `CONTRIBUTING.md` — `direnv` + `.envrc` workflow for real_stripe tests (D-13j). If file already exists, extend it.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (Phase 12 shipped these)
- **`LatticeStripe.Resource` helpers:** `unwrap_singular/1`, `unwrap_list/1` — TestClock CRUD will route through these just like Product/Price did.
- **`LatticeStripe.FormEncoder` with D-09f float-safe scalar encoder:** TestClock `frozen_time` is a Unix timestamp integer, not a float, so the float branch isn't exercised — but the encoder's atomization and nested-key handling are used.
- **`LatticeStripe.Customer.create/2`:** `Testing.TestClock.create_customer/3` wrapper calls this directly, passing merged params.
- **Phase 12 atomization pattern (D-03):** helpers like `atomize_status/1` with whitelist + forward-compat string pass-through apply unchanged to TestClock `status`.
- **Phase 12 `from_map/1` + `extra: %{}` catch-all pattern:** TestClock struct follows the exact shape.
- **Phase 12 telemetry events (`[:lattice_stripe, :request, :start | :stop]`):** `advance_and_wait`'s telemetry (D-13b) is a peer, not a replacement.

### Established Patterns (from Phase 12)
- **Plan ordering within a phase:** test scaffolds wave 0 → core helpers wave 1 → resource + unit wave 2 → integration + docs wave 3. Phase 13 will likely mirror this.
- **TDD discipline:** RED-then-GREEN commits per task, pre-existing in Phase 12 executor behavior.
- **Dialyzer-free:** typespecs for docs only. Applies unchanged.
- **Flat module structure (existing):** Phase 13 introduces the first nested namespace — call this out to the planner so Credo rules and `mix.exs` `elixirc_paths` don't need updates (nothing to update, just a precedent shift).

### Integration Points
- **`test/support/` directory:** already exists (Phase 9 / Phase 12). `real_stripe_case.ex` lands here. Confirm `elixirc_paths(:test)` includes `test/support`.
- **`test/integration/`:** existing stripe-mock integration tests. Untouched by Phase 13.
- **`test/real_stripe/`:** NEW directory. Must be added to `test_paths` in `mix.exs` under `:test` Mix env, AND `ExUnit.configure(exclude: [:integration, :real_stripe])` must be set in `test/test_helper.exs` (verify Phase 9's `:integration` exclusion is there — extend, don't replace).
- **`LatticeStripe.Error`:** check if the struct exists (likely introduced in an earlier phase around HTTP errors). If it exists, extend with `:test_clock_timeout` and `:test_clock_failed` type values. If it does NOT exist, this phase introduces it — and future phases should adopt it as the canonical error struct.
- **`LatticeStripe.Client.new/1`:** needs to support `:idempotency_key_prefix` option (D-13i). Check if this option already exists; if not, add it as a Phase 13 micro-task (small, self-contained).

</code_context>

<deferred>
## Deferred Ideas

- **Webhook-driven clock advancement notifications.** Stripe emits `test_helpers.test_clock.advancing` / `.ready` events. A webhook-based `advance_and_await` would eliminate polling entirely — but webhooks aren't usable from an SDK unit-test helper (no public endpoint in tests). Revisit in a future phase if/when LatticeStripe ships webhook infrastructure for user apps.
- **`LatticeStripe.Testing.TestClock` shipping as a public helper for non-LatticeStripe users.** Currently private to users of this SDK. A general-purpose Stripe test-clock helper could be a separate Hex package. Not this milestone.
- **`:real_stripe_slow` tag for 5-minute tests.** Phase 17+ may need it for long subscription schedules. The tag system is additive — just add `@moduletag :real_stripe_slow` on top of `:real_stripe`. No refactor needed.
- **Customer / Subscription / Invoice fixture factories.** Explicitly rejected as scope creep (D-13e). Users compose on top of `test_clock` + `client` primitives.
- **Process-dict-scoped clock binding (`with_clock/2`).** Rejected (D-13h). If a future need emerges, revisit — but async-test safety is a hard constraint.
- **`stripe_test` as an `ExUnit.configure` preset.** Could ship a one-liner `LatticeStripe.Testing.configure()` that sets up excludes + timeout defaults. Consider in Phase 19 polish if real-world users request it.

</deferred>

---

*Phase: 13-billing-test-clocks*
*Context gathered: 2026-04-12*
*Research: 4 parallel gsd-advisor-researchers (naming, polling+errors, test helper library, real_stripe tier)*
