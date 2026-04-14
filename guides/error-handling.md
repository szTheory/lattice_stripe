# Error Handling

Every function in LatticeStripe returns either `{:ok, result}` or `{:error, %LatticeStripe.Error{}}`.
There are no raw strings or bare atoms in the error path — every failure is a fully structured
`%LatticeStripe.Error{}` struct that you can pattern match on with confidence.

For a complete reference of Stripe error codes and types, see
[Stripe's error documentation](https://docs.stripe.com/error-codes).

## The Error Struct

`LatticeStripe.Error` is an Elixir exception struct (it also implements `defexception`, so you can
raise it or use it with `rescue/1`). All fields are available for pattern matching:

```elixir
%LatticeStripe.Error{
  # Always present — use this to drive your case statement
  type: :card_error,

  # Stripe error code string, e.g. "card_declined", "missing_param", "resource_missing"
  code: "card_declined",

  # Human-readable message from Stripe (safe to log, not always safe to show users)
  message: "Your card was declined.",

  # HTTP status code — nil only for :connection_error (no HTTP response received)
  status: 402,

  # Stripe's Request-Id header value — include this when contacting Stripe support
  request_id: "req_abc123xyz",

  # Parameter name that caused the error (for :invalid_request_error)
  param: nil,

  # Card decline reason (for :card_error only)
  decline_code: "insufficient_funds",

  # Stripe charge ID associated with a card error
  charge: "ch_abc123",

  # URL to Stripe documentation for this specific error
  doc_url: "https://docs.stripe.com/error-codes/card-declined",

  # Full decoded error body — escape hatch for fields not yet in the struct
  raw_body: %{"error" => %{...}}
}
```

### Error Types

The `:type` field is always one of these atoms:

| Type | When | User-facing? |
|------|------|-------------|
| `:card_error` | Card was declined or has an issue (expired, wrong CVC, insufficient funds) | Yes — show a friendly message |
| `:invalid_request_error` | Invalid or missing parameters in the request | No — this is a developer error |
| `:authentication_error` | API key is invalid, revoked, or missing | No — ops/infrastructure issue |
| `:rate_limit_error` | Too many requests in too short a time | No — back off and retry |
| `:api_error` | Stripe server error or unexpected response | No — already retried automatically |
| `:idempotency_error` | Idempotency key reused with different parameters | No — developer/race condition issue |
| `:connection_error` | Network failure — no HTTP response received | No — retry with backoff |

## Pattern Matching on Error Types

Use a `case` statement to handle each error type appropriately. The pattern is: handle user-facing
errors gracefully, log infrastructure errors, and crash on developer errors (so they get fixed during
development).

```elixir
case LatticeStripe.PaymentIntent.create(client, params) do
  {:ok, intent} ->
    # Success — proceed with the payment intent
    {:ok, intent}

  {:error, %LatticeStripe.Error{type: :card_error, decline_code: decline_code, code: code}} ->
    # Card was declined — show a user-friendly message based on decline_code
    # Common decline codes: "insufficient_funds", "card_declined", "expired_card",
    # "incorrect_cvc", "do_not_honor", "lost_card", "stolen_card"
    message = friendly_decline_message(decline_code || code)
    {:error, {:card_declined, message}}

  {:error, %LatticeStripe.Error{type: :authentication_error}} ->
    # API key is wrong, revoked, or missing — this is an ops issue, not a user issue
    Logger.error("Stripe authentication failed — check your API key configuration")
    {:error, :service_unavailable}

  {:error, %LatticeStripe.Error{type: :rate_limit_error, request_id: req_id}} ->
    # Too many requests — LatticeStripe already retried with backoff; now fully exhausted
    Logger.warning("Stripe rate limit exhausted", request_id: req_id)
    {:error, :rate_limited}

  {:error, %LatticeStripe.Error{type: :invalid_request_error, param: param, message: message}} ->
    # Bad request parameters — fix the code that's sending this request
    Logger.error("Invalid Stripe request", param: param, message: message)
    {:error, {:invalid_params, param}}

  {:error, %LatticeStripe.Error{type: :idempotency_error, request_id: req_id}} ->
    # Idempotency key reused with different parameters — race condition or bug
    Logger.error("Idempotency key conflict", request_id: req_id)
    {:error, :idempotency_conflict}

  {:error, %LatticeStripe.Error{type: :api_error, message: message, request_id: req_id} = err} ->
    # Stripe server error — LatticeStripe already retried automatically
    # Log the request_id so you can share it with Stripe support
    Logger.error("Stripe API error: #{message}", request_id: req_id, status: err.status)
    {:error, :service_unavailable}

  {:error, %LatticeStripe.Error{type: :connection_error}} ->
    # Network failure — LatticeStripe already retried; DNS/TLS/timeout at OS level
    Logger.warning("Could not reach Stripe — network error")
    {:error, :service_unavailable}
end
```

### Matching Decline Codes

For `:card_error`, the `:decline_code` field gives you more specific information about why the card
was declined. Use it to show appropriate messages or take action:

```elixir
def friendly_decline_message("insufficient_funds"),
  do: "Your card has insufficient funds. Please use a different card."

def friendly_decline_message("card_declined"),
  do: "Your card was declined. Please try a different card or contact your bank."

def friendly_decline_message("expired_card"),
  do: "Your card has expired. Please update your payment method."

def friendly_decline_message("incorrect_cvc"),
  do: "Your card's security code is incorrect. Please check and try again."

def friendly_decline_message("lost_card"),
  do: "Your card was declined. Please use a different payment method."

def friendly_decline_message("stolen_card"),
  do: "Your card was declined. Please use a different payment method."

def friendly_decline_message(_other),
  do: "Your card was declined. Please try a different card or contact your bank."
```

### Invoice payment failures

Billing failures don't come back from the SDK call that creates the
invoice — Stripe attempts collection asynchronously and reports the
outcome via webhooks. Handle `invoice.payment_failed` in your webhook
handler to drive dunning workflows (notify the customer, pause the
subscription, retry later). The corresponding `{:error, %LatticeStripe.Error{}}`
from a synchronous call indicates the request itself failed, not the
collection attempt. See [Webhooks](webhooks.md) for event wiring.

### Connect account errors

Connect-specific failures surface as `:invalid_request_error` with the
`code` field set to values such as `account_invalid`,
`account_country_invalid_address`, or `account_number_invalid`.
Match on the `code` field rather than the `:type` atom to distinguish
"the connected account id is wrong" from "the destination bank account
is malformed". Drive downstream account state off
`account.updated` webhooks, not off these synchronous error responses.

## Bang Variants

All resource functions have a `!` variant that raises `LatticeStripe.Error` instead of returning
`{:error, error}`. Use bang functions in scripts, data migrations, or contexts where you want an
immediate crash on failure:

```elixir
# In a script — crash if anything goes wrong
customer = LatticeStripe.Customer.create!(client, %{
  "email" => "user@example.com",
  "name" => "Alice"
})

# In a test — let ExUnit show the error
intent = LatticeStripe.PaymentIntent.create!(client, %{
  "amount" => 2000,
  "currency" => "usd"
})
```

In production application code, prefer the non-bang variants and handle errors explicitly.

## Automatic Retries

LatticeStripe automatically retries failed requests following Stripe's official SDK conventions.
You don't need to implement your own retry loop for transient failures.

**Default retry behavior:**
- **2 retries by default** (3 total attempts)
- **Exponential backoff with jitter:** `min(500ms * 2^(attempt-1), 5000ms)`, jittered to 50-100% of
  that value
- **Stripe-Should-Retry header respected:** When Stripe explicitly tells the SDK to retry (or not),
  that instruction takes precedence over all other logic
- **Retry-After header respected:** On 429 responses, the `Retry-After` header value is used (capped
  at 5 seconds)
- **Idempotency keys preserved across retries:** The same key is reused on all attempts so retrying
  a POST is safe

**What gets retried automatically:**
- Connection errors (network failure, DNS, timeout) — `:connection_error`
- Rate limit errors (429) — `:rate_limit_error`
- Stripe server errors (500, 502, 503, 504) — `:api_error`

**What is never retried:**
- Card errors (402) — `:card_error` — the card was declined, retrying won't help
- Invalid request errors (400) — `:invalid_request_error` — fix the request
- Authentication errors (401) — `:authentication_error` — fix the API key
- Idempotency conflicts (409) — `:idempotency_error` — retrying would cause the same conflict again

## Configuring Retries

Override the number of retries when building a client:

```elixir
# High-reliability client: 4 retries (5 total attempts)
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,
  max_retries: 4
)

# No retries — useful if your caller has its own retry/circuit-breaker logic
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,
  max_retries: 0
)
```

Override per-request:

```elixir
# Retry up to 5 times just for this critical payment
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, params, max_retries: 5)
```

For custom retry behavior (circuit breakers, custom backoff), see
[Extending LatticeStripe](extending-lattice-stripe.html).

## Using request_id for Support

Every successful or failed Stripe API response includes a `request_id` — Stripe's internal
identifier for the exact server-side execution of your request. Always log it when something
goes wrong.

```elixir
case LatticeStripe.PaymentIntent.create(client, params) do
  {:ok, %LatticeStripe.PaymentIntent{} = intent} ->
    # The response includes request_id too (via the raw response headers)
    Logger.info("Payment intent created", payment_intent_id: intent.id)
    {:ok, intent}

  {:error, %LatticeStripe.Error{} = err} ->
    # ALWAYS log the request_id — it's what Stripe support needs to investigate
    Logger.error("Payment intent creation failed",
      type: err.type,
      code: err.code,
      message: err.message,
      request_id: err.request_id,
      status: err.status
    )
    {:error, err}
end
```

When filing a Stripe support ticket, include the `request_id` value (e.g., `req_abc123xyz`).
Stripe support can look up the exact server-side context using this ID.

## Exception Format

`LatticeStripe.Error` implements `Exception`, so `Exception.message/1` (and `to_string/1`) produce
a readable summary:

```elixir
err = %LatticeStripe.Error{
  type: :card_error,
  status: 402,
  code: "card_declined",
  message: "Your card was declined.",
  request_id: "req_abc123"
}

Exception.message(err)
# => "(card_error) 402 card_declined Your card was declined. (request: req_abc123)"

# Can also be raised:
raise err
# ** (LatticeStripe.Error) (card_error) 402 card_declined Your card was declined. (request: req_abc123)
```

## Common Pitfalls

**Don't catch all errors in one clause**

This silently swallows important signals:

```elixir
# Bad: loses error type and context
{:error, _err} -> {:error, :stripe_failed}

# Good: handle each type appropriately
{:error, %LatticeStripe.Error{type: :card_error}} -> {:error, :card_declined}
{:error, %LatticeStripe.Error{type: :api_error}} -> {:error, :service_unavailable}
```

**Distinguish user-facing errors from infrastructure errors**

`:card_error` should result in a user-visible message. `:api_error`, `:authentication_error`, and
`:connection_error` are infrastructure problems — log them and show a generic "something went wrong"
message to users.

**Always log request_id**

Even when an error is expected (like `:card_error`), log the `request_id`. It's invaluable for
debugging edge cases and filing Stripe support tickets.

**Idempotency conflicts signal a bug or race condition**

An `:idempotency_error` means you sent two requests with the same idempotency key but different
parameters. This is almost always a developer error or a race condition in your code — investigate
before retrying.

**Connection errors may mean Stripe was reached**

A `:connection_error` means the TCP connection failed or timed out. The request may or may not have
reached Stripe. If you sent a POST without an idempotency key, you can't safely retry — you might
create duplicate records. LatticeStripe auto-generates idempotency keys for POST requests to make
safe retries possible.

## See also

- [Webhooks](webhooks.md) — asynchronous failure handling for billing and Connect
- [Invoices](invoices.md) — dunning patterns for `invoice.payment_failed`
- [Connect](connect.md) — Connect-specific error codes and account-state recovery
- [metering.md](metering.md#reconciliation-via-webhooks) — async billing error codes
  (`meter_event_customer_not_found`, `archived_meter`, etc.) that surface via webhook
