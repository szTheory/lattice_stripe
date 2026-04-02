# Phase 3: Pagination & Response - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 03-pagination-response
**Areas discussed:** Auto-pagination stream API, Search vs cursor pagination, Response metadata exposure, Expand & typed struct timing, List struct completeness, Per-request options in streaming, Testing strategy, Response/Client rewrite scope, Access behaviour nuances, File organization, User-Agent headers

---

## Auto-Pagination Stream API

### Where should auto-pagination live?

| Option | Description | Selected |
|--------|-------------|----------|
| Option C: Both layers | List module with stream!/stream in Phase 3, resource convenience in Phase 4+ | ✓ |
| Option B: Stream on List struct only | List.stream(list) from existing + List.stream!(client, req) one-shot | |
| Option A: Dedicated List module only | List.create + List.stream as standalone functions | |

**User's choice:** Option C: Both layers
**Notes:** Matches ExAws pattern + official SDK conventions. Foundation-first architecture.

### How should the stream-from-list API work?

| Option | Description | Selected |
|--------|-------------|----------|
| Approach 2: Explicit client | Pure data List struct + stream!(client, req) + stream(list, client) | ✓ |
| Approach 3: One-shot only | Only stream!(client, req), no stream-from-list | |
| Approach 1: Client inside List struct | List captures client internally, stream(list) with one arg | |

**User's choice:** Approach 2: Explicit client
**Notes:** Idiomatic Elixir — matches Ecto/ExAws/Finch/Tesla patterns. Structs are pure data.

### Error handling mid-stream

| Option | Description | Selected |
|--------|-------------|----------|
| Option A: stream! raises | Raise on any page failure. Matches ExAws, all 4 Stripe SDKs | ✓ |
| Option C: Both stream! and stream | stream! raises, stream catches first page only | |
| Option B: Error tuples in stream | Stream emits {:ok, item} / {:error, reason} | |

**User's choice:** Option A: stream! raises
**Notes:** Retries already exhausted before error surfaces. No Elixir library emits error tuples from streams.

### Remaining stream details

| Decision | Choice | Notes |
|----------|--------|-------|
| Collect-all safety guard | No guard | Document risk. Elixir devs use Stream.take. |
| Backward pagination | Auto-detect from ending_before | Matches all SDKs |
| Function naming | stream!/stream | Elixir convention (ExAws, Ecto, File) |

**User's choice:** Claude's recommendations accepted for all three.

---

## Search vs Cursor Pagination

| Option | Description | Selected |
|--------|-------------|----------|
| Option A: Same List struct | One struct with optional next_page field, auto-detect | ✓ |
| Option B: Separate SearchResult struct | Two distinct structs, two stream! functions | |
| Option C: Same struct with :mode option | One struct with explicit pagination mode option | |

**User's choice:** Option A: Same List struct
**Notes:** Consumer doesn't need to know the difference. Matches Ruby/Node.

### Search sub-decisions

Covered systematically: next_page token forwarding, search parameters, eventual consistency documentation, backward pagination on search (pass through to Stripe), manual search pagination, total_count field. All marked as Claude's discretion or implementation details.

---

## Response Metadata Exposure

### How should response metadata be exposed?

| Option | Description | Selected |
|--------|-------------|----------|
| Option C: Response struct + Access | Always return %Response{data, status, headers, request_id} with Access behaviour | ✓ |
| Option B: Opt-in metadata | Default {:ok, map}, separate function for metadata | |
| Option A: Response wrapper (no Access) | Always %Response{data: map}, consumer must use .data | |

**User's choice:** Option C: Response struct + Access
**Notes:** Matches Req/Tesla pattern. All metadata always available. Access makes resp["name"] work.

### Response + List interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Response wraps List, keep 'data' | List is resp.data, field stays 'data' matching Stripe JSON | ✓ |
| Response wraps List, rename to 'items' | List uses 'items' instead of 'data' | |
| List includes metadata (no wrapping) | List has own status/headers/request_id fields | |

**User's choice:** Response wraps List, keep 'data'
**Notes:** resp.data.data is rare in practice (streams/resource modules handle most cases).

### Protocol decisions

| Protocol | Decision | Notes |
|----------|----------|-------|
| String.Chars | Don't implement | No Elixir HTTP lib does it. No natural string form. |
| Inspect | Custom implementation | Truncate PII, show id/object/status/request_id. Plug.Conn pattern. |
| Jason.Encoder | Don't implement | Prevents accidental PII serialization. Matches Phase 2 D-04. |

**User's choice:** Agreed with all three.

### Phase 4+ resource module return type

| Option | Description | Selected |
|--------|-------------|----------|
| Option C: Clean struct default | Resource modules return {:ok, %Customer{}}, Client returns {:ok, %Response{}} | ✓ |
| Option A: Always Response wrapper | Everything returns {:ok, %Response{data: ...}} | |
| Option B: Metadata on struct (__meta__) | {:ok, %Customer{__meta__: %{request_id: ...}}} | |

**User's choice:** Option C: Clean struct default
**Notes:** Two tiers: ergonomic sugar (resources) and power tool (Client). Telemetry covers logging.

### Header access

| Option | Description | Selected |
|--------|-------------|----------|
| get_header/2 returns list | Response.get_header(resp, "name") returns [binary()] | ✓ |
| get_header/2 returns single or nil | First matching value or nil | |
| No helper | Let users filter headers list | |

**User's choice:** get_header/2 returns list
**Notes:** Matches Req, Plug pattern. Case-insensitive.

### request!/2 return type

| Option | Description | Selected |
|--------|-------------|----------|
| Returns %Response{} | Same as non-bang minus {:ok, _} wrapper | ✓ |
| Returns data map only | Unwraps Response, returns resp.data | |

**User's choice:** Returns %Response{}
**Notes:** Matches Req.request! pattern. Consistent.

### Additional response decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| List carries metadata? | No — pure data | Single source of truth on Response |
| Headers on Error struct? | No — keep as-is | request_id + status sufficient. Additive later. |
| Custom Inspect on List? | Yes — count + first item | Payment library PII safety |

**User's choice:** Agreed with all three.

---

## Expand & Typed Struct Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Option A: Pass through, plain maps | Phase 3 passes expand, returns plain maps. Typing in Phase 4. | ✓ |
| Option B: Build decode infrastructure | Type registry + decoder framework now | |
| Option C: Generic StripeObject wrapper | Light wrapper for expanded objects | |

**User's choice:** Claude's recommendation (Option A)
**Notes:** All SDKs build types and expand together. No throwaway abstractions.

---

## Additional Gray Areas (Round 2)

### List struct completeness

| Option | Description | Selected |
|--------|-------------|----------|
| Both object + extra | Include 'object' field and 'extra' catch-all map | ✓ |
| Object only, no extra | Include 'object' but skip 'extra' | |
| Neither | Minimal fields only | |

**User's choice:** Both object + extra

### Per-request options in streaming

All options carry forward except idempotency_key. Matches all SDKs. Claude's discretion.

### Testing strategy

Follow Phase 1/2 test layer pattern. Mox ordered expects for multi-page sequences. Laziness verified by Mox expect counts. All async: true, zero-delay retry strategy. Claude's discretion for implementation details.

---

## Additional Gray Areas (Round 3)

### List detection in Client

| Option | Description | Selected |
|--------|-------------|----------|
| Check 'object' field | "list"/"search_result" → %List{}, else plain map | ✓ |
| Duck typing | Check for data + has_more keys | |
| Caller specifies type | Extra parameter on Client.request | |

**User's choice:** Check 'object' field

### API version constant

| Option | Description | Selected |
|--------|-------------|----------|
| Function on top-level module | LatticeStripe.api_version/0 | ✓ |
| Config default only | Already in NimbleOptions schema | |

**User's choice:** Function on top-level module

### Module file location

| Option | Description | Selected |
|--------|-------------|----------|
| Flat alongside existing | response.ex and list.ex at lib/lattice_stripe/ | ✓ |
| Nested under types/ | lib/lattice_stripe/types/ | |

**User's choice:** Flat alongside existing

### Exhausted list streaming

| Option | Description | Selected |
|--------|-------------|----------|
| Emit items, then stop | Yield existing items, halt. No extra API call. | ✓ |
| Raise an error | Reject streaming exhausted list | |
| Empty stream | Skip existing items | |

**User's choice:** Emit items, then stop

---

## Additional Gray Areas (Round 4)

### List.stream params forwarding

| Option | Description | Selected |
|--------|-------------|----------|
| Store on List struct (_params, _opts) | Underscore-prefixed internal fields, set by Client | ✓ |
| Pass request explicitly | stream(list, client, request) — three args | |

**User's choice:** Store on List struct

### Enumerable protocol on List

| Option | Description | Selected |
|--------|-------------|----------|
| Don't implement | List is a paginated envelope, not a collection | ✓ |
| Implement (delegate to data) | Enum.map(list, ...) works but misleads | |

**User's choice:** Don't implement

### Delete response handling

| Option | Description | Selected |
|--------|-------------|----------|
| Defer to Phase 4 | Plain maps for deletes in Phase 3 | ✓ |
| Handle now | Premature without typed structs | |

**User's choice:** Defer to Phase 4

---

## Additional Gray Areas (Round 5)

### Access on Response for List data

| Option | Description | Selected |
|--------|-------------|----------|
| Returns nil | Bracket access only works for plain map data | ✓ |
| Delegate through to List | resp["has_more"] works but confusing | |

**User's choice:** Returns nil

### List file organization

| Option | Description | Selected |
|--------|-------------|----------|
| One file | Struct + stream + Inspect + helpers in list.ex | ✓ |
| Split struct from streaming | list.ex + list/stream.ex | |

**User's choice:** One file

### User-Agent header

| Option | Description | Selected |
|--------|-------------|----------|
| OTP version + X-Stripe-Client-User-Agent | Enhanced User-Agent + JSON client header | ✓ |
| Keep current only | LatticeStripe/version elixir/version | |

**User's choice:** OTP version + client header

---

## Claude's Discretion

- Stream.resource implementation details (start/next/cleanup functions)
- List deserialization logic (from_json)
- Access implementation details on Response
- Internal helper function organization
- Test fixture data shapes
- X-Stripe-Client-User-Agent exact field set
- Backward pagination cursor logic
- extra field population logic
- next_page token forwarding in stream
- Search parameter handling

## Deferred Ideas

- Typed deserialization for expanded objects — Phase 4
- Delete response handling (separate struct vs deleted field) — Phase 4
- Response headers on Error struct — additive, add when use case emerges
