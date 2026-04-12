defmodule LatticeStripe.ConfigTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Config

  describe "validate!/1" do
    test "returns validated keyword list with defaults when required fields present" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch)
      assert is_list(result)
      assert result[:api_key] == "sk_test_123"
      assert result[:finch] == MyFinch
    end

    test "raises NimbleOptions.ValidationError mentioning :api_key when missing" do
      assert_raise NimbleOptions.ValidationError, ~r/api_key/, fn ->
        Config.validate!(finch: MyFinch)
      end
    end

    test "raises NimbleOptions.ValidationError mentioning :finch when missing" do
      assert_raise NimbleOptions.ValidationError, ~r/finch/, fn ->
        Config.validate!(api_key: "sk_test_123")
      end
    end

    test "raises when api_key is not a string" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.validate!(api_key: 123, finch: MyFinch)
      end
    end

    test "defaults applied: base_url, timeout, transport, json_codec, max_retries, retry_strategy, telemetry_enabled" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch)
      assert result[:base_url] == "https://api.stripe.com"
      assert result[:timeout] == 30_000
      assert result[:transport] == LatticeStripe.Transport.Finch
      assert result[:json_codec] == LatticeStripe.Json.Jason
      assert result[:max_retries] == 2
      assert result[:retry_strategy] == LatticeStripe.RetryStrategy.Default
      assert result[:telemetry_enabled] == true
    end

    test "retry_strategy defaults to LatticeStripe.RetryStrategy.Default" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch)
      assert result[:retry_strategy] == LatticeStripe.RetryStrategy.Default
    end

    test "retry_strategy accepts custom module atom" do
      result =
        Config.validate!(
          api_key: "sk_test_123",
          finch: MyFinch,
          retry_strategy: MyApp.CustomRetryStrategy
        )

      assert result[:retry_strategy] == MyApp.CustomRetryStrategy
    end

    test "retry_strategy rejects non-atom value" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.validate!(api_key: "sk_test_123", finch: MyFinch, retry_strategy: "not_an_atom")
      end
    end

    test "max_retries defaults to 2" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch)
      assert result[:max_retries] == 2
    end

    test "custom values override defaults" do
      result =
        Config.validate!(
          api_key: "sk_test",
          finch: MyFinch,
          timeout: 60_000,
          base_url: "http://localhost:12111"
        )

      assert result[:timeout] == 60_000
      assert result[:base_url] == "http://localhost:12111"
    end

    test "stripe_account accepts string" do
      result =
        Config.validate!(api_key: "sk_test_123", finch: MyFinch, stripe_account: "acct_123")

      assert result[:stripe_account] == "acct_123"
    end

    test "stripe_account accepts nil" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch, stripe_account: nil)
      assert result[:stripe_account] == nil
    end

    test "api_version defaults to a string (pinned Stripe version)" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch)
      assert is_binary(result[:api_version])
      assert String.length(result[:api_version]) > 0
    end

    test "api_version default matches LatticeStripe.api_version/0" do
      schema_default = Config.schema().schema[:api_version][:default]
      assert schema_default == LatticeStripe.api_version()
    end

    test "require_explicit_proration defaults to false" do
      result = Config.validate!(api_key: "sk_test_123", finch: MyFinch)
      assert result[:require_explicit_proration] == false
    end

    test "require_explicit_proration accepts true" do
      result =
        Config.validate!(
          api_key: "sk_test_123",
          finch: MyFinch,
          require_explicit_proration: true
        )

      assert result[:require_explicit_proration] == true
    end

    test "require_explicit_proration rejects non-boolean" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.validate!(
          api_key: "sk_test_123",
          finch: MyFinch,
          require_explicit_proration: "yes"
        )
      end
    end
  end

  describe "validate/1" do
    test "returns {:ok, validated} on success" do
      assert {:ok, result} = Config.validate(api_key: "sk_test_123", finch: MyFinch)
      assert result[:api_key] == "sk_test_123"
    end

    test "returns {:error, %NimbleOptions.ValidationError{}} on failure" do
      assert {:error, %NimbleOptions.ValidationError{}} = Config.validate([])
    end
  end
end
