defmodule LatticeStripe.AccountIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Account` against stripe-mock.

  Run stripe-mock before these tests:

      docker run --rm -p 12111:12111 stripe/stripe-mock:latest

  These tests validate wire-level correctness that unit tests cannot cover:
  URL paths, HTTP verbs, form-encoded body shapes, and Response/List
  unwrapping against real Stripe-shaped JSON responses.

  stripe-mock is stateless — it validates against the OpenAPI spec and returns
  canned-but-randomized responses. Assertions check SHAPE (structs, `is_binary(id)`)
  not SEMANTICS (actual status transitions). See 17-VALIDATION.md for details.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Account
  alias LatticeStripe.Account.{BusinessProfile, Capability}

  # Guard: stripe-mock must be reachable on localhost:12111.
  # Start the Finch pool used by `test_integration_client/0`.
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
  # create
  # ---------------------------------------------------------------------------

  test "create/3 with minimal params returns %Account{} with populated id", %{client: client} do
    assert {:ok, %Account{id: id} = account} =
             Account.create(client, %{
               "type" => "custom",
               "country" => "US",
               "email" => "test-phase17@acme.test"
             })

    assert is_binary(id)
    assert String.starts_with?(id, "acct_")
    assert %Account{} = account
  end

  # ---------------------------------------------------------------------------
  # retrieve
  # ---------------------------------------------------------------------------

  test "retrieve/3 by id returns %Account{} with matching id", %{client: client} do
    {:ok, %Account{id: id}} =
      Account.create(client, %{
        "type" => "custom",
        "country" => "US"
      })

    assert {:ok, %Account{id: ^id}} = Account.retrieve(client, id)
  end

  # ---------------------------------------------------------------------------
  # update
  # ---------------------------------------------------------------------------

  test "update/4 with metadata returns %Account{}", %{client: client} do
    {:ok, %Account{id: id}} =
      Account.create(client, %{
        "type" => "custom",
        "country" => "US"
      })

    assert {:ok, %Account{}} =
             Account.update(client, id, %{
               "metadata" => %{"phase" => "17"}
             })
  end

  # ---------------------------------------------------------------------------
  # list + stream!
  # ---------------------------------------------------------------------------

  test "list/3 with limit returns %Response{data: %List{data: [%Account{}]}}", %{client: client} do
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
             Account.list(client, %{"limit" => 3})

    assert is_list(data)
    Enum.each(data, fn account -> assert %Account{} = account end)
  end

  test "stream!/3 composes with Enum.take/2 yielding %Account{} structs", %{client: client} do
    accounts = Account.stream!(client) |> Enum.take(2)
    assert length(accounts) <= 2
    Enum.each(accounts, fn account -> assert %Account{} = account end)
  end

  # ---------------------------------------------------------------------------
  # reject — REJECT_SUPPORTED=true per 17-VALIDATION.md (scripts/verify_stripe_mock_reject.exs)
  # ---------------------------------------------------------------------------

  test "reject/4 with :fraud hits POST /v1/accounts/:id/reject", %{client: client} do
    {:ok, %Account{id: id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    # stripe-mock confirmed to support /v1/accounts/:id/reject (see 17-VALIDATION.md).
    # REJECT_SUPPORTED=true verified on 2026-04-12 via scripts/verify_stripe_mock_reject.exs.
    assert {:ok, %Account{}} = Account.reject(client, id, :fraud)
  end

  test "reject/4 atom guard rejects unknown reason with FunctionClauseError", %{client: client} do
    # This guard fires before any HTTP call — purely structural. Including here
    # alongside the reject wire test to keep all reject semantics in one place.
    assert_raise FunctionClauseError, fn ->
      Account.reject(client, "acct_test", :not_a_real_reason)
    end
  end

  # ---------------------------------------------------------------------------
  # delete
  # ---------------------------------------------------------------------------

  test "delete/3 returns %Account{} with extra[\"deleted\"] == true", %{client: client} do
    {:ok, %Account{id: id}} =
      Account.create(client, %{
        "type" => "custom",
        "country" => "US"
      })

    assert {:ok, %Account{extra: extra}} = Account.delete(client, id)
    assert extra["deleted"] == true
  end

  # ---------------------------------------------------------------------------
  # nested struct casting via live fetch
  # ---------------------------------------------------------------------------

  test "business_profile and capabilities are typed structs after retrieve", %{client: client} do
    {:ok, %Account{id: id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    {:ok, %Account{} = account} = Account.retrieve(client, id)

    # stripe-mock may return a sparse account — only assert shape when populated
    if account.business_profile do
      assert %BusinessProfile{} = account.business_profile
    end

    if is_map(account.capabilities) and map_size(account.capabilities) > 0 do
      [{_name, capability} | _] = Enum.take(account.capabilities, 1)
      assert %Capability{} = capability
    end
  end
end
