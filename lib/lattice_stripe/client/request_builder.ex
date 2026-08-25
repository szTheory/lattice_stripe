defmodule LatticeStripe.Client.RequestBuilder do
  @moduledoc false

  alias LatticeStripe.{Client, FormEncoder, MultipartEncoder, Request}

  @version Mix.Project.config()[:version]

  def build(%Client{} = client, %Request{} = request) do
    api_key = Keyword.get(request.opts, :api_key, client.api_key)
    api_version = Keyword.get(request.opts, :stripe_version, client.api_version)
    stripe_account = Keyword.get(request.opts, :stripe_account, client.stripe_account)
    max_retries = Keyword.get(request.opts, :max_retries, client.max_retries)
    timeout = resolve_request_timeout(client, request)
    params = merge_expand(request.params, Keyword.get(request.opts, :expand, []))
    idempotency_key = resolve_idempotency_key(request.method, request.opts)
    {url, body} = build_url_and_body(client.base_url, request.method, request.path, params)

    headers =
      build_headers(
        request.method,
        api_key,
        api_version,
        stripe_account,
        idempotency_key
      )

    transport_request = %{
      method: request.method,
      url: url,
      headers: headers,
      body: body,
      opts: [finch: client.finch, timeout: timeout],
      _params: params,
      _req_opts: request.opts
    }

    {transport_request, idempotency_key, max_retries}
  end

  def build_upload(%Client{} = client, file_binary, params, opts)
      when is_binary(file_binary) do
    filename = Map.get(params, "filename", "upload")
    string_fields = Map.drop(params, ["filename"])

    {body, boundary} =
      MultipartEncoder.encode(
        file_binary,
        filename,
        string_fields,
        Keyword.take(opts, [:boundary])
      )

    idempotency_key = resolve_idempotency_key(:post, opts)
    api_key = Keyword.get(opts, :api_key, client.api_key)
    api_version = Keyword.get(opts, :stripe_version, client.api_version)
    stripe_account = Keyword.get(opts, :stripe_account, client.stripe_account)
    max_retries = Keyword.get(opts, :max_retries, client.max_retries)
    timeout = resolve_timeout(client, :upload, opts)

    headers =
      build_headers(:post, api_key, api_version, stripe_account, idempotency_key)
      |> replace_content_type("multipart/form-data; boundary=#{boundary}")

    transport_request = %{
      method: :post,
      url: client.files_base_url <> "/v1/files",
      headers: headers,
      body: body,
      opts: [finch: client.finch, timeout: timeout]
    }

    telemetry_request = %Request{method: :post, path: "/v1/files", params: params, opts: opts}

    {transport_request, telemetry_request, idempotency_key, max_retries}
  end

  def build_download(%Client{} = client, path, opts) when is_binary(path) do
    api_key = Keyword.get(opts, :api_key, client.api_key)
    api_version = Keyword.get(opts, :stripe_version, client.api_version)
    stripe_account = Keyword.get(opts, :stripe_account, client.stripe_account)
    max_retries = Keyword.get(opts, :max_retries, client.max_retries)
    timeout = resolve_timeout(client, :download, opts)

    transport_request = %{
      method: :get,
      url: client.base_url <> path,
      headers: build_headers(:get, api_key, api_version, stripe_account, nil),
      body: nil,
      opts: [finch: client.finch, timeout: timeout]
    }

    telemetry_request = %Request{method: :get, path: path, params: %{}, opts: opts}

    {transport_request, telemetry_request, max_retries}
  end

  defp resolve_request_timeout(client, request) do
    case Keyword.fetch(request.opts, :timeout) do
      {:ok, timeout} ->
        timeout

      :error ->
        case client.operation_timeouts do
          %{} = timeouts -> Map.get(timeouts, classify_operation(request), client.timeout)
          nil -> client.timeout
        end
    end
  end

  defp resolve_timeout(client, operation, opts) do
    case Keyword.fetch(opts, :timeout) do
      {:ok, timeout} ->
        timeout

      :error ->
        case client.operation_timeouts do
          %{} = timeouts -> Map.get(timeouts, operation, client.timeout)
          nil -> client.timeout
        end
    end
  end

  defp resolve_idempotency_key(method, opts) do
    case Keyword.get(opts, :idempotency_key) do
      nil when method == :post -> "idk_ltc_" <> uuid4()
      nil -> nil
      key -> key
    end
  end

  defp uuid4 do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)

    <<a::48, 4::4, b::12, 2::2, c::62>>
    |> encode_uuid()
  end

  defp encode_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    [
      Base.encode16(<<a::32>>, case: :lower),
      "-",
      Base.encode16(<<b::16>>, case: :lower),
      "-",
      Base.encode16(<<c::16>>, case: :lower),
      "-",
      Base.encode16(<<d::16>>, case: :lower),
      "-",
      Base.encode16(<<e::48>>, case: :lower)
    ]
    |> IO.iodata_to_binary()
  end

  defp build_headers(method, api_key, api_version, stripe_account, idempotency_key) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"stripe-version", api_version},
      {"user-agent",
       "LatticeStripe/#{@version} elixir/#{System.version()} otp/#{System.otp_release()}"},
      {"x-stripe-client-user-agent", client_user_agent_json()},
      {"accept", "application/json"}
    ]

    headers
    |> maybe_add_content_type(method)
    |> maybe_add_stripe_account(stripe_account)
    |> maybe_add_idempotency_key(idempotency_key)
  end

  defp client_user_agent_json do
    %{
      "bindings_version" => @version,
      "lang" => "elixir",
      "lang_version" => System.version(),
      "publisher" => "lattice_stripe",
      "otp_version" => System.otp_release()
    }
    |> Jason.encode!()
  end

  defp maybe_add_content_type(headers, method) when method in [:post, :put, :patch] do
    [{"content-type", "application/x-www-form-urlencoded"} | headers]
  end

  defp maybe_add_content_type(headers, _method), do: headers
  defp maybe_add_stripe_account(headers, nil), do: headers
  defp maybe_add_stripe_account(headers, account), do: [{"stripe-account", account} | headers]
  defp maybe_add_idempotency_key(headers, nil), do: headers
  defp maybe_add_idempotency_key(headers, key), do: [{"idempotency-key", key} | headers]

  defp replace_content_type(headers, content_type) do
    headers
    |> Enum.reject(fn {name, _value} -> String.downcase(name) == "content-type" end)
    |> then(&[{"content-type", content_type} | &1])
  end

  defp build_url_and_body(base_url, method, path, params)
       when method in [:post, :put, :patch] do
    {base_url <> path, FormEncoder.encode(params)}
  end

  defp build_url_and_body(base_url, _method, path, params) do
    case FormEncoder.encode(params) do
      "" -> {base_url <> path, nil}
      encoded -> {base_url <> path <> "?" <> encoded, nil}
    end
  end

  defp merge_expand(params, []), do: params

  defp merge_expand(params, expand) when is_list(expand) do
    expand_map =
      expand
      |> Enum.with_index()
      |> Enum.into(%{}, fn {value, index} -> {index, value} end)

    Map.put(params, "expand", expand_map)
  end

  defp classify_operation(%Request{method: method, path: path}) do
    segments =
      path
      |> String.replace_prefix("/v1/", "")
      |> String.replace_prefix("/v1", "")
      |> String.split("/", trim: true)

    case {method, segments} do
      {:get, [_resource]} -> :list
      {:get, [_resource, "search"]} -> :search
      {:get, [_resource, _id]} -> :retrieve
      {:post, [_resource]} -> :create
      {:post, [_resource, _id]} -> :update
      {:delete, [_resource, _id]} -> :delete
      _ -> :other
    end
  end
end
