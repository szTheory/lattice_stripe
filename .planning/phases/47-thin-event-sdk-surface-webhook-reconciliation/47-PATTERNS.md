# Phase 47: Thin-Event SDK Surface & Webhook Reconciliation - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 17 (8 new, 9 modified)
**Analogs found:** 17 / 17 (every new/modified file has a strong in-tree precedent)

## File Classification

| New/Modified File | Status | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|--------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/event_notification.ex` | NEW | top-level struct module | infallible deserialize + custom Inspect | `lib/lattice_stripe/event.ex` | exact |
| `lib/lattice_stripe/event_notification/related_object.ex` | NEW | nested sub-struct module | infallible deserialize | `lib/lattice_stripe/invoice/line_item.ex` | exact |
| `lib/lattice_stripe/event.ex` | MOD | top-level struct module | add nested-struct decode in `from_map/1` | self (already has the pattern) | exact (in-file) |
| `lib/lattice_stripe/webhook.ex` | MOD | functional core (verify + decode + fetch helpers) | request-response w/ HMAC verify | self — `construct_event/4` is the verify-then-decode template | exact (in-file) |
| `lib/lattice_stripe/webhook/plug.ex` | MOD | Plug boundary / NimbleOptions schema | request-response | self (schema row swap only) | exact (in-file) |
| `lib/lattice_stripe/object_types.ex` | MOD | dispatch table / utility | lookup | self — `maybe_deserialize/1` reads the same `@object_map` | exact (in-file) |
| `lib/lattice_stripe/testing.ex` | MOD | test helper module | build + sign payload | self — `generate_webhook_payload/3` + `dispute/1` | exact (in-file) |
| `test/lattice_stripe/event_notification_test.exs` | NEW | unit test (from_map + Inspect) | unit | `test/lattice_stripe/event_test.exs` describe blocks "from_map/1" + "Inspect" | exact |
| `test/lattice_stripe/webhook/fetch_test.exs` | NEW | unit test (Mox-driven HTTP) | unit (Mox) | `test/lattice_stripe/event_test.exs` describe "retrieve/3" | exact |
| `test/support/fixtures/event_notification.ex` | NEW | fixture builder | data | `test/support/fixtures/event.ex` | exact |
| `test/lattice_stripe/webhook_test.exs` | MOD | unit test (verify + parse) | unit | self (`:121` test + sibling describes) | exact (in-file) |
| `test/lattice_stripe/webhook/plug_test.exs` | MOD | unit test (Plug.Test) | unit | self (existing Plug.Test cases) | partial (need to find existing file) |
| `test/lattice_stripe/testing_test.exs` | MOD | unit test | unit | self | partial |
| `test/lattice_stripe/object_types_test.exs` | MOD | unit test | unit | self | partial |
| `test/lattice_stripe/event_test.exs` | MOD | unit test | unit | self — add cases to existing `from_map/1` describe | exact (in-file) |
| `test/lattice_stripe/docs_truth_test.exs` | MOD | docs-truth regression test | grep test | self | partial |
| `CHANGELOG.md` | MOD | release notes | docs | self (prior v1.4 entry) | partial |

---

## Pattern Assignments

### `lib/lattice_stripe/event_notification/related_object.ex` (NEW — nested sub-struct module)

**Analog:** `lib/lattice_stripe/invoice/line_item.ex`

**File-layout convention** — the precedent file lives at `lib/lattice_stripe/<parent>/<sub>.ex`, with module name `LatticeStripe.<Parent>.<Sub>`. Mirror exactly for `LatticeStripe.EventNotification.RelatedObject`.

**`@known_fields` + `defstruct` + `@type t` block** (lib/lattice_stripe/invoice/line_item.ex:52-125 — adapt down to 3 fields):

```elixir
@known_fields ~w[id type url]

defstruct [:id, :type, :url, extra: %{}]

@type t :: %__MODULE__{
        id: String.t() | nil,
        type: String.t() | nil,
        url: String.t() | nil,
        extra: map()
      }
```

**`from_map/1` pattern with nil handling** (lib/lattice_stripe/invoice/line_item.ex:145-179):

```elixir
@spec from_map(map() | nil) :: t() | nil
def from_map(nil), do: nil

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)

  %__MODULE__{
    id: known["id"],
    type: known["type"],
    url: known["url"],
    extra: extra
  }
end
```

The `from_map(nil), do: nil` clause is load-bearing — `EventNotification.from_map/1` and `Event.from_map/1` both call `RelatedObject.from_map(map["related_object"])` unconditionally and rely on `nil` round-tripping.

**Inspect impl** (lib/lattice_stripe/invoice/line_item.ex:182-212) — copy with field-set `[:id, :type, :url]` (and `extra` only when non-empty). Note: `RelatedObject.url` is **not** a sensitive Stripe-signed URL (it's a relative path like `/v2/core/accounts/acct_...`), so showing it in Inspect is fine and matches LineItem precedent.

---

### `lib/lattice_stripe/event_notification.ex` (NEW — top-level module)

**Analog:** `lib/lattice_stripe/event.ex`

**Module layout, aliases, `@known_fields`, `defstruct`** (lib/lattice_stripe/event.ex:40-64). Adapt to thin-event field set. Per RESEARCH.md Finding 1, `object` default is `"v2.core.event"` (not `"v2.core.event_notification"`):

```elixir
defmodule LatticeStripe.EventNotification do
  @moduledoc """..."""

  alias LatticeStripe.EventNotification.RelatedObject

  # Wire-shape fields per stripe-node v2 EventNotificationBase.
  # See research.md Finding 1: object string is "v2.core.event" on the wire.
  @known_fields ~w[id object type created context livemode related_object reason]

  defstruct [
    :id,
    :type,
    :created,       # NOTE: ISO 8601 string per wire, NOT Unix integer (research Finding 2)
    :context,
    :livemode,
    :related_object,
    :reason,
    object: "v2.core.event",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          type: String.t() | nil,
          created: String.t() | nil,
          context: String.t() | nil,
          livemode: boolean() | nil,
          related_object: RelatedObject.t() | nil,
          reason: map() | nil,
          extra: map()
        }
end
```

**`from_map/1` pattern with nested-struct decode** — mirror `Event.from_map/1` (lib/lattice_stripe/event.ex:213-229) exactly, swapping `RelatedObject.from_map(map["related_object"])` in for the `related_object` field:

```elixir
@spec from_map(map()) :: t()
def from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    object: map["object"] || "v2.core.event",
    type: map["type"],
    created: map["created"],
    context: map["context"],
    livemode: map["livemode"],
    related_object: RelatedObject.from_map(map["related_object"]),
    reason: map["reason"],
    extra: Map.drop(map, @known_fields)
  }
end
```

Note: `Event` uses bare `map["x"]` lookups (not `Map.split/2`-style); follow that convention for consistency.

**Inspect impl** (lib/lattice_stripe/event.ex:232-255) — copy structure, field set `[:id, :type, :object, :created, :livemode, :related_object]`. Hide `:extra` and `:reason` (request id / idempotency key live inside `:reason` — same "hide noisy/auth-adjacent fields" rule the Event Inspect follows).

---

### `lib/lattice_stripe/event.ex` (MOD — add `related_object` to existing struct)

**Analog:** self (already has the exact pattern).

**Three concrete edits** (in-file):

1. Extend `@known_fields` at `:46-49` — add `related_object`:
   ```elixir
   @known_fields ~w[
     id object account api_version context created data livemode
     pending_webhooks request type related_object
   ]
   ```

2. Extend `defstruct` at `:51-64` — add `:related_object` field with `nil` default:
   ```elixir
   defstruct [
     :id, :account, :api_version, :context, :created, :data,
     :livemode, :pending_webhooks, :related_object, :request, :type,
     object: "event",
     extra: %{}
   ]
   ```

3. Extend `@type t` at `:87-100` — add `related_object: EventNotification.RelatedObject.t() | nil` and add `alias LatticeStripe.EventNotification.RelatedObject` at top.

4. Extend `from_map/1` at `:213-229` — add one line decoding the nested map:
   ```elixir
   related_object: RelatedObject.from_map(map["related_object"]),
   ```

Backwards compat: `Event.from_map(snapshot_payload)` → `related_object: nil` (because `map["related_object"]` returns nil → `RelatedObject.from_map(nil) → nil`).

**Optional — `Event.created` type widening** (per RESEARCH.md Finding 3, Open Question 2): when an `Event` is fetched from `/v2/core/events/{id}`, `created` arrives as ISO string. Recommendation in research: widen `@type t` `created` from `integer() | nil` to `integer() | String.t() | nil`. Planner should flag for user confirmation.

---

### `lib/lattice_stripe/webhook.ex` — `parse_event_notification/4` + bang variant (MOD)

**Analog:** self — `construct_event/4` at `lib/lattice_stripe/webhook.ex:91-108`.

**Verify-then-decode pattern** (lib/lattice_stripe/webhook.ex:93-108) — copy verbatim, swap target module:

```elixir
@spec parse_event_notification(String.t(), String.t() | nil, secret(), keyword()) ::
        {:ok, EventNotification.t()} | {:error, verify_error()}
def parse_event_notification(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
  LatticeStripe.Telemetry.webhook_verify_span([], fn ->
    case verify_signature(payload, sig_header, secret, opts) do
      {:ok, _timestamp} ->
        notification =
          payload
          |> Jason.decode!()
          |> EventNotification.from_map()

        {:ok, notification}

      {:error, _reason} = error ->
        error
    end
  end)
end
```

**Bang variant pattern** (lib/lattice_stripe/webhook.ex:118-124):

```elixir
@spec parse_event_notification!(String.t(), String.t() | nil, secret(), keyword()) ::
        EventNotification.t()
def parse_event_notification!(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
  case parse_event_notification(payload, sig_header, secret, opts) do
    {:ok, notif} -> notif
    {:error, reason} -> raise SignatureVerificationError, reason: reason
  end
end
```

Both functions reuse: `verify_signature/4` (unchanged), `Jason.decode!/1`, `webhook_verify_span/2`, and `SignatureVerificationError` (which already supports the exact 4-atom set per `lib/lattice_stripe/webhook/signature_verification_error.ex:28-29`).

---

### `lib/lattice_stripe/webhook.ex` — `fetch_event/3` + bang variant (MOD)

**Analog:** `Event.retrieve/3` at `lib/lattice_stripe/event.ex:122-127` (the `Request → Client.request → Resource.unwrap_singular` pipeline).

**CRITICAL correction per RESEARCH.md Finding 3:** Path is `/v2/core/events/#{id}`, NOT `/v1/events/#{id}`. Do **not** delegate to `Event.retrieve/3` (which calls v1).

**Inline pipeline pattern** (adapted from lib/lattice_stripe/event.ex:123-126):

```elixir
@spec fetch_event(Client.t(), EventNotification.t() | String.t(), keyword()) ::
        {:ok, Event.t()} | {:error, Error.t() | :no_event_id}

# Defensive clause for malformed notifications
def fetch_event(%Client{} = _client, %EventNotification{id: nil}, _opts),
  do: {:error, :no_event_id}

# Notification → extract id → delegate
def fetch_event(%Client{} = client, %EventNotification{id: id}, opts) when is_binary(id),
  do: fetch_event(client, id, opts)

# Bare string id form
def fetch_event(%Client{} = client, id, opts) when is_binary(id) do
  %Request{method: :get, path: "/v2/core/events/#{id}", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&Event.from_map/1)
end
```

**Bang variant pattern** (lib/lattice_stripe/event.ex:132-135):

```elixir
@spec fetch_event!(Client.t(), EventNotification.t() | String.t(), keyword()) :: Event.t()
def fetch_event!(%Client{} = client, notif_or_id, opts \\ []) do
  fetch_event(client, notif_or_id, opts) |> Resource.unwrap_bang!()
end
```

Per-request opts `:api_version` / `:idempotency_key` flow through `Client.request/2` automatically (see lib/lattice_stripe/client.ex:180-204). The `:client` per-request opt is a no-op here since client is passed explicitly.

Required new aliases at top of `webhook.ex`:
```elixir
alias LatticeStripe.{Client, Error, EventNotification, Request, Resource, Response}
alias LatticeStripe.EventNotification.RelatedObject
alias LatticeStripe.ObjectTypes
```

---

### `lib/lattice_stripe/webhook.ex` — `fetch_related_object/3` + bang variant (MOD)

**Analog:** `Event.retrieve/3` pipeline (HTTP shape) + `ObjectTypes.maybe_deserialize/1` (dispatch).

**Typed-error gate before HTTP** (RESEARCH Pattern 4, anchored on `lib/lattice_stripe/object_types.ex:55-60`):

```elixir
@spec fetch_related_object(Client.t(), EventNotification.t(), keyword()) ::
        {:ok, struct()}
        | {:error, Error.t() | {:unknown_object_type, String.t()} | :no_related_object}

def fetch_related_object(%Client{} = _client, %EventNotification{related_object: nil}, _opts),
  do: {:error, :no_related_object}

def fetch_related_object(
      %Client{} = client,
      %EventNotification{related_object: %RelatedObject{type: type, url: url}},
      opts
    ) do
  case ObjectTypes.fetch_module(type) do
    {:ok, _module} ->
      %Request{method: :get, path: url, params: %{}, opts: opts}
      |> then(&Client.request(client, &1))
      |> case do
        {:ok, %Response{data: raw}} -> {:ok, ObjectTypes.maybe_deserialize(raw)}
        {:error, %Error{}} = error -> error
      end

    :error ->
      {:error, {:unknown_object_type, type}}
  end
end
```

`:expand` opt support is free via `Client.request/2` (lib/lattice_stripe/client.ex:200, `expand = Keyword.get(req.opts, :expand, [])` → `merge_expand/2` at `:695-705`).

**Bang variant pattern** — for typed-error atoms (`{:unknown_object_type, _}`, `:no_related_object`), construct a minimal `LatticeStripe.Error{type: :invalid_request, message: "..."}` to collapse to the standard bang exception type:

```elixir
@spec fetch_related_object!(Client.t(), EventNotification.t(), keyword()) :: struct()
def fetch_related_object!(%Client{} = client, %EventNotification{} = notif, opts \\ []) do
  case fetch_related_object(client, notif, opts) do
    {:ok, obj} -> obj
    {:error, %Error{} = err} -> raise err
    {:error, {:unknown_object_type, type}} ->
      raise %Error{type: :invalid_request, message: "Unknown Stripe object type: #{type}"}
    {:error, :no_related_object} ->
      raise %Error{type: :invalid_request, message: "EventNotification has no related_object"}
  end
end
```

---

### `lib/lattice_stripe/webhook.ex` — WEBFIX-01 four-surface reconciliation (MOD)

**Analog:** self — the current broken behavior is at `lib/lattice_stripe/webhook.ex:268-273`.

**Current broken code** (lib/lattice_stripe/webhook.ex:266-273):

```elixir
# Checks that the webhook timestamp is within the tolerance window.
# tolerance: 0 means any non-current timestamp will fail.
defp check_tolerance(_timestamp, 0) do
  # tolerance: 0 means any age is expired — we always compare against current time
  # We must still check: if timestamp == now it's fine, otherwise expired.
  # But since this is called per-second, we skip the 0 case with a special path.
  {:error, :timestamp_expired}
end
```

**Replacement per D-03:**

```elixir
# tolerance: 0 disables the staleness check entirely (matches stripe-node's
# `if (tolerance > 0 && ...)` gate and stripe-go's IgnoreTolerance flag).
# Use this in tests with `:timestamp` overrides; never in production traffic.
# Reconciles four-surface drift documented in WEBFIX-01 (CHANGELOG v1.5).
defp check_tolerance(_timestamp, 0), do: :ok
```

**Docstring touchup at `:84`** — already says "Set `0` to disable staleness check" so the docstring is correct; flag for cross-reference to the inline comment.

---

### `lib/lattice_stripe/webhook/plug.ex` — NimbleOptions schema swap (MOD)

**Analog:** self — schema entry at `lib/lattice_stripe/webhook/plug.ex:142-146`.

**Current** (lib/lattice_stripe/webhook/plug.ex:142-146):

```elixir
tolerance: [
  type: :pos_integer,
  default: 300,
  doc: "Max age of webhook timestamp in seconds."
]
```

**Replacement per D-03:**

```elixir
tolerance: [
  type: :non_neg_integer,
  default: 300,
  doc: "Max age of webhook timestamp in seconds. Set 0 to disable the staleness check (testing only)."
]
```

Per RESEARCH Assumption A3, verify with `iex> NimbleOptions.validate([tolerance: 0], [tolerance: [type: :non_neg_integer]])`. `:non_neg_integer` is documented in NimbleOptions ~> 1.0.

---

### `lib/lattice_stripe/object_types.ex` — new `fetch_module/1` helper (MOD)

**Analog:** self — `maybe_deserialize/1` already reads `@object_map` at `lib/lattice_stripe/object_types.ex:55-60`.

**Add immediately after `object_map/0` at `:49`:**

```elixir
@doc """
Looks up the LatticeStripe module for a Stripe object type string.

Returns `{:ok, module}` for known types and `:error` for unknown types.
Used by `LatticeStripe.Webhook.fetch_related_object/3` to gate HTTP requests
behind dispatch-table membership (fail fast on unknown types — see Phase 47 D-05).
"""
@spec fetch_module(String.t() | nil) :: {:ok, module()} | :error
def fetch_module(nil), do: :error
def fetch_module(type) when is_binary(type), do: Map.fetch(@object_map, type)
```

This is the same `Map.fetch/2` lookup already used inside `maybe_deserialize/1` at `:56` — just exposed as a public `@spec` boundary for the typed-gate pattern. No new dispatch entries per CONTEXT D-05.

---

### `lib/lattice_stripe/testing.ex` — `generate_thin_event_payload/3` + `event_notification/1` (MOD)

**Analog A — sign-payload builder:** `generate_webhook_payload/3` at `lib/lattice_stripe/testing.ex:197-221`.

**Snapshot pattern to mirror** (lib/lattice_stripe/testing.ex:197-221):

```elixir
@spec generate_webhook_payload(String.t(), map(), keyword()) :: {String.t(), String.t()}
def generate_webhook_payload(type, object_data \\ %{}, opts) do
  {secret, opts} = Keyword.pop!(opts, :secret)
  {timestamp, event_opts} = Keyword.pop(opts, :timestamp, System.system_time(:second))

  id = Keyword.get(event_opts, :id, "evt_test_" <> random_hex(16))
  api_version = Keyword.get(event_opts, :api_version, @default_api_version)
  livemode = Keyword.get(event_opts, :livemode, false)

  raw_map = %{
    "id" => id,
    "object" => "event",        # ← snapshot uses "event"
    "type" => type,
    # ... snapshot-only fields (api_version, pending_webhooks, request, data) ...
  }

  payload = Jason.encode!(raw_map)
  sig_header = Webhook.generate_test_signature(payload, secret, timestamp: timestamp)
  {payload, sig_header}
end
```

**Thin-event adaptation (TESTING-01):**

```elixir
@spec generate_thin_event_payload(String.t(), map() | nil, keyword()) :: {String.t(), String.t()}
def generate_thin_event_payload(type, related_object_data \\ nil, opts) do
  {secret, opts} = Keyword.pop!(opts, :secret)
  {timestamp, notif_opts} = Keyword.pop(opts, :timestamp, System.system_time(:second))

  id = Keyword.get(notif_opts, :id, "evt_test_" <> random_hex(16))
  context = Keyword.get(notif_opts, :context)
  livemode = Keyword.get(notif_opts, :livemode, false)

  # ISO 8601 string per wire (research Finding 2)
  created_iso = DateTime.from_unix!(timestamp) |> DateTime.to_iso8601()

  raw_map = %{
    "id" => id,
    "object" => "v2.core.event",   # ← thin-event wire value (research Finding 1)
    "type" => type,
    "created" => created_iso,
    "context" => context,
    "livemode" => livemode,
    "related_object" => related_object_data
  }

  payload = Jason.encode!(raw_map)
  sig_header = Webhook.generate_test_signature(payload, secret, timestamp: timestamp)
  {payload, sig_header}
end
```

**Analog B — typed-builder helper:** `dispute/1` at `lib/lattice_stripe/testing.ex:78-79`.

**Snapshot pattern to mirror:**

```elixir
@spec dispute(map()) :: Dispute.t()
def dispute(raw_map), do: Dispute.from_map(raw_map)
```

**Thin-event adaptation:**

```elixir
@spec event_notification(map()) :: EventNotification.t()
def event_notification(raw_map), do: EventNotification.from_map(raw_map)
```

Add `EventNotification` to the alias block at lib/lattice_stripe/testing.ex:49-59.

`Webhook.generate_test_signature/3` (lib/lattice_stripe/webhook.ex:206-212) — unchanged, signs both shapes byte-for-byte the same:

```elixir
def generate_test_signature(payload, secret, opts \\ []) when is_binary(payload) do
  timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
  timestamp_str = Integer.to_string(timestamp)
  signature = compute_signature(payload, timestamp_str, secret)
  "t=#{timestamp_str},v1=#{signature}"
end
```

---

### `test/support/fixtures/event_notification.ex` (NEW)

**Analog:** `test/support/fixtures/event.ex` (the whole file is 30 lines — the precedent).

**File-layout convention** (test/support/fixtures/event.ex:1-30):

```elixir
defmodule LatticeStripe.Test.Fixtures.EventNotification do
  @moduledoc false

  def event_notification_map(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO",
        "object" => "v2.core.event",
        "type" => "v2.core.account.updated",
        "livemode" => false,
        "created" => "2026-03-09T13:00:28.435Z",
        "context" => nil,
        "reason" => %{
          "type" => "request",
          "request" => %{
            "id" => "req_v2y9y15XqG3Futmjg",
            "idempotency_key" => "ik_TgmEI3jHxXt8RFw4jS7ve2QcAReDQWBjPAkAEUm"
          }
        },
        "related_object" => %{
          "id" => "acct_1T93Q4Pmpb34Vto6",
          "type" => "v2.core.account",
          "url" => "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
        }
      },
      overrides
    )
  end

  def event_notification_map_no_related_object(overrides \\ %{}) do
    event_notification_map(%{"related_object" => nil} |> Map.merge(overrides))
  end
end
```

Concrete payload values lifted from RESEARCH.md "Wire-format reference payload" block (lines 576-597) — sourced from stripe-node v2 events test fixtures.

---

### `test/lattice_stripe/event_notification_test.exs` (NEW)

**Analog:** `test/lattice_stripe/event_test.exs` (the file has the exact describe/test structure to copy — from_map + Inspect + missing-fields + extra-fields).

**Setup pattern** (test/lattice_stripe/event_test.exs:1-10):

```elixir
defmodule LatticeStripe.EventNotificationTest do
  use ExUnit.Case, async: true

  import LatticeStripe.Test.Fixtures.EventNotification,
    only: [event_notification_map: 0, event_notification_map: 1, event_notification_map_no_related_object: 0]

  alias LatticeStripe.EventNotification
  alias LatticeStripe.EventNotification.RelatedObject
end
```

**`from_map/1` describe block** (mirror test/lattice_stripe/event_test.exs:16-74):

- "maps all known fields correctly" — assert `id`, `object == "v2.core.event"`, `type`, `created` (string), `livemode`, `context`, `reason`
- "decodes nested related_object map to %RelatedObject{} struct"
- "related_object is nil when wire map has nil" (snapshot-style v2 events)
- "defaults object to 'v2.core.event' when missing"
- "unknown fields go to extra map"
- "missing fields are nil"

**`Inspect` describe block** (mirror test/lattice_stripe/event_test.exs:80-116):

- "shows id, type, object, created, livemode, related_object"
- "does NOT show extra"
- "does NOT show reason" (includes idempotency_key)
- **Per RESEARCH Pitfall 4 — security regression:** "inspect output does not contain '%Client' or 'sk_' or 'api_key'"

**`RelatedObject` describe block** — similar structure for the sub-struct: from_map + nil handling + Inspect.

---

### `test/lattice_stripe/webhook/fetch_test.exs` (NEW — Mox-driven HTTP tests)

**Analog:** `test/lattice_stripe/event_test.exs` describe "retrieve/3" at `:122-145`.

**Setup pattern** (test/lattice_stripe/event_test.exs:1-10):

```elixir
defmodule LatticeStripe.Webhook.FetchTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Event, only: [event_map: 0]
  import LatticeStripe.Test.Fixtures.EventNotification

  alias LatticeStripe.{Error, Event, EventNotification, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject

  setup :verify_on_exit!
end
```

**`fetch_event/3` happy-path pattern** (test/lattice_stripe/event_test.exs:123-134) — adapt URL assertion to v2 path:

```elixir
describe "fetch_event/3" do
  test "sends GET /v2/core/events/:id and returns {:ok, %Event{}}" do
    client = test_client()
    notif = EventNotification.from_map(event_notification_map())

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :get
      assert String.ends_with?(req.url, "/v2/core/events/#{notif.id}")
      ok_response(event_map(%{"id" => notif.id, "object" => "event"}))
    end)

    assert {:ok, %Event{id: id}} = Webhook.fetch_event(client, notif)
    assert id == notif.id
  end

  test "accepts bare String.t() id form" do
    client = test_client()

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert String.ends_with?(req.url, "/v2/core/events/evt_test_123")
      ok_response(event_map(%{"id" => "evt_test_123"}))
    end)

    assert {:ok, %Event{}} = Webhook.fetch_event(client, "evt_test_123")
  end

  test "returns {:error, :no_event_id} for %EventNotification{id: nil}" do
    client = test_client()
    # Mox expectation count = 0 (must NOT hit transport)
    assert {:error, :no_event_id} =
             Webhook.fetch_event(client, %EventNotification{id: nil})
  end
end
```

**`fetch_related_object/3` describe block** — same Mox/test_client/ok_response/error_response pattern:

- "returns {:ok, %Customer{}} for known related_object.type" (use customer fixture)
- "returns {:error, {:unknown_object_type, type}} BEFORE any HTTP call" — assert Mox expectation count = 0 via no `expect` call
- "returns {:error, :no_related_object} when related_object is nil"
- "uses related_object.url verbatim as request path"
- "honors :expand opt" — assert query string contains `expand[0]=...`

**`!` variant tests** — mirror test/lattice_stripe/event_test.exs:151-162 ("retrieve!/3 raises %Error{} on error response").

---

### `test/lattice_stripe/webhook_test.exs` — `:121` rewrite + `parse_event_notification/4` block (MOD)

**Analog:** self — existing describe block structure at `lib/lattice_stripe/webhook_test.exs:107-128`.

**Current `:121` test to rewrite** (test/lattice_stripe/webhook_test.exs:121-127):

```elixir
test "tolerance: 0 fails on any non-zero-age timestamp" do
  old_ts = System.system_time(:second) - 1
  header = Webhook.generate_test_signature(@payload, @secret, timestamp: old_ts)

  assert {:error, :timestamp_expired} =
           Webhook.verify_signature(@payload, header, @secret, tolerance: 0)
end
```

**Replacement per D-03:**

```elixir
test "tolerance: 0 disables the staleness check (any age accepted)" do
  ancient_ts = System.system_time(:second) - 100_000
  header = Webhook.generate_test_signature(@payload, @secret, timestamp: ancient_ts)

  assert {:ok, ^ancient_ts} =
           Webhook.verify_signature(@payload, header, @secret, tolerance: 0)
end
```

**New `describe "parse_event_notification/4"` block** — mirror existing `describe "construct_event/4"` patterns. Cover the full error-atom set (D-07): `:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`, plus the happy path returning `{:ok, %EventNotification{}}` with a populated `related_object`.

---

## Shared Patterns

### `{:ok, t()} | {:error, reason}` + bang variant convention

**Source:** `lib/lattice_stripe/event.ex:122-135` (retrieve/3 + retrieve!/3 pair).
**Apply to:** all 6 new public functions on `Webhook` (`parse_event_notification`, `fetch_event`, `fetch_related_object` + bang variants).

```elixir
@spec X(...) :: {:ok, t()} | {:error, Error.t()}
def X(...) do
  ...
  |> Resource.unwrap_singular(&Mod.from_map/1)
end

@spec X!(...) :: t()
def X!(...) do
  X(...) |> Resource.unwrap_bang!()
end
```

`Resource.unwrap_bang!/1` (lib/lattice_stripe/resource.ex:91-93) raises `%LatticeStripe.Error{}` on `{:error, %Error{}}`. For non-Error atom errors (e.g., `:no_event_id`), the bang variant must wrap them in `%Error{}` manually before raising — see `fetch_related_object!/3` pattern above.

### `from_map/1` infallible deserialization

**Source:** `lib/lattice_stripe/event.ex:213-229` (top-level) + `lib/lattice_stripe/invoice/line_item.ex:145-179` (nested with nil clause).
**Apply to:** `EventNotification.from_map/1`, `RelatedObject.from_map/1`.

Rules:
- Always succeeds (never returns `{:error, _}` — that's the resource boundary's job).
- Nested-struct fields: parent calls `Sub.from_map(map["key"])` unconditionally; `Sub.from_map/1` must handle `nil` input via `def from_map(nil), do: nil` clause.
- Unknown fields collected into `extra: %{}` via `Map.drop(map, @known_fields)` (top-level pattern) or `Map.split(map, @known_fields)` (Invoice.LineItem pattern). Either works — pick one per file and stay consistent.

### Custom `Inspect` impl hiding noisy/sensitive fields

**Source:** `lib/lattice_stripe/event.ex:232-255` (top-level) and `lib/lattice_stripe/invoice/line_item.ex:182-212` (nested).
**Apply to:** `EventNotification`, `RelatedObject`.

```elixir
defimpl Inspect, for: LatticeStripe.X do
  import Inspect.Algebra

  def inspect(x, opts) do
    fields = [key1: x.key1, key2: x.key2, ...]   # safe-to-show fields only

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.X<" | pairs] ++ [">"])
  end
end
```

Per RESEARCH Pitfall 4: include a test that asserts the `Inspect` output contains no `"api_key"`, `"sk_"`, or `"%Client"` strings.

### Mox-driven HTTP test pattern

**Source:** `test/lattice_stripe/event_test.exs:122-145` + `test/support/test_helpers.ex:6-53`.
**Apply to:** `test/lattice_stripe/webhook/fetch_test.exs`.

```elixir
use ExUnit.Case, async: true
import Mox
import LatticeStripe.TestHelpers
setup :verify_on_exit!

test "..." do
  client = test_client()

  expect(LatticeStripe.MockTransport, :request, fn req ->
    assert req.method == :get
    assert String.ends_with?(req.url, "/v2/core/events/evt_...")
    ok_response(event_map())   # or list_json([...]) or error_response()
  end)

  assert {:ok, %Event{}} = Webhook.fetch_event(client, "evt_...")
end
```

The `test_client/0` helper (test/support/test_helpers.ex:6-16) wires `transport: LatticeStripe.MockTransport`, `max_retries: 0`, `telemetry_enabled: false` — exactly the right shape for fetch-after-verify tests. `ok_response/1` and `error_response/0` produce the canonical `{:ok, %{status:, headers:, body:}}` transport response shape.

### Fixture-builder module convention

**Source:** `test/support/fixtures/event.ex:1-30` (and 33 other files in `test/support/fixtures/`).
**Apply to:** `test/support/fixtures/event_notification.ex`.

```elixir
defmodule LatticeStripe.Test.Fixtures.X do
  @moduledoc false

  def x_map(overrides \\ %{}) do
    Map.merge(%{"id" => "...", ...}, overrides)
  end
end
```

Always `@moduledoc false`, always `Map.merge(canonical_map, overrides)`. Helper functions for variant shapes (e.g., `event_notification_map_no_related_object/1`) wrap the canonical builder.

### Telemetry span at verify boundary

**Source:** `lib/lattice_stripe/webhook.ex:94` (`LatticeStripe.Telemetry.webhook_verify_span([], fn -> ... end)`).
**Apply to:** `parse_event_notification/4` (verify boundary is identical to `construct_event/4` per RESEARCH Architectural Responsibility Map). Use the exact same call — no new span event in v1.5.

### NimbleOptions schema convention

**Source:** `lib/lattice_stripe/webhook/plug.ex:123-147`.
**Apply to:** D-03 swap (`:pos_integer` → `:non_neg_integer`). The schema entry is otherwise unchanged. NimbleOptions ~> 1.0 supports `:non_neg_integer` (RESEARCH A3 — verify at planning time).

---

## No Analog Found

None — every file in this phase has a strong in-tree precedent. The phase is purely additive composition over already-shipped foundations (see RESEARCH "Don't Hand-Roll" table).

---

## Metadata

**Analog search scope:** `lib/lattice_stripe/`, `lib/lattice_stripe/webhook/`, `lib/lattice_stripe/invoice/`, `lib/lattice_stripe/credit_note/`, `test/lattice_stripe/`, `test/support/`, `test/support/fixtures/`.

**Files scanned (read in full or in targeted ranges):**
- `lib/lattice_stripe/event.ex` (256 lines — full read)
- `lib/lattice_stripe/webhook.ex` (315 lines — full read)
- `lib/lattice_stripe/webhook/plug.ex` (286 lines — full read)
- `lib/lattice_stripe/webhook/signature_verification_error.ex` (53 lines — full read)
- `lib/lattice_stripe/invoice/line_item.ex` (213 lines — full read; canonical nested sub-struct precedent)
- `lib/lattice_stripe/object_types.ex` (64 lines — full read)
- `lib/lattice_stripe/testing.ex` (225 lines — full read)
- `lib/lattice_stripe/resource.ex` (126 lines — full read)
- `lib/lattice_stripe/client.ex` (targeted reads at `:180-280` and `:680-740` for expand/request pipeline)
- `test/lattice_stripe/event_test.exs` (210 lines — full read; canonical Mox + from_map + Inspect test precedent)
- `test/lattice_stripe/webhook_test.exs` (targeted read `:1-160`)
- `test/support/test_helpers.ex` (64 lines — full read)
- `test/support/fixtures/event.ex` (30 lines — full read; canonical fixture-builder precedent)
- `test/support/fixtures/dispute.ex` (targeted read `:1-40`)

**Pattern extraction date:** 2026-05-27

---

## PATTERN MAPPING COMPLETE

**Phase:** 47 - Thin-Event SDK Surface & Webhook Reconciliation
**Files classified:** 17 (8 new, 9 modified)
**Analogs found:** 17 / 17

### Coverage
- Files with exact analog: 17
- Files with role-match analog: 0
- Files with no analog: 0

### Key Patterns Identified
- **Nested-sub-struct precedent is `Invoice.LineItem`** — exact file-layout, `@known_fields ~w[]`, `defstruct [..., extra: %{}]`, `from_map(nil) -> nil` + `from_map(map)` pair, and `defimpl Inspect` block. Mirror once for `EventNotification.RelatedObject`.
- **Top-level struct precedent is `Event`** — same `defstruct/@known_fields/@type t/from_map/1` shape plus the custom `Inspect` that hides noisy fields. Mirror for `EventNotification`, swapping field set to the v2 wire shape (`object: "v2.core.event"`, `created` as ISO string, nested `related_object`).
- **Verify-then-decode core** is `construct_event/4` at `webhook.ex:93-108` — copy verbatim into `parse_event_notification/4`, swap the `Event.from_map/1` call for `EventNotification.from_map/1`.
- **Retrieve pipeline** is `Event.retrieve/3` at `event.ex:122-127` — `%Request{} |> Client.request/2 |> Resource.unwrap_singular(&from_map/1)`. `fetch_event/3` mirrors this exactly with path `/v2/core/events/#{id}` (NOT `/v1/events/` — RESEARCH Finding 3).
- **Typed-error-gate** is the new `ObjectTypes.fetch_module/1` helper anchored on the existing `Map.fetch(@object_map, type)` call inside `maybe_deserialize/1` at `object_types.ex:56`. One-line addition; no new dispatch entries.
- **Mox-driven HTTP tests** follow `event_test.exs:122-145` exactly — `test_client/0` + `expect(LatticeStripe.MockTransport, :request, ...)` + `ok_response(event_map())`. The "no HTTP" assertion for typed-error-gate tests = no `expect` call (Mox verifies on exit).
- **Testing helpers** split into two parallel APIs — `dispute/1`-style typed builders (lines 78-103 of `testing.ex`) → `event_notification/1`; and `generate_webhook_payload/3`-style signed-payload builders (lines 197-221) → `generate_thin_event_payload/3`. Both adaptations swap snapshot fields for the thin-event wire shape and reuse `Webhook.generate_test_signature/3` byte-for-byte.
- **WEBFIX-01 is a one-line code swap** on `webhook.ex:268-273` (`{:error, :timestamp_expired}` → `:ok`) plus a NimbleOptions atom swap on `plug.ex:144` (`:pos_integer` → `:non_neg_integer`). Bounded blast radius — deserves its own dedicated plan.

### File Created
`/Users/jon/projects/lattice_stripe/.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Every new file has a concrete in-tree analog with file-path + line-range citations. Planner can embed these excerpts directly into `<read_first>` blocks of each plan without re-deriving from research.
