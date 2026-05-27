defmodule LatticeStripe.Tax.SettingsTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.TaxSettings

  alias LatticeStripe.Tax.Settings
  alias LatticeStripe.Tax.Settings.Defaults

  setup :verify_on_exit!

  describe "retrieve/2" do
    test "sends GET /v1/tax/settings with no trailing ID segment" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax/settings")
        refute req.url =~ ~r{/v1/tax/settings/[^/]}
        ok_response(basic())
      end)

      assert {:ok, %Settings{object: "tax.settings"}} = Settings.retrieve(client)
    end
  end

  describe "update/3" do
    test "sends POST /v1/tax/settings and forwards nested defaults params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax/settings")
        assert req.body =~ "defaults"
        ok_response(basic())
      end)

      assert {:ok, %Settings{}} =
               Settings.update(client, %{
                 "defaults" => %{"tax_behavior" => "inclusive"}
               })
    end
  end

  describe "retrieve/2 with stripe_account opt" do
    test "threads stripe_account opt through to the Stripe-Account header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert {"stripe-account", "acct_123"} in req.headers
        ok_response(basic())
      end)

      assert {:ok, %Settings{}} = Settings.retrieve(client, stripe_account: "acct_123")
    end

    test "platform call does not send the stripe-account header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        refute Enum.any?(req.headers, fn {k, _} -> k == "stripe-account" end)
        ok_response(basic())
      end)

      assert {:ok, %Settings{}} = Settings.retrieve(client)
    end
  end

  describe "module surface" do
    test "Settings is a singleton — no list/create/delete or ID-based arities exported" do
      refute function_exported?(Settings, :list, 1)
      refute function_exported?(Settings, :list, 2)
      refute function_exported?(Settings, :list, 3)
      refute function_exported?(Settings, :create, 2)
      refute function_exported?(Settings, :create, 3)
      refute function_exported?(Settings, :delete, 2)
      refute function_exported?(Settings, :delete, 3)
      refute function_exported?(Settings, :retrieve, 3)
      refute function_exported?(Settings, :update, 4)
    end

    test "%Settings{} has no :id field" do
      refute Map.has_key?(%Settings{}, :id)
    end

    test "retrieve/2, retrieve!/2, update/3, and update!/3 are exported" do
      assert function_exported?(Settings, :retrieve, 2)
      assert function_exported?(Settings, :retrieve!, 2)
      assert function_exported?(Settings, :update, 3)
      assert function_exported?(Settings, :update!, 3)
    end
  end

  describe "from_map/1" do
    test "decodes defaults into %Defaults{}" do
      settings = Settings.from_map(basic())
      assert %Defaults{tax_behavior: :exclusive, tax_code: "txcd_99999999"} = settings.defaults
    end

    test "unknown top-level field survives in :extra" do
      settings = Settings.from_map(basic(%{"reserved_field" => "hello"}))
      assert settings.extra["reserved_field"] == "hello"
    end
  end
end
