defmodule LatticeStripe.Testing.WrapperCompletenessTest do
  @moduledoc """
  OBJ-02 forcing function: "each fixture with a typed-conversion wrapper".

  The POPULATION is derived at runtime from the shipped
  `LatticeStripe.Testing.Fixtures.*` surface, so a new public fixture cannot be added
  without this test noticing. The CLASSIFICATION is explicit: every derived object type
  must appear in exactly one of `@wrapped` or `@unwrapped`, and every builder that emits
  no top-level `"object"` key must appear in `@objectless`. There is no default and no
  fallthrough — adding a fixture for a new Stripe object fails here until someone writes
  down which bucket it is in.

  Deriving the wrapper NAME is deliberately not attempted: `tax.calculation` maps to
  `tax_calculation/1` (namespace kept) while `billing.meter_event` maps to `meter_event/1`
  (namespace stripped), so no rule reproduces the shipped surface. What IS derived is the
  set that must be classified — which is the property that actually drifted in Phase 65,
  where 4 of 6 wrappers shipped and the gap was invisible.

  Every opt-out reason is itself machine-checked. `COVERAGE.md` shipped the claim that
  `MeterErrorReport` had no `from_map/1` to wrap while
  `LatticeStripe.Billing.MeterErrorReport.from_map/1` existed the whole time. A prose
  rationale that nothing verifies is exactly how that happens.
  """
  use ExUnit.Case, async: true

  alias LatticeStripe.Testing

  # `function_exported?/3` answers false for a module that merely has not been loaded
  # yet, which would turn every wrapper assertion below into a false failure.
  setup_all do
    Code.ensure_loaded!(Testing)
    :ok
  end

  @fixture_prefix "Elixir.LatticeStripe.Testing.Fixtures."

  # ── Object types that MUST have a typed wrapper ─────────────────────────────────
  # {stripe "object" string, LatticeStripe.Testing wrapper fun, expected struct module}
  @wrapped [
    {"billing.meter_event", :meter_event, LatticeStripe.Billing.MeterEvent},
    {"billing.meter_event_summary", :meter_event_summary,
     LatticeStripe.Billing.MeterEventSummary},
    {"credit_note", :credit_note, LatticeStripe.CreditNote},
    {"customer", :customer, LatticeStripe.Customer},
    {"dispute", :dispute, LatticeStripe.Dispute},
    {"entitlements.active_entitlement", :active_entitlement,
     LatticeStripe.Entitlements.ActiveEntitlement},
    {"entitlements.active_entitlement_summary", :active_entitlement_summary,
     LatticeStripe.Entitlements.ActiveEntitlementSummary},
    {"entitlements.feature", :feature, LatticeStripe.Entitlements.Feature},
    {"file", :file, LatticeStripe.File},
    {"file_link", :file_link, LatticeStripe.FileLink},
    {"invoice", :invoice, LatticeStripe.Invoice},
    {"mandate", :mandate, LatticeStripe.Mandate},
    {"payment_intent", :payment_intent, LatticeStripe.PaymentIntent},
    {"quote", :quote, LatticeStripe.Quote},
    {"setup_attempt", :setup_attempt, LatticeStripe.SetupAttempt},
    {"subscription", :subscription, LatticeStripe.Subscription},
    {"tax.calculation", :tax_calculation, LatticeStripe.Tax.Calculation},
    {"tax.transaction", :tax_transaction, LatticeStripe.Tax.Transaction},
    {"tax_id", :tax_id, LatticeStripe.TaxId}
  ]

  # ── Object types deliberately WITHOUT a wrapper ─────────────────────────────────
  # Each reason atom is MACHINE-CHECKED below:
  #   :sub_object -- reachable through its parent's wrapper; MUST still have from_map/1
  #   :envelope   -- a list/event wrapper, not a resource; MUST have no resource module
  #   :no_from_map-- there is genuinely nothing to wrap; asserted with refute
  @unwrapped [
    {"credit_note_line_item", :sub_object, LatticeStripe.CreditNote.LineItem},
    {"quote_line_item", :sub_object, LatticeStripe.Quote.LineItem},
    {"tax.calculation_line_item", :sub_object, LatticeStripe.Tax.Calculation.LineItem},
    {"tax.transaction_line_item", :sub_object, LatticeStripe.Tax.Transaction.LineItem},
    # Stripe list envelope. Decoded by each resource's list path, never by a from_map wrapper.
    {"list", :envelope, nil},
    # A v2 event ENVELOPE, not a resource. Decoded by Webhook.parse_event_notification/4
    # or Billing.MeterErrorReport.from_event/1 — never by a from_map wrapper.
    {"v2.core.event", :envelope, nil}
  ]

  # ── Builders with NO top-level "object" key ─────────────────────────────────────
  # Invisible to the derivation above, so they are named explicitly. The ABSENCE of the
  # "object" key is itself asserted, so if Stripe ever adds one this fires and the builder
  # rejoins the derived population.
  #   {fixture module, arity-0 builder, :wrapped | :fragment, wrapper fun, struct module}
  @objectless [
    # `data` carries no "object", so this wrapper cannot use object-type dispatch.
    {LatticeStripe.Testing.Fixtures.MeterErrorReport, :meter_error_report_json, :wrapped,
     :meter_error_report, LatticeStripe.Billing.MeterErrorReport},
    # Embedded fragments of a parent payload — never decoded standalone.
    {LatticeStripe.Testing.Fixtures.Dispute, :dispute_evidence_json, :fragment, nil, nil},
    {LatticeStripe.Testing.Fixtures.Dispute, :dispute_evidence_details_json, :fragment, nil, nil},
    {LatticeStripe.Testing.Fixtures.Mandate, :mandate_customer_acceptance_json, :fragment, nil,
     nil},
    {LatticeStripe.Testing.Fixtures.Mandate, :mandate_single_use_json, :fragment, nil, nil},
    {LatticeStripe.Testing.Fixtures.SetupAttempt, :setup_attempt_setup_error_json, :fragment, nil,
     nil}
  ]

  defp fixture_modules do
    :lattice_stripe
    |> Application.spec(:modules)
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), @fixture_prefix))
    |> Enum.sort()
  end

  # Every arity-0-callable public builder that returns a map. Builders are defined as
  # `def x(overrides \\ %{})`, so the arity-0 head always exists. The is_map/1 guard
  # drops non-builders such as MeterErrorReport.meter_id/0.
  defp builder_maps do
    for mod <- fixture_modules(),
        {fun, 0} <- mod.__info__(:functions),
        result = apply(mod, fun, []),
        is_map(result),
        do: {mod, fun, result}
  end

  # Top-level "object" values only — nested envelopes are not part of the contract.
  defp declared_object_types do
    builder_maps()
    |> Enum.flat_map(fn {_mod, _fun, map} ->
      case Map.get(map, "object") do
        t when is_binary(t) -> [t]
        _ -> []
      end
    end)
    |> MapSet.new()
  end

  defp objectless_builders do
    builder_maps()
    |> Enum.reject(fn {_mod, _fun, map} -> is_binary(Map.get(map, "object")) end)
    |> Enum.map(fn {mod, fun, _map} -> {mod, fun} end)
    |> MapSet.new()
  end

  describe "OBJ-02 completeness invariant" do
    test "every fixture object type is classified as wrapped or deliberately unwrapped" do
      wrapped = MapSet.new(@wrapped, fn {t, _, _} -> t end)
      unwrapped = MapSet.new(@unwrapped, fn {t, _, _} -> t end)

      assert MapSet.size(MapSet.intersection(wrapped, unwrapped)) == 0,
             "An object type is in BOTH lists: " <>
               inspect(Enum.sort(MapSet.intersection(wrapped, unwrapped)))

      unclassified =
        MapSet.difference(declared_object_types(), MapSet.union(wrapped, unwrapped))

      assert MapSet.size(unclassified) == 0, """
      New public fixture object type(s) with no typed-wrapper decision:

        #{unclassified |> Enum.sort() |> Enum.map_join("\n  ", &inspect/1)}

      Add each to @wrapped (with its LatticeStripe.Testing wrapper) or to @unwrapped
      (with a machine-checked reason atom) in this file. There is no default — OBJ-02
      says "each with a typed-conversion wrapper", and silence is how 4-of-6 shipped
      in Phase 65.
      """
    end

    test "no stale classification survives a fixture removal" do
      wrapped = MapSet.new(@wrapped, fn {t, _, _} -> t end)
      unwrapped = MapSet.new(@unwrapped, fn {t, _, _} -> t end)
      stale = MapSet.difference(MapSet.union(wrapped, unwrapped), declared_object_types())

      assert MapSet.size(stale) == 0,
             "Classified object types no longer produced by any public fixture: " <>
               inspect(Enum.sort(stale)) <> " — delete the rows."
    end

    test "every objectless builder is classified, and none is missing from @objectless" do
      classified = MapSet.new(@objectless, fn {m, f, _, _, _} -> {m, f} end)
      actual = objectless_builders()

      unclassified = MapSet.difference(actual, classified)

      assert MapSet.size(unclassified) == 0, """
      Public fixture builder(s) emitting no top-level "object" key and not classified:

        #{unclassified |> Enum.sort() |> Enum.map_join("\n  ", fn {m, f} -> "#{inspect(m)}.#{f}/0" end)}

      Add each to @objectless as :wrapped (it decodes to a struct via a Testing wrapper)
      or :fragment (it is an embedded piece of a parent payload, never decoded standalone).
      """

      stale = MapSet.difference(classified, actual)

      assert MapSet.size(stale) == 0,
             "@objectless rows that now emit an \"object\" key or no longer exist: " <>
               inspect(Enum.sort(Enum.map(stale, fn {m, f} -> "#{inspect(m)}.#{f}/0" end)))
    end

    for {object_type, wrapper, struct_mod} <- @wrapped do
      test "#{object_type} has a working LatticeStripe.Testing.#{wrapper}/1 wrapper" do
        assert function_exported?(Testing, unquote(wrapper), 1),
               "OBJ-02: #{unquote(object_type)} is classified @wrapped but " <>
                 "LatticeStripe.Testing.#{unquote(wrapper)}/1 does not exist."

        Code.ensure_loaded!(unquote(struct_mod))

        assert function_exported?(unquote(struct_mod), :from_map, 1),
               "#{inspect(unquote(struct_mod))}.from_map/1 is missing — the wrapper " <>
                 "cannot delegate to it."
      end
    end

    for {object_type, reason, resource_mod} <- @unwrapped do
      test "#{object_type} opt-out reason #{reason} is factually true" do
        case unquote(reason) do
          :no_from_map ->
            # The exact false claim COVERAGE.md:44 made about MeterErrorReport.
            # Now unfalsifiable.
            Code.ensure_loaded!(unquote(resource_mod))

            refute function_exported?(unquote(resource_mod), :from_map, 1),
                   "#{unquote(object_type)} is opted out as :no_from_map but " <>
                     "#{inspect(unquote(resource_mod))}.from_map/1 EXISTS. Either move it " <>
                     "to @wrapped or correct the reason."

          :sub_object ->
            # A sub-object is reachable through its parent's wrapper; it may still have
            # from_map/1, which is why the reason must be :sub_object and not :no_from_map.
            Code.ensure_loaded!(unquote(resource_mod))

            assert function_exported?(unquote(resource_mod), :from_map, 1),
                   "#{unquote(object_type)} is opted out as :sub_object, which asserts the " <>
                     "parent decodes it — but #{inspect(unquote(resource_mod))}.from_map/1 " <>
                     "does not exist. The correct reason is probably :no_from_map."

          :envelope ->
            assert unquote(resource_mod) == nil,
                   "#{unquote(object_type)} is opted out as :envelope, which asserts there " <>
                     "is no resource module to wrap — but one was named."
        end
      end
    end

    # Split by kind at COMPILE time rather than branching on `kind` at runtime: a runtime
    # `case` would emit the :fragment branch into the :wrapped row's body, where
    # `wrapper == nil` is an always-false comparison that Elixir 1.19 reports as a typing
    # violation — and CI compiles with --warnings-as-errors.
    for {fixture_mod, builder, :wrapped, wrapper, struct_mod} <-
          Enum.filter(@objectless, &(elem(&1, 2) == :wrapped)) do
      test "#{inspect(fixture_mod)}.#{builder}/0 has no \"object\" key and is wrapped" do
        raw = apply(unquote(fixture_mod), unquote(builder), [])

        refute Map.has_key?(raw, "object"),
               "This fixture gained a top-level \"object\" key — remove it from @objectless " <>
                 "and let the derivation classify it instead."

        assert function_exported?(Testing, unquote(wrapper), 1),
               "LatticeStripe.Testing.#{unquote(wrapper)}/1 does not exist."

        decoded = apply(Testing, unquote(wrapper), [raw])

        assert decoded.__struct__ == unquote(struct_mod),
               "LatticeStripe.Testing.#{unquote(wrapper)}/1 returned " <>
                 "#{inspect(decoded.__struct__)}, expected #{inspect(unquote(struct_mod))}."
      end
    end

    for {fixture_mod, builder, :fragment, _wrapper, _struct_mod} <-
          Enum.filter(@objectless, &(elem(&1, 2) == :fragment)) do
      test "#{inspect(fixture_mod)}.#{builder}/0 is an embedded fragment with no object key" do
        raw = apply(unquote(fixture_mod), unquote(builder), [])

        refute Map.has_key?(raw, "object"),
               "This fixture gained a top-level \"object\" key — remove it from @objectless " <>
                 "and let the derivation classify it instead."

        # A fragment has no standalone decode path by definition. Asserting the absence of
        # a same-named wrapper is what keeps :fragment from becoming a dumping ground for
        # objects that simply have not been wrapped yet.
        refute function_exported?(Testing, unquote(builder), 1),
               "#{unquote(builder)} is classified :fragment but a LatticeStripe.Testing " <>
                 "wrapper of that name exists — reclassify it as :wrapped."
      end
    end
  end
end
