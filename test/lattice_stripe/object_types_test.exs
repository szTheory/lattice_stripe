defmodule LatticeStripe.ObjectTypesTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.ObjectTypes
  alias LatticeStripe.Testing.Fixtures.Entitlements, as: EntitlementsFixture
  alias LatticeStripe.Testing.Fixtures.MeterErrorReport, as: MeterErrorReportFixture
  alias LatticeStripe.Testing.Fixtures.MeterEvent, as: MeterEventFixture
  alias LatticeStripe.Testing.Fixtures.MeterEventSummary, as: MeterEventSummaryFixture

  describe "maybe_deserialize/1" do
    test "returns nil for nil input" do
      assert ObjectTypes.maybe_deserialize(nil) == nil
    end

    test "returns string IDs unchanged" do
      assert ObjectTypes.maybe_deserialize("cus_123") == "cus_123"
      assert ObjectTypes.maybe_deserialize("pi_abc") == "pi_abc"
    end

    test "dispatches customer map to Customer.from_map/1" do
      map = %{"object" => "customer", "id" => "cus_123", "email" => "test@example.com"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Customer{id: "cus_123"} = result
    end

    test "dispatches payment_intent map to PaymentIntent.from_map/1" do
      map = %{
        "object" => "payment_intent",
        "id" => "pi_123",
        "amount" => 2000,
        "currency" => "usd"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.PaymentIntent{id: "pi_123"} = result
    end

    test "dispatches the public entitlement fixture to ActiveEntitlement.from_map/1" do
      # End-to-end tracer: the map comes from the PUBLIC fixture module that ships in the
      # Hex tarball, so this single assertion crosses both the registry row and the newly
      # published surface.
      map = EntitlementsFixture.active_entitlement_json()
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Entitlements.ActiveEntitlement{id: "ent_123"} = result
    end

    test "dispatches the public entitlement summary fixture to ActiveEntitlementSummary.from_map/1" do
      map = EntitlementsFixture.active_entitlement_summary_json()
      result = ObjectTypes.maybe_deserialize(map)

      assert %LatticeStripe.Entitlements.ActiveEntitlementSummary{
               customer: "cus_ABC123customer"
             } = result

      # The refute is the point, not a leftover: Stripe's
      # entitlements.active_entitlement_summary object has NO `id` property — not even an
      # optional one — so the struct deliberately omits :id (Phase 63 F-02). Asserting on an
      # :id here would raise KeyError. Do not "fix" the struct by adding the field.
      refute Map.has_key?(result, :id)
    end

    test "product_feature resolves and deserializes exactly" do
      map = %{
        "object" => "product_feature",
        "id" => "prodft_123",
        "livemode" => false,
        "entitlement_feature" => %{
          "object" => "entitlements.feature",
          "id" => "feat_123",
          "lookup_key" => "advanced_analytics",
          "name" => "Advanced analytics"
        },
        "future_top_level_field" => "retained"
      }

      assert ObjectTypes.fetch_module("product_feature") == {:ok, LatticeStripe.Product.Feature}

      assert %LatticeStripe.Product.Feature{
               id: "prodft_123",
               entitlement_feature: %LatticeStripe.Entitlements.Feature{
                 id: "feat_123",
                 lookup_key: "advanced_analytics"
               },
               extra: %{"future_top_level_field" => "retained"}
             } = ObjectTypes.maybe_deserialize(map)
    end

    test "dispatches the public meter event fixture to MeterEvent.from_map/1" do
      map = MeterEventFixture.meter_event_json()
      result = ObjectTypes.maybe_deserialize(map)

      # Asserted on :event_name, NEVER on the object field — %MeterEvent{} is the EVENT-05
      # minimal shape and has no :object key, so reading that field off the result raises
      # KeyError, even though the wire payload carries "object" => "billing.meter_event"
      # (which is exactly what routed it here).
      assert %LatticeStripe.Billing.MeterEvent{event_name: "api_call"} = result
    end

    test "a deserialized meter event keeps its payload masked in inspect/1 output" do
      # T-65-02. Registering "billing.meter_event" is precisely what lets this struct
      # reach adopter Logger output, crash dumps and telemetry handlers, and its payload
      # carries the customer-mapping key plus the metered value. The custom
      # `defimpl Inspect` in lib/lattice_stripe/billing/meter_event.ex allowlists
      # structural fields only; deleting it would silently start leaking both.
      result = ObjectTypes.maybe_deserialize(MeterEventFixture.meter_event_json())
      rendered = inspect(result)

      refute rendered =~ "cus_test_123"
      refute rendered =~ "stripe_customer_id"
      refute rendered =~ "payload"

      # Structural fields must still be visible — masking, not blanket redaction.
      assert rendered =~ "api_call"
      assert rendered =~ "req_abc"
    end

    test "dispatches the public meter event summary fixture to MeterEventSummary.from_map/1" do
      map = MeterEventSummaryFixture.meter_event_summary_json()
      result = ObjectTypes.maybe_deserialize(map)

      # 42.5 in the pattern pins the FLOAT: `42.5 = 42` does not match, so a silent
      # integer coercion on the read path would fail this test (F-05).
      assert %LatticeStripe.Billing.MeterEventSummary{
               id: "mtrusg_123",
               aggregated_value: 42.5
             } = result

      assert is_float(result.aggregated_value)
    end

    test "dispatches invoice map to Invoice.from_map/1" do
      map = %{"object" => "invoice", "id" => "in_123", "status" => "open"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Invoice{id: "in_123"} = result
    end

    test "dispatches expanded invoice quote back-reference to Quote.from_map/1" do
      invoice =
        ObjectTypes.maybe_deserialize(%{
          "object" => "invoice",
          "id" => "in_123",
          "quote" => %{
            "object" => "quote",
            "id" => "qt_123",
            "status" => "open"
          }
        })

      assert %LatticeStripe.Invoice{quote: %LatticeStripe.Quote{id: "qt_123"}} = invoice
    end

    test "dispatches mandate map to Mandate.from_map/1" do
      map = %{
        "object" => "mandate",
        "id" => "mandate_123",
        "status" => "active",
        "type" => "single_use"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Mandate{id: "mandate_123"} = result
    end

    test "dispatches credit_note map to CreditNote.from_map/1" do
      map = %{"object" => "credit_note", "id" => "cn_123", "status" => "issued"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.CreditNote{id: "cn_123"} = result
    end

    test "dispatches credit_note_line_item map to CreditNote.LineItem.from_map/1" do
      map = %{
        "object" => "credit_note_line_item",
        "id" => "cnli_123",
        "type" => "invoice_line_item"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.CreditNote.LineItem{id: "cnli_123"} = result
    end

    test "dispatches tax.calculation map to Tax.Calculation.from_map/1" do
      map = %{"object" => "tax.calculation", "id" => "taxcalc_x", "currency" => "usd"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Calculation{id: "taxcalc_x"} = result
    end

    test "dispatches tax.transaction map to Tax.Transaction.from_map/1" do
      map = %{"object" => "tax.transaction", "id" => "tax_x", "type" => "transaction"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Transaction{id: "tax_x"} = result
    end

    test "dispatches tax.settings map to Tax.Settings.from_map/1" do
      map = %{
        "object" => "tax.settings",
        "status" => "active",
        "defaults" => %{"tax_behavior" => "exclusive"}
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Settings{status: :active} = result
    end

    test "dispatches tax.registration map to Tax.Registration.from_map/1" do
      map = %{
        "object" => "tax.registration",
        "id" => "taxreg_123",
        "country" => "US",
        "status" => "active"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Tax.Registration{id: "taxreg_123", status: :active} = result
    end

    test "dispatches tax_id map to TaxId.from_map/1" do
      map = %{"object" => "tax_id", "id" => "txi_123", "type" => "eu_vat"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.TaxId{id: "txi_123"} = result
    end

    test "dispatches quote map to Quote.from_map/1" do
      map = %{"object" => "quote", "id" => "qt_123", "status" => "draft"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Quote{id: "qt_123"} = result
    end

    test "dispatches quote_line_item map to Quote.LineItem.from_map/1" do
      map = %{
        "object" => "quote_line_item",
        "id" => "qli_123",
        "description" => "Quoted item"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Quote.LineItem{id: "qli_123"} = result
    end

    test "dispatches setup_attempt map to SetupAttempt.from_map/1" do
      map = %{
        "object" => "setup_attempt",
        "id" => "setatt_123",
        "status" => "succeeded",
        "usage" => "off_session"
      }

      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.SetupAttempt{id: "setatt_123"} = result
    end

    test "dispatches checkout.session map to Checkout.Session.from_map/1" do
      map = %{"object" => "checkout.session", "id" => "cs_123"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Checkout.Session{id: "cs_123"} = result
    end

    test "dispatches subscription map to Subscription.from_map/1" do
      map = %{"object" => "subscription", "id" => "sub_123"}
      result = ObjectTypes.maybe_deserialize(map)
      assert %LatticeStripe.Subscription{id: "sub_123"} = result
    end

    test "returns unknown object types as raw map" do
      map = %{"object" => "unknown_future_type", "id" => "foo_123"}
      assert ObjectTypes.maybe_deserialize(map) == map
    end

    test "product.feature is rejected byte-for-byte" do
      dotted_typo = %{"object" => "product.feature", "id" => "prodft_123"}

      assert ObjectTypes.fetch_module("product.feature") == :error
      assert ObjectTypes.maybe_deserialize(dotted_typo) == dotted_typo
    end

    test "returns maps without 'object' key as raw map" do
      map = %{"id" => "foo_123", "data" => "some_value"}
      assert ObjectTypes.maybe_deserialize(map) == map
    end

    test "returns empty map as raw map" do
      assert ObjectTypes.maybe_deserialize(%{}) == %{}
    end

    test "returns the meter error report payload unchanged — it has no object key" do
      # The structural reason the registry can never deserialize this payload:
      # it is event `data`, not an object, so it carries no "object" key for the
      # dispatch head to match. It comes back as the raw map it went in as.
      data = MeterErrorReportFixture.meter_error_report_json()

      result = ObjectTypes.maybe_deserialize(data)

      assert result == data
      refute is_struct(result)
    end
  end

  describe "fetch_module/1" do
    test "returns {:ok, LatticeStripe.Customer} for 'customer'" do
      assert ObjectTypes.fetch_module("customer") == {:ok, LatticeStripe.Customer}
    end

    test "returns {:ok, LatticeStripe.Invoice} for 'invoice'" do
      assert ObjectTypes.fetch_module("invoice") == {:ok, LatticeStripe.Invoice}
    end

    test "returns :error for unknown v2-namespaced type 'v2.core.account'" do
      # This is the v2-namespaced type which is intentionally NOT in @object_map
      # and will trigger the typed-error gate in fetch_related_object/3 (Phase 47 D-05).
      assert ObjectTypes.fetch_module("v2.core.account") == :error
    end

    test "returns :error for nil" do
      assert ObjectTypes.fetch_module(nil) == :error
    end

    test "returns :error for an empty string" do
      assert ObjectTypes.fetch_module("") == :error
    end

    test "carries no billing.meter_error_report key — the dispatch cannot reach it" do
      # maybe_deserialize/1 dispatches on `%{"object" => object_type}`. The
      # v1.billing.meter.error_report_triggered `data` payload has no "object"
      # key at all, so a registry row for it would be a DEAD key — present,
      # never reached, and assumed to work by the next contributor who sees it.
      # LatticeStripe.Billing.MeterErrorReport.from_event/1 must be called
      # explicitly. Phase 65's OBJ-01 excludes this key for the same reason;
      # this test is what keeps the exclusion from being quietly undone.
      refute Map.has_key?(ObjectTypes.object_map(), "billing.meter_error_report")
      assert ObjectTypes.fetch_module("billing.meter_error_report") == :error
    end

    test "resolves all five Tax family object types" do
      assert ObjectTypes.fetch_module("tax.calculation") == {:ok, LatticeStripe.Tax.Calculation}
      assert ObjectTypes.fetch_module("tax.transaction") == {:ok, LatticeStripe.Tax.Transaction}
      assert ObjectTypes.fetch_module("tax.settings") == {:ok, LatticeStripe.Tax.Settings}
      assert ObjectTypes.fetch_module("tax.registration") == {:ok, LatticeStripe.Tax.Registration}
      assert ObjectTypes.fetch_module("tax_id") == {:ok, LatticeStripe.TaxId}
    end

    test "resolves all four Phase 65 entitlement and meter object types" do
      # Four, not five. The fifth candidate key is deliberately absent — see the
      # dedicated absence test above for why registering it would be a dead row.
      assert ObjectTypes.fetch_module("entitlements.active_entitlement") ==
               {:ok, LatticeStripe.Entitlements.ActiveEntitlement}

      assert ObjectTypes.fetch_module("entitlements.active_entitlement_summary") ==
               {:ok, LatticeStripe.Entitlements.ActiveEntitlementSummary}

      assert ObjectTypes.fetch_module("billing.meter_event") ==
               {:ok, LatticeStripe.Billing.MeterEvent}

      assert ObjectTypes.fetch_module("billing.meter_event_summary") ==
               {:ok, LatticeStripe.Billing.MeterEventSummary}
    end

    test "matches wire strings by exact bytes — no case folding, normalization, or trimming" do
      # Lookup is Map.fetch/2 on a string-keyed map, so a near-miss key is a silently
      # DEAD row rather than a loud failure. Pinning this is what makes a future
      # mis-cased or space-padded registry key fail here instead of in production.
      assert ObjectTypes.fetch_module("Billing.meter_event") == :error
      assert ObjectTypes.fetch_module("BILLING.METER_EVENT") == :error
      assert ObjectTypes.fetch_module(" billing.meter_event") == :error
      assert ObjectTypes.fetch_module("billing.meter_event ") == :error
      assert ObjectTypes.fetch_module("Entitlements.active_entitlement_summary") == :error
    end

    test "every registered object type is triaged as individually retrievable or not" do
      # TRIAGE INVARIANT (Phase 65 UAT checkpoint 3). @object_map has TWO consumers:
      #
      #   1. maybe_deserialize/1 -- decode a %{"object" => _} payload  (the obvious one)
      #   2. Webhook.fetch_related_object/3 -- the D-05 fail-fast HTTP gate (easy to miss)
      #
      # Adding a row for consumer 1 silently changes consumer 2's behaviour for that type:
      # it stops returning {:error, {:unknown_object_type, _}} with zero HTTP and starts
      # issuing GET related_object.url. For a type with no `id` and no single-object
      # endpoint that GET is doomed (404). This partition forces the trade-off to be an
      # EXPLICIT decision instead of a side effect. See the paired characterization tests
      # in test/lattice_stripe/webhook/fetch_test.exs.
      #
      # Deliberately NOT `map_size(object_map()) == 52`. A bare count was rejected as
      # brittle (65-RESEARCH pitfall 7), and it teaches nothing: "expected 52, got 53"
      # names no key. This partition fails by NAMING the new key and stating which list it
      # belongs in. The failure message IS the decision record.
      #
      # This list lives in test/, NOT lib/: @object_map encodes object-type -> module and
      # nothing else. It carries no URL (RelatedObject.url comes verbatim off the wire) and
      # no retrievability flag. Retrievability is a review-time fact about Stripe's REST
      # surface, so asserting it here beats shipping a lib attribute that nothing in lib/
      # reads -- the "decorative attribute is a worse trap" anti-pattern COVERAGE.md
      # invoked against @known_fields on meter_event.ex. Promote to lib/ only if
      # fetch_related_object/3 ever consumes it (deferred-items.md item 2).

      # No `id` and/or no single-object retrieve endpoint. A v2 related_object delivery of
      # one of these would issue a doomed GET rather than failing fast.
      not_individually_retrievable = [
        "account_link",
        "balance",
        "billing.meter_event_summary",
        "credit_note_line_item",
        "entitlements.active_entitlement_summary",
        "line_item",
        "login_link",
        "quote_line_item",
        "tax.calculation_line_item",
        "tax.settings",
        "tax.transaction_line_item"
      ]

      # GET <related_object.url> returns the object.
      individually_retrievable = [
        "account",
        "balance_transaction",
        "bank_account",
        "billing.meter",
        "billing.meter_event",
        "billing_portal.configuration",
        "billing_portal.session",
        "card",
        "charge",
        "checkout.session",
        "coupon",
        "credit_note",
        "customer",
        "dispute",
        "entitlements.active_entitlement",
        "event",
        "file",
        "file_link",
        "invoice",
        "invoiceitem",
        "mandate",
        "payment_intent",
        "payment_method",
        "payout",
        "price",
        "product",
        "product_feature",
        "promotion_code",
        "quote",
        "refund",
        "setup_attempt",
        "setup_intent",
        "subscription",
        "subscription_item",
        "subscription_schedule",
        "tax.calculation",
        "tax.registration",
        "tax.transaction",
        "tax_id",
        "test_helpers.test_clock",
        "transfer",
        "transfer_reversal"
      ]

      retrievable = MapSet.new(individually_retrievable)
      not_retrievable = MapSet.new(not_individually_retrievable)
      registered = ObjectTypes.object_map() |> Map.keys() |> MapSet.new()

      overlap = MapSet.intersection(retrievable, not_retrievable)

      assert MapSet.size(overlap) == 0,
             "A key is in BOTH triage lists: " <> inspect(Enum.sort(overlap))

      untriaged = MapSet.difference(registered, MapSet.union(retrievable, not_retrievable))

      assert MapSet.size(untriaged) == 0, """
      New @object_map row(s) with no retrievability decision:

        #{untriaged |> Enum.sort() |> Enum.map_join("\n  ", &inspect/1)}

      Add each to `individually_retrievable` (GET <related_object.url> returns the object)
      or to `not_individually_retrievable` (no `id` and/or no single-object endpoint — a v2
      related_object delivery would issue a doomed GET; see the characterization test
      "a REGISTERED but non-retrievable type passes the D-05 gate" in
      test/lattice_stripe/webhook/fetch_test.exs).
      """

      dangling = MapSet.difference(MapSet.union(retrievable, not_retrievable), registered)

      assert MapSet.size(dangling) == 0,
             "Triaged keys no longer present in @object_map: " <>
               inspect(Enum.sort(dangling)) <> " — delete the rows."
    end
  end
end
