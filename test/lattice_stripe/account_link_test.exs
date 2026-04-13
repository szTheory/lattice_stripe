defmodule LatticeStripe.AccountLinkTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{AccountLink, Error}
  alias LatticeStripe.Test.Fixtures.AccountLink, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert AccountLink.from_map(nil) == nil
    end

    test "maps known fields into struct" do
      link = AccountLink.from_map(Fixtures.basic())

      assert link.object == "account_link"
      assert link.created == 1_700_000_000
      assert link.expires_at == 1_700_000_300
      assert link.url == "https://connect.stripe.com/setup/e/acct_test/xyz"
    end

    test "unknown fields land in :extra" do
      link = AccountLink.from_map(Fixtures.basic())

      assert link.extra == %{"zzz_forward_compat_field" => "extra_value"}
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/account_links and returns {:ok, %AccountLink{}}" do
      client = test_client()

      params = %{
        "account" => "acct_test",
        "type" => "account_onboarding",
        "refresh_url" => "https://example.com/refresh",
        "return_url" => "https://example.com/return"
      }

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/account_links")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %AccountLink{url: "https://connect.stripe.com/setup/e/acct_test/xyz"}} =
               AccountLink.create(client, params)
    end

    test "forwards params verbatim including unknown keys" do
      client = test_client()

      params = %{
        "account" => "acct_test",
        "type" => "account_onboarding",
        "refresh_url" => "https://example.com/refresh",
        "return_url" => "https://example.com/return",
        "collect" => "currently_due",
        "future_param" => "some_value"
      }

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req._params == params
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %AccountLink{}} = AccountLink.create(client, params)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               AccountLink.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns struct directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %AccountLink{url: "https://connect.stripe.com/setup/e/acct_test/xyz"} =
               AccountLink.create!(client, %{})
    end

    test "raises LatticeStripe.Error on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise LatticeStripe.Error, fn ->
        AccountLink.create!(client, %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # D-04c: no positional type arg — regression guard
  # ---------------------------------------------------------------------------

  describe "D-04c: no positional type arg" do
    test "create/4 does not exist — SDK-wide create(client, params, opts) shape preserved" do
      refute function_exported?(LatticeStripe.AccountLink, :create, 4)
    end

    test "create!/4 does not exist — bang variant also guards D-04c" do
      refute function_exported?(LatticeStripe.AccountLink, :create!, 4)
    end
  end

  # ---------------------------------------------------------------------------
  # Create-only: no retrieve/update/delete/list
  # ---------------------------------------------------------------------------

  describe "create-only: no retrieve/update/delete/list" do
    test "retrieve/3, update/4, delete/3, list/3 are not exported — Stripe API constraint" do
      refute function_exported?(LatticeStripe.AccountLink, :retrieve, 3)
      refute function_exported?(LatticeStripe.AccountLink, :update, 4)
      refute function_exported?(LatticeStripe.AccountLink, :delete, 3)
      refute function_exported?(LatticeStripe.AccountLink, :list, 3)
    end
  end
end
