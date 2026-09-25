# API Coverage — Stripe contracts selected for the Phoenix adopter

> Full coverage by default. This matrix records the selected contract surface of the single test-only adopter app. It is not a claim that the app implements all Stripe workflows.

| capability | decision | reason |
|---|---|---|
| Versioned Invoice retrieval and typed off-Stripe paid amount | INTEGRATE | |
| Usage summary cursor pagination and lazy stream | INTEGRATE | |
| Meter event body identifier and HTTP idempotency key | INTEGRATE | |
| Connect Balance read with per-request account context | INTEGRATE | |
| Structured SDK error from a synthetic Stripe response | INTEGRATE | |
| Raw-body webhook signature verification and rejection before host dispatch | INTEGRATE | |
| Checkout and subscription host route | OPT-OUT | Already covered by Phase 76 core flow; Phase 77 reruns that test in the full adopter suite. |
| Invoice creation, finalization, collection, and durable reconciliation | OPT-OUT | This phase selects a versioned typed reconciliation read and leaves billing lifecycle policy to the adopter application. |
| Usage aggregation policy, durable meter event queue, and settlement | OPT-OUT | The selected SDK contracts are request encoding, idempotency, and bounded synthetic summary traversal; application orchestration remains outside the test harness. |
| Connect account creation, onboarding, payouts, and transfers | OPT-OUT | The selected tenant-context contract is account-scoped Balance retrieval; platform workflows require a separate adopter job. |
| Other Stripe resource families | OPT-OUT | This phase proves the three named edge profiles; additional API breadth requires adopter evidence and separate scope. |
| Live Stripe delivery and production data | OPT-OUT | Deterministic Mox fixtures and visibly synthetic values are the authorized host proof boundary. |
