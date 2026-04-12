defmodule LatticeStripe.Billing.GuardsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Billing.Guards
  alias LatticeStripe.{Client, Error}

  defp test_client(overrides \\ []) do
    defaults = [api_key: "sk_test_123", finch: :test_finch]
    Client.new!(Keyword.merge(defaults, overrides))
  end

  describe "check_proration_required/2" do
    test "returns :ok when require_explicit_proration is false (default), regardless of params" do
      client = test_client(require_explicit_proration: false)
      assert Guards.check_proration_required(client, %{}) == :ok
    end

    test "returns :ok when require_explicit_proration is false and proration_behavior is present" do
      client = test_client(require_explicit_proration: false)
      assert Guards.check_proration_required(client, %{"proration_behavior" => "none"}) == :ok
    end

    test "returns :ok when require_explicit_proration is true and proration_behavior is present" do
      client = test_client(require_explicit_proration: true)
      assert Guards.check_proration_required(client, %{"proration_behavior" => "none"}) == :ok
    end

    test "returns :ok when require_explicit_proration is true and proration_behavior is create_prorations" do
      client = test_client(require_explicit_proration: true)

      assert Guards.check_proration_required(client, %{
               "proration_behavior" => "create_prorations"
             }) == :ok
    end

    test "returns :ok when require_explicit_proration is true and proration_behavior is always_invoice" do
      client = test_client(require_explicit_proration: true)

      assert Guards.check_proration_required(client, %{
               "proration_behavior" => "always_invoice"
             }) == :ok
    end

    test "returns error when require_explicit_proration is true and proration_behavior is missing" do
      client = test_client(require_explicit_proration: true)
      result = Guards.check_proration_required(client, %{})

      assert {:error, %Error{} = error} = result
      assert error.type == :proration_required
      assert error.message =~ "proration_behavior is required"
      assert error.message =~ "require_explicit_proration"
    end

    test "returns :ok when proration_behavior is nested in subscription_details" do
      client = test_client(require_explicit_proration: true)

      params = %{
        "subscription_details" => %{"proration_behavior" => "create_prorations"}
      }

      assert Guards.check_proration_required(client, params) == :ok
    end

    test "returns error when subscription_details exists but has no proration_behavior" do
      client = test_client(require_explicit_proration: true)
      params = %{"subscription_details" => %{"items" => []}}

      assert {:error, %Error{type: :proration_required}} =
               Guards.check_proration_required(client, params)
    end

    test "error message includes valid values guidance" do
      client = test_client(require_explicit_proration: true)
      {:error, error} = Guards.check_proration_required(client, %{"other_param" => "value"})

      assert error.message =~ "create_prorations"
    end
  end
end
