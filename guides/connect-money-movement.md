# Connect Money Movement

> Deep-dive on Transfers, Payouts, Balance, and platform-fee reconciliation. For account lifecycle see [Connect Accounts](connect-accounts.md). For the conceptual overview see [Connect](connect.md).

Account onboarding is only half of Connect. Once an account is active you
need to move money: attach bank accounts, read balances, send transfers,
schedule payouts, reconcile platform fees. This section covers every Phase
18 resource against the D-07 outline.

> **Webhook handoff** — drive application state from webhook events, not
> from SDK responses. SDK responses reflect a point-in-time snapshot;
> Stripe may transition state moments later. See the
> [Webhooks guide](webhooks.html).

## External accounts

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

## Balance

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

## Transfers

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

## Payouts

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

## Destination charges

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

## Separate charges and transfers

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

## Reconciling platform fees

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

## What's next

The Connect surface is now complete for money movement. See the
`LatticeStripe` ExDoc **Connect** module group for the full reference —
every module mentioned in this guide has typespecs and full function
documentation. For webhook signature verification and event dispatch, see
the [Webhooks guide](webhooks.html).

## See also

- [Connect](connect.md) — conceptual overview of Standard/Express/Custom
- [Connect Accounts](connect-accounts.md) — account lifecycle, onboarding, capabilities
- [Error Handling](error-handling.md) — Connect-specific error patterns and retries
