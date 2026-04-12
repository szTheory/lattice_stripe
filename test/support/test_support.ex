defmodule LatticeStripe.TestSupport do
  @moduledoc false

  alias LatticeStripe.Client

  def test_client(overrides \\ []) do
    defaults = [
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false,
      max_retries: 0
    ]

    Client.new!(Keyword.merge(defaults, overrides))
  end

  def test_integration_client(overrides \\ []) do
    defaults = [
      api_key: "sk_test_123",
      base_url: "http://localhost:12111",
      finch: LatticeStripe.IntegrationFinch,
      transport: LatticeStripe.Transport.Finch,
      telemetry_enabled: false,
      max_retries: 0
    ]

    Client.new!(Keyword.merge(defaults, overrides))
  end

  def ok_response(body) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_test"}],
       body: Jason.encode!(body)
     }}
  end

  def error_response do
    {:ok,
     %{
       status: 400,
       headers: [{"request-id", "req_err"}],
       body:
         Jason.encode!(%{
           "error" => %{
             "type" => "invalid_request_error",
             "message" => "bad request"
           }
         })
     }}
  end

  def list_json(items, url \\ "/v1/objects") do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => url
    }
  end
end
