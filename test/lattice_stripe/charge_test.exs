defmodule LatticeStripe.ChargeTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Charge

  alias LatticeStripe.{Charge, Error}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/charges/:id and returns {:ok, %Charge{}} with full field surface" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/charges/ch_3OoLqrJ2eZvKYlo20wxYzAbC")
        ok_response(basic())
      end)

      assert {:ok, charge} = Charge.retrieve(client, "ch_3OoLqrJ2eZvKYlo20wxYzAbC")

      assert %Charge{
               id: "ch_3OoLqrJ2eZvKYlo20wxYzAbC",
               object: "charge",
               amount: 2000,
               amount_captured: 2000,
               amount_refunded: 0,
               application_fee: "fee_1OoLqrJ2eZvKYlo2AbCdEfGh",
               application_fee_amount: 200,
               balance_transaction: "txn_3OoLqrJ2eZvKYlo2BtXyZ",
               captured: true,
               currency: "usd",
               customer: "cus_OoLqrJ2eZvKYlo2",
               livemode: false,
               on_behalf_of: "acct_1Nv0FGQ9RKHgCVdK",
               paid: true,
               payment_intent: "pi_3OoLpqJ2eZvKYlo21fGhIjKl",
               payment_method: "pm_1OoLqrJ2eZvKYlo2NoPqRsTu",
               refunded: false,
               status: :succeeded
             } = charge
    end

    test "threads expand: [\"balance_transaction\"] opts through to Client.request" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/charges/ch_3OoLqrJ2eZvKYlo20wxYzAbC"
        # expand is form-encoded as expand[]=balance_transaction in the query string
        assert req.url =~ "expand"
        assert req.url =~ "balance_transaction"
        ok_response(with_balance_transaction_expanded())
      end)

      assert {:ok, %Charge{balance_transaction: bt}} =
               Charge.retrieve(client, "ch_3OoLqrJ2eZvKYlo20wxYzAbC",
                 expand: ["balance_transaction"]
               )

      # When expanded, balance_transaction is deserialized to a %BalanceTransaction{} struct.
      assert %LatticeStripe.BalanceTransaction{fee_details: fee_details} = bt

      application_fees =
        Enum.filter(fee_details, fn fd -> fd.type == "application_fee" end)

      assert length(application_fees) == 1
    end

    test "raises ArgumentError pre-network when id is empty string" do
      client = test_client()

      assert_raise ArgumentError, ~r/charge id/, fn ->
        Charge.retrieve(client, "")
      end
    end

    test "raises ArgumentError pre-network when id is nil" do
      client = test_client()

      assert_raise ArgumentError, ~r/charge id/, fn ->
        Charge.retrieve(client, nil)
      end
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert {:error, %Error{}} = Charge.retrieve(client, "ch_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve!/3
  # ---------------------------------------------------------------------------

  describe "retrieve!/3" do
    test "returns %Charge{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response(basic()) end)

      assert %Charge{id: "ch_3OoLqrJ2eZvKYlo20wxYzAbC"} =
               Charge.retrieve!(client, "ch_3OoLqrJ2eZvKYlo20wxYzAbC")
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn ->
        Charge.retrieve!(client, "ch_missing")
      end
    end

    test "raises ArgumentError pre-network when id is empty" do
      client = test_client()

      assert_raise ArgumentError, ~r/charge id/, fn ->
        Charge.retrieve!(client, "")
      end
    end

    test "raises ArgumentError pre-network when id is nil" do
      client = test_client()

      assert_raise ArgumentError, ~r/charge id/, fn ->
        Charge.retrieve!(client, nil)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps every known field explicitly" do
      charge = Charge.from_map(basic())

      assert charge.id == "ch_3OoLqrJ2eZvKYlo20wxYzAbC"
      assert charge.object == "charge"
      assert charge.amount == 2000
      assert charge.amount_captured == 2000
      assert charge.amount_refunded == 0
      assert charge.application_fee == "fee_1OoLqrJ2eZvKYlo2AbCdEfGh"
      assert charge.application_fee_amount == 200
      assert charge.balance_transaction == "txn_3OoLqrJ2eZvKYlo2BtXyZ"
      assert charge.captured == true
      assert charge.created == 1_700_000_000
      assert charge.currency == "usd"
      assert charge.customer == "cus_OoLqrJ2eZvKYlo2"
      assert charge.description == "Charge for connect platform fee"
      assert charge.livemode == false
      assert charge.on_behalf_of == "acct_1Nv0FGQ9RKHgCVdK"
      assert charge.paid == true
      assert charge.payment_intent == "pi_3OoLpqJ2eZvKYlo21fGhIjKl"
      assert charge.payment_method == "pm_1OoLqrJ2eZvKYlo2NoPqRsTu"
      assert charge.refunded == false
      assert charge.status == :succeeded
      assert is_map(charge.outcome)
      assert is_map(charge.refunds)
    end

    test "F-001: unknown future Stripe fields survive in :extra" do
      map =
        basic()
        |> Map.put("extra_thing", "future_value")
        |> Map.put("another_unknown", %{"nested" => 1})

      charge = Charge.from_map(map)

      assert charge.extra["extra_thing"] == "future_value"
      assert charge.extra["another_unknown"] == %{"nested" => 1}
    end

    test "known fields are NOT included in :extra" do
      charge = Charge.from_map(basic())

      refute Map.has_key?(charge.extra, "id")
      refute Map.has_key?(charge.extra, "amount")
      refute Map.has_key?(charge.extra, "billing_details")
    end

    test "from_map(nil) returns nil" do
      assert Charge.from_map(nil) == nil
    end

    test "defaults object to 'charge' when missing" do
      charge = Charge.from_map(%{"id" => "ch_x"})
      assert charge.object == "charge"
    end

    test "atomizes status to atom" do
      charge = Charge.from_map(%{"object" => "charge", "status" => "succeeded"})
      assert charge.status == :succeeded
    end

    test "passes through unknown status as string" do
      charge = Charge.from_map(%{"object" => "charge", "status" => "future_unknown"})
      assert charge.status == "future_unknown"
    end

    test "handles nil status" do
      charge = Charge.from_map(%{"object" => "charge", "status" => nil})
      assert charge.status == nil
    end

    test "customer field: keeps string ID when not expanded" do
      charge = Charge.from_map(%{"object" => "charge", "customer" => "cus_123"})
      assert charge.customer == "cus_123"
    end

    test "customer field: deserializes to %Customer{} when expanded" do
      expanded = %{"object" => "customer", "id" => "cus_123", "email" => "x@y.com"}
      charge = Charge.from_map(%{"object" => "charge", "customer" => expanded})
      assert %LatticeStripe.Customer{id: "cus_123"} = charge.customer
    end

    test "customer field: handles nil" do
      charge = Charge.from_map(%{"object" => "charge", "customer" => nil})
      assert charge.customer == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect — PII hide-list
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    setup do
      %{charge: Charge.from_map(with_pii())}
    end

    test "shows id, object, amount, currency, status, captured, paid", %{charge: charge} do
      inspected = inspect(charge)

      assert inspected =~ "ch_3OoLqrJ2eZvKYlo20wxYzAbC"
      assert inspected =~ "charge"
      assert inspected =~ "2000"
      assert inspected =~ "usd"
      assert inspected =~ "succeeded"
      assert inspected =~ "captured"
      assert inspected =~ "paid"
    end

    test "hides billing_details PII (email, name, address, phone)", %{charge: charge} do
      inspected = inspect(charge)

      refute String.contains?(inspected, "sentinel.billing@example.com")
      refute String.contains?(inspected, "SENTINEL_BILLING_NAME")
      refute String.contains?(inspected, "SENTINEL_LINE1")
      refute String.contains?(inspected, "SENTINEL_CITY")
      refute String.contains?(inspected, "SENTINEL_ZIP")
      refute String.contains?(inspected, "+15555550123")
    end

    test "hides payment_method_details (card last4, fingerprint)", %{charge: charge} do
      inspected = inspect(charge)

      refute String.contains?(inspected, "SENTINEL4242")
      refute String.contains?(inspected, "SENTINEL_FP")
    end

    test "hides fraud_details", %{charge: charge} do
      inspected = inspect(charge)

      refute String.contains?(inspected, "SENTINEL_FRAUD_REPORT")
      refute String.contains?(inspected, "SENTINEL_USER_REPORT")
    end

    test "hides receipt_email, receipt_number, receipt_url", %{charge: charge} do
      inspected = inspect(charge)

      refute String.contains?(inspected, "sentinel.receipt@example.com")
      refute String.contains?(inspected, "SENTINEL_RCPT_NUM")
      refute String.contains?(inspected, "SENTINEL_RECEIPT_PATH")
    end

    test "hides customer and payment_method ids", %{charge: charge} do
      inspected = inspect(charge)

      refute String.contains?(inspected, "cus_OoLqrJ2eZvKYlo2")
      refute String.contains?(inspected, "pm_1OoLqrJ2eZvKYlo2NoPqRsTu")
    end
  end

  # ---------------------------------------------------------------------------
  # Module surface — D-06: retrieve-only
  # ---------------------------------------------------------------------------

  describe "module surface (D-06 retrieve-only)" do
    test "does NOT export create/2" do
      refute function_exported?(LatticeStripe.Charge, :create, 2)
      refute function_exported?(LatticeStripe.Charge, :create, 3)
      refute function_exported?(LatticeStripe.Charge, :create!, 2)
      refute function_exported?(LatticeStripe.Charge, :create!, 3)
    end

    test "does NOT export update/3" do
      refute function_exported?(LatticeStripe.Charge, :update, 3)
      refute function_exported?(LatticeStripe.Charge, :update, 4)
      refute function_exported?(LatticeStripe.Charge, :update!, 3)
      refute function_exported?(LatticeStripe.Charge, :update!, 4)
    end

    test "does NOT export capture/3" do
      refute function_exported?(LatticeStripe.Charge, :capture, 2)
      refute function_exported?(LatticeStripe.Charge, :capture, 3)
      refute function_exported?(LatticeStripe.Charge, :capture, 4)
      refute function_exported?(LatticeStripe.Charge, :capture!, 2)
      refute function_exported?(LatticeStripe.Charge, :capture!, 3)
      refute function_exported?(LatticeStripe.Charge, :capture!, 4)
    end

    test "does NOT export cancel/3" do
      refute function_exported?(LatticeStripe.Charge, :cancel, 2)
      refute function_exported?(LatticeStripe.Charge, :cancel, 3)
      refute function_exported?(LatticeStripe.Charge, :cancel, 4)
    end

    test "does NOT export list/2" do
      refute function_exported?(LatticeStripe.Charge, :list, 1)
      refute function_exported?(LatticeStripe.Charge, :list, 2)
      refute function_exported?(LatticeStripe.Charge, :list, 3)
      refute function_exported?(LatticeStripe.Charge, :list!, 1)
      refute function_exported?(LatticeStripe.Charge, :list!, 2)
      refute function_exported?(LatticeStripe.Charge, :list!, 3)
    end

    test "does NOT export stream!/2" do
      refute function_exported?(LatticeStripe.Charge, :stream!, 1)
      refute function_exported?(LatticeStripe.Charge, :stream!, 2)
      refute function_exported?(LatticeStripe.Charge, :stream!, 3)
    end

    test "does NOT export search/2" do
      refute function_exported?(LatticeStripe.Charge, :search, 1)
      refute function_exported?(LatticeStripe.Charge, :search, 2)
      refute function_exported?(LatticeStripe.Charge, :search, 3)
    end

    test "DOES export retrieve/2, retrieve/3, retrieve!/2, retrieve!/3, from_map/1" do
      assert function_exported?(LatticeStripe.Charge, :retrieve, 2)
      assert function_exported?(LatticeStripe.Charge, :retrieve, 3)
      assert function_exported?(LatticeStripe.Charge, :retrieve!, 2)
      assert function_exported?(LatticeStripe.Charge, :retrieve!, 3)
      assert function_exported?(LatticeStripe.Charge, :from_map, 1)
    end
  end
end
