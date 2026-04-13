defmodule LatticeStripe.Error do
  @moduledoc """
  Structured error type for Stripe API errors.

  All errors returned by `LatticeStripe.Client.request/2` are wrapped in this struct.
  The `:type` field is always an atom, enabling clean pattern matching:

      case LatticeStripe.Customer.create(client, params) do
        {:ok, customer} -> handle_success(customer)
        {:error, %LatticeStripe.Error{type: :card_error, code: code}} -> handle_card_error(code)
        {:error, %LatticeStripe.Error{type: :authentication_error}} -> handle_auth_error()
        {:error, %LatticeStripe.Error{type: :rate_limit_error}} -> handle_rate_limit()
        {:error, %LatticeStripe.Error{}} -> handle_generic_error()
      end

  ## Fields

  - `type` - Error category atom: `:card_error | :invalid_request_error | :authentication_error | :rate_limit_error | :api_error | :idempotency_error | :connection_error`
  - `code` - Stripe error code string (e.g., `"card_declined"`, `"missing_param"`) or `nil`
  - `message` - Human-readable error message
  - `status` - HTTP status integer, or `nil` for connection errors (no HTTP response received)
  - `request_id` - Stripe request ID from `Request-Id` response header, or `nil`
  - `param` - Parameter name that caused the error (e.g., `"card[number]"`), or `nil`
  - `decline_code` - Decline code for card errors (e.g., `"insufficient_funds"`), or `nil`
  - `charge` - Stripe charge ID associated with the error, or `nil`
  - `doc_url` - URL to Stripe documentation for this error, or `nil`
  - `raw_body` - Full decoded error body map — escape hatch for fields not yet in the struct, or `nil`
  """

  defexception [
    :type,
    :code,
    :message,
    :status,
    :request_id,
    :param,
    :decline_code,
    :charge,
    :doc_url,
    :raw_body
  ]

  @typedoc """
  Stripe error type atom.

  See the [Stripe error types documentation](https://docs.stripe.com/api/errors) for details.

  - `:card_error` — The card was declined or has an issue (e.g., `"card_declined"`, `"expired_card"`)
  - `:invalid_request_error` — Invalid parameters in the request (e.g., missing required field)
  - `:authentication_error` — Invalid or missing API key
  - `:rate_limit_error` — Too many requests in too short a time
  - `:api_error` — Stripe server error or unexpected response
  - `:idempotency_error` — The same idempotency key was reused with different parameters
  - `:connection_error` — Network-level failure, no HTTP response received
  - `:test_clock_timeout` — A test clock advance timed out waiting for the clock to reach the target time
  - `:test_clock_failed` — A test clock advance completed but the clock reported a failed status
  - `:proration_required` — Returned by the Billing proration guard when `require_explicit_proration: true`
    and the `proration_behavior` param is missing from a proration-sensitive request
  """
  @type error_type ::
          :card_error
          | :invalid_request_error
          | :authentication_error
          | :rate_limit_error
          | :api_error
          | :idempotency_error
          | :connection_error
          | :test_clock_timeout
          | :test_clock_failed
          | :proration_required

  @typedoc """
  A structured Stripe API error.

  All errors from `LatticeStripe.Client.request/2` are wrapped in this struct.
  Pattern match on `type` to handle specific error categories.

  See the [Stripe error object](https://docs.stripe.com/api/errors) for field definitions.

  - `type` - Error category atom (always present)
  - `code` - Stripe error code string (e.g., `"card_declined"`, `"missing_param"`), or `nil`
  - `message` - Human-readable error description
  - `status` - HTTP status integer, or `nil` for `:connection_error`
  - `request_id` - Stripe `Request-Id` header value for support, or `nil`
  - `param` - Parameter name that caused the error (e.g., `"card[number]"`), or `nil`
  - `decline_code` - Card decline reason (e.g., `"insufficient_funds"`), or `nil`
  - `charge` - Stripe charge ID associated with the error, or `nil`
  - `doc_url` - Stripe documentation URL for this specific error, or `nil`
  - `raw_body` - Full decoded error body — escape hatch for fields not in the struct, or `nil`
  """
  @type t :: %__MODULE__{
          type: error_type(),
          code: String.t() | nil,
          message: String.t() | nil,
          status: pos_integer() | nil,
          request_id: String.t() | nil,
          param: String.t() | nil,
          decline_code: String.t() | nil,
          charge: String.t() | nil,
          doc_url: String.t() | nil,
          raw_body: map() | nil
        }

  @impl true
  def message(%__MODULE__{} = error) do
    parts = ["(#{error.type})"]
    parts = if error.status, do: parts ++ ["#{error.status}"], else: parts
    parts = if error.code, do: parts ++ [error.code], else: parts
    parts = if error.message, do: parts ++ [error.message], else: parts
    parts = if error.request_id, do: parts ++ ["(request: #{error.request_id})"], else: parts
    Enum.join(parts, " ")
  end

  @doc """
  Build an `Error` struct from a Stripe API response.

  Called by `Client.request/2` when the HTTP status indicates an error (4xx or 5xx).

  ## Parameters

  - `status` - HTTP status code integer
  - `decoded_body` - Decoded JSON body map
  - `request_id` - Value of the `Request-Id` response header, or `nil`
  """
  @spec from_response(pos_integer(), map(), String.t() | nil) :: t()
  def from_response(status, decoded_body, request_id) do
    case decoded_body do
      %{"error" => %{"type" => type_str} = error_map} ->
        %__MODULE__{
          type: parse_type(type_str),
          code: Map.get(error_map, "code"),
          message: Map.get(error_map, "message"),
          param: Map.get(error_map, "param"),
          decline_code: Map.get(error_map, "decline_code"),
          charge: Map.get(error_map, "charge"),
          doc_url: Map.get(error_map, "doc_url"),
          status: status,
          request_id: request_id,
          raw_body: decoded_body
        }

      _ ->
        %__MODULE__{
          type: :api_error,
          code: nil,
          message: "An unexpected error occurred",
          status: status,
          request_id: request_id,
          raw_body: decoded_body
        }
    end
  end

  @spec parse_type(String.t()) :: error_type()
  defp parse_type("card_error"), do: :card_error
  defp parse_type("invalid_request_error"), do: :invalid_request_error
  defp parse_type("authentication_error"), do: :authentication_error
  defp parse_type("rate_limit_error"), do: :rate_limit_error
  defp parse_type("api_error"), do: :api_error
  defp parse_type("idempotency_error"), do: :idempotency_error
  defp parse_type(_), do: :api_error
end

defimpl String.Chars, for: LatticeStripe.Error do
  def to_string(error) do
    Exception.message(error)
  end
end
