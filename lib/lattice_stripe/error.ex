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

  - `type` - Error category atom: `:card_error | :invalid_request_error | :authentication_error | :rate_limit_error | :api_error | :connection_error`
  - `code` - Stripe error code string (e.g., `"card_declined"`, `"missing_param"`) or `nil`
  - `message` - Human-readable error message
  - `status` - HTTP status integer, or `nil` for connection errors (no HTTP response received)
  - `request_id` - Stripe request ID from `Request-Id` response header, or `nil`
  """

  defexception [:type, :code, :message, :status, :request_id]

  @type error_type ::
          :card_error
          | :invalid_request_error
          | :authentication_error
          | :rate_limit_error
          | :api_error
          | :connection_error

  @type t :: %__MODULE__{
          type: error_type(),
          code: String.t() | nil,
          message: String.t() | nil,
          status: pos_integer() | nil,
          request_id: String.t() | nil
        }

  @impl true
  def message(%__MODULE__{type: type, message: msg}) do
    "(#{type}) #{msg}"
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
          status: status,
          request_id: request_id
        }

      _ ->
        %__MODULE__{
          type: :api_error,
          code: nil,
          message: "An unexpected error occurred",
          status: status,
          request_id: request_id
        }
    end
  end

  @spec parse_type(String.t()) :: error_type()
  defp parse_type("card_error"), do: :card_error
  defp parse_type("invalid_request_error"), do: :invalid_request_error
  defp parse_type("authentication_error"), do: :authentication_error
  defp parse_type("rate_limit_error"), do: :rate_limit_error
  defp parse_type("api_error"), do: :api_error
  defp parse_type(_), do: :api_error
end
