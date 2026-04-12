defmodule LatticeStripe.SubscriptionTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, List, Response, Subscription}
  alias LatticeStripe.Invoice.AutomaticTax
  alias LatticeStripe.Subscription.{CancellationDetails, PauseCollection, TrialSettings}
  alias LatticeStripe.Test.Fixtures.Subscription, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert Subscription.from_map(nil) == nil
    end

    test "maps basic known fields" do
      sub = Subscription.from_map(Fixtures.basic())

      assert sub.id == "sub_test1234567890"
      assert sub.object == "subscription"
      assert sub.status == "active"
      assert sub.customer == "cus_test123"
      assert sub.livemode == false
      assert sub.currency == "usd"
    end

    test "decodes automatic_tax via Invoice.AutomaticTax" do
      sub =
        Subscription.from_map(
          Fixtures.basic(%{
            "automatic_tax" => %{"enabled" => true, "status" => "complete", "liability" => nil}
          })
        )

      assert %AutomaticTax{enabled: true, status: "complete"} = sub.automatic_tax
    end

    test "decodes pause_collection into a typed struct" do
      sub = Subscription.from_map(Fixtures.paused())

      assert %PauseCollection{behavior: "keep_as_draft", resumes_at: 1_730_000_000} =
               sub.pause_collection
    end

    test "decodes cancellation_details into a typed struct" do
      sub = Subscription.from_map(Fixtures.canceled())

      assert %CancellationDetails{reason: "cancellation_requested", feedback: "too_expensive"} =
               sub.cancellation_details

      # Raw comment field is accessible (only Inspect masks it)
      assert sub.cancellation_details.comment == "customer comment"
    end

    test "decodes trial_settings into a typed struct" do
      sub =
        Subscription.from_map(
          Fixtures.basic(%{
            "trial_settings" => %{"end_behavior" => %{"missing_payment_method" => "cancel"}}
          })
        )

      assert %TrialSettings{end_behavior: %{"missing_payment_method" => "cancel"}} =
               sub.trial_settings
    end

    test "items list data decodes preserving id (stripity_stripe regression guard)" do
      sub = Subscription.from_map(Fixtures.with_items())

      assert %{"object" => "list", "data" => [item1, item2]} = sub.items

      # The decoded items MUST retain their id. stripity_stripe's nested
      # item decoder dropped id (issue #208), making programmatic updates
      # impossible. Assert id preservation without pattern-matching on
      # %SubscriptionItem{} so this unit test compiles under Plan 15-01
      # (SubscriptionItem module ships in Plan 15-02, and Subscription
      # still round-trips items via SubscriptionItem.from_map/1 at runtime).
      assert item1.__struct__ == LatticeStripe.SubscriptionItem
      assert item2.__struct__ == LatticeStripe.SubscriptionItem
      assert item1.id == "si_test1"
      assert item2.id == "si_test2"
    end

    test "unknown top-level fields land in :extra" do
      sub = Subscription.from_map(Fixtures.basic(%{"future_field" => "hello"}))
      assert sub.extra == %{"future_field" => "hello"}
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/subscriptions and returns {:ok, %Subscription{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscriptions")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{id: "sub_test1234567890"}} =
               Subscription.create(client, %{"customer" => "cus_test123"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = Subscription.create(client, %{})
    end

    test "strict client rejects items[] without proration_behavior without hitting Transport" do
      client = test_client(require_explicit_proration: true)

      params = %{
        "customer" => "cus_test123",
        "items" => [%{"price" => "price_test1", "quantity" => 1}]
      }

      assert {:error, %Error{type: :proration_required}} = Subscription.create(client, params)
    end

    test "strict client accepts items[] with proration_behavior" do
      client = test_client(require_explicit_proration: true)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      params = %{
        "customer" => "cus_test123",
        "items" => [
          %{
            "price" => "price_test1",
            "quantity" => 1,
            "proration_behavior" => "create_prorations"
          }
        ]
      }

      assert {:ok, %Subscription{}} = Subscription.create(client, params)
    end

    test "forwards opts[:idempotency_key] to Request opts" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "test-ik-create"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.create(client, %{"customer" => "cus_test123"},
                 idempotency_key: "test-ik-create"
               )
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/subscriptions/:id and returns {:ok, %Subscription{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/subscriptions/sub_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{id: "sub_test1234567890"}} =
               Subscription.retrieve(client, "sub_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/subscriptions/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscriptions/sub_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.update(client, "sub_test1234567890", %{"description" => "new"})
    end

    test "returns proration_required when items[] has no proration_behavior under strict client" do
      client = test_client(require_explicit_proration: true)

      params = %{"items" => [%{"id" => "si_test1", "quantity" => 2}]}

      assert {:error, %Error{type: :proration_required}} =
               Subscription.update(client, "sub_test1234567890", params)
    end

    test "forwards opts[:idempotency_key]" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "test-ik-update"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.update(client, "sub_test1234567890", %{},
                 idempotency_key: "test-ik-update"
               )
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/3 and cancel/4
  # ---------------------------------------------------------------------------

  describe "cancel/3 and cancel/4" do
    test "cancel/3 delegates to cancel/4 with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/subscriptions/sub_test1234567890")
        ok_response(Fixtures.canceled())
      end)

      assert {:ok, %Subscription{status: "canceled"}} =
               Subscription.cancel(client, "sub_test1234567890")
    end

    test "cancel/4 passes prorate param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        # DELETE requests encode params in the query string, not the body.
        assert req.url =~ "prorate"
        ok_response(Fixtures.canceled())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.cancel(client, "sub_test1234567890", %{"prorate" => true}, [])
    end

    test "cancel forwards opts[:idempotency_key]" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-cancel"
               end)

        ok_response(Fixtures.canceled())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.cancel(client, "sub_test1234567890", idempotency_key: "ik-cancel")
    end
  end

  # ---------------------------------------------------------------------------
  # resume/3
  # ---------------------------------------------------------------------------

  describe "resume/3" do
    test "sends POST /v1/subscriptions/:id/resume" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscriptions/sub_test1234567890/resume")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{}} = Subscription.resume(client, "sub_test1234567890")
    end

    test "forwards opts[:idempotency_key]" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-resume"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.resume(client, "sub_test1234567890", idempotency_key: "ik-resume")
    end
  end

  # ---------------------------------------------------------------------------
  # pause_collection/5
  # ---------------------------------------------------------------------------

  describe "pause_collection/5" do
    test "merges pause_collection.behavior and dispatches to update" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscriptions/sub_test1234567890")
        assert req.body =~ "pause_collection"
        assert req.body =~ "keep_as_draft"
        ok_response(Fixtures.paused())
      end)

      assert {:ok, %Subscription{pause_collection: %PauseCollection{behavior: "keep_as_draft"}}} =
               Subscription.pause_collection(client, "sub_test1234567890", :keep_as_draft)
    end

    test "accepts :mark_uncollectible and :void" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, 2, fn req ->
        assert req.body =~ "pause_collection"
        ok_response(Fixtures.paused())
      end)

      assert {:ok, %Subscription{}} =
               Subscription.pause_collection(client, "sub_test1234567890", :mark_uncollectible)

      assert {:ok, %Subscription{}} =
               Subscription.pause_collection(client, "sub_test1234567890", :void)
    end

    test "rejects invalid behavior atoms at the function head" do
      client = test_client()

      assert_raise FunctionClauseError, fn ->
        Subscription.pause_collection(client, "sub_test1234567890", :invalid_behavior)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/subscriptions and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/subscriptions")
        ok_response(list_json([Fixtures.basic()], "/v1/subscriptions"))
      end)

      assert {:ok, %Response{data: %List{data: [%Subscription{id: "sub_test1234567890"}]}}} =
               Subscription.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # search/3
  # ---------------------------------------------------------------------------

  describe "search/3" do
    test "raises ArgumentError when query is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/query/, fn ->
        Subscription.search(client, %{})
      end
    end

    test "sends GET /v1/subscriptions/search with query param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/subscriptions/search"
        ok_response(list_json([Fixtures.basic()], "/v1/subscriptions/search"))
      end)

      assert {:ok, %Response{data: %List{}}} =
               Subscription.search(client, %{"query" => "status:'active'"})
    end
  end

  describe "search_stream!/3" do
    test "raises ArgumentError when query is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/query/, fn ->
        Subscription.search_stream!(client, %{}) |> Enum.take(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "bang variants" do
    test "create! returns %Subscription{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %Subscription{} = Subscription.create!(client, %{"customer" => "cus_test123"})
    end

    test "create! raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Subscription.create!(client, %{}) end
    end

    test "pause_collection! returns %Subscription{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.paused())
      end)

      assert %Subscription{pause_collection: %PauseCollection{behavior: "keep_as_draft"}} =
               Subscription.pause_collection!(client, "sub_test1234567890", :keep_as_draft)
    end

    test "pause_collection! raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Subscription.pause_collection!(client, "sub_test1234567890", :keep_as_draft)
      end
    end

    test "resume! returns %Subscription{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %Subscription{} = Subscription.resume!(client, "sub_test1234567890")
    end

    test "resume! raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Subscription.resume!(client, "sub_test1234567890") end
    end

    test "list! returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([Fixtures.basic()], "/v1/subscriptions"))
      end)

      assert %Response{data: %List{data: [%Subscription{}]}} = Subscription.list!(client)
    end

    test "list! raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Subscription.list!(client) end
    end

    test "stream! raises mid-stream when page fetch fails" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Subscription.stream!(client) |> Enum.take(5)
      end
    end

    test "stream! yields decoded %Subscription{} structs on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([Fixtures.basic()], "/v1/subscriptions"))
      end)

      assert [%Subscription{id: "sub_test1234567890"}] =
               Subscription.stream!(client) |> Enum.take(5)
    end

    test "cancel! returns %Subscription{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.canceled())
      end)

      assert %Subscription{status: "canceled"} =
               Subscription.cancel!(client, "sub_test1234567890")
    end

    test "cancel! raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Subscription.cancel!(client, "sub_test1234567890") end
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "hides customer and payment_settings raw values" do
      sub =
        Subscription.from_map(
          Fixtures.basic(%{
            "customer" => "cus_super_secret_abcdef",
            "payment_settings" => %{
              "payment_method_options" => %{"card" => %{"request_three_d_secure" => "any"}}
            },
            "default_payment_method" => "pm_secret_xyz",
            "latest_invoice" => "in_secret_xyz"
          })
        )

      inspected = inspect(sub)

      refute inspected =~ "cus_super_secret_abcdef"
      refute inspected =~ "payment_method_options"
      refute inspected =~ "pm_secret_xyz"
      refute inspected =~ "in_secret_xyz"
      assert inspected =~ "#LatticeStripe.Subscription<"
      assert inspected =~ "has_customer?: true"
      assert inspected =~ "has_payment_settings?: true"
      assert inspected =~ "has_default_payment_method?: true"
      assert inspected =~ "has_latest_invoice?: true"
    end
  end

  # ---------------------------------------------------------------------------
  # Form encoder sanity (T-15-05)
  # ---------------------------------------------------------------------------

  describe "form encoder (T-15-05 sanity)" do
    test "nested metadata with bracket/ampersand keys encodes without breaking request" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        # Body must be a non-empty string; form encoder must not crash on weird keys.
        assert is_binary(req.body)
        refute req.body == ""
        ok_response(Fixtures.basic())
      end)

      params = %{
        "customer" => "cus_test123",
        "metadata" => %{"key[with]brackets" => "val&evil=foo"}
      }

      assert {:ok, %Subscription{}} = Subscription.create(client, params)
    end
  end
end
