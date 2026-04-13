# Connect

> Onboarding connected accounts and acting on their behalf.

LatticeStripe supports Stripe Connect — the API for platforms that create and
manage connected accounts on behalf of their users (marketplaces, SaaS billing
platforms, payment facilitators). This guide covers the Phase 17 scope:
connected account lifecycle, onboarding URLs, and acting on behalf of a
connected account. Money movement (Transfers, Payouts, Balance, External
Accounts) is covered in the [Payouts guide](payouts.html) once Phase 18 ships.

## Acting on behalf of a connected account

The most common Connect idiom is making Stripe API calls **on behalf of a
connected account** — for example, creating a charge or subscription that
belongs to your user's account rather than your platform account. LatticeStripe
threads the `Stripe-Account` header end-to-end through every resource call
automatically. You do not need to configure anything beyond setting the opt.

There are two ways to set the connected account:

**Option 1: per-client** — useful when your platform holds a key and acts on
behalf of a single connected account for the lifetime of the client:

```elixir
# Per-client (platform acts on one connected account)
client = LatticeStripe.Client.new!(
  api_key: "sk_test_platform_secret",
  finch: MyApp.Finch,
  stripe_account: "acct_connected_customer"
)

# Every call on this client acts on acct_connected_customer
LatticeStripe.Customer.create(client, %{email: "c@example.test"})
LatticeStripe.PaymentIntent.create(client, %{amount: 1000, currency: "usd"})
```

**Option 2: per-request** — useful for multi-tenant platforms that manage many
connected accounts with a single platform client:

```elixir
# Per-request (one platform client, switch connected account per-call)
platform_client = LatticeStripe.Client.new!(
  api_key: "sk_test_platform_secret",
  finch: MyApp.Finch
)

LatticeStripe.Customer.create(platform_client, %{email: "c@example.test"},
  stripe_account: "acct_connected_customer_a")

LatticeStripe.Customer.create(platform_client, %{email: "d@example.test"},
  stripe_account: "acct_connected_customer_b")
```

Per-request takes precedence over per-client: if you set `stripe_account:` in
both the `Client.new!/1` options and the per-call opts, the per-call value wins.

LatticeStripe threads this header through every resource call automatically —
`Customer`, `PaymentIntent`, `Subscription`, `Invoice`, and every other
resource. You do not need to configure anything beyond setting the opt.

## Creating a connected account

To onboard a user, start by creating a connected account:

```elixir
{:ok, account} = LatticeStripe.Account.create(client, %{
  "type" => "express",
  "country" => "US",
  "email" => "seller@example.test"
})
```

Stripe supports three account types:

- **Express** — Stripe-hosted onboarding dashboard with customizable branding.
  Stripe handles most compliance requirements. Recommended for most platforms.
- **Standard** — Your user creates and manages their own Stripe account. Minimal
  platform-side complexity; the connected account is fully autonomous.
- **Custom** — Full white-label control. You are responsible for collecting all
  information and handling all compliance. Complex to implement correctly.

For new platforms, **Express** is the right default. See the
[Account module docs](LatticeStripe.Account.html) for the full field reference.

## Onboarding URL flow

After creating an account, redirect your user to a Stripe-hosted onboarding
page. The flow is:

1. Create the Account (or use an existing one that isn't fully onboarded)
2. Create an `AccountLink` with `type: "account_onboarding"`, a `refresh_url`,
   and a `return_url`
3. Redirect the user to `link.url`
4. The user completes KYC on Stripe-hosted pages
5. Stripe redirects back to your `return_url`
6. Your webhook handler receives `account.updated` events — handle state there,
   do not re-fetch the account in the redirect handler

```elixir
# Step 1 — create or retrieve the account
{:ok, account} = LatticeStripe.Account.create(client, %{
  "type" => "express",
  "country" => "US",
  "email" => "seller@example.test"
})

# Step 2 — create the onboarding link
{:ok, link} = LatticeStripe.AccountLink.create(client, %{
  "account" => account.id,
  "type" => "account_onboarding",
  "refresh_url" => "https://myplatform.example.test/connect/refresh",
  "return_url" => "https://myplatform.example.test/connect/return"
})

# Step 3 — redirect the user
redirect_user_to(link.url)
```

> #### Security: `link.url` is a short-lived bearer token {: .warning}
>
> The `url` field expires approximately 300 seconds after creation. **Do not
> log the URL, do not store it in a database, and do not include it in error
> reports or telemetry payloads.** Redirect the user immediately and let the
> URL expire. If you need a fresh URL, create a new `AccountLink` — they are
> cheap (T-17-02).

If the user lands on your `refresh_url` (expired link, browser back, etc.),
create a new `AccountLink` for the same `account.id` and redirect again. The
`refresh_url` exists specifically to handle this case.

## Login Links (return path for Express accounts)

After a user has onboarded, you can generate a single-use Express dashboard
URL so they can return to review their account, payouts, and disputes:

```elixir
{:ok, link} = LatticeStripe.LoginLink.create(client, "acct_connected_123")
redirect_user_to(link.url)
```

Note the signature deviation: `account_id` is the second positional argument
rather than a key inside the params map. This matches the Stripe API wire shape
(`POST /v1/accounts/:account_id/login_links`) and every other Stripe SDK.
See the [LoginLink module docs](LatticeStripe.LoginLink.html) for the full
rationale.

Login Links are **Express-only**. Calling this on a Standard or Custom account
returns `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`.

> #### Security: `link.url` is a short-lived bearer token {: .warning}
>
> Like `AccountLink`, the returned URL is a bearer token granting the holder
> access to the connected account's Express dashboard. **Do not log, store,
> or include the URL in telemetry payloads.** Redirect the user immediately
> (T-17-02).

## Handling capabilities

Stripe capabilities control which payment methods and features are available to
a connected account. LatticeStripe does NOT provide a `request_capability/4`
helper — capability names are an open, growing set (~30+ identifiers), and any
hardcoded whitelist would go stale within a quarter. Use `update/4` with the
nested-map idiom instead:

```elixir
LatticeStripe.Account.update(client, "acct_123", %{
  capabilities: %{
    "card_payments" => %{requested: true},
    "transfers" => %{requested: true}
  }
})
```

To check whether a capability is active, use
`LatticeStripe.Account.Capability.status_atom/1`:

```elixir
case LatticeStripe.Account.Capability.status_atom(account.capabilities["card_payments"]) do
  :active -> # ready to accept card payments
  :pending -> # Stripe is reviewing; wait for account.updated webhook
  :inactive -> # blocked; check account.requirements for what's missing
  :unknown -> # forward-compat fallthrough; log and revisit
end
```

The `status_atom/1` helper converts Stripe's status strings to atoms safely —
it uses `String.to_existing_atom/1` against a compile-time declared set and
returns `:unknown` for any value not in that set. It never calls
`String.to_atom/1` on Stripe input.

## Rejecting an account

To permanently reject a connected account, use `Account.reject/4` with an atom
reason:

```elixir
LatticeStripe.Account.reject(client, "acct_123", :fraud)
LatticeStripe.Account.reject(client, "acct_123", :terms_of_service)
LatticeStripe.Account.reject(client, "acct_123", :other)
```

The three valid atoms map to Stripe's `reason` enum. Any other atom raises
`FunctionClauseError` at call time — typos fail loudly rather than silently
sending an invalid payload to Stripe.

> #### Irreversible {: .error}
>
> Rejection is one-way. Once rejected, the connected account cannot be
> re-activated. Use this only when you have confirmed fraudulent or policy-
> violating behavior. Wire `account.application.deauthorized` into your
> webhook handler for any downstream state cleanup.

## Webhook handoff

> **Drive your application state from webhook events, not SDK responses.** An
> SDK response reflects the account state at the moment of the call, but
> Stripe may transition the account a moment later (capability activation,
> requirements update, payouts enablement). Wire `account.updated`,
> `account.application.authorized`, and `account.application.deauthorized`
> into your webhook handler via `LatticeStripe.Webhook`.

Key Connect events to handle:

| Event | When it fires |
| --- | --- |
| `account.updated` | Any change to account state, requirements, or capabilities |
| `account.application.authorized` | User connected your platform to their account |
| `account.application.deauthorized` | User or platform disconnected the account |
| `capability.updated` | A capability's status changed (e.g., `pending` → `active`) |

See the [Webhooks guide](webhooks.html) for signature verification and handler setup.

## Money Movement

Account onboarding is only half of Connect. Once an account is active you
need to move money: attach bank accounts, read balances, send transfers,
schedule payouts, reconcile platform fees. This section covers every Phase
18 resource against the D-07 outline.

> **Webhook handoff** — drive application state from webhook events, not
> from SDK responses. SDK responses reflect a point-in-time snapshot;
> Stripe may transition state moments later. See the
> [Webhooks guide](webhooks.html).

### 1. External accounts

External accounts are the bank accounts and debit cards a connected account
uses to receive payouts. `LatticeStripe.ExternalAccount` is a polymorphic
dispatcher — it returns `%LatticeStripe.BankAccount{}`,
`%LatticeStripe.Card{}`, or `%LatticeStripe.ExternalAccount.Unknown{}`
depending on the object type returned by Stripe.

```elixir
# Attach a tokenized bank account
{:ok, ba} =
  LatticeStripe.ExternalAccount.create(client, "acct_123", %{
    "external_account" => "btok_us",
    "default_for_currency" => true
  })

# Attach a tokenized debit card
{:ok, card} =
  LatticeStripe.ExternalAccount.create(client, "acct_123", %{
    "external_account" => "tok_visa_debit"
  })

# Pattern-match on the returned struct — NEVER on a string type field
case ba do
  %LatticeStripe.BankAccount{last4: last4} -> "Bank ****#{last4}"
  %LatticeStripe.Card{last4: last4} -> "Card ****#{last4}"
  %LatticeStripe.ExternalAccount.Unknown{object: obj} -> "Unknown: #{obj}"
end

# List, retrieve, update, delete
{:ok, resp} = LatticeStripe.ExternalAccount.list(client, "acct_123")

client
|> LatticeStripe.ExternalAccount.stream!("acct_123")
|> Enum.each(&handle_external_account/1)
```

> **Webhook handoff** — react to `account.external_account.created`,
> `account.external_account.updated`, and `account.external_account.deleted`
> rather than polling after each mutation.

### 2. Balance

`LatticeStripe.Balance` is a singleton. The ONLY distinction between
reading the platform balance and reading a connected account's balance is
the per-request `stripe_account:` option, which threads the
`Stripe-Account` header on that single call:

```elixir
# Platform balance
{:ok, platform} = LatticeStripe.Balance.retrieve(client)

# Connected account balance
{:ok, connected} =
  LatticeStripe.Balance.retrieve(client, stripe_account: "acct_123")

# Read available USD funds
[usd] = Enum.filter(platform.available, &(&1.currency == "usd"))
IO.puts("Available USD: #{usd.amount}")

# Source-type breakdown
IO.puts("From cards: #{usd.source_types.card}")
```

> #### Reconciliation loop antipattern {: .warning}
>
> When walking connected accounts in a loop, you MUST pass the
> `stripe_account:` opt on every call:
>
> ```elixir
> # WRONG — returns platform balance N times, silently wrong totals
> Enum.map(connected_accounts, fn acct ->
>   LatticeStripe.Balance.retrieve(client)
> end)
>
> # RIGHT — per-request header override
> Enum.map(connected_accounts, fn acct ->
>   LatticeStripe.Balance.retrieve(client, stripe_account: acct.id)
> end)
> ```
>
> `Balance.retrieve(client)` with no opts always returns whichever balance
> `client.stripe_account` points at — the platform balance if `nil`. A
> missing `stripe_account:` opt inside a connected-account loop is the #1
> reconciliation bug for Connect platforms.

Balance has additional fields for specific flows: `connect_reserved`
(Connect pending funds), `instant_available` (Instant Payouts eligible),
`issuing` (Issuing program balance). All list fields decode to
`%LatticeStripe.Balance.Amount{}` with a `source_types` struct.

### 3. Transfers

Transfers move funds from the platform balance to a connected account's
balance. Use `transfer_group` to bind a transfer to an order or charge for
reporting:

```elixir
{:ok, transfer} =
  LatticeStripe.Transfer.create(client, %{
    "amount" => 1000,
    "currency" => "usd",
    "destination" => "acct_123",
    "transfer_group" => "ORDER_42"
  })

{:ok, transfer} = LatticeStripe.Transfer.retrieve(client, transfer.id)

# Reverse a transfer (full or partial)
{:ok, reversal} =
  LatticeStripe.TransferReversal.create(client, transfer.id, %{
    "amount" => 500
  })

{:ok, resp} = LatticeStripe.Transfer.list(client, %{"limit" => 10})
```

> **Webhook handoff** — react to `transfer.created`, `transfer.updated`,
> `transfer.reversed`, and `transfer.paid` rather than polling the transfer
> state.

### 4. Payouts

Payouts move funds from a Stripe balance to an external account. The
standard lifecycle is: `create` → Stripe schedules → webhook notifies. Use
`method: "instant"` for Instant Payouts (fees apply):

```elixir
{:ok, payout} =
  LatticeStripe.Payout.create(client, %{
    "amount" => 2000,
    "currency" => "usd",
    "method" => "instant"
  })

# Read settlement tracking id (if present)
case payout.trace_id do
  %LatticeStripe.Payout.TraceId{value: tid, status: status} ->
    Logger.info("Payout trace #{tid} / #{status}")

  nil ->
    :not_yet_available
end

# Cancel a pending payout. Use expand: [\"balance_transaction\"] to read the
# associated BalanceTransaction in one round-trip (D-03).
{:ok, cancelled} =
  LatticeStripe.Payout.cancel(client, payout.id, %{},
    expand: ["balance_transaction"]
  )

# Reverse a paid payout (Standard bank accounts only)
{:ok, reversed} =
  LatticeStripe.Payout.reverse(client, payout.id, %{
    "metadata" => %{"reason" => "overpayment"}
  })
```

> **Webhook handoff** — react to `payout.paid`, `payout.failed`, and
> `payout.canceled` rather than polling. The trace id lets you correlate
> with your bank's statement without querying Stripe.

### 5. Destination charges

Destination charges are PaymentIntents that automatically transfer funds to
a connected account and collect a platform fee. **LatticeStripe ships no
`create_destination_charge` wrapper — the PaymentIntent params ARE the API
surface** (D-07). Use the existing `LatticeStripe.PaymentIntent.create/3`
with Connect-specific fields:

```elixir
{:ok, pi} =
  LatticeStripe.PaymentIntent.create(client, %{
    "amount" => 5000,
    "currency" => "usd",
    "payment_method_types" => ["card"],
    "application_fee_amount" => 500,
    "transfer_data" => %{"destination" => "acct_123"},
    "on_behalf_of" => "acct_123",
    "transfer_group" => "ORDER_42"
  })
```

Key fields:

- `application_fee_amount` — platform fee (in smallest currency unit) deducted
  from the destination's share. Matches the field on Stripe's PaymentIntent
  API; LatticeStripe preserves the name verbatim.
- `transfer_data.destination` — the connected account that receives funds.
- `on_behalf_of` — the merchant of record for the charge (affects statement
  descriptor, fees, and settlement currency).
- `transfer_group` — optional grouping id shared with later `Transfer`
  calls for the same order.

> **Webhook handoff** — react to `charge.succeeded` and `application_fee.created`
> rather than reading `pi.charges` or polling the PaymentIntent. The
> `application_fee.created` event is the authoritative record that the
> platform fee was collected.

### 6. Separate charges and transfers

When a single order fans out to multiple connected accounts, or when the
merchant of record is the platform, use the separate-charges-and-transfers
pattern. The three steps are:

1. Create a PaymentIntent with a `transfer_group` (no `transfer_data`).
2. Confirm the PaymentIntent. Funds settle into the platform balance.
3. Create one `Transfer` per destination with the SAME `transfer_group`
   AND `source_transaction: "ch_..."` — the charge id from step 2.

```elixir
# Step 1: platform-direct PaymentIntent
{:ok, pi} =
  LatticeStripe.PaymentIntent.create(client, %{
    "amount" => 5000,
    "currency" => "usd",
    "payment_method" => "pm_card_visa",
    "confirm" => true,
    "transfer_group" => "ORDER_42"
  })

# pi.latest_charge is the ch_... id needed by step 3
charge_id = pi.latest_charge

# Step 3a: transfer to merchant A
{:ok, _t1} =
  LatticeStripe.Transfer.create(client, %{
    "amount" => 2000,
    "currency" => "usd",
    "destination" => "acct_merchant_a",
    "transfer_group" => "ORDER_42",
    "source_transaction" => charge_id
  })

# Step 3b: transfer to merchant B
{:ok, _t2} =
  LatticeStripe.Transfer.create(client, %{
    "amount" => 2500,
    "currency" => "usd",
    "destination" => "acct_merchant_b",
    "transfer_group" => "ORDER_42",
    "source_transaction" => charge_id
  })
```

**`source_transaction` is load-bearing.** Without it, a transfer can run
ahead of settled funds — the platform balance momentarily goes negative,
and Stripe will reject the transfer. With it, Stripe guarantees the
transfer will not process until the source charge settles, even if that
takes days (delayed capture, disputes, ACH). Always pass
`source_transaction` in separate-charges-and-transfers flows.

### 7. Reconciling platform fees

LatticeStripe supports BOTH canonical reconciliation idioms. Pick the one
that matches your data shape:

**Per-object idiom** — walk one charge / PaymentIntent and its expanded
balance transaction. Best for "what did I earn on THIS order":

```elixir
# If you have a charge id directly
{:ok, charge} =
  LatticeStripe.Charge.retrieve(client, "ch_123",
    expand: ["balance_transaction"]
  )

# charge.balance_transaction is now an inline map (expanded)
bt_map = charge.balance_transaction
bt = LatticeStripe.BalanceTransaction.from_map(bt_map)

app_fees =
  bt.fee_details
  |> Enum.filter(&(&1.type == "application_fee"))
  |> Enum.map(& &1.amount)
  |> Enum.sum()

# If you only have a PaymentIntent, go via the charge
{:ok, pi} = LatticeStripe.PaymentIntent.retrieve(client, "pi_123")
{:ok, charge} =
  LatticeStripe.Charge.retrieve(client, pi.latest_charge,
    expand: ["balance_transaction"]
  )
```

**Per-payout batch idiom** — list every balance transaction on a payout.
Best for "reconcile today's payout against our internal ledger":

```elixir
# One payout → all its balance transactions → all their fee details
{:ok, resp} =
  LatticeStripe.BalanceTransaction.list(client, %{
    "payout" => "po_123",
    "limit" => 100
  })

# For large payouts, stream the full page chain lazily
totals =
  client
  |> LatticeStripe.BalanceTransaction.stream!(%{"payout" => "po_123"})
  |> Enum.flat_map(& &1.fee_details)
  |> Enum.filter(&(&1.type == "application_fee"))
  |> Enum.map(& &1.amount)
  |> Enum.sum()

# When you need typed access to bt.source, expand it and cast manually
# per D-05 — the source sum type is not auto-decoded by the SDK.
{:ok, bt} =
  LatticeStripe.BalanceTransaction.retrieve(client, "txn_123",
    expand: ["source"]
  )

typed_source =
  case bt.source do
    %{"object" => "charge"} = m -> LatticeStripe.Charge.from_map(m)
    %{"object" => "refund"} = m -> LatticeStripe.Refund.from_map(m)
    %{"object" => "transfer"} = m -> LatticeStripe.Transfer.from_map(m)
    other -> other
  end
```

> **Webhook handoff** — trigger reconciliation on `payout.paid` rather
> than polling. The `payout.paid` event is fired once per payout and is
> the authoritative signal that funds have hit the external account.

### 8. What's next

The Connect surface is now complete for money movement. See the
`LatticeStripe` ExDoc **Connect** module group for the full reference —
every module mentioned in this guide has typespecs and full function
documentation. For webhook signature verification and event dispatch, see
the [Webhooks guide](webhooks.html).
