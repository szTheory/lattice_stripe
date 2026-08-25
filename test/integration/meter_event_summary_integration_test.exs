defmodule LatticeStripe.Billing.MeterEventSummaryIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Billing.MeterEventSummary` and the
  Stripe-side half of the meter-event payload contract, against stripe-mock.

  stripe-mock validates every request against Stripe's own OpenAPI spec, which
  makes it the only place three claims in this phase can be checked: that
  `GET /v1/billing/meters/:meter_id/event_summaries` is a route Stripe serves at
  all, that each of the three required filters is enforced server-side, and that
  a nested meter-event payload is refused. Everything else in this phase is
  proven against a mocked transport, which is correct — mock-at-transport is the
  only place pagination and header survival are observable.

  ## What is deliberately NOT asserted here

  stripe-mock returns one synthetic item per list, ignores `limit` and
  `starting_after`, accepts unaligned timestamps, and answers with a literal
  placeholder `url` that does not echo the requested meter id. So it cannot
  prove pagination, timestamp alignment, eventual consistency, zero-bucket
  behavior or deactivated-meter reads, and the response `url` is never asserted.
  Pagination's proof lives in `meter_event_summary_pagination_test.exs` and must
  stay there.

  ## Which side each test proves

  Several facts have both a client-side and a server-side half, and a test that
  re-proves the client-side raise while claiming to prove server behavior is
  worse than no test. Every test name below is therefore prefixed `SERVER:` or
  `CLIENT:`. The `SERVER:` cases reach the wire by constructing a `%Request{}`
  directly, bypassing the guards in `MeterEventSummary` that would otherwise
  raise before any network call.

  ## Enforcement order is not provable here

  stripe-mock names only ONE missing property per response, and when more than
  one required filter is absent, which one it names varies between otherwise
  identical requests (Go map iteration order — observed alternating between
  `customer` and `start_time` across eight consecutive probes of the same URL).
  So each server-side required-param case omits exactly one filter, which is
  deterministic. The client-side guard *order* is asserted separately, and
  labelled as the client-side fact it is.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Billing.{MeterEvent, MeterEventSummary}
  alias LatticeStripe.{Client, Error, Request}

  # 2025-07-28 00:00 UTC and 2025-07-29 00:00 UTC. Both are exact multiples of
  # 86_400, and therefore also of 3_600 and 60, so they satisfy every supported window.
  # every grouping window. This matters: the alignment guard raises before the
  # request leaves the process, so an unaligned literal here would mean the
  # server was never reached and the test proved nothing about Stripe.
  @start_time 1_753_660_800
  @end_time 1_753_747_200

  @meter_id "mtr_123"

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  defp full_params do
    %{"customer" => "cus_123", "start_time" => @start_time, "end_time" => @end_time}
  end

  # Sends the same GET that `MeterEventSummary.list/4` builds, but without its
  # guards. This is the only way to observe Stripe's own enforcement of the three
  # required filters: `list/4` raises ArgumentError first and the request never
  # leaves the process.
  defp raw_list(client, params) do
    Client.request(client, %Request{
      method: :get,
      path: "/v1/billing/meters/#{@meter_id}/event_summaries",
      params: params
    })
  end

  # The path is served, and a served body decodes

  test "SERVER: GET /v1/billing/meters/:meter_id/event_summaries is a served route",
       %{client: client} do
    assert {:ok, resp} = MeterEventSummary.list(client, @meter_id, full_params())

    # A 404 would arrive as {:error, %Error{status: 404}}; reaching an :ok tuple
    # at all is the route's existence proof.
    assert resp.status == 200
  end

  test "SERVER: a served body decodes into %MeterEventSummary{} with the expected field types",
       %{client: client} do
    assert {:ok, resp} = MeterEventSummary.list(client, @meter_id, full_params())

    assert [%MeterEventSummary{} = summary | _] = resp.data.data

    assert is_binary(summary.id)
    assert summary.object == "billing.meter_event_summary"
    assert is_number(summary.aggregated_value)
    assert is_integer(summary.start_time)
    assert is_integer(summary.end_time)
    assert is_binary(summary.meter)
    assert is_boolean(summary.livemode)

    # The struct has no :customer field, by design — the customer is an input to
    # the query and never an output. Asserting its absence here confirms the
    # wire object really does omit it, not merely that the struct drops it.
    refute Map.has_key?(summary, :customer)
    refute Map.has_key?(summary.extra, "customer")
  end

  # Required-param enforcement, server side
  #
  # One filter omitted per case. Omitting more than one makes the named property
  # nondeterministic — see the moduledoc.

  test "SERVER: omitting only customer is rejected by Stripe, naming the customer param",
       %{client: client} do
    params = Map.delete(full_params(), "customer")

    assert {:error, %Error{type: :invalid_request_error} = error} = raw_list(client, params)
    assert error.status == 400
    assert error.message =~ "customer"
    assert error.message =~ "required"
  end

  test "SERVER: omitting only start_time is rejected by Stripe, naming the start_time param",
       %{client: client} do
    params = Map.delete(full_params(), "start_time")

    assert {:error, %Error{type: :invalid_request_error} = error} = raw_list(client, params)
    assert error.status == 400
    assert error.message =~ "start_time"
    assert error.message =~ "required"
  end

  test "SERVER: omitting only end_time is rejected by Stripe, naming the end_time param",
       %{client: client} do
    params = Map.delete(full_params(), "end_time")

    assert {:error, %Error{type: :invalid_request_error} = error} = raw_list(client, params)
    assert error.status == 400
    assert error.message =~ "end_time"
    assert error.message =~ "required"
  end

  test "CLIENT: list/4 raises in the order customer, start_time, end_time before any request",
       %{client: client} do
    # The separate, client-side half of the fact above. Stripe's own ordering is
    # not observable (it reports one arbitrary missing property), so this is the
    # only place the documented order is checkable at all — and it is a claim
    # about this library, not about Stripe.
    assert_raise ArgumentError, ~r/requires a customer param/, fn ->
      MeterEventSummary.list(client, @meter_id, %{})
    end

    assert_raise ArgumentError, ~r/requires a start_time param/, fn ->
      MeterEventSummary.list(client, @meter_id, %{"customer" => "cus_123"})
    end

    assert_raise ArgumentError, ~r/requires an end_time param/, fn ->
      MeterEventSummary.list(client, @meter_id, %{
        "customer" => "cus_123",
        "start_time" => @start_time
      })
    end
  end

  # Enum validation

  test "SERVER: an unrecognised value_grouping_window is rejected by the enum validator",
       %{client: client} do
    # No guard bypass is needed: alignment checking deliberately skips
    # an unrecognised window (forward compatibility — Stripe added "day" to this
    # enum mid-2024), so the value reaches Stripe and Stripe is what rejects it.
    params = Map.put(full_params(), "value_grouping_window", "fortnight")

    assert {:error, %Error{type: :invalid_request_error} = error} =
             MeterEventSummary.list(client, @meter_id, params)

    assert error.status == 400
    assert error.message =~ "value_grouping_window"
    assert error.message =~ "enumeration"
  end

  test "SERVER: a recognised value_grouping_window with aligned timestamps is accepted",
       %{client: client} do
    for window <- ["hour", "day"] do
      params = Map.put(full_params(), "value_grouping_window", window)

      assert {:ok, resp} = MeterEventSummary.list(client, @meter_id, params)
      assert resp.status == 200
    end
  end

  # the Stripe-side half of the payload contract

  test "SERVER: a flat payload with several custom dimensions and a decimal-string value is accepted",
       %{client: client} do
    params = %{
      "event_name" => "api_call",
      "payload" => %{
        "stripe_customer_id" => "cus_123",
        "value" => "10",
        "region" => "us-east-1",
        "tier" => "gold",
        "endpoint" => "/v1/search"
      }
    }

    assert {:ok, %MeterEvent{} = event} = MeterEvent.create(client, params)
    assert event.event_name == "api_call"
  end

  test "SERVER: a payload nesting a map under a key is rejected, naming the offending kind",
       %{client: client} do
    # The single check that would have caught the fact that this SDK will happily
    # build a request Stripe refuses: the form encoder serialises the nested map
    # as payload[meta][region], and Stripe's spec types every payload value as a
    # string.
    params = %{
      "event_name" => "api_call",
      "payload" => %{
        "stripe_customer_id" => "cus_123",
        "value" => "10",
        "meta" => %{"region" => "us-east-1"}
      }
    }

    assert {:error, %Error{type: :invalid_request_error} = error} =
             MeterEvent.create(client, params)

    assert error.status == 400
    assert error.message =~ "payload"
    assert error.message =~ "meta"
    assert error.message =~ "not a string"
    assert error.message =~ "map"
  end
end
