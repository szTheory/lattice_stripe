# Phase 65: Webhook ObjectTypes & Testing Fixtures - Research

**Researched:** 2026-07-28
**Domain:** Elixir SDK internals — a compile-time dispatch registry (`@object_map`) plus a public test-fixture surface promotion (`test/support/` → `lib/`)
**Confidence:** HIGH (grounded almost entirely in direct source reads and executed commands in this worktree; near-zero web dependency)

---

<user_constraints>
## User Constraints

**There is NO `65-CONTEXT.md`** — `/gsd-discuss-phase` was not run for Phase 65. The binding
constraints below are assembled from three authoritative sources, in this precedence order:

1. `.planning/ROADMAP.md` § Phase 65 (build constraints + success criteria) — **primary**
2. `.planning/phases/64-meter-event-summary-reads/64-CONTEXT.md` **F-13 / D-14** — the exclusion rule
3. `.planning/phases/63-stripe-native-entitlements/63-CONTEXT.md` — inherited namespace/idiom rules

### Locked Decisions (from ROADMAP Phase 65 build constraints, verbatim)

> Register in `lib/lattice_stripe/object_types.ex` (`billing.meter_event` module already exists — registrable as-is). Each key → a module with `from_map/1`; the `active_entitlement_summary` key must tolerate the missing `id`. Follow existing `LatticeStripe.Testing` fixture patterns (e.g. `dispute/1`, `customer/1`). Phase 63's `test/support/fixtures/entitlements.ex` is a promotion target: move it to `lib/lattice_stripe/testing/fixtures/entitlements.ex` **and** rename the module from `LatticeStripe.Test.Fixtures.Entitlements` to `LatticeStripe.Testing.Fixtures.Entitlements` — this is a move *plus* a module rename, because the private test-support namespace (`LatticeStripe.Test.Fixtures.*`) differs from the public one (`LatticeStripe.Testing.Fixtures.*`) and a literal file move alone produces a compile error; carry the four function names (`active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2`) and their bodies over unchanged rather than re-authoring them.

### Locked Decision — Phase 64 CONTEXT D-14 (verbatim, `64-CONTEXT.md:145`)

> **D-14 ⚠ — strike `billing.meter_error_report` from Phase 65's OBJ-01.** F-13: `maybe_deserialize/1` dispatches on `%{"object" => _}`, and this payload has no `"object"` key, so the registry row is **unimplementable and would be a dead key** a future contributor assumes works. `MeterErrorReport.from_map/1` must be called **explicitly** from the webhook handler. The other four OBJ-01 keys are fine. Lock it with a `refute` (D-31).

### Supporting Finding — Phase 64 CONTEXT F-13 (verbatim, `64-CONTEXT.md:49`)

> **F-13 — VERIFIED — `ObjectTypes.maybe_deserialize/1` structurally cannot handle it.** Dispatch is `def maybe_deserialize(%{"object" => object_type} = map)` (`object_types.ex:73`, read directly). The `data` payload has **no `"object"` key**, so it falls through to the raw-map clause. **Phase 65's OBJ-01 row for `billing.meter_error_report` is a dead key by construction** — see D-14.

### Inherited Constraints (Phase 63 CONTEXT / STATE carry-forward — still binding)

- **[63-01 / D-16, one-way]** `LatticeStripe.Entitlements.*` is the published semver namespace. Do not rename.
- **[63-04 / F-02]** `%ActiveEntitlementSummary{}` has **no `:id` field**, deliberately, with a source comment saying so. Do not "fix" it.
- **[STATE carry-forward]** **Gate against an ExDoc warning baseline of 38**, not 42. Confirmed by execution this session (see § Validation Architecture).
- **[STATE carry-forward]** `mix ci` is **RED at clean HEAD** (its last step is `docs --warnings-as-errors`). **Do not use `mix ci` as this phase's gate.** Use a differential gate.
- **[STATE carry-forward]** Two pre-existing flakes: `test/lattice_stripe/client_test.exs:912` (~1 in 20) and `test/lattice_stripe/batch_test.exs:72` (~1 in 30). Neither is Phase 65's to fix; a spurious red is ~1 in 12 per full run.
- **[SEED-005 §6, FROZEN]** `Client.new!/1` takes a keyword list; per-request opts override per-client; nil `stripe_account` omits the header; `api_version` default `2026-03-25.dahlia`.

### Claude's Discretion

Prose, `@moduledoc`/`@doc` wording, test names, plan/wave decomposition, and fixture field
selection for the newly-authored core-billing fixtures. Also **the open questions in § Open
Questions** — chiefly the shape of the metering fixture promotion (Q1) and whether the OBJ-03
core-billing fixtures are moved or duplicated (Q2). These are genuinely unresolved and should be
settled before planning, not during.

### Deferred Ideas (OUT OF SCOPE)

- Registering a fifth key `billing.meter_error_report` — **forbidden** (D-14).
- Any new Stripe verb, request, or resource module. This phase adds registry rows and fixtures only.
- Clearing the 38 pre-existing ExDoc warnings — that is Phase 67-shaped work.
- Fixing the two known flakes — logged in `64/deferred-items.md`.
- `Product.Feature` typing — Phase 66.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **OBJ-01** | Four missing webhook object types deserialize via `ObjectTypes.maybe_deserialize/1` | § The Four-vs-Five Resolution; § Pattern 1 (registry row); § Target Module Audit — all four `from_map/1` implementations **empirically verified to work** this session |
| **OBJ-02** | Public `Testing.Fixtures` for entitlement + meter objects (incl. no-`id` summary), each with a typed-conversion wrapper in `Testing` | § Pattern 2 (public fixture module); § Pattern 3 (typed wrapper); § The Two Promotion Targets; § Open Question Q1 |
| **OBJ-03** | Public `Testing.Fixtures` for core billing objects (subscription, invoice, customer, payment_intent) | § Core-Billing Fixture Inventory — **`invoice` has no fixture module anywhere**, it must be authored; the other three exist privately; § Open Question Q2 |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 65 |
|-----------|--------------------|
| **No Dialyzer** — typespecs are documentation only | Add `@spec` to new public fixture functions (matches `Testing.Fixtures.Dispute`), but no Dialyzer gate exists to enforce them. |
| **Dependencies: minimal** | **Phase 65 adds ZERO dependencies.** Everything needed is already in the tree. |
| **Elixir 1.15+ / OTP 26+** | Nothing in this phase uses post-1.15 syntax. Local toolchain is Elixir 1.19.5 / OTP 28 (verified). |
| **What NOT to Use: ExVCR / Bypass** | Fixtures stay pure string-keyed maps + Mox at the `Transport` boundary. No cassettes. |
| **GSD Workflow Enforcement** | All edits go through `/gsd-execute-phase`. |
| **Credo (not Dialyzer) for static analysis** | `.credo.exs` includes `lib/` and `test/`, with `Credo.Check.Readability.ModuleDoc` **enabled**. Every module promoted into `lib/` must carry a `@moduledoc` (real string or `false`) or `mix credo --strict` fails. |
| **Conventions / Architecture sections are empty** | No conflicting project convention exists; the codebase's own idioms (documented below) are the authority. |

---

## Summary

Phase 65 is small in code volume and disproportionately large in *decision* content. It is two
mechanically distinct jobs sharing one phase:

**Job A (OBJ-01) — four registry rows.** `lib/lattice_stripe/object_types.ex` is a single
47-entry compile-time map (`@object_map`) at module attribute scope with a three-clause
`maybe_deserialize/1` and a `fetch_module/1` accessor. Adding a key is a one-line insertion.
**All four target modules already exist and all four already expose a working `from_map/1`** — I
executed each one against its existing fixture this session and confirmed a typed struct comes
back, including the no-`id` `ActiveEntitlementSummary` (verified `Map.has_key?(struct, :id) ==
false` while `customer` populates). Nothing must be built; nothing must be modified. The
`refute` lock for the deliberately-absent `billing.meter_error_report` key **already exists** —
Phase 64 Plan 04 wrote it at `test/lattice_stripe/object_types_test.exs:217-227` plus a second
positive-behavior lock at `:181-191`. Phase 65 should *verify* those two tests, not re-author
them. The non-obvious risk in Job A is that `@object_map` is **dual-purpose**: `fetch_module/1`
also gates `Webhook.fetch_related_object/3`'s HTTP request (Phase 47 D-05 fail-fast contract), so
each new key silently unlocks a thin-event fetch path for that type.

**Job B (OBJ-02/OBJ-03) — the public fixture surface.** `lib/lattice_stripe/testing/fixtures/`
already holds ten public fixture modules following a rigid, easy-to-copy shape: one flat module
per resource, a real `@moduledoc`, `@spec`'d `*_json(overrides \\ %{})` functions returning
`Map.merge(canonical_map, overrides)`. `LatticeStripe.Testing` holds one-line typed wrappers
(`def dispute(raw_map), do: Dispute.from_map(raw_map)`). Two `test/support/` files carry
in-source `# PROMOTION TARGET (Phase 65 ...)` headers written by prior phases —
`entitlements.ex` and, less visibly, **`metering.ex`** (the ROADMAP build constraint names only
the first; the second's header was written by Phase 64 and is easy to miss). Because
`mix.exs`'s package `files:` list is `["lib", "mix.exs", "README.md", "CHANGELOG.md",
"LICENSE"]`, anything moved into `lib/` **ships in the Hex tarball** — which is the point (this
is a public testing surface), but it also means the fixtures become semver-covered API and
Credo's `ModuleDoc` check starts applying to them.

The single largest correctness hazard is a **counting error already present in the ROADMAP goal
line** — it says "five" object types while OBJ-01 and Success Criterion 1 both enumerate four.
Resolved plainly below.

**Primary recommendation:** Split into two independent plan tracks — a tiny Wave 1 that adds the
four `@object_map` rows and their positive dispatch assertions (the `refute` lock is already
green, verify only), and a larger Wave 1-parallel fixture track whose *first* task is resolving
Open Questions Q1 and Q2 as a `checkpoint:decision`, because both are one-way public-API naming
doors that a Hex 1.8.0 tag makes permanent.

---

## The Four-vs-Five Resolution

**The ROADMAP goal line is wrong; OBJ-01 and Success Criterion 1 are right. Register FOUR keys.**

| Source | Says | Verdict |
|--------|------|---------|
| `ROADMAP.md:155` goal — *"The five missing entitlement/meter webhook object types"* | five | **Stale prose.** Written before Phase 64's D-14 was decided. `ROADMAP.md:36` repeats it in the phase checklist line. |
| `ROADMAP.md:160` Success Criterion 1 | enumerates four, then explicitly excludes `billing.meter_error_report` | **Authoritative** |
| `REQUIREMENTS.md:27` OBJ-01 — *"The four missing webhook object types"* | four | **Authoritative** |
| `64-CONTEXT.md:145` D-14 | strike the fifth | **Authoritative, one-way** |
| `test/lattice_stripe/object_types_test.exs:217` | already refutes the fifth key | **Already enforced in code** |

The "five" almost certainly counted `billing.meter_error_report` before F-13 proved it
structurally unregistrable. **The planner MUST NOT register a fifth key**, and should include a
housekeeping task correcting `ROADMAP.md:36` and `:155` from "five" to "four" so the stale count
does not survive into the milestone summary. [VERIFIED: direct read of all five sources in this
worktree]

The four keys to register:

| Wire `"object"` string | Module | Module exists | `from_map/1` exists | Verified working |
|---|---|---|---|---|
| `entitlements.active_entitlement` | `LatticeStripe.Entitlements.ActiveEntitlement` | ✅ | ✅ (`:211-216`) | ✅ executed |
| `entitlements.active_entitlement_summary` | `LatticeStripe.Entitlements.ActiveEntitlementSummary` | ✅ | ✅ (`:134-139`) | ✅ executed |
| `billing.meter_event` | `LatticeStripe.Billing.MeterEvent` | ✅ | ✅ (`:104`) | ✅ executed |
| `billing.meter_event_summary` | `LatticeStripe.Billing.MeterEventSummary` | ✅ | ✅ (`:344-349`) | ✅ executed |

---

## Architectural Responsibility Map

This is a single-tier Elixir library. The meaningful decomposition is by *module role*, not
network tier.

| Capability | Primary Owner | Secondary | Rationale |
|------------|---------------|-----------|-----------|
| Wire-string → module dispatch (OBJ-01) | `lib/lattice_stripe/object_types.ex` (`@object_map`) | — | Single compile-time registry; the codebase's only dispatch table. |
| Wire-map → typed struct decoding | The resource module's own `from_map/1` | — | Already implemented for all four. `ObjectTypes` never decodes; it only routes. |
| Thin-event related-object HTTP gate | `lib/lattice_stripe/webhook.ex` `fetch_related_object/3` | `ObjectTypes.fetch_module/1` | **Coupling hazard:** shares `@object_map` with the deserializer. See Pitfall 1. |
| Canonical raw fixture maps (public) | `lib/lattice_stripe/testing/fixtures/*.ex` | — | Ships in the Hex package (`mix.exs:325`). Semver-covered. |
| Canonical raw fixture maps (private) | `test/support/fixtures/*.ex` | — | Compiled only under `elixirc_paths(:test)` (`mix.exs:329`). Not shipped. |
| Typed-struct conversion wrappers (public) | `lib/lattice_stripe/testing.ex` | resource `from_map/1` | One-liner delegation; the entire wrapper contract. |
| ExDoc grouping / semver registration | `mix.exs` `groups_for_modules[:Testing]` | `test/lattice_stripe/docs_truth_test.exs` | A module absent from its group is silently dropped from HexDocs. |
| Docs-truth regression locks | `test/lattice_stripe/docs_truth_test.exs` | `guides/testing.md` | Its own CI lane ("Docs Truth"). |

---

## Standard Stack

### Core — nothing is added

**Phase 65 introduces ZERO new dependencies.** Every capability it needs already exists in
`mix.exs`. [VERIFIED: `mix.exs` read directly]

| Library | Version in tree | Role in this phase |
|---------|-----------------|--------------------|
| ExUnit | Elixir 1.19.5 stdlib | All new tests |
| Mox | `~> 1.2` | Not strictly needed — Phase 65's tests are pure decode/structural tests, no HTTP |
| Jason | `~> 1.4` | Indirect (fixtures are maps, not JSON strings) |
| ExDoc | `~> 0.34` (0.40.x installed) | `groups_for_modules[:Testing]` registration for new public modules |
| Credo | `~> 1.7` | `Readability.ModuleDoc` applies to everything moved into `lib/` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual `@object_map` entry | A `use`-macro / compile-time module scan that auto-registers any module defining `from_map/1` + an `object` default | **Reject.** Would auto-register `MeterErrorReport` (which has `from_map/1` but no `"object"` key) — the exact dead key D-14 forbids. Explicit rows are the mitigation, not an inconvenience. |
| Moving `test/support` fixtures into `lib/` | Duplicating them (keep both copies) | **Both precedents exist in-tree** (`Dispute` was duplicated; `TaxId` was moved). See Open Question Q2 and Pitfall 5 — duplication has already produced two byte-identical files with no drift lock. |
| One `metering.ex` file with nested fixture modules | Flat one-file-per-resource | Public precedent is **flat** (`Testing.Fixtures.TaxCalculation`, not `Testing.Fixtures.Tax.Calculation`); Phase 64's in-source header says keep the nested file. Genuine conflict — Q1. |

**Installation:** none.

---

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.**

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| *(none)* | — | — | — |

**Packages removed due to `[SLOP]` verdict:** none
**Packages flagged as suspicious `[SUS]`:** none

No `mix.exs` `deps/0` change is expected. If a plan proposes one, that is a scope violation
against CLAUDE.md's "Dependencies: minimal" directive and should be challenged.

---

## Target Module Audit (empirically verified this session)

I ran each `from_map/1` against its existing fixture via `MIX_ENV=test mix run`. Results:

```
active_entitlement:      LatticeStripe.Entitlements.ActiveEntitlement
summary(no id):          {LatticeStripe.Entitlements.ActiveEntitlementSummary, false, "cus_ABC123customer"}
                          #  ^ Map.has_key?(struct, :id) == false — the no-id contract holds
meter_event:             #LatticeStripe.Billing.MeterEvent<event_name: "api_call", ...>
meter_event_summary:     LatticeStripe.Billing.MeterEventSummary
```

**Conclusion: no module must be created and no `from_map/1` must be written.** OBJ-01 is four
lines of `@object_map` plus tests. [VERIFIED: executed in this worktree]

### Per-module notes the planner needs

**`LatticeStripe.Entitlements.ActiveEntitlement`** (`active_entitlement.ex`) — full-resource
template: `@known_fields ~w(id object feature lookup_key livemode)`, `defstruct [..., object:
"entitlements.active_entitlement", extra: %{}]`, three-clause `from_map/1` with the
`%__MODULE__{}` idempotency clause preceding `is_map/1`. Nothing to do.

**`LatticeStripe.Entitlements.ActiveEntitlementSummary`** (`active_entitlement_summary.ex`) —
**the no-`id` module.** `@known_fields ~w(object customer entitlements livemode)` with the
in-source comment *"Exactly the four fields Stripe's spec marks required. Note the absence of
'id'."* and a second comment at `:80-82`: *"There is deliberately NO :id field... This is not an
oversight and must not be 'fixed'."* `from_map/1` never references `id`, so **the "must tolerate
the missing id" build constraint is already satisfied by construction** — there is no id-handling
code path to break. The phase's job is to *prove* it with a registry-level assertion, not to add
tolerance. Its `parse_entitlements/2` has a load-bearing call-order comment (`:154-159`): pass the
raw list to `List.from_json/3` **before** typing `data`, or `_last_id` silently goes nil.

**`LatticeStripe.Billing.MeterEvent`** (`meter_event.ex`) — **the odd one out.** Its struct is
`defstruct [:event_name, :identifier, :payload, :timestamp, :created, :livemode]` — **no
`:object` field, no `:id`, no `:extra`, and no `@known_fields` attribute at all** (documented as
the "EVENT-05 minimal-struct contract"). It also carries a custom `defimpl Inspect` that hides
`:payload`. Two consequences:
1. `maybe_deserialize/1` returns a `%MeterEvent{}` that has **dropped the `"object"` key** — an
   assertion of the form `assert result.object == "billing.meter_event"` will fail with a
   `KeyError`. Assert on `%MeterEvent{event_name: "api_call"}` instead.
2. See Pitfall 2 — the missing `@known_fields` has a drift-tooling consequence.

**`LatticeStripe.Billing.MeterEventSummary`** (`meter_event_summary.ex`) — standard shape, but
`@known_fields` uses the **square-bracket sigil** `~w[...]` with an in-source comment explaining
why (Phase 64 D-20 + the `drift.ex` regex fix in 64-02). Do not "normalize" it to parens.

---

## Architecture Patterns

### System Architecture Diagram

```
                          ┌─────────────────────────────────────┐
   Stripe v1 webhook  ──▶ │ Webhook.construct_event/4           │
   (snapshot, signed)     │  → %Event{data: %{"object" => map}} │
                          └───────────────┬─────────────────────┘
                                          │  raw string-keyed map
                                          ▼
   Stripe v2 thin event   ┌─────────────────────────────────────┐
   (related_object) ────▶ │ Webhook.fetch_related_object/3      │
                          │  1. ObjectTypes.fetch_module(type)  │◀── GATE (Phase 47 D-05):
                          │     :error → {:error,               │    unknown type ⇒ NO HTTP
                          │       {:unknown_object_type, t}}    │
                          │  2. GET related_object.url          │
                          │  3. ObjectTypes.maybe_deserialize   │
                          └───────────────┬─────────────────────┘
                                          ▼
                    ╔═════════════════════════════════════════════╗
                    ║ lib/lattice_stripe/object_types.ex          ║
                    ║ @object_map  (47 rows today → 51 after 65)  ║
                    ║                                             ║
                    ║ maybe_deserialize(nil)        → nil         ║
                    ║ maybe_deserialize(binary)     → binary      ║
                    ║ maybe_deserialize(%{"object"  → module      ║
                    ║   => t} = m)                    .from_map(m)║
                    ║   ...:error branch            → m (raw)     ║  ◀── billing.meter_error_report
                    ║ maybe_deserialize(map)        → map         ║      lands HERE, forever,
                    ╚══════════════╤══════════════════════════════╝      because it has no
                                   │  {:ok, module}                      "object" key at all
              ┌────────────────────┼────────────────────┬─────────────────┐
              ▼                    ▼                    ▼                 ▼
   Entitlements.Active   Entitlements.Active   Billing.MeterEvent   Billing.MeterEvent
     Entitlement           EntitlementSummary    .from_map/1          Summary.from_map/1
     .from_map/1           .from_map/1           (no :object,         (~w[ ] sigil)
                           (NO :id)               no :extra)


   ══════════════ separate, explicit path — never reaches the registry ══════════════

   v1.billing.meter.error_report_triggered
        │  event.data  (no "object" key)
        ▼
   Billing.MeterErrorReport.from_event/1  ──▶  %MeterErrorReport{reason: %Reason{...}}


   ══════════════ the fixture surface (OBJ-02 / OBJ-03) ══════════════

   PUBLIC (ships in Hex — mix.exs files: ["lib", ...])     PRIVATE (test-only)
   ┌────────────────────────────────────────────┐        ┌──────────────────────────┐
   │ lib/lattice_stripe/testing/fixtures/*.ex   │        │ test/support/fixtures/   │
   │   LatticeStripe.Testing.Fixtures.Dispute   │        │  LatticeStripe.Test.     │
   │   ...TaxId, ...Quote  (10 modules)         │◀─move──│    Fixtures.Entitlements │
   │            │ raw string-keyed map          │  +     │  LatticeStripe.Test.     │
   │            ▼                               │ rename │    Fixtures.Metering     │
   │ lib/lattice_stripe/testing.ex              │        │  (elixirc_paths(:test)   │
   │   Testing.dispute/1  → Dispute.from_map/1  │        │   only — mix.exs:329)    │
   │   Testing.generate_webhook_event/3         │        └──────────────────────────┘
   │   Testing.generate_webhook_payload/3       │
   └────────────────────────────────────────────┘
```

### Recommended Project Structure (post-phase)

```
lib/lattice_stripe/
├── object_types.ex                       # +4 rows in @object_map
├── testing.ex                            # +N one-line typed wrappers
└── testing/fixtures/
    ├── dispute.ex  credit_note.ex  ...   # 10 existing, untouched
    ├── entitlements.ex                   # MOVED from test/support + renamed
    ├── metering.ex        (or split)     # MOVED from test/support + renamed  ← see Q1
    ├── customer.ex  subscription.ex      # OBJ-03
    ├── payment_intent.ex                 # OBJ-03
    └── invoice.ex                        # OBJ-03 — NEW, no source exists anywhere
mix.exs                                   # groups_for_modules[:Testing] += new modules
guides/testing.md                         # the public fixture bullet list += new modules
test/lattice_stripe/object_types_test.exs # +4 positive dispatch tests (refute already there)
test/lattice_stripe/testing_test.exs      # +fixture-builder and typed-wrapper assertions
test/lattice_stripe/docs_truth_test.exs   # +ExDoc Testing-group placement assertions
```

### Pattern 1: Adding an `@object_map` row

**What:** A single `"wire_string" => Module,` line inside the `@object_map` literal.
**When to use:** Whenever a Stripe object arrives in a `%{"object" => ...}` envelope AND a module
with `from_map/1` exists for it.
**Constraint:** The key must match the wire `"object"` string **verbatim**. All four target
strings are already present as `defstruct` defaults in their own modules — copy from there rather
than retyping.

```elixir
# lib/lattice_stripe/object_types.ex — inside @object_map %{ ... }
# Source: existing rows at object_types.ex:38-52 (tax.* and billing.meter precedent)
    "billing.meter" => LatticeStripe.Billing.Meter,
    "billing.meter_event" => LatticeStripe.Billing.MeterEvent,
    "billing.meter_event_summary" => LatticeStripe.Billing.MeterEventSummary,
    "entitlements.active_entitlement" => LatticeStripe.Entitlements.ActiveEntitlement,
    "entitlements.active_entitlement_summary" =>
      LatticeStripe.Entitlements.ActiveEntitlementSummary,
```

**Note the existing map is NOT alphabetically sorted** — it is roughly alphabetical through
`"transfer_reversal"` then appends `billing.meter`, `billing_portal.*`, `checkout.session`,
`test_helpers.test_clock`, `line_item` (`object_types.ex:47-52`). Placing new rows near their
family (`billing.meter*` together) is more consistent with the file than forcing global sort
order. `mix format` will not reorder map keys.

### Pattern 2: A public fixture module

**What:** One flat module per resource under `LatticeStripe.Testing.Fixtures.*`, a real
`@moduledoc`, `@spec`'d `*_json/1` builders taking `overrides \\ %{}`.
**When to use:** Every OBJ-02 / OBJ-03 fixture.

```elixir
# Source: lib/lattice_stripe/testing/fixtures/tax_id.ex (verbatim shape)
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
        # ... canonical wire fields ...
      },
      overrides
    )
  end
end
```

Note the *private* twins use `|> Map.merge(overrides)` at the end of a pipe
(`test/support/fixtures/entitlements.ex`) while the *public* ones use `Map.merge(map, overrides)`
as a call. Both are in-tree; the ROADMAP says carry the promoted bodies over **unchanged**, so
prefer preserving the source form over normalizing it.

### Pattern 3: A typed-conversion wrapper in `LatticeStripe.Testing`

**What:** A three-line `@doc` + `@spec` + one-line delegation. Never anything more.

```elixir
# Source: lib/lattice_stripe/testing.ex:78-82
  @doc """
  Converts a canonical Dispute fixture map into `%LatticeStripe.Dispute{}`.
  """
  @spec dispute(map()) :: Dispute.t()
  def dispute(raw_map), do: Dispute.from_map(raw_map)
```

The module aliases its targets in one `alias LatticeStripe.{...}` block at `testing.ex:49-62`;
new wrappers must extend that block. `LatticeStripe.Entitlements.*` and `LatticeStripe.Billing.*`
are **not currently aliased there** and will need adding — mind unused-alias warnings under
`--warnings-as-errors` (this exact trap bit Phase 63; see STATE `[63-01]`).

**Naming caution:** `Testing.quote/1` already exists and shadows `Kernel.quote/2` inside that
module — precedent that the project accepts shadowing for wire-name fidelity. A wrapper named
`Testing.subscription/1`, `Testing.invoice/1`, `Testing.customer/1`, `Testing.payment_intent/1`
has no such conflict. `Testing.active_entitlement/1`, `active_entitlement_summary/1`,
`meter_event/1`, `meter_event_summary/1` likewise.

### Pattern 4: The promotion (move + rename + caller update)

The ROADMAP is explicit that this is **not** a file move. Sequence:

1. `git mv test/support/fixtures/entitlements.ex lib/lattice_stripe/testing/fixtures/entitlements.ex`
2. Rename `defmodule LatticeStripe.Test.Fixtures.Entitlements` →
   `defmodule LatticeStripe.Testing.Fixtures.Entitlements`
3. Replace `@moduledoc false` with a real `@moduledoc` (required for the module to appear in
   HexDocs at all; `@moduledoc false` would satisfy Credo but produce an invisible "public" surface)
4. Delete the `# PROMOTION TARGET (Phase 65 ...)` header comment — it is discharged
5. Update the alias line in **each caller** (exact list below)
6. Add `@spec` lines to match public-fixture convention
7. Register in `mix.exs` `groups_for_modules[:Testing]`
8. Add to the `guides/testing.md` bullet list at `:20-29`

### Anti-Patterns to Avoid

- **Registering a fifth key.** D-14 forbids it; `object_types_test.exs:217` already fails if you do.
- **Adding `:id` to `ActiveEntitlementSummary`.** Two in-source comments forbid it (`:69`, `:80-82`).
- **Asserting `.object` on a `%MeterEvent{}`.** The struct has no such field — `KeyError`.
- **Auto-registering by scanning for `from_map/1`.** Would resurrect the dead key.
- **`@moduledoc false` on a promoted "public" fixture.** Passes Credo, ships in the tarball,
  never appears in HexDocs — a public surface nobody can discover.
- **Normalizing `~w[...]` to `~w(...)` in `MeterEventSummary`.** Phase 64 D-20; the `drift.ex`
  regex handles both, but the bracket form is deliberate and commented.
- **Duplicating instead of moving.** Produces the `Dispute` situation (Pitfall 5).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wire-string → module dispatch | A `case`/`cond` in the webhook handler | `ObjectTypes.maybe_deserialize/1` | One registry, already gates HTTP too. |
| Wire-map → struct decoding | New decode logic in a fixture or test | The resource module's own `from_map/1` | All four already exist and are verified. |
| Fixture "override" merging | Keyword-list merge / `struct!/2` | `Map.merge(canonical, overrides)` with string keys | The wire is string-keyed; ten existing fixtures do exactly this. |
| Meter-error-report decoding | An `@object_map` row | `Billing.MeterErrorReport.from_event/1` | It is event `data`, not an object — D-14/F-13. |
| Building `%Event{}` test payloads | Hand-writing an event envelope | `Testing.generate_webhook_event/3` | Already exists, already used by the guide. |
| Signed webhook payloads | HMAC by hand | `Testing.generate_webhook_payload/3` | Already exists. |
| List envelopes in fixtures | Inline `%{"object" => "list", ...}` in each test | `LatticeStripe.TestHelpers.list_json/3` (`test/support/test_helpers.ex:55`) or the fixture's own `*_list_json/2` | Precedent: `Entitlements.active_entitlement_list_json/2`. Note `TestHelpers` is **test-only** and cannot be called from `lib/` — a promoted fixture must keep its own list builder. |

**Key insight:** Phase 65 is a *registration and relocation* phase. Almost every line it needs
already exists somewhere in the tree; the failure mode is re-authoring rather than under-building.

---

## Runtime State Inventory

This phase performs a module **rename** (`LatticeStripe.Test.Fixtures.*` →
`LatticeStripe.Testing.Fixtures.*`) and a **file relocation across compile paths**
(`test/support/` → `lib/`), so this section is mandatory.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| **Stored data** | **None — verified.** LatticeStripe is a stateless HTTP client library. `grep` for Ecto/Repo/database references in `lib/` returns nothing; CLAUDE.md explicitly lists Ecto under "What NOT to Use" (*"No database. This is an HTTP client library."*). No datastore holds the old module name. | none |
| **Live service config** | **None — verified.** The only external service touched is `stripe-mock`, started ad hoc via `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`; it holds no LatticeStripe module names. No n8n / Datadog / Cloudflare surface exists for this repo. | none |
| **OS-registered state** | **None — verified.** No launchd/systemd/Task Scheduler registration. The only scheduled automation is GitHub Actions (`.github/workflows/`: `ci.yml`, `drift.yml`, `pr-title.yml`, `publish-hex.yml`, `release.yml`, `release-pr-automerge.yml`, `dependabot-automerge.yml`) — **none references a fixture module name**; they invoke `mix` aliases only. | none |
| **Secrets / env vars** | **None — verified.** No `.env`, no SOPS. The only secret is the Hex publish token consumed by `publish-hex.yml`, unrelated to module naming. | none |
| **Build artifacts / installed packages** | **THREE items — action required.** ① Stale `.beam` files: `_build/{dev,test}/lib/lattice_stripe/ebin/Elixir.LatticeStripe.Test.Fixtures.Entitlements.beam` (and `...Metering*.beam`) persist until Mix's manifest prunes them. Mix normally removes beams for deleted sources, but this rename crosses `elixirc_paths` boundaries (`test/support` is compiled only in `:test`), so `_build/dev` and `_build/test` can diverge. ② **The Hex tarball grows** — `mix.exs:325` `files: ["lib", ...]` means every promoted fixture ships to hex.pm. This is intended (OBJ-02/03 say "public") but is a semver commitment. ③ ExDoc output (`doc/`) is regenerated, not stale-prone. | ① Run `mix clean && mix compile` (or at minimum `mix compile` in both `MIX_ENV=dev` and `MIX_ENV=test`) before trusting any structural assertion about module presence/absence. **Do NOT write a `refute Code.ensure_loaded?(LatticeStripe.Test.Fixtures.Entitlements)` lock** — it is stale-beam-sensitive and will produce a false green or false red depending on build cache. ② Run `mix hex.build` (already a CI Quality-lane step, `ci.yml:257`) and eyeball the file count. ③ none |

**The canonical question — "after every file in the repo is updated, what runtime systems still
have the old string cached?"** For this repo the answer is exactly one: **`_build` beam caches**,
and CI's `Cache _build` steps (`ci.yml:46,80,124,171,205,239`) mean a *restored* cache can carry
a stale `Elixir.LatticeStripe.Test.Fixtures.Entitlements.beam` into a CI run. That is the single
runtime-state risk in this phase, and it is low-severity (a stale beam for an unreferenced module
is inert) but it is the reason presence/absence assertions on the *old* name are unreliable.

---

## Common Pitfalls

### Pitfall 1: `@object_map` is dual-purpose — a new key silently unlocks an HTTP path

**What goes wrong:** Adding `"billing.meter_event_summary" => ...` does more than enable
deserialization. `ObjectTypes.fetch_module/1` is the **fail-fast gate** in
`Webhook.fetch_related_object/3` (`webhook.ex:444`): unknown types short-circuit to
`{:error, {:unknown_object_type, type}}` with **zero HTTP requests** (Phase 47 D-05). Registering
a type flips that branch — `fetch_related_object/3` will now issue
`GET <related_object.url>` for it.
**Why it happens:** The registry has two consumers and the phase brief only describes one.
**How to avoid:** Register anyway (the four types are correct), but be aware that
`entitlements.active_entitlement_summary` in particular is **not individually retrievable** — it
has no `id` and no canonical single-object URL — so if Stripe ever sent it as a `related_object`,
the GET would 404 rather than returning `{:error, {:unknown_object_type, _}}`. In practice Stripe
delivers entitlement summaries as v1 snapshot events, not v2 thin events, so this path is inert
today. Document the coupling in the plan rather than "fixing" it.
**Warning signs:** A `webhook/fetch_test.exs` case that asserts `{:error, {:unknown_object_type,
"entitlements.active_entitlement"}}` would start failing. Grep `test/lattice_stripe/webhook/`
before editing the map. [VERIFIED: `webhook.ex:429-456` read directly]

### Pitfall 2: `MeterEvent` has no `@known_fields`, which makes the drift report noisy

**What goes wrong:** `LatticeStripe.Drift.run/1` iterates `ObjectTypes.object_map()` and, for
each registered module, regex-scrapes `@known_fields ~w[...]` **out of the module's source file**
(`drift.ex:209-217`). `MeterEvent` has no `@known_fields` attribute at all, so
`parse_known_fields/1` falls to `nil -> MapSet.new()` and **every field in Stripe's
`billing.meter_event` schema is reported as an "actionable addition."**
**Why it happens:** `MeterEvent` deliberately follows the "EVENT-05 minimal-struct contract" (no
`:extra`, no `@known_fields`) — a valid choice that predates its registry membership.
**How to avoid:** Two options for the planner: (a) accept the noise and note it, or (b) add
`@known_fields ~w[object event_name identifier payload timestamp created livemode]` to
`meter_event.ex` purely for the drift tool. **Option (a) is lower-risk** — the same file's
`from_map/1` does not use `Map.split/2`, so introducing `@known_fields` without wiring it in
would be a decorative attribute that the next reader misreads as load-bearing.
**Blast radius is small:** drift runs in its own scheduled workflow (`.github/workflows/drift.yml`),
**not** in the PR-gating `ci.yml`, and requires network access to fetch Stripe's OpenAPI spec.
**Warning signs:** The next drift issue lists `LatticeStripe.Billing.MeterEvent` with a dozen `+`
additions. [VERIFIED: `drift.ex:16-42,192-217` + `meter_event.ex:20` read directly]

### Pitfall 3: Moving fixtures into `lib/` makes them compile in **every** env, including `:prod`

**What goes wrong:** `elixirc_paths(:test) → ["lib", "test/support"]`; `elixirc_paths(_) →
["lib"]` (`mix.exs:329-330`). A file in `test/support/` may reference other test-support code; a
file in `lib/` may not, or the production build breaks.
**Why it happens:** The promotion crosses a compile-path boundary invisibly.
**How to avoid:** Audit each promotion candidate for test-only references before moving. I did
this: **`test/support/fixtures/entitlements.ex` and `test/support/fixtures/metering.ex` are both
pure** — they reference nothing but literals and each other's sibling functions. `customer.ex`,
`subscription.ex`, `payment_intent.ex` are likewise pure. (Contrast `test/support/fixtures/quote.ex`,
which aliases `LatticeStripe.{Customer, Product, Quote}` — those are `lib/` modules, so even that
would be safe.) The specific thing to watch for is any call into `LatticeStripe.TestHelpers`
(defined in `test/support/test_helpers.ex`, **test-only**) — e.g. `list_json/3`. None of the
promotion candidates call it today. **Do not introduce such a call during promotion.**
**Warning signs:** `MIX_ENV=prod mix compile` fails with `LatticeStripe.TestHelpers.list_json/3 is
undefined`. Add `MIX_ENV=prod mix compile` to a plan `<verify>` block — CI does not run it
(`ci.yml` compiles in the default env). [VERIFIED: `mix.exs:329-330` + source audit of all five
candidate files]

### Pitfall 4: `Credo.Check.Readability.ModuleDoc` + ExDoc invisibility

**What goes wrong:** Credo's `ModuleDoc` check is enabled (`.credo.exs:102`) and `lib/` is in the
`included` list (`:24-33`). A promoted module with no `@moduledoc` fails `mix credo --strict`
(a CI Quality-lane step, `ci.yml:251`). But satisfying it with `@moduledoc false` — which is what
the private fixtures currently carry — makes the module **invisible in HexDocs**, so the "public
fixture" is undiscoverable.
**Why it happens:** `@moduledoc false` passes the lint and looks done.
**How to avoid:** Every promoted fixture module gets a real `@moduledoc` string in the shape of
`Testing.Fixtures.Dispute`'s (*"Canonical raw fixtures for Stripe X objects."*). For
`metering.ex`, that is **six** modules (`Metering` + five nested), each currently
`@moduledoc false`.
**Warning signs:** `mix docs` succeeds, the module is in `groups_for_modules[:Testing]`, and it
still does not appear on the HexDocs sidebar. [VERIFIED: `.credo.exs` + all ten public fixture
files read directly]

### Pitfall 5: The `Dispute` precedent is a duplication, not a promotion — do not copy it

**What goes wrong:** `test/support/fixtures/dispute.ex` (`@moduledoc false`, no `@spec`) and
`lib/lattice_stripe/testing/fixtures/dispute.ex` (real `@moduledoc`, `@spec`'d) **both exist with
byte-identical function bodies**, and nothing in the test suite locks them together. That is
silent-drift-by-construction. `TaxId` shows the other precedent: promoted by move, with no
private twin left behind (`test/support/fixtures/` has `tax_registration.ex` and
`tax_settings.ex` but **no `tax_id.ex`**).
**Why it happens:** Duplication is the path of least resistance — no callers need updating.
**How to avoid:** Follow the **TaxId (move)** precedent, which is also what the ROADMAP build
constraint mandates for entitlements. If any plan proposes duplication for the OBJ-03 fixtures,
it must also propose a drift lock (e.g. an assertion that
`Testing.Fixtures.Customer.customer_json() == Test.Fixtures.Customer.customer_json()`).
**Warning signs:** A change to a private fixture that leaves the public twin stale, or vice versa.
[VERIFIED: `diff`-equivalent read of both `dispute.ex` files + `ls test/support/fixtures/`]

### Pitfall 6: Unused-alias warnings under `--warnings-as-errors`

**What goes wrong:** Adding `LatticeStripe.Entitlements` / `LatticeStripe.Billing` to
`testing.ex`'s `alias LatticeStripe.{...}` block **before** the wrappers that use them are written
fails `mix compile --warnings-as-errors` (`ci.yml:92` and `mix ci` step 2).
**Why it happens:** Plans that split "add alias" and "add wrapper" into different tasks.
**How to avoid:** Alias and wrapper land in the **same** task/commit. This is a recorded prior
incident — STATE `[63-01]`: *"Feature.ex ships decode-only; its alias `LatticeStripe.{Client,
Request, Resource}` was omitted (unused-alias vs `--warnings-as-errors`)"*.
**Warning signs:** A green local `mix test` and a red Compile lane in CI. [VERIFIED: STATE.md +
`ci.yml:92`]

### Pitfall 7: The `refute` lock already exists — re-authoring it creates a duplicate

**What goes wrong:** Success Criterion 1 says *"lock the absence with a `refute`."* A planner
reads that as "write a new test." **Phase 64 Plan 04 already wrote it**, twice:
- `test/lattice_stripe/object_types_test.exs:217-227` — `refute Map.has_key?(ObjectTypes.object_map(),
  "billing.meter_error_report")` plus `assert ObjectTypes.fetch_module("billing.meter_error_report")
  == :error`, with an eight-line comment that explicitly names Phase 65 and OBJ-01.
- `test/lattice_stripe/object_types_test.exs:181-191` — the positive-behavior twin: feeds the real
  `MeterErrorReport` fixture through `maybe_deserialize/1` and asserts `result == data` and
  `refute is_struct(result)`.
**How to avoid:** Phase 65's task is to **verify these two tests are present and green** after the
four rows are added (they are the regression proof that adding rows did not tempt a fifth), not to
write new ones. If the planner wants an additional lock, the useful new one is a *count* assertion
(`map_size(ObjectTypes.object_map()) == 51`) — but that is brittle against Phase 66's
`product.feature` row and is **not recommended**.
**Warning signs:** Two near-identical `describe` blocks in `object_types_test.exs`.
[VERIFIED: file read directly; both tests currently green in a 2305-test run]

### Pitfall 8: Two pre-existing flakes will occasionally redden an otherwise-clean run

`test/lattice_stripe/client_test.exs:912` (~1 in 20) and `test/lattice_stripe/batch_test.exs:72`
(~1 in 30) — combined ~1 in 12 per full-suite run, both proven pre-existing on commit `a22e197`.
**Do not** let a plan attribute such a failure to Phase 65's changes; re-run once and check the
test name against `.planning/phases/64-meter-event-summary-reads/deferred-items.md`.
[VERIFIED: STATE.md carry-forward]

---

## Code Examples

### The current dispatch (unchanged by this phase)

```elixir
# Source: lib/lattice_stripe/object_types.ex:69-80 (verbatim)
  @spec maybe_deserialize(map() | String.t() | nil) :: struct() | map() | String.t() | nil
  def maybe_deserialize(nil), do: nil
  def maybe_deserialize(val) when is_binary(val), do: val

  def maybe_deserialize(%{"object" => object_type} = map) do
    case Map.fetch(@object_map, object_type) do
      {:ok, module} -> module.from_map(map)
      :error -> map
    end
  end

  def maybe_deserialize(map) when is_map(map), do: map
```

### The four positive dispatch assertions (OBJ-01's proof)

```elixir
# Shape copied from object_types_test.exs:17-33 (the existing customer/payment_intent cases).
# Assert on a DISTINGUISHING field, not on .object — %MeterEvent{} has no :object key.
test "dispatches entitlements.active_entitlement to ActiveEntitlement.from_map/1" do
  map = Fixtures.Entitlements.active_entitlement_json()
  assert %LatticeStripe.Entitlements.ActiveEntitlement{id: "ent_123"} =
           ObjectTypes.maybe_deserialize(map)
end

test "dispatches the no-id active_entitlement_summary without dropping it" do
  map = Fixtures.Entitlements.active_entitlement_summary_json()
  result = ObjectTypes.maybe_deserialize(map)

  assert %LatticeStripe.Entitlements.ActiveEntitlementSummary{customer: "cus_ABC123customer"} =
           result

  # ENT-05 / F-02: the struct genuinely has no :id, and the registry row tolerates that.
  refute Map.has_key?(result, :id)
end

test "dispatches billing.meter_event to MeterEvent.from_map/1" do
  map = Fixtures.Metering.MeterEvent.basic()
  # NOT `result.object` — MeterEvent's defstruct has no :object field (meter_event.ex:20).
  assert %LatticeStripe.Billing.MeterEvent{event_name: "api_call"} =
           ObjectTypes.maybe_deserialize(map)
end

test "dispatches billing.meter_event_summary to MeterEventSummary.from_map/1" do
  map = Fixtures.Metering.MeterEventSummary.basic()
  assert %LatticeStripe.Billing.MeterEventSummary{id: "mtrusg_123", aggregated_value: 42.5} =
           ObjectTypes.maybe_deserialize(map)
end
```

### The typed-wrapper test shape (OBJ-02/03's proof)

```elixir
# Source: test/lattice_stripe/testing_test.exs:244-253 (extend these two existing blocks
# rather than adding new describe blocks).
  describe "typed wrappers" do
    test "return typed structs from canonical fixture maps" do
      assert %Dispute{} = Testing.dispute(Fixtures.Dispute.dispute_json())
      # ... + the new ones:
      assert %ActiveEntitlement{} =
               Testing.active_entitlement(Fixtures.Entitlements.active_entitlement_json())
    end
  end
```

### The `fetch_related_object/3` gate that shares the registry

```elixir
# Source: lib/lattice_stripe/webhook.ex:439-456 (verbatim) — the second consumer of @object_map.
  def fetch_related_object(%Client{} = client, %EventNotification{related_object:
        %RelatedObject{type: type, url: url}}, opts) do
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

---

## The Two Promotion Targets

Both files carry an in-source `# PROMOTION TARGET (Phase 65 / OBJ-02)` header written by a prior
phase. **The ROADMAP build constraint names only the first.** The second is easy to miss.

### Target A — `test/support/fixtures/entitlements.ex` → `lib/lattice_stripe/testing/fixtures/entitlements.ex`

- 78 lines, one flat module, four functions, `@moduledoc false`, no `@spec`s.
- Functions to carry over **unchanged**: `active_entitlement_json/1`,
  `feature_json/1`, `active_entitlement_summary_json/1`, `active_entitlement_list_json/2`.
- The `active_entitlement_summary_json/1` docstring explains that the nested `entitlements.url` is
  the **un-rewritten** webhook path `"/v1/customer/cus_ABC123customer/entitlements"` on purpose —
  Phase 63 D-04's rewrite is only provable if the fixture carries the original. **Do not
  "correct" that URL.**
- **Callers to update (4 files, one `alias` line each):**

| File | Line |
|---|---|
| `test/lattice_stripe/entitlements/active_entitlement_test.exs` | 8 |
| `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` | 13 |
| `test/lattice_stripe/entitlements/feature_test.exs` | 18 |
| `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | 19 |

### Target B — `test/support/fixtures/metering.ex` → (see Open Question Q1)

- 332 lines, **one outer module with five nested modules**: `Meter`, `MeterEvent`,
  `MeterEventAdjustment`, `MeterEventStreamSession`, `MeterEventSummary`, `MeterErrorReport`.
  All six carry `@moduledoc false`.
- `MeterErrorReport`'s fixture (`basic/1`, `event/1`, `no_meter_found_event/1`, `meter_id/0`) has
  a 25-line source comment recording that every value is **verbatim from Stripe's published
  example** and warning against hand-invented fixtures. Carry it over intact.
- **Callers to update (9 files, one `alias` line each):**

| File | Note |
|---|---|
| `test/lattice_stripe/object_types_test.exs` | **line 5** — `alias ... .MeterErrorReport, as: MeterErrorReportFixture`; this is the file Phase 65 edits anyway |
| `test/lattice_stripe/billing/meter_test.exs` | |
| `test/lattice_stripe/billing/meter_guards_test.exs` | |
| `test/lattice_stripe/billing/meter_event_test.exs` | |
| `test/lattice_stripe/billing/meter_event_summary_test.exs` | |
| `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` | |
| `test/lattice_stripe/billing/meter_event_stream_test.exs` | |
| `test/lattice_stripe/billing/meter_event_adjustment_test.exs` | |
| `test/lattice_stripe/billing/meter_error_report_test.exs` | |

---

## Core-Billing Fixture Inventory (OBJ-03)

| Object | Private fixture today | Module | Functions | Callers | Public fixture today |
|--------|----------------------|--------|-----------|---------|----------------------|
| `customer` | `test/support/fixtures/customer.ex` | `LatticeStripe.Test.Fixtures.Customer` | `customer_json/1` | 2 test files (`customer_test.exs`, `webhook/thin_event_test.exs`, `webhook/fetch_test.exs` → **3**) | ❌ |
| `subscription` | `test/support/fixtures/subscription.ex` | `LatticeStripe.Test.Fixtures.Subscription` | `basic/1`, `with_items/1`, `paused/1`, `canceled/1` | 1 (`subscription_test.exs`) | ❌ |
| `payment_intent` | `test/support/fixtures/payment_intent.ex` | `LatticeStripe.Test.Fixtures.PaymentIntent` | `payment_intent_json/1` | 1 (`payment_intent_test.exs`) | ❌ |
| **`invoice`** | **NONE — no fixture module exists anywhere in the repo** | — | — | — | ❌ |

**The invoice gap is the one genuinely new authoring task in this phase.** The only invoice
fixture data in the tree is a *private function* `invoice_json/1` inside
`test/lattice_stripe/invoice_test.exs:16-60` (≈35 wire fields including nested `automatic_tax`,
`status_transitions`, and a `lines` list envelope), plus a smaller
`invoice_json_for_telemetry/1` at `telemetry_test.exs:780`. **Recommendation:** lift
`invoice_test.exs`'s version into `LatticeStripe.Testing.Fixtures.Invoice.invoice_json/1`
verbatim and have the test call the public fixture — that preserves the exact shape the existing
19+ invoice assertions were written against, rather than inventing a new one.

**Naming inconsistency to resolve:** `Subscription` uses `basic/1` while `Customer` /
`PaymentIntent` / `Dispute` / `TaxId` use `<resource>_json/1`. The public surface is uniformly
`*_json` (all ten existing modules). Promoting `Subscription` verbatim would introduce the
project's first public `basic/1`. Either rename to `subscription_json/1` (breaks the one existing
caller — trivial) or accept the divergence. **Recommend renaming**, since this is a one-way
public-API door.

---

## State of the Art

| Old state | Current state | When changed | Impact on Phase 65 |
|-----------|---------------|--------------|--------------------|
| `@object_map` had no entitlement or meter-summary rows | Still true — Phase 64 left `object_types.ex` **byte-identical** to its pre-phase state, verified at gate time | Phase 64 close, 2026-07-28 | Phase 65 **owns every registry row**; no merge conflict risk from 63/64. [VERIFIED: STATE.md] |
| `billing.meter_error_report` presumed registrable | Proven structurally unregistrable (F-13); absence locked by test | Phase 64 Plan 04 | Do not register. Verify the existing lock. |
| ExDoc warning baseline 42 | **38** (42 → 40 via 64-09's `meter_event_stream.ex` IAL fix; 40 → 38 via 64-08's `scope.md` `../README.md` repair) | Phase 64 | Gate against **38**. Re-verified by execution this session. |
| Test count 2188 | **2305** (0 failures, 1 skipped, 214 excluded) | Phase 64 close | Step-3 floor for the differential gate. Re-verified this session. |
| `mix ci` usable as a phase gate | **RED at clean HEAD** — final step is `docs --warnings-as-errors` | Phase 63 | Use the differential gate below instead. |
| `LatticeStripe.Testing.Fixtures` covers "the v1.3 resource families" | Still says so in its `@moduledoc` and in `guides/testing.md:13-14` | v1.3 | **Stale prose** — Phase 65 extends the surface past v1.3 and must update both. |

**Deprecated / not to be used:**
- `mix ci` as this phase's gate (see above).
- `refute Code.ensure_loaded?(<old module name>)` as a rename proof — stale-beam-sensitive.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Stripe's wire payload for an active entitlement carries exactly `"object": "entitlements.active_entitlement"`, and the summary carries `"entitlements.active_entitlement_summary"`. **Not re-verified against live Stripe docs this session** — taken from `63-RESEARCH.md:212` (which cites the Stripe API reference) and from the modules' own `defstruct` defaults. | Four-vs-Five Resolution | A wrong key is a silently dead row: `maybe_deserialize/1` falls through to the raw-map clause and the object is never typed. **Mitigated** by the fact that Phase 63 shipped and its stripe-mock integration suite (`test/integration/entitlements_integration_test.exs`) routes real responses through `from_map/1`. |
| A2 | `"billing.meter_event"` and `"billing.meter_event_summary"` are the exact wire strings. Same provenance (`64-RESEARCH.md:817,832`, citing the OpenAPI `components.schemas` key). | Four-vs-Five Resolution | Same as A1. Lower risk — `64-RESEARCH.md:817` records the literal OpenAPI schema name. |
| A3 | Mix reliably prunes `.beam` files for modules whose source was deleted, across `elixirc_paths` boundaries. Based on general knowledge of Mix's compile manifest, not verified here. | Runtime State Inventory | A stale beam makes an absence assertion on the old module name unreliable. **Mitigated** by the recommendation not to write such an assertion at all. |
| A4 | Stripe does not deliver `entitlements.active_entitlement_summary` as a v2 thin-event `related_object`. Inferred from it having no `id` and no single-object endpoint; not confirmed against Stripe's v2 event-type catalog. | Pitfall 1 | If wrong, `fetch_related_object/3` would issue a GET that 404s instead of returning `{:error, {:unknown_object_type, _}}` — a worse error message, not data loss. |
| A5 | Adding fixture modules to `groups_for_modules[:Testing]` does not increase the ExDoc warning count. Untested (the modules do not exist yet). | Validation Architecture | If their moduledocs autolink a `@moduledoc false` module (e.g. `` `LatticeStripe.ObjectTypes` ``), the count rises past 38 and the gate fails — **this is exactly the 64-04 lesson**: reference hidden modules as plain prose, never as backticked autolinks. |

---

## Open Questions

### Q1 — What shape does the metering fixture promotion take? *(one-way public-API door)*

- **What we know:** `test/support/fixtures/metering.ex` carries a Phase-64-written header saying
  *"move this file to `lib/lattice_stripe/testing/fixtures/metering.ex` AND rename the module to
  `LatticeStripe.Testing.Fixtures.Metering`."* That yields depth-4 names like
  `LatticeStripe.Testing.Fixtures.Metering.MeterEventSummary`.
- **What's unclear:** Every one of the ten existing public fixture modules is **flat** —
  `Testing.Fixtures.TaxCalculation`, not `Testing.Fixtures.Tax.Calculation` (note that the Tax
  family was deliberately *flattened* on promotion). The in-source header and the established
  public convention conflict. Also unclear: whether all six nested fixtures should be promoted, or
  only the two OBJ-01-relevant ones (`MeterEvent`, `MeterEventSummary`) plus `MeterErrorReport`
  (which OBJ-02's "meter objects" arguably covers).
- **Recommendation:** Take this to a `checkpoint:decision` in Wave 1 before any file moves. My
  lean is **flat, matching the public convention**: `Testing.Fixtures.MeterEvent`,
  `Testing.Fixtures.MeterEventSummary`, `Testing.Fixtures.MeterErrorReport` — and **leave**
  `Meter`, `MeterEventAdjustment`, `MeterEventStreamSession` private in `test/support/`, since
  OBJ-02 names neither and promoting them expands the semver surface for free. That contradicts
  the in-source header, so it needs an explicit decision record, not a silent choice.

### Q2 — Are the OBJ-03 core-billing fixtures moved or duplicated?

- **What we know:** Both precedents exist in-tree — `TaxId` was moved (no private twin);
  `Dispute` was duplicated (two byte-identical files, no drift lock). The ROADMAP mandates *move*
  only for entitlements. `customer`/`subscription`/`payment_intent` have 5 caller files between
  them; `invoice` has none (it must be authored).
- **What's unclear:** Whether the small caller-update cost is worth avoiding the drift hazard.
- **Recommendation:** **Move.** Five alias-line edits is cheap, and the `Dispute` duplication is
  already an unlocked drift hazard this project should stop replicating. Also settle the
  `Subscription.basic/1` → `subscription_json/1` rename here (see § Core-Billing Fixture Inventory).

### Q3 — Should `meter_event.ex` gain a `@known_fields` attribute?

- **What we know:** Registering `billing.meter_event` makes `Drift` scrape its source for
  `@known_fields`; it has none, so the drift report will flag every spec field as an addition.
  Drift is a scheduled workflow, not a PR gate.
- **Recommendation:** **No** — accept the noise, note it in the plan. Adding a decorative
  `@known_fields` that `from_map/1` does not consume is a worse trap for the next reader. If the
  drift noise becomes annoying, it is a `/gsd-quick` follow-up.

### Q4 — Does the ROADMAP's "five" get corrected in this phase?

- **Recommendation:** Yes. Add a one-line housekeeping task correcting `ROADMAP.md:36` and `:155`
  from "Five"/"five" to "Four"/"four", so the milestone summary does not inherit the stale count.

---

## Environment Availability

Probed in this worktree, 2026-07-28.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | everything | ✓ | 1.19.5 | — |
| Erlang/OTP | everything | ✓ | 28 (erts-16.3) | — |
| `mix test` | all verification | ✓ | 2305 tests, 0 failures, 1 skipped, 214 excluded, 5.1s | — |
| `mix docs` (ExDoc) | ExDoc registration gate | ✓ | exits 0; **38 warnings** | — |
| `mix credo --strict` | CI Quality lane | ✓ (installed `~> 1.7`) | — | — |
| `mix format` | CI Format lane | ✓ | — | — |
| Mox | not needed this phase | ✓ | `~> 1.2` | — |
| **stripe-mock** (Docker) | integration lane only | **not probed / assume down** | — | **Phase 65 needs no integration tests** — every new test is a pure decode or structural assertion. Skip the lane. |
| Network (Stripe OpenAPI spec) | `mix lattice_stripe.check_drift` only | n/a | — | Drift is a separate scheduled workflow, not a phase gate. |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** stripe-mock — not required; do not add an integration
plan for this phase.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 stdlib); Mox `~> 1.2` available but **not needed** this phase |
| Config file | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])` |
| Quick run command | `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/testing_test.exs` |
| Full suite command | `mix test` |
| Docs-truth lane | `mix test test/lattice_stripe/docs_truth_test.exs` (its own CI lane, `ci.yml:217`) |
| Measured baseline | **2305 tests, 0 failures, 1 skipped, 214 excluded — 5.1s** (executed this session) |
| ExDoc baseline | **38 warnings, `mix docs` exit 0, 0 warnings matching `entitlement|meter|testing|fixture`** (executed this session) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OBJ-01 | `maybe_deserialize/1` returns `%ActiveEntitlement{}` for `entitlements.active_entitlement` | unit | `mix test test/lattice_stripe/object_types_test.exs` | ✅ file exists, case ❌ Wave 0 |
| OBJ-01 | `maybe_deserialize/1` returns `%ActiveEntitlementSummary{}` for the **no-`id`** summary, and `refute Map.has_key?(result, :id)` | unit | same | ✅ file, case ❌ W0 |
| OBJ-01 | `maybe_deserialize/1` returns `%MeterEvent{event_name: ...}` — **not** asserted on `.object` | unit | same | ✅ file, case ❌ W0 |
| OBJ-01 | `maybe_deserialize/1` returns `%MeterEventSummary{}` incl. float `aggregated_value` | unit | same | ✅ file, case ❌ W0 |
| OBJ-01 | `fetch_module/1` returns `{:ok, Module}` for each of the four keys | unit (structural) | same | ✅ file, case ❌ W0 |
| OBJ-01 | **`billing.meter_error_report` absent** — `refute Map.has_key?(object_map(), ...)` | unit (structural) | same | ✅ **already exists & green** — `object_types_test.exs:217-227`; **verify, do not re-author** |
| OBJ-01 | The error-report `data` payload round-trips unchanged through `maybe_deserialize/1` | unit | same | ✅ **already exists & green** — `:181-191` |
| OBJ-01 | No `webhook/fetch_test.exs` case regresses from the new `fetch_module/1` rows | unit (regression) | `mix test test/lattice_stripe/webhook/` | ✅ file exists |
| OBJ-02 | `Testing.Fixtures.Entitlements.{active_entitlement_json,active_entitlement_summary_json,feature_json,active_entitlement_list_json}` are public and return maps | unit | `mix test test/lattice_stripe/testing_test.exs` | ✅ file, case ❌ W0 |
| OBJ-02 | Meter fixtures public (shape per Q1) and return maps | unit | same | ✅ file, case ❌ W0 |
| OBJ-02 | Typed wrappers in `LatticeStripe.Testing` return the right struct for each new fixture | unit | same (`describe "typed wrappers"`, `:244`) | ✅ file, case ❌ W0 |
| OBJ-02 | The **no-`id` summary** wrapper produces a struct with no `:id` | unit (structural) | same | ✅ file, case ❌ W0 |
| OBJ-02 | The 4 entitlement + 9 metering caller test files still compile and pass after the rename | regression | `mix test` | ✅ all exist |
| OBJ-03 | `Testing.Fixtures.{Customer,Subscription,Invoice,PaymentIntent}` public, return maps, and convert to typed structs | unit | `mix test test/lattice_stripe/testing_test.exs` | ✅ file, case ❌ W0 |
| OBJ-03 | `invoice_test.exs`'s existing ~19 assertions still pass against the promoted fixture | regression | `mix test test/lattice_stripe/invoice_test.exs` | ✅ file exists |
| OBJ-01/02/03 | Every new public module is in `groups_for_modules[:Testing]` (ExDoc silently drops ungrouped modules) | unit (config) | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ file exists (precedent at `:535-538`, `:599-604`), case ❌ W0 |
| OBJ-02/03 | `guides/testing.md`'s public-fixture bullet list names each new module | unit (docs-truth) | same | ✅ file, case ❌ W0 |
| all | Promoted fixtures compile outside `:test` | build | `MIX_ENV=prod mix compile` | n/a — **not covered by CI**, add to a `<verify>` block |
| all | Hex tarball builds with the enlarged `lib/` | build | `mix hex.build` | ✅ CI Quality lane `ci.yml:257` |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/testing_test.exs` — sub-second.
- **Per wave merge:** `mix test` — full suite, ~5s, floor 2305. Never skip.
- **Phase gate:** the differential gate below, all five steps green, before `/gsd-verify-work`.
- **Max feedback latency:** ~5 seconds.

### ⚠ `mix ci` is NOT this phase's gate

`mix ci`'s final step is `docs --warnings-as-errors`, which is **RED at clean HEAD** on 38
pre-existing warnings (Tax.* nested types, `File.create/3`, `../README.md`, hidden `ObjectTypes` /
`BillingPortal.Guards` / `Webhook.check_tolerance`). Steps 1–4 pass. Clearing them is Phase
67-shaped. Use the differential gate:

### Phase gate (five differential steps)

1. `mix format --check-formatted && mix compile --warnings-as-errors` — green
2. `mix credo --strict` — green
3. `mix test` — green, count **≥ 2305** (never fewer). *A single failure in
   `client_test.exs:912` or `batch_test.exs:72` is a known flake — re-run once before treating it
   as a regression.*
4. `mix docs` exits 0 **and** warning count **≤ 38** (never up). Measure with
   `mix docs 2>&1 | grep -c 'warning:'`.
5. **Zero** `mix docs` warnings matching the substring `entitlement`, `meter`, `testing`, or
   `fixture` — currently **0** for all four, verified this session. Unconditional; if one appears,
   fix it at its cause. **Do not rescope the substring list to make the step pass** — Phase 63
   (STATE `[63-07]`) and Phase 64 (D-29) both settled that rescoping a gate is the same move as
   raising a baseline.

Additionally, once per phase (not per wave): `MIX_ENV=prod mix compile` and `mix hex.build`,
both because fixtures crossing into `lib/` change what ships.

### Not in the gate

`mix test --only integration` (needs stripe-mock) — **Phase 65 requires no integration tests**;
every assertion is a pure decode or a structural/config check.

### Wave 0 Gaps

No new test *files* are required — every target file already exists. Wave 0 is therefore
**cases, not files**:

- [ ] `test/lattice_stripe/object_types_test.exs` — 5 new cases (4 positive dispatch + 1
      `fetch_module/1` group). **Also update its `alias` at line 5** if Q1 moves the metering fixtures.
- [ ] `test/lattice_stripe/testing_test.exs` — extend `describe "public fixture builders"` (`:22`)
      and `describe "typed wrappers"` (`:244`); update the `alias LatticeStripe.{...}` block at `:4-17`.
- [ ] `test/lattice_stripe/docs_truth_test.exs` — a new ExDoc `groups_for_modules[:Testing]`
      placement assertion + a `guides/testing.md` prose assertion.
- [ ] **Framework install:** none — ExUnit is stdlib and already configured.

---

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json`, so this section is
included. **Phase 65 has a near-empty threat surface**: it adds no network call, no input parsing,
no credential handling, and no new dependency.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface touched; `Client` credential handling is untouched. |
| V3 Session Management | no | Stateless library. |
| V4 Access Control | no | No authorization decision is made or changed. |
| V5 Input Validation | **partially** | `maybe_deserialize/1` accepts untrusted webhook JSON. The four new rows widen which payloads get *typed* — but `from_map/1` is total (all four have a `when is_map(map)` clause and a `nil` clause), performs no atom creation from input, and routes unknown keys to `:extra` (or drops them, for `MeterEvent`). **No atom-exhaustion vector**: no `String.to_atom/1` anywhere on this path. Verified: Phase 64 D-18 explicitly decided against atomizing error codes. |
| V6 Cryptography | no | Webhook HMAC verification (`Plug.Crypto.secure_compare/2`) is untouched. |
| V7 Error Handling & Logging | **watch** | `MeterEvent` ships a custom `defimpl Inspect` that **hides `:payload`** because it carries the customer-mapping key and metered value (`meter_event.ex:116-146`). Registering `billing.meter_event` means `maybe_deserialize/1` can now return this struct into adopter logs — the existing masking is exactly right and **must not be removed**. Add a regression assertion if convenient. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation | Status in Phase 65 |
|---------|--------|---------------------|--------------------|
| Atom exhaustion from attacker-controlled JSON keys | DoS | Never `String.to_atom/1` on input; use `Map.split/2` with a string allowlist | **Already mitigated** — all four modules use `@known_fields` string allowlists (or, for `MeterEvent`, explicit `map["key"]` reads) |
| Sensitive data leaking into logs / crash dumps | Information Disclosure | Custom `Inspect` allowlist | **Already mitigated** for `MeterEvent`; preserve it |
| Registry row enabling an unintended outbound HTTP request | SSRF-adjacent | The URL comes from Stripe's own signed `related_object.url`, never from user input; `fetch_module/1` gates it | **Accepted** — see Pitfall 1; behavior change is intentional and documented |
| Test fixtures containing real secrets shipped to hex.pm | Information Disclosure | Fixtures use obviously-fake ids (`cus_test…`, `whsec_test…`, `tok_test_abc`) | **Verify during promotion** — audit each promoted fixture for anything resembling a live key before it enters `lib/` and therefore the Hex tarball. `MeterEventStreamSession.basic/1` contains `"authentication_token" => "tok_test_abc"` — clearly fake, but this is exactly the class of value to re-check. |

**One concrete security action for the planner:** before any fixture file moves into `lib/`, grep
it for `sk_live`, `pk_live`, `whsec_`, `rk_live`, and `acct_1` and confirm every value is
synthetic. This is cheap and the promotion is the last moment it is free.

---

## Sources

### Primary (HIGH confidence — direct source reads and executed commands in this worktree)

- `lib/lattice_stripe/object_types.ex` (whole file) — `@object_map`, `fetch_module/1`, `maybe_deserialize/1`
- `lib/lattice_stripe/webhook.ex:370-456` — the `fetch_related_object/3` gate
- `lib/lattice_stripe/entitlements/{active_entitlement,active_entitlement_summary,feature}.ex`
- `lib/lattice_stripe/billing/{meter_event,meter_event_summary,meter_error_report}.ex`
- `lib/lattice_stripe/testing.ex` (whole file) — the typed-wrapper surface
- `lib/lattice_stripe/testing/fixtures.ex`, `.../fixtures/{dispute,tax_id}.ex`
- `test/support/fixtures/{entitlements,metering,customer,subscription,payment_intent,dispute}.ex`
- `test/lattice_stripe/object_types_test.exs` (whole file) — the existing `refute` lock at `:217-227`
- `test/lattice_stripe/testing_test.exs`, `test/lattice_stripe/docs_truth_test.exs:95-148,520-604`
- `test/lattice_stripe/invoice_test.exs:1-72` — the private invoice fixture
- `lib/lattice_stripe/drift.ex:16-42,192-235` — the `@known_fields` source scrape
- `mix.exs` (whole file) — `elixirc_paths/1`, `package/0` `files:`, `groups_for_modules`, `ci` alias
- `.credo.exs:18-40,100-133`, `.formatter.exs`, `.github/workflows/ci.yml`
- **Executed:** `mix test` → 2305 / 0 failures / 1 skipped / 214 excluded, 5.1s
- **Executed:** `mix docs` → exit 0, 38 warnings, 0 matching `entitlement|meter|testing|fixture`
- **Executed:** `MIX_ENV=test mix run` probe — all four `from_map/1` verified against real fixtures
- **Executed:** `grep` caller enumeration for all five `Test.Fixtures.*` modules

### Secondary (HIGH confidence — prior-phase planning artifacts written from verified research)

- `.planning/phases/64-meter-event-summary-reads/64-CONTEXT.md` — F-13 (`:49`), D-14 (`:145`), `:335`
- `.planning/phases/64-meter-event-summary-reads/64-VALIDATION.md` — the D-29 five-step gate template
- `.planning/phases/63-stripe-native-entitlements/63-05-SUMMARY.md:111-118,142` — the D-27 promotion handoff
- `.planning/phases/63-stripe-native-entitlements/63-PATTERNS.md`, `64-PATTERNS.md` — codebase idioms
- `.planning/STATE.md` — carry-forward (baseline 38, flakes, `mix ci` red, `object_types.ex` untouched)
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `./CLAUDE.md`

### Tertiary (LOW confidence — none used)

No web search was performed. Every wire-format question was answerable from in-repo artifacts that
prior phases verified against Stripe's live documentation and OpenAPI spec. The two residual
wire-string assumptions are recorded as A1/A2 in the Assumptions Log.

---

## Metadata

**Confidence breakdown:**

- **Standard stack — HIGH.** Zero new dependencies; every tool verified present and executed.
- **Architecture — HIGH.** The registry, the dispatch, the fixture surface, and the promotion
  mechanics were all read directly and, where behavioral, executed.
- **Target module readiness — HIGH.** All four `from_map/1` implementations were run against real
  fixtures this session and returned correct typed structs, including the no-`id` case.
- **Pitfalls — HIGH** for 1, 3, 4, 5, 6, 7, 8 (each traced to a specific file:line or an executed
  command); **MEDIUM** for 2 (the drift consequence is inferred from reading `drift.ex`'s regex and
  `meter_event.ex`'s absent attribute — not reproduced, since `check_drift` needs network).
- **OBJ-03 scope — MEDIUM.** The `invoice` gap is verified (no fixture module exists), but whether
  to move vs. duplicate the other three is an unresolved decision (Q2).
- **Wire-string exactness — MEDIUM.** Sourced from prior-phase research and module defaults rather
  than re-verified against Stripe today (A1/A2).

**Research date:** 2026-07-28
**Valid until:** 2026-08-27 (30 days — the codebase facts are stable; the only volatile input is
Stripe's object-string catalog, and A1/A2 record that exposure). **Invalidate immediately** if any
other phase touches `lib/lattice_stripe/object_types.ex`, `lib/lattice_stripe/testing/`, or the
`mix.exs` `groups_for_modules[:Testing]` list.
