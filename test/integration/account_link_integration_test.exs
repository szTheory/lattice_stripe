defmodule LatticeStripe.AccountLinkIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.AccountLink` against stripe-mock.

  Run stripe-mock before these tests:

      docker run --rm -p 12111:12111 stripe/stripe-mock:latest

  These tests validate wire-level correctness: URL path (`POST /v1/account_links`),
  HTTP verb, form-encoded body shape, and response struct unwrapping against real
  Stripe-shaped JSON. Unit tests (Mox-based) cannot catch path or verb errors.

  stripe-mock validates against the Stripe OpenAPI spec and returns canned responses.
  Assertions check SHAPE (is_binary, String.starts_with?) not SEMANTICS.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Account, AccountLink, Error}

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  # ---------------------------------------------------------------------------
  # create/3 — happy path
  # ---------------------------------------------------------------------------

  test "create/3 with all required params returns %AccountLink{} with url and expires_at", %{
    client: client
  } do
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    assert {:ok, %AccountLink{url: url, expires_at: expires_at}} =
             AccountLink.create(client, %{
               "account" => account_id,
               "type" => "account_onboarding",
               "refresh_url" => "https://example.test/connect/refresh",
               "return_url" => "https://example.test/connect/return"
             })

    assert is_binary(url)
    assert String.starts_with?(url, "https://")
    assert is_integer(expires_at)
  end

  test "create/3 returns %AccountLink{} struct with correct object field", %{client: client} do
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    assert {:ok, %AccountLink{} = link} =
             AccountLink.create(client, %{
               "account" => account_id,
               "type" => "account_onboarding",
               "refresh_url" => "https://example.test/connect/refresh",
               "return_url" => "https://example.test/connect/return"
             })

    assert link.object == "account_link"
    assert is_integer(link.created)
  end

  # ---------------------------------------------------------------------------
  # create!/3 — bang variant
  # ---------------------------------------------------------------------------

  test "create!/3 happy path returns %AccountLink{} directly", %{client: client} do
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    link =
      AccountLink.create!(client, %{
        "account" => account_id,
        "type" => "account_onboarding",
        "refresh_url" => "https://example.test/connect/refresh",
        "return_url" => "https://example.test/connect/return"
      })

    assert %AccountLink{} = link
    assert is_binary(link.url)
  end

  # ---------------------------------------------------------------------------
  # D-04c: missing `type` param — let Stripe 400 flow through
  # ---------------------------------------------------------------------------

  test "create/3 missing required type param surfaces Stripe error or succeeds (stripe-mock validation varies)",
       %{client: client} do
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    result =
      AccountLink.create(client, %{
        "account" => account_id,
        "refresh_url" => "https://example.test/connect/refresh",
        "return_url" => "https://example.test/connect/return"
        # intentionally omitting "type"
      })

    # D-04c: we do NOT client-side validate. Stripe's own error flows through.
    # stripe-mock may or may not enforce this field — both outcomes are valid here.
    assert match?({:ok, %AccountLink{}}, result) or
             match?({:error, %Error{type: :invalid_request_error}}, result)
  end
end
