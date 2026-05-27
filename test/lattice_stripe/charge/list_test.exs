defmodule LatticeStripe.Charge.ListTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Charge

  alias LatticeStripe.{Charge, Error, List, Response}

  setup :verify_on_exit!

  describe "list/3" do
    test "sends GET ending with /v1/charges and returns {:ok, %Response{data: %List{data: [%Charge{}]}}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/charges")
        ok_response(list_json([basic()], "/v1/charges"))
      end)

      assert {:ok, %Response{data: %List{data: [%Charge{id: "ch_3OoLqrJ2eZvKYlo20wxYzAbC"}]}}} =
               Charge.list(client)
    end

    test "passes limit param in request URL" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "limit=10"
        ok_response(list_json([basic()], "/v1/charges"))
      end)

      assert {:ok, %Response{data: %List{data: [%Charge{}]}}} =
               Charge.list(client, %{"limit" => "10"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Charge.list(client)
    end
  end

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([basic()], "/v1/charges"))
      end)

      assert %Response{data: %List{data: [%Charge{}]}} = Charge.list!(client)
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Charge.list!(client)
      end
    end
  end

  describe "stream!/3" do
    test "emits %Charge{} from one page" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/charges"
        ok_response(list_json([basic()], "/v1/charges"))
      end)

      results = Charge.stream!(client) |> Enum.to_list()

      assert [%Charge{id: "ch_3OoLqrJ2eZvKYlo20wxYzAbC"}] = results
    end
  end
end
