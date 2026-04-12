# Phase 13: Billing Test Clocks — Research

**Researched:** 2026-04-11
**Domain:** Stripe Billing Test Clocks SDK resource + ExUnit test helper library (Elixir)
**Confidence:** HIGH for codebase audit and ecosystem precedents; MEDIUM on stripe-mock runtime behaviour (documented as "hardcoded fixtures"; actual advance semantics must be confirmed by a probe task in Plan 01).

## Summary

Phase 13 is a **two-surface** phase: (a) a normal Stripe resource module (`LatticeStripe.TestHelpers.TestClock`) following the Phase 12 template exactly, plus (b) a user-facing ExUnit ergonomics library (`LatticeStripe.Testing.TestClock`) that has no precedent inside the repo but strong precedent in the Elixir ecosystem (Oban.Testing, Ecto.Sandbox). CONTEXT.md locks ~14 decisions; this research primarily answers the "what's actually in the codebase today" questions so the planner can scope the CaseTemplate wiring, the `Client` option addition, the `Error` struct extension, and the stripe-mock test surface correctly.

The codebase audit surfaces **four facts that change CONTEXT's shape slightly**:

1. `LatticeStripe.Error` already exists and already implements `Exception`, but its field schema is `type/code/message/status/request_id/param/decline_code/charge/doc_url/raw_body` — **not** the `type/message/details` shape D-13c describes. Phase 13 must extend the existing struct, not create it. The `:details` payload CONTEXT wants (`clock_id`, `last_status`, `elapsed_ms`) should land in `raw_body` (map), and the `:type` atom whitelist must be expanded to include `:test_clock_timeout` and `:test_clock_failed`. This is a **small, non-breaking extension**, not a new file.
2. `LatticeStripe.Client.new/1` validates options through `LatticeStripe.Config` (NimbleOptions schema) and does **not** support `:idempotency_key_prefix`. Adding it is straightforward (schema entry + `defstruct` field + `resolve_idempotency_key/2` branch), but it touches three files and wants its own wave-0 task with unit tests — not a smuggled-in detail of the TestClock resource.
3. **Nested namespaces already exist.** `LatticeStripe.Checkout.Session` lives at `lib/lattice_stripe/checkout/session.ex` and `LatticeStripe.Checkout.LineItem` at `lib/lattice_stripe/checkout/line_item.ex`. CONTEXT D-13a claims "Phase 13 introduces the first nested sub-product namespace" — that is **factually wrong** for the codebase as shipped. The decision itself (flat-core / nested-subproduct) is still sound, but `.planning/CONVENTIONS.md` must describe the existing Checkout nesting as the precedent, not "Phase 13 sets the precedent." Phase 13 merely extends it and writes down the rule.
4. **stripe-mock is documented as stateless with hardcoded responses.** It ships OpenAPI fixtures and will accept `POST /v1/test_helpers/test_clocks` + `/advance`, but the response body is a canned fixture — `status` field comes from the fixture, not from any stateful advancement. In practice this means `advance_and_wait`'s zero-delay first-poll branch (D-13b) is the ONLY branch exercised against stripe-mock. The polling/backoff loop, the `:advancing`-then-`:ready` transition, and the `:internal_failure` terminal path all get their coverage from (a) unit tests mocking the Transport behaviour via Mox, and (b) the single `:real_stripe` test in `test/real_stripe/test_clock_real_stripe_test.exs`.

**Primary recommendation:** Seven plans, three waves. Wave 0 = scaffolds (Error extension + Client option + test_paths + test/real_stripe scaffolding + CaseTemplate stub + CONVENTIONS.md). Wave 1 = SDK resource (struct + from_map + CRUD + advance + `advance_and_wait`/`!`). Wave 2 = user-facing helper (`Testing.TestClock` use-macro, Owner, Mix task) + `:real_stripe` round-trip test + docs.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-13a — Naming.**
- SDK resource: `LatticeStripe.TestHelpers.TestClock`. Not `BillingTestClock`, not `LatticeStripe.TestClock`, not `LatticeStripe.Billing.TestClock`.
- User-facing helper: `LatticeStripe.Testing.TestClock`. Parallel namespace — `TestHelpers` = SDK wrappers over `/test_helpers/*` API, `Testing` = ExUnit ergonomics.
- Rule codified in new `.planning/CONVENTIONS.md`: core billing resources (Customer, Product, Price, Coupon, Subscription, Invoice) stay flat under `LatticeStripe.*`; Stripe sub-product families (`TestHelpers`, `Connect`, `Issuing`, `Terminal`, `BillingPortal`, `Radar`, `Treasury`, `Identity`) nest. Phase 17 Connect will use `LatticeStripe.Connect.Account` / `.AccountLink` / `.Transfer`.

**D-13b — `advance_and_wait/3` polling strategy.**
- Exponential backoff with full jitter; initial 500ms, multiplier 1.5, cap 5_000ms; `:rand.uniform(delay)` per step.
- First poll happens with zero delay (catches stripe-mock + already-ready fixtures).
- Default timeout 60_000ms. Configurable via `opts[:timeout]`. Also accepts `:initial_interval`, `:max_interval`, `:multiplier` (un-prominent docs).
- Monotonic deadline via `System.monotonic_time(:millisecond)`.
- 500ms floor is non-negotiable even if user configures lower (Stripe rate-limit warning).

**D-13c — Error shape.**
- Return `{:error, %LatticeStripe.Error{}}`, not `{:error, :timeout}`.
- `LatticeStripe.Error` implements `Exception` (same value works for tuple returns and `raise/1`).
- CONTEXT spec: `type :: atom()`, `message :: String.t()`, `details :: map()`. **Codebase audit overrides this**: struct already has richer fields; see Codebase Audit #1 below. Phase 13 adds `:test_clock_timeout` and `:test_clock_failed` to the `:type` whitelist, stores clock context in `raw_body` (a map) with keys `clock_id`, `last_status`, `elapsed_ms`.
- Ship both `advance_and_wait/3` and `advance_and_wait!/3`; bang variant raises the same `%Error{}`.
- `internal_failure` is terminal — first poll returning `"internal_failure"` immediately returns `{:error, %Error{type: :test_clock_failed}}`, no retry.
- Telemetry: `[:lattice_stripe, :test_clock, :advance_and_wait, :start | :stop]` with `%{status:, attempts:, duration:}`. Peer of `[:lattice_stripe, :request, :*]`, not a replacement.
- BILL-08b text to be amended to use struct shape.

**D-13d — `Testing.TestClock` public API.**
- `use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient` — Oban.Testing-style compile-time client binding, used **inside** the user's own CaseTemplate (typically `MyApp.StripeCase`). Not a CaseTemplate itself.
- Compile-time validation of `:client` option; missing/non-module = `CompileError`.
- Per-call client override: every helper accepts `client:` opt that wins over the compile-time binding.
- Imported helper surface (exactly this):
  - `test_clock/1` — create clock, register for cleanup. Opts: `:frozen_time`, `:name`, `:metadata`.
  - `advance/2` — advance clock and wait for `:ready`. `unit_opts` like `[days: 30]`, `[months: 1]`, `[to: ~U[...]]`. Wraps `TestHelpers.TestClock.advance_and_wait!/3`.
  - `freeze/1` — waits for current clock state to reach `:ready` (no advancement).
  - `create_customer/3` — wraps `LatticeStripe.Customer.create/2`, auto-injects `test_clock: clock.id`.
  - `with_test_clock/1` — ExUnit setup callback, returns `%{test_clock: clock}` in context.
- Canonical happy-path example (CONTEXT lines 66–87) is the contract. Any decision that makes it uglier is wrong.

**D-13e — Scope discipline.**
- Helper owns: clock lifecycle, clock advancement, ONE customer wrapper (`create_customer/3`).
- Helper does NOT own: Subscription/Invoice/Price/Product factories. Users layer ExMachina or plain functions on top.
- Narrow like `Ecto.Sandbox`, not broad like `ExMachina`.

**D-13f — Cleanup.**
- Primary: ExUnit `Owner` pattern via `start_owner!` + `on_exit`. Lightweight per-test `GenServer` owner tracks created clocks; `on_exit` calls `DELETE /v1/test_helpers/test_clocks/:id` on each. Stripe cascades to attached customers and subs.
- NOT `start_supervised!/1` — `on_exit` runs even when test pid crashes.
- Backstop: `mix lattice_stripe.test_clock.cleanup` with `--dry-run`, `--older-than 1h` (default), `--client` (module or Application env key). Reads Stripe, filters by metadata marker, deletes matching. Detects stripe-mock via base_url and no-ops.
- Shared deletion core: both paths call `LatticeStripe.TestHelpers.TestClock.cleanup_tagged/2`.

**D-13g — Tagging marker.**
- Metadata key `"lattice_stripe_test_clock"`, value `"v1"`. Stored as `@cleanup_marker {"lattice_stripe_test_clock", "v1"}` module attribute in `LatticeStripe.Testing.TestClock`.
- Merged into user-supplied metadata at clock creation in `test_clock/1`. Never touches clock `name`.
- Public stable API — changing key or value is a breaking change.
- Versioning: Mix task must always match `"v1"` and `"v2"` (future) tagged clocks.
- Metadata-limit guard: if user metadata + marker > 50 keys, raise `Testing.TestClockError` (or similar) — never silently drop the marker.

**D-13h — Customer ↔ clock linkage.**
- `create_customer/3` auto-injects `test_clock: clock.id`. Closes silent-correctness footgun.
- Process-dict scope rejected (breaks async, nested describes).
- Users calling `LatticeStripe.Customer.create/2` directly are on their own — document explicitly.

**D-13i — `:real_stripe` test tier.**
- NEW orthogonal tag `:real_stripe`. NOT nested under `:integration`. Running both: `mix test --include integration --include real_stripe`.
- `ExUnit.configure(exclude: [:integration, :real_stripe])` in `test/test_helper.exs`.
- Directory: `test/real_stripe/*_test.exs`. Added to `test_paths` in `mix.exs` under `:test` env.
- CaseTemplate: `LatticeStripe.Testing.RealStripeCase` in `test/support/real_stripe_case.ex`. Internal only.
- CaseTemplate applies: `@moduletag :real_stripe`, `@moduletag timeout: 120_000`, `async: false` implicit.
- `setup_all` behaviour:
  - No key + no `CI` → `{:skip, ...}`.
  - No key + `CI=true` → `flunk(...)`.
  - Key starts with `sk_live_` → `flunk(...)` (non-negotiable safety guard).
  - Key starts with `sk_test_` → build `LatticeStripe.Client`, inject into context as `client`.
  - Otherwise → `flunk(...)`.
- Per-test idempotency prefix: `LatticeStripe.Client.new(api_key: key, idempotency_key_prefix: "lattice-test-#{System.system_time(:millisecond)}-")`. **New option — see Codebase Audit #2.**
- Canonical first test: `test/real_stripe/test_clock_real_stripe_test.exs` — create, advance 30 days, assert `:ready`, assert marker, delete.

**D-13j — Secret handling.**
- Env var only: `STRIPE_TEST_SECRET_KEY`. No Mix config, no `dotenv` dep.
- `CONTRIBUTING.md` documents `direnv` + `.envrc`.
- `.envrc` added to `.gitignore`.
- CI: GitHub Actions repo secret → job env var.

### Claude's Discretion

- Internal module layout of the `Owner` GenServer (inline in `Testing.TestClock` vs separate file).
- Whether `cleanup_tagged/2` lives on `TestHelpers.TestClock` or a separate `TestHelpers.TestClock.Cleanup` submodule.
- `advance/2`'s `unit_opts` parser — DateTime shift direct vs `Date.shift` routing. Caller cares only that `days: 30` and `to: ~U[...]` both work.
- Exact wording of `Testing.TestClockError` messages.
- Mix task progress output: `Mix.shell().info/1` vs `IO.puts/1`.
- Property-test coverage for metadata merging (nice-to-have, not load-bearing).

### Deferred Ideas (OUT OF SCOPE)

- Webhook-driven clock advancement notifications.
- Publishing `Testing.TestClock` as a standalone Hex package.
- `:real_stripe_slow` tag for 5-minute tests (Phase 17+).
- Customer/Subscription/Invoice fixture factories (D-13e).
- Process-dict-scoped clock binding (`with_clock/2`).
- `LatticeStripe.Testing.configure()` ExUnit preset (Phase 19 polish).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BILL-08 | SDK resource `LatticeStripe.TestHelpers.TestClock` with create/retrieve/list/stream/delete/advance | Direct Phase 12 template copy (Product/Price shape). Stripe API paths `POST /v1/test_helpers/test_clocks`, `GET /v1/test_helpers/test_clocks/:id`, `GET /v1/test_helpers/test_clocks`, `DELETE /v1/test_helpers/test_clocks/:id`, `POST /v1/test_helpers/test_clocks/:id/advance`. No `/search`. |
| BILL-08b | `advance_and_wait/3` polls until `:ready`, returns struct error on timeout or `:internal_failure` | D-13b polling strategy + D-13c error shape. Monotonic deadline + full-jitter backoff + zero-delay first poll + 500ms floor. |
| BILL-08c | `advance_and_wait!/3` bang variant raises `LatticeStripe.Error` | D-13c. Same `%Error{}` value — works for both tuple and raise. |
| TEST-09 | User-facing `LatticeStripe.Testing.TestClock` helper library | D-13d–D-13h. `use` macro, Owner cleanup, metadata marker, customer wrapper, Mix task backstop. |
| TEST-10 | `:real_stripe` test tier established; first clock-advancement round-trip test against live Stripe test mode | D-13i–D-13j. `RealStripeCase` + `test/real_stripe/test_clock_real_stripe_test.exs`. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Constraint | Source | Impact on Phase 13 |
|------------|--------|--------------------|
| Elixir >= 1.15, OTP >= 26 | Platform Target | `advance_and_wait` must compile on 1.15. `Date.shift/2` was added in 1.17 — **flag**: if `unit_opts` uses `Date.shift`, guard or route through manual calculation. Use `DateTime.add/3` (available since 1.0) for second-resolution shifts. Months are tricky — see Pitfalls. |
| No Dialyzer | Constraints | Typespecs documentation-only. `:known \| String.t()` unions are fine. |
| Minimal deps | Constraints | **Zero new runtime deps**. Zero new test deps. All Phase 13 functionality builds on existing Finch/Jason/Telemetry/Mox/stream_data. |
| Jason for JSON | Stack | TestClock `from_map/1` consumes string-keyed maps. |
| Finch default transport | Stack | No transport changes. `:real_stripe` tests reuse `LatticeStripe.IntegrationFinch` pool (or a new `RealStripeFinch` pool — planner decides). |
| GSD workflow enforcement | CLAUDE.md | Planner must use `/gsd-plan-phase` and `/gsd-execute-phase`. |
| Forbidden tools | "What NOT to Use" | No HTTPoison, Poison, Tesla, Req, ExVCR, Bypass, Ecto, GenServer-for-state, Dialyzer. **Exception**: the `Testing.TestClock.Owner` GenServer is NOT "GenServer for state" — it's a per-test ExUnit ownership pattern mirroring `Ecto.Adapters.SQL.Sandbox`. This is the intended idiomatic use. |
| Credo `--strict` | `mix.exs` aliases | `Testing.TestClock` `use` macro will likely trigger `Credo.Check.Readability.LargeNumbers` and `Credo.Check.Refactor.LongQuoteBlocks` — pre-approve `credo:disable-for-next-line` annotations rather than reshape for arbitrary limits. |
| `format --check-formatted` | aliases | All new files must pass `mix format`. |
| `compile --warnings-as-errors` | aliases | No unused aliases. |
| `docs --warnings-as-errors` | aliases | All `@doc`s must render — especially the moduledoc happy-path example. |

## Codebase Audit

Answers to the nine discovery questions asked in the research brief.

### 1. `LatticeStripe.Error` — exists, shape differs from CONTEXT

**File:** `lib/lattice_stripe/error.ex` (lines 1–162).

**Status:** Exists. Implements `Exception` via `defexception`. Implements `String.Chars` (line 157). Has a `message/1` callback that composes `(type)` + status + code + message + request_id.

**Actual fields (line 30–41):**
```elixir
defexception [
  :type, :code, :message, :status, :request_id,
  :param, :decline_code, :charge, :doc_url, :raw_body
]
```

**Current `:type` whitelist (line 56–63):**
```
:card_error | :invalid_request_error | :authentication_error |
:rate_limit_error | :api_error | :idempotency_error | :connection_error
```

**Current `parse_type/1` (line 148–154):** closed mapping from Stripe string types; unknown types fall through to `:api_error`.

**Delta vs CONTEXT D-13c:**
- CONTEXT says field schema is `type :: atom(), message :: String.t(), details :: map()`. **Wrong for this codebase** — struct is richer.
- `:details` does not exist. The closest field is `:raw_body` (`map() | nil`), which already serves as an escape hatch for arbitrary structured context. TestClock context (`clock_id`, `last_status`, `elapsed_ms`) goes into `raw_body` as a map.
- `:type` whitelist must be **extended**, not replaced: add `:test_clock_timeout` and `:test_clock_failed`. This is source-breaking for any downstream code that pattern-matches `type` against the closed list, but since the SDK hasn't shipped `LatticeStripe.Error` to end-users as a sealed union (the typedoc says "see Stripe error types doc" — descriptive, not prescriptive), the extension is safe.
- `parse_type/1` does NOT need updating — it only runs on HTTP responses, never on locally-constructed errors. TestClock errors are constructed directly via `%LatticeStripe.Error{type: :test_clock_timeout, ...}`.

**Proposed change (small, non-breaking):**
1. Extend `@type error_type` union to include `:test_clock_timeout` and `:test_clock_failed`.
2. Update typedoc to document the new types.
3. No `parse_type/1` change.
4. No new field.
5. Unit test asserts constructing + raising the new types works and produces sensible `Exception.message/1` output.

**Confidence:** HIGH — verified from `error.ex` lines 1–162.

### 2. `LatticeStripe.Client.new/1` — no `:idempotency_key_prefix` option

**File:** `lib/lattice_stripe/client.ex` (lines 118–142), `lib/lattice_stripe/config.ex` (lines 31–90).

**Status:** Client is built via `struct!(__MODULE__, validated)` where `validated` comes from `LatticeStripe.Config.validate!/1` (NimbleOptions schema, `config.ex` line 31–90). The schema does NOT include `:idempotency_key_prefix`. `Client` struct (line 52–64) has 13 fields; none is an idempotency prefix.

**Idempotency key flow (client.ex line 242–265):** `resolve_idempotency_key/2` runs per-request, returning user's `opts[:idempotency_key]` if present, else auto-generating `"idk_ltc_" <> uuid4()` for POST, else `nil`. No prefix hook exists anywhere.

**To add `:idempotency_key_prefix` (D-13i):**
1. Add `idempotency_key_prefix: [type: :string, default: nil, ...]` to `Config.@schema`.
2. Add `:idempotency_key_prefix` to `defstruct` in `client.ex` (line 52).
3. Extend `@type t` typedoc accordingly.
4. In `resolve_idempotency_key/2`, honour the prefix when auto-generating: `(client.idempotency_key_prefix || "idk_ltc_") <> uuid4()`. Note: this requires passing the client (or just the prefix) through to the resolver — currently it takes only `method` and `opts`. Threading the prefix through `request/2` is a 3-line change.
5. **Preserve existing contract**: user-supplied `opts[:idempotency_key]` still wins unconditionally (auto-prefix only applies to auto-generated keys). CONTEXT D-13i's expected usage is consistent with this.
6. Unit tests: (a) prefix applied when set, (b) default `idk_ltc_` applied when unset, (c) user-supplied `:idempotency_key` ignores prefix.

**Recommendation:** Make this a distinct Plan 01 task (not smuggled into Plan 04 where it's first USED by `RealStripeCase`). The change is small and self-contained, but it touches three files and a public `Config` schema — wants its own RED/GREEN commit.

**Confidence:** HIGH — verified from `client.ex` lines 118–280 and `config.ex` lines 31–90.

### 3. `@known_fields` + `from_map/1` + `extra: %{}` pattern

**File:** `lib/lattice_stripe/product.ex` (lines 51–56, 59–84, 397–425).

**Exact pattern:**

```elixir
# Module attribute: known top-level fields as a space-separated sigil list.
@known_fields ~w[
  id object active attributes caption created default_price deleted
  ...
]

# defstruct: enumerate all known fields as atoms; object: has a default
# string ("product"); deleted: false; extra: %{} is the catch-all.
defstruct [
  :id, :active, ..., :url,
  object: "product",
  deleted: false,
  extra: %{}
]

# from_map/1: enumerate each known field via map["key"], pass the type
# field through an atomize_type/1 helper (whitelist + forward-compat
# string pass-through), and compute extra: Map.drop(map, @known_fields).
def from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    object: map["object"] || "product",
    ...,
    type: atomize_type(map["type"]),
    ...,
    deleted: map["deleted"] || false,
    extra: Map.drop(map, @known_fields)
  }
end

# Atomization: closed whitelist + nil + string fallthrough + catch-all.
defp atomize_type("good"), do: :good
defp atomize_type("service"), do: :service
defp atomize_type(nil), do: nil
defp atomize_type(other) when is_binary(other), do: other
defp atomize_type(other), do: other
```

**TestClock applies this verbatim.** Stripe Test Clock object fields (per `https://docs.stripe.com/api/test_clocks/object`):
- `id` (string)
- `object` ("test_helpers.test_clock")
- `created` (integer, unix timestamp)
- `deletes_after` (integer, unix timestamp) — cleanup deadline Stripe imposes
- `frozen_time` (integer, unix timestamp)
- `livemode` (boolean)
- `name` (string or null)
- `status` (enum: `advancing | internal_failure | ready`)
- `metadata` — NOT present on test_clock per current API docs (verify in Plan 02 — if absent, omit from `@known_fields`)
- `status_details` — newer field, may or may not be present (verify)

`object` default: `"test_helpers.test_clock"`. `deleted` follows Phase 12 pattern. `extra: %{}` catches anything not enumerated.

**Atomization — `status` field (per D-03):**

```elixir
defp atomize_status("ready"), do: :ready
defp atomize_status("advancing"), do: :advancing
defp atomize_status("internal_failure"), do: :internal_failure
defp atomize_status(nil), do: nil
defp atomize_status(other) when is_binary(other), do: other
defp atomize_status(other), do: other
```

Typespec: `status: :ready | :advancing | :internal_failure | String.t() | nil`.

**Note:** CONTEXT mentions "metadata merging" for the Testing helper's `test_clock/1` wrapper. Stripe's Test Clock API does **not** document `metadata` as a supported field on the test_clock object itself (unlike most Stripe resources). **This is a Plan 02 verification task**: hit the live API / OpenAPI spec and confirm whether `metadata` is accepted on `POST /v1/test_helpers/test_clocks`. If metadata IS supported (likely — Stripe has been adding it everywhere), the marker lives there. If NOT supported, the Testing helper must track the `clock_id → marker` association in the `Owner` GenServer and the Mix task cleanup strategy becomes "delete all test clocks older than X" instead of "delete by metadata marker" — a significant change to D-13g. **FLAG for planner.**

**Confidence:** HIGH for pattern, MEDIUM for TestClock field list (docs reference), LOW for metadata-supported question (must verify).

### 4. `Resource.unwrap_singular / unwrap_list / unwrap_bang!`

**File:** `lib/lattice_stripe/resource.ex` (lines 52–116).

**Pattern:**

```elixir
# Singular — POST/GET/:id path
%Request{method: :post, path: "/v1/test_helpers/test_clocks", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)

# List — GET without :id
%Request{method: :get, path: "/v1/test_helpers/test_clocks", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_list(&from_map/1)

# Bang — pipe through unwrap_bang!
def create!(%Client{} = client, params \\ %{}, opts \\ []) do
  create(client, params, opts) |> Resource.unwrap_bang!()
end
```

`unwrap_singular` returns `{:ok, struct} | {:error, %Error{}}`. `unwrap_list` returns `{:ok, %Response{data: %List{data: [struct, ...]}}} | {:error, %Error{}}`. `unwrap_bang!` unwraps or raises. Pattern applies verbatim to TestClock CRUD.

**Delete follows same pattern** (returns a `%TestClock{deleted: true}` with only id/deleted fields populated — Stripe's delete response shape).

**Advance endpoint is a singular POST with non-empty body:**
```elixir
%Request{method: :post, path: "/v1/test_helpers/test_clocks/#{id}/advance", params: %{frozen_time: ts}, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)
```

Returns the updated `%TestClock{}` with `status: :advancing` (typically).

**Confidence:** HIGH.

### 5. D-03 atomization helper pattern

Same as the `atomize_type/1` helper shown in question 3. Every module defines private `atomize_*` helpers; no shared helper module. TestClock defines `atomize_status/1` locally in `lib/lattice_stripe/test_helpers/test_clock.ex`.

**Confidence:** HIGH — verified in `product.ex` line 428–432, same pattern in `price.ex`, `coupon.ex` per Phase 12 research.

### 6. stripe-mock support for test clocks

**Facts:**
- stripe-mock is **OpenAPI-driven**: every endpoint the Stripe OpenAPI spec defines is accepted, including `/v1/test_helpers/test_clocks/*`. `[VERIFIED: github.com/stripe/stripe-mock README — "powered by the Stripe OpenAPI specification"]`
- stripe-mock is **stateless with hardcoded fixtures**: responses come from the OpenAPI `x-resourceId` fixtures. `"stripe-mock is stateless. Data you send on a POST request will be validated, but it will be completely ignored beyond that."` `[CITED: github.com/stripe/stripe-mock README]`
- Practical implication for `advance_and_wait`: a `POST /advance` call returns a canned fixture. The fixture's `status` is whatever Stripe shipped in the OpenAPI sample — almost certainly `"ready"` (it's the happiest-path sample). **Zero-delay first poll returns `:ready` immediately. The backoff loop is NEVER exercised against stripe-mock.**
- Unit coverage of the backoff loop is done via Mox on the Transport behaviour: return `:advancing` 3 times, then `:ready`, and assert the loop terminates with the expected attempt count.
- Real coverage of the backoff loop is done in `test/real_stripe/test_clock_real_stripe_test.exs` — one test, gated by `STRIPE_TEST_SECRET_KEY`, asserts the round trip.
- **Plan 01 probe task**: hit stripe-mock at `http://localhost:12111/v1/test_helpers/test_clocks` with `curl -X POST -u sk_test_123: -d frozen_time=$(date +%s)` to confirm (a) the endpoint exists and returns 200, (b) the response body is a well-formed test_clock JSON, (c) the `status` field's value (expect `"ready"`). Capture output for the research appendix. This de-risks the integration-test wave.

**Workaround pattern for integration tests that want to exercise polling behaviour against stripe-mock:** NONE needed — integration tests assert request encoding, URL paths, header propagation, and response decoding. They do NOT assert polling timing. The Mox unit tests own that.

**Confidence:** MEDIUM for test_clocks-specifically (OpenAPI fixtures are auto-generated and I haven't inspected the shipped binary's fixture for this endpoint). HIGH for "stripe-mock is stateless and cannot simulate advancement progression." `[CITED: github.com/stripe/stripe-mock README]`

### 7. Existing `:integration` tag setup

**File:** `test/test_helper.exs` (all 10 lines):
```elixir
ExUnit.start()
ExUnit.configure(exclude: [:integration])

# Transport mock for testing Client.request/2 without real HTTP
Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)
Mox.defmock(LatticeStripe.MockJson, for: LatticeStripe.Json)
Mox.defmock(LatticeStripe.MockRetryStrategy, for: LatticeStripe.RetryStrategy)
```

**Delta:** Add `:real_stripe` to the exclusion list. One-line change:

```elixir
ExUnit.configure(exclude: [:integration, :real_stripe])
```

**mix.exs also needs a `test_paths` entry** — currently absent. Default `test_paths` is `["test"]`, which already picks up `test/real_stripe/*` because it's under `test/`. **But** the `test/real_stripe/` directory doesn't exist yet, and the wave-0 task needs to create it AND decide whether to explicitly list `test_paths: ["test"]` (no change) or split into `test_paths: ["test", "test/real_stripe"]` (also redundant because it's nested). **Recommendation**: do NOT change `test_paths`. The default `["test"]` already covers `test/real_stripe/` due to recursive discovery. CONTEXT line 120 ("Added to `test_paths` in `mix.exs`") is over-specified — it's unnecessary. Flag for planner confirmation.

**Confidence:** HIGH — verified from `test_helper.exs` (all 10 lines) and `mix.exs` (line 130).

### 8. `test/support/` in `elixirc_paths(:test)`

**File:** `mix.exs` line 130:
```elixir
defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]
```

`test/support/` already exists and already contains `test_helpers.ex` (62 lines — defines `LatticeStripe.TestHelpers` module at `@moduledoc false` — see Note below) and a `fixtures/` subdir.

**⚠ Naming collision risk:** There is already a `LatticeStripe.TestHelpers` module at `test/support/test_helpers.ex`. It's `@moduledoc false` (internal test-only), not shipped in `lib/`. Phase 13 wants to ship `LatticeStripe.TestHelpers.TestClock` at `lib/lattice_stripe/test_helpers/test_clock.ex`. **Elixir allows nesting a submodule under a parent module that exists in a different application path** — `LatticeStripe.TestHelpers` (test-only) and `LatticeStripe.TestHelpers.TestClock` (library) will not conflict at compile time because they live in different compilation paths and the parent module is not `use`d by the child. But they share a namespace in ExDoc and HexDocs.

**Two options:**
1. **Rename the test-only module** to `LatticeStripe.TestSupport` or `LatticeStripe.Test.Helpers`. Touches every integration test (`test/integration/*.exs`) that imports/aliases `LatticeStripe.TestHelpers`. Safer for documentation.
2. **Leave as-is.** Elixir will compile both without conflict (they're technically different modules at different fully-qualified paths only if the test-only one is renamed… wait, they're actually the SAME atom — `Elixir.LatticeStripe.TestHelpers`). **Re-check:** both define `LatticeStripe.TestHelpers`. That's a genuine conflict.

**Actual conflict:** `test/support/test_helpers.ex` line 1 = `defmodule LatticeStripe.TestHelpers do`. If Phase 13 adds `lib/lattice_stripe/test_helpers.ex` with the same module name (or doesn't and only defines `LatticeStripe.TestHelpers.TestClock`), Elixir will compile both files and produce DIFFERENT modules:
- `lib/lattice_stripe/test_helpers/test_clock.ex` = `LatticeStripe.TestHelpers.TestClock` (a fully-qualified submodule, no parent needed)
- `test/support/test_helpers.ex` = `LatticeStripe.TestHelpers` (a separate atom)

Elixir **does not require a parent module to exist for a submodule**. `defmodule LatticeStripe.TestHelpers.TestClock do ... end` is valid even if `LatticeStripe.TestHelpers` is undefined. So Phase 13 can ship `LatticeStripe.TestHelpers.TestClock` WITHOUT creating `LatticeStripe.TestHelpers`, and the existing test-only `LatticeStripe.TestHelpers` in `test/support/` will continue to compile and function fine in the `:test` env.

**But ExDoc.** `groups_for_modules` in `mix.exs` (line 40–80) explicitly lists modules. `LatticeStripe.TestHelpers.TestClock` must be added to a group (probably a new "Test Helpers" group or into "Telemetry & Testing"). The existing `LatticeStripe.TestHelpers` is test-only and won't appear in ExDoc because `elixirc_paths(:dev)` returns `["lib"]` without `test/support`.

**Recommendation:** Rename `test/support/test_helpers.ex`'s module to `LatticeStripe.TestSupport` as a **Plan 01 micro-task**. Reasons: (a) avoids confusion for future contributors, (b) frees the `LatticeStripe.TestHelpers` namespace for a potential future root module if one is ever needed, (c) integration tests that alias `LatticeStripe.TestHelpers, as: TH` need only a one-line update per file (there are ~10 such files). Low cost, high clarity. Planner decides.

**Confidence:** HIGH — verified from `mix.exs` line 130 and `test/support/test_helpers.ex`.

### 9. Telemetry event pattern

**File:** `lib/lattice_stripe/telemetry.ex` (lines 305–319, 375–382).

**Pattern for direct `:telemetry.execute/3`:**

```elixir
# From emit_retry/6 (line 304–319):
:telemetry.execute(
  @retry_event,
  %{attempt: attempt, delay_ms: delay_ms},
  %{method: method, path: extract_path(url), error_type: error.type, status: error.status}
)
```

**Pattern for `:telemetry.span/3` (preferred for `advance_and_wait`):**

```elixir
# From request_span/4 (line 277–291):
:telemetry.span(
  [:lattice_stripe, :test_clock, :advance_and_wait],
  %{clock_id: clock_id, timeout: timeout},
  fn ->
    result = do_poll_loop(...)
    stop_meta = %{status: extract_status(result), attempts: attempt_count, duration: :erlang.monotonic_time() - started_at}
    {result, stop_meta}
  end
)
```

`:telemetry.span/3` auto-injects `telemetry_span_context` and emits `:start`, `:stop`, `:exception`. Matches the existing convention in `Client.request/2`.

**Recommendation:** Use `:telemetry.span/3` in `advance_and_wait/3` (not manual `:telemetry.execute/3`). Add a `@doc false` helper `poll_span/3` in `TestHelpers.TestClock` that wraps the poll loop if telemetry is enabled (honour `client.telemetry_enabled` flag — see `request_span/4` line 274).

**Event name:** `[:lattice_stripe, :test_clock, :advance_and_wait]` per D-13c. Distinct prefix from `[:lattice_stripe, :request, ...]`. **However**, each INDIVIDUAL `POST /advance` and `GET /retrieve` call inside the poll loop will ALSO emit `[:lattice_stripe, :request, :start | :stop]` via the existing `Client.request/2` pipeline. That's desirable — users can correlate the outer `advance_and_wait` span with the inner per-request spans via `telemetry_span_context`.

**Metadata to emit on `:stop`:**
- `:status` — final observed status (`:ready`, `:internal_failure`, or `:timeout` as atoms)
- `:attempts` — total poll attempts (including the zero-delay first)
- `:clock_id` — for correlation
- `:duration` — auto-added by `:telemetry.span/3` as measurement
- `:outcome` — `:ok | :error` (mirrors `request_span`'s convention)

**Confidence:** HIGH — verified from `telemetry.ex` lines 252–320.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir >= 1.15 | All code | existing project constraint | mix.exs line 11 (`~> 1.15`) | — |
| OTP >= 26 | All code | existing project constraint | — | — |
| `finch` `~> 0.19` | HTTP transport | present (`mix.exs` line 100) | — | — |
| `jason` `~> 1.4` | JSON codec | present | — | — |
| `telemetry` `~> 1.0` | Span emission | present | — | — |
| `nimble_options` `~> 1.0` | Config schema extension | present | — | — |
| `mox` `~> 1.2` | Transport mock unit tests | present (test-only) | — | — |
| `stream_data` `~> 1.1` | Property tests (optional) | present (test-only) | — | — |
| `stripe-mock` Docker | Integration tests | Plan 01 probe task verifies | — | Unit tests via Mox cover resource CRUD encoding; `:real_stripe` covers runtime |
| `STRIPE_TEST_SECRET_KEY` env var | `:real_stripe` tier | Dev-time via `direnv`; CI via GitHub Actions secret | — | `setup_all` skips when unset (non-CI) or flunks (CI) per D-13i |

**No new Hex dependencies required.** Zero runtime dep additions, zero test dep additions.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| (none added) | — | Phase 13 adds zero new deps | Same as Phase 12. Existing Finch/Jason/Telemetry/Mox/stream_data cover everything. |

### Supporting
Not applicable.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled Owner GenServer | `ExUnit.Callbacks.on_exit/1` alone | `on_exit` alone can't track state (the list of clock ids) across a test — need a process or an Agent. Using bare `Process.put/2` would survive within the test pid but not across nested `setup`s. A lightweight per-test GenServer is the Ecto.Sandbox precedent and the right primitive. |
| Hand-rolled Owner GenServer | `Agent` | `Agent` is a GenServer with less boilerplate. Valid alternative. Planner's call. Ecto.Sandbox uses a full `GenServer`; mirror that for pattern-recognition. |
| Hand-rolled Owner GenServer | `ETS table with test-pid key` | Works, but ETS visibility issues across tests and requires manual cleanup. GenServer is cleaner. |
| `:timer.send_after` for backoff | `Process.sleep/1` | `Process.sleep` is synchronous and simpler inside a poll loop. `send_after` needs a message handler and complicates the control flow. Use `Process.sleep`. Existing `Client.request/2` retry loop uses `Process.sleep` (client.ex line 369) — follow precedent. |
| `:telemetry.span/3` | Manual `:telemetry.execute/3` pair | `span/3` auto-injects span context and handles exceptions. Client request pipeline uses `span/3` (telemetry.ex line 278). Follow precedent. |
| `Date.shift/2` for month shifts | Manual calendar math | `Date.shift/2` was added in Elixir 1.17. Project minimum is 1.15. **Cannot use `Date.shift/2`.** Use `DateTime.add/3` for days/hours (`days: 30` → `DateTime.add(dt, 30 * 86400, :second)`) and hand-rolled month math for `months: N` (approximate as `30 * N * 86400` OR parse year/month and increment — see Pitfalls). Or: accept only `:seconds`, `:minutes`, `:hours`, `:days`, and `:to` (DateTime); reject months/years with a compile-time error. **Recommendation**: support `seconds`, `minutes`, `hours`, `days`, `to` only in v1; defer `months`/`years` to a later milestone after establishing Elixir 1.17 as minimum. Flag CONTEXT D-13d's `[months: 1]` example — it's reachable via `[to: DateTime.utc_now() \|> add months]` but not via a `months:` keyword directly. |

## Architecture Patterns

### Recommended File Layout

```
lib/lattice_stripe/
├── error.ex                         # MODIFIED: @type error_type adds :test_clock_timeout, :test_clock_failed
├── config.ex                        # MODIFIED: :idempotency_key_prefix schema entry
├── client.ex                        # MODIFIED: :idempotency_key_prefix struct field + resolve_idempotency_key/2 prefix branch
└── test_helpers/
    └── test_clock.ex                # NEW: resource module (struct, from_map, CRUD, advance, advance_and_wait, cleanup_tagged)

lib/lattice_stripe/testing/
├── test_clock.ex                    # NEW: use-macro helper library
├── test_clock/
│   ├── owner.ex                     # NEW: per-test cleanup GenServer (or inline in test_clock.ex — Claude's discretion per CONTEXT)
│   └── error.ex                     # NEW: LatticeStripe.Testing.TestClockError exception
└── real_stripe_case.ex              # NOT here — this lives in test/support/

lib/mix/tasks/
└── lattice_stripe.test_clock.cleanup.ex    # NEW: Mix task backstop

test/support/
├── test_helpers.ex                  # MAYBE RENAMED to test_support.ex → LatticeStripe.TestSupport (Plan 01 decision)
└── real_stripe_case.ex              # NEW: LatticeStripe.Testing.RealStripeCase CaseTemplate

test/lattice_stripe/test_helpers/
└── test_clock_test.exs              # NEW: unit tests (Mox-based)

test/lattice_stripe/testing/
├── test_clock_test.exs              # NEW: use-macro + Owner + cleanup tests (Mox-based)
└── test_clock_mix_task_test.exs     # NEW: Mix task --dry-run tests

test/integration/
└── test_clock_integration_test.exs  # NEW: stripe-mock CRUD encoding + response decoding (no polling assertions)

test/real_stripe/
└── test_clock_real_stripe_test.exs  # NEW: THE canonical first :real_stripe test

.planning/
└── CONVENTIONS.md                   # NEW: flat-core / nested-subproduct rule

CONTRIBUTING.md                      # NEW or EXTENDED: direnv + .envrc workflow
.gitignore                           # MAYBE MODIFIED: add .envrc if missing
```

### Pattern 1: SDK Resource Module (`LatticeStripe.TestHelpers.TestClock`)

Copy Phase 12's Product template verbatim. Path `/v1/test_helpers/test_clocks`, object name `"test_helpers.test_clock"`, no search, yes delete, plus `advance/3` and `advance_and_wait/3` as extra verbs.

```elixir
defmodule LatticeStripe.TestHelpers.TestClock do
  @moduledoc """
  Operations on Stripe Test Clock objects.

  Test Clocks let you simulate the passage of time in Stripe test mode —
  useful for exercising subscription renewals, invoice cycles, and billing
  lifecycle events without waiting real-world time. ...
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object created deletes_after frozen_time livemode name status status_details
  ]

  defstruct [
    :id, :created, :deletes_after, :frozen_time, :livemode, :name, :status, :status_details,
    object: "test_helpers.test_clock",
    deleted: false,
    extra: %{}
  ]

  @type t :: %__MODULE__{
    id: String.t() | nil,
    object: String.t(),
    created: integer() | nil,
    deletes_after: integer() | nil,
    frozen_time: integer() | nil,
    livemode: boolean() | nil,
    name: String.t() | nil,
    status: :ready | :advancing | :internal_failure | String.t() | nil,
    status_details: map() | nil,
    deleted: boolean(),
    extra: map()
  }

  # CRUD — create/retrieve/list/stream!/delete — standard pipeline
  def create(%Client{} = client, params \\ %{}, opts \\ []), do: ...
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id), do: ...
  def list(%Client{} = client, params \\ %{}, opts \\ []), do: ...
  def stream!(%Client{} = client, params \\ %{}, opts \\ []), do: ...
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id), do: ...

  # Advance — POST /v1/test_helpers/test_clocks/:id/advance
  @spec advance(Client.t(), String.t(), integer(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def advance(%Client{} = client, id, frozen_time, opts \\ []) when is_binary(id) and is_integer(frozen_time) do
    %Request{
      method: :post,
      path: "/v1/test_helpers/test_clocks/#{id}/advance",
      params: %{"frozen_time" => frozen_time},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # Advance and poll until status is :ready
  @spec advance_and_wait(Client.t(), String.t(), integer(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def advance_and_wait(%Client{} = client, id, frozen_time, opts \\ []) do
    # see Pattern 2
  end

  def advance_and_wait!(...) do
    case advance_and_wait(...) do
      {:ok, clock} -> clock
      {:error, %Error{} = e} -> raise e
    end
  end

  # Bang variants, from_map/1, atomize_status/1 — standard Phase 12 shape
end
```

### Pattern 2: `advance_and_wait/3` Poll Loop

```elixir
def advance_and_wait(%Client{} = client, id, frozen_time, opts \\ []) do
  timeout = Keyword.get(opts, :timeout, 60_000)
  initial = max(Keyword.get(opts, :initial_interval, 500), 500)  # 500ms floor
  max_int = Keyword.get(opts, :max_interval, 5_000)
  mult = Keyword.get(opts, :multiplier, 1.5)

  deadline = System.monotonic_time(:millisecond) + timeout

  LatticeStripe.Telemetry.advance_and_wait_span(client, id, timeout, fn ->
    with {:ok, _advancing} <- advance(client, id, frozen_time, opts) do
      poll_until_ready(client, id, deadline, initial, max_int, mult, opts, _attempts = 0)
    end
  end)
end

defp poll_until_ready(client, id, deadline, delay, max_int, mult, opts, attempts) do
  # Zero-delay first poll (D-13b)
  case retrieve(client, id, opts) do
    {:ok, %__MODULE__{status: :ready} = clock} ->
      {:ok, clock}

    {:ok, %__MODULE__{status: :internal_failure}} ->
      {:error, %Error{
        type: :test_clock_failed,
        message: "Test clock #{id} entered internal_failure state",
        raw_body: %{"clock_id" => id, "last_status" => "internal_failure", "attempts" => attempts + 1}
      }}

    {:ok, %__MODULE__{status: status}} ->
      now = System.monotonic_time(:millisecond)
      if now >= deadline do
        {:error, %Error{
          type: :test_clock_timeout,
          message: "Test clock #{id} did not reach :ready within #{opts[:timeout] || 60_000}ms",
          raw_body: %{"clock_id" => id, "last_status" => to_string(status), "attempts" => attempts + 1}
        }}
      else
        sleep_ms = min(max_int, :rand.uniform(delay))  # full jitter per D-13b
        Process.sleep(sleep_ms)
        next_delay = min(max_int, round(delay * mult))
        poll_until_ready(client, id, deadline, next_delay, max_int, mult, opts, attempts + 1)
      end

    {:error, %Error{}} = err ->
      err
  end
end
```

**Note**: CONTEXT D-13b says "first poll happens with zero delay" — the code above achieves that because the first iteration enters `case retrieve` before any `Process.sleep`. CONTEXT D-13b also says "Start 500ms" — that's the initial `delay` for the SECOND poll (after the first zero-delay poll misses).

### Pattern 3: `LatticeStripe.Testing.TestClock` use-macro

```elixir
defmodule LatticeStripe.Testing.TestClock do
  @cleanup_marker {"lattice_stripe_test_clock", "v1"}

  defmacro __using__(opts) do
    client = Keyword.fetch!(opts, :client)
    unless is_atom(client), do: raise CompileError, description: "Testing.TestClock requires :client to be a module atom, got #{inspect(client)}"

    quote do
      import LatticeStripe.Testing.TestClock, only: [
        test_clock: 0, test_clock: 1,
        advance: 2,
        freeze: 1,
        create_customer: 2, create_customer: 3,
        with_test_clock: 1
      ]

      @test_clock_client unquote(client)
    end
  end

  # test_clock/1: resolve client (compile-time default, per-call override), create, register with Owner
  def test_clock(opts \\ []) do
    client = Keyword.get(opts, :client) || Process.get(:__lattice_stripe_test_client__) || raise "no client bound"
    # ... merge metadata marker, call TestHelpers.TestClock.create, register in Owner
  end

  # advance/2: wraps TestHelpers.TestClock.advance_and_wait!/3
  def advance(%LatticeStripe.TestHelpers.TestClock{id: id}, unit_opts) do
    frozen = compute_frozen_time(unit_opts)
    # ... fetch client, call advance_and_wait!
  end

  # etc.
end
```

**Client binding via module attribute vs process dict**: `@test_clock_client unquote(client)` stores the client on the **calling module**, not in process dict. Function clauses inside the helper need to read this via `__MODULE__` at call time — but helpers are imported into the test module, so `@test_clock_client` as a module attribute of the helper module is NOT what we want. The cleanest pattern is: the `__using__` macro compiles client-specific wrapper functions into the TEST module via `quote`, so each test module has its own bound `test_clock/1` etc. Pattern mirror: `Oban.Testing` does exactly this. Planner should study `hex.pm/packages/oban` source for the exact macro shape before writing Plan 05.

### Pattern 4: `LatticeStripe.Testing.RealStripeCase` CaseTemplate

```elixir
defmodule LatticeStripe.Testing.RealStripeCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :real_stripe
      @moduletag timeout: 120_000
    end
  end

  setup_all do
    case System.get_env("STRIPE_TEST_SECRET_KEY") do
      nil ->
        if System.get_env("CI") do
          flunk("STRIPE_TEST_SECRET_KEY not set in CI environment — real Stripe tests cannot run")
        else
          {:skip, "STRIPE_TEST_SECRET_KEY not set; skipping :real_stripe tests"}
        end

      "sk_live_" <> _ ->
        flunk("Refusing to run :real_stripe tests against a LIVE key. Use sk_test_*.")

      "sk_test_" <> _ = key ->
        {:ok, _} = Finch.start_link(name: LatticeStripe.RealStripeFinch)  # or reuse IntegrationFinch
        prefix = "lattice-test-#{System.system_time(:millisecond)}-"
        client = LatticeStripe.Client.new!(
          api_key: key,
          finch: LatticeStripe.RealStripeFinch,
          idempotency_key_prefix: prefix,
          max_retries: 2
        )
        {:ok, client: client}

      _other ->
        flunk("STRIPE_TEST_SECRET_KEY must start with sk_test_")
    end
  end
end
```

### Anti-Patterns to Avoid

- **`start_supervised!/1` for the Owner**: dies with the test pid. Use `start_owner!` + `on_exit` (Ecto.Sandbox convention).
- **`Process.put/2` for client binding**: breaks under async tests and nested describes (CONTEXT D-13h rejected process-dict scope).
- **`String.to_atom/1` on Stripe status strings**: atom-table exhaustion (CONTEXT D-03 atomization rule). Use `atomize_status/1` whitelist.
- **Re-raising with `raise %Error{}, []`**: `defexception` + implementing `Exception` already makes `raise %Error{type: :test_clock_timeout, message: "..."}` work. No need for `Exception.exception/1` shim.
- **Assuming `Date.shift/2`**: Elixir 1.17+. Project minimum is 1.15. Use `DateTime.add/3` or reject month/year advancement units in v1.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exponential backoff with jitter | Custom retry library | Inline `:rand.uniform(delay)` + `Process.sleep/1` in the poll loop | Existing `RetryStrategy.Default` in `lib/lattice_stripe/retry_strategy/` is for HTTP-level retries; reusing it for application-level polling would require awkward shape bending. A 15-line inline poll loop is clearer. |
| Test-process ownership | Global `:ets` table keyed by `self()` | `start_owner!` GenServer + `on_exit` callback | Direct Ecto.Sandbox precedent. Survives test pid crashes, works with `async: true`. |
| HMAC signature for real_stripe webhook | Custom signing | `LatticeStripe.Webhook.generate_test_signature/3` (already exists per `lib/lattice_stripe/testing.ex` line 157) | Not needed in Phase 13 scope, but flagged: Phase 14+ webhook-driven real_stripe tests have this primitive ready. |
| DateTime arithmetic | Custom calendar math | `DateTime.add/3` + `DateTime.to_unix/1` | Stdlib. For seconds/minutes/hours/days only. Months/years deferred to Elixir-1.17 milestone. |
| Telemetry event emission | Manual `:telemetry.execute` pair | `:telemetry.span/3` | Auto-injects span_context + exception handling. Matches existing `Client.request/2` convention (`telemetry.ex` line 278). |
| Exception struct | Custom error record | Extend `LatticeStripe.Error` | Already implements `Exception`, already ships as the canonical error type. Adding two type atoms is the minimal non-breaking extension. |

**Key insight:** Phase 13 leans HEAVILY on existing primitives — retry pattern, telemetry span pattern, Resource unwrap pattern, Error struct. The only genuinely NEW code is (a) the poll loop, (b) the `use` macro, and (c) the Owner GenServer. Everything else is paste-and-adapt.

## Runtime State Inventory

Not applicable — Phase 13 is greenfield code (new files) plus small non-breaking extensions to existing files (`error.ex`, `client.ex`, `config.ex`, `test_helper.exs`, `mix.exs`, `.gitignore`). No renames, no data migrations, no OS-registered state.

**Stored data:** None. `:real_stripe` tests create clocks in live Stripe test mode; these are cleaned up by the test's own `on_exit` and backstopped by the Mix task. If a prior test run leaked clocks (before this phase shipped), a one-time manual `mix lattice_stripe.test_clock.cleanup --older-than 0s` run clears them.
**Live service config:** None.
**OS-registered state:** None.
**Secrets/env vars:** Adds `STRIPE_TEST_SECRET_KEY` as a required env var for `:real_stripe` tests. CI path: GitHub Actions repo secret.
**Build artifacts:** None.

## Common Pitfalls

### Pitfall 1: `Date.shift/2` unavailable on Elixir 1.15

**What goes wrong:** CONTEXT D-13d's example uses `[months: 1]`. The obvious implementation is `Date.shift(date, month: 1)` — **only available in Elixir 1.17+**.

**Why it happens:** `Date.shift/2` is new. Project minimum is 1.15.

**How to avoid:** v1 of `advance/2` supports `:seconds`, `:minutes`, `:hours`, `:days`, `:to`. Reject `:months` and `:years` with a clear error. Defer full calendar support to a later milestone that bumps the Elixir floor to 1.17, OR implement manual month math (fiddly because of variable-length months — months are NOT 30 days).

**Warning signs:** `advance(clock, months: 1)` returns wrong `frozen_time` (not 30 days but some approximation); tests exercising month boundaries fail.

**Flag to planner:** CONTEXT D-13d's example `advance(clock, days: 30)` is safe. CONTEXT mentions `[months: 1]` in passing as an example — confirm with user whether v1 must support months. Recommend: NO for v1, document as a known limitation.

### Pitfall 2: `async: true` + shared `Owner` process

**What goes wrong:** Ecto.Sandbox's Owner uses `start_owner!(pid, opts)` where `pid` is `self()`. If Phase 13's Owner uses a named process, parallel tests clobber each other.

**How to avoid:** Spawn one Owner per test via `start_owner!/1`, register the clock ids in THAT process, `on_exit` reads from THAT process. Each test gets its own isolated Owner. Study `ecto_sql/lib/ecto/adapters/sql/sandbox.ex` `start_owner!/2` for the exact shape.

### Pitfall 3: Stripe's 100-clock-per-account hard limit

**What goes wrong:** If `on_exit` doesn't fire (SIGKILL, BEAM crash, CI timeout), clocks leak. After ~100 leaks, the CI account is full and EVERY subsequent `:real_stripe` test fails at `create` with a 400 error.

**How to avoid:** Mix task backstop (D-13f). CI runs `mix lattice_stripe.test_clock.cleanup --older-than 1h` as a pre-step before the real_stripe test job. Deletes any stale clocks from prior runs.

### Pitfall 4: stripe-mock's canned `status` fixture

**What goes wrong:** Writing an integration test that asserts `advance_and_wait` transitions through `:advancing` into `:ready` — against stripe-mock — will produce misleading results because stripe-mock's `advance` response has a static `status`.

**How to avoid:** Integration tests against stripe-mock assert request shape (URL, method, body encoding, headers) and response decoding only. Polling semantics are covered by Mox unit tests + the `:real_stripe` test. Document this in the integration test file header.

### Pitfall 5: `Owner` GenServer `on_exit` cleanup races with `ExUnit.stop`

**What goes wrong:** If `on_exit` calls `TestHelpers.TestClock.delete/3` which makes a real HTTP request via Finch, and the Finch pool has already been stopped by ExUnit's own `on_exit`, the cleanup call hangs or raises.

**How to avoid:** Register the Owner's cleanup `on_exit` callback BEFORE any other setup that starts Finch-related resources. `on_exit` callbacks run in **reverse order of registration** — register cleanup first means it runs LAST, after other `on_exit` cleanups. But other `on_exit`s stopping Finch before cleanup runs cause the race. The correct fix: inside the cleanup callback, check whether the Finch pool is alive before making the HTTP call. If dead, log a warning and skip. The Mix task backstop then handles the clocks that survived the race.

### Pitfall 6: `LatticeStripe.TestHelpers` namespace collision

**What goes wrong:** `test/support/test_helpers.ex` currently defines `LatticeStripe.TestHelpers`. Phase 13 wants to ship `LatticeStripe.TestHelpers.TestClock`. Both can coexist (different atoms — the submodule doesn't require a parent), but it's confusing and the test-only parent module is invisible to ExDoc.

**How to avoid:** Rename the test-only module to `LatticeStripe.TestSupport` as a Plan 01 micro-task. ~10 integration test files need a one-line alias update.

### Pitfall 7: Full-jitter floor interaction

**What goes wrong:** CONTEXT D-13b says "500ms floor is non-negotiable." With full jitter (`:rand.uniform(delay)`), the actual sleep is `rand(1..delay)` — which can be as low as 1ms. "500ms floor" means what exactly: (a) the MINIMUM of the jittered sleep should be 500ms, or (b) the UN-jittered base delay should never go below 500ms?

**Resolution:** (b) — the un-jittered base delay has a 500ms floor. Jitter is applied on top, producing sleeps in `[1, delay]`. After first poll (zero delay), the NEXT sleep is `:rand.uniform(500)` = 1..500ms, not 500..2500ms. **This contradicts the "500ms non-negotiable floor" intent** — full jitter can produce near-zero sleeps. CONTEXT is internally inconsistent here.

**Planner decision needed:** Either (a) use "equal jitter" — `sleep = delay/2 + :rand.uniform(delay/2)` — which produces sleeps in `[delay/2, delay]`, honouring the 500ms floor at 250ms; or (b) floor the jittered value: `max(500, :rand.uniform(delay))`. Both diverge from "full jitter" vocabulary. **Recommendation**: option (b) — preserve full jitter shape, clamp the result to 500ms minimum. Clear, one line, honours the non-negotiable floor.

## Code Examples

### Extending `LatticeStripe.Error`'s type whitelist

```elixir
# lib/lattice_stripe/error.ex

@type error_type ::
        :card_error
        | :invalid_request_error
        | :authentication_error
        | :rate_limit_error
        | :api_error
        | :idempotency_error
        | :connection_error
        | :test_clock_timeout     # NEW
        | :test_clock_failed      # NEW
```

No other change to `error.ex` — no new field, no `parse_type/1` entry. Locally-constructed errors use `raw_body` for the context map.

### Constructing a test clock timeout error

```elixir
%LatticeStripe.Error{
  type: :test_clock_timeout,
  message: "Test clock clock_abc did not reach :ready within 60000ms",
  raw_body: %{
    "clock_id" => "clock_abc",
    "last_status" => "advancing",
    "attempts" => 8,
    "elapsed_ms" => 60_142
  }
}
```

Works with `raise/1` because `Error` implements `Exception`:

```elixir
raise %LatticeStripe.Error{type: :test_clock_timeout, message: "..."}
# => ** (LatticeStripe.Error) (test_clock_timeout) ...
```

### Adding `:idempotency_key_prefix` to Config schema

```elixir
# lib/lattice_stripe/config.ex — add to @schema after :stripe_account
idempotency_key_prefix: [
  type: {:or, [:string, nil]},
  default: nil,
  doc:
    "Optional string prefix for auto-generated idempotency keys. " <>
    "When set, auto-generated keys are formatted as `<prefix><uuid4>` " <>
    "instead of the default `idk_ltc_<uuid4>`. User-supplied " <>
    "`opts[:idempotency_key]` always wins over auto-generation."
]
```

```elixir
# lib/lattice_stripe/client.ex — extend defstruct
defstruct [
  :api_key, :finch, :stripe_account, :idempotency_key_prefix,
  base_url: "https://api.stripe.com",
  # ... rest unchanged
]
```

```elixir
# lib/lattice_stripe/client.ex — update resolve_idempotency_key to accept client
defp resolve_idempotency_key(%__MODULE__{} = client, method, opts) do
  user_key = Keyword.get(opts, :idempotency_key)
  cond do
    user_key != nil -> user_key
    method == :post -> generate_idempotency_key(client.idempotency_key_prefix)
    true -> nil
  end
end

defp generate_idempotency_key(nil), do: "idk_ltc_" <> uuid4()
defp generate_idempotency_key(prefix) when is_binary(prefix), do: prefix <> uuid4()
```

Update the call site at `client.ex` line 181 to pass `client` through.

### `test/test_helper.exs` update

```elixir
ExUnit.start()
ExUnit.configure(exclude: [:integration, :real_stripe])  # added :real_stripe

# Transport mock for testing Client.request/2 without real HTTP
Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)
Mox.defmock(LatticeStripe.MockJson, for: LatticeStripe.Json)
Mox.defmock(LatticeStripe.MockRetryStrategy, for: LatticeStripe.RetryStrategy)
```

### `.planning/CONVENTIONS.md` scaffold

```markdown
# LatticeStripe Conventions

## Module Namespace

Core billing resources stay FLAT under `LatticeStripe.*`:

- `LatticeStripe.Customer`
- `LatticeStripe.Product`
- `LatticeStripe.Price`
- `LatticeStripe.Coupon`
- `LatticeStripe.Subscription` (future)
- `LatticeStripe.Invoice` (future)
- `LatticeStripe.PaymentIntent`
- `LatticeStripe.PaymentMethod`
- `LatticeStripe.SetupIntent`
- `LatticeStripe.Refund`

Stripe sub-product families NEST under a named namespace:

- `LatticeStripe.Checkout.Session`, `LatticeStripe.Checkout.LineItem` (existing)
- `LatticeStripe.TestHelpers.TestClock` (Phase 13)
- `LatticeStripe.Connect.Account`, `.AccountLink`, `.Transfer` (Phase 17)
- `LatticeStripe.Issuing.*` (future)
- `LatticeStripe.Terminal.*` (future)
- `LatticeStripe.BillingPortal.*` (future)
- `LatticeStripe.Radar.*` (future)
- `LatticeStripe.Treasury.*` (future)
- `LatticeStripe.Identity.*` (future)

Rule of thumb: if the Stripe REST API path is `/v1/<resource>` (top-level),
the module is flat. If it's `/v1/<family>/<resource>` (namespaced), the
module nests under `LatticeStripe.<Family>.<Resource>`.

## Testing Namespaces

Two parallel, intentional, distinct namespaces:

- `LatticeStripe.TestHelpers.*` — SDK resource wrappers over Stripe's
  `/v1/test_helpers/*` API. Ships in `lib/`. Public.
- `LatticeStripe.Testing.*` — user-facing ExUnit ergonomics
  (`Testing.TestClock`, future `Testing.PaymentIntent`, etc.). Ships in `lib/`.
  Public.
- `LatticeStripe.TestSupport` (or similar) — internal test-only helpers.
  Ships in `test/support/`. `@moduledoc false`.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `{:error, :timeout}` bare atoms | Struct errors implementing `Exception` | ~Elixir 1.10+ consensus (Mint, Nimble, Ecto) | Phase 13 adopts this for polling errors. No API break because existing `LatticeStripe.Error` already follows the convention. |
| `start_supervised!/1` for test-owned processes | `ExUnit.Callbacks.start_owner!/2` for tear-down-survival | Ecto 3.0 (2018) | Phase 13 Owner uses this pattern. Cleanup runs even on test pid crash. |
| Hand-rolled retry with fixed delay | Exponential backoff + full jitter with monotonic deadline | AWS (2012), Google SRE book (2016) | Phase 13 poll loop uses this. Matches existing retry strategy shape in `lib/lattice_stripe/retry_strategy/default.ex`. |
| Global setup via `setup_all` + process dict | Compile-time binding via `use MyHelper, client: MyClient` | Oban.Testing (2020), ExMachina.Ecto (2015) | Phase 13 `Testing.TestClock` uses this. `async: true` safe. |
| `Process.sleep` in polling loops | `:timer.send_after` + receive | Opinion split. For simple polling, `Process.sleep` wins on clarity. | Phase 13 uses `Process.sleep` for backoff delays. Matches `Client.request/2` retry loop precedent (`client.ex` line 369). |

**Deprecated/outdated:**
- `Timex` for DateTime arithmetic: avoid. Stdlib `DateTime.add/3` covers Phase 13 needs.
- `ExVCR`: brittle. Not used.
- `Bypass`: superseded by stripe-mock for Stripe-specific integration tests.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Stripe's Test Clock object supports a `metadata` field on `POST /v1/test_helpers/test_clocks` | Codebase Audit #3 | **HIGH**: if metadata is unsupported, D-13g's marker strategy fails and Mix task cleanup must switch to "delete by age" heuristic. **Plan 02 MUST verify this** by reading the current Stripe API reference or hitting stripe-mock's OpenAPI fixture for `test_clocks`. `[ASSUMED]` |
| A2 | `LatticeStripe.TestHelpers.TestClock` (library) and `LatticeStripe.TestHelpers` (test-only) do not cause a compile-time conflict | Codebase Audit #8 | MEDIUM: if Elixir's module system does in fact require the parent module to exist (it does not, but I haven't tested this combination), Plan 01 must rename the test-only module. Easy fix. `[ASSUMED]` — Elixir docs confirm submodules do not require parents to exist, but the `LatticeStripe.TestHelpers` name being OCCUPIED by the test-only module is different from absent. Concrete test: does `defmodule A.B do end` in file1 + `defmodule A do end` in file2 conflict? **No, they are independent atoms.** But we have `LatticeStripe.TestHelpers` already defined — that's the parent atom. Adding a submodule to an existing parent is standard and allowed. **Downgrade to LOW risk.** |
| A3 | stripe-mock's test_clocks endpoint returns a fixture with `status: "ready"` | Codebase Audit #6 | MEDIUM: if the fixture's `status` is `"advancing"`, the zero-delay first-poll branch will NOT satisfy against stripe-mock and integration tests will need manual mocking. **Plan 01 probe task resolves this**. `[ASSUMED]` |
| A4 | CONTEXT D-13b's "500ms floor" means the jittered sleep value, not the base delay | Pitfall 7 | LOW: either interpretation is defensible; the planner can pick. Worth raising explicitly so the decision is locked. `[ASSUMED]` |
| A5 | `Date.shift/2` is Elixir 1.17+ and the project targets 1.15 | Pitfall 1 | LOW: verified in Elixir changelog; cannot use `Date.shift` in v1. `[VERIFIED: elixir-lang.org/blog/2024/06/12/elixir-v1-17-0-released]` |
| A6 | Test clock field list includes `status_details` | Pattern 1 struct definition | LOW: Stripe has been adding `status_details` to various billing objects; may or may not be present on test_clock. `from_map/1` with `extra: %{}` catch-all makes this safe either way. `[ASSUMED]` |
| A7 | `Testing.TestClock.Owner` survives SIGKILL — FALSE, backstopped by Mix task | D-13f | N/A — explicitly documented in CONTEXT that Mix task is the SIGKILL backstop. Not assumed, just restated. |

## Open Questions

1. **Does Stripe's Test Clock object accept `metadata` on create?**
   - What we know: Most Stripe objects accept metadata. Test clock docs don't explicitly mention it.
   - What's unclear: Whether `metadata` is in the Stripe OpenAPI schema for `POST /v1/test_helpers/test_clocks`.
   - Recommendation: Plan 02 probe task — curl the Stripe API docs page or hit stripe-mock's fixture endpoint with `metadata[key]=value` and verify the response echoes it. If not supported, switch D-13g strategy: Testing helper tracks clock ids in the Owner process, Mix task cleans by age instead of by marker.

2. **Is `:idempotency_key_prefix` added in Plan 01 (pre-requisite) or Plan 06 (just-in-time for RealStripeCase)?**
   - What we know: RealStripeCase is the only in-tree consumer. But the change touches Config schema, which is a public API.
   - What's unclear: Whether there's a cleaner narrative in reviewing it alongside RealStripeCase.
   - Recommendation: Plan 01. The change is small, self-contained, and independent of Phase 13's other work. Keeps the wave-0 review simple.

3. **Rename `LatticeStripe.TestHelpers` test-only module?**
   - What we know: No compile-time conflict exists, but there's a clarity cost.
   - What's unclear: Whether the ~10 integration test file updates are within the phase's budget.
   - Recommendation: Yes, rename. Plan 01 micro-task.

4. **Does `advance/2` support months/years in v1?**
   - What we know: CONTEXT's canonical example uses `days: 30`. `months: 1` appears in D-13d's prose as an example but not the canonical happy path.
   - What's unclear: Whether users expect month-level advancement at v1.
   - Recommendation: NO for v1. Document limitation. Support `:seconds`, `:minutes`, `:hours`, `:days`, `:to`. Defer months/years to an Elixir-1.17 milestone.

5. **Full jitter floor semantics (Pitfall 7).**
   - Recommendation: Floor the jittered result: `sleep_ms = max(500, :rand.uniform(delay))`. One line. Honours the "500ms non-negotiable" constraint.

6. **Does `mix.exs` need a `test_paths` entry?**
   - Recommendation: NO. Default `["test"]` already covers `test/real_stripe/`. CONTEXT line 120 is over-specified.

7. **`RealStripeFinch` vs reusing `IntegrationFinch`.**
   - What we know: `IntegrationFinch` points at `http://localhost:12111` for stripe-mock. `RealStripeFinch` would point at `https://api.stripe.com`.
   - Recommendation: Separate Finch pool. Pools are cheap, and shared pools with different base URLs lead to connection-reuse surprises.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Mox 1.2 + stream_data 1.3 (existing) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` (excludes `:integration` and `:real_stripe`) |
| Full suite command | `mix test --include integration` (stripe-mock required) |
| Real-Stripe command | `mix test --include real_stripe` (requires `STRIPE_TEST_SECRET_KEY`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BILL-08 (create) | `TestHelpers.TestClock.create/3` encodes frozen_time and returns typed struct | unit (Mox) | `mix test test/lattice_stripe/test_helpers/test_clock_test.exs -x` | Wave 0 |
| BILL-08 (retrieve) | `TestHelpers.TestClock.retrieve/3` returns typed struct | unit (Mox) | same | Wave 0 |
| BILL-08 (list) | `TestHelpers.TestClock.list/3` returns `%Response{data: %List{data: [%TestClock{}, ...]}}` | unit (Mox) | same | Wave 0 |
| BILL-08 (stream!) | `TestHelpers.TestClock.stream!/3` lazy pagination emits structs | unit (Mox) | same | Wave 0 |
| BILL-08 (delete) | `TestHelpers.TestClock.delete/3` returns struct with `deleted: true` | unit (Mox) | same | Wave 0 |
| BILL-08 (advance) | `TestHelpers.TestClock.advance/4` POSTs `/advance` with frozen_time | unit (Mox) | same | Wave 0 |
| BILL-08b (advance_and_wait, happy) | zero-delay first poll returns `:ready` immediately | unit (Mox — returns `:ready` on first retrieve) | same | Wave 0 |
| BILL-08b (advance_and_wait, polling) | Mox returns `:advancing` 3x then `:ready`; loop terminates with attempts=4 | unit (Mox) | same | Wave 0 |
| BILL-08b (advance_and_wait, timeout) | Mox returns `:advancing` always; loop returns `{:error, %Error{type: :test_clock_timeout}}` after deadline | unit (Mox — patch `System.monotonic_time` via a stubbed time provider, or use a 10ms timeout) | same | Wave 0 |
| BILL-08b (advance_and_wait, internal_failure) | First poll returns `:internal_failure`; immediate `{:error, %Error{type: :test_clock_failed}}` | unit (Mox) | same | Wave 0 |
| BILL-08c (bang) | `advance_and_wait!/3` raises `%LatticeStripe.Error{}` on failure | unit (Mox) | same | Wave 0 |
| BILL-08 (telemetry) | `:telemetry.attach` catches `[:lattice_stripe, :test_clock, :advance_and_wait, :stop]` with `%{status:, attempts:, duration:}` | unit (Mox + :telemetry.attach) | same | Wave 0 |
| TEST-09 (use-macro) | `use LatticeStripe.Testing.TestClock, client: MyClient` compiles; missing `:client` = `CompileError` | unit (compile-time exception) | `mix test test/lattice_stripe/testing/test_clock_test.exs -x` | Wave 0 |
| TEST-09 (Owner lifecycle) | `test_clock/1` creates + registers; `on_exit` deletes | unit (Mox) | same | Wave 0 |
| TEST-09 (metadata marker) | Created clock carries `{"lattice_stripe_test_clock", "v1"}` in metadata | unit (Mox asserts params) | same | Wave 0 |
| TEST-09 (metadata limit guard) | 50-key metadata + marker → `Testing.TestClockError` raised | unit | same | Wave 0 |
| TEST-09 (create_customer) | wrapper auto-injects `test_clock: clock.id` into `Customer.create` params | unit (Mox) | same | Wave 0 |
| TEST-09 (Mix task dry-run) | `mix lattice_stripe.test_clock.cleanup --dry-run` reports candidates | unit (Mox) | `mix test test/lattice_stripe/testing/test_clock_mix_task_test.exs -x` | Wave 0 |
| TEST-09 (integration) | CRUD and advance round-trip against stripe-mock | integration | `mix test --include integration test/integration/test_clock_integration_test.exs` | Wave 0 |
| TEST-10 (real_stripe) | Create clock, advance 30 days, assert `:ready`, assert marker, delete | real_stripe | `mix test --include real_stripe test/real_stripe/test_clock_real_stripe_test.exs` | Wave 0 |
| TEST-10 (safety guards) | `RealStripeCase` flunks on `sk_live_*`, skips when env var unset in non-CI, flunks in CI | unit | `mix test test/support/real_stripe_case_test.exs` (if we test the case template itself — optional) | Wave 0 optional |

### Sampling Rate
- **Per task commit:** `mix test` (excludes integration and real_stripe; all unit tests run)
- **Per wave merge:** `mix test --include integration` (adds stripe-mock integration tests)
- **Phase gate:** `mix test --include integration --include real_stripe` green (requires stripe-mock running AND `STRIPE_TEST_SECRET_KEY` set; maintainer-local or GitHub Actions with secret)

### Wave 0 Gaps
- [ ] `test/lattice_stripe/test_helpers/test_clock_test.exs` — new file, unit tests for CRUD + advance + advance_and_wait (all 4 branches) + telemetry + bang variant
- [ ] `test/lattice_stripe/testing/test_clock_test.exs` — new file, unit tests for use-macro + Owner + cleanup + metadata guard + create_customer wrapper
- [ ] `test/lattice_stripe/testing/test_clock_mix_task_test.exs` — new file, Mix task --dry-run unit tests
- [ ] `test/integration/test_clock_integration_test.exs` — new file, stripe-mock integration
- [ ] `test/real_stripe/test_clock_real_stripe_test.exs` — new file, the canonical :real_stripe round-trip
- [ ] `test/support/real_stripe_case.ex` — new file, internal CaseTemplate
- [ ] `test/test_helper.exs` — one-line edit: `exclude: [:integration, :real_stripe]`

No new framework install, no new fixtures shared infrastructure.

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | API key via `Client.api_key`. `RealStripeCase` refuses `sk_live_*`. |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | `frozen_time` integer type check in `advance/4`. `RealStripeCase` key-prefix validation. `unit_opts` parser rejects unsupported keys. |
| V6 Cryptography | yes (minor) | `:idempotency_key_prefix` handled as opaque strings. UUID4 generation uses `:crypto.strong_rand_bytes/1` (existing `client.ex` line 261). No new crypto introduced. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Live key in `:real_stripe` test run | Elevation | `RealStripeCase` prefix check (`sk_live_*` → flunk). Non-negotiable. |
| Secret key leak via CI logs | Information Disclosure | GitHub Actions masks secrets by default. `Client.new!/1` does not log the API key. Verified: `client.ex` doesn't ship the key in error paths — only header construction at line 389. |
| Clock id collision across parallel runs | DoS via 100-clock limit | Per-run idempotency prefix (`lattice-test-<ms>-`). Mix task backstop for leaked clocks. |
| Metadata marker spoofing | Tampering | Attacker modifying `lattice_stripe_test_clock=v1` metadata to delete user's real clocks via Mix task. Mitigation: the Mix task defaults to `--dry-run false` only after printing a confirmation. Actually — **flag for planner**: CONTEXT D-13f says `--dry-run` is an option, but doesn't say the default. Recommend default: `--dry-run true`, require `--yes` flag to actually delete. Users who run cleanup in CI can pass `--yes` explicitly. |

## Proposed Plan Breakdown

Seven plans, three waves. Complexity estimates are "small" (1–2 files, <200 LOC), "medium" (3–5 files, 200–500 LOC), "large" (>5 files or >500 LOC).

| # | Name | Scope | Dependencies | Complexity | Requirements |
|---|------|-------|--------------|------------|-------------|
| **01** | Scaffolds & env wiring | Extend `Error` type whitelist (`:test_clock_timeout`, `:test_clock_failed`) + unit tests. Add `:idempotency_key_prefix` to `Config` schema, `Client` struct, and `resolve_idempotency_key/2` + unit tests. Update `test/test_helper.exs` exclusion list. Rename `test/support/test_helpers.ex` to `test_support.ex` → `LatticeStripe.TestSupport` (and update all integration test aliases). Create `.planning/CONVENTIONS.md`. Create (or extend) `CONTRIBUTING.md` with `direnv`/`.envrc` section. Add `.envrc` to `.gitignore` if missing. Probe stripe-mock test_clocks endpoint shape; document fixture status. | none | medium | foundational (TEST-09, TEST-10) |
| **02** | `LatticeStripe.TestHelpers.TestClock` struct + from_map | Create `lib/lattice_stripe/test_helpers/test_clock.ex` with `defstruct`, `@known_fields`, `from_map/1`, `atomize_status/1`, typespec. Unit tests for struct construction and atomization. Verify metadata support via live-API or OpenAPI check (Open Question #1). | Plan 01 | small | BILL-08 |
| **03** | TestClock CRUD (create/retrieve/list/stream!/delete) | Add CRUD functions + bang variants. Unit tests via Mox covering request shape, response decoding, error paths. | Plan 02 | medium | BILL-08 |
| **04** | TestClock advance + advance_and_wait + telemetry | Add `advance/4`, `advance_and_wait/4`, `advance_and_wait!/4`. Implement poll loop (zero-delay first, monotonic deadline, jitter+floor per Pitfall 7). Wire `:telemetry.span/3`. Unit tests for all 4 branches (happy, polling, timeout, internal_failure), telemetry attach-and-assert, bang variant. | Plan 03 | medium | BILL-08b, BILL-08c |
| **05** | `LatticeStripe.Testing.TestClock` helper library | `use`-macro with compile-time `:client` validation. Owner GenServer for per-test cleanup (or Agent — Claude's discretion). `test_clock/1`, `advance/2`, `freeze/1`, `create_customer/3`, `with_test_clock/1`. Metadata marker merging with 50-key guard. `TestClockError` exception. `cleanup_tagged/2` in `TestHelpers.TestClock`. Mix task `lattice_stripe.test_clock.cleanup` with `--dry-run` default. Unit tests for all public helpers + use-macro `CompileError` path + metadata guard + Mix task dry-run. | Plan 04 | large | TEST-09 |
| **06** | `RealStripeCase` + canonical :real_stripe test | `test/support/real_stripe_case.ex` with `setup_all` gating (non-CI skip, CI flunk, live-key flunk, test-key ok). `test/real_stripe/test_clock_real_stripe_test.exs` creating a clock, advancing 30 days, asserting `:ready`, asserting marker metadata, deleting. Integration test file against stripe-mock for CRUD encoding shape. | Plan 05 | medium | TEST-10 |
| **07** | Docs & release prep | Extend `mix.exs` `groups_for_modules` with new namespaces. `guides/testing.md` section on Test Clock usage. Update `CHANGELOG.md`. Moduledoc example (CONTEXT canonical happy path) lands verbatim. Credo `--strict` + `format --check-formatted` + `docs --warnings-as-errors` pass. | Plan 06 | small | docs quality gates |

### Wave Grouping

- **Wave 0 (Plan 01)**: Scaffolds. Must land first; every downstream plan imports `Error` extension, `Config` option, or needs the test-helper rename. Plan 01 is merge-gated.
- **Wave 1 (Plans 02, 03, 04)**: SDK resource module. 02 → 03 → 04 is a hard dependency chain (no parallelism). Serial TDD per task.
- **Wave 2 (Plan 05)**: User-facing helper. Depends on Plan 04's `advance_and_wait!/3` signature being stable.
- **Wave 3 (Plans 06, 07)**: Real Stripe tier + polish. Plan 06 and Plan 07 can run in parallel after Plan 05 lands, though Plan 07's moduledoc updates benefit from seeing Plan 06's final public shape first — recommend serial for reviewer clarity.

**Total:** 3-4 waves depending on 06/07 parallelism, 7 plans, ~15–25 tasks.

## Sources

### Primary (HIGH confidence)
- `lib/lattice_stripe/error.ex` (all 162 lines) — struct fields, `Exception` impl, `parse_type/1`
- `lib/lattice_stripe/client.ex` (lines 52–142, 242–285, 386–430) — struct, `new!/1` flow, `resolve_idempotency_key/2`, headers
- `lib/lattice_stripe/config.ex` (lines 31–90) — NimbleOptions schema for client options
- `lib/lattice_stripe/product.ex` (lines 51–84, 397–432) — `@known_fields` + `from_map/1` + `atomize_*` template
- `lib/lattice_stripe/resource.ex` (lines 52–116) — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`
- `lib/lattice_stripe/telemetry.ex` (lines 252–319, 375–382) — `:telemetry.span/3` and `:telemetry.execute/3` patterns
- `lib/lattice_stripe/testing.ex` (all 163 lines) — existing user-facing test helper patterns
- `mix.exs` (lines 97–131) — deps, elixirc_paths, no test_paths customization
- `test/test_helper.exs` (all 10 lines) — Mox mocks, ExUnit exclude list
- `test/support/test_helpers.ex` (all 62 lines) — existing test-only `LatticeStripe.TestHelpers` module (naming collision candidate)
- `.planning/phases/12-billing-catalog/12-RESEARCH.md` — format precedent

### Secondary (MEDIUM confidence)
- https://github.com/stripe/stripe-mock — `[CITED]` README statement that stripe-mock is stateless with hardcoded OpenAPI fixtures
- https://docs.stripe.com/api/test_clocks — Stripe Test Clock object field reference
- https://docs.stripe.com/api/test_clocks/advance — advance endpoint semantics
- https://docs.stripe.com/billing/testing/test-clocks/api-advanced-usage — polling guidance + 500ms rate-limit note
- https://hexdocs.pm/oban/Oban.Testing.html — `use ..., client: MyClient` pattern reference
- https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html — `start_owner!/2` + `on_exit` cleanup reference
- https://hexdocs.pm/ex_unit/ExUnit.CaseTemplate.html — CaseTemplate API reference

### Tertiary (LOW confidence — flagged for validation)
- Whether Stripe's Test Clock object accepts `metadata` on create (Plan 02 must verify)
- Whether stripe-mock's shipped fixture for `/v1/test_helpers/test_clocks` has `status: "ready"` or something else (Plan 01 probe task)

## Metadata

**Confidence breakdown:**
- Codebase audit: HIGH — every fact verified by reading the file
- CONTEXT interpretation: HIGH — all 14 locked decisions walked through and mapped to concrete code changes
- Phase 12 inherited patterns: HIGH — verified in `product.ex` and `resource.ex`
- stripe-mock runtime behaviour: MEDIUM — documented as stateless; exact fixture status value needs probing
- Stripe API field list for TestClock: MEDIUM — from docs reference, not OpenAPI spec directly
- Plan breakdown: HIGH — mirrors Phase 12's 7-plan / 4-wave shape with direct analogues
- Ecosystem pattern fit (Oban.Testing, Ecto.Sandbox): HIGH — precedents are well-documented and widely used

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable deps, stable Stripe API; re-verify if Elixir 1.18+ is released)
