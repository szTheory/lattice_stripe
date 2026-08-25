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

  ## Snapshot events vs thin events: when to use which

  Stripe ships **two** webhook payload shapes and LatticeStripe exposes a distinct
  entry point for each:

  - **Snapshot events** (the classic v1 webhook path — `object: "event"`, full event
    `data` embedded, Unix-integer `created`). Use `construct_event/4` and pattern-match
    `LatticeStripe.Event.t()`. This is what `/v1/webhook_endpoints` delivers and what
    every adopter using `LatticeStripe.Webhook.Plug` receives today.

  - **Thin events** (the v2 event-destinations path — `object: "v2.core.event"`, no
    embedded `data`, ISO 8601 string `created`, `related_object` reference to the
    underlying resource). Use `parse_event_notification/4` and pattern-match
    `LatticeStripe.EventNotification.t()`. The notification carries only metadata +
    a `related_object` pointer; adopters fetch the full `%Event{}` via
    `fetch_event/3` and the underlying resource via `fetch_related_object/3`
    (both shipped in this same v1.5 milestone).

  Calling the wrong entry point on a payload will silently produce a mostly-nil
  struct (the JSON keys don't overlap between the two wire shapes). Route based on
  which webhook endpoint Stripe is calling — `parse_event_notification/4` is for
  `/v2/event-destinations` traffic, `construct_event/4` is for everything else.

  ## Stripe API Reference

  See the [Stripe Webhooks documentation](https://docs.stripe.com/webhooks) for the full
  webhook reference, event catalog, and delivery guarantees.
  """

  alias LatticeStripe.Client
  alias LatticeStripe.Error
  alias LatticeStripe.Event
  alias LatticeStripe.EventNotification
  alias LatticeStripe.EventNotification.RelatedObject
  alias LatticeStripe.ObjectTypes
  alias LatticeStripe.Request
  alias LatticeStripe.Resource
  alias LatticeStripe.Response
  alias LatticeStripe.Webhook.SignatureVerificationError

  @type secret :: String.t() | [String.t(), ...]
  @type verify_error ::
          :missing_header | :invalid_header | :no_matching_signature | :timestamp_expired

  # Default replay attack protection window in seconds (matches Stripe's default).
  @default_tolerance 300

  # Public API

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
    - `:tolerance` - max age in seconds (default: 300). Set `0` to disable the
      staleness check (testing only — see WEBFIX-01 CHANGELOG entry and the
      inline comment on `check_tolerance/2` for the decision context).

  ## Returns

  - `{:ok, %Event{}}` on success
  - `{:error, verify_error()}` on failure — see `t:verify_error/0`
  """
  @spec construct_event(String.t(), String.t() | nil, secret(), keyword()) ::
          {:ok, Event.t()} | {:error, verify_error()}
  def construct_event(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
    LatticeStripe.Telemetry.webhook_verify_span([], fn ->
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
    end)
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
  Verifies a Stripe thin-event signature and decodes the payload into an `%EventNotification{}`.

  This is the thin-event (`/v2/events`) counterpart to `construct_event/4`. It uses
  the **same** HMAC-SHA256 verification primitive (`verify_signature/4`) — same wire
  format for `Stripe-Signature`, same tolerance machinery, same error atoms — but
  decodes the verified payload into `LatticeStripe.EventNotification.t()` instead of
  `LatticeStripe.Event.t()`.

  Thin events are delivered by Stripe `/v2/event-destinations` endpoints. The
  notification carries only metadata + a `related_object` reference; adopters fetch
  the full event with `fetch_event/3` and the underlying typed resource with
  `fetch_related_object/3`.

  For snapshot/v1 webhook payloads (`object: "event"`, full `data` embedded), use
  `construct_event/4` instead. See the module docstring "Snapshot events vs thin
  events: when to use which" for routing guidance.

  ## Parameters

  - `payload` - The raw, unmodified request body string
  - `sig_header` - The value of the `Stripe-Signature` header (e.g., `"t=1234,v1=abc..."`)
  - `secret` - Your webhook signing secret (string or list of strings for rotation)
  - `opts` - Options:
    - `:tolerance` - max age in seconds (default: 300). Set `0` to disable the
      staleness check (testing only — see WEBFIX-01 CHANGELOG entry).

  ## Returns

  - `{:ok, %EventNotification{}}` on success — typed struct exposing `id`, `type`,
    `created`, `context`, `livemode`, and `related_object`.
  - `{:error, :missing_header}` — no `Stripe-Signature` header was provided
  - `{:error, :invalid_header}` — header is present but malformed
  - `{:error, :no_matching_signature}` — HMAC doesn't match any provided secret
  - `{:error, :timestamp_expired}` — timestamp older than tolerance

  Identical 4-atom error set as `construct_event/4` (the verify boundary is shared).

  ## Example

      case LatticeStripe.Webhook.parse_event_notification(payload, sig_header, secret) do
        {:ok, %LatticeStripe.EventNotification{
           type: "v2.core.account.updated",
           related_object: %LatticeStripe.EventNotification.RelatedObject{
             type: "v2.core.account",
             id: account_id
           }} = notif} ->
          handle_account_update(notif, account_id)

        {:ok, %LatticeStripe.EventNotification{related_object: nil} = notif} ->
          # Snapshot-style v2 event (no related object) — fetch full event for context
          {:ok, %LatticeStripe.Event{} = event} =
            LatticeStripe.Webhook.fetch_event(client, notif)

          handle_full_event(event)

        {:error, :timestamp_expired} ->
          Logger.warning("Stripe webhook expired; check clock skew")

        {:error, reason} ->
          Logger.error("Stripe webhook verification failed: \#{inspect(reason)}")
      end
  """
  @spec parse_event_notification(String.t(), String.t() | nil, secret(), keyword()) ::
          {:ok, EventNotification.t()} | {:error, verify_error()}
  def parse_event_notification(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
    LatticeStripe.Telemetry.webhook_verify_span([], fn ->
      case verify_signature(payload, sig_header, secret, opts) do
        {:ok, _timestamp} ->
          notification =
            payload
            |> Jason.decode!()
            |> EventNotification.from_map()

          {:ok, notification}

        {:error, _reason} = error ->
          error
      end
    end)
  end

  @doc """
  Like `parse_event_notification/4` but raises `SignatureVerificationError` on failure.

  Parity with `construct_event!/4`: returns the typed notification struct on success,
  raises `LatticeStripe.Webhook.SignatureVerificationError` (carrying the `:reason`
  atom from the 4-atom verify error set) on any verify failure.

  ## Returns

  - `%EventNotification{}` on success
  - Raises `LatticeStripe.Webhook.SignatureVerificationError` on failure
  """
  @spec parse_event_notification!(String.t(), String.t() | nil, secret(), keyword()) ::
          EventNotification.t()
  def parse_event_notification!(payload, sig_header, secret, opts \\ [])
      when is_binary(payload) do
    case parse_event_notification(payload, sig_header, secret, opts) do
      {:ok, notif} -> notif
      {:error, reason} -> raise SignatureVerificationError, reason: reason
    end
  end

  @doc """
  Retrieves the full v2 `Event.t()` for a thin-event notification.

  Issues `GET /v2/core/events/{id}` and decodes the response via
  `LatticeStripe.Event.from_map/1`. Adopters call this after
  `parse_event_notification/4` returns an `%EventNotification{}` and they need
  the authoritative event state (e.g., for snapshot-style v2 events that have
  no `related_object`).

  Accepts either a `%LatticeStripe.EventNotification{}` (the `id` is extracted)
  or a bare `String.t()` event ID. The `%Client{}` is passed explicitly per
  Phase 47 D-04 — the notification struct stays pure serializable data with no
  embedded credential material, safe for ETS / logs / distributed Erlang.

  ## Snapshot vs thin-event Event retrieval

  For snapshot/v1 event IDs (returned by `construct_event/4` on the legacy
  `/v1/webhooks` path), use `LatticeStripe.Event.retrieve/3` instead — it hits
  `/v1/events/{id}` which differs from the v2 endpoint and returns a different
  payload shape (no `related_object`, integer `created`).

  ## `created` wire-format note

  On a `%Event{}` fetched via `fetch_event/3` from `/v2/core/events/{id}`, the
  `created` field arrives as an **ISO 8601 string** (e.g.,
  `"2026-03-09T13:00:28.435Z"`) — Stripe's wire format for v2 events. Snapshot
  v1 events delivered through `construct_event/4` (and retrieved via
  `Event.retrieve/3`) carry an integer Unix timestamp instead. The
  `Event.@type t() :created` typespec is currently `integer() | nil`; this
  asymmetry is documented and will be widened in a future patch (see Phase 47
  Open Question 2). The runtime behavior is correct either way — `Event.from_map/1`
  is infallible-deserialize and Dialyzer is not in use.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `notification_or_id` - An `%EventNotification{}` (whose `id` is extracted)
    OR a bare event-ID string (e.g., `"evt_test_..."`)
  - `opts` - Per-request overrides: `:api_version`, `:idempotency_key`, etc.
    (forwarded to `Client.request/2`)

  ## Returns

  - `{:ok, %Event{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on HTTP failure
  - `{:error, :no_event_id}` when called with `%EventNotification{id: nil}`
    (defensive — does NOT issue an HTTP request)

  ## Examples

      # From a parsed notification:
      {:ok, notif} = Webhook.parse_event_notification(payload, sig_header, secret)
      {:ok, %Event{} = event} = Webhook.fetch_event(client, notif)

      # From a bare ID:
      {:ok, %Event{}} = Webhook.fetch_event(client, "evt_test_65UIRNU7G1XbhCfOim416TgmEI4ASQ3jHxXt8RFwXoeVwO")
  """
  @spec fetch_event(Client.t(), EventNotification.t() | String.t(), keyword()) ::
          {:ok, Event.t()} | {:error, Error.t() | :no_event_id}
  # Defensive clause for malformed notifications.
  # Returns the typed error WITHOUT issuing an HTTP request.
  def fetch_event(%Client{} = _client, %EventNotification{id: nil}, _opts),
    do: {:error, :no_event_id}

  # Notification → extract id → delegate to bare-id clause.
  def fetch_event(%Client{} = client, %EventNotification{id: id}, opts) when is_binary(id),
    do: fetch_event(client, id, opts)

  # Bare-id clause: actual HTTP path.
  # Path is `/v2/core/events/#{id}` per RESEARCH Finding 3 — NOT `/v1/events/`
  # (which is what `Event.retrieve/3` calls for snapshot v1 events).
  def fetch_event(%Client{} = client, id, opts) when is_binary(id) do
    %Request{method: :get, path: "/v2/core/events/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&Event.from_map/1)
  end

  # 2-arity convenience: default opts to [].
  @spec fetch_event(Client.t(), EventNotification.t() | String.t()) ::
          {:ok, Event.t()} | {:error, Error.t() | :no_event_id}
  def fetch_event(%Client{} = client, notification_or_id),
    do: fetch_event(client, notification_or_id, [])

  @doc """
  Like `fetch_event/3` but raises on failure.

  Returns `%Event{}` on success. Raises `LatticeStripe.Error` on HTTP failure
  or on `{:error, :no_event_id}` (the typed atom is collapsed into a
  `%LatticeStripe.Error{type: :invalid_request_error}` for consistent
  exception semantics).
  """
  @spec fetch_event!(Client.t(), EventNotification.t() | String.t(), keyword()) :: Event.t()
  def fetch_event!(%Client{} = client, notification_or_id, opts \\ []) do
    case fetch_event(client, notification_or_id, opts) do
      {:ok, %Event{} = event} ->
        event

      {:error, %Error{} = err} ->
        raise err

      {:error, :no_event_id} ->
        raise %Error{
          type: :invalid_request_error,
          message: "EventNotification id is nil"
        }
    end
  end

  @doc """
  Retrieves the typed underlying resource referenced by a thin-event notification's
  `related_object`.

  Looks up the LatticeStripe module for `notification.related_object.type` in the
  internal object-type registry **before** issuing any HTTP request (Phase 47 D-05
  fail-fast contract). On a known type, issues a GET against the
  `notification.related_object.url` (Stripe ships the path verbatim) and decodes
  the response into the corresponding struct.

  ## Typed-error contract (Phase 47 D-05 + D-07)

  - `{:error, {:unknown_object_type, type}}` — `related_object.type` is not in
    `LatticeStripe.ObjectTypes.@object_map`. Stripe shipped a new resource type;
    opening a PR to add the module to the dispatch table resolves this. No HTTP
    request is issued in this case.
  - `{:error, :no_related_object}` — `notification.related_object == nil`
    (snapshot-style v2 events). Adopters should call `fetch_event/3` to retrieve
    the full `%Event{}` instead.
  - `{:error, %LatticeStripe.Error{}}` — standard HTTP failure (4xx/5xx,
    connection error, etc.).

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct (passed explicitly per D-04 —
    the notification carries no embedded credential material)
  - `notification` - An `%EventNotification{}` returned by
    `parse_event_notification/4`
  - `opts` - Per-request overrides:
    - `:expand` - list of paths to expand inline; reuses v1.2 expand machinery
      via `Client.request/2`
    - `:api_version` - per-request Stripe API version override
    - `:idempotency_key` - per-request idempotency key

  ## Returns

  - `{:ok, struct()}` - typed resource decoded via `ObjectTypes.maybe_deserialize/1`
  - `{:error, %LatticeStripe.Error{} | {:unknown_object_type, String.t()} | :no_related_object}`

  ## Example

      case Webhook.parse_event_notification(payload, sig_header, secret) do
        {:ok, %EventNotification{
           related_object: %RelatedObject{type: "customer"}
         } = notif} ->
          {:ok, %LatticeStripe.Customer{} = customer} =
            Webhook.fetch_related_object(client, notif)

          handle_customer_event(customer)

        {:ok, %EventNotification{related_object: nil} = notif} ->
          # No related object — fetch the full event instead.
          {:ok, %Event{}} = Webhook.fetch_event(client, notif)

        {:error, reason} ->
          Logger.error("verify failed: \#{inspect(reason)}")
      end
  """
  @spec fetch_related_object(Client.t(), EventNotification.t(), keyword()) ::
          {:ok, struct() | map()}
          | {:error, Error.t() | {:unknown_object_type, String.t()} | :no_related_object}
  # A missing related object returns a typed error without calling
  # ObjectTypes.fetch_module/1 or Client.request/2.
  def fetch_related_object(%Client{} = _client, %EventNotification{related_object: nil}, _opts),
    do: {:error, :no_related_object}

  # Gate unknown types before any HTTP request so they short-circuit
  # to {:error, {:unknown_object_type, type}} — Mox expectation count = 0.
  def fetch_related_object(
        %Client{} = client,
        %EventNotification{related_object: %RelatedObject{type: type, url: url}},
        opts
      ) do
    case ObjectTypes.fetch_module(type) do
      {:ok, _module} ->
        %Request{method: :get, path: url, params: %{}, opts: opts}
        |> then(&Client.request(client, &1))
        |> case do
          {:ok, %Response{data: raw}} -> {:ok, ObjectTypes.maybe_deserialize(raw)}
          {:error, %Error{}} = error -> error
        end

      :error ->
        {:error, {:unknown_object_type, type}}
    end
  end

  # 2-arity convenience: default opts to [].
  @spec fetch_related_object(Client.t(), EventNotification.t()) ::
          {:ok, struct() | map()}
          | {:error, Error.t() | {:unknown_object_type, String.t()} | :no_related_object}
  def fetch_related_object(%Client{} = client, %EventNotification{} = notif),
    do: fetch_related_object(client, notif, [])

  @doc """
  Like `fetch_related_object/3` but raises on failure.

  Collapses all error paths into `LatticeStripe.Error` for consistent exception
  semantics:

  - `{:error, %Error{}}` → raises the Error verbatim
  - `{:error, {:unknown_object_type, type}}` → raises
    `%Error{type: :invalid_request_error, message: "Unknown Stripe object type: \#{type}"}`
  - `{:error, :no_related_object}` → raises
    `%Error{type: :invalid_request_error, message: "EventNotification has no related_object"}`
  """
  @spec fetch_related_object!(Client.t(), EventNotification.t(), keyword()) :: struct() | map()
  def fetch_related_object!(%Client{} = client, %EventNotification{} = notif, opts \\ []) do
    case fetch_related_object(client, notif, opts) do
      {:ok, obj} ->
        obj

      {:error, %Error{} = err} ->
        raise err

      {:error, {:unknown_object_type, type}} ->
        raise %Error{
          type: :invalid_request_error,
          message: "Unknown Stripe object type: #{type}"
        }

      {:error, :no_related_object} ->
        raise %Error{
          type: :invalid_request_error,
          message: "EventNotification has no related_object"
        }
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

      if signatures_match?(computed, signatures) do
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

  # Private helpers

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
  # `tolerance: 0` disables the staleness check entirely, matching the docstring at
  # `:tolerance` and every
  # canonical Stripe SDK — stripe-node's `if (tolerance > 0 && ...)` gate and
  # stripe-go's `IgnoreTolerance` flag. Use this in tests (with `:timestamp`
  # overrides via `generate_test_signature/3`); never in production traffic —
  # the canonical Phoenix guide states this explicitly.
  # Inline comment is load-bearing for the four-surface regression contract.
  defp check_tolerance(_timestamp, 0), do: :ok

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

  # Checks whether any computed signature matches any received signature.
  # Timing-safe comparison via Plug.Crypto.secure_compare/2.
  defp signatures_match?(computed, signatures) do
    Enum.any?(computed, fn computed_sig ->
      Enum.any?(signatures, &Plug.Crypto.secure_compare(computed_sig, &1))
    end)
  end

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
