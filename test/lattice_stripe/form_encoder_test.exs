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
end
