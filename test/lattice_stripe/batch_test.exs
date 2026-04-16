defmodule LatticeStripe.BatchTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Batch, Error}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # run/3 — happy path
  # ---------------------------------------------------------------------------

  describe "run/3 — happy path" do
    test "returns {:ok, results} with one {:ok, _} per task, order preserved" do
      client = test_client()

      stub(LatticeStripe.MockTransport, :request, fn req ->
        cond do
          req.url =~ "customers/cus_123" ->
            ok_response(%{"id" => "cus_123", "object" => "customer"})

          req.url =~ "subscriptions" ->
            ok_response(%{
              "object" => "list",
              "data" => [],
              "has_more" => false,
              "url" => "/v1/subscriptions"
            })

          true ->
            ok_response(%{
              "object" => "list",
              "data" => [],
              "has_more" => false,
              "url" => "/v1/invoices"
            })
        end
      end)

      tasks = [
        {LatticeStripe.Customer, :retrieve, ["cus_123"]},
        {LatticeStripe.Subscription, :list, [%{}]},
        {LatticeStripe.Invoice, :list, [%{}]}
      ]

      assert {:ok, results} = Batch.run(client, tasks)
      assert length(results) == 3
      assert [{:ok, _}, {:ok, _}, {:ok, _}] = results
    end

    test "client is prepended to args automatically" do
      client = test_client()

      stub(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "customers/cus_123"
        ok_response(%{"id" => "cus_123", "object" => "customer"})
      end)

      tasks = [{LatticeStripe.Customer, :retrieve, ["cus_123"]}]

      assert {:ok, [{:ok, _}]} = Batch.run(client, tasks)
    end
  end

  # ---------------------------------------------------------------------------
  # run/3 — error isolation
  # ---------------------------------------------------------------------------

  describe "run/3 — error isolation" do
    test "one failing task returns {:error, %Error{}} in its slot, others succeed" do
      client = test_client()
      call_count = :counters.new(1, [])

      stub(LatticeStripe.MockTransport, :request, fn _req ->
        idx = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if idx == 0 do
          ok_response(%{"id" => "cus_123", "object" => "customer"})
        else
          error_response()
        end
      end)

      tasks = [
        {LatticeStripe.Customer, :retrieve, ["cus_123"]},
        {LatticeStripe.Customer, :retrieve, ["cus_bad"]}
      ]

      assert {:ok, results} = Batch.run(client, tasks)
      assert length(results) == 2
      assert [{:ok, _}, {:error, %Error{}}] = results
    end

    test "task that raises returns {:error, %Error{type: :connection_error}} without crashing caller" do
      client = test_client()

      stub(LatticeStripe.MockTransport, :request, fn _req ->
        raise RuntimeError, "unexpected transport failure"
      end)

      tasks = [{LatticeStripe.Customer, :retrieve, ["cus_123"]}]

      assert {:ok, [{:error, %Error{type: :connection_error}}]} = Batch.run(client, tasks)
      assert Process.alive?(self())
    end
  end

  # ---------------------------------------------------------------------------
  # run/3 — validation
  # ---------------------------------------------------------------------------

  describe "run/3 — validation" do
    test "empty task list returns {:error, %Error{type: :invalid_request_error}}" do
      client = test_client()
      assert {:error, %Error{type: :invalid_request_error}} = Batch.run(client, [])
    end

    test "invalid MFA tuple returns {:error, %Error{type: :invalid_request_error}}" do
      client = test_client()

      assert {:error, %Error{type: :invalid_request_error, message: msg}} =
               Batch.run(client, [{"not_atom", :retrieve, []}])

      assert msg =~ "invalid task"
    end
  end

  # ---------------------------------------------------------------------------
  # run/3 — options
  # ---------------------------------------------------------------------------

  describe "run/3 — options" do
    test "accepts max_concurrency option" do
      client = test_client()

      stub(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(%{"id" => "cus_123", "object" => "customer"})
      end)

      tasks = [{LatticeStripe.Customer, :retrieve, ["cus_123"]}]

      assert {:ok, results} = Batch.run(client, tasks, max_concurrency: 1)
      assert [{:ok, _}] = results
    end
  end
end
