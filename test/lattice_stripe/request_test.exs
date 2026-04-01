defmodule LatticeStripe.RequestTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Request

  describe "Request struct defaults" do
    test "params defaults to %{} and opts defaults to []" do
      request = %Request{method: :get, path: "/v1/customers"}
      assert request.params == %{}
      assert request.opts == []
    end
  end

  describe "Request struct fields" do
    test "can be created with method, path, params, and opts" do
      request = %Request{
        method: :post,
        path: "/v1/customers",
        params: %{email: "test@example.com"},
        opts: [idempotency_key: "idem_123"]
      }

      assert request.method == :post
      assert request.path == "/v1/customers"
      assert request.params == %{email: "test@example.com"}
      assert request.opts == [idempotency_key: "idem_123"]
    end

    test "method can be :get" do
      request = %Request{method: :get, path: "/v1/customers/cus_123"}
      assert request.method == :get
    end

    test "method can be :delete" do
      request = %Request{method: :delete, path: "/v1/customers/cus_123"}
      assert request.method == :delete
    end

    test "path is accessible" do
      request = %Request{method: :get, path: "/v1/customers"}
      assert request.path == "/v1/customers"
    end
  end
end
