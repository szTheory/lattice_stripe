defmodule LatticeStripe.PriceTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Price
  alias LatticeStripe.Price.{Recurring, Tier}

  describe "Price.from_map/1 — D-03 atomization" do
    test "type=recurring → :recurring" do
      assert Price.from_map(%{"type" => "recurring"}).type == :recurring
    end

    test "type=one_time → :one_time" do
      assert Price.from_map(%{"type" => "one_time"}).type == :one_time
    end

    test "type=unknown → raw string" do
      assert Price.from_map(%{"type" => "future_unknown"}).type == "future_unknown"
    end

    test "billing_scheme atomization" do
      assert Price.from_map(%{"billing_scheme" => "per_unit"}).billing_scheme == :per_unit
      assert Price.from_map(%{"billing_scheme" => "tiered"}).billing_scheme == :tiered
      assert Price.from_map(%{"billing_scheme" => "mystery"}).billing_scheme == "mystery"
    end

    test "tax_behavior atomization" do
      assert Price.from_map(%{"tax_behavior" => "inclusive"}).tax_behavior == :inclusive
      assert Price.from_map(%{"tax_behavior" => "exclusive"}).tax_behavior == :exclusive
      assert Price.from_map(%{"tax_behavior" => "unspecified"}).tax_behavior == :unspecified
    end
  end

  describe "Price.from_map/1 — typed nesteds (D-01)" do
    test "recurring nested decodes to %Price.Recurring{}" do
      p = Price.from_map(%{"recurring" => %{"interval" => "month", "interval_count" => 1}})
      assert %Recurring{interval: :month, interval_count: 1} = p.recurring
    end

    test "recurring nil stays nil" do
      assert Price.from_map(%{"recurring" => nil}).recurring == nil
    end

    test "tiers list decodes to [%Price.Tier{}]" do
      p =
        Price.from_map(%{
          "tiers" => [
            %{"up_to" => 100, "flat_amount" => 1000},
            %{"up_to" => "inf", "unit_amount" => 500}
          ]
        })

      assert [%Tier{up_to: 100}, %Tier{up_to: :inf}] = p.tiers
    end

    test "tiers nil stays nil" do
      assert Price.from_map(%{"tiers" => nil}).tiers == nil
    end
  end

  describe "Price.Recurring.from_map/1" do
    test "atomizes interval" do
      assert Recurring.from_map(%{"interval" => "day"}).interval == :day
      assert Recurring.from_map(%{"interval" => "week"}).interval == :week
      assert Recurring.from_map(%{"interval" => "month"}).interval == :month
      assert Recurring.from_map(%{"interval" => "year"}).interval == :year
    end

    test "unknown interval passes through" do
      assert Recurring.from_map(%{"interval" => "century"}).interval == "century"
    end

    test "atomizes usage_type" do
      assert Recurring.from_map(%{"usage_type" => "licensed"}).usage_type == :licensed
      assert Recurring.from_map(%{"usage_type" => "metered"}).usage_type == :metered
    end

    test "atomizes aggregate_usage including :last_during_period" do
      assert Recurring.from_map(%{"aggregate_usage" => "sum"}).aggregate_usage == :sum

      assert Recurring.from_map(%{"aggregate_usage" => "last_during_period"}).aggregate_usage ==
               :last_during_period

      assert Recurring.from_map(%{"aggregate_usage" => "last_ever"}).aggregate_usage == :last_ever
      assert Recurring.from_map(%{"aggregate_usage" => "max"}).aggregate_usage == :max
    end
  end

  describe "Price.Tier.from_map/1" do
    test "up_to integer stays integer" do
      assert Tier.from_map(%{"up_to" => 100}).up_to == 100
    end

    test "up_to 'inf' becomes :inf" do
      assert Tier.from_map(%{"up_to" => "inf"}).up_to == :inf
    end

    test "up_to nil stays nil" do
      assert Tier.from_map(%{"up_to" => nil}).up_to == nil
    end
  end

  describe "function surface (D-05 forbidden ops absence)" do
    test "CRUD functions exported" do
      assert function_exported?(Price, :create, 2)
      assert function_exported?(Price, :retrieve, 2)
      assert function_exported?(Price, :update, 3)
      assert function_exported?(Price, :list, 1)
      assert function_exported?(Price, :stream!, 1)
      assert function_exported?(Price, :search, 2)
      assert function_exported?(Price, :search_stream!, 2)
    end

    test "D-05: Price.delete is NOT exported (Stripe API constraint)" do
      refute function_exported?(Price, :delete, 2)
      refute function_exported?(Price, :delete, 3)
      refute function_exported?(Price, :delete!, 2)
      refute function_exported?(Price, :delete!, 3)
    end
  end

  describe "documentation contracts" do
    test "D-10: search/3 @doc contains eventual-consistency callout" do
      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Price)

      search_doc =
        Enum.find_value(docs, fn
          {{:function, :search, 3}, _, _, %{"en" => doc}, _} -> doc
          _ -> nil
        end)

      assert is_binary(search_doc)
      assert search_doc =~ "eventual consistency"
      assert search_doc =~ "https://docs.stripe.com/search#data-freshness"
    end

    test "D-05: @moduledoc documents forbidden delete with workaround" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Price)
      assert moduledoc =~ "Operations not supported by the Stripe API"
      assert moduledoc =~ "delete"
      assert moduledoc =~ "active"
    end
  end
end
