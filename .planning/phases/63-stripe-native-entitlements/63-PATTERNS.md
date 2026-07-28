# Phase 63: Stripe-Native Entitlements - Pattern Map

**Mapped:** 2026-07-27
**Files analyzed:** 13 (4 lib/guide, 1 build config, 8 test)
**Analogs found:** 13 / 13 (every file has an in-repo analog; zero greenfield mechanism)

> **Boundary correction (load-bearing):** the orchestrator hint listed
> `lib/lattice_stripe/object_types.ex` as a MODIFY target. **It is not.**
> `63-CONTEXT.md` Integration Points and `63-RESEARCH.md` Anti-Patterns both
> state: *"`lib/lattice_stripe/object_types.ex` — Phase 65 only. Phase 63 must
> not touch it."* F-09 confirms there is no code dependency (typing happens at
> the resource layer via `Stream.map(&from_map/1)`). It appears below only in
> *No Analog Needed* as an explicit non-target.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| NEW `lib/lattice_stripe/entitlements/active_entitlement.ex` | model + resource | request-response (read-only CRUD-L) + streaming | `lib/lattice_stripe/billing/meter.ex` | exact |
| NEW `lib/lattice_stripe/entitlements/feature.ex` | model + resource | CRUD + streaming | `lib/lattice_stripe/billing/meter.ex` | exact |
| NEW `lib/lattice_stripe/entitlements/active_entitlement_summary.ex` | model (decode-only) | transform (wire map → struct, no HTTP) | `lib/lattice_stripe/tax/calculation.ex` (`parse_line_items/1`, L190-196) | role-match |
| NEW `guides/entitlements.md` | doc | — | `guides/tax.md` | exact |
| MOD `mix.exs` (`docs/0`) | config | — | existing `"Billing Metering"` group (L177-188) + `guides/tax.md` extras rows | exact |
| MOD `test/support/test_helpers.ex` (`list_json/3`) | test utility | — | itself, L55-62 (add 3rd defaulted arg) | exact |
| NEW `test/support/fixtures/entitlements.ex` | test fixture | — | `test/support/fixtures/metering.ex` | exact |
| NEW `test/lattice_stripe/entitlements/active_entitlement_test.exs` | test (unit, Mox) | request-response | `test/lattice_stripe/billing/meter_test.exs` + `test/lattice_stripe/tax_id_test.exs` L27-39 (locks) | exact |
| NEW `test/lattice_stripe/entitlements/feature_test.exs` | test (unit, Mox) | CRUD | same as above | exact |
| NEW `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | test (unit, Mox multi-page) | streaming | `test/lattice_stripe/list_test.exs` L384-449 | exact |
| NEW `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` | test (unit, pure) | transform | `test/lattice_stripe/billing/meter_test.exs` `from_map` describes | role-match |
| NEW `test/integration/entitlements_integration_test.exs` | test (integration) | request-response | `test/integration/charge_integration_test.exs` L1-31 | exact |
| MOD `test/lattice_stripe/docs_truth_test.exs` | test (docs-truth) | file-I/O + assertion | itself: L447-520 (tax template), L341-348 (`scope.md` lock), L85-87 (`docs_config/0`) | exact |

## Pattern Assignments

### `lib/lattice_stripe/entitlements/active_entitlement.ex` and `.../feature.ex`

**Analog:** `lib/lattice_stripe/billing/meter.ex` (288 lines — full file read).
Use this for *structure*; use `charge.ex` only for the expandable-field idiom
(research C-05).

**Module skeleton + imports** (`meter.ex` L1-77) — note `alias LatticeStripe.{Client, Request, Resource}`, `@known_fields` as a `~w()` sigil of **string** keys, `@type t` before `defstruct`, and `defstruct` ending with `object: "<wire object>", extra: %{}`:

```elixir
defmodule LatticeStripe.Billing.Meter do
  @moduledoc """..."""

  alias LatticeStripe.{Client, Request, Resource}

  @known_fields ~w(id object display_name event_name status default_aggregation
                   customer_mapping value_settings status_transitions created
                   updated livemode)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          ...
          extra: map()
        }

  defstruct [
    :id,
    :display_name,
    ...
    object: "billing.meter",
    extra: %{}
  ]
```

**Banner comment sections** (`meter.ex` L79-81, L123-125, L143-145, L169-171, L242-244) — every verb group is fenced by an exactly-77-column rule. Copy verbatim:

```elixir
  # ---------------------------------------------------------------------------
  # CREATE
  # ---------------------------------------------------------------------------
```

Section order in `meter.ex`: `CREATE` → `RETRIEVE` → `UPDATE` → `LIST + STREAM` → (`LIFECYCLE VERBS`) → `DECODE + STATUS HELPER`. `Feature` uses this order minus lifecycle verbs (D-08: no archive verb). `ActiveEntitlement` uses `RETRIEVE` → `LIST + STREAM` → `DECODE` only.

**Required-param guard + request pipe + unwrap** (`meter.ex` L91-116) — this is the exact template for `Feature.create/3` (guards `lookup_key`, `name`) and, via D-10, for `ActiveEntitlement.list/3` and `stream!/3` (guards `customer`). Note `params` has **no** `\\ %{}` default on `create/3` (Pitfall 5), and the message string format:

```elixir
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(
      params,
      "display_name",
      "LatticeStripe.Billing.Meter.create/3 requires a display_name param"
    )

    %Request{method: :post, path: "/v1/billing/meters", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end
```

**Bang twin** (`meter.ex` L118-121) — one-liner, `@doc` string is formulaic. Every non-bang verb gets one; `stream!/3` gets none:

```elixir
  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()
```

**Retrieve — `is_binary(id)` guard only** (`meter.ex` L130-136). D-11 forbids adding `id in [nil, ""]` clauses:

```elixir
  @spec retrieve(Client.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/billing/meters/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end
```

**Update/4 signature** (`meter.ex` L155-162) — for `Feature.update/4`; note the double guard `when is_binary(id) and is_map(params)`:

```elixir
  def update(%Client{} = client, id, params, opts \\ [])
      when is_binary(id) and is_map(params) do
    %Request{method: :post, path: "/v1/billing/meters/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end
```

**List + stream** (`meter.ex` L177-200) — `list/3` returns `{:ok, LatticeStripe.Response.t()}` (NOT `t()`) via `unwrap_list`; `stream!/3` is 4 lines and wraps `LatticeStripe.List.stream!/2`:

```elixir
  @spec list(Client.t(), map(), keyword()) ::
          {:ok, LatticeStripe.Response.t()} | {:error, LatticeStripe.Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/billing/meters", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/billing/meters", params: params, opts: opts}
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end
```

D-06 replaces the two literal path strings with a single `@list_path` module attribute, plus `@doc false def list_path, do: @list_path` so the summary module can reuse it.

**`from_map/1`** (`meter.ex` L253-272) — `Map.split/2` against `@known_fields`, `object` falls back to the literal, unknown keys land in `:extra`:

```elixir
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "billing.meter",
      display_name: known["display_name"],
      ...
      extra: extra
    }
  end
```

D-07 prepends `def from_map(nil), do: nil` and `def from_map(%__MODULE__{} = e), do: e` — the struct clause must come **before** `when is_map(map)` since a struct is a map. `tax/calculation.ex` L161-164 shows the `nil` clause pattern with the widened spec `@spec from_map(map() | nil) :: t() | nil`.

**Expandable field decode** — analog `lib/lattice_stripe/charge.ex` L514-518:

```elixir
      balance_transaction:
        if(is_map(known["balance_transaction"]),
          do: ObjectTypes.maybe_deserialize(known["balance_transaction"]),
          else: known["balance_transaction"]
        ),
```

For `ActiveEntitlement.feature`, substitute `Feature.from_map/1` for `ObjectTypes.maybe_deserialize/1` (research Pattern 4) — routing through `ObjectTypes` would create a false Phase 65 dependency and silently fall through to a raw map. Add a comment saying why.

**"Relationship to other …" moduledoc section** (D-15) — analog `lib/lattice_stripe/tax/transaction.ex` L20-26, clone the shape:

```elixir
  ## Relationship to other tax surfaces

  This module is **not** `LatticeStripe.Invoice.AutomaticTax`. Automatic tax on
  Invoices, Subscriptions, and Quotes is configured via nested `automatic_tax`
  settings on those Billing resources. ...
```

Note `transaction.ex` also demonstrates `## Lifecycle`, `## Operational constraints`, and `## Usage` moduledoc sections and the `\#{}` escaping required inside a `@moduledoc` heredoc (L18, L29).

**Warning admonition** (D-19.1) — `lib/lattice_stripe/balance.ex` L10:

```elixir
  > #### Reconciliation loop antipattern {: .warning}
  >
  > ...
```

**No custom `Inspect` impl** (D-14) — `meter.ex` has none; that is the default. `charge.ex` L588+ has one *only* to redact PII.

---

### `lib/lattice_stripe/entitlements/active_entitlement_summary.ex`

**Analog:** `lib/lattice_stripe/tax/calculation.ex` L190-196 (nested typed `%List{}`) + `meter.ex` for the module skeleton.

**Core pattern — typed nested `%LatticeStripe.List{}`** (`tax/calculation.ex` L190-196). **The call order is the whole of D-05:** `List.from_json/1` runs on the raw string-keyed map first (so `_last_id` derivation can match `%{"id" => id}`), and the `Enum.map` typing happens in the struct-update afterwards:

```elixir
  defp parse_line_items(nil), do: nil

  defp parse_line_items(%{"object" => "list", "data" => data} = list) when is_list(data) do
    %{List.from_json(list) | data: Enum.map(data, &LineItem.from_map/1)}
  end

  defp parse_line_items(other), do: other
```

The three-clause `nil` / matched-shape / `other` fallthrough shape is the idiom — copy it. Extend the update map with D-04's `url:` rewrite and pass `%{"customer" => customer}` as `from_json/3`'s params arg.

**Why order matters — cursor derivation** (`lib/lattice_stripe/list.ex` L283-295). This is the code the ordering protects; typed structs do not match `%{"id" => id}`:

```elixir
  defp first_item_id([%{"id" => id} | _]), do: id
  defp first_item_id(_), do: nil

  defp last_item_id([]), do: nil

  defp last_item_id(items) do
    case Enum.at(items, -1) do
      %{"id" => id} -> id
      _ -> nil
    end
  end
```

**Why `url` must be rewritten and `_params` populated** (`list.ex` L245-275) — `build_next_page_request/1` reads `list._params`, `list._last_id`, and `list.url`; a `nil` `_last_id` falls to the `true -> %{}` branch (L262-263) and re-requests page 1:

```elixir
  defp build_next_page_request(%__MODULE__{} = list) do
    base_params = Map.drop(list._params, ["starting_after", "ending_before", "page"])

    pagination_params =
      cond do
        list.object == "search_result" && list.next_page -> %{"page" => list.next_page}
        Map.has_key?(list._params, "ending_before") && list._first_id != nil ->
          %{"ending_before" => list._first_id}
        list._last_id != nil -> %{"starting_after" => list._last_id}
        true -> %{}
      end

    # Strip idempotency_key from opts — page fetches are GET (D-31)
    opts = Keyword.delete(list._opts, :idempotency_key)

    %Request{method: :get, path: list.url, params: Map.merge(base_params, pagination_params), opts: opts}
  end
```

`base_params` at L246 is what D-22's cross-tenant test guards. `_params`/`_opts`/`_first_id`/`_last_id` are documented non-contract at `list.ex` L81-82.

**`defstruct` with NO `:id`** (F-02) — deviates from every other resource module. Follow `meter.ex` L63-77 but simply omit `:id`, and omit `"id"` from `@known_fields`. Add a source comment stating why so a future contributor does not "fix" it.

---

### `guides/entitlements.md`

**Analog:** `guides/tax.md` (350 lines; section headings read via grep).

**Section skeleton** (`guides/tax.md` `^## ` headings): `Scope boundary` → `Choose your path` → `Mental model` → `Configure once` → `Primary spine: …` → `TaxId dual-path API` → `Testing` → `Error handling` → `See also`. D-18's ordering maps onto this directly; keep `## Scope boundary` first and `## Error handling` / `## See also` last.

**Opening + scope-boundary prose** (`guides/tax.md` L1-28) — copy the *shape*: one-paragraph what-it-is, one-paragraph what-this-guide-covers with a version anchor, then a bolded in-scope list and an explicit out-of-scope paragraph naming Accrue:

```markdown
# Stripe Tax

Stripe Tax helps you calculate, collect, and report sales tax, VAT, and GST.
LatticeStripe exposes the Tax resource family as typed modules under
`LatticeStripe.Tax.*` ...

## Scope boundary

LatticeStripe is an HTTP client SDK — typed resources, `{:ok, struct}` /
`{:error, %LatticeStripe.Error{}}`, and Testing fixtures. Nothing more.

**In scope:** `Tax.Calculation`, `Tax.Transaction`, ...

Tax filing, returns preparation, nexus threshold monitoring, and jurisdiction
registration with government agencies are **out of SDK scope**. Those
workflows belong in your application or downstream in
[Accrue](https://github.com/sztheory/accrue) (an early LatticeStripe consumer).
LatticeStripe stays lower-level than Accrue so the SDK remains correct for any
Elixir Stripe integration.
```

D-19.2 requires this section carry the **working replacement** (reconciler → local store → gate locally → fail closed), not just the refusal.

Cross-links in `tax.md` are relative filenames (`testing.md`, `error-handling.md`, `payments.md`) — locked at `docs_truth_test.exs` L469-471. Use the same form; D-29 forbids hardcoded hexdocs URLs in new prose.

---

### `mix.exs` (`docs/0`)

**Analog:** the file's own existing rows. Three edits, all in `docs/0`.

**`extras:`** (L22-58) is a flat list of `"guides/*.md"` strings in reader order; insert `"guides/entitlements.md"` between `"guides/customer-portal.md"` and `"guides/metering.md"`. Note `extras:` currently orders `metering.md`, `tax.md`, `subscriptions.md`, `connect*.md`, `customer-portal.md` — the **`groups_for_extras` "Canonical Guides" list** (L75-88) is the one with `customer-portal.md` immediately before `metering.md`:

```elixir
          {"Canonical Guides",
           [
             "guides/payments.md",
             "guides/checkout.md",
             "guides/invoices.md",
             "guides/credit_notes.md",
             "guides/subscriptions.md",
             "guides/customer-portal.md",
             "guides/metering.md",
             ...
           ]},
```

Both edits are mandatory — a guide in `groups_for_extras` but absent from `extras:` is silently dropped (D-18).

**`groups_for_modules:`** — insert a new `Entitlements:` tuple between the existing `"Billing Metering"` group (L177-188) and `Connect:` (L189). The quoted-atom form is used only when the group name contains a space; `Entitlements` is a bare atom key like `Connect:`:

```elixir
          "Billing Metering": [
            LatticeStripe.Billing.Meter,
            ...
            LatticeStripe.Billing.MeterEventStream.Session
          ],
          Connect: [
            LatticeStripe.Account,
```

---

### `test/lattice_stripe/entitlements/{active_entitlement,feature}_test.exs`

**Analog:** `test/lattice_stripe/billing/meter_test.exs` L1-18 (header) + `test/lattice_stripe/tax_id_test.exs` L27-39 (surface locks).

**Test header** (`meter_test.exs` L1-18) — `async: true`, `import Mox`, `import LatticeStripe.TestHelpers`, alias the fixture module, `setup :verify_on_exit!`:

```elixir
defmodule LatticeStripe.Billing.MeterTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.Meter
  alias LatticeStripe.Test.Fixtures.Metering

  setup :verify_on_exit!
```

`meter_test.exs` also uses banner comments to separate preserved plan-era sections and `describe "Mod.fun/arity"` blocks — mirror that.

**Structural surface locks (L1/L2)** — `test/lattice_stripe/tax_id_test.exs` L27-39, verbatim shape:

```elixir
  describe "module surface" do
    test "does not export update or search" do
      refute function_exported?(TaxId, :update, 3)
      refute function_exported?(TaxId, :update, 4)
      refute function_exported?(TaxId, :search, 2)
      refute function_exported?(TaxId, :search, 3)
    end

    test "exports dual-path create arities" do
      assert function_exported?(TaxId, :create, 3)
      assert function_exported?(TaxId, :create, 4)
    end
  end
```

Also from `tax_id_test.exs` L12-25: the local `<resource>_json(overrides \\ %{})` helper via `Map.merge/2`. Phase 63 puts these in the shared fixture module instead (D-27), but the `overrides \\ %{}` + `Map.merge` signature is the convention to carry over.

**Inline-fixture negative assertion idiom** (`meter_test.exs` L38-40): `refute Map.has_key?(%DefaultAggregation{}, :extra)` — the exact shape D-26's `refute Map.has_key?(%ActiveEntitlementSummary{}, :id)` needs.

---

### `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs`

**Analog:** `test/lattice_stripe/list_test.exs` L1-45 (helpers) + L384-449 (multi-page).

**Local `list_response/3` helper** (`list_test.exs` L26-45) — note it returns the raw transport-shaped `{:ok, %{status:, headers:, body:}}` tuple with `has_more` as a positional arg. This is why D-28 extends `TestHelpers.list_json/2`:

```elixir
  defp list_response(items, has_more, opts \\ []) do
    url = Keyword.get(opts, :url, "/v1/customers")
    object = Keyword.get(opts, :object, "list")
    next_page = Keyword.get(opts, :next_page)

    body = %{"object" => object, "data" => items, "has_more" => has_more, "url" => url}
    body = if next_page, do: Map.put(body, "next_page", next_page), else: body

    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_#{System.unique_integer([:positive])}"}],
       body: Jason.encode!(body)
     }}
  end
```

**Multi-page + cursor assertion** (`list_test.exs` L429-448) — the exact shape for D-21 assertions (1) and (2). Note chained `|> expect(:request, fn req -> ... end)` sets ordered expectations, and cursor assertions are `req.url =~ "..."` string matches:

```elixir
    test "page 2 request uses starting_after cursor from last item of page 1" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_a"}, %{"id" => "cus_b"}], true)
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "starting_after=cus_b"
        list_response([%{"id" => "cus_c"}], false)
      end)

      client = test_client()
      req = customers_req()

      items = client |> List.stream!(req) |> Enum.to_list()

      assert length(items) == 3
    end
```

**Call-count assertion (D-21 #3)** — `list_test.exs` L405-427: N chained `expect/3` calls plus the trailing comment `# Mox verify_on_exit! ensures exactly 3 calls were made`. No separate counter.

**Laziness assertion (D-21 #5)** — `list_test.exs` L451+ `describe "stream!/2 - laziness"`, `test "Stream.take(stream, 1) on a multi-page list only fetches page 1"`; a single `expect` is the whole assertion.

Header assertions (D-21 #6, #7) are on `req.headers` with **lowercase** names (`{"stripe-account", _}`, `{"idempotency-key", _}`) per research.

---

### `test/integration/entitlements_integration_test.exs`

**Analog:** `test/integration/charge_integration_test.exs` L1-36. Copy L17-31 literally (D-20):

```elixir
defmodule LatticeStripe.ChargeIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Charge` against stripe-mock.
  ...
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Charge

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

  test "retrieve/3 returns a %Charge{}", %{client: client} do
    assert {:ok, %Charge{} = charge} = Charge.retrieve(client, "ch_test")
    assert is_binary(charge.id)
  end
```

Note `async: false` (mandatory — shared Finch pool) and the `%{client: client}` context destructure in every test.

---

### `test/support/fixtures/entitlements.ex`

**Analog:** `test/support/fixtures/metering.ex` L1-60.

**Module + nesting + `@moduledoc false`** — note the **private** namespace is `LatticeStripe.Test.Fixtures.*` (research C-01; the public Phase-65 namespace is `LatticeStripe.Testing.Fixtures.*`, so the promotion is a move **plus** a module rename):

```elixir
defmodule LatticeStripe.Test.Fixtures.Metering do
  @moduledoc false

  defmodule Meter do
    @moduledoc false

    @doc """
    Basic active Meter fixture with all Phase 20 nested struct fields populated.

    Returns a string-keyed map matching Stripe's wire format. Suitable for
    unit tests that call `LatticeStripe.Billing.Meter.from_map/1`.
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "mtr_123",
        "object" => "billing.meter",
        ...
      }
      |> Map.merge(overrides)
    end

    def list_response(items \\ [basic()]) do
      %{"object" => "list", "data" => items, "has_more" => false, "url" => "/v1/billing/meters"}
    end
```

D-27 mandates **flat** function names on a single module (`active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2`), not `metering.ex`'s nested-submodule form — the flat names are what Phase 65 will consume. Keep `overrides \\ %{}` + `Map.merge` and the `@moduledoc false`.

---

### `test/support/test_helpers.ex` — `list_json/2` → `list_json/3`

**Analog:** itself, L55-62. Backward-compatible one-line change (D-28):

```elixir
  def list_json(items, url \\ "/v1/objects") do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => url
    }
  end
```

Also relevant from this file: `test_client/1` (L6-16, wires `transport: LatticeStripe.MockTransport`, `max_retries: 0`), `test_integration_client/1` (L18-29, `base_url: "http://localhost:12111"`), and `ok_response/1` (L31-38, `Jason.encode!` into a `{:ok, %{status:, headers:, body:}}` tuple).

---

### `test/lattice_stripe/docs_truth_test.exs` (extend)

**Analog:** its own tax-guide lock at L447-520 — clone this whole test as `"entitlements guide locks ExDoc placement, content anchors, cross-links, and moduledocs"`.

**ExDoc registration lock** (L448-454) — reads the live `mix.exs` config via the `docs_config/0` helper at L85-87 (`LatticeStripe.MixProject.project()[:docs]`):

```elixir
    root = Path.expand("../..", __DIR__)
    tax_guide = File.read!("guides/tax.md")
    docs = docs_config()
    groups = docs[:groups_for_extras] |> Map.new()

    assert "guides/tax.md" in docs[:extras]
    assert "guides/tax.md" in groups["Canonical Guides"]
```

**Prose anchors + cross-links** (L456-478) — flat `assert guide =~ "..."` lines, with `or` for tolerated wording variants:

```elixir
    assert tax_guide =~ "Calculation.create"
    assert tax_guide =~ "out of SDK scope"
    assert tax_guide =~ "expires_at" or tax_guide =~ "days"

    assert tax_guide =~ "testing.md"
    assert tax_guide =~ "error-handling.md"
```

**Source-file (moduledoc) locks** (L480-519) — `File.read!(Path.join(root, "lib/..."))` then `=~`; the `for source <- [...]` loop is the idiom for an assertion shared across every module in the family:

```elixir
    calc = File.read!(Path.join(root, "lib/lattice_stripe/tax/calculation.ex"))
    txn = File.read!(Path.join(root, "lib/lattice_stripe/tax/transaction.ex"))

    for source <- [calc, txn, settings, registration, tax_id] do
      assert source =~ "guides/tax.md"
    end

    assert txn =~ "create_from_calculation"
    assert txn =~ "LatticeStripe.Tax.Calculation"
```

This is exactly D-23 L3's mechanism (`=~ "gate"`, `=~ "fail closed"`, `=~ "stream!/3"`, `=~ "no top-level"`, and D-24's **present**-not-refuted `=~ "entitled?"`).

**`guides/scope.md` lock to extend** (L341-348) — append 2-3 `assert scope =~ ...` lines inside this existing test (D-19.3):

```elixir
    test "guides/scope.md is the canonical deferred-scope contract" do
      scope = File.read!("guides/scope.md")

      assert scope =~ "Identity"
      assert scope =~ "Reporting" or scope =~ "Sigma"
      assert scope =~ "adopter pull" or scope =~ "maintenance mode"
      assert scope =~ "Client.request"
    end
```

## Shared Patterns

### Response unwrapping and required-param guards
**Source:** `lib/lattice_stripe/resource.ex` (full file, `@moduledoc false`)
**Apply to:** both resource modules — all four helpers are used verbatim, none is reimplemented.

```elixir
  def unwrap_singular({:ok, %Response{data: data}}, from_map_fn), do: {:ok, from_map_fn.(data)}
  def unwrap_singular({:error, %Error{}} = error, _from_map_fn), do: error

  def unwrap_list({:ok, %Response{data: %List{} = list} = resp}, from_map_fn) do
    typed_items = Enum.map(list.data, from_map_fn)
    {:ok, %{resp | data: %{list | data: typed_items}}}
  end

  def unwrap_bang!({:ok, result}), do: result
  def unwrap_bang!({:error, %Error{} = error}), do: raise(error)

  @spec require_param!(map(), String.t(), String.t()) :: :ok
  def require_param!(params, key, message) do
    unless Map.has_key?(params, key) do
      raise ArgumentError, message
    end

    :ok
  end
```

Note `require_param!/3` checks **presence only, not emptiness** (D-10 requires saying so in `@doc`), and that `unwrap_list/2` preserves the `%Response{}` wrapper so callers reach `resp.data.has_more`.

### Request construction pipe
**Source:** `lib/lattice_stripe/billing/meter.ex` (every verb)
**Apply to:** every non-bang verb in both resource modules. Exact three-line shape — do not refactor into a helper:

```elixir
    %Request{method: :get, path: ..., params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)   # or unwrap_list/2
```

### Pagination — reuse, never rebuild
**Source:** `lib/lattice_stripe/list.ex` (`stream!/2` L154, `stream/2` L180, `build_next_page_request/1` L245-275)
**Apply to:** both `stream!/3` implementations and the summary's nested-list construction. Recorded project decision: reuse existing dispatch, do not grow a new mechanism.

### Mox transport mocking
**Source:** `test/support/test_helpers.ex` L6-16 + `test/test_helper.exs` L5 (`Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)`)
**Apply to:** all four unit test files. `setup :verify_on_exit!` at the top; the mock callback receives a plain map with `:method`, `:url`, `:headers`, `:body`, `:opts`; GET params arrive query-encoded in `:url`.

## No Analog Needed / Explicit Non-Targets

| File | Role | Why |
|------|------|-----|
| `lib/lattice_stripe/object_types.ex` | dispatch registry | **Phase 65 only — Phase 63 MUST NOT touch it.** F-09: typing happens at the resource layer (`Stream.map(&from_map/1)`), so there is no code dependency. Listed here to prevent an accidental edit. |
| `lib/lattice_stripe/entitlements.ex` (parent) | — | **Must not exist** (D-16). Verified rule: `billing/`, `billing_portal/`, `checkout/`, `tax/`, `builders/`, `test_helpers/` all have no parent `.ex` because no parent endpoint exists. |
| custom `Inspect` impl | — | Deliberately absent (D-14). `charge.ex` L588+ is PII-redaction-only and is the wrong analog here. |
| `.planning/ROADMAP.md` (Phase 65 build constraints) | planning artifact | One appended line for D-27's promote-by-move; no code pattern applies. |

## Metadata

**Analog search scope:** `lib/lattice_stripe/` (billing, tax, charge, list, resource), `guides/`, `mix.exs`, `test/lattice_stripe/`, `test/integration/`, `test/support/`
**Files read this session:** `billing/meter.ex` (full), `resource.ex` (full), `tax/calculation.ex` L140-204, `tax/transaction.ex` L1-40, `charge.ex` L495-534, `list.ex` L60-108 + L240-296, `mix.exs` L18-120 + L177-191, `test/support/test_helpers.ex` (full), `test/support/fixtures/metering.ex` L1-60, `test/lattice_stripe/list_test.exs` L1-45 + L380-454, `test/lattice_stripe/billing/meter_test.exs` L1-60, `test/lattice_stripe/tax_id_test.exs` L1-45, `test/lattice_stripe/docs_truth_test.exs` L330-359 + L440-529, `test/integration/charge_integration_test.exs` L1-60, `guides/tax.md` L1-30 + headings
**Pattern extraction date:** 2026-07-27
