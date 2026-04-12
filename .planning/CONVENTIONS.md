# LatticeStripe Conventions

Project-wide conventions that outlive any single phase. New code and new
phases MUST align with the rules below — or propose an amendment to this
document as part of the phase planning step.

## Module Namespace

Core billing and payments resources stay FLAT under `LatticeStripe.*`:

- `LatticeStripe.Customer`
- `LatticeStripe.Product`
- `LatticeStripe.Price`
- `LatticeStripe.Coupon`
- `LatticeStripe.PromotionCode`
- `LatticeStripe.Discount`
- `LatticeStripe.PaymentIntent`
- `LatticeStripe.PaymentMethod`
- `LatticeStripe.SetupIntent`
- `LatticeStripe.Refund`
- `LatticeStripe.Subscription` (future)
- `LatticeStripe.Invoice` (future)

Stripe sub-product families NEST under a named namespace. The existing
precedent is `LatticeStripe.Checkout.*` (shipped in v1 —
`LatticeStripe.Checkout.Session`, `LatticeStripe.Checkout.LineItem`).
Phase 13 extends the precedent with `LatticeStripe.TestHelpers.*` and
`LatticeStripe.Testing.*`. Future sub-product families follow the same
rule:

- `LatticeStripe.Checkout.Session`, `LatticeStripe.Checkout.LineItem` (existing, v1)
- `LatticeStripe.TestHelpers.TestClock` (Phase 13)
- `LatticeStripe.Testing.TestClock` (Phase 13)
- `LatticeStripe.Connect.Account`, `.AccountLink`, `.Transfer` (Phase 17 — NOT `LatticeStripe.ConnectAccount`)
- `LatticeStripe.Issuing.*` (future)
- `LatticeStripe.Terminal.*` (future)
- `LatticeStripe.BillingPortal.*` (future)
- `LatticeStripe.Radar.*` (future)
- `LatticeStripe.Treasury.*` (future)
- `LatticeStripe.Identity.*` (future)

**Rule of thumb.** If the Stripe REST API path is `/v1/<resource>`
(top-level), the Elixir module is flat (`LatticeStripe.<Resource>`). If
it's `/v1/<family>/<resource>` (namespaced), the module nests as
`LatticeStripe.<Family>.<Resource>`.

## Testing Namespaces

Two parallel, intentional, distinct public namespaces:

- `LatticeStripe.TestHelpers.*` — SDK resource wrappers over Stripe's
  `/v1/test_helpers/*` API. Ships in `lib/`. Public. Example:
  `LatticeStripe.TestHelpers.TestClock` wraps `/v1/test_helpers/test_clocks`.
- `LatticeStripe.Testing.*` — user-facing ExUnit ergonomics. Ships in `lib/`.
  Public. Example: `LatticeStripe.Testing.TestClock` is the `use`-macro
  helper library users opt into from their own test `CaseTemplate`.

Internal test-only helpers live under `LatticeStripe.TestSupport` in
`test/support/`, marked `@moduledoc false`, never shipped to Hex.

## Error Struct

`LatticeStripe.Error` is the canonical error shape for every LatticeStripe
operation. It implements the `Exception` behaviour, so the same value
works for `{:error, %Error{}}` tuple returns and `raise/1` in bang
variants. Locally-constructed errors (e.g., timeouts from polling
helpers) use `:raw_body` as a free-form map for structured context —
there is no separate `:details` field.
