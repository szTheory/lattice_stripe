defmodule LatticeStripe.ExternalAccountTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{BankAccount, Card, Error, ExternalAccount, List, Response}
  alias LatticeStripe.ExternalAccount.Unknown
  alias LatticeStripe.Test.Fixtures.ExternalAccount, as: Fixtures

  setup :verify_on_exit!

  @account_id "acct_1OoKpqJ2eZvKYlo2"
  @ba_id "ba_1OoKqrJ2eZvKYlo2C9hXqGtR"
  @card_id "card_1OoKqrJ2eZvKYlo2C9hXqGtR"

  # ---------------------------------------------------------------------------
  # cast/1 polymorphic dispatch
  # ---------------------------------------------------------------------------

  describe "cast/1" do
    test ~S[dispatches %{"object" => "bank_account"} -> %BankAccount{}] do
      assert %BankAccount{id: @ba_id} = ExternalAccount.cast(Fixtures.bank_account())
    end

    test ~S[dispatches %{"object" => "card"} -> %Card{}] do
      assert %Card{id: @card_id} = ExternalAccount.cast(Fixtures.card())
    end

    test "dispatches unknown object -> %ExternalAccount.Unknown{} with payload in :extra" do
      raw = Fixtures.unknown()

      assert %Unknown{id: "xa_future1234567890abc", object: "future_thing", extra: extra} =
               ExternalAccount.cast(raw)

      assert extra["some_field"] == "some_value"
      assert extra["nested"] == %{"a" => 1}
    end

    test "nil returns nil" do
      assert ExternalAccount.cast(nil) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # create/4
  # ---------------------------------------------------------------------------

  describe "create/4" do
    test "sends POST /v1/accounts/:account/external_accounts and returns {:ok, %BankAccount{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/accounts/#{@account_id}/external_accounts"
        refute req.url =~ "external_accounts/"
        ok_response(Fixtures.bank_account())
      end)

      assert {:ok, %BankAccount{id: @ba_id}} =
               ExternalAccount.create(
                 client,
                 @account_id,
                 %{"external_account" => "btok_test"}
               )
    end

    test "returns {:ok, %Card{}} when response object is card" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.card())
      end)

      assert {:ok, %Card{id: @card_id}} =
               ExternalAccount.create(
                 client,
                 @account_id,
                 %{"external_account" => "tok_visa_debit"}
               )
    end

    test "raises ArgumentError when account_id is empty" do
      client = test_client()

      assert_raise ArgumentError, ~r/account/, fn ->
        ExternalAccount.create(client, "", %{})
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} =
               ExternalAccount.create(client, @account_id, %{"external_account" => "btok_x"})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/4
  # ---------------------------------------------------------------------------

  describe "retrieve/4" do
    test "sends GET /v1/accounts/:account/external_accounts/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/accounts/#{@account_id}/external_accounts/#{@ba_id}"
        ok_response(Fixtures.bank_account())
      end)

      assert {:ok, %BankAccount{id: @ba_id}} =
               ExternalAccount.retrieve(client, @account_id, @ba_id)
    end

    test "raises ArgumentError when id is empty" do
      client = test_client()

      assert_raise ArgumentError, fn ->
        ExternalAccount.retrieve(client, @account_id, "")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update/5
  # ---------------------------------------------------------------------------

  describe "update/5" do
    test "sends POST /v1/accounts/:account/external_accounts/:id and returns sum type" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/accounts/#{@account_id}/external_accounts/#{@card_id}"
        assert req.body =~ "metadata"
        ok_response(Fixtures.card())
      end)

      assert {:ok, %Card{id: @card_id}} =
               ExternalAccount.update(
                 client,
                 @account_id,
                 @card_id,
                 %{"metadata" => %{"k" => "v"}}
               )
    end
  end

  # ---------------------------------------------------------------------------
  # delete/4
  # ---------------------------------------------------------------------------

  describe "delete/4" do
    test "sends DELETE; deleted=true flows into :extra on returned %BankAccount{}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert req.url =~ "/v1/accounts/#{@account_id}/external_accounts/#{@ba_id}"
        ok_response(Fixtures.deleted_bank_account())
      end)

      assert {:ok, %BankAccount{id: @ba_id, extra: %{"deleted" => true}}} =
               ExternalAccount.delete(client, @account_id, @ba_id)
    end

    test "delete on a card returns %Card{} with deleted flag in :extra" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.deleted_card())
      end)

      assert {:ok, %Card{id: @card_id, extra: %{"deleted" => true}}} =
               ExternalAccount.delete(client, @account_id, @card_id)
    end
  end

  # ---------------------------------------------------------------------------
  # list/4
  # ---------------------------------------------------------------------------

  describe "list/4" do
    test "sends GET; returns %Response{data: %List{}} with mixed sum-type items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/accounts/#{@account_id}/external_accounts"
        ok_response(Fixtures.mixed_list())
      end)

      assert {:ok, %Response{data: %List{data: [%BankAccount{}, %Card{}, %Unknown{}]}}} =
               ExternalAccount.list(client, @account_id)
    end

    test "passes filter params through (object=bank_account)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "object=bank_account"
        ok_response(Fixtures.mixed_list())
      end)

      assert {:ok, %Response{}} =
               ExternalAccount.list(client, @account_id, %{"object" => "bank_account"})
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/4
  # ---------------------------------------------------------------------------

  describe "stream!/4" do
    test "yields mixed BankAccount / Card / Unknown structs lazily" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/accounts/#{@account_id}/external_accounts"
        ok_response(Fixtures.mixed_list())
      end)

      results = client |> ExternalAccount.stream!(@account_id) |> Enum.to_list()

      assert [%BankAccount{}, %Card{}, %Unknown{}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "create!/4" do
    test "returns the sum-type value on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.bank_account())
      end)

      assert %BankAccount{} =
               ExternalAccount.create!(client, @account_id, %{"external_account" => "btok_x"})
    end

    test "raises LatticeStripe.Error on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        ExternalAccount.create!(client, @account_id, %{"external_account" => "btok_x"})
      end
    end
  end

  describe "retrieve!/4" do
    test "returns sum-type value on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.card())
      end)

      assert %Card{} = ExternalAccount.retrieve!(client, @account_id, @card_id)
    end
  end

  describe "update!/5" do
    test "returns sum-type value on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.bank_account())
      end)

      assert %BankAccount{} =
               ExternalAccount.update!(client, @account_id, @ba_id, %{"metadata" => %{}})
    end
  end

  describe "delete!/4" do
    test "returns sum-type value with deleted flag on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.deleted_bank_account())
      end)

      assert %BankAccount{extra: %{"deleted" => true}} =
               ExternalAccount.delete!(client, @account_id, @ba_id)
    end
  end

  describe "list!/4" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.mixed_list())
      end)

      assert %Response{data: %List{data: [_, _, _]}} =
               ExternalAccount.list!(client, @account_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown fallback module
  # ---------------------------------------------------------------------------

  describe "ExternalAccount.Unknown" do
    test "cast/1 returns nil on nil" do
      assert Unknown.cast(nil) == nil
    end

    test "cast/1 preserves id/object and stuffs the rest into :extra" do
      u = Unknown.cast(Fixtures.unknown())

      assert u.id == "xa_future1234567890abc"
      assert u.object == "future_thing"
      assert u.extra["some_field"] == "some_value"
      refute Map.has_key?(u.extra, "id")
      refute Map.has_key?(u.extra, "object")
    end
  end
end
