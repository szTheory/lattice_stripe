defmodule LatticeStripe.Testing do
  @moduledoc """
  Test helpers for apps using LatticeStripe.

  This module ships with the LatticeStripe hex package so downstream users can
  construct realistic Stripe webhook events in their test suites without needing
  to know Stripe's HMAC signing scheme.

  ## Usage

      # High-level: get a typed %Event{} struct for testing event handlers
      import LatticeStripe.Testing

      test "handles payment_intent.succeeded webhook" do
        event = generate_webhook_event("payment_intent.succeeded", %{
          "id" => "pi_test_123",
          "amount" => 2000,
          "currency" => "usd",
          "status" => "succeeded"
        })

        assert {:ok, :processed} = MyApp.Webhooks.handle(event)
      end

      # Low-level: get a signed raw payload + header for Plug-level testing
      test "verifies webhook signature via Plug" do
        {payload, sig_header} = generate_webhook_payload(
          "customer.created",
          %{"id" => "cus_test_456", "email" => "new@example.com"},
          secret: "whsec_test_secret"
        )

        conn =
          Plug.Test.conn(:post, "/webhooks", payload)
          |> Plug.Conn.put_req_header("stripe-signature", sig_header)
          |> MyApp.Router.call([])

        assert conn.status == 200
      end

  ## Important Note

  This module is intended for use in test environments only. It ships in `lib/`
  (not `test/support/`) so downstream users can import it without configuring
  custom `elixirc_paths` — but it has no side effects and is safe to include in
  production releases.
  """

  alias LatticeStripe.{
    CreditNote,
    Dispute,
    Event,
    File,
    FileLink,
    Mandate,
    Quote,
    SetupAttempt,
    Webhook
  }

  @default_api_version "2026-03-25.dahlia"

  @doc """
  Converts a canonical File fixture map into `%LatticeStripe.File{}`.
  """
  @spec file(map()) :: File.t()
  def file(raw_map), do: File.from_map(raw_map)

  @doc """
  Converts a canonical FileLink fixture map into `%LatticeStripe.FileLink{}`.
  """
  @spec file_link(map()) :: FileLink.t()
  def file_link(raw_map), do: FileLink.from_map(raw_map)

  @doc """
  Converts a canonical Dispute fixture map into `%LatticeStripe.Dispute{}`.
  """
  @spec dispute(map()) :: Dispute.t()
  def dispute(raw_map), do: Dispute.from_map(raw_map)

  @doc """
  Converts a canonical CreditNote fixture map into `%LatticeStripe.CreditNote{}`.
  """
  @spec credit_note(map()) :: CreditNote.t()
  def credit_note(raw_map), do: CreditNote.from_map(raw_map)

  @doc """
  Converts a canonical Mandate fixture map into `%LatticeStripe.Mandate{}`.
  """
  @spec mandate(map()) :: Mandate.t()
  def mandate(raw_map), do: Mandate.from_map(raw_map)

  @doc """
  Converts a canonical SetupAttempt fixture map into `%LatticeStripe.SetupAttempt{}`.
  """
  @spec setup_attempt(map()) :: SetupAttempt.t()
  def setup_attempt(raw_map), do: SetupAttempt.from_map(raw_map)

  @doc """
  Converts a canonical Quote fixture map into `%LatticeStripe.Quote{}`.
  """
  @spec quote(map()) :: Quote.t()
  def quote(raw_map), do: Quote.from_map(raw_map)

  @doc """
  Builds a `%LatticeStripe.Event{}` struct for the given event type and object data.

  Constructs a realistic Stripe event shape without making any HTTP calls.
  The `data.object` map is whatever you pass as `object_data`.

  ## Parameters

  - `type` - Stripe event type string, e.g. `"payment_intent.succeeded"`
  - `object_data` - The `data.object` map for the event (default: `%{}`)
  - `opts` - Options:
    - `:id` - Event ID string (default: `"evt_test_" <> random_hex(16)`)
    - `:api_version` - API version string (default: `"2026-03-25.dahlia"`)
    - `:livemode` - boolean (default: `false`)

  ## Returns

  A `%LatticeStripe.Event{}` struct.

  Canonical raw maps from `LatticeStripe.Testing.Fixtures.*` compose directly
  with this helper.

  ## Example

      file = LatticeStripe.Testing.Fixtures.File.file_json()

      event = LatticeStripe.Testing.generate_webhook_event(
        "payment_intent.succeeded",
        file
      )
      assert event.type == "payment_intent.succeeded"
      assert event.data["object"]["id"] == file["id"]
  """
  @spec generate_webhook_event(String.t(), map(), keyword()) :: Event.t()
  def generate_webhook_event(type, object_data \\ %{}, opts \\ []) do
    id = Keyword.get(opts, :id, "evt_test_" <> random_hex(16))
    api_version = Keyword.get(opts, :api_version, @default_api_version)
    livemode = Keyword.get(opts, :livemode, false)

    %{
      "id" => id,
      "object" => "event",
      "type" => type,
      "api_version" => api_version,
      "created" => System.system_time(:second),
      "livemode" => livemode,
      "pending_webhooks" => 1,
      "request" => %{"id" => nil, "idempotency_key" => nil},
      "data" => %{"object" => object_data}
    }
    |> Event.from_map()
  end

  @doc """
  Generates a signed webhook payload pair for Plug-level testing.

  Returns `{payload_string, signature_header_value}` where the signature
  is computed using `Webhook.generate_test_signature/3`. The returned pair
  passes `Webhook.construct_event/4` without modification.

  The raw event map is JSON-encoded directly (before `Event.from_map/1`) to
  avoid round-trip encoding issues with the `%Event{}` struct.

  ## Parameters

  - `type` - Stripe event type string, e.g. `"customer.created"`
  - `object_data` - The `data.object` map for the event (default: `%{}`)
  - `opts` - Options:
    - `:secret` - Webhook signing secret (required)
    - `:timestamp` - Unix timestamp integer to embed in signature (default: current time)
    - Other opts (`:id`, `:api_version`, `:livemode`) are forwarded to `generate_webhook_event/3`

  ## Returns

  `{raw_payload_string, stripe_signature_header_value}`

  Canonical raw maps from `LatticeStripe.Testing.Fixtures.*` compose directly
  with this helper.

  ## Example

      dispute = LatticeStripe.Testing.Fixtures.Dispute.dispute_json()

      {payload, sig_header} = LatticeStripe.Testing.generate_webhook_payload(
        "payment_intent.succeeded",
        dispute,
        secret: "whsec_test"
      )

      {:ok, event} = LatticeStripe.Webhook.construct_event(payload, sig_header, "whsec_test")
      assert event.type == "payment_intent.succeeded"
  """
  @spec generate_webhook_payload(String.t(), map(), keyword()) :: {String.t(), String.t()}
  def generate_webhook_payload(type, object_data \\ %{}, opts) do
    {secret, opts} = Keyword.pop!(opts, :secret)
    {timestamp, event_opts} = Keyword.pop(opts, :timestamp, System.system_time(:second))

    id = Keyword.get(event_opts, :id, "evt_test_" <> random_hex(16))
    api_version = Keyword.get(event_opts, :api_version, @default_api_version)
    livemode = Keyword.get(event_opts, :livemode, false)

    raw_map = %{
      "id" => id,
      "object" => "event",
      "type" => type,
      "api_version" => api_version,
      "created" => System.system_time(:second),
      "livemode" => livemode,
      "pending_webhooks" => 1,
      "request" => %{"id" => nil, "idempotency_key" => nil},
      "data" => %{"object" => object_data}
    }

    payload = Jason.encode!(raw_map)
    sig_header = Webhook.generate_test_signature(payload, secret, timestamp: timestamp)
    {payload, sig_header}
  end

  defp random_hex(bytes), do: :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
end
