defmodule LatticeStripe.Charge.UpdateTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Charge

  alias LatticeStripe.{Charge, Error}

  @charge_id "ch_3OoLqrJ2eZvKYlo20wxYzAbC"

  setup :verify_on_exit!

  describe "update/4" do
    test "sends POST to /v1/charges/:id with metadata and description in body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/charges/#{@charge_id}")
        assert req.body =~ "metadata"
        assert req.body =~ "description"

        ok_response(
          basic(%{
            "metadata" => %{"order_id" => "ord_123"},
            "description" => "Updated description"
          })
        )
      end)

      assert {:ok,
              %Charge{
                id: @charge_id,
                metadata: %{"order_id" => "ord_123"},
                description: "Updated description"
              }} =
               Charge.update(client, @charge_id, %{
                 "metadata" => %{"order_id" => "ord_123"},
                 "description" => "Updated description"
               })
    end
  end

  describe "update!/4" do
    test "returns %Charge{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(basic())
      end)

      assert %Charge{id: @charge_id} =
               Charge.update!(client, @charge_id, %{"metadata" => %{}})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Charge.update!(client, @charge_id, %{})
      end
    end
  end
end
