# Phase 2: Error Handling & Retry - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Structured error returns, automatic retry with exponential backoff, and idempotency key management. Every public API call returns `{:ok, result} | {:error, %Error{}}` with bang variants that raise. Failed requests are automatically retried respecting Stripe's retry signals. Mutating requests carry idempotency keys for safe retries.

Requirements: ERRR-01..06, RTRY-01..06 (12 total)

</domain>

<decisions>
## Implementation Decisions

### Error Struct Enrichment
- **D-01:** Full preservation — add named fields `param`, `decline_code`, `charge`, `doc_url` to the Error struct, plus `raw_body` map for the complete error envelope. Named fields give dot-access and pattern matching for common cases; `raw_body` is the escape hatch for anything Stripe adds later without requiring a library update.
- **D-02:** Single Error struct with `:type` atom — no separate exception modules. Keep Phase 1 pattern. Add `:idempotency_error` as new type atom for 409 conflicts. `parse_type/1` gains one new clause.
- **D-03:** Implement `String.Chars` protocol on Error, delegating to `message/1`. Enables `"#{error}"` interpolation in strings and logging.
- **D-04:** No `Jason.Encoder` on Error — users explicitly control what they serialize. Security-first for a payment library; prevents accidental leaking of `raw_body` or `request_id` to frontends.

### Error Message Formatting
- **D-05:** Structured single-line format: `"(type) status code message (request: request_id)"`. Example: `"(card_error) 402 card_declined Your card has insufficient funds. (request: req_abc123)"`. Grep-friendly, log-friendly, includes correlation ID for Stripe dashboard.

### RetryStrategy Behaviour
- **D-06:** Single callback: `retry?(attempt :: pos_integer(), context()) :: {:retry, delay_ms :: non_neg_integer()} | :stop`. Context is a plain map (not a struct) with keys: `error`, `status`, `headers`, `stripe_should_retry`, `method`, `idempotency_key`. Plain map is consistent with Transport behaviour (D-07 from Phase 1) and is open for future key additions without breaking existing strategies.
- **D-07:** Behaviour and `RetryStrategy.Default` implementation live in the same file (`retry_strategy.ex`). The default has no external dependencies — subdirectory reserved for future alternative strategies (e.g., `retry_strategy/circuit_breaker.ex`).
- **D-08:** `retry_strategy` config field on Client struct, type `:atom`, default `LatticeStripe.RetryStrategy.Default`. Consistent with `transport` and `json_codec` — no behaviour validation at config time (same trade-off).

### Default Retry Behaviour
- **D-09:** `Stripe-Should-Retry` header is authoritative when present. `true` → retry (even unusual statuses). `false` → stop (even normally retriable statuses). Absent → fall back to status-code heuristics: retry 429, 500+, connection errors; don't retry other 4xx. Matches all official Stripe SDKs.
- **D-10:** Respect `Retry-After` header on 429 responses with a 5-second cap (`@max_retry_after 5_000`). Prevents a misbehaving server from stalling the app. Use exponential backoff when header is absent.
- **D-11:** Connection errors (timeout, DNS failure, connection refused) are retriable by default. Safe because mutating requests have idempotency keys. Capped by user's `max_retries`. This is the primary reason retry exists.
- **D-12:** 409 Idempotency conflicts are non-retriable — retrying with the same key and different params would just hit the same conflict.
- **D-13:** Default `max_retries` changes from 0 to 2, matching Stripe SDK convention (up to 3 total attempts). Exponential backoff with jitter: `min(500 * 2^(attempt-1), 5000)` jittered to 50-100% of calculated value.

### Retry Integration
- **D-14:** Retry loop lives internal to `Client.request/2`. One telemetry span wraps all attempts. Per-retry telemetry events (`[:lattice_stripe, :request, :retry]`) emitted for each retry attempt. Public API unchanged — callers don't know retries are happening.
- **D-15:** `Process.sleep/1` for retry delays. The BEAM scheduler handles thousands of sleeping processes. No async alternative — users wrap in `Task.async` if they need non-blocking calls.
- **D-16:** Count-based retries only (`max_retries`). No wall-clock time budget. Worst case bounded by `max_retries * (timeout + max_delay)`. Users who need time-based limits implement a custom RetryStrategy.

### Per-Request Overrides
- **D-17:** `max_retries` overridable per-request via `opts: [max_retries: 5]`. Consistent with existing per-request overrides (`timeout`, `api_key`, `stripe_account`). `retry_strategy` is per-client only — swapping strategy per-request is a code smell.

### Idempotency Keys
- **D-18:** Auto-generate UUID v4 for all POST requests. User-provided key takes precedence (skip auto-gen). Non-POST methods (GET, DELETE) don't get auto-generated keys — Stripe's v1 API uses POST for all mutations. User can still explicitly provide a key on any method.
- **D-19:** Key format: `idk_ltc_` prefix + UUID v4. Example: `"idk_ltc_7f3a1b2c-4d5e-4f7a-8b9c-0d1e2f3a4b5c"`. Prefix is not configurable — exists for debuggability in Stripe dashboard. 44 chars total, well under Stripe's 255 max.
- **D-20:** UUID v4 generated inline via `:crypto.strong_rand_bytes/1` (~5 lines of bit manipulation). No hex dependency. Same approach as Ecto.UUID. Follows project constraint of minimal dependencies.
- **D-21:** Same idempotency key reused across all retry attempts for a single request. Generated once before the retry loop, passed through on each attempt.

### Bang Variants
- **D-22:** `Client.request!/2` added in Phase 2. Resource module bang variants (e.g., `Customer.create!/2`) added in Phase 4+. Both layers exist — Client for raw requests, resources for typed operations.
- **D-23:** `request!/2` retries first, raises on final failure. Thin wrapper: calls `request/2`, unwraps `{:ok, result}`, raises on `{:error, error}`. No independent logic.

### Telemetry
- **D-24:** Rich metadata on stop event: `attempts` (total), `retries` (attempts - 1), `request_id`, `idempotency_key`, `http_status`, `error_type`. Per-retry event `[:lattice_stripe, :request, :retry]` with measurements `attempt` and `delay_ms`, metadata `method`, `path`, `error_type`, `status`.
- **D-25:** Telemetry only — no `Logger` calls in library code. Libraries emit telemetry, applications log. Consistent with Ecto, Phoenix, Finch, Oban convention.

### Json Behaviour Evolution
- **D-26:** Add `decode/1` and `encode/1` (non-bang) to `LatticeStripe.Json` behaviour for full bang/non-bang symmetry. Jason already provides both. Used internally for graceful non-JSON response handling — no `rescue` needed.
- **D-27:** Non-JSON responses (HTML maintenance pages, empty body, malformed JSON) produce a structured `%Error{type: :api_error}` with descriptive message and truncated body in `raw_body` under `%{"_raw" => "..."}` key. These flow through the retry loop normally (503/502 are retriable).

### Naming
- **D-28:** Keep `max_retries` naming. Consistent with every Stripe SDK and Req. `max_retries: 2` means up to 3 total attempts.

### Test Strategy
- **D-29:** Three-layer approach: (1) `RetryStrategy.Default` unit tests — pure functions, given context map assert return value. (2) Client retry integration tests — Mox transport + zero-delay test strategy for fast retry count verification, idempotency key reuse, header handling. (3) Client error tests — Mox transport + `max_retries: 0` for error struct fields, non-JSON handling, bang variants. All `async: true`.

### Claude's Discretion
- Internal helper function organization within modules
- Exact exponential backoff constants (500ms base, 5s max are guidelines)
- Jitter implementation details (50-100% range is guideline)
- Test fixture data shapes and assertion style
- `raw_body` truncation length for non-JSON responses (~500 bytes guideline)
- UUID v4 bit manipulation implementation details
- Error message wording for edge cases (empty body, HTML detection)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — Core value, constraints, design philosophy, key decisions
- `.planning/REQUIREMENTS.md` — Full v1 requirements with traceability (Phase 2: ERRR-01..06, RTRY-01..06)
- `.planning/ROADMAP.md` — Phase structure, dependencies, success criteria

### Phase 1 context (builds on this)
- `.planning/phases/01-transport-client-configuration/01-CONTEXT.md` — All Phase 1 decisions; D-07 (Transport behaviour shape), D-09/D-10 (Error struct design intent), D-12 (extra field pattern), D-18 (test strategy)

### Existing implementation (modify these)
- `lib/lattice_stripe/error.ex` — Current Error struct, `from_response/3`, `parse_type/1`
- `lib/lattice_stripe/client.ex` — Current `request/2`, header building, transport dispatch, telemetry span
- `lib/lattice_stripe/config.ex` — NimbleOptions schema, `max_retries` field (currently default 0)
- `lib/lattice_stripe/json.ex` — Json behaviour (currently `encode!/1` and `decode!/1` only)
- `lib/lattice_stripe/json/jason.ex` — Jason adapter (needs `encode/1` and `decode/1`)

### Research findings
- `.planning/research/STACK.md` — Technology recommendations
- `.planning/research/ARCHITECTURE.md` — Component boundaries, data flow
- `.planning/research/PITFALLS.md` — Domain-specific pitfalls including retry and idempotency gotchas

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Error` — Already has `defexception`, `from_response/3`, 6 error types parsed. Phase 2 enriches additively.
- `LatticeStripe.Client.request/2` — Already has telemetry span, transport dispatch, header building with conditional idempotency key. Phase 2 adds retry loop inside this function.
- `LatticeStripe.Config` — Already has `max_retries` field validated by NimbleOptions. Phase 2 changes default from 0 to 2 and adds `retry_strategy` field.
- `LatticeStripe.MockTransport` (Mox) — Already set up for testing transport calls. Phase 2 tests use `expect(:request, N, fn ...)` for retry count verification.

### Established Patterns
- Behaviour + default adapter: `Transport` → `Transport.Finch`, `Json` → `Json.Jason`. RetryStrategy follows the same pattern.
- Plain maps for behaviour inputs: Transport uses `%{method, url, headers, body, opts}`. RetryContext uses same approach.
- NimbleOptions `:atom` type for module fields: `transport`, `json_codec`, now `retry_strategy`.
- `defexception` with custom `message/1`: already on Error, Phase 2 enriches the format.

### Integration Points
- Phase 3 (Pagination) will use the retry-enabled `Client.request/2` — gets retries for free
- Phase 4 (Customers & PaymentIntents) introduces resource modules with bang variants (`create!/2`) that wrap the retry-enabled client
- Phase 8 (Telemetry) will document the retry telemetry events added here
- Phase 9 (Testing) will add integration tests against stripe-mock that exercise retry behavior end-to-end

</code_context>

<specifics>
## Specific Ideas

- Default strategy modeled after official Stripe SDKs (Ruby/Python/Node) — exponential backoff, Stripe-Should-Retry authoritative, Retry-After respected with cap
- `idk_ltc_` prefix inspired by Stripe's own key prefixes (`sk_`, `pk_`, `pi_`) — instantly identifiable in dashboard
- UUID v4 generation follows Ecto.UUID approach — `:crypto.strong_rand_bytes` with RFC 4122 bit manipulation
- Error struct enrichment follows the "extra field" philosophy from Phase 1 D-12 but applied to errors: named fields for common access + `raw_body` as catch-all
- Non-JSON response handling inspired by how Req handles non-JSON: structured error with descriptive message, not a crash
- Three-layer test strategy keeps test suite fast (zero-delay strategy) while covering all behavior

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-error-handling-retry*
*Context gathered: 2026-04-02*
