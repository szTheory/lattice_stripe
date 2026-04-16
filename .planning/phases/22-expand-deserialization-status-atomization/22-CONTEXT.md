# Phase 22: Expand Deserialization & Status Atomization - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers who pass `expand:` options receive fully typed structs (not raw string IDs or raw maps) in response fields. Dot-path expand syntax works for nested list items via the same mechanism. Every resource module consistently auto-atomizes status-like and enum-like string fields.

This phase touches `from_map/1` in every resource module (84+), adds one new registry module, and updates typespecs. It does NOT add new Stripe resource modules, change the request pipeline, or modify Client/Transport/Request.

</domain>

<decisions>
## Implementation Decisions

### D-01: Central ObjectTypes Registry (Expand Dispatch)
A single `LatticeStripe.ObjectTypes` module with a compile-time `@object_map` mapping Stripe's `"object"` type strings to their LatticeStripe modules. Example: `"customer" => LatticeStripe.Customer`, `"billing_portal.session" => LatticeStripe.BillingPortal.Session`.

Called from a new `Expand.maybe_deserialize/1` helper that each resource's `from_map/1` delegates to for expandable fields.

**Rationale:** Mirrors battle-tested pattern from stripe-ruby (`ObjectTypes.object_names_to_classes`) and stripe-python (`_object_classes.py`). Naming-convention approach rejected because LatticeStripe's nested module paths (`BillingPortal.Session`) don't map cleanly to Stripe's dot-notation (`billing_portal.session`) without non-trivial parsing that is effectively a registry with extra steps.

**Footgun avoidance:** When registry has no match for an `"object"` value, preserve the raw map as-is (don't wrap in a generic struct). This keeps pattern-matching safe — callers always know what they're getting.

### D-02: Always Auto-Deserialize Expanded Fields (Type Safety)
In each resource's `from_map/1`, expandable fields use an `is_map(val)` guard to dispatch to the correct module's `from_map/1` via the ObjectTypes registry. If the field is a string ID, it's kept as-is.

```elixir
customer: if is_map(known["customer"]),
  do: Expand.maybe_deserialize(known["customer"]),
  else: known["customer"]
```

**Type specs become union types:** `customer: Customer.t() | String.t() | nil`. Since typespecs are documentation-only (no Dialyzer), this has zero runtime effect — only behavior changes.

**Semver rationale:** This is a minor bump (v1.2). Callers who pass `expand:` were already getting a raw `map()` back — the change is from `map()` → `%Customer{}`, which is strictly more useful. Callers who don't pass `expand:` see zero change (field is still a string ID).

**CHANGELOG migration note required:** Explain that expandable fields now return typed structs when expanded. Audit Accrue for string-pattern matches on expandable fields before release.

### D-03: Auto-Atomize All Status/Enum Fields (Atomization Strategy)
Private `defp atomize_status/1` (and `atomize_billing_reason/1`, `atomize_collection_method/1`, etc.) in each resource's `from_map/1`. Unknown values fall through as raw strings for forward-compatibility.

**Pattern (consistent with existing Invoice precedent):**
```elixir
defp atomize_status("succeeded"), do: :succeeded
defp atomize_status("processing"), do: :processing
defp atomize_status(other), do: other
```

**Scope of sweep:**
- **9 modules need status atomizers:** PaymentIntent, Subscription, SubscriptionSchedule, Payout, Refund, SetupIntent, Charge, BankAccount, BalanceTransaction
- **2 modules need consistency fix:** Capability and Meter should be updated to auto-atomize in `from_map/1`/`cast/1` (currently they only expose public `status_atom/1` without auto-converting). Deprecate or remove the public `status_atom/1`.
- **Non-status enum fields also swept:** `billing_reason`, `collection_method`, `cancellation_details.reason`, `type` on resources where Stripe documents a finite set of values. Invoice already atomizes `billing_reason` and `collection_method` — extend the same pattern.
- **Sweep stops at:** open-ended text fields (`description`, `currency`, `metadata` keys).

### D-04: Response-Driven Dot-Path Expand (No Parsing Needed)
Dot-path expand (`expand: ["data.customer"]`) works automatically because:
1. LatticeStripe already passes expand params through to Stripe as-is
2. Stripe expands the fields server-side and returns expanded objects in the response
3. The `is_map(val)` guard from D-02 detects the expanded map in `from_map/1`
4. The ObjectTypes registry from D-01 deserializes it

No client-side dot-path parsing. No context threading through List/pagination. Expand params are already preserved in `List._params` and re-sent on each paginated page — Stripe re-expands independently.

**Edge case:** `expand: ["customer"]` vs `expand: ["data.customer"]` — Stripe returns 400 for the wrong prefix on the wrong endpoint type. LatticeStripe does not need to guard against this; the error surfaces immediately from Stripe.

### Claude's Discretion
- Order of module sweep (which resource modules to update first)
- Whether to update all 84+ modules in one plan or split into batches
- Exact set of non-status enum fields to atomize (use Stripe docs as the source of truth for "finite documented values")
- Whether `Expand.maybe_deserialize/1` is a public or private function
- Test structure for the ObjectTypes registry (unit tests for registry + integration tests for end-to-end expand)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Expand Deserialization
- `.planning/research/SUMMARY.md` — Synthesized research findings including architecture integration points and pitfall warnings
- `.planning/research/ARCHITECTURE.md` — Integration point analysis: expand hooks into `from_map/1`, not Client pipeline
- `.planning/research/PITFALLS.md` — Pitfall #1: expand union types break downstream pattern matches silently
- `.planning/research/FEATURES.md` — Feature classification and competitor analysis (stripe-ruby, stripe-go expand patterns)

### Existing Patterns
- `lib/lattice_stripe/invoice.ex` — Reference implementation for auto-atomization (`atomize_status`, `atomize_billing_reason`, `atomize_collection_method`) and nested struct deserialization in `from_map/1`
- `lib/lattice_stripe/account/capability.ex` — Current public `status_atom/1` pattern (to be deprecated/updated)
- `lib/lattice_stripe/billing/meter.ex` — Current public `status_atom/1` pattern (to be deprecated/updated)
- `lib/lattice_stripe/payout.ex` — Only module that documents expandable fields explicitly; has `String.t() | map() | nil` type pattern
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2` and `unwrap_list/2` helpers that apply `from_map_fn`
- `lib/lattice_stripe/client.ex:458-467` — `merge_expand/2` showing how expand params are sent
- `lib/lattice_stripe/list.ex` — `_params` preservation for pagination; `stream!/2` implementation

### Project Constraints
- `guides/api_stability.md` — Semver contract; this change is a minor bump
- `.planning/PROJECT.md` — Core value, design philosophy, constraints

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Invoice's `atomize_*` pattern** — battle-tested private atomizer with string fallthrough; copy for 9 other modules
- **`Map.split/2` variant of `from_map/1`** — cleaner pattern (Invoice, Subscription) vs older `Map.drop` (Customer, PaymentIntent); prefer the newer variant when touching modules
- **`Resource.unwrap_singular/2` and `unwrap_list/2`** — already apply `from_map_fn` to response data; potential hook point for expand deserialization if a recursive walk is later desired (D-01 does not require this)

### Established Patterns
- **`@known_fields` + `extra`** — every module; forward-compatible deserialization
- **`from_map/1` with `when is_map(map)` guard** — entry point for deserialization; the natural place for D-02's `is_map` expand guard
- **Nested struct calls in `from_map/1`** — Invoice calls `AutomaticTax.from_map(...)`, `StatusTransitions.from_map(...)` etc. Same pattern for expand deserialization.

### Integration Points
- **New `LatticeStripe.ObjectTypes` module** — new file in `lib/lattice_stripe/object_types.ex`
- **New `LatticeStripe.Expand` helper** — new file in `lib/lattice_stripe/expand.ex` (or inline in ObjectTypes)
- **84+ resource modules** — each `from_map/1` touched for expand guards and/or atomizer additions
- **Typespec updates** — expandable field types change from `String.t() | nil` to `Module.t() | String.t() | nil`
- **CHANGELOG.md** — migration note for expand behavior change

</code_context>

<specifics>
## Specific Ideas

- The user wants all 4 decisions to be **coherent and mutually reinforcing**: ObjectTypes registry provides lookup, `is_map` guard provides dispatch, auto-atomize provides consistency, response-driven detection provides dot-path support — all localized to `from_map/1` changes.
- DX is the top priority — `payment_intent.customer` should be `%Customer{}` or `"cus_123"` depending on whether `expand:` was passed, with zero ceremony.
- Stripe-ruby and stripe-python's central registry pattern is the validated reference architecture.
- Capability's and Meter's existing public `status_atom/1` should be deprecated/updated for consistency with the auto-atomize pattern.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 22-expand-deserialization-status-atomization*
*Context gathered: 2026-04-16*
