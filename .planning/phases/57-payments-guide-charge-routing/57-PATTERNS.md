# Phase 57 — Pattern Map

**Mapped:** 2026-05-27

## Files to Modify

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `guides/payments.md` | Canonical payments API guide | `guides/tax.md` routing tables + `charge.ex` moduledoc | Distill examples; PI-first framing; two-layer status model |
| `guides/production-checklist.md` | Operator launch spine | Phase 53 operator guide bullets | Verb bullets + cross-link, no duplicate code fences |
| `guides/event-debugging.md` | Post-incident webhook spine | Existing `charge.*` anti-pattern for search | Bullet + anti-pattern shape |
| `test/lattice_stripe/docs_truth_test.exs` | docs regression SSOT | `describe "guides/getting-started.md"` (Phase 56) | Positive + refute grep locks per guide |

## Analog: Phase 56 getting-started describe

```elixir
describe "guides/getting-started.md" do
  test "release-status prose matches current Hex surface" do
    getting_started = File.read!("guides/getting-started.md")
    assert getting_started =~ current_release_line()
    for claim <- @stale_release_status_claims do
      refute getting_started =~ claim
    end
  end
end
```

**Apply to payments:** `@stale_payments_api_patterns` + two-test describe block.

## Analog: Charge moduledoc (distill source for ROUTE-01)

```elixir
# Retrieve with expand
{:ok, charge} =
  LatticeStripe.Charge.retrieve(client, "ch_3OoLqrJ...",
    expand: ["balance_transaction"]
  )

# Search (query string, not map)
{:ok, resp} = LatticeStripe.Charge.search(client, "status:'succeeded' AND currency:'usd'")

# Update metadata
{:ok, charge} =
  LatticeStripe.Charge.update(client, "ch_3OoLqrJ...", %{
    "metadata" => %{"order_id" => "ord_456"},
    "description" => "Order #456"
  })

# Legacy capture
{:ok, charge} = LatticeStripe.Charge.capture(client, "ch_3OoLqrJ...")
```

**Do not paste** Connect fee walkthrough — link to `connect-money-movement.md`.

## Analog: PaymentIntent.search/3 signature

```elixir
def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
```

Guide must show: `PaymentIntent.search(client, "metadata['order_id']:'ord_456'")`

## Analog: Operator guide spine (production-checklist L163–176)

Current pattern — PI-first paragraph + verb bullets without code fences:

```markdown
Charge is the **result record** of a payment attempt...
- List or filter settled charges: `LatticeStripe.Charge.list/3`
- Search by Stripe query syntax: `LatticeStripe.Charge.search/3` — eventually consistent
```

**Extend with:** retrieve/update/capture bullets + cross-link to `payments.md#charge-reconciliation`.

## Target: confirm/3 fix (GUIDE-01)

```elixir
case confirmed.status do
  :succeeded -> IO.puts("Payment succeeded!")
  :requires_action -> IO.puts("3D Secure required — redirect to: ...")
  other -> IO.puts("Unexpected status: #{other}")
end
```

With bridge note before wire-string status machine bullets.

## Target: Charge section placement

Insert between Search note (L218–220) and `## Refunding a Payment` (L222):

```
## Listing and Searching
  ... search eventual-consistency note ...

## Charge reconciliation          ← NEW (anchor: #charge-reconciliation)

## Refunding a Payment
```

## PATTERN MAPPING COMPLETE
