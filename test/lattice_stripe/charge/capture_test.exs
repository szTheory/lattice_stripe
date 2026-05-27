defmodule LatticeStripe.Charge.CaptureTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Charge

  alias LatticeStripe.{Charge, Error}

  @charge_id "ch_3OoLqrJ2eZvKYlo20wxYzAbC"

  setup :verify_on_exit!

  describe "capture/4" do
    test "sends POST to /v1/charges/:id/capture and returns {:ok, %Charge{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/charges/#{@charge_id}/capture")
        ok_response(basic(%{"captured" => true}))
      end)

      assert {:ok, %Charge{id: @charge_id, captured: true}} =
               Charge.capture(client, @charge_id)
    end

    test "sends capture with optional amount param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/charges/#{@charge_id}/capture")
        assert req.body =~ "amount=1000"
        ok_response(basic(%{"amount_captured" => 1000, "captured" => true}))
      end)

      assert {:ok, %Charge{amount_captured: 1000, captured: true}} =
               Charge.capture(client, @charge_id, %{"amount" => 1000})
    end
  end

  describe "capture!/4" do
    test "returns %Charge{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(basic())
      end)

      assert %Charge{id: @charge_id} = Charge.capture!(client, @charge_id)
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Charge.capture!(client, @charge_id)
      end
    end
  end
end
