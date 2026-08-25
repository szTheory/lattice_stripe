defmodule LatticeStripe.Client.ResponseDecoder do
  @moduledoc false

  alias LatticeStripe.{Client, Error, List, Response}

  def decode(%Client{} = client, status, headers, body, params, request_opts) do
    request_id = request_id(headers)

    case client.json_codec.decode(body) do
      {:ok, decoded} ->
        decoded_response(status, decoded, request_id, headers, params, request_opts)

      {:error, _decode_error} ->
        non_json_error(status, body, request_id, headers)
    end
  end

  def decode_download(%Client{} = client, status, headers, body) do
    if status in 200..299 do
      {:ok,
       %Response{data: body, status: status, headers: headers, request_id: request_id(headers)}}
    else
      decode(client, status, headers, body, %{}, [])
    end
  end

  defp decoded_response(status, decoded, request_id, headers, params, request_opts) do
    if status in 200..299 do
      data =
        case decoded["object"] do
          type when type in ["list", "search_result"] ->
            List.from_json(decoded, params, request_opts)

          _ ->
            decoded
        end

      {:ok, %Response{data: data, status: status, headers: headers, request_id: request_id}}
    else
      {:error, Error.from_response(status, decoded, request_id, headers), headers}
    end
  end

  defp non_json_error(status, body, request_id, headers) do
    error = %Error{
      type: :api_error,
      code: nil,
      message: "Non-JSON response from Stripe API (HTTP #{status})",
      status: status,
      request_id: request_id,
      raw_body: %{"_raw" => truncate_body(body, 500)},
      headers: headers,
      retry_after: Error.from_response(status, %{}, request_id, headers).retry_after
    }

    {:error, error, headers}
  end

  defp truncate_body(nil, _max), do: ""
  defp truncate_body("", _max), do: ""
  defp truncate_body(body, max) when byte_size(body) <= max, do: body
  defp truncate_body(body, max), do: binary_part(body, 0, max) <> "..."

  defp request_id(headers) do
    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(name) == "request-id", do: value
    end)
  end
end
