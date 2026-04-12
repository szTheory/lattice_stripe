defmodule LatticeStripe.FormEncoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias LatticeStripe.FormEncoder

  describe "encode/1" do
    test "flat params: encodes a simple map with URL-encoded values" do
      result = FormEncoder.encode(%{email: "j@example.com"})
      assert result == "email=j%40example.com"
    end

    test "nested map: encodes with bracket notation" do
      result = FormEncoder.encode(%{metadata: %{plan: "pro"}})
      assert result == "metadata[plan]=pro"
    end

    test "array of maps: encodes with indices" do
      result = FormEncoder.encode(%{items: [%{price: "price_123", quantity: 1}]})
      # Both keys should appear with indexed bracket notation
      assert result =~ "items[0][price]=price_123"
      assert result =~ "items[0][quantity]=1"
    end

    test "deep nesting (3+ levels): encodes correctly" do
      result = FormEncoder.encode(%{a: %{b: %{c: "d"}}})
      assert result == "a[b][c]=d"
    end

    test "boolean values: encode as literal true/false strings" do
      result = FormEncoder.encode(%{active: true})
      assert result == "active=true"

      result_false = FormEncoder.encode(%{active: false})
      assert result_false == "active=false"
    end

    test "nil values are omitted: nil keys do not appear in output" do
      result = FormEncoder.encode(%{name: "Jo", nickname: nil})
      assert result == "name=Jo"
      refute result =~ "nickname"
    end

    test "empty map: returns empty string" do
      result = FormEncoder.encode(%{})
      assert result == ""
    end

    test "integer values: encode correctly" do
      result = FormEncoder.encode(%{amount: 2000})
      assert result == "amount=2000"
    end

    test "atom keys converted to strings" do
      result = FormEncoder.encode(%{currency: :usd})
      assert result == "currency=usd"
    end

    test "multiple top-level params sorted alphabetically" do
      result = FormEncoder.encode(%{b: "2", a: "1"})
      assert result == "a=1&b=2"
    end

    test "special characters URL-encoded" do
      result = FormEncoder.encode(%{desc: "a b&c"})
      # URI.encode_www_form encodes spaces as +
      assert result == "desc=a+b%26c"
    end

    test "empty string value preserved: Stripe uses empty string to clear values" do
      result = FormEncoder.encode(%{coupon: ""})
      assert result == "coupon="
    end

    test "array of scalars: encodes with indices" do
      result = FormEncoder.encode(%{expand: ["data.customer", "data.charge"]})
      assert result == "expand[0]=data.customer&expand[1]=data.charge"
    end

    test "mixed nested: array of maps with multiple keys sorts keys correctly" do
      result =
        FormEncoder.encode(%{
          items: [%{price: "price_123", quantity: 2}, %{price: "price_456", quantity: 1}]
        })

      assert result =~ "items[0][price]=price_123"
      assert result =~ "items[0][quantity]=2"
      assert result =~ "items[1][price]=price_456"
      assert result =~ "items[1][quantity]=1"
    end
  end

  describe "encode/1 edge cases" do
    test "empty list value: encodes to empty string (no key emitted)" do
      # An empty array has no elements to flatten, so nothing is emitted
      result = FormEncoder.encode(%{items: []})
      assert result == ""
    end

    test "empty nested map value: omitted (no keys emitted)" do
      # An empty map has no key-value pairs, so nothing is emitted
      result = FormEncoder.encode(%{metadata: %{}})
      assert result == ""
    end

    test "mixed string and atom keys: both encode correctly" do
      result = FormEncoder.encode(%{"string_key" => "val1", atom_key: "val2"})
      assert result =~ "string_key=val1"
      assert result =~ "atom_key=val2"
    end

    test "unicode values with accented characters: URL-encoded correctly" do
      # é is a multibyte UTF-8 character and must be percent-encoded
      result = FormEncoder.encode(%{name: "René"})
      assert result =~ "name="
      # URI.encode_www_form encodes é as %C3%A9
      assert result =~ "%C3%A9"
    end

    test "unicode values with CJK characters: URL-encoded correctly" do
      result = FormEncoder.encode(%{name: "東京"})
      assert result =~ "name="
      # Verify non-ASCII bytes are percent-encoded
      refute result =~ "東京"
    end

    test "value containing equals sign: equals must be encoded" do
      result = FormEncoder.encode(%{query: "a=b"})
      # URI.encode_www_form encodes = as %3D
      assert result == "query=a%3Db"
    end

    test "value containing ampersand in nested context: ampersand must be encoded" do
      result = FormEncoder.encode(%{metadata: %{note: "a&b"}})
      # URI.encode_www_form encodes & as %26
      assert result == "metadata[note]=a%26b"
    end

    test "deeply nested (4+ levels): produces correct bracket notation" do
      result = FormEncoder.encode(%{a: %{b: %{c: %{d: "deep"}}}})
      assert result == "a[b][c][d]=deep"
    end

    test "array of empty maps: produces empty string (no keys emitted)" do
      result = FormEncoder.encode(%{items: [%{}, %{}]})
      assert result == ""
    end

    test "nil in array: nil element is skipped (omitted from output)" do
      # flatten_value/2 for nil returns [] so nil array elements are skipped
      result = FormEncoder.encode(%{items: ["a", nil, "b"]})
      assert result =~ "items[0]=a"
      assert result =~ "items[2]=b"
      # nil at index 1 is omitted — no items[1] key
      refute result =~ "items[1]"
    end

    test "integer zero encodes as '0' string" do
      result = FormEncoder.encode(%{amount: 0})
      assert result == "amount=0"
    end

    test "negative integer encodes as negative string" do
      result = FormEncoder.encode(%{adjustment: -500})
      assert result == "adjustment=-500"
    end
  end

  describe "encode/1 — float handling (D-09f)" do
    test "small float: does not emit scientific notation" do
      assert FormEncoder.encode(%{"x" => 0.00001}) == "x=0.00001"
    end

    test "very small float: stays compact decimal" do
      result = FormEncoder.encode(%{"x" => 1.0e-20})
      refute result =~ "e-"
      refute result =~ "E-"
    end

    test "normal float: 12.5 encodes as 12.5" do
      assert FormEncoder.encode(%{"x" => 12.5}) == "x=12.5"
    end

    test "zero float: 0.0 encodes as 0.0" do
      assert FormEncoder.encode(%{"x" => 0.0}) == "x=0.0"
    end

    test "negative float: -1.5 encodes as -1.5" do
      assert FormEncoder.encode(%{"x" => -1.5}) == "x=-1.5"
    end

    test "percent_off fractional (Coupon case)" do
      assert FormEncoder.encode(%{"percent_off" => 12.5}) == "percent_off=12.5"
    end
  end

  describe "encode/1 — D-09a triple-nested inline shapes" do
    test "items[0][price_data][recurring][interval] round-trips" do
      result =
        FormEncoder.encode(%{
          "items" => [
            %{
              "price_data" => %{
                "currency" => "usd",
                "unit_amount" => 2000,
                "product_data" => %{"name" => "T-shirt"},
                "recurring" => %{
                  "interval" => "month",
                  "interval_count" => 3,
                  "usage_type" => "licensed"
                },
                "tax_behavior" => "exclusive"
              }
            }
          ]
        })

      assert result =~ "items[0][price_data][currency]=usd"
      assert result =~ "items[0][price_data][unit_amount]=2000"
      assert result =~ "items[0][price_data][product_data][name]=T-shirt"
      assert result =~ "items[0][price_data][recurring][interval]=month"
      assert result =~ "items[0][price_data][recurring][interval_count]=3"
      assert result =~ "items[0][price_data][recurring][usage_type]=licensed"
      assert result =~ "items[0][price_data][tax_behavior]=exclusive"
    end
  end

  describe "encode/1 — D-09a quadruple-nested transform_quantity" do
    test "items[0][price_data][transform_quantity][divide_by] round-trips" do
      result =
        FormEncoder.encode(%{
          "items" => [
            %{
              "price_data" => %{
                "transform_quantity" => %{"divide_by" => 10, "round" => "up"}
              }
            }
          ]
        })

      assert result =~ "items[0][price_data][transform_quantity][divide_by]=10"
      assert result =~ "items[0][price_data][transform_quantity][round]=up"
    end
  end

  describe "encode/1 — D-09a arrays of scalars inside nested maps" do
    test "tax_rates under items[] and expand top-level" do
      result =
        FormEncoder.encode(%{
          "items" => [%{"tax_rates" => ["txr_123", "txr_456"]}],
          "expand" => ["data.customer", "data.default_payment_method"]
        })

      assert result =~ "items[0][tax_rates][0]=txr_123"
      assert result =~ "items[0][tax_rates][1]=txr_456"
      assert result =~ "expand[0]=data.customer"
      assert result =~ "expand[1]=data.default_payment_method"
    end
  end

  describe "encode/1 — D-09a multiple items with mixed shapes" do
    test "items[0]=existing price, items[1]=inline price_data" do
      result =
        FormEncoder.encode(%{
          "items" => [
            %{"price" => "price_existing"},
            %{"price_data" => %{"currency" => "usd", "recurring" => %{"interval" => "year"}}}
          ]
        })

      assert result =~ "items[0][price]=price_existing"
      assert result =~ "items[1][price_data][currency]=usd"
      assert result =~ "items[1][price_data][recurring][interval]=year"
    end
  end

  describe "encode/1 — D-09a Coupon custom ID at top level (D-07)" do
    test "id=SUMMER25 flows through" do
      result =
        FormEncoder.encode(%{"id" => "SUMMER25", "percent_off" => 25, "duration" => "once"})

      assert result =~ "id=SUMMER25"
      assert result =~ "percent_off=25"
      assert result =~ "duration=once"
    end
  end

  describe "encode/1 — D-09a Price tier lists" do
    test "tiers with flat_amount and up_to=inf" do
      result =
        FormEncoder.encode(%{
          "tiers" => [
            %{"up_to" => 100, "flat_amount" => 1000},
            %{"up_to" => "inf", "unit_amount" => 500}
          ]
        })

      assert result =~ "tiers[0][up_to]=100"
      assert result =~ "tiers[0][flat_amount]=1000"
      assert result =~ "tiers[1][up_to]=inf"
      assert result =~ "tiers[1][unit_amount]=500"
    end
  end

  describe "encode/1 — D-09a Coupon applies_to products array" do
    test "applies_to[products][0], [1] encode correctly" do
      result =
        FormEncoder.encode(%{
          "applies_to" => %{"products" => ["prod_abc", "prod_def"]}
        })

      assert result =~ "applies_to[products][0]=prod_abc"
      assert result =~ "applies_to[products][1]=prod_def"
    end
  end

  describe "encode/1 — D-09a Connect account nested booleans" do
    test "account[controller][application][loss_liable]=true" do
      result =
        FormEncoder.encode(%{
          "account" => %{
            "controller" => %{
              "application" => %{"loss_liable" => true},
              "stripe_dashboard" => %{"type" => "express"}
            }
          }
        })

      assert result =~ "account[controller][application][loss_liable]=true"
      assert result =~ "account[controller][stripe_dashboard][type]=express"
    end
  end

  describe "encode/1 — D-09c metadata special characters" do
    test "hyphen in metadata key URL-encodes (brackets NOT double-encoded)" do
      result = FormEncoder.encode(%{"metadata" => %{"user-id" => "usr_abc"}})
      assert result =~ "metadata[user-id]=usr_abc"
    end

    test "slash in metadata key encodes as %2F in the key segment" do
      result = FormEncoder.encode(%{"metadata" => %{"tenant/plan" => "gold"}})
      # URI.encode_www_form encodes / as %2F
      assert result =~ "metadata[tenant%2Fplan]=gold"
    end

    test "space in metadata key encodes as + (URI.encode_www_form)" do
      result = FormEncoder.encode(%{"metadata" => %{"hello world" => "value"}})
      assert result =~ "metadata[hello+world]=value"
    end

    test "brackets are never double-encoded" do
      result = FormEncoder.encode(%{"metadata" => %{"user-id" => "x"}})
      refute result =~ "%5B"
      refute result =~ "%5D"
    end
  end

  describe "encode/1 — D-09d empty-string vs nil" do
    test "nil value omits field entirely" do
      result = FormEncoder.encode(%{"name" => nil, "email" => "u@x.com"})
      refute result =~ "name"
      assert result =~ "email=u%40x.com"
    end

    test "empty string preserves key= (Stripe clear-field)" do
      result = FormEncoder.encode(%{"name" => ""})
      assert result == "name="
    end
  end

  describe "encode/1 — D-09e atom value round-trip" do
    test "atom :month and string \"month\" encode identically" do
      atom_version = FormEncoder.encode(%{"recurring" => %{"interval" => :month}})
      string_version = FormEncoder.encode(%{"recurring" => %{"interval" => "month"}})
      assert atom_version == string_version
      assert atom_version == "recurring[interval]=month"
    end

    test "atom :inf and string \"inf\" for tiers up_to" do
      atom_version = FormEncoder.encode(%{"tiers" => [%{"up_to" => :inf}]})
      string_version = FormEncoder.encode(%{"tiers" => [%{"up_to" => "inf"}]})
      assert atom_version == string_version
    end
  end

  describe "encode/1 — D-09a sort determinism and coercion" do
    test "same input produces identical output bytes" do
      input = %{"b" => 2, "a" => 1, "c" => %{"z" => "z", "y" => "y"}}
      assert FormEncoder.encode(input) == FormEncoder.encode(input)
    end

    test "keys are alphabetically sorted" do
      result = FormEncoder.encode(%{"z" => 1, "a" => 2, "m" => 3})
      assert result == "a=2&m=3&z=1"
    end

    test "integer, boolean, string coercion" do
      result = FormEncoder.encode(%{"active" => true, "unit_amount" => 2000})
      assert result =~ "active=true"
      assert result =~ "unit_amount=2000"
    end
  end

  describe "encode/1 — D-09b StreamData property layer" do
    defp nested_param_map_gen do
      scalar_gen =
        StreamData.one_of([
          StreamData.string(:alphanumeric, min_length: 1, max_length: 8),
          StreamData.integer(),
          StreamData.boolean()
        ])

      key_gen = StreamData.string(:alphanumeric, min_length: 1, max_length: 6)

      StreamData.tree(scalar_gen, fn leaf ->
        StreamData.one_of([
          StreamData.map_of(key_gen, leaf, max_length: 4),
          StreamData.list_of(leaf, max_length: 4)
        ])
      end)
      |> StreamData.map(fn value ->
        case value do
          m when is_map(m) -> m
          other -> %{"root" => other}
        end
      end)
    end

    property "nil values are never emitted in encoded output" do
      check all(map <- nested_param_map_gen(), max_runs: 200) do
        encoded = FormEncoder.encode(map)
        refute encoded =~ "=nil"
      end
    end

    property "output is deterministic across repeated calls" do
      check all(map <- nested_param_map_gen(), max_runs: 200) do
        assert FormEncoder.encode(map) == FormEncoder.encode(map)
      end
    end

    property "output is URL-decodable via URI.decode_query" do
      check all(map <- nested_param_map_gen(), max_runs: 200) do
        encoded = FormEncoder.encode(map)

        if encoded != "" do
          # Must not raise
          URI.decode_query(encoded)
        end
      end
    end

    property "no duplicate keys in encoded output" do
      check all(map <- nested_param_map_gen(), max_runs: 200) do
        encoded = FormEncoder.encode(map)

        if encoded != "" do
          keys =
            encoded
            |> String.split("&")
            |> Enum.map(&(String.split(&1, "=") |> hd()))

          assert length(keys) == length(Enum.uniq(keys))
        end
      end
    end
  end
end
