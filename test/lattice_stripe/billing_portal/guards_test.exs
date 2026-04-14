defmodule LatticeStripe.BillingPortal.GuardsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BillingPortal.Guards

  @moduletag :billing_portal

  # ---------------------------------------------------------------------------
  # PORTAL-04 — check_flow_data!/1 guard matrix (D-01 CONTEXT.md test matrix)
  # 10 cases: 3 happy paths, 6 missing-field raises, 1 unknown-type raise.
  # Plus 2 extras: malformed flow_data and non-map flow_data value.
  # All cases are unit-testable without network calls — stripe-mock does NOT
  # enforce sub-field validation (RESEARCH Finding 1).
  # ---------------------------------------------------------------------------

  describe "check_flow_data!/1" do
    test "case 1: no flow_data key → :ok" do
      assert Guards.check_flow_data!(%{}) == :ok
      assert Guards.check_flow_data!(%{"customer" => "cus_123"}) == :ok
    end

    test "case 2: payment_method_update with no sub-fields → :ok" do
      params = %{"flow_data" => %{"type" => "payment_method_update"}}
      assert Guards.check_flow_data!(params) == :ok
    end

    test "case 3: subscription_cancel with required sub-fields → :ok" do
      params = %{
        "flow_data" => %{
          "type" => "subscription_cancel",
          "subscription_cancel" => %{"subscription" => "sub_123"}
        }
      }

      assert Guards.check_flow_data!(params) == :ok
    end

    test "case 4: subscription_cancel with empty subscription_cancel sub-map → raises" do
      params = %{
        "flow_data" => %{
          "type" => "subscription_cancel",
          "subscription_cancel" => %{}
        }
      }

      assert_raise ArgumentError, ~r/subscription_cancel\.subscription/, fn ->
        Guards.check_flow_data!(params)
      end
    end

    test "case 5: subscription_cancel with no subscription_cancel key → raises" do
      params = %{"flow_data" => %{"type" => "subscription_cancel"}}

      assert_raise ArgumentError, ~r/subscription_cancel\.subscription/, fn ->
        Guards.check_flow_data!(params)
      end
    end

    test "case 6: subscription_update with required sub-fields → :ok" do
      params = %{
        "flow_data" => %{
          "type" => "subscription_update",
          "subscription_update" => %{"subscription" => "sub_456"}
        }
      }

      assert Guards.check_flow_data!(params) == :ok
    end

    test "case 7: subscription_update with no subscription_update key → raises" do
      params = %{"flow_data" => %{"type" => "subscription_update"}}

      assert_raise ArgumentError, ~r/subscription_update\.subscription/, fn ->
        Guards.check_flow_data!(params)
      end
    end

    test "case 8: subscription_update_confirm with subscription + non-empty items → :ok" do
      params = %{
        "flow_data" => %{
          "type" => "subscription_update_confirm",
          "subscription_update_confirm" => %{
            "subscription" => "sub_789",
            "items" => [%{}]
          }
        }
      }

      assert Guards.check_flow_data!(params) == :ok
    end

    test "case 9: subscription_update_confirm with empty items list → raises" do
      params = %{
        "flow_data" => %{
          "type" => "subscription_update_confirm",
          "subscription_update_confirm" => %{
            "subscription" => "sub_789",
            "items" => []
          }
        }
      }

      assert_raise ArgumentError,
                   ~r/subscription_update_confirm\.subscription AND \.items/,
                   fn ->
                     Guards.check_flow_data!(params)
                   end
    end

    test "case 10: unknown type string → raises with valid types listed" do
      params = %{"flow_data" => %{"type" => "subscription_pause"}}

      assert_raise ArgumentError, ~r/unknown flow_data\.type/, fn ->
        Guards.check_flow_data!(params)
      end

      error =
        assert_raise ArgumentError, fn ->
          Guards.check_flow_data!(params)
        end

      assert error.message =~ "subscription_cancel"
      assert error.message =~ "subscription_update"
      assert error.message =~ "subscription_update_confirm"
      assert error.message =~ "payment_method_update"
    end

    test "extra: malformed flow_data (no type key) → raises with 'must contain a type key'" do
      params = %{"flow_data" => %{"subscription_cancel" => %{}}}

      error =
        assert_raise ArgumentError, fn ->
          Guards.check_flow_data!(params)
        end

      assert error.message =~ ~s[must contain a "type" key]
    end

    test "extra: non-map flow_data value → :ok via catchall" do
      # Atom-keyed or non-map flow_data bypasses the guard — HTTP layer surfaces Stripe's 400
      params = %{"flow_data" => :not_a_map}
      assert Guards.check_flow_data!(params) == :ok
    end

    # All raise cases must include the fully-qualified function name prefix
    test "all raise cases include the function name prefix" do
      fn_name = "LatticeStripe.BillingPortal.Session.create/3"

      cases = [
        %{"flow_data" => %{"type" => "subscription_cancel"}},
        %{"flow_data" => %{"type" => "subscription_update"}},
        %{
          "flow_data" => %{
            "type" => "subscription_update_confirm",
            "subscription_update_confirm" => %{"subscription" => "sub_1", "items" => []}
          }
        },
        %{"flow_data" => %{"type" => "subscription_pause"}},
        %{"flow_data" => %{"no_type" => true}}
      ]

      for params <- cases do
        error = assert_raise ArgumentError, fn -> Guards.check_flow_data!(params) end
        assert error.message =~ fn_name,
               "Expected message to contain '#{fn_name}', got: #{error.message}"
      end
    end
  end
end
