# Phase 67: DX Hardening & Milestone Doc Close - Pattern Map

**Mapped:** 2026-08-25  
**Files analyzed:** 13 modified files  
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/lattice_stripe/error.ex` | model / public error API | transform | `lib/lattice_stripe/response.ex` | exact semantic match |
| `lib/lattice_stripe/client.ex` | service / transport controller | request-response | existing `decode_response/6` and retry loop in same file | exact |
| `test/lattice_stripe/error_test.exs` | test | transform | existing `Error.from_response/3` tests | exact |
| `test/lattice_stripe/client_test.exs` | test | request-response | existing mocked HTTP/retry tests | exact |
| `lib/lattice_stripe/webhook/cache_body_reader.ex` | middleware / optional Plug helper | streaming / request-response | `lib/lattice_stripe/webhook/plug.ex` raw-body contract | role-match |
| `test/lattice_stripe/webhook/plug_test.exs` | test | streaming / request-response | existing `CacheBodyReader` and Plug integration tests | exact |
| `guides/error-handling.md` | documentation / config guidance | request-response | existing Automatic Retries section | exact |
| `guides/webhooks.md` | documentation / framework integration | streaming / request-response | existing canonical-vs-advanced webhook setup | exact |
| `lib/lattice_stripe/charge.ex` | model / public resource documentation | CRUD / request-response | existing Charge moduledoc and `PaymentIntent.create/3` API | exact |
| `guides/payments.md` | documentation / consumer workflow | CRUD / request-response | existing `## Charge reconciliation` section | exact |
| `test/lattice_stripe/docs_truth_test.exs` | test | transform | existing scoped guide/moduledoc assertions | exact |
| `guides/api_stability.md` | documentation / public-API contract | transform | existing internal-module exclusion list | exact |
| `priv/api/current.txt` | config / generated public API lock | batch / transform | `LatticeStripe.ApiSurface` snapshot workflow | exact |

## Pattern Assignments

### `lib/lattice_stripe/error.ex` (model/public error API, transform)

**Analog:** `lib/lattice_stripe/response.ex` lines 29-67; extend the existing Error struct/constructor at `lib/lattice_stripe/error.ex` lines 30-159.

**Wire-evidence and lookup pattern** (`lib/lattice_stripe/response.ex` lines 29-67):

```elixir
defstruct [:data, :status, :request_id, headers: []]

@spec get_header(t(), String.t()) :: [String.t()]
def get_header(%__MODULE__{headers: headers}, name) do
  downcased = String.downcase(name)
  for {k, v} <- headers, String.downcase(k) == downcased, do: v
end
```

Copy its ordered-list, case-insensitive, all-values semantics verbatim for `Error.get_header/2`; do not normalize or deduplicate header tuples. Add `headers: []` and `retry_after: nil` in the exception definition and both field-doc/typespec blocks (`error.ex` lines 16-102).

**Compatibility-constructor pattern** (`lib/lattice_stripe/error.ex` lines 114-159):

```elixir
@spec from_response(pos_integer(), map(), String.t() | nil) :: t()
def from_response(status, decoded_body, request_id) do
  case decoded_body do
    %{"error" => %{"type" => type_str} = error_map} ->
      %__MODULE__{type: parse_type(type_str), status: status,
        request_id: request_id, raw_body: decoded_body}
    _ ->
      %__MODULE__{type: :api_error, status: status,
        request_id: request_id, raw_body: decoded_body}
  end
end
```

Keep `/3` as a delegating compatibility entry point and implement `/4` as the sole metadata-building path. The strict public Retry-After parser must be local/new: trim every matching value, accept only `Integer.parse(value) == {seconds, ""}` with `seconds >= 0`, and select the first valid matching header. Do not reuse the retry strategy parser: it accepts suffixes and caps its internal milliseconds value.

### `lib/lattice_stripe/client.ex` (transport service, request-response)

**Analog:** existing response decode and retry pipeline in the same file, especially lines 482-520 and 730-799.

**Retry/header threading pattern** (lines 482-520):

```elixir
{:error, %Error{} = error, resp_headers} = _failure

retry_state = %{method: method, idempotency_key: idempotency_key,
  max_retries: max_retries, attempt: attempt, total_attempts: total_attempts}

maybe_retry(client, transport_request, retry_state, error, resp_headers)
...
context = %{error: error, status: error.status, headers: resp_headers,
  stripe_should_retry: stripe_should_retry, method: retry_state.method,
  idempotency_key: retry_state.idempotency_key}
```

This already ensures the strategy sees the response attempt's headers and that terminal retry return uses its final `error`. Change error construction, not retry eligibility/backoff/sleeps.

**All HTTP error builders must use the same metadata** (lines 751-799):

```elixir
case client.json_codec.decode(body) do
  {:ok, decoded} ->
    build_decoded_response(status, decoded, request_id, resp_headers, params, req_opts)
  {:error, _decode_error} ->
    build_non_json_error(status, body, request_id, resp_headers)
end
...
{:error, Error.from_response(status, decoded, request_id), resp_headers}
```

Pass `resp_headers` to `Error.from_response/4` in decoded non-2xx responses, and use the same header/retry-after field builder for `build_non_json_error/4`. Both normal request and download failures share `decode_response/6` (`client.ex` lines 626-647), so preserve that reuse. Connection branches remain `%Error{type: :connection_error, message: inspect(reason)}` with the existing empty tuple-list return.

### `test/lattice_stripe/error_test.exs` (unit test, transform)

**Analog:** `Error.from_response/3` table-like unit tests at lines 197-318 and their direct struct assertions.

```elixir
body = %{"error" => %{"type" => "rate_limit_error", "message" => "Too many requests"}}
error = Error.from_response(429, body, nil)

assert %Error{type: :rate_limit_error, request_id: nil} = error
```

Extend this style with `/3` compatibility/default tests and `/4` cases covering preserved header order/casing/duplicates, `get_header/2`, first-valid strict decimal parsing (including whitespace), malformed/suffixed/negative/HTTP-date `nil`, and raw decoded-body preservation.

### `test/lattice_stripe/client_test.exs` (Mox transport test, request-response)

**Analog:** response factory at lines 38-53 and retry-loop tests at lines 544-597, plus the non-JSON retry cases beginning line 774.

```elixir
defp error_response(status, type, message, extra_headers \\ []) do
  {:ok, %{status: status,
    headers: [{"request-id", "req_err_456"}] ++ extra_headers,
    body: Jason.encode!(%{"error" => %{"type" => type, "message" => message}})}}
end
```

Use successive `expect/3` transport responses and a stubbed `MockRetryStrategy.retry?/2` to assert both strategy context headers and the terminal public error's final-attempt headers/retry_after. Add decoded JSON, non-JSON, download, and connection cases; avoid testing private helpers.

### `lib/lattice_stripe/webhook/cache_body_reader.ex` (optional middleware, streaming)

**Analog:** the module's existing optional compile guard and return-contract lines 1-33; public raw-body consumer at `lib/lattice_stripe/webhook/plug.ex` lines 79-90.

```elixir
if Code.ensure_loaded?(Plug) do
  defmodule LatticeStripe.Webhook.CacheBodyReader do
    ...
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:ok, body, conn}
      {:more, body, conn} ->
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:more, body, conn}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

Retain this guard, the fixed `:raw_body` private key, native tuple tag/current chunk, and error passthrough. Replace the overwrite with `Map.get(conn.private, :raw_body, "") <> chunk` for both `:more` and `:ok`. Remove `@moduledoc false` and document conditional Plug availability, terminal-only complete-body invariant, PII/lifetime warning, and non-multipart limitation.

### `test/lattice_stripe/webhook/plug_test.exs` (Plug integration test, streaming)

**Analog:** existing reader unit and integration coverage at lines 362-389.

```elixir
conn = Plug.Test.conn(:post, "/webhook", @payload)
{:ok, body, conn} = CacheBodyReader.read_body(conn, [])
assert body == @payload
assert conn.private[:raw_body] == @payload
```

Keep the single-read tuple behavior and `Webhook.Plug` private-body integration test. Add a forced `length: 3` read sequence on `"abcdef"`: assert `{:more, "abc", conn}`, then `{:ok, "def", conn}`, and only then assert `conn.private[:raw_body] == "abcdef"`.

### `guides/error-handling.md` (documentation, request-response)

**Analog:** Automatic Retries at lines 185-240 and request-id handling at lines 242-255.

```markdown
- **Retry-After header respected:** On 429 responses, the `Retry-After` header value is used (capped
  at 5 seconds)
```

Preserve the distinction between the retry strategy's capped scheduling behavior and the new uncapped public `Error.retry_after` evidence. Add a consumer snippet using `Error.get_header/2` / `retry_after`, warn that headers/raw bodies can contain sensitive data and must not be logged wholesale, and advise Phoenix callers to schedule delayed background work rather than block request processes.

### `guides/webhooks.md` (documentation, Plug request-response)

**Analog:** canonical path at lines 31-53 and advanced body-reader route at lines 152-180.

```elixir
plug LatticeStripe.Webhook.Plug, at: "/webhooks/stripe", ...
plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], ...

body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}
```

Keep the endpoint-level Plug-before-Parsers configuration as canonical. Upgrade the advanced alternative with conditional availability, fixed `conn.private[:raw_body]` completion invariant, extra-copy/PII/no-logging warning, and an explicit "not for multipart" constraint; do not add new options or a new webhook path.

### `lib/lattice_stripe/charge.ex` and `guides/payments.md` (public-resource docs / consumer workflow, CRUD)

**Analogs:** Charge moduledoc lines 1-97 and `guides/payments.md` `## Charge reconciliation` lines 223-239.

```elixir
## When not to use this module
- **Accept a payment** -> `LatticeStripe.PaymentIntent.create/3`
...
## SDK surface (intentionally omitted)
There is no `create/3` or `cancel/3` — this module does not initiate payments.
```

```markdown
There is no `Charge.create/3` — charges are created as a side effect of PaymentIntent
confirmation.
```

These are the two and only two canonical full-policy surfaces. Replace historic Phase-18 wording with durable task language that explicitly names `Charge.create/3` and `PaymentIntent.create/3`; in the guide's reconciliation section include the exact direct server-side `PaymentIntent.create` example with amount, currency, payment method, and `"confirm" => true`, explain the resulting Charge is for reconciliation, and distinguish browser/Stripe.js confirmation and possible SCA/customer action.

### `test/lattice_stripe/docs_truth_test.exs` (documentation-contract test, transform)

**Analog:** scoped payments assertions at lines 273-310 and Charge moduledoc lock at lines 866-881.

```elixir
payments = File.read!("guides/payments.md")
assert payments =~ "## Charge reconciliation"
{creating_idx, _} = :binary.match(payments, "## Creating a PaymentIntent")
{charge_idx, _} = :binary.match(payments, "## Charge reconciliation")
assert creating_idx < charge_idx
```

Follow the existing direct-file, section-aware pattern, but extract the Charge reconciliation range before asserting policy anchors so unrelated prose cannot satisfy it. Assert both this bounded guide section and Charge's moduledoc name `Charge.create/3` and `PaymentIntent.create/3`; assert `"confirm" => true` in the guide's direct-server explanation. Add the CacheBodyReader ExDoc group/publicization assertion here, following the module-doc lock style at lines 1219-1230.

### `guides/api_stability.md` and `priv/api/current.txt` (public API contract / generated snapshot)

**Analog:** internal exclusion list at `guides/api_stability.md` lines 35-55, API surface lock at `test/lattice_stripe/api_surface_lock_test.exs` lines 20-31, and documented update procedure in `CONTRIBUTING.md` lines 86-95.

```elixir
expected = ApiSurface.lock_path() |> File.read!() |> ApiSurface.parse()
actual = ApiSurface.lines()
case ApiSurface.diff(expected, actual) do
  {[], []} -> :ok
  {removed, added} -> flunk(ApiSurface.format_diff(removed, added))
end
```

Remove only `LatticeStripe.Webhook.CacheBodyReader` from the guide's non-public list. After its real public moduledoc/API change is complete, run `mix lattice_stripe.api_surface --update` and commit the intentional `priv/api/current.txt` diff; do not hand-edit the lock or weaken the test.

## Shared Patterns

### Ordered response-header evidence

**Sources:** `lib/lattice_stripe/response.ex` lines 29-67; `lib/lattice_stripe/client.ex` lines 730-799.

Apply to Error's struct, `/4` constructor, both decoded and non-JSON HTTP failures, and retry tests. Header tuples stay verbatim; only lookup/parsing derives convenience data. Connection errors get their struct defaults and no fabricated header evidence.

### Optional Plug boundary

**Sources:** `lib/lattice_stripe/webhook/cache_body_reader.ex` lines 1-33; `lib/lattice_stripe/webhook/plug.ex` lines 1-44.

All CacheBodyReader changes remain inside `if Code.ensure_loaded?(Plug)`. Docs must say availability is conditional; production integration tests remain Plug-backed.

### Consumer docs are executable contracts

**Sources:** `test/lattice_stripe/docs_truth_test.exs` lines 296-310, 866-881; `test/lattice_stripe/charge_test.exs` lines 331-344.

Add scoped prose tests alongside the existing structural negative capability test. Do not use broad repository grep or change historical plans/audits as evidence.

### Strict docs and API gates

**Sources:** `mix.exs` lines 230-240; `.github/workflows/ci.yml` lines 216-263; `CONTRIBUTING.md` lines 86-129.

`mix ci` already runs API surface and `docs --warnings-as-errors`; CI's named docs-truth/API-lock and Quality docs steps provide enforcement. Zero ExDoc warnings is the baseline—no differential warning mechanism or warning-cleanup work is needed. The post-phase milestone audit is a workflow action; do not rewrite `.planning/v1.10-MILESTONE-AUDIT.md`.

## No Analog Found

None. Every planned edit extends an established project-local pattern. The strict public `retry_after` parser is intentionally new behavior, but its storage and lookup convention comes directly from `LatticeStripe.Response.get_header/2`; it must not borrow the retry strategy's capped parser.

## Metadata

**Analog search scope:** `lib/lattice_stripe`, `test/lattice_stripe`, `guides`, `priv/api`, `mix.exs`, `.github/workflows/ci.yml`, `CONTRIBUTING.md`  
**Files scanned:** 24 focused source, test, guide, CI, and lock files  
**Pattern extraction date:** 2026-08-25
