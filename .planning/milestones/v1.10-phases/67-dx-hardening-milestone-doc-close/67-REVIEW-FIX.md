---
phase: 67
fixed_at: 2026-08-25T18:26:46Z
review_path: .planning/phases/67-dx-hardening-milestone-doc-close/67-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 67: Code Review Fix Report

**Fixed at:** 2026-08-25T18:26:46Z
**Source review:** `.planning/phases/67-dx-hardening-milestone-doc-close/67-REVIEW.md`
**Iteration:** 1

**Summary:**

- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: A retry of a binary download switches to the JSON request pipeline

**Files modified:** `lib/lattice_stripe/client.ex`, `test/lattice_stripe/client_test.exs`
**Commits:** `81616c5`, `59db960`
**Applied fix:** Retry dispatch now preserves the request kind, so downloads return through the binary pipeline after a transient failure. The regression test exercises a retryable 500 followed by a PDF response.

### CR-02: Invalid-request errors can crash while building the error struct

**Files modified:** `lib/lattice_stripe/error.ex`, `test/lattice_stripe/error_test.exs`
**Commit:** `67b3df3`
**Applied fix:** Parameter suggestions now require a binary message. A nullable Stripe message with a parameter returns a valid `%Error{}` instead of raising.

### CR-03: The documented advanced webhook configuration retains raw bodies globally, including multipart uploads

**Files modified:** `guides/webhooks.md`, `lib/lattice_stripe/webhook/plug.ex`, `test/lattice_stripe/webhook/plug_test.exs`, `test/lattice_stripe/docs_truth_test.exs`
**Commits:** `be9d105`, `4e32362`
**Applied fix:** The published advanced configuration is a Phoenix route-scoped JSON-only pipeline for `/webhooks/stripe`; it excludes multipart and no longer configures endpoint-wide raw-body caching. Topology and prose locks cover the contract.

### WR-01: `Retry-After` parser accepts signed values despite the documented strict decimal contract

**Files modified:** `lib/lattice_stripe/error.ex`, `test/lattice_stripe/error_test.exs`
**Commit:** `03dc3e3`
**Applied fix:** Parsed values must now match digits only after OWS trimming. `+5` and `-0` are regression-tested as rejected values.

### WR-02: Mount-before-parsers verification drops chunked raw request bodies

**Files modified:** `lib/lattice_stripe/webhook/plug.ex`, `test/lattice_stripe/webhook/plug_test.exs`
**Commit:** `95f03b7`
**Applied fix:** Direct reads now collect all `{:more, chunk, conn}` chunks in byte order before verification. An end-to-end chunked adapter test proves signature validation succeeds.

### WR-03: PaymentIntent confirmation/SCA example is internally contradictory and unsafe for common 3DS responses

**Files modified:** `guides/payments.md`, `test/lattice_stripe/docs_truth_test.exs`
**Commits:** `99bdd37`, `45cc39e`
**Applied fix:** The guide distinguishes server confirmation from Stripe.js next-action handling, branches safely on `use_stripe_sdk` and `redirect_to_url`, and keeps the canonical Charge policy surfaces consistent.

---

_Fixed: 2026-08-25T18:26:46Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
