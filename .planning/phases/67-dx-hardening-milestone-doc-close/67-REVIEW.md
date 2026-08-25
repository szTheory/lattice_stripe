---
phase: 67-dx-hardening-milestone-doc-close
reviewed: 2026-08-25T18:17:47Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - lib/lattice_stripe/error.ex
  - lib/lattice_stripe/client.ex
  - lib/lattice_stripe/webhook/cache_body_reader.ex
  - lib/lattice_stripe/webhook/plug.ex
  - lib/lattice_stripe/charge.ex
  - test/lattice_stripe/error_test.exs
  - test/lattice_stripe/client_test.exs
  - test/lattice_stripe/webhook/plug_test.exs
  - test/lattice_stripe/docs_truth_test.exs
  - guides/error-handling.md
  - guides/webhooks.md
  - guides/api_stability.md
  - guides/payments.md
  - priv/api/current.txt
findings:
  critical: 3
  warning: 3
  info: 1
  total: 7
status: issues_found
---

# Phase 67: Code Review Report

**Reviewed:** 2026-08-25T18:17:47Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

The scoped tests pass (236 tests), but the reviewed implementation has three ship-blocking correctness/privacy defects: a binary download retry changes into the JSON request path, a valid nullable error shape crashes the error handler, and the documented advanced webhook setup globally retains raw multipart/request bodies despite stating the opposite. Retry parsing, direct raw-body reads, and SCA documentation also need correction.

## Critical Issues

### CR-01 (BLOCKER): A retry of a binary download switches to the JSON request pipeline

**File:** `lib/lattice_stripe/client.ex:622`

**Issue:** `do_download_with_retries/7` delegates failures to `maybe_retry/5`, but its `{:retry, delay_ms}` branch always recurses into `do_request_with_retries/7` (line 548), not `do_download_with_retries/7`. A transient failed `download/3` followed by a successful PDF/binary response is then JSON-decoded and returned as a non-JSON `:api_error`, instead of the documented `%Response{data: binary}`. The download tests only cover success and non-retried errors, so they miss the public retry path.

**Fix:** Parameterize the retry continuation (or implement a download-specific `maybe_retry`) so `do_download_with_retries/7` recursively calls itself after a retry. Add a test with a retryable first failure and binary 200 second response.

### CR-02 (BLOCKER): Invalid-request errors can crash while building the error struct

**File:** `lib/lattice_stripe/error.ex:224-229`

**Issue:** `maybe_enrich_message/3` accepts a non-empty `param` but does not require `message` to be a binary. Its `message <> ...` therefore raises when Stripe sends (or a transport supplies) `%{"error" => %{"type" => "invalid_request_error", "message" => nil, "param" => "payment_method_type"}}`. This is especially inconsistent with the public type declaring `message: String.t() | nil`; direct execution reproduces `ArgumentError` at line 228 instead of returning `%Error{}`.

**Fix:** Only append a suggestion when `is_binary(message)`, or provide a stable fallback message before concatenating. Add the nullable-message-plus-param case to `error_test.exs`.

### CR-03 (BLOCKER): The documented advanced webhook configuration retains raw bodies globally, including multipart uploads

**File:** `guides/webhooks.md:165-169`

**Issue:** The example attaches `CacheBodyReader` to the endpoint-wide `Plug.Parsers`, permits `"*/*"`, and includes `:multipart`. `body_reader` consequently caches every parser-consumed request, including multipart data, not just the forwarded webhook route. That directly contradicts the surrounding privacy contract that says to scope it narrowly and not use it for multipart parsing, and can retain arbitrary PII/file content for each connection.

**Fix:** Document a route-scoped parser pipeline/body reader that handles only the webhook content type and excludes multipart, or remove the sample until that configuration is available. Add an integration-style Plug test that demonstrates the published topology does not set `private[:raw_body]` on non-webhook or multipart requests.

## Warnings

### WR-01 (WARNING): `Retry-After` parser accepts signed values despite the documented strict decimal contract

**File:** `lib/lattice_stripe/error.ex:205-209`

**Issue:** `Integer.parse/1` accepts `"+5"` and `"-0"`; both pass the non-negative guard, even though a strict decimal-seconds value is digits only. The guide and test title promise a “valid, non-negative decimal” parser, so external retry evidence can be misclassified.

**Fix:** After trimming OWS, require `Regex.match?(~r/^\d+$/, value)` before `String.to_integer/1` (or use an equivalent digit-only parser). Add `+5` and `-0` to the rejected-value cases.

### WR-02 (WARNING): Mount-before-parsers verification drops chunked raw request bodies

**File:** `lib/lattice_stripe/webhook/plug.ex:278-284`

**Issue:** Without `CacheBodyReader`, `get_raw_body/1` accepts only `{:ok, body, conn}`. `Plug.Conn.read_body/2` can return `{:more, chunk, conn}` when the configured read length is exceeded; this branch returns `""`, making signature verification fail for an otherwise valid webhook. The chunk-integrity test covers only the cache reader, not the primary mount-before-parsers strategy.

**Fix:** Recursively read and concatenate every `{:more, chunk, conn}` result until `{:ok, last_chunk, conn}`, while preserving byte order. Add an end-to-end Plug test that forces multiple reads without a cached body.

### WR-03 (WARNING): PaymentIntent confirmation/SCA example is internally contradictory and unsafe for common 3DS responses

**File:** `guides/payments.md:71-81, 97-99, 232-245, 406-410`

**Issue:** The guide says `confirmation_method: "manual"` is what enables server-side confirmation, although the code must still call `PaymentIntent.confirm/3`; it then dereferences only `next_action["redirect_to_url"]["url"]`. Common Stripe.js 3DS flows use a `use_stripe_sdk` next action, so this example can crash or direct an adopter down the wrong confirmation path. The later Charge example sends `confirm: true` server-side but says to then confirm it with Stripe.js, contradicting its own request.

**Fix:** Separate client-SDK and server-confirmation flows. For `:requires_action`, pass the client secret/next action to Stripe.js (or branch explicitly by `next_action.type`) rather than assuming a redirect URL; state that `confirmation_method` determines who may call `confirm`, not that it itself confirms. Update the `confirm: true` example narrative accordingly.

## Info

### IN-01 (INFO): Documentation tests lock strings but do not validate the published behavioral claims

**File:** `test/lattice_stripe/docs_truth_test.exs:7-22, 266-278`

**Issue:** The Charge-policy test positively requires the contradictory `"confirm" => true` snippet, while the cache-reader test only verifies direct reader calls. These string locks can keep the incorrect SCA guidance and unsafe endpoint-wide parser topology in place while all tests pass.

**Fix:** Keep the text-presence checks as drift guards, but add executable examples/topology tests for the claimed PaymentIntent and Plug behavior; make the string assertions describe the corrected contract.

---

_Reviewed: 2026-08-25T18:17:47Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
