defmodule LatticeStripe.Client.ResponseDecodingTest do
  use LatticeStripe.ClientCase, async: true

  describe "request/2 response handling" do
    # Test 14: request/2 on 200 returns {:ok, %Response{data: decoded_map}}
    test "200 response returns {:ok, %Response{data: decoded_map}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response(%{"id" => "cus_123", "object" => "customer"})
      end)

      assert {:ok, %Response{data: %{"id" => "cus_123", "object" => "customer"}}} =
               Client.request(client, get_request())
    end

    # Test 15: request/2 on 401 returns {:error, %Error{type: :authentication_error}}
    test "401 response returns authentication_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(401, "authentication_error", "No such API key")
      end)

      assert {:error, %Error{type: :authentication_error, status: 401}} =
               Client.request(client, get_request())
    end

    # Test 16: request/2 on 400 returns {:error, %Error{type: :invalid_request_error}}
    test "400 response returns invalid_request_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(400, "invalid_request_error", "Missing required param: source")
      end)

      assert {:error, %Error{type: :invalid_request_error, status: 400}} =
               Client.request(client, post_request())
    end

    # Test 17: request/2 on 429 returns {:error, %Error{type: :rate_limit_error}}
    test "429 response returns rate_limit_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(429, "rate_limit_error", "Too many requests")
      end)

      assert {:error, %Error{type: :rate_limit_error, status: 429}} =
               Client.request(client, get_request())
    end

    # Test 18: request/2 on transport error returns {:error, %Error{type: :connection_error}}
    test "transport error returns connection_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:error, :timeout}
      end)

      assert {:error, %Error{type: :connection_error, headers: [], retry_after: nil}} =
               Client.request(client, get_request())
    end
  end

  describe "request/2 non-JSON responses" do
    # Test 40: HTML response body returns structured api_error with raw_body
    test "HTML response returns api_error with raw_body containing _raw key" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        non_json_response(503, "<html><body>We're down for maintenance</body></html>")
      end)

      assert {:error, %Error{type: :api_error, raw_body: %{"_raw" => raw}}} =
               Client.request(client, get_request())

      assert is_binary(raw)
      assert String.contains?(raw, "maintenance")
    end

    test "non-JSON errors preserve their response headers and Retry-After evidence" do
      client = test_client(max_retries: 0)

      headers = [
        {"Request-Id", "req_non_json"},
        {"Retry-After", " 60 "},
        {"retry-after", "120"}
      ]

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok, %{status: 503, headers: headers, body: "<html>maintenance</html>"}}
      end)

      assert {:error, %Error{headers: ^headers, retry_after: 60}} =
               Client.request(client, get_request())
    end

    # Test 41: Empty response body returns structured api_error
    test "empty response body returns api_error with descriptive message" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        non_json_response(500, "")
      end)

      assert {:error, %Error{type: :api_error, message: message}} =
               Client.request(client, get_request())

      assert is_binary(message)
    end

    # Test 42: Non-JSON 503 response flows through retry loop normally
    test "non-JSON 503 response flows through retry loop" do
      client = retry_client(max_retries: 1)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # 2 total attempts (initial + 1 retry)
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        non_json_response(503, "<html>maintenance</html>")
      end)

      assert {:error, %Error{type: :api_error, status: 503}} =
               Client.request(client, get_request())
    end

    # Test 43: Non-JSON body is truncated at 500 bytes in raw_body
    test "long non-JSON body is truncated in raw_body" do
      client = test_client(max_retries: 0)
      long_body = String.duplicate("x", 1000)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        non_json_response(502, long_body)
      end)

      assert {:error, %Error{type: :api_error, raw_body: %{"_raw" => raw}}} =
               Client.request(client, get_request())

      # Should be truncated (500 chars + "...")
      assert byte_size(raw) <= 510
    end
  end

  describe "request!/2 bang variant" do
    # Test 44: request!/2 raises LatticeStripe.Error on failure
    test "raises LatticeStripe.Error on failure" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(401, "authentication_error", "Invalid API key")
      end)

      assert_raise LatticeStripe.Error, fn ->
        Client.request!(client, get_request())
      end
    end

    # Test 45: request!/2 returns %Response{} on success
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response(%{"id" => "cus_bang_123"})
      end)

      result = Client.request!(client, get_request())
      assert %Response{data: %{"id" => "cus_bang_123"}} = result
    end

    # Test 46: request!/2 retries before raising
    test "retries before raising on final failure" do
      client = retry_client(max_retries: 2)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # All 3 attempts fail
      expect(LatticeStripe.MockTransport, :request, 3, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      assert_raise LatticeStripe.Error, fn ->
        Client.request!(client, get_request())
      end
    end

    # Test 47: request!/2 raises with correct error type
    test "raised error has correct type and status" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(402, "card_error", "Card declined")
      end)

      error =
        assert_raise LatticeStripe.Error, fn ->
          Client.request!(client, post_request())
        end

      assert error.type == :card_error
      assert error.status == 402
    end
  end

  describe "response wrapping" do
    # Test 53: Singular resource response is wrapped in %Response{} with metadata
    test "singular resource wrapped in %Response{} with status and request_id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 200,
           headers: [{"request-id", "req_test_123"}],
           body: Jason.encode!(%{"id" => "cus_123", "object" => "customer"})
         }}
      end)

      assert {:ok, %Response{data: %{"id" => "cus_123"}, status: 200, request_id: "req_test_123"}} =
               Client.request(client, get_request())
    end

    # Test 54: List response auto-detected and wrapped in %LatticeStripe.List{}
    test "list object auto-detected and data wrapped in %List{}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 200,
           headers: [{"request-id", "req_list_123"}],
           body:
             Jason.encode!(%{
               "object" => "list",
               "data" => [%{"id" => "cus_1"}],
               "has_more" => true,
               "url" => "/v1/customers"
             })
         }}
      end)

      assert {:ok,
              %Response{
                data: %LatticeStripe.List{
                  object: "list",
                  data: [%{"id" => "cus_1"}],
                  has_more: true
                }
              }} =
               Client.request(client, get_request("/v1/customers"))
    end

    # Test 55: Search result auto-detected and wrapped in %LatticeStripe.List{}
    test "search_result object auto-detected and wrapped in %List{}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 200,
           headers: [{"request-id", "req_search_456"}],
           body:
             Jason.encode!(%{
               "object" => "search_result",
               "data" => [%{"id" => "cus_2"}],
               "has_more" => false,
               "next_page" => "page_token_abc"
             })
         }}
      end)

      assert {:ok,
              %Response{
                data: %LatticeStripe.List{object: "search_result", next_page: "page_token_abc"}
              }} =
               Client.request(client, get_request("/v1/customers/search"))
    end

    # Test 56: List response carries _params from the request
    test "_params and _opts are threaded into %List{} from the original request" do
      client = test_client()

      req = %Request{
        method: :get,
        path: "/v1/customers",
        params: %{"limit" => 10},
        opts: [stripe_account: "acct_123"]
      }

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 200,
           headers: [{"request-id", "req_params_789"}],
           body:
             Jason.encode!(%{
               "object" => "list",
               "data" => [],
               "has_more" => false,
               "url" => "/v1/customers"
             })
         }}
      end)

      assert {:ok, %Response{data: list}} = Client.request(client, req)
      assert %LatticeStripe.List{} = list
      assert list._params == %{"limit" => 10}
      assert list._opts == [stripe_account: "acct_123"]
    end

    # Test 57: Response headers are accessible on the Response struct
    test "response headers accessible on %Response{} struct" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 200,
           headers: [{"request-id", "req_hdr_111"}, {"content-type", "application/json"}],
           body: Jason.encode!(%{"id" => "cus_hdr"})
         }}
      end)

      assert {:ok, resp} = Client.request(client, get_request())
      assert resp.headers != []
      assert {"request-id", "req_hdr_111"} in resp.headers
    end

    # Test 58: bang variant returns %Response{} on success
    test "request!/2 returns %Response{} struct on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 200,
           headers: [{"request-id", "req_bang_999"}],
           body: Jason.encode!(%{"id" => "cus_bang"})
         }}
      end)

      assert %Response{data: %{"id" => "cus_bang"}} = Client.request!(client, get_request())
    end
  end
end
