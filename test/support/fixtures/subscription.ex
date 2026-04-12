defmodule LatticeStripe.Test.Fixtures.Subscription do
  @moduledoc false

  @doc "Basic active subscription with no items."
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "sub_test1234567890",
        "object" => "subscription",
        "status" => "active",
        "customer" => "cus_test123",
        "livemode" => false,
        "created" => 1_700_000_000,
        "current_period_start" => 1_700_000_000,
        "current_period_end" => 1_702_679_200,
        "cancel_at_period_end" => false,
        "collection_method" => "charge_automatically",
        "currency" => "usd",
        "metadata" => %{},
        "automatic_tax" => %{"enabled" => false, "status" => nil, "liability" => nil},
        "items" => %{
          "object" => "list",
          "data" => [],
          "has_more" => false,
          "url" => "/v1/subscription_items?subscription=sub_test1234567890"
        }
      },
      overrides
    )
  end

  @doc "Subscription with two items, each carrying an id (stripity_stripe regression guard)."
  def with_items(overrides \\ %{}) do
    item1 = %{
      "id" => "si_test1",
      "object" => "subscription_item",
      "subscription" => "sub_test1234567890",
      "quantity" => 1,
      "price" => %{"id" => "price_test1", "unit_amount" => 1000, "currency" => "usd"},
      "created" => 1_700_000_000,
      "metadata" => %{}
    }

    item2 = %{
      "id" => "si_test2",
      "object" => "subscription_item",
      "subscription" => "sub_test1234567890",
      "quantity" => 2,
      "price" => %{"id" => "price_test2", "unit_amount" => 2500, "currency" => "usd"},
      "created" => 1_700_000_000,
      "metadata" => %{}
    }

    basic(
      Map.merge(
        %{
          "items" => %{
            "object" => "list",
            "data" => [item1, item2],
            "has_more" => false,
            "url" => "/v1/subscription_items?subscription=sub_test1234567890"
          }
        },
        overrides
      )
    )
  end

  @doc "Paused subscription (collection paused with keep_as_draft)."
  def paused(overrides \\ %{}) do
    basic(
      Map.merge(
        %{
          "pause_collection" => %{
            "behavior" => "keep_as_draft",
            "resumes_at" => 1_730_000_000
          }
        },
        overrides
      )
    )
  end

  @doc "Canceled subscription with cancellation_details."
  def canceled(overrides \\ %{}) do
    basic(
      Map.merge(
        %{
          "status" => "canceled",
          "canceled_at" => 1_701_000_000,
          "ended_at" => 1_701_000_000,
          "cancellation_details" => %{
            "reason" => "cancellation_requested",
            "feedback" => "too_expensive",
            "comment" => "customer comment"
          }
        },
        overrides
      )
    )
  end
end
