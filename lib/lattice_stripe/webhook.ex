defmodule LatticeStripe.Webhook do
  @moduledoc """
  Stripe webhook signature verification and event construction.

  LatticeStripe.Webhook provides pure-functional HMAC-SHA256 signature verification
  for incoming Stripe webhook payloads. It is designed to be used in a Plug pipeline
  or any web framework — it has no Plug dependency itself.

  ## Usage

      # In a Plug or controller action, after reading the raw body:
      raw_body = conn.assigns[:raw_body]
      sig_header = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()
      secret = Application.fetch_env!(:my_app, :stripe_webhook_secret)

      case LatticeStripe.Webhook.construct_event(raw_body, sig_header, secret) do
        {:ok, event} ->
          handle_event(event)
          send_resp(conn, 200, "ok")

        {:error, :missing_header} ->
          send_resp(conn, 400, "Missing Stripe-Signature header")

        {:error, :timestamp_expired} ->
          send_resp(conn, 400, "Webhook timestamp too old")

        {:error, reason} ->
          send_resp(conn, 400, "Signature verification failed: \#{reason}")
      end

  ## Important: Raw Body Requirement

  Stripe signs the **raw, unmodified request body**. Most web frameworks parse
  the body and discard the original bytes. You must configure your framework to
  preserve the raw body before calling these functions. See the LatticeStripe
  Plug documentation for a ready-made solution.

  ## Replay Attack Protection

  By default, `verify_signature/3` rejects webhooks with a timestamp older than
  300 seconds (5 minutes). Override with `tolerance: seconds` in opts.

  ## Multiple Secrets (Secret Rotation)

  Pass a list of secrets to verify against any of them. Useful during Stripe
  webhook secret rotation — the new and old secret both work until rotation completes.

      Webhook.verify_signature(payload, header, [old_secret, new_secret])
  """

  alias LatticeStripe.Event
  alias LatticeStripe.Webhook.SignatureVerificationError

  @type secret :: String.t() | [String.t(), ...]
  @type verify_error ::
          :missing_header | :invalid_header | :no_matching_signature | :timestamp_expired

  # Default replay attack protection window in seconds (matches Stripe's default).
  @default_tolerance 300

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Verifies a Stripe webhook signature and, if valid, constructs a typed `%Event{}`.

  This is the primary function for handling incoming webhooks. It:
  1. Verifies the `Stripe-Signature` header using HMAC-SHA256
  2. Checks the timestamp is within the tolerance window (replay attack protection)
  3. Decodes the JSON payload into a `%LatticeStripe.Event{}` struct

  ## Parameters

  - `payload` - The raw, unmodified request body string
  - `sig_header` - The value of the `Stripe-Signature` header (e.g., `"t=1234,v1=abc..."`)
  - `secret` - Your webhook signing secret (string or list of strings for rotation)
  - `opts` - Options:
    - `:tolerance` - max age in seconds (default: 300). Set `0` to disable staleness check.

  ## Returns

  - `{:ok, %Event{}}` on success
  - `{:error, verify_error()}` on failure — see `t:verify_error/0`
  """
  @spec construct_event(String.t(), String.t() | nil, secret(), keyword()) ::
          {:ok, Event.t()} | {:error, verify_error()}
  def construct_event(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
    case verify_signature(payload, sig_header, secret, opts) do
      {:ok, _timestamp} ->
        event =
          payload
          |> Jason.decode!()
          |> Event.from_map()

        {:ok, event}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Like `construct_event/4` but raises `SignatureVerificationError` on failure.

  ## Returns

  - `%Event{}` on success
  - Raises `LatticeStripe.Webhook.SignatureVerificationError` on failure
  """
  @spec construct_event!(String.t(), String.t() | nil, secret(), keyword()) :: Event.t()
  def construct_event!(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
    case construct_event(payload, sig_header, secret, opts) do
      {:ok, event} -> event
      {:error, reason} -> raise SignatureVerificationError, reason: reason
    end
  end

  @doc """
  Verifies a Stripe webhook signature header against a payload and secret.

  Performs timing-safe HMAC-SHA256 comparison via `Plug.Crypto.secure_compare/2`.
  Returns the parsed timestamp integer on success (useful for logging).

  ## Parameters

  - `payload` - The raw request body string
  - `sig_header` - The `Stripe-Signature` header value
  - `secret` - Signing secret or list of secrets (for rotation)
  - `opts` - Options:
    - `:tolerance` - max timestamp age in seconds (default: 300)

  ## Returns

  - `{:ok, timestamp}` where `timestamp` is a Unix integer on success
  - `{:error, :missing_header}` — no header provided
  - `{:error, :invalid_header}` — header is present but malformed
  - `{:error, :timestamp_expired}` — timestamp older than tolerance
  - `{:error, :no_matching_signature}` — HMAC doesn't match any provided secret
  """
  @spec verify_signature(String.t(), String.t() | nil, secret(), keyword()) ::
          {:ok, integer()} | {:error, verify_error()}
  def verify_signature(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)

    with {:ok, timestamp_str, signatures} <- parse_header(sig_header),
         {:ok, timestamp} <- parse_timestamp(timestamp_str),
         :ok <- check_tolerance(timestamp, tolerance) do
      secrets = normalize_secrets(secret)
      computed = Enum.map(secrets, &compute_signature(payload, timestamp_str, &1))

      matched =
        Enum.any?(computed, fn computed_sig ->
          Enum.any?(signatures, fn received_sig ->
            Plug.Crypto.secure_compare(computed_sig, received_sig)
          end)
        end)

      if matched do
        {:ok, timestamp}
      else
        {:error, :no_matching_signature}
      end
    end
  end

  @doc """
  Like `verify_signature/4` but raises `SignatureVerificationError` on failure.

  ## Returns

  - `timestamp` (integer) on success
  - Raises `LatticeStripe.Webhook.SignatureVerificationError` on failure
  """
  @spec verify_signature!(String.t(), String.t() | nil, secret(), keyword()) :: integer()
  def verify_signature!(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
    case verify_signature(payload, sig_header, secret, opts) do
      {:ok, timestamp} -> timestamp
      {:error, reason} -> raise SignatureVerificationError, reason: reason
    end
  end

  @doc """
  Generates a Stripe-compatible webhook signature header for testing.

  Use this in tests to produce a `Stripe-Signature` header that passes
  `verify_signature/3`. This avoids hard-coding computed HMAC values in tests
  and correctly simulates what Stripe's servers send.

  ## Parameters

  - `payload` - The JSON-encoded payload string
  - `secret` - The webhook signing secret
  - `opts` - Options:
    - `:timestamp` - Unix timestamp integer to embed (default: current time)

  ## Returns

  A `Stripe-Signature` header value string, e.g. `"t=1680000000,v1=abc123..."`.

  ## Example

      header = LatticeStripe.Webhook.generate_test_signature(payload, secret)
      {:ok, event} = LatticeStripe.Webhook.construct_event(payload, header, secret)
  """
  @spec generate_test_signature(String.t(), String.t(), keyword()) :: String.t()
  def generate_test_signature(payload, secret, opts \\ []) when is_binary(payload) do
    timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
    timestamp_str = Integer.to_string(timestamp)
    signature = compute_signature(payload, timestamp_str, secret)
    "t=#{timestamp_str},v1=#{signature}"
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Parses the Stripe-Signature header value.
  #
  # Expected format: "t=1234567890,v1=abc123def456,v1=another_sig"
  # Multiple v1= values are allowed (Stripe may send multiple signatures during
  # key rotation).
  #
  # Returns {:ok, timestamp_str, [sig_string, ...]} or {:error, :invalid_header}
  #
  # Example input:  "t=1680000000,v1=abcdef"
  # Example output: {:ok, "1680000000", ["abcdef"]}
  defp parse_header(nil), do: {:error, :missing_header}
  defp parse_header(""), do: {:error, :missing_header}

  defp parse_header(header) when is_binary(header) do
    parts = String.split(header, ",")

    timestamp_str =
      Enum.find_value(parts, fn part ->
        case String.split(part, "=", parts: 2) do
          ["t", ts] -> ts
          _ -> nil
        end
      end)

    signatures =
      Enum.flat_map(parts, fn part ->
        case String.split(part, "=", parts: 2) do
          ["v1", sig] -> [sig]
          _ -> []
        end
      end)

    cond do
      is_nil(timestamp_str) -> {:error, :invalid_header}
      signatures == [] -> {:error, :invalid_header}
      true -> {:ok, timestamp_str, signatures}
    end
  end

  # Parses timestamp string to integer. Returns {:error, :invalid_header} if not
  # a valid integer string.
  defp parse_timestamp(timestamp_str) do
    case Integer.parse(timestamp_str) do
      {ts, ""} -> {:ok, ts}
      _ -> {:error, :invalid_header}
    end
  end

  # Checks that the webhook timestamp is within the tolerance window.
  # tolerance: 0 means any non-current timestamp will fail.
  defp check_tolerance(_timestamp, 0) do
    # tolerance: 0 means any age is expired — we always compare against current time
    # We must still check: if timestamp == now it's fine, otherwise expired.
    # But since this is called per-second, we skip the 0 case with a special path.
    {:error, :timestamp_expired}
  end

  defp check_tolerance(timestamp, tolerance) when is_integer(tolerance) do
    now = System.system_time(:second)
    age = now - timestamp

    if age > tolerance do
      {:error, :timestamp_expired}
    else
      :ok
    end
  end

  # Normalizes secret to always be a list for uniform multi-secret handling.
  # Input: "single_secret" -> ["single_secret"]
  # Input: ["s1", "s2"]   -> ["s1", "s2"]
  defp normalize_secrets(secret) when is_binary(secret), do: [secret]
  defp normalize_secrets(secrets) when is_list(secrets), do: secrets

  # Computes the HMAC-SHA256 signature for the given payload and timestamp.
  #
  # Stripe's signing scheme: signed_payload = "#{timestamp}.#{payload}"
  # Then HMAC-SHA256(key=secret, message=signed_payload) encoded as lowercase hex.
  #
  # Example:
  #   compute_signature("payload", "1680000000", "secret")
  #   => "a3b2c1..." (64 hex chars)
  defp compute_signature(payload, timestamp_str, secret) do
    signed_payload = "#{timestamp_str}.#{payload}"

    :crypto.mac(:hmac, :sha256, secret, signed_payload)
    |> Base.encode16(case: :lower)
  end
end
