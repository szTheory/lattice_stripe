---
phase: 31-livebook-notebook
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - notebooks/stripe_explorer.livemd
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 31: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

The `stripe_explorer.livemd` notebook covers client setup, payments, billing, Connect, webhooks, and v1.2 features (Batch, expand deserialization, MeterEventStream, SubscriptionSchedule builder). The structure is clear and the code demonstrates realistic usage patterns.

One critical bug was found: the Webhooks section calls a function that does not exist on the module it references — `LatticeStripe.Testing.generate_test_signature/2` — causing an `UndefinedFunctionError` at runtime when a user runs that cell. Two warnings cover a variable cross-cell dependency that silently produces wrong behavior, and a misleading expires_at display. Two info items cover amount param style inconsistency with SDK docs and a minor comment accuracy gap.

## Critical Issues

### CR-01: Wrong module for `generate_test_signature` — cell raises `UndefinedFunctionError`

**File:** `notebooks/stripe_explorer.livemd:372`
**Issue:** The Webhooks section calls `LatticeStripe.Testing.generate_test_signature(raw_body, secret)`, but `generate_test_signature/3` is defined on `LatticeStripe.Webhook`, not `LatticeStripe.Testing`. `LatticeStripe.Testing` does not define, delegate, or re-export this function. Running this cell raises `UndefinedFunctionError: function LatticeStripe.Testing.generate_test_signature/2 is undefined`. This completely breaks the Webhooks demo section.

**Fix:**
```elixir
# line 372 — change this:
sig_header = LatticeStripe.Testing.generate_test_signature(raw_body, secret)

# to this:
sig_header = LatticeStripe.Webhook.generate_test_signature(raw_body, secret)
```

## Warnings

### WR-01: Cross-section variable dependency on `confirmed` is silently broken when cells run out of order

**File:** `notebooks/stripe_explorer.livemd:139-143`
**Issue:** The Refund section at line 139 references `confirmed.id`, which is bound in the PaymentIntent section (line 103) when the "confirm" cell runs. If a user runs the Refund cell before running the confirm cell (or if Livebook loses cell state on reconnect), the match on `{:ok, refund_resp}` pattern will raise `UndefinedFunctionError` or `CompileError` because `confirmed` is unbound. Unlike `customer`, which has a prerequisite note in the Billing section header, this dependency is undocumented and the bind is spread across two non-adjacent cells.

**Fix:** Add a comment before the Refund cell explaining the dependency, and guard against the unbound case:
```elixir
# Requires `confirmed` bound in the PaymentIntent → "confirm" cell above.
# If you skipped that cell, substitute a real PaymentIntent ID here:
# confirmed_id = "pi_..."
# {:ok, refund_resp} = LatticeStripe.Refund.create(client, %{
#   "payment_intent" => confirmed_id
# })

{:ok, refund_resp} = LatticeStripe.Refund.create(client, %{
  "payment_intent" => confirmed.id
})
```

Alternatively, bind `confirmed_id = confirmed.id` immediately after the confirm cell and use `confirmed_id` in the Refund cell, making the dependency explicit and scannable.

### WR-02: `session.expires_at` displayed as a raw Unix timestamp — confusing for notebook users

**File:** `notebooks/stripe_explorer.livemd:269`
**Issue:** `IO.puts("Session expires at: #{session.expires_at}")` prints an integer Unix timestamp (e.g., `1713225600`). For a developer exploration notebook, this is unhelpful — the reader cannot easily tell whether the session is still valid. The `expires_at` field is documented as a Unix integer, but the notebook is an interactive teaching tool where UX matters.

**Fix:**
```elixir
expires_readable = session.expires_at |> DateTime.from_unix!() |> to_string()
IO.puts("Session expires at: #{expires_readable}")
```

Or using plain Erlang if `DateTime` is unfamiliar in a Livebook context:
```elixir
IO.puts("Session expires at Unix: #{session.expires_at} (~15 min TTL from creation)")
```

## Info

### IN-01: `amount` and `unit_amount` params use string values where SDK docs use integers

**File:** `notebooks/stripe_explorer.livemd:78,109,163`
**Issue:** Several cells pass `amount` and `unit_amount` as string values (e.g., `"amount" => "2000"`) while the SDK module docs and `@moduledoc` examples consistently show integer values (e.g., `"amount" => 2000`). Functionally this is harmless — `FormEncoder` calls `to_string/1` on all scalar values before form-encoding, so both representations produce identical wire bytes. However, copying the notebook's string style into production code that uses the real Stripe API REST layer (bypassing LatticeStripe) would cause 400 errors, and the inconsistency with the SDK docs may confuse readers about what Stripe actually expects.

**Fix:** Use integer literals to match SDK documentation and Stripe API semantics:
```elixir
# line 78
{:ok, pi_resp} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 2000,   # integer, not "2000"
  "currency" => "usd",
  "customer" => customer.id
})

# line 163
{:ok, price_resp} = LatticeStripe.Price.create(client, %{
  "product" => product.id,
  "currency" => "usd",
  "unit_amount" => 2000,   # integer, not "2000"
  "recurring" => %{"interval" => "month"}
})
```

### IN-02: Batch section comment says "error isolation guaranteed" but `Batch.run` uses `:infinity` timeout

**File:** `notebooks/stripe_explorer.livemd:432`
**Issue:** The comment at line 432 states "error isolation guaranteed" which is accurate for exceptions — each task is wrapped in a `try/rescue`. However, `Batch.run/3` passes `timeout: :infinity` to `Task.async_stream`, meaning a hung Stripe connection (e.g., stripe-mock stops responding) will block the entire `Batch.run/3` call indefinitely. The comment may give users a false sense of isolation from network hangs, not just crashes. This is a documentation accuracy issue, not a bug in the notebook itself.

**Fix:** Add a clarifying note to the comment:
```elixir
# Each result is independently {:ok, _} or {:error, _} — crash isolation guaranteed.
# Note: a hung task will still block the call; set :timeout opt to bound wall time.
for {label, result} <- Enum.zip(["Customer", "Subscriptions", "Invoices"], results) do
```

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
