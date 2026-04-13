defmodule LatticeStripe.LoginLinkTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, LoginLink}
  alias LatticeStripe.Test.Fixtures.LoginLink, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert LoginLink.from_map(nil) == nil
    end

    test "maps known fields into struct" do
      link = LoginLink.from_map(Fixtures.basic())

      assert link.object == "login_link"
      assert link.created == 1_700_000_000
      assert link.url == "https://connect.stripe.com/express/Ln7F..."
    end

    test "unknown fields land in :extra" do
      link = LoginLink.from_map(Fixtures.basic())

      assert link.extra == %{"zzz_forward_compat_field" => "extra_value"}
    end
  end

  # ---------------------------------------------------------------------------
  # create/4 — account_id as second positional arg
  # ---------------------------------------------------------------------------

  describe "create/4" do
    test "sends POST /v1/accounts/:account_id/login_links and returns {:ok, %LoginLink{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/accounts/acct_test/login_links")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %LoginLink{url: "https://connect.stripe.com/express/Ln7F..."}} =
               LoginLink.create(client, "acct_test")
    end

    test "URL path interpolates the account_id correctly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "/v1/accounts/acct_another123/login_links"
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %LoginLink{}} = LoginLink.create(client, "acct_another123")
    end

    test "forwards extra params when provided" do
      client = test_client()

      extra_params = %{"future_param" => "value"}

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req._params == extra_params
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %LoginLink{}} = LoginLink.create(client, "acct_test", extra_params)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               LoginLink.create(client, "acct_test")
    end
  end

  # ---------------------------------------------------------------------------
  # create/4 signature deviation — account_id must be binary
  # ---------------------------------------------------------------------------

  describe "create/4 signature deviation" do
    test "create(client, account_id) works with default params and opts" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert String.ends_with?(req.url, "/v1/accounts/acct_test/login_links")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %LoginLink{}} = LoginLink.create(client, "acct_test")
    end

    test "create(client, non_binary) raises FunctionClauseError — account_id must be a string" do
      client = test_client()

      assert_raise FunctionClauseError, fn ->
        LoginLink.create(client, %{"account" => "acct_test"})
      end
    end

    test "create/4 full arity is exported" do
      assert function_exported?(LatticeStripe.LoginLink, :create, 4)
    end
  end

  # ---------------------------------------------------------------------------
  # create!/4
  # ---------------------------------------------------------------------------

  describe "create!/4" do
    test "returns struct directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %LoginLink{url: "https://connect.stripe.com/express/Ln7F..."} =
               LoginLink.create!(client, "acct_test")
    end

    test "raises LatticeStripe.Error on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise LatticeStripe.Error, fn ->
        LoginLink.create!(client, "acct_test")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Create-only: no retrieve/update/delete/list
  # ---------------------------------------------------------------------------

  describe "create-only: no retrieve/update/delete/list" do
    test "retrieve/3, update/4, delete/3, list/3 are not exported — Stripe API constraint" do
      refute function_exported?(LatticeStripe.LoginLink, :retrieve, 3)
      refute function_exported?(LatticeStripe.LoginLink, :update, 4)
      refute function_exported?(LatticeStripe.LoginLink, :delete, 3)
      refute function_exported?(LatticeStripe.LoginLink, :list, 3)
    end
  end
end
