# Phase 64: Meter Event-Summary Reads - Pattern Map

**Mapped:** 2026-07-28
**Files analyzed:** 18 (7 new lib/test modules, 11 modified)
**Analogs found:** 17 / 18

All hinted analogs were verified against real source at HEAD. **Two hints did not hold as stated** — see
`## Hint Corrections` before planning.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/billing/meter_event_summary.ex` **NEW** | resource module | request-response (GET list + stream) | `lib/lattice_stripe/transfer_reversal.ex` | exact (parent-scoped, flat, wire-named, ships `list/4`+`stream!/4`) |
| — its guard block | validation | pre-network raise | `lib/lattice_stripe/entitlements/active_entitlement.ex:140-150,180-195` | exact |
| — its `validate_id!/2` | validation | pre-network raise | `lib/lattice_stripe/external_account.ex:271-278` | exact |
| `lib/lattice_stripe/billing/meter_error_report.ex` **NEW** | value object (non-resource) | transform (event `data` → struct) | `lib/lattice_stripe/entitlements/active_entitlement_summary.ex` | exact (no `:id`, nested decode, `Map.split` + `:extra`) |
| `lib/lattice_stripe/billing/meter_error_report/reason.ex` **NEW** | value object | transform (array-of-struct fan-out) | `lib/lattice_stripe/tax/calculation.ex:198-203` (`parse_tax_breakdown/1`) | exact |
| `lib/lattice_stripe/billing/meter_error_report/error_type.ex` **NEW** | value object | transform | `lib/lattice_stripe/tax/calculation.ex:198-203` + `billing/meter/value_settings.ex` | exact |
| `lib/lattice_stripe/billing/meter_error_report/sample_error.ex` **NEW** | value object (leaf) | transform | `lib/lattice_stripe/billing/meter/value_settings.ex` | exact |
| `lib/lattice_stripe/billing/guards.ex` **EDIT** (GUARD-04) | guard module | pre-network raise | same file, `check_meter_value_settings!/1` (GUARD-01) | exact (in-file sibling) |
| `lib/lattice_stripe/drift.ex:210` **EDIT** | utility | transform (regex parse) | n/a — one-line regex widen | no analog needed |
| `lib/lattice_stripe/billing/meter_event.ex:26-30` **EDIT** | resource `@doc` | docs | n/a — targeted prose edit | no analog needed |
| `mix.exs:179-190` **EDIT** | config | n/a | same block (append to `"Billing Metering"`) | exact |
| `test/.../billing/meter_event_summary_test.exs` **NEW** | test | request-response + refutation | `test/lattice_stripe/entitlements/active_entitlement_test.exs:216-244` | exact |
| `test/.../billing/meter_event_summary_pagination_test.exs` **NEW** | test | Mox-at-Transport pagination | `test/lattice_stripe/list_test.exs:384-449` | exact |
| `test/.../billing/meter_error_report_test.exs` **NEW** | test | pure transform, no transport | `test/lattice_stripe/entitlements/active_entitlement_test.exs` (decode describe blocks) | role-match |
| `test/support/fixtures/metering.ex` **NEW** | test fixture module | data | `test/support/fixtures/entitlements.ex` | exact |
| `test/integration/meter_event_summary_integration_test.exs` **NEW** | integration test | request-response | `test/integration/charge_integration_test.exs:1-33` | exact |
| `test/.../form_encoder_test.exs` **EDIT** | test | transform | same file (existing 26/27 tests) | exact |
| `test/.../docs_truth_test.exs` **EDIT** | test | config assertion | same file, `:89` block | exact |
| `guides/metering.md`, `guides/metering-runtime-and-reconciliation.md`, `guides/scope.md` **EDIT** | docs | n/a | `guides/entitlements.md:250-268` (stub idiom) | role-match |

## Hint Corrections

Verify these before planning — the prompt's hints are close but not exact:

1. **`transfer_reversal.ex` uses `when id in [nil, ""]` *function clauses*, NOT a private `validate_id!/2`.**
   CONTEXT D-09 explicitly chooses the *other* form. The `validate_id!/2` helper lives in
   `external_account.ex:271-278` and its message is **generic (no arity, no function name)**:
   `"LatticeStripe.ExternalAccount requires a non-empty binary #{name}"`. D-09 mandates a *different*
   message carrying the arity — so the helper's **shape** is copied but its **message** is not.
2. **`guides/entitlements.md`'s "PROMOTION TARGET" header comment is on `test/support/fixtures/entitlements.ex`
   (lines 1-6) and names `Phase 65 / OBJ-02`, not `(Phase 65)`.** Clone the 6-line form verbatim, swapping
   the module/file names.
3. **`Billing.Guards` has `@moduledoc false`** — the GUARD-01…03 block is a plain `#` comment, not moduledoc.
   GUARD-04's line goes in that comment block; user-facing prose must go on the *function's* `@doc`.
4. **`tax_id.ex` was not needed.** F-04 makes its dual-mode structurally inapplicable; `transfer_reversal.ex`
   plus `active_entitlement.ex` cover every pattern this phase needs. Do not read it.

## Pattern Assignments

### `lib/lattice_stripe/billing/meter_event_summary.ex` (resource module, request-response)

**Analog:** `lib/lattice_stripe/transfer_reversal.ex` (structure) + `entitlements/active_entitlement.ex`
(guards, `from_map` idempotency, moduledoc voice)

**Imports / aliases** — `transfer_reversal.ex:59` vs `active_entitlement.ex:70-71`. **Use the narrower
`active_entitlement.ex` form** (this module needs no `ObjectTypes`; F-13/D-14 and Phase 63's precedent both
say do not route through it):

```elixir
alias LatticeStripe.{Client, Request, Resource}
```

**Path constant** — `active_entitlement.ex:73-75`. Adopt this so `list/4` and `stream!/4` cannot diverge:

```elixir
# D-06: the canonical path lives here once. `list/3`, the streaming variant, and the
# summary module's url rewrite all read it, so they physically cannot diverge.
@list_path "/v1/entitlements/active_entitlements"
```
→ here it is interpolated, so make it a private function: `defp path(meter_id), do: "/v1/billing/meters/#{meter_id}/event_summaries"`.

**`@known_fields`** — `active_entitlement.ex:79` uses `~w(...)` **parens**. D-19 mandates `~w[...]` **square
brackets** (that is exactly the `drift.ex:210` bug). Copy the *bracket* form from
`transfer_reversal.ex:63-66`:

```elixir
  # Known top-level fields from the Stripe TransferReversal object.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object amount balance_transaction created currency
    destination_payment_refund metadata source_refund transfer
  ]
```

**defstruct with wire-object default** — `transfer_reversal.ex:68-80` / `active_entitlement.ex:90-97`:

```elixir
  defstruct [
    :id,
    :feature,
    :lookup_key,
    :livemode,
    object: "entitlements.active_entitlement",
    extra: %{}
  ]
```

**Core `list/4` pattern (parent-scoped)** — `transfer_reversal.ex:227-244`. This is the transliteration
target; replace the `when id in [nil, ""]` clauses with D-09's `validate_id!/2` call:

```elixir
  @spec list(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list(client, transfer_id, params \\ %{}, opts \\ [])

  def list(%Client{}, id, _params, _opts) when id in [nil, ""] do
    raise ArgumentError, ~s|TransferReversal.list/4 requires a non-empty transfer id|
  end

  def list(%Client{} = client, transfer_id, params, opts) when is_binary(transfer_id) do
    %Request{
      method: :get,
      path: "/v1/transfers/#{transfer_id}/reversals",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end
```

**Bang twin** — `transfer_reversal.ex:246-250`:

```elixir
  @doc "Like `list/4` but raises on failure."
  @spec list!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list!(client, transfer_id, params \\ %{}, opts \\ []) do
    client |> list(transfer_id, params, opts) |> Resource.unwrap_bang!()
  end
```

**`stream!/4` — the `List.stream!/2` delegation** — `transfer_reversal.ex:258-274` for the parent-scoped
shape, `active_entitlement.ex:180-195` for the guard-first ordering + the comment that must be preserved:

```elixir
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    # MUST be the first statement. `Stream.resource/3` defers its start function, so a
    # guard constructed lazily would not raise until the stream is consumed.
    Resource.require_param!(
      params,
      "customer",
      "LatticeStripe.Entitlements.ActiveEntitlement.stream!/3 requires a customer param"
    )

    req = %Request{method: :get, path: @list_path, params: params, opts: opts}

    # The cursor state machine — base_params preservation, the starting_after cursor, and
    # the idempotency-key strip on page fetches — belongs to LatticeStripe.List and is not
    # re-grown here. This function's only job is to hand it correctly-shaped state.
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end
```

**Guard block (D-08 × 3)** — `billing/meter.ex:90-109` is the verbatim-message lock (note the vowel on
`an event_name`, which D-08 mirrors for `an end_time`):

```elixir
    Resource.require_param!(
      params,
      "display_name",
      "LatticeStripe.Billing.Meter.create/3 requires a display_name param"
    )

    Resource.require_param!(
      params,
      "event_name",
      "LatticeStripe.Billing.Meter.create/3 requires an event_name param"
    )
```
Note `meter.ex:110` then calls `Billing.Guards.check_meter_value_settings!(params)` **after** the
`require_param!` calls and **before** `%Request{}` — that is exactly where GUARD-04 goes.

**Private id guard (D-09)** — `external_account.ex:267-278`, copy the shape, replace the message:

```elixir
  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Pre-network guard: raise ArgumentError immediately on empty / nil / non-binary.
  defp validate_id!(value, _name) when is_binary(value) and value != "", do: :ok

  defp validate_id!(_value, name) do
    raise ArgumentError,
          "LatticeStripe.ExternalAccount requires a non-empty binary #{name}"
  end
```

**`from_map/1` with idempotency clause + `Map.split`** — `active_entitlement.ex:210-234`. The comment on
`:213` is load-bearing and must be carried:

```elixir
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil

  # The struct clause MUST precede the `is_map/1` clause — a struct is a map.
  def from_map(%__MODULE__{} = entitlement), do: entitlement

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "entitlements.active_entitlement",
      ...
      extra: extra
    }
  end
```

**Moduledoc voice** — `active_entitlement.ex:1-68` is the freshest and best model: opening one-line
definition, wire object + id prefix + path in paragraph 1, an admonition block
(`> #### ... {: .warning}`) for the one surprising fact, a `## Listing` section that states the `limit`
default-10 truncation trap, then `## Usage`. Phase 64's warning block should carry F-02 (no `customer`
field on the returned object) and F-09 (eventual consistency, no freshness field).

---

### `lib/lattice_stripe/billing/meter_error_report.ex` (value object, transform)

**Analog:** `lib/lattice_stripe/entitlements/active_entitlement_summary.ex` (no-`:id` struct, nested decode)
+ `lib/lattice_stripe/tax/calculation.ex` (array-of-typed-substructs)

**No-`:id` decode with `Map.split`** — `active_entitlement_summary.ex:70,134-140`:

```elixir
  @known_fields ~w(object customer entitlements livemode)
  ...
  def from_map(nil), do: nil
  def from_map(%__MODULE__{} = summary), do: summary
  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
```
Phase 64 drops `object` and `livemode` from that list (D-17) and adds N-01's four fields:
`~w[developer_message_summary reason validation_start validation_end]` — **square brackets** (D-19/D-20).

**Array fan-out to typed sub-structs** — `tax/calculation.ex:198-203`. This is the exact shape for
`Reason.error_types` and `ErrorType.sample_errors`, except D-19 requires `[]` not `nil` on the empty branch:

```elixir
  defp parse_tax_breakdown(nil), do: nil

  defp parse_tax_breakdown(items) when is_list(items),
    do: Enum.map(items, &TaxBreakdown.from_map/1)

  defp parse_tax_breakdown(other), do: other
```
→ Phase 64 variant: `defp parse_error_types(items) when is_list(items), do: Enum.map(items, &ErrorType.from_map/1)`
with `defp parse_error_types(_), do: []`.

**RFC3339-vs-Unix `NOTE:` to mirror** for `validation_start`/`validation_end` (D-19 + N-01) —
`event_notification.ex:33-38`:

```
  - `created` — **ISO 8601 string** like `"2026-03-09T13:00:28.435Z"`. This is a
    legitimate type asymmetry vs. `LatticeStripe.Event.t()` `created :: integer()`
    (Unix seconds on v1/snapshot events) — Stripe ships the wire value verbatim and
    LatticeStripe preserves it. Adopters who need a `DateTime` should call
    `DateTime.from_iso8601/1` themselves.
```

**The two-idempotency-key disambiguation (N-04)** already has in-repo prose to point at —
`event_notification.ex:44-46`:

```
  - `reason` — Map describing what triggered the event (contains `request.id` and
    `request.idempotency_key`; hidden in `Inspect` because of that)
```
The moduledoc must say `SampleError.request_identifier` is **not** this field.

---

### `lib/lattice_stripe/billing/meter_error_report/{reason,error_type,sample_error}.ex` (value objects)

**Analog:** `lib/lattice_stripe/billing/meter/value_settings.ex` — the complete file, and the exact
depth-3 sibling in the same ExDoc group. This is the whole template for `SampleError`:

```elixir
defmodule LatticeStripe.Billing.Meter.ValueSettings do
  @moduledoc """
  Value-extraction settings for sum/last meters. `event_payload_key` names
  the field inside `MeterEvent.payload` from which Stripe reads the numeric
  value. Defaults server-side to `"value"` when omitted in `Meter.create/3`.
  """

  @type t :: %__MODULE__{event_payload_key: String.t() | nil}
  defstruct [:event_payload_key]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map),
    do: %__MODULE__{event_payload_key: map["event_payload_key"]}
end
```
Note: **no `%Request{}`, no `@known_fields`, no `:extra`, terse moduledoc, `from_map(nil) -> nil` first.**
`Reason` and `ErrorType` add only the `Enum.map` fan-out above. `SampleError` must reach one level into
`request` (`data["request"]["identifier"]`) rather than typing a fourth sub-struct.

---

### `lib/lattice_stripe/billing/guards.ex` — GUARD-04 (guard module, pre-network raise)

**Analog:** the same file's GUARD-01, `check_meter_value_settings!/1`.

**Header block to extend** (`guards.ex:1-13`) — add the GUARD-04 line here:

```elixir
defmodule LatticeStripe.Billing.Guards do
  @moduledoc false
  # Guard numbering scheme (discoverability entry point):
  #
  #   GUARD-01 — check_meter_value_settings!/1 (sum/last formula requires value_settings)
  #   GUARD-02 — @doc contract on MeterEvent.create/3 documenting 35-day window, ...
  #   GUARD-03 — check_adjustment_cancel_shape!/1 (cancel must nest identifier)
```

**`@doc` shape** — GUARD-01's `@doc` is the model, including the two sentences Phase 64 must echo
(silent-pass hatch + string-keys-only):

```elixir
  @doc """
  Pre-flight guard for `LatticeStripe.Billing.Meter.create/3`.

  Raises `ArgumentError` when ... This blocks the silent-zero trap where Stripe returns HTTP 200 but
  every event's value contribution is silently dropped.

  Silent-passes when `value_settings` is omitted — Stripe defaults `event_payload_key`
  to `"value"`, which is a legal and common shape.

  Reads string keys only (Stripe wire format). Atom-keyed params bypass the guard.
  """
  @spec check_meter_value_settings!(map()) :: :ok
  def check_meter_value_settings!(params) when is_map(params) do
```

**Multi-line message construction with `<>`** (GUARD-01's raise body) is the house style for GUARD-04's
long microcopy — not heredocs:

```elixir
        raise ArgumentError,
              "LatticeStripe.Billing.Meter.create/3: default_aggregation.formula " <>
                "is #{inspect(formula)} but value_settings.event_payload_key is " <>
                "missing or empty. Stripe would accept this and silently drop " <>
                ...
```

**Total-fallback clause** — `check_meter_value_settings!(_non_map), do: :ok` (D-10's mandatory pass-through
hatch has the same shape).

---

### `mix.exs:179-190` (config)

**Analog:** the block itself. Append the five modules, lifecycle order (define → write → read → diagnose):

```elixir
          "Billing Metering": [
            LatticeStripe.Billing.Meter,
            LatticeStripe.Billing.Meter.DefaultAggregation,
            ...
            LatticeStripe.Billing.MeterEventStream,
            LatticeStripe.Billing.MeterEventStream.Session
          ],
```
Note the existing ordering rule: each parent is immediately followed by its depth-3 value objects. So
`MeterEventSummary` goes after `MeterEventStream.Session`, then `MeterErrorReport` + its three sub-modules.

---

### `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` (test, Mox-at-Transport)

**Analog:** `test/lattice_stripe/list_test.exs:384-449` — all nine D-30 assertions build on these three:

```elixir
  describe "stream!/2 - multi-page list" do
    test "fetches page 2 when page 1 has_more: true and emits items from both pages" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}, %{"id" => "cus_2"}], true)
      end)
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_3"}], false)
      end)
      ...
    end

    test "page 2 request uses starting_after cursor from last item of page 1" do
      ...
      |> expect(:request, fn req ->
        assert req.url =~ "starting_after=cus_b"
        list_response([%{"id" => "cus_c"}], false)
      end)
```
D-30's assertion (2) (page 2 preserves `customer`/`start_time`/`end_time`/`value_grouping_window`) is a
direct extension: add more `assert req.url =~ ...` lines inside that second `expect`. Assertion (6)
(no `idempotency-key` on page 2) reads `req.headers` in the same closure.

**List fixture builder** — `test/support/test_helpers.ex:55-62`:

```elixir
  def list_json(items, url \\ "/v1/objects", has_more \\ false) do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => has_more,
      "url" => url
    }
  end
```

---

### `test/lattice_stripe/billing/meter_event_summary_test.exs` — the D-31 refutation block

**Analog:** `test/lattice_stripe/entitlements/active_entitlement_test.exs:216-244`:

```elixir
      refute function_exported?(ActiveEntitlement, :create, 2)
      refute function_exported?(ActiveEntitlement, :create, 3)
      refute function_exported?(ActiveEntitlement, :update, 3)
      refute function_exported?(ActiveEntitlement, :update, 4)
      refute function_exported?(ActiveEntitlement, :delete, 2)
      refute function_exported?(ActiveEntitlement, :delete, 3)
      ...
      refute function_exported?(ActiveEntitlement, :stream, 1)
      refute function_exported?(ActiveEntitlement, :stream, 2)
      refute function_exported?(ActiveEntitlement, :stream, 3)
```
Phase 64 adds `:retrieve/2,3`, `:align_window/2`; on `Billing.Meter`, `:event_summaries/3,4`. **Do not
refute `:list/2` or `:list/3`** — default args export them (D-31).

---

### `test/support/fixtures/metering.ex` (test fixture module)

**Analog:** `test/support/fixtures/entitlements.ex:1-27` — copy the promotion header verbatim, swapping
names, and the `overrides \\ %{} |> Map.merge(overrides)` convention:

```elixir
# PROMOTION TARGET (Phase 65 / OBJ-02): move this file to
# lib/lattice_stripe/testing/fixtures/entitlements.ex AND rename the module to
# LatticeStripe.Testing.Fixtures.Entitlements. The private test-support namespace is
# LatticeStripe.Test.Fixtures.*; the public one is LatticeStripe.Testing.Fixtures.* — the
# promotion is a move PLUS a module rename, and skipping the rename is a compile error.
# Function names and bodies transfer unchanged — do not re-author.
defmodule LatticeStripe.Test.Fixtures.Entitlements do
  @moduledoc false

  @doc """
  Wire-shaped `entitlements.active_entitlement` fixture.
  ...
  """
  def active_entitlement_json(overrides \\ %{}) do
    %{
      "id" => "ent_123",
      ...
    }
    |> Map.merge(overrides)
  end
```
Note `entitlements.ex:44-52` shows the idiom for documenting **why a fixture carries a specific
un-normalised wire value** — mirror it for D-32's "verbatim published payload, never hand-invented".

---

### `test/integration/meter_event_summary_integration_test.exs` (integration test)

**Analog:** `test/integration/charge_integration_test.exs:1-33` — copy literally (D-34):

```elixir
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end
```

---

### `test/lattice_stripe/docs_truth_test.exs` (test, config assertion)

**Analog:** same file, `:89` — D-26's *only* permitted addition is inside this structural block
(`assert <module> in groups[...]`), never a new prose grep:

```elixir
  test "exdoc keeps the primary public truth surfaces published" do
    docs = docs_config()
    extras = docs[:extras]
    groups = docs[:groups_for_extras] |> Map.new()
    ...
    assert "guides/metering-runtime-and-reconciliation.md" in extras
```

## Shared Patterns

### Pre-network raise ordering (applies to `MeterEventSummary.list/4` and `stream!/4`)
**Source:** `lib/lattice_stripe/entitlements/active_entitlement.ex:180-187`, `billing/meter.ex:90-112`
**Rule:** every raise fires before `%Request{}` is constructed, and in `stream!` the first guard is the
function's literal first statement. Order for Phase 64: `validate_id!` → `require_param!` ×3 →
`Guards.check_summary_window!` → `%Request{}`.

### `Resource` unwrap trio
**Source:** `lib/lattice_stripe/resource.ex`; used verbatim at `transfer_reversal.ex:137,243,249`
**Apply to:** `MeterEventSummary` only.
- singular: `|> Resource.unwrap_singular(&from_map/1)` — **not used this phase** (no `retrieve/3`, F-04)
- list: `|> Resource.unwrap_list(&from_map/1)`
- bang: `client |> list(...) |> Resource.unwrap_bang!()`

### `from_map/1` clause ordering
**Source:** `active_entitlement.ex:211-216`
**Apply to:** all five new decode-bearing modules.
```elixir
def from_map(nil), do: nil
# The struct clause MUST precede the `is_map/1` clause — a struct is a map.
def from_map(%__MODULE__{} = x), do: x
def from_map(map) when is_map(map) do
```
Exception: the three depth-3 value objects follow `value_settings.ex` (nil clause + is_map clause only);
add the `%__MODULE__{}` clause only where a test or `from_event/1` round-trips one.

### `@known_fields` bracket sigil
**Source:** `transfer_reversal.ex:63-66` (correct), `active_entitlement.ex:79` and `billing/meter.ex:43`
(both `~w(` — the `drift.ex:210` miscount, D-20)
**Apply to:** every new module with an `:extra` field. **Always `~w[...]`.** Do not copy the parens form
from `active_entitlement.ex` even though it is otherwise the freshest analog.

### Deliberate-absence documentation
**Source:** `transfer_reversal.ex:9-16` (`## Design: standalone module, no Transfer.reverse/4 delegator`)
**Apply to:** `MeterEventSummary` (no `retrieve/3`, no `align_window/2`, no `Meter.event_summaries/4`) and
`MeterErrorReport` (no `list`/`retrieve`/`create`, no `:id`). This is the in-repo idiom for the D-31 refute
set's prose counterpart — a `##`-level moduledoc section naming the absence and the reason.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `MeterErrorReport.from_event/1` | constructor from `%LatticeStripe.Event{}` | transform | No existing module constructs a struct from a v2 fetched-event `data` payload. `event.ex:234`'s `RelatedObject.from_map/1` is the closest read, but the constructor-asymmetry contract (D-16 — `from_map` leaves `:meter` nil, `from_event` populates it) is genuinely new. Use RESEARCH.md's Pattern 4 sketch (`64-RESEARCH.md:656-673`). |
| GUARD-04's alignment arithmetic + microcopy | guard | pre-network raise | `check_meter_value_settings!/1` supplies the *shape* (raise + `@doc` + fallback clause) but no in-repo guard does numeric-divisor validation or prints remediation arithmetic. Microcopy is specified verbatim in `64-CONTEXT.md:370-382`. |

## Metadata

**Analog search scope:** `lib/lattice_stripe/` (all depths), `test/lattice_stripe/`, `test/integration/`,
`test/support/`, `mix.exs`
**Files read this session:** `transfer_reversal.ex`, `entitlements/active_entitlement.ex`,
`billing/guards.ex`, `billing/meter.ex` (35-115), `billing/meter_event.ex` (1-120),
`billing/meter/value_settings.ex`, `external_account.ex` (255-278), `drift.ex` (200-220),
`event_notification.ex` (20-60), `tax/calculation.ex` (grep), `entitlements/active_entitlement_summary.ex`
(grep), `mix.exs` (175-195), `test/support/fixtures/entitlements.ex` (1-60),
`test/support/test_helpers.ex` (45-70), `test/lattice_stripe/list_test.exs` (384-452),
`test/lattice_stripe/docs_truth_test.exs` (70-112), `test/integration/charge_integration_test.exs` (1-35),
`test/lattice_stripe/entitlements/active_entitlement_test.exs` (grep)
**Pattern extraction date:** 2026-07-28
