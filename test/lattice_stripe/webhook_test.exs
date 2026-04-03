defmodule LatticeStripe.WebhookTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Event, Webhook}
  alias LatticeStripe.Webhook.SignatureVerificationError

  @secret "whsec_test_secret"
  @payload Jason.encode!(%{
             "id" => "evt_test",
             "type" => "payment_intent.succeeded",
             "object" => "event",
             "created" => 1_680_000_000,
             "livemode" => false,
             "pending_webhooks" => 1,
             "api_version" => "2026-03-25.dahlia",
             "data" => %{"object" => %{"id" => "pi_abc123"}},
             "request" => nil,
             "account" => nil,
             "context" => nil
           })

  # Helper: produce a fresh valid header for @payload/@secret
  defp valid_header, do: Webhook.generate_test_signature(@payload, @secret)

  # ---------------------------------------------------------------------------
  # verify_signature/3 — ok cases
  # ---------------------------------------------------------------------------

  describe "verify_signature/3 — success" do
    test "returns {:ok, timestamp} when signature matches" do
      header = valid_header()
      assert {:ok, ts} = Webhook.verify_signature(@payload, header, @secret)
      assert is_integer(ts)
    end

    test "timestamp returned matches the t= value in the header" do
      ts = System.system_time(:second)
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: ts)
      assert {:ok, ^ts} = Webhook.verify_signature(@payload, header, @secret, tolerance: 600)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature/3 — error: missing header
  # ---------------------------------------------------------------------------

  describe "verify_signature/3 — :missing_header" do
    test "returns {:error, :missing_header} when sig_header is nil" do
      assert {:error, :missing_header} = Webhook.verify_signature(@payload, nil, @secret)
    end

    test "returns {:error, :missing_header} when sig_header is empty string" do
      assert {:error, :missing_header} = Webhook.verify_signature(@payload, "", @secret)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature/3 — error: invalid header
  # ---------------------------------------------------------------------------

  describe "verify_signature/3 — :invalid_header" do
    test "returns {:error, :invalid_header} when t= part is missing" do
      assert {:error, :invalid_header} = Webhook.verify_signature(@payload, "v1=abc123", @secret)
    end

    test "returns {:error, :invalid_header} when v1= part is missing" do
      ts = System.system_time(:second)
      assert {:error, :invalid_header} = Webhook.verify_signature(@payload, "t=#{ts}", @secret)
    end

    test "returns {:error, :invalid_header} when t= is not a number" do
      assert {:error, :invalid_header} =
               Webhook.verify_signature(@payload, "t=not_a_number,v1=abc123", @secret)
    end

    test "returns {:error, :invalid_header} when header is completely garbage" do
      assert {:error, :invalid_header} =
               Webhook.verify_signature(@payload, "garbage", @secret)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature/3 — error: no matching signature
  # ---------------------------------------------------------------------------

  describe "verify_signature/3 — :no_matching_signature" do
    test "returns {:error, :no_matching_signature} when secret is wrong" do
      header = valid_header()

      assert {:error, :no_matching_signature} =
               Webhook.verify_signature(@payload, header, "wrong_secret")
    end

    test "returns {:error, :no_matching_signature} when payload was tampered" do
      header = valid_header()
      tampered = @payload <> "extra"

      assert {:error, :no_matching_signature} =
               Webhook.verify_signature(tampered, header, @secret)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature/4 — tolerance
  # ---------------------------------------------------------------------------

  describe "verify_signature/4 — :timestamp_expired" do
    test "returns {:error, :timestamp_expired} when timestamp is older than tolerance" do
      old_ts = System.system_time(:second) - 400
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: old_ts)
      # default tolerance 300s — 400s old should fail
      assert {:error, :timestamp_expired} = Webhook.verify_signature(@payload, header, @secret)
    end

    test "returns {:ok, ts} when timestamp is within tolerance window" do
      fresh_ts = System.system_time(:second) - 100
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: fresh_ts)
      assert {:ok, _ts} = Webhook.verify_signature(@payload, header, @secret, tolerance: 300)
    end

    test "tolerance: 0 fails on any non-zero-age timestamp" do
      old_ts = System.system_time(:second) - 1
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: old_ts)

      assert {:error, :timestamp_expired} =
               Webhook.verify_signature(@payload, header, @secret, tolerance: 0)
    end
  end

  # ---------------------------------------------------------------------------
  # multi-secret support
  # ---------------------------------------------------------------------------

  describe "verify_signature/3 — multi-secret" do
    test "returns {:ok, ts} when second secret in list matches" do
      header = valid_header()

      assert {:ok, _ts} =
               Webhook.verify_signature(@payload, header, ["wrong_secret", @secret])
    end

    test "returns {:ok, ts} when first secret in list matches" do
      header = valid_header()

      assert {:ok, _ts} =
               Webhook.verify_signature(@payload, header, [@secret, "other_secret"])
    end

    test "returns {:error, :no_matching_signature} when all secrets are wrong" do
      header = valid_header()

      assert {:error, :no_matching_signature} =
               Webhook.verify_signature(@payload, header, ["wrong1", "wrong2"])
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature!/3 — bang variant
  # ---------------------------------------------------------------------------

  describe "verify_signature!/3" do
    test "returns timestamp integer on success" do
      header = valid_header()
      ts = Webhook.verify_signature!(@payload, header, @secret)
      assert is_integer(ts)
    end

    test "raises SignatureVerificationError with :missing_header reason" do
      assert_raise SignatureVerificationError, fn ->
        Webhook.verify_signature!(@payload, nil, @secret)
      end

      e =
        assert_raise SignatureVerificationError, fn ->
          Webhook.verify_signature!(@payload, nil, @secret)
        end

      assert e.reason == :missing_header
    end

    test "raises SignatureVerificationError with :no_matching_signature reason" do
      header = valid_header()

      e =
        assert_raise SignatureVerificationError, fn ->
          Webhook.verify_signature!(@payload, header, "wrong_secret")
        end

      assert e.reason == :no_matching_signature
    end

    test "raises SignatureVerificationError with :timestamp_expired reason" do
      old_ts = System.system_time(:second) - 400
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: old_ts)

      e =
        assert_raise SignatureVerificationError, fn ->
          Webhook.verify_signature!(@payload, header, @secret)
        end

      assert e.reason == :timestamp_expired
    end
  end

  # ---------------------------------------------------------------------------
  # construct_event/3
  # ---------------------------------------------------------------------------

  describe "construct_event/3" do
    test "returns {:ok, %Event{}} with valid signature" do
      header = valid_header()

      assert {:ok, %Event{type: "payment_intent.succeeded"}} =
               Webhook.construct_event(@payload, header, @secret)
    end

    test "returns {:ok, %Event{}} and decodes payload into typed struct" do
      header = valid_header()
      {:ok, event} = Webhook.construct_event(@payload, header, @secret)
      assert event.id == "evt_test"
      assert event.livemode == false
    end

    test "returns {:error, :no_matching_signature} with invalid signature" do
      header = valid_header()

      assert {:error, :no_matching_signature} =
               Webhook.construct_event(@payload, header, "wrong_secret")
    end

    test "returns {:error, :missing_header} with nil header" do
      assert {:error, :missing_header} =
               Webhook.construct_event(@payload, nil, @secret)
    end
  end

  # ---------------------------------------------------------------------------
  # construct_event!/3 — bang variant
  # ---------------------------------------------------------------------------

  describe "construct_event!/3" do
    test "returns %Event{} struct with valid signature" do
      header = valid_header()
      event = Webhook.construct_event!(@payload, header, @secret)
      assert %Event{} = event
      assert event.type == "payment_intent.succeeded"
    end

    test "raises SignatureVerificationError with invalid signature" do
      header = valid_header()

      e =
        assert_raise SignatureVerificationError, fn ->
          Webhook.construct_event!(@payload, header, "wrong_secret")
        end

      assert e.reason == :no_matching_signature
    end
  end

  # ---------------------------------------------------------------------------
  # generate_test_signature/2 and /3
  # ---------------------------------------------------------------------------

  describe "generate_test_signature/2" do
    test "produces a header string that passes verify_signature/3" do
      header = Webhook.generate_test_signature(@payload, @secret)
      assert {:ok, _ts} = Webhook.verify_signature(@payload, header, @secret)
    end

    test "header format is t=...,v1=..." do
      header = Webhook.generate_test_signature(@payload, @secret)
      assert header =~ ~r/^t=\d+,v1=[a-f0-9]+$/
    end
  end

  describe "generate_test_signature/3 with timestamp option" do
    test "uses provided timestamp in the header" do
      ts = 1_680_000_000
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: ts)
      assert header =~ "t=#{ts}"
    end

    test "produces a verifiable header with custom timestamp and matching tolerance" do
      ts = System.system_time(:second) - 50
      header = Webhook.generate_test_signature(@payload, @secret, timestamp: ts)
      assert {:ok, ^ts} = Webhook.verify_signature(@payload, header, @secret, tolerance: 300)
    end
  end
end
