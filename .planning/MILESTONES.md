# Milestones

## v1.0 Foundation & Payments (Shipped: 2026-04-04 as `lattice_stripe` v0.2.0)

**Phases completed:** 11 phases, 31 plans, 49 tasks
**Timeline:** 2026-03-31 → 2026-04-04 (195 commits)
**Hex release:** `lattice_stripe` v0.2.0 on 2026-04-04

### Key Accomplishments

1. **Production-ready HTTP foundation** — pluggable `Transport` behaviour with Finch default adapter, `Client` struct with `new!/1` + `request/2`, NimbleOptions config validation, recursive Stripe bracket-notation form encoder, `Jason`-backed Json behaviour with 4 callbacks for graceful non-JSON handling.

2. **Full error + retry model** — 10-field `Error` struct with pattern-matchable `:type` atoms (card/auth/rate_limit/idempotency_error/api_error), `RetryStrategy` behaviour honoring `Stripe-Should-Retry` header, exponential backoff with jitter, `Retry-After` capped at 5s, 409 idempotency conflicts non-retriable, auto-generated `idk_ltc_<uuid4>` idempotency keys reused across retries.

3. **Pagination & Response layer** — `Response` struct implementing Access/Inspect protocols, `List` struct with `from_json/Inspect`, lazy `Stream.resource/3` auto-pagination (`stream!/2` from scratch, `stream/2` from existing list) supporting cursor, backward, and search pagination modes, API version pinned to `2026-03-25.dahlia`, enhanced User-Agent with OTP version + `X-Stripe-Client-User-Agent` header.

4. **Complete Payments resource coverage** — `Customer`, `PaymentIntent` (with confirm/capture/cancel action verbs and `Inspect` hiding `client_secret`), `SetupIntent` (CRUD + confirm/cancel/verify_microdeposits), `PaymentMethod` (CRUD + attach/detach + conditional card Inspect), `Refund`, `Checkout.Session` (create in payment/subscription/setup modes + `LineItem` + list/stream/expire/search). All resources reuse the extracted `LatticeStripe.Resource` helper module for consistent unwrap patterns and pre-network param validation. 350+ tests passing.

5. **Webhooks end-to-end** — `Event` struct, HMAC-SHA256 signature verification with multi-secret rotation and configurable tolerance window, `Webhook.Plug` with path matching and MFA secrets, `CacheBodyReader` for raw body preservation, Phoenix integration tests, `webhook_verify_span/2` telemetry events.

6. **Developer experience** — 5 complete guides (install to first PaymentIntent, Client options, payment lifecycle, Checkout 3 modes, webhook setup), full ExDoc coverage with 13 typed public structs, README <60 second quickstart, cheatsheet, `attach_default_logger/1` producing structured `"POST /v1/customers => 200 in 145ms (1 attempt, req_xxx)"` log lines.

7. **CI/CD automation** — GitHub Actions with 3 parallel jobs (lint, test matrix across Elixir 1.15/1.17/1.19 x OTP 26/27/28, integration against stripe-mock Docker), complete Hex package metadata, MIT license, Release Please manifest workflow with Hex.pm auto-publish, Dependabot for mix + github-actions with patch-only auto-merge, MixAudit security scanning, CONTRIBUTING/SECURITY/issue templates.

### Known Gaps (deferred)

Three v1 Expand requirements shipped unimplemented. `expand` is supported at the request-option level (raw string paths pass through to Stripe), but typed deserialization and atom-based status fields were deferred:

- `EXPD-02` — Expanded objects are deserialized into typed structs, unexpanded remain as string IDs
- `EXPD-03` — Nested expansion is supported (e.g., `expand: ["data.customer"]`)
- `EXPD-05` — Pattern-matchable domain types use atoms for status fields (e.g., `:succeeded`, `:requires_action`)

These can be promoted from deferred into a future milestone when typed-struct deserialization becomes a blocker. Today, callers get raw maps for unexpanded fields and string statuses — workable but not idiomatic Elixir.

---
