defmodule LatticeStripe.FormEncoderTest do
  use ExUnit.Case, async: true

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

    test "phases[].items[].price_data nested encoding (Phase 16 regression guard)" do
      # Phase 16 regression guard: SubscriptionSchedule update accepts deeply
      # nested params at phases[][items][][price_data][recurring][interval].
      # If the form encoder ever drops a level here, stripe-mock would reject
      # the request — but unit-level we want a fast feedback loop too.
      params = %{
        "phases" => [
          %{
            "items" => [
              %{
                "price_data" => %{
                  "currency" => "usd",
                  "recurring" => %{"interval" => "month"}
                }
              }
            ],
            "proration_behavior" => "create_prorations"
          }
        ]
      }

      result = FormEncoder.encode(params)

      assert result =~ "phases[0][items][0][price_data][currency]=usd"
      assert result =~ "phases[0][items][0][price_data][recurring][interval]=month"
      assert result =~ "phases[0][proration_behavior]=create_prorations"
    end
  end
end
