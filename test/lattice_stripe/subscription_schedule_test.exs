defmodule LatticeStripe.SubscriptionScheduleTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, List, Response, SubscriptionSchedule}
  alias LatticeStripe.SubscriptionSchedule.{CurrentPhase, Phase, PhaseItem}
  alias LatticeStripe.Test.Fixtures.SubscriptionSchedule, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionSchedule.from_map(nil) == nil
    end

    test "maps basic top-level fields" do
      sched = SubscriptionSchedule.from_map(Fixtures.basic())

      assert sched.id == "sub_sched_test1234567890"
      assert sched.object == "subscription_schedule"
      assert sched.status == "active"
      assert sched.customer == "cus_test123"
      assert sched.subscription == "sub_test456"
      assert sched.end_behavior == "release"
      assert sched.livemode == false
    end

    test "decodes current_phase as %CurrentPhase{}" do
      sched = SubscriptionSchedule.from_map(Fixtures.basic())

      assert %CurrentPhase{start_date: 1_700_000_000, end_date: 1_702_678_400} =
               sched.current_phase
    end

    test "decodes default_settings as %Phase{} with nil timeline fields" do
      sched = SubscriptionSchedule.from_map(Fixtures.basic())

      assert %Phase{} = sched.default_settings
      assert sched.default_settings.start_date == nil
      assert sched.default_settings.end_date == nil
      assert sched.default_settings.iterations == nil
      assert sched.default_settings.trial_end == nil
      assert sched.default_settings.trial_continuation == nil
      assert sched.default_settings.collection_method == "charge_automatically"
      assert sched.default_settings.default_payment_method == "pm_default_test"
    end

    test "decodes phases[] as [%Phase{}] with nested PhaseItem and AddInvoiceItem" do
      sched = SubscriptionSchedule.from_map(Fixtures.basic())

      assert [%Phase{} = phase] = sched.phases
      assert phase.start_date == 1_700_000_000
      assert phase.end_date == 1_702_678_400
      assert phase.proration_behavior == "create_prorations"
      assert [%PhaseItem{price: "price_test123", quantity: 1}] = phase.items
      assert [item] = phase.add_invoice_items
      assert item.price == "price_setup_fee"
    end

    test "decodes a two-phase schedule preserving order" do
      sched = SubscriptionSchedule.from_map(Fixtures.with_two_phases())

      assert [%Phase{} = first, %Phase{} = second] = sched.phases
      assert [%PhaseItem{price: "price_test123"}] = first.items
      assert [%PhaseItem{price: "price_test_second", quantity: 2}] = second.items
    end

    test "unknown top-level fields land in :extra" do
      sched = SubscriptionSchedule.from_map(Fixtures.basic(%{"future_field" => "hello"}))

      assert sched.extra == %{"future_field" => "hello"}
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/subscription_schedules and returns {:ok, %SubscriptionSchedule{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscription_schedules")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionSchedule{id: "sub_sched_test1234567890"}} =
               SubscriptionSchedule.create(client, %{"customer" => "cus_test123"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               SubscriptionSchedule.create(client, %{})
    end

    test "create/3 forwards idempotency_key" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-create"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionSchedule{}} =
               SubscriptionSchedule.create(client, %{"customer" => "cus_test123"},
                 idempotency_key: "ik-create"
               )
    end

    test "create!/3 returns the struct directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %SubscriptionSchedule{} = SubscriptionSchedule.create!(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/subscription_schedules/:id and returns {:ok, struct}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/subscription_schedules/sub_sched_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionSchedule{id: "sub_sched_test1234567890"}} =
               SubscriptionSchedule.retrieve(client, "sub_sched_test1234567890")
    end

    test "retrieve!/3 returns the struct directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %SubscriptionSchedule{} =
               SubscriptionSchedule.retrieve!(client, "sub_sched_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/subscription_schedules/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/subscription_schedules/sub_sched_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionSchedule{}} =
               SubscriptionSchedule.update(client, "sub_sched_test1234567890", %{
                 "metadata" => %{"key" => "value"}
               })
    end

    test "forwards opts[:idempotency_key]" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "ik-update"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %SubscriptionSchedule{}} =
               SubscriptionSchedule.update(
                 client,
                 "sub_sched_test1234567890",
                 %{},
                 idempotency_key: "ik-update"
               )
    end

    test "update!/4 returns the struct directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %SubscriptionSchedule{} =
               SubscriptionSchedule.update!(client, "sub_sched_test1234567890", %{})
    end
  end

  # ---------------------------------------------------------------------------
  # list/3 + stream!/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/subscription_schedules and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/subscription_schedules")
        ok_response(list_json([Fixtures.basic()], "/v1/subscription_schedules"))
      end)

      assert {:ok,
              %Response{
                data: %List{data: [%SubscriptionSchedule{id: "sub_sched_test1234567890"}]}
              }} = SubscriptionSchedule.list(client)
    end

    test "list!/3 returns the response directly" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([Fixtures.basic()], "/v1/subscription_schedules"))
      end)

      assert %Response{data: %List{}} = SubscriptionSchedule.list!(client)
    end
  end

  describe "stream!/3" do
    test "returns an Enumerable that lazily fetches pages" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/subscription_schedules")
        ok_response(list_json([Fixtures.basic()], "/v1/subscription_schedules"))
      end)

      result = SubscriptionSchedule.stream!(client) |> Enum.take(1)

      assert [%SubscriptionSchedule{id: "sub_sched_test1234567890"}] = result
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect — PII safety (T-16-01)
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "hides PII fields and surfaces only safe presence booleans + counts" do
      sched =
        SubscriptionSchedule.from_map(
          Fixtures.basic(%{
            "released_subscription" => "sub_released789"
          })
        )

      inspected = inspect(sched)

      # PII paths must NEVER appear:
      refute inspected =~ "cus_test123"
      refute inspected =~ "sub_test456"
      refute inspected =~ "sub_released789"
      refute inspected =~ "pm_default_test"
      refute inspected =~ "pm_phase_test"
      # Defense-in-depth catch-all for any payment method id leak
      refute inspected =~ "pm_"

      # Safe metadata MUST appear:
      assert inspected =~ "has_customer?: true"
      assert inspected =~ "has_subscription?: true"
      assert inspected =~ "has_released_subscription?: true"
      assert inspected =~ "has_default_settings?: true"
      assert inspected =~ "phase_count: 1"
      assert inspected =~ "end_behavior:"
      assert inspected =~ "#LatticeStripe.SubscriptionSchedule<"
    end

    test "phase_count is 0 when phases is nil" do
      sched =
        SubscriptionSchedule.from_map(
          Fixtures.basic(%{"phases" => nil, "customer" => nil, "subscription" => nil})
        )

      inspected = inspect(sched)

      assert inspected =~ "phase_count: 0"
      assert inspected =~ "has_customer?: false"
      assert inspected =~ "has_subscription?: false"
    end

    test "shows top-level extra only when non-empty" do
      # The nested current_phase's default-derived Inspect emits its own
      # `extra: %{}` even when empty. Only the top-level Inspect should
      # suppress an empty :extra. Anchor on "phase_count: N>" (with no
      # trailing extra) vs "phase_count: N, extra:".
      sched_no_extra = SubscriptionSchedule.from_map(Fixtures.basic())
      refute inspect(sched_no_extra) =~ ~r/phase_count: \d+, extra:/

      sched_extra = SubscriptionSchedule.from_map(Fixtures.basic(%{"future_field" => "hello"}))
      assert inspect(sched_extra) =~ ~r/phase_count: \d+, extra:/
    end
  end
end
