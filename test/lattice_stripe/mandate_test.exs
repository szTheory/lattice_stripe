defmodule LatticeStripe.MandateTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Testing.Fixtures.Mandate

  alias LatticeStripe.{Error, Mandate, PaymentMethod}

  setup :verify_on_exit!

  describe "retrieve/3" do
    test "sends GET /v1/mandates/:id and returns {:ok, %Mandate{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/mandates/mandate_test1234567890abc")
        ok_response(mandate_json())
      end)

      assert {:ok, %Mandate{id: "mandate_test1234567890abc"}} =
               Mandate.retrieve(client, "mandate_test1234567890abc")
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Mandate.retrieve(client, "mandate_missing")
    end
  end

  describe "retrieve!/3" do
    test "returns %Mandate{} directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(mandate_json())
      end)

      assert %Mandate{id: "mandate_test1234567890abc"} =
               Mandate.retrieve!(client, "mandate_test1234567890abc")
    end
  end

  describe "from_map/1" do
    test "atomizes status, type, and customer_acceptance.type" do
      mandate = Mandate.from_map(mandate_json())

      assert mandate.status == :active
      assert mandate.type == :single_use
      assert mandate.customer_acceptance.type == :online
    end

    test "expanded payment_method map dispatches through ObjectTypes" do
      mandate =
        Mandate.from_map(
          mandate_json(%{
            "payment_method" => %{
              "object" => "payment_method",
              "id" => "pm_test1234567890abc",
              "type" => "card"
            }
          })
        )

      assert %PaymentMethod{id: "pm_test1234567890abc"} = mandate.payment_method
    end

    test "unknown top-level fields land in extra" do
      mandate = Mandate.from_map(mandate_json(%{"future_field" => "extra"}))

      assert mandate.extra == %{"future_field" => "extra"}
    end
  end

  describe "documentation contracts" do
    test "@moduledoc makes the read-only diagnostic posture explicit" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Mandate)

      assert moduledoc =~ "inspection"
      assert moduledoc =~ "retrieve-only"
      assert moduledoc =~ ~r/does not expose create, update, or\s+delete flows/
    end
  end
end
