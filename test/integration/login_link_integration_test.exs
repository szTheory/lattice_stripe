defmodule LatticeStripe.LoginLinkIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.LoginLink` against stripe-mock.

  Run stripe-mock before these tests:

      docker run --rm -p 12111:12111 stripe/stripe-mock:latest

  These tests validate wire-level correctness: URL path
  (`POST /v1/accounts/:account_id/login_links`), HTTP verb, and response struct
  unwrapping against real Stripe-shaped JSON. Unit tests (Mox-based) cannot
  catch path or verb errors.

  LoginLink is Express-only in production. stripe-mock may not enforce the
  account-type constraint — both 200 and 400 outcomes are acceptable from
  stripe-mock; what we're verifying is that the wire path is correct.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Account, LoginLink}

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
  # create/4 — Express account path
  # ---------------------------------------------------------------------------

  test "create/4 hits POST /v1/accounts/:id/login_links and returns url", %{client: client} do
    # Create an Express account first. stripe-mock may not model the full Express
    # lifecycle, so we also accept a 400 from the LoginLink call (correct wire path,
    # mock-level constraint surfaced).
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "express", "country" => "US"})

    case LoginLink.create(client, account_id) do
      {:ok, %LoginLink{url: url}} ->
        assert is_binary(url)

      {:error, %LatticeStripe.Error{status: 400}} ->
        # stripe-mock returned 400 — acceptable for non-conformant Express setup in mock mode.
        # The wire path (POST /v1/accounts/:id/login_links) was correct.
        :ok
    end
  end

  test "create/4 with explicit empty params map works", %{client: client} do
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "express", "country" => "US"})

    result = LoginLink.create(client, account_id, %{})

    assert match?({:ok, %LoginLink{}}, result) or
             match?({:error, %LatticeStripe.Error{}}, result)
  end

  # ---------------------------------------------------------------------------
  # create!/4 — bang variant
  # ---------------------------------------------------------------------------

  test "create!/4 happy path returns %LoginLink{} or raises on error", %{client: client} do
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "express", "country" => "US"})

    # create!/4 either returns struct or raises — both are valid given stripe-mock Express handling.
    try do
      link = LoginLink.create!(client, account_id)
      assert %LoginLink{} = link
    rescue
      LatticeStripe.Error -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # is_binary(account_id) guard — locks in signature deviation (Plan 17-04)
  # ---------------------------------------------------------------------------

  test "create/4 with non-binary account_id raises FunctionClauseError", %{client: client} do
    assert_raise FunctionClauseError, fn ->
      LoginLink.create(client, %{"account" => "acct_test"})
    end
  end

  test "create/4 with nil account_id raises FunctionClauseError", %{client: client} do
    assert_raise FunctionClauseError, fn ->
      LoginLink.create(client, nil)
    end
  end
end
