defmodule LatticeStripe.Billing.MeterEventStream do
  @moduledoc """
  Stripe v2 Billing Meter Event Stream — high-throughput session-token API.

  Unlike other LatticeStripe modules, `MeterEventStream` bypasses the standard
  `Client` request pipeline. The v2 event stream uses a different authentication model
  (short-lived session tokens instead of API keys) and a different host
  (`meter-events.stripe.com` instead of `api.stripe.com`). This module calls
  `client.transport.request/1` directly with the appropriate headers.

  ## Two-Step Usage

  1. Create a session (uses your API key, returns a 15-minute token):

      {:ok, session} = MeterEventStream.create_session(client)

  2. Send event batches within the session (uses the session token):

      events = [
        %{"event_name" => "api_call", "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"}},
        %{"event_name" => "api_call", "payload" => %{"stripe_customer_id" => "cus_456", "value" => "3"}}
      ]

      {:ok, %{}} = MeterEventStream.send_events(client, session, events)

  ## Session Expiry

  Sessions expire 15 minutes after creation. `send_events/4` checks
  `session.expires_at` before each call and returns `{:error, :session_expired}`
  immediately if the session has expired — saving a network round-trip.

  If the server returns a 401 with code `billing_meter_event_session_expired`
  (e.g., due to clock skew), it is also normalized to `{:error, :session_expired}`.

  There is no automatic session renewal. Call `create_session/2` again to obtain
  a fresh session.

  ## Differences from v1 MeterEvent

  | Aspect | v1 `MeterEvent.create/3` | v2 `MeterEventStream.send_events/4` |
  |--------|--------------------------|--------------------------------------|
  | Auth | API key (Bearer) | Session token (Bearer) |
  | Host | `api.stripe.com` | `meter-events.stripe.com` |
  | Encoding | form-urlencoded | JSON |
  | Batch | Single event | Up to 100 events |
  | Response | Returns event object | Returns empty `%{}` |

  See `guides/metering.md` for the complete metering guide including v1 and v2 patterns.
  """

  alias LatticeStripe.Billing.MeterEventStream.Session
  alias LatticeStripe.{Client, Error}

  @version Mix.Project.config()[:version]

  @session_url "https://api.stripe.com/v2/billing/meter_event_session"
  @stream_url "https://meter-events.stripe.com/v2/billing/meter_event_stream"

  @doc """
  Create a short-lived meter event stream session.

  Returns a `%Session{}` struct containing an `authentication_token` valid for
  15 minutes. Pass this session to `send_events/4` to send event batches.

  ## Opts

    - `:timeout` — HTTP request timeout in milliseconds (default: `client.timeout`)

  ## Return value

    - `{:ok, %Session{}}` — session created successfully
    - `{:error, %Error{}}` — Stripe API error or connection error

  ## Example

      {:ok, session} = MeterEventStream.create_session(client)
      # session.authentication_token is the bearer credential for send_events/4
      # session.expires_at is a Unix timestamp (created + 900 seconds)
  """
  @spec create_session(Client.t(), keyword()) ::
          {:ok, Session.t()} | {:error, Error.t()}
  def create_session(%Client{} = client, opts \\ []) do
    telemetry_wrap(client, [:lattice_stripe, :meter_event_stream, :create_session], fn ->
      do_create_session(client, opts)
    end)
  end

  @doc """
  Send a batch of meter events within an active session.

  ## Params

    - `client` — `%Client{}` (used for transport, json_codec, finch, timeout)
    - `session` — `%Session{}` from `create_session/2`
    - `events` — non-empty list of event maps, each with:
      - `"event_name"` (required) — must match a `Billing.Meter.event_name`
      - `"payload"` (required) — map with customer mapping key and value
      - `"identifier"` (optional) — deduplication UUID
      - `"timestamp"` (optional) — Unix timestamp or ISO 8601 string

  ## Opts

    - `:timeout` — HTTP request timeout in milliseconds (default: `client.timeout`)

  ## Return value

    - `{:ok, %{}}` — events accepted (fire-and-forget; no per-event response)
    - `{:error, :session_expired}` — session token has expired (client-side or server-side)
    - `{:error, %Error{}}` — Stripe API error, validation error, or connection error

  ## Example

      events = [
        %{"event_name" => "api_call", "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"}}
      ]

      case MeterEventStream.send_events(client, session, events) do
        {:ok, %{}} -> :sent
        {:error, :session_expired} -> # create a new session
        {:error, %Error{} = err} -> # handle error
      end
  """
  @spec send_events(Client.t(), Session.t(), [map()], keyword()) ::
          {:ok, map()} | {:error, :session_expired} | {:error, Error.t()}
  def send_events(%Client{} = client, %Session{} = session, events, opts \\ [])
      when is_list(events) do
    with :ok <- validate_events(events),
         :ok <- check_expiry(session) do
      telemetry_wrap(client, [:lattice_stripe, :meter_event_stream, :send_events], fn ->
        do_send_events(client, session, events, opts)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — session create implementation
  # ---------------------------------------------------------------------------

  defp do_create_session(client, opts) do
    headers = [
      {"authorization", "Bearer #{client.api_key}"},
      {"stripe-version", client.api_version},
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"user-agent",
       "LatticeStripe/#{@version} elixir/#{System.version()} otp/#{System.otp_release()}"}
    ]

    transport_request = %{
      method: :post,
      url: @session_url,
      headers: headers,
      body: "{}",
      opts: [finch: client.finch, timeout: Keyword.get(opts, :timeout, client.timeout)]
    }

    case client.transport.request(transport_request) do
      {:ok, %{status: 200, body: body}} ->
        case client.json_codec.decode(body) do
          {:ok, decoded} -> {:ok, Session.from_map(decoded)}
          {:error, _} -> {:error, %Error{type: :api_error, message: "Non-JSON response"}}
        end

      {:ok, %{status: status, body: body}} ->
        decode_error(client, status, body)

      {:error, reason} ->
        {:error, %Error{type: :connection_error, message: inspect(reason)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — send events implementation
  # ---------------------------------------------------------------------------

  defp do_send_events(client, session, events, opts) do
    headers = [
      {"authorization", "Bearer #{session.authentication_token}"},
      {"stripe-version", client.api_version},
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"user-agent",
       "LatticeStripe/#{@version} elixir/#{System.version()} otp/#{System.otp_release()}"}
    ]

    body = client.json_codec.encode!(%{"events" => events})

    transport_request = %{
      method: :post,
      url: @stream_url,
      headers: headers,
      body: body,
      opts: [finch: client.finch, timeout: Keyword.get(opts, :timeout, client.timeout)]
    }

    case client.transport.request(transport_request) do
      {:ok, %{status: 200, body: resp_body}} ->
        case client.json_codec.decode(resp_body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, %Error{type: :api_error, message: "Non-JSON response"}}
        end

      {:ok, %{status: 401, body: resp_body}} ->
        handle_401(client, resp_body)

      {:ok, %{status: status, body: resp_body}} ->
        decode_error(client, status, resp_body)

      {:error, reason} ->
        {:error, %Error{type: :connection_error, message: inspect(reason)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_events([]) do
    {:error, %Error{type: :invalid_request_error, message: "events list cannot be empty"}}
  end

  defp validate_events(events) when is_list(events), do: :ok

  defp check_expiry(%Session{expires_at: expires_at}) when is_integer(expires_at) do
    if System.system_time(:second) >= expires_at do
      {:error, :session_expired}
    else
      :ok
    end
  end

  defp check_expiry(%Session{expires_at: nil}), do: :ok

  defp handle_401(client, body) do
    case client.json_codec.decode(body) do
      {:ok, %{"error" => %{"code" => "billing_meter_event_session_expired"}}} ->
        {:error, :session_expired}

      {:ok, decoded} ->
        {:error, Error.from_response(401, decoded, nil)}

      {:error, _} ->
        {:error, %Error{type: :authentication_error, status: 401, message: "Unauthorized"}}
    end
  end

  defp decode_error(client, status, body) do
    case client.json_codec.decode(body) do
      {:ok, decoded} -> {:error, Error.from_response(status, decoded, nil)}
      {:error, _} -> {:error, %Error{type: :api_error, status: status, message: "Non-JSON response"}}
    end
  end

  defp telemetry_wrap(client, event_name, fun) do
    if client.telemetry_enabled do
      :telemetry.span(event_name, %{}, fn ->
        result = fun.()
        stop_meta = %{status: if(match?({:ok, _}, result), do: :ok, else: :error)}
        {result, stop_meta}
      end)
    else
      fun.()
    end
  end
end
