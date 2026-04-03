defmodule LatticeStripe.ResourceTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Error, List, Resource, Response}

  # ---------------------------------------------------------------------------
  # unwrap_singular/2
  # ---------------------------------------------------------------------------

  describe "unwrap_singular/2" do
    test "returns {:ok, struct} when given {:ok, %Response{}} with map data" do
      data = %{"id" => "cus_123", "object" => "customer"}
      resp = %Response{status: 200, headers: [], data: data, request_id: "req_abc"}

      assert {:ok, %{id: "cus_123"}} =
               Resource.unwrap_singular({:ok, resp}, fn map -> %{id: map["id"]} end)
    end

    test "calls the from_map_fn with the response data" do
      data = %{"id" => "obj_xyz", "value" => 42}
      resp = %Response{status: 200, headers: [], data: data, request_id: nil}

      assert {:ok, %{id: "obj_xyz", value: 42}} =
               Resource.unwrap_singular({:ok, resp}, fn map ->
                 %{id: map["id"], value: map["value"]}
               end)
    end

    test "passes through {:error, %Error{}} unchanged" do
      error = %Error{type: :invalid_request_error, message: "bad request"}

      assert {:error, ^error} =
               Resource.unwrap_singular({:error, error}, fn _ -> :never_called end)
    end
  end

  # ---------------------------------------------------------------------------
  # unwrap_list/2
  # ---------------------------------------------------------------------------

  describe "unwrap_list/2" do
    test "returns {:ok, %Response{data: %List{data: typed_items}}} with typed items" do
      raw_items = [%{"id" => "obj_1"}, %{"id" => "obj_2"}]

      list = %List{
        data: raw_items,
        has_more: false,
        url: "/v1/objects",
        object: "list"
      }

      resp = %Response{status: 200, headers: [], data: list, request_id: "req_abc"}

      assert {:ok, %Response{data: %List{data: typed}}} =
               Resource.unwrap_list({:ok, resp}, fn map -> %{id: map["id"]} end)

      assert typed == [%{id: "obj_1"}, %{id: "obj_2"}]
    end

    test "maps each item through from_map_fn" do
      raw_items = [%{"id" => "x", "val" => 10}, %{"id" => "y", "val" => 20}]

      list = %List{data: raw_items, has_more: false, url: "/v1/test", object: "list"}
      resp = %Response{status: 200, headers: [], data: list, request_id: nil}

      assert {:ok, %Response{data: %List{data: [first, second]}}} =
               Resource.unwrap_list({:ok, resp}, fn map ->
                 %{id: map["id"], val: map["val"]}
               end)

      assert first == %{id: "x", val: 10}
      assert second == %{id: "y", val: 20}
    end

    test "passes through {:error, %Error{}} unchanged" do
      error = %Error{type: :api_error, message: "server error"}

      assert {:error, ^error} = Resource.unwrap_list({:error, error}, fn _ -> :never_called end)
    end
  end

  # ---------------------------------------------------------------------------
  # unwrap_bang!/1
  # ---------------------------------------------------------------------------

  describe "unwrap_bang!/1" do
    test "returns the inner value for {:ok, result}" do
      assert :my_result = Resource.unwrap_bang!({:ok, :my_result})
    end

    test "returns the struct for {:ok, %SomeStruct{}}" do
      resp = %Response{status: 200, data: %{"id" => "abc"}, headers: []}
      assert ^resp = Resource.unwrap_bang!({:ok, resp})
    end

    test "raises the error for {:error, %Error{}}" do
      error = %Error{type: :invalid_request_error, message: "missing required param"}

      assert_raise Error, fn ->
        Resource.unwrap_bang!({:error, error})
      end
    end

    test "raised error is the original error struct" do
      error = %Error{type: :card_error, message: "card declined", code: "card_declined"}

      raised =
        assert_raise Error, fn ->
          Resource.unwrap_bang!({:error, error})
        end

      assert raised.type == :card_error
      assert raised.code == "card_declined"
    end
  end

  # ---------------------------------------------------------------------------
  # require_param!/3
  # ---------------------------------------------------------------------------

  describe "require_param!/3" do
    test "returns :ok when key is present in params" do
      assert :ok = Resource.require_param!(%{"amount" => 2000}, "amount", "amount is required")
    end

    test "returns :ok when key maps to nil value (key exists)" do
      assert :ok = Resource.require_param!(%{"customer" => nil}, "customer", "customer required")
    end

    test "raises ArgumentError when key is missing" do
      assert_raise ArgumentError, "currency is required", fn ->
        Resource.require_param!(%{"amount" => 2000}, "currency", "currency is required")
      end
    end

    test "raises with the provided message" do
      msg = "You must provide an amount in the smallest currency unit"

      assert_raise ArgumentError, msg, fn ->
        Resource.require_param!(%{}, "amount", msg)
      end
    end
  end
end
