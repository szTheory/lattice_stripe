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
    Billing,
    CreditNote,
    Dispute,
    Entitlements,
    Event,
    EventNotification,
    File,
    FileLink,
    Mandate,
    Quote,
    SetupAttempt,
    Tax,
    TaxId,
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
  Converts a canonical Tax Calculation fixture map into `%LatticeStripe.Tax.Calculation{}`.
  """
  @spec tax_calculation(map()) :: Tax.Calculation.t()
  def tax_calculation(raw_map), do: Tax.Calculation.from_map(raw_map)

  @doc """
  Converts a canonical Tax Transaction fixture map into `%LatticeStripe.Tax.Transaction{}`.
  """
  @spec tax_transaction(map()) :: Tax.Transaction.t()
  def tax_transaction(raw_map), do: Tax.Transaction.from_map(raw_map)

  @doc """
  Converts a canonical TaxId fixture map into `%LatticeStripe.TaxId{}`.
  """
  @spec tax_id(map()) :: TaxId.t()
  def tax_id(raw_map), do: TaxId.from_map(raw_map)

  @doc """
  Converts a canonical ActiveEntitlement fixture map into
  `%LatticeStripe.Entitlements.ActiveEntitlement{}`.
  """
  @spec active_entitlement(map()) :: Entitlements.ActiveEntitlement.t()
  def active_entitlement(raw_map), do: Entitlements.ActiveEntitlement.from_map(raw_map)

  @doc """
  Converts a canonical ActiveEntitlementSummary fixture map into
  `%LatticeStripe.Entitlements.ActiveEntitlementSummary{}`.
  """
  @spec active_entitlement_summary(map()) :: Entitlements.ActiveEntitlementSummary.t()
  def active_entitlement_summary(raw_map),
    do: Entitlements.ActiveEntitlementSummary.from_map(raw_map)

  @doc """
  Converts a canonical MeterEvent fixture map into
  `%LatticeStripe.Billing.MeterEvent{}`.
  """
  @spec meter_event(map()) :: Billing.MeterEvent.t()
  def meter_event(raw_map), do: Billing.MeterEvent.from_map(raw_map)

  @doc """
  Converts a canonical MeterEventSummary fixture map into
  `%LatticeStripe.Billing.MeterEventSummary{}`.
  """
  @spec meter_event_summary(map()) :: Billing.MeterEventSummary.t()
  def meter_event_summary(raw_map), do: Billing.MeterEventSummary.from_map(raw_map)

  @doc """
  Converts a canonical thin-event notification fixture map into
  `%LatticeStripe.EventNotification{}`.

  Direct typed-builder parallel to `dispute/1`, `customer/1`, etc. — use this when
  your test needs a typed `%EventNotification{}` value without going through
  signature verification.

  ## Example

      import LatticeStripe.Test.Fixtures.EventNotification

      notif = LatticeStripe.Testing.event_notification(event_notification_map())
      assert notif.type == "v2.core.account.updated"

  When you need a signed wire-format payload (for example to exercise a Phoenix
  controller calling `Webhook.parse_event_notification/4`), use
  `generate_thin_event_payload/3` instead.
  """
  @spec event_notification(map()) :: EventNotification.t()
  def event_notification(raw_map), do: EventNotification.from_map(raw_map)

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

  @doc """
  Generates a signed **thin-event** webhook payload pair for Plug-level testing.

  Thin-event counterpart to `generate_webhook_payload/3` — produces a wire-format
  `/v2/events` notification payload (`object: "v2.core.event"`, ISO 8601 `created`,
  no `data` or `pending_webhooks` keys) and a matching `Stripe-Signature` header.
  Returns `{payload_string, signature_header_value}` that round-trips through
  `LatticeStripe.Webhook.parse_event_notification/4` without modification.

  Use `generate_webhook_payload/3` for snapshot v1 webhooks (`construct_event/4`)
  and this helper for thin-event v2 webhooks (`parse_event_notification/4`).
  Calling the wrong helper produces a structurally-valid payload that decodes to
  a mostly-`nil` struct — keep snapshot and thin-event test paths obviously
  distinct in your test suite.

  ## Parameters

  - `type` - Stripe thin-event type string, e.g. `"v2.core.account.updated"`
  - `related_object_data` - The `related_object` map (`%{"id" => ..., "type" => ...,
    "url" => ...}`) or `nil` for snapshot-style v2 events (default: `nil`)
  - `opts` - Options:
    - `:secret` - Webhook signing secret (required; raises `KeyError` if absent)
    - `:timestamp` - Unix-seconds timestamp integer used both to sign the payload
      and to derive the ISO 8601 `created` field (default: current system time)
    - `:id` - Event ID string (default: `"evt_test_" <> random_hex(16)`)
    - `:context` - Free-form `context` string (default: `nil`)
    - `:livemode` - boolean (default: `false`)

  ## Returns

  `{raw_payload_string, stripe_signature_header_value}` — the same shape as
  `generate_webhook_payload/3`.

  ## Example

      {payload, sig_header} =
        LatticeStripe.Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          %{
            "id" => "acct_test_123",
            "type" => "v2.core.account",
            "url" => "/v2/core/accounts/acct_test_123"
          },
          secret: "whsec_test"
        )

      {:ok, notif} =
        LatticeStripe.Webhook.parse_event_notification(payload, sig_header, "whsec_test")

      assert notif.type == "v2.core.account.updated"
      assert notif.related_object.id == "acct_test_123"

  Pass `nil` for `related_object_data` to produce a snapshot-style v2 event (the
  notification will have `related_object: nil`; adopters dispatch these to
  `Webhook.fetch_event/3` rather than `fetch_related_object/3`).
  """
  @spec generate_thin_event_payload(String.t(), map() | nil, keyword()) ::
          {String.t(), String.t()}
  def generate_thin_event_payload(type, related_object_data \\ nil, opts) do
    {secret, opts} = Keyword.pop!(opts, :secret)
    {timestamp, notif_opts} = Keyword.pop(opts, :timestamp, System.system_time(:second))

    id = Keyword.get(notif_opts, :id, "evt_test_" <> random_hex(16))
    context = Keyword.get(notif_opts, :context)
    livemode = Keyword.get(notif_opts, :livemode, false)

    # ISO 8601 string per Stripe wire format (RESEARCH Finding 2). The same Unix-seconds
    # timestamp signs the payload and is encoded as an ISO 8601 string in `created`.
    created_iso = DateTime.from_unix!(timestamp) |> DateTime.to_iso8601()

    raw_map = %{
      "id" => id,
      # Thin-event wire value per Stripe v2 events spec (RESEARCH Finding 1).
      # Do NOT change to the v2.core.event-notification namespace — `Webhook`
      # routing + EventNotification.from_map both expect this exact string.
      "object" => "v2.core.event",
      "type" => type,
      "created" => created_iso,
      "context" => context,
      "livemode" => livemode,
      "related_object" => related_object_data
    }

    payload = Jason.encode!(raw_map)
    sig_header = Webhook.generate_test_signature(payload, secret, timestamp: timestamp)
    {payload, sig_header}
  end

  defp random_hex(bytes), do: :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
end
