defmodule LatticeStripe.ErrorTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Error

  describe "Error struct / Exception behaviour" do
    test "Error struct implements Exception behaviour and can be raised" do
      error = %Error{
        type: :api_error,
        message: "Internal server error",
        status: 500,
        request_id: "req_abc"
      }

      assert_raise LatticeStripe.Error, fn ->
        raise error
      end
    end

    test "Error.message/1 returns '(type) status message' format (no code)" do
      error = %Error{type: :card_error, message: "Your card was declined", status: 402}
      assert Exception.message(error) == "(card_error) 402 Your card was declined"
    end

    test "Error.message/1 includes code when present" do
      error = %Error{
        type: :card_error,
        code: "card_declined",
        message: "Your card has insufficient funds.",
        status: 402,
        request_id: "req_abc123"
      }

      assert Exception.message(error) ==
               "(card_error) 402 card_declined Your card has insufficient funds. (request: req_abc123)"
    end

    test "Error.message/1 with nil code omits code segment" do
      error = %Error{
        type: :api_error,
        code: nil,
        message: "Server error",
        status: 500,
        request_id: "req_xyz"
      }

      assert Exception.message(error) == "(api_error) 500 Server error (request: req_xyz)"
    end

    test "Error.message/1 with nil request_id omits request segment" do
      error = %Error{
        type: :rate_limit_error,
        code: "rate_limited",
        message: "Too many requests",
        status: 429,
        request_id: nil
      }

      assert Exception.message(error) == "(rate_limit_error) 429 rate_limited Too many requests"
    end

    test "Error.message/1 with nil status omits status" do
      error = %Error{
        type: :connection_error,
        message: "Connection refused",
        status: nil,
        request_id: nil
      }

      assert Exception.message(error) == "(connection_error) Connection refused"
    end

    test "all struct fields are accessible: type, code, message, status, request_id" do
      error = %Error{
        type: :invalid_request_error,
        code: "missing_param",
        message: "Missing required param: amount",
        status: 400,
        request_id: "req_xyz"
      }

      assert error.type == :invalid_request_error
      assert error.code == "missing_param"
      assert error.message == "Missing required param: amount"
      assert error.status == 400
      assert error.request_id == "req_xyz"
    end

    test "pattern matching on error type works" do
      error = %Error{type: :card_error, message: "Declined", status: 402}

      result =
        case error do
          %Error{type: :card_error} -> :matched
          _ -> :no_match
        end

      assert result == :matched
    end
  end

  describe "Error struct — new fields" do
    test "struct has :param field defaulting to nil" do
      error = %Error{}
      assert Map.has_key?(error, :param)
      assert error.param == nil
    end

    test "struct has :decline_code field defaulting to nil" do
      error = %Error{}
      assert Map.has_key?(error, :decline_code)
      assert error.decline_code == nil
    end

    test "struct has :charge field defaulting to nil" do
      error = %Error{}
      assert Map.has_key?(error, :charge)
      assert error.charge == nil
    end

    test "struct has :doc_url field defaulting to nil" do
      error = %Error{}
      assert Map.has_key?(error, :doc_url)
      assert error.doc_url == nil
    end

    test "struct has :raw_body field defaulting to nil" do
      error = %Error{}
      assert Map.has_key?(error, :raw_body)
      assert error.raw_body == nil
    end

    test "new fields can be set and accessed" do
      error = %Error{
        type: :card_error,
        param: "card[number]",
        decline_code: "insufficient_funds",
        charge: "ch_test123",
        doc_url: "https://stripe.com/docs/error-codes/card-declined",
        raw_body: %{"error" => %{"type" => "card_error"}}
      }

      assert error.param == "card[number]"
      assert error.decline_code == "insufficient_funds"
      assert error.charge == "ch_test123"
      assert error.doc_url == "https://stripe.com/docs/error-codes/card-declined"
      assert error.raw_body == %{"error" => %{"type" => "card_error"}}
    end
  end

  describe "Error type — idempotency_error" do
    test "parse_type/1 handles idempotency_error" do
      body = %{
        "error" => %{
          "type" => "idempotency_error",
          "message" => "Keys for idempotent requests can only be used with the same parameters"
        }
      }

      error = Error.from_response(409, body, "req_idem123")
      assert error.type == :idempotency_error
    end

    test "idempotency_error can be pattern matched" do
      error = %Error{type: :idempotency_error, status: 409}

      result =
        case error do
          %Error{type: :idempotency_error} -> :matched
          _ -> :no_match
        end

      assert result == :matched
    end
  end

  describe "String.Chars protocol" do
    test "string interpolation returns same as Exception.message(error)" do
      error = %Error{
        type: :card_error,
        code: "card_declined",
        message: "Your card has insufficient funds.",
        status: 402,
        request_id: "req_abc123"
      }

      assert "#{error}" == Exception.message(error)
    end

    test "String.Chars works for all error types" do
      error = %Error{type: :api_error, message: "Server error", status: 500}
      assert is_binary("#{error}")
      assert "#{error}" =~ "api_error"
    end
  end

  describe "Error.from_response/3" do
    test "parses authentication_error from 401 response" do
      body = %{"error" => %{"type" => "authentication_error", "message" => "Invalid API Key"}}
      error = Error.from_response(401, body, "req_123")

      assert %Error{
               type: :authentication_error,
               status: 401,
               request_id: "req_123",
               message: "Invalid API Key"
             } = error
    end

    test "parses card_error with code from 402 response" do
      body = %{
        "error" => %{
          "type" => "card_error",
          "code" => "card_declined",
          "message" => "Your card was declined"
        }
      }

      error = Error.from_response(402, body, "req_456")

      assert %Error{
               type: :card_error,
               code: "card_declined",
               message: "Your card was declined",
               status: 402,
               request_id: "req_456"
             } = error
    end

    test "parses invalid_request_error from 400 response" do
      body = %{
        "error" => %{"type" => "invalid_request_error", "message" => "Missing param"}
      }

      error = Error.from_response(400, body, "req_789")
      assert %Error{type: :invalid_request_error, status: 400} = error
    end

    test "parses rate_limit_error from 429 with nil request_id" do
      body = %{
        "error" => %{"type" => "rate_limit_error", "message" => "Too many requests"}
      }

      error = Error.from_response(429, body, nil)

      assert %Error{type: :rate_limit_error, request_id: nil} = error
    end

    test "parses api_error from 500 response" do
      body = %{"error" => %{"type" => "api_error", "message" => "Internal error"}}
      error = Error.from_response(500, body, "req_abc")
      assert %Error{type: :api_error, status: 500} = error
    end

    test "falls back to :api_error for non-standard error body" do
      body = %{"unexpected" => "body"}
      error = Error.from_response(500, body, "req_def")
      assert %Error{type: :api_error, status: 500} = error
    end

    test "unknown type strings fall back to :api_error" do
      body = %{
        "error" => %{"type" => "unknown_new_type", "message" => "Something new"}
      }

      error = Error.from_response(500, body, "req_ghi")
      assert %Error{type: :api_error} = error
    end

    test "connection error has nil status" do
      error = %Error{type: :connection_error, message: "Connection refused", status: nil}
      assert error.status == nil
      assert error.type == :connection_error
    end

    test "from_response/3 extracts param, decline_code, charge, doc_url into named fields" do
      body = %{
        "error" => %{
          "type" => "card_error",
          "code" => "card_declined",
          "message" => "Your card has insufficient funds.",
          "param" => "card[number]",
          "decline_code" => "insufficient_funds",
          "charge" => "ch_test_abc123",
          "doc_url" => "https://stripe.com/docs/error-codes/card-declined"
        }
      }

      error = Error.from_response(402, body, "req_full")

      assert error.param == "card[number]"
      assert error.decline_code == "insufficient_funds"
      assert error.charge == "ch_test_abc123"
      assert error.doc_url == "https://stripe.com/docs/error-codes/card-declined"
    end

    test "from_response/3 stores full error envelope in raw_body" do
      body = %{
        "error" => %{
          "type" => "card_error",
          "message" => "Declined",
          "code" => "card_declined"
        }
      }

      error = Error.from_response(402, body, "req_raw")
      assert error.raw_body == body
    end

    test "from_response/3 with non-standard body sets raw_body to the full body" do
      body = %{"unexpected" => "body", "some" => "data"}
      error = Error.from_response(500, body, "req_nonstandard")

      assert error.type == :api_error
      assert error.raw_body == body
    end
  end
end
