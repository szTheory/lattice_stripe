defmodule LatticeStripe.SetupAttemptTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.SetupAttempt

  alias LatticeStripe.{Error, List, PaymentMethod, Response, SetupAttempt}

  setup :verify_on_exit!

  describe "list/3" do
    test "sends GET /v1/setup_attempts and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.starts_with?(req.url, "https://api.stripe.com/v1/setup_attempts?")
        assert req.url =~ "setup_intent=seti_test1234567890abc"
        ok_response(list_json([setup_attempt_json()], "/v1/setup_attempts"))
      end)

      assert {:ok, %Response{data: %List{data: [%SetupAttempt{id: "setatt_test1234567890abc"}]}}} =
               SetupAttempt.list(client, %{"setup_intent" => "seti_test1234567890abc"})
    end

    test "raises ArgumentError when setup_intent param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/requires a "setup_intent" key/, fn ->
        SetupAttempt.list(client, %{})
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} =
               SetupAttempt.list(client, %{"setup_intent" => "seti_test1234567890abc"})
    end
  end

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([setup_attempt_json()], "/v1/setup_attempts"))
      end)

      assert %Response{data: %List{data: [%SetupAttempt{}]}} =
               SetupAttempt.list!(client, %{"setup_intent" => "seti_test1234567890abc"})
    end
  end

  describe "stream!/3" do
    test "streams typed setup attempts with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "setup_intent=seti_test1234567890abc"
        ok_response(list_json([setup_attempt_json()], "/v1/setup_attempts"))
      end)

      results =
        SetupAttempt.stream!(client, %{"setup_intent" => "seti_test1234567890abc"})
        |> Enum.to_list()

      assert [%SetupAttempt{id: "setatt_test1234567890abc"}] = results
    end

    test "raises ArgumentError when setup_intent param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/requires a "setup_intent" key/, fn ->
        SetupAttempt.stream!(client, %{}) |> Enum.to_list()
      end
    end
  end

  describe "from_map/1" do
    test "atomizes status and usage with string passthrough" do
      succeeded = SetupAttempt.from_map(setup_attempt_json())

      future =
        SetupAttempt.from_map(
          setup_attempt_json(%{"status" => "future_status", "usage" => "future_usage"})
        )

      assert succeeded.status == :succeeded
      assert succeeded.usage == :off_session
      assert future.status == "future_status"
      assert future.usage == "future_usage"
    end

    test "parses non-nil setup_error with expanded payment_method" do
      setup_attempt =
        SetupAttempt.from_map(
          setup_attempt_with_error_json(%{
            "setup_error" =>
              setup_attempt_setup_error_json(%{
                "payment_method" => %{
                  "object" => "payment_method",
                  "id" => "pm_test1234567890abc",
                  "type" => "card"
                }
              })
          })
        )

      assert %SetupAttempt.SetupError{} = setup_attempt.setup_error
      assert %PaymentMethod{id: "pm_test1234567890abc"} = setup_attempt.setup_error.payment_method
    end

    test "preserves unknown fields in extra" do
      setup_attempt = SetupAttempt.from_map(setup_attempt_json(%{"future_field" => "extra"}))

      assert setup_attempt.extra == %{"future_field" => "extra"}
    end
  end

  describe "documentation contracts" do
    test "@moduledoc documents read-only inspection posture" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(SetupAttempt)

      assert moduledoc =~ "inspect"
      assert moduledoc =~ "read-only"
      assert moduledoc =~ "only list/stream access"
    end

    test "@moduledoc documents required setup_intent filter and local ArgumentError" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(SetupAttempt)

      assert moduledoc =~ ~s|"setup_intent"|
      assert moduledoc =~ "required"
      assert moduledoc =~ "ArgumentError"
      assert moduledoc =~ ~r/before any network\s+call/
    end
  end
end
