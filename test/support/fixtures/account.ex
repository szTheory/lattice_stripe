defmodule LatticeStripe.Test.Fixtures.Account do
  @moduledoc false

  @doc """
  Fully-populated Account fixture exercising all D-01 nested struct modules:
  BusinessProfile, Requirements (at both `requirements` and `future_requirements`),
  TosAcceptance, Company (business_type=company), and Settings (with sub-objects).

  Capabilities shape follows D-02 with three entries of varying status.

  Includes `zzz_forward_compat_field` at top level and inside `business_profile`
  to exercise F-001 `:extra` map split.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "acct_test1234567890",
        "object" => "account",
        "business_type" => "company",
        "business_profile" => %{
          "mcc" => "5734",
          "monthly_estimated_revenue" => %{"amount" => 10_000, "currency" => "usd"},
          "name" => "Acme Corp",
          "product_description" => "Software tools for teams",
          "support_address" => %{
            "city" => "San Francisco",
            "country" => "US",
            "line1" => "123 Main St",
            "line2" => nil,
            "postal_code" => "94105",
            "state" => "CA"
          },
          "support_email" => "support@acme.test",
          "support_phone" => "+15555550100",
          "support_url" => "https://support.acme.test",
          "url" => "https://acme.test",
          "zzz_forward_compat_field" => "extra_value_in_business_profile"
        },
        "capabilities" => %{
          "card_payments" => %{
            "status" => "active",
            "requested" => true,
            "requested_at" => 1_700_000_000,
            "requirements" => %{"currently_due" => []},
            "disabled_reason" => nil
          },
          "transfers" => %{
            "status" => "pending",
            "requested" => true,
            "requested_at" => 1_700_000_000,
            "requirements" => %{"currently_due" => ["external_account"]},
            "disabled_reason" => nil
          },
          "us_bank_account_payments" => %{
            "status" => "unrequested",
            "requested" => false,
            "requested_at" => nil,
            "requirements" => %{},
            "disabled_reason" => nil
          }
        },
        "charges_enabled" => true,
        "company" => %{
          "name" => "Acme Corp LLC",
          "tax_id" => "00-0000000",
          "phone" => "+15555550101",
          "address" => %{
            "city" => "San Francisco",
            "country" => "US",
            "line1" => "123 Main St",
            "line2" => nil,
            "postal_code" => "94105",
            "state" => "CA"
          },
          "directors_provided" => true,
          "owners_provided" => true,
          "structure" => "private_corporation"
        },
        "controller" => %{
          "fees" => %{"payer" => "application"},
          "is_controller" => true,
          "losses" => %{"payments" => "application"},
          "requirement_collection" => "application",
          "stripe_dashboard" => %{"type" => "none"},
          "type" => "application"
        },
        "country" => "US",
        "created" => 1_700_000_000,
        "default_currency" => "usd",
        "details_submitted" => true,
        "email" => "test@acme.test",
        "external_accounts" => %{
          "object" => "list",
          "data" => [],
          "has_more" => false,
          "url" => "/v1/accounts/acct_test1234567890/external_accounts"
        },
        "future_requirements" => %{
          "alternatives" => [],
          "current_deadline" => nil,
          "currently_due" => [],
          "disabled_reason" => nil,
          "errors" => [],
          "eventually_due" => [],
          "past_due" => [],
          "pending_verification" => []
        },
        "individual" => nil,
        "livemode" => false,
        "metadata" => %{},
        "payouts_enabled" => true,
        "requirements" => %{
          "alternatives" => [],
          "current_deadline" => nil,
          "currently_due" => ["business_profile.mcc", "business_profile.url"],
          "disabled_reason" => nil,
          "errors" => [],
          "eventually_due" => ["individual.dob.day"],
          "past_due" => [],
          "pending_verification" => []
        },
        "settings" => %{
          "branding" => %{
            "icon" => nil,
            "logo" => nil,
            "primary_color" => "#7c5cfc",
            "secondary_color" => nil
          },
          "card_payments" => %{
            "decline_on" => %{"avs_failure" => false, "cvc_failure" => false},
            "statement_descriptor_prefix" => nil,
            "statement_descriptor_prefix_kanji" => nil,
            "statement_descriptor_prefix_kana" => nil
          },
          "dashboard" => %{
            "display_name" => "Acme Corp",
            "timezone" => "America/Los_Angeles"
          },
          "payments" => %{
            "statement_descriptor" => "ACME CORP",
            "statement_descriptor_kanji" => nil,
            "statement_descriptor_kana" => nil
          },
          "payouts" => %{
            "debit_negative_balances" => true,
            "schedule" => %{"delay_days" => 2, "interval" => "daily"},
            "statement_descriptor" => nil
          }
        },
        "tos_acceptance" => %{
          "date" => 1_700_000_000,
          "ip" => "203.0.113.42",
          "service_agreement" => "full",
          "user_agent" => "Mozilla/5.0 Test"
        },
        "type" => "custom",
        "zzz_forward_compat_field" => "extra_value_at_top_level"
      },
      overrides
    )
  end

  @doc """
  Variant that merges additional capability entries into `basic/1`.
  Useful for testing `Capability.status_atom/1` unknown-status fallthrough.
  """
  def with_capabilities(extra_caps, overrides \\ %{}) do
    base = basic(overrides)
    updated_caps = Map.merge(base["capabilities"], extra_caps)
    Map.put(base, "capabilities", updated_caps)
  end

  @doc """
  Stripe-shape delete response for an account: `{"id", "object", "deleted": true}`.
  """
  def deleted(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "acct_test1234567890",
        "object" => "account",
        "deleted" => true
      },
      overrides
    )
  end

  @doc """
  Wraps `basic/1` in a Stripe list-response envelope.
  """
  def list_response(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "list",
        "data" => [basic()],
        "has_more" => false,
        "url" => "/v1/accounts"
      },
      overrides
    )
  end
end
