# Phase 7: Webhooks - Research

**Researched:** 2026-04-03
**Domain:** Stripe webhook signature verification, Elixir Plug, HMAC-SHA256
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Split by concern: `LatticeStripe.Webhook` (pure verification functions), `LatticeStripe.Event` (top-level resource struct like Customer/PaymentIntent), `LatticeStripe.Webhook.Plug` (Phoenix Plug), `LatticeStripe.Webhook.Handler` (behaviour for Plug dispatch).
- **D-02:** Event is a top-level resource module — not nested under Webhook — because it's also a Stripe API resource (`GET /v1/events/:id`, `GET /v1/events`).
- **D-03:** Fully typed top-level fields: id, type, data, request, account, api_version, created, livemode, pending_webhooks, object (default "event"), extra (catch-all `%{}`). Follows `@known_fields` + `from_map/1` + `Map.drop` pattern.
- **D-04:** `data` field is a raw decoded map — `%{"object" => %{...}, "previous_attributes" => %{...}}`. NOT parsed into typed structs.
- **D-05:** `request` field is a raw decoded map or nil.
- **D-06:** `from_map/1` is infallible — missing fields become nil, unknown fields go to `extra`.
- **D-07:** Manual `defimpl Inspect` whitelist: id, type, object, created, livemode. Hides: data, request, account, extra.
- **D-08:** Event ships with retrieve/2, retrieve!/2, list/2, list!/2, stream/2, stream!/2. Read-only.
- **D-09:** Event types remain as raw strings. No constants module, no atom conversion.
- **D-10:** Webhook.Plug in two modes: without handler (assigns to `conn.assigns.stripe_event`, passes through); with handler (dispatches, returns 200/400, halts).
- **D-11:** Handler behaviour contract: `@callback handle_event(Event.t()) :: :ok | {:ok, term} | :error | {:error, term}`.
- **D-12:** Verify-gate: bad signature → 400 + halt. No handler → assign + pass through. `:ok`/`{:ok, _}` → 200 + halt. `:error`/`{:error, _}` → 400 + halt. Exception → re-raise. Invalid return → raise RuntimeError.
- **D-13:** Non-POST to webhook path → 405 Method Not Allowed with `Allow: POST` header + halt.
- **D-14:** NimbleOptions in `init/1`. Schema: secret (required), handler (optional, atom), at (optional, string), tolerance (optional, pos_integer, default 300).
- **D-15:** Optional `at:` path matching using stripity_stripe same-variable pattern match trick.
- **D-16:** Assigns key is `:stripe_event`.
- **D-17:** Ship `LatticeStripe.Webhook.CacheBodyReader`. Stash in `conn.private[:raw_body]`. Plug checks `conn.private[:raw_body]` first; falls back to `Plug.Conn.read_body/2`.
- **D-18:** `construct_event` and Plug accept `String.t() | [String.t(), ...]`. Try each secret, return first match.
- **D-19:** Plug accepts `{Module, :function, [args]}` tuples and zero-arity functions. Resolved in `call/2`.
- **D-20:** Tolerance configurable in `construct_event/4` opts and Plug init. Default 300 seconds.
- **D-21:** Error atoms: `:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`.
- **D-22:** Bang variants: `construct_event!/3,4`, `verify_signature!/3,4`. Raise `LatticeStripe.Webhook.SignatureVerificationError` with `:message` and `:reason` fields.
- **D-23:** Five public functions in `LatticeStripe.Webhook`: construct_event/3,4, construct_event!/3,4, verify_signature/3,4, verify_signature!/3,4, generate_test_signature/2,3.
- **D-24:** Only `Webhook.Plug` and `Webhook.CacheBodyReader` wrapped in `if Code.ensure_loaded?(Plug)`. All other modules compile unconditionally.
- **D-25:** `{:plug_crypto, "~> 2.0"}` as required dep; `{:plug, "~> 1.16", optional: true}`.
- **D-26:** No Logger calls in webhook code. No telemetry in Phase 7.
- **D-27:** Ship `@moduledoc` and `@doc` on every module.
- **D-28:** Two test files: `webhook_test.exs` and `webhook/plug_test.exs`. All `async: true`.

### Claude's Discretion

- Internal HMAC implementation details (how to parse the `t=...v1=...` header format)
- Exact NimbleOptions schema structure for Plug init
- File organization within `lib/lattice_stripe/webhook/`
- Test fixture organization and helper module structure
- SignatureVerificationError `defexception` field details beyond :message and :reason

### Deferred Ideas (OUT OF SCOPE)

- Webhook telemetry events — Phase 8
- Integration tests against stripe-mock — Phase 9
- `LatticeStripe.Testing` module with webhook event factory helpers — Phase 9
- Documentation guides — Phase 10
- Auto-parsing `data.object` into typed structs — future
- Event type constants/atoms module — explicitly rejected

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WHBK-01 | User can verify webhook signature against raw request body with timing-safe comparison | HMAC-SHA256 algorithm verified against Stripe docs; `Plug.Crypto.secure_compare/2` confirmed for constant-time comparison |
| WHBK-02 | User can parse verified webhook payload into a typed Event struct | Event struct pattern established from existing resource modules; Stripe Event object fields verified against API docs |
| WHBK-03 | User can configure signature tolerance window (default 300 seconds) | Stripe default is 300s (5 minutes); NimbleOptions `:pos_integer` type confirmed for validation |
| WHBK-04 | Library provides a Phoenix Plug that handles raw body extraction and signature verification | Both mounting strategies researched; `at:` pattern from stripity_stripe confirmed; CacheBodyReader Plug.Parsers integration confirmed |
| WHBK-05 | Webhook Plug documents and solves the Plug.Parsers raw body consumption problem | `conn.private[:raw_body]` via `put_private/3` is the library-correct location; CacheBodyReader stash pattern researched; two-strategy documentation approach confirmed |

</phase_requirements>

---

## Summary

Phase 7 delivers the complete webhook reception pipeline: a pure verification module, an Event struct mirroring existing resource patterns, a Phoenix Plug with two mounting strategies, and a test helper for generating valid signatures. All architectural decisions have been locked in CONTEXT.md — this research validates the technical implementation path and documents the specific APIs and patterns the planner needs.

The core algorithm is straightforward: parse the `Stripe-Signature` header to extract `t=` (timestamp) and `v1=` (signature), reconstruct the signed payload as `"#{timestamp}.#{raw_body}"`, compute `HMAC-SHA256(secret, signed_payload)`, and compare the hex-encoded result against the header's `v1=` value using `Plug.Crypto.secure_compare/2`. Timestamp staleness check is a simple integer subtraction against `System.system_time(:second)`. All of this is pure Erlang/Elixir — no external HTTP involved.

The main complexity is the Plug integration, specifically the raw body problem. Research confirms two viable strategies (endpoint-level `at:` mounting and CacheBodyReader) that should both be supported, exactly as D-17 specifies. The `conn.private` store is the correct location for library-internal state per Plug conventions (D-17 uses `:raw_body` in `conn.private`, which is the library-appropriate location vs `conn.assigns` which is application-level). File organization follows the established nested-module-as-subdirectory pattern already used by checkout and transport.

**Primary recommendation:** Follow all CONTEXT.md decisions exactly. The research confirms every locked decision is technically sound. Implementation is purely additive — no existing modules need modification except `mix.exs` for dependency additions.

---

## Standard Stack

### Core Dependencies (already in project or adding now)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| plug_crypto | ~> 2.0 | `Plug.Crypto.secure_compare/2` for timing-safe HMAC comparison | Required dep per D-25; transitively pulled by Plug but declared explicitly |
| plug | ~> 1.16 | `Plug.Conn`, `Plug.Test`, body reading | Optional dep per D-25; already Elixir ecosystem standard |
| :crypto (OTP) | OTP stdlib | `:crypto.mac(:hmac, :sha256, key, data)` for HMAC computation | Ships with OTP, no dep needed |

### Already In Project

| Library | Version | Purpose |
|---------|---------|---------|
| jason | ~> 1.4 | JSON decode of webhook payload body |
| nimble_options | ~> 1.0 | Plug `init/1` option validation |

**Verified current versions (from mix.exs):**

The project currently declares `{:finch, "~> 0.19"}` — note CLAUDE.md recommends `~> 0.21`. That gap is not Phase 7's concern. For Phase 7, the new deps are:

```elixir
{:plug_crypto, "~> 2.0"},
{:plug, "~> 1.16", optional: true},
```

**Installation (additions to mix.exs `deps/0`):**

```elixir
{:plug_crypto, "~> 2.0"},
{:plug, "~> 1.16", optional: true},
```

---

## Architecture Patterns

### Recommended File Structure

```
lib/lattice_stripe/
├── event.ex                     # LatticeStripe.Event (top-level resource, not nested)
├── webhook.ex                   # LatticeStripe.Webhook (pure verification)
└── webhook/
    ├── plug.ex                  # LatticeStripe.Webhook.Plug (wrapped in Code.ensure_loaded?)
    ├── handler.ex               # LatticeStripe.Webhook.Handler (pure behaviour)
    ├── cache_body_reader.ex     # LatticeStripe.Webhook.CacheBodyReader (wrapped in Code.ensure_loaded?)
    └── signature_verification_error.ex  # LatticeStripe.Webhook.SignatureVerificationError

test/lattice_stripe/
├── event_test.exs               # Event struct + API resource tests
├── webhook_test.exs             # Pure crypto: construct_event, verify_signature, generate_test_signature
└── webhook/
    └── plug_test.exs            # Plug.Test-based integration tests

test/support/fixtures/
└── event.ex                     # LatticeStripe.Test.Fixtures.Event (mirrors customer.ex, checkout_session.ex)
```

### Pattern 1: Stripe HMAC-SHA256 Verification

**What:** Parse the `Stripe-Signature` header, reconstruct the signed payload, compute HMAC, compare with timing-safe comparison.

**Algorithm (verified against Stripe docs):**

```
signed_payload = "#{timestamp}.#{raw_body}"
expected_sig   = HMAC-SHA256(signing_secret, signed_payload) |> Base.encode16(case: :lower)
valid?         = Plug.Crypto.secure_compare(expected_sig, received_sig)
```

**Header format:** `"t=1492774577,v1=5257a869e7..."` — comma-separated, each part is `key=value`. A single header may contain multiple `v1=` entries (Stripe rolls secrets during rotation). Only `v1=` schemes are checked; `v0=` (test mode) is ignored.

**Example (internal implementation — Claude's discretion):**

```elixir
# Source: Stripe docs + Plug.Crypto HexDocs
defp parse_header(header) do
  # "t=1492774577,v1=abc123,v1=def456"
  parts = String.split(header, ",")

  timestamp =
    Enum.find_value(parts, fn part ->
      case String.split(part, "=", parts: 2) do
        ["t", ts] -> ts
        _ -> nil
      end
    end)

  signatures =
    Enum.flat_map(parts, fn part ->
      case String.split(part, "=", parts: 2) do
        ["v1", sig] -> [sig]
        _ -> []
      end
    end)

  case {timestamp, signatures} do
    {nil, _} -> {:error, :invalid_header}
    {_, []} -> {:error, :invalid_header}
    {ts, sigs} -> {:ok, ts, sigs}
  end
end

defp compute_signature(payload, timestamp, secret) do
  signed_payload = "#{timestamp}.#{payload}"
  :crypto.mac(:hmac, :sha256, secret, signed_payload)
  |> Base.encode16(case: :lower)
end

defp signatures_match?(expected, received_sigs) do
  Enum.any?(received_sigs, fn sig ->
    Plug.Crypto.secure_compare(expected, sig)
  end)
end
```

### Pattern 2: Event Struct (mirrors Customer/PaymentIntent)

**What:** Standard resource struct pattern with `@known_fields`, `from_map/1`, `defimpl Inspect`.

**Stripe Event fields (verified against Stripe API docs):**

| Field | Type | Note |
|-------|------|------|
| id | string | e.g., "evt_..." |
| object | string | always "event" |
| account | string \| nil | Connect platform account |
| api_version | string \| nil | e.g., "2026-03-25.dahlia" |
| context | string \| nil | newer field, include in known_fields |
| created | integer | Unix timestamp |
| data | map | `%{"object" => %{...}, "previous_attributes" => %{...}}` |
| livemode | boolean | |
| pending_webhooks | integer | |
| request | map \| nil | `%{"id" => "req_...", "idempotency_key" => "..."}` |
| type | string | e.g., "payment_intent.succeeded" |

**Note:** Stripe docs show `context` as a newer nullable field. Include it in `@known_fields` so it lands in the struct rather than `extra`.

**Example (following established pattern):**

```elixir
# Source: lib/lattice_stripe/customer.ex pattern
@known_fields ~w[id object account api_version context created data livemode
                  pending_webhooks request type]

defstruct [
  :id, :account, :api_version, :context, :created, :data, :livemode,
  :pending_webhooks, :request, :type,
  object: "event",
  extra: %{}
]
```

### Pattern 3: Plug `at:` Path Matching

**What:** Store split path in opts during `init/1`, use same-variable pattern match in `call/2`.

**Verified pattern (from stripity_stripe research):**

```elixir
# Source: beam-community/stripity_stripe webhook_plug.ex + quick task 260402-wte
def init(opts) do
  validated = NimbleOptions.validate!(opts, @schema)
  path_info =
    case Keyword.get(validated, :at) do
      nil -> nil
      at -> String.split(at, "/", trim: true)
    end
  Map.new(validated) |> Map.put(:path_info, path_info)
end

# Three call/2 clauses in order:
# 1. POST to matching path (or no path filter) -> process
# 2. Non-POST to matching path -> 405
# 3. Path doesn't match -> pass through

def call(%Conn{method: "POST", path_info: path_info} = conn, %{path_info: path_info} = opts)
    when not is_nil(path_info) do
  handle_webhook(conn, opts)
end

def call(%Conn{} = conn, %{path_info: nil} = opts) do
  # No `at:` configured — process every POST (router-level mounting via forward)
  if conn.method == "POST", do: handle_webhook(conn, opts), else: conn
end

def call(%Conn{path_info: path_info} = conn, %{path_info: path_info}) do
  # Matching path, non-POST
  conn
  |> put_resp_header("allow", "POST")
  |> send_resp(405, "Method Not Allowed")
  |> halt()
end

def call(conn, _opts), do: conn
```

**Key insight:** The same variable name `path_info` in both `%Conn{path_info: path_info}` and `%{path_info: path_info}` implements structural equality matching. This is idiomatic Elixir pattern matching — no explicit `==` needed.

### Pattern 4: CacheBodyReader

**What:** Wrap `Plug.Conn.read_body/2`, stash raw body in `conn.private`.

**Decision D-17 uses `conn.private` (not `conn.assigns`)** — this is correct per Plug conventions: `assigns` is for application-level data, `private` is for library/framework internal state.

```elixir
# Source: Plug.Parsers HexDocs (body_reader option)
# Uses conn.private instead of conn.assigns per Plug conventions
if Code.ensure_loaded?(Plug) do
  defmodule LatticeStripe.Webhook.CacheBodyReader do
    @moduledoc """
    Caches the raw request body for webhook signature verification.
    ...
    """

    def read_body(conn, opts) do
      with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:ok, body, conn}
      end
    end
  end
end
```

**Plug reads body:** `conn.private[:raw_body]` first. If nil, falls back to `Plug.Conn.read_body/2` directly (works when Plug is mounted before `Plug.Parsers` in endpoint.ex).

### Pattern 5: Multi-Secret Iteration

**What:** Normalize secret to list, try each, return first match.

```elixir
# Decision D-18: guard-based normalization
defp normalize_secrets(secret) when is_binary(secret), do: [secret]
defp normalize_secrets(secrets) when is_list(secrets), do: secrets

defp try_secrets(payload, timestamp, signatures, secrets) do
  Enum.find_value(secrets, :no_matching_signature, fn secret ->
    expected = compute_signature(payload, timestamp, secret)
    if signatures_match?(expected, signatures), do: :matched, else: false
  end)
end
```

### Pattern 6: MFA/Function Secret Resolution in Plug

**Decision D-19 — resolved in `call/2`, not `init/1`:**

```elixir
defp resolve_secret({mod, fun, args}), do: apply(mod, fun, args)
defp resolve_secret(fun) when is_function(fun, 0), do: fun.()
defp resolve_secret(secret), do: secret
```

**Why `call/2` not `init/1`:** `init/1` runs at compile time in production (Phoenix compiles plugs). Secrets aren't available at compile time in Docker/Kubernetes environments. Resolution at `call/2` ensures the value is always fresh.

### Pattern 7: NimbleOptions Schema for Plug

**Decision D-14 — recommended schema structure:**

```elixir
# Source: lib/lattice_stripe/config.ex pattern + NimbleOptions HexDocs
@schema NimbleOptions.new!(
  secret: [
    type: {:or, [:string, {:list, :string}, :mfa, {:fun, 0}]},
    required: true,
    doc: "Webhook signing secret(s). Accepts a string, list of strings for multi-secret support, {M,F,A} tuple, or zero-arity function for runtime resolution."
  ],
  handler: [
    type: {:or, [:atom, nil]},
    default: nil,
    doc: "Module implementing LatticeStripe.Webhook.Handler behaviour. When provided, dispatches to handle_event/1 and returns 200/400."
  ],
  at: [
    type: {:or, [:string, nil]},
    default: nil,
    doc: "Mount path for endpoint-level installation (e.g., \"/webhooks/stripe\"). When omitted, processes every request (use with router-level forward)."
  ],
  tolerance: [
    type: :pos_integer,
    default: 300,
    doc: "Maximum allowed age of webhook timestamp in seconds. Default 300 (5 minutes)."
  ]
)
```

### Pattern 8: SignatureVerificationError

**Decision D-22 — `defexception` with `:message` and `:reason`:**

```elixir
defmodule LatticeStripe.Webhook.SignatureVerificationError do
  defexception [:message, :reason]

  @impl true
  def exception(opts) do
    reason = Keyword.fetch!(opts, :reason)
    message = Keyword.get(opts, :message, default_message(reason))
    %__MODULE__{message: message, reason: reason}
  end

  defp default_message(:missing_header), do: "No Stripe-Signature header found"
  defp default_message(:invalid_header), do: "Stripe-Signature header is malformed"
  defp default_message(:no_matching_signature), do: "Signature verification failed — no secret matched"
  defp default_message(:timestamp_expired), do: "Webhook timestamp is too old (replay attack protection)"
end
```

### Anti-Patterns to Avoid

- **String comparison for HMAC:** Never use `==` to compare signatures. `Plug.Crypto.secure_compare/2` is mandatory — timing attacks are real.
- **Parsing body after Plug.Parsers:** `Plug.Conn.read_body/2` returns `{:ok, "", conn}` after Parsers has run. Plug must either be before Parsers, or use CacheBodyReader.
- **Resolving secrets in `init/1`:** Compile-time secret resolution breaks container deployments where env vars are injected at runtime.
- **Mutating `conn.assigns` in library code:** Use `conn.private` for library-internal state (raw_body). Use `conn.assigns` for values the application should read (`:stripe_event`).
- **Accepting `v0=` signatures:** Stripe only guarantees `v1=` for HMAC-SHA256. `v0=` is a test-only fake; ignore non-`v1=` schemes in production.
- **Using `String.to_atom/1` for event types:** 250+ types, user-defined via Stripe Dashboard, can exhaust the atom table. Keep as strings.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timing-safe byte comparison | Custom loop comparing byte-by-byte | `Plug.Crypto.secure_compare/2` | Constant-time guarantee from the Plug team; timing attacks are subtle to prevent correctly |
| HMAC-SHA256 computation | Pure Elixir hash loop | `:crypto.mac(:hmac, :sha256, key, data)` | OTP stdlib, FIPS-certified, no dep needed |
| Option schema validation in Plug | Hand-rolled keyword validation with `Keyword.get` and `is_binary` guards | `NimbleOptions.new!/1` + `NimbleOptions.validate!/2` | Already in project; generates documentation; provides clear error messages |
| Path segment splitting | `String.split(path, "/") \|> Enum.filter(...)` | `String.split(path, "/", trim: true)` | One call, handles leading slash, idiomatic — same as stripity_stripe |

**Key insight:** The crypto primitives (HMAC computation, timing-safe comparison) must come from established, audited sources. A hand-rolled constant-time comparison is easy to get wrong — compilers can optimize away loops, Elixir's binary comparison may short-circuit. Only `Plug.Crypto.secure_compare/2` gives the guarantee.

---

## Common Pitfalls

### Pitfall 1: Raw Body Consumed Before Plug Runs

**What goes wrong:** Developer mounts `Webhook.Plug` after `Plug.Parsers` in endpoint.ex. `Plug.Conn.read_body/2` returns `{:ok, "", conn}`. Signature computed against empty string. All events return `:no_matching_signature`.

**Why it happens:** `Plug.Parsers` consumes the body stream. It's a one-time read. After parsing, the stream is closed.

**How to avoid:** Document both mounting strategies prominently in `Webhook.Plug` `@moduledoc`. Strategy A: mount before `Plug.Parsers` with `at:` option. Strategy B: configure `CacheBodyReader` in `Plug.Parsers`, mount via `forward` in router.

**Warning signs:** All webhooks return 400; Stripe Dashboard shows delivery failures; test passes locally but fails in production (different parsers ordering).

### Pitfall 2: `init/1` Called at Compile Time in Production

**What goes wrong:** NimbleOptions `secret: System.get_env("STRIPE_WEBHOOK_SECRET")` evaluated in `init/1` returns nil at compile time. All signature verifications fail silently or raise at runtime.

**Why it happens:** Phoenix compiles plugs at startup (or compile time in releases). `init/1` is not a runtime function.

**How to avoid:** Support MFA tuples and zero-arity functions for the `secret` option (D-19). Document this prominently. Resolve secrets in `call/2`.

**Warning signs:** Works in development (env vars always loaded), fails in Docker/CI where env vars arrive after compile.

### Pitfall 3: Comparing Hex-Encoded vs Raw Bytes

**What goes wrong:** Developer computes `:crypto.mac(:hmac, :sha256, key, payload)` which returns raw bytes (binary). Stripe's `v1=` value in the header is hex-encoded lowercase string. Comparing them directly always fails.

**Why it happens:** HMAC returns `<<90, 21, 255, ...>>` but the header contains `"5a15ff..."`.

**How to avoid:** Always `Base.encode16(hmac_bytes, case: :lower)` before comparing with `secure_compare/2`.

**Warning signs:** Signatures always fail even with correct secret and payload.

### Pitfall 4: Multiple `v1=` Entries in Header

**What goes wrong:** During Stripe secret rotation, the header contains TWO `v1=` entries: `"t=123,v1=abc,v1=def"`. Parser only takes the first, misses the match with the new secret.

**Why it happens:** Stripe sends signatures for all active secrets during a rotation window.

**How to avoid:** `Enum.flat_map` over all header parts, collect all `v1=` values into a list, try each against each secret.

**Warning signs:** Signature failures during key rotation periods only.

### Pitfall 5: Path Matching with Trailing Slash

**What goes wrong:** User configures `at: "/webhooks/stripe/"` (trailing slash). `String.split("/webhooks/stripe/", "/", trim: true)` produces `["webhooks", "stripe"]` — same as without trailing slash. Stripe sends request to `/webhooks/stripe` (no trailing slash). `conn.path_info` is `["webhooks", "stripe"]`. Match succeeds. **This is actually fine — `trim: true` handles it correctly.**

Actual pitfall: User configures `at: "/webhooks/stripe"` but route is registered as `/webhooks/stripe/` in Phoenix router. `conn.path_info` differs. No match.

**How to avoid:** Use `String.split(at, "/", trim: true)` — handles leading and trailing slashes. Document to match exactly what Phoenix router uses.

### Pitfall 6: `conn.private` vs `conn.assigns` for Raw Body

**What goes wrong:** Library stores raw body in `conn.assigns[:raw_body]`. Application code also uses `:raw_body` key in assigns for other purposes. Collision.

**Why it happens:** `assigns` is shared application space; `private` is library space.

**How to avoid:** D-17 already makes the right call — `conn.private[:raw_body]` for CacheBodyReader storage (library internal), `conn.assigns[:stripe_event]` for the parsed event (application-consumable output).

---

## Code Examples

### Full Verification Flow

```elixir
# Source: Stripe webhook signature docs + Plug.Crypto HexDocs

def verify_signature(payload, sig_header, secret, opts \\ []) do
  tolerance = Keyword.get(opts, :tolerance, 300)

  with {:ok, timestamp_str, signatures} <- parse_header(sig_header),
       {timestamp, ""} <- Integer.parse(timestamp_str),
       :ok <- check_tolerance(timestamp, tolerance),
       secrets = normalize_secrets(secret),
       :ok <- match_any_secret(payload, timestamp_str, signatures, secrets) do
    {:ok, timestamp}
  end
end

defp check_tolerance(timestamp, tolerance) do
  now = System.system_time(:second)
  if now - timestamp > tolerance, do: {:error, :timestamp_expired}, else: :ok
end
```

### Plug Test Pattern

```elixir
# Source: Plug.Test HexDocs + existing test patterns
defmodule LatticeStripe.Webhook.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias LatticeStripe.Webhook

  @secret "whsec_test_secret"
  @payload ~s({"id":"evt_123","type":"payment_intent.succeeded"})

  test "returns 200 for valid signature (no handler mode)" do
    sig = Webhook.generate_test_signature(@payload, @secret)

    conn =
      conn(:post, "/webhooks/stripe", @payload)
      |> put_req_header("stripe-signature", sig)
      |> put_req_header("content-type", "application/json")

    opts = LatticeStripe.Webhook.Plug.init(secret: @secret, at: "/webhooks/stripe")
    conn = LatticeStripe.Webhook.Plug.call(conn, opts)

    assert conn.assigns[:stripe_event] != nil
    refute conn.halted
  end
end
```

### generate_test_signature Implementation

```elixir
# Source: D-23 API design + Stripe algorithm
def generate_test_signature(payload, secret, opts \\ []) do
  timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
  sig = compute_signature(payload, Integer.to_string(timestamp), secret)
  "t=#{timestamp},v1=#{sig}"
end
```

### Event from_map/1 Pattern

```elixir
# Source: lib/lattice_stripe/customer.ex pattern
@known_fields ~w[id object account api_version context created data livemode
                  pending_webhooks request type]

def from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    object: map["object"] || "event",
    account: map["account"],
    api_version: map["api_version"],
    context: map["context"],
    created: map["created"],
    data: map["data"],
    livemode: map["livemode"],
    pending_webhooks: map["pending_webhooks"],
    request: map["request"],
    type: map["type"],
    extra: Map.drop(map, @known_fields)
  }
end
```

### Inspect Implementation (whitelist)

```elixir
# Source: lib/lattice_stripe/customer.ex Inspect pattern
defimpl Inspect, for: LatticeStripe.Event do
  import Inspect.Algebra

  def inspect(event, opts) do
    # Show structural fields only. Hide: data (full PII objects), request
    # (idempotency keys), account, extra.
    fields = [
      id: event.id,
      type: event.type,
      object: event.object,
      created: event.created,
      livemode: event.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Event<" | pairs] ++ [">"])
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| stripity_stripe stores raw body in `conn.assigns` | Use `conn.private` for library state | Plug docs have always specified this; just a convention gap | Avoids naming collision with user assigns |
| stripity_stripe returns 400 for non-POST requests | Return 405 with `Allow: POST` header | HTTP spec best practice; D-13 decision | More correct, better debuggability |
| stripity_stripe error strings like `"No signatures found matching the expected signature for payload"` | Error atoms `:missing_header`, `:no_matching_signature`, etc. | LatticeStripe design; Plug.Crypto/Phoenix.Token convention | Pattern-matchable, not string-parseable |
| Single-secret webhook verification (all official SDKs) | Multi-secret `String.t() \| [String.t()]` | LatticeStripe innovation | Covers key rotation overlap and Connect multi-endpoint natively |

**Deprecated/outdated:**

- `v0=` scheme in `Stripe-Signature`: Test-mode only; ignore in signature matching (Stripe docs explicitly say so)
- `Plug.Conn.read_body/2` called inside controller after `Plug.Parsers`: Will always return empty body; use endpoint-level or CacheBodyReader

---

## Open Questions

1. **`context` field in Event struct**
   - What we know: Stripe API docs list `context` as a nullable string field in the Event object (newer addition)
   - What's unclear: Whether it appears in the `@known_fields` matters for ensuring it doesn't land in `extra`
   - Recommendation: Include `context` in `@known_fields` and struct. Cost is one nil field. Value is forward-compatibility.

2. **`:crypto.mac/4` vs `:crypto.hmac/3` API**
   - What we know: `:crypto.hmac/3` was deprecated in OTP 23; `:crypto.mac(:hmac, :sha256, key, data)` is the current API. OTP 26+ is the project minimum.
   - What's unclear: Nothing — this is verified. Use `:crypto.mac/4`.
   - Recommendation: Use `:crypto.mac(:hmac, :sha256, secret, signed_payload)`. OTP 28 (current env) and 26 (min) both support this.

3. **Plug.Test raw body behavior**
   - What we know: `Plug.Test.conn(:post, path, body_string)` sets the body in a way that `Plug.Conn.read_body/2` can read it once.
   - What's unclear: Whether `conn.private[:raw_body]` can be pre-set in test to simulate CacheBodyReader, or if tests must actually call `read_body/2`.
   - Recommendation: In `webhook/plug_test.exs`, pre-set `conn.private[:raw_body]` directly using `Plug.Conn.put_private/3` to test the CacheBodyReader path without needing actual Parsers setup. Test the direct `read_body/2` path by not setting private.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 7 is code/config changes only. New deps (`plug_crypto`, `plug`) are Hex packages fetched by `mix deps.get`. No external services, CLIs, or runtimes beyond the Elixir/OTP already confirmed present (Elixir 1.19.5 / OTP 28).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/webhook/plug_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WHBK-01 | `verify_signature/4` with known payload+secret returns `{:ok, timestamp}` | unit | `mix test test/lattice_stripe/webhook_test.exs -x` | Wave 0 |
| WHBK-01 | Bad signature returns `{:error, :no_matching_signature}` | unit | `mix test test/lattice_stripe/webhook_test.exs -x` | Wave 0 |
| WHBK-01 | `Plug.Crypto.secure_compare/2` is used (not `==`) | code review | N/A (reviewer check) | N/A |
| WHBK-02 | `construct_event/4` returns `{:ok, %Event{}}` with typed fields | unit | `mix test test/lattice_stripe/webhook_test.exs -x` | Wave 0 |
| WHBK-02 | `Event.from_map/1` handles all 11 Stripe fields | unit | `mix test test/lattice_stripe/event_test.exs -x` | Wave 0 |
| WHBK-03 | Expired timestamp returns `{:error, :timestamp_expired}` | unit | `mix test test/lattice_stripe/webhook_test.exs -x` | Wave 0 |
| WHBK-03 | Custom tolerance option respected | unit | `mix test test/lattice_stripe/webhook_test.exs -x` | Wave 0 |
| WHBK-04 | Plug with valid sig assigns `:stripe_event` and passes through | integration | `mix test test/lattice_stripe/webhook/plug_test.exs -x` | Wave 0 |
| WHBK-04 | Plug with invalid sig returns 400 and halts | integration | `mix test test/lattice_stripe/webhook/plug_test.exs -x` | Wave 0 |
| WHBK-04 | Plug with handler dispatches, returns 200 on `:ok` | integration | `mix test test/lattice_stripe/webhook/plug_test.exs -x` | Wave 0 |
| WHBK-04 | Non-POST returns 405 with Allow header | integration | `mix test test/lattice_stripe/webhook/plug_test.exs -x` | Wave 0 |
| WHBK-05 | `@moduledoc` on `Webhook.Plug` covers raw body problem | doc review | `mix docs` (Wave 0 or final gate) | Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/event_test.exs --no-start`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green + `mix credo --strict` before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/webhook_test.exs` — covers WHBK-01, WHBK-02, WHBK-03
- [ ] `test/lattice_stripe/event_test.exs` — covers WHBK-02 (Event struct + API resource)
- [ ] `test/lattice_stripe/webhook/plug_test.exs` — covers WHBK-04, WHBK-05
- [ ] `test/support/fixtures/event.ex` — `LatticeStripe.Test.Fixtures.Event` with `event_json/0`

---

## Sources

### Primary (HIGH confidence)

- Stripe Webhook Signatures docs (https://docs.stripe.com/webhooks/signatures) — HMAC-SHA256 algorithm, header format, signed payload construction, tolerance
- Stripe Event Object API docs (https://docs.stripe.com/api/events/object) — all 11 top-level fields including `context`
- Plug.Crypto HexDocs (https://hexdocs.pm/plug_crypto/Plug.Crypto.html) — `secure_compare/2` signature and constant-time guarantee
- Plug.Parsers HexDocs (https://hexdocs.pm/plug/Plug.Parsers.html) — `body_reader` option, CacheBodyReader MFA format
- Plug.Conn HexDocs (https://hexdocs.pm/plug/Plug.Conn.html) — `assigns` vs `private` distinction, `put_private/3`, `read_body/2`
- Plug.Test HexDocs (https://hexdocs.pm/plug/Plug.Test.html) — `conn/3` signature, `put_req_header/3`
- NimbleOptions HexDocs (https://hexdocs.pm/nimble_options/NimbleOptions.html) — `{:or, [...]}`, `:mfa`, `{:fun, 0}` types
- Quick task 260402-wte RESEARCH.md — stripity_stripe `at:` pattern, `Plug.Router.forward/2` path_info behavior, all three mounting strategies
- lib/lattice_stripe/customer.ex — @known_fields + from_map/1 + Inspect defimpl pattern
- lib/lattice_stripe/config.ex — NimbleOptions schema compiled at module load pattern
- lib/lattice_stripe/resource.ex — unwrap_singular/2, unwrap_list/2, unwrap_bang!/1

### Secondary (MEDIUM confidence)

- stripity_stripe source (beam-community/stripity_stripe) — WebhookPlug implementation (via quick task research); confirms `at:` pattern, `String.split(at, "/", trim: true)`, three-clause `call/2` structure

### Tertiary (LOW confidence)

None — all key findings verified against official sources.

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all deps verified on Hex.pm; OTP `:crypto.mac/4` API verified against OTP 26+ docs
- Architecture: HIGH — all patterns sourced from official Plug docs and existing project code
- Verification algorithm: HIGH — verified directly against Stripe official docs
- Pitfalls: HIGH — all sourced from official docs, Plug.Conn docs, and prior research
- Test patterns: HIGH — based on existing project test conventions

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable domain — Stripe webhook algorithm and Plug patterns rarely change)
