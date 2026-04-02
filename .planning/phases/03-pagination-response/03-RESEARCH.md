# Phase 3: Pagination & Response - Research

**Researched:** 2026-04-02
**Domain:** Elixir Stream.resource/3 pagination, Access behaviour, Inspect protocol, Stripe API versioning
**Confidence:** HIGH

## Summary

Phase 3 builds the data layer that sits between the raw HTTP client (Phase 1/2) and the typed resource modules (Phase 4+). The three new artifacts are `%LatticeStripe.Response{}`, `%LatticeStripe.List{}`, and `LatticeStripe.api_version/0`. All implementation decisions are locked in CONTEXT.md after a thorough discussion session. This research confirms the correctness of those decisions and fills in implementation details.

The core pattern is `Stream.resource/3` for lazy pagination. The start/next/after function model maps cleanly onto Stripe's has_more + cursor paradigm, and this is the established approach used by ExAws, Ecto, and other idiomatic Elixir libraries. The `Access` behaviour on `Response` requires three callbacks (`fetch/2`, `get_and_update/3`, `pop/2`) and enables bracket-syntax delegation from response to data. Custom `Inspect` implementations follow Plug.Conn precedent: replace sensitive fields with `:...` atoms and delegate to `Inspect.Any`.

The current pinned Stripe API version is `2026-03-25.dahlia` (confirmed April 2026). The existing codebase has `"2025-12-18.acacia"` hardcoded as a struct default — this needs updating to match `LatticeStripe.api_version/0`.

**Primary recommendation:** Implement in this sequence: (1) Response struct + Access + Inspect, (2) update Client.request/2 to wrap returns in Response, (3) List struct + from_json/1 + stream! + stream + Inspect, (4) update Client.request/2 with list detection + _params/_opts, (5) add api_version/0 to top-level module + update Config default, (6) enhance User-Agent headers, (7) update existing tests for the new {:ok, %Response{}} return shape.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Auto-Pagination Stream API**
- D-01: Both layers: `LatticeStripe.List` module provides `stream!(client, req)` one-shot and `stream(list, client)` from-existing-list.
- D-02: Explicit client passing — List struct is pure data (no client reference for streaming). `stream(list, client)` takes client as second argument.
- D-03: `stream!` raises on any page fetch error (after retries exhausted). No `{:ok, item} | {:error, reason}` from streams — breaks Stream/Enum composability.
- D-04: Streams emit individual items (flattened), not pages.
- D-05: No collect-all safety guard. Document memory risk in `@doc`. Use `Stream.take(N)` to limit.
- D-06: Auto-detect backward pagination from `ending_before` param presence.
- D-07: Named `stream!` / `stream` — Elixir convention.
- D-08: `stream(list, client)` re-emits first page items then fetches remaining.
- D-09: Exhausted lists (`has_more: false`) — emit existing items and halt. No extra API call.

**List Struct Design**
- D-10: Single `%LatticeStripe.List{}` struct for both cursor-based and page-based (search) pagination. Optional `next_page` field for search.
- D-11: Fields: `data`, `has_more`, `url`, `total_count`, `next_page`, `object`, `extra` (catch-all map).
- D-12: Internal `_params` and `_opts` fields (underscore-prefixed) on List struct. Set by `Client.request/2` when wrapping list responses.
- D-13: List does NOT implement `Enumerable` protocol.
- D-14: Custom `Inspect` on List — shows item count + first item summary (id/object). Hides PII.
- D-15: All in one file: `lib/lattice_stripe/list.ex`.

**Search Pagination**
- D-16: Auto-detect search vs cursor pagination from `"object"` field in response JSON. `"list"` → cursor-based, `"search_result"` → page-based.
- D-17: Eventual consistency documented on Phase 4+ search resource functions and briefly in List `@moduledoc`.

**Response Struct**
- D-18: `%LatticeStripe.Response{}` fields: `data`, `status`, `headers`, `request_id`. Implements `Access` behaviour delegating to `resp.data["key"]`.
- D-19: `Client.request/2` returns `{:ok, %Response{}}`. `Client.request!/2` returns `%Response{}`.
- D-20: Response wraps List: `{:ok, %Response{data: %List{...}}}`.
- D-21: Access on Response returns nil when `data` is a `%List{}` struct.
- D-22: `Response.get_header(resp, name)` returns `[binary()]`. Case-insensitive.
- D-23: Custom `Inspect` on Response — shows id/object, status, request_id. Truncates PII. Hides header details.
- D-24: No `String.Chars` or `Jason.Encoder` on Response.
- D-25: List detection in `Client.request/2`: check decoded JSON `"object"` field. `"list"` or `"search_result"` → wrap in `%List{}`.
- D-26: Phase 4+ resource modules return typed structs directly. Client.request returns Response with metadata.

**Error Struct**
- D-27: Error struct keeps current fields — no changes in Phase 3.

**Expand & Typed Structs**
- D-28: Phase 3 passes expand params through, returns expanded objects as nested plain maps. Typed deserialization deferred to Phase 4.

**API Versioning**
- D-29: `LatticeStripe.api_version/0` public function on top-level module. Config defaults and Client struct reference it.
- D-30: User-Agent enhanced to include OTP version. New `X-Stripe-Client-User-Agent` JSON header.

**Per-Request Options in Streaming**
- D-31: All request opts carry forward across page fetches except idempotency key (GET only).

**Testing Strategy**
- D-32: Unit tests for Response/List struct logic. Mox-based tests for Client.request Response wrapping, multi-page streaming, error mid-stream, search pagination, stream laziness.
- D-33: Existing Phase 1/2 tests updated in same plan that introduces `%Response{}`.
- D-34: Test helpers stay inline for now.

### Claude's Discretion
- Internal `Stream.resource` implementation details (start/next/cleanup functions)
- Exact `from_json/1` deserialization logic for List struct
- Exact `Access` implementation details on Response
- Internal helper function organization within modules
- Test fixture data shapes and assertion style
- Exact `X-Stripe-Client-User-Agent` JSON field set
- API version string value (use current stable)
- Backward pagination cursor logic (use first item ID for `ending_before`)
- `extra` field population logic (Map.drop known keys)

### Deferred Ideas (OUT OF SCOPE)
- Typed deserialization for expanded objects (EXPD-02 typed structs) — deferred to Phase 4
- Delete response handling (`{"deleted": true}`) — Phase 4 resource module decision
- Response headers on Error struct — additive/non-breaking to add later
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PAGE-01 | List endpoints return a struct with `data`, `has_more`, and pagination cursors | `%LatticeStripe.List{}` struct with those fields; Client.request/2 detects "object":"list" and wraps |
| PAGE-02 | User can paginate manually with `starting_after` and `ending_before` parameters | Pass-through via `%Request{}` params; FormEncoder already handles nested encoding |
| PAGE-03 | Library provides auto-pagination via `Stream.resource/3` that lazily fetches all pages | `LatticeStripe.List.stream!/2` using Stream.resource/3 start/next/after pattern |
| PAGE-04 | Auto-pagination streams are composable with Elixir's Stream and Enum modules | Stream.resource/3 returns `Enumerable.t()` — natively composable; no Enumerable on List itself |
| PAGE-05 | Search endpoints support page-based pagination with `page` and `next_page` parameters | Single %List{} struct with `next_page` field; `"search_result"` object type auto-detected |
| PAGE-06 | Search pagination documents eventual consistency caveats clearly | Brief @moduledoc note in List; full warning in Phase 4+ search resource functions |
| EXPD-01 | User can pass `expand` option to expand nested objects on any request | Already supported via `merge_expand/2` in Client; opts forwarded through Request.opts |
| EXPD-02 | Expanded objects are deserialized into typed structs | **DEFERRED to Phase 4** — plain maps in Phase 3 |
| EXPD-03 | Nested expansion supported (e.g., `expand: ["data.customer"]`) | Already works via `merge_expand/2`; no Phase 3 changes needed |
| EXPD-04 | Response structs expose raw response metadata: request_id, HTTP status, headers | `%LatticeStripe.Response{}` with status, headers, request_id fields |
| EXPD-05 | Pattern-matchable domain types use atoms for status fields | Phase 4 concern (resource structs); Phase 3 adds infrastructure |
| VERS-01 | Library pins to a specific Stripe API version per release | `LatticeStripe.api_version/0` returns pinned version constant |
| VERS-02 | User can override API version per-client | Already supported via `client.api_version`; Config default references `api_version/0` |
| VERS-03 | User can override API version per-request | Already supported via `Keyword.get(req.opts, :stripe_version, ...)` in Client.request/2 |
</phase_requirements>

## Standard Stack

### Core (all already in mix.exs — no new deps)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir stdlib | 1.15+ | `Stream.resource/3`, `Access` behaviour, `Inspect` protocol | All built-in; no new dependencies |
| Jason | ~> 1.4 | JSON encode for X-Stripe-Client-User-Agent header | Already a dep |
| Telemetry | ~> 1.0 | request telemetry already in place | Already a dep |

No new Hex dependencies are introduced in Phase 3. All capabilities needed (Stream, Access, Inspect, defimpl, defstruct) are part of Elixir's standard library.

**Installation:** None required.

**Version verification:** All stdlib — no registry check needed.

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── lattice_stripe.ex            # add api_version/0 function (Phase 3)
├── lattice_stripe/
│   ├── client.ex                # modify: Response wrapping, list detection, enhanced headers
│   ├── config.ex                # modify: api_version default references LatticeStripe.api_version/0
│   ├── response.ex              # NEW: %Response{} struct, Access, get_header/2, Inspect
│   ├── list.ex                  # NEW: %List{} struct, stream!/2, stream/2, from_json/1, Inspect
│   ├── request.ex               # unchanged
│   └── error.ex                 # unchanged

test/lattice_stripe/
│   ├── client_test.exs          # modify: pattern match {:ok, %Response{data: map}} not {:ok, map}
│   ├── response_test.exs        # NEW
│   └── list_test.exs            # NEW
```

### Pattern 1: Stream.resource/3 for Lazy Pagination

**What:** `Stream.resource/3` takes three funs: `start_fun` (zero-arity, produces initial acc), `next_fun` (acc → {items, next_acc} | {:halt, acc}), `after_fun` (cleanup, receives final acc).

**When to use:** Any case where items come from paginated HTTP responses. The stream is lazy — pages are only fetched when the consumer demands more items.

**State machine for pagination:**
- Initial state: `{:start, list_struct, client}` for `stream(list, client)`, or `{:start_fresh, req, client}` for `stream!(client, req)`
- Next states: `{:buffer, remaining_items, list_struct, client}` while items remain on current page
- Terminal state: `{:halt, acc}` when `has_more: false` and buffer is empty

**Example:**
```elixir
# Source: https://hexdocs.pm/elixir/Stream.html#resource/3
def stream!(%Client{} = client, %Request{} = req) do
  Stream.resource(
    fn -> fetch_page!(client, req) end,
    fn
      %__MODULE__{data: [], has_more: false} = list ->
        {:halt, list}

      %__MODULE__{data: [], has_more: true} = list ->
        next_page = build_next_page_request(list)
        {[], fetch_page!(client, next_page)}

      %__MODULE__{data: [item | rest]} = list ->
        {[item], %{list | data: rest}}
    end,
    fn _list -> :ok end
  )
end

defp fetch_page!(client, req) do
  case Client.request(client, req) do
    {:ok, %Response{data: %__MODULE__{} = list}} -> list
    {:error, error} -> raise error
  end
end
```

**Key insight on state:** The accumulator is the `%List{}` itself with `data` consumed item-by-item. When the buffer empties and `has_more: true`, fetch the next page and replace the accumulator. When the buffer empties and `has_more: false`, halt.

### Pattern 2: Access Behaviour on Response

**What:** Implement three callbacks so `resp["key"]` delegates to `resp.data["key"]` when data is a plain map.

**When to use:** Allows syntactic convenience for common case (singular resource responses).

**Example:**
```elixir
# Source: https://hexdocs.pm/elixir/Access.html
defimpl Access, for: LatticeStripe.Response do
  def fetch(%{data: data}, key) when is_map(data) and not is_struct(data) do
    Access.fetch(data, key)
  end
  def fetch(_resp, _key), do: :error

  def get_and_update(%{data: data} = resp, key, fun) when is_map(data) and not is_struct(data) do
    {current, new_data} = Access.get_and_update(data, key, fun)
    {current, %{resp | data: new_data}}
  end
  def get_and_update(resp, _key, fun) do
    {current, _} = fun.(nil)
    {current, resp}
  end

  def pop(%{data: data} = resp, key) when is_map(data) and not is_struct(data) do
    {value, new_data} = Access.pop(data, key)
    {value, %{resp | data: new_data}}
  end
  def pop(resp, _key), do: {nil, resp}
end
```

**D-21 enforcement:** The `is_map(data) and not is_struct(data)` guard ensures that when `data` is a `%List{}` struct, bracket access returns `:error` (nil). This prevents confusing `resp["data"]` returning the `data` field of the List, which was D-21's concern.

### Pattern 3: Custom Inspect for PII Safety

**What:** Replace sensitive fields with `:...` atoms or truncated summaries, then delegate to `Inspect.Any`.

**When to use:** Any struct that may contain PII in a payment library. Follows Plug.Conn precedent.

**Example (from Plug.Conn source):**
```elixir
# Source: https://github.com/elixir-plug/plug/blob/main/lib/plug/conn.ex
defimpl Inspect, for: LatticeStripe.Response do
  def inspect(resp, opts) do
    resp
    |> sanitize_for_inspect()
    |> Inspect.Any.inspect(opts)
  end

  defp sanitize_for_inspect(resp) do
    summary = case resp.data do
      %LatticeStripe.List{data: items} ->
        "LatticeStripe.List<#{length(items)} items>"
      data when is_map(data) ->
        data |> Map.take(["id", "object"]) |> Map.put("...", :truncated)
      _ ->
        :truncated
    end
    %{resp | data: summary, headers: "(#{length(resp.headers)} headers)"}
  end
end
```

**Simpler alternative using @derive:** `@derive {Inspect, only: [:status, :request_id]}` produces `#LatticeStripe.Response<status: 200, request_id: "req_abc">`. This is adequate and avoids writing callbacks. The tradeoff: less control over how `data` is summarized. Given D-23 specifies showing id/object from data, a full `defimpl` is needed.

### Pattern 4: api_version/0 as Single Source of Truth

**What:** Module attribute `@stripe_api_version "2026-03-25.dahlia"` on `LatticeStripe` module, exposed as `def api_version/0`.

**When to use:** Anywhere the version string is needed — Config default, Client struct default, test assertions.

**Example:**
```elixir
defmodule LatticeStripe do
  @moduledoc "..."

  @stripe_api_version "2026-03-25.dahlia"

  @doc "Returns the Stripe API version this release of LatticeStripe is pinned to."
  @spec api_version() :: String.t()
  def api_version, do: @stripe_api_version
end
```

**Config integration:** In `config.ex`, change the hardcoded `default: "2025-12-18.acacia"` to `default: LatticeStripe.api_version()`. The NimbleOptions schema is compiled at module load via `@schema NimbleOptions.new!(...)`, so this is a compile-time reference — no runtime overhead.

**Important:** The Client struct currently also has `api_version: "2025-12-18.acacia"` as a default. That default comes from Config validation (not the struct `defstruct` line for users who go through `new!/1`), but the defstruct line should also reference `LatticeStripe.api_version()` to stay in sync.

### Pattern 5: X-Stripe-Client-User-Agent Header

**What:** JSON-encoded header with SDK metadata for Stripe's support tooling.

**Fields (modeled on Ruby SDK, adapted for Elixir):**
```elixir
%{
  "bindings_version" => @version,        # e.g., "0.1.0"
  "lang" => "elixir",
  "lang_version" => System.version(),    # e.g., "1.19.5"
  "publisher" => "lattice_stripe",
  "otp_version" => System.otp_release()  # e.g., "28"
}
|> Jason.encode!()
```

**User-Agent update:**
```
LatticeStripe/0.1.0 elixir/1.19.5 otp/28
```
Format: `LatticeStripe/{version} elixir/{elixir_version} otp/{otp_release}`

`System.otp_release/0` returns the OTP major release as a string (e.g., `"28"`). Available since Elixir 1.0 — no version concern.

### Anti-Patterns to Avoid
- **Implementing `Enumerable` on `%List{}`:** Makes `Enum.map(list, fn)` work but only operates on page 1. The footgun is severe for a pagination library — D-13 explicitly forbids this.
- **Emitting `{:ok, item}` from streams:** Breaks composability with `Stream.filter`, `Enum.map`, etc. Streams emit plain items.
- **Storing client reference in List struct:** Breaks idiomatic Elixir (data vs actors). Explicit client passing is the correct pattern.
- **Fetching extra page when `has_more: false`:** The stream should halt immediately when the buffer empties AND has_more is false. Never make an extra API call to confirm emptiness.
- **Using atom keys in `_params` / `_opts`:** These are internal fields populated from the original request. Keep them as-is (opts is a keyword list, params is a map).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Lazy pagination | Custom GenServer or recursive Enum.flat_map | `Stream.resource/3` (stdlib) | Stream.resource is designed exactly for this: stateful, lazy, composable, with cleanup guarantee |
| Bracket access on structs | `defmacro __getitem__` or similar | `defimpl Access` (stdlib) | Access behaviour is the official Elixir contract for `data[key]` syntax |
| Inspect customization | Custom `to_string` or Logger formatter | `defimpl Inspect` (stdlib) | Inspect is the protocol IEx, Logger, and all debugging tools use |
| JSON encoding of User-Agent header | Manual string concatenation | `Jason.encode!/1` (already a dep) | Correctly handles escaping, already validated |

**Key insight:** Phase 3 is entirely standard library work. Every problem here has a stdlib or existing-dep solution. Zero new dependencies needed.

## Runtime State Inventory

Step 2.5: SKIPPED — This is a new-feature phase (not a rename/refactor/migration). No stored data, live service config, OS registrations, secrets, or build artifacts need migrating.

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is pure code/config changes with no external runtime dependencies beyond what Phase 1/2 already established (Finch, Jason, Telemetry, Mox, ExUnit). All confirmed present (161 tests passing).

## Common Pitfalls

### Pitfall 1: Stale api_version in Two Places
**What goes wrong:** `LatticeStripe.api_version/0` is added but `Config` default and/or `Client` defstruct still have the old hardcoded version string.
**Why it happens:** Three places currently have the version: `LatticeStripe.api_version/0` (new), `Config` NimbleOptions schema default (existing, hardcoded to `"2025-12-18.acacia"`), `Client` defstruct field default (existing, same hardcoded).
**How to avoid:** Update all three in the same task. The Config schema default becomes `default: LatticeStripe.api_version()`. The Client defstruct can also reference it, or rely on Config validation always providing it.
**Warning signs:** Tests that check `client.api_version` will fail if not updated.

### Pitfall 2: NimbleOptions Schema Compilation Order
**What goes wrong:** `Config.ex` references `LatticeStripe.api_version()` in `@schema NimbleOptions.new!(...)` at compile time. If `LatticeStripe` module is not compiled before `Config`, the function call will fail.
**Why it happens:** Elixir compiles modules in dependency order, but `Config` is currently independent of `LatticeStripe`. Adding this reference creates a compile-time dependency.
**How to avoid:** Either (a) use a module attribute `@default_api_version LatticeStripe.api_version()` at the top of Config — Elixir resolves this at compile time after compiling LatticeStripe, or (b) keep the version hardcoded in Config and have `LatticeStripe.api_version/0` also return the same compile-time constant. Option (b) is simpler: both reference the same `@stripe_api_version` module attribute, verified by test.
**Warning signs:** `CompileError: undefined function api_version/0` or `(UndefinedFunctionError)` during `mix compile`.

### Pitfall 3: Client.request/2 Return Type Change Breaks All Existing Tests
**What goes wrong:** Changing `{:ok, map}` to `{:ok, %Response{data: map}}` in `Client.request/2` immediately breaks all 161 existing tests that pattern match on `{:ok, map}`.
**Why it happens:** 161 tests were written expecting the old return shape. The change is correct but requires coordinated updates.
**How to avoid:** D-33 mandates updating existing tests in the same plan that introduces `%Response{}`. Plan this as a single wave: (1) introduce Response struct, (2) update Client.request/2, (3) update all existing tests in one commit. Do not split across separate plans without updating tests.
**Warning signs:** `mix test` shows mass failures on client_test.exs immediately after Client.request/2 change.

### Pitfall 4: get_and_update/3 with Pop Semantics
**What goes wrong:** The `Access.get_and_update/3` callback must handle when the function returns `:pop`. If this case is omitted, updating a Response via `put_in` or `update_in` paths that internally call `get_and_update` will raise a FunctionClauseError.
**Why it happens:** Access callbacks are called by macros like `put_in/update_in` with the `:pop` return from the inner function.
**How to avoid:** The `get_and_update` implementation must handle `{current, new_value}` AND `:pop` returns from the provided function.
**Warning signs:** `FunctionClauseError` when using `put_in(resp, ["key"], value)` or `pop_in(resp, ["key"])`.

### Pitfall 5: stream(list, client) Emitting Page-1 Items Twice
**What goes wrong:** If the Stream.resource start_fun eagerly emits page-1 items and the next_fun then also emits them, consumers get duplicates.
**Why it happens:** The accumulator initialization is confused — starting with the List struct means its `data` items must be the first thing emitted by next_fun, not by start_fun.
**How to avoid:** `start_fun` returns the initial List struct (accumulator). `next_fun` immediately drains its `data` field item-by-item. The start_fun does not "emit" — it only produces the initial state. D-08 confirms that `stream(list, client)` re-emits first page items, meaning next_fun handles them.
**Warning signs:** Integration test consuming a 2-page list via `stream/2` returns double the items on page 1.

### Pitfall 6: Backward Pagination Cursor Selection
**What goes wrong:** For `ending_before` (backward pagination), the cursor must be the ID of the *first* item in the current page (not the last), because Stripe returns items before that ID.
**Why it happens:** Forward and backward pagination use different anchor semantics — `starting_after` uses the last item of the current page, `ending_before` uses the first item.
**How to avoid:** In `build_next_page_request/1` or equivalent, detect `ending_before` presence in `list._params`, then use `List.first(list.data)["id"]` for the cursor. D-06 confirms auto-detection from `ending_before` param presence.
**Warning signs:** Backward pagination stream returns wrong items or misses items.

### Pitfall 7: search_result Pagination Uses `page` Not `starting_after`
**What goes wrong:** Search pagination uses `page: next_page_token` as the query parameter, not `starting_after`. If the stream code uses `starting_after` for search responses, the next-page request will be malformed.
**Why it happens:** Stripe has two pagination protocols. D-16 mandates detecting `"object"` field value.
**How to avoid:** In next-page request construction, branch on pagination type: `"list"` → use `starting_after: last_id`, `"search_result"` → use `page: list.next_page`.
**Warning signs:** Search auto-pagination returns only page 1 (second request fails silently or returns empty).

## Code Examples

Verified patterns from official sources:

### Stream.resource/3 Signature
```elixir
# Source: https://hexdocs.pm/elixir/Stream.html#resource/3
@spec resource(
  (-> acc()),
  (acc() -> {[element()], acc()} | {:halt, acc()}),
  (acc() -> term())
) :: Enumerable.t()
```

### Access Behaviour Callbacks
```elixir
# Source: https://hexdocs.pm/elixir/Access.html
@callback fetch(term :: t(), key()) :: {:ok, value()} | :error
@callback get_and_update(data, key(), (value() | nil -> {current, new} | :pop)) ::
  {current_value, new_data :: data}
@callback pop(data, key()) :: {value(), data}
```

### Inspect Protocol Callback
```elixir
# Source: https://hexdocs.pm/elixir/Inspect.html
@callback inspect(t(), Inspect.Opts.t()) ::
  Inspect.Algebra.t() | {Inspect.Algebra.t(), Inspect.Opts.t()}
```

### Plug.Conn Inspect Pattern (PII hiding reference)
```elixir
# Source: https://github.com/elixir-plug/plug/blob/main/lib/plug/conn.ex
defimpl Inspect, for: Plug.Conn do
  def inspect(conn, opts) do
    conn
    |> no_secret_key_base()
    |> no_adapter_data(opts)
    |> Inspect.Any.inspect(opts)
  end
  defp no_secret_key_base(%{secret_key_base: nil} = conn), do: conn
  defp no_secret_key_base(conn), do: %{conn | secret_key_base: :...}
  defp no_adapter_data(conn, %{limit: :infinity}), do: conn
  defp no_adapter_data(%{adapter: {adapter, _}} = conn, _),
    do: %{conn | adapter: {adapter, :...}}
end
```

### System Functions for User-Agent Header
```elixir
# Source: Elixir stdlib — verified against System module docs
System.version()       # => "1.19.5"  (Elixir version)
System.otp_release()   # => "28"      (OTP major release as string)
```

### Stripe API Version (current stable)
```elixir
# Source: https://docs.stripe.com/api/versioning (verified 2026-04-02)
@stripe_api_version "2026-03-25.dahlia"
```

### List.from_json/1 Pattern
```elixir
# Known keys for %List{} — populate `extra` with the remainder
@known_keys ~w[object data has_more url total_count next_page]

def from_json(decoded, params \\ %{}, opts \\ []) do
  %__MODULE__{
    object:      decoded["object"],
    data:        decoded["data"] || [],
    has_more:    decoded["has_more"] || false,
    url:         decoded["url"],
    total_count: decoded["total_count"],
    next_page:   decoded["next_page"],
    extra:       Map.drop(decoded, @known_keys),
    _params:     params,
    _opts:       opts
  }
end
```

### Client.request/2 List Detection
```elixir
# In build_decoded_response/4 — add list wrapping before building Response
defp build_decoded_response(status, decoded, request_id, resp_headers, params, opts) do
  if status in 200..299 do
    data = case decoded["object"] do
      type when type in ["list", "search_result"] ->
        LatticeStripe.List.from_json(decoded, params, opts)
      _ ->
        decoded
    end
    {:ok, %LatticeStripe.Response{
      data: data,
      status: status,
      headers: resp_headers,
      request_id: request_id
    }}
  else
    {:error, Error.from_response(status, decoded, request_id), resp_headers}
  end
end
```

Note: `build_decoded_response/4` must become `/6` (or be refactored) to accept `params` and `opts` for populating `List._params` and `List._opts`. Alternatively, thread them from the outer `request/2` via a context struct.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `{:ok, map}` from Client.request | `{:ok, %Response{}}` with metadata | Phase 3 | Access to request_id, status, headers |
| Hardcoded version string | `LatticeStripe.api_version/0` function | Phase 3 | Single source of truth for pinned version |
| User-Agent: `LatticeStripe/{v} elixir/{v}` | Adds `otp/{v}` + `X-Stripe-Client-User-Agent` JSON header | Phase 3 | Better SDK identification for Stripe support |
| `"2025-12-18.acacia"` pinned version | `"2026-03-25.dahlia"` | Phase 3 | Current stable as of April 2026 |

**Current Stripe API version:** `2026-03-25.dahlia` (verified against https://docs.stripe.com/api/versioning, April 2026). The codebase currently has `"2025-12-18.acacia"` in both `client.ex` defstruct default and `config.ex` schema default — both need updating.

**Deprecated/outdated:**
- Hardcoded version strings in client.ex and config.ex: replace with `LatticeStripe.api_version()` reference

## Open Questions

1. **Arity change in build_decoded_response**
   - What we know: Currently `decode_response/4` calls `build_decoded_response(status, decoded, request_id, resp_headers)`. Adding list detection requires `params` and `opts` to populate `List._params` and `List._opts`.
   - What's unclear: Whether to change arity (add params/opts parameters), extract to a context struct, or use a different threading strategy.
   - Recommendation: Thread `params` and `opts` as additional parameters. The call chain is short and internal. Adding `/6` is simpler than a new struct. Alternatively, store in a module-level process dictionary (anti-pattern) or extract to a `RequestContext` struct (overkill for now).

2. **Config.ex compile-time reference to LatticeStripe.api_version/0**
   - What we know: `@schema NimbleOptions.new!(...)` is compiled at module load. `LatticeStripe.api_version()` must be compiled first.
   - What's unclear: Whether Elixir will resolve this dependency automatically or require explicit import.
   - Recommendation: Use a module attribute approach — define `@stripe_api_version` in LatticeStripe, then have Config reference `Application.compile_env` or simply hardcode the same constant in both. The simplest correct approach: keep the same string constant in both places and write a test that asserts `LatticeStripe.Config.schema().schema[:api_version][:default] == LatticeStripe.api_version()`. This avoids circular compile concerns entirely.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` (existing, has Mox defmock setup) |
| Quick run command | `mix test` |
| Full suite command | `mix test --trace` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAGE-01 | `%List{}` struct created from "list" JSON response | unit | `mix test test/lattice_stripe/list_test.exs` | ❌ Wave 0 |
| PAGE-02 | `starting_after`/`ending_before` pass through to next-page requests in stream | unit (Mox) | `mix test test/lattice_stripe/list_test.exs` | ❌ Wave 0 |
| PAGE-03 | `stream!/2` fetches multiple pages lazily | unit (Mox) | `mix test test/lattice_stripe/list_test.exs` | ❌ Wave 0 |
| PAGE-04 | Stream composes with `Stream.take/2`, `Enum.map/2`, `Stream.filter/2` | unit | `mix test test/lattice_stripe/list_test.exs` | ❌ Wave 0 |
| PAGE-05 | `"search_result"` object type produces `%List{next_page: token}` | unit | `mix test test/lattice_stripe/list_test.exs` | ❌ Wave 0 |
| PAGE-06 | `@moduledoc` of List mentions eventual consistency | manual | inspect source | ❌ Wave 0 |
| EXPD-01 | expand opts forward through all page-fetch requests in streaming | unit (Mox) | `mix test test/lattice_stripe/list_test.exs` | ❌ Wave 0 |
| EXPD-02 | Typed deserialization — DEFERRED | — | — | DEFERRED |
| EXPD-03 | Nested expand paths work (already passing via merge_expand) | unit | `mix test` (existing) | ✅ |
| EXPD-04 | `%Response{}` has `request_id`, `status`, `headers` fields | unit | `mix test test/lattice_stripe/response_test.exs` | ❌ Wave 0 |
| EXPD-05 | Atom status fields — PHASE 4 concern | — | — | DEFERRED |
| VERS-01 | `LatticeStripe.api_version/0` returns a pinned version string | unit | `mix test test/lattice_stripe_test.exs` | ❌ Wave 0 |
| VERS-02 | `Config` default for `api_version` equals `LatticeStripe.api_version()` | unit | `mix test test/lattice_stripe/config_test.exs -r` | ✅ (exists, needs new assertion) |
| VERS-03 | Per-request `stripe_version` override in Request.opts takes precedence | unit | `mix test test/lattice_stripe/client_test.exs` | ✅ (exists, needs pattern-match update) |

### Sampling Rate
- **Per task commit:** `mix test`
- **Per wave merge:** `mix test --trace`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/lattice_stripe/response_test.exs` — covers EXPD-04, Response Access behaviour, get_header/2, Inspect
- [ ] `test/lattice_stripe/list_test.exs` — covers PAGE-01..06, EXPD-01, stream!/2, stream/2, from_json/1, Inspect
- [ ] `test/lattice_stripe_test.exs` — covers VERS-01 (api_version/0 function)
- [ ] No new framework install needed — ExUnit and Mox already configured

## Sources

### Primary (HIGH confidence)
- [Stream.html#resource/3](https://hexdocs.pm/elixir/Stream.html#resource/3) — Signature, start/next/after semantics, return type `Enumerable.t()`
- [Access.html](https://hexdocs.pm/elixir/Access.html) — fetch/2, get_and_update/3, pop/2 callbacks and return values
- [Inspect.html](https://hexdocs.pm/elixir/Inspect.html) — inspect/2 signature, Inspect.Algebra, @derive pattern
- [Plug.Conn source](https://github.com/elixir-plug/plug/blob/main/lib/plug/conn.ex) — PII-safe Inspect pattern using `:...` atom replacement
- [Stripe pagination docs](https://docs.stripe.com/api/pagination) — has_more, data, url, object:"list" fields
- [Stripe search pagination docs](https://docs.stripe.com/api/pagination/search) — next_page, object:"search_result", eventual consistency
- [Stripe versioning docs](https://docs.stripe.com/api/versioning) — current version `2026-03-25.dahlia` confirmed
- Existing codebase — `Client.request/2`, `Config`, `Request`, `Error` confirmed via direct file reads

### Secondary (MEDIUM confidence)
- [stripe-ruby api_requestor.rb](https://github.com/stripe/stripe-ruby/blob/master/lib/stripe/api_requestor.rb) — X-Stripe-Client-User-Agent field set (bindings_version, lang, lang_version, publisher, engine)
- `System.otp_release/0` — Elixir stdlib, returns OTP major version as string; confirmed via web search

### Tertiary (LOW confidence)
- stripity_stripe List module (beam-community fork) — confirmed it does NOT implement auto-pagination (design validation only)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all stdlib
- Architecture: HIGH — Stream.resource/3, Access, Inspect are stable, well-documented Elixir primitives
- Pitfalls: HIGH — derived from CONTEXT.md decisions + direct codebase analysis of existing return type (`{:ok, decoded}`)
- API version string: HIGH — verified against official Stripe versioning docs April 2026

**Research date:** 2026-04-02
**Valid until:** 2026-07-02 (90 days — stdlib patterns are stable; verify Stripe API version at implementation time)
