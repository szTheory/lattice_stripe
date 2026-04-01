defmodule LatticeStripe.JsonTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Json.Jason, as: JasonAdapter

  describe "LatticeStripe.Json.Jason.encode!/1" do
    test "encodes a map to valid JSON string" do
      result = JasonAdapter.encode!(%{id: "cus_123"})
      assert is_binary(result)
      assert result =~ "cus_123"
    end

    test "encodes nested maps correctly" do
      result = JasonAdapter.encode!(%{customer: %{id: "cus_123"}})
      assert is_binary(result)
      decoded = Jason.decode!(result)
      assert decoded["customer"]["id"] == "cus_123"
    end

    test "raises on non-encodable input like a PID" do
      assert_raise Protocol.UndefinedError, fn ->
        JasonAdapter.encode!(self())
      end
    end
  end

  describe "LatticeStripe.Json.Jason.decode!/1" do
    test "decodes a valid JSON string to a map" do
      result = JasonAdapter.decode!(~s({"id":"cus_123"}))
      assert result == %{"id" => "cus_123"}
    end

    test "decodes nested JSON correctly" do
      result = JasonAdapter.decode!(~s({"customer":{"id":"cus_123"}}))
      assert result == %{"customer" => %{"id" => "cus_123"}}
    end

    test "raises on invalid JSON string" do
      assert_raise Jason.DecodeError, fn ->
        JasonAdapter.decode!("not valid json {{{")
      end
    end
  end

  describe "LatticeStripe.Json behaviour" do
    test "Jason adapter implements all callbacks defined by the behaviour" do
      # Verify the module exports the behaviour callbacks
      behaviours = LatticeStripe.Json.Jason.module_info(:attributes)[:behaviour] || []
      assert LatticeStripe.Json in behaviours
    end

    test "a custom module implementing @behaviour LatticeStripe.Json can be used via Mox" do
      # The mock was defined in test_helper.exs
      # Verify the mock implements the behaviour interface
      Mox.expect(LatticeStripe.MockJson, :encode!, fn data ->
        Jason.encode!(data)
      end)

      result = LatticeStripe.MockJson.encode!(%{id: "cus_123"})
      assert result =~ "cus_123"

      Mox.verify!(LatticeStripe.MockJson)
    end

    test "behaviour callbacks are satisfied by MockJson" do
      Mox.expect(LatticeStripe.MockJson, :decode!, fn data ->
        Jason.decode!(data)
      end)

      result = LatticeStripe.MockJson.decode!(~s({"id":"cus_123"}))
      assert result == %{"id" => "cus_123"}

      Mox.verify!(LatticeStripe.MockJson)
    end
  end
end
