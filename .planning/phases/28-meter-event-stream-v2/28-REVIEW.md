---
phase: 28-meter-event-stream-v2
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - guides/metering.md
  - lib/lattice_stripe/billing/meter_event_stream.ex
  - lib/lattice_stripe/billing/meter_event_stream/session.ex
  - mix.exs
  - test/lattice_stripe/billing/meter_event_stream_integration_test.exs
  - test/lattice_stripe/billing/meter_event_stream_test.exs
  - test/support/fixtures/metering.ex
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 28 delivers the v2 Meter Event Stream implementation: `MeterEventStream` module,
`Session` struct with `Inspect` masking, telemetry wrapping, client-side expiry guard,
server-side 401 normalization, and a comprehensive unit test suite. The implementation
is clean and idiomatic. No critical security or correctness bugs were found.

Three warnings and three informational items follow. The most actionable warning is
the boundary condition in `check_expiry/1`: the `>=` comparison accepts an `expires_at`
value that is equal to the current second, which means the session is treated as valid
when it may have already expired at the sub-second boundary. The other warnings cover
a silent `json_codec.encode!/2` crash path and an over-broad `fuse` dev dependency.

---

## Warnings

### WR-01: `check_expiry/1` boundary — expired session treated as valid at exact expiry second

**File:** `lib/lattice_stripe/billing/meter_event_stream.ex:225`
**Issue:** The guard uses `>=` to detect expiry:

```elixir
if System.system_time(:second) >= expires_at do
  {:error, :session_expired}
else
  :ok
end
```

This means a session is considered expired only when `now >= expires_at`. At the
exact second when `now == expires_at`, the session is returned as expired — that
part is correct. However, at `now == expires_at - 1` (one second before), the
client passes the guard but Stripe may reject the request if the server clock is
slightly ahead or if the network round-trip pushes it past expiry. This is a
clock-skew boundary issue, not a logic inversion.

The real issue is the inverse case that falls through: `check_expiry/1` only
matches `when is_integer(expires_at)`. If `expires_at` is `nil` (line 232), the
function returns `:ok` unconditionally, which is intentional but undocumented.
The nil-bypass path is safe for the integration test fixture (`expires_at` is
always set by Stripe), but a locally-constructed `%Session{}` with `expires_at:
nil` will never be client-side rejected.

Recommendation: Add a one- or two-second safety buffer to guard against clock skew:

```elixir
@expiry_buffer_seconds 2

defp check_expiry(%Session{expires_at: expires_at}) when is_integer(expires_at) do
  if System.system_time(:second) + @expiry_buffer_seconds >= expires_at do
    {:error, :session_expired}
  else
    :ok
  end
end
```

This is a minor hardening item, not a correctness bug — the server-side 401
normalization in `handle_401/2` handles the clock-skew case already. But the
buffer prevents a race where the client-side guard passes and the server
immediately returns 401.

### WR-02: `json_codec.encode!/2` raises on encoding failure — not caught

**File:** `lib/lattice_stripe/billing/meter_event_stream.ex:186`
**Issue:** The events body is built with the bang variant:

```elixir
body = client.json_codec.encode!(%{"events" => events})
```

`encode!/1` raises `Jason.EncodeError` (or equivalent) if an event map contains
a value that cannot be JSON-encoded (e.g., a tuple, an atom key in a nested map,
a struct without `Jason.Encoder` implementation). This exception propagates
unhandled out of `do_send_events/4` and through `send_events/4`, crashing the
caller's process rather than returning `{:error, %Error{}}`.

All other error paths in this module return tagged tuples. An uncaught encode
exception is an inconsistent API contract: callers that `case` on `{:ok, _} |
{:error, _}` are not prepared for a raise.

Fix — use the non-bang variant and normalize the error:

```elixir
case client.json_codec.encode(%{"events" => events}) do
  {:ok, body} ->
    # proceed with transport_request
  {:error, reason} ->
    {:error, %Error{type: :invalid_request_error,
                    message: "Failed to encode events: #{inspect(reason)}"}}
end
```

Or wrap with a rescue if the codec only ships a bang variant:

```elixir
body =
  try do
    client.json_codec.encode!(%{"events" => events})
  rescue
    e -> return {:error, %Error{type: :invalid_request_error, message: Exception.message(e)}}
  end
```

Note: `LatticeStripe.Json.Jason` wraps `Jason.encode!/1`. Check whether `LatticeStripe.Json`
behaviour exposes a non-bang `encode/1` — if so, prefer that.

### WR-03: `fuse` is a dev/test-only dep but listed without `runtime: false`

**File:** `mix.exs:202`
**Issue:**

```elixir
{:fuse, "~> 2.5", only: [:dev, :test]},
```

`fuse` is scoped to `:dev` and `:test` which is correct for availability, but it
is missing `runtime: false`. Without `runtime: false`, Mix will start the `fuse`
application in dev and test environments — it is loaded at runtime, not just at
compile time. This is typically fine for a test dependency but is inconsistent
with how the other compile-time-only dev deps (`ex_doc`, `credo`, `mix_audit`)
are declared:

```elixir
{:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
```

If `fuse` is used at runtime in tests (i.e., a supervised `fuse` process is
needed during test execution), the current declaration is correct. If it is only
referenced at compile time or in test setup, add `runtime: false` to prevent the
OTP application from starting unnecessarily.

Same applies to the OpenTelemetry deps on lines 203-205:

```elixir
{:opentelemetry_exporter, "~> 1.8", only: [:dev, :test]},
{:opentelemetry, "~> 1.5", only: [:dev, :test]},
{:opentelemetry_api, "~> 1.4", only: [:dev, :test]}
```

These start OTP applications. If they are only needed for integration or guide
examples, add `runtime: false`.

---

## Info

### IN-01: `validate_events/1` does not validate individual event shape

**File:** `lib/lattice_stripe/billing/meter_event_stream.ex:218-222`
**Issue:** `validate_events/1` guards against an empty list but does not check
that each element is a map or that required keys (`"event_name"`, `"payload"`)
are present. A caller passing `[nil]` or `["string"]` will produce a
`Jason.EncodeError` raise (the WR-02 issue) rather than a clean
`{:error, %Error{}}`.

This is an info-level item because the Stripe server will reject structurally
invalid events regardless. Adding map-shape validation here would only improve
error ergonomics for callers building event lists programmatically.

### IN-02: `telemetry_wrap/3` emits no metadata other than `:status`

**File:** `lib/lattice_stripe/billing/meter_event_stream.ex:254-263`
**Issue:** The telemetry span attaches only `%{}` as start metadata and
`%{status: :ok | :error}` as stop metadata:

```elixir
:telemetry.span(event_name, %{}, fn ->
  result = fun.()
  stop_meta = %{status: if(match?({:ok, _}, result), do: :ok, else: :error)}
  {result, stop_meta}
end)
```

Other SDK telemetry spans (e.g., in `Client`) include richer metadata such as
the resource name, HTTP method, or URL. For the `create_session` span, the
absence of any metadata makes it harder to correlate with transport-level spans.
Consider emitting at minimum `%{operation: :create_session}` or
`%{operation: :send_events, event_count: length(events)}` for the stop metadata.

This does not affect correctness; it is an observability improvement suggestion.

### IN-03: Guide section "Session renewal" GenServer example swallows error on retry

**File:** `guides/metering.md:726-729`
**Issue:** In the GenServer `handle_call` example, when the session is expired
and a new one is created, the renewal itself is not guarded:

```elixir
{:error, :session_expired} ->
  # Renew and retry once
  {:ok, new_session} = MeterEventStream.create_session(client)  # can fail

  result = MeterEventStream.send_events(client, new_session, events)
  {:reply, result, %{state | session: new_session}}
```

If `create_session/2` returns `{:error, %Error{}}`, the pattern match crashes
the GenServer process. For a guide aimed at production use, the recommended
pattern should handle the session creation failure gracefully:

```elixir
{:error, :session_expired} ->
  case MeterEventStream.create_session(client) do
    {:ok, new_session} ->
      result = MeterEventStream.send_events(client, new_session, events)
      {:reply, result, %{state | session: new_session}}

    {:error, _} = error ->
      {:reply, error, state}
  end
```

This is a documentation item — the guide code is illustrative, not shipped
library code. Fixing it prevents copy-paste failures in production apps.

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
