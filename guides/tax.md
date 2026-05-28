# Stripe Tax

Stripe Tax helps you calculate, collect, and report sales tax, VAT, and GST.
LatticeStripe exposes the Tax resource family as typed modules under
`LatticeStripe.Tax.*` plus top-level `LatticeStripe.TaxId` for customer tax
identification numbers.

This guide covers SDK primitives for custom payment flows (calculate → record →
reverse), account configuration (settings and registrations), and Tax ID
management. Code examples reflect function signatures shipped in v1.6.

## Scope boundary

LatticeStripe is an HTTP client SDK — typed resources, `{:ok, struct}` /
`{:error, %LatticeStripe.Error{}}`, and Testing fixtures. Nothing more.

**In scope:** `Tax.Calculation`, `Tax.Transaction`, `Tax.Settings`,
`Tax.Registration`, and `TaxId` CRUDL.

Tax filing, returns preparation, nexus threshold monitoring, and jurisdiction
registration with government agencies are **out of SDK scope**. Those
workflows belong in your application or downstream in
[Accrue](https://github.com/sztheory/accrue) (an early LatticeStripe consumer).
LatticeStripe stays lower-level than Accrue so the SDK remains correct for any
Elixir Stripe integration.

For Stripe-hosted billing flows, use automatic tax on Invoices, Checkout,
Subscriptions, or Quotes instead of the standalone Calculations API.

## Choose your path

Pick one model before reading Calculation moduledocs — mixing them causes
integration confusion.

### Path A — Automatic tax on Billing resources

Enable tax via nested `automatic_tax` on Billing resources:

| Surface | When to use |
|---------|-------------|
| `LatticeStripe.Invoice` | B2B/B2C invoicing |
| `LatticeStripe.Checkout.Session` | Hosted or embedded checkout |
| `LatticeStripe.Subscription` | Recurring billing |
| `LatticeStripe.Quote` | Quotes converting to invoices |

`LatticeStripe.Invoice.AutomaticTax` is a **nested struct** on invoice payloads —
not a standalone API module. Stripe calculates tax from the customer address and
your Tax Settings when the invoice finalizes. You do **not** call
`Tax.Calculation.create/3` on this path.

See [invoices.md](invoices.md) and [subscriptions.md](subscriptions.md) for
`automatic_tax` examples.

### Path B — Standalone Tax Calculations API

When you own the payment flow (custom cart, marketplace, POS bridge):

1. `LatticeStripe.Tax.Calculation.create/3` — ephemeral tax quote
2. `LatticeStripe.Tax.Transaction.create_from_calculation/3` — durable record
3. `LatticeStripe.Tax.Transaction.create_reversal/3` — undo on refund

This guide's primary spine. Stripe depth:
[Custom payment flows](https://docs.stripe.com/tax/custom),
[Standalone Tax API](https://docs.stripe.com/tax/standalone-tax-api).

### Path C — Tax IDs only

B2B VAT often needs `TaxId` without standalone calculations — see
[TaxId](#taxid-dual-path-api). Tax IDs inform automatic tax and calculation
`customer_details` but do not replace Path A or B.

## Mental model

```
Tax.Settings (singleton defaults)
  └── tax_code, tax_behavior fallbacks
          │
Tax.Registration (jurisdiction config in Stripe)
  └── country_options — where you collect (not legal registration)
          │
          ▼
Tax.Calculation (ephemeral quote, ~90 days)
  ├── expires_at
  └── tax_amount_exclusive / inclusive, line_items
          │
          │  Transaction.create_from_calculation/3
          ▼
Tax.Transaction (durable record)
  ├── reference — globally unique in your Stripe account
  └── type: "transaction"
          │
          │  Transaction.create_reversal/3
          ▼
Tax.Transaction (type: "reversal")
```

**Calculations** are working snapshots, not compliance records. **Transactions**
are durable — pair each charge with a transaction and each full refund with a
reversal.

Calculations expire after roughly **90 days**. Check `expires_at` on
`%Calculation{}` and call `create_from_calculation/3` before that deadline.

## Configure once

Configure tax at deploy or admin time, not on every checkout.

### Tax.Settings — account defaults

`LatticeStripe.Tax.Settings` is a **singleton** (no resource ID):

```elixir
{:ok, settings} = LatticeStripe.Tax.Settings.retrieve(client)

{:ok, settings} =
  LatticeStripe.Tax.Settings.update(client, %{
    "defaults" => %{
      "tax_behavior" => "exclusive",
      "tax_code" => "txcd_99999999"
    }
  })
```

`defaults` supplies fallbacks when line items in `Calculation.create/3` omit
`tax_code` or `tax_behavior`. Check `status` / `status_details` for whether Tax
is active. Pass `stripe_account: "acct_..."` in opts for Connect (same as
`Balance.retrieve/2`). Stripe does not support unsetting defaults fields via
API — only changing values.

### Tax.Registration — where you collect

`LatticeStripe.Tax.Registration` tells Stripe which jurisdictions you collect in.
**Creating a registration does not register you with tax authorities** — legal
registration with government agencies remains your responsibility.

Params require nested `country_options` keyed by lowercase ISO codes matching
top-level `"country"`. Do **not** pass `type` at the top level.

**US state sales tax:**

```elixir
{:ok, _} =
  LatticeStripe.Tax.Registration.create(client, %{
    "country" => "US",
    "country_options" => %{
      "us" => %{"type" => "state_sales_tax", "state" => "CA"}
    }
  })
```

**EU OSS (non-US):**

```elixir
{:ok, _} =
  LatticeStripe.Tax.Registration.create(client, %{
    "country" => "DE",
    "country_options" => %{
      "de" => %{"type" => "oss_union", "oss_union" => "standard"}
    }
  })
```

See [Stripe Tax Registrations](https://docs.stripe.com/api/tax/registrations) for
the full `country_options` matrix. Use `Registration.stream!/3` when listing
many jurisdictions (`list/3` returns `%LatticeStripe.List{}`, not `Enumerable`).

## Primary spine: calculate → record → reverse

Aligned with `test/lattice_stripe/tax/calculation_transaction_test.exs`.

### Step 1 — Calculate

```elixir
client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)

{:ok, calc} =
  LatticeStripe.Tax.Calculation.create(client, %{
    "currency" => "usd",
    "customer_details" => %{
      "address" => %{
        "line1" => "123 Main St",
        "city" => "Seattle",
        "state" => "WA",
        "postal_code" => "98101",
        "country" => "US"
      },
      "address_source" => "shipping"
    },
    "line_items" => [
      %{
        "amount" => 1000,
        "reference" => "line-1",
        "tax_behavior" => "exclusive",
        "tax_code" => "txcd_99999999"
      }
    ]
  })
```

Line item `"reference"` identifies rows within the calculation — distinct from
the transaction `reference` below. Use `Calculation.retrieve/3` and
`Calculation.list_line_items/4` for follow-up reads.

### Step 2 — Record

```elixir
reference = "order_#{order.id}"

{:ok, txn} =
  LatticeStripe.Tax.Transaction.create_from_calculation(client, %{
    "calculation" => calc.id,
    "reference" => reference
  })
```

#### The `reference` must be globally unique

The `reference` passed to `create_from_calculation/3` must be **globally unique**
across all tax transactions in your Stripe account — not per-customer or
per-session. Stripe rejects duplicates account-wide.

```elixir
reference = "order_#{order.id}"           # good — stable domain id
reference = "charge_#{Ecto.UUID.generate()}"  # good — one-offs
reference = "order_42"                    # risky — colliding order numbers
```

Use a **different** reference for reversals (e.g. `"#{reference}-rev"`).

### Step 3 — Reverse on refund

```elixir
{:ok, reversal} =
  LatticeStripe.Tax.Transaction.create_reversal(client, %{
    "mode" => "full",
    "original_transaction" => txn.id,
    "reference" => "#{reference}-rev"
  })
```

Partial refunds use `"mode" => "partial"` with line-item references — see
Stripe's Transactions API docs.

### Timing checklist

| When | Call |
|------|------|
| Checkout quote | `Calculation.create/3` |
| Payment success | `create_from_calculation/3` (within ~90 days) |
| Long checkout | Verify `calc.expires_at` before record |
| Full refund | `create_reversal/3`, new reference |

Store `calc.id`, `txn.id`, and both references in your database for support and
reconciliation.

## TaxId dual-path API

`LatticeStripe.TaxId` manages VAT/EIN/etc. Stripe exposes two URL families;
LatticeStripe routes by **arity** (function signature = HTTP path).

| Operation | Top-level | Customer-nested |
|-----------|-----------|-----------------|
| Create | `create/3` | `create/4` — `customer_id` 2nd after `client` |
| Retrieve | `retrieve/3` | `retrieve/4` |
| List | `list/3` | `list/4` |
| Delete | `delete/3` | `delete/4` |
| Stream | `stream!/3` | `stream!/4` |

No `update/*` (immutable) or `search/*`.

```elixir
# Top-level
{:ok, tax_id} =
  LatticeStripe.TaxId.create(client, %{"type" => "eu_vat", "value" => "DE123456789"})

# Customer-nested — omits "customer" from body; Stripe infers from URL
{:ok, tax_id} =
  LatticeStripe.TaxId.create(client, "cus_123", %{
    "type" => "eu_vat",
    "value" => "DE123456789"
  })
```

Check `tax_id.verification.status` (`:pending`, `:verified`, `:unverified`,
`:unavailable`) for B2B workflows. Type/country formats:
[Stripe Tax IDs](https://docs.stripe.com/billing/taxes/tax-ids).

Tax IDs complement `Invoice.AutomaticTax` and standalone calculations; they do not
replace either path.

## Testing

Unit-test with Mox at Transport and `LatticeStripe.Testing` fixtures:

```elixir
import LatticeStripe.Testing.Fixtures.TaxCalculation
import LatticeStripe.Testing.Fixtures.TaxTransaction

alias LatticeStripe.Testing
alias LatticeStripe.Tax.{Calculation, Transaction}

# Wire map → typed struct
calc = Testing.tax_calculation(tax_calculation_json(%{"id" => "taxcalc_test"}))
reference = "order_#{System.unique_integer([:positive])}"

expect(LatticeStripe.MockTransport, :request, fn req ->
  assert String.ends_with?(req.url, "/v1/tax/transactions/create_from_calculation")
  ok_response(tax_transaction_json(%{"reference" => reference}))
end)

assert {:ok, %Transaction{reference: ^reference}} =
         Transaction.create_from_calculation(client, %{
           "calculation" => calc.id,
           "reference" => reference
         })
```

**Public helpers:** `tax_calculation_json/1`, `tax_transaction_json/1`,
`tax_id_json/1` → `Testing.tax_calculation/1`, `tax_transaction/1`, `tax_id/1`.

`Tax.Settings` / `Tax.Registration` fixtures stay internal in `test/support/`.

Full Mox setup and fixture catalog: [testing.md](testing.md#tax).
Canonical flow test: `test/lattice_stripe/tax/calculation_transaction_test.exs`.

## Error handling

Tax calls return `{:error, %LatticeStripe.Error{}}`. Common cases: duplicate
transaction `reference`, expired calculation past `expires_at`, missing
registration, invalid `country_options`.

Prefer `{:ok, _}` / `{:error, _}` in production; bang variants for scripts only.

See [error-handling.md](error-handling.md) for struct fields, retries, and
idempotency on write endpoints.

## See also

- [payments.md](payments.md) — PaymentIntent lifecycle; calculate tax before
  charging in custom flows
- [error-handling.md](error-handling.md) — `%LatticeStripe.Error{}` reference
- [testing.md](testing.md) — Mox mocks and Tax fixtures
- [invoices.md](invoices.md), [subscriptions.md](subscriptions.md) —
  `automatic_tax` on Billing resources
- [recipes.md](recipes.md) — compact job-to-primitive bridge
- [Stripe Tax: custom payment flows](https://docs.stripe.com/tax/custom)
- [Stripe Standalone Tax API](https://docs.stripe.com/tax/standalone-tax-api)
- [Stripe Tax Calculations](https://docs.stripe.com/api/tax/calculations)
- [Stripe Tax Transactions](https://docs.stripe.com/api/tax/transactions)
- [Stripe Tax IDs](https://docs.stripe.com/api/tax_ids)
