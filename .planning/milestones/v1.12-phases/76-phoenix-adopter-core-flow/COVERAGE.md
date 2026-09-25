# API Coverage — Stripe contracts selected for the Phoenix adopter

> Full coverage by default. This matrix records the external contract boundary exercised by the synthetic, test-only adopter; it does not claim live Stripe delivery.

| capability | decision | reason |
|---|---|---|
| Subscription Checkout request and typed Session decoding in Phoenix | INTEGRATE | |
| Signed raw-body webhook verification and typed Event dispatch in Phoenix | INTEGRATE | |
| Live Stripe API calls and production credentials | OPT-OUT | The phase uses a deterministic Mox transport so the SDK and host boundary are reproducible without network access or secrets. |
| Live Stripe webhook delivery, durable processing, and duplicate-event handling | OPT-OUT | These production behaviors require an external Stripe environment and adopter-owned persistence, both outside this test-only core flow. |
| Other Stripe resource families and adopter edge profiles | OPT-OUT | Phase 76 proves the common Checkout/webhook spine; Phase 77 owns selected B2B, usage, and Connect edge profiles. |
