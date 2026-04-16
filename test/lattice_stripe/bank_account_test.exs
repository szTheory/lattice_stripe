defmodule LatticeStripe.BankAccountTest do
  use ExUnit.Case, async: true

  import LatticeStripe.Test.Fixtures.BankAccount

  alias LatticeStripe.BankAccount

  describe "cast/1" do
    test "maps all known fields from a Stripe bank_account map" do
      ba = BankAccount.cast(basic())

      assert %BankAccount{} = ba
      assert ba.id == "ba_1OoKqrJ2eZvKYlo2C9hXqGtR"
      assert ba.object == "bank_account"
      assert ba.account == "acct_1OoKpqJ2eZvKYlo2"
      assert ba.account_holder_name == "Jane Doe"
      assert ba.account_holder_type == "individual"
      assert ba.account_type == "checking"
      assert ba.available_payout_methods == ["standard", "instant"]
      assert ba.bank_name == "STRIPE TEST BANK"
      assert ba.country == "US"
      assert ba.currency == "usd"
      assert ba.default_for_currency == true
      assert ba.fingerprint == "fp_ba_abcdef1234567890"
      assert ba.last4 == "6789"
      assert ba.metadata == %{}
      assert ba.routing_number == "110000000"
      assert ba.status == :new
      assert ba.extra == %{}
    end

    test "nil returns nil" do
      assert BankAccount.cast(nil) == nil
    end

    test "preserves unknown fields in :extra (F-001)" do
      ba = BankAccount.cast(basic(%{"future_field" => "x", "another" => 42}))

      assert ba.extra == %{"future_field" => "x", "another" => 42}
    end

    test "preserves the deleted=true flag from a DELETE response in :extra" do
      ba = BankAccount.cast(deleted())

      assert ba.id == "ba_1OoKqrJ2eZvKYlo2C9hXqGtR"
      assert ba.object == "bank_account"
      assert ba.extra == %{"deleted" => true}
    end

    test "from_map/1 is an alias for cast/1" do
      assert BankAccount.from_map(basic()) == BankAccount.cast(basic())
    end
  end

  describe "cast/1 status atomization" do
    test "atomizes 'new' to :new" do
      ba = BankAccount.cast(basic(%{"status" => "new"}))
      assert ba.status == :new
    end

    test "atomizes 'validated' to :validated" do
      ba = BankAccount.cast(basic(%{"status" => "validated"}))
      assert ba.status == :validated
    end

    test "atomizes 'verified' to :verified" do
      ba = BankAccount.cast(basic(%{"status" => "verified"}))
      assert ba.status == :verified
    end

    test "atomizes 'verification_failed' to :verification_failed" do
      ba = BankAccount.cast(basic(%{"status" => "verification_failed"}))
      assert ba.status == :verification_failed
    end

    test "atomizes 'errored' to :errored" do
      ba = BankAccount.cast(basic(%{"status" => "errored"}))
      assert ba.status == :errored
    end

    test "passes through unknown status string" do
      ba = BankAccount.cast(basic(%{"status" => "future_status"}))
      assert ba.status == "future_status"
    end

    test "passes through nil status" do
      ba = BankAccount.cast(basic(%{"status" => nil}))
      assert ba.status == nil
    end
  end

  describe "cast/1 customer expand guard" do
    test "customer stays as nil when absent" do
      ba = BankAccount.cast(basic())
      assert ba.customer == nil
    end

    test "customer stays as string ID when not expanded" do
      ba = BankAccount.cast(basic(%{"customer" => "cus_abc"}))
      assert ba.customer == "cus_abc"
    end

    test "customer dispatches to Customer.from_map when expanded map" do
      ba =
        BankAccount.cast(
          basic(%{
            "customer" => %{
              "id" => "cus_abc",
              "object" => "customer",
              "email" => "test@example.com"
            }
          })
        )

      assert %LatticeStripe.Customer{id: "cus_abc"} = ba.customer
    end
  end

  describe "Inspect (PII hide-list)" do
    test "inspect output contains id, object, bank_name, country, currency, status" do
      ba = BankAccount.cast(basic())
      out = inspect(ba)

      assert out =~ "LatticeStripe.BankAccount"
      assert out =~ "ba_1OoKqrJ2eZvKYlo2C9hXqGtR"
      assert out =~ "bank_account"
      assert out =~ "STRIPE TEST BANK"
      assert out =~ "US"
      assert out =~ "usd"
      assert out =~ "new"
    end

    test "inspect output does NOT contain routing_number, account_number, fingerprint, last4, account_holder_name" do
      ba = BankAccount.cast(with_account_number())
      out = inspect(ba)

      refute out =~ "110000000"
      refute out =~ "000123456789"
      refute out =~ "fp_ba_abcdef1234567890"
      refute out =~ "6789"
      refute out =~ "Jane Doe"
    end
  end
end
