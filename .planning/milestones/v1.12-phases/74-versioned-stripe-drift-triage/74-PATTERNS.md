# Phase 74: Versioned Stripe Drift Triage - Pattern Map

**Mapped:** 2026-09-23  
**Files analyzed:** 1 planned artifact  
**Analogs found:** 5 / 1 artifact-level match

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/phases/74-versioned-stripe-drift-triage/74-TRIAGE.md` (recommended filename) | decision record / documentation | transform (drift leads + versioned evidence → disposition) | `lib/lattice_stripe/drift.ex`; `guides/api_stability.md` | exact content pattern |

No implementation files are in scope. The context excludes typed fields, resource families, API pin changes, generators, and validators. Produce one human-reviewable Markdown artifact; the filename remains discretionary.

## Pattern Assignments

### `74-TRIAGE.md` (decision record, transform)

**Analogs:** `lib/lattice_stripe/drift.ex`, `lib/mix/tasks/lattice_stripe.check_drift.ex`, and `guides/api_stability.md`.

**Evidence-first table pattern** (`lib/lattice_stripe/drift.ex:49-62`):

```elixir
## Drift summary (date)

| Category | Count |
|---|---:|
| Actionable field additions | count |
| Spec mismatch warnings | count |
| Unmodeled resources | count |

Triage: act on additions for adopter-used modules; defer shape noise.
```

Copy the compact table and explicit category/disposition style, but add the required provenance columns: complete resource/field path, dated source and API version, GA/preview status, current-pin or later-stable applicability, adopter job, semantic/type/decode rationale, disposition, and deferral reopen evidence. Keep raw drift output as a lead list only.

**Discovery/report separation** (`lib/mix/tasks/lattice_stripe.check_drift.ex:30-54`): `Drift.run/1` discovers and `emit_report/2` renders. Preserve that separation conceptually: qualify candidates from stable versioned Stripe sources and a GA OpenAPI snapshot; do not present `master` or runtime observations as release proof.

**Compatibility rationale** (`guides/api_stability.md:20-24,37-40,69-75`): optional fields are additive; unknown fields stay in `extra`; unknown enum-like values remain unchanged. Use this for each type/decode note and record that the default pin remains `2026-03-25.dahlia`.

## Shared Patterns

### Tolerant resource decoding

**Source:** `lib/lattice_stripe/subscription.ex:449-500` (tracked).

```elixir
{known, extra} = Map.split(map, @known_fields)
...
extra: extra
```

Selected optional fields preserve this behavior. Record full nested paths and do not infer event-payload applicability from an ordinary resource response.

### Open enum values

**Source:** `lib/lattice_stripe/subscription.ex:506-514` (tracked).

```elixir
defp atomize_status("active"), do: :active
defp atomize_status("paused"), do: :paused
defp atomize_status(other), do: other
```

Flag proposed enum fields as open unless Stripe provides a stability guarantee.

### Candidate source boundary

**Source:** `lib/lattice_stripe/drift.ex:11-18` (tracked).

```elixir
@spec_url "https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json"
with {:ok, spec} <- fetch_spec(), ...
```

Mark this discovery-only. Promoted rows need the exact dated changelog/reference and exact GA `/latest` snapshot identity. Preview and unconfirmed/schema-noise rows must not be promoted.

## Resource-Specific Analogs

| Candidate family | Analog | Relevant pattern |
|---|---|---|
| `Invoice.amount_paid_off_stripe` | `lib/lattice_stripe/invoice.ex:72-92` | top-level `@known_fields` is the recognized-field seam; integer money fields are optional struct fields |
| Refund customer/account/payment-method references | `lib/lattice_stripe/refund.ex:65-124` | object-or-ID response types and `extra` establish additive conventions |
| `Dispute.payment_method_details.card.network` | `lib/lattice_stripe/dispute/payment_method_details.ex:10-34` | nested `Map.split/2` preserves unknown keys in `extra` |

Tracked tests (`test/lattice_stripe/invoice_test.exs:17-31`, `test/lattice_stripe/refund_test.exs:1-10`, `test/lattice_stripe/dispute_test.exs:154-167`) show the later Phase 75 fixture → `from_map/1` → assertion shape; they are not Phase 74 deliverables.

## No Analog Found

No existing versioned source qualification or triage record exists. Use the research evidence-first row pattern; do not invent a generator, validator, score, or issue-per-field workflow.

## Metadata

**Analog search scope:** `.planning`, `lib/lattice_stripe`, `lib/mix/tasks`, `test/lattice_stripe`, `guides`  
**Tracked analog gate:** named source analogs verified with `git ls-files`  
**Pattern extraction date:** 2026-09-23
