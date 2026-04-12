defmodule LatticeStripe.Test.Fixtures.SubscriptionSchedule do
  @moduledoc false

  @doc """
  Basic active subscription schedule with one phase containing one PhaseItem
  and one AddInvoiceItem. Includes a `default_payment_method` on both
  `default_settings` and the single phase to exercise PII-masking assertions.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "sub_sched_test1234567890",
        "object" => "subscription_schedule",
        "application" => nil,
        "billing_mode" => nil,
        "canceled_at" => nil,
        "completed_at" => nil,
        "created" => 1_700_000_000,
        "current_phase" => %{"start_date" => 1_700_000_000, "end_date" => 1_702_678_400},
        "customer" => "cus_test123",
        "customer_account" => nil,
        "default_settings" => %{
          "application_fee_percent" => nil,
          "automatic_tax" => %{"enabled" => false, "liability" => nil},
          "billing_cycle_anchor" => "automatic",
          "collection_method" => "charge_automatically",
          "default_payment_method" => "pm_default_test",
          "invoice_settings" => %{"days_until_due" => nil},
          "transfer_data" => nil
        },
        "end_behavior" => "release",
        "livemode" => false,
        "metadata" => %{},
        "phases" => [
          %{
            "add_invoice_items" => [
              %{
                "metadata" => %{},
                "price" => "price_setup_fee",
                "quantity" => 1,
                "tax_rates" => []
              }
            ],
            "application_fee_percent" => nil,
            "automatic_tax" => %{"enabled" => false, "liability" => nil},
            "billing_cycle_anchor" => nil,
            "collection_method" => nil,
            "currency" => "usd",
            "default_payment_method" => "pm_phase_test",
            "default_tax_rates" => [],
            "description" => nil,
            "discounts" => [],
            "end_date" => 1_702_678_400,
            "invoice_settings" => nil,
            "items" => [
              %{
                "billing_thresholds" => nil,
                "discounts" => [],
                "metadata" => %{},
                "price" => "price_test123",
                "quantity" => 1,
                "tax_rates" => []
              }
            ],
            "metadata" => %{},
            "on_behalf_of" => nil,
            "proration_behavior" => "create_prorations",
            "start_date" => 1_700_000_000,
            "transfer_data" => nil,
            "trial_end" => nil
          }
        ],
        "released_at" => nil,
        "released_subscription" => nil,
        "status" => "active",
        "subscription" => "sub_test456",
        "test_clock" => nil
      },
      overrides
    )
  end

  @doc "Schedule with two phases — used as a regression guard for phase decoding."
  def with_two_phases(overrides \\ %{}) do
    second_phase = %{
      "add_invoice_items" => [],
      "automatic_tax" => %{"enabled" => false, "liability" => nil},
      "currency" => "usd",
      "default_payment_method" => nil,
      "default_tax_rates" => [],
      "discounts" => [],
      "end_date" => 1_705_356_800,
      "invoice_settings" => nil,
      "items" => [
        %{
          "discounts" => [],
          "metadata" => %{},
          "price" => "price_test_second",
          "quantity" => 2,
          "tax_rates" => []
        }
      ],
      "metadata" => %{},
      "proration_behavior" => "create_prorations",
      "start_date" => 1_702_678_400,
      "trial_end" => nil
    }

    base = basic()
    [first_phase] = base["phases"]

    Map.merge(
      Map.put(base, "phases", [first_phase, second_phase]),
      overrides
    )
  end

  @doc "Canceled schedule fixture."
  def canceled(overrides \\ %{}) do
    basic(
      Map.merge(
        %{
          "status" => "canceled",
          "canceled_at" => 1_701_000_000
        },
        overrides
      )
    )
  end

  @doc "Released schedule fixture (detached from its subscription)."
  def released(overrides \\ %{}) do
    basic(
      Map.merge(
        %{
          "status" => "released",
          "released_at" => 1_701_000_000,
          "released_subscription" => "sub_released789"
        },
        overrides
      )
    )
  end

  @doc "Wraps `count` schedule fixtures into a Stripe list response."
  def list_response(0) do
    %{
      "object" => "list",
      "data" => [],
      "has_more" => false,
      "url" => "/v1/subscription_schedules"
    }
  end

  def list_response(count) when is_integer(count) and count > 0 do
    items = Enum.map(1..count, fn i -> basic(%{"id" => "sub_sched_test#{i}"}) end)

    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => "/v1/subscription_schedules"
    }
  end
end
