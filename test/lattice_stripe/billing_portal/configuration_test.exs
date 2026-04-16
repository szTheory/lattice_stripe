defmodule LatticeStripe.BillingPortal.ConfigurationTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  @moduletag :billing_portal

  alias LatticeStripe.BillingPortal.Configuration
  alias LatticeStripe.BillingPortal.Configuration.Features
  alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "returns {:ok, %Configuration{id: \"bpc_123\"}} on success" do
      client = test_client()
      fixture = Fixtures.Configuration.basic()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/billing_portal/configurations")
        ok_response(fixture)
      end)

      assert {:ok, %Configuration{id: "bpc_123"}} =
               Configuration.create(client, %{
                 "business_profile" => %{
                   "headline" => "Manage your subscription"
                 }
               })
    end

    test "returns {:error, %LatticeStripe.Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %LatticeStripe.Error{}} =
               Configuration.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "returns {:ok, %Configuration{id: \"bpc_123\"}} on success" do
      client = test_client()
      fixture = Fixtures.Configuration.basic()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/billing_portal/configurations/bpc_123"
        ok_response(fixture)
      end)

      assert {:ok, %Configuration{id: "bpc_123"}} =
               Configuration.retrieve(client, "bpc_123")
    end

    test "returns {:error, %LatticeStripe.Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %LatticeStripe.Error{}} =
               Configuration.retrieve(client, "bpc_123")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "returns {:ok, %Configuration{}} on success" do
      client = test_client()
      fixture = Fixtures.Configuration.basic(%{"name" => "Updated"})

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/billing_portal/configurations/bpc_123"
        ok_response(fixture)
      end)

      assert {:ok, %Configuration{}} =
               Configuration.update(client, "bpc_123", %{"name" => "Updated"})
    end

    test "returns {:error, %LatticeStripe.Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %LatticeStripe.Error{}} =
               Configuration.update(client, "bpc_123", %{"name" => "Updated"})
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "returns {:ok, %Response{}} with list data" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/billing_portal/configurations")

        ok_response(
          list_json([Fixtures.Configuration.basic()], "/v1/billing_portal/configurations")
        )
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: [%Configuration{id: "bpc_123"}]}}} =
               Configuration.list(client)
    end

    test "returns {:error, %LatticeStripe.Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %LatticeStripe.Error{}} = Configuration.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %Configuration{} directly on success" do
      client = test_client()
      fixture = Fixtures.Configuration.basic()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(fixture)
      end)

      assert %Configuration{id: "bpc_123"} =
               Configuration.create!(client, %{})
    end

    test "raises LatticeStripe.Error on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise LatticeStripe.Error, fn ->
        Configuration.create!(client, %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "decodes features into %Features{}" do
      map = Fixtures.Configuration.basic()
      config = Configuration.from_map(map)

      assert %Features{} = config.features
      assert config.features.customer_update != nil
      assert config.features.subscription_cancel != nil
    end

    test "keeps business_profile as raw map (not a struct)" do
      map = Fixtures.Configuration.basic()
      config = Configuration.from_map(map)

      assert is_map(config.business_profile)
      refute is_struct(config.business_profile)
      assert Map.has_key?(config.business_profile, "headline")
    end

    test "keeps login_page as raw map (not a struct)" do
      map = Fixtures.Configuration.basic()
      config = Configuration.from_map(map)

      assert is_map(config.login_page)
      refute is_struct(config.login_page)
      assert Map.has_key?(config.login_page, "enabled")
    end

    test "captures unknown keys into :extra" do
      map = Fixtures.Configuration.basic(%{"future_field" => "val"})
      config = Configuration.from_map(map)

      assert config.extra == %{"future_field" => "val"}
    end

    test "returns nil when given nil" do
      assert Configuration.from_map(nil) == nil
    end

    test "decodes all known scalar fields" do
      map = Fixtures.Configuration.basic()
      config = Configuration.from_map(map)

      assert config.id == "bpc_123"
      assert config.object == "billing_portal.configuration"
      assert config.active == true
      assert config.is_default == false
      assert config.livemode == false
      assert config.created == 1_712_345_678
      assert config.updated == 1_712_345_678
      assert config.metadata == %{}
    end
  end
end
