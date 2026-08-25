# Phase 65: Webhook ObjectTypes & Testing Fixtures - Pattern Map

**Mapped:** 2026-07-28
**Files analyzed:** 20 (5–8 new `lib/` fixture modules depending on Q1/Q2, 15 modified)
**Analogs found:** 19 / 20

Every analog below was read at HEAD in this worktree. Phase 65 is a **registration + relocation**
phase: almost nothing is authored from scratch, so the dominant analog is *the precedent for the
move*, not "a file that looks similar."

> **The move precedent is `TaxId` (moved, no private twin left behind).**
> **`Dispute` is an ANTI-precedent** — `test/support/fixtures/dispute.ex` and
> `lib/lattice_stripe/testing/fixtures/dispute.ex` both exist with byte-identical bodies and no
> drift lock. Do **not** copy that shape. See § Anti-Precedent.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/object_types.ex` **EDIT** | registry / config | dispatch table (compile-time) | same file, rows `:38-52` (`tax.*`, `billing.meter`) | exact (in-file sibling) |
| `lib/lattice_stripe/testing/fixtures/entitlements.ex` **MOVED+RENAMED** | fixture module (public) | data | `lib/lattice_stripe/testing/fixtures/tax_id.ex` (shape) + **TaxId's move history** (process) | exact |
| `lib/lattice_stripe/testing/fixtures/metering*.ex` **MOVED+RENAMED** (shape per Q1) | fixture module (public) | data | `lib/.../fixtures/tax_calculation.ex` / `tax_id.ex` — the **flat** public convention | role-match (source is nested; target convention is flat) |
| `lib/lattice_stripe/testing/fixtures/customer.ex` **MOVED** | fixture module (public) | data | `lib/.../fixtures/tax_id.ex` | exact |
| `lib/lattice_stripe/testing/fixtures/subscription.ex` **MOVED** | fixture module (public) | data | `lib/.../fixtures/dispute.ex` (multi-function module) | exact for shape; **rename `basic/1` → `subscription_json/1`** |
| `lib/lattice_stripe/testing/fixtures/payment_intent.ex` **MOVED** | fixture module (public) | data | `lib/.../fixtures/tax_id.ex` | exact |
| `lib/lattice_stripe/testing/fixtures/invoice.ex` **NEW** | fixture module (public) | data | **no fixture module exists**; body source = `test/lattice_stripe/invoice_test.exs:16-61` private `invoice_json/1` | partial (body exists, module does not) |
| `lib/lattice_stripe/testing.ex` **EDIT** | facade / typed wrappers | transform (map → struct) | same file, `:78-82` (`dispute/1`) + alias block `:49-62` | exact |
| `mix.exs` **EDIT** | config | n/a | same file, `groups_for_modules[:Testing]` `:239-254` | exact |
| `guides/testing.md` **EDIT** | docs | n/a | same file, bullet list `:20-29` | exact |
| `test/lattice_stripe/object_types_test.exs` **EDIT** | test | dispatch assertion | same file `:17-33` (positive), `:194-234` (`fetch_module/1` describe) | exact |
| `test/lattice_stripe/testing_test.exs` **EDIT** | test | fixture + wrapper assertion | same file `:22-32` and `:244-253` | exact |
| `test/lattice_stripe/docs_truth_test.exs` **EDIT** | test | config assertion | same file `:584-606` (metering group block) | exact |
| 4 entitlement caller test files **EDIT** | test | alias-only | — | mechanical |
| 9 metering caller test files **EDIT** | test | alias-only | — | mechanical |
| 5 core-billing caller test files **EDIT** | test | alias/import-only | — | mechanical |
| `.planning/ROADMAP.md:36,155` **EDIT** | docs | n/a | — | housekeeping ("five" → "four") |

---

## Pattern Assignments

### `lib/lattice_stripe/object_types.ex` (registry, compile-time dispatch)

**Analog:** the same file. `@object_map` is a 47-row literal at `:4-53`; `fetch_module/1` `:65-67`;
`maybe_deserialize/1` `:69-80`. `@moduledoc false` — the module is deliberately hidden.

**Existing family-append rows to copy the placement from** (`object_types.ex:47-52` — note the map
is roughly alphabetical only through `"transfer_reversal"`, then appends by family; `mix format`
will not reorder keys, so put the new rows next to `"billing.meter"`):

```elixir
    "transfer_reversal" => LatticeStripe.TransferReversal,
    "billing.meter" => LatticeStripe.Billing.Meter,
    "billing_portal.configuration" => LatticeStripe.BillingPortal.Configuration,
```

**The four rows to add** (exact wire strings — copy from each module's own `defstruct` default,
do not retype):

```elixir
    "billing.meter_event" => LatticeStripe.Billing.MeterEvent,
    "billing.meter_event_summary" => LatticeStripe.Billing.MeterEventSummary,
    "entitlements.active_entitlement" => LatticeStripe.Entitlements.ActiveEntitlement,
    "entitlements.active_entitlement_summary" =>
      LatticeStripe.Entitlements.ActiveEntitlementSummary,
```

**⚠ `@object_map` is DUAL-PURPOSE.** It is read by two consumers, and the phase brief describes
only one:

```elixir
# lib/lattice_stripe/object_types.ex:58-67 — the second consumer's entry point
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

Each added row flips `Webhook.fetch_related_object/3` from "no HTTP, `{:error,
{:unknown_object_type, t}}`" to "issue `GET related_object.url`". Register anyway (correct), but
grep `test/lattice_stripe/webhook/` for `unknown_object_type` assertions on these four strings
before editing, and document the coupling in the plan rather than "fixing" it.

---

### `test/lattice_stripe/object_types_test.exs` (test, dispatch assertion)

**Analog:** the same file. Two existing shapes to extend — **do not add new `describe` blocks.**

**Positive dispatch shape** (`:17-33`) — extend `describe "maybe_deserialize/1"`:

```elixir
    test "dispatches customer map to Customer.from_map/1" do
      map = %{"object" => "customer", "id" => "cus_123", "email" => "test@example.com"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Customer{id: "cus_123"} = result
    end
```

**`fetch_module/1` group shape** (`:229-234`) — the family-batch assertion, the model for a
"resolves all four Phase 65 object types" test:

```elixir
    test "resolves all five Tax family object types" do
      assert ObjectTypes.fetch_module("tax.calculation") == {:ok, LatticeStripe.Tax.Calculation}
      assert ObjectTypes.fetch_module("tax.transaction") == {:ok, LatticeStripe.Tax.Transaction}
      ...
```

**Two tests that ALREADY EXIST and must be VERIFIED, NOT RE-AUTHORED** (Phase 64 Plan 04 wrote
both; re-authoring produces a duplicate `describe` pair):

- `:181-191` — error-report `data` round-trips unchanged (`assert result == data; refute is_struct(result)`)
- `:217-227` — `refute Map.has_key?(ObjectTypes.object_map(), "billing.meter_error_report")` plus
  `assert ObjectTypes.fetch_module("billing.meter_error_report") == :error`

**Assertion hazards (from RESEARCH, both real):**
- `%MeterEvent{}` has **no `:object` field** — `assert result.object == ...` raises `KeyError`.
  Assert `%LatticeStripe.Billing.MeterEvent{event_name: "api_call"} = ...` instead.
- `%ActiveEntitlementSummary{}` has **no `:id`** — assert on `customer:` and add
  `refute Map.has_key?(result, :id)`.

**Alias line `:5` must change** if the metering fixtures move:
```elixir
  alias LatticeStripe.Test.Fixtures.Metering.MeterErrorReport, as: MeterErrorReportFixture
```

---

### `lib/lattice_stripe/testing/fixtures/*.ex` (fixture modules, public)

**Analog (shape):** `lib/lattice_stripe/testing/fixtures/tax_id.ex` — the whole file, 22 lines:

```elixir
defmodule LatticeStripe.Testing.Fixtures.TaxId do
  @moduledoc """
  Canonical raw fixtures for Stripe TaxId objects.
  """

  @spec tax_id_json(map()) :: map()
  def tax_id_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "txi_test123",
        "object" => "tax_id",
        ...
      },
      overrides
    )
  end
end
```

Public-surface invariants, all ten existing modules conform:
1. **Flat** — `Testing.Fixtures.TaxCalculation`, never `Testing.Fixtures.Tax.Calculation`. The Tax
   family was deliberately flattened on promotion.
2. **Real `@moduledoc`** in the fixed voice *"Canonical raw fixtures for Stripe X objects."*
   `@moduledoc false` passes Credo (`.credo.exs` `Readability.ModuleDoc` is on and `lib/` is
   included) but makes the module **invisible in HexDocs** — a public surface nobody can find.
3. **`@spec f(map()) :: map()`** on every builder.
4. **`*_json(overrides \\ %{})`** naming — the whole public surface. This is why
   `Subscription.basic/1` should become `subscription_json/1` on promotion (one caller to fix).
5. `Map.merge(canonical, overrides)` as a **call**, not a pipe.

**Multi-function module** (Subscription, Invoice, promoted Entitlements): `dispute.ex` is the
precedent — three `@spec`'d `*_json/1` builders in one flat module, nested ones composed by call
(`"evidence" => dispute_evidence_json()`).

**Umbrella moduledoc to update** — `lib/lattice_stripe/testing/fixtures.ex` still claims *"the
v1.3 resource families"*; Phase 65 pushes past v1.3, so this prose is stale (same string appears
at `guides/testing.md:13-14`).

---

### Promotion source A — `test/support/fixtures/entitlements.ex` → `lib/lattice_stripe/testing/fixtures/entitlements.ex`

**Analog for the process:** `TaxId` — promoted by move, **no private twin** (`ls
test/support/fixtures/` has `tax_registration.ex` and `tax_settings.ex` but no `tax_id.ex`).

**Header to DELETE on promotion** (`entitlements.ex:1-6` — it is discharged by this phase; the
identical 6-line header is on `metering.ex:1-6`):

```elixir
# PROMOTION TARGET (Phase 65 / OBJ-02): move this file to
# lib/lattice_stripe/testing/fixtures/entitlements.ex AND rename the module to
# LatticeStripe.Testing.Fixtures.Entitlements. The private test-support namespace is
# LatticeStripe.Test.Fixtures.*; the public one is LatticeStripe.Testing.Fixtures.* — the
# promotion is a move PLUS a module rename, and skipping the rename is a compile error.
# Function names and bodies transfer unchanged — do not re-author.
defmodule LatticeStripe.Test.Fixtures.Entitlements do
  @moduledoc false
```

**Body form to PRESERVE** (`:17-26`) — the private twins pipe into `Map.merge`; the ROADMAP says
carry bodies over **unchanged**, so preserve the pipe rather than normalizing to the public
`Map.merge(map, overrides)` call form:

```elixir
  def active_entitlement_json(overrides \\ %{}) do
    %{
      "id" => "ent_123",
      "object" => "entitlements.active_entitlement",
      "feature" => "feat_123",
      "lookup_key" => "premium_support",
      "livemode" => false
    }
    |> Map.merge(overrides)
  end
```

**Load-bearing `@doc` that must survive verbatim** (`:44-51`) — Phase 63 D-04's URL-rewrite is only
provable because this fixture carries the un-rewritten path:

```elixir
  @doc """
  Wire-shaped `entitlements.active_entitlement_summary` fixture.

  The nested `entitlements` envelope carries the **un-rewritten** webhook url
  `"/v1/customer/cus_ABC123customer/entitlements"` — the exact string Stripe publishes.
  The summary module rewrites it to the canonical list path, so the fixture must carry the
  original for that rewrite to be provable.
  """
```

Four functions carried unchanged: `active_entitlement_json/1`, `feature_json/1`,
`active_entitlement_summary_json/1`, `active_entitlement_list_json/2`. The last one is the
**in-module list builder** — keep it; `LatticeStripe.TestHelpers.list_json/3` is test-only and
cannot be called from `lib/` (Pitfall 3).

**Exact caller `alias` lines to change (4 files):**

| File | Line | Current text |
|---|---|---|
| `test/lattice_stripe/entitlements/active_entitlement_test.exs` | 8 | `alias LatticeStripe.Test.Fixtures.Entitlements` |
| `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` | 13 | same |
| `test/lattice_stripe/entitlements/feature_test.exs` | 18 | same |
| `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | 19 | same |

Each is a one-token edit: `Test.Fixtures` → `Testing.Fixtures`.

---

### Promotion source B — `test/support/fixtures/metering.ex` (Q1 shape undecided)

332 lines: one outer module `LatticeStripe.Test.Fixtures.Metering` with **five nested modules** —
`Meter`, `MeterEvent`, `MeterEventAdjustment`, `MeterEventStreamSession`, `MeterEventSummary`,
`MeterErrorReport`. All six carry `@moduledoc false`, so **six** real moduledocs must be authored
if all six are promoted.

**The conflict the planner must resolve at a `checkpoint:decision` before any file moves:** the
in-source header (Phase 64) says keep the nested file and rename the outer module → depth-4 names
like `Testing.Fixtures.Metering.MeterEventSummary`. The established public convention is **flat**
(ten-for-ten). RESEARCH leans flat + promote only `MeterEvent`, `MeterEventSummary`,
`MeterErrorReport`; that contradicts the header, so it needs an explicit decision record.

**Body form** (`metering.ex:80-94`) — same pipe idiom, plus load-bearing docs to carry:

```elixir
  defmodule MeterEvent do
    @moduledoc false

    @doc """
    Basic MeterEvent fixture matching Stripe's wire format.

    The `payload` field intentionally includes both the customer mapping key
    (`stripe_customer_id`) and the value key (`value`). Tests for Inspect
    masking should assert that `:payload` is hidden in the string
    representation of `%LatticeStripe.Billing.MeterEvent{}`.
    """
    def basic(overrides \\ %{}) do
      %{
        "object" => "billing.meter_event",
        ...
      }
      |> Map.merge(overrides)
    end
  end
```

`MeterErrorReport`'s 25-line "verbatim from Stripe's published example" comment must be carried
intact. Note the nested builders are named `basic/1`, not `*_json/1` — same public-naming
question as `Subscription.basic/1`.

**Exact caller `alias` lines to change (9 files):**

| File | Line | Current text |
|---|---|---|
| `test/lattice_stripe/object_types_test.exs` | 5 | `alias LatticeStripe.Test.Fixtures.Metering.MeterErrorReport, as: MeterErrorReportFixture` |
| `test/lattice_stripe/billing/meter_test.exs` | 16 | `alias LatticeStripe.Test.Fixtures.Metering` |
| `test/lattice_stripe/billing/meter_guards_test.exs` | 8 | same |
| `test/lattice_stripe/billing/meter_event_test.exs` | 8 | same |
| `test/lattice_stripe/billing/meter_event_summary_test.exs` | 8 | same |
| `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` | 28 | same |
| `test/lattice_stripe/billing/meter_event_stream_test.exs` | 10 | same |
| `test/lattice_stripe/billing/meter_event_adjustment_test.exs` | 6 | same |
| `test/lattice_stripe/billing/meter_error_report_test.exs` | 7 | `alias LatticeStripe.Test.Fixtures.Metering.MeterErrorReport, as: Fixture` |

If Q1 chooses **flat**, these are not one-token edits — the call sites (`Metering.MeterEvent.basic()`)
change too. Budget for that.

---

### OBJ-03 core-billing fixtures (Q2: move vs duplicate — RESEARCH recommends **move**)

| Object | Source | Module | Functions | Caller `alias`/`import` lines |
|---|---|---|---|---|
| customer | `test/support/fixtures/customer.ex` (19 lines) | `LatticeStripe.Test.Fixtures.Customer` | `customer_json/1` | `customer_test.exs:6` (`import`), `webhook/thin_event_test.exs:9` (`import ..., only: [customer_json: 1]`), `webhook/fetch_test.exs:8` (same) |
| subscription | `test/support/fixtures/subscription.ex` (102 lines) | `...Subscription` | `basic/1`, `with_items/1`, `paused/1`, `canceled/1` | `subscription_test.exs:10` (`alias ..., as: Fixtures`) |
| payment_intent | `test/support/fixtures/payment_intent.ex` (20 lines) | `...PaymentIntent` | `payment_intent_json/1` | `payment_intent_test.exs:6` (`import`) |
| **invoice** | **none** | — | — | — |

Total **5 caller lines**, three of which are `import`s (not `alias`) — an `import` rename changes
only the module path, call sites are unaffected.

`customer.ex` and `payment_intent.ex` are already in the exact public form (`Map.merge(map,
overrides)` call, `*_json/1` naming) — promotion is: add `@moduledoc`, add `@spec`, rename module.

`subscription.ex` composes via `basic(Map.merge(%{...}, overrides))` for its three variants; if
`basic/1` is renamed to `subscription_json/1`, the three internal call sites at `:54`, `:71`, `:85`
change with it.

**`invoice.ex` — the one genuinely new authoring task.** No fixture module exists anywhere. The
only source is the private `invoice_json/1` at `test/lattice_stripe/invoice_test.exs:16-61` (≈35
wire fields, nested `automatic_tax`, `status_transitions`, and a `lines` list envelope) — already
in the public call form:

```elixir
  defp invoice_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "in_test1234567890",
        "object" => "invoice",
        "status" => "draft",
        ...
        "lines" => %{
          "object" => "list",
          "data" => [],
          "has_more" => false,
          "url" => "/v1/invoices/in_test1234567890/lines"
        }
      },
      overrides
    )
  end
```

**Lift it verbatim** into `LatticeStripe.Testing.Fixtures.Invoice.invoice_json/1` and have
`invoice_test.exs` call the public fixture — that preserves the exact shape its ~19 existing
assertions were written against.

---

### `lib/lattice_stripe/testing.ex` (facade, typed wrappers)

**Analog:** the same file, `:78-82` — the complete wrapper contract, never anything more:

```elixir
  @doc """
  Converts a canonical Dispute fixture map into `%LatticeStripe.Dispute{}`.
  """
  @spec dispute(map()) :: Dispute.t()
  def dispute(raw_map), do: Dispute.from_map(raw_map)
```

**Alias block to extend** (`:49-62`) — alphabetical, single `LatticeStripe.{...}` group:

```elixir
  alias LatticeStripe.{
    CreditNote,
    Dispute,
    Event,
    EventNotification,
    File,
    FileLink,
    Mandate,
    Quote,
    SetupAttempt,
    Tax,
    TaxId,
    Webhook
  }
```

`LatticeStripe.Entitlements.*` and `LatticeStripe.Billing.*` are **not** aliased here. Note the
existing `Tax` entry is aliased at the **parent** level and used as `Tax.Calculation.from_map/1`
(`:112`) — the same shape works for `Billing` and `Entitlements`.

**Pitfall 6 (recorded prior incident, STATE `[63-01]`):** the alias and the wrapper that uses it
must land in the **same task/commit** — an alias added ahead of its wrapper fails
`mix compile --warnings-as-errors` (`ci.yml:92`).

**Naming:** `Testing.quote/1` (`:105`) already shadows `Kernel.quote/2` — precedent that the
project accepts shadowing for wire-name fidelity. None of `subscription/1`, `invoice/1`,
`customer/1`, `payment_intent/1`, `active_entitlement/1`, `meter_event/1` collide.

---

### `mix.exs` (config)

**Analog:** the same block, `:239-254`. Every new public module must be appended or ExDoc
**silently drops it**:

```elixir
          Testing: [
            LatticeStripe.Testing,
            LatticeStripe.Testing.Fixtures,
            LatticeStripe.Testing.Fixtures.File,
            ...
            LatticeStripe.Testing.Fixtures.TaxId,
            LatticeStripe.Testing.TestClock,
            LatticeStripe.Testing.TestClock.Owner,
            LatticeStripe.Testing.TestClock.Error
          ],
```

Two other lines matter and are **not** edited:
```elixir
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]   # :325 — anything under lib/ SHIPS
  defp elixirc_paths(:test), do: ["lib", "test/support"]                  # :329
  defp elixirc_paths(_), do: ["lib"]                                      # :330 — promoted files now compile in :prod
```

---

### `test/lattice_stripe/testing_test.exs` (test)

**Analog:** the same file. Extend the two existing blocks; do not add new `describe`s.

**Fixture-builder block** (`:22-32`):
```elixir
  describe "public fixture builders" do
    test "expose canonical raw-map builders for each v1.3 family" do
      assert is_map(Fixtures.File.file_json())
      assert is_map(Fixtures.Dispute.dispute_json())
      ...
```

**Typed-wrapper block** (`:244-253`):
```elixir
  describe "typed wrappers" do
    test "return typed structs from canonical fixture maps" do
      assert %File{} = Testing.file(Fixtures.File.file_json())
      assert %Dispute{} = Testing.dispute(Fixtures.Dispute.dispute_json())
      ...
```

Alias block `:4-19` gains the new struct modules; `alias LatticeStripe.Testing.Fixtures` (`:19`)
already exists, so fixtures are reachable as `Fixtures.X`.

---

### `test/lattice_stripe/docs_truth_test.exs` (test, config assertion)

**Analog:** `:584-606` — the Phase 64 metering block, both halves plus the load-bearing comment:

```elixir
  test "metering guide and the Phase 64 metering modules keep their ExDoc placement" do
    docs = docs_config()
    groups = docs[:groups_for_extras] |> Map.new()

    assert "guides/metering.md" in docs[:extras]
    assert "guides/metering.md" in groups["Canonical Guides"]

    # A module absent from its group is silently dropped from the published docs,
    # so an adopter reading HexDocs would never learn these exist. Structural
    # assertion only — this is the sole docs-truth addition this phase, and
    # deliberately not a prose grep.
    metering_group = docs[:groups_for_modules][:"Billing Metering"]

    assert LatticeStripe.Billing.MeterEventSummary in metering_group
```

For Phase 65 the group key is the plain atom `:Testing` (see `:535` for the `[:Entitlements]`
access form). `guides/testing.md` is already locked into `groups["Operations & DX"]` at `:130`, so
only the **module** assertions plus a prose assertion on the bullet list are new.

**Prose-assertion idiom** (`:637`, `:812`): `testing = File.read!("guides/testing.md")` then
`assert testing =~ "<literal>"`.

---

### `guides/testing.md` (docs)

**Analog:** the same file, `:12-34`. Append to the bullet list; also fix the **stale "v1.3" claim**
on `:13-14` (Phase 65 extends past v1.3):

```markdown
## Public fixture builders

LatticeStripe now ships canonical raw-map fixtures for the v1.3 resource families under
`LatticeStripe.Testing.Fixtures.*`.
...
- `LatticeStripe.Testing.Fixtures.TaxId`
...
- `LatticeStripe.Testing.quote/1`, `dispute/1`, `credit_note/1`, ... for typed structs
```

**Autolink hazard (Assumption A5 / the 64-04 lesson):** never backtick-autolink a `@moduledoc
false` module (`LatticeStripe.ObjectTypes` is hidden). Reference hidden modules as plain prose or
the ExDoc warning count rises above the 38 baseline and gate step 4/5 fails.

---

## Shared Patterns

### The promotion sequence (apply to every moved fixture)
**Source:** the `TaxId` outcome + the `entitlements.ex:1-6` header.
1. `git mv` the file into `lib/lattice_stripe/testing/fixtures/`
2. `LatticeStripe.Test.Fixtures.X` → `LatticeStripe.Testing.Fixtures.X` (move alone = compile error)
3. `@moduledoc false` → real `@moduledoc` (`"Canonical raw fixtures for Stripe X objects."`)
4. Delete the `# PROMOTION TARGET` header
5. Add `@spec f(map()) :: map()` to every builder
6. Update every caller `alias`/`import` (exact lines tabulated above)
7. Append to `mix.exs` `groups_for_modules[:Testing]`
8. Append to the `guides/testing.md` bullet list
9. Add a `docs_truth_test.exs` group-membership assertion

### Secrets audit before entering `lib/`
**Source:** `mix.exs:325` `files: ["lib", ...]`.
**Apply to:** every promoted file, at the moment of the move (last free opportunity).
`grep -nE 'sk_live|pk_live|whsec_|rk_live|acct_1' <file>` — every value must be obviously synthetic.

### Compile-path crossing
**Source:** `mix.exs:329-330`.
**Apply to:** every promoted file. A file in `lib/` may not reference `LatticeStripe.TestHelpers`
(test-only). All five promotion candidates are currently pure — do not introduce such a call, and
put `MIX_ENV=prod mix compile` in a `<verify>` block (CI does not run it).

### Alias + usage in one commit
**Source:** STATE `[63-01]`, `ci.yml:92`.
**Apply to:** `testing.ex` and every caller test file.

---

## Anti-Precedent — do NOT copy `Dispute`

`test/support/fixtures/dispute.ex` and `lib/lattice_stripe/testing/fixtures/dispute.ex` both exist
with byte-identical function bodies and **no test locks them together** — silent drift by
construction. It is the path of least resistance (no callers to update) and it is wrong.

**Use the `TaxId` precedent: move, leave no private twin.** If any plan proposes duplication for
the OBJ-03 fixtures, it must also ship a drift lock, e.g.
`assert Testing.Fixtures.Customer.customer_json() == Test.Fixtures.Customer.customer_json()`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/lattice_stripe/testing/fixtures/invoice.ex` | fixture module | data | No invoice fixture **module** exists anywhere. The *body* is fully specified by `test/lattice_stripe/invoice_test.exs:16-61`; only the module wrapper is new, and `tax_id.ex` supplies that. Effectively a partial match, not a gap. |
| Flattening a nested fixture module (Q1) | fixture module | data | The Tax family was flattened on promotion, but that predates the current tree and left no nested source to diff against. There is **no in-tree example of a nested `Test.Fixtures.*` module being flattened into public flat modules**, so the metering shape decision has no precedent to copy — it is a genuine `checkpoint:decision`. |

---

## Metadata

**Analog search scope:** `lib/lattice_stripe/` (all depths), `lib/lattice_stripe/testing/`,
`test/support/fixtures/`, `test/lattice_stripe/`, `mix.exs`, `guides/`

**Files read this session:** `lib/lattice_stripe/object_types.ex` (whole),
`lib/lattice_stripe/testing.ex` (1-130), `lib/lattice_stripe/testing/fixtures.ex` (whole),
`lib/lattice_stripe/testing/fixtures/tax_id.ex` (whole), `.../fixtures/dispute.ex` (whole),
`test/support/fixtures/entitlements.ex` (whole), `.../metering.ex` (1-120),
`.../customer.ex` (whole), `.../subscription.ex` (whole), `.../payment_intent.ex` (whole),
`test/lattice_stripe/object_types_test.exs` (1-60, 170-234),
`test/lattice_stripe/testing_test.exs` (1-45, 238-263),
`test/lattice_stripe/docs_truth_test.exs` (520-609, greps),
`test/lattice_stripe/invoice_test.exs` (1-65), `mix.exs` (greps), `guides/testing.md` (1-40),
plus a repo-wide `grep` enumerating all `Test.Fixtures.*` caller lines.

**Pattern extraction date:** 2026-07-28
