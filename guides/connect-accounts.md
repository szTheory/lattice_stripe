# Connect Accounts

> Deep-dive on the Connect account lifecycle: creation, onboarding, capabilities, rejection, and acting on behalf. For the conceptual overview, see the [Connect](connect.md) guide. For money movement, see [Connect Money Movement](connect-money-movement.md).

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


## See also

- [Connect](connect.md) — conceptual overview of Standard/Express/Custom
- [Connect Money Movement](connect-money-movement.md) — Transfers, Payouts, Balance
- [Webhooks](webhooks.md) — handling `account.updated` and capability events
