---
phase: 23-billingportal-configuration-crudl
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/lattice_stripe/billing/meter.ex
  - lib/lattice_stripe/billing_portal/configuration.ex
  - lib/lattice_stripe/billing_portal/configuration/features.ex
  - lib/lattice_stripe/billing_portal/configuration/features/customer_update.ex
  - lib/lattice_stripe/billing_portal/configuration/features/payment_method_update.ex
  - lib/lattice_stripe/billing_portal/configuration/features/subscription_cancel.ex
  - lib/lattice_stripe/billing_portal/configuration/features/subscription_update.ex
  - lib/lattice_stripe/billing_portal/session.ex
  - lib/lattice_stripe/object_types.ex
  - mix.exs
  - test/integration/billing_portal_configuration_integration_test.exs
  - test/lattice_stripe/billing_portal/configuration/features/customer_update_test.exs
  - test/lattice_stripe/billing_portal/configuration/features/payment_method_update_test.exs
  - test/lattice_stripe/billing_portal/configuration/features/subscription_cancel_test.exs
  - test/lattice_stripe/billing_portal/configuration/features/subscription_update_test.exs
  - test/lattice_stripe/billing_portal/configuration/features_test.exs
  - test/lattice_stripe/billing_portal/configuration_test.exs
  - test/lattice_stripe/billing_portal/session_test.exs
  - test/support/fixtures/billing_portal.ex
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Phase 23 delivers the `BillingPortal.Configuration` CRUDL resource plus nested feature sub-structs (`CustomerUpdate`, `PaymentMethodUpdate`, `SubscriptionCancel`, `SubscriptionUpdate`). The implementation is consistent with existing SDK patterns — the `from_map/1` / `extra` pattern, bang variants, `Resource.unwrap_*` dispatchers, and the `stream!` auto-pagination helper all follow established conventions. Test coverage is thorough, including regression guards for the "Pitfall 1" extra-map misrouting bug.

Three warnings were found:

1. The `Session.from_map/1` does not use `@known_fields` for extracting known keys (it accesses the raw map directly and only uses `@known_fields` for `Map.drop/2` to populate `:extra`). This is an existing pre-phase pattern but is now more visible given the Configuration module was added as a known expandable field — if `"configuration"` is accidentally missing from `@known_fields`, the extra map will silently capture it.
2. The `Inspect` implementation builds the output string using `Atom.to_string(k)` with manual string construction instead of using `Inspect.Algebra` field-formatting helpers consistently, producing output that doesn't exactly follow `%Struct{field: val}` convention (uses `<>` delimiters instead of `{}`). This is an intentional deviation but worth documenting as a risk.
3. The integration test asserts `list_resp.data.data` (line 57) rather than the `Response` typed accessor, which will silently pass if the list unwrap shape changes.

---

## Warnings

### WR-01: `Session.from_map/1` accesses `"configuration"` outside `@known_fields` split

**File:** `lib/lattice_stripe/billing_portal/session.ex:233-251`

**Issue:** `Session.from_map/1` does not call `Map.split(map, @known_fields)` to separate known from unknown fields. Instead, it reads each field directly from the raw map and then computes `:extra` via `Map.drop(map, @known_fields)` at the end. This is internally consistent because every field in `@known_fields` (line 114) is also read explicitly in the struct literal — including `"configuration"` which was added in this phase.

However, the two lists (`@known_fields` and the struct literal field assignments) are maintained independently. If a field is added to the struct literal but forgotten in `@known_fields`, it will be read correctly _and_ will also leak into `:extra` (double-populated). If a field is added to `@known_fields` but not read in the struct literal, it will silently be dropped. Other modules in this codebase (`Configuration.from_map/1`, `Features.from_map/1`, etc.) all use `Map.split/2` to enforce a single source of truth. The inconsistency creates a maintenance foothole.

**Fix:** Align `Session.from_map/1` with the pattern used in every other `from_map/1` in this codebase — use `Map.split/2` first, then read from `known`:

```elixir
def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)

  %__MODULE__{
    id: known["id"],
    object: known["object"],
    customer: known["customer"],
    url: known["url"],
    return_url: known["return_url"],
    created: known["created"],
    livemode: known["livemode"],
    locale: known["locale"],
    configuration:
      (if is_map(known["configuration"]),
         do: ObjectTypes.maybe_deserialize(known["configuration"]),
         else: known["configuration"]),
    on_behalf_of: known["on_behalf_of"],
    flow: FlowData.from_map(known["flow"]),
    extra: extra
  }
end
```

This makes a future field addition atomic: add to `@known_fields` and add to the struct literal — no way to forget one half.

---

### WR-02: `Inspect` implementation produces non-standard delimiter output

**File:** `lib/lattice_stripe/billing_portal/session.ex:254-307`

**Issue:** The custom `Inspect` implementation uses `<` / `>` delimiters (`#LatticeStripe.BillingPortal.Session<...>`) instead of the standard Elixir struct notation `%LatticeStripe.BillingPortal.Session{...}`. The `Enum.intersperse/2` used to join key-value pairs inserts a plain `", "` separator string, but `Inspect.Algebra.concat/1` expects algebra documents — mixing plain strings and algebra docs is technically valid (`concat` accepts binaries), but the resulting algebra document is not formatted correctly under line-width constraints. If an `%opts.width` limit causes a line break, the output will not re-indent correctly.

Specifically, `Enum.intersperse(", ")` inserts a plain binary between algebra documents, but `concat(["prefix" | pairs] ++ [">"])` flattens this into a single non-breakable line. Standard Elixir `Inspect.Algebra` practice for struct-like output uses `container_doc/6` or `surround_many/6` (deprecated but widely used) to get proper break-on-width behavior.

This is an intentional choice (the `<>` delimiters signal "some fields are hidden") but the algebra tree will produce garbage under narrow terminal widths (e.g., `IEx.configure(inspect: [width: 40])`).

**Fix:** Use `container_doc/6` for proper width-aware formatting, or at minimum use `break/1` between pairs so the algebra engine can wrap:

```elixir
def inspect(session, opts) do
  fields = [
    id: session.id,
    object: session.object,
    # ... rest of fields
  ]

  doc =
    fields
    |> Enum.map(fn {k, v} ->
      concat([to_string(k), ": ", to_doc(v, opts)])
    end)
    |> Enum.intersperse(concat([",", break(" ")]))
    |> concat()

  concat(["#LatticeStripe.BillingPortal.Session<", doc, ">"])
end
```

---

### WR-03: Integration test accesses `list_resp.data.data` — fragile double-dereference

**File:** `test/integration/billing_portal_configuration_integration_test.exs:57`

**Issue:** The assertion `assert is_list(list_resp.data.data)` navigates two levels of `.data` to reach the actual items list. The outer `.data` accesses the `%Response{}` struct's `:data` field (which holds a `%LatticeStripe.List{}`), and the inner `.data` accesses the `%LatticeStripe.List{}` struct's `:data` field (which holds the actual item list). If `Response.data` or `List.data` field names change, this test will produce a confusing `KeyError` or `FunctionClauseError` rather than a meaningful assertion failure.

The same pattern also appears in `configuration_test.exs` at line 129 in the unit tests, where it is tested more precisely via a full pattern match. But the integration test only asserts `is_list/1`, which passes even if the nested structure is wrong (e.g., `is_list(nil)` returns false but `is_list([])` passes vacuously).

**Fix:** Use a pattern match in the integration test to be explicit about the structure:

```elixir
{:ok, list_resp} = Configuration.list(client)
assert %LatticeStripe.Response{
  data: %LatticeStripe.List{data: configs}
} = list_resp
assert is_list(configs)
```

---

## Info

### IN-01: `mix.exs` version is `1.1.0` but project is shipping v1.2 work

**File:** `mix.exs:4`

**Issue:** `@version "1.1.0"` has not been bumped to reflect Phase 23 (v1.2 work per memory notes). This is expected if version bumps are handled by release automation (Release Please), but worth noting in review for awareness.

**Fix:** No action needed if Release Please owns the bump. Confirm the CI release workflow will increment the version on merge.

---

### IN-02: `Configuration.from_map/1` missing `is_map` guard on `params` in `create/3`

**File:** `lib/lattice_stripe/billing_portal/configuration.ex:116`

**Issue:** `create/3` has a default parameter `params \\ %{}` but no `when is_map(params)` guard. `Meter.create/3` (line 92) and `Session.create/3` (line 200) both guard with `when is_map(params)`. Without the guard, passing a non-map (e.g., a keyword list) will raise a less informative error at the `%Request{}` struct construction or deeper in the transport layer rather than at the function head.

**Fix:**

```elixir
def create(%Client{} = client, params \\ %{}, opts \\ []) when is_map(params) do
```

---

### IN-03: `object_types.ex` — `"billing_portal.session"` registered but `Session.from_map/1` is the deserializer for an expand-able field already handled inline in `Session.from_map/1`

**File:** `lib/lattice_stripe/object_types.ex:33`

**Issue:** `"billing_portal.session"` is registered in `@object_map`. A `BillingPortal.Session` object is never embedded inside another object in expanded form in Stripe's API — sessions are top-level create-only resources. The registration is harmless but dead code. If Stripe ever returns a `billing_portal.session` map inside another resource and `ObjectTypes.maybe_deserialize/1` is called on it, it will dispatch to `Session.from_map/1` correctly, which is fine. This is a low-severity observation.

By contrast, `"billing_portal.configuration"` is correctly registered because it _is_ expandable in `Session` (the `"configuration"` field can be expanded to the full configuration object).

**Fix:** No immediate action required. Consider adding a comment explaining why `billing_portal.session` is registered if it is intentional, or remove it if it is dead code introduced speculatively.

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
