defmodule LatticeStripe.TypedContractDocsTest do
  use ExUnit.Case, async: true

  test "Invoice and Refund docs state their version and response-scope contracts" do
    invoice_module = read_normalized("lib/lattice_stripe/invoice.ex")
    refund_module = read_normalized("lib/lattice_stripe/refund.ex")
    invoice_guide = read_normalized("guides/invoices.md")
    changelog = read_normalized("CHANGELOG.md")

    assert invoice_module =~ "amount_paid_off_stripe"
    assert invoice_module =~ "2026-05-27.dahlia"
    assert invoice_module =~ "API request responses"
    assert invoice_module =~ "2026-03-25.dahlia"
    assert invoice_module =~ "webhook event payloads"

    assert invoice_guide =~ "amount_paid_off_stripe"
    assert invoice_guide =~ "2026-05-27.dahlia"
    assert invoice_guide =~ "API request responses"
    assert invoice_guide =~ "2026-03-25.dahlia"
    assert invoice_guide =~ "webhook event payloads"

    for field <- ["customer", "customer_account", "payment_method"] do
      assert refund_module =~ field
      assert changelog =~ "Refund.#{field}"
    end

    assert refund_module =~ "2026-07-29.dahlia"
    assert refund_module =~ "Refund responses"
    assert refund_module =~ "2026-03-25.dahlia"
    assert refund_module =~ "Availability in webhook event payloads has not been established"

    assert changelog =~ "2026-05-27.dahlia"
    assert changelog =~ "2026-07-29.dahlia"
    assert changelog =~ "Refund API endpoint responses"
    assert changelog =~ "Webhook event availability"
    assert changelog =~ "2026-03-25.dahlia"
  end

  defp read_normalized(path) do
    path
    |> File.read!()
    |> String.replace(~r/\s+/, " ")
  end
end
