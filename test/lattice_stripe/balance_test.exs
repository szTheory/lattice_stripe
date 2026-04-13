defmodule LatticeStripe.BalanceTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Balance

  alias LatticeStripe.{Balance, Error}
  alias LatticeStripe.Balance.{Amount, SourceTypes}

  setup :verify_on_exit!

  describe "retrieve/2" do
    test "sends GET /v1/balance and returns {:ok, %Balance{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/balance")
        ok_response(basic())
      end)

      assert {:ok, %Balance{object: "balance"}} = Balance.retrieve(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Balance.retrieve(client)
    end
  end

  describe "retrieve/2 with stripe_account opt" do
    test "threads stripe_account: opt through to the Stripe-Account header end-to-end" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.method == :get
        assert String.ends_with?(req_map.url, "/v1/balance")
        assert {"stripe-account", "acct_123"} in req_map.headers
        ok_response(basic())
      end)

      assert {:ok, %Balance{}} = Balance.retrieve(client, stripe_account: "acct_123")
    end

    test "platform call (no opts) does NOT send the stripe-account header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        refute Enum.any?(req_map.headers, fn {k, _} -> k == "stripe-account" end)
        ok_response(basic())
      end)

      assert {:ok, %Balance{}} = Balance.retrieve(client)
    end
  end

  describe "retrieve!/2" do
    test "returns bare %Balance{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response(basic()) end)

      assert %Balance{object: "balance"} = Balance.retrieve!(client)
    end

    test "raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise LatticeStripe.Error, fn -> Balance.retrieve!(client) end
    end
  end

  describe "from_map/1" do
    test "decodes available/pending/connect_reserved/instant_available into [%Balance.Amount{}]" do
      balance = Balance.from_map(basic())

      assert [%Amount{currency: "usd"} | _] = balance.available
      assert [%Amount{currency: "usd"}] = balance.pending
      assert [%Amount{currency: "usd"}] = balance.connect_reserved
      assert [%Amount{currency: "usd"}] = balance.instant_available
    end

    test "decodes source_types into %Balance.SourceTypes{}" do
      balance = Balance.from_map(basic())
      [usd | _] = balance.available
      assert %SourceTypes{card: 10_000, bank_account: 2_000, fpx: 345} = usd.source_types
    end

    test "nil returns nil" do
      assert Balance.from_map(nil) == nil
    end
  end

  describe "from_map/1 issuing" do
    test "issuing.available decoded into [%Balance.Amount{}]" do
      balance = Balance.from_map(basic())

      assert %{"available" => [%Amount{} = amt]} = balance.issuing
      assert amt.currency == "usd"
      assert amt.amount == 750
    end

    test "issuing with no available list is preserved verbatim" do
      balance = Balance.from_map(basic(%{"issuing" => %{"foo" => "bar"}}))
      assert balance.issuing == %{"foo" => "bar"}
    end
  end

  describe "from_map/1 reuse proof" do
    test "Balance.Amount is the same struct in all 5 call-sites (zero duplication)" do
      balance = Balance.from_map(basic())

      assert match?(%Amount{}, hd(balance.available))
      assert match?(%Amount{}, hd(balance.pending))
      assert match?(%Amount{}, hd(balance.connect_reserved))
      assert match?(%Amount{}, hd(balance.instant_available))

      %{"available" => [issuing_amt | _]} = balance.issuing
      assert match?(%Amount{}, issuing_amt)
    end

    test "instant_available[] carries net_available in :extra per D-05 rule 1" do
      balance = Balance.from_map(basic())
      [amt | _] = balance.instant_available
      assert is_list(amt.extra["net_available"])
    end
  end

  describe "module surface" do
    test "Balance is a singleton — no list/create/update/delete exported" do
      refute function_exported?(LatticeStripe.Balance, :list, 1)
      refute function_exported?(LatticeStripe.Balance, :list, 2)
      refute function_exported?(LatticeStripe.Balance, :list, 3)
      refute function_exported?(LatticeStripe.Balance, :create, 2)
      refute function_exported?(LatticeStripe.Balance, :create, 3)
      refute function_exported?(LatticeStripe.Balance, :update, 3)
      refute function_exported?(LatticeStripe.Balance, :update, 4)
      refute function_exported?(LatticeStripe.Balance, :delete, 2)
      refute function_exported?(LatticeStripe.Balance, :delete, 3)
    end

    test "%Balance{} has no :id field" do
      refute Map.has_key?(%LatticeStripe.Balance{}, :id)
    end

    test "retrieve/2 and retrieve!/2 are exported" do
      assert function_exported?(LatticeStripe.Balance, :retrieve, 1)
      assert function_exported?(LatticeStripe.Balance, :retrieve, 2)
      assert function_exported?(LatticeStripe.Balance, :retrieve!, 1)
      assert function_exported?(LatticeStripe.Balance, :retrieve!, 2)
    end
  end

  describe "F-001" do
    test "unknown top-level field survives in :extra" do
      raw = basic(%{"reserved_field" => "hello"})
      balance = Balance.from_map(raw)
      assert balance.extra["reserved_field"] == "hello"
    end
  end
end
