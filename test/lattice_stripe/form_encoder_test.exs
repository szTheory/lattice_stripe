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

  # These two describe blocks back published prose in `guides/metering.md`
  # ("The payload contract"). Each assertion below is a sentence the guide
  # states as fact. Breaking one of these tests does not merely change library
  # behavior — it makes a shipped, published sentence false. If you change the
  # encoder, update the guide in the same commit.

  describe "encode/1 payload contract (backs guides/metering.md)" do
    test "arbitrary custom dimension keys survive byte-exact — there is no allowlist" do
      # None of these dimension names share a prefix with "value", so a whitelist
      # anywhere between the caller and the wire would visibly drop them.
      result =
        FormEncoder.encode(%{
          "payload" => %{
            "region" => "us-west-2",
            "sku" => "gpu-a100",
            "tenant_tier" => "enterprise",
            "value" => "0.000001"
          }
        })

      assert result ==
               "payload[region]=us-west-2&payload[sku]=gpu-a100" <>
                 "&payload[tenant_tier]=enterprise&payload[value]=0.000001"
    end

    test "a decimal passed as a string survives to 36 significant digits, unrounded" do
      # The encoder stringifies; it never computes. No rounding, no truncation,
      # no tie-breaking of any kind is applied to a value that arrives as a binary.
      decimal = "0.123456789012345678901234567890123456"

      assert FormEncoder.encode(%{"payload" => %{"value" => decimal}}) ==
               "payload[value]=" <> decimal
    end

    test "an integer payload value encodes identically to its string form (v1 path)" do
      # guides/metering.md pitfall #4 claimed integers trigger
      # `meter_event_invalid_value`. That is false on the v1 form-encoded path —
      # the two bodies are byte-identical. The string rule is real but applies
      # only to the v2 JSON stream (meter_event_stream.ex).
      as_integer = FormEncoder.encode(%{"payload" => %{"value" => 5}})
      as_string = FormEncoder.encode(%{"payload" => %{"value" => "5"}})

      assert as_integer == as_string
      assert as_integer == "payload[value]=5"
    end

    test "a nil value is dropped entirely, not sent as an empty string" do
      # Consequence for callers: a zero must be sent as the string "0". There is
      # no way to express "send this key with no value" via nil.
      assert FormEncoder.encode(%{"a" => nil, "b" => "1"}) == "b=1"
    end

    test "encode/1 is pure — the same map twice yields identical output" do
      params = %{"payload" => %{"region" => "eu-central-1", "value" => "1.5"}}

      assert FormEncoder.encode(params) == FormEncoder.encode(params)
    end

    test "multi-byte UTF-8 in a dimension key and value reassembles after URI decoding" do
      key = "région_🌍"
      value = "café_東京"

      body = FormEncoder.encode(%{"payload" => %{key => value}})
      [encoded_key, encoded_value] = String.split(body, "=", parts: 2)

      inner_key =
        encoded_key |> String.trim_leading("payload[") |> String.trim_trailing("]")

      assert URI.decode_www_form(inner_key) == key
      assert URI.decode_www_form(encoded_value) == value
    end
  end

  describe "encode/1 float hazard (backs guides/metering.md)" do
    test "below the cliff: 0.0001 encodes in literal decimal form" do
      # Proves the threshold is exactly where the guide says it is.
      assert FormEncoder.encode(%{"v" => 0.0001}) == "v=0.0001"
    end

    test "at the cliff: 0.00001 encodes in exponent form as 1.0e-5" do
      # Elixir's `to_string/1` flips to scientific notation at 1.0e-5 — the
      # narrowest threshold in the ecosystem, and one decimal place away from
      # values people actually bill on (per-token costs). This assertion is the
      # lock that stops the guide's warning from silently becoming false.
      assert FormEncoder.encode(%{"v" => 0.00001}) == "v=1.0e-5"
    end

    test "a binary-float artifact reaches the wire unrepaired" do
      # Distinct from the decimal-string case above: that one says the encoder
      # never computes on strings; this one says it never repairs what float
      # arithmetic already did before the value arrived.
      assert FormEncoder.encode(%{"v" => 0.1 + 0.2}) == "v=0.30000000000000004"
    end
  end
end
