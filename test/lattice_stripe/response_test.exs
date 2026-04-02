defmodule LatticeStripe.ResponseTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{List, Response}

  describe "struct" do
    test "has correct default fields" do
      resp = %Response{}
      assert resp.data == nil
      assert resp.status == nil
      assert resp.headers == []
      assert resp.request_id == nil
    end

    test "can be constructed with values" do
      resp = %Response{
        data: %{"id" => "cus_123"},
        status: 200,
        request_id: "req_abc",
        headers: [{"content-type", "application/json"}]
      }

      assert resp.data == %{"id" => "cus_123"}
      assert resp.status == 200
      assert resp.request_id == "req_abc"
      assert resp.headers == [{"content-type", "application/json"}]
    end
  end

  describe "Access behaviour - fetch" do
    test "fetches key from data map" do
      resp = %Response{data: %{"name" => "John"}}
      assert resp["name"] == "John"
    end

    test "returns nil for missing key in data map" do
      resp = %Response{data: %{"name" => "John"}}
      assert resp["missing"] == nil
    end

    test "returns nil when data is a %List{} struct" do
      resp = %Response{data: %List{}}
      assert resp["name"] == nil
    end

    test "returns nil when data is nil" do
      resp = %Response{data: nil}
      assert resp["name"] == nil
    end

    test "Access.fetch returns {:ok, value} for existing key" do
      resp = %Response{data: %{"name" => "John"}}
      assert Access.fetch(resp, "name") == {:ok, "John"}
    end

    test "Access.fetch returns :error for missing key" do
      resp = %Response{data: %{"name" => "John"}}
      assert Access.fetch(resp, "missing") == :error
    end

    test "Access.fetch returns :error when data is a List struct" do
      resp = %Response{data: %List{}}
      assert Access.fetch(resp, "name") == :error
    end
  end

  describe "Access behaviour - get_and_update" do
    test "put_in updates data map key" do
      resp = %Response{data: %{"name" => "John"}}
      updated = put_in(resp, ["name"], "Jane")
      assert updated.data == %{"name" => "Jane"}
    end

    test "put_in adds new key to data map" do
      resp = %Response{data: %{"name" => "John"}}
      updated = put_in(resp, ["email"], "john@example.com")
      assert updated.data == %{"name" => "John", "email" => "john@example.com"}
    end

    test "get_and_update returns nil current when data is a List struct" do
      resp = %Response{data: %List{}}
      {current, updated_resp} = Access.get_and_update(resp, "name", fn _ -> {"Jane", "Jane"} end)
      assert current == nil
      assert updated_resp == resp
    end

    test "get_and_update returns nil current when data is nil" do
      resp = %Response{data: nil}
      {current, updated_resp} = Access.get_and_update(resp, "name", fn _ -> {"Jane", "Jane"} end)
      assert current == nil
      assert updated_resp == resp
    end
  end

  describe "Access behaviour - pop" do
    test "pop removes key from data map and returns value" do
      resp = %Response{data: %{"name" => "John", "email" => "john@example.com"}}
      {value, updated_resp} = pop_in(resp, ["name"])
      assert value == "John"
      assert updated_resp.data == %{"email" => "john@example.com"}
    end

    test "pop returns nil when key not in data map" do
      resp = %Response{data: %{"name" => "John"}}
      {value, updated_resp} = pop_in(resp, ["missing"])
      assert value == nil
      assert updated_resp.data == %{"name" => "John"}
    end

    test "pop returns {nil, resp} when data is a List struct" do
      resp = %Response{data: %List{}}
      {value, updated_resp} = Access.pop(resp, "name")
      assert value == nil
      assert updated_resp == resp
    end
  end

  describe "get_header/2" do
    test "returns matching header value" do
      resp = %Response{headers: [{"Request-Id", "req_123"}]}
      assert Response.get_header(resp, "Request-Id") == ["req_123"]
    end

    test "returns header value case-insensitively" do
      resp = %Response{headers: [{"Request-Id", "req_123"}]}
      assert Response.get_header(resp, "request-id") == ["req_123"]
      assert Response.get_header(resp, "REQUEST-ID") == ["req_123"]
    end

    test "returns [] when header not found" do
      resp = %Response{headers: [{"Content-Type", "application/json"}]}
      assert Response.get_header(resp, "missing") == []
    end

    test "returns all values when multiple matching headers" do
      resp = %Response{headers: [{"x-custom", "val1"}, {"X-Custom", "val2"}, {"other", "val3"}]}
      assert Response.get_header(resp, "x-custom") == ["val1", "val2"]
    end

    test "returns [] when headers list is empty" do
      resp = %Response{headers: []}
      assert Response.get_header(resp, "request-id") == []
    end
  end

  describe "Inspect protocol" do
    test "shows id and object from data, not full data" do
      resp = %Response{
        data: %{"id" => "cus_123", "object" => "customer", "email" => "pii@example.com"},
        status: 200,
        request_id: "req_abc"
      }

      inspected = inspect(resp)
      assert inspected =~ "cus_123"
      assert inspected =~ "customer"
      refute inspected =~ "pii@example.com"
    end

    test "shows status and request_id" do
      resp = %Response{
        data: %{"id" => "cus_123"},
        status: 200,
        request_id: "req_abc"
      }

      inspected = inspect(resp)
      assert inspected =~ "200"
      assert inspected =~ "req_abc"
    end

    test "shows List item count when data is a List" do
      list = %List{data: [%{"id" => "cus_1"}, %{"id" => "cus_2"}]}
      resp = %Response{data: list}
      inspected = inspect(resp)
      assert inspected =~ "LatticeStripe.List<2 items>"
    end

    test "hides individual header values, shows count" do
      resp = %Response{
        data: %{"id" => "cus_123"},
        headers: [
          {"authorization", "Bearer sk_test_secret"},
          {"content-type", "application/json"}
        ]
      }

      inspected = inspect(resp)
      refute inspected =~ "sk_test_secret"
      assert inspected =~ "2 headers"
    end
  end
end
