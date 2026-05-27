defmodule LatticeStripe.Tax.RegistrationTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.TaxRegistration

  alias LatticeStripe.{List, Response}
  alias LatticeStripe.Tax.Registration

  setup :verify_on_exit!

  describe "create/3" do
    test "sends POST /v1/tax/registrations and forwards nested country_options" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax/registrations")
        assert req.body =~ "country_options[us]"
        assert req.body =~ "state_sales_tax"
        ok_response(basic())
      end)

      assert {:ok, %Registration{id: "taxreg_123"}} =
               Registration.create(client, %{
                 "country" => "US",
                 "country_options" => %{
                   "us" => %{"type" => "state_sales_tax", "state" => "CA"}
                 }
               })
    end
  end

  describe "retrieve/3" do
    test "sends GET /v1/tax/registrations/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax/registrations/taxreg_123")
        ok_response(basic())
      end)

      assert {:ok, %Registration{id: "taxreg_123"}} =
               Registration.retrieve(client, "taxreg_123")
    end
  end

  describe "update/4" do
    test "sends POST /v1/tax/registrations/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax/registrations/taxreg_123")
        ok_response(basic())
      end)

      assert {:ok, %Registration{id: "taxreg_123"}} =
               Registration.update(client, "taxreg_123", %{"active_from" => 1_700_000_001})
    end
  end

  describe "list/3" do
    test "sends GET /v1/tax/registrations and returns typed list items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax/registrations")
        ok_response(list_json([basic()], "/v1/tax/registrations"))
      end)

      assert {:ok, %Response{data: %List{data: [%Registration{id: "taxreg_123"}]}}} =
               Registration.list(client)
    end
  end

  describe "stream!/3" do
    test "streams %Registration{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/tax/registrations"
        ok_response(list_json([basic()], "/v1/tax/registrations"))
      end)

      assert [%Registration{id: "taxreg_123"}] =
               Registration.stream!(client) |> Enum.to_list()
    end
  end

  describe "from_map/1" do
    test "keeps country_options as a raw map and atomizes status" do
      registration = Registration.from_map(basic())

      assert registration.status == :active

      assert registration.country_options == %{
               "us" => %{"type" => "state_sales_tax", "state" => "CA"}
             }
    end
  end
end
