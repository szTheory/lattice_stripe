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
        parsed_type = parse_type(type_str)

        %__MODULE__{
          type: parsed_type,
          code: Map.get(error_map, "code"),
          message: maybe_enrich_message(
            parsed_type,
            Map.get(error_map, "message"),
            Map.get(error_map, "param")
          ),
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

  # Append fuzzy param suggestion to invalid_request_error messages (D-03).
  # Only fires when type is :invalid_request_error and param is a non-nil binary.
  # Guard clause + catch-all mirrors parse_type/1 multi-clause style.
  defp maybe_enrich_message(:invalid_request_error, message, param)
       when is_binary(param) and byte_size(param) > 0 do
    case suggest_param(param) do
      nil -> message
      match -> message <> "; did you mean :#{match}?"
    end
  end

  defp maybe_enrich_message(_type, message, _param), do: message

  # Response-only fields that should never appear as param suggestions (D-02).
  # These are read-only fields returned by Stripe, never sent as request params.
  @response_only_fields ~w[id object created livemode url deleted has_more
                           total_count next_page previous_page data]

  # Find the closest matching field name for a param string (D-02).
  # Uses String.jaro_distance/2 (Elixir stdlib) with 0.8 threshold and
  # minimum length 4 to avoid noisy short-name matches.
  defp suggest_param(param) do
    leaf = extract_leaf_param(param)

    if String.length(leaf) < 4 do
      nil
    else
      candidates =
        all_known_fields()
        |> Enum.reject(&(&1 in @response_only_fields))

      case Enum.max_by(candidates, &String.jaro_distance(leaf, &1), fn -> nil end) do
        nil -> nil
        best -> if String.jaro_distance(leaf, best) >= 0.8, do: best, else: nil
      end
    end
  end

  # Extract the leaf field name from bracket notation params.
  # "card[nubmer]" -> "nubmer", "payment_method_type" -> "payment_method_type"
  defp extract_leaf_param(param) do
    case Regex.run(~r/\[(\w+)\]$/, param) do
      [_, leaf] -> leaf
      nil -> param
    end
  end

  # All resource modules whose struct keys serve as the global param candidate pool.
  # Struct keys mirror @known_fields in every resource module.
  # When a new resource module is added to ObjectTypes, add it here too.
  # (Phase 30 drift detection can automate this check.)
  @all_resource_modules [
    LatticeStripe.Account,
    LatticeStripe.AccountLink,
    LatticeStripe.Balance,
    LatticeStripe.BalanceTransaction,
    LatticeStripe.BankAccount,
    LatticeStripe.Card,
    LatticeStripe.Charge,
    LatticeStripe.Checkout.Session,
    LatticeStripe.Coupon,
    LatticeStripe.Customer,
    LatticeStripe.Event,
    LatticeStripe.Invoice,
    LatticeStripe.Invoice.LineItem,
    LatticeStripe.InvoiceItem,
    LatticeStripe.LoginLink,
    LatticeStripe.PaymentIntent,
    LatticeStripe.PaymentMethod,
    LatticeStripe.Payout,
    LatticeStripe.Price,
    LatticeStripe.Product,
    LatticeStripe.PromotionCode,
    LatticeStripe.Refund,
    LatticeStripe.SetupIntent,
    LatticeStripe.Subscription,
    LatticeStripe.SubscriptionItem,
    LatticeStripe.SubscriptionSchedule,
    LatticeStripe.Transfer,
    LatticeStripe.TransferReversal,
    LatticeStripe.Billing.Meter,
    LatticeStripe.Billing.MeterEvent,
    LatticeStripe.Billing.MeterEventAdjustment,
    LatticeStripe.BillingPortal.Configuration,
    LatticeStripe.BillingPortal.Session,
    LatticeStripe.TestHelpers.TestClock
  ]

  # Build global param candidate list from all resource module struct keys at compile time.
  # Struct keys mirror @known_fields in every resource module.
  @all_resource_known_fields (
    Enum.flat_map(@all_resource_modules, fn mod ->
      mod.__struct__()
      |> Map.keys()
      |> Enum.reject(&(&1 == :__struct__))
      |> Enum.map(&Atom.to_string/1)
    end)
    |> Enum.uniq()
  )

  # Collect all field names across all resource modules for fuzzy matching.
  defp all_known_fields, do: @all_resource_known_fields
end

defimpl String.Chars, for: LatticeStripe.Error do
  def to_string(error) do
    Exception.message(error)
  end
end
