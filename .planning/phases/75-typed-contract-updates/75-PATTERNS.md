# Phase 75: Typed Contract Updates - Pattern Map

**Mapped:** 2026-09-23  
**Status:** Conditional only. Phase 74 selected no field, and research found neither exact inventory membership nor immutable GA schema paths. This is an analog map, not an implementation file list. Apply a row only after D-01 qualifies that property; if none qualifies, no source, test, fixture, or adopter documentation file below should change.

## File Classification

| Conditional file | Role | Data flow | Closest tracked analog | Match |
|---|---|---|---|---|
| `lib/lattice_stripe/invoice.ex` | model, decoder | response transform | same file, lines 75-95 and 923-1013 | exact |
| `lib/lattice_stripe/refund.ex` | model, decoder | response transform | same file, lines 68-115 and 363-386 | exact |
| `lib/lattice_stripe/dispute.ex` and possibly `lib/lattice_stripe/dispute/payment_method_details.ex` | model, nested decoder | response transform | same files, lines 37-91, 219-242; nested lines 1-34 | exact |
| `lib/lattice_stripe/invoice_item.ex` | model, decoder | response transform | same file, lines 57-110 and 335-367 | exact |
| `lib/lattice_stripe/subscription.ex` | model, decoder | response transform | same file, lines 69-81, 138-172, 447-500 | exact |
| Matching `test/lattice_stripe/{invoice,refund,dispute,invoice_item,subscription}_test.exs` | test | response transform | same resource test file | exact |
| Matching `lib/lattice_stripe/testing/fixtures/{invoice,dispute,subscription}.ex`, if fixture changes are needed | test fixture | data transform | same fixture file | exact |
| `CHANGELOG.md` | documentation | release information | same file, lines 1-34 | exact |
| `guides/invoices.md` or `guides/subscriptions.md`, only for a material adopter job | documentation | adopter task | same guide | exact |

Refund and InvoiceItem fixture builders are used in their resource tests; their exact owning location should be retained after selection. No fixture file should be created solely to document hypothetical fields.

## Pattern Assignments

### Existing resource module (model, response transform)

**Use the selected resource's own module.** Invoice provides the general pattern (`lib/lattice_stripe/invoice.ex:75-95,188-196,923-936`):

```elixir
@known_fields ~w[
  id object account_country account_name account_tax_ids amount_due amount_paid
  amount_remaining amount_shipping application application_fee_amount attempt_count
]

@type t :: %__MODULE__{
  id: String.t() | nil,
  amount_paid: integer() | nil,
  amount_remaining: integer() | nil
}

def from_map(nil), do: nil

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{
    id: known["id"],
    amount_paid: known["amount_paid"],
    amount_remaining: known["amount_remaining"],
    # existing fields continue here
    extra: extra
  }
end
```

The excerpt condenses nonadjacent source lines to show the four places to edit together: known keys, struct field, typespec, and decoder assignment. It is structural guidance, not a copyable replacement for the full function. In Refund, `charge: ObjectTypes.maybe_deserialize(known["charge"])` at `lib/lattice_stripe/refund.ex:369` and `charge: LatticeStripe.Charge.t() | String.t() | nil` at line 108 are the expandable reference pattern. Use it only if the qualified property is expandable in the exact schema. For a simple property, copy the neighboring `known["..."]` pass-through pattern. Existing `extra: extra` at line 386 preserves unrelated keys.

### Nested Dispute property (model, nested response transform)

**Analog:** `lib/lattice_stripe/dispute.ex:221-242` delegates to `PaymentMethodDetails.from_map/1`; `lib/lattice_stripe/dispute/payment_method_details.ex:1-34` keeps `card` as `map() | nil` and retains unknown keys in `extra`.

```elixir
payment_method_details: PaymentMethodDetails.from_map(known["payment_method_details"])

@known_fields ~w[type card klarna paypal amazon_pay]
@type t :: %__MODULE__{type: String.t() | nil, card: map() | nil, extra: map()}

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
  struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
end
```

The candidate `payment_method_details.card.network` is inside a raw `card` map. Promoting this nested property would require a specific public-shape decision and compatibility review; the existing top-level `@known_fields` pattern alone cannot make it a typed nested field. Do not infer a new nested module from this pattern map.

### Invoice and Subscription payment settings (model, map pass-through)

**Analogs:** `lib/lattice_stripe/invoice.ex:243,983`; `lib/lattice_stripe/subscription.ex:172,486`.

```elixir
payment_settings: map() | nil,
payment_settings: known["payment_settings"],
```

The field is already represented as a raw map in both resources. A nested `payment_method_types` lead therefore needs separate evidence of adopter value and public-shape analysis before any typed nested representation is planned. Preserve existing map behavior if that decision is not made.

### Resource tests (test, response transform)

**Analog:** `test/lattice_stripe/refund_test.exs:356-418` has a focused `describe "from_map/1"` group. It tests known values, unknown keys in `extra`, missing/default behavior, unknown status values, and string, expanded, and nil forms of `charge`. The direct pattern is:

```elixir
test "unknown fields go to extra map" do
  map = refund_json(%{"unknown_field" => "some_value", "another_unknown" => 42})
  refund = Refund.from_map(map)
  assert refund.extra == %{"unknown_field" => "some_value", "another_unknown" => 42}
end

test "charge field: deserializes to %Charge{} when expanded" do
  expanded = %{"object" => "charge", "id" => "ch_123", "amount" => 2000}
  refund = Refund.from_map(refund_json(%{"charge" => expanded}))
  assert %LatticeStripe.Charge{id: "ch_123"} = refund.charge
end
```

Use only shape cases supported by the selected field's pinned schema. `test/lattice_stripe/invoice_test.exs:189-230`, `test/lattice_stripe/invoice_item_test.exs:78-120`, `test/lattice_stripe/dispute_test.exs:154-227`, and `test/lattice_stripe/subscription_test.exs:87-137` are the corresponding resource-specific precedents. Add an adjacent source comment or fixture note stating whether each payload is captured or schema-derived, plus API version, immutable GA snapshot identity, and exact property path. Decoder tests prove local mapping, not that Stripe emitted the payload.

### Adopter documentation (documentation, adopter task)

**Analogs:** module `@moduledoc` and `@typedoc` in the selected resource (`lib/lattice_stripe/refund.ex:1-61,98-103`); `CHANGELOG.md:1-34`; `guides/invoices.md:1-25` and `guides/subscriptions.md` when a real job needs a walkthrough. State the field's meaning, minimum API version, and only proven response/event surfaces. Keep the guide focused on the adopter task; do not put source provenance mechanics in the task flow. Use a concise source note in developer-facing field docs or the evidence record.

## Shared Patterns

### Decoder and forward compatibility

`Map.split(map, @known_fields)` separates deliberate typed fields from future Stripe keys; `extra: extra` retains the latter. See `lib/lattice_stripe/invoice.ex:925-926,1013`, `lib/lattice_stripe/refund.ex:363-386`, and matching ExUnit assertions above. Only known, compile-time field atoms are added. Existing enum helpers pass unfamiliar strings through; see `test/lattice_stripe/dispute_test.exs:185-204` and `test/lattice_stripe/refund_test.exs:395-402`.

### Public API compatibility

`guides/api_stability.md:14-24,37-40` says adding an optional public struct field is additive, while changing a field's type or value representation is breaking. `test/lattice_stripe/api_surface_lock_test.exs` and `priv/api/current.txt` provide the public surface review seam. A qualified field addition should update the lock through the established project workflow and make that diff reviewable.

### No applicable auth or request errors

This phase's conditional files decode already received response maps. They do not introduce authentication, transport, request validation, Phoenix/Plug routing, Ecto persistence, or a new error response. If evidence shows any of those changes are needed, return to scope and compatibility planning.

## No Analog Found

| Conditional need | Reason |
|---|---|
| Evidence ledger with exact inventory membership and immutable GA schema property paths | No current artifact meets both gates. Phase 74 triage and Phase 75 research are decision records, not a qualifying source artifact. |
| A typed model specifically for `Dispute.payment_method_details.card` or nested payment settings | Current public fields are maps. Creating a nested model is a new compatibility decision, not an existing pattern to copy automatically. |

## Metadata

**Analog search scope:** `lib/lattice_stripe`, `lib/lattice_stripe/testing/fixtures`, `test/lattice_stripe`, `guides`, `CHANGELOG.md`, `priv/api`.  
**Tracked-source gate:** Every source analog named above was checked with `git ls-files`; no ignored runtime mirror is used.  
**Candidate status:** zero fields selected; all file assignments are conditional.  
**Extraction date:** 2026-09-23.
