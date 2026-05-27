defmodule LatticeStripe.Charge.SearchTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Charge

  alias LatticeStripe.{Charge, List, Response}

  setup :verify_on_exit!

  describe "search/3" do
    test "sends GET to path containing /v1/charges/search with query param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/charges/search"
        assert req.url =~ "query="

        ok_response(%{
          "object" => "search_result",
          "data" => [basic()],
          "has_more" => false,
          "url" => "/v1/charges/search"
        })
      end)

      assert {:ok, %Response{data: %List{data: [%Charge{id: "ch_3OoLqrJ2eZvKYlo20wxYzAbC"}]}}} =
               Charge.search(client, "status:'succeeded'")
    end
  end

  describe "search!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(%{
          "object" => "search_result",
          "data" => [basic()],
          "has_more" => false,
          "url" => "/v1/charges/search"
        })
      end)

      assert %Response{data: %List{data: [%Charge{}]}} =
               Charge.search!(client, "status:'succeeded'")
    end
  end

  describe "search_stream!/3" do
    test "emits %Charge{} from search results" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "/v1/charges/search"

        ok_response(%{
          "object" => "search_result",
          "data" => [basic()],
          "has_more" => false,
          "url" => "/v1/charges/search"
        })
      end)

      results = Charge.search_stream!(client, "status:'succeeded'") |> Enum.to_list()

      assert [%Charge{id: "ch_3OoLqrJ2eZvKYlo20wxYzAbC"}] = results
    end
  end
end
