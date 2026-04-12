# Phase 2: Error Handling & Retry - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 02-error-handling-retry
**Areas discussed:** Error struct enrichment, RetryStrategy behaviour, Bang variant pattern, Idempotency key handling, Retry loop integration, Error module organization, Idempotency conflict handling, Retry-After header handling, Connection error retries, Per-request retry overrides, retry_strategy config field, Process.sleep vs :timer, Telemetry metadata shape, Default max_retries value, Stripe-Should-Retry semantics, Error message formatting, Idempotency key prefix/format, Which HTTP methods are mutating, Error struct for non-JSON responses, UUID generation approach, max_retries vs max_attempts naming, Retry logging/debug output, Json behaviour symmetry, Bang + retry interaction, Retry strategy default module location, Error JSON serialization, Retry context: struct vs map, Wall-clock retry budget, Error protocol implementations, Phase 2 test strategy

---

## Error Struct Enrichment

| Option | Description | Selected |
|--------|-------------|----------|
| Full preservation | Named fields (param, decline_code, charge, doc_url) + raw_body map | ✓ |
| Named fields only | Named fields, no raw_body | |
| Minimal + extra map | Keep Phase 1 fields, single extra map for everything else | |

**User's choice:** Full preservation
**Notes:** User wanted full examples printed out to compare tradeoffs. Chose full preservation for best DX (dot-access + pattern matching) with raw_body as future-proofing escape hatch.

---

## RetryStrategy Behaviour

| Option | Description | Selected |
|--------|-------------|----------|
| Single callback | retry?(attempt, context) :: {:retry, delay_ms} \| :stop | ✓ |
| Two callbacks | retriable?(error, context) :: boolean + delay(attempt, context) :: ms | |
| You decide | Claude picks | |

**User's choice:** Single callback
**Notes:** Research conducted on Req, Oban, Broadway, official Stripe SDKs, and ElixirRetry. User agreed with recommendation to follow Phase 1's "narrowest possible behaviour" pattern (D-07). No strong opinion — followed recommendation.

---

## Bang Variant Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Resource modules only | Bang variants on future resource modules, not Client | |
| Client AND resource modules | request!/2 on Client now, resource bangs in Phase 4+ | ✓ |
| Client only | Only Client.request!/2, no resource-level bangs | |

**User's choice:** On Client AND resource modules

---

## Idempotency Key Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-generate for all mutating | UUID v4 for every POST, user key takes precedence | ✓ |
| Auto-generate only when retries > 0 | Only generate when max_retries > 0 | |
| Never auto-generate | Users must always provide their own | |

**User's choice:** Auto-generate for all mutating requests

---

## Retry Loop Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Internal to Client.request/2 | Retry wraps transport call inside request/2 | ✓ |
| Separate Retry module | LatticeStripe.Retry module, Client delegates | |
| Middleware/pipeline | Composable pipeline approach | |

**User's choice:** Internal to Client.request/2

---

## Error Module Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Single struct with type atom | Keep %Error{type: :card_error}, no separate modules | ✓ |
| Separate exception modules | CardError, RateLimitError, etc. | |
| Single struct + guards | One struct with helper guards for rescue | |

**User's choice:** Single struct with type atom

---

## Idempotency Conflict Handling

| Option | Description | Selected |
|--------|-------------|----------|
| New type atom on Error | :idempotency_error added to parse_type/1 | ✓ |
| Separate fields for conflict | Extra fields like idempotency_key on Error | |

**User's choice:** New type atom

---

## Retry-After Header Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Respect with cap | Honor Retry-After, cap at 5 seconds | ✓ |
| Always respect, no cap | Trust Stripe completely | |
| Ignore, always backoff | Don't parse header | |

**User's choice:** Respect with 5-second cap

---

## Connection Error Retries

| Option | Description | Selected |
|--------|-------------|----------|
| Retry by default | Connection errors retriable, capped by max_retries | ✓ |
| Don't retry | Fail immediately on connection errors | |
| Retry fewer times | Lower max for connection errors | |

**User's choice:** Retry by default

---

## Per-Request Retry Overrides

| Option | Description | Selected |
|--------|-------------|----------|
| max_retries per-request only | retry_strategy per-client only | ✓ |
| Both per-request | max_retries and retry_strategy overridable | |
| No per-request overrides | Client-level only | |

**User's choice:** max_retries per-request, retry_strategy per-client only

---

## retry_strategy Config Field

| Option | Description | Selected |
|--------|-------------|----------|
| Atom field with default | :atom type, default RetryStrategy.Default, no behaviour validation | ✓ |
| Validate behaviour at config time | Custom validator checking function_exported? | |

**User's choice:** Atom field with default, consistent with transport/json_codec

---

## Process.sleep vs :timer

| Option | Description | Selected |
|--------|-------------|----------|
| Process.sleep, no async | Standard blocking sleep | ✓ |
| Task-based async retry | Client.request_async/2 | |
| :timer.send_after + receive | Message-based delay | |

**User's choice:** Process.sleep

---

## Telemetry Metadata Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Rich metadata with attempt tracking | Per-retry events + enriched stop event | ✓ |
| Minimal — just attempt count | Only add attempts to stop | |
| Everything — raw headers per attempt | Full per-attempt timing and headers | |

**User's choice:** Rich metadata

---

## Default max_retries Value

| Option | Description | Selected |
|--------|-------------|----------|
| Change to 2 | Match Stripe SDK convention | ✓ |
| Keep at 0 | Opt-in retries | |
| Default to 1 | Conservative middle ground | |

**User's choice:** Change to 2

---

## Stripe-Should-Retry Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Authoritative when present | true=retry, false=stop, absent=heuristics | ✓ |
| Advisory only | Don't override non-retriable statuses | |
| Only retry when true | Absent = don't retry | |

**User's choice:** Authoritative when present

---

## Error Message Formatting

| Option | Description | Selected |
|--------|-------------|----------|
| Structured single-line | (type) status code message (request: id) | ✓ |
| Keep minimal | (type) message | |
| Multi-line with all fields | Labeled block format | |

**User's choice:** Structured single-line

---

## Idempotency Key Prefix/Format

| Option | Description | Selected |
|--------|-------------|----------|
| Prefixed UUID, not configurable | idk_ltc_ + UUID v4 | ✓ |
| Plain UUID | No prefix | |
| Configurable prefix | User sets prefix in config | |

**User's choice:** Prefixed UUID, not configurable

---

## Which HTTP Methods Are Mutating

| Option | Description | Selected |
|--------|-------------|----------|
| POST only | Stripe v1 uses POST for all mutations | ✓ |
| POST, PUT, PATCH | All typically-mutating methods | |
| All except GET | Everything except GET | |

**User's choice:** POST only

---

## Error Struct for Non-JSON Responses

| Option | Description | Selected |
|--------|-------------|----------|
| Catch decode, wrap as :api_error (rescue) | Rescue decode!/1 failure | |
| Add decode/1 to Json behaviour | Non-bang decode returns result tuple | ✓ |
| Let it crash | decode!/1 raises, caller gets Jason.DecodeError | |

**User's choice:** Option B — Add decode/1 to Json behaviour
**Notes:** User initially undecided between A and B. Asked Claude to decide based on idiomatic Elixir, DX, sustainability, and principle of least surprise. Claude recommended B: non-JSON response is an expected failure (not exceptional), so pattern matching on {:ok, _} | {:error, _} is more idiomatic than rescue. Also, decode!/1 without decode/1 was already a gap in the Json behaviour.

---

## UUID Generation Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Inline with :crypto | ~5 lines, no dependency | ✓ |
| uniq hex dependency | Lightweight UUID library | |
| elixir_uuid hex dependency | Established UUID library | |

**User's choice:** Inline with :crypto

---

## max_retries vs max_attempts Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Keep max_retries | Consistent with Stripe SDKs and Phase 1 | ✓ |
| Switch to max_attempts | Total attempts including original | |
| Both (alias) | Accept both names | |

**User's choice:** Keep max_retries

---

## Retry Logging/Debug Output

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry only | No Logger calls in library | ✓ |
| Logger.debug for retries | Debug-level logging | |
| Configurable | log_retries config option | |

**User's choice:** Telemetry only

---

## Json Behaviour Symmetry

| Option | Description | Selected |
|--------|-------------|----------|
| Add both decode/1 and encode/1 | Full bang/non-bang symmetry | ✓ |
| Only add decode/1 | Only what's needed now | |

**User's choice:** Add both

---

## Bang + Retry Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Retry first, raise on final failure | request!/2 wraps request/2 | ✓ |
| Raise immediately, no retries | Bypass retry loop | |

**User's choice:** Retry first, raise on final failure

---

## Retry Strategy Default Module Location

| Option | Description | Selected |
|--------|-------------|----------|
| Same file as behaviour | retry_strategy.ex has both | ✓ |
| Separate file in subdirectory | retry_strategy/default.ex | |
| Inline in Client | Private functions, no module | |

**User's choice:** Same file as behaviour
**Notes:** User confirmed this is most idiomatic Elixir, principle of least surprise for developers reading the code.

---

## Error JSON Serialization

| Option | Description | Selected |
|--------|-------------|----------|
| Don't implement Jason.Encoder | Users control serialization | ✓ |
| Implement with all fields | Auto-serialize everything | |
| Implement with curated fields | Safe subset only | |

**User's choice:** Don't implement — security first for payment library

---

## Retry Context: Struct vs Map

| Option | Description | Selected |
|--------|-------------|----------|
| Plain map | Documented keys, open pattern matching | ✓ |
| Named struct | %RetryContext{} with enforce_keys | |

**User's choice:** Plain map, consistent with Transport behaviour

---

## Wall-Clock Retry Budget

| Option | Description | Selected |
|--------|-------------|----------|
| Count-based only | max_retries is the only limit | ✓ |
| Optional retry_timeout | Additional time-based budget | |
| Time budget instead of count | Replace max_retries | |

**User's choice:** Count-based only

---

## Error Protocol Implementations

| Option | Description | Selected |
|--------|-------------|----------|
| Implement String.Chars | Delegates to message/1, enables #{error} | ✓ |
| Don't implement | Rely on Exception.message/1 | |

**User's choice:** Implement String.Chars

---

## Phase 2 Test Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Mox with controlled failures | Three-layer: unit, retry integration, error tests | ✓ |
| Zero-delay strategy for tests | Supplement for fast retry tests | ✓ |

**User's choice:** Combined approach — both selected
**Notes:** Three layers: (1) RetryStrategy.Default unit tests, (2) Client retry integration with zero-delay strategy, (3) Client error tests with max_retries: 0.

---

## Claude's Discretion

- Internal helper function organization
- Exact backoff constants and jitter implementation
- Test fixture data shapes
- raw_body truncation length
- UUID v4 bit manipulation details
- Error message edge case wording

## Deferred Ideas

None — discussion stayed within phase scope
