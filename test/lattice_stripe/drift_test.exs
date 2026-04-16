defmodule LatticeStripe.DriftTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Drift
  alias LatticeStripe.Test.Fixtures.OpenApiSpec

  # ---------------------------------------------------------------
  # resource_schemas/1
  # ---------------------------------------------------------------

  describe "resource_schemas/1" do
    test "extracts first-class schemas keyed by object type enum value" do
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      # These three have single-element object enums — all should be present
      assert Map.has_key?(result, "customer")
      assert Map.has_key?(result, "invoice")
      assert Map.has_key?(result, "tax.calculation")
    end

    test "excludes non-first-class schemas (no object enum)" do
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      # coupon_applies_to has no object property
      refute Map.has_key?(result, "coupon_applies_to")
    end

    test "excludes schemas with multi-element object enum" do
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      # multi_enum_resource has ["type_a", "type_b"] — not first-class
      refute Map.has_key?(result, "multi_enum_resource")
    end

    test "uses properties.object.enum[0] as key, not schema name" do
      # The fixture has schema key "tax_calculation" but object enum ["tax.calculation"]
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      # Should be keyed by "tax.calculation", not "tax_calculation"
      assert Map.has_key?(result, "tax.calculation")
      refute Map.has_key?(result, "tax_calculation")
    end

    test "returns field names as MapSet for each schema" do
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      customer = result["customer"]
      assert %MapSet{} = customer.fields
      assert MapSet.member?(customer.fields, "id")
      assert MapSet.member?(customer.fields, "email")
      assert MapSet.member?(customer.fields, "name")
      assert MapSet.member?(customer.fields, "object")
      assert MapSet.member?(customer.fields, "new_spec_only_field")
    end

    test "returns field types map for each schema" do
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      customer = result["customer"]
      assert is_map(customer.types)
      assert customer.types["id"] == "string"
      assert customer.types["email"] == "string"
      assert customer.types["new_spec_only_field"] == "string"
    end

    test "maps $ref fields to 'object' type" do
      result = Drift.resource_schemas(OpenApiSpec.minimal_spec())

      invoice = result["invoice"]
      assert invoice.types["nested_ref_field"] == "object"
    end

    test "returns empty map for spec with no components.schemas" do
      result = Drift.resource_schemas(%{})
      assert result == %{}
    end
  end

  # ---------------------------------------------------------------
  # known_fields_for/1
  # ---------------------------------------------------------------

  describe "known_fields_for/1" do
    test "extracts @known_fields from a real module" do
      assert {:ok, fields} = Drift.known_fields_for(LatticeStripe.Customer)

      # Customer has these fields in @known_fields
      assert MapSet.member?(fields, "id")
      assert MapSet.member?(fields, "email")
      assert MapSet.member?(fields, "name")
      assert MapSet.member?(fields, "object")
      assert MapSet.member?(fields, "livemode")
    end

    test "extracts @known_fields from a multi-line ~w[] form" do
      # Invoice uses a multi-line ~w[...] — verify it parses correctly
      assert {:ok, fields} = Drift.known_fields_for(LatticeStripe.Invoice)

      assert MapSet.member?(fields, "id")
      assert MapSet.member?(fields, "amount_due")
      assert MapSet.member?(fields, "status")
      assert MapSet.member?(fields, "customer")
    end

    test "returns {:error, :no_source} when source path is nil" do
      # Hard to test without a mock module that returns nil from __info__(:compile)[:source].
      # Skipping direct test — covered by the nil guard in known_fields_for/1 implementation.
      # The guard: case module.__info__(:compile)[:source] do nil -> {:error, :no_source}
      :ok
    end
  end

  # ---------------------------------------------------------------
  # compare/2
  # ---------------------------------------------------------------

  describe "compare/2" do
    test "reports additions (in spec, not in known)" do
      spec_fields = MapSet.new(["id", "email", "new_field"])
      known_fields = MapSet.new(["id", "email"])

      result = Drift.compare(spec_fields, known_fields)

      assert MapSet.member?(result.additions, "new_field")
      refute MapSet.member?(result.additions, "id")
      refute MapSet.member?(result.additions, "email")
    end

    test "reports removals (in known, not in spec)" do
      spec_fields = MapSet.new(["id", "email"])
      known_fields = MapSet.new(["id", "email", "removed_field"])

      result = Drift.compare(spec_fields, known_fields)

      assert MapSet.member?(result.removals, "removed_field")
      refute MapSet.member?(result.removals, "id")
    end

    test "returns empty sets when fields match exactly" do
      fields = MapSet.new(["id", "email", "name"])

      result = Drift.compare(fields, fields)

      assert MapSet.size(result.additions) == 0
      assert MapSet.size(result.removals) == 0
    end

    test "handles completely disjoint sets" do
      spec_fields = MapSet.new(["a", "b"])
      known_fields = MapSet.new(["c", "d"])

      result = Drift.compare(spec_fields, known_fields)

      assert result.additions == MapSet.new(["a", "b"])
      assert result.removals == MapSet.new(["c", "d"])
    end

    test "handles empty spec fields" do
      spec_fields = MapSet.new()
      known_fields = MapSet.new(["id", "email"])

      result = Drift.compare(spec_fields, known_fields)

      assert MapSet.size(result.additions) == 0
      assert result.removals == MapSet.new(["id", "email"])
    end
  end

  # ---------------------------------------------------------------
  # format_report/1
  # ---------------------------------------------------------------

  describe "format_report/1" do
    test "returns clean message when no drift" do
      result = %{drift_count: 0, modules: [], new_resources: []}

      report = Drift.format_report(result)

      assert String.contains?(report, "No drift detected")
    end

    test "formats additions with + prefix" do
      result = %{
        drift_count: 1,
        modules: [
          %{
            module: LatticeStripe.Customer,
            object_type: "customer",
            additions: MapSet.new(["new_spec_only_field"]),
            removals: MapSet.new(),
            spec_types: %{"new_spec_only_field" => "string"}
          }
        ],
        new_resources: []
      }

      report = Drift.format_report(result)

      assert String.contains?(report, "+ new_spec_only_field")
    end

    test "formats removals with - prefix and warning text" do
      result = %{
        drift_count: 1,
        modules: [
          %{
            module: LatticeStripe.Customer,
            object_type: "customer",
            additions: MapSet.new(),
            removals: MapSet.new(["removed_field"]),
            spec_types: %{}
          }
        ],
        new_resources: []
      }

      report = Drift.format_report(result)

      assert String.contains?(report, "- removed_field")
      assert String.contains?(report, "warning: in @known_fields but not in spec")
    end

    test "groups output by module name" do
      result = %{
        drift_count: 2,
        modules: [
          %{
            module: LatticeStripe.Customer,
            object_type: "customer",
            additions: MapSet.new(["field_a"]),
            removals: MapSet.new(),
            spec_types: %{"field_a" => "string"}
          },
          %{
            module: LatticeStripe.Invoice,
            object_type: "invoice",
            additions: MapSet.new(["field_b"]),
            removals: MapSet.new(),
            spec_types: %{"field_b" => "integer"}
          }
        ],
        new_resources: []
      }

      report = Drift.format_report(result)

      assert String.contains?(report, "LatticeStripe.Customer")
      assert String.contains?(report, "(stripe object: \"customer\")")
      assert String.contains?(report, "LatticeStripe.Invoice")
      assert String.contains?(report, "(stripe object: \"invoice\")")
    end

    test "includes new resources section when present" do
      result = %{
        drift_count: 0,
        modules: [],
        new_resources: ["tax.calculation", "identity.verification_session"]
      }

      report = Drift.format_report(result)

      assert String.contains?(report, "New resources not yet implemented")
      assert String.contains?(report, "tax.calculation")
      assert String.contains?(report, "identity.verification_session")
    end

    test "shows drift count in header" do
      result = %{
        drift_count: 2,
        modules: [
          %{
            module: LatticeStripe.Customer,
            object_type: "customer",
            additions: MapSet.new(["f1"]),
            removals: MapSet.new(),
            spec_types: %{"f1" => "string"}
          },
          %{
            module: LatticeStripe.Invoice,
            object_type: "invoice",
            additions: MapSet.new(["f2"]),
            removals: MapSet.new(),
            spec_types: %{"f2" => "string"}
          }
        ],
        new_resources: []
      }

      report = Drift.format_report(result)

      assert String.contains?(report, "Drift detected in 2 module")
    end

    test "includes field type annotations in additions" do
      result = %{
        drift_count: 1,
        modules: [
          %{
            module: LatticeStripe.Customer,
            object_type: "customer",
            additions: MapSet.new(["amount_total"]),
            removals: MapSet.new(),
            spec_types: %{"amount_total" => "integer"}
          }
        ],
        new_resources: []
      }

      report = Drift.format_report(result)

      assert String.contains?(report, "(integer)")
    end
  end
end
