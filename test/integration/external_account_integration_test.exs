defmodule LatticeStripe.ExternalAccountIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.ExternalAccount` against stripe-mock.

  Run stripe-mock before these tests:

      docker run --rm -p 12111:12111 stripe/stripe-mock:latest

  stripe-mock is stateless — these assertions check SHAPE (structs, `is_binary(id)`)
  not SEMANTICS. The dispatcher on `object` is the thing under test; stripe-mock
  is free to canonicalise its response regardless of the input token.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Account, BankAccount, Card, ExternalAccount}
  alias LatticeStripe.ExternalAccount.Unknown

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
    {:ok, account_id: create_account!(), client: test_integration_client()}
  end

  defp create_account! do
    client = test_integration_client()

    {:ok, %Account{id: id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    id
  end

  defp assert_ea(ea) do
    case ea do
      %BankAccount{} -> :ok
      %Card{} -> :ok
      %Unknown{} -> :ok
    end
  end

  describe "create/4 dispatcher" do
    test "returns a typed external account struct (bank token)", %{
      client: client,
      account_id: account_id
    } do
      assert {:ok, ea} =
               ExternalAccount.create(client, account_id, %{"external_account" => "btok_us"})

      assert_ea(ea)
    end

    test "returns a typed external account struct (debit card token)", %{
      client: client,
      account_id: account_id
    } do
      assert {:ok, ea} =
               ExternalAccount.create(client, account_id, %{
                 "external_account" => "tok_visa_debit"
               })

      assert_ea(ea)
    end
  end

  describe "retrieve/4, update/5, delete/4" do
    test "round-trips through the dispatcher", %{client: client, account_id: account_id} do
      {:ok, ea} =
        ExternalAccount.create(client, account_id, %{"external_account" => "btok_us"})

      ea_id = ea_id(ea)
      assert is_binary(ea_id)

      assert {:ok, got} = ExternalAccount.retrieve(client, account_id, ea_id)
      assert_ea(got)

      assert {:ok, updated} =
               ExternalAccount.update(client, account_id, ea_id, %{
                 "metadata" => %{"k" => "v"}
               })

      assert_ea(updated)

      assert {:ok, deleted} = ExternalAccount.delete(client, account_id, ea_id)
      assert deleted_extra(deleted)["deleted"] == true
    end
  end

  describe "list/4 + stream!/4" do
    test "list returns wrapped %Response{data: %List{}} with dispatched structs", %{
      client: client,
      account_id: account_id
    } do
      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
               ExternalAccount.list(client, account_id, %{"limit" => 5})

      assert is_list(data)
      Enum.each(data, &assert_ea/1)
    end

    test "stream!/4 lazily yields dispatched structs", %{
      client: client,
      account_id: account_id
    } do
      eas =
        ExternalAccount.stream!(client, account_id, %{"limit" => 2})
        |> Enum.take(5)

      assert is_list(eas)
      Enum.each(eas, &assert_ea/1)
    end
  end

  defp ea_id(%BankAccount{id: id}), do: id
  defp ea_id(%Card{id: id}), do: id
  defp ea_id(%Unknown{id: id}), do: id

  defp deleted_extra(%BankAccount{extra: extra}), do: extra
  defp deleted_extra(%Card{extra: extra}), do: extra
  defp deleted_extra(%Unknown{extra: extra}), do: extra
end
