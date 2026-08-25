defmodule LatticeStripe.ClientCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias LatticeStripe.{Client, Request}

  using do
    quote do
      import Mox
      import LatticeStripe.ClientCase

      alias LatticeStripe.{Client, Error, Request, Response}

      setup :verify_on_exit!
    end
  end

  def test_client(overrides \\ []) do
    defaults = [
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false
    ]

    Client.new!(Keyword.merge(defaults, overrides))
  end

  def retry_client(overrides \\ []) do
    defaults = [max_retries: 2, retry_strategy: LatticeStripe.MockRetryStrategy]
    test_client(Keyword.merge(defaults, overrides))
  end

  def ok_response(body \\ %{"id" => "obj_123", "object" => "charge"}) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_test_123"}],
       body: Jason.encode!(body)
     }}
  end

  def error_response(status, type, message, extra_headers \\ []) do
    body = %{
      "error" => %{
        "type" => type,
        "message" => message,
        "code" => "some_code"
      }
    }

    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_err_456"}] ++ extra_headers,
       body: Jason.encode!(body)
     }}
  end

  def non_json_response(status, body) do
    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_html_789"}],
       body: body
     }}
  end

  def get_request(path \\ "/v1/customers/cus_123", opts \\ []) do
    %Request{method: :get, path: path, params: %{}, opts: opts}
  end

  def post_request(path \\ "/v1/charges", params \\ %{}, opts \\ []) do
    %Request{method: :post, path: path, params: params, opts: opts}
  end

  def delete_request(path \\ "/v1/customers/cus_123", opts \\ []) do
    %Request{method: :delete, path: path, params: %{}, opts: opts}
  end
end
