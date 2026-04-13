defmodule LatticeStripe.Test.Fixtures.Account do
  @moduledoc false

  @doc """
  Fully-populated Account wire-format map exercising every D-01 nested struct
  module (BusinessProfile, Requirements, TosAcceptance, Company, Individual,
  Settings) and the D-02 Capability inner shape.

  Includes `"zzz_forward_compat_field"` at the top level AND inside
  `"business_profile"` so F-001 `:extra` capture is covered by fixtures.
  """
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "acct_test1234567890",
        "object" => "account",
        "business_type" => "company",
        "business_profile" => %{
          "mcc" => "7372",
          "monthly_estimated_revenue" => %{"amount" => 10_000, "currency" => "usd"},
          "name" => "Acme Corp",
          "product_description" => "Software as a service",
          "support_address" => %{
            "city" => "San Francisco",
            "country" => "US",
            "line1" => "123 Main St",
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
          "address" => %{
            "city" => "San Francisco",
            "country" => "US",
            "line1" => "123 Main St",
            "postal_code" => "94105",
            "state" => "CA"
          },
          "address_kana" => nil,
          "address_kanji" => nil,
          "directors_provided" => true,
          "executives_provided" => true,
          "name" => "Acme Corp",
          "name_kana" => nil,
          "name_kanji" => nil,
          "owners_provided" => true,
          "phone" => "+15555550101",
          "structure" => nil,
          "tax_id" => "00-0000000",
          "tax_id_registrar" => nil,
          "vat_id" => nil,
          "verification" => %{"document" => %{"back" => nil, "details" => nil, "front" => nil}}
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
          "currently_due" => ["external_account"],
          "disabled_reason" => nil,
          "errors" => [],
          "eventually_due" => ["external_account"],
          "past_due" => [],
          "pending_verification" => []
        },
        "settings" => %{
          "branding" => %{
            "icon" => nil,
            "logo" => nil,
            "primary_color" => nil,
            "secondary_color" => nil
          },
          "card_issuing" => %{"tos_acceptance" => %{"date" => nil, "ip" => nil}},
          "card_payments" => %{
            "decline_on" => %{"avs_failure" => false, "cvc_failure" => false},
            "statement_descriptor_prefix" => nil
          },
          "dashboard" => %{"display_name" => "Acme Corp", "timezone" => "US/Pacific"},
          "invoices" => %{"default_account_tax_ids" => nil},
          "payments" => %{
            "statement_descriptor" => "ACME",
            "statement_descriptor_kana" => nil,
            "statement_descriptor_kanji" => nil
          },
          "payouts" => %{
            "debit_negative_balances" => true,
            "schedule" => %{"delay_days" => 2, "interval" => "daily"},
            "statement_descriptor" => nil
          },
          "sepa_debit" => %{"creditor_id" => nil},
          "treasury" => %{"tos_acceptance" => %{"date" => nil, "ip" => nil}}
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

  @doc "Variant with additional capability entries for atom-fallthrough tests."
  def with_capabilities(extra_caps, overrides \\ %{}) do
    base = basic(overrides)
    Map.put(base, "capabilities", Map.merge(base["capabilities"], extra_caps))
  end

  @doc "Deleted account response matching Stripe's delete-response shape."
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

  @doc "Wraps account fixtures into a Stripe list response."
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
