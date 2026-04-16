defmodule LatticeStripe.Test.Fixtures.BillingPortal do
  @moduledoc false

  defmodule Session do
    @moduledoc false

    @doc """
    Basic BillingPortal.Session fixture with all 11 wire-format fields populated.

    Returns a string-keyed map matching Stripe's wire format. Suitable for
    unit tests that call `LatticeStripe.BillingPortal.Session.from_map/1`.

    The `"url"` field is a fake placeholder — not a real bearer credential.
    Tests MUST assert `refute inspect(session) =~ session.url` to catch Inspect
    regressions (TEST-02, T-21-01 Inspect masking contract).
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "bps_123",
        "object" => "billing_portal.session",
        "customer" => "cus_test123",
        "url" => "https://billing.stripe.com/session/test_token",
        "return_url" => "https://example.com/account",
        "configuration" => "bpc_123",
        "on_behalf_of" => nil,
        "locale" => nil,
        "created" => 1_712_345_678,
        "livemode" => false,
        "flow" => nil
      }
      |> Map.merge(overrides)
    end

    @doc """
    Session fixture with a `payment_method_update` flow.

    The `payment_method_update` flow type has no required sub-fields — only the
    `"type"` key is needed. All other branch keys are nil.
    """
    def with_payment_method_update_flow(overrides \\ %{}) do
      basic(%{
        "flow" => %{
          "type" => "payment_method_update",
          "after_completion" => %{"type" => "portal_homepage"},
          "subscription_cancel" => nil,
          "subscription_update" => nil,
          "subscription_update_confirm" => nil
        }
      })
      |> Map.merge(overrides)
    end

    @doc """
    Session fixture with a `subscription_cancel` flow.

    Includes the required `subscription_cancel.subscription` sub-field. The D-01
    guard enforces this sub-field pre-network; stripe-mock does NOT enforce it
    (RESEARCH Finding 1).
    """
    def with_subscription_cancel_flow(overrides \\ %{}) do
      basic(%{
        "flow" => %{
          "type" => "subscription_cancel",
          "after_completion" => nil,
          "subscription_cancel" => %{
            "subscription" => "sub_123",
            "retention" => nil
          },
          "subscription_update" => nil,
          "subscription_update_confirm" => nil
        }
      })
      |> Map.merge(overrides)
    end

    @doc """
    Session fixture with a `subscription_update` flow.

    Includes the required `subscription_update.subscription` sub-field.
    """
    def with_subscription_update_flow(overrides \\ %{}) do
      basic(%{
        "flow" => %{
          "type" => "subscription_update",
          "after_completion" => nil,
          "subscription_cancel" => nil,
          "subscription_update" => %{
            "subscription" => "sub_456"
          },
          "subscription_update_confirm" => nil
        }
      })
      |> Map.merge(overrides)
    end

    @doc """
    Session fixture with a `subscription_update_confirm` flow.

    Includes the required `subscription_update_confirm.subscription` and
    `.items` (non-empty list) sub-fields. The D-01 guard enforces both.
    """
    def with_subscription_update_confirm_flow(overrides \\ %{}) do
      basic(%{
        "flow" => %{
          "type" => "subscription_update_confirm",
          "after_completion" => nil,
          "subscription_cancel" => nil,
          "subscription_update" => nil,
          "subscription_update_confirm" => %{
            "subscription" => "sub_789",
            "items" => [%{"id" => "si_123", "price" => "price_abc"}],
            "discounts" => []
          }
        }
      })
      |> Map.merge(overrides)
    end
  end

  defmodule Configuration do
    @moduledoc false

    @doc """
    Basic BillingPortal.Configuration fixture with all wire-format fields populated.

    Returns a string-keyed map matching Stripe's wire format. Suitable for
    unit tests that call `LatticeStripe.BillingPortal.Configuration.from_map/1`
    and feature sub-struct tests.
    """
    def basic(overrides \\ %{}) do
      %{
        "id" => "bpc_123",
        "object" => "billing_portal.configuration",
        "active" => true,
        "application" => nil,
        "business_profile" => %{
          "headline" => nil,
          "privacy_policy_url" => nil,
          "terms_of_service_url" => nil
        },
        "created" => 1_712_345_678,
        "default_return_url" => nil,
        "features" => %{
          "customer_update" => %{"allowed_updates" => [], "enabled" => false},
          "invoice_history" => %{"enabled" => true},
          "payment_method_update" => %{"enabled" => false, "payment_method_configuration" => nil},
          "subscription_cancel" => %{
            "cancellation_reason" => %{"enabled" => false, "options" => []},
            "enabled" => false,
            "mode" => "at_period_end",
            "proration_behavior" => "none"
          },
          "subscription_update" => %{
            "billing_cycle_anchor" => nil,
            "default_allowed_updates" => [],
            "enabled" => false,
            "products" => [],
            "proration_behavior" => "none",
            "schedule_at_period_end" => nil,
            "trial_update_behavior" => nil
          }
        },
        "is_default" => false,
        "livemode" => false,
        "login_page" => %{"enabled" => false, "url" => nil},
        "metadata" => %{},
        "name" => nil,
        "updated" => 1_712_345_678
      }
      |> Map.merge(overrides)
    end
  end
end
