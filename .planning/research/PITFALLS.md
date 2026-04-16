# Pitfalls Research

**Domain:** Elixir SDK for Stripe API — v1.2 Production Hardening & DX additions to a published library
**Researched:** 2026-04-16
**Confidence:** HIGH (codebase read directly; Stripe docs verified; Elixir library guidelines confirmed)

## Critical Pitfalls

### Pitfall 1: Struct Field Expansion Breaks Downstream Pattern Matches at Runtime

**What goes wrong:**
The existing `from_map/1` + `@known_fields` pattern stores expandable fields (like `customer` on `PaymentIntent`) as `String.t() | nil` (the Stripe ID). When expand deserialization (EXPD-02/03) lands, these fields change type to `Customer.t() | String.t() | nil` when expanded. Downstream code that pattern-matches `%PaymentIntent{customer: id}` expecting a string ID will silently receive a `%Customer{}` struct. No compile error, no runtime error on the match itself — wrong behavior downstream.

**Why it happens:**
Elixir structs are open by construction. Adding a type union to a field is not flagged by the compiler. The `~> 1.x` semver constraint in Accrue means the new version is pulled automatically on `mix deps.update`, and nothing warns the consumer that a previously-string field may now be a struct.

**How to avoid:**
- Mark every expandable field in `@type t()` as a union: `customer: String.t() | Customer.t() | nil`. Makes the change visible in HexDocs.
- Only return a typed struct when the raw Stripe response value `is_map(val)` — meaning `expand:` was passed and Stripe returned the full object. When the value is a string (unexpanded ID), leave it as a string. This makes the distinction load-bearing and testable.
- Prominently warn in the expand deserialization guide: "If you pass `expand: [\"customer\"]`, the `customer` field becomes a `%Customer{}` struct instead of an ID string. Existing pattern matches on the raw string ID will receive a struct and must be updated."
- Write a `feat:` CHANGELOG entry that explicitly calls out the type change per expandable field.

**Warning signs:**
- Downstream code does `intent.customer <> "_suffix"` (string concatenation on what was an ID string) — crashes with `FunctionClauseError`.
- Pattern `case intent.customer do "cus_" <> _ -> ...` stops matching after upgrade.

**Phase to address:**
EXPD-02 expand deserialization. Must include migration notes in the guide and explicit union types in `@type t()` for every expandable field.

---

### Pitfall 2: Adding New Client Struct Fields is a Semver Risk for Literal Construction

**What goes wrong:**
Users who construct `%LatticeStripe.Client{}` directly (rather than via `Client.new!/1`) get a compile-time `KeyError` if a new field without a default is added to `defstruct`. If the field has a default, they silently get the library default rather than noticing a new option exists. More subtly, code using the update syntax `%{client | new_field: val}` fails at runtime with `ArgumentError: unknown key :new_field` against older client versions.

**Why it happens:**
Elixir struct modules export their field list at compile time and check field names at construction time. When a library adds a field, dependent modules that were compiled against the old struct shape are recompiled. If a consumer pinned to a older compiled artifact (rare, but possible in some CI setups), mismatches occur.

**How to avoid:**
- All new `Client` struct fields in v1.2 (e.g., `operation_timeouts`, `rate_limit_telemetry`) must have defaults. Never add new fields to `@enforce_keys` in a minor release.
- Add a statement to `api_stability.md`: "Construct clients using `Client.new!/1` or `Client.new/1`. Direct struct literal construction `%Client{...}` is not covered by the semver guarantee — new fields may be added with defaults in minor releases."
- Regression test: `test/readme_test.exs` calls `Client.new!(api_key: ..., finch: ...)` and verifies the output struct is valid. This catches any accidental `@enforce_keys` addition.

**Warning signs:**
- A PR adds a field to `defstruct` without a default value.
- Any field added to `@enforce_keys` in a v1.x PR.

**Phase to address:**
Any phase adding Client options (rate-limit tracking, warm-up, per-operation timeouts). Rule: every new field has a default.

---

### Pitfall 3: Circuit Breaker via :fuse Adds a Required OTP Process to a "No GenServer" Library

**What goes wrong:**
`:fuse` works by running a named GenServer process (`:fuse_server`) that tracks circuit state. If LatticeStripe ships a first-class circuit breaker using `:fuse`, it silently requires the user to start `:fuse_server` in their supervision tree. A library that adds supervised processes contradicts PROJECT.md ("processes only when truly needed") and violates the principle that the library has no global state.

The failure mode is non-obvious: if `:fuse_server` is not running, all `:fuse.ask/2` calls raise `{:not_found, :fuse_server}`. This crash happens at request time, not at startup, making it hard to diagnose in production.

Additionally, the `:fuse` library's async call tracking is known to be unreliable — circuits may not trip correctly when called from async tasks, which is a common pattern in parallel Stripe request batching.

**Why it happens:**
`:fuse` is the obvious Erlang circuit breaker library and Tesla already uses it. Developers add it as a dep, add `:fuse.ask(:stripe_circuit, :sync)` in the transport path, and ship. It works in their dev environment because `:fuse_server` starts automatically via the `:fuse` OTP application. But the library consumer may not have included `:fuse` in their release, or the startup order may differ.

**How to avoid:**
- Do not add `:fuse` as a runtime dep to LatticeStripe at all — not even optional.
- Deliver circuit breaker as a guide + example `RetryStrategy` module in `guides/circuit-breaker.md`. The example can reference `:fuse` as a user-side dep they add to their own application.
- If a built-in circuit breaker is desired, implement it using the existing `RetryStrategy` behaviour callback with ETS for state storage (the user creates and owns the ETS table, passes its name to the strategy). Zero extra library processes.

**Warning signs:**
- Any PR adding `:fuse` to `mix.exs` in the runtime deps section.
- Code calling `:fuse.ask/2` inside `LatticeStripe.Transport.Finch` or `LatticeStripe.RetryStrategy.Default`.

**Phase to address:**
Circuit breaker phase. Deliver as guide + example, not a bundled dep.

---

### Pitfall 4: Rate-Limit Header Tracking Requires Shared State the Library Architecture Forbids

**What goes wrong:**
Stripe sends `Stripe-Rate-Limited-Reason` on 429 responses (values: `global-rate`, `global-concurrency`, `endpoint-rate`, `endpoint-concurrency`, `resource-specific`). A simple `RateLimit-Remaining` counter header is NOT documented by Stripe and likely does not exist. If the feature scope expands from "emit telemetry" to "track and throttle based on remaining budget," it needs shared mutable state across concurrent requests — a counter, timestamp, or budget per account. The library's architecture explicitly forbids this (no GenServer, no global state).

Common mistakes: using `Process` dictionary (per-process, not shared) or `Application.put_env/3` (not thread-safe under concurrent requests) to store rate limit state.

**Why it happens:**
Rate limit tracking looks like a natural extension of the existing retry strategy, which already reads `Retry-After`. Developers assume "track the header" and "throttle based on the header" are the same scope.

**How to avoid:**
- Scope v1.2 rate-limit tracking to telemetry emission only: emit `[:lattice_stripe, :request, :rate_limited]` with `reason: "global-rate"` (or whatever the header says) in metadata when a 429 is received.
- This is purely additive to the existing telemetry span — no new state, no new behaviours.
- Explicitly document the design boundary: "LatticeStripe emits rate-limit events. Proactive throttling belongs in the application layer via a custom `RetryStrategy` backed by an ETS table you control."

**Warning signs:**
- Code that writes to ETS, `Application.put_env`, or `Process.put` inside `Client.request/2` or any retry callback.
- A new GenServer or Agent added to the library for "rate limit state."

**Phase to address:**
Rate-limit awareness phase. Implement as telemetry metadata addition to the existing 429 handling path.

---

### Pitfall 5: Richer Error Suggestions Add a New Dependency or Run on Every Error Path

**What goes wrong:**
Fuzzy param name suggestions ("Did you mean `:payment_method_types`?") require computing edit distance. If implemented via a library (`the_fuzz`, `akin`, `levenshtein`), it adds a runtime dep to a library that advertises "minimal dependencies" — every user gets the dep regardless of whether they want error suggestions. If implemented eagerly (running on every `{:error, ...}` return), it runs on `:connection_error` and `:api_error` types where Stripe's `param` field is nil, wasting CPU.

At 50 known params per resource with 30-character max names, the computation is trivial on its own — but multiplied across high-error-rate paths under load, it becomes visible in profiling.

**Why it happens:**
Developers reach for a fuzzy-match library because implementing Levenshtein from scratch feels wrong. The library is small and already solves the problem. Dependency added, tests pass, shipped. The condition narrowing ("only on invalid_request_error with non-nil param") is forgotten.

**How to avoid:**
- Implement a 20-line inline Levenshtein with a max-distance early-exit at distance 2. The known-param lists are small enough that a hand-rolled function is faster and zero-dep.
- Embed known-param maps per resource as compile-time module attributes, not runtime lookups.
- Gate strictly: only compute when `error.type == :invalid_request_error` AND `error.param != nil`. No computation on `:api_error`, `:connection_error`, `:card_error`.
- Keep suggestions as an addition to the existing `Error` struct (e.g., a `suggestion` field, `nil` by default), not a new struct or wrapping type. Avoids breaking existing pattern matches on `%Error{}`.

**Warning signs:**
- `mix.exs` gains any new runtime dep for string similarity.
- Suggestion computation runs in the `from_response/3` fallback clause (the `_` catch-all for non-`invalid_request_error` types).

**Phase to address:**
Richer error context phase. Implement inline, zero new deps.

---

### Pitfall 6: Task.async_stream Batching Exposes Callers to Linked Process Crashes

**What goes wrong:**
`Task.async_stream` links the spawned tasks to the caller. If any individual Stripe request raises (rather than returning `{:error, ...}`), the exception propagates to the calling process. In an SDK that returns `{:ok, ...} | {:error, ...}` everywhere, a crash in a task is unexpected and breaks the contract. SDK consumers who wrap a batch helper in `try/rescue` will miss it because async_stream propagates crashes through the stream pipeline at `Enum.to_list/1` time, not at `Task.async_stream/3` invocation time.

Additionally, with `on_timeout: :kill_task`, a timed-out task returns `{:exit, :timeout}` as a stream element — this is a stream value, not a raised exception. Code that unwraps results with `Enum.map(fn {:ok, v} -> v end)` will crash on the unmatched `{:exit, :timeout}` element.

**Why it happens:**
`Task.async_stream` is the idiomatic Elixir concurrent-work pattern. SDK authors use it without realizing they are changing the failure semantics from "returns {:error, ...}" to "may crash caller."

**How to avoid:**
- Wrap every task body in `try/rescue` that returns `{:error, %Error{type: :connection_error, message: inspect(e)}}` on any raised exception.
- Return `{:ok, result} | {:error, reason}` from each stream element. The public API returns `[{:ok, struct()} | {:error, Error.t()}]`, never raising by default.
- Handle `{:exit, :timeout}` explicitly in the stream result mapping, converting it to `{:error, %Error{type: :connection_error, message: "request timeout"}}`.
- Consider `Task.Supervisor.async_nolink/3` instead of `Task.async_stream` to avoid process linking entirely. Requires adding a `Task.Supervisor` to the user's supervision tree — document this requirement.
- Bang variant `batch!/2` raises if ANY element errors.

**Warning signs:**
- `Task.async_stream` without a `try/rescue` in each task body.
- Stream result mapped with `fn {:ok, v} -> v end` without a clause for `{:exit, :timeout}` or `{:exit, reason}`.

**Phase to address:**
Request batching phase.

---

### Pitfall 7: meter_event_stream Requires v2 Session Token Auth — Cannot Reuse Client.request/2 As-Is

**What goes wrong:**
The `/v2/billing/meter_event_stream` endpoint is part of Stripe's v2 API with a different auth model: a short-lived session token (15-minute TTL), NOT the standard secret key. Auth flow: `POST /v2/billing/meter_event_session` → returns a session token → use that token for stream requests. Using `client.api_key` directly against the stream endpoint returns a 401. The session must be created first, stored, and refreshed before expiry.

This means the feature cannot be a thin wrapper around the existing `Client.request/2` — it needs its own session lifecycle.

**Why it happens:**
The endpoint resembles existing v1 metering endpoints. The naming pattern (`MeterEvent.create/3`) suggests the same API key auth. The v2 API is a separate authentication domain that is not obvious from the path name alone.

**How to avoid:**
- Implement `MeterEventStream.create_session/2` as the documented first step, with the session `expires_at` stored in the returned struct.
- Provide a `MeterEventStream.send_batch/3` helper that checks `expires_at` before each call and refreshes the session on 401 or expiry.
- Verify against `stripe-mock` whether v2 endpoints are supported — some v2 endpoints may require real Stripe test mode. Integration tests for this endpoint may need to be tagged with `@tag :live_only` if stripe-mock does not support them.
- Document the URL base for v2: confirm whether it's `api.stripe.com/v2/...` or `meter-events.stripe.com/...` against the Stripe v2 API reference.

**Warning signs:**
- `MeterEventStream` module that calls `Client.request/2` with `client.api_key` without a session token step.
- Missing `expires_at` check before stream calls.
- Integration test for `meter_event_stream` that never mocks a 401 / token refresh scenario.

**Phase to address:**
meter_event_stream phase. Treat as a distinct feature with its own session lifecycle, not a wrapper around existing metering code.

---

### Pitfall 8: BillingPortal.Configuration Has 4 Levels of Nesting — Struct Generation Explodes

**What goes wrong:**
The BillingPortal Configuration object (confirmed from Stripe API docs) has 4 nesting levels:
- Level 1: `business_profile`, `features`, `login_page`
- Level 2: `features` contains `customer_update`, `invoice_history`, `payment_method_update`, `subscription_cancel`, `subscription_update`
- Level 3: Each feature has `enabled`, `mode`, `proration_behavior`, `products`, `conditions`, etc.
- Level 4: `subscription_cancel.cancellation_reason` → `{enabled, options}`; `subscription_update.products` → `{product, prices, adjustable_quantity}`

Fully typing all 4 levels requires approximately 10 nested struct modules with their own `from_map/1` implementations. Each one must stay in sync with Stripe's API. When Stripe adds a field to `subscription_update` in a future API version bump, 3 files need updating instead of 1.

**Why it happens:**
The `from_map/1` + nested typed struct pattern scales cleanly to 2-level nesting (Meter has 4 nested structs, all 1 level deep). Developers assume linear extrapolation to 4 levels. The maintenance cost is not obvious until the first Stripe API drift event.

**How to avoid:**
- Decide the typing depth explicitly and document it as a code comment at the top of the resource module: "Level 1 and Level 2 are typed structs. Level 3+ fields are stored in parent struct's `extra` map."
- Use the existing `extra` map pattern for Level 3+ fields. They remain accessible via `config.features.subscription_cancel["cancellation_reason"]` (map access) — not dropped.
- Do NOT model `subscription_update.products` (a list of product references) as typed structs — it is too variable in shape.
- Maximum 6 nested struct modules for BillingPortal.Configuration total.

**Warning signs:**
- More than 6 nested struct files in the `billing_portal/` directory tree for Configuration.
- Any `from_map/1` calling more than 3 other `from_map/1` functions in sequence.

**Phase to address:**
BillingPortal.Configuration phase. Define the typing depth contract in the first plan task before writing any code.

---

### Pitfall 9: Changeset-Style Builders Become Dead Code Unless Scope Is Bounded Up-Front

**What goes wrong:**
Fluent param builders (e.g., `SubscriptionSchedule.Params.new() |> add_phase(...)`) add a second public API surface maintained in parallel with the raw `%{"phases" => [...]}` map approach. When Stripe adds a field to `subscription_schedule`, developers update `from_map/1` but forget the builder. The builder silently cannot express the new field, and users fall back to raw maps — making the builder an obstacle that ships alongside the real API.

The specific failure: builders that cover 80% of the API create more frustration than no builder, because users hit a wall mid-implementation and must start over with raw maps.

**Why it happens:**
Builders feel ergonomic to write. The first version covering the common cases ships fast. But SubscriptionSchedule phases have many fields (billing cycle anchor, trial behavior, coupon, metadata, multiple items with their own pricing). A complete builder becomes more complex than the raw API it wraps.

**How to avoid:**
- Define the explicit scope limit BEFORE writing code: e.g., "SubscriptionScheduleBuilder covers `phases` with `items`, `start_date`, and `end_date` only. All other phase params use raw map merge."
- Make builders produce `map()` output compatible with raw params, so `Map.merge(builder_output, %{"some_advanced_field" => val})` works. Never return a closed struct from a builder.
- If the scope limit means the builder covers less than the top-3 use cases in the Accrue codebase, defer to v1.3 after real usage patterns are validated.

**Warning signs:**
- A builder function that accepts `Map.t()` as an escape hatch for "other stuff" — the symptom of an incomplete abstraction.
- More than 5 `defp` helpers in a builder module to handle special cases.

**Phase to address:**
Changeset-style builders phase. Set and document scope limit before writing any code.

---

### Pitfall 10: Stripe API Drift Detection in CI Produces High Noise, Low Signal

**What goes wrong:**
Stripe adds new fields to existing objects frequently — each new beta feature, each API version bump. A naive CI job that diffs the full Stripe OpenAPI spec against LatticeStripe's known field lists fires on every Stripe OpenAPI push, including resources LatticeStripe does not implement (Tax, Treasury, Issuing, Terminal). CI becomes noisy, developers ignore it, real drift goes undetected.

**Why it happens:**
Developers build the alerting without filtering for scope. The Stripe OpenAPI spec covers thousands of endpoints and objects. Diffing the whole spec generates events on every Stripe release.

**How to avoid:**
- Maintain an explicit allowlist of resource paths LatticeStripe implements (e.g., `/v1/customers`, `/v1/payment_intents`, `/v1/invoices`).
- Separate signal types: new field on existing resource → INFO log, no CI failure. Field type change or field removal → WARNING, CI failure.
- Run on a weekly schedule (not on every Stripe OpenAPI commit). Output a summary GitHub issue.
- Build an ignore list of fields intentionally omitted (LatticeStripe's `extra` map handles unknown fields — the drift detector should not flag every new Stripe field as a required implementation).

**Warning signs:**
- CI job fails on additive Stripe API changes (new fields added to existing objects).
- No scope filter — the job diffs all of Stripe's OpenAPI rather than the implemented resource subset.

**Phase to address:**
Stripe API drift detection phase. Deliver as a weekly scheduled job with allowlist + ignore list before implementing.

---

### Pitfall 11: Connection Warm-Up in Wrong Supervision Position Silently Does Nothing

**What goes wrong:**
A warm-up helper that pre-establishes Finch connections works by making a cheap HTTP request at app startup. If called before the Finch pool starts (wrong supervision tree ordering), the call fails with `{:error, :not_connected}` and the pool simply warms up on the first real request instead. The user gets false confidence that warm-up succeeded.

Child processes in Elixir supervision trees start in the order they are listed in `children`. If warm-up is triggered in `Application.start/2` before the Finch child spec starts, it silently does nothing.

**Why it happens:**
Developers add the warm-up call at the end of `Application.start/2` assuming all supervision tree children are running by then. They are — but only if the warm-up call is made after `Supervisor.start_link/2` returns. Calling it before `Supervisor.start_link/2` runs, or in the wrong supervision order, hits an unstarted pool.

**How to avoid:**
- Deliver warm-up as a child-spec-compatible module (`LatticeStripe.Warmup` with a `child_spec/1`) that the user adds to their supervision tree AFTER the Finch pool entry. Supervision tree ordering makes the dependency explicit.
- The `Warmup` module should return `{:ok, :warmed}` on success and `{:error, reason}` on failure — never silently swallowing the error.
- Guide example must show the correct supervision tree ordering, not a bare function call.

**Warning signs:**
- Warm-up function that returns `:ok` unconditionally rather than threading the actual HTTP result.
- Guide examples showing warm-up as a bare function call in `Application.start/2` without supervision tree context.

**Phase to address:**
Connection warm-up phase. Deliver as a `child_spec`-compatible module.

---

### Pitfall 12: Per-Operation Timeout Defaults Change Existing Behavior Without User Opt-In

**What goes wrong:**
The `Client` struct has `timeout: 30_000` as the global default. If per-operation defaults are implemented by overriding the effective timeout inside resource modules (e.g., `list/3` silently uses 60s, `create/3` uses 15s), existing callers who relied on the 30s default see changed behavior. If any per-op default is LOWER than the client's configured timeout (e.g., a 15s create default for callers who set `timeout: 60_000`), it silently reduces the effective timeout, causing previously-succeeding requests to time out.

**Why it happens:**
Per-operation defaults seem like a pure improvement ("list operations inherently take longer"). Developers set them as constants inside resource modules without considering that callers may have tuned infrastructure (load balancers, upstream timeouts, circuit breakers) around the existing 30s default.

**How to avoid:**
- Per-operation timeout defaults must be opt-in via a new `operation_timeouts: %{list: 60_000, search: 60_000}` field on `Client`. Default: `nil` (no per-op override, existing behavior preserved).
- When `operation_timeouts` is nil, existing behavior is unchanged — regression test verifies this.
- Never hard-code a timeout value in milliseconds inside a resource module. All timeout values flow from the `Client` struct.
- Per-op defaults should never reduce the effective timeout below the client's `timeout` value.

**Warning signs:**
- Any resource module with a literal timeout integer (e.g., `@list_timeout 60_000`).
- A PR that changes `Client.request/2` timeout resolution without a behavior-unchanged regression test.

**Phase to address:**
Per-operation timeout phase. Implement as opt-in `Client` config field.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Adding fuzzy-match library dep | Correct edit-distance, no hand-rolling | Permanent runtime dep, version conflict surface for all downstream users | Never — inline 20-line Levenshtein is sufficient for small known-param lists |
| Deep-typing all 4 BillingPortal.Configuration levels | Fully typed, self-documenting | ~10 nested struct modules, high maintenance burden as Stripe evolves the object | Never for Level 3+ — use `extra` map pattern |
| Shipping `:fuse` as a bundled runtime dep | Out-of-the-box circuit breaker | Adds OTP process requirement, violates "no global state" philosophy | Never as a bundled dep — guide + example `RetryStrategy` only |
| `Task.async_stream` without crash wrapper | Simpler concurrent batching code | Any raise propagates to caller, breaks `{:ok, ...} \| {:error, ...}` contract | Never — always wrap each task body |
| Hard-coded per-op timeout constants in resource modules | Sensible defaults baked in | Changes existing behavior for all callers without opt-in | Never — opt-in via `Client` config only |
| Rate-limit counter in `Application.put_env` | Simple global tracking | Not thread-safe under concurrent requests, incorrect under load | Never — telemetry emission only |
| Changeset builders without a defined scope limit | Ergonomic for common cases | Users hit walls at advanced params, fall back to raw maps, builders become dead code | Acceptable only if scope limit is explicitly bounded and documented up-front |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Stripe expand deserialization | Returning `%Customer{}` when `expand:` was not requested | Only call `Customer.from_map(val)` when `is_map(val)` — string values are unexpanded IDs, leave them as strings |
| meter_event_stream auth | Using `client.api_key` for stream POST calls | Create session first via `POST /v2/billing/meter_event_session`; use session token; check expiry before each call |
| stripe-mock + v2 endpoints | Assuming stripe-mock supports all v2 endpoint shapes | Verify each v2 endpoint against stripe-mock changelog; tag integration tests with `@tag :live_only` if unsupported |
| Finch warm-up supervision ordering | Warm-up before Finch pool starts | Add `LatticeStripe.Warmup` as a child spec entry AFTER the Finch pool in the supervision tree |
| `:fuse` async circuit breaker | Expecting fuse to trip on async task failures | `:fuse`'s async tracking is unreliable; use synchronous fuse checks only, or use ETS-backed `RetryStrategy` |
| Rate-limit telemetry | Emitting on every request | Only emit `[:lattice_stripe, :request, :rate_limited]` event on HTTP 429 responses |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Fuzzy param matching on every error | Latency spike on error paths | Only run when `error.type == :invalid_request_error` and `error.param != nil`; compile-time known-param lists | Any error rate above ~1% at volume |
| Recursive expand deserialization on list responses | `list/3` parsing latency multiplies with response size | Only expand fields explicitly requested via `expand:` opt; do not recursively expand nested fields without explicit depth limit | Lists of 25+ items with 3+ expand fields |
| Connection warm-up blocking app startup | App start latency increases by HTTP round-trip (~100-500ms) | Implement warm-up asynchronously inside the Warmup child spec's `init`; do not block the supervision tree | Kubernetes liveness probe timeouts |
| BillingPortal.Configuration deep `from_map` chain | CPU spike parsing config responses at high call volume | Cap at 2 levels of typed struct; level 3+ as plain map | High-frequency configuration retrieval |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Rate-limit telemetry metadata including raw headers | API key or auth headers captured in telemetry spans | Rate-limit event metadata includes only the `reason` string value, not the full headers list |
| meter_event_stream session token in library state | Token leaked via process inspection, crash dumps | Token stored in calling process state (GenServer assigns, Phoenix socket assigns) — not in LatticeStripe internals |
| Expand deserialization logging `%Customer{}` | PII (email, name, phone) appears in logs via `inspect/1` | Verify `Customer` retains its `Inspect` implementation after expand changes; add an `inspect_test.exs` assertion |
| Changeset builder logging raw params | Stripe params containing card details or bank data in logs | Builders must never call `Logger.*` on their input; leave sanitization to the caller |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Expand deserialization silently changes field type | Runtime `FunctionClauseError` on what was a string field | CHANGELOG callout + guide migration note + union type in `@type t()` |
| meter_event_stream requires 2-step auth with no helper | Cryptic 401 when calling stream without session token | Ship `MeterEventStream.create_session/2` + `send_batch/3` that wraps refresh |
| Per-op timeout defaults applied without opt-in | Infrastructure SLA violations, unexpected timeouts | Require explicit opt-in via `Client` field; default preserves existing 30s behavior |
| Drift detector CI noise | Team ignores alerts; real drift goes undetected | Weekly schedule + allowlist + additive-only INFO filter |
| Changeset builders that cover 80% of the API | Users hit a wall, must restart with raw maps | Document scope boundary explicitly; provide raw-map merge escape hatch |

## "Looks Done But Isn't" Checklist

- [ ] **Expand deserialization:** Test covers the case where `expand:` is NOT passed — field remains a string ID, not a struct.
- [ ] **Expand deserialization:** `@type t()` updated to `Customer.t() | String.t() | nil` for every expandable field.
- [ ] **Circuit breaker:** `:fuse` is NOT in `mix.exs` runtime deps. Feature delivered as guide + example module.
- [ ] **Rate-limit telemetry:** Event fires only on HTTP 429, not on every request. Verified with a non-429 test.
- [ ] **meter_event_stream:** `expires_at` checked before each send. Session refresh tested with a mocked 401 response.
- [ ] **BillingPortal.Configuration:** Typing depth documented in a code comment. Level 3+ fields accessible in `extra` (not silently dropped).
- [ ] **Changeset builders:** Builder output is `Map.merge`-compatible with raw params. Scope limit documented before code is written.
- [ ] **Drift detector:** Allowlist of implemented resource paths defined before the CI job is wired. Additive changes produce INFO, not CI failure.
- [ ] **Connection warm-up:** Returns `{:ok, :warmed} | {:error, reason}`. Tested with Finch pool absent — returns error, does not crash.
- [ ] **Per-op timeouts:** Regression test verifies existing 30s default is unchanged when `operation_timeouts: nil`.
- [ ] **Task.async_stream batch helper:** Every task body wrapped in `try/rescue`. Test verifies a raising task returns `{:error, %Error{}}`, not a crash.
- [ ] **Richer errors:** Suggestion not computed for `:api_error` or `:connection_error`. Test verifies computation is gated on `error.type` + `error.param != nil`.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Expand type union breaks downstream pattern match | HIGH | Patch 1.2.x: ensure non-expand path returns string ID unchanged (was it already?); update CHANGELOG; notify Accrue maintainer |
| `:fuse` dep added and must be removed | MEDIUM | Remove from `mix.exs`; mark as user-side dep in guide; bump minor if it was in any `@spec` |
| Per-op timeout lowers effective timeout, causes failures | HIGH | Immediate patch: `nil` default restores existing behavior for all callers who did not opt in |
| meter_event_stream session not refreshed, silent auth failures | MEDIUM | Patch: add `expires_at` check before every call; non-breaking (purely internal to `MeterEventStream`) |
| Drift detector too noisy, team disables | LOW | Re-scope to allowlist + weekly schedule + INFO-only for additive changes; re-enable |
| BillingPortal.Configuration Level 3+ fields silently dropped | MEDIUM | Add `extra` map to affected nested structs; release as patch (additive change) |
| Changeset builder ships at 80% coverage, users bypass | LOW | Document boundary explicitly; add raw-map escape hatch; defer completion to v1.3 |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Expand field type union breaks downstream | EXPD-02 expand deserialization | Test: expand off → string ID; expand on → typed struct; `@type t()` shows union |
| New Client fields break literal construction | Any phase adding Client opts | Regression: `Client.new!(api_key:, finch:)` with no other opts produces valid struct with all new fields at defaults |
| Circuit breaker adds OTP process dep | Circuit breaker phase | Verify: `:fuse` absent from runtime deps; feature in guide only |
| Rate-limit tracking adds shared state | Rate-limit awareness phase | Verify: no ETS/Application env writes in request path; telemetry-only implementation |
| Fuzzy error suggestions add dep | Richer error context phase | Verify: no new runtime dep; suggestion gated on `error.type == :invalid_request_error` AND `error.param != nil` |
| Task.async_stream crash propagation | Request batching phase | Test: task that raises returns `{:error, %Error{}}`, not a caller crash |
| meter_event_stream wrong auth model | meter_event_stream phase | Test: missing session token returns `{:error, ...}`; 401 triggers token refresh |
| BillingPortal.Configuration struct depth explosion | BillingPortal.Configuration phase | Max 6 nested struct modules; Level 3+ accessible via `extra` map; typing depth in code comment |
| Changeset builders become dead code | Changeset builders phase | Scope limit defined before coding; builder output is `map()`, not a closed struct |
| Drift detector CI noise | Stripe API drift detection phase | Allowlist of implemented paths; additive changes → INFO only; weekly schedule not per-commit |
| Warm-up in wrong supervision position | Connection warm-up phase | child_spec-compatible module; ordering shown in guide; error returned when pool absent |
| Per-op timeouts change existing behavior | Per-operation timeouts phase | Regression: zero-config client uses 30s unchanged; per-op only applies when `operation_timeouts` explicitly set |

## Sources

- [LatticeStripe PROJECT.md](/.planning/PROJECT.md) — design philosophy, "no GenServer" constraint, existing `Client` struct shape
- [LatticeStripe client.ex](lib/lattice_stripe/client.ex) — confirmed `timeout: 30_000` default, `@enforce_keys [:api_key, :finch]`
- [LatticeStripe retry_strategy.ex](lib/lattice_stripe/retry_strategy.ex) — confirmed stateless behaviour pattern, no shared state
- [Stripe Rate Limits documentation](https://docs.stripe.com/rate-limits) — confirmed `Stripe-Rate-Limited-Reason` header on 429; `RateLimit-Remaining` NOT documented
- [Stripe Meter Event Stream v2 API](https://docs.stripe.com/api/v2/billing-meter-stream) — confirmed session token auth, 15-min TTL, `POST /v2/billing/meter_event_session` required first
- [Stripe BillingPortal Configuration object](https://docs.stripe.com/api/customer_portal/configurations/object) — confirmed 4-level nesting, ~10 nested objects
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) — optional dep compile-test requirement; flexible version constraint guidance; `~> x.y` vs `~> x.y.z` warning
- [Task async_stream timeout bug](https://github.com/elixir-lang/elixir/issues/6395) — confirmed `{:exit, :timeout}` as stream element behavior with `on_timeout: :kill_task`
- [Fuse async pitfall](https://elixirforum.com/t/fuse-circuit-breaker-not-breaking-when-called-asynchronously/24669) — confirmed async tracking unreliability in `:fuse`
- [Elixir Code Anti-Patterns](https://hexdocs.pm/elixir/code-anti-patterns.html) — struct evolution, process anti-patterns

---
*Pitfalls research for: LatticeStripe v1.2 Production Hardening & DX — adding features to a published Elixir Stripe SDK*
*Researched: 2026-04-16*
