defmodule LatticeStripe.Client.Executor do
  @moduledoc false

  alias LatticeStripe.{Client, Error, Response}
  alias LatticeStripe.Client.ResponseDecoder

  def request(%Client{} = client, transport_request, method, idempotency_key, max_retries) do
    retry_state = retry_state(method, idempotency_key, max_retries, :request)
    execute_with_retries(client, transport_request, retry_state)
  end

  def download(%Client{} = client, transport_request, method, idempotency_key, max_retries) do
    retry_state = retry_state(method, idempotency_key, max_retries, :download)
    execute_with_retries(client, transport_request, retry_state)
  end

  defp execute_with_retries(client, transport_request, retry_state) do
    case execute(client, transport_request, retry_state.kind) do
      {:ok, %Response{} = response} = success ->
        {success, retry_state.total_attempts, response.headers}

      {:error, %Error{} = error, response_headers} ->
        maybe_retry(client, transport_request, retry_state, error, response_headers)
    end
  end

  defp maybe_retry(client, transport_request, retry_state, error, response_headers) do
    if retry_state.attempt <= retry_state.max_retries do
      context = %{
        error: error,
        status: error.status,
        headers: response_headers,
        stripe_should_retry: parse_stripe_should_retry(response_headers),
        method: retry_state.method,
        idempotency_key: retry_state.idempotency_key
      }

      apply_retry_decision(client, transport_request, retry_state, error, context)
    else
      {{:error, error}, retry_state.total_attempts, response_headers}
    end
  end

  defp apply_retry_decision(client, transport_request, retry_state, error, context) do
    case client.retry_strategy.retry?(retry_state.attempt, context) do
      {:retry, delay_ms} ->
        LatticeStripe.Telemetry.emit_retry(
          client,
          retry_state.method,
          transport_request.url,
          error,
          retry_state.attempt,
          delay_ms
        )

        Process.sleep(delay_ms)

        next_retry_state = %{
          retry_state
          | attempt: retry_state.attempt + 1,
            total_attempts: retry_state.total_attempts + 1
        }

        execute_with_retries(client, transport_request, next_retry_state)

      :stop ->
        {{:error, error}, retry_state.total_attempts, context.headers}
    end
  end

  defp execute(client, transport_request, :request) do
    params = Map.get(transport_request, :_params, %{})
    request_opts = Map.get(transport_request, :_req_opts, [])

    case client.transport.request(transport_request) do
      {:ok, %{status: status, headers: headers, body: body}} ->
        ResponseDecoder.decode(client, status, headers, body, params, request_opts)

      {:error, reason} ->
        connection_error(reason)
    end
  end

  defp execute(client, transport_request, :download) do
    case client.transport.request(transport_request) do
      {:ok, %{status: status, headers: headers, body: body}} ->
        ResponseDecoder.decode_download(client, status, headers, body)

      {:error, reason} ->
        connection_error(reason)
    end
  end

  defp connection_error(reason) do
    {:error, %Error{type: :connection_error, message: inspect(reason)}, []}
  end

  defp retry_state(method, idempotency_key, max_retries, kind) do
    %{
      method: method,
      idempotency_key: idempotency_key,
      max_retries: max_retries,
      attempt: 1,
      total_attempts: 1,
      kind: kind
    }
  end

  defp parse_stripe_should_retry(headers) do
    value =
      Enum.find_value(headers, fn {name, value} ->
        if String.downcase(name) == "stripe-should-retry", do: value
      end)

    case value do
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end
end
