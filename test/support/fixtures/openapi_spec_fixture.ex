defmodule LatticeStripe.Test.Fixtures.OpenApiSpec do
  @moduledoc false

  @doc """
  Returns a minimal OpenAPI spec3.json-shaped map for deterministic drift tests.

  Contains:
  - "customer" schema: has "new_spec_only_field" not in @known_fields (tests additions)
  - "invoice" schema: has additions + omits some @known_fields fields (tests both)
  - "tax_calculation" schema: object enum is "tax.calculation" (tests schema name != object type)
  - "unregistered_resource" schema: not in ObjectTypes registry (tests new resource detection)
  - "coupon_applies_to" schema: no "object" enum (non-first-class, should be filtered out)
  """
  def minimal_spec do
    %{
      "components" => %{
        "schemas" => %{
          # First-class: customer with a field not in @known_fields
          "customer" => %{
            "properties" => %{
              "id" => %{"type" => "string"},
              "object" => %{"enum" => ["customer"], "type" => "string"},
              "email" => %{"type" => "string"},
              "name" => %{"type" => "string"},
              "new_spec_only_field" => %{"type" => "string"}
            }
          },
          # First-class: invoice with additions and omissions vs @known_fields
          # In spec: id, object, amount_due, new_invoice_field
          # Omits many @known_fields fields (they become removals)
          "invoice" => %{
            "properties" => %{
              "id" => %{"type" => "string"},
              "object" => %{"enum" => ["invoice"], "type" => "string"},
              "amount_due" => %{"type" => "integer"},
              "new_invoice_field" => %{"type" => "object"},
              "nested_ref_field" => %{"$ref" => "#/components/schemas/invoice_settings"}
            }
          },
          # First-class: schema name differs from object type enum value
          # schema key = "tax_calculation", object type = "tax.calculation"
          "tax_calculation" => %{
            "properties" => %{
              "id" => %{"type" => "string"},
              "object" => %{"enum" => ["tax.calculation"], "type" => "string"},
              "currency" => %{"type" => "string"},
              "customer" => %{"type" => "string"}
            }
          },
          # Non-first-class: no "object" property with single-element enum
          # Should be filtered out by resource_schemas/1
          "coupon_applies_to" => %{
            "properties" => %{
              "products" => %{"type" => "array"}
            }
          },
          # Non-first-class: multi-element enum — should be filtered out
          "multi_enum_resource" => %{
            "properties" => %{
              "id" => %{"type" => "string"},
              "object" => %{"enum" => ["type_a", "type_b"], "type" => "string"}
            }
          }
        }
      }
    }
  end
end
